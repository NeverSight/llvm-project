; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx -O0 -verify-machineinstrs < %t/sgx64.ll | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes='default<O2>' %t/sgx64.ll | llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx < %t/sgx64.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx -O0 -verify-machineinstrs < %t/sgx32.ll | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes='default<O2>' %t/sgx32.ll | llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx < %t/sgx32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=-sgx < %t/sgx64.ll 2>&1 | FileCheck %s --check-prefix=FEATURE
; MODE: SGX intrinsic does not match the target code mode
; FEATURE: SGX intrinsic requires the sgx target feature

;--- sgx64.ll

declare { i64, i64, i64, i64, i8 } @llvm.x86.encls(i64, i64, i64, i64)
; X64-LABEL: probe_encls:
; X64-COUNT-3: encls
define { i64, i64, i64, i64, i8 } @probe_encls(i64 %a, i64 %b, i64 %c, i64 %d) {
  call { i64, i64, i64, i64, i8 } @llvm.x86.encls(i64 %a, i64 %b, i64 %c, i64 %d)
  call { i64, i64, i64, i64, i8 } @llvm.x86.encls(i64 %a, i64 %b, i64 %c, i64 %d)
  %result = call { i64, i64, i64, i64, i8 } @llvm.x86.encls(i64 %a, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result
}

declare { i64, i64, i64, i64, i8 } @llvm.x86.enclv(i64, i64, i64, i64)
; X64-LABEL: probe_enclv:
; X64-COUNT-3: enclv
define { i64, i64, i64, i64, i8 } @probe_enclv(i64 %a, i64 %b, i64 %c, i64 %d) {
  call { i64, i64, i64, i64, i8 } @llvm.x86.enclv(i64 %a, i64 %b, i64 %c, i64 %d)
  call { i64, i64, i64, i64, i8 } @llvm.x86.enclv(i64 %a, i64 %b, i64 %c, i64 %d)
  %result = call { i64, i64, i64, i64, i8 } @llvm.x86.enclv(i64 %a, i64 %b, i64 %c, i64 %d)
  ret { i64, i64, i64, i64, i8 } %result
}

;--- sgx32.ll

declare { i32, i32, i32, i32, i8 } @llvm.x86.encls32(i32, i32, i32, i32)
; X32-LABEL: probe_encls:
; X32-COUNT-3: encls
define { i32, i32, i32, i32, i8 } @probe_encls(i32 %a, i32 %b, i32 %c, i32 %d) {
  call { i32, i32, i32, i32, i8 } @llvm.x86.encls32(i32 %a, i32 %b, i32 %c, i32 %d)
  call { i32, i32, i32, i32, i8 } @llvm.x86.encls32(i32 %a, i32 %b, i32 %c, i32 %d)
  %result = call { i32, i32, i32, i32, i8 } @llvm.x86.encls32(i32 %a, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result
}

declare { i32, i32, i32, i32, i8 } @llvm.x86.enclv32(i32, i32, i32, i32)
; X32-LABEL: probe_enclv:
; X32-COUNT-3: enclv
define { i32, i32, i32, i32, i8 } @probe_enclv(i32 %a, i32 %b, i32 %c, i32 %d) {
  call { i32, i32, i32, i32, i8 } @llvm.x86.enclv32(i32 %a, i32 %b, i32 %c, i32 %d)
  call { i32, i32, i32, i32, i8 } @llvm.x86.enclv32(i32 %a, i32 %b, i32 %c, i32 %d)
  %result = call { i32, i32, i32, i32, i8 } @llvm.x86.enclv32(i32 %a, i32 %b, i32 %c, i32 %d)
  ret { i32, i32, i32, i32, i8 } %result
}
