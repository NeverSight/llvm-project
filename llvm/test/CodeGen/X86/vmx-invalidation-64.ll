; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.obj
; RUN: llc -mtriple=x86_64-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.macho
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: LLVM ERROR: 64-bit VMX invalidation intrinsic requires 64-bit mode

declare i8 @llvm.x86.invept(i64, ptr)

declare i8 @llvm.x86.invvpid(i64, ptr)

define i8 @invept_status(i64 %type, ptr %descriptor) {
; CHECK-LABEL: invept_status:
; CHECK-NOT: #APP
; CHECK: invept (
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK: ret
  %status = call i8 @llvm.x86.invept(i64 %type, ptr %descriptor)
  ret i8 %status
}

define void @invept_dead(i64 %type, ptr %descriptor) {
; CHECK-LABEL: invept_dead:
; CHECK-NOT: #APP
; CHECK: invept (
; CHECK: ret
  %status = call i8 @llvm.x86.invept(i64 %type, ptr %descriptor)
  ret void
}

define i8 @invvpid_status(i64 %type, ptr %descriptor) {
; CHECK-LABEL: invvpid_status:
; CHECK-NOT: #APP
; CHECK: invvpid (
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK: ret
  %status = call i8 @llvm.x86.invvpid(i64 %type, ptr %descriptor)
  ret i8 %status
}

define void @invvpid_dead(i64 %type, ptr %descriptor) {
; CHECK-LABEL: invvpid_dead:
; CHECK-NOT: #APP
; CHECK: invvpid (
; CHECK: ret
  %status = call i8 @llvm.x86.invvpid(i64 %type, ptr %descriptor)
  ret void
}
