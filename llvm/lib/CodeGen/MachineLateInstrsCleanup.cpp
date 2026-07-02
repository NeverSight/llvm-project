//==--- MachineLateInstrsCleanup.cpp - Late Instructions Cleanup Pass -----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This simple pass removes any identical and redundant immediate or address
// loads to the same register. The immediate loads removed can originally be
// the result of rematerialization, while the addresses are redundant frame
// addressing anchor points created during Frame Indices elimination.
//
//===----------------------------------------------------------------------===//

#include "llvm/CodeGen/MachineLateInstrsCleanup.h"
#include "llvm/ADT/BitVector.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineOperand.h"
#include "llvm/CodeGen/TargetInstrInfo.h"
#include "llvm/CodeGen/TargetRegisterInfo.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"
#include "llvm/InitializePasses.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"

using namespace llvm;

#define DEBUG_TYPE "machine-latecleanup"

STATISTIC(NumRemoved, "Number of redundant instructions removed.");

// Removing one redundant rematerialized def requires clearing every kill flag
// on the register along the CFG paths back to the reaching def -- clearing only
// *some* of them would leave a stale kill on a now-extended live range, i.e. a
// miscompile.  So unlike the sibling addressing-combine guards
// (combiner-post-index-max-base-users / arm-max-base-updates-to-check) we must
// not truncate the clear midway; instead we probe the region first and, when it
// is larger than this bound, conservatively keep the redundant def (always
// valid, only very slightly larger code).  Real code's rematerialized-address
// reuse spans a handful of blocks and never approaches this; only pathological
// flattened/obfuscated CFGs (thousands of blocks, O(defs x blocks) blow-up) hit
// it.
static cl::opt<unsigned> MaxClearKillsBlocks(
    "latecleanup-max-clearkills-blocks", cl::Hidden, cl::init(1000),
    cl::desc("Max CFG blocks MachineLateInstrsCleanup walks backwards to clear "
             "kill flags for one removed redundant def; beyond this the def is "
             "conservatively kept instead."));

namespace {

class MachineLateInstrsCleanup {
  const TargetRegisterInfo *TRI = nullptr;
  const TargetInstrInfo *TII = nullptr;

  // Data structures to map regs to their definitions and kills per MBB.
  struct Reg2MIMap : public SmallDenseMap<Register, MachineInstr *> {
    bool hasIdentical(Register Reg, MachineInstr *ArgMI) {
      MachineInstr *MI = lookup(Reg);
      return MI && MI->isIdenticalTo(*ArgMI);
    }
  };
  typedef SmallDenseMap<Register, TinyPtrVector<MachineInstr *>> Reg2MIVecMap;
  std::vector<Reg2MIMap> RegDefs;
  std::vector<Reg2MIVecMap> RegKills;

  // Walk through the instructions in MBB and remove any redundant
  // instructions.
  bool processBlock(MachineBasicBlock *MBB);

  // Try to remove a redundant def.  Returns false (leaving MI in place) when
  // clearing its kill flags would require walking more than
  // MaxClearKillsBlocks blocks -- keeping the def is always valid.
  bool removeRedundantDef(MachineInstr *MI);

  // Backward CFG walk that *collects* (does not yet clear) the kill flags to
  // drop and the blocks that must gain a live-in for Reg.  Returns false as
  // soon as Budget is exhausted, so nothing is committed for an oversized
  // region.
  bool collectKillsForDef(Register Reg, MachineBasicBlock *MBB,
                          BitVector &VisitedPreds, MachineInstr *ToRemoveMI,
                          SmallVectorImpl<MachineInstr *> &KillsToClear,
                          SmallVectorImpl<MachineBasicBlock *> &LiveInBlocks,
                          unsigned &Budget);

public:
  bool run(MachineFunction &MF);
};

class MachineLateInstrsCleanupLegacy : public MachineFunctionPass {
public:
  static char ID; // Pass identification, replacement for typeid

  MachineLateInstrsCleanupLegacy() : MachineFunctionPass(ID) {}

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

  MachineFunctionProperties getRequiredProperties() const override {
    return MachineFunctionProperties().setNoVRegs();
  }
};

} // end anonymous namespace

char MachineLateInstrsCleanupLegacy::ID = 0;

char &llvm::MachineLateInstrsCleanupID = MachineLateInstrsCleanupLegacy::ID;

INITIALIZE_PASS(MachineLateInstrsCleanupLegacy, DEBUG_TYPE,
                "Machine Late Instructions Cleanup Pass", false, false)

bool MachineLateInstrsCleanupLegacy::runOnMachineFunction(MachineFunction &MF) {
  if (skipFunction(MF.getFunction()))
    return false;

  return MachineLateInstrsCleanup().run(MF);
}

PreservedAnalyses
MachineLateInstrsCleanupPass::run(MachineFunction &MF,
                                  MachineFunctionAnalysisManager &MFAM) {
  MFPropsModifier _(*this, MF);
  if (!MachineLateInstrsCleanup().run(MF))
    return PreservedAnalyses::all();
  auto PA = getMachineFunctionPassPreservedAnalyses();
  PA.preserveSet<CFGAnalyses>();
  return PA;
}

bool MachineLateInstrsCleanup::run(MachineFunction &MF) {
  TRI = MF.getSubtarget().getRegisterInfo();
  TII = MF.getSubtarget().getInstrInfo();

  RegDefs.clear();
  RegDefs.resize(MF.getNumBlockIDs());
  RegKills.clear();
  RegKills.resize(MF.getNumBlockIDs());

  // Visit all MBBs in an order that maximises the reuse from predecessors.
  bool Changed = false;
  ReversePostOrderTraversal<MachineFunction *> RPOT(&MF);
  for (MachineBasicBlock *MBB : RPOT)
    Changed |= processBlock(MBB);

  return Changed;
}

// Collect (but do not yet clear) the preceding kill flags on Reg that must be
// dropped when removing a redundant definition, along with the blocks that need
// a live-in added for Reg.  Bounded by Budget: returns false the moment the
// walk would exceed it, so the caller can keep the redundant def rather than
// commit a partial (miscompiling) kill-flag clear.
bool MachineLateInstrsCleanup::collectKillsForDef(
    Register Reg, MachineBasicBlock *MBB, BitVector &VisitedPreds,
    MachineInstr *ToRemoveMI, SmallVectorImpl<MachineInstr *> &KillsToClear,
    SmallVectorImpl<MachineBasicBlock *> &LiveInBlocks, unsigned &Budget) {
  if (Budget == 0)
    return false;
  --Budget;
  VisitedPreds.set(MBB->getNumber());

  // Record kill flag(s) in MBB, that have been seen after the preceding
  // definition. If Reg or one of its subregs was killed, it would actually
  // be ok to stop after removing that (and any other) kill-flag, but it
  // doesn't seem noticeably faster while it would be a bit more complicated.
  Reg2MIVecMap &MBBKills = RegKills[MBB->getNumber()];
  if (auto Kills = MBBKills.find(Reg); Kills != MBBKills.end())
    for (auto *KillMI : Kills->second)
      KillsToClear.push_back(KillMI);

  // Definition in current MBB: done.
  Reg2MIMap &MBBDefs = RegDefs[MBB->getNumber()];
  MachineInstr *DefMI = MBBDefs[Reg];
  assert(DefMI->isIdenticalTo(*ToRemoveMI) && "Previous def not identical?");
  if (DefMI->getParent() == MBB)
    return true;

  // If an earlier def is not in MBB, continue in predecessors.
  if (!MBB->isLiveIn(Reg))
    LiveInBlocks.push_back(MBB);
  assert(!MBB->pred_empty() && "Predecessor def not found!");
  for (MachineBasicBlock *Pred : MBB->predecessors())
    if (!VisitedPreds.test(Pred->getNumber()))
      if (!collectKillsForDef(Reg, Pred, VisitedPreds, ToRemoveMI, KillsToClear,
                              LiveInBlocks, Budget))
        return false;
  return true;
}

bool MachineLateInstrsCleanup::removeRedundantDef(MachineInstr *MI) {
  Register Reg = MI->getOperand(0).getReg();
  BitVector VisitedPreds(MI->getMF()->getNumBlockIDs());
  SmallVector<MachineInstr *, 16> KillsToClear;
  SmallVector<MachineBasicBlock *, 16> LiveInBlocks;
  unsigned Budget = MaxClearKillsBlocks;

  // Probe the region first.  If it is too large, keep the def: clearing only
  // part of the kills (as a mid-walk bail would) could leave a stale kill on
  // the extended live range, so we must clear all-or-nothing.
  if (!collectKillsForDef(Reg, MI->getParent(), VisitedPreds, MI, KillsToClear,
                          LiveInBlocks, Budget))
    return false;

  // Region within budget: commit the exact same mutations the unbounded walk
  // would have (order between them is irrelevant).
  for (MachineBasicBlock *Block : LiveInBlocks)
    Block->addLiveIn(Reg);
  for (MachineInstr *KillMI : KillsToClear)
    KillMI->clearRegisterKills(Reg, TRI);
  MI->eraseFromParent();
  ++NumRemoved;
  return true;
}

// Return true if MI is a potential candidate for reuse/removal and if so
// also the register it defines in DefedReg.  A candidate is a simple
// instruction that does not touch memory, has only one register definition
// and the only reg it may use is FrameReg. Typically this is an immediate
// load or a load-address instruction.
static bool isCandidate(const MachineInstr *MI, Register &DefedReg,
                        Register FrameReg) {
  DefedReg = MCRegister::NoRegister;
  bool SawStore = true;
  if (!MI->isSafeToMove(SawStore) || MI->isImplicitDef() || MI->isInlineAsm())
    return false;
  for (unsigned i = 0, e = MI->getNumOperands(); i != e; ++i) {
    const MachineOperand &MO = MI->getOperand(i);
    if (MO.isReg()) {
      if (MO.isDef()) {
        if (i == 0 && !MO.isImplicit() && !MO.isDead())
          DefedReg = MO.getReg();
        else
          return false;
      } else if (MO.getReg() && MO.getReg() != FrameReg)
        return false;
    } else if (!(MO.isImm() || MO.isCImm() || MO.isFPImm() || MO.isCPI() ||
                 MO.isGlobal() || MO.isSymbol()))
      return false;
  }
  return DefedReg.isValid();
}

bool MachineLateInstrsCleanup::processBlock(MachineBasicBlock *MBB) {
  bool Changed = false;
  Reg2MIMap &MBBDefs = RegDefs[MBB->getNumber()];
  Reg2MIVecMap &MBBKills = RegKills[MBB->getNumber()];

  // Find reusable definitions in the predecessor(s).
  if (!MBB->pred_empty() && !MBB->isEHPad() &&
      !MBB->isInlineAsmBrIndirectTarget()) {
    MachineBasicBlock *FirstPred = *MBB->pred_begin();
    for (auto [Reg, DefMI] : RegDefs[FirstPred->getNumber()])
      if (llvm::all_of(
              drop_begin(MBB->predecessors()),
              [&, &Reg = Reg, &DefMI = DefMI](const MachineBasicBlock *Pred) {
                return RegDefs[Pred->getNumber()].hasIdentical(Reg, DefMI);
              })) {
        MBBDefs[Reg] = DefMI;
        LLVM_DEBUG(dbgs() << "Reusable instruction from pred(s): in "
                          << printMBBReference(*MBB) << ":  " << *DefMI);
      }
  }

  // Process MBB.
  MachineFunction *MF = MBB->getParent();
  const TargetRegisterInfo *TRI = MF->getSubtarget().getRegisterInfo();
  Register FrameReg = TRI->getFrameRegister(*MF);
  for (MachineInstr &MI : llvm::make_early_inc_range(*MBB)) {
    // If FrameReg is modified, no previous load-address instructions (using
    // it) are valid.
    if (MI.modifiesRegister(FrameReg, TRI)) {
      MBBDefs.clear();
      MBBKills.clear();
      continue;
    }

    Register DefedReg;
    bool IsCandidate = isCandidate(&MI, DefedReg, FrameReg);

    // Check for an earlier identical and reusable instruction.
    if (IsCandidate && MBBDefs.hasIdentical(DefedReg, &MI)) {
      // removeRedundantDef may decline (return false) for an oversized kill-
      // clearing region; then fall through and treat MI as a fresh def below.
      if (removeRedundantDef(&MI)) {
        LLVM_DEBUG(dbgs() << "Removing redundant instruction in "
                          << printMBBReference(*MBB) << ":  " << MI);
        Changed = true;
        continue;
      }
    }

    // Clear any entries in map that MI clobbers.
    for (auto DefI : llvm::make_early_inc_range(MBBDefs)) {
      Register Reg = DefI.first;
      if (MI.modifiesRegister(Reg, TRI)) {
        MBBDefs.erase(Reg);
        MBBKills.erase(Reg);
      } else if (MI.findRegisterUseOperandIdx(Reg, TRI, true /*isKill*/) != -1)
        // Keep track of all instructions that fully or partially kills Reg.
        MBBKills[Reg].push_back(&MI);
    }

    // Record this MI for potential later reuse.
    if (IsCandidate) {
      LLVM_DEBUG(dbgs() << "Found interesting instruction in "
                        << printMBBReference(*MBB) << ":  " << MI);
      MBBDefs[DefedReg] = &MI;
      assert(!MBBKills.count(DefedReg) && "Should already have been removed.");
    }
  }

  return Changed;
}
