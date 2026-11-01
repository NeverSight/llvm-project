; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,+xsave -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnux32 -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -mtriple=x86_64-pc-windows-msvc -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -mtriple=x86_64-apple-darwin -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx,+xsave -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X32
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X32
; RUN: llc -mtriple=i386-pc-windows-msvc -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X32
; RUN: llc -mtriple=i386-apple-darwin -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X32
; RUN: llc -enable-new-pm -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -enable-new-pm -mtriple=i386-unknown-linux-gnu -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X32
; RUN: not --crash llc -mtriple=i386-unknown-linux-code16 -mattr=+sgx,+xsave < %s 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=-sgx,+xsave < %s 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,-xsave < %s 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: opt -S '-passes=default<O2>' < %s | FileCheck %s --check-prefix=IR

; INVALID: ENCLU transfer context requires code32/code64, XSAVE and SGX
; COMMON-LABEL: transfer:
; COMMON: subl $2, %eax
; COMMON-NEXT: cmpl $2, %eax
; COMMON-NEXT: jbe
; COMMON-NEXT: ud2
; X64: xrstor64 (%rsi)
; X64-NEXT: movq %rdi, %rax
; X64-NEXT: pushq 128(%rax)
; X64-NEXT: popfq
; X64-NEXT: movq 8(%rax), %rcx
; X64: movq 120(%rax), %r15
; X64-NEXT: movq 32(%rax), %rsp
; X64-NEXT: movq (%rax), %rax
; X32: xrstor (%esi)
; X32-NEXT: movl %edi, %eax
; X32-NEXT: pushl 32(%eax)
; X32-NEXT: popfl
; X32-NEXT: movl 4(%eax), %ecx
; X32: movl 28(%eax), %edi
; X32-NEXT: movl 16(%eax), %esp
; X32-NEXT: movl (%eax), %eax
; COMMON-NEXT: enclu
; COMMON-NEXT: ud2
; COMMON-NOT: ret
; COMMON-NOT: #APP
; IR: call void @llvm.x86.enclu.transfer.context(ptr %context)
; IR-NEXT: unreachable
; IR: attributes {{.*}}convergent noduplicate noreturn nounwind

declare void @llvm.x86.enclu.transfer.context(ptr)
define void @transfer(ptr %context, i32 %count) "frame-pointer"="all" {
  %frame = alloca i8, i32 %count, align 64
  store volatile i8 17, ptr %frame
  call void @llvm.x86.enclu.transfer.context(ptr %context)
  unreachable
}
