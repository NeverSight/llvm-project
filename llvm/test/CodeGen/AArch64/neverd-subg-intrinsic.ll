; RUN: llc -mtriple=aarch64-none-linux-gnu -mattr=+mte < %s | FileCheck %s

declare ptr @llvm.aarch64.subg(ptr, i64, i64)

define ptr @subg(ptr %pointer) {
; CHECK-LABEL: subg:
; CHECK:       subg x0, x0, #112, #9
  %result = call ptr @llvm.aarch64.subg(ptr %pointer, i64 112, i64 9)
  ret ptr %result
}
