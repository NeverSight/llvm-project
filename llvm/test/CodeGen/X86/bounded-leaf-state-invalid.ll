; RUN: split-file %s %t
; BAD: bounded leaf state requires a constant fallthrough leaf
; IMM: immarg operand has non-immediate parameter
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/enclu-2.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/enclu-3.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/enclu-4.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/enclu-12.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/enclu-4294967295.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not opt -passes=verify -disable-output %t/enclu-dynamic.ll 2>&1 | FileCheck %s --check-prefix=IMM
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/getsec-1.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/getsec-2.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/getsec-3.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/getsec-4.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/getsec-5.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/getsec-9.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/getsec-4294967295.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not opt -passes=verify -disable-output %t/getsec-dynamic.ll 2>&1 | FileCheck %s --check-prefix=IMM

;--- enclu-2.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 2, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- enclu-3.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 3, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- enclu-4.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 4, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- enclu-12.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 12, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- enclu-4294967295.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 4294967295, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- enclu-dynamic.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 %leaf, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- getsec-1.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 1, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- getsec-2.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 2, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- getsec-3.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 3, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- getsec-4.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 4, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- getsec-5.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 5, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- getsec-9.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 9, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- getsec-4294967295.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 4294967295, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- getsec-dynamic.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64, i64, i64, i64, i16)
define void @bad(i64 %leaf) {
  call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 %leaf, i64 0, i64 0, i64 0, i16 0)
  ret void
}
