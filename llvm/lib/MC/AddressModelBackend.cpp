//===- AddressModelBackend.cpp - Backend decorator for rewriting ----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// AddressModelBackend resolves external/cross-section symbols to final VAs
/// using the caller-provided RewriteAddressModel and returns IsResolved=true,
/// so the stock applyFixup back-fills the bytes and no relocation is recorded.
/// Special handling for AArch64 ADRP (page-aligned delta) and @PAGEOFF (low
/// 12-bit mask) ensures correct encoding at non-page-aligned fixup PCs.
///
//===----------------------------------------------------------------------===//

#include "AddressModelBackend.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCSection.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCValue.h"

namespace {
// Detect AArch64 ADRP and ADD/LDR imm12 fixup kinds by name rather than
// numeric value — the target-specific fixup kind enum starts at
// FirstTargetFixupKind for every backend, so raw integer comparisons
// would collide with x86/ARM fixup kinds.
bool isAArch64PageFixup(const llvm::MCAsmBackend &MAB, unsigned FK) {
  if (FK < llvm::FirstTargetFixupKind)
    return false;
  llvm::StringRef Name =
      MAB.getFixupKindInfo(static_cast<llvm::MCFixupKind>(FK)).Name;
  return Name.contains("adrp");
}
bool isAArch64PageOffFixup(const llvm::MCAsmBackend &MAB, unsigned FK) {
  if (FK < llvm::FirstTargetFixupKind)
    return false;
  llvm::StringRef Name =
      MAB.getFixupKindInfo(static_cast<llvm::MCFixupKind>(FK)).Name;
  return Name.contains("add_imm12") || Name.contains("ldst_imm12");
}
} // namespace

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

  // Preserve any pre-seed the wrapped backend wrote into Value. MCAssembler
  // zero-initialises Value before calling this hook, then the stock fallback
  // does `Value += Target.getConstant()` (MCAssembler::evaluateFixup) so any
  // pre-seed survives. We must mirror that with `+=`, not `=`: the ARM backend
  // pre-seeds Value with (fragOffset + fixupOffset) % 4 for Thumb PC-relative
  // ldr fixups (fixup_t2_ldst_pcrel_12 etc.) so the later `Value -= FixupPC`
  // effectively subtracts AlignDown(PC, 4) — the Thumb literal-pool anchor.
  // Overwriting with `=` dropped that low-bit pre-seed, mis-anchoring 32-bit
  // ldr.w literal loads by up to 2 bytes whenever the fixup PC was not already
  // 4-aligned (x86/AArch64 fold their adjustment into Target's constant, so
  // their pre-seed is 0 and `+=` is identical to `=`).
  Value += Target.getConstant();

  if (const MCSymbol *Add = Target.getAddSym()) {
    auto VA = resolveSymVA(Add);
    if (!VA)
      return std::nullopt;
    // For external symbols resolved via the address model callback, strip the
    // ARM/Thumb interworking bit (bit 0). Resolve callbacks may return
    // addresses with bit 0 set to indicate Thumb mode; this bit must not
    // participate in offset calculations. In-section / absolute symbols use
    // their exact computed addresses (no Thumb bit ambiguity).
    if (!Add->isInSection() && !Add->isAbsolute())
      Value += *VA & ~uint64_t(1);
    else
      Value += *VA;
  }
  if (const MCSymbol *Sub = Target.getSubSym()) {
    auto VA = resolveSymVA(Sub);
    if (!VA)
      return std::nullopt;
    Value -= *VA;
  }

  // Detect PAGE / PAGEOFF addressing mode via specifier OR fixup kind.
  // Specifier detection works for ELF (bitfield) and MachO (enum).
  // Fixup-kind detection covers COFF AArch64 where Spec==0 but the fixup kind
  // unambiguously identifies ADRP (PAGE) or ADD_IMM12/LDST_IMM12 (PAGEOFF).
  uint32_t Spec = Target.getSpecifier();
  unsigned FK = Fixup.getKind();
  bool IsPage = false, IsPageOff = false;
  if (Spec) {
    IsPage = (Spec & 0x0f0) == 0x010;
    IsPage |= (Spec == 0x406 || Spec == 0x404 || Spec == 0x409);
    IsPageOff = (Spec & 0x0f0) == 0x020;
    IsPageOff |= (Spec == 0x407 || Spec == 0x405 || Spec == 0x40a);
  }
  if (!IsPage && isAArch64PageFixup(*Wrapped, FK))
    IsPage = true;
  if (!IsPageOff && isAArch64PageOffFixup(*Wrapped, FK))
    IsPageOff = true;

  if (Fixup.isPCRel()) {
    StringRef Sec = F.getParent()->getName();
    uint64_t SecVA =
        Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Sec) : 0;
    uint64_t FixupPC = SecVA + Asm->getFragmentOffset(F) + Fixup.getOffset();
    if (IsPage) {
      uint64_t PageDelta =
          (Value & ~uint64_t(0xFFF)) - (FixupPC & ~uint64_t(0xFFF));
      // COFF AArch64 adjustFixupValue expects already-shifted page count
      // (Value & 0x1fffff), while ELF/MachO expects the raw byte delta and
      // does (Value & 0x1fffff000) >> 12 internally.
      if (Asm->getContext().getTargetTriple().isOSBinFormatCOFF())
        Value = static_cast<int64_t>(PageDelta) >> 12;
      else
        Value = PageDelta;
    } else {
      Value -= FixupPC;
    }
  }

  if (IsPageOff)
    Value &= 0xFFF;

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

  // ARM/Thumb BL→BLX interworking: when Thumb code calls an ARM-mode target,
  // the compiler emits BL (stays in Thumb) but we need BLX (switches to ARM).
  // After the wrapped backend writes the BL encoding, re-encode as BLX.
  unsigned FK = Fixup.getKind();
  if (FK >= FirstTargetFixupKind && IsResolved) {
    StringRef FKName =
        Wrapped->getFixupKindInfo(static_cast<MCFixupKind>(FK)).Name;
    if (FKName == "fixup_arm_thumb_bl") {
      const MCSymbol *Sym = Target.getAddSym();
      if (Sym && !Sym->isInSection() && !Sym->isAbsolute() &&
          Opts.Model.resolve) {
        auto TargetVA =
            Opts.Model.resolve(Sym->getName(), Target.getSpecifier());
        if (TargetVA && (*TargetVA & 1) == 0) {
          // Target VA is even → ARM mode. Re-encode BL as BLX.
          // BLX offset base = Align(PC+4, 4), not PC+4.
          StringRef Sec = F.getParent()->getName();
          uint64_t SecVA =
              Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Sec) : 0;
          uint64_t PC = SecVA + Asm->getFragmentOffset(F) + Fixup.getOffset();
          uint64_t AlignedBase = (PC + 4) & ~uint64_t(3);
          int32_t Delta = static_cast<int32_t>(
              static_cast<int64_t>(*TargetVA) -
              static_cast<int64_t>(AlignedBase));

          uint32_t offset = static_cast<uint32_t>(Delta) >> 2;
          uint32_t signBit = (offset >> 22) & 1;
          uint32_t I1Bit = (offset >> 21) & 1;
          uint32_t J1Bit = (I1Bit ^ 1) ^ signBit;
          uint32_t I2Bit = (offset >> 20) & 1;
          uint32_t J2Bit = (I2Bit ^ 1) ^ signBit;
          uint32_t imm10H = (offset >> 10) & 0x3FF;
          uint32_t imm10L = offset & 0x3FF;

          // First halfword: 11110 S imm10H
          uint16_t hw1 = 0xF000 | (signBit << 10) | imm10H;
          // Second halfword: 11 J1 0 J2 imm10L 0
          //                       ^ bit12=0 for BLX     ^ H=0
          uint16_t hw2 = 0xC000 | (J1Bit << 13) |
                         (J2Bit << 11) | (imm10L << 1);

          Data[0] = hw1 & 0xFF;
          Data[1] = (hw1 >> 8) & 0xFF;
          Data[2] = hw2 & 0xFF;
          Data[3] = (hw2 >> 8) & 0xFF;
        }
      }
    }
  }
}

std::unique_ptr<MCAsmBackend>
llvm::mc_rewrite::createAddressModelBackend(
    std::unique_ptr<MCAsmBackend> TargetBackend,
    const mc_rewrite::RewriteOptions &Opts) {
  return std::make_unique<AddressModelBackend>(std::move(TargetBackend), Opts);
}
