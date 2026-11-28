# RUN: not llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %s -o %t 2>&1 | FileCheck %s
.set mips16
save $f1, 32
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error: expected $ra or $s0 through $s2
restore $s2-$s0, 16
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error: invalid MIPS16 frame register range
save $ra, 2048
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error: MIPS16 frame size must be a multiple of 8
restore 4
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error: MIPS16 frame size must be a multiple of 8
save 16, 32
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error: duplicate MIPS16 frame size
li $2, -1
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error:
addiu $2, $3, 16384
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error:
sw $2, 32768($sp)
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error:
lw $2, 4($8)
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error:
lbu $2, 4($sp)
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error:
jrc $8
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error:
sw $2, 4($pc)
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error: $pc base requires a MIPS16 literal load
lw $2, 32768($pc)
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error:
lw $2, 3($pc)
# CHECK: :[[@LINE-1]]:{{[0-9]+}}: error:
