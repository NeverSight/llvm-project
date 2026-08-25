; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj %s -o %t.obj
; RUN: llvm-readobj --unwind --relocations --sections --section-data %t.obj | FileCheck %s

target triple = "x86_64-pc-windows-msvc"

declare void @may_throw()
declare i32 @__CxxFrameHandler4(...)
declare i32 @__GSHandlerCheck_EH4(...)

define void @gs_protected() #0 personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @may_throw()
          to label %done unwind label %dispatch

dispatch:
  %cs = catchswitch within none [label %catch] unwind to caller

catch:
  %cp = catchpad within %cs [ptr null, i32 64, ptr null]
  catchret from %cp to label %done

done:
  ret void
}

attributes #0 = { sspreq "llvm.rewrite.win-cxx-fh4" "llvm.rewrite.win-gs-handler"="cxx-fh4" }

; CHECK: 0010: 00000000 23000000
; CHECK: IMAGE_REL_AMD64_REL32 __security_cookie
; CHECK: IMAGE_REL_AMD64_REL32 __security_check_cookie
; CHECK: IMAGE_REL_AMD64_ADDR32NB __GSHandlerCheck_EH4
; CHECK: Handler: __GSHandlerCheck_EH4
