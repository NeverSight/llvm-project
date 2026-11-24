# RUN: llvm-mc %s -triple=mips-unknown-linux -show-encoding -mcpu=mips32r6 -mattr=micromips -mattr=+dspr3 | FileCheck %s

  .set noat
  bposge32c 342                # CHECK: bposge32c 342           # encoding: [0x43,0x20,0x00,0xab]

# RUN: llvm-mc %s -triple=mips -mcpu=mips32r6 -mattr=+micromips,+dspr3 -filetype=obj -o %t
# RUN: llvm-objdump -dr --mattr=+micromips,+dspr3 %t | FileCheck %s --check-prefix=OBJ

.set noreorder
bposge32c next
move16 $2, $3
next:
bposge32c external
# OBJ: 4: 43 20 00 01 {{.*}}bposge32c{{.*}}0xa <next>
# OBJ: a: 43 20 ff fe {{.*}}bposge32c
# OBJ: R_MICROMIPS_PC16_S1 external
