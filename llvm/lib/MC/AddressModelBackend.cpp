//===- AddressModelBackend.cpp - Backend decorator for rewriting ----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// Skeleton implementation of the two rewrite hooks. Both currently forward to
/// the wrapped backend so the decorator is behavior-neutral and links cleanly;
/// the real address-model resolution and per-ISA fixup handling land in a
/// later step.
///
//===----------------------------------------------------------------------===//

#include "AddressModelBackend.h"
#include "llvm/MC/MCObjectWriter.h" // complete MCObjectTargetWriter

using namespace llvm;

std::unique_ptr<MCObjectTargetWriter>
AddressModelBackend::createObjectTargetWriter() const {
  return Wrapped->createObjectTargetWriter();
}

std::optional<bool> AddressModelBackend::evaluateFixup(const MCFragment &F,
                                                       MCFixup &Fixup,
                                                       MCValue &Target,
                                                       uint64_t &Value) {
  syncWrappedAssembler();

  // TODO: resolve Target.getAddSym()/getSubSym() to final VAs via Opts.Model
  //   (TextVA / getSectionVA / resolve), compute the absolute Value (for PC-rel
  //   subtract sectionVA(F) + getFragmentOffset(F) + Fixup.getOffset()), and
  //   return /*IsResolved=*/true. Must first chain the wrapped backend's
  //   evaluateFixup so per-ISA PC-rel pre-adjustment (x86 -4 / GOTPC, ARM32
  //   Thumb AlignDown) is preserved.
  return Wrapped->evaluateFixup(F, Fixup, Target, Value);
}

void AddressModelBackend::applyFixup(const MCFragment &F, const MCFixup &Fixup,
                                     const MCValue &Target, uint8_t *Data,
                                     uint64_t Value, bool IsResolved) {
  syncWrappedAssembler();

  // TODO: for the per-ISA "forced relocation" kinds (AArch64 ADRP page-delta,
  //   ARM32 BL/BLX interworking, @PLT/@GOT specifiers) resolve via Opts.Model
  //   and back-fill directly here instead of letting shouldForceRelocation push
  //   them to a reloc record.
  // TODO: before bit-packing, run Value through Opts.onFixup (if set) with a
  //   FixupCtx so the caller can transform the immediate.
  Wrapped->applyFixup(F, Fixup, Target, Data, Value, IsResolved);
}
