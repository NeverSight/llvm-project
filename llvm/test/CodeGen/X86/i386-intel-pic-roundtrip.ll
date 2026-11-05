; RUN: llc -mtriple=i386-linux-gnu -relocation-model=pic -x86-asm-syntax=intel -O0 %s -o %t.O0.s
; RUN: FileCheck %s --check-prefix=ASM < %t.O0.s
; RUN: llvm-mc -triple=i386-linux-gnu -filetype=obj %t.O0.s -o %t.O0.o
; RUN: llvm-objdump -dr %t.O0.o | FileCheck %s --check-prefix=OBJ
; RUN: llc -mtriple=i386-linux-gnu -relocation-model=pic -x86-asm-syntax=intel -O2 %s -o %t.O2.s
; RUN: llvm-mc -triple=i386-linux-gnu -filetype=obj %t.O2.s -o %t.O2.o
; RUN: llvm-objdump -dr %t.O2.o | FileCheck %s --check-prefix=OBJ

; ASM: add {{e[a-z]+}}, offset _GLOBAL_OFFSET_TABLE_+(
; OBJ-LABEL: <address>:
; OBJ: R_386_GOTPC _GLOBAL_OFFSET_TABLE_
; OBJ: R_386_GOT32{{X?}} global

@global = external global i32

define ptr @address() {
  ret ptr @global
}
