; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips3 -mattr=-fp64 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=ISA,FR0
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips3 -mattr=-fp64 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=ISA,FR0
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips3 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=ISA,FR1
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips3 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=ISA,FR1
; ISA: EF_MIPS_ARCH_3
; ISA: ISA: MIPS3
; FR0: FP ABI: Hard float (double precision)
; FR1: FP ABI: Hard float (32-bit CPU, 64-bit FPU)
; ISA: GPR size: 64
; FR0: CPR1 size: 32
; FR1: CPR1 size: 64

define double @sum(double %x, double %y) {
  %z = fadd double %x, %y
  ret double %z
}
