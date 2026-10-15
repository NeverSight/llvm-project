; RUN: llc -O0 -print-after=x86-winehstate -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: llc -O2 -print-after=x86-winehstate -o /dev/null < %s 2>&1 | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -O2 -print-after=x86-winehstate -o /dev/null 2>&1 | FileCheck %s
; RUN: llc -O0 -filetype=obj < %s -o %t.obj
; RUN: llc -O2 -filetype=obj < %s -o %t.obj
; RUN: sed 's/_except_handler3/_except_handler4/g' %s > %t-eh4.ll
; RUN: llc -O0 -print-after=x86-winehstate -o /dev/null < %t-eh4.ll 2>&1 | FileCheck %s --check-prefix=EH4
; RUN: llc -O2 -filetype=obj < %t-eh4.ll -o %t-eh4.obj
; RUN: sed '/call .* #1$/s/ #1$//' %s | llc -O0 -print-after=x86-winehstate -o /dev/null 2>&1 | FileCheck %s --check-prefix=UNMARKED
; RUN: sed 's/"llvm.rewrite.win-x86-seh-inherit-state"/"llvm.rewrite.win-x86-seh-inherit-state"="bad"/' %s | not --crash llc -o /dev/null 2>&1 | FileCheck %s --check-prefix=VALUE
; RUN: sed '/attributes #1/s/noinline //' %s | not --crash llc -o /dev/null 2>&1 | FileCheck %s --check-prefix=VALUE
; RUN: sed 's/"llvm.rewrite.win-x86-registration-state"//' %s | not --crash llc -o /dev/null 2>&1 | FileCheck %s --check-prefix=PARENT
; RUN: sed 's/_except_handler3/__CxxFrameHandler3/g' %s | not --crash llc -o /dev/null 2>&1 | FileCheck %s --check-prefix=PARENT
; RUN: sed 's/declare void @may_throw()/declare void @may_throw() #1/' %s | not --crash llc -o /dev/null 2>&1 | FileCheck %s --check-prefix=CALLEE
; RUN: sed 's/  call void @may_throw()/  tail call void @may_throw()/' %s | not --crash llc -O0 -o /dev/null 2>&1 | FileCheck %s --check-prefix=CALL
; RUN: sed 's/invoke void @llvm.seh.scope.begin()/invoke void @llvm.seh.scope.begin() #1/' %s | not --crash llc -O0 -o /dev/null 2>&1 | FileCheck %s --check-prefix=CALL
; RUN: sed 's/ptr %buffer, i32 0/ptr %buffer, i32 2/' %s | not --crash llc -O0 -o /dev/null 2>&1 | FileCheck %s --check-prefix=CAPTURE
; RUN: sed 's/ptr %buffer, i32 0/ptr %buffer, i32 2, i32 0, i32 0/' %s | not --crash llc -O0 -o /dev/null 2>&1 | FileCheck %s --check-prefix=CAPTURE
;
; VALUE: requires an empty marker and a noinline call site
; PARENT: requires a defined MSVC SEH rewrite parent with EH pads
; CALLEE: attribute must belong to a call site, not a function
; CALL: requires an ordinary non-tail parent call
; CAPTURE: setjmp requires the compiler-owned (buffer, 0) interface
;
; EH4-LABEL: define i32 @parent(
; EH4: body:
; EH4-NOT: store volatile i32 -2
; EH4: call void @may_throw()
; EH4-NOT: store volatile i32 -2
; EH4: [[STATE:%.*]] = load volatile i32, ptr
; EH4: call i32 (ptr, i32, ...) @_setjmp3(ptr %buffer, i32 3, ptr @_seh_longjmp_unwind4, i32 [[STATE]], ptr @__security_cookie)
;
; UNMARKED-LABEL: define i32 @parent(
; UNMARKED: body:
; UNMARKED: store volatile i32 -1
; UNMARKED-NEXT: call void @may_throw()
; UNMARKED-NEXT: %saved = call i32 (ptr, i32, ...) @_setjmp3(ptr %buffer, i32 2, ptr @_seh_longjmp_unwind, i32 -1)
;
; A shared source call inherits the scope selected by its incoming edge. In
; particular, setjmp must save that live state rather than the parent's -1.

target datalayout = "e-m:x-p:32:32-i64:64-n8:16:32-S32"
target triple = "i686-pc-windows-msvc"

; CHECK-LABEL: define i32 @parent(
; CHECK: body:
; CHECK-NOT: store volatile i32 -1
; CHECK: call void @may_throw()
; CHECK-NOT: store volatile i32 -1
; CHECK: [[STATE:%.*]] = load volatile i32, ptr
; CHECK: call i32 (ptr, i32, ...) @_setjmp3(ptr %buffer, i32 2, ptr @_seh_longjmp_unwind, i32 [[STATE]])

define i32 @parent(i1 %inner, ptr %buffer) #0 personality ptr @_except_handler3 {
entry:
  br i1 %inner, label %begin1, label %begin0
begin0:
  invoke void @llvm.seh.scope.begin() to label %body unwind label %scope0
begin1:
  invoke void @llvm.seh.scope.begin() to label %body unwind label %scope1
body:
  call void @may_throw() #1
  %saved = call i32 (ptr, i32, ...) @_setjmp3(ptr %buffer, i32 0) #1
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
  ret i32 %saved
}

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
