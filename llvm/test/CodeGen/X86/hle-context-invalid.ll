; RUN: not --crash llc -mtriple=x86_64 < %s 2>&1 | FileCheck %s
; RUN: sed 's/i32 274, i32 8/i32 0, i32 3/' %s | not --crash llc -mtriple=x86_64 2>&1 | FileCheck %s
; RUN: sed 's/i32 274, i32 8/i32 3, i32 1/' %s | not --crash llc -mtriple=x86_64 2>&1 | FileCheck %s
; RUN: sed 's/i32 274, i32 8/i32 7, i32 4/' %s | not --crash llc -mtriple=x86_64 2>&1 | FileCheck %s
; RUN: sed 's/i32 274, i32 8/i32 19, i32 8/' %s | not --crash llc -mtriple=x86_64 2>&1 | FileCheck %s
; RUN: sed 's/i32 274, i32 8/i32 1024, i32 8/' %s | not --crash llc -mtriple=x86_64 2>&1 | FileCheck %s
; CHECK: invalid HLE operation or width

declare void @llvm.x86.hle.context(ptr, ptr, ptr, i32 immarg, i32 immarg)
define void @invalid_acquire_store(ptr %memory, ptr %gprs, ptr %flags) {
  call void @llvm.x86.hle.context(ptr %memory, ptr %gprs, ptr %flags, i32 274, i32 8)
  ret void
}
