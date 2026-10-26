; RUN: opt -S -passes='loop(loop-simplifycfg)' -verify-each < %s | FileCheck %s
; RUN: opt -S -passes='loop-mssa(loop-simplifycfg)' -verify-each -verify-memoryssa < %s | FileCheck %s
; RUN: opt -disable-output -passes='default<O2>' -verify-each < %s

; A handler can retry the protected code. The resulting natural loop starts
; at a catchswitch, whose unwind predecessors cannot form a branch preheader.
declare void @may_throw()
declare i32 @__C_specific_handler(...)

define void @catchswitch_loop(i1 %again) personality ptr @__C_specific_handler {
; CHECK-LABEL: define void @catchswitch_loop(
; CHECK: invoke void @may_throw()
; CHECK-NEXT: to label %{{.*}} unwind label %dispatch
; CHECK: dispatch:
; CHECK-NEXT: %switch = catchswitch within none [label %catch] unwind to caller
; CHECK: %pad = catchpad within %switch [ptr null]
; CHECK-NEXT: catchret from %pad to label %handler
; CHECK: handler:
; CHECK: br i1 %again, label %retry, label %{{.*}}
; CHECK: retry:
; CHECK-NEXT: invoke void @may_throw()
; CHECK-NEXT: to label %{{.*}} unwind label %dispatch
entry:
  invoke void @may_throw()
          to label %exit unwind label %dispatch

dispatch:
  %switch = catchswitch within none [label %catch] unwind to caller

catch:
  %pad = catchpad within %switch [ptr null]
  catchret from %pad to label %handler

handler:
  br i1 %again, label %retry, label %exit

retry:
  invoke void @may_throw()
          to label %exit unwind label %dispatch

exit:
  ret void
}
