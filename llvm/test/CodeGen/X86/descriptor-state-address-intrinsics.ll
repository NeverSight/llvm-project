; RUN: split-file %s %t
; RUN: opt -S -passes='default<O0>' %t/64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs -filetype=obj %t/64.ll -o %t/x86_64-unknown-linux-gnu-0.o
; RUN: opt -S -passes='default<O2>' %t/64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs -filetype=obj %t/64.ll -o %t/x86_64-unknown-linux-gnu-2.o
; RUN: opt -S -passes='default<O0>' %t/64.ll | llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs -filetype=obj %t/64.ll -o %t/x86_64-pc-windows-msvc-0.o
; RUN: opt -S -passes='default<O2>' %t/64.ll | llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs -filetype=obj %t/64.ll -o %t/x86_64-pc-windows-msvc-2.o
; RUN: opt -S -passes='default<O0>' %t/64.ll | llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs -filetype=obj %t/64.ll -o %t/x86_64-apple-darwin-0.o
; RUN: opt -S -passes='default<O2>' %t/64.ll | llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs -filetype=obj %t/64.ll -o %t/x86_64-apple-darwin-2.o
; RUN: opt -S -passes='default<O0>' %t/32.ll | llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs -filetype=obj %t/32.ll -o %t/i386-unknown-linux-gnu-0.o
; RUN: opt -S -passes='default<O2>' %t/32.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs -filetype=obj %t/32.ll -o %t/i386-unknown-linux-gnu-2.o
; RUN: opt -S -passes='default<O0>' %t/32.ll | llc -mtriple=i386-pc-windows-msvc -O0 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-pc-windows-msvc -O0 -verify-machineinstrs -filetype=obj %t/32.ll -o %t/i386-pc-windows-msvc-0.o
; RUN: opt -S -passes='default<O2>' %t/32.ll | llc -mtriple=i386-pc-windows-msvc -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-pc-windows-msvc -O2 -verify-machineinstrs -filetype=obj %t/32.ll -o %t/i386-pc-windows-msvc-2.o
; RUN: opt -S -passes='default<O0>' %t/32.ll | llc -mtriple=i386-apple-darwin -O0 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-apple-darwin -O0 -verify-machineinstrs -filetype=obj %t/32.ll -o %t/i386-apple-darwin-0.o
; RUN: opt -S -passes='default<O2>' %t/32.ll | llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs -filetype=obj %t/32.ll -o %t/i386-apple-darwin-2.o
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/64.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-none-code16 %t/32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/width.ll 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/prefix.ll 2>&1 | FileCheck %s --check-prefix=PREFIX
; RUN: not opt -passes=verify -disable-output %t/dynamic.ll 2>&1 | FileCheck %s --check-prefix=IMM
; MODE: descriptor-state address intrinsic does not match the target code mode
; WIDTH: native memory address width is invalid for this code mode
; PREFIX: invalid native memory segment prefix
; IMM: immarg operand has non-immediate parameter

;--- 64.ll
declare i8 @llvm.x86.verr.mem.address(i64, i32, i32)
define i8 @verr_mem_address(i64 %offset) {
; X64-LABEL: verr_mem_address:
; X64: verr{{[a-z]*}}{{[ \t]+}}(%r{{[abcd]}}x)
  %dead = call i8 @llvm.x86.verr.mem.address(i64 %offset, i32 64, i32 0)
; X64: verr{{[a-z]*}}{{[ \t]+}}%gs:(%e{{[abcd]}}x)
; X64: sete
  %live = call i8 @llvm.x86.verr.mem.address(i64 %offset, i32 32, i32 101)
  ret i8 %live
}

declare i8 @llvm.x86.verw.mem.address(i64, i32, i32)
define i8 @verw_mem_address(i64 %offset) {
; X64-LABEL: verw_mem_address:
; X64: verw{{[a-z]*}}{{[ \t]+}}(%r{{[abcd]}}x)
  %dead = call i8 @llvm.x86.verw.mem.address(i64 %offset, i32 64, i32 0)
; X64: verw{{[a-z]*}}{{[ \t]+}}%gs:(%e{{[abcd]}}x)
; X64: sete
  %live = call i8 @llvm.x86.verw.mem.address(i64 %offset, i32 32, i32 101)
  ret i8 %live
}

declare void @llvm.x86.sldt.mem.address(i64, i32, i32)
define void @sldt_mem_address(i64 %offset) {
; X64-LABEL: sldt_mem_address:
; X64: sldt{{[a-z]*}}{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.sldt.mem.address(i64 %offset, i32 64, i32 0)
; X64: sldt{{[a-z]*}}{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.sldt.mem.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare void @llvm.x86.str.mem.address(i64, i32, i32)
define void @str_mem_address(i64 %offset) {
; X64-LABEL: str_mem_address:
; X64: str{{[a-z]*}}{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.str.mem.address(i64 %offset, i32 64, i32 0)
; X64: str{{[a-z]*}}{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.str.mem.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare void @llvm.x86.smsw.mem.address(i64, i32, i32)
define void @smsw_mem_address(i64 %offset) {
; X64-LABEL: smsw_mem_address:
; X64: smsw{{[a-z]*}}{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.smsw.mem.address(i64 %offset, i32 64, i32 0)
; X64: smsw{{[a-z]*}}{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.smsw.mem.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare void @llvm.x86.lldt.mem.address(i64, i32, i32)
define void @lldt_mem_address(i64 %offset) {
; X64-LABEL: lldt_mem_address:
; X64: lldt{{[a-z]*}}{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.lldt.mem.address(i64 %offset, i32 64, i32 0)
; X64: lldt{{[a-z]*}}{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.lldt.mem.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare void @llvm.x86.ltr.mem.address(i64, i32, i32)
define void @ltr_mem_address(i64 %offset) {
; X64-LABEL: ltr_mem_address:
; X64: ltr{{[a-z]*}}{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.ltr.mem.address(i64 %offset, i32 64, i32 0)
; X64: ltr{{[a-z]*}}{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.ltr.mem.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare void @llvm.x86.lmsw.mem.address(i64, i32, i32)
define void @lmsw_mem_address(i64 %offset) {
; X64-LABEL: lmsw_mem_address:
; X64: lmsw{{[a-z]*}}{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.lmsw.mem.address(i64 %offset, i32 64, i32 0)
; X64: lmsw{{[a-z]*}}{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.lmsw.mem.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare void @llvm.x86.sgdt.address(i64, i32, i32)
define void @sgdt_address(i64 %offset) {
; X64-LABEL: sgdt_address:
; X64: sgdtq{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.sgdt.address(i64 %offset, i32 64, i32 0)
; X64: sgdtq{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.sgdt.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare void @llvm.x86.sidt.address(i64, i32, i32)
define void @sidt_address(i64 %offset) {
; X64-LABEL: sidt_address:
; X64: sidtq{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.sidt.address(i64 %offset, i32 64, i32 0)
; X64: sidtq{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.sidt.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare void @llvm.x86.lgdt.address(i64, i32, i32)
define void @lgdt_address(i64 %offset) {
; X64-LABEL: lgdt_address:
; X64: lgdtq{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.lgdt.address(i64 %offset, i32 64, i32 0)
; X64: lgdtq{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.lgdt.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare void @llvm.x86.lidt.address(i64, i32, i32)
define void @lidt_address(i64 %offset) {
; X64-LABEL: lidt_address:
; X64: lidtq{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.lidt.address(i64 %offset, i32 64, i32 0)
; X64: lidtq{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.lidt.address(i64 %offset, i32 32, i32 101)
  ret void
}

declare void @llvm.x86.invlpg.address(i64, i32, i32)
define void @invlpg_address(i64 %offset) {
; X64-LABEL: invlpg_address:
; X64: invlpg{{[a-z]*}}{{[ \t]+}}(%r{{[abcd]}}x)
  call void @llvm.x86.invlpg.address(i64 %offset, i32 64, i32 0)
; X64: invlpg{{[a-z]*}}{{[ \t]+}}%gs:(%e{{[abcd]}}x)
  call void @llvm.x86.invlpg.address(i64 %offset, i32 32, i32 101)
  ret void
}

;--- 32.ll
declare i8 @llvm.x86.verr.mem.address32(i32, i32, i32)
define i8 @verr_mem_address32(i32 %offset) {
; X32-LABEL: verr_mem_address32:
; X32: verr{{[a-z]*}}{{[ \t]+}}(%e{{[abcd]}}x)
  %dead = call i8 @llvm.x86.verr.mem.address32(i32 %offset, i32 32, i32 0)
; X32: verr{{[a-z]*}}{{[ \t]+}}%gs:(%{{[sd]}}i)
; X32: sete
  %live = call i8 @llvm.x86.verr.mem.address32(i32 %offset, i32 16, i32 101)
  ret i8 %live
}

declare i8 @llvm.x86.verw.mem.address32(i32, i32, i32)
define i8 @verw_mem_address32(i32 %offset) {
; X32-LABEL: verw_mem_address32:
; X32: verw{{[a-z]*}}{{[ \t]+}}(%e{{[abcd]}}x)
  %dead = call i8 @llvm.x86.verw.mem.address32(i32 %offset, i32 32, i32 0)
; X32: verw{{[a-z]*}}{{[ \t]+}}%gs:(%{{[sd]}}i)
; X32: sete
  %live = call i8 @llvm.x86.verw.mem.address32(i32 %offset, i32 16, i32 101)
  ret i8 %live
}

declare void @llvm.x86.sldt.mem.address32(i32, i32, i32)
define void @sldt_mem_address32(i32 %offset) {
; X32-LABEL: sldt_mem_address32:
; X32: sldt{{[a-z]*}}{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.sldt.mem.address32(i32 %offset, i32 32, i32 0)
; X32: sldt{{[a-z]*}}{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.sldt.mem.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.str.mem.address32(i32, i32, i32)
define void @str_mem_address32(i32 %offset) {
; X32-LABEL: str_mem_address32:
; X32: str{{[a-z]*}}{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.str.mem.address32(i32 %offset, i32 32, i32 0)
; X32: str{{[a-z]*}}{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.str.mem.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.smsw.mem.address32(i32, i32, i32)
define void @smsw_mem_address32(i32 %offset) {
; X32-LABEL: smsw_mem_address32:
; X32: smsw{{[a-z]*}}{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.smsw.mem.address32(i32 %offset, i32 32, i32 0)
; X32: smsw{{[a-z]*}}{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.smsw.mem.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.lldt.mem.address32(i32, i32, i32)
define void @lldt_mem_address32(i32 %offset) {
; X32-LABEL: lldt_mem_address32:
; X32: lldt{{[a-z]*}}{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.lldt.mem.address32(i32 %offset, i32 32, i32 0)
; X32: lldt{{[a-z]*}}{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.lldt.mem.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.ltr.mem.address32(i32, i32, i32)
define void @ltr_mem_address32(i32 %offset) {
; X32-LABEL: ltr_mem_address32:
; X32: ltr{{[a-z]*}}{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.ltr.mem.address32(i32 %offset, i32 32, i32 0)
; X32: ltr{{[a-z]*}}{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.ltr.mem.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.lmsw.mem.address32(i32, i32, i32)
define void @lmsw_mem_address32(i32 %offset) {
; X32-LABEL: lmsw_mem_address32:
; X32: lmsw{{[a-z]*}}{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.lmsw.mem.address32(i32 %offset, i32 32, i32 0)
; X32: lmsw{{[a-z]*}}{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.lmsw.mem.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.sgdt.address32(i32, i32, i32)
define void @sgdt_address32(i32 %offset) {
; X32-LABEL: sgdt_address32:
; X32: sgdtl{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.sgdt.address32(i32 %offset, i32 32, i32 0)
; X32: sgdtl{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.sgdt.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.sidt.address32(i32, i32, i32)
define void @sidt_address32(i32 %offset) {
; X32-LABEL: sidt_address32:
; X32: sidtl{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.sidt.address32(i32 %offset, i32 32, i32 0)
; X32: sidtl{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.sidt.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.lgdt.address32(i32, i32, i32)
define void @lgdt_address32(i32 %offset) {
; X32-LABEL: lgdt_address32:
; X32: lgdtl{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.lgdt.address32(i32 %offset, i32 32, i32 0)
; X32: lgdtl{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.lgdt.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.lidt.address32(i32, i32, i32)
define void @lidt_address32(i32 %offset) {
; X32-LABEL: lidt_address32:
; X32: lidtl{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.lidt.address32(i32 %offset, i32 32, i32 0)
; X32: lidtl{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.lidt.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.invlpg.address32(i32, i32, i32)
define void @invlpg_address32(i32 %offset) {
; X32-LABEL: invlpg_address32:
; X32: invlpg{{[a-z]*}}{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.invlpg.address32(i32 %offset, i32 32, i32 0)
; X32: invlpg{{[a-z]*}}{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.invlpg.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.sgdt16.address32(i32, i32, i32)
define void @sgdt16_address32(i32 %offset) {
; X32-LABEL: sgdt16_address32:
; X32: sgdtw{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.sgdt16.address32(i32 %offset, i32 32, i32 0)
; X32: sgdtw{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.sgdt16.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.sidt16.address32(i32, i32, i32)
define void @sidt16_address32(i32 %offset) {
; X32-LABEL: sidt16_address32:
; X32: sidtw{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.sidt16.address32(i32 %offset, i32 32, i32 0)
; X32: sidtw{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.sidt16.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.lgdt16.address32(i32, i32, i32)
define void @lgdt16_address32(i32 %offset) {
; X32-LABEL: lgdt16_address32:
; X32: lgdtw{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.lgdt16.address32(i32 %offset, i32 32, i32 0)
; X32: lgdtw{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.lgdt16.address32(i32 %offset, i32 16, i32 101)
  ret void
}

declare void @llvm.x86.lidt16.address32(i32, i32, i32)
define void @lidt16_address32(i32 %offset) {
; X32-LABEL: lidt16_address32:
; X32: lidtw{{[ \t]+}}(%e{{[abcd]}}x)
  call void @llvm.x86.lidt16.address32(i32 %offset, i32 32, i32 0)
; X32: lidtw{{[ \t]+}}%gs:(%{{[sd]}}i)
  call void @llvm.x86.lidt16.address32(i32 %offset, i32 16, i32 101)
  ret void
}

;--- width.ll
declare void @llvm.x86.lgdt.address(i64, i32, i32)
define void @invalid(i64 %offset, i32 %width) {
  call void @llvm.x86.lgdt.address(i64 %offset, i32 16, i32 0)
  ret void
}

;--- prefix.ll
declare void @llvm.x86.lgdt.address(i64, i32, i32)
define void @invalid(i64 %offset, i32 %width) {
  call void @llvm.x86.lgdt.address(i64 %offset, i32 64, i32 1)
  ret void
}

;--- dynamic.ll
declare void @llvm.x86.lgdt.address(i64, i32, i32)
define void @invalid(i64 %offset, i32 %width) {
  call void @llvm.x86.lgdt.address(i64 %offset, i32 %width, i32 0)
  ret void
}

