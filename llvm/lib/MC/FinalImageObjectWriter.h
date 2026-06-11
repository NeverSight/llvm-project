//===- FinalImageObjectWriter.h - Object writer for rewriting --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// FinalImageObjectWriter is the "output seam" of the binary-rewrite emit path.
/// Unlike the format-specific object writers (ELF/MachO/COFF), it does not emit
/// a relocatable container: by the time writeObject() runs, every fixup has
/// already been resolved and back-filled by AddressModelBackend, so this writer
/// simply assembles each section's final bytes (at their final VA) into the
/// RewriteResult, then runs the per-image hook (RewriteOptions::onImage).
///
/// recordRelocation() is a backstop: after the resolve seam there should be no
/// unresolved fixups, so anything reaching here is collected into
/// RewriteResult::Unresolved for the caller to inspect.
///
/// This header is internal to lib/MC.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_MC_FINALIMAGEOBJECTWRITER_H
#define LLVM_LIB_MC_FINALIMAGEOBJECTWRITER_H

#include "llvm/MC/BinaryRewrite.h"
#include "llvm/MC/MCObjectWriter.h"
#include <cstdint>

namespace llvm {

/// Object writer that emits a fully fixed-up image instead of a relocatable
/// object file. Writes its output into the caller-owned RewriteResult.
class FinalImageObjectWriter final : public MCObjectWriter {
  const mc_rewrite::RewriteOptions &Opts;
  mc_rewrite::RewriteResult &Out;

public:
  FinalImageObjectWriter(const mc_rewrite::RewriteOptions &Options,
                         mc_rewrite::RewriteResult &Result)
      : Opts(Options), Out(Result) {}

  // After the resolve seam there should be nothing to record; collect any
  // residual into Out.Unresolved as a backstop.
  void recordRelocation(const MCFragment &F, const MCFixup &Fixup,
                        MCValue Target, uint64_t &FixedValue) override;

  // Assemble each section's final (already fixed-up) bytes at its final VA into
  // Out.Sections, populate Out.SymbolAddrs, then run Opts.onImage.
  uint64_t writeObject() override;
};

} // namespace llvm

#endif // LLVM_LIB_MC_FINALIMAGEOBJECTWRITER_H
