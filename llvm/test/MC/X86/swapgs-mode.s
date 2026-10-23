// RUN: llvm-mc -triple x86_64-unknown-unknown --show-encoding %s | FileCheck %s --check-prefix=VALID
// RUN: not llvm-mc -triple i386-unknown-unknown %s 2>&1 | FileCheck %s --check-prefix=INVALID
// RUN: not llvm-mc -triple i386-unknown-none-code16 %s 2>&1 | FileCheck %s --check-prefix=INVALID

// VALID: swapgs
// VALID: encoding: [0x0f,0x01,0xf8]
// INVALID: error: instruction requires: 64-bit mode
swapgs
