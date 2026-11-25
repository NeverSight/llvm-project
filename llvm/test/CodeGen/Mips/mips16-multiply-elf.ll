; RUN: llc -mtriple=mips -mcpu=mips32r2 -mattr=+mips16 -verify-machineinstrs -filetype=obj %s -o %t.be
; RUN: llvm-objdump -s -j .text.low -j .text.high -j .text.add %t.be | FileCheck %s --check-prefix=BE
; RUN: llc -mtriple=mipsel -mcpu=mips32r2 -mattr=+mips16 -verify-machineinstrs -filetype=obj %s -o %t.le
; RUN: llvm-objdump -s -j .text.low -j .text.high -j .text.add %t.le | FileCheck %s --check-prefix=LE

; mult $4,$5 / mflo $2, multu $4,$5 / mfhi $2
; BE: Contents of section .text.low:
; BE-NEXT: ecb8ea12
; BE: Contents of section .text.high:
; BE-NEXT: ecb9ea10
; BE: Contents of section .text.add:
; BE-NEXT: 4c076744 e8a0
; LE: Contents of section .text.low:
; LE-NEXT: b8ec12ea
; LE: Contents of section .text.high:
; LE-NEXT: b9ec10ea
; LE: Contents of section .text.add:
; LE-NEXT: 074c4467 a0e8

define i32 @low(i32 %a, i32 %b) nounwind section ".text.low" {
  %v = mul i32 %a, %b
  ret i32 %v
}

define i32 @high(i32 %a, i32 %b) nounwind section ".text.high" {
  %x = zext i32 %a to i64
  %y = zext i32 %b to i64
  %v = mul i64 %x, %y
  %h = lshr i64 %v, 32
  %r = trunc i64 %h to i32
  ret i32 %r
}

; addiu $4,7 / move $2,$4 / jrc $ra
define i32 @add_seven(i32 %x) nounwind section ".text.add" {
  %r = add i32 %x, 7
  ret i32 %r
}
