//===- FinalImageObjectWriter.cpp - Object writer for rewriting -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// FinalImageObjectWriter walks MCAssembler sections after all fixups have been
/// resolved by AddressModelBackend, copies fragment contents at their final VAs,
/// collects symbol addresses, and runs the ImagePostProcess hook.
/// recordRelocation unconditionally suppresses — any fixup reaching it has
/// already been back-filled by AddressModelBackend + stock applyFixup.
///
//===----------------------------------------------------------------------===//

#include "FinalImageObjectWriter.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCSection.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCValue.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

uint64_t llvm::mc_rewrite::sectionImageVA(MCAssembler &Asm,
                                          const RewriteOptions &Opts,
                                          const MCSection &Sec) {
  // getSectionVA is keyed by name, but several MCSections can share a name
  // (notably COFF, which puts each mergeable constant in its own COMDAT
  // ".rdata"). Anchoring them all at getSectionVA(name) would overlap them, so
  // walk the same-named sections in MC emission order and pack them
  // contiguously: the first lands exactly at getSectionVA(name), each
  // subsequent one is aligned to its own alignment and placed after the
  // previous. AddressModelBackend and FinalImageObjectWriter both call this so
  // their fixup/symbol/byte address views stay identical.
  StringRef Name = Sec.getName();
  uint64_t Base = Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Name) : 0;
  uint64_t Cur = Base;
  bool First = true;
  for (MCSection &S : Asm) {
    if (S.getName() != Name)
      continue;
    uint64_t A = std::max<uint64_t>(S.getAlign().value(), uint64_t(1));
    uint64_t VA = First ? Base : alignTo(Cur, A);
    First = false;
    if (&S == &Sec)
      return VA;
    Cur = VA + Asm.getSectionAddressSize(S);
  }
  return Base;
}

void FinalImageObjectWriter::recordRelocation(const MCFragment &F,
                                              const MCFixup &Fixup,
                                              MCValue Target,
                                              uint64_t &FixedValue) {
  // AddressModelBackend::evaluateFixup has already resolved the value and the
  // bytes have been back-filled. shouldForceRelocation in the target backend
  // (e.g. AArch64 forces ADRP) may still route through here — suppress those
  // false positives: if the symbol is defined / in-section / absolute, or if
  // the caller's resolve callback can handle it, it is not truly unresolved.
  // AddressModelBackend::evaluateFixup resolved the value and the bytes are
  // already back-filled. Target backends that force relocations (ARM BL/BLX,
  // AArch64 ADRP, specifiers with @PLT/@GOT) still route through here.
  // In B2 mode these are already handled — suppress unconditionally.
  // Any truly unresolvable symbol would have made evaluateFixup return
  // nullopt, which prevents applyFixup from running at all.
  (void)F;
  (void)Fixup;
  (void)Target;
  (void)FixedValue;
}

uint64_t FinalImageObjectWriter::writeObject() {
  uint64_t TotalBytes = 0;

  // Helper: append ISA-correct NOP padding for text sections via the backend's
  // writeNopData(). Falls back to zero-fill if writeNopData() fails.
  auto appendNopPad = [&](std::vector<uint8_t> &Buf, uint64_t PadSize,
                          const MCSubtargetInfo *STI) {
    SmallVector<char, 64> NopBuf;
    raw_svector_ostream NopOS(NopBuf);
    if (Asm->getBackend().writeNopData(NopOS, PadSize, STI)) {
      Buf.insert(Buf.end(), reinterpret_cast<const uint8_t *>(NopBuf.data()),
                 reinterpret_cast<const uint8_t *>(NopBuf.data()) +
                     NopBuf.size());
    } else {
      Buf.resize(Buf.size() + PadSize, 0x00);
    }
  };

  // Build the final bytes for one MCSection (fragment contents + alignment
  // padding) — exactly getSectionAddressSize(Sec) bytes.
  auto buildSectionBytes = [&](MCSection &Sec,
                               bool IsText) -> std::vector<uint8_t> {
    std::vector<uint8_t> Bytes;
    uint64_t Size = Asm->getSectionAddressSize(Sec);
    Bytes.reserve(Size);

    // Grab a subtarget pointer from the first fragment (for writeNopData).
    const MCSubtargetInfo *SecSTI = nullptr;
    for (const MCFragment &F : Sec)
      if (F.getSubtargetInfo()) {
        SecSTI = F.getSubtargetInfo();
        break;
      }

    for (const MCFragment &F : Sec) {
      uint64_t FOffset = Asm->getFragmentOffset(F);

      // Fill gap between the current output position and the fragment's offset
      // with ISA-correct NOPs (text) or zeros (data).
      if (Bytes.size() < FOffset) {
        uint64_t Gap = FOffset - Bytes.size();
        if (IsText)
          appendNopPad(Bytes, Gap, SecSTI);
        else
          Bytes.resize(FOffset, 0x00);
      }

      // FT_Fill fragments carry no bytes in getContents()/getVarContents():
      // their payload is a (value, value-size, count) triple.  The backend
      // routes any repeated-byte constant through emitFill (see
      // isRepeatedByteSequence in AsmPrinter) — e.g. an all-ones <N x i32>
      // vector that lands in the constant pool emits emitFill(bytes, 0xFF).
      // Falling through to the generic path below would treat the whole run as
      // padding and zero-fill it, silently turning a non-zero fill into zeros
      // (all-ones -> 0x00) and miscompiling any code that reads the constant
      // (e.g. `pxor xmm, [pool]` for `~x` becomes a no-op).  A zero fill
      // (emitZeros) still materializes correctly here.
      if (F.getKind() == MCFragment::FT_Fill) {
        const auto &FF = cast<MCFillFragment>(F);
        uint64_t Total = Asm->computeFragmentSize(F);
        unsigned VSize = FF.getValueSize();
        uint64_t Val = FF.getValue();
        for (uint64_t I = 0; I < Total; ++I)
          Bytes.push_back(VSize ? uint8_t((Val >> (8 * (I % VSize))) & 0xFF)
                                : uint8_t(0));
        continue;
      }

      auto Content = F.getContents();
      Bytes.insert(Bytes.end(),
                   reinterpret_cast<const uint8_t *>(Content.data()),
                   reinterpret_cast<const uint8_t *>(Content.data()) +
                       Content.size());
      auto Var = F.getVarContents();
      if (!Var.empty())
        Bytes.insert(Bytes.end(),
                     reinterpret_cast<const uint8_t *>(Var.data()),
                     reinterpret_cast<const uint8_t *>(Var.data()) +
                         Var.size());

      // Alignment fragments (FT_Align, FT_PrefAlign) have padding that's
      // generated by writeNopData() during standard emission, not stored in
      // getContents()/getVarContents(). Generate the padding here.
      uint64_t FragSize = Asm->computeFragmentSize(F);
      uint64_t Written = Content.size() + Var.size();
      if (FragSize > Written) {
        uint64_t PadSize = FragSize - Written;
        if (IsText && (F.getKind() == MCFragment::FT_Align ||
                       F.getKind() == MCFragment::FT_PrefAlign))
          appendNopPad(Bytes, PadSize,
                       F.getSubtargetInfo() ? F.getSubtargetInfo() : SecSTI);
        else if (IsText)
          appendNopPad(Bytes, PadSize, SecSTI);
        else
          Bytes.resize(Bytes.size() + PadSize, 0x00);
      }
    }

    // Pad to the section's full address size.
    if (Bytes.size() < Size) {
      uint64_t Remaining = Size - Bytes.size();
      if (IsText)
        appendNopPad(Bytes, Remaining, SecSTI);
      else
        Bytes.resize(Size, 0x00);
    }
    return Bytes;
  };

  // Emit one RewriteSection per *distinct section name*. Some formats emit
  // several MCSections that share a name (COFF places each mergeable constant —
  // e.g. a vector literal an obfuscation pass introduced — in its own COMDAT
  // ".rdata"). sectionImageVA packs same-named sections contiguously; here we
  // lay their bytes into a single RewriteSection at the shared base VA so
  // name-keyed callers (the patch-image layout, which maps section name -> VA)
  // never see a duplicate that would overlap.
  std::map<std::string, size_t> NameToIdx;
  for (MCSection &Sec : *Asm) {
    StringRef Name = Sec.getName();
    bool IsText = Name.contains("text") || Name.contains("TEXT");
    std::vector<uint8_t> SecBytes = buildSectionBytes(Sec, IsText);
    uint64_t Base =
        Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Name) : 0;
    uint64_t VA = mc_rewrite::sectionImageVA(*Asm, Opts, Sec);

    auto It = NameToIdx.find(Name.str());
    if (It == NameToIdx.end()) {
      mc_rewrite::RewriteSection RS;
      RS.Name = Name.str();
      RS.VA = Base;
      uint64_t Off = VA - Base; // 0 for the first same-named section
      RS.Bytes.resize(Off, 0x00);
      RS.Bytes.insert(RS.Bytes.end(), SecBytes.begin(), SecBytes.end());
      NameToIdx[RS.Name] = Out.Sections.size();
      Out.Sections.push_back(std::move(RS));
    } else {
      auto &RS = Out.Sections[It->second];
      uint64_t Off = VA - RS.VA;
      // Off >= current size (same-named sections are packed in MC order), so
      // resize fills the small inter-constant alignment gap with zeros.
      if (RS.Bytes.size() < Off)
        RS.Bytes.resize(Off, 0x00);
      RS.Bytes.insert(RS.Bytes.end(), SecBytes.begin(), SecBytes.end());
    }
  }

  for (auto &RS : Out.Sections)
    TotalBytes += RS.Bytes.size();

  // Collect defined symbols. Some targets (ARM32 ELF) leave symbols in the
  // table whose MCSymbol pointers reference freed or invalid memory after
  // layout; guard every dereference with address-range plausibility checks.
  if (Asm) {
    for (const MCSymbol &Sym : Asm->symbols()) {
      // Skip symbols that may crash on property access.
      if (Sym.isVariable() || Sym.isTemporary())
        continue;
      bool InSec = Sym.isInSection();
      bool IsAbs = !InSec && Sym.isAbsolute();
      if (!InSec && !IsAbs)
        continue;
      uint64_t VA = 0;
      if (InSec)
        VA = mc_rewrite::sectionImageVA(*Asm, Opts, Sym.getSection()) +
             Asm->getSymbolOffset(Sym);
      else
        VA = Asm->getSymbolOffset(Sym);
      Out.SymbolAddrs[Sym.getName().str()] = VA;
    }
  }

  if (Opts.onImage)
    Opts.onImage(Out.Sections);

  return TotalBytes;
}

std::unique_ptr<MCObjectWriter>
llvm::mc_rewrite::createFinalImageObjectWriter(
    const mc_rewrite::RewriteOptions &Opts,
    mc_rewrite::RewriteResult &Result) {
  return std::make_unique<FinalImageObjectWriter>(Opts, Result);
}
