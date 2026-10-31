; RUN: opt -passes='loop(loop-reduce)' -verify-loop-lcssa -verify-each -S %s | FileCheck %s
; RUN: opt -passes='loop-mssa(loop-reduce)' -verify-loop-lcssa -verify-memoryssa -verify-each -S %s | FileCheck %s
; RUN: llc -mtriple=x86_64 --enable-new-pm -verify-machineinstrs -o /dev/null %s
;
; Rewriting the induction variable splits an exit edge shared with an unrelated
; load's PHI. That value also needs an LCSSA PHI in the new exit block, or visiting
; the parent loop observes a broken inner loop. Reduced from the VMRUN guest
; qualification after replacing the intrinsic with an ordinary external call.

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; CHECK-LABEL: define i32 @preserve_other_exit_phi(
; CHECK: [[LOADED:%.*]] = load i64, ptr %input
; CHECK: [[ESCAPING:%.*]] = phi i64 [ [[LOADED]], %inner ]
; CHECK: phi i64 {{.*}}[[ESCAPING]]
; CHECK: ret i32
define i32 @preserve_other_exit_phi(ptr %input, ptr %output, i1 %first,
                                   i1 %second, i1 %restart) {
entry:
  br label %outer

outer:
  br label %inner

inner:
  %iv = phi i64 [ %next, %latch ], [ 0, %outer ]
  %loaded = load i64, ptr %input, align 8
  br i1 %first, label %test, label %exit

exit:
  %value = phi i64 [ %loaded, %inner ], [ 0, %test ]
  store i64 %value, ptr %output, align 8
  %result = trunc i64 %iv to i32
  ret i32 %result

test:
  br i1 %second, label %latch, label %exit

latch:
  %next = add i64 %iv, 1
  br i1 %restart, label %outer, label %inner
}
