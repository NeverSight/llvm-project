; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32r2 -filetype=obj %s -o %t
; RUN: llvm-readobj --symbols --arch-specific --relocations %t | FileCheck %s
; RUN: llvm-readobj --hex-dump=.text %t | FileCheck %s --check-prefix=BE
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32r2 -filetype=obj %s -o %t
; RUN: llvm-readobj --symbols --arch-specific --relocations %t | FileCheck %s
; RUN: llvm-readobj --hex-dump=.text %t | FileCheck %s --check-prefix=LE

@also_compact = hidden alias i32 (), ptr @compact
@table = global [2 x ptr] [ptr @compact, ptr @plain]

define hidden i32 @compact() "mips16" {
  ret i32 17
}

define i32 @plain() "nomips16" {
  ret i32 23
}

; CHECK: R_MIPS_32 compact
; CHECK: Name: compact (
; CHECK: Type: Function
; CHECK-NEXT: Other [ (0xF2)
; CHECK: Name: plain (
; CHECK: Type: Function
; CHECK-NEXT: Other: 0
; CHECK: Name: also_compact (
; CHECK: Type: Function
; CHECK-NEXT: Other [ (0xF2)
; CHECK: ASEs [ (0x400)
; Both byte orders fetch EXTEND first, then li $2,17 and jrc $ra.
; BE: 0x00000000 f0006a11 e8a0
; LE: 0x00000000 00f0116a a0e8
