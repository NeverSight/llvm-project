; RUN: llc -mtriple=x86_64-unknown-linux-gnux32 -mattr=+xsave -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+xsave -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+xsave -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -mattr=+xsave -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-apple-darwin -mattr=+xsave -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -enable-new-pm -mtriple=x86_64-unknown-linux-gnu -mattr=+xsave -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu -mattr=+xsave < %s 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=-xsave < %s 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: opt -S '-passes=default<O2>' < %s | FileCheck %s --check-prefix=IR

; INVALID: RSM context requires 64-bit mode and XSAVE
; CHECK-LABEL: transfer:
; CHECK: movq {{.*}}, %r10
; CHECK-NEXT: movq 16(%r10), %rax
; CHECK-NEXT: movq %rax, %cr2
; CHECK-NEXT: movq 24(%r10), %rax
; CHECK-NEXT: movq %rax, %cr8
; CHECK-NEXT: movl 32(%r10), %eax
; CHECK-NEXT: movl 36(%r10), %edx
; CHECK-NEXT: movl $3221225730, %ecx
; CHECK-NEXT: wrmsr
; CHECK-NEXT: movq (%r10), %r11
; CHECK-NEXT: movl 8(%r10), %eax
; CHECK-NEXT: movl 12(%r10), %edx
; CHECK-NEXT: xrstor64 (%r11)
; CHECK-NEXT: rsm
; CHECK-NOT: ret
; CHECK-NOT: #APP
; IR: call void @llvm.x86.rsm.context(ptr %context)
; IR-NEXT: unreachable
; IR: attributes {{.*}}convergent noduplicate noreturn nounwind

declare void @llvm.x86.rsm.context(ptr)
define void @transfer(ptr %context, i64 %count) "frame-pointer"="all" {
  %frame = alloca i8, i64 %count, align 64
  store volatile i8 17, ptr %frame
  call void @llvm.x86.rsm.context(ptr %context)
  unreachable
}
