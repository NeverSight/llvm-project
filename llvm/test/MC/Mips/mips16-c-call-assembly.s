# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %s -o %t.be
# RUN: llvm-objdump -s -j .args -j .calls -j .pools -j .offsets -j .fallthrough -j .padding %t.be | FileCheck %s --check-prefix=BE
# RUN: llvm-readobj -r %t.be | FileCheck %s --check-prefix=REL
# RUN: llvm-mc -triple=mipsel -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %s -o %t.le
# RUN: llvm-objdump -s -j .args -j .calls -j .pools -j .offsets -j .fallthrough -j .padding %t.le | FileCheck %s --check-prefix=LE
# RUN: llvm-readobj -r %t.le | FileCheck %s --check-prefix=REL

# The calling, literal and fallthrough sequences agree with GNU as 2.42.
# BE-LABEL: Contents of section .args:
# BE-NEXT: 0000 64ccf110 64f1f110 6471f000 64806400
# BE-NEXT: 0010 6cfff100 6c00f000 6c014a80 f0804a00
# BE-NEXT: 0020 02fff400 020063fe 4348f7ff 4347e285
# BE-NEXT: 0030 ea8de9ee 339cf7c0 32433342 82fff020
# BE-NEXT: 0040 a2e089df f040a9c0 9b3ff080 9b20c2ff
# BE-NEXT: 0050 c9dfd2ff f400d200 f000d204 f7ff921c
# BE-NEXT: 0060 b201f000 b204e8a0
# BE-LABEL: Contents of section .calls:
# BE-NEXT: 0000 18000000 4a011c00 00006500 18000000
# BE-NEXT: 0010 6500e8a0
# BE-LABEL: Contents of section .pools:
# BE-NEXT: 0000 10203040 f7ffb21c b302f000 b4080000
# BE-NEXT: 0010 50607080
# BE-LABEL: Contents of section .offsets:
# BE-NEXT: 0000 6500b2ff 00000000 00000000 00000000
# BE: 0400 6500f400 b3000000 00000000 00000000
# BE: 0800 11223344
# BE-LABEL: Contents of section .fallthrough:
# BE-NEXT: 0000 682b6500 4801e8a0
# BE-LABEL: Contents of section .padding:
# BE-NEXT: 0000 a5006500 65006500 65006500 65006500
# BE-COUNT-31: 65006500 65006500 65006500 65006500
# BE-NEXT: 0200 abcd
# LE-LABEL: Contents of section .args:
# LE-NEXT: 0000 cc6410f1 f16410f1 716400f0 80640064
# LE-NEXT: 0010 ff6c00f1 006c00f0 016c804a 80f0004a
# LE-NEXT: 0020 ff0200f4 0002fe63 4843fff7 474385e2
# LE-NEXT: 0030 8deaeee9 9c33c0f7 43324233 ff8220f0
# LE-NEXT: 0040 e0a2df89 40f0c0a9 3f9b80f0 209bffc2
# LE-NEXT: 0050 dfc9ffd2 00f400d2 00f004d2 fff71c92
# LE-NEXT: 0060 01b200f0 04b2a0e8
# LE-LABEL: Contents of section .calls:
# LE-NEXT: 0000 00180000 014a001c 00000065 00180000
# LE-NEXT: 0010 0065a0e8
# LE-LABEL: Contents of section .pools:
# LE-NEXT: 0000 40302010 fff71cb2 02b300f0 08b40000
# LE-NEXT: 0010 80706050
# LE-LABEL: Contents of section .offsets:
# LE-NEXT: 0000 0065ffb2 00000000 00000000 00000000
# LE: 0400 006500f4 00b30000 00000000 00000000
# LE: 0800 44332211
# LE-LABEL: Contents of section .fallthrough:
# LE-NEXT: 0000 2b680065 0148a0e8
# LE-LABEL: Contents of section .padding:
# LE-NEXT: 0000 a5000065 00650065 00650065 00650065
# LE-COUNT-31: 00650065 00650065 00650065 00650065
# LE-NEXT: 0200 cdab
# REL: 0x0 R_MIPS16_26 callee
# REL-NEXT: 0x6 R_MIPS16_26 classic
# REL-NEXT: 0xC R_MIPS16_26 callee

# Each extended instruction consists of two target-endian halfwords.
.set mips16
.set noreorder
.section .args,"ax",@progbits
save $ra, 96
save $s0-$s2, $ra, 136
restore 136, $s0-$s2, $ra
save 0
restore 128
li $4, 255
li $4, 256
li.e $4, 1
addiu $2, -128
addiu $2, 128
addiu $2, $sp, 1020
addiu $2, $sp, 1024
addiu $sp, -16
addiu $2, $3, -8
addiu $2, $3, -9
addu $17, $2, $4
or $2, $4
xor $17, $7
sll $3, $4, 7
sra $2, $2, 31
srl $3, $2, 8
lb $7, 31($2)
lbu $7, 32($2)
lh $6, 62($17)
lhu $6, 64($17)
lw $17, 124($3)
lw $17, 128($3)
sb $7, 31($2)
sh $6, 62($17)
sw $2, 1020($sp)
sw $2, 1024($sp)
sw.e $2, 4($sp)
lw $2, -4($sp)
lw $2, 4($pc)
lw.e $2, 4($pc)
jrc $ra

.section .calls,"ax",@progbits
jal callee
addiu $2, 1
jalx classic
nop
# With reorder the assembler owns one compact delay slot.
.set reorder
jal callee
.set noreorder
jrc $ra

.section .pools,"ax",@progbits
.Lprevious:
.word 0x10203040
lw $2, .Lprevious
lw $3, .Lnear
lw.e $4, .Lnear
.balign 4, 0
.Lnear:
.word 0x50607080

.section .offsets,"ax",@progbits
# At byte offset two the base is the preceding word. Exactly 1020 fits.
nop
lw $2, .Llimit
.space 1016
.Llimit:
.word 0
# One word further requires EXTEND. Keep the destination fixed during layout.
nop
lw $3, .Lfar
.org 2048
.Lfar:
.word 0x11223344

.section .fallthrough,"ax",@progbits
li $16, 43
.p2align 2
addiu $16, 1
jrc $ra

# Odd-sized data needs one zero byte before the aligned NOPs begin.
.section .padding,"ax",@progbits
.byte 0xa5
.p2align 9
.2byte 0xabcd
