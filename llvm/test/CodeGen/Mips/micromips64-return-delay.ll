; RUN: llc -mtriple=mips64-linux-gnuabin32 -mcpu=mips64r2 -mattr=+micromips,+noabicalls -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=mips64el-linux-gnuabi64 -mcpu=mips64r2 -mattr=+micromips,+noabicalls -verify-machineinstrs %s -o - | FileCheck %s

; An ADDIUS5 cannot occupy the 32-bit delay slot of JR. When there is no
; independent full-width filler, emit the compact return without a delay slot.
define i32 @calc(i32 %x) nounwind {
; CHECK-LABEL: calc:
; CHECK: addius5
; CHECK-NEXT: jrc $ra
  %mul = mul i32 %x, 9
  %r = add i32 %mul, 3
  ret i32 %r
}
