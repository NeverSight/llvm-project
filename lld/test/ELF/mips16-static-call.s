# REQUIRES: mips
# RUN: split-file %s %t
# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+noabicalls -filetype=obj %t/main.s -o %t/main.o
# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+noabicalls,+mips16 -filetype=obj %t/calc.s -o %t/calc.o
# RUN: ld.lld -T %t/script -e calc %t/main.o %t/calc.o -o %t/a
# RUN: llvm-objdump -s -j .text -j .data %t/a | FileCheck %s --check-prefix=STATIC
# RUN: llvm-readobj -h -s %t/a | FileCheck %s --check-prefix=SYM
# RUN: ld.lld -r %t/calc.o -o %t/partial.o
# RUN: ld.lld -T %t/script -e calc %t/main.o %t/partial.o -o %t/b
# RUN: llvm-objdump -s -j .text -j .data %t/b | FileCheck %s --check-prefix=STATIC
# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -position-independent -mattr=+mips16 -filetype=obj %t/calc.s -o %t/pic.o
# RUN: ld.lld -T %t/script -e caller %t/main.o %t/pic.o -o %t/pic
# RUN: llvm-objdump -d --mattr=-mips16 --no-show-raw-insn %t/pic | FileCheck %s --check-prefix=PIC

## The ordinary JAL becomes JALX. Both the data pointer and e_entry carry
## the mode bit. The function's static symbol retains its physical address.
# STATIC: Contents of section .text:
# STATIC-NEXT:  20000 74008400 00000000
# STATIC: Contents of section .data:
# STATIC-NEXT:  22000 00021001
# SYM: Entry: 0x21001
# SYM: Name: calc (
# SYM-NEXT: Value: 0x21000
# SYM: Other [ (0xF0)
# PIC: <caller>:
# PIC-NEXT: {{.*}}jal {{.*}}<__LA25Thunk_calc>
# PIC: <__LA25Thunk_calc>:
# PIC-NEXT: {{.*}}lui $25, 0x2
# PIC-NEXT: {{.*}}addiu $25, $25, 0x1011
# PIC-NEXT: {{.*}}jr $25
# PIC-NEXT: {{.*}}nop

#--- main.s
.set noreorder
.text
.globl caller
caller:
  jal calc
  nop
.data
.word calc

#--- calc.s
.section .calc,"ax",@progbits
.globl calc
.ent calc
calc:
  .insn
  .2byte 0xe8a0 # jrc $ra
.end calc

#--- script
SECTIONS {
  .text 0x20000 : { *(.text) }
  .calc 0x21000 : { *(.calc) }
  .data 0x22000 : { *(.data) }
}
