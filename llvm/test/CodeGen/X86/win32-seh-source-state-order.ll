; RUN: llc -O0 < %s | FileCheck %s
; RUN: llc -O2 < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -O2 | FileCheck %s
; RUN: llc -O2 -filetype=obj < %s -o %t.obj
; RUN: sed 's/i8 1, i32 1, i32 0/i8 1, i32 0, i32 0/' %s | not --crash llc -filetype=obj -o /dev/null 2>&1 | FileCheck %s --check-prefix=DUPLICATE
; RUN: sed 's/i8 1, i32 0, i32 0/i8 1, i32 9, i32 0/' %s | not --crash llc -filetype=obj -o /dev/null 2>&1 | FileCheck %s --check-prefix=OUTER
;
; DUPLICATE: duplicate x86 SEH rewrite state identity
; OUTER: x86 SEH rewrite enclosing state must precede its scope
;
; The CRT compares the live state with the saved numeric setjmp bound. The
; predecessor traversal used to number this source graph 0,3,4,1,2, causing
; longjmp from scope 4 to scope 1 to skip the finally entirely.

target datalayout = "e-m:x-p:32:32-i64:64-n8:16:32-S32"
target triple = "i686-pc-windows-msvc"

@llvm.compiler.used = appending global [2 x ptr] [ptr @filter, ptr @cleanup], section "llvm.metadata"

; CHECK-LABEL: _parent:
; CHECK: calll __setjmp3
; CHECK-DAG: Lparent$seh_state$0$1$2$3$4 = 0
; CHECK-DAG: Lparent$seh_state$1$5$6$7$8 = 1
; CHECK-DAG: Lparent$seh_state$2$9$A$B$C = 2
; CHECK-DAG: Lparent$seh_state$3$D$E$F$10 = 3
; CHECK-DAG: Lparent$seh_state$4$11$12$13$14 = 4

define void @parent(ptr %buffer) #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw(ptr null) to label %capture unwind label %scope2
capture:
  %saved = invoke i32 (ptr, i32, ...) @_setjmp3(ptr %buffer, i32 0)
      to label %active unwind label %scope1
active:
  invoke void @may_throw(ptr %buffer) to label %done unwind label %finally4
scope0:
  %switch0 = catchswitch within none [label %handler0] unwind to caller
handler0:
  %pad0 = catchpad within %switch0 [ptr @filter], !llvm.rewrite.windows-eh.semantic !0
  catchret from %pad0 to label %done
scope1:
  %switch1 = catchswitch within none [label %handler1] unwind label %scope0
handler1:
  %pad1 = catchpad within %switch1 [ptr @filter], !llvm.rewrite.windows-eh.semantic !1
  catchret from %pad1 to label %done
scope2:
  %switch2 = catchswitch within none [label %handler2] unwind label %scope1
handler2:
  %pad2 = catchpad within %switch2 [ptr @filter], !llvm.rewrite.windows-eh.semantic !2
  catchret from %pad2 to label %done
scope3:
  %switch3 = catchswitch within none [label %handler3] unwind label %scope0
handler3:
  %pad3 = catchpad within %switch3 [ptr @filter], !llvm.rewrite.windows-eh.semantic !3
  catchret from %pad3 to label %done
finally4:
  %pad4 = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !4
  %frame = call ptr @llvm.localaddress()
  call void @cleanup(i8 1, ptr %frame) [ "funclet"(token %pad4) ]
  cleanupret from %pad4 unwind label %scope3
done:
  ret void
}

define internal i32 @filter() #1 {
entry:
  %runtime = call ptr @llvm.frameaddress.p0(i32 1)
  %frame = call ptr @llvm.eh.recoverfp(ptr @parent, ptr %runtime)
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 2, i64 9, i64 10, i64 11, i64 12, i64 1)
  ret i32 -1
}

define internal void @cleanup(i8 %abnormal, ptr %frame) #1 {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 3, i64 13, i64 14, i64 15, i64 16, i64 2)
  call void @may_throw(ptr %frame)
  ret void
}

declare void @may_throw(ptr)
declare i32 @_except_handler3(...)
declare i32 @_setjmp3(ptr, i32, ...) returns_twice
declare ptr @llvm.localaddress()
declare ptr @llvm.frameaddress.p0(i32 immarg)
declare ptr @llvm.eh.recoverfp(ptr, ptr)
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)

attributes #0 = { noinline "frame-pointer"="all" "llvm.rewrite.win-x86-registration-state" }
attributes #1 = { noinline "frame-pointer"="all" }

!0 = !{i32 1, i8 1, i32 0, i32 0, i64 1, i64 2, i64 3, i64 4}
!1 = !{i32 1, i8 1, i32 1, i32 0, i64 5, i64 6, i64 7, i64 8}
!2 = !{i32 1, i8 1, i32 2, i32 0, i64 9, i64 10, i64 11, i64 12}
!3 = !{i32 1, i8 1, i32 3, i32 0, i64 13, i64 14, i64 15, i64 16}
!4 = !{i32 1, i8 1, i32 4, i32 0, i64 17, i64 18, i64 19, i64 20}
