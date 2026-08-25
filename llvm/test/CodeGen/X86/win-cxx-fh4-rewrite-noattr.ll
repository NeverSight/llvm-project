; RUN: not llc -mtriple=x86_64-pc-windows-msvc -filetype=obj %s -o /dev/null 2>&1 | FileCheck %s

target triple = "x86_64-pc-windows-msvc"

declare void @may_throw()
declare i32 @__CxxFrameHandler4(...)

define void @no_writer_contract() personality ptr @__CxxFrameHandler4 {
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

; CHECK: error: __CxxFrameHandler4 requires the bounded rewrite writer attribute
