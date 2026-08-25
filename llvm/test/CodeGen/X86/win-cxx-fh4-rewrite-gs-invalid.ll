; RUN: not llc -mtriple=x86_64-pc-windows-msvc -filetype=obj %s -o /dev/null 2>&1 | FileCheck %s

target triple = "x86_64-pc-windows-msvc"

declare void @may_throw()
declare i32 @__CxxFrameHandler4(...)
declare win64cc i32 @__GSHandlerCheck_EH4(...)

define void @wrong_wrapper_abi() #0 personality ptr @__CxxFrameHandler4 {
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

; CHECK: error: authenticated GS rewrite requires exact external C ABI declarations for __CxxFrameHandler4 and __GSHandlerCheck_EH4
