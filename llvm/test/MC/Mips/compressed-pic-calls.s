# RUN: split-file %s %t
# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %t/m16.s -o %t.m16be
# RUN: llvm-mc -triple=mipsel -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %t/m16.s -o %t.m16le
# RUN: llvm-objdump -s -j .pic16 %t.m16be | FileCheck %s --check-prefix=M16BE
# RUN: llvm-objdump -s -j .pic16 %t.m16le | FileCheck %s --check-prefix=M16LE
# RUN: llvm-readobj -r %t.m16be | FileCheck %s --check-prefix=REL
# RUN: llvm-readobj -r %t.m16le | FileCheck %s --check-prefix=REL
# RUN: llvm-mc -triple=mips -mcpu=mips32r6 -mattr=+micromips -filetype=obj %t/mm.s -o %t.mmbe
# RUN: llvm-mc -triple=mipsel -mcpu=mips32r6 -mattr=+micromips -filetype=obj %t/mm.s -o %t.mmle
# RUN: llvm-objdump -d --mcpu=mips32r6 --mattr=+micromips %t.mmbe | FileCheck %s --check-prefixes=MMBE,MM
# RUN: llvm-objdump -d --mcpu=mips32r6 --mattr=+micromips %t.mmle | FileCheck %s --check-prefixes=MMLE,MM

# The MIPS16 GP setup and register calls agree with GNU as 2.42.
# M16BE: 0000 f0006a00 f0000b00 eac0e8c0 efc00b01
# M16BE-NEXT: 0010 f7ff0b1c f0000b04
# M16LE: 0000 00f0006a 00f0000b c0eac0e8 c0ef010b
# M16LE-NEXT: 0010 fff71c0b 00f0040b
# REL: 0x0 R_MIPS16_HI16 _gp_disp
# REL-NEXT: 0x4 R_MIPS16_LO16 _gp_disp

#--- m16.s
.set mips16
.set noreorder
.section .pic16,"ax",@progbits
li $2, %hi(_gp_disp)
addiu $3, $pc, %lo(_gp_disp)
jalrc $2
jalrc $16
jalrc $7
addiu $3, $pc, 4
addiu $3, $pc, -4
addiu.e $3, $pc, 4

#--- mm.s
.text
.set noreorder
.set micromips
f:
# The same major opcode selects equality or overflow by register order.
# MMBE-COUNT-2: 74 83 00 08 {{.*}}beqc
# MMLE-COUNT-2: 83 74 08 00 {{.*}}beqc
beqc $3, $4, 16
beqc $4, $3, 16
# MMBE-COUNT-2: 7c 83 00 08 {{.*}}bnec
# MMLE-COUNT-2: 83 7c 08 00 {{.*}}bnec
bnec $3, $4, 16
bnec $4, $3, 16
# MMBE-COUNT-2: 74 64 00 08 {{.*}}bovc
# MMLE-COUNT-2: 64 74 08 00 {{.*}}bovc
bovc $3, $4, 16
bovc $4, $3, 16
# MMBE-COUNT-2: 7c 64 00 08 {{.*}}bnvc
# MMLE-COUNT-2: 64 7c 08 00 {{.*}}bnvc
bnvc $3, $4, 16
bnvc $4, $3, 16
# MM: move16 $gp, $16
# MM-NEXT: {{.*}}move16 $2, $sp
move $gp, $16
move $2, $sp
