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
  /// variants; for those the result is the VA of an existing stub in the target
  /// binary (resolved by the caller), not a freshly synthesized GOT/PLT entry.
  std::function<std::optional<uint64_t>(StringRef Sym, uint32_t Specifier)>
      resolve;
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

/// Per-image hook: called after every fixup is applied, to mutate the final
/// bytes in place (whole-section checksum / code encryption / ...). Defaults to
/// a no-op when unset.
using ImagePostProcess = std::function<void(MutableArrayRef<RewriteSection>)>;

/// The complete set of knobs for one binary-rewrite emit.
struct RewriteOptions {
  RewriteAddressModel Model;
  FixupTransform onFixup;   // may be empty
  ImagePostProcess onImage; // may be empty
};

/// Result of a binary-rewrite emit.
struct RewriteResult {
  /// Each section's already-fixed-up (and post-onImage) bytes.
  std::vector<RewriteSection> Sections;
  /// Defined symbol -> final VA.
  std::map<std::string, uint64_t> SymbolAddrs;
  /// External symbols that could not be resolved (should be empty on success).
  std::vector<std::string> Unresolved;
};

/// Wrap a target MCAsmBackend with address-model resolution for binary rewrite.
/// The returned backend intercepts evaluateFixup/applyFixup; all other virtuals
/// forward to \p TargetBackend.  \p Opts must outlive the returned backend.
std::unique_ptr<MCAsmBackend>
createAddressModelBackend(std::unique_ptr<MCAsmBackend> TargetBackend,
                          const RewriteOptions &Opts);

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
