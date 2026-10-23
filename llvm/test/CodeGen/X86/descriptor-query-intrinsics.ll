; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/query64.ll | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %t/query64.ll | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes='default<O2>' %t/query64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/query32.ll | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs < %t/query32.ll | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes='default<O2>' %t/query32.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/wrong-mode.ll 2>&1 | FileCheck %s --check-prefix=ERROR
; ERROR: 64-bit descriptor query requires 64-bit mode

; Register and memory queries remain observable when their outputs are dead.
; Runtime result/flag transport is qualified by the cross-compiler completion
; harness in NeverC; these tests also cover both code modes and machine checks.

;--- query64.ll
declare { i16, i8 } @llvm.x86.lar.reg16(i16, i16)
; X64-LABEL: lar_reg16:
; X64-COUNT-2: larw
define { i16, i8 } @lar_reg16(i16 %selector, i16 %prior) {
  %first = call { i16, i8 } @llvm.x86.lar.reg16(i16 %selector, i16 %prior)
  %second = call { i16, i8 } @llvm.x86.lar.reg16(i16 %selector, i16 %prior)
  ret { i16, i8 } %first
}

declare { i16, i8 } @llvm.x86.lar.mem16(ptr, i16)
; X64-LABEL: lar_mem16:
; X64-COUNT-2: larw
define { i16, i8 } @lar_mem16(ptr %selector, i16 %prior) {
  %first = call { i16, i8 } @llvm.x86.lar.mem16(ptr %selector, i16 %prior)
  %second = call { i16, i8 } @llvm.x86.lar.mem16(ptr %selector, i16 %prior)
  ret { i16, i8 } %first
}

declare { i32, i8 } @llvm.x86.lar.reg32(i16, i32)
; X64-LABEL: lar_reg32:
; X64-COUNT-2: larl
define { i32, i8 } @lar_reg32(i16 %selector, i32 %prior) {
  %first = call { i32, i8 } @llvm.x86.lar.reg32(i16 %selector, i32 %prior)
  %second = call { i32, i8 } @llvm.x86.lar.reg32(i16 %selector, i32 %prior)
  ret { i32, i8 } %first
}

declare { i32, i8 } @llvm.x86.lar.mem32(ptr, i32)
; X64-LABEL: lar_mem32:
; X64-COUNT-2: larl
define { i32, i8 } @lar_mem32(ptr %selector, i32 %prior) {
  %first = call { i32, i8 } @llvm.x86.lar.mem32(ptr %selector, i32 %prior)
  %second = call { i32, i8 } @llvm.x86.lar.mem32(ptr %selector, i32 %prior)
  ret { i32, i8 } %first
}

declare { i64, i8 } @llvm.x86.lar.reg64(i16, i64)
; X64-LABEL: lar_reg64:
; X64-COUNT-2: larq
define { i64, i8 } @lar_reg64(i16 %selector, i64 %prior) {
  %first = call { i64, i8 } @llvm.x86.lar.reg64(i16 %selector, i64 %prior)
  %second = call { i64, i8 } @llvm.x86.lar.reg64(i16 %selector, i64 %prior)
  ret { i64, i8 } %first
}

declare { i64, i8 } @llvm.x86.lar.mem64(ptr, i64)
; X64-LABEL: lar_mem64:
; X64-COUNT-2: larq
define { i64, i8 } @lar_mem64(ptr %selector, i64 %prior) {
  %first = call { i64, i8 } @llvm.x86.lar.mem64(ptr %selector, i64 %prior)
  %second = call { i64, i8 } @llvm.x86.lar.mem64(ptr %selector, i64 %prior)
  ret { i64, i8 } %first
}

declare { i16, i8 } @llvm.x86.lsl.reg16(i16, i16)
; X64-LABEL: lsl_reg16:
; X64-COUNT-2: lslw
define { i16, i8 } @lsl_reg16(i16 %selector, i16 %prior) {
  %first = call { i16, i8 } @llvm.x86.lsl.reg16(i16 %selector, i16 %prior)
  %second = call { i16, i8 } @llvm.x86.lsl.reg16(i16 %selector, i16 %prior)
  ret { i16, i8 } %first
}

declare { i16, i8 } @llvm.x86.lsl.mem16(ptr, i16)
; X64-LABEL: lsl_mem16:
; X64-COUNT-2: lslw
define { i16, i8 } @lsl_mem16(ptr %selector, i16 %prior) {
  %first = call { i16, i8 } @llvm.x86.lsl.mem16(ptr %selector, i16 %prior)
  %second = call { i16, i8 } @llvm.x86.lsl.mem16(ptr %selector, i16 %prior)
  ret { i16, i8 } %first
}

declare { i32, i8 } @llvm.x86.lsl.reg32(i16, i32)
; X64-LABEL: lsl_reg32:
; X64-COUNT-2: lsll
define { i32, i8 } @lsl_reg32(i16 %selector, i32 %prior) {
  %first = call { i32, i8 } @llvm.x86.lsl.reg32(i16 %selector, i32 %prior)
  %second = call { i32, i8 } @llvm.x86.lsl.reg32(i16 %selector, i32 %prior)
  ret { i32, i8 } %first
}

declare { i32, i8 } @llvm.x86.lsl.mem32(ptr, i32)
; X64-LABEL: lsl_mem32:
; X64-COUNT-2: lsll
define { i32, i8 } @lsl_mem32(ptr %selector, i32 %prior) {
  %first = call { i32, i8 } @llvm.x86.lsl.mem32(ptr %selector, i32 %prior)
  %second = call { i32, i8 } @llvm.x86.lsl.mem32(ptr %selector, i32 %prior)
  ret { i32, i8 } %first
}

declare { i64, i8 } @llvm.x86.lsl.reg64(i16, i64)
; X64-LABEL: lsl_reg64:
; X64-COUNT-2: lslq
define { i64, i8 } @lsl_reg64(i16 %selector, i64 %prior) {
  %first = call { i64, i8 } @llvm.x86.lsl.reg64(i16 %selector, i64 %prior)
  %second = call { i64, i8 } @llvm.x86.lsl.reg64(i16 %selector, i64 %prior)
  ret { i64, i8 } %first
}

declare { i64, i8 } @llvm.x86.lsl.mem64(ptr, i64)
; X64-LABEL: lsl_mem64:
; X64-COUNT-2: lslq
define { i64, i8 } @lsl_mem64(ptr %selector, i64 %prior) {
  %first = call { i64, i8 } @llvm.x86.lsl.mem64(ptr %selector, i64 %prior)
  %second = call { i64, i8 } @llvm.x86.lsl.mem64(ptr %selector, i64 %prior)
  ret { i64, i8 } %first
}

declare i32 @llvm.x86.lsl(i32)
; X64-LABEL: legacy:
; X64-COUNT-2: lsll
define i32 @legacy(i32 %selector) {
  %first = call i32 @llvm.x86.lsl(i32 %selector)
  %second = call i32 @llvm.x86.lsl(i32 %selector)
  ret i32 %first
}

;--- query32.ll
declare { i16, i8 } @llvm.x86.lar.reg16(i16, i16)
; X32-LABEL: lar_reg16:
; X32-COUNT-2: larw
define { i16, i8 } @lar_reg16(i16 %selector, i16 %prior) {
  %first = call { i16, i8 } @llvm.x86.lar.reg16(i16 %selector, i16 %prior)
  %second = call { i16, i8 } @llvm.x86.lar.reg16(i16 %selector, i16 %prior)
  ret { i16, i8 } %first
}

declare { i16, i8 } @llvm.x86.lar.mem16(ptr, i16)
; X32-LABEL: lar_mem16:
; X32-COUNT-2: larw
define { i16, i8 } @lar_mem16(ptr %selector, i16 %prior) {
  %first = call { i16, i8 } @llvm.x86.lar.mem16(ptr %selector, i16 %prior)
  %second = call { i16, i8 } @llvm.x86.lar.mem16(ptr %selector, i16 %prior)
  ret { i16, i8 } %first
}

declare { i32, i8 } @llvm.x86.lar.reg32(i16, i32)
; X32-LABEL: lar_reg32:
; X32-COUNT-2: larl
define { i32, i8 } @lar_reg32(i16 %selector, i32 %prior) {
  %first = call { i32, i8 } @llvm.x86.lar.reg32(i16 %selector, i32 %prior)
  %second = call { i32, i8 } @llvm.x86.lar.reg32(i16 %selector, i32 %prior)
  ret { i32, i8 } %first
}

declare { i32, i8 } @llvm.x86.lar.mem32(ptr, i32)
; X32-LABEL: lar_mem32:
; X32-COUNT-2: larl
define { i32, i8 } @lar_mem32(ptr %selector, i32 %prior) {
  %first = call { i32, i8 } @llvm.x86.lar.mem32(ptr %selector, i32 %prior)
  %second = call { i32, i8 } @llvm.x86.lar.mem32(ptr %selector, i32 %prior)
  ret { i32, i8 } %first
}

declare { i16, i8 } @llvm.x86.lsl.reg16(i16, i16)
; X32-LABEL: lsl_reg16:
; X32-COUNT-2: lslw
define { i16, i8 } @lsl_reg16(i16 %selector, i16 %prior) {
  %first = call { i16, i8 } @llvm.x86.lsl.reg16(i16 %selector, i16 %prior)
  %second = call { i16, i8 } @llvm.x86.lsl.reg16(i16 %selector, i16 %prior)
  ret { i16, i8 } %first
}

declare { i16, i8 } @llvm.x86.lsl.mem16(ptr, i16)
; X32-LABEL: lsl_mem16:
; X32-COUNT-2: lslw
define { i16, i8 } @lsl_mem16(ptr %selector, i16 %prior) {
  %first = call { i16, i8 } @llvm.x86.lsl.mem16(ptr %selector, i16 %prior)
  %second = call { i16, i8 } @llvm.x86.lsl.mem16(ptr %selector, i16 %prior)
  ret { i16, i8 } %first
}

declare { i32, i8 } @llvm.x86.lsl.reg32(i16, i32)
; X32-LABEL: lsl_reg32:
; X32-COUNT-2: lsll
define { i32, i8 } @lsl_reg32(i16 %selector, i32 %prior) {
  %first = call { i32, i8 } @llvm.x86.lsl.reg32(i16 %selector, i32 %prior)
  %second = call { i32, i8 } @llvm.x86.lsl.reg32(i16 %selector, i32 %prior)
  ret { i32, i8 } %first
}

declare { i32, i8 } @llvm.x86.lsl.mem32(ptr, i32)
; X32-LABEL: lsl_mem32:
; X32-COUNT-2: lsll
define { i32, i8 } @lsl_mem32(ptr %selector, i32 %prior) {
  %first = call { i32, i8 } @llvm.x86.lsl.mem32(ptr %selector, i32 %prior)
  %second = call { i32, i8 } @llvm.x86.lsl.mem32(ptr %selector, i32 %prior)
  ret { i32, i8 } %first
}

declare i32 @llvm.x86.lsl(i32)
; X32-LABEL: legacy:
; X32-COUNT-2: lsll
define i32 @legacy(i32 %selector) {
  %first = call i32 @llvm.x86.lsl(i32 %selector)
  %second = call i32 @llvm.x86.lsl(i32 %selector)
  ret i32 %first
}

;--- wrong-mode.ll
declare { i64, i8 } @llvm.x86.lar.reg64(i16, i64)
define { i64, i8 } @wrong(i16 %selector, i64 %prior) {
  %result = call { i64, i8 } @llvm.x86.lar.reg64(i16 %selector, i64 %prior)
  ret { i64, i8 } %result
}
