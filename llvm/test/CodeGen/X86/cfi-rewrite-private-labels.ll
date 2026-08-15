; RUN: llc -mtriple=x86_64-unknown-linux-gnu -filetype=obj \
; RUN:   -save-temp-labels %s -o - | llvm-readobj --symbols - | \
; RUN:   FileCheck %s --implicit-check-not=cfi_begin \
; RUN:   --implicit-check-not=cfi_end
;
; Ordinary object emission must not turn CFI range endpoints into saved
; symbols, even when saving other temporary labels was requested. Binary
; rewrite assigns private endpoint names through its dedicated MCContext.

; CHECK: Name: f

define void @f() uwtable {
entry:
  ret void
}
