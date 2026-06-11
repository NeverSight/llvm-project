//===- AddressModelBackend.cpp - Backend decorator for rewriting ----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// Skeleton implementation of the two rewrite hooks. Both currently forward to
/// the wrapped backend so the decorator is behavior-neutral and links cleanly;
/// the real address-model resolution and per-ISA fixup handling land in a
/// later step.
///
//===----------------------------------------------------------------------===//

#include "AddressModelBackend.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCSection.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCValue.h"

using namespace llvm;

std::unique_ptr<MCObjectTargetWriter>
AddressModelBackend::createObjectTargetWriter() const {
  return Wrapped->createObjectTargetWriter();
}

std::optional<bool> AddressModelBackend::evaluateFixup(const MCFragment &F,
                                                       MCFixup &Fixup,
                                                       MCValue &Target,
                                                       uint64_t &Value) {
  syncWrappedAssembler();

  // Let the wrapped backend try first — it handles ISA-specific pre-adjustments
  // (x86 PC-rel -4, ARM Thumb AlignDown, etc.).
  auto WrappedResult = Wrapped->evaluateFixup(F, Fixup, Target, Value);
  if (WrappedResult && *WrappedResult)
    return true;

  // Resolve via the caller's address model.
  auto resolveSymVA = [&](const MCSymbol *Sym)
      -> std::optional<uint64_t> {
    if (!Sym)
      return std::nullopt;
    if (Sym->isInSection()) {
      StringRef Sec = Sym->getSection().getName();
      uint64_t Base =
          Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Sec) : 0;
      return Base + Asm->getSymbolOffset(*Sym);
    }
    if (Sym->isAbsolute())
      return static_cast<uint64_t>(Asm->getSymbolOffset(*Sym));
    // External — ask the address model.
    if (Opts.Model.resolve)
      return Opts.Model.resolve(Sym->getName(), Target.getSpecifier());
    return std::nullopt;
  };

  Value = Target.getConstant();

  if (const MCSymbol *Add = Target.getAddSym()) {
    auto VA = resolveSymVA(Add);
    if (!VA)
      return std::nullopt;
    Value += *VA;
  }
  if (const MCSymbol *Sub = Target.getSubSym()) {
    auto VA = resolveSymVA(Sub);
    if (!VA)
      return std::nullopt;
    Value -= *VA;
  }

  if (Fixup.isPCRel()) {
    StringRef Sec = F.getParent()->getName();
    uint64_t SecVA =
        Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Sec) : 0;
    Value -= SecVA + Asm->getFragmentOffset(F) + Fixup.getOffset();
  }

  return true;
}

void AddressModelBackend::applyFixup(const MCFragment &F, const MCFixup &Fixup,
                                     const MCValue &Target, uint8_t *Data,
                                     uint64_t Value, bool IsResolved) {
  syncWrappedAssembler();

  if (Opts.onFixup) {
    mc_rewrite::FixupCtx Ctx;
    Ctx.Kind = Fixup.getKind();
    StringRef Sec = F.getParent()->getName();
    uint64_t SecVA =
        Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Sec) : 0;
    Ctx.FixupVA = SecVA + Asm->getFragmentOffset(F) + Fixup.getOffset();
    if (Target.getAddSym())
      Ctx.Sym = Target.getAddSym()->getName();
    Ctx.Specifier = Target.getSpecifier();
    Ctx.IsPCRel = Fixup.isPCRel();
    Ctx.BitWidth = Wrapped->getFixupKindInfo(
        static_cast<MCFixupKind>(Fixup.getKind())).TargetSize;
    Value = Opts.onFixup(Ctx, Value);
  }

  Wrapped->applyFixup(F, Fixup, Target, Data, Value, IsResolved);
}

std::unique_ptr<MCAsmBackend>
llvm::mc_rewrite::createAddressModelBackend(
    std::unique_ptr<MCAsmBackend> TargetBackend,
    const mc_rewrite::RewriteOptions &Opts) {
  return std::make_unique<AddressModelBackend>(std::move(TargetBackend), Opts);
}
