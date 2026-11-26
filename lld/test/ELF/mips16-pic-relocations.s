# REQUIRES: mips
# RUN: split-file %s %t
# RUN: yaml2obj %t/input.yaml -DDATA=ELFDATA2MSB -DTEXT=f0006a00f0000b006500f0006a00f0000b00f0006a02f0009b40f3d56b0df0009b00f0009c00f6606c18f1209d14 -o %t/be.o
# RUN: yaml2obj %t/input.yaml -DDATA=ELFDATA2LSB -DTEXT=00f0006a00f0000b006500f0006a00f0000b00f0026a00f0409bd5f30d6b00f0009b00f0009c60f6186c20f1149d -o %t/le.o
# RUN: ld.lld -static -e samples -T %t/layout %t/be.o -o %t/be
# RUN: llvm-objdump -s -j .samples -j .got %t/be | FileCheck %s --check-prefix=BE
# RUN: ld.lld -static -e samples -T %t/layout %t/le.o -o %t/le
# RUN: llvm-objdump -s -j .samples -j .got %t/le | FileCheck %s --check-prefix=LE
# RUN: ld.lld -r %t/le.o -o %t/partial.o
# RUN: ld.lld -static -e samples -T %t/layout %t/partial.o -o %t/partial
# RUN: llvm-objdump -s -j .samples -j .got %t/partial | FileCheck %s --check-prefix=LE
# RUN: not ld.lld -static -e samples --defsym=far=1 -T %t/layout %t/be.o -o /dev/null 2>&1 | FileCheck %s --check-prefix=RANGE

## O32 REL addends live in both halfwords of each EXTEND instruction.
## The two GP prologues start at offsets 0 and 10. The absolute HI/LO pair
## spans an unrelated CALL16 and has a negative implicit low addend.
# RANGE: R_MIPS16_GPREL out of range
## GNU ld produces the same GP values, absolute address and short-data offset.
## Its GOT has a different order. Check each LLD offset against its own slots.
# BE: Contents of section .samples:
# BE-NEXT: 400000 f0006a02 f0100b0c 6500f000 6a02f010
# BE-NEXT: 400010 0b04f040 6a06f030 9b40f3f5 6b1df030
# BE-NEXT: 400020 9b04f010 9c18f6a0 6c0cf220 9d04
# BE: Contents of section .got:
# BE-NEXT: 410020 00000000 80000000 00440000 00450000
# BE-NEXT: 410030 00400001 00440030
# LE: Contents of section .samples:
# LE-NEXT: 400000 00f0026a 10f00c0b 006500f0 026a10f0
# LE-NEXT: 400010 040b40f0 066a30f0 409bf5f3 1d6b30f0
# LE-NEXT: 400020 049b10f0 189ca0f6 0c6c20f2 049d
# LE: Contents of section .got:
# LE-NEXT: 410020 00000000 00000080 00004400 00004500
# LE-NEXT: 410030 01004000 30004400

#--- input.yaml
--- !ELF
FileHeader:
  Class: ELFCLASS32
  Data: [[DATA]]
  Type: ET_REL
  Machine: EM_MIPS
  Flags: [ EF_MIPS_ARCH_32R2, EF_MIPS_ABI_O32, EF_MIPS_ARCH_ASE_M16 ]
Sections:
  - Name: .samples
    Type: SHT_PROGBITS
    Flags: [ SHF_ALLOC, SHF_EXECINSTR ]
    Content: "[[TEXT]]"
  - Name: .data
    Type: SHT_PROGBITS
    Flags: [ SHF_ALLOC, SHF_WRITE ]
    Size: 8
  - Name: .near
    Type: SHT_PROGBITS
    Flags: [ SHF_ALLOC, SHF_WRITE ]
    Size: 4
  - Name: .rel.samples
    Type: SHT_REL
    Info: .samples
    Link: .symtab
    Relocations:
      - { Offset:  0, Type: R_MIPS16_HI16,   Symbol: _gp_disp }
      - { Offset:  4, Type: R_MIPS16_LO16,   Symbol: _gp_disp }
      - { Offset: 10, Type: R_MIPS16_HI16,   Symbol: _gp_disp }
      - { Offset: 14, Type: R_MIPS16_LO16,   Symbol: _gp_disp }
      - { Offset: 18, Type: R_MIPS16_HI16,   Symbol: datum }
      - { Offset: 22, Type: R_MIPS16_CALL16, Symbol: samples }
      - { Offset: 26, Type: R_MIPS16_LO16,   Symbol: datum }
      - { Offset: 30, Type: R_MIPS16_GOT16,  Symbol: datum }
      - { Offset: 34, Type: R_MIPS16_GOT16,  Symbol: local }
      - { Offset: 38, Type: R_MIPS16_LO16,   Symbol: local }
      - { Offset: 42, Type: R_MIPS16_GPREL,  Symbol: nearby }
Symbols:
  - { Name: local, Section: .data, Type: STT_OBJECT, Value: 4 }
  - { Name: samples, Section: .samples, Binding: STB_GLOBAL, Type: STT_FUNC, Other: [ STO_MIPS_MIPS16 ] }
  - { Name: datum, Section: .data, Binding: STB_GLOBAL, Type: STT_OBJECT }
  - { Name: nearby, Section: .near, Binding: STB_GLOBAL, Type: STT_OBJECT }
  - { Name: _gp_disp, Binding: STB_GLOBAL }

#--- layout
SECTIONS {
  .samples 0x400000 : { *(.samples) }
  .got 0x410020 : { *(.got) }
  .near (DEFINED(far) ? 0x430100 : 0x418100) : { *(.near) }
  .data 0x440030 : { *(.data) }
}
