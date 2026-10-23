; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx -O0 -verify-machineinstrs < %t/user64.ll | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes="default<O2>" %t/user64.ll | llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx < %t/user64.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx -O0 -verify-machineinstrs < %t/user32.ll | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes="default<O2>" %t/user32.ll | llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx < %t/user32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-none-code16 -mattr=+sgx < %t/user32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=-sgx < %t/user64.ll 2>&1 | FileCheck %s --check-prefix=FEATURE
; RUN: not opt -passes=verify -disable-output %t/dynamic.ll 2>&1 | FileCheck %s --check-prefix=IMMEDIATE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx < %t/reject2.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx < %t/reject3.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx < %t/reject4.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx < %t/reject12.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx < %t/reject4294967295.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx < %t/reject9305357563761524738.ll 2>&1 | FileCheck %s --check-prefix=LEAF
; MODE: SGX intrinsic does not match the target code mode
; FEATURE: SGX intrinsic requires the sgx target feature
; LEAF: bounded ENCLU requires a fallthrough leaf (0, 1, 5..11)
; IMMEDIATE: immarg operand has non-immediate parameter

;--- user64.ll
declare { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64, i64, i64, i64)
; X64-LABEL: leaf0:
; X64-COUNT-3: enclu
define { i64, i64, i64, i64, i8 } @leaf0(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524736, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524736, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524736, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result2
}
; X64-LABEL: leaf1:
; X64-COUNT-3: enclu
define { i64, i64, i64, i64, i8 } @leaf1(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524737, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524737, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524737, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result2
}
; X64-LABEL: leaf5:
; X64-COUNT-3: enclu
define { i64, i64, i64, i64, i8 } @leaf5(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524741, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524741, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524741, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result2
}
; X64-LABEL: leaf6:
; X64-COUNT-3: enclu
define { i64, i64, i64, i64, i8 } @leaf6(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524742, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524742, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524742, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result2
}
; X64-LABEL: leaf7:
; X64-COUNT-3: enclu
define { i64, i64, i64, i64, i8 } @leaf7(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524743, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524743, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524743, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result2
}
; X64-LABEL: leaf8:
; X64-COUNT-3: enclu
define { i64, i64, i64, i64, i8 } @leaf8(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524744, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524744, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524744, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result2
}
; X64-LABEL: leaf9:
; X64-COUNT-3: enclu
define { i64, i64, i64, i64, i8 } @leaf9(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524745, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524745, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524745, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result2
}
; X64-LABEL: leaf10:
; X64-COUNT-3: enclu
define { i64, i64, i64, i64, i8 } @leaf10(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524746, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524746, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524746, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result2
}
; X64-LABEL: leaf11:
; X64-COUNT-3: enclu
define { i64, i64, i64, i64, i8 } @leaf11(i64 %b, i64 %c, i64 %d) {
  %result0 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524747, i64 %b, i64 %c, i64 %d)
  %result1 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524747, i64 %b, i64 %c, i64 %d)
  %result2 = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524747, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result2
}

;--- user32.ll
declare { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32, i32, i32, i32)
; X32-LABEL: leaf0:
; X32-COUNT-3: enclu
define { i32, i32, i32, i32, i8 } @leaf0(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 0, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 0, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 0, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result2
}
; X32-LABEL: leaf1:
; X32-COUNT-3: enclu
define { i32, i32, i32, i32, i8 } @leaf1(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 1, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 1, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 1, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result2
}
; X32-LABEL: leaf5:
; X32-COUNT-3: enclu
define { i32, i32, i32, i32, i8 } @leaf5(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 5, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 5, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 5, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result2
}
; X32-LABEL: leaf6:
; X32-COUNT-3: enclu
define { i32, i32, i32, i32, i8 } @leaf6(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 6, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 6, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 6, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result2
}
; X32-LABEL: leaf7:
; X32-COUNT-3: enclu
define { i32, i32, i32, i32, i8 } @leaf7(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 7, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 7, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 7, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result2
}
; X32-LABEL: leaf8:
; X32-COUNT-3: enclu
define { i32, i32, i32, i32, i8 } @leaf8(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 8, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 8, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 8, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result2
}
; X32-LABEL: leaf9:
; X32-COUNT-3: enclu
define { i32, i32, i32, i32, i8 } @leaf9(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 9, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 9, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 9, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result2
}
; X32-LABEL: leaf10:
; X32-COUNT-3: enclu
define { i32, i32, i32, i32, i8 } @leaf10(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 10, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 10, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 10, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result2
}
; X32-LABEL: leaf11:
; X32-COUNT-3: enclu
define { i32, i32, i32, i32, i8 } @leaf11(i32 %b, i32 %c, i32 %d) {
  %result0 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 11, i32 %b, i32 %c, i32 %d)
  %result1 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 11, i32 %b, i32 %c, i32 %d)
  %result2 = call { i32, i32, i32, i32, i8 } @llvm.x86.enclu.bounded32(i32 11, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result2
}

;--- dynamic.ll
declare { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 %a, i64 0, i64 0, i64 0)
  ret void
}

;--- reject2.ll
declare { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 2, i64 0, i64 0, i64 0)
  ret void
}

;--- reject3.ll
declare { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 3, i64 0, i64 0, i64 0)
  ret void
}

;--- reject4.ll
declare { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 4, i64 0, i64 0, i64 0)
  ret void
}

;--- reject12.ll
declare { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 12, i64 0, i64 0, i64 0)
  ret void
}

;--- reject4294967295.ll
declare { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 4294967295, i64 0, i64 0, i64 0)
  ret void
}

;--- reject9305357563761524738.ll
declare { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64, i64, i64, i64)
define void @probe(i64 %a) {
  call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 9305357563761524738, i64 0, i64 0, i64 0)
  ret void
}
