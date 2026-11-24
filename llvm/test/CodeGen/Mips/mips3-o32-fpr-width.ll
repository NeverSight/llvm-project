; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips3 -mattr=-fp64 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=ISA,FR0
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips3 -mattr=-fp64 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=ISA,FR0
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips3 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=ISA,FR1
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips3 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=ISA,FR1
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips3 -mattr=-fp64 -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=O32
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips3 -mattr=-fp64 -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=O32
; ISA: EF_MIPS_ARCH_3
; ISA: ISA: MIPS3
; FR0: FP ABI: Hard float (double precision)
; FR1: FP ABI: Hard float (32-bit CPU, 64-bit FPU)
; ISA: GPR size: 64
; FR0: CPR1 size: 32
; FR1: CPR1 size: 64

; O32-LABEL: sum:
; O32: add.d $f0, $f12, $f14
define double @sum(double %x, double %y) {
  %z = fadd double %x, %y
  ret double %z
}

; A 64-bit GPR ISA still passes long long in a pair of O32 argument words.
; O32-LABEL: pair:
; O32-DAG: move $2, $4
; O32-DAG: move $3, $5
define i64 @pair(i64 %x) {
  ret i64 %x
}

; O32-LABEL: fifth:
; O32: lw $2, 16($sp)
define i32 @fifth(i32 %a, i32 %b, i32 %c, i32 %d, i32 %e) {
  ret i32 %e
}
