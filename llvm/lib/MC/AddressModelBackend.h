//===- AddressModelBackend.h - Backend decorator for rewriting --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// AddressModelBackend is the "resolve seam" of the binary-rewrite emit path.
/// It is a decorator that wraps an arbitrary target MCAsmBackend and overrides
/// only the two hooks that matter for rewriting:
///
///   * evaluateFixup() - resolve external/cross-section symbols to their final
///     VA using the caller-provided RewriteAddressModel and report
///     IsResolved=true, so the stock applyFixup back-fills the bytes and
///     maybeAddReloc records nothing.
///   * applyFixup()    - per-ISA handling for the few "forced relocation" kinds
///     (AArch64 ADRP page-delta, ARM32 BL/BLX interworking, @PLT/@GOT
///     specifiers) plus the per-fixup hook (RewriteOptions::onFixup).
///
/// Every other virtual is forwarded verbatim to the wrapped backend, so no ISA
/// encoding is ever re-implemented here.
///
/// This header is internal to lib/MC. The wiring (the new emit entry +
/// streamer initializer) is added separately and is what other components
/// touch; they do not construct this class directly.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_MC_ADDRESSMODELBACKEND_H
#define LLVM_LIB_MC_ADDRESSMODELBACKEND_H

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/MC/BinaryRewrite.h"
#include "llvm/MC/MCAsmBackend.h"
#include <memory>
#include <optional>

namespace llvm {

/// Decorator backend implementing the rewrite "resolve seam". Owns the wrapped
/// target backend and forwards all but evaluateFixup()/applyFixup() to it.
class AddressModelBackend final : public MCAsmBackend {
  std::unique_ptr<MCAsmBackend> Wrapped;
  // Owned by the caller; must outlive this backend (guaranteed by the wiring
  // that constructs both for the duration of one emit).
  const mc_rewrite::RewriteOptions &Opts;

  // The wrapped backend's own `Asm` member must point at the same MCAssembler
  // as ours: several target hooks read it (maybeAddReloc -> Asm->getWriter()
  // from applyFixup; X86AsmBackend::finishLayout -> Asm->symbols(); etc.).
  // setAssembler() is non-virtual so MCAssembler only ever sets it on *us*, not
  // the wrapped backend; we cannot intercept that call. Instead we mirror it
  // into the wrapped backend before forwarding into any hook that may read Asm.
  // const because the layout-time relaxation hooks are const.
  void syncWrappedAssembler() const { Wrapped->setAssembler(Asm); }

public:
  AddressModelBackend(std::unique_ptr<MCAsmBackend> WrappedBackend,
                      const mc_rewrite::RewriteOptions &Options)
      : MCAsmBackend(WrappedBackend->Endian),
        Wrapped(std::move(WrappedBackend)), Opts(Options) {}

  MCAsmBackend &getWrapped() const { return *Wrapped; }

  bool shouldPreserveSymbolicFixupExpressions() const override {
    return true;
  }

  // —— The two rewrite hooks (implemented in AddressModelBackend.cpp) ——
  std::optional<bool> evaluateFixup(const MCFragment &F, MCFixup &Fixup,
                                    MCValue &Target, uint64_t &Value) override;
  void applyFixup(const MCFragment &F, const MCFixup &Fixup,
                  const MCValue &Target, uint8_t *Data, uint64_t Value,
                  bool IsResolved) override;

  // —— Everything else is forwarded verbatim to the wrapped backend ——
  void reset() override { Wrapped->reset(); }

  // Out-of-line: returning unique_ptr<MCObjectTargetWriter> needs the complete
  // type, which is only forward-declared here.
  std::unique_ptr<MCObjectTargetWriter>
  createObjectTargetWriter() const override;

  std::optional<MCFixupKind> getFixupKind(StringRef Name) const override {
    return Wrapped->getFixupKind(Name);
  }
  MCFixupKindInfo getFixupKindInfo(MCFixupKind Kind) const override {
    return Wrapped->getFixupKindInfo(Kind);
  }

  bool mayNeedRelaxation(unsigned Opcode, ArrayRef<MCOperand> Operands,
                         const MCSubtargetInfo &STI) const override {
    syncWrappedAssembler();
    return Wrapped->mayNeedRelaxation(Opcode, Operands, STI);
  }
  bool fixupNeedsRelaxationAdvanced(const MCFragment &F, const MCFixup &Fixup,
                                    const MCValue &Target, uint64_t Value,
                                    bool Resolved) const override {
    syncWrappedAssembler();
    return Wrapped->fixupNeedsRelaxationAdvanced(F, Fixup, Target, Value,
                                                 Resolved);
  }
  void relaxInstruction(MCInst &Inst,
                        const MCSubtargetInfo &STI) const override {
    syncWrappedAssembler();
    Wrapped->relaxInstruction(Inst, STI);
  }
  bool relaxAlign(MCFragment &F, unsigned &Size) override {
    syncWrappedAssembler();
    return Wrapped->relaxAlign(F, Size);
  }
  bool relaxDwarfLineAddr(MCFragment &F) const override {
    syncWrappedAssembler();
    return Wrapped->relaxDwarfLineAddr(F);
  }
  bool relaxDwarfCFA(MCFragment &F) const override {
    syncWrappedAssembler();
    return Wrapped->relaxDwarfCFA(F);
  }
  bool relaxSFrameCFA(MCFragment &F) const override {
    syncWrappedAssembler();
    return Wrapped->relaxSFrameCFA(F);
  }
  std::pair<bool, bool> relaxLEB128(MCFragment &F,
                                    int64_t &Value) const override {
    syncWrappedAssembler();
    return Wrapped->relaxLEB128(F, Value);
  }

  unsigned getMinimumNopSize() const override {
    return Wrapped->getMinimumNopSize();
  }
  unsigned getMaximumNopSize(const MCSubtargetInfo &STI) const override {
    return Wrapped->getMaximumNopSize(STI);
  }
  bool writeNopData(raw_ostream &OS, uint64_t Count,
                    const MCSubtargetInfo *STI) const override {
    syncWrappedAssembler();
    return Wrapped->writeNopData(OS, Count, STI);
  }

  // X86AsmBackend::finishLayout() walks Asm->symbols() / *Asm, so the wrapped
  // backend must see our assembler first (this was an x86-only crash: AArch64
  // finishLayout does not touch Asm).
  bool finishLayout() const override {
    syncWrappedAssembler();
    return Wrapped->finishLayout();
  }

  uint64_t generateCompactUnwindEncoding(const MCDwarfFrameInfo *FI,
                                         const MCContext *Ctxt) const override {
    syncWrappedAssembler();
    return Wrapped->generateCompactUnwindEncoding(FI, Ctxt);
  }
};

} // namespace llvm

#endif // LLVM_LIB_MC_ADDRESSMODELBACKEND_H
