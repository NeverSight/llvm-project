; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+hreset -O0 -verify-machineinstrs < %t/state64.ll | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes='default<O2>' %t/state64.ll | llc -mtriple=x86_64-unknown-linux-gnu -mattr=+hreset -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+hreset -O0 -verify-machineinstrs < %t/state32.ll | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes='default<O2>' %t/state32.ll | llc -mtriple=i386-unknown-linux-gnu -mattr=+hreset -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/wrong-lkgs.ll 2>&1 | FileCheck %s --check-prefix=LKGS-ERROR
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/wrong-lkgs-memory.ll 2>&1 | FileCheck %s --check-prefix=LKGS-ERROR
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/wrong-invlpgb.ll 2>&1 | FileCheck %s --check-prefix=INVLPGB-ERROR
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/wrong-invlpgb64.ll 2>&1 | FileCheck %s --check-prefix=INVLPGB-ERROR
; LKGS-ERROR: LKGS intrinsic requires 64-bit mode
; INVLPGB-ERROR: INVLPGB intrinsic does not match the target code mode

;--- state64.ll
declare void @llvm.x86.hreset(i32)
; X64-LABEL: hreset:
; X64-COUNT-2: hreset
define void @hreset(i32 %control) {
  call void @llvm.x86.hreset(i32 %control)
  call void @llvm.x86.hreset(i32 %control)
  ret void
}

declare void @llvm.x86.invlpgb(i64, i32, i32)
; X64-LABEL: invlpgb:
; X64-COUNT-2: invlpgb
define void @invlpgb(i64 %address, i32 %ids, i32 %count) {
  call void @llvm.x86.invlpgb(i64 %address, i32 %ids, i32 %count)
  call void @llvm.x86.invlpgb(i64 %address, i32 %ids, i32 %count)
  ret void
}

declare void @llvm.x86.tlbsync()
; X64-LABEL: tlbsync:
; X64-COUNT-2: tlbsync
define void @tlbsync() {
  call void @llvm.x86.tlbsync()
  call void @llvm.x86.tlbsync()
  ret void
}

declare void @llvm.x86.lkgs.reg(i16)
; X64-LABEL: lkgs_reg:
; X64-COUNT-2: lkgs
define void @lkgs_reg(i16 %selector) {
  call void @llvm.x86.lkgs.reg(i16 %selector)
  call void @llvm.x86.lkgs.reg(i16 %selector)
  ret void
}

declare void @llvm.x86.lkgs.mem(ptr)
; X64-LABEL: lkgs_mem:
; X64-COUNT-2: lkgs
define void @lkgs_mem(ptr %selector) {
  call void @llvm.x86.lkgs.mem(ptr %selector)
  call void @llvm.x86.lkgs.mem(ptr %selector)
  ret void
}


;--- state32.ll
declare void @llvm.x86.hreset(i32)
; X32-LABEL: hreset:
; X32-COUNT-2: hreset
define void @hreset(i32 %control) {
  call void @llvm.x86.hreset(i32 %control)
  call void @llvm.x86.hreset(i32 %control)
  ret void
}

declare void @llvm.x86.invlpgb32(i32, i32, i32)
; X32-LABEL: invlpgb32:
; X32-COUNT-2: invlpgb
define void @invlpgb32(i32 %address, i32 %ids, i32 %count) {
  call void @llvm.x86.invlpgb32(i32 %address, i32 %ids, i32 %count)
  call void @llvm.x86.invlpgb32(i32 %address, i32 %ids, i32 %count)
  ret void
}

declare void @llvm.x86.tlbsync()
; X32-LABEL: tlbsync:
; X32-COUNT-2: tlbsync
define void @tlbsync() {
  call void @llvm.x86.tlbsync()
  call void @llvm.x86.tlbsync()
  ret void
}

;--- wrong-lkgs.ll
declare void @llvm.x86.lkgs.reg(i16)
define void @bad(i16 %selector) {
  call void @llvm.x86.lkgs.reg(i16 %selector)
  ret void
}
;--- wrong-invlpgb.ll
declare void @llvm.x86.invlpgb32(i32, i32, i32)
define void @bad(i32 %control) {
  call void @llvm.x86.invlpgb32(i32 %control, i32 0, i32 0)
  ret void
}
;--- wrong-lkgs-memory.ll
declare void @llvm.x86.lkgs.mem(ptr)
define void @bad(ptr %selector) {
  call void @llvm.x86.lkgs.mem(ptr %selector)
  ret void
}
;--- wrong-invlpgb64.ll
declare void @llvm.x86.invlpgb(i64, i32, i32)
define void @bad(i64 %control) {
  call void @llvm.x86.invlpgb(i64 %control, i32 0, i32 0)
  ret void
}
