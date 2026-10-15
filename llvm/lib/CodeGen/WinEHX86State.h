//===- WinEHX86State.h - Rewrite-owned x86 SEH states -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_CODEGEN_WINEHX86STATE_H
#define LLVM_LIB_CODEGEN_WINEHX86STATE_H

namespace llvm {
class Function;
struct WinEHFuncInfo;

/// Preserve source state comparisons before assigning invoke and async states.
void orderWinX86SEHRewriteStates(const Function &F, WinEHFuncInfo &Info);
} // namespace llvm

#endif
