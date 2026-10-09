//===- WinEHFrame.h - Rewrite frame objects ----------------------*- C++
//-*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_IR_WINEHFRAME_H
#define LLVM_IR_WINEHFRAME_H

#include "llvm/ADT/StringRef.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/Error.h"
#include <cstdint>

namespace llvm {
class AllocaInst;
class CatchPadInst;
class Function;

/// Rewrite-only PE32 FH3 catch objects can share one static frame allocation.
/// The catchpad object operand remains the whole alloca. Its subfield carries
/// {i32 1, i32 byte_offset, i32 size} under this attachment. Keeping the static
/// alloca operand preserves ordinary catchpad address and escape invariants.
/// The verifier and CodeGen use the same bounded offset/extent check. This
/// marker alone does not authenticate source object identity or authorize
/// rewriting.
inline constexpr StringLiteral
    RewriteWinX86CxxFrameAttribute("llvm.rewrite.win-x86-cxx-frame");
inline constexpr StringLiteral RewriteWinX86CxxCatchObjectAttachment(
    "llvm.rewrite.win-x86-cxx-catch-object");

struct RewriteWinX86CxxCatchFrameObject {
  const AllocaInst *Frame = nullptr;
  uint32_t Offset = 0;
  uint32_t Size = 0;
};

/// Check the exact target, personality, definition and attribute spelling.
LLVM_ABI Error validateRewriteWinX86CxxFrame(const Function &F);

/// Resolve a static allocation and its checked metadata subfield. A null
/// object has a null Frame and zero Size. Dynamic/non-alloca objects, malformed
/// offsets/extents and objects outside the allocation fail explicitly.
LLVM_ABI Expected<RewriteWinX86CxxCatchFrameObject>
getRewriteWinX86CxxCatchFrameObject(const CatchPadInst &CPI);

} // namespace llvm
#endif
