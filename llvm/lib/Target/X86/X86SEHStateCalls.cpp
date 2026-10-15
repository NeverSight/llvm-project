//===- X86SEHStateCalls.cpp - Calls in a dynamic SEH scope ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "X86SEHState.h"
#include "llvm/IR/EHPersonalities.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/MC/BinaryRewrite.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

bool llvm::inheritsX86SEHState(const CallBase &Call) {
  return Call.getAttributes().hasFnAttr(
      mc_rewrite::RewriteWinX86SEHInheritStateAttribute);
}

void llvm::validateX86SEHStateCalls(Module &M) {
  const auto Name = mc_rewrite::RewriteWinX86SEHInheritStateAttribute;
  auto Fail = [&](const Twine &Reason) {
    report_fatal_error(Name + ": " + Reason);
  };
  for (Function &F : M) {
    if (F.hasFnAttribute(Name))
      Fail("attribute must belong to a call site, not a function");
    SmallVector<CallInst *, 4> Calls;
    for (Instruction &I : instructions(F)) {
      const auto *Call = dyn_cast<CallBase>(&I);
      if (!Call || !inheritsX86SEHState(*Call))
        continue;
      auto *CI = dyn_cast<CallInst>(&I);
      if (!CI || CI->isTailCall() || CI->isInlineAsm() ||
          isa<IntrinsicInst>(CI) || CI->getOperandBundle("funclet"))
        Fail("requires an ordinary non-tail parent call");
      if (!CI->getAttributes().getFnAttr(Name).getValueAsString().empty() ||
          !CI->getAttributes().hasFnAttr(Attribute::NoInline))
        Fail("requires an empty marker and a noinline call site");
      if (const auto *Callee = CI->getCalledFunction();
          Callee && Callee->getName() == "_setjmp3") {
        const auto *Count = CI->arg_size() == 2
                                ? dyn_cast<ConstantInt>(CI->getArgOperand(1))
                                : nullptr;
        if (!CI->getType()->isIntegerTy(32) || !Count ||
            !Count->getType()->isIntegerTy(32) || !Count->isZero() ||
            !CI->getArgOperand(0)->getType()->isPointerTy())
          Fail("setjmp requires the compiler-owned (buffer, 0) interface");
      }
      Calls.push_back(CI);
    }
    if (Calls.empty())
      continue;
    const auto *Personality =
        F.hasPersonalityFn()
            ? dyn_cast<Function>(F.getPersonalityFn()->stripPointerCasts())
            : nullptr;
    if (F.hasAvailableExternallyLinkage() ||
        !F.hasFnAttribute(
            mc_rewrite::RewriteWinX86RegistrationStateAttribute) ||
        !Personality ||
        (Personality->getName() != "_except_handler3" &&
         Personality->getName() != "_except_handler4") ||
        !M.getTargetTriple().isWindowsMSVCEnvironment() ||
        llvm::none_of(F, [](const BasicBlock &BB) { return BB.isEHPad(); }))
      Fail("requires a defined MSVC SEH rewrite parent with EH pads");
    auto Colors = colorEHFunclets(F);
    for (CallInst *Call : Calls) {
      const auto Found = Colors.find(Call->getParent());
      if (Found == Colors.end() || Found->second.size() != 1 ||
          Found->second.front() != &F.getEntryBlock())
        Fail("call must execute exclusively in the parent frame");
    }
  }
}
