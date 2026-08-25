; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj %s -o %t.obj
; RUN: llvm-readobj --relocations %t.obj | FileCheck %s

target triple = "x86_64-pc-windows-msvc"

@type_descriptor = external global i8

declare void @may_throw()
declare i32 @__CxxFrameHandler4(...)

define void @typed_catch() #0 personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @may_throw()
          to label %done unwind label %dispatch

dispatch:
  %cs = catchswitch within none [label %catch] unwind to caller

catch:
  %cp = catchpad within %cs [ptr @type_descriptor, i32 0, ptr null]
  catchret from %cp to label %done

done:
  ret void
}

attributes #0 = { "llvm.rewrite.win-cxx-fh4" }

; CHECK: IMAGE_REL_AMD64_ADDR32NB type_descriptor
; CHECK: IMAGE_REL_AMD64_ADDR32NB {{.*catch.*}}
