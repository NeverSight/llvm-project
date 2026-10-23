; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes="default<O2>" %t/64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/64.ll -o %t/64-pc-windows-msvc.o
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs -filetype=obj %t/64.ll -o %t/64-apple-darwin.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes="default<O2>" %t/32.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/32.ll -o %t/32-pc-windows-msvc.o
; RUN: llc -mtriple=i386-apple-darwin -verify-machineinstrs -filetype=obj %t/32.ll -o %t/32-apple-darwin.o
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/64.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-none-code16 %t/32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/width16.ll 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/width64.ll 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/width0.ll 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/prefix67.ll 2>&1 | FileCheck %s --check-prefix=PREFIX
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/prefixlock.ll 2>&1 | FileCheck %s --check-prefix=PREFIX
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/negative.ll 2>&1 | FileCheck %s --check-prefix=PREFIX
; RUN: not opt -passes=verify -disable-output %t/dynamic_width.ll 2>&1 | FileCheck %s --check-prefix=IMM
; RUN: not opt -passes=verify -disable-output %t/dynamic_segment.ll 2>&1 | FileCheck %s --check-prefix=IMM
; MODE: VMX address intrinsic does not match the target code mode
; WIDTH: native memory address width is invalid for this code mode
; PREFIX: invalid native memory segment prefix
; IMM: immarg operand has non-immediate parameter

;--- 64.ll
declare i8 @llvm.x86.vmread.address(i64, i64, i32, i32)
define i8 @vmread(i64 %selector, i64 %offset) {
; X64-LABEL: vmread:
; X64-COUNT-2: vmread
  %status0 = call i8 @llvm.x86.vmread.address(i64 %selector, i64 %offset, i32 64, i32 0)
  %status1 = call i8 @llvm.x86.vmread.address(i64 %selector, i64 %offset, i32 32, i32 100)
  ret i8 %status1
}

declare i8 @llvm.x86.vmwrite.mem.address(i64, i64, i32, i32)
define i8 @vmwrite_mem(i64 %selector, i64 %offset) {
; X64-LABEL: vmwrite_mem:
; X64-COUNT-2: vmwrite
  %status0 = call i8 @llvm.x86.vmwrite.mem.address(i64 %selector, i64 %offset, i32 64, i32 0)
  %status1 = call i8 @llvm.x86.vmwrite.mem.address(i64 %selector, i64 %offset, i32 32, i32 100)
  ret i8 %status1
}

declare i8 @llvm.x86.invept.address(i64, i64, i32, i32)
define i8 @invept(i64 %selector, i64 %offset) {
; X64-LABEL: invept:
; X64-COUNT-2: invept
  %status0 = call i8 @llvm.x86.invept.address(i64 %selector, i64 %offset, i32 64, i32 0)
  %status1 = call i8 @llvm.x86.invept.address(i64 %selector, i64 %offset, i32 32, i32 100)
  ret i8 %status1
}

declare i8 @llvm.x86.invvpid.address(i64, i64, i32, i32)
define i8 @invvpid(i64 %selector, i64 %offset) {
; X64-LABEL: invvpid:
; X64-COUNT-2: invvpid
  %status0 = call i8 @llvm.x86.invvpid.address(i64 %selector, i64 %offset, i32 64, i32 0)
  %status1 = call i8 @llvm.x86.invvpid.address(i64 %selector, i64 %offset, i32 32, i32 100)
  ret i8 %status1
}

declare i8 @llvm.x86.vmclear.address(i64, i32, i32)
define i8 @vmclear(i64 %selector, i64 %offset) {
; X64-LABEL: vmclear:
; X64-COUNT-2: vmclear
  %status0 = call i8 @llvm.x86.vmclear.address(i64 %offset, i32 64, i32 0)
  %status1 = call i8 @llvm.x86.vmclear.address(i64 %offset, i32 32, i32 101)
  ret i8 %status1
}

declare i8 @llvm.x86.vmptrld.address(i64, i32, i32)
define i8 @vmptrld(i64 %selector, i64 %offset) {
; X64-LABEL: vmptrld:
; X64-COUNT-2: vmptrld
  %status0 = call i8 @llvm.x86.vmptrld.address(i64 %offset, i32 64, i32 0)
  %status1 = call i8 @llvm.x86.vmptrld.address(i64 %offset, i32 32, i32 101)
  ret i8 %status1
}

declare void @llvm.x86.vmptrst.address(i64, i32, i32)
define void @vmptrst(i64 %selector, i64 %offset) {
; X64-LABEL: vmptrst:
; X64-COUNT-2: vmptrst
  call void @llvm.x86.vmptrst.address(i64 %offset, i32 64, i32 0)
  call void @llvm.x86.vmptrst.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare i8 @llvm.x86.vmxon.address(i64, i32, i32)
define i8 @vmxon(i64 %selector, i64 %offset) {
; X64-LABEL: vmxon:
; X64-COUNT-2: vmxon
  %status0 = call i8 @llvm.x86.vmxon.address(i64 %offset, i32 64, i32 0)
  %status1 = call i8 @llvm.x86.vmxon.address(i64 %offset, i32 32, i32 101)
  ret i8 %status1
}

;--- 32.ll
declare i8 @llvm.x86.vmread.address32(i32, i32, i32, i32)
define i8 @vmread(i32 %selector, i32 %offset) {
; X32-LABEL: vmread:
; X32-COUNT-2: vmread
  %status0 = call i8 @llvm.x86.vmread.address32(i32 %selector, i32 %offset, i32 32, i32 0)
  %status1 = call i8 @llvm.x86.vmread.address32(i32 %selector, i32 %offset, i32 16, i32 100)
  ret i8 %status1
}

declare i8 @llvm.x86.vmwrite.mem.address32(i32, i32, i32, i32)
define i8 @vmwrite_mem(i32 %selector, i32 %offset) {
; X32-LABEL: vmwrite_mem:
; X32-COUNT-2: vmwrite
  %status0 = call i8 @llvm.x86.vmwrite.mem.address32(i32 %selector, i32 %offset, i32 32, i32 0)
  %status1 = call i8 @llvm.x86.vmwrite.mem.address32(i32 %selector, i32 %offset, i32 16, i32 100)
  ret i8 %status1
}

declare i8 @llvm.x86.invept.address32(i32, i32, i32, i32)
define i8 @invept(i32 %selector, i32 %offset) {
; X32-LABEL: invept:
; X32-COUNT-2: invept
  %status0 = call i8 @llvm.x86.invept.address32(i32 %selector, i32 %offset, i32 32, i32 0)
  %status1 = call i8 @llvm.x86.invept.address32(i32 %selector, i32 %offset, i32 16, i32 100)
  ret i8 %status1
}

declare i8 @llvm.x86.invvpid.address32(i32, i32, i32, i32)
define i8 @invvpid(i32 %selector, i32 %offset) {
; X32-LABEL: invvpid:
; X32-COUNT-2: invvpid
  %status0 = call i8 @llvm.x86.invvpid.address32(i32 %selector, i32 %offset, i32 32, i32 0)
  %status1 = call i8 @llvm.x86.invvpid.address32(i32 %selector, i32 %offset, i32 16, i32 100)
  ret i8 %status1
}

declare i8 @llvm.x86.vmclear.address32(i32, i32, i32)
define i8 @vmclear(i32 %selector, i32 %offset) {
; X32-LABEL: vmclear:
; X32-COUNT-2: vmclear
  %status0 = call i8 @llvm.x86.vmclear.address32(i32 %offset, i32 32, i32 0)
  %status1 = call i8 @llvm.x86.vmclear.address32(i32 %offset, i32 16, i32 101)
  ret i8 %status1
}

declare i8 @llvm.x86.vmptrld.address32(i32, i32, i32)
define i8 @vmptrld(i32 %selector, i32 %offset) {
; X32-LABEL: vmptrld:
; X32-COUNT-2: vmptrld
  %status0 = call i8 @llvm.x86.vmptrld.address32(i32 %offset, i32 32, i32 0)
  %status1 = call i8 @llvm.x86.vmptrld.address32(i32 %offset, i32 16, i32 101)
  ret i8 %status1
}

declare void @llvm.x86.vmptrst.address32(i32, i32, i32)
define void @vmptrst(i32 %selector, i32 %offset) {
; X32-LABEL: vmptrst:
; X32-COUNT-2: vmptrst
  call void @llvm.x86.vmptrst.address32(i32 %offset, i32 32, i32 0)
  call void @llvm.x86.vmptrst.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare i8 @llvm.x86.vmxon.address32(i32, i32, i32)
define i8 @vmxon(i32 %selector, i32 %offset) {
; X32-LABEL: vmxon:
; X32-COUNT-2: vmxon
  %status0 = call i8 @llvm.x86.vmxon.address32(i32 %offset, i32 32, i32 0)
  %status1 = call i8 @llvm.x86.vmxon.address32(i32 %offset, i32 16, i32 101)
  ret i8 %status1
}

;--- width16.ll
declare i8 @llvm.x86.vmread.address(i64, i64, i32, i32)
define i8 @probe(i64 %field, i64 %offset, i32 %control) {
  %status = call i8 @llvm.x86.vmread.address(i64 %field, i64 %offset, i32 16, i32 0)
  ret i8 %status
}

;--- width64.ll
declare i8 @llvm.x86.vmread.address32(i32, i32, i32, i32)
define i8 @probe(i32 %field, i32 %offset, i32 %control) {
  %status = call i8 @llvm.x86.vmread.address32(i32 %field, i32 %offset, i32 64, i32 0)
  ret i8 %status
}

;--- width0.ll
declare i8 @llvm.x86.vmread.address(i64, i64, i32, i32)
define i8 @probe(i64 %field, i64 %offset, i32 %control) {
  %status = call i8 @llvm.x86.vmread.address(i64 %field, i64 %offset, i32 0, i32 0)
  ret i8 %status
}

;--- prefix67.ll
declare i8 @llvm.x86.vmread.address(i64, i64, i32, i32)
define i8 @probe(i64 %field, i64 %offset, i32 %control) {
  %status = call i8 @llvm.x86.vmread.address(i64 %field, i64 %offset, i32 64, i32 103)
  ret i8 %status
}

;--- prefixlock.ll
declare i8 @llvm.x86.vmread.address(i64, i64, i32, i32)
define i8 @probe(i64 %field, i64 %offset, i32 %control) {
  %status = call i8 @llvm.x86.vmread.address(i64 %field, i64 %offset, i32 32, i32 240)
  ret i8 %status
}

;--- negative.ll
declare i8 @llvm.x86.vmread.address32(i32, i32, i32, i32)
define i8 @probe(i32 %field, i32 %offset, i32 %control) {
  %status = call i8 @llvm.x86.vmread.address32(i32 %field, i32 %offset, i32 32, i32 -1)
  ret i8 %status
}

;--- dynamic_width.ll
declare i8 @llvm.x86.vmread.address(i64, i64, i32, i32)
define i8 @probe(i64 %field, i64 %offset, i32 %control) {
  %status = call i8 @llvm.x86.vmread.address(i64 %field, i64 %offset, i32 %control, i32 0)
  ret i8 %status
}

;--- dynamic_segment.ll
declare i8 @llvm.x86.vmread.address(i64, i64, i32, i32)
define i8 @probe(i64 %field, i64 %offset, i32 %control) {
  %status = call i8 @llvm.x86.vmread.address(i64 %field, i64 %offset, i32 64, i32 %control)
  ret i8 %status
}
