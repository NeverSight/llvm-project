; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 --enable-new-pm -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 --enable-new-pm -verify-machineinstrs < %s | FileCheck %s

; Rewriting tied operands is mandatory even when optnone disables optimization.
; Skipping the pass leaves different virtual registers tied together and crashes
; the fast register allocator. This includes constant operations at -O0.

define i64 @constant_and() noinline optnone {
; CHECK-LABEL: constant_and:
; CHECK: retq
  %value = and i64 0, 0
  ret i64 %value
}

define i64 @variable_and(i64 %left, i64 %right) noinline optnone {
; CHECK-LABEL: variable_and:
; CHECK: andq
; CHECK: retq
  %value = and i64 %left, %right
  ret i64 %value
}
