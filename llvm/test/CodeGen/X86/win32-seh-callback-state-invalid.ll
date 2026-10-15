; RUN: split-file %s %t
; RUN: not --crash llc -filetype=obj %t/no-attribute.ll -o %t/no-attribute.obj 2>&1 | FileCheck %s --check-prefix=PARENT
; RUN: not --crash llc -filetype=obj %t/wrong-parent.ll -o %t/wrong-parent.obj 2>&1 | FileCheck %s --check-prefix=PARENT
; RUN: not --crash llc -filetype=obj %t/wrong-token.ll -o %t/wrong-token.obj 2>&1 | FileCheck %s --check-prefix=TOKEN
; RUN: not --crash llc -filetype=obj %t/wrong-sentinel.ll -o %t/wrong-sentinel.obj 2>&1 | FileCheck %s --check-prefix=SENTINEL
; RUN: not --crash llc -filetype=obj %t/sentinel-digest.ll -o %t/sentinel-digest.obj 2>&1 | FileCheck %s --check-prefix=SENTINEL
; RUN: not --crash llc -filetype=obj %t/duplicate-write.ll -o %t/duplicate-write.obj 2>&1 | FileCheck %s --check-prefix=IDENTITY
; RUN: not --crash llc -filetype=obj %t/zero-write.ll -o %t/zero-write.obj 2>&1 | FileCheck %s --check-prefix=IDENTITY
; RUN: not --crash llc -filetype=obj %t/wrong-frame.ll -o %t/wrong-frame.obj 2>&1 | FileCheck %s --check-prefix=FRAME
; RUN: not --crash llc -filetype=obj %t/unchecked-nested-caller.ll -o %t/unchecked-nested-caller.obj 2>&1 | FileCheck %s --check-prefix=FRAME
; RUN: not --crash llc -filetype=obj %t/unrooted-cycle.ll -o %t/unrooted-cycle.obj 2>&1 | FileCheck %s --check-prefix=FRAME
; RUN: not --crash llc -filetype=obj %t/filter-unchecked-caller.ll -o %t/filter-unchecked-caller.obj 2>&1 | FileCheck %s --check-prefix=FRAME
; RUN: not --crash llc -filetype=obj %t/filter-without-parent.ll -o %t/filter-without-parent.obj 2>&1 | FileCheck %s --check-prefix=FRAME
; RUN: not --crash llc -filetype=obj %t/filter-wrong-depth.ll -o %t/filter-wrong-depth.obj 2>&1 | FileCheck %s --check-prefix=FRAME
; RUN: not --crash llc -filetype=obj %t/zero-scope-digest.ll -o %t/zero-scope-digest.obj 2>&1 | FileCheck %s --check-prefix=DIGEST
; RUN: not --crash llc -filetype=obj %t/changed-callback-abi.ll -o %t/changed-callback-abi.obj 2>&1 | FileCheck %s --check-prefix=FRAME
; RUN: not --crash llc -filetype=obj %t/escaped-callback.ll -o %t/escaped-callback.obj 2>&1 | FileCheck %s --check-prefix=FRAME
;
; PARENT: llvm.x86.seh.setstate: parent must be a defined SEH rewrite function in this module
; TOKEN: llvm.x86.seh.setstate: scope token must uniquely identify a parent SEH row
; SENTINEL: llvm.x86.seh.setstate: sentinel must match the parent personality and have zero digest
; IDENTITY: llvm.x86.seh.setstate: write identity must be nonzero and unique within its callback
; DIGEST: llvm.x86.seh.setstate: scope digest must be nonzero
; FRAME: llvm.x86.seh.setstate: frame must be the callback's checked parent localaddress

;--- no-attribute.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret void
}
define void @parent() personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

;--- wrong-parent.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @missing, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret void
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

;--- wrong-token.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 18, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret void
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

;--- wrong-sentinel.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 -2, i64 0, i64 0, i64 0, i64 0, i64 1)
  ret void
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

;--- sentinel-digest.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 -1, i64 0, i64 0, i64 0, i64 1, i64 1)
  ret void
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

;--- duplicate-write.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret void
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

;--- zero-write.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 0)
  ret void
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

;--- wrong-frame.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  %invalid = getelementptr i8, ptr %frame, i32 4
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %invalid, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret void
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

;--- unchecked-nested-caller.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret void
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

define internal void @unchecked(i8 %abnormal, ptr %frame) {
  call void @callback(i8 %abnormal, ptr %frame)
  ret void
}
define void @ordinary_caller() {
  call void @unchecked(i8 0, ptr null)
  ret void
}

;--- unrooted-cycle.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  call void @nested(i8 0, ptr %frame)
  ret void
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @may_throw() [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

define internal void @nested(i8 %abnormal, ptr %frame) {
  call void @callback(i8 %abnormal, ptr %frame)
  ret void
}

;--- filter-unchecked-caller.ll
target triple = "i686-pc-windows-msvc"
define internal i32 @filter() {
  %runtime = call ptr @llvm.frameaddress.p0(i32 1)
  %frame = call ptr @llvm.eh.recoverfp(ptr @parent, ptr %runtime)
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret i32 1
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %dispatch
dispatch:
  %cs = catchswitch within none [label %handler] unwind to caller
handler:
  %pad = catchpad within %cs [ptr @filter], !llvm.rewrite.windows-eh.semantic !0
  catchret from %pad to label %done
done:
  ret void
}
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.frameaddress.p0(i32 immarg)
declare ptr @llvm.eh.recoverfp(ptr, ptr)
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

define i32 @ordinary_caller() {
  %result = call i32 @filter()
  ret i32 %result
}

;--- filter-without-parent.ll
target triple = "i686-pc-windows-msvc"
define internal i32 @filter() {
  %runtime = call ptr @llvm.frameaddress.p0(i32 1)
  %frame = call ptr @llvm.eh.recoverfp(ptr @parent, ptr %runtime)
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret i32 1
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %dispatch
dispatch:
  %cs = catchswitch within none [label %handler] unwind to caller
handler:
  %pad = catchpad within %cs [ptr @other_filter], !llvm.rewrite.windows-eh.semantic !0
  catchret from %pad to label %done
done:
  ret void
}
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.frameaddress.p0(i32 immarg)
declare ptr @llvm.eh.recoverfp(ptr, ptr)
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}
declare i32 @other_filter()

;--- filter-wrong-depth.ll
target triple = "i686-pc-windows-msvc"
define internal i32 @filter() {
  %runtime = call ptr @llvm.frameaddress.p0(i32 0)
  %frame = call ptr @llvm.eh.recoverfp(ptr @parent, ptr %runtime)
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret i32 1
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %dispatch
dispatch:
  %cs = catchswitch within none [label %handler] unwind to caller
handler:
  %pad = catchpad within %cs [ptr @filter], !llvm.rewrite.windows-eh.semantic !0
  catchret from %pad to label %done
done:
  ret void
}
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.frameaddress.p0(i32 immarg)
declare ptr @llvm.eh.recoverfp(ptr, ptr)
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}

;--- zero-scope-digest.ll
target triple = "i686-pc-windows-msvc"
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 0, i64 0, i64 0, i64 0, i64 1)
  ret void
}
define void @parent() #0 personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 0, i64 0, i64 0, i64 0}


;--- changed-callback-abi.ll
target triple = "i686-pc-windows-msvc"
define internal fastcc void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret void
}
define void @parent() "llvm.rewrite.win-x86-registration-state" personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call fastcc void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}


;--- escaped-callback.ll
target triple = "i686-pc-windows-msvc"
@escaped = global ptr @callback
define internal void @callback(i8 %abnormal, ptr %frame) {
entry:
  call void @llvm.x86.seh.setstate(ptr @parent, ptr %frame, i32 17, i64 1, i64 2, i64 3, i64 4, i64 1)
  ret void
}
define void @parent() "llvm.rewrite.win-x86-registration-state" personality ptr @_except_handler3 {
entry:
  invoke void @may_throw() to label %done unwind label %cleanup
cleanup:
  %pad = cleanuppad within none [], !llvm.rewrite.windows-eh.semantic !0
  %frame = call ptr @llvm.localaddress()
  call void @callback(i8 1, ptr %frame) [ "funclet"(token %pad) ]
  cleanupret from %pad unwind to caller
done:
  ret void
}
declare void @missing()
declare void @may_throw()
declare i32 @_except_handler3(...)
declare ptr @llvm.localaddress()
declare void @llvm.x86.seh.setstate(ptr, ptr, i32 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg, i64 immarg)
attributes #0 = { "llvm.rewrite.win-x86-registration-state" }
!0 = !{i32 1, i8 1, i32 17, i32 0, i64 1, i64 2, i64 3, i64 4}
