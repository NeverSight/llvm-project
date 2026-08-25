; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj %s -o %t.obj
; RUN: llvm-readobj --sections --section-data --relocations %t.obj | FileCheck %s --check-prefix=OBJECT
; RUN: llvm-readobj --unwind %t.obj | FileCheck %s --check-prefix=UNWIND
; RUN: llvm-readobj --symbols %t.obj | FileCheck %s --check-prefix=SYMBOL

target triple = "x86_64-pc-windows-msvc"

declare void @may_throw()
declare i32 @__CxxFrameHandler4(...)

define i32 @probe() #0 personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @may_throw()
          to label %ok unwind label %dispatch

ok:
  ret i32 1

dispatch:
  %cs = catchswitch within none [label %catch] unwind to caller

catch:
  %cp = catchpad within %cs [ptr null, i32 64, ptr null]
  catchret from %cp to label %caught

caught:
  ret i32 2
}

attributes #0 = { "llvm.rewrite.win-cxx-fh4" }

; The parent installs FH4 and owns the only FuncInfo4 pointer.
; UNWIND: RuntimeFunction {
; UNWIND-NEXT: StartAddress: probe
; UNWIND: Flags [ (0x3)
; UNWIND-NEXT: ExceptionHandler
; UNWIND-NEXT: TerminateHandler
; UNWIND: Handler: __CxxFrameHandler4

; The ordinary catch funclet is pure unwind and cannot borrow the parent FI.
; UNWIND: RuntimeFunction {
; UNWIND-NEXT: StartAddress: ?catch$
; UNWIND: Flags [ (0x0)
; UNWIND-NEXT: ]
; UNWIND-NOT: Handler:

; FuncInfo4 begins at 0x1c. Its exact minimal wire is:
;   38 + three RVA32s
;   04 08 10
;   02 00 00 02 + handler-map RVA32
;   02 01 80 + catch-funclet RVA32
;   06 00 00 + root-local IP transitions.
; OBJECT: Name: .xdata
; OBJECT: RawDataSize: 66
; OBJECT: 0020: 00000000 00000000 00040810 02000002
; OBJECT-NEXT: 0030: 00000000 02018000 00000006 00002402
; OBJECT-NEXT: 0040: 0C00

; OBJECT: Section (4) .xdata {
; OBJECT: 0xC IMAGE_REL_AMD64_ADDR32NB __CxxFrameHandler4
; OBJECT: 0x10 IMAGE_REL_AMD64_ADDR32NB $cppxdata4$probe
; OBJECT: 0x1D IMAGE_REL_AMD64_ADDR32NB $stateUnwindMap4$probe
; OBJECT: 0x21 IMAGE_REL_AMD64_ADDR32NB $tryMap4$probe
; OBJECT: 0x25 IMAGE_REL_AMD64_ADDR32NB $ip2state4$probe
; OBJECT: 0x30 IMAGE_REL_AMD64_ADDR32NB $handlerMap4$0$probe
; OBJECT: 0x37 IMAGE_REL_AMD64_ADDR32NB ?catch$

; SYMBOL: Name: $cppxdata4$probe
; SYMBOL-NEXT: Value: 28
; SYMBOL: Name: $stateUnwindMap4$probe
; SYMBOL-NEXT: Value: 41
; SYMBOL: Name: $tryMap4$probe
; SYMBOL-NEXT: Value: 44
; SYMBOL: Name: $ip2state4$probe
; SYMBOL-NEXT: Value: 59
; SYMBOL: Name: $handlerMap4$0$probe
; SYMBOL-NEXT: Value: 52
