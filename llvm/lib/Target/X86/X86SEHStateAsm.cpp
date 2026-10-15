//===- X86SEHStateAsm.cpp - SEH state assembly ---------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "X86AsmPrinter.h"
#include "X86Subtarget.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/WinEHFuncInfo.h"
#include "llvm/IR/Function.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInstBuilder.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCStreamer.h"

using namespace llvm;

void X86AsmPrinter::emitSEHStateWrite(const MachineInstr &MI) {
  const auto *Parent = cast<Function>(MI.getOperand(1).getGlobal());
  const StringRef ParentName =
      GlobalValue::dropLLVMManglingEscape(Parent->getName());
  const int64_t SourceState = MI.getOperand(2).getImm();
  std::optional<mc_rewrite::RewriteWinEHSemanticToken> Semantic;
  if (SourceState >= 0) {
    Semantic.emplace();
    Semantic->Kind = mc_rewrite::RewriteWinEHSemanticKind::SEHScope;
    Semantic->Region = static_cast<uint32_t>(SourceState);
    Semantic->Clause = 0;
    for (unsigned J = 0; J != Semantic->Digest.size(); ++J)
      Semantic->Digest[J] =
          static_cast<uint64_t>(MI.getOperand(3 + J).getImm());
  }

  MCSymbol *FrameOffset =
      OutContext.getOrCreateParentFrameOffsetSymbol(ParentName);
  MCSymbol *State = getWinX86SEHStateSymbol(OutContext, ParentName, Semantic);
  SEHStateWriteSymbols.push_back(FrameOffset);
  SEHStateWriteSymbols.push_back(State);
  const MCExpr *Displacement = MCBinaryExpr::createAdd(
      MCSymbolRefExpr::create(FrameOffset, OutContext),
      MCConstantExpr::create(20, OutContext), OutContext);
  MCInst Store = MCInstBuilder(X86::MOV32mi)
                     .addReg(MI.getOperand(0).getReg())
                     .addImm(1)
                     .addReg(0)
                     .addExpr(Displacement)
                     .addReg(0)
                     .addExpr(MCSymbolRefExpr::create(State, OutContext));

  const bool Rewrite = OutContext.requiresRewriteFunctionProvenance();
  MCSymbol *Begin = nullptr;
  MCSymbol *End = nullptr;
  if (Rewrite) {
    Begin = OutContext.createTempSymbol("rewrite_x86_seh_state_write", true);
    End = OutContext.createTempSymbol("rewrite_x86_seh_state_write_end", true);
    OutStreamer->emitLabel(Begin);
  }
  EmitAndCountInstruction(Store);
  if (!Rewrite)
    return;
  OutStreamer->emitLabel(End);

  MCRewriteWinX86SEHStateWrite Write;
  Write.WriteID = static_cast<uint64_t>(MI.getOperand(7).getImm());
  Write.SourceFunction = MF->getFunction().getName().str();
  Write.Owner = CurrentFnSym;
  Write.ParentFrame.SourceFunction = Parent->getName().str();
  Write.ParentFrame.Owner = getSymbol(Parent);
  Write.ParentFrame.RegistrationOffset = FrameOffset;
  const auto *Personality =
      cast<Function>(Parent->getPersonalityFn()->stripPointerCasts());
  Write.ParentFrame.Encoding =
      Personality->getName() == "_except_handler4"
          ? mc_rewrite::RewriteWinEHSemanticEncoding::X86SEH4
          : mc_rewrite::RewriteWinEHSemanticEncoding::X86SEH3;
  Write.Semantic = Semantic;
  Write.GeneratedState = State;
  Write.AddressRegister = TM.getMCRegisterInfo().getEncodingValue(
      MI.getOperand(0).getReg().asMCReg());
  Write.Begin = Begin;
  Write.End = End;
  MCAssembler *Assembler = OutStreamer->getAssemblerPtr();
  assert(Assembler && "rewrite provenance requires an object streamer");
  Assembler->registerRewriteWinX86SEHStateWrite(Write);
}
