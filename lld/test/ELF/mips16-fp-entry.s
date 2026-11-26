# REQUIRES: mips
# RUN: split-file %s %t
# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+noabicalls -filetype=obj %t/main.s -o %t/main.o
# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16,+noabicalls -filetype=obj %t/body.s -o %t/body.o
# RUN: yaml2obj %t/calls16.yaml -o %t/calls16.o
# RUN: ld.lld --gc-sections -T %t/layout -e caller %t/main.o %t/body.o %t/calls16.o -o %t/out
# RUN: llvm-objdump -s -j .main -j .calls16 -j .adapter %t/out | FileCheck %s
# RUN: ld.lld -r %t/main.o %t/body.o %t/calls16.o -o %t/combined.o
# RUN: ld.lld --gc-sections -T %t/layout -e caller %t/combined.o -o %t/partial
# RUN: llvm-objdump -s -j .main -j .calls16 -j .adapter %t/partial | FileCheck %s

## The classic JAL, materialized address and data pointer select the adapter,
## while a direct MIPS16 call and the adapter itself select the tagged body.
# CHECK: Contents of section .main:
# CHECK-NEXT: 20000 0c008c00 00000000 3c050002 24a53000
# CHECK-NEXT: 20010 00023000
# CHECK: Contents of section .calls16:
# CHECK-NEXT: 22000 18008400 6500
# CHECK: Contents of section .adapter:
# CHECK-NEXT: 23000 3c190002 27391001 03200008 00000000

#--- main.s
.set noreorder
.section .main,"ax",@progbits
.globl caller
.ent caller
caller:
  jal calc
  nop
  lui $5, %hi(calc)
  addiu $5, $5, %lo(calc)
  .word calc
.end caller

#--- body.s
.set noreorder
.section .body,"ax",@progbits
.globl calc
.ent calc
calc:
  .insn
  .2byte 0xe8a0
.end calc

.set nomips16
.section .mips16.fn.calc,"ax",@progbits
__fn_stub_calc:
  lui $25, %hi(calc)
  addiu $25, $25, %lo(calc)
  jr $25
  nop

#--- calls16.yaml
--- !ELF
FileHeader:
  Class: ELFCLASS32
  Data: ELFDATA2MSB
  Type: ET_REL
  Machine: EM_MIPS
  Flags: [ EF_MIPS_ARCH_32R2, EF_MIPS_ABI_O32, EF_MIPS_ARCH_ASE_M16 ]
Sections:
  - Name: .calls16
    Type: SHT_PROGBITS
    Flags: [ SHF_ALLOC, SHF_EXECINSTR ]
    Content: "180000006500"
  - Name: .rel.calls16
    Type: SHT_REL
    Info: .calls16
    Link: .symtab
    Relocations:
      - { Offset: 0, Type: R_MIPS16_26, Symbol: calc }
Symbols:
  - { Name: calc, Binding: STB_GLOBAL, Type: STT_FUNC }

#--- layout
SECTIONS {
  .main 0x20000 : { *(.main) }
  .body 0x21000 : { *(.body) }
  .calls16 0x22000 : { KEEP(*(.calls16)) }
  .adapter 0x23000 : { *(.mips16.fn.calc) }
}
