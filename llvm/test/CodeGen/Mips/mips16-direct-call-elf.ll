; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32r2 -mattr=+soft-float,+noabicalls -relocation-model=static -filetype=obj %s -o %t
; RUN: llvm-readobj --relocations --hex-dump=.text %t | FileCheck %s --check-prefixes=REL,BE
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32r2 -mattr=+soft-float,+noabicalls -relocation-model=static -filetype=obj %s -o %t
; RUN: llvm-readobj --relocations --hex-dump=.text %t | FileCheck %s --check-prefixes=REL,LE
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32r2 -mattr=+soft-float -relocation-model=pic -filetype=obj %s -o %t
; RUN: llvm-readobj --relocations --hex-dump=.text %t | FileCheck %s --check-prefixes=PIC,PICBE
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32r2 -mattr=+soft-float -relocation-model=pic -filetype=obj %s -o %t
; RUN: llvm-readobj --relocations --hex-dump=.text %t | FileCheck %s --check-prefixes=PIC,PICLE
;
; SAVE $ra,24; JAL callee; mandatory 16-bit NOP slot. GNU ld uses the
; relocation's symbol mode to choose JAL or JALX when it binds callee.
; REL: 0x2 R_MIPS16_26 callee
; BE: 0x00000000 64c31800 00006500
; LE: 0x00000000 c3640018 00000065
; PIC: 0x2 R_MIPS16_HI16 _gp_disp
; PIC: 0x6 R_MIPS16_LO16 _gp_disp
; PIC: 0x10 R_MIPS16_CALL16 callee
; PICBE: 0x00000010 f0009a60 653b659a ebc04a01 6443e8a0
; PICLE: 0x00000010 00f0609a 3b659a65 c0eb014a 4364a0e8

declare i32 @callee(i32)

define i32 @caller(i32 %x) "mips16" {
  %y = call i32 @callee(i32 %x)
  %z = add i32 %y, 1
  ret i32 %z
}
