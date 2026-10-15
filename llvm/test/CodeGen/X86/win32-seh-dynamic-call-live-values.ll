; RUN: llc -O0 -verify-machineinstrs -filetype=obj < %s -o %t.obj
; RUN: llc -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: sed 's/_except_handler3/_except_handler4/g' %s | llc -O2 -verify-machineinstrs | FileCheck %s
; RUN: sed 's/unreachable/ret i32 0/;s/ noreturn//' %s | llc -O2 -verify-machineinstrs | FileCheck %s
; RUN: sed 's/ optnone//' %s | opt -passes='default<O2>' -S | llc -O2 -verify-machineinstrs | FileCheck %s
;
; The x86 SEH runtime does not restore callee-saved registers on handler entry.
; A value used only by a handler must survive even when a dynamic call cannot
; return normally. The scope-begin edges alone do not model a clobber at the call.

target triple = "i686-pc-windows-msvc"

; CHECK-LABEL: _parent:
; CHECK: calll _get_value
; CHECK: movl %eax, [[SLOT:-[0-9]+]](%ebp)
; CHECK: calll _may_throw
; CHECK: movl [[SLOT]](%ebp), %eax
; CHECK: retl
define i32 @parent(i1 %inner) #0 personality ptr @_except_handler3 {
entry:
  %live = call i32 @get_value()
  br i1 %inner, label %begin1, label %begin0
begin0:
  invoke void @llvm.seh.scope.begin() to label %body unwind label %scope0
begin1:
  invoke void @llvm.seh.scope.begin() to label %body unwind label %scope1
body:
  notail call void @may_throw() #1
  unreachable
scope0:
  %switch0 = catchswitch within none [label %handler0] unwind to caller
handler0:
  %pad0 = catchpad within %switch0 [ptr @filter], !llvm.rewrite.windows-eh.semantic !0
  catchret from %pad0 to label %handled
scope1:
  %switch1 = catchswitch within none [label %handler1] unwind to caller
handler1:
  %pad1 = catchpad within %switch1 [ptr @filter], !llvm.rewrite.windows-eh.semantic !1
  catchret from %pad1 to label %handled
handled:
  ret i32 %live
}

declare i32 @get_value()
declare void @may_throw() noreturn
declare i32 @filter()
declare i32 @_except_handler3(...)
declare void @llvm.seh.scope.begin()

attributes #0 = { noinline optnone "frame-pointer"="all" "llvm.rewrite.win-x86-registration-state" }
attributes #1 = { noinline "llvm.rewrite.win-x86-seh-inherit-state" }

!0 = !{i32 1, i8 1, i32 0, i32 0, i64 1, i64 2, i64 3, i64 4}
!1 = !{i32 1, i8 1, i32 1, i32 0, i64 5, i64 6, i64 7, i64 8}
