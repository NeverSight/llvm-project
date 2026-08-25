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
#include <array>
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
  /// Non-empty only for a compiler-created private owner (for example, a
  /// Windows EH funclet) derived from an authenticated source-function owner.
  std::string ParentOwnerSymbol;
  uint64_t ParentOwnerVA = 0;
};

/// Stable semantic record kinds emitted by the Windows EH backend. These are
/// rewrite-only identities: ordinary object emission does not create them.
enum class RewriteWinEHSemanticKind : uint8_t {
  SEHScope = 1,
  CxxCatch = 2,
};
static_assert(static_cast<uint8_t>(RewriteWinEHSemanticKind::SEHScope) == 1 &&
              static_cast<uint8_t>(RewriteWinEHSemanticKind::CxxCatch) == 2);

/// Exact physical encoding used for one compiler-emitted Windows EH semantic
/// row.  This is deliberately separate from RewriteWinEHSemanticKind: FH3 and
/// FH4 carry the same C++ catch semantics in incompatible fixed-width and
/// compressed wire formats.
enum class RewriteWinEHSemanticEncoding : uint8_t {
  SEH = 1,
  CxxFH3 = 2,
  CxxFH4 = 3,
};
static_assert(static_cast<uint8_t>(RewriteWinEHSemanticEncoding::SEH) == 1 &&
              static_cast<uint8_t>(RewriteWinEHSemanticEncoding::CxxFH3) == 2 &&
              static_cast<uint8_t>(RewriteWinEHSemanticEncoding::CxxFH4) == 3);

/// Instruction attachment consumed by WinEH state construction only when the
/// MC context requests binary-rewrite provenance. The four digest words are an
/// opaque source-issued identity; LLVM never derives source semantics from
/// their numeric value.
inline constexpr StringLiteral
    RewriteWinEHSemanticAttachment("llvm.rewrite.windows-eh.semantic");
inline constexpr uint32_t RewriteWinEHSemanticSchemaVersion = 1;
inline constexpr unsigned RewriteWinEHSemanticOperandCount = 8;

struct RewriteWinEHSemanticToken {
  RewriteWinEHSemanticKind Kind = RewriteWinEHSemanticKind::SEHScope;
  uint32_t Region = 0;
  uint32_t Clause = 0;
  std::array<uint64_t, 4> Digest{};

  friend bool operator==(const RewriteWinEHSemanticToken &Left,
                         const RewriteWinEHSemanticToken &Right) {
    return Left.Kind == Right.Kind && Left.Region == Right.Region &&
           Left.Clause == Right.Clause && Left.Digest == Right.Digest;
  }
  friend bool operator!=(const RewriteWinEHSemanticToken &Left,
                         const RewriteWinEHSemanticToken &Right) {
    return !(Left == Right);
  }
};

/// One source-token to exact final WinEH language-record association. The
/// container identifies the physical table row which makes the record
/// reachable: the SEH scope-table begin or the C++ TryBlockMap row. RecordVA
/// and RecordSize bind the raw action row. Begin/End bind an SEH protected
/// range; HandlerVA binds the SEH action or C++ catch funclet.
struct RewriteWinEHSemanticRecord {
  RewriteWinEHSemanticToken Token;
  std::string SourceFunction;
  std::string OwnerSymbol;
  uint64_t OwnerVA = 0;
  std::string ContainerSymbol;
  uint64_t ContainerVA = 0;
  uint64_t RecordVA = 0;
  uint32_t RecordSize = 0;
  std::string BeginSymbol;
  uint64_t BeginVA = 0;
  std::string EndSymbol;
  uint64_t EndVA = 0;
  std::string HandlerSymbol;
  uint64_t HandlerVA = 0;
  RewriteWinEHSemanticEncoding Encoding = RewriteWinEHSemanticEncoding::SEH;

  friend bool operator==(const RewriteWinEHSemanticRecord &Left,
                         const RewriteWinEHSemanticRecord &Right) {
    return Left.Token == Right.Token &&
           Left.SourceFunction == Right.SourceFunction &&
           Left.OwnerSymbol == Right.OwnerSymbol &&
           Left.OwnerVA == Right.OwnerVA &&
           Left.ContainerSymbol == Right.ContainerSymbol &&
           Left.ContainerVA == Right.ContainerVA &&
           Left.RecordVA == Right.RecordVA &&
           Left.RecordSize == Right.RecordSize &&
           Left.BeginSymbol == Right.BeginSymbol &&
           Left.BeginVA == Right.BeginVA && Left.EndSymbol == Right.EndSymbol &&
           Left.EndVA == Right.EndVA &&
           Left.HandlerSymbol == Right.HandlerSymbol &&
           Left.HandlerVA == Right.HandlerVA && Left.Encoding == Right.Encoding;
  }
  friend bool operator!=(const RewriteWinEHSemanticRecord &Left,
                         const RewriteWinEHSemanticRecord &Right) {
    return !(Left == Right);
  }
};

/// Stable role of one rewrite source-owner receipt.  New roles may be appended
/// without changing the meaning of existing FunctionEntry records.
enum class RewriteSourceFunctionOwnerKind : uint8_t {
  FunctionEntry = 0,
  WinCxxCatchFunclet = 1,
};
static_assert(
    static_cast<uint8_t>(RewriteSourceFunctionOwnerKind::FunctionEntry) == 0 &&
    static_cast<uint8_t>(RewriteSourceFunctionOwnerKind::WinCxxCatchFunclet) ==
        1);

/// Rewrite-only IR markers used to delegate one source function's physical
/// owner to a Windows C++ catch funclet in another IR function.  The source
/// function attribute carries the exact parent IR name; the catchpad metadata
/// attachment carries the exact delegated source IR name.  A delegated
/// source's independently emitted function entry is deliberately not a source
/// receipt.  A producer which retains that helper body must remove its own
/// native EH personality and unwind-table requirement before CodeGen; the
/// authenticated WinCFI owner is the parent function's physical funclet.
inline constexpr StringLiteral
    RewriteWinCxxCatchParentAttribute("llvm.rewrite.win-cxx-catch-parent");
inline constexpr StringLiteral
    RewriteWinCxxCatchSourceAttachment("llvm.rewrite.win-cxx-catch-source");

/// Opt-in for the rewrite-only, bounded C++ EH4 table writer.  The writer
/// validates the exact personality and its supported semantic subset before
/// changing ordinary MSVC C++ emission.
inline constexpr StringLiteral
    RewriteWinCxxFH4Attribute("llvm.rewrite.win-cxx-fh4");

/// Opt-in for a compiler-derived GS wrapper whose cookie slot and checks are
/// regenerated from the final machine frame.  The value names the exact base
/// language writer; unsupported values fail closed.
inline constexpr StringLiteral
    RewriteWinGSHandlerAttribute("llvm.rewrite.win-gs-handler");
inline constexpr StringLiteral RewriteWinGSHandlerCxxFH4("cxx-fh4");

/// One exact IR-definition to final MC-owner association.  SourceFunction is
/// the original IR name and OwnerSymbol is the target-selected symbol spelling;
/// consumers compare both identities exactly and never infer one from the
/// other.
struct RewriteSourceFunctionOwner {
  std::string SourceFunction;
  std::string OwnerSymbol;
  uint64_t OwnerVA = 0;
  bool IsPrivate = false;
  RewriteSourceFunctionOwnerKind Kind =
      RewriteSourceFunctionOwnerKind::FunctionEntry;
  std::string ParentSourceFunction;
};

/// Validate one role-specific source-owner descriptor independently of its MC
/// symbol and collection.  Function entries have no parent.  Windows C++ catch
/// funclets are private, name a distinct non-empty parent, and are validated
/// against that parent's FunctionEntry receipt by the collection validator.
LLVM_ABI bool isValidRewriteSourceFunctionOwnerDescriptor(
    StringRef SourceFunction, bool IsPrivate,
    RewriteSourceFunctionOwnerKind Kind, StringRef ParentSourceFunction);

/// Validate the portable identity constraints of source-owner provenance.
/// Source identities are unique.  Owner addresses need not be unique because
/// zero-sized or folded entries can legally share an address while retaining
/// distinct symbol identities.  A catch-funclet parent must have its own exact
/// FunctionEntry receipt in the same collection.
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

/// Validate portable identity and extent invariants for compiler-emitted WinEH
/// semantic rows. The exact language payload remains a format consumer's job.
LLVM_ABI bool validateRewriteWinEHSemanticRecords(
    ArrayRef<RewriteWinEHSemanticRecord> Records,
    ArrayRef<RewriteSourceFunctionOwner> SourceOwners,
    ArrayRef<RewriteFunctionRange> FunctionRanges,
    const std::map<std::string, uint64_t> &FunctionOwnerAddrs,
    bool ValidateGlobalFunctionRangeOverlap = true);

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
  /// Source-issued WinEH semantic tokens joined to exact compiler-emitted
  /// language table rows.
  std::vector<RewriteWinEHSemanticRecord> WinEHSemanticRecords;
  bool WinEHSemanticsValid = true;
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
