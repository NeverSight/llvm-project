; RUN: llc -O0 -print-after=x86-winehstate -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc -O2 -print-after=x86-winehstate -o /dev/null < %s 2>&1 | FileCheck %s
;
; Both successors inherit the selected scope before an unmarked call resets
; it. Hoisting that later reset into their common predecessor is invalid.
;
; CHECK-LABEL: define i32 @parent(
; CHECK: join:
; CHECK-NOT: store volatile i32
; CHECK: br i1 %path
; CHECK: body:
; CHECK-NOT: store volatile i32
; CHECK: call void @may_throw()
; CHECK: load volatile i32
; CHECK: call i32 (ptr, i32, ...) @_setjmp3
; CHECK: store volatile i32 -1
; CHECK-NEXT: call void @after_scope()
; CHECK: second:
; CHECK-NOT: store volatile i32
; CHECK: call void @may_throw()
; CHECK: store volatile i32 -1
; CHECK-NEXT: call void @after_scope()

target datalayout = "e-m:x-p:32:32-i64:64-n8:16:32-S32"
target triple = "i686-pc-windows-msvc"


define i32 @parent(i1 %inner, i1 %path, ptr %buffer) #0 personality ptr @_except_handler3 {
entry:
  br i1 %inner, label %begin1, label %begin0
begin0:
  invoke void @llvm.seh.scope.begin() to label %join unwind label %scope0
begin1:
  invoke void @llvm.seh.scope.begin() to label %join unwind label %scope1
join:
  br i1 %path, label %body, label %second
body:
  call void @may_throw() #1
  %saved = call i32 (ptr, i32, ...) @_setjmp3(ptr %buffer, i32 0) #1
  call void @after_scope()
  br label %endselect
second:
  call void @may_throw() #1
  call void @after_scope()
  br label %endselect
endselect:
  br i1 %inner, label %end1, label %end0
end0:
  invoke void @llvm.seh.scope.end() to label %done unwind label %scope0
end1:
  invoke void @llvm.seh.scope.end() to label %done unwind label %scope1
scope0:
  %switch0 = catchswitch within none [label %handler0] unwind to caller
handler0:
  %pad0 = catchpad within %switch0 [ptr @filter], !llvm.rewrite.windows-eh.semantic !0
  catchret from %pad0 to label %handled
scope1:
  %switch1 = catchswitch within none [label %handler1] unwind label %scope0
handler1:
  %pad1 = catchpad within %switch1 [ptr @filter], !llvm.rewrite.windows-eh.semantic !1
  catchret from %pad1 to label %handled
handled:
  ret i32 -1
done:
  ret i32 0
}

declare void @after_scope()
declare void @may_throw()
declare i32 @filter()
declare i32 @_except_handler3(...)
declare i32 @_setjmp3(ptr, i32, ...) returns_twice
declare void @llvm.seh.scope.begin()
declare void @llvm.seh.scope.end()

attributes #0 = { noinline "frame-pointer"="all" "llvm.rewrite.win-x86-registration-state" }
attributes #1 = { noinline "llvm.rewrite.win-x86-seh-inherit-state" }

!0 = !{i32 1, i8 1, i32 0, i32 0, i64 1, i64 2, i64 3, i64 4}
!1 = !{i32 1, i8 1, i32 1, i32 0, i64 5, i64 6, i64 7, i64 8}
