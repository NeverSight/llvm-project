; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+avx10.1-256,-evex512 -verify-machineinstrs < %s 2>%t | FileCheck %s
; RUN: FileCheck %s --check-prefix=NO-WARNING --allow-empty < %t

; Older NeverC/LLVM IR spells AVX10.1 as avx10.1-256. The separate
; evex512 feature still controls vector width; accepting the alias must
; preserve instruction availability without a discarded-feature warning.
; NO-WARNING-NOT: recognized
; NO-WARNING-NOT: warning
; CHECK-LABEL: add:
; CHECK: vpaddd
define <8 x i32> @add(<8 x i32> %a, <8 x i32> %b) {
  %r = add <8 x i32> %a, %b
  ret <8 x i32> %r
}
