; RUN: llc < %s | FileCheck %s

; The rewrite's EH and GS cookies must use registration + 24, including when
; stack realignment makes the actual EBP displacement dynamic. An escaped
; argument copy must remain in the local-frame domain used by localrecover.

target datalayout = "e-m:x-p:32:32-i64:64-n8:16:32-S32"
target triple = "i686-pc-windows-msvc"

; CHECK-LABEL: _realigned_rewrite:
; CHECK: andl $-64, %esp
; CHECK: movl %esp, %esi
; CHECK: Lrealigned_rewrite$frame_escape_0 = [[#LOCAL:]]
; CHECK: movl 8(%ebp), %[[ARG:[a-z]+]]
; CHECK: leal [[#RUNTIME:]](%esi), %[[BASE:[a-z]+]]
; CHECK: movl ___security_cookie, %[[ENC:[a-z]+]]
; CHECK: xorl %[[BASE]], %[[ENC]]
; CHECK: movl %[[ENC]], [[#GS:]](%esi)
; CHECK-NOT: xorl %ebp,
; CHECK: xorl %[[BASE]], %[[EHENC:[a-z]+]]
; CHECK: movl %[[EHENC]], [[#EH:]](%esi)
; CHECK: movl %[[ARG]], [[#LOCAL]](%esi)
; CHECK: calll _useit
; CHECK: movl [[#GS]](%esi), %[[DECODE:[a-z]+]]
; CHECK: leal [[#RUNTIME]](%esi), %[[EXITBASE:[a-z]+]]
; CHECK: xorl %[[EXITBASE]], %[[DECODE]]
; CHECK: calll @__security_check_cookie@4
; CHECK: L__ehtable$realigned_rewrite:
; CHECK-NEXT: .long [[#GS - RUNTIME]]
; CHECK-NEXT: .long 0
; CHECK-NEXT: .long [[#EH - RUNTIME]]
; CHECK-NEXT: .long 0
define i32 @realigned_rewrite(i32 %argument) sspreq "llvm.rewrite.win-x86-registration-state" "frame-pointer"="all" personality ptr @_except_handler4 {
entry:
  %local = alloca i32, align 4
  %aligned = alloca [64 x i8], align 64
  store i32 %argument, ptr %local
  call void (...) @llvm.localescape(ptr %local, ptr %aligned)
  invoke void @useit(ptr %aligned) to label %normal unwind label %dispatch

dispatch:
  %switch = catchswitch within none [label %pad] unwind to caller

pad:
  %catch = catchpad within %switch [ptr @filter]
  catchret from %catch to label %handled

normal:
  ret i32 0

handled:
  ret i32 42
}

define internal i32 @filter() "frame-pointer"="all" {
entry:
  %runtime = call ptr @llvm.frameaddress.p0(i32 1)
  %frame = call ptr @llvm.eh.recoverfp(ptr @realigned_rewrite, ptr %runtime)
  %local = call ptr @llvm.localrecover(ptr @realigned_rewrite, ptr %frame, i32 0)
  %value = load i32, ptr %local
  ret i32 %value
}

declare i32 @_except_handler4(...)
declare void @useit(ptr)
declare void @llvm.localescape(...)
declare ptr @llvm.localrecover(ptr, ptr, i32 immarg)
declare ptr @llvm.frameaddress.p0(i32 immarg)
declare ptr @llvm.eh.recoverfp(ptr, ptr)
