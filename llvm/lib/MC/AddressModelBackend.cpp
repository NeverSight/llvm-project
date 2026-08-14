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
#include "llvm/ADT/APInt.h"
#include "llvm/ADT/ScopeExit.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCSection.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCValue.h"

#include <limits>

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
  SmallPtrSet<const MCSymbol *, 8> ActiveVariables;
  auto resolveSymVA = [&](auto &&Resolve, const MCSymbol *Sym,
                          uint32_t Specifier) -> std::optional<APInt> {
    if (!Sym)
      return std::nullopt;
    if (Sym->isVariable()) {
      // Mach-O uses an anonymous assignment for absolute differences such as
      // an FDE's `function - field` initial location.  Its ordinary object
      // writer recursively evaluates that assignment during relocation.  Do
      // the same here, but against final section VAs and without letting a
      // malformed alias cycle or overflow escape as a plausible address.
      if (!ActiveVariables.insert(Sym).second)
        return std::nullopt;
      scope_exit RemoveActive([&] { ActiveVariables.erase(Sym); });

      MCValue Aliased;
      if (!Sym->getVariableValue()->evaluateAsRelocatable(Aliased, Asm))
        return std::nullopt;
      const uint32_t InnerSpecifier = Aliased.getSpecifier();
      if (Specifier && InnerSpecifier && Specifier != InnerSpecifier)
        return std::nullopt;
      const uint32_t EffectiveSpecifier =
          InnerSpecifier ? InnerSpecifier : Specifier;

      APInt Address(128, static_cast<uint64_t>(Aliased.getConstant()), true);
      if (const MCSymbol *Add = Aliased.getAddSym()) {
        auto AddVA = Resolve(Resolve, Add, EffectiveSpecifier);
        if (!AddVA)
          return std::nullopt;
        bool Overflow = false;
        Address = Address.sadd_ov(*AddVA, Overflow);
        if (Overflow)
          return std::nullopt;
      }
      if (const MCSymbol *Sub = Aliased.getSubSym()) {
        auto SubVA = Resolve(Resolve, Sub, EffectiveSpecifier);
        if (!SubVA)
          return std::nullopt;
        bool Overflow = false;
        Address = Address.ssub_ov(*SubVA, Overflow);
        if (Overflow)
          return std::nullopt;
      }
      return Address;
    }
    if (Sym->isInSection()) {
      // sectionImageVA (not getSectionVA(name)) so that same-named sections —
      // e.g. COFF's per-constant COMDAT ".rdata" — resolve to their packed VA
      // instead of all overlapping at getSectionVA(name).
      uint64_t Base = mc_rewrite::sectionImageVA(*Asm, Opts, Sym->getSection());
      const uint64_t Offset = Asm->getSymbolOffset(*Sym);
      if (Offset > std::numeric_limits<uint64_t>::max() - Base)
        return std::nullopt;
      return APInt(128, Base + Offset);
    }
    if (Sym->isAbsolute())
      return APInt(128, static_cast<uint64_t>(Asm->getSymbolOffset(*Sym)));
    // External — ask the address model.
    if (Opts.Model.resolve) {
      auto Address = Opts.Model.resolve(Sym->getName(), Specifier);
      if (Address)
        return APInt(128, *Address);
    }
    return std::nullopt;
  };

  // A variable expression may be a negative PC-relative delta. Preserve its
  // two's-complement representation while rejecting values that fit neither a
  // signed nor an unsigned 64-bit fixup, instead of confusing a legitimate
  // backward reference with arithmetic underflow.
  auto encode64 = [](const APInt &Address) -> std::optional<uint64_t> {
    if (Address.isNegative() ? !Address.isSignedIntN(64) : !Address.isIntN(64))
      return std::nullopt;
    return Address.trunc(64).getZExtValue();
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

  // R_ARM_NONE records a symbol dependency for linker garbage collection but
  // never contributes that symbol's address to the field.  ARM EHABI emits
  // this fixup at the same offset as an .ARM.exidx function PREL31; treating
  // it as ordinary FK_Data_4 data ORs the personality address into the index
  // word before the PREL31 fixup is applied.
  const Triple &TT = Asm->getContext().getTargetTriple();
  const std::optional<uint32_t> ArmNoneSpecifier =
      Asm->getContext().getAsmInfo().getSpecifierForName("none");
  const bool IsArmNone = (TT.isARM() || TT.isThumb()) &&
                         Fixup.getKind() == FK_Data_4 && ArmNoneSpecifier &&
                         Target.getSpecifier() == *ArmNoneSpecifier;
  if (IsArmNone) {
    Value = 0;
    return true;
  }

  if (const MCSymbol *Add = Target.getAddSym()) {
    auto Address = resolveSymVA(resolveSymVA, Add, Target.getSpecifier());
    auto VA = Address ? encode64(*Address) : std::nullopt;
    if (!VA)
      return std::nullopt;
    // The ARM/Thumb interworking bit (bit 0) is an AArch32-only concept: a
    // function-pointer VA encodes Thumb mode in bit 0, which must not enter the
    // offset math for ARM/Thumb branch fixups, so a resolve callback may return
    // it set. On AArch64/x86 there is no such bit, so stripping it would
    // corrupt a genuine odd in-image address — e.g. a string literal at an odd
    // VA referenced via ADRP+ADD, whose @PAGEOFF would lose its low bit. Gate
    // the strip to AArch32 external symbols; everywhere else use the exact VA.
    bool IsArm32 = TT.isARM() || TT.isThumb();
    // Absolute data relocations (FK_Data_*, non-PC-relative) that point at a
    // Thumb function — function-pointer tables, vtables, GCC computed-goto
    // label tables — must carry the interworking bit so an indirect transfer
    // (blx/bx/ldr pc) through the slot lands in Thumb mode. The stock ELF/COFF
    // writers encode this in the symbol's table value (R_ARM_ABS32 against a
    // Thumb-func symbol keeps bit 0); B2 computes the VA itself — resolveSymVA
    // returns the even byte offset — so it must OR the bit in here. Without it,
    // the loaded pointer is even, blx switches to ARM mode at a Thumb-encoded
    // address, and the fetch faults (UC_ERR_FETCH_UNMAPPED).
    unsigned KindForData = Fixup.getKind();
    bool IsAbsData = !Fixup.isPCRel() &&
                     (KindForData == FK_Data_1 || KindForData == FK_Data_2 ||
                      KindForData == FK_Data_4 || KindForData == FK_Data_8);
    // MOVW/MOVT immediate pairs materialise a 32-bit symbol address directly in
    // code (e.g. Thumb `movw rX,:lower16:f; movt rX,:upper16:f` for a function
    // pointer later called via blx rX). Like an absolute data relocation these
    // must carry the interworking bit on the low half so the indirect transfer
    // lands in Thumb mode; the stock ELF/COFF writers fold it into the symbol
    // value (R_ARM_THM_MOVW_ABS_NC uses S|T, COFF MOV32T sets it), but B2
    // computes the VA itself. These are target-specific fixup kinds, so match
    // by name. OR-ing bit 0 into the full VA is safe for the movt (hi16) half
    // too — it only extracts bits 16..31, which bit 0 never touches.
    bool IsMovwMovt = false;
    if (IsArm32 && !Fixup.isPCRel() && KindForData >= FirstTargetFixupKind) {
      StringRef FKName =
          Wrapped->getFixupKindInfo(static_cast<MCFixupKind>(KindForData)).Name;
      IsMovwMovt = FKName.contains("movw") || FKName.contains("movt");
    }
    bool CallbackSaysThumb =
        !Add->isInSection() && !Add->isAbsolute() && ((*VA & uint64_t(1)) != 0);
    bool TargetIsThumb = Asm->isThumbFunc(Add) || CallbackSaysThumb;
    if (IsArm32 && (IsAbsData || IsMovwMovt) && TargetIsThumb) {
      Value += *VA | uint64_t(1);
    } else {
      Value += IsArm32 && !Add->isInSection() && !Add->isAbsolute()
                   ? (*VA & ~uint64_t(1))
                   : *VA;
    }
  }
  if (const MCSymbol *Sub = Target.getSubSym()) {
    auto Address = resolveSymVA(resolveSymVA, Sub, Target.getSpecifier());
    auto VA = Address ? encode64(*Address) : std::nullopt;
    if (!VA)
      return std::nullopt;
    Value -= *VA;
  }

  // COFF unwind and language tables encode image-relative 32-bit addresses.
  // A normal COFF writer applies IMAGE_REL_*_ADDR32NB at link time; the final
  // image writer bypasses that relocation stage, so honor the expression's
  // IMGREL modifier here.  Keep this in the generic address model rather than
  // teaching callers about .pdata/.xdata wire layouts.
  if (Target.getSpecifier() == MCSymbolRefExpr::VK_COFF_IMGREL32)
    Value -= Opts.Model.ImageBaseVA;

  // Section-relative debug/directive records likewise normally rely on the
  // object writer.  Resolve their value against the referenced MCSection when
  // the add symbol is known.
  if ((Fixup.getKind() == FK_SecRel_1 || Fixup.getKind() == FK_SecRel_2 ||
       Fixup.getKind() == FK_SecRel_4 || Fixup.getKind() == FK_SecRel_8) &&
      Target.getAddSym() && Target.getAddSym()->isInSection()) {
    Value -= mc_rewrite::sectionImageVA(*Asm, Opts,
                                        Target.getAddSym()->getSection());
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

  // ARM EHABI spells R_ARM_PREL31 as an FK_Data_4 carrying the `prel31`
  // specifier.  The generic fixup therefore does not advertise itself as
  // PC-relative even though the relocation is measured from the word being
  // written.  Object writers normally apply that relocation after assembly;
  // the rewrite backend resolves final VAs directly, so it must perform the
  // subtraction here before the wrapped ARM backend stores the word.
  const std::optional<uint32_t> Prel31Specifier =
      Asm->getContext().getAsmInfo().getSpecifierForName("prel31");
  const bool IsArmPrel31 = (TT.isARM() || TT.isThumb()) &&
                           Fixup.getKind() == FK_Data_4 && Prel31Specifier &&
                           Target.getSpecifier() == *Prel31Specifier;
  if (IsArmPrel31) {
    const uint64_t SecVA =
        mc_rewrite::sectionImageVA(*Asm, Opts, *F.getParent());
    const uint64_t FixupPC =
        SecVA + Asm->getFragmentOffset(F) + Fixup.getOffset();
    // AArch32 address arithmetic wraps modulo 2^32.  PREL31 can encode the
    // result exactly when bit 31 is the sign extension of bit 30.
    const uint32_t Delta =
        static_cast<uint32_t>(Value) - static_cast<uint32_t>(FixupPC);
    if (static_cast<bool>(Delta & uint32_t(1) << 31) !=
        static_cast<bool>(Delta & uint32_t(1) << 30)) {
      Asm->getContext().reportError(Fixup.getLoc(),
                                    "R_ARM_PREL31 target out of range");
      Value = 0;
      return true;
    }
    Value = Delta & 0x7fffffffu;
  } else if (Fixup.isPCRel()) {
    uint64_t SecVA = mc_rewrite::sectionImageVA(*Asm, Opts, *F.getParent());
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
    uint64_t SecVA = mc_rewrite::sectionImageVA(*Asm, Opts, *F.getParent());
    Ctx.FixupVA = SecVA + Asm->getFragmentOffset(F) + Fixup.getOffset();
    if (Target.getAddSym())
      Ctx.Sym = Target.getAddSym()->getName();
    Ctx.Specifier = Target.getSpecifier();
    Ctx.IsPCRel = Fixup.isPCRel();
    Ctx.BitWidth =
        Wrapped->getFixupKindInfo(static_cast<MCFixupKind>(Fixup.getKind()))
            .TargetSize;
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
          uint64_t SecVA =
              mc_rewrite::sectionImageVA(*Asm, Opts, *F.getParent());
          uint64_t PC = SecVA + Asm->getFragmentOffset(F) + Fixup.getOffset();
          uint64_t AlignedBase = (PC + 4) & ~uint64_t(3);
          int32_t Delta =
              static_cast<int32_t>(static_cast<int64_t>(*TargetVA) -
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
          uint16_t hw2 = 0xC000 | (J1Bit << 13) | (J2Bit << 11) | (imm10L << 1);

          Data[0] = hw1 & 0xFF;
          Data[1] = (hw1 >> 8) & 0xFF;
          Data[2] = hw2 & 0xFF;
          Data[3] = (hw2 >> 8) & 0xFF;
        }
      }
    }
  }
}

std::unique_ptr<MCAsmBackend> llvm::mc_rewrite::createAddressModelBackend(
    std::unique_ptr<MCAsmBackend> TargetBackend,
    const mc_rewrite::RewriteOptions &Opts) {
  return std::make_unique<AddressModelBackend>(std::move(TargetBackend), Opts);
}
