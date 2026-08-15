//===- llvm/MC/BinaryRewrite.h - Binary rewrite interface -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// Interface contract for the "binary rewrite" emit path: emit fully-fixed-up
/// section bytes for a given final address model, instead of a relocatable
/// object file.
///
/// Everything that can change with new requirements is expressed here as a
/// caller-provided callback, so the emitter-side code (AddressModelBackend /
/// FinalImageObjectWriter) stays closed and does not need to be touched again
/// after this is added.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_MC_BINARYREWRITE_H
#define LLVM_MC_BINARYREWRITE_H

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/Compiler.h"
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace llvm {
class MCAsmBackend;
class MCObjectWriter;
class MCAssembler;
class MCSection;
} // namespace llvm

namespace llvm::mc_rewrite {

/// Complete context for resolving one external symbol referenced by a native
/// fixup or final-image symbol-index record.  Raw numeric identities are
/// preserved alongside stable callback-lifetime names, so address-model owners
/// can distinguish calls, ordinary data, GOT/TLV references, authenticated
/// pointers, and other relocation families without including target-private
/// enum headers or relying on a lossy generic classification.
struct RewriteSymbolResolveRequest {
  /// External symbol spelling selected by the target object convention.
  /// Valid only for the duration of the resolver callback.
  StringRef Symbol;
  /// Raw MC expression specifier (@PLT/@GOT/@TLV/auth/...), if any.
  uint32_t Specifier = 0;
  /// Stable target spelling of `Specifier`; empty when the target exposes no
  /// registered spelling. Valid only for the duration of the callback.
  StringRef SpecifierName;
  /// Raw target fixup kind from MCFixup.
  unsigned FixupKind = 0;
  /// Stable target spelling of `FixupKind`. Final-image symbol-index records
  /// use the generic `FK_NONE` name because they have no native fixup.
  /// Valid only for the duration of the resolver callback.
  StringRef FixupKindName;
  /// Owning output section. Valid only for the duration of the callback.
  StringRef SectionName;
  /// Byte offset of the reference within the merged output section.
  uint64_t SectionOffset = 0;
  /// Final image VA of the fixup or symbol-index field.
  uint64_t FixupVA = 0;
  /// True when the native fixup itself is PC-relative.
  bool IsPCRel = false;
  /// True when this symbol contributes with a negative sign.  Alias expansion
  /// composes nested add/subtract signs before invoking the resolver.
  bool IsSubtrahend = false;
  /// Width in bits of the native value field written by the fixup.
  unsigned BitWidth = 0;
};

/// Caller-provided "final address model": where the new code/sections live and
/// where external symbols resolve to in the target binary. Changing the
/// resolution strategy never touches the emitter-side code.
struct RewriteAddressModel {
  /// Final VA of the primary text section.
  uint64_t TextVA = 0;
  /// Load address subtracted for object-format image-relative references
  /// (COFF IMGREL32 / RVA fields).  Zero preserves absolute-address behavior
  /// for formats without an image base.
  uint64_t ImageBaseVA = 0;
  /// Final base VA of an arbitrary section by name.
  std::function<uint64_t(StringRef Section)> getSectionVA;
  /// External symbol -> absolute VA. \p Specifier distinguishes @PLT/@GOT/@TLS
  /// variants; the caller supplies the address required by that exact contract
  /// (for example, an existing callable stub or storage slot), not a freshly
  /// synthesized GOT/PLT entry.
  std::function<std::optional<uint64_t>(StringRef Sym, uint32_t Specifier)>
      resolve;
  /// Context-aware external-symbol resolver.  When installed, this is the
  /// authoritative resolver even when it returns std::nullopt; the legacy
  /// callback above is consulted only when this callback is absent.  This
  /// preserves old clients while allowing new clients to fail closed based on
  /// the exact native fixup contract.
  std::function<std::optional<uint64_t>(
      const RewriteSymbolResolveRequest &Request)>
      resolveWithContext;

  /// Resolve through the richest installed callback, falling back to the
  /// legacy symbol/specifier callback for source compatibility.
  std::optional<uint64_t>
  resolveSymbol(const RewriteSymbolResolveRequest &Request) const {
    if (resolveWithContext)
      return resolveWithContext(Request);
    if (resolve)
      return resolve(Request.Symbol, Request.Specifier);
    return std::nullopt;
  }
};

/// Context handed to the per-fixup hook: enough to do immediate-level
/// transforms / checksum work without understanding ISA encoding details.
struct FixupCtx {
  /// Target fixup kind.
  unsigned Kind = 0;
  /// Owning output section and byte offset within the merged RewriteSection.
  /// StringRef values are valid only for the duration of the callback.
  StringRef SectionName;
  uint64_t SectionOffset = 0;
  /// VA of this fixup within the final image.
  uint64_t FixupVA = 0;
  /// Direct add and subtract symbols from the evaluated MCValue, if any.
  /// Variable-symbol aliases are not recursively expanded here.
  StringRef Sym;
  StringRef SubSym;
  /// Signed constant term from the direct MCValue expression.
  int64_t Addend = 0;
  /// Expression specifier (@PLT/@GOT/...), if any.
  uint32_t Specifier = 0;
  bool IsPCRel = false;
  /// Whether the assembler resolved the fixup before applying it.
  bool IsResolved = false;
  /// Width in bits of the value field this fixup writes.
  unsigned BitWidth = 0;
};

/// Per-fixup hook: called once \p Value is the final absolute value but before
/// it is bit-packed into the instruction by the ISA encoder. Returns the
/// transformed value. Defaults to identity when unset.
using FixupTransform =
    std::function<uint64_t(const FixupCtx &, uint64_t Value)>;

/// Format-independent classification of an emitted section.  Object-format
/// flags stay an MC implementation detail; binary rewriters only need enough
/// information to place the section with compatible memory permissions.
enum class RewriteSectionKind : uint8_t {
  Code,
  ReadOnlyData,
  WritableData,
  UninitializedData,
  Metadata,
  Other,
};

/// One linker symbol-index record carried by a metadata section such as
/// COFF's `.gfids$y`/`.gehcont$y`.  A final-image writer has no object symbol
/// table to index, so it preserves the semantic target directly for the binary
/// rewriter that owns the final load-config table.
struct RewriteSymbolIndexReference {
  uint64_t Offset = 0;
  std::string Symbol;
  uint64_t TargetVA = 0;
};

/// One emitted section with its final placement and (post fixup) bytes.
struct RewriteSection {
  std::string Name;
  uint64_t VA = 0;
  uint64_t Alignment = 1;
  RewriteSectionKind Kind = RewriteSectionKind::Other;
  /// Whether the native object format marks this section as part of the loaded
  /// image.  Debug and linker-directive sections are normally not allocated.
  bool IsAllocated = true;
  std::vector<uint8_t> Bytes;
  std::vector<RewriteSymbolIndexReference> SymbolIndexReferences;
};

/// One compiler-authenticated CFI fragment.  Range IDs are opaque, nonzero,
/// and unique within one RewriteResult; consumers must not derive identity from
/// symbol spelling or address proximity.  BeginVA and EndVA form an exact
/// half-open range even when the underlying MC labels are temporary.
struct RewriteFunctionRange {
  uint64_t Id = 0;
  std::string OwnerSymbol;
  uint64_t OwnerVA = 0;
  std::string BeginSymbol;
  uint64_t BeginVA = 0;
  std::string EndSymbol;
  uint64_t EndVA = 0;
};

/// One exact IR-definition to final MC-owner association.  SourceFunction is
/// the original IR name and OwnerSymbol is the target-selected symbol spelling;
/// consumers compare both identities exactly and never infer one from the
/// other.
struct RewriteSourceFunctionOwner {
  std::string SourceFunction;
  std::string OwnerSymbol;
  uint64_t OwnerVA = 0;
  bool IsPrivate = false;
};

/// Validate the portable identity constraints of source-owner provenance.
/// Source identities are unique.  Owner addresses need not be unique because
/// zero-sized or folded entries can legally share an address while retaining
/// distinct symbol identities.
LLVM_ABI bool validateRewriteSourceFunctionOwners(
    ArrayRef<RewriteSourceFunctionOwner> Owners);

/// Validate the portable portion of function-range provenance.  IDs are
/// checked for uniqueness independently of address order; exact half-open
/// ranges may be adjacent but may not be empty or duplicated.  Global address
/// overlap may be deferred while a provisional multi-section layout is being
/// measured; final images must use the default complete validation.
LLVM_ABI bool validateRewriteFunctionRanges(
    ArrayRef<RewriteFunctionRange> Ranges,
    const std::map<std::string, uint64_t> &FunctionOwnerAddrs,
    bool ValidateGlobalOverlap = true);

/// Per-image hook: called after every fixup is applied, to mutate the final
/// bytes in place (whole-section checksum / code encryption / ...). Defaults to
/// a no-op when unset.
using ImagePostProcess = std::function<void(MutableArrayRef<RewriteSection>)>;

/// The complete set of knobs for one binary-rewrite emit.
struct RewriteOptions {
  RewriteAddressModel Model;
  FixupTransform onFixup;   // may be empty
  ImagePostProcess onImage; // may be empty
  /// Permit provisional ranges in distinct MC sections to share an address.
  /// The final placement must leave this false so global overlap is rejected.
  bool DeferGlobalFunctionRangeOverlap = false;
};

/// Result of a binary-rewrite emit.
struct RewriteResult {
  /// Each section's already-fixed-up (and post-onImage) bytes.
  std::vector<RewriteSection> Sections;
  /// Defined symbol -> final VA.
  std::map<std::string, uint64_t> SymbolAddrs;
  /// False when final section placement or byte materialization failed.
  bool ImageValid = true;
  /// Function owners used only to authenticate FunctionRanges.  Temporary
  /// owners are retained here without exposing them as public symbols.
  std::map<std::string, uint64_t> FunctionOwnerAddrs;
  /// Exact source IR definition -> final compiler owner association.  This is
  /// populated only by the binary-rewrite emission path.
  std::vector<RewriteSourceFunctionOwner> SourceFunctionOwners;
  /// Compiler-authenticated CFI fragment ownership and exact final ranges.
  std::vector<RewriteFunctionRange> FunctionRanges;
  /// False when any registered range failed identity or bounds validation.
  bool FunctionRangesValid = true;
  /// External symbols that could not be resolved (should be empty on success).
  std::vector<std::string> Unresolved;
};

/// Wrap a target MCAsmBackend with address-model resolution for binary rewrite.
/// The returned backend intercepts evaluateFixup/applyFixup; all other virtuals
/// forward to \p TargetBackend.  \p Opts and \p Result must outlive the
/// returned backend.
std::unique_ptr<MCAsmBackend>
createAddressModelBackend(std::unique_ptr<MCAsmBackend> TargetBackend,
                          const RewriteOptions &Opts, RewriteResult &Result);

/// Create an MCObjectWriter that emits fully fixed-up section bytes into
/// \p Result instead of a relocatable object file.  \p Opts and \p Result must
/// outlive the returned writer.
std::unique_ptr<MCObjectWriter>
createFinalImageObjectWriter(const RewriteOptions &Opts, RewriteResult &Result);

/// Compute the VA at which \p Sec's bytes begin under \p Opts's address model.
/// The caller-provided getSectionVA is keyed by section *name*, but some object
/// formats emit several MCSections that share a name — notably COFF, which
/// places each mergeable constant (e.g. a vector literal introduced by an
/// obfuscation pass) in its own COMDAT ".rdata". Anchoring them all at
/// getSectionVA(name) would overlap them, so same-named sections are packed
/// contiguously in MC emission order: the first lands exactly at
/// getSectionVA(name); each subsequent one is aligned to its own alignment and
/// placed after the previous. AddressModelBackend (fixup/symbol VAs) and
/// FinalImageObjectWriter (byte placement + symbol collection) both use this so
/// their address views stay identical, and the writer merges the same-named
/// MCSections into one RewriteSection so name-keyed callers see no duplicate.
uint64_t sectionImageVA(MCAssembler &Asm, const RewriteOptions &Opts,
                        const MCSection &Sec);

} // namespace llvm::mc_rewrite

#endif // LLVM_MC_BINARYREWRITE_H
