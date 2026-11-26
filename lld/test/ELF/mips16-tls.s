# REQUIRES: mips
# RUN: split-file %s %t
# RUN: yaml2obj %t/input.yaml -DDATA=ELFDATA2MSB -DTEXT=f0006a00f0004a00f0009b00 -o %t/be.o
# RUN: yaml2obj %t/input.yaml -DDATA=ELFDATA2LSB -DTEXT=00f0006a00f0004a00f0009b -o %t/le.o
# RUN: ld.lld -static -e samples -T %t/layout %t/be.o -o %t/be
# RUN: llvm-objdump -s -j .samples -j .got %t/be | FileCheck %s --check-prefix=BE
# RUN: ld.lld -r %t/le.o -o %t/partial.o
# RUN: ld.lld -static -e samples -T %t/layout %t/partial.o -o %t/le
# RUN: llvm-objdump -s -j .samples -j .got %t/le | FileCheck %s --check-prefix=LE

## Variable offset 0x10234 minus the o32 thread-pointer bias is 0x9234.
## The signed LO16 needs a carry into HI16. The initial-exec load uses
## the third GOT entry (GP - 0x7fe8), which holds the same displacement.
# BE:      Contents of section .samples:
# BE-NEXT: 400000 f0006a01 f2324a14 f0109b18
# BE:      Contents of section .got:
# BE-NEXT: 410000 00000000 80000000 00009234
# LE:      Contents of section .samples:
# LE-NEXT: 400000 00f0016a 32f2144a 10f0189b
# LE:      Contents of section .got:
# LE-NEXT: 410000 00000000 00000080 34920000

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
  - Name: .tbss
    Type: SHT_NOBITS
    Flags: [ SHF_ALLOC, SHF_WRITE, SHF_TLS ]
    Size: 0x10238
  - Name: .rel.samples
    Type: SHT_REL
    Info: .samples
    Link: .symtab
    Relocations:
      - { Offset: 0, Type: R_MIPS16_TLS_TPREL_HI16, Symbol: v }
      - { Offset: 4, Type: R_MIPS16_TLS_TPREL_LO16, Symbol: v }
      - { Offset: 8, Type: R_MIPS16_TLS_GOTTPREL, Symbol: v }
Symbols:
  - { Name: samples, Section: .samples, Type: STT_FUNC, Binding: STB_GLOBAL }
  - { Name: v, Section: .tbss, Value: 0x10234, Type: STT_TLS, Binding: STB_GLOBAL }

#--- layout
SECTIONS {
  .samples 0x400000 : { *(.samples) }
  .got 0x410000 : { *(.got) }
  .tbss 0x420000 : { *(.tbss) }
}
