//===- X86SEHState.cpp - SEH callback state writes -----------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "X86SEHState.h"
#include "X86.h"
#include "X86Subtarget.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/SelectionDAG.h"
#include "llvm/CodeGen/WinEHFuncInfo.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/IntrinsicsX86.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

static bool isIntrinsic(const Value *V, Intrinsic::ID ID) {
  const auto *Call = dyn_cast<IntrinsicInst>(V->stripPointerCasts());
  return Call && Call->getIntrinsicID() == ID;
}

// Used lists preserve an outlined callback's runtime ABI through IPO. They do
// not introduce a runtime caller or an address escape.
static bool isUsedListReference(const User *U) {
  const auto *Array = dyn_cast<ConstantArray>(U);
  if (!Array || Array->use_empty())
    return false;
  return llvm::all_of(Array->users(), [&](const User *Use) {
    const auto *GV = dyn_cast<GlobalVariable>(Use);
    return GV && GV->hasAppendingLinkage() && GV->use_empty() &&
           GV->getInitializer() == Array &&
           GV->getSection() == "llvm.metadata" &&
           (GV->getName() == "llvm.used" ||
            GV->getName() == "llvm.compiler.used");
  });
}

static bool isFilterParentAddress(const Value *Frame, const Function &Filter,
                                  const Function &Parent) {
  if (!Filter.hasLocalLinkage() || Filter.isVarArg() ||
      Filter.getCallingConv() != CallingConv::C || !Filter.arg_empty() ||
      !Filter.getReturnType()->isIntegerTy(32))
    return false;
  bool FoundFilter = false;
  for (const User *Use : Filter.users()) {
    if (isUsedListReference(Use))
      continue;
    const auto *Pad = dyn_cast<CatchPadInst>(Use);
    if (!Pad || Pad->getFunction() != &Parent || Pad->arg_size() != 1 ||
        Pad->getArgOperand(0) != &Filter)
      return false;
    FoundFilter = true;
  }
  if (!FoundFilter)
    return false;
  const auto *Recover = dyn_cast<IntrinsicInst>(Frame->stripPointerCasts());
  if (!Recover || Recover->getIntrinsicID() != Intrinsic::eh_recoverfp ||
      Recover->getArgOperand(0) != &Parent)
    return false;
  const auto *Address =
      dyn_cast<IntrinsicInst>(Recover->getArgOperand(1)->stripPointerCasts());
  const auto *Depth =
      Address && Address->getIntrinsicID() == Intrinsic::frameaddress
          ? dyn_cast<ConstantInt>(Address->getArgOperand(0))
          : nullptr;
  return Depth && Depth->equalsInt(1);
}

static bool isFinallyFrameArgument(const Value *Frame,
                                   const Function &Callback) {
  const auto *Arg = dyn_cast<Argument>(Frame->stripPointerCasts());
  return Callback.hasLocalLinkage() && !Callback.isVarArg() &&
         Callback.getCallingConv() == CallingConv::C && Arg &&
         Arg->getParent() == &Callback && Arg->getArgNo() == 1 &&
         Callback.arg_size() == 2 && Callback.getReturnType()->isVoidTy() &&
         Callback.getArg(0)->getType()->isIntegerTy(8);
}

static bool hasParentLocalAddress(const CallBase &Write,
                                  const Function &Parent) {
  const Function &Callback = *Write.getFunction();
  const Value *Frame = Write.getArgOperand(1);
  if (isFilterParentAddress(Frame, Callback, Parent))
    return true;
  if (!isFinallyFrameArgument(Frame, Callback))
    return false;

  // Nested finally calls forward the same physical parent localaddress. Check
  // every use, then propagate proven roots through the finite callback graph.
  // This accepts rooted recursion without recursively walking caller chains,
  // and rejects an unrooted cycle or any unchecked caller/address escape.
  SmallVector<const Function *, 8> Pending{&Callback};
  DenseSet<const Function *> Visited{&Callback};
  DenseSet<const Function *> Rooted;
  DenseMap<const Function *, SmallVector<const Function *, 2>> Dependents;
  for (unsigned Index = 0; Index != Pending.size(); ++Index) {
    const Function *Current = Pending[Index];
    for (const User *Use : Current->users()) {
      if (isUsedListReference(Use))
        continue;
      const auto *Call = dyn_cast<CallBase>(Use);
      if (!Call || Call->getCalledOperand() != Current ||
          Call->arg_size() != 2 || Call->getCallingConv() != CallingConv::C)
        return false;
      const Function *Caller = Call->getFunction();
      const Value *Incoming = Call->getArgOperand(1);
      if ((Caller == &Parent &&
           isIntrinsic(Incoming, Intrinsic::localaddress)) ||
          isFilterParentAddress(Incoming, *Caller, Parent)) {
        Rooted.insert(Current);
        continue;
      }
      if (!isFinallyFrameArgument(Incoming, *Caller))
        return false;
      Dependents[Caller].push_back(Current);
      if (Visited.insert(Caller).second)
        Pending.push_back(Caller);
    }
  }
  Pending.assign(Rooted.begin(), Rooted.end());
  for (unsigned Index = 0; Index != Pending.size(); ++Index)
    for (const Function *Dependent : Dependents[Pending[Index]])
      if (Rooted.insert(Dependent).second)
        Pending.push_back(Dependent);
  return Rooted.size() == Visited.size();
}

void llvm::validateX86SEHStateWrites(const Module &M) {
  for (const Function &Callback : M) {
    // All nonzero bit patterns are valid source-issued identities.
    SmallSet<uint64_t, 8> WriteIDs;
    for (const Instruction &I : instructions(Callback)) {
      const auto *Write = dyn_cast<CallBase>(&I);
      if (!Write || Write->getIntrinsicID() != Intrinsic::x86_seh_setstate)
        continue;
      auto Fail = [&](const Twine &Reason) {
        report_fatal_error("llvm.x86.seh.setstate: " + Reason);
      };
      if (!isa<CallInst>(Write))
        Fail("state write must be a call instruction");
      const auto *Parent = dyn_cast<Function>(Write->getArgOperand(0));
      if (!Parent || Parent->getParent() != &M || Parent->isDeclaration() ||
          Parent->hasAvailableExternallyLinkage() || Parent == &Callback ||
          !Parent->hasFnAttribute(
              mc_rewrite::RewriteWinX86RegistrationStateAttribute) ||
          !Parent->hasPersonalityFn())
        Fail("parent must be a defined SEH rewrite function in this module");
      const auto *Personality =
          dyn_cast<Function>(Parent->getPersonalityFn()->stripPointerCasts());
      if (!Personality || (Personality->getName() != "_except_handler3" &&
                           Personality->getName() != "_except_handler4"))
        Fail("parent must use _except_handler3 or _except_handler4");
      if (!hasParentLocalAddress(*Write, *Parent))
        Fail("frame must be the callback's checked parent localaddress");

      // ImmArg verification normally checks this before code generation. Keep
      // the backend boundary checked for clients which omit the IR verifier.
      std::array<const ConstantInt *, 6> Constants;
      for (unsigned J = 0; J != Constants.size(); ++J) {
        Constants[J] = dyn_cast<ConstantInt>(Write->getArgOperand(J + 2));
        if (!Constants[J] || Constants[J]->getBitWidth() != (J == 0 ? 32 : 64))
          Fail("source state, digest and write identity must be constants");
      }
      const uint64_t WriteID = Constants[5]->getZExtValue();
      if (!WriteID || !WriteIDs.insert(WriteID).second)
        Fail("write identity must be nonzero and unique within its callback");
      const int64_t SourceState = Constants[0]->getSExtValue();
      mc_rewrite::RewriteWinEHSemanticToken Token;
      Token.Kind = mc_rewrite::RewriteWinEHSemanticKind::SEHScope;
      Token.Region = static_cast<uint32_t>(SourceState);
      Token.Clause = 0;
      for (unsigned J = 0; J != Token.Digest.size(); ++J)
        Token.Digest[J] = Constants[J + 1]->getZExtValue();
      if (SourceState < 0) {
        const int Base = Personality->getName() == "_except_handler4" ? -2 : -1;
        if (SourceState != Base ||
            llvm::any_of(Token.Digest, [](uint64_t Word) { return Word != 0; }))
          Fail("sentinel must match the parent personality and have zero "
               "digest");
      } else if (llvm::all_of(Token.Digest,
                              [](uint64_t Word) { return Word == 0; })) {
        Fail("scope digest must be nonzero");
      }
      bool HasScope = false;
      unsigned Matches = 0;
      for (const Instruction &Pad : instructions(Parent)) {
        if (!Pad.isEHPad())
          continue;
        auto Candidate = getRewriteWinEHSemanticToken(
            Pad, mc_rewrite::RewriteWinEHSemanticKind::SEHScope);
        HasScope |= Candidate && Candidate->Clause == 0 &&
                    llvm::any_of(Candidate->Digest,
                                 [](uint64_t Word) { return Word != 0; });
        Matches += Candidate && *Candidate == Token;
      }
      if (!HasScope)
        Fail("parent must retain an authenticated SEH scope");
      if (SourceState >= 0 && Matches != 1)
        Fail("scope token must uniquely identify a parent SEH row");
    }
  }
}

SDValue llvm::lowerX86SEHStateWrite(SDValue Op, SelectionDAG &DAG,
                                    const X86Subtarget &Subtarget) {
  if (Subtarget.is64Bit() || !Subtarget.isTargetWindowsMSVC())
    report_fatal_error("llvm.x86.seh.setstate requires 32-bit MSVC Windows");
  SDLoc DL(Op);
  const auto *Parent = dyn_cast<GlobalAddressSDNode>(Op.getOperand(2));
  if (!Parent || !isa<Function>(Parent->getGlobal()))
    report_fatal_error(
        "llvm.x86.seh.setstate requires a direct parent function");
  SmallVector<SDValue, 9> Operands = {
      Op.getOperand(3),
      DAG.getTargetGlobalAddress(Parent->getGlobal(), DL, MVT::i32)};
  for (unsigned J = 4; J != 10; ++J) {
    const auto *Constant = dyn_cast<ConstantSDNode>(Op.getOperand(J));
    if (!Constant)
      report_fatal_error("llvm.x86.seh.setstate requires constant identities");
    Operands.push_back(DAG.getTargetConstant(Constant->getAPIntValue(), DL,
                                             J == 4 ? MVT::i32 : MVT::i64));
  }
  Operands.push_back(Op.getOperand(0));
  MachineSDNode *Node =
      DAG.getMachineNode(X86::SEH_SetState, DL, MVT::Other, Operands);
  MachineMemOperand *Memory = DAG.getMachineFunction().getMachineMemOperand(
      MachinePointerInfo(),
      MachineMemOperand::MOStore | MachineMemOperand::MOVolatile, 4, Align(4));
  DAG.setNodeMemRefs(Node, {Memory});
  return SDValue(Node, 0);
}
