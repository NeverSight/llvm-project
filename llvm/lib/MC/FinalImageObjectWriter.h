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
/// a relocatable container: AddressModelBackend back-fills every fixup it can
/// resolve, and this writer assembles the resulting section bytes at their
/// final VAs before running the per-image hook (RewriteOptions::onImage).
///
/// recordRelocation() separates target-forced relocations from undefined
/// externals that the address model could not resolve. Each such external is
/// collected once in RewriteResult::Unresolved for the caller to inspect.
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

  // Collect genuinely unresolved external components once; ignore relocations
  // forced for symbols whose final address is already known.
  void recordRelocation(const MCFragment &F, const MCFixup &Fixup,
                        MCValue Target, uint64_t &FixedValue) override;

  // Assemble each section's resulting bytes at its final VA into Out.Sections,
  // populate Out.SymbolAddrs, then run Opts.onImage.
  uint64_t writeObject() override;
};

} // namespace llvm

#endif // LLVM_LIB_MC_FINALIMAGEOBJECTWRITER_H
