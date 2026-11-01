; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,+xsave -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnux32 -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -mtriple=x86_64-pc-windows-msvc -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -mtriple=x86_64-apple-darwin -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X64
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx,+xsave -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X32
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X32
; RUN: llc -mtriple=i386-pc-windows-msvc -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X32
; RUN: llc -mtriple=i386-apple-darwin -mattr=+sgx,+xsave -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefixes=COMMON,X32
; RUN: llc -enable-new-pm -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,+xsave -O2 -filetype=obj -verify-machineinstrs < %s -o %t.o
; RUN: llc -enable-new-pm -mtriple=i386-unknown-linux-gnu -mattr=+sgx,+xsave -O2 -filetype=obj -verify-machineinstrs < %s -o %t.o
; RUN: llc -mtriple=x86_64-pc-windows-msvc -mattr=+sgx,+xsave -O2 -filetype=obj < %s -o %t.o
; RUN: llc -mtriple=i386-pc-windows-msvc -mattr=+sgx,+xsave -O2 -filetype=obj < %s -o %t.o
; RUN: llc -mtriple=x86_64-apple-darwin -mattr=+sgx,+xsave -O2 -filetype=obj < %s -o %t.o
; RUN: llc -mtriple=i386-apple-darwin -mattr=+sgx,+xsave -O2 -filetype=obj < %s -o %t.o
; RUN: sed 's/i64 4096/i64 4294967296/' %s | not --crash llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx,+xsave 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: sed 's/i64 4096/i64 %%pc/' %s | not opt -passes=verify -disable-output 2>&1 | FileCheck %s --check-prefix=IMMEDIATE
; RUN: opt -S '-passes=default<O2>' < %s | FileCheck %s --check-prefix=IR
; RUN: sed 's/i64 4096/i64 4294971392/' %s | llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,+xsave -O2 | FileCheck %s --check-prefix=WIDE-SITE
; RUN: sed 's/i64 4096/i64 4294971392/' %s | llc -mtriple=x86_64-unknown-linux-gnux32 -mattr=+sgx,+xsave -O2 | FileCheck %s --check-prefix=WIDE-SITE

; WIDTH: ENCLU original site must be a code-width constant
; WIDE-SITE: .quad 4294971392
; IMMEDIATE: immarg operand has non-immediate parameter
; COMMON-LABEL: transfer:
; COMMON: subl $2, %eax
; COMMON-NEXT: cmpl $2, %eax
; COMMON-NEXT: jbe
; COMMON-NEXT: ud2
; X64: xrstor64 (%rsi)
; X64: movq 32(%rax), %rsp
; X64-NEXT: movq (%rax), %rax
; X64-NEXT: jmpq *[[SITE:[a-zA-Z0-9_.]+]](%rip)
; X64-NEXT: .p2align 3
; X64-NEXT: [[SITE]]:
; X64-NEXT: .quad 4096
; X32: xrstor (%esi)
; X32: movl 16(%eax), %esp
; X32-NEXT: movl (%eax), %eax
; X32-NEXT: jmpl *[[SITE:[a-zA-Z0-9_.]+]]
; X32-NEXT: .p2align 2
; X32-NEXT: [[SITE]]:
; X32-NEXT: .long 4096
; COMMON-NOT: ret
; COMMON-NOT: enclu
; COMMON-NOT: #APP
; IR: call void @llvm.x86.enclu.transfer.at.context(ptr %context, i64 4096)
; IR-NEXT: unreachable
; IR: attributes {{.*}}convergent noduplicate noreturn nounwind

declare void @llvm.x86.enclu.transfer.at.context(ptr, i64)
define void @transfer(ptr %context, i32 %count, i64 %pc) "frame-pointer"="all" {
  %frame = alloca i8, i32 %count, align 64
  store volatile i8 17, ptr %frame
  call void @llvm.x86.enclu.transfer.at.context(ptr %context, i64 4096)
  unreachable
}
