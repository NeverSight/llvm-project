//===-- MipsAsmBackend.cpp - Mips Asm Backend  ----------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the MipsAsmBackend class.
//
//===----------------------------------------------------------------------===//
//

#include "MCTargetDesc/MipsAsmBackend.h"
#include "MCTargetDesc/MipsABIInfo.h"
#include "MCTargetDesc/MipsBaseInfo.h"
#include "MCTargetDesc/MipsFixupKinds.h"
#include "MCTargetDesc/MipsMCTargetDesc.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/BinaryFormat/ELFRelocs/Mips.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCELFObjectWriter.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/MCSymbolELF.h"
#include "llvm/MC/MCTargetOptions.h"
#include "llvm/MC/MCValue.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/EndianStream.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

// Prepare value for the target space for it
static uint64_t adjustFixupValue(const MCFixup &Fixup, uint64_t Value,
                                 MCContext &Ctx) {

  unsigned Kind = Fixup.getKind();

  // Add/subtract and shift
  switch (Kind) {
  default:
    return 0;
  case FK_Data_2:
  case Mips::fixup_Mips16_LO16:
  case Mips::fixup_Mips16_GPREL:
  case Mips::fixup_Mips16_TLS_GOTTPREL:
  case Mips::fixup_Mips16_TLS_TPREL_LO16:
  case Mips::fixup_MICROMIPS_GPREL16:
  case Mips::fixup_Mips16_CALL16:
  case Mips::fixup_Mips_16:
  case Mips::fixup_Mips_LO16:
  case Mips::fixup_Mips_GPREL16:
  case Mips::fixup_Mips_GPOFF_HI:
  case Mips::fixup_Mips_GPOFF_LO:
  case Mips::fixup_Mips_GOT_PAGE:
  case Mips::fixup_Mips_GOT_OFST:
  case Mips::fixup_Mips_GOT_DISP:
  case Mips::fixup_Mips_GOT_LO16:
  case Mips::fixup_Mips_CALL_LO16:
  case Mips::fixup_MICROMIPS_GPOFF_HI:
  case Mips::fixup_MICROMIPS_GPOFF_LO:
  case Mips::fixup_MICROMIPS_LO16:
  case Mips::fixup_MICROMIPS_GOT_PAGE:
  case Mips::fixup_MICROMIPS_GOT_OFST:
  case Mips::fixup_MICROMIPS_GOT_DISP:
  case Mips::fixup_MIPS_PCLO16:
    Value &= 0xffff;
    break;
  case Mips::fixup_Mips_AnyImm16:
    if (!isInt<16>(Value) && !isUInt<16>(Value))
      Ctx.reportError(Fixup.getLoc(),
                      "fixup value out of range [-32768, 65535]");
    break;
  case Mips::fixup_Mips_GPREL32:
  case Mips::fixup_Mips_DTPREL32:
  case Mips::fixup_Mips_DTPREL64:
  case Mips::fixup_Mips_TPREL32:
  case Mips::fixup_Mips_TPREL64:
  case FK_Data_4:
  case FK_Data_8:
  case Mips::fixup_Mips_32:
  case Mips::fixup_Mips_64:
  case Mips::fixup_Mips_SUB:
  case Mips::fixup_MICROMIPS_SUB:
    break;
  case Mips::fixup_Mips_PC16:
    // The displacement is then divided by 4 to give us an 18 bit
    // address range. Forcing a signed division because Value can be negative.
    Value = (int64_t)Value / 4;
    // We now check if Value can be encoded as a 16-bit signed immediate.
    if (!isInt<16>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC16 fixup");
      return 0;
    }
    break;
  case Mips::fixup_Mips16_LWPC8:
  case Mips::fixup_Mips16_LWPC16: {
    bool Compact = Kind == Mips::fixup_Mips16_LWPC8;
    if ((Value & 3) || (Compact ? !isUInt<10>(Value) : !isInt<16>(Value))) {
      Ctx.reportError(Fixup.getLoc(),
                      "invalid MIPS16 literal pool displacement");
      return 0;
    }
    return Compact ? Value >> 2 : Value & 0xffff;
  }
  case Mips::fixup_Mips16_PC8_S1:
  case Mips::fixup_Mips16_PC11_S1:
  case Mips::fixup_Mips16_PC16_S1: {
    unsigned Bits = Kind == Mips::fixup_Mips16_PC8_S1    ? 8
                    : Kind == Mips::fixup_Mips16_PC11_S1 ? 11
                                                         : 16;
    if ((Value & 1) || !isIntN(Bits + 1, Value)) {
      Ctx.reportError(Fixup.getLoc(), "invalid MIPS16 branch displacement");
      return 0;
    }
    return (Value >> 1) & maskTrailingOnes<uint64_t>(Bits);
  }
  case Mips::fixup_MIPS_PC19_S2:
  case Mips::fixup_MICROMIPS_PC19_S2:
    // Forcing a signed division because Value can be negative.
    Value = (int64_t)Value / 4;
    // We now check if Value can be encoded as a 19-bit signed immediate.
    if (!isInt<19>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC19 fixup");
      return 0;
    }
    break;
  case Mips::fixup_Mips16_26:
  case Mips::fixup_Mips_26:
    // So far we are only using this type for jumps.
    // The displacement is then divided by 4 to give us an 28 bit
    // address range.
    Value >>= 2;
    break;
  case Mips::fixup_Mips16_HI16:
  case Mips::fixup_Mips16_TLS_TPREL_HI16:
  case Mips::fixup_Mips16_GOT16:
  case Mips::fixup_Mips_HI16:
  case Mips::fixup_Mips_GOT:
  case Mips::fixup_MICROMIPS_GOT16:
  case Mips::fixup_Mips_GOT_HI16:
  case Mips::fixup_Mips_CALL_HI16:
  case Mips::fixup_MICROMIPS_HI16:
  case Mips::fixup_MIPS_PCHI16:
    // Get the 2nd 16-bits. Also add 1 if bit 15 is 1.
    Value = ((Value + 0x8000) >> 16) & 0xffff;
    break;
  case Mips::fixup_Mips_HIGHER:
  case Mips::fixup_MICROMIPS_HIGHER:
    // Get the 3rd 16-bits.
    Value = ((Value + 0x80008000LL) >> 32) & 0xffff;
    break;
  case Mips::fixup_Mips_HIGHEST:
  case Mips::fixup_MICROMIPS_HIGHEST:
    // Get the 4th 16-bits.
    Value = ((Value + 0x800080008000LL) >> 48) & 0xffff;
    break;
  case Mips::fixup_MICROMIPS_26_S1:
    Value >>= 1;
    break;
  case Mips::fixup_MICROMIPS_PC7_S1:
    Value -= 4;
    // Forcing a signed division because Value can be negative.
    Value = (int64_t) Value / 2;
    // We now check if Value can be encoded as a 7-bit signed immediate.
    if (!isInt<7>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC7 fixup");
      return 0;
    }
    break;
  case Mips::fixup_MICROMIPS_PC10_S1:
    Value -= 2;
    // Forcing a signed division because Value can be negative.
    Value = (int64_t) Value / 2;
    // We now check if Value can be encoded as a 10-bit signed immediate.
    if (!isInt<10>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC10 fixup");
      return 0;
    }
    break;
  case Mips::fixup_MICROMIPS_PC16_S1:
    Value -= 4;
    // Forcing a signed division because Value can be negative.
    Value = (int64_t)Value / 2;
    // We now check if Value can be encoded as a 16-bit signed immediate.
    if (!isInt<16>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC16 fixup");
      return 0;
    }
    break;
  case Mips::fixup_MIPS_PC18_S3:
    // Forcing a signed division because Value can be negative.
    Value = (int64_t)Value / 8;
    // We now check if Value can be encoded as a 18-bit signed immediate.
    if (!isInt<18>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC18 fixup");
      return 0;
    }
    break;
  case Mips::fixup_MICROMIPS_PC18_S3:
    // Check alignment.
    if ((Value & 7)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC18 fixup");
    }
    // Forcing a signed division because Value can be negative.
    Value = (int64_t)Value / 8;
    // We now check if Value can be encoded as a 18-bit signed immediate.
    if (!isInt<18>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC18 fixup");
      return 0;
    }
    break;
  case Mips::fixup_MIPS_PC21_S2:
    // Forcing a signed division because Value can be negative.
    Value = (int64_t) Value / 4;
    // We now check if Value can be encoded as a 21-bit signed immediate.
    if (!isInt<21>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC21 fixup");
      return 0;
    }
    break;
  case Mips::fixup_MIPS_PC26_S2:
    // Forcing a signed division because Value can be negative.
    Value = (int64_t) Value / 4;
    // We now check if Value can be encoded as a 26-bit signed immediate.
    if (!isInt<26>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC26 fixup");
      return 0;
    }
    break;
  case Mips::fixup_MICROMIPS_PC26_S1:
    // Forcing a signed division because Value can be negative.
    Value = (int64_t)Value / 2;
    // We now check if Value can be encoded as a 26-bit signed immediate.
    if (!isInt<26>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC26 fixup");
      return 0;
    }
    break;
  case Mips::fixup_MICROMIPS_PC21_S1:
    // Forcing a signed division because Value can be negative.
    Value = (int64_t)Value / 2;
    // We now check if Value can be encoded as a 21-bit signed immediate.
    if (!isInt<21>(Value)) {
      Ctx.reportError(Fixup.getLoc(), "out of range PC21 fixup");
      return 0;
    }
    break;
  }

  return Value;
}

std::unique_ptr<MCObjectTargetWriter>
MipsAsmBackend::createObjectTargetWriter() const {
  return createMipsELFObjectWriter(TheTriple, IsN32);
}

// Little-endian fixup data byte ordering:
//   mips32r2:   a | b | x | x
//   microMIPS:  x | x | a | b

static bool needsMMLEByteOrder(unsigned Kind) {
  return Kind == Mips::fixup_Mips16_26 ||
         (Kind != Mips::fixup_MICROMIPS_PC10_S1 &&
          Kind >= Mips::fixup_MICROMIPS_26_S1 &&
          Kind < Mips::LastTargetFixupKind);
}

// Calculate index for microMIPS specific little endian byte order
static unsigned calculateMMLEIndex(unsigned i) {
  assert(i <= 3 && "Index out of range!");

  return (1 - i / 2) * 2 + i % 2;
}

static bool shouldForceRelocation(const MCFixup &Fixup) {
  const unsigned FixupKind = Fixup.getKind();
  switch (FixupKind) {
  default:
    return false;
  case Mips::fixup_Mips16_CALL16:
  case Mips::fixup_Mips16_GOT16:
  // All these relocations require special processing
  // at linking time. Delegate this work to a linker.
  case Mips::fixup_Mips_CALL_HI16:
  case Mips::fixup_Mips_CALL_LO16:
  case Mips::fixup_Mips_CALL16:
  case Mips::fixup_Mips_GOT:
  case Mips::fixup_Mips_GOT_PAGE:
  case Mips::fixup_Mips_GOT_OFST:
  case Mips::fixup_Mips_GOT_DISP:
  case Mips::fixup_Mips_GOT_HI16:
  case Mips::fixup_Mips_GOT_LO16:
  case Mips::fixup_Mips16_TLS_GOTTPREL:
  case Mips::fixup_Mips16_TLS_TPREL_HI16:
  case Mips::fixup_Mips16_TLS_TPREL_LO16:
  case Mips::fixup_Mips_GOTTPREL:
  case Mips::fixup_Mips_DTPREL_HI:
  case Mips::fixup_Mips_DTPREL_LO:
  case Mips::fixup_Mips_TLSGD:
  case Mips::fixup_Mips_TLSLDM:
  case Mips::fixup_Mips_TPREL_HI:
  case Mips::fixup_Mips_TPREL_LO:
  case Mips::fixup_Mips_JALR:
  case Mips::fixup_MICROMIPS_CALL16:
  case Mips::fixup_MICROMIPS_GOT_DISP:
  case Mips::fixup_MICROMIPS_GOT_PAGE:
  case Mips::fixup_MICROMIPS_GOT_OFST:
  case Mips::fixup_MICROMIPS_GOT16:
  case Mips::fixup_MICROMIPS_GOTTPREL:
  case Mips::fixup_MICROMIPS_TLS_DTPREL_HI16:
  case Mips::fixup_MICROMIPS_TLS_DTPREL_LO16:
  case Mips::fixup_MICROMIPS_TLS_GD:
  case Mips::fixup_MICROMIPS_TLS_LDM:
  case Mips::fixup_MICROMIPS_TLS_TPREL_HI16:
  case Mips::fixup_MICROMIPS_TLS_TPREL_LO16:
  case Mips::fixup_MICROMIPS_JALR:
    return true;
  }
}

// The ELF linker folds the ISA mode into a compressed code address before
// adding the relocation addend. A resolved final-image fixup has no linker.
static bool materializesMipsAddress(MCFixupKind Kind) {
  switch ((unsigned)Kind) {
  case FK_Data_4:
  case FK_Data_8:
  case Mips::fixup_Mips_32:
  case Mips::fixup_Mips_64:
  case Mips::fixup_Mips16_HI16:
  case Mips::fixup_Mips16_LO16:
  case Mips::fixup_Mips_HI16:
  case Mips::fixup_Mips_LO16:
  case Mips::fixup_Mips_HIGHER:
  case Mips::fixup_Mips_HIGHEST:
  case Mips::fixup_MICROMIPS_HI16:
  case Mips::fixup_MICROMIPS_LO16:
  case Mips::fixup_MICROMIPS_HIGHER:
  case Mips::fixup_MICROMIPS_HIGHEST:
    return true;
  default:
    return false;
  }
}

// A locally defined compressed symbol has an even section offset and an ELF
// mode tag. An external resolver returns the callable address with bit zero
// set.
static unsigned compressedMode(const MCSymbolELF &Symbol) {
  unsigned Other = Symbol.getOther();
  if ((Other & ELF::STO_MIPS_MIPS16) == ELF::STO_MIPS_MIPS16)
    return ELF::STO_MIPS_MIPS16;
  return Other & ELF::STO_MIPS_MICROMIPS;
}

static bool isPseudoDirectJump(MCFixupKind Kind) {
  return Kind == Mips::fixup_Mips_26 || Kind == Mips::fixup_Mips16_26 ||
         Kind == Mips::fixup_MICROMIPS_26_S1;
}

static unsigned branchTargetAlignment(MCFixupKind Kind) {
  switch (static_cast<unsigned>(Kind)) {
  case Mips::fixup_Mips_PC16:
  case Mips::fixup_MIPS_PC21_S2:
  case Mips::fixup_MIPS_PC26_S2:
    return 4;
  case Mips::fixup_MICROMIPS_PC7_S1:
  case Mips::fixup_MICROMIPS_PC10_S1:
  case Mips::fixup_MICROMIPS_PC16_S1:
  case Mips::fixup_MICROMIPS_PC21_S1:
  case Mips::fixup_MICROMIPS_PC26_S1:
  case Mips::fixup_Mips16_PC8_S1:
  case Mips::fixup_Mips16_PC11_S1:
  case Mips::fixup_Mips16_PC16_S1:
    return 2;
  default:
    return 0;
  }
}

bool MipsAsmBackend::mayNeedRelaxation(unsigned Opcode,
                                       ArrayRef<MCOperand> Operands,
                                       const MCSubtargetInfo &) const {
  return MipsII::getMips16ExtendedBranchOpcode(Opcode) != Opcode &&
         Operands.back().isExpr();
}

bool MipsAsmBackend::fixupNeedsRelaxationAdvanced(const MCFragment &,
                                                  const MCFixup &Fixup,
                                                  const MCValue &,
                                                  uint64_t Value,
                                                  bool Resolved) const {
  switch (static_cast<unsigned>(Fixup.getKind())) {
  case Mips::fixup_Mips16_PC8_S1:
    return !Resolved || !isInt<9>(Value);
  case Mips::fixup_Mips16_PC11_S1:
    return !Resolved || !isInt<12>(Value);
  default:
    return false;
  }
}

void MipsAsmBackend::relaxInstruction(MCInst &Inst,
                                      const MCSubtargetInfo &) const {
  Inst.setOpcode(MipsII::getMips16ExtendedBranchOpcode(Inst.getOpcode()));
}

static bool needsGPOrTLSBase(MCFixupKind Kind) {
  switch (static_cast<unsigned>(Kind)) {
  case Mips::fixup_Mips16_GPREL:
  case Mips::fixup_MICROMIPS_GPREL16:
  case Mips::fixup_Mips_GPREL16:
  case Mips::fixup_Mips_GPREL32:
  case Mips::fixup_Mips_LITERAL:
  case Mips::fixup_Mips_GPOFF_HI:
  case Mips::fixup_Mips_GPOFF_LO:
  case Mips::fixup_MICROMIPS_GPOFF_HI:
  case Mips::fixup_MICROMIPS_GPOFF_LO:
  case Mips::fixup_Mips_DTPREL32:
  case Mips::fixup_Mips_DTPREL64:
  case Mips::fixup_Mips_TPREL32:
  case Mips::fixup_Mips_TPREL64:
    return true;
  default:
    return false;
  }
}

// The jump instruction concatenates high bits of PC+4 with its immediate.
// JALX exchanges ISA mode and, for microMIPS, also changes the target scale.
static void applyFinalJump(MCContext &Ctx, endianness Endian,
                           const MCFixup &Fixup, const MCValue &Target,
                           uint8_t *Data, uint64_t Value, uint64_t NextPC,
                           const MCSubtargetInfo *STI) {
  const bool Micro = Fixup.getKind() == Mips::fixup_MICROMIPS_26_S1;
  const bool Mips16 = Fixup.getKind() == Mips::fixup_Mips16_26;
  unsigned Mode = 0;
  if (const auto *Sym = Target.getAddSym(); Sym && Sym->isInSection()) {
    Mode = compressedMode(*static_cast<const MCSymbolELF *>(Sym));
  } else if ((Value - Target.getConstant()) & 1) {
    // The external pointer distinguishes classic from compressed; direct calls
    // between MIPS16 and microMIPS require a linker stub.
    Mode = Mips16 ? ELF::STO_MIPS_MIPS16 : ELF::STO_MIPS_MICROMIPS;
    --Value;
  }
  if ((Micro && Mode == ELF::STO_MIPS_MIPS16) ||
      (Mips16 && Mode == ELF::STO_MIPS_MICROMIPS)) {
    Ctx.reportError(Fixup.getLoc(), "direct call between MIPS16 and microMIPS");
    return;
  }
  bool Exchange = bool(Mode) != (Micro || Mips16);
  if (Exchange && STI && STI->hasFeature(Mips::FeatureMips32r6)) {
    Ctx.reportError(Fixup.getLoc(),
                    "MIPS Release 6 direct jump cannot change ISA mode");
    return;
  }
  unsigned Scale = Micro && !Exchange ? 1 : 2;
  if ((Value & ((1u << Scale) - 1)) || ((Value ^ NextPC) >> (26 + Scale))) {
    Ctx.reportError(Fixup.getLoc(),
                    "MIPS jump target is misaligned or outside the PC region");
    return;
  }
  uint32_t Field = (Value >> Scale) & 0x03ffffff;
  if (Mips16) {
    Field = ELF::encodeMips16JumpField(Field);
    support::endian::write16(Data, (Exchange ? 0x1c00 : 0x1800) | (Field >> 16),
                             Endian);
    support::endian::write16(Data + 2, Field, Endian);
    return;
  }
  unsigned Opcode = Micro ? support::endian::read16(Data, Endian) >> 10
                          : support::endian::read32(Data, Endian) >> 26;
  const unsigned Jal = Micro ? 0x3d : 0x03, Jalx = Micro ? 0x3c : 0x1d;
  if (Opcode == Jal || Opcode == Jalx)
    Opcode = Exchange ? Jalx : Jal;
  else if (Exchange) {
    Ctx.reportError(Fixup.getLoc(),
                    "MIPS jump requires a linker stub to exchange ISA mode");
    return;
  }
  const uint32_t Word = (uint32_t(Opcode) << 26) | Field;
  if (Micro) {
    support::endian::write16(Data, Word >> 16, Endian);
    support::endian::write16(Data + 2, Word, Endian);
  } else
    support::endian::write32(Data, Word, Endian);
}

/// ApplyFixup - Apply the \p Value for given \p Fixup into the provided
/// data fragment, at the offset specified by the fixup and following the
/// fixup kind as appropriate.
void MipsAsmBackend::applyFixup(const MCFragment &F, const MCFixup &Fixup,
                                const MCValue &Target, uint8_t *Data,
                                uint64_t Value, bool IsResolved) {
  MCFixupKind Kind = Fixup.getKind();
  bool ForceRelocation = shouldForceRelocation(Fixup);
  if ((ForceRelocation || needsGPOrTLSBase(Kind)) &&
      TheTriple.isOSBinFormatELF() &&
      !dynamic_cast<ELFObjectWriter *>(&Asm->getWriter())) {
    getContext().reportError(
        Fixup.getLoc(), Twine("MIPS final image requires an ELF linker for ") +
                            getFixupKindInfo(Kind).Name);
    return;
  }
  if (ForceRelocation)
    IsResolved = false;
  if (TheTriple.isOSBinFormatELF() && IsResolved && isPseudoDirectJump(Kind)) {
    if (auto PC = Asm->getWriter().getFinalFixupVA(F, Fixup)) {
      uint64_t NextPC = *PC + 4;
      if (TheTriple.isArch32Bit())
        NextPC = static_cast<uint32_t>(NextPC);
      applyFinalJump(getContext(), Endian, Fixup, Target, Data, Value, NextPC,
                     getSubtargetInfo(F));
      return;
    }
  }
  if (unsigned Align = branchTargetAlignment(Kind);
      Align && TheTriple.isOSBinFormatELF() && IsResolved &&
      !Target.getSubSym()) {
    const bool Mips16 =
        Kind >= Mips::fixup_Mips16_PC8_S1 && Kind <= Mips::fixup_Mips16_PC16_S1;
    const unsigned CompressedMode =
        Mips16 ? ELF::STO_MIPS_MIPS16 : ELF::STO_MIPS_MICROMIPS;
    const unsigned Mode = Align == 2 ? CompressedMode : 0;
    if (const auto *Sym =
            static_cast<const MCSymbolELF *>(Target.getAddSym())) {
      unsigned TargetMode = Mode;
      if (Sym->isUndefined() && Asm->getWriter().getFinalFixupVA(F, Fixup)) {
        // External resolutions return callable pointers. Drop the ISA tag
        // before scaling the signed PC-relative displacement.
        bool Tagged = (Value - Target.getConstant()) & 1;
        TargetMode = Tagged ? CompressedMode : 0;
        Value -= Tagged;
      } else if (Sym->isInSection() && Sym->getType() == ELF::STT_FUNC) {
        TargetMode = compressedMode(*Sym);
      }
      if (Mode != TargetMode) {
        getContext().reportError(Fixup.getLoc(),
                                 "MIPS branch cannot change ISA mode");
        return;
      }
    }
    if (Value & (Align - 1)) {
      getContext().reportError(Fixup.getLoc(), "misaligned MIPS branch target");
      return;
    }
  }
  if (TheTriple.isOSBinFormatELF() && IsResolved && !Fixup.isPCRel() &&
      !Target.getSubSym() && materializesMipsAddress(Kind))
    if (const auto *Symbol = Target.getAddSym();
        Symbol && Symbol->isInSection())
      if (compressedMode(*static_cast<const MCSymbolELF *>(Symbol)))
        ++Value;
  if (Kind == Mips::fixup_Mips16_LWPC8 || Kind == Mips::fixup_Mips16_LWPC16) {
    // The constant-island pass places its word in this section. There is no
    // MIPS16 ELF relocation for a literal load from an unknown address.
    if (!IsResolved) {
      getContext().reportError(Fixup.getLoc(),
                               "unresolved MIPS16 literal pool");
      return;
    }
    // MC subtracted the instruction address. LWPC instead uses that address
    // rounded down to a word boundary, including the EXTEND halfword.
    auto PC = Asm->getWriter().getFinalFixupVA(F, Fixup);
    Value += PC.value_or(Asm->getFragmentOffset(F) + Fixup.getOffset()) & 3;
  }
  maybeAddReloc(F, Fixup, Target, Value, IsResolved);
  MCContext &Ctx = getContext();
  // O32 REL stores JAL's word addend in linear order. The final encoding
  // swaps the two five-bit fields and uses JALX for a classic callee.
  if (IsResolved && Kind == Mips::fixup_Mips16_26) {
    const MCSymbol *Symbol = Target.getAddSym();
    unsigned Mode =
        Symbol && Symbol->isInSection()
            ? compressedMode(*static_cast<const MCSymbolELF *>(Symbol))
            : ((Value & 1) ? ELF::STO_MIPS_MIPS16 : 0);
    if (Mode == ELF::STO_MIPS_MICROMIPS || (Value & 2)) {
      Ctx.reportError(Fixup.getLoc(), "invalid target for MIPS16 JAL");
      return;
    }
    if (!Mode)
      Data[Endian == llvm::endianness::little ? 1 : 0] |= 4;
    uint32_t Word = (Value >> 2) & 0x03ffffff;
    Value = ELF::encodeMips16JumpField(Word);
  } else if (Kind == Mips::fixup_MICROMIPS_26_S1 &&
             (support::endian::read16(Data, Endian) >> 10) == 0x3c) {
    // The microMIPS JALX REL addend is word-scaled even though it uses
    // R_MICROMIPS_26_S1 like JAL.
    Value >>= 2;
  } else
    Value = adjustFixupValue(Fixup, Value, Ctx);

  if (!Value)
    return; // Doesn't change encoding.

  if ((Kind >= Mips::fixup_Mips16_HI16 &&
       Kind <= Mips::fixup_Mips16_TLS_TPREL_LO16) ||
      Kind == Mips::fixup_Mips16_PC16_S1 || Kind == Mips::fixup_Mips16_LWPC16) {
    uint32_t Field = ELF::encodeMips16Imm16(Value);
    uint16_t Ext = support::endian::read16(Data, Endian);
    uint16_t Op = support::endian::read16(Data + 2, Endian);
    support::endian::write16(Data, Ext | (Field >> 16), Endian);
    support::endian::write16(Data + 2, Op | uint16_t(Field), Endian);
    return;
  }

  // Where do we start in the object
  // Number of bytes we need to fixup
  unsigned NumBytes = (getFixupKindInfo(Kind).TargetSize + 7) / 8;
  // Used to point to big endian bytes
  unsigned FullSize;

  switch ((unsigned)Kind) {
  case FK_Data_2:
  case Mips::fixup_Mips_16:
  case Mips::fixup_Mips16_PC8_S1:
  case Mips::fixup_Mips16_PC11_S1:
  case Mips::fixup_Mips16_LWPC8:
  case Mips::fixup_MICROMIPS_PC10_S1:
    FullSize = 2;
    break;
  case FK_Data_8:
  case Mips::fixup_Mips_64:
    FullSize = 8;
    break;
  case FK_Data_4:
  default:
    FullSize = 4;
    break;
  }

  // Grab current value, if any, from bits.
  uint64_t CurVal = 0;

  bool microMipsLEByteOrder = needsMMLEByteOrder((unsigned) Kind);

  for (unsigned i = 0; i != NumBytes; ++i) {
    unsigned Idx = Endian == llvm::endianness::little
                       ? (microMipsLEByteOrder ? calculateMMLEIndex(i) : i)
                       : (FullSize - 1 - i);
    CurVal |= (uint64_t)((uint8_t)Data[Idx]) << (i * 8);
  }

  uint64_t Mask = ((uint64_t)(-1) >>
                    (64 - getFixupKindInfo(Kind).TargetSize));
  CurVal |= Value & Mask;

  // Write out the fixed up bytes back to the code/data bits.
  for (unsigned i = 0; i != NumBytes; ++i) {
    unsigned Idx = Endian == llvm::endianness::little
                       ? (microMipsLEByteOrder ? calculateMMLEIndex(i) : i)
                       : (FullSize - 1 - i);
    Data[Idx] = (uint8_t)((CurVal >> (i * 8)) & 0xff);
  }
}

std::optional<MCFixupKind> MipsAsmBackend::getFixupKind(StringRef Name) const {
  unsigned Type = llvm::StringSwitch<unsigned>(Name)
                      .Case("BFD_RELOC_NONE", ELF::R_MIPS_NONE)
                      .Case("BFD_RELOC_16", ELF::R_MIPS_16)
                      .Case("BFD_RELOC_32", ELF::R_MIPS_32)
                      .Case("BFD_RELOC_64", ELF::R_MIPS_64)
                      .Default(-1u);
  if (Type != -1u)
    return static_cast<MCFixupKind>(FirstLiteralRelocationKind + Type);

  return StringSwitch<std::optional<MCFixupKind>>(Name)
      .Case("R_MIPS_NONE", FK_NONE)
      .Case("R_MIPS_32", FK_Data_4)
      .Case("R_MIPS_CALL_HI16", Mips::fixup_Mips_CALL_HI16)
      .Case("R_MIPS_CALL_LO16", Mips::fixup_Mips_CALL_LO16)
      .Case("R_MIPS_CALL16", Mips::fixup_Mips_CALL16)
      .Case("R_MIPS_GOT16", Mips::fixup_Mips_GOT)
      .Case("R_MIPS_GOT_PAGE", Mips::fixup_Mips_GOT_PAGE)
      .Case("R_MIPS_GOT_OFST", Mips::fixup_Mips_GOT_OFST)
      .Case("R_MIPS_GOT_DISP", Mips::fixup_Mips_GOT_DISP)
      .Case("R_MIPS_GOT_HI16", Mips::fixup_Mips_GOT_HI16)
      .Case("R_MIPS_GOT_LO16", Mips::fixup_Mips_GOT_LO16)
      .Case("R_MIPS_TLS_GOTTPREL", Mips::fixup_Mips_GOTTPREL)
      .Case("R_MIPS_TLS_DTPREL_HI16", Mips::fixup_Mips_DTPREL_HI)
      .Case("R_MIPS_TLS_DTPREL_LO16", Mips::fixup_Mips_DTPREL_LO)
      .Case("R_MIPS_TLS_GD", Mips::fixup_Mips_TLSGD)
      .Case("R_MIPS_TLS_LDM", Mips::fixup_Mips_TLSLDM)
      .Case("R_MIPS_TLS_TPREL_HI16", Mips::fixup_Mips_TPREL_HI)
      .Case("R_MIPS_TLS_TPREL_LO16", Mips::fixup_Mips_TPREL_LO)
      .Case("R_MICROMIPS_CALL16", Mips::fixup_MICROMIPS_CALL16)
      .Case("R_MICROMIPS_GOT_DISP", Mips::fixup_MICROMIPS_GOT_DISP)
      .Case("R_MICROMIPS_GOT_PAGE", Mips::fixup_MICROMIPS_GOT_PAGE)
      .Case("R_MICROMIPS_GOT_OFST", Mips::fixup_MICROMIPS_GOT_OFST)
      .Case("R_MICROMIPS_GOT16", Mips::fixup_MICROMIPS_GOT16)
      .Case("R_MICROMIPS_TLS_GOTTPREL", Mips::fixup_MICROMIPS_GOTTPREL)
      .Case("R_MICROMIPS_TLS_DTPREL_HI16",
            Mips::fixup_MICROMIPS_TLS_DTPREL_HI16)
      .Case("R_MICROMIPS_TLS_DTPREL_LO16",
            Mips::fixup_MICROMIPS_TLS_DTPREL_LO16)
      .Case("R_MICROMIPS_TLS_GD", Mips::fixup_MICROMIPS_TLS_GD)
      .Case("R_MICROMIPS_TLS_LDM", Mips::fixup_MICROMIPS_TLS_LDM)
      .Case("R_MICROMIPS_TLS_TPREL_HI16", Mips::fixup_MICROMIPS_TLS_TPREL_HI16)
      .Case("R_MICROMIPS_TLS_TPREL_LO16", Mips::fixup_MICROMIPS_TLS_TPREL_LO16)
      .Case("R_MIPS_JALR", Mips::fixup_Mips_JALR)
      .Case("R_MICROMIPS_JALR", Mips::fixup_MICROMIPS_JALR)
      .Default(MCAsmBackend::getFixupKind(Name));
}

MCFixupKindInfo MipsAsmBackend::getFixupKindInfo(MCFixupKind Kind) const {
  const static MCFixupKindInfo LittleEndianInfos[] = {
      // This table *must* be in same the order of fixup_* kinds in
      // MipsFixupKinds.h.
      //
      // name                    offset  bits  flags
      // clang-format off
    { "fixup_Mips_16",           0,     16,   0 },
    { "fixup_Mips_32",           0,     32,   0 },
    { "fixup_Mips_REL32",        0,     32,   0 },
    { "fixup_Mips_GPREL32",      0,     32,   0 },
    { "fixup_Mips_DTPREL32",     0,     32,   0 },
    { "fixup_Mips_DTPREL64",     0,     64,   0 },
    { "fixup_Mips_TPREL32",      0,     32,   0 },
    { "fixup_Mips_TPREL64",      0,     64,   0 },
    { "fixup_Mips_26",           0,     26,   0 },
    { "fixup_Mips16_26",         0,     26,   0 },
    { "fixup_Mips16_HI16", 0, 16, 0 },
    { "fixup_Mips16_LO16", 0, 16, 0 },
    { "fixup_Mips16_GOT16", 0, 16, 0 },
    { "fixup_Mips16_CALL16", 0, 16, 0 },
    { "fixup_Mips16_GPREL", 0, 16, 0 },
    { "fixup_Mips16_TLS_GOTTPREL", 0, 16, 0 },
    { "fixup_Mips16_TLS_TPREL_HI16", 0, 16, 0 },
    { "fixup_Mips16_TLS_TPREL_LO16", 0, 16, 0 },
    { "fixup_Mips16_PC8_S1",     0,      8,   0 },
    { "fixup_Mips16_PC11_S1",    0,     11,   0 },
    { "fixup_Mips16_PC16_S1",    0,     16,   0 },
    { "fixup_Mips16_LWPC8",      0,      8,   0 },
    { "fixup_Mips16_LWPC16",     0,     16,   0 },
    { "fixup_Mips_HI16",         0,     16,   0 },
    { "fixup_Mips_LO16",         0,     16,   0 },
    { "fixup_Mips_AnyImm16",     0,     16,   0 },
    { "fixup_Mips_GPREL16",      0,     16,   0 },
    { "fixup_Mips_LITERAL",      0,     16,   0 },
    { "fixup_Mips_GOT",          0,     16,   0 },
    { "fixup_Mips_PC16",         0,     16,   0 },
    { "fixup_Mips_CALL16",       0,     16,   0 },
    { "fixup_Mips_SHIFT5",       6,      5,   0 },
    { "fixup_Mips_SHIFT6",       6,      5,   0 },
    { "fixup_Mips_64",           0,     64,   0 },
    { "fixup_Mips_TLSGD",        0,     16,   0 },
    { "fixup_Mips_GOTTPREL",     0,     16,   0 },
    { "fixup_Mips_TPREL_HI",     0,     16,   0 },
    { "fixup_Mips_TPREL_LO",     0,     16,   0 },
    { "fixup_Mips_TLSLDM",       0,     16,   0 },
    { "fixup_Mips_DTPREL_HI",    0,     16,   0 },
    { "fixup_Mips_DTPREL_LO",    0,     16,   0 },
    { "fixup_Mips_Branch_PCRel", 0,     16,   0 },
    { "fixup_Mips_GPOFF_HI",     0,     16,   0 },
    { "fixup_MICROMIPS_GPOFF_HI",0,     16,   0 },
    { "fixup_Mips_GPOFF_LO",     0,     16,   0 },
    { "fixup_MICROMIPS_GPOFF_LO",0,     16,   0 },
    { "fixup_Mips_GOT_PAGE",     0,     16,   0 },
    { "fixup_Mips_GOT_OFST",     0,     16,   0 },
    { "fixup_Mips_GOT_DISP",     0,     16,   0 },
    { "fixup_Mips_HIGHER",       0,     16,   0 },
    { "fixup_MICROMIPS_HIGHER",  0,     16,   0 },
    { "fixup_Mips_HIGHEST",      0,     16,   0 },
    { "fixup_MICROMIPS_HIGHEST", 0,     16,   0 },
    { "fixup_Mips_GOT_HI16",     0,     16,   0 },
    { "fixup_Mips_GOT_LO16",     0,     16,   0 },
    { "fixup_Mips_CALL_HI16",    0,     16,   0 },
    { "fixup_Mips_CALL_LO16",    0,     16,   0 },
    { "fixup_Mips_PC18_S3",      0,     18,   0 },
    { "fixup_MIPS_PC19_S2",      0,     19,   0 },
    { "fixup_MIPS_PC21_S2",      0,     21,   0 },
    { "fixup_MIPS_PC26_S2",      0,     26,   0 },
    { "fixup_MIPS_PCHI16",       0,     16,   0 },
    { "fixup_MIPS_PCLO16",       0,     16,   0 },
    { "fixup_MICROMIPS_26_S1",   0,     26,   0 },
    { "fixup_MICROMIPS_HI16",    0,     16,   0 },
    { "fixup_MICROMIPS_LO16",    0,     16,   0 },
    { "fixup_MICROMIPS_GPREL16",  0,     16,   0 },
    { "fixup_MICROMIPS_GOT16",   0,     16,   0 },
    { "fixup_MICROMIPS_PC7_S1",  0,      7,   0 },
    { "fixup_MICROMIPS_PC10_S1", 0,     10,   0 },
    { "fixup_MICROMIPS_PC16_S1", 0,     16,   0 },
    { "fixup_MICROMIPS_PC26_S1", 0,     26,   0 },
    { "fixup_MICROMIPS_PC19_S2", 0,     19,   0 },
    { "fixup_MICROMIPS_PC18_S3", 0,     18,   0 },
    { "fixup_MICROMIPS_PC21_S1", 0,     21,   0 },
    { "fixup_MICROMIPS_CALL16",  0,     16,   0 },
    { "fixup_MICROMIPS_GOT_DISP",        0,     16,   0 },
    { "fixup_MICROMIPS_GOT_PAGE",        0,     16,   0 },
    { "fixup_MICROMIPS_GOT_OFST",        0,     16,   0 },
    { "fixup_MICROMIPS_TLS_GD",          0,     16,   0 },
    { "fixup_MICROMIPS_TLS_LDM",         0,     16,   0 },
    { "fixup_MICROMIPS_TLS_DTPREL_HI16", 0,     16,   0 },
    { "fixup_MICROMIPS_TLS_DTPREL_LO16", 0,     16,   0 },
    { "fixup_MICROMIPS_GOTTPREL",        0,     16,   0 },
    { "fixup_MICROMIPS_TLS_TPREL_HI16",  0,     16,   0 },
    { "fixup_MICROMIPS_TLS_TPREL_LO16",  0,     16,   0 },
    { "fixup_Mips_SUB",                  0,     64,   0 },
    { "fixup_MICROMIPS_SUB",             0,     64,   0 },
    { "fixup_Mips_JALR",                 0,     32,   0 },
    { "fixup_MICROMIPS_JALR",            0,     32,   0 },
      // clang-format on
  };
  static_assert(std::size(LittleEndianInfos) == Mips::NumTargetFixupKinds,
                "Not all MIPS little endian fixup kinds added!");

  const static MCFixupKindInfo BigEndianInfos[] = {
      // This table *must* be in same the order of fixup_* kinds in
      // MipsFixupKinds.h.
      //
      // name                    offset  bits  flags
      // clang-format off
    { "fixup_Mips_16",          16,     16,   0 },
    { "fixup_Mips_32",           0,     32,   0 },
    { "fixup_Mips_REL32",        0,     32,   0 },
    { "fixup_Mips_GPREL32",      0,     32,   0 },
    { "fixup_Mips_DTPREL32",     0,     32,   0 },
    { "fixup_Mips_DTPREL64",     0,     64,   0 },
    { "fixup_Mips_TPREL32",      0,     32,   0 },
    { "fixup_Mips_TPREL64",      0,     64,   0 },
    { "fixup_Mips_26",           6,     26,   0 },
    { "fixup_Mips16_26",         6,     26,   0 },
    { "fixup_Mips16_HI16", 0, 16, 0 },
    { "fixup_Mips16_LO16", 0, 16, 0 },
    { "fixup_Mips16_GOT16", 0, 16, 0 },
    { "fixup_Mips16_CALL16", 0, 16, 0 },
    { "fixup_Mips16_GPREL", 0, 16, 0 },
    { "fixup_Mips16_TLS_GOTTPREL", 0, 16, 0 },
    { "fixup_Mips16_TLS_TPREL_HI16", 0, 16, 0 },
    { "fixup_Mips16_TLS_TPREL_LO16", 0, 16, 0 },
    { "fixup_Mips16_PC8_S1",     8,      8,   0 },
    { "fixup_Mips16_PC11_S1",    5,     11,   0 },
    { "fixup_Mips16_PC16_S1",    0,     16,   0 },
    { "fixup_Mips16_LWPC8",      8,      8,   0 },
    { "fixup_Mips16_LWPC16",     0,     16,   0 },
    { "fixup_Mips_HI16",        16,     16,   0 },
    { "fixup_Mips_LO16",        16,     16,   0 },
    { "fixup_Mips_AnyImm16",    16,     16,   0 },
    { "fixup_Mips_GPREL16",     16,     16,   0 },
    { "fixup_Mips_LITERAL",     16,     16,   0 },
    { "fixup_Mips_GOT",         16,     16,   0 },
    { "fixup_Mips_PC16",        16,     16,   0 },
    { "fixup_Mips_CALL16",      16,     16,   0 },
    { "fixup_Mips_SHIFT5",      21,      5,   0 },
    { "fixup_Mips_SHIFT6",      21,      5,   0 },
    { "fixup_Mips_64",           0,     64,   0 },
    { "fixup_Mips_TLSGD",       16,     16,   0 },
    { "fixup_Mips_GOTTPREL",    16,     16,   0 },
    { "fixup_Mips_TPREL_HI",    16,     16,   0 },
    { "fixup_Mips_TPREL_LO",    16,     16,   0 },
    { "fixup_Mips_TLSLDM",      16,     16,   0 },
    { "fixup_Mips_DTPREL_HI",   16,     16,   0 },
    { "fixup_Mips_DTPREL_LO",   16,     16,   0 },
    { "fixup_Mips_Branch_PCRel",16,     16,   0 },
    { "fixup_Mips_GPOFF_HI",    16,     16,   0 },
    { "fixup_MICROMIPS_GPOFF_HI", 16,   16,   0 },
    { "fixup_Mips_GPOFF_LO",    16,     16,   0 },
    { "fixup_MICROMIPS_GPOFF_LO", 16,   16,   0 },
    { "fixup_Mips_GOT_PAGE",    16,     16,   0 },
    { "fixup_Mips_GOT_OFST",    16,     16,   0 },
    { "fixup_Mips_GOT_DISP",    16,     16,   0 },
    { "fixup_Mips_HIGHER",      16,     16,   0 },
    { "fixup_MICROMIPS_HIGHER", 16,     16,   0 },
    { "fixup_Mips_HIGHEST",     16,     16,   0 },
    { "fixup_MICROMIPS_HIGHEST",16,     16,   0 },
    { "fixup_Mips_GOT_HI16",    16,     16,   0 },
    { "fixup_Mips_GOT_LO16",    16,     16,   0 },
    { "fixup_Mips_CALL_HI16",   16,     16,   0 },
    { "fixup_Mips_CALL_LO16",   16,     16,   0 },
    { "fixup_Mips_PC18_S3",     14,     18,   0 },
    { "fixup_MIPS_PC19_S2",     13,     19,   0 },
    { "fixup_MIPS_PC21_S2",     11,     21,   0 },
    { "fixup_MIPS_PC26_S2",      6,     26,   0 },
    { "fixup_MIPS_PCHI16",      16,     16,   0 },
    { "fixup_MIPS_PCLO16",      16,     16,   0 },
    { "fixup_MICROMIPS_26_S1",   6,     26,   0 },
    { "fixup_MICROMIPS_HI16",   16,     16,   0 },
    { "fixup_MICROMIPS_LO16",   16,     16,   0 },
    { "fixup_MICROMIPS_GPREL16", 16,     16,   0 },
    { "fixup_MICROMIPS_GOT16",  16,     16,   0 },
    { "fixup_MICROMIPS_PC7_S1",  9,      7,   0 },
    { "fixup_MICROMIPS_PC10_S1", 6,     10,   0 },
    { "fixup_MICROMIPS_PC16_S1",16,     16,   0 },
    { "fixup_MICROMIPS_PC26_S1", 6,     26,   0 },
    { "fixup_MICROMIPS_PC19_S2",13,     19,   0 },
    { "fixup_MICROMIPS_PC18_S3",14,     18,   0 },
    { "fixup_MICROMIPS_PC21_S1",11,     21,   0 },
    { "fixup_MICROMIPS_CALL16", 16,     16,   0 },
    { "fixup_MICROMIPS_GOT_DISP",        16,     16,   0 },
    { "fixup_MICROMIPS_GOT_PAGE",        16,     16,   0 },
    { "fixup_MICROMIPS_GOT_OFST",        16,     16,   0 },
    { "fixup_MICROMIPS_TLS_GD",          16,     16,   0 },
    { "fixup_MICROMIPS_TLS_LDM",         16,     16,   0 },
    { "fixup_MICROMIPS_TLS_DTPREL_HI16", 16,     16,   0 },
    { "fixup_MICROMIPS_TLS_DTPREL_LO16", 16,     16,   0 },
    { "fixup_MICROMIPS_GOTTPREL",        16,     16,   0 },
    { "fixup_MICROMIPS_TLS_TPREL_HI16",  16,     16,   0 },
    { "fixup_MICROMIPS_TLS_TPREL_LO16",  16,     16,   0 },
    { "fixup_Mips_SUB",                   0,     64,   0 },
    { "fixup_MICROMIPS_SUB",              0,     64,   0 },
    { "fixup_Mips_JALR",                  0,     32,   0 },
    { "fixup_MICROMIPS_JALR",             0,     32,   0 },
      // clang-format on
  };
  static_assert(std::size(BigEndianInfos) == Mips::NumTargetFixupKinds,
                "Not all MIPS big endian fixup kinds added!");

  if (mc::isRelocation(Kind))
    return {};
  if (Kind < FirstTargetFixupKind)
    return MCAsmBackend::getFixupKindInfo(Kind);

  assert(unsigned(Kind - FirstTargetFixupKind) < Mips::NumTargetFixupKinds &&
         "Invalid kind!");

  if (Endian == llvm::endianness::little)
    return LittleEndianInfos[Kind - FirstTargetFixupKind];
  return BigEndianInfos[Kind - FirstTargetFixupKind];
}

/// WriteNopData - Write an (optimal) nop sequence of Count bytes
/// to the given output. If the target cannot generate such a sequence,
/// it should return an error.
///
/// \return - True on success.
bool MipsAsmBackend::writeNopData(raw_ostream &OS, uint64_t Count,
                                  const MCSubtargetInfo *STI) const {
  // A zero halfword starts a 32-bit instruction. Use MOVE16 $zero, $zero
  // for a two-byte remainder so execution cannot consume the next symbol.
  if (STI && STI->hasFeature(Mips::FeatureMicroMips) &&
      !STI->hasFeature(Mips::FeatureMips32r6) && Count % 4 == 2) {
    support::endian::write<uint16_t>(OS, 0x0c00, Endian);
    Count -= 2;
  }
  OS.write_zeros(Count);
  return true;
}

namespace {

class WindowsMipsAsmBackend : public MipsAsmBackend {
public:
  WindowsMipsAsmBackend(const Target &T, const MCRegisterInfo &MRI,
                        const MCSubtargetInfo &STI)
      : MipsAsmBackend(T, MRI, STI.getTargetTriple(), STI.getCPU(), false) {}

  std::unique_ptr<MCObjectTargetWriter>
  createObjectTargetWriter() const override {
    return createMipsWinCOFFObjectWriter();
  }
};

} // end anonymous namespace

MCAsmBackend *llvm::createMipsAsmBackend(const Target &T,
                                         const MCSubtargetInfo &STI,
                                         const MCRegisterInfo &MRI,
                                         const MCTargetOptions &Options) {
  const Triple &TheTriple = STI.getTargetTriple();
  if (TheTriple.isOSWindows() && TheTriple.isOSBinFormatCOFF())
    return new WindowsMipsAsmBackend(T, MRI, STI);

  MipsABIInfo ABI = MipsABIInfo::computeTargetABI(STI.getTargetTriple(),
                                                  Options.getABIName());
  return new MipsAsmBackend(T, MRI, STI.getTargetTriple(), STI.getCPU(),
                            ABI.IsN32());
}
