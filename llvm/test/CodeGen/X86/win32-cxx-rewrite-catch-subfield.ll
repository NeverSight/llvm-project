; RUN: opt -passes=verify -disable-output < %s
; RUN: opt -passes='default<O2>' -S < %s | llc | FileCheck %s --check-prefix=VALID
; RUN: llc < %s | FileCheck %s --check-prefix=VALID
; RUN: sed 's/i32 1, i32 12, i32 4}/i32 1, i32 12, i32 24}/' %s | not llc 2>&1 | FileCheck %s --check-prefix=BOUNDS
; RUN: sed 's/, !llvm.rewrite.win-x86-cxx-catch-object !0//' %s | not llc 2>&1 | FileCheck %s --check-prefix=EXTENT
; RUN: sed 's/i32 0, ptr %frame]/i32 0, ptr %object]/' %s | not llc 2>&1 | FileCheck %s --check-prefix=BOUNDS
; RUN: sed 's/i32 1, i32 12, i32 4}/i32 1, i32 -1, i32 4}/' %s | not llc 2>&1 | FileCheck %s --check-prefix=BOUNDS
; RUN: sed 's/i686-pc-windows-msvc/x86_64-pc-windows-msvc/' %s | not llc 2>&1 | FileCheck %s --check-prefix=ABI
; RUN: sed -e 's/alloca \[32 x i8\],/alloca [32 x i8], i32 %offset,/' -e '/call void.*localescape/d' %s | not llc 2>&1 | FileCheck %s --check-prefix=BOUNDS
; RUN: sed 's/"llvm.rewrite.win-x86-cxx-frame"//' %s | not opt -passes=verify -disable-output 2>&1 | FileCheck %s --check-prefix=ABI

; A checked catch-object metadata subfield belongs to the same escaped
; frame used by ordinary code. Its HandlerType displacement must include that
; subfield even when physical stack realignment changes the machine frame base.
; BOUNDS: rewrite C++ catch object exceeds its static frame
; EXTENT: rewrite C++ catch object has no checked extent
; ABI: rewrite C++ frame requires the PE32 MSVC C++ ABI

target datalayout = "e-m:x-p:32:32-i64:64-n8:16:32-S32"
target triple = "i686-pc-windows-msvc"

@type = external constant i8

; VALID-LABEL: _subfield:
; VALID: Lsubfield$frame_escape_0 = [[#%d,FRAME:]]
; VALID: leal [[#%d,NODE:]](%ebp),
; VALID: leal [[#FRAME]](%ebp),
; VALID: "[[HANDLER:\?catch\$[0-9]+@\?0\?subfield@4HA]]":
; VALID: addl $[[#%d,0 - NODE - 12]], %ebp
; VALID: leal [[#FRAME + 12]](%ebp),
; VALID: $handlerMap$0$subfield:
; VALID-NEXT: .long 0
; VALID-NEXT: .long _type
; VALID-NEXT: .long [[#%d,FRAME - NODE]]
; VALID-NEXT: .long "[[HANDLER]]"
define i32 @subfield(i32 %offset) "llvm.rewrite.win-x86-cxx-frame" "frame-pointer"="all" personality ptr @__CxxFrameHandler3 {
entry:
  %frame = alloca [32 x i8], align 4
  %object = getelementptr inbounds i8, ptr %frame, i32 12
  call void (...) @llvm.localescape(ptr %frame)
  invoke void @may_throw(ptr %frame) to label %normal unwind label %dispatch

dispatch:
  %switch = catchswitch within none [label %handler] unwind to caller

handler:
  %catch = catchpad within %switch [ptr @type, i32 0, ptr %frame], !llvm.rewrite.win-x86-cxx-catch-object !0
  call void @use(ptr %object) ["funclet"(token %catch)]
  catchret from %catch to label %handled

normal:
  ret i32 0

handled:
  ret i32 7
}

; VALID-LABEL: _realigned_subfield:
; VALID: andl $-64, %esp
; VALID: movl %esp, %esi
; VALID: Lrealigned_subfield$frame_escape_0 = [[#%d,ALIGNED_FRAME:]]
; VALID: leal [[#%d,ALIGNED_NODE:]](%esi),
; VALID: "[[ALIGNED_HANDLER:\?catch\$[0-9]+@\?0\?realigned_subfield@4HA]]":
; VALID: leal [[#%d,0 - ALIGNED_NODE - 12]](%ebp), %esi
; VALID: leal [[#ALIGNED_FRAME + 12]](%esi),
; VALID: $handlerMap$0$realigned_subfield:
; VALID-NEXT: .long 0
; VALID-NEXT: .long _type
; VALID-NEXT: .long [[#%d,ALIGNED_FRAME - ALIGNED_NODE]]
; VALID-NEXT: .long "[[ALIGNED_HANDLER]]"
define i32 @realigned_subfield(i32 %offset) "llvm.rewrite.win-x86-cxx-frame" "frame-pointer"="all" personality ptr @__CxxFrameHandler3 {
entry:
  %frame = alloca [32 x i8], align 64
  %object = getelementptr inbounds i8, ptr %frame, i32 12
  call void (...) @llvm.localescape(ptr %frame)
  invoke void @may_throw(ptr %frame) to label %normal unwind label %dispatch

dispatch:
  %switch = catchswitch within none [label %handler] unwind to caller

handler:
  %catch = catchpad within %switch [ptr @type, i32 0, ptr %frame], !llvm.rewrite.win-x86-cxx-catch-object !0
  call void @use(ptr %object) ["funclet"(token %catch)]
  catchret from %catch to label %handled

normal:
  ret i32 0

handled:
  ret i32 7
}

declare i32 @__CxxFrameHandler3(...)
declare void @may_throw(ptr)
declare void @use(ptr)
declare void @llvm.localescape(...)

!0 = !{i32 1, i32 12, i32 4}
