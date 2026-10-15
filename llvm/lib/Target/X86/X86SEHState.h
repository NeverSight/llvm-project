//===- X86SEHState.h - SEH state writes -----------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_X86_X86SEHSTATE_H
#define LLVM_LIB_TARGET_X86_X86SEHSTATE_H

namespace llvm {
class Module;
class SDValue;
class SelectionDAG;
class X86Subtarget;

/// Check the complete source contract before any parent's EH pads are lowered.
void validateX86SEHStateWrites(const Module &M);
SDValue lowerX86SEHStateWrite(SDValue Op, SelectionDAG &DAG,
                              const X86Subtarget &Subtarget);
} // namespace llvm

#endif
