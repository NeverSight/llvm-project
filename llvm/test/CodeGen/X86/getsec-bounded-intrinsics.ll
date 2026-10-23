; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=-sgx -O0 -verify-machineinstrs < %t/user64.ll | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes="default<O2>" %t/user64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=-sgx -O0 -verify-machineinstrs < %t/user32.ll | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes="default<O2>" %t/user32.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/user64.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/user32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-none-code16 < %t/user32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not opt -passes=verify -disable-output %t/dynamic.ll 2>&1 | FileCheck %s --check-prefix=IMMEDIATE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/reject1.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/reject2.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/reject3.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/reject4.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/reject5.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/reject9.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/reject4294967295.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/reject9223372041149743106.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; MODE: GETSEC intrinsic does not match the target code mode
; LEAF: bounded GETSEC requires a fallthrough leaf (0, 6..8)
; IMMEDIATE: immarg operand has non-immediate parameter

;--- user64.ll
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
; X64-LABEL: leaf0:
; X64-COUNT-3: getsec
define { i64, i64, i64, i64 } @leaf0(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743104, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743104, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743104, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64 } %result2
}
; X64-LABEL: leaf6:
; X64-COUNT-3: getsec
define { i64, i64, i64, i64 } @leaf6(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743110, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743110, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743110, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64 } %result2
}
; X64-LABEL: leaf7:
; X64-COUNT-3: getsec
define { i64, i64, i64, i64 } @leaf7(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743111, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743111, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743111, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64 } %result2
}
; X64-LABEL: leaf8:
; X64-COUNT-3: getsec
define { i64, i64, i64, i64 } @leaf8(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743112, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743112, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743112, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64 } %result2
}

;--- user32.ll
declare { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32, i32, i32, i32)
; X32-LABEL: leaf0:
; X32-COUNT-3: getsec
define { i32, i32, i32, i32 } @leaf0(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 0, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 0, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 0, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32 } %result2
}
; X32-LABEL: leaf6:
; X32-COUNT-3: getsec
define { i32, i32, i32, i32 } @leaf6(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 6, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 6, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 6, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32 } %result2
}
; X32-LABEL: leaf7:
; X32-COUNT-3: getsec
define { i32, i32, i32, i32 } @leaf7(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 7, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 7, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 7, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32 } %result2
}
; X32-LABEL: leaf8:
; X32-COUNT-3: getsec
define { i32, i32, i32, i32 } @leaf8(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 8, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 8, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32 } @llvm.x86.getsec.bounded32(i32 8, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32 } %result2
}

;--- dynamic.ll
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 %a, i64 0, i64 0, i64 0)
  ret void
}

;--- reject1.ll
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 1, i64 0, i64 0, i64 0)
  ret void
}

;--- reject2.ll
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 2, i64 0, i64 0, i64 0)
  ret void
}

;--- reject3.ll
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 3, i64 0, i64 0, i64 0)
  ret void
}

;--- reject4.ll
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 4, i64 0, i64 0, i64 0)
  ret void
}

;--- reject5.ll
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 5, i64 0, i64 0, i64 0)
  ret void
}

;--- reject9.ll
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9, i64 0, i64 0, i64 0)
  ret void
}

;--- reject4294967295.ll
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 4294967295, i64 0, i64 0, i64 0)
  ret void
}

;--- reject9223372041149743106.ll
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 9223372041149743106, i64 0, i64 0, i64 0)
  ret void
}
