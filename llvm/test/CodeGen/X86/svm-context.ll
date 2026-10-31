; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs %t/valid.ll -o %t/out.s
; RUN: FileCheck %s --check-prefix=ASM < %t/out.s
; RUN: llc --enable-new-pm -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs %t/valid.ll -o - | FileCheck %s --check-prefix=ASM
; RUN: llvm-mc -triple=x86_64-unknown-linux-gnu -filetype=obj %t/out.s -o %t/out.o
; RUN: llvm-objdump -d %t/out.o | FileCheck %s --check-prefix=BYTES
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/valid.ll -o %t/win.obj
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs -filetype=obj %t/valid.ll -o %t/mac.o
; RUN: opt -S '-passes=default<O2>' %t/valid.ll | FileCheck %s --check-prefix=IR
; RUN: not --crash llc -mtriple=i386 %t/valid.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64 %t/bad-width.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: not --crash llc -mtriple=x86_64 %t/bundles.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BUNDLE
;
; Preserve the returning continuation and memory observations even when no
; scalar call result exists. The runtime SVM test qualifies all fourteen GPRs,
; x87 and YMM values, caller frames and both VM-exit intercepts.
; ASM-LABEL: __llvm_x86_vmrun_context:
; ASM: xsave64
; ASM: xrstor64
; ASM: vmrun
; ASM: xsave64
; ASM: xrstor64
; ASM: retq
; BYTES: 0f 01 d8
; BYTES: 67 0f 01 d8
; IR: store volatile i32 1
; IR: call void @llvm.x86.vmrun.context(ptr %context, i32 64)
; IR: store volatile i32 2
; IR: call void @llvm.x86.vmrun.context(ptr %context, i32 32)
; IR: load volatile i32
; MODE: VMRUN context requires an isolated 64-bit helper
; WIDTH: VMRUN context address width must be 32 or 64
; BUNDLE: VMRUN context does not support operand bundles

;--- valid.ll
declare void @llvm.x86.vmrun.context(ptr, i32 immarg)
define i32 @run(ptr %context, ptr %marker) "frame-pointer"="all" {
  store volatile i32 1, ptr %marker
  call void @llvm.x86.vmrun.context(ptr %context, i32 64)
  store volatile i32 2, ptr %marker
  call void @llvm.x86.vmrun.context(ptr %context, i32 32)
  %result = load volatile i32, ptr %marker
  ret i32 %result
}

;--- bad-width.ll
declare void @llvm.x86.vmrun.context(ptr, i32 immarg)
define void @run(ptr %context) {
  call void @llvm.x86.vmrun.context(ptr %context, i32 16)
  ret void
}

;--- bundles.ll
declare void @llvm.x86.vmrun.context(ptr, i32 immarg)
define void @run(ptr %context) {
  call void @llvm.x86.vmrun.context(ptr %context, i32 64) [ "deopt"(i32 1) ]
  ret void
}
