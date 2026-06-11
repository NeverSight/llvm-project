//===- FinalImageObjectWriter.cpp - Object writer for rewriting -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// Skeleton implementation of the output seam. writeObject() is stubbed to
/// return 0 for now; the real image assembly (walk MCAssembler sections, copy
/// getContents() to each final VA, fill SymbolAddrs, run onImage) lands in a
/// later step.
///
//===----------------------------------------------------------------------===//

#include "FinalImageObjectWriter.h"
#include "llvm/MC/MCValue.h" // complete MCValue for the by-value parameter

using namespace llvm;

void FinalImageObjectWriter::recordRelocation(const MCFragment &F,
                                              const MCFixup &Fixup,
                                              MCValue Target,
                                              uint64_t &FixedValue) {
  // TODO: the resolve seam should have made every fixup resolved, so reaching
  //   here means a residual unresolved reference. Record it in Out.Unresolved
  //   (with a symbol name) for the caller to surface.
}

uint64_t FinalImageObjectWriter::writeObject() {
  // TODO: for each section, copy the layout()-fixed getContents() bytes into
  //   Out.Sections at getSectionVA(name); populate Out.SymbolAddrs from defined
  //   symbols; finally run Opts.onImage(Out.Sections). Return the number of
  //   bytes written.
  return 0;
}
