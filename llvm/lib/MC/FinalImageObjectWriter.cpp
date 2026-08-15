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
/// resolved by AddressModelBackend, copies fragment contents at their final
/// VAs, collects symbol addresses, and runs the ImagePostProcess hook.
/// recordRelocation distinguishes target-forced relocations from external
/// symbols that the address model could not resolve.
///
//===----------------------------------------------------------------------===//

#include "FinalImageObjectWriter.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/ScopeExit.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/BinaryFormat/COFF.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/BinaryFormat/MachO.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCSection.h"
#include "llvm/MC/MCSectionCOFF.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/MC/MCSectionMachO.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCValue.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TargetParser/Triple.h"
#include <algorithm>
#include <functional>
#include <limits>
#include <optional>
#include <set>

using namespace llvm;

namespace {

struct RewriteSectionTraits {
  llvm::mc_rewrite::RewriteSectionKind Kind =
      llvm::mc_rewrite::RewriteSectionKind::Other;
  bool IsAllocated = true;
};

RewriteSectionTraits classifySection(const MCAssembler &Asm,
                                     const MCSection &Sec) {
  using Kind = llvm::mc_rewrite::RewriteSectionKind;
  RewriteSectionTraits Traits;
  const MCContext &Ctx = Asm.getContext();

  switch (Ctx.getObjectFileType()) {
  case MCContext::IsCOFF: {
    const auto &C = static_cast<const MCSectionCOFF &>(Sec);
    unsigned Flags = C.getCharacteristics();
    StringRef Name = C.getName();
    // These sections contain object symbol-table indices consumed by the COFF
    // linker.  Their ordinary "dr" characteristics do not describe final-
    // image allocation, and retaining their raw indices as mapped data would
    // be meaningless.  The rewrite result exposes the semantic references to
    // the image post-processor instead.
    bool IsSymbolIndexMetadata =
        Name.starts_with(".gfids") || Name.starts_with(".gehcont") ||
        Name.starts_with(".giats") || Name.starts_with(".gljmp");
    Traits.IsAllocated =
        !IsSymbolIndexMetadata &&
        !(Flags & (COFF::IMAGE_SCN_LNK_REMOVE | COFF::IMAGE_SCN_LNK_INFO));
    if (Flags & (COFF::IMAGE_SCN_CNT_CODE | COFF::IMAGE_SCN_MEM_EXECUTE))
      Traits.Kind = Kind::Code;
    else if (Flags & COFF::IMAGE_SCN_CNT_UNINITIALIZED_DATA)
      Traits.Kind = Kind::UninitializedData;
    else if (!Traits.IsAllocated || Name.starts_with(".debug") ||
             Name == ".drectve")
      Traits.Kind = Kind::Metadata;
    else if (Flags & COFF::IMAGE_SCN_MEM_WRITE)
      Traits.Kind = Kind::WritableData;
    else if (Flags &
             (COFF::IMAGE_SCN_CNT_INITIALIZED_DATA | COFF::IMAGE_SCN_MEM_READ))
      Traits.Kind = Kind::ReadOnlyData;
    break;
  }
  case MCContext::IsELF: {
    const auto &E = static_cast<const MCSectionELF &>(Sec);
    unsigned Flags = E.getFlags();
    Traits.IsAllocated = (Flags & ELF::SHF_ALLOC) != 0;
    if (Flags & ELF::SHF_EXECINSTR)
      Traits.Kind = Kind::Code;
    else if (E.getType() == ELF::SHT_NOBITS)
      Traits.Kind = Kind::UninitializedData;
    else if (!Traits.IsAllocated)
      Traits.Kind = Kind::Metadata;
    else if (Flags & ELF::SHF_WRITE)
      Traits.Kind = Kind::WritableData;
    else
      Traits.Kind = Kind::ReadOnlyData;
    break;
  }
  case MCContext::IsMachO: {
    const auto &M = static_cast<const MCSectionMachO &>(Sec);
    unsigned Flags = M.getTypeAndAttributes();
    Traits.IsAllocated = (Flags & MachO::S_ATTR_DEBUG) == 0;
    if (Flags &
        (MachO::S_ATTR_PURE_INSTRUCTIONS | MachO::S_ATTR_SOME_INSTRUCTIONS))
      Traits.Kind = Kind::Code;
    else if (M.getType() == MachO::S_ZEROFILL ||
             M.getType() == MachO::S_GB_ZEROFILL ||
             M.getType() == MachO::S_THREAD_LOCAL_ZEROFILL)
      Traits.Kind = Kind::UninitializedData;
    else if (!Traits.IsAllocated)
      Traits.Kind = Kind::Metadata;
    else if (M.getSegmentName() == "__TEXT" ||
             M.getSegmentName() == "__DATA_CONST")
      Traits.Kind = Kind::ReadOnlyData;
    else
      Traits.Kind = Kind::WritableData;
    break;
  }
  default:
    if (Sec.isText() || Sec.hasInstructions())
      Traits.Kind = Kind::Code;
    else if (Sec.isBssSection())
      Traits.Kind = Kind::UninitializedData;
    else if (Sec.getName().starts_with(".debug")) {
      Traits.Kind = Kind::Metadata;
      Traits.IsAllocated = false;
    } else
      Traits.Kind = Kind::ReadOnlyData;
    break;
  }

  return Traits;
}

llvm::mc_rewrite::RewriteSectionKind
mergeSectionKind(llvm::mc_rewrite::RewriteSectionKind A,
                 llvm::mc_rewrite::RewriteSectionKind B) {
  using Kind = llvm::mc_rewrite::RewriteSectionKind;
  if (A == B)
    return A;
  if (A == Kind::Other)
    return B;
  if (B == Kind::Other)
    return A;
  // Same-named MC sections normally agree.  If a producer emits conflicting
  // traits, report the least restrictive data class rather than accidentally
  // mapping writable bytes read-only or data executable.
  if (A == Kind::WritableData || B == Kind::WritableData)
    return Kind::WritableData;
  return Kind::Other;
}

bool checkedAdd(uint64_t Left, uint64_t Right, uint64_t &Result) {
  if (Right > std::numeric_limits<uint64_t>::max() - Left)
    return false;
  Result = Left + Right;
  return true;
}

} // namespace

bool llvm::mc_rewrite::validateRewriteFunctionRanges(
    ArrayRef<RewriteFunctionRange> Ranges,
    const std::map<std::string, uint64_t> &FunctionOwnerAddrs,
    bool ValidateGlobalOverlap) {
  DenseSet<uint64_t> SeenIds;
  std::vector<const RewriteFunctionRange *> ByAddress;
  if (ValidateGlobalOverlap)
    ByAddress.reserve(Ranges.size());
  for (const RewriteFunctionRange &Range : Ranges) {
    const auto Owner = FunctionOwnerAddrs.find(Range.OwnerSymbol);
    if (Range.Id == 0 || !SeenIds.insert(Range.Id).second ||
        Range.OwnerSymbol.empty() || Range.BeginSymbol.empty() ||
        Range.EndSymbol.empty() || Owner == FunctionOwnerAddrs.end() ||
        Owner->second != Range.OwnerVA || Range.BeginVA >= Range.EndVA)
      return false;
    if (ValidateGlobalOverlap)
      ByAddress.push_back(&Range);
  }

  if (!ValidateGlobalOverlap)
    return true;

  llvm::sort(ByAddress, [](const RewriteFunctionRange *Left,
                           const RewriteFunctionRange *Right) {
    if (Left->BeginVA != Right->BeginVA)
      return Left->BeginVA < Right->BeginVA;
    if (Left->EndVA != Right->EndVA)
      return Left->EndVA < Right->EndVA;
    return Left->Id < Right->Id;
  });
  for (size_t I = 1; I < ByAddress.size(); ++I)
    if (ByAddress[I]->BeginVA < ByAddress[I - 1]->EndVA)
      return false;
  return true;
}

bool llvm::mc_rewrite::validateRewriteSourceFunctionOwners(
    ArrayRef<RewriteSourceFunctionOwner> Owners) {
  std::set<std::string> SeenSources;
  std::set<std::string> SeenOwnerSymbols;
  for (const RewriteSourceFunctionOwner &Owner : Owners) {
    if (Owner.SourceFunction.empty() || Owner.OwnerSymbol.empty() ||
        !SeenSources.insert(Owner.SourceFunction).second ||
        !SeenOwnerSymbols.insert(Owner.OwnerSymbol).second)
      return false;
  }
  return true;
}

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
    uint64_t VA = Base;
    if (!First) {
      if (Cur > std::numeric_limits<uint64_t>::max() - (A - 1)) {
        Asm.getContext().reportError(
            SMLoc(),
            "binary rewrite section alignment overflows for '" + Name + "'");
        return 0;
      }
      VA = alignTo(Cur, A);
    }
    First = false;
    uint64_t EndVA = 0;
    if (!checkedAdd(VA, Asm.getSectionAddressSize(S), EndVA)) {
      Asm.getContext().reportError(
          SMLoc(),
          "binary rewrite section address overflows for '" + Name + "'");
      return 0;
    }
    if (&S == &Sec)
      return VA;
    Cur = EndVA;
  }
  return Base;
}

void FinalImageObjectWriter::recordRelocation(const MCFragment &F,
                                              const MCFixup &Fixup,
                                              MCValue Target,
                                              uint64_t &FixedValue) {
  // A target backend may force an otherwise resolved fixup through this hook
  // (for example, an AArch64 page relocation). Recheck each component against
  // the same address-model seam so those relocations are not reported as
  // unresolved. The generic assembler fallback also reaches this hook after
  // an address-model lookup fails, so undefined externals must be retained for
  // the caller instead of being mistaken for successfully written zeroes.
  const MCContext &Context = Asm->getContext();
  const std::optional<uint32_t> ArmNoneSpecifier =
      Context.getAsmInfo().getSpecifierForName("none");
  const Triple &TT = Context.getTargetTriple();
  const bool IsArmNone = Context.getObjectFileType() == MCContext::IsELF &&
                         (TT.isARM() || TT.isThumb()) &&
                         Fixup.getKind() == FK_Data_4 && ArmNoneSpecifier &&
                         Target.getSpecifier() == *ArmNoneSpecifier;

  const MCFixupKindInfo KindInfo = Asm->getBackend().getFixupKindInfo(
      static_cast<MCFixupKind>(Fixup.getKind()));
  const MCSection &Section = *F.getParent();
  const uint64_t SectionVA = mc_rewrite::sectionImageVA(*Asm, Opts, Section);
  const uint64_t FixupVA =
      SectionVA + Asm->getFragmentOffset(F) + Fixup.getOffset();
  const uint64_t SectionBaseVA =
      Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Section.getName())
                              : SectionVA;
  auto appendUnresolved = [&](const MCSymbol *Sym) {
    if (!Sym)
      return;
    std::string Name = Sym->getName().str();
    if (std::find(Out.Unresolved.begin(), Out.Unresolved.end(), Name) ==
        Out.Unresolved.end())
      Out.Unresolved.push_back(std::move(Name));
  };
  SmallPtrSet<const MCSymbol *, 8> ActiveVariables;
  auto recordUnresolved = [&](auto &&Record, const MCSymbol *Sym,
                              uint32_t Specifier, bool IsSubtrahend) -> void {
    if (!Sym || Sym->isInSection() || Sym->isAbsolute())
      return;
    if (Sym->isVariable()) {
      if (!ActiveVariables.insert(Sym).second) {
        appendUnresolved(Sym);
        return;
      }
      scope_exit RemoveActive([&] { ActiveVariables.erase(Sym); });

      MCValue Aliased;
      if (!Sym->getVariableValue()->evaluateAsRelocatable(Aliased, Asm)) {
        appendUnresolved(Sym);
        return;
      }
      const uint32_t InnerSpecifier = Aliased.getSpecifier();
      if (Specifier && InnerSpecifier && Specifier != InnerSpecifier) {
        appendUnresolved(Sym);
        return;
      }
      const uint32_t EffectiveSpecifier =
          InnerSpecifier ? InnerSpecifier : Specifier;
      Record(Record, Aliased.getAddSym(), EffectiveSpecifier, IsSubtrahend);
      Record(Record, Aliased.getSubSym(), EffectiveSpecifier, !IsSubtrahend);
      return;
    }

    mc_rewrite::RewriteSymbolResolveRequest Request;
    Request.Symbol = Sym->getName();
    Request.Specifier = Specifier;
    if (Specifier)
      Request.SpecifierName =
          Context.getAsmInfo().getSpecifierNameOrEmpty(Specifier);
    Request.FixupKind = Fixup.getKind();
    Request.FixupKindName = KindInfo.Name;
    Request.SectionName = Section.getName();
    Request.SectionOffset = FixupVA - SectionBaseVA;
    Request.FixupVA = FixupVA;
    Request.IsPCRel = Fixup.isPCRel();
    Request.IsSubtrahend = IsSubtrahend;
    Request.BitWidth = KindInfo.TargetSize;
    if (Opts.Model.resolveSymbol(Request))
      return;
    appendUnresolved(Sym);
  };

  // R_ARM_NONE is an explicit no-op dependency used by ARM EHABI compact
  // records. It neither contributes a value nor requires runtime resolution;
  // reporting its personality symbol here would reject otherwise complete
  // unwind output after AddressModelBackend had correctly consumed the fixup.
  if (!IsArmNone) {
    recordUnresolved(recordUnresolved, Target.getAddSym(),
                     Target.getSpecifier(), false);
    recordUnresolved(recordUnresolved, Target.getSubSym(),
                     Target.getSpecifier(), true);
  }

  (void)FixedValue;
}

uint64_t FinalImageObjectWriter::writeObject() {
  uint64_t TotalBytes = 0;
  Out.Sections.clear();
  Out.SymbolAddrs.clear();
  // MCAssembler records unresolved relocations after final layout and before
  // writeObject().  Keep that evidence intact; clearing it here would turn
  // every undefined external into an apparently successful zero target.
  Out.FunctionRanges.clear();
  Out.FunctionOwnerAddrs.clear();
  Out.SourceFunctionOwners.clear();
  Out.ImageValid = true;
  Out.FunctionRangesValid = true;

  auto failClosed = [&]() -> uint64_t {
    Out.Sections.clear();
    Out.SymbolAddrs.clear();
    Out.Unresolved.clear();
    Out.FunctionRanges.clear();
    Out.FunctionOwnerAddrs.clear();
    Out.SourceFunctionOwners.clear();
    Out.ImageValid = false;
    return 0;
  };
  auto reportWriterError = [&](const Twine &Message) {
    Asm->getContext().reportError(SMLoc(), Message);
  };

  // Validate every section interval before publishing any bytes.  Calls made
  // by fixup evaluation normally discover the same error before writeObject,
  // but sections without fixups still require an explicit final-image check.
  for (MCSection &Sec : *Asm) {
    (void)mc_rewrite::sectionImageVA(*Asm, Opts, Sec);
    if (Asm->getContext().hadError())
      return failClosed();
  }

  // Helper: append ISA-correct NOP padding for text sections via the backend's
  // writeNopData(). Falls back to zero-fill if writeNopData() fails.
  auto appendNopPad = [&](std::vector<uint8_t> &Buf, uint64_t PadSize,
                          const MCSubtargetInfo *STI) -> bool {
    if (PadSize > Buf.max_size() - Buf.size()) {
      reportWriterError("binary rewrite section byte size overflows");
      return false;
    }
    SmallVector<char, 64> NopBuf;
    raw_svector_ostream NopOS(NopBuf);
    if (Asm->getBackend().writeNopData(NopOS, PadSize, STI)) {
      if (NopBuf.size() != PadSize) {
        reportWriterError("binary rewrite backend produced invalid NOP size");
        return false;
      }
      Buf.insert(Buf.end(), reinterpret_cast<const uint8_t *>(NopBuf.data()),
                 reinterpret_cast<const uint8_t *>(NopBuf.data()) +
                     NopBuf.size());
    } else {
      Buf.resize(Buf.size() + static_cast<size_t>(PadSize), 0x00);
    }
    return true;
  };

  // Build the final bytes for one MCSection (fragment contents + alignment
  // padding) — exactly getSectionAddressSize(Sec) bytes.
  auto buildSectionBytes =
      [&](MCSection &Sec, bool IsText,
          std::vector<mc_rewrite::RewriteSymbolIndexReference> &SymbolRefs)
      -> std::vector<uint8_t> {
    std::vector<uint8_t> Bytes;
    uint64_t Size = Asm->getSectionAddressSize(Sec);
    if (Size > Bytes.max_size()) {
      reportWriterError("binary rewrite section is too large to materialize");
      return {};
    }
    Bytes.reserve(static_cast<size_t>(Size));

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
        if (IsText) {
          if (!appendNopPad(Bytes, Gap, SecSTI))
            return {};
        } else {
          if (FOffset > Bytes.max_size()) {
            reportWriterError(
                "binary rewrite fragment offset exceeds host size");
            return {};
          }
          Bytes.resize(static_cast<size_t>(FOffset), 0x00);
        }
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
        if (Total > Bytes.max_size() - Bytes.size()) {
          reportWriterError("binary rewrite fill fragment size overflows");
          return {};
        }
        unsigned VSize = FF.getValueSize();
        uint64_t Val = FF.getValue();
        for (uint64_t I = 0; I < Total; ++I)
          Bytes.push_back(VSize ? uint8_t((Val >> (8 * (I % VSize))) & 0xFF)
                                : uint8_t(0));
        continue;
      }

      if (F.getKind() == MCFragment::FT_SymbolId) {
        const auto &SF = cast<MCSymbolIdFragment>(F);
        const MCSymbol *Sym = SF.getSymbol();
        mc_rewrite::RewriteSymbolIndexReference Ref;
        Ref.Offset = FOffset;
        if (Sym) {
          Ref.Symbol = Sym->getName().str();
          if (Sym->isInSection()) {
            const uint64_t SectionVA =
                mc_rewrite::sectionImageVA(*Asm, Opts, Sym->getSection());
            if (!checkedAdd(SectionVA, Asm->getSymbolOffset(*Sym),
                            Ref.TargetVA)) {
              reportWriterError(
                  "binary rewrite symbol-index target address overflows");
              return {};
            }
          } else if (Sym->isAbsolute())
            Ref.TargetVA = Asm->getSymbolOffset(*Sym);
          else {
            mc_rewrite::RewriteSymbolResolveRequest Request;
            Request.Symbol = Sym->getName();
            Request.FixupKind = FK_NONE;
            Request.FixupKindName =
                Asm->getBackend().getFixupKindInfo(FK_NONE).Name;
            Request.SectionName = Sec.getName();
            const uint64_t SectionVA =
                mc_rewrite::sectionImageVA(*Asm, Opts, Sec);
            const uint64_t SectionBaseVA =
                Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Sec.getName())
                                        : SectionVA;
            Request.FixupVA = SectionVA + FOffset;
            Request.SectionOffset = Request.FixupVA - SectionBaseVA;
            Request.BitWidth = 32;
            Ref.TargetVA = Opts.Model.resolveSymbol(Request).value_or(0);
          }
        }
        SymbolRefs.push_back(std::move(Ref));
        // Preserve the native four-byte fragment extent.  The value was an
        // object symbol-table index and has no meaning in a final image.
        const uint64_t FragmentSize = Asm->computeFragmentSize(F);
        if (FragmentSize > Bytes.max_size() - Bytes.size()) {
          reportWriterError("binary rewrite symbol-id fragment size overflows");
          return {};
        }
        Bytes.resize(Bytes.size() + static_cast<size_t>(FragmentSize), 0x00);
        continue;
      }

      auto Content = F.getContents();
      if (Content.size() > Bytes.max_size() - Bytes.size()) {
        reportWriterError("binary rewrite fragment contents overflow");
        return {};
      }
      Bytes.insert(
          Bytes.end(), reinterpret_cast<const uint8_t *>(Content.data()),
          reinterpret_cast<const uint8_t *>(Content.data()) + Content.size());
      auto Var = F.getVarContents();
      if (!Var.empty()) {
        if (Var.size() > Bytes.max_size() - Bytes.size()) {
          reportWriterError("binary rewrite variable contents overflow");
          return {};
        }
        Bytes.insert(Bytes.end(), reinterpret_cast<const uint8_t *>(Var.data()),
                     reinterpret_cast<const uint8_t *>(Var.data()) +
                         Var.size());
      }

      // Alignment fragments (FT_Align, FT_PrefAlign) have padding that's
      // generated by writeNopData() during standard emission, not stored in
      // getContents()/getVarContents(). Generate the padding here.
      uint64_t FragSize = Asm->computeFragmentSize(F);
      uint64_t Written = 0;
      if (!checkedAdd(Content.size(), Var.size(), Written)) {
        reportWriterError("binary rewrite fragment byte count overflows");
        return {};
      }
      if (FragSize > Written) {
        uint64_t PadSize = FragSize - Written;
        if (IsText && (F.getKind() == MCFragment::FT_Align ||
                       F.getKind() == MCFragment::FT_PrefAlign)) {
          if (!appendNopPad(Bytes, PadSize,
                            F.getSubtargetInfo() ? F.getSubtargetInfo()
                                                 : SecSTI))
            return {};
        } else if (IsText) {
          if (!appendNopPad(Bytes, PadSize, SecSTI))
            return {};
        } else {
          if (PadSize > Bytes.max_size() - Bytes.size()) {
            reportWriterError("binary rewrite fragment padding overflows");
            return {};
          }
          Bytes.resize(Bytes.size() + static_cast<size_t>(PadSize), 0x00);
        }
      }
    }

    if (Bytes.size() > Size) {
      reportWriterError("binary rewrite section contents exceed layout size");
      return {};
    }
    // Pad to the section's full address size.
    if (Bytes.size() < Size) {
      uint64_t Remaining = Size - Bytes.size();
      if (IsText) {
        if (!appendNopPad(Bytes, Remaining, SecSTI))
          return {};
      } else {
        Bytes.resize(static_cast<size_t>(Size), 0x00);
      }
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
    RewriteSectionTraits Traits = classifySection(*Asm, Sec);
    bool IsText = Traits.Kind == mc_rewrite::RewriteSectionKind::Code;
    std::vector<mc_rewrite::RewriteSymbolIndexReference> SymbolRefs;
    std::vector<uint8_t> SecBytes = buildSectionBytes(Sec, IsText, SymbolRefs);
    if (Asm->getContext().hadError())
      return failClosed();
    uint64_t Base = Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Name) : 0;
    uint64_t VA = mc_rewrite::sectionImageVA(*Asm, Opts, Sec);
    if (Asm->getContext().hadError())
      return failClosed();

    auto It = NameToIdx.find(Name.str());
    if (It == NameToIdx.end()) {
      mc_rewrite::RewriteSection RS;
      RS.Name = Name.str();
      RS.VA = Base;
      RS.Alignment = std::max<uint64_t>(Sec.getAlign().value(), 1);
      RS.Kind = Traits.Kind;
      RS.IsAllocated = Traits.IsAllocated;
      if (VA < Base) {
        reportWriterError("binary rewrite section precedes its base address");
        return failClosed();
      }
      uint64_t Off = VA - Base; // 0 for the first same-named section
      if (Off > RS.Bytes.max_size() ||
          SecBytes.size() > RS.Bytes.max_size() - static_cast<size_t>(Off)) {
        reportWriterError("binary rewrite merged section size overflows");
        return failClosed();
      }
      RS.Bytes.resize(static_cast<size_t>(Off), 0x00);
      RS.Bytes.insert(RS.Bytes.end(), SecBytes.begin(), SecBytes.end());
      for (auto &Ref : SymbolRefs) {
        if (!checkedAdd(Ref.Offset, Off, Ref.Offset)) {
          reportWriterError(
              "binary rewrite symbol-index reference offset overflows");
          return failClosed();
        }
        RS.SymbolIndexReferences.push_back(std::move(Ref));
      }
      NameToIdx[RS.Name] = Out.Sections.size();
      Out.Sections.push_back(std::move(RS));
    } else {
      auto &RS = Out.Sections[It->second];
      RS.Alignment = std::max<uint64_t>(RS.Alignment, Sec.getAlign().value());
      RS.Kind = mergeSectionKind(RS.Kind, Traits.Kind);
      RS.IsAllocated |= Traits.IsAllocated;
      if (VA < RS.VA) {
        reportWriterError("binary rewrite merged section address underflows");
        return failClosed();
      }
      uint64_t Off = VA - RS.VA;
      if (Off > RS.Bytes.max_size()) {
        reportWriterError("binary rewrite merged section offset is too large");
        return failClosed();
      }
      // Off >= current size (same-named sections are packed in MC order), so
      // resize fills the small inter-constant alignment gap with zeros.
      if (RS.Bytes.size() < Off)
        RS.Bytes.resize(static_cast<size_t>(Off), 0x00);
      if (SecBytes.size() > RS.Bytes.max_size() - RS.Bytes.size()) {
        reportWriterError("binary rewrite merged section size overflows");
        return failClosed();
      }
      RS.Bytes.insert(RS.Bytes.end(), SecBytes.begin(), SecBytes.end());
      for (auto &Ref : SymbolRefs) {
        if (!checkedAdd(Ref.Offset, Off, Ref.Offset)) {
          reportWriterError(
              "binary rewrite symbol-index reference offset overflows");
          return failClosed();
        }
        RS.SymbolIndexReferences.push_back(std::move(Ref));
      }
    }
  }

  for (auto &RS : Out.Sections)
    if (!checkedAdd(TotalBytes, RS.Bytes.size(), TotalBytes)) {
      reportWriterError("binary rewrite total image size overflows");
      return failClosed();
    }

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
      if (InSec) {
        const uint64_t SectionVA =
            mc_rewrite::sectionImageVA(*Asm, Opts, Sym.getSection());
        if (!checkedAdd(SectionVA, Asm->getSymbolOffset(Sym), VA)) {
          reportWriterError("binary rewrite symbol address overflows");
          return failClosed();
        }
      } else {
        VA = Asm->getSymbolOffset(Sym);
      }
      Out.SymbolAddrs[Sym.getName().str()] = VA;
    }
  }

  // Resolve authenticated CFI fragment labels directly from MC symbols after
  // final layout.  Begin/end labels are commonly temporary and intentionally
  // remain absent from SymbolAddrs.  FunctionOwnerAddrs is a provenance-only
  // namespace, so private owners remain authenticated without becoming public
  // linker symbols.
  if (Asm) {
    struct SymbolLocation {
      uint64_t VA = 0;
      uint64_t Offset = 0;
      const MCSection *Section = nullptr;
    };
    auto symbolLocation =
        [&](const MCSymbol *Symbol,
            bool AllowSectionEnd) -> std::optional<SymbolLocation> {
      if (!Symbol || Symbol->isVariable() || !Symbol->isInSection())
        return std::nullopt;
      uint64_t Offset = 0;
      if (!Asm->getSymbolOffset(*Symbol, Offset))
        return std::nullopt;
      const MCSection &Section = Symbol->getSection();
      const uint64_t SectionSize = Asm->getSectionAddressSize(Section);
      if (Offset > SectionSize || (!AllowSectionEnd && Offset == SectionSize))
        return std::nullopt;
      const uint64_t SectionVA =
          mc_rewrite::sectionImageVA(*Asm, Opts, Section);
      if (SectionSize > std::numeric_limits<uint64_t>::max() - SectionVA ||
          Offset > std::numeric_limits<uint64_t>::max() - SectionVA)
        return std::nullopt;
      return SymbolLocation{SectionVA + Offset, Offset, &Section};
    };

    DenseSet<StringRef> SeenSourceFunctions;
    DenseSet<const MCSymbol *> AuthenticatedOwnerSymbols;
    for (const MCRewriteSourceFunctionOwner &Input :
         Asm->getRewriteSourceFunctionOwners()) {
      if (Input.SourceFunction.empty() ||
          !SeenSourceFunctions.insert(Input.SourceFunction).second ||
          !Input.Owner || Input.Owner->isVariable() ||
          Input.Owner->getName().empty() ||
          !AuthenticatedOwnerSymbols.insert(Input.Owner).second) {
        Out.FunctionRangesValid = false;
        break;
      }

      const RewriteSectionTraits OwnerSection =
          Input.Owner->isInSection()
              ? classifySection(*Asm, Input.Owner->getSection())
              : RewriteSectionTraits{};
      const std::optional<SymbolLocation> Owner =
          symbolLocation(Input.Owner, /*AllowSectionEnd=*/false);
      if (!OwnerSection.IsAllocated ||
          OwnerSection.Kind != mc_rewrite::RewriteSectionKind::Code || !Owner) {
        Out.FunctionRangesValid = false;
        break;
      }

      const std::string OwnerName = Input.Owner->getName().str();
      const auto [OwnerIt, Inserted] =
          Out.FunctionOwnerAddrs.try_emplace(OwnerName, Owner->VA);
      if (!Inserted && OwnerIt->second != Owner->VA) {
        Out.FunctionRangesValid = false;
        break;
      }

      Out.SourceFunctionOwners.push_back(
          {Input.SourceFunction, OwnerName, Owner->VA, Input.IsPrivate});
      if (Input.IsPrivate)
        Out.SymbolAddrs.erase(OwnerName);
    }
    if (Out.FunctionRangesValid &&
        !mc_rewrite::validateRewriteSourceFunctionOwners(
            Out.SourceFunctionOwners))
      Out.FunctionRangesValid = false;

    struct LocalFunctionRange {
      const MCSection *Section = nullptr;
      uint64_t BeginOffset = 0;
      uint64_t EndOffset = 0;
    };
    DenseSet<uint64_t> SeenIds;
    std::vector<LocalFunctionRange> LocalRanges;
    LocalRanges.reserve(Asm->getRewriteFunctionRanges().size());

    for (const MCRewriteFunctionRange &Input :
         Asm->getRewriteFunctionRanges()) {
      if (!Out.FunctionRangesValid)
        break;
      if (Input.Id == 0 || !SeenIds.insert(Input.Id).second || !Input.Owner ||
          !AuthenticatedOwnerSymbols.contains(Input.Owner) ||
          Input.Owner->isVariable() || Input.Owner->getName().empty() ||
          !Input.Begin || !Input.End || Input.Begin->getName().empty() ||
          Input.End->getName().empty() || !Input.Begin->isInSection() ||
          !Input.End->isInSection() ||
          &Input.Begin->getSection() != &Input.End->getSection()) {
        Out.FunctionRangesValid = false;
        break;
      }

      const RewriteSectionTraits RangeSection =
          classifySection(*Asm, Input.Begin->getSection());
      const RewriteSectionTraits OwnerSection =
          Input.Owner->isInSection()
              ? classifySection(*Asm, Input.Owner->getSection())
              : RewriteSectionTraits{};
      const std::optional<SymbolLocation> Owner =
          symbolLocation(Input.Owner, /*AllowSectionEnd=*/false);
      const std::optional<SymbolLocation> Begin =
          symbolLocation(Input.Begin, /*AllowSectionEnd=*/false);
      const std::optional<SymbolLocation> End =
          symbolLocation(Input.End, /*AllowSectionEnd=*/true);
      if (!RangeSection.IsAllocated || !OwnerSection.IsAllocated ||
          RangeSection.Kind != mc_rewrite::RewriteSectionKind::Code ||
          OwnerSection.Kind != mc_rewrite::RewriteSectionKind::Code || !Owner ||
          !Begin || !End || Begin->Offset >= End->Offset) {
        Out.FunctionRangesValid = false;
        break;
      }

      const std::string OwnerName = Input.Owner->getName().str();
      const auto [OwnerIt, Inserted] =
          Out.FunctionOwnerAddrs.try_emplace(OwnerName, Owner->VA);
      if (!Inserted && OwnerIt->second != Owner->VA) {
        Out.FunctionRangesValid = false;
        break;
      }

      mc_rewrite::RewriteFunctionRange Range;
      Range.Id = Input.Id;
      Range.OwnerSymbol = OwnerName;
      Range.OwnerVA = Owner->VA;
      Range.BeginSymbol = Input.Begin->getName().str();
      Range.BeginVA = Begin->VA;
      Range.EndSymbol = Input.End->getName().str();
      Range.EndVA = End->VA;
      Out.FunctionRanges.push_back(std::move(Range));
      LocalRanges.push_back({Begin->Section, Begin->Offset, End->Offset});
    }

    if (Out.FunctionRangesValid) {
      llvm::sort(LocalRanges, [](const LocalFunctionRange &Left,
                                 const LocalFunctionRange &Right) {
        if (Left.Section != Right.Section)
          return std::less<const MCSection *>()(Left.Section, Right.Section);
        if (Left.BeginOffset != Right.BeginOffset)
          return Left.BeginOffset < Right.BeginOffset;
        return Left.EndOffset < Right.EndOffset;
      });
      for (size_t I = 1; I < LocalRanges.size(); ++I)
        if (LocalRanges[I].Section == LocalRanges[I - 1].Section &&
            LocalRanges[I].BeginOffset < LocalRanges[I - 1].EndOffset) {
          Out.FunctionRangesValid = false;
          break;
        }
    }
    if (Out.FunctionRangesValid)
      Out.FunctionRangesValid = mc_rewrite::validateRewriteFunctionRanges(
          Out.FunctionRanges, Out.FunctionOwnerAddrs,
          !Opts.DeferGlobalFunctionRangeOverlap);
    if (!Out.FunctionRangesValid) {
      Out.FunctionRanges.clear();
      Out.FunctionOwnerAddrs.clear();
      Out.SourceFunctionOwners.clear();
    }
  }

  if (Opts.onImage)
    Opts.onImage(Out.Sections);

  return TotalBytes;
}

std::unique_ptr<MCObjectWriter> llvm::mc_rewrite::createFinalImageObjectWriter(
    const mc_rewrite::RewriteOptions &Opts, mc_rewrite::RewriteResult &Result) {
  return std::make_unique<FinalImageObjectWriter>(Opts, Result);
}
