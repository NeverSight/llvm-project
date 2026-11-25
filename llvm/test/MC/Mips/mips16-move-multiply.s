# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %s -o %t.be
# RUN: llvm-objdump -s -j .text %t.be | FileCheck %s --check-prefix=BE
# RUN: llvm-mc -triple=mipsel -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %s -o %t.le
# RUN: llvm-objdump -s -j .text %t.le | FileCheck %s --check-prefix=LE
# RUN: not llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -defsym INVALID=1 %s 2>&1 | FileCheck %s --check-prefix=ERR

# BE: 675f6738 65db6550 ecb8ea12 eef9eb10
# LE: 5f673867 db655065 b8ec12ea f9ee10eb
  .set noreorder
  .set mips16
  move $2, $31
  move $17, $24
  move $30, $3
  move $18, $16
  mult $4, $5
  mflo $2
  multu $6, $7
  mfhi $3

  .ifdef INVALID
  move $30, $24
# ERR: :[[@LINE-1]]:{{[0-9]+}}: error:
  mult $f4, $5
# ERR: :[[@LINE-1]]:{{[0-9]+}}: error:
  .endif
