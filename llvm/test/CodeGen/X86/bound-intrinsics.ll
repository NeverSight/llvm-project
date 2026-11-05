; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes='default<O2>' %s | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-code16 -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes='default<O2>' %s | llc -mtriple=i386-unknown-linux-code16 -O2 -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -stop-after=finalize-isel -verify-machineinstrs < %s | FileCheck %s --check-prefix=MIR
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: sed 's/i32 16, i32 100/i32 64, i32 100/' %s | not --crash llc -mtriple=i386-unknown-linux-gnu 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: sed 's/i32 16, i32 100/i32 16, i32 256/' %s | not --crash llc -mtriple=i386-unknown-linux-gnu 2>&1 | FileCheck %s --check-prefix=PREFIX
; WIDTH: native memory address width is invalid for this code mode
; PREFIX: invalid native memory segment prefix or stack-reference control
; MODE: BOUND intrinsic requires 16- or 32-bit code mode

declare void @llvm.x86.bound16(i16, ptr)
declare void @llvm.x86.bound32(i32, ptr)
declare void @llvm.x86.bound16.address32(i16, i32, i32 immarg, i32 immarg)
declare void @llvm.x86.bound32.address32(i32, i32, i32 immarg, i32 immarg)

; CHECK-LABEL: check16:
; CHECK: bound %{{[a-z]+}}, (
; CHECK: ret
; MIR-LABEL: name: check16
; MIR-NOT: = BOUNDS
; MIR: BOUNDS16rm
; MIR-NOT: implicit-def $eflags
define i16 @check16(i16 %index, ptr %bounds) {
  call void @llvm.x86.bound16(i16 %index, ptr %bounds)
  ret i16 %index
}

; CHECK-LABEL: check32:
; CHECK: bound %{{e[a-z]+}}, (
; CHECK: ret
; MIR-LABEL: name: check32
; MIR-NOT: = BOUNDS
; MIR: BOUNDS32rm
; MIR-NOT: implicit-def $eflags
define i32 @check32(i32 %index, ptr %bounds) {
  call void @llvm.x86.bound32(i32 %index, ptr %bounds)
  ret i32 %index
}

; CHECK-LABEL: narrow:
; CHECK: bound %{{[a-z]+}}, %fs:(%{{[a-z][a-z]}})
; CHECK: bound %{{e[a-z]+}}, %ss:(%{{[a-z][a-z]}})
; CHECK: ret
; MIR-LABEL: name: narrow
; MIR-NOT: = BOUNDS
; MIR: BOUNDS16rm_ADDR16
; MIR: BOUNDS32rm_ADDR16
define void @narrow(i16 %word, i32 %dword, i32 %offset) {
  call void @llvm.x86.bound16.address32(i16 %word, i32 %offset, i32 16, i32 100)
  call void @llvm.x86.bound32.address32(i32 %dword, i32 %offset, i32 16, i32 54)
  ret void
}

; CHECK-LABEL: ordered:
; CHECK: bound
; CHECK: bound
; CHECK: ret
; MIR-LABEL: name: ordered
; MIR-NOT: = BOUNDS
; MIR: BOUNDS32rm
; MIR: BOUNDS32rm
define void @ordered(i32 %index, ptr %bounds) {
  call void @llvm.x86.bound32(i32 %index, ptr %bounds)
  call void @llvm.x86.bound32(i32 %index, ptr %bounds)
  ret void
}
