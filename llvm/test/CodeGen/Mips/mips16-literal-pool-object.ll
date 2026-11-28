; RUN: llc -mtriple=mips -mcpu=mips32r2 -mattr=+mips16,+noabicalls -verify-machineinstrs -filetype=obj %s -o %t.be
; RUN: llvm-objdump -s -j .text %t.be | FileCheck %s --check-prefix=BE
; RUN: llc -mtriple=mipsel -mcpu=mips32r2 -mattr=+mips16,+noabicalls -verify-machineinstrs -filetype=obj %s -o %t.le
; RUN: llvm-objdump -s -j .text %t.le | FileCheck %s --check-prefix=LE

; LWPC at byte 0 loads the word at byte 8. Check the instructions as well as
; the word in the object so an unresolved immediate cannot pass as zero.
; BE: 0000 b202e449 e8a00000 12345678
; LE: 0000 02b249e4 a0e80000 78563412

define i32 @addword(i32 %x) nounwind {
  %v = add i32 %x, 305419896
  ret i32 %v
}
