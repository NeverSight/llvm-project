; RUN: split-file %s %t
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/width.ll 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/segment.ll 2>&1 | FileCheck %s --check-prefix=SEGMENT
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/condition.ll 2>&1 | FileCheck %s --check-prefix=CONDITION
; RUN: not opt -passes=verify -disable-output %t/dynamic.ll 2>&1 | FileCheck %s --check-prefix=DYNAMIC
; WIDTH: native memory address width is invalid
; SEGMENT: invalid native memory segment prefix
; CONDITION: APX atomic condition must be a constant in [0, 15]
; DYNAMIC: immarg operand has non-immediate parameter

;--- width.ll
declare void @llvm.x86.aadd32.address(i64, i32, i32, i32)
define void @f(i64 %address, i32 %x) {
  call void @llvm.x86.aadd32.address(i64 %address, i32 %x, i32 16, i32 0)
  ret void
}
;--- segment.ll
declare void @llvm.x86.aadd32.address(i64, i32, i32, i32)
define void @f(i64 %address, i32 %x) {
  call void @llvm.x86.aadd32.address(i64 %address, i32 %x, i32 64, i32 99)
  ret void
}
;--- condition.ll
declare i64 @llvm.x86.cmpccxadd64.address(i64, i64, i64, i32, i32, i32)
define i64 @f(i64 %address, i64 %x) {
  %v = call i64 @llvm.x86.cmpccxadd64.address(i64 %address, i64 %x, i64 %x, i32 16, i32 64, i32 0)
  ret i64 %v
}
;--- dynamic.ll
declare i64 @llvm.x86.cmpccxadd64.address(i64, i64, i64, i32, i32, i32)
define i64 @f(i64 %address, i64 %x, i32 %condition) {
  %v = call i64 @llvm.x86.cmpccxadd64.address(i64 %address, i64 %x, i64 %x, i32 %condition, i32 64, i32 0)
  ret i64 %v
}

