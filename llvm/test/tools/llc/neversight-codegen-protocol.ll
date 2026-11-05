; REQUIRES: x86-registered-target
; RUN: llc --neversight-codegen-protocol | FileCheck %s
; RUN: not llc --neversight-codegen -mtriple=i386 %s -o %t 2>&1 | FileCheck %s --check-prefix=BAD
; CHECK: neversight-codegen-v1 x86
; CHECK-NOT: {{.}}
; BAD: unknown LLVM intrinsic 'llvm.x86.unknown.neverc'

declare void @llvm.x86.unknown.neverc()
define void @invalid() {
  call void @llvm.x86.unknown.neverc()
  ret void
}
