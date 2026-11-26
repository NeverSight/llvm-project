# REQUIRES: mips
# RUN: split-file %s %t
# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %t/from.s -o %t/from.be
# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %t/to.s -o %t/to.be
# RUN: ld.lld -static -T %t/layout %t/from.be %t/to.be -o %t/big
# RUN: llvm-objdump -s -j .to -j .from %t/big | FileCheck %s --check-prefix=BE
# RUN: llvm-mc -triple=mipsel -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %t/from.s -o %t/from.le
# RUN: llvm-mc -triple=mipsel -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %t/to.s -o %t/to.le
# RUN: ld.lld -r %t/from.le %t/to.le -o %t/partial.o
# RUN: ld.lld -static -T %t/layout %t/partial.o -o %t/little
# RUN: llvm-objdump -s -j .to -j .from %t/little | FileCheck %s --check-prefix=LE
# RUN: not ld.lld -static --defsym=far=1 -T %t/layout %t/from.be %t/to.be -o /dev/null 2>&1 | FileCheck %s --check-prefix=RANGE
# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -filetype=obj -defsym CLASSIC=1 %t/to.s -o %t/classic.o
# RUN: not ld.lld -static -T %t/layout %t/from.be %t/classic.o -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE

## The O32 REL fields include the PC+4 bias. Check forward and backward
## branches and signed addends of both signs against GNU as and ld output.
# BE-LABEL: Contents of section .to:
# BE-NEXT: 400000 65006500 f100100c
# BE-LABEL: Contents of section .from:
# BE-NEXT: 400220 f6ff100f f6ff220e f6ff290a
# LE-LABEL: Contents of section .to:
# LE-NEXT: 400000 00650065 00f10c10
# LE-LABEL: Contents of section .from:
# LE-NEXT: 400220 fff60f10 fff60e22 fff60a29
# RANGE: relocation R_MIPS16_PC16_S1 out of range
# MODE: R_MIPS16_PC16_S1 cannot branch to a different ISA mode: target

#--- from.s
.set noreorder
.set mips16
.section .from,"ax",@progbits
.globl entry
.ent entry
entry:
  b.e target
  beqz.e $2, target+2
  bnez.e $17, target-2
.end entry

#--- to.s
.set noreorder
.section .to,"ax",@progbits
.ifdef CLASSIC
  .set nomips16
  .4byte 0
.else
  .set mips16
  .2byte 0x6500
.endif
.globl target
.ent target
target:
  .insn
.ifdef CLASSIC
  nop
.else
  .2byte 0x6500
  b.e entry
.endif
.end target

#--- layout
ENTRY(entry)
SECTIONS {
  .to 0x400000 : { *(.to) }
  .from (DEFINED(far) ? 0x420000 : 0x400220) : { *(.from) }
}
