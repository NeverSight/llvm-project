; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.64.obj
; RUN: llc -mtriple=i686-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.32.obj
; RUN: llc -mtriple=x86_64-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.64.macho
; RUN: llc -mtriple=i386-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.32.macho

declare i64 @llvm.x86.rdmsr(i32)
declare void @llvm.x86.wrmsr(i32, i64)

define i64 @read(i32 %index) {
; CHECK-LABEL: read:
; CHECK-NOT: #APP
; CHECK: rdmsr
; CHECK: ret
  %value = call i64 @llvm.x86.rdmsr(i32 %index)
  ret i64 %value
}

define void @write(i32 %index, i64 %value) {
; CHECK-LABEL: write:
; CHECK-NOT: #APP
; CHECK: wrmsr
; CHECK: ret
  call void @llvm.x86.wrmsr(i32 %index, i64 %value)
  ret void
}

define void @read_dead_result(i32 %index) {
; CHECK-LABEL: read_dead_result:
; CHECK: rdmsr
; CHECK: ret
  %value = call i64 @llvm.x86.rdmsr(i32 %index)
  ret void
}

define void @ordered(i32 %index, i64 %value, ptr %memory) {
; CHECK-LABEL: ordered:
; CHECK: mov
; CHECK: wrmsr
; CHECK: rdmsr
; CHECK: mov
; CHECK: ret
  store i64 %value, ptr %memory, align 1
  call void @llvm.x86.wrmsr(i32 %index, i64 %value)
  %read = call i64 @llvm.x86.rdmsr(i32 %index)
  store i64 %read, ptr %memory, align 1
  ret void
}
