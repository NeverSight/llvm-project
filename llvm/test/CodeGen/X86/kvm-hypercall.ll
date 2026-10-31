; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64 -O0 -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64 -O2 -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64 -O0 --enable-new-pm -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64 -O2 --enable-new-pm -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=i386 -O0 -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386 -O2 -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386 -O0 --enable-new-pm -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386 -O2 --enable-new-pm -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=x86_64-windows-msvc -filetype=obj -verify-machineinstrs %t/64.ll -o %t/win64.obj
; RUN: llc -mtriple=x86_64-apple-darwin -filetype=obj -verify-machineinstrs %t/64.ll -o %t/mac64.o
; RUN: llc -mtriple=i386-windows-msvc -filetype=obj -verify-machineinstrs %t/32.ll -o %t/win32.obj
; RUN: llc -mtriple=i386-apple-darwin -filetype=obj -verify-machineinstrs %t/32.ll -o %t/mac32.o
; RUN: not --crash llc -mtriple=i386 %t/64.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64 %t/32.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-none-code16 %t/32.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: opt -passes='default<O2>' -S %t/64.ll -o - | FileCheck %s --check-prefix=EFFECT
;
; MODE: KVM hypercall intrinsic does not match target code mode
; EFFECT-LABEL: define void @effects
; EFFECT: store i64 7,
; EFFECT-NEXT: {{.*}}call i64 @llvm.x86.vmcall.kvm
; EFFECT-NEXT: store i64 9,
; EFFECT-NEXT: {{.*}}call i64 @llvm.x86.vmmcall.kvm
;
; X64-LABEL: vmx:
; X64-DAG: movl $1, %eax
; X64-DAG: movl $2, %ebx
; X64-DAG: movl $3, %ecx
; X64-DAG: movl $4, %edx
; X64-DAG: movl $5, %esi
; X64: vmcall
; X64: retq
; X64-LABEL: svm:
; X64: vmmcall
; X64: retq
;
; X32-LABEL: vmx:
; X32-DAG: movl $1, %eax
; X32-DAG: movl $2, %ebx
; X32-DAG: movl $3, %ecx
; X32-DAG: movl $4, %edx
; X32-DAG: movl $5, %esi
; X32: vmcall
; X32: retl
; X32-LABEL: svm:
; X32: vmmcall
; X32: retl

;--- 64.ll
declare i64 @llvm.x86.vmcall.kvm(i64, i64, i64, i64, i64)
declare i64 @llvm.x86.vmmcall.kvm(i64, i64, i64, i64, i64)
define i64 @vmx() noinline optnone {
  %r = call i64 @llvm.x86.vmcall.kvm(i64 1, i64 2, i64 3, i64 4, i64 5)
  ret i64 %r
}
define i64 @svm(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e) {
  %r = call i64 @llvm.x86.vmmcall.kvm(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e)
  ret i64 %r
}
define void @effects(ptr %p) {
  store i64 7, ptr %p
  call i64 @llvm.x86.vmcall.kvm(i64 1, i64 2, i64 3, i64 4, i64 5)
  store i64 9, ptr %p
  call i64 @llvm.x86.vmmcall.kvm(i64 1, i64 2, i64 3, i64 4, i64 5)
  ret void
}

;--- 32.ll
declare i32 @llvm.x86.vmcall.kvm32(i32, i32, i32, i32, i32)
declare i32 @llvm.x86.vmmcall.kvm32(i32, i32, i32, i32, i32)
define i32 @vmx() noinline optnone {
  %r = call i32 @llvm.x86.vmcall.kvm32(i32 1, i32 2, i32 3, i32 4, i32 5)
  ret i32 %r
}
define i32 @svm(i32 %a, i32 %b, i32 %c, i32 %d, i32 %e) {
  %r = call i32 @llvm.x86.vmmcall.kvm32(i32 %a, i32 %b, i32 %c, i32 %d, i32 %e)
  ret i32 %r
}
