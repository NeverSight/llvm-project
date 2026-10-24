; RUN: split-file %s %t
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sahf %t/element.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sahf %t/address.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sahf %t/segment.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sahf %t/repeat.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sahf %t/port-width.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=i386 -mattr=+sahf %t/narrow-width.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not opt -passes=verify -disable-output %t/dynamic.ll 2>&1 | FileCheck %s --check-prefix=IMM
; BAD: invalid explicit REP element, address, segment or repeat control
; IMM: immarg operand has non-immediate parameter

;--- element.ll
declare { i64, i64, i64 } @llvm.x86.rep.movs.state(i64, i64, i64, i8, i32, i32, i32)
define void @bad(i32 %control) {
  call { i64, i64, i64 } @llvm.x86.rep.movs.state(i64 0, i64 0, i64 0, i8 0, i32 3, i32 64, i32 0)
  ret void
}

;--- address.ll
declare { i64, i64, i64 } @llvm.x86.rep.movs.state(i64, i64, i64, i8, i32, i32, i32)
define void @bad(i32 %control) {
  call { i64, i64, i64 } @llvm.x86.rep.movs.state(i64 0, i64 0, i64 0, i8 0, i32 1, i32 16, i32 0)
  ret void
}

;--- segment.ll
declare { i64, i64, i64 } @llvm.x86.rep.movs.state(i64, i64, i64, i8, i32, i32, i32)
define void @bad(i32 %control) {
  call { i64, i64, i64 } @llvm.x86.rep.movs.state(i64 0, i64 0, i64 0, i8 0, i32 1, i32 64, i32 1)
  ret void
}

;--- repeat.ll
declare { i64, i64, i64, i16 } @llvm.x86.rep.cmps.state(i64, i64, i64, i8, i16, i32, i32, i32, i32)
define void @bad(i32 %control) {
  call { i64, i64, i64, i16 } @llvm.x86.rep.cmps.state(i64 0, i64 0, i64 0, i8 0, i16 0, i32 1, i32 64, i32 0, i32 2)
  ret void
}

;--- port-width.ll
declare { i64, i64 } @llvm.x86.rep.ins.state(i64, i64, i16, i8, i32, i32)
define void @bad(i32 %control) {
  call { i64, i64 } @llvm.x86.rep.ins.state(i64 0, i64 0, i16 0, i8 0, i32 8, i32 64)
  ret void
}

;--- narrow-width.ll
declare { i32, i32, i32 } @llvm.x86.rep.lods.state32(i32, i32, i32, i8, i32, i32, i32)
define void @bad(i32 %control) {
  call { i32, i32, i32 } @llvm.x86.rep.lods.state32(i32 0, i32 0, i32 0, i8 0, i32 8, i32 32, i32 0)
  ret void
}

;--- dynamic.ll
declare { i64, i64, i64 } @llvm.x86.rep.movs.state(i64, i64, i64, i8, i32, i32, i32)
define void @bad(i32 %control) {
  call { i64, i64, i64 } @llvm.x86.rep.movs.state(i64 0, i64 0, i64 0, i8 0, i32 %control, i32 64, i32 0)
  ret void
}
