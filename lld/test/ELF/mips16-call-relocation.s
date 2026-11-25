# REQUIRES: mips
# RUN: split-file %s %t
# RUN: yaml2obj %t/calls.yaml -DDATA=ELFDATA2MSB -DCALLS=180000006500180000016500 -o %t/be.o
# RUN: yaml2obj %t/calls.yaml -DDATA=ELFDATA2LSB -DCALLS=001800000065001801000065 -o %t/le.o
# RUN: ld.lld -e caller -T %t/script %t/be.o -o %t/be
# RUN: llvm-objdump -s -j .calls %t/be | FileCheck %s --check-prefix=BE
# RUN: ld.lld -r %t/le.o -o %t/partial.o
# RUN: ld.lld -e caller -T %t/script %t/partial.o -o %t/le
# RUN: llvm-objdump -s -j .calls %t/le | FileCheck %s --check-prefix=LE
# RUN: not ld.lld -e caller -T %t/script --defsym=far=1 %t/be.o -o /dev/null 2>&1 | FileCheck %s --check-prefix=REGION
# RUN: not ld.lld -e caller -T %t/script --defsym=misaligned=1 %t/be.o -o /dev/null 2>&1 | FileCheck %s --check-prefix=ALIGN
# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+noabicalls,+micromips -filetype=obj %t/micro.s -o %t/micro.o
# RUN: not ld.lld -r %t/be.o %t/micro.o -o /dev/null 2>&1 | FileCheck %s --check-prefix=MIX

## Compare with GNU ld for the same O32 REL objects. The first call targets
## MIPS16 and the second targets classic MIPS with a nonzero implicit addend.
# BE: Contents of section .calls:
# BE-NEXT: 11000000 1902d158 65001e26 59e16500
# LE: Contents of section .calls:
# LE-NEXT: 11000000 021958d1 0065261e e1590065
# REGION: R_MIPS16_26 target outside the jump region of PC+4
# ALIGN: R_MIPS16_26
# ALIGN-SAME: aligned
# MIX: MIPS16 and microMIPS cannot share an ELF ISA mode bit

#--- calls.yaml
--- !ELF
FileHeader:
  Class:   ELFCLASS32
  Data:    [[DATA]]
  Type:    ET_REL
  Machine: EM_MIPS
  Flags:   [ EF_MIPS_ARCH_32R2, EF_MIPS_ABI_O32, EF_MIPS_ARCH_ASE_M16 ]
Sections:
  - Name:    .calls
    Type:    SHT_PROGBITS
    Flags:   [ SHF_ALLOC, SHF_EXECINSTR ]
    Content: "[[CALLS]]"
  - Name:    .narrow
    Type:    SHT_PROGBITS
    Flags:   [ SHF_ALLOC, SHF_EXECINSTR ]
    Size:    2
  - Name:    .wide
    Type:    SHT_PROGBITS
    Flags:   [ SHF_ALLOC, SHF_EXECINSTR ]
    Size:    12
  - Name: .rel.calls
    Type: SHT_REL
    Info: .calls
    Link: .symtab
    Relocations:
      - { Offset: 0, Type: R_MIPS16_26, Symbol: narrow }
      - { Offset: 6, Type: R_MIPS16_26, Symbol: wide }
Symbols:
  - { Name: caller, Section: .calls, Binding: STB_GLOBAL, Type: STT_FUNC, Other: [ STO_MIPS_MIPS16 ] }
  - { Name: narrow, Section: .narrow, Binding: STB_GLOBAL, Type: STT_FUNC, Other: [ STO_MIPS_MIPS16 ] }
  - { Name: wide, Section: .wide, Binding: STB_GLOBAL, Type: STT_FUNC }

#--- script
PHDRS { caller PT_LOAD; narrow PT_LOAD; wide PT_LOAD; }
SECTIONS {
  .calls (DEFINED(far) ? 0x0ffffff0 : 0x11000000) : { *(.calls) } :caller
  .narrow (DEFINED(misaligned) ? 0x11234562 : 0x11234560) : { *(.narrow) } :narrow
  .wide 0x13456780 : { *(.wide) } :wide
}
#--- micro.s
nop
