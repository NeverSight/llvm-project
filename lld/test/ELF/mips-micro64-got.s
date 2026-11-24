# REQUIRES: mips

# RUN: llvm-mc -triple=mips64 -mcpu=mips64r2 -mattr=+micromips -filetype=obj %s -o %t.BE.o
# RUN: ld.lld --defsym=far_symbol=0x1234f67e9abcfed8 --section-start=.text=0x100010000 --section-start=.got=0x100038000 --section-start=.data=0x100048020 -e entry %t.BE.o -o %t.BE
# RUN: llvm-objdump -d --mattr=+micromips --no-print-imm-hex --no-show-raw-insn %t.BE | FileCheck %s
# RUN: llvm-readelf -x .got %t.BE | FileCheck %s --check-prefix=BE

# RUN: llvm-mc -triple=mips64el -mcpu=mips64r2 -mattr=+micromips -filetype=obj %s -o %t.LE.o
# RUN: ld.lld --defsym=far_symbol=0x1234f67e9abcfed8 --section-start=.text=0x100010000 --section-start=.got=0x100038000 --section-start=.data=0x100048020 -e entry %t.LE.o -o %t.LE
# RUN: llvm-objdump -d --mattr=+micromips --no-print-imm-hex --no-show-raw-insn %t.LE | FileCheck %s
# RUN: llvm-readelf -x .got %t.LE | FileCheck %s --check-prefix=LE

## $t9 carries the tagged entry address. The first pair therefore computes
## 0x10003fff0 - 0x100010001. The local data address is 0x100048028.
# CHECK:      lui $2, 3
# CHECK-NEXT: daddiu $2, $2, -17
# CHECK-NEXT: ld $3, -32720($gp)
# CHECK-NEXT: ld $4, -32736($gp)
# CHECK-NEXT: daddiu $4, $4, -32728
# CHECK-NEXT: lui $5, 4661
# CHECK-NEXT: daddiu $5, $5, -2433
# CHECK-NEXT: dsll $5, $5, 16
# CHECK-NEXT: daddiu $5, $5, -25923
# CHECK-NEXT: dsll $5, $5, 16
# CHECK-NEXT: jr $ra
# CHECK-NEXT: daddiu $5, $5, -296

# BE: 0x100038010 00000001 00050000
# BE: 0x100038020 00000001 00048020
# LE: 0x100038010 00000500 01000000
# LE: 0x100038020 20800400 01000000

.set micromips
.set noreorder
.option pic2
.text
.globl entry
.ent entry
entry:
  lui $2, %hi(%neg(%gp_rel(entry)))
  daddiu $2, $2, %lo(%neg(%gp_rel(entry)))
  ld $3, %got_disp(global)($gp)
  ld $4, %got_page(.Llocal)($gp)
  daddiu $4, $4, %got_ofst(.Llocal)
  lui $5, %highest(far_symbol)
  daddiu $5, $5, %higher(far_symbol)
  dsll $5, $5, 16
  daddiu $5, $5, %hi(far_symbol)
  dsll $5, $5, 16
  jr $ra
  daddiu $5, $5, %lo(far_symbol)
.end entry
.data
.globl global
global:
  .dword 37
.Llocal:
  .dword 43
