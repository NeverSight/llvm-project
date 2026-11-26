# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %s -o %t.be
# RUN: llvm-objdump -s -j .compact -j .extended -j .limits %t.be | FileCheck %s --check-prefix=BE
# RUN: llvm-readobj -r %t.be | FileCheck %s --check-prefix=RELOC
# RUN: llvm-mc -triple=mipsel -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %s -o %t.le
# RUN: llvm-objdump -s -j .compact -j .extended -j .limits %t.le | FileCheck %s --check-prefix=LE
# RUN: llvm-readobj -r %t.le | FileCheck %s --check-prefix=RELOC
# RUN: not llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -filetype=obj -defsym INVALID=1 %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=ERR

# Compare both instruction halfwords with GNU as. The backwards branch in
# .limits no longer fits its signed eight-bit field, while the forward one
# reaches its exact positive limit. The external branch carries a -4 REL addend.
# BE-LABEL: Contents of section .compact:
# BE-NEXT: 0000 10042bfe 210260fc 61006500
# BE-LABEL: Contents of section .extended:
# BE-NEXT: 0000 6500f000 1009f7ff 221bf000 2905f7ff
# BE-NEXT: 0010 6017f000 61016500 6500
# BE-LABEL: Contents of section .limits:
# BE-NEXT: 0000 227f0000
# BE:      0100 f77f2a1e f7ff101e
# LE-LABEL: Contents of section .compact:
# LE-NEXT: 0000 0410fe2b 0221fc60 00610065
# LE-LABEL: Contents of section .extended:
# LE-NEXT: 0000 006500f0 0910fff7 1b2200f0 0529fff7
# LE-NEXT: 0010 176000f0 01610065 0065
# LE-LABEL: Contents of section .limits:
# LE-NEXT: 0000 7f220000
# LE:      0100 7ff71e2a fff71e10
# RELOC: 0x104 R_MIPS16_PC16_S1 external

  .set noreorder
  .set mips16
  .section .compact,"ax",@progbits
.Lstart:
  b .Lnear
  bnez $3, .Lstart
  beqz $17, .Lnear
  bteqz .Lstart
  btnez .Lnear
.Lnear:
  .insn
  .2byte 0x6500
  .section .extended,"ax",@progbits
.Lback:
  .insn
  .2byte 0x6500
  b.e .Lafter
  beqz.e $2, .Lback
  bnez.e $17, .Lafter
  bteqz.e .Lback
  btnez.e .Lafter
  .2byte 0x6500
.Lafter:
  .insn
  .2byte 0x6500
  .section .limits,"ax",@progbits
.Lfirst:
  beqz $2, .Lend
  .space 254
.Lend:
  bnez $2, .Lfirst
  b external

  .ifdef INVALID
  b.e 65536
# ERR: error: invalid MIPS16 branch displacement
  beqz $2, 3
# ERR: error: invalid MIPS16 branch displacement
  .endif
