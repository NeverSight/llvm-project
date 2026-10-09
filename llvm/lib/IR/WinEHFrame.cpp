//===- WinEHFrame.cpp - Checked Windows rewrite frame objects
//--------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/IR/WinEHFrame.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Metadata.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/Errc.h"
#include "llvm/TargetParser/Triple.h"

using namespace llvm;

Error llvm::validateRewriteWinX86CxxFrame(const Function &F) {
  const Triple &TT = F.getParent()->getTargetTriple();
  const auto *Personality =
      F.hasPersonalityFn()
          ? dyn_cast<Function>(F.getPersonalityFn()->stripPointerCasts())
          : nullptr;
  if (!F.hasFnAttribute(RewriteWinX86CxxFrameAttribute) || F.isDeclaration() ||
      TT.getArch() != Triple::x86 || !TT.isWindowsMSVCEnvironment() ||
      F.getDataLayout().getIndexSizeInBits(0) != 32 || !Personality ||
      Personality->getName() != "__CxxFrameHandler3" ||
      !F.getFnAttribute(RewriteWinX86CxxFrameAttribute)
           .getValueAsString()
           .empty())
    return createStringError(
        errc::invalid_argument,
        "rewrite C++ frame requires the PE32 MSVC C++ ABI");
  return Error::success();
}

Expected<RewriteWinX86CxxCatchFrameObject>
llvm::getRewriteWinX86CxxCatchFrameObject(const CatchPadInst &CPI) {
  const Function &F = *CPI.getFunction();
  if (Error E = validateRewriteWinX86CxxFrame(F))
    return std::move(E);
  if (CPI.arg_size() != 3 || !isa<Constant>(CPI.getArgOperand(0)) ||
      (!isa<GlobalVariable>(CPI.getArgOperand(0)->stripPointerCasts()) &&
       !isa<ConstantPointerNull>(CPI.getArgOperand(0))) ||
      !isa<ConstantInt>(CPI.getArgOperand(1)) ||
      !CPI.getArgOperand(1)->getType()->isIntegerTy(32) ||
      !CPI.getArgOperand(2)->getType()->isPointerTy())
    return createStringError(errc::invalid_argument,
                             "rewrite C++ catch operands have no FH3 ABI");
  const MDNode *MD = CPI.getMetadata(RewriteWinX86CxxCatchObjectAttachment);
  const Value *Object = CPI.getArgOperand(2);
  if (isa<ConstantPointerNull>(Object)) {
    if (MD)
      return createStringError(errc::invalid_argument,
                               "rewrite C++ null catch object has an extent");
    return RewriteWinX86CxxCatchFrameObject{};
  }
  auto UInt = [&](unsigned Index) -> std::optional<uint32_t> {
    if (!MD || MD->getNumOperands() != 3)
      return std::nullopt;
    const auto *CM =
        dyn_cast_or_null<ConstantAsMetadata>(MD->getOperand(Index).get());
    const auto *CI = CM ? dyn_cast<ConstantInt>(CM->getValue()) : nullptr;
    if (!CI || !CI->getType()->isIntegerTy(32))
      return std::nullopt;
    return static_cast<uint32_t>(CI->getZExtValue());
  };
  const auto Version = UInt(0), Offset = UInt(1), Size = UInt(2);
  if (!Version || *Version != 1 || !Offset || !Size || !*Size)
    return createStringError(errc::invalid_argument,
                             "rewrite C++ catch object has no checked extent");

  const DataLayout &DL = F.getDataLayout();
  const auto *AI = dyn_cast<AllocaInst>(Object);
  const auto Allocation = AI ? AI->getAllocationSize(DL) : std::nullopt;
  if (!AI || AI->getFunction() != &F || !AI->isStaticAlloca() ||
      AI->getParent() != &F.getEntryBlock() || AI->getAddressSpace() != 0 ||
      AI->isSwiftError() || AI->isUsedWithInAlloca() || !Allocation ||
      Allocation->isScalable() || Allocation->getFixedValue() > INT32_MAX ||
      *Offset > Allocation->getFixedValue() ||
      *Size > Allocation->getFixedValue() - *Offset)
    return createStringError(
        errc::invalid_argument,
        "rewrite C++ catch object exceeds its static frame");
  return RewriteWinX86CxxCatchFrameObject{AI, *Offset, *Size};
}
