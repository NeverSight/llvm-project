// REQUIRES: mips-registered-target
// RUN: mkdir -p %t.be %t.le
// RUN: cd %t.be && %clang -target mips-linux-gnu -march=mips32r2 -mabi=32 -mips16 -mno-abicalls -fno-pic -ffreestanding -O2 -fintegrated-as -save-temps=obj -c %s -o call.o
// RUN: llvm-readobj --relocations %t.be/call.o | FileCheck %s
// RUN: cd %t.le && %clang -target mipsel-linux-gnu -march=mips32r2 -mabi=32 -mips16 -mno-abicalls -fno-pic -ffreestanding -O2 -fintegrated-as -save-temps=obj -c %s -o call.o
// RUN: llvm-readobj --relocations %t.le/call.o | FileCheck %s
// CHECK: R_MIPS16_26 consume

extern void consume(unsigned char *, unsigned);
unsigned call(unsigned value, unsigned other) {
  unsigned char area[2064];
  area[0] = (unsigned char)value;
  consume(area, sizeof(area));
  return (area[0] ^ other) + 0x10203040;
}
