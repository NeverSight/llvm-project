# REQUIRES: mips
# RUN: split-file %s %t
# RUN: llvm-mc -filetype=obj -triple=mips64 -mcpu=mips64r2 -mattr=+micromips %t/lib.s -o %t/lib.o
# RUN: ld.lld -shared %t/lib.o -o %t/lib.so
# RUN: llvm-mc -filetype=obj -triple=mips64 -mcpu=mips64r2 -mattr=+micromips %t/call-r2.s -o %t/r2.o
# RUN: ld.lld -Ttext=0x100218000 --section-start=.plt=0x100238000 --section-start=.got.plt=0x500348000 -e caller %t/r2.o %t/lib.so -o %t/r2
# RUN: llvm-objdump -d --mattr=+micromips --no-print-imm-hex --no-show-raw-insn %t/r2 | FileCheck %s --check-prefix=R2
# RUN: llvm-readelf -r -x .got.plt -x .plt %t/r2 | FileCheck %s --check-prefixes=REL,BE
# RUN: llvm-mc -filetype=obj -triple=mips64 -mcpu=mips64r2 -mattr=+micromips %t/edge.s -o %t/edge.o
# RUN: ld.lld -Ttext=0x107fffff0 --section-start=.plt=0x108020000 -e caller %t/edge.o %t/lib.so -o %t/edge
# RUN: llvm-objdump -d -j .text --mattr=+micromips --no-show-raw-insn %t/edge | FileCheck %s --check-prefix=EDGE
# RUN: not ld.lld -Ttext=0x100218000 --section-start=.plt=0x108020000 -e caller %t/r2.o %t/lib.so -o %t/far 2>&1 | FileCheck %s --check-prefix=REGION
# EDGE: 107fffffc: jal 0x108020038
# REGION: R_MICROMIPS_26_S1 target outside the jump region of PC+4
# RUN: llvm-mc -filetype=obj -triple=mips64el -mcpu=mips64r6 -mattr=+micromips %t/lib.s -o %t/libel.o
# RUN: ld.lld -shared %t/libel.o -o %t/libel.so
# RUN: llvm-mc -filetype=obj -triple=mips64el -mcpu=mips64r6 -mattr=+micromips %t/call-r6.s -o %t/r6.o
# RUN: ld.lld -Ttext=0x100218000 --section-start=.plt=0x100238000 --section-start=.got.plt=0x500348000 -e caller %t/r6.o %t/libel.so -o %t/r6
# RUN: llvm-objdump -d --mattr=+micromips --no-print-imm-hex --no-show-raw-insn %t/r6 | FileCheck %s --check-prefix=R6
# RUN: llvm-readelf -r -x .got.plt -x .plt %t/r6 | FileCheck %s --check-prefixes=REL,LE
# RUN: ld.lld -Ttext=0x100218000 --section-start=.plt=0x100238000 --section-start=.got.plt=0x100240000 -e caller %t/r6.o %t/libel.so -o %t/near
# RUN: llvm-objdump -d -j .plt --mattr=+micromips --no-print-imm-hex --no-show-raw-insn %t/near | FileCheck %s --check-prefix=NEAR

# RUN: llvm-mc -filetype=obj -triple=mips64el -mcpu=mips64r6 %t/classic.s -o %t/classic.o
# RUN: llvm-mc -filetype=obj -triple=mips64el -mcpu=mips64r6 -mattr=+micromips %t/cross-r6.s -o %t/cross.o
# RUN: not ld.lld -e caller %t/cross.o %t/classic.o -o %t/bad 2>&1 | FileCheck %s --check-prefix=MODE
# MODE: unsupported jump/branch instruction between ISA modes referenced by R_MICROMIPS_PC26_S1
# MODE: unsupported jump/branch instruction between ISA modes referenced by R_MICROMIPS_PC21_S1

## The caller reaches the entry, which loads a full-width GOT slot. On lazy
## binding the header passes the GOT base, the original return PC and the slot
## index in $14, $15 and $24. A resolved entry returns through its original $ra.
# R2:      100218000: jal 0x100238038
# R2:      100238000: move $15, $ra
# R2-NEXT: 100238002: bal 0x10023800a
# R2:      10023800a: ld $2, 37($ra)
# R2-NEXT: 10023800e: daddu $2, $ra, $2
# R2-NEXT: 100238012: ld $25, 0($2)
# R2-NEXT: 100238016: dsubu $24, $24, $2
# R2-NEXT: 10023801a: dsrl $24, $24, 3
# R2-NEXT: 10023801e: daddiu $24, $24, -2
# R2-NEXT: 100238022: move $14, $2
# R2-NEXT: 100238024: jalr $ra, $25
# R2:      100238042: ld $2, 21($ra)
# R2:      10023804a: ld $25, 0($2)
# R2-NEXT: 10023804e: move $ra, $15
# R2-NEXT: 100238050: jr16 $25
# R2-NEXT: 100238052: move $24, $2
# R6:      100218000: balc 0x100238030
# R6:      100238000: lapc $3, 0
# R6-NEXT: 100238004: ld $2, 40($3)
# R6-NEXT: 100238008: daddu $2, $2, $3
# R6-NEXT: 10023800c: ld $25, 0($2)
# R6:      100238020: jalrc $25
# R6:      100238034: ld $2, 24($3)
# R6:      10023803c: ld $25, 0($2)
# R6-NEXT: 100238040: move16 $24, $2
# R6-NEXT: 100238042: jrc16 $25
# NEAR:      100238000: lapc $2, 32768
# NEAR-NEXT: 100238004: ld $25, 0($2)

# REL: 0000000500348010 {{.*}} R_MIPS_JUMP_SLOT{{.*}} callee
# BE-DAG: 0x100238030 00000004 0010fff5
# BE-DAG: 0x500348010 00000001 00238001
# LE-DAG: 00001100 04000000
# LE-DAG: 0x500348010 01802300 01000000

#--- lib.s
.set micromips
.text
.globl callee
.type callee,@function
.ent callee
callee:
  nop
.end callee

#--- call-r2.s
.set micromips
.set noreorder
.option pic0
.text
.globl caller
.ent caller
caller:
  jal callee
  nop
.end caller

#--- call-r6.s
.set micromips
.set noreorder
.option pic0
.text
.globl caller
.ent caller
caller:
  balc callee
.end caller

#--- classic.s
.option pic0
.text
.globl callee
.ent callee
callee:
  nop
.end callee

#--- cross-r6.s
.set micromips
.set noreorder
.option pic0
.text
.globl caller
.ent caller
caller:
  balc callee
  beqzc $4, callee
.end caller

#--- edge.s
.set micromips
.set noreorder
.option pic0
.text
.space 12
.globl caller
.ent caller
caller:
  jal callee
  nop
.end caller
