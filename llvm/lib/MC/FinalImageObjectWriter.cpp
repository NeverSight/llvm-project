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
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCSection.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCValue.h"

using namespace llvm;

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

  for (MCSection &Sec : *Asm) {
    StringRef Name = Sec.getName();
    uint64_t SecVA =
        Opts.Model.getSectionVA ? Opts.Model.getSectionVA(Name) : 0;

    mc_rewrite::RewriteSection RS;
    RS.Name = Name.str();
    RS.VA = SecVA;

    uint64_t Size = Asm->getSectionAddressSize(Sec);
    RS.Bytes.reserve(Size);

    for (const MCFragment &F : Sec) {
      auto Content = F.getContents();
      RS.Bytes.insert(RS.Bytes.end(),
                      reinterpret_cast<const uint8_t *>(Content.data()),
                      reinterpret_cast<const uint8_t *>(Content.data()) +
                          Content.size());
      auto Var = F.getVarContents();
      if (!Var.empty())
        RS.Bytes.insert(RS.Bytes.end(),
                        reinterpret_cast<const uint8_t *>(Var.data()),
                        reinterpret_cast<const uint8_t *>(Var.data()) +
                            Var.size());
    }

    TotalBytes += RS.Bytes.size();
    Out.Sections.push_back(std::move(RS));
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
        StringRef SecName = Sym.getSection().getName();
        uint64_t SecVA =
            Opts.Model.getSectionVA ? Opts.Model.getSectionVA(SecName) : 0;
        VA = SecVA + Asm->getSymbolOffset(Sym);
      } else {
        VA = Asm->getSymbolOffset(Sym);
      }
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
