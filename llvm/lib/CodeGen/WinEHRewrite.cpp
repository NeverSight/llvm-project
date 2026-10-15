//===- WinEHRewrite.cpp - WinEH rewrite symbols --------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/StringExtras.h"
#include "llvm/CodeGen/WinEHFuncInfo.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicsX86.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCContext.h"

using namespace llvm;

bool llvm::hasWinX86SEHStateWriteRequests(const Function &Parent) {
  for (const User *Use : Parent.users())
    if (const auto *Call = dyn_cast<CallBase>(Use);
        Call && Call->getIntrinsicID() == Intrinsic::x86_seh_setstate &&
        Call->getArgOperand(0) == &Parent)
      return true;
  return false;
}

MCSymbol *llvm::getWinX86SEHStateSymbol(
    MCContext &Context, StringRef ParentName,
    const std::optional<mc_rewrite::RewriteWinEHSemanticToken> &Token) {
  std::string Name = (Context.getAsmInfo().getInternalSymbolPrefix() +
                      ParentName + "$seh_state$")
                         .str();
  if (!Token)
    Name += "base";
  else {
    Name += utostr(Token->Region);
    for (uint64_t Word : Token->Digest)
      Name += "$" + utohexstr(Word);
  }
  return Context.getOrCreateSymbol(Name);
}
