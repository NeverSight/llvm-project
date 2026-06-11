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
#include <optional>
#include <string>
#include <vector>

namespace llvm::mc_rewrite {

/// Caller-provided "final address model": where the new code/sections live and
/// where external symbols resolve to in the target binary. Changing the
/// resolution strategy never touches the emitter-side code.
struct RewriteAddressModel {
  /// Final VA of the primary text section.
  uint64_t TextVA = 0;
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
  /// VA of this fixup within the final image.
  uint64_t FixupVA = 0;
  /// Referenced symbol and its specifier (@PLT/@GOT/...), if any.
  StringRef Sym;
  uint32_t Specifier = 0;
  bool IsPCRel = false;
  /// Width in bits of the value field this fixup writes.
  unsigned BitWidth = 0;
};

/// Per-fixup hook: called once \p Value is the final absolute value but before
/// it is bit-packed into the instruction by the ISA encoder. Returns the
/// transformed value. Defaults to identity when unset.
using FixupTransform = std::function<uint64_t(const FixupCtx &, uint64_t Value)>;

/// One emitted section with its final VA and (post fixup) bytes.
struct RewriteSection {
  std::string Name;
  uint64_t VA = 0;
  std::vector<uint8_t> Bytes;
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

} // namespace llvm::mc_rewrite

#endif // LLVM_MC_BINARYREWRITE_H
