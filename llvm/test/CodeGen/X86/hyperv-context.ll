; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -enable-new-pm -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -enable-new-pm -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj < %s -o %t.obj
; RUN: llc -mtriple=x86_64-apple-darwin -filetype=obj < %s -o %t.o
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: Hyper-V context requires 64-bit mode

declare void @llvm.x86.hyperv.call(ptr, ptr, ptr, i32 immarg) convergent noduplicate nounwind

define void @run(ptr %entry, ptr %gpr, ptr %xmm) {
; CHECK-LABEL: run:
; CHECK: movq 8(%r10), %rcx
; CHECK: movq 16(%r10), %rdx
; CHECK: movq 64(%r10), %r8
; CHECK: movups (%r11), %xmm0
; CHECK: movups 80(%r11), %xmm5
; CHECK: callq *%r9
; CHECK-NEXT: movq %rax, (%r10)
; CHECK-NEXT: movq %rcx, 8(%r10)
; CHECK-NEXT: movq %rdx, 16(%r10)
; CHECK-NEXT: movq %r8, 64(%r10)
; CHECK: movups %xmm5, 80(%r11)
; CHECK: retq
  call void @llvm.x86.hyperv.call(ptr %entry, ptr %gpr, ptr %xmm, i32 16)
  ret void
}

define void @optnone(ptr %entry, ptr %gpr, ptr %xmm) noinline optnone {
  call void @llvm.x86.hyperv.call(ptr %entry, ptr %gpr, ptr %xmm, i32 64)
  ret void
}
