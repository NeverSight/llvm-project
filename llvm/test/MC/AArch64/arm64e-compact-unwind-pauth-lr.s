// RUN: llvm-mc -triple=arm64e-apple-macos -mattr=+pauth-lr -filetype=obj %S/Inputs/compact-pauth-lr.def -o %t
// RUN: llvm-objdump --macho --unwind-info %t | FileCheck %s
// RUN: llvm-mc -triple=arm64-apple-macos -mattr=+pauth-lr -filetype=obj %S/Inputs/compact-pauth-lr.def -o %t.plain
// RUN: llvm-objdump --macho --unwind-info %t.plain | FileCheck %s --check-prefix=PLAIN

// A signing instruction at the function entry has a compact object encoding.
// CHECK: compact encoding:     0x05000000
// Nonzero and maximum offsets are final-image encodings. Regular object
// emission retains DWARF because external linkers may discard their PC rule.
// Overflow, missing B key, frameless, repeated state, no preceding instruction,
// misaligned PC, noncanonical frame and unresolved alignment retain DWARF.
// CHECK-COUNT-10: compact encoding:     0x03000000
// PLAIN-COUNT-11: compact encoding:     0x03000000
