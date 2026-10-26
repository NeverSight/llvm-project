; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes='default<O2>' %t/64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/64.ll -o %t/win64.o
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs -filetype=obj %t/64.ll -o %t/mac64.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes='default<O2>' %t/32.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/32.ll -o %t/win32.o
; RUN: llc -mtriple=i386-apple-darwin -verify-machineinstrs -filetype=obj %t/32.ll -o %t/mac32.o
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/64.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-none-code16 %t/32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/width.ll 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/prefix.ll 2>&1 | FileCheck %s --check-prefix=PREFIX
; RUN: not opt -passes=verify -disable-output %t/dynamic.ll 2>&1 | FileCheck %s --check-prefix=IMM
; MODE: descriptor memory intrinsic does not match the target code mode
; WIDTH: native memory address width is invalid for this code mode
; PREFIX: invalid native memory segment prefix
; IMM: immarg operand has non-immediate parameter

; Offsets are truncated before segment-base addition. A default DS address
; retains its segment regardless of register allocation. Failed queries return
; the supplied prior and actual ZF; dead calls remain instruction-owned reads.

;--- 64.ll
declare { i16, i8 } @llvm.x86.lar.mem16.address(i64, i32, i32, i16)
define { i16, i8 } @lar_mem16(i64 %offset, i16 %prior) {
; X64-LABEL: lar_mem16:
; X64: larw{{[ \t]+}}(%r{{[abcd]}}x),
; X64: larw{{[ \t]+}}%gs:(%e{{[abcd]}}x),
  %dead = call { i16, i8 } @llvm.x86.lar.mem16.address(i64 %offset, i32 64, i32 0, i16 %prior)
  %live = call { i16, i8 } @llvm.x86.lar.mem16.address(i64 %offset, i32 32, i32 101, i16 %prior)
  ret { i16, i8 } %live
}

declare { i32, i8 } @llvm.x86.lar.mem32.address(i64, i32, i32, i32)
define { i32, i8 } @lar_mem32(i64 %offset, i32 %prior) {
; X64-LABEL: lar_mem32:
; X64: larl{{[ \t]+}}(%r{{[abcd]}}x),
; X64: larl{{[ \t]+}}%gs:(%e{{[abcd]}}x),
  %dead = call { i32, i8 } @llvm.x86.lar.mem32.address(i64 %offset, i32 64, i32 0, i32 %prior)
  %live = call { i32, i8 } @llvm.x86.lar.mem32.address(i64 %offset, i32 32, i32 101, i32 %prior)
  ret { i32, i8 } %live
}

declare { i64, i8 } @llvm.x86.lar.mem64.address(i64, i32, i32, i64)
define { i64, i8 } @lar_mem64(i64 %offset, i64 %prior) {
; X64-LABEL: lar_mem64:
; X64: larq{{[ \t]+}}(%r{{[abcd]}}x),
; X64: larq{{[ \t]+}}%gs:(%e{{[abcd]}}x),
  %dead = call { i64, i8 } @llvm.x86.lar.mem64.address(i64 %offset, i32 64, i32 0, i64 %prior)
  %live = call { i64, i8 } @llvm.x86.lar.mem64.address(i64 %offset, i32 32, i32 101, i64 %prior)
  ret { i64, i8 } %live
}

declare { i16, i8 } @llvm.x86.lsl.mem16.address(i64, i32, i32, i16)
define { i16, i8 } @lsl_mem16(i64 %offset, i16 %prior) {
; X64-LABEL: lsl_mem16:
; X64: lslw{{[ \t]+}}(%r{{[abcd]}}x),
; X64: lslw{{[ \t]+}}%gs:(%e{{[abcd]}}x),
  %dead = call { i16, i8 } @llvm.x86.lsl.mem16.address(i64 %offset, i32 64, i32 0, i16 %prior)
  %live = call { i16, i8 } @llvm.x86.lsl.mem16.address(i64 %offset, i32 32, i32 101, i16 %prior)
  ret { i16, i8 } %live
}

declare { i32, i8 } @llvm.x86.lsl.mem32.address(i64, i32, i32, i32)
define { i32, i8 } @lsl_mem32(i64 %offset, i32 %prior) {
; X64-LABEL: lsl_mem32:
; X64: lsll{{[ \t]+}}(%r{{[abcd]}}x),
; X64: lsll{{[ \t]+}}%gs:(%e{{[abcd]}}x),
  %dead = call { i32, i8 } @llvm.x86.lsl.mem32.address(i64 %offset, i32 64, i32 0, i32 %prior)
  %live = call { i32, i8 } @llvm.x86.lsl.mem32.address(i64 %offset, i32 32, i32 101, i32 %prior)
  ret { i32, i8 } %live
}

declare { i64, i8 } @llvm.x86.lsl.mem64.address(i64, i32, i32, i64)
define { i64, i8 } @lsl_mem64(i64 %offset, i64 %prior) {
; X64-LABEL: lsl_mem64:
; X64: lslq{{[ \t]+}}(%r{{[abcd]}}x),
; X64: lslq{{[ \t]+}}%gs:(%e{{[abcd]}}x),
  %dead = call { i64, i8 } @llvm.x86.lsl.mem64.address(i64 %offset, i32 64, i32 0, i64 %prior)
  %live = call { i64, i8 } @llvm.x86.lsl.mem64.address(i64 %offset, i32 32, i32 101, i64 %prior)
  ret { i64, i8 } %live
}

declare void @llvm.x86.lkgs.address(i64, i32, i32)
define void @lkgs(i64 %offset) {
; X64-LABEL: lkgs:
; X64: lkgs{{[ \t]+}}(%r{{[abcd]}}x)
; X64: lkgs{{[ \t]+}}%fs:(%e{{[abcd]}}x)
  call void @llvm.x86.lkgs.address(i64 %offset, i32 64, i32 0)
  call void @llvm.x86.lkgs.address(i64 %offset, i32 32, i32 100)
  ret void
}

;--- 32.ll
declare { i16, i8 } @llvm.x86.lar.mem16.address32(i32, i32, i32, i16)
define { i16, i8 } @lar_mem16(i32 %offset, i16 %prior) {
; X32-LABEL: lar_mem16:
; X32: larw{{[ \t]+}}(%e{{[abcd]}}x),
; X32: larw{{[ \t]+}}%gs:(%{{[sd]}}i),
  %dead = call { i16, i8 } @llvm.x86.lar.mem16.address32(i32 %offset, i32 32, i32 0, i16 %prior)
  %live = call { i16, i8 } @llvm.x86.lar.mem16.address32(i32 %offset, i32 16, i32 101, i16 %prior)
  ret { i16, i8 } %live
}

declare { i32, i8 } @llvm.x86.lar.mem32.address32(i32, i32, i32, i32)
define { i32, i8 } @lar_mem32(i32 %offset, i32 %prior) {
; X32-LABEL: lar_mem32:
; X32: larl{{[ \t]+}}(%e{{[abcd]}}x),
; X32: larl{{[ \t]+}}%gs:(%{{[sd]}}i),
  %dead = call { i32, i8 } @llvm.x86.lar.mem32.address32(i32 %offset, i32 32, i32 0, i32 %prior)
  %live = call { i32, i8 } @llvm.x86.lar.mem32.address32(i32 %offset, i32 16, i32 101, i32 %prior)
  ret { i32, i8 } %live
}

declare { i16, i8 } @llvm.x86.lsl.mem16.address32(i32, i32, i32, i16)
define { i16, i8 } @lsl_mem16(i32 %offset, i16 %prior) {
; X32-LABEL: lsl_mem16:
; X32: lslw{{[ \t]+}}(%e{{[abcd]}}x),
; X32: lslw{{[ \t]+}}%gs:(%{{[sd]}}i),
  %dead = call { i16, i8 } @llvm.x86.lsl.mem16.address32(i32 %offset, i32 32, i32 0, i16 %prior)
  %live = call { i16, i8 } @llvm.x86.lsl.mem16.address32(i32 %offset, i32 16, i32 101, i16 %prior)
  ret { i16, i8 } %live
}

declare { i32, i8 } @llvm.x86.lsl.mem32.address32(i32, i32, i32, i32)
define { i32, i8 } @lsl_mem32(i32 %offset, i32 %prior) {
; X32-LABEL: lsl_mem32:
; X32: lsll{{[ \t]+}}(%e{{[abcd]}}x),
; X32: lsll{{[ \t]+}}%gs:(%{{[sd]}}i),
  %dead = call { i32, i8 } @llvm.x86.lsl.mem32.address32(i32 %offset, i32 32, i32 0, i32 %prior)
  %live = call { i32, i8 } @llvm.x86.lsl.mem32.address32(i32 %offset, i32 16, i32 101, i32 %prior)
  ret { i32, i8 } %live
}

;--- width.ll
declare {i32, i8} @llvm.x86.lsl.mem32.address(i64, i32, i32, i32)
define {i32, i8} @probe(i64 %offset, i32 %width, i32 %prefix, i32 %prior) {
  %value = call {i32, i8} @llvm.x86.lsl.mem32.address(i64 %offset, i32 16, i32 0, i32 %prior)
  ret {i32, i8} %value
}

;--- prefix.ll
declare {i32, i8} @llvm.x86.lsl.mem32.address(i64, i32, i32, i32)
define {i32, i8} @probe(i64 %offset, i32 %width, i32 %prefix, i32 %prior) {
  %value = call {i32, i8} @llvm.x86.lsl.mem32.address(i64 %offset, i32 64, i32 103, i32 %prior)
  ret {i32, i8} %value
}

;--- dynamic.ll
declare {i32, i8} @llvm.x86.lsl.mem32.address(i64, i32, i32, i32)
define {i32, i8} @probe(i64 %offset, i32 %width, i32 %prefix, i32 %prior) {
  %value = call {i32, i8} @llvm.x86.lsl.mem32.address(i64 %offset, i32 %width, i32 %prefix, i32 %prior)
  ret {i32, i8} %value
}

