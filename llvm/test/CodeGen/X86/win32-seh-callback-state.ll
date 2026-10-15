; RUN: llc -O0 < %s | FileCheck %s
; RUN: llc -O2 < %s | FileCheck %s
; RUN: llc -O2 -filetype=obj < %s -o %t.obj
; RUN: opt -passes='default<O2>' -S < %s | llc -O2 | FileCheck %s
;
; A callback may precede its parent in IR and assembly. Its source scope token
; resolves to the generated table state, and its write targets the compiler's
; registration allocation relative to the parent's actual localaddress.

target datalayout = "e-m:x-p:32:32-i64:64-n8:16:32-S32"
target triple = "i686-pc-windows-msvc"

; Preserve the runtime finally ABI through module-level IPO.
@llvm.compiler.used = appending global [3 x ptr] [ptr @callback3, ptr @outer_finally, ptr @inner_finally], section "llvm.metadata"

; CHECK-LABEL: _callback3:
; CHECK: movl $[[STATE3:[^, ]*parent3[^, ]*seh_state[^, ]*]], [[OFFSET3:[^+ ]*parent3[^+ ]*parent_frame_offset]]+20(%[[FRAME3:e[a-z]+]])
; CHECK: movl $[[BASE3:[^, ]*parent3[^, ]*seh_state[^, ]*base]], [[OFFSET3]]+20(%[[RESETFRAME3:e[a-z]+]])
define internal void @callback3(i8 %abnormal, ptr %frame) #1 {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent3, ptr %frame, i32 17, i64 -1, i64 -2, i64 -9223372036854775808, i64 4, i64 -1)
  call void @may_throw(ptr %frame)
  call void @llvm.x86.seh.setstate(ptr @parent3, ptr %frame, i32 -1, i64 0, i64 0, i64 0, i64 0, i64 -2)
  ret void
}

; CHECK-LABEL: _parent3:
; CHECK-DAG: [[OFFSET3]] = {{-?[0-9]+}}
; CHECK-DAG: [[STATE3]] = 0
; CHECK-DAG: [[BASE3]] = -1
define void @parent3() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw(ptr null) to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback3(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}

; CHECK-LABEL: _filter4:
; CHECK: movl $[[STATE4:[^, ]*parent4[^, ]*seh_state[^, ]*]], [[OFFSET4:[^+ ]*parent4[^+ ]*parent_frame_offset]]+20(%[[FRAME4:e[a-z]+]])
; CHECK: movl $[[BASE4:[^, ]*parent4[^, ]*seh_state[^, ]*base]], [[OFFSET4]]+20(%[[FRAME4]])
define internal i32 @filter4() #1 {
entry:
  %runtime = call ptr @llvm.frameaddress.p0(i32 1)
  %frame = call ptr @llvm.eh.recoverfp(ptr @parent4, ptr %runtime)
  call void @llvm.x86.seh.setstate(ptr @parent4, ptr %frame, i32 17, i64 5, i64 6, i64 7, i64 8, i64 71)
  call void @llvm.x86.seh.setstate(ptr @parent4, ptr %frame, i32 -2, i64 0, i64 0, i64 0, i64 0, i64 72)
  ret i32 1
}

; CHECK-LABEL: _parent4:
; CHECK: andl $-64, %esp
; CHECK: movl %esp, %esi
; CHECK-DAG: [[OFFSET4]] = {{-?[0-9]+}}
; CHECK-DAG: [[STATE4]] = 0
; CHECK-DAG: [[BASE4]] = -2
define void @parent4() #0 personality ptr @_except_handler4 {
entry:
  %aligned = alloca [64 x i8], align 64
  call void (...) @llvm.localescape(ptr %aligned)
  invoke void @may_throw(ptr %aligned) to label %done unwind label %dispatch
dispatch:
  %switch = catchswitch within none [label %handler] unwind to caller
handler:
  %pad = catchpad within %switch [ptr @filter4], !llvm.rewrite.windows-eh.semantic !1
  catchret from %pad to label %done
done:
  ret void
}

; The parent can also precede a graph of nested finally callbacks. The
; conditional cycle forwards the same pointer and has a checked parent root.
; CHECK-LABEL: _parent_nested:
; CHECK-DAG: [[NESTOFFSET:[^ ]*parent_nested[^ ]*parent_frame_offset]] = {{-?[0-9]+}}
; CHECK-DAG: [[NESTSTATE:[^ ]*parent_nested[^ ]*seh_state[^ ]*29[^ ]*]] = 0
define void @parent_nested() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw(ptr null) to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !2
  %frame = call ptr @llvm.localaddress()
  call void @outer_finally(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}

define internal void @outer_finally(i8 %abnormal, ptr %frame) #1 {
entry:
  call void @inner_finally(i8 %abnormal, ptr %frame)
  ret void
}

; CHECK-LABEL: _inner_finally:
; CHECK: movl $[[NESTSTATE]], [[NESTOFFSET]]+20(%{{e[a-z]+}})
define internal void @inner_finally(i8 %abnormal, ptr %frame) #1 {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent_nested, ptr %frame, i32 29, i64 21, i64 22, i64 23, i64 24, i64 91)
  %recurse = icmp ne i8 %abnormal, 0
  br i1 %recurse, label %forward, label %done
forward:
  call void @outer_finally(i8 0, ptr %frame)
  br label %done
done:
  ret void
}

declare void @may_throw(ptr)
declare i32 @_except_handler3(...)
declare i32 @_except_handler4(...)
declare ptr @llvm.localaddress()
declare void @llvm.localescape(...)
declare ptr @llvm.frameaddress.p0(i32 immarg)
declare ptr @llvm.eh.recoverfp(ptr, ptr)
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)

attributes #0 = { noinline "frame-pointer"="all" "llvm.rewrite.win-x86-registration-state" }
attributes #1 = { noinline "frame-pointer"="all" }

!0 = !{i32 1, i8 1, i32 17, i32 0, i64 -1, i64 -2, i64 -9223372036854775808, i64 4}
!1 = !{i32 1, i8 1, i32 17, i32 0, i64 5, i64 6, i64 7, i64 8}
!2 = !{i32 1, i8 1, i32 29, i32 0, i64 21, i64 22, i64 23, i64 24}
