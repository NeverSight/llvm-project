; RUN: split-file %s %t
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/control32.ll | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes='default<O2>' %t/control32.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/control64.ll | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes='default<O2>' %t/control64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/control32.ll 2>&1 | FileCheck %s --check-prefix=ERROR
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/control64.ll 2>&1 | FileCheck %s --check-prefix=ERROR
; ERROR: TLBSYNC intrinsic does not match the target code mode

; EnhancedTlbi interprets the complete rAX control word. Reserved bits must
; reach the instruction, not be masked into an apparently successful request.
; The no-argument compatibility API selects CPU-only synchronization, rAX = 0.

;--- control32.ll
declare void @llvm.x86.tlbsync()
declare void @llvm.x86.tlbsync.control32(i32)

; X32-LABEL: control32:
; X32: movl {{.*}}, %eax
; X32: tlbsync
; X32: tlbsync
; X32: retl
define i32 @control32(i32 %control, ptr %memory) {
  store i32 %control, ptr %memory
  call void @llvm.x86.tlbsync.control32(i32 %control)
  call void @llvm.x86.tlbsync.control32(i32 %control)
  %result = load i32, ptr %memory
  ret i32 %result
}

; X32-LABEL: reserved32:
; X32: movl $-1, %eax
; X32: tlbsync
; X32: retl
define void @reserved32() {
  call void @llvm.x86.tlbsync.control32(i32 -1)
  ret void
}

; X32-LABEL: compatibility32:
; X32: {{(xorl|movl)}} {{.*}}%eax
; X32: tlbsync
; X32: retl
define void @compatibility32() {
  call void @llvm.x86.tlbsync()
  ret void
}

;--- control64.ll
declare void @llvm.x86.tlbsync()
declare void @llvm.x86.tlbsync.control64(i64)

; X64-LABEL: control64:
; X64: movq %rdi, %rax
; X64: tlbsync
; X64: tlbsync
; X64: retq
define i64 @control64(i64 %control, ptr %memory) {
  store i64 %control, ptr %memory
  call void @llvm.x86.tlbsync.control64(i64 %control)
  call void @llvm.x86.tlbsync.control64(i64 %control)
  %result = load i64, ptr %memory
  ret i64 %result
}

; X64-LABEL: reserved64:
; X64: movabsq $-9223372036854775807, %rax
; X64: tlbsync
; X64: retq
define void @reserved64() {
  call void @llvm.x86.tlbsync.control64(i64 -9223372036854775807)
  ret void
}

; X64-LABEL: compatibility64:
; X64: {{(xorl|movl)}} {{.*}}%eax
; X64: tlbsync
; X64: retq
define void @compatibility64() {
  call void @llvm.x86.tlbsync()
  ret void
}
