// RUN: llvm-mc -triple=arm64e-apple-macos -mattr=+pauth-lr -filetype=obj %S/Inputs/compact-pauth-lr.def -o %t
// RUN: llvm-objdump --macho --unwind-info %t | FileCheck %s
// RUN: llvm-mc -triple=arm64-apple-macos -mattr=+pauth-lr -filetype=obj %S/Inputs/compact-pauth-lr.def -o %t.plain
// RUN: llvm-objdump --macho --unwind-info %t.plain | FileCheck %s --check-prefix=PLAIN

// Zero, nonzero and maximum signing-PC offsets, including saved GPR/D pairs.
// CHECK: compact encoding:     0x05000000
// CHECK: compact encoding:     0x05002101
// CHECK: compact encoding:     0x05fff000
// Overflow, missing B key, frameless, repeated state, no preceding instruction,
// misaligned PC, noncanonical frame and unresolved alignment retain DWARF.
// CHECK-COUNT-8: compact encoding:     0x03000000
// PLAIN-COUNT-11: compact encoding:     0x03000000
