; RUN: llc -mtriple=mips64-linux-gnuabi64 -mcpu=mips5 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=N64,BE,ISA
; RUN: llc -mtriple=mips64el-linux-gnuabi64 -mcpu=mips5 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=N64,LE,ISA
; RUN: llc -mtriple=mips64-linux-gnuabin32 -mcpu=mips5 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=N32,BE,ISA
; RUN: llc -mtriple=mips64el-linux-gnuabin32 -mcpu=mips5 -filetype=obj %s -o %t
; RUN: llvm-readobj --file-headers --arch-specific %t | FileCheck %s --check-prefixes=N32,LE,ISA
; RUN: llc -mtriple=mips64-linux-gnuabin32 -mcpu=mips5 -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=ASM
;
; N64: AddressSize: 64bit
; N32: AddressSize: 32bit
; BE: DataEncoding: BigEndian
; LE: DataEncoding: LittleEndian
; N32: EF_MIPS_ABI2
; ISA: EF_MIPS_ARCH_5
; ISA: ISA: MIPS5
; ISA: GPR size: 64
; ISA: CPR1 size: 64

; ASM-LABEL: add_shift:
; ASM: daddu
; ASM: dsll
define i64 @add_shift(i64 %x, i64 %y) {
  %sum = add i64 %x, %y
  %result = shl i64 %sum, 3
  ret i64 %result
}

; ASM-LABEL: dot:
; ASM: mul.d
define double @dot(double %x, double %y) {
  %p = fmul double %x, %y
  ret double %p
}
