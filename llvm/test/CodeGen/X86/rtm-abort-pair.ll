; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -x86-asm-syntax=att -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -x86-asm-syntax=att -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -enable-new-pm -x86-asm-syntax=att -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -x86-asm-syntax=att -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-apple-darwin -x86-asm-syntax=att -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -x86-asm-syntax=att -verify-machineinstrs < %s | FileCheck %s

declare i32 @llvm.x86.rtm.abort.pair(i32 immarg)

define i32 @pair(i32 %live, ptr %memory) {
; CHECK-LABEL: pair:
; CHECK: movl $71,
; CHECK: xbegin [[ABORT:[.$A-Za-z_0-9]+]]
; CHECK-NEXT: xabort $167
; CHECK-NEXT: [[ABORT]]:
; CHECK: movl $73,
; CHECK: addl
; CHECK: ret
  store i32 71, ptr %memory
  %status = call i32 @llvm.x86.rtm.abort.pair(i32 167)
  store i32 73, ptr %memory
  %result = add i32 %status, %live
  ret i32 %result
}
