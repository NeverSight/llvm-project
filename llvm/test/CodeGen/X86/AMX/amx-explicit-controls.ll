; RUN: split-file %s %t
; RUN: llc %t/good.ll -O0 -mtriple=x86_64 -mattr=+amx-tile,+amx-movrs,+amx-avx512,+avx10.2,+egpr -verify-machineinstrs -o - | FileCheck %s
; RUN: llc %t/good.ll -O2 -mtriple=x86_64 -mattr=+amx-tile,+amx-movrs,+amx-avx512,+avx10.2,+egpr -verify-machineinstrs -o - | FileCheck %s
; RUN: not --crash llc %t/width.ll -mtriple=x86_64 -mattr=+amx-tile -o /dev/null 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: not --crash llc %t/prefix.ll -mtriple=x86_64 -mattr=+amx-tile -o /dev/null 2>&1 | FileCheck %s --check-prefix=PREFIX
; RUN: not --crash llc %t/tile.ll -mtriple=x86_64 -mattr=+amx-tile -o /dev/null 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc %t/encoding.ll -mtriple=x86_64 -mattr=+amx-tile -o /dev/null 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc %t/egpr.ll -mtriple=x86_64 -mattr=+amx-tile -o /dev/null 2>&1 | FileCheck %s --check-prefix=EGPR
; RUN: not --crash llc %t/row.ll -mtriple=x86_64 -mattr=+amx-avx512,+avx10.2 -o /dev/null 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc %t/mixed.ll -mtriple=x86_64 -mattr=+amx-tile -o /dev/null 2>&1 | FileCheck %s --check-prefix=MIXED
; CHECK-LABEL: good:
; CHECK: {vex} ldtilecfg %fs:(%e{{[abcd]}}x)
; CHECK: {evex} sttilecfg %gs:(%r{{[abcd]}}x)
; CHECK: {evex} tileloadd %ss:(%e{{[abcd]}}x,%ecx), %tmm7
; CHECK: {vex} tileloaddrst1 (%r{{[abcd]}}x,%rcx), %tmm1
; CHECK: {vex} tilestored %tmm7, %ds:(%r{{[abcd]}}x,%rcx)
; CHECK: tilemovrow %r16d, %tmm7,
; CHECK: tcvtrowd2ps %ecx, %tmm0,
; CHECK: tilemovrow %r16d, %tmm0,
; WIDTH: native memory address width is invalid for this code mode
; PREFIX: invalid native memory segment prefix
; CONTROL: invalid explicit AMX constant control
; EGPR: explicit AMX extended encoding requires egpr
; MIXED: cannot mix physical AMX tile intrinsics with compiler-managed tiles

;--- good.ll
declare void @llvm.x86.ldtilecfg.address(i64, i32, i32, i32)
declare void @llvm.x86.sttilecfg.address(i64, i32, i32, i32)
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
declare void @llvm.x86.tileloaddrst164.address(i8, i64, i64, i32, i32, i32)
declare void @llvm.x86.tilestored64.address(i8, i64, i64, i32, i32, i32)
declare <16 x i32> @llvm.x86.tilemovrow.reg(i8, i32, i32)
declare <16 x float> @llvm.x86.tcvtrowd2ps.reg(i8, i32, i32)
define void @good(i64 %base, i64 %stride, i32 %row, ptr %out) {
  call void @llvm.x86.ldtilecfg.address(i64 %base, i32 32, i32 100, i32 0)
  call void @llvm.x86.sttilecfg.address(i64 %base, i32 64, i32 101, i32 1)
  call void @llvm.x86.tileloadd64.address(i8 7, i64 %base, i64 %stride, i32 32, i32 54, i32 1)
  call void @llvm.x86.tileloaddrst164.address(i8 1, i64 %base, i64 %stride, i32 64, i32 0, i32 0)
  call void @llvm.x86.tilestored64.address(i8 7, i64 %base, i64 %stride, i32 64, i32 62, i32 0)
  %v = call <16 x i32> @llvm.x86.tilemovrow.reg(i8 7, i32 %row, i32 1)
  store <16 x i32> %v, ptr %out, align 1
  %f = call <16 x float> @llvm.x86.tcvtrowd2ps.reg(i8 0, i32 %row, i32 0)
  store <16 x float> %f, ptr %out, align 1
  %zero = call <16 x i32> @llvm.x86.tilemovrow.reg(i8 0, i32 0, i32 1)
  store <16 x i32> %zero, ptr %out, align 1
  ret void
}

;--- width.ll
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
define void @bad(i64 %base, i64 %stride) {
  call void @llvm.x86.tileloadd64.address(i8 0, i64 %base, i64 %stride, i32 16, i32 0, i32 0)
  ret void
}

;--- prefix.ll
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
define void @bad(i64 %base, i64 %stride) {
  call void @llvm.x86.tileloadd64.address(i8 0, i64 %base, i64 %stride, i32 64, i32 1, i32 0)
  ret void
}

;--- tile.ll
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
define void @bad(i64 %base, i64 %stride) {
  call void @llvm.x86.tileloadd64.address(i8 8, i64 %base, i64 %stride, i32 64, i32 0, i32 0)
  ret void
}

;--- encoding.ll
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
define void @bad(i64 %base, i64 %stride) {
  call void @llvm.x86.tileloadd64.address(i8 0, i64 %base, i64 %stride, i32 64, i32 0, i32 2)
  ret void
}

;--- egpr.ll
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
define void @bad(i64 %base, i64 %stride) {
  call void @llvm.x86.tileloadd64.address(i8 0, i64 %base, i64 %stride, i32 64, i32 0, i32 1)
  ret void
}

;--- row.ll
declare <16 x i32> @llvm.x86.tilemovrow.reg(i8, i32, i32)
define void @bad(i32 %row) {
  %v = call <16 x i32> @llvm.x86.tilemovrow.reg(i8 0, i32 %row, i32 2)
  ret void
}

;--- mixed.ll
declare x86_amx @llvm.x86.tileloadd64.internal(i16, i16, ptr, i64)
declare void @llvm.x86.tilestored64.internal(i16, i16, ptr, i64, x86_amx)
declare void @llvm.x86.ldtilecfg.address(i64, i32, i32, i32)
define void @mixed(ptr %input, ptr %output) {
  %tile = call x86_amx @llvm.x86.tileloadd64.internal(i16 2, i16 16, ptr %input, i64 64)
  call void @llvm.x86.ldtilecfg.address(i64 0, i32 64, i32 0, i32 0)
  call void @llvm.x86.tilestored64.internal(i16 2, i16 16, ptr %output, i64 64, x86_amx %tile)
  ret void
}
