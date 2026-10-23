; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes='default<O2>' %s | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: INVLPGB intrinsic does not match the target code mode

declare void @llvm.x86.invlpgb.addr32(i32, i32, i32)

; CHECK-LABEL: invalidate:
; CHECK-COUNT-2: addr32{{[ \t]+}}invlpgb
; CHECK: ret
define i64 @invalidate(i32 %address, i32 %ids, i32 %count, ptr %ordinary) {
  store i64 42, ptr %ordinary
  call void @llvm.x86.invlpgb.addr32(i32 %address, i32 %ids, i32 %count)
  call void @llvm.x86.invlpgb.addr32(i32 %address, i32 %ids, i32 %count)
  %result = load i64, ptr %ordinary
  ret i64 %result
}
