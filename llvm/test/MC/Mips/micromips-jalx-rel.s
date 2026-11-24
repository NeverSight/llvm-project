# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+micromips -filetype=obj %s -o %t.be
# RUN: llvm-mc -triple=mipsel -mcpu=mips32r2 -mattr=+micromips -filetype=obj %s -o %t.le
# RUN: llvm-objdump -dr %t.be | FileCheck %s --check-prefixes=BE,RELOC
# RUN: llvm-objdump -dr %t.le | FileCheck %s --check-prefixes=LE,RELOC

.set noreorder
caller:
  jalx callee+4
  nop
# BE: f0 00 00 01
# LE: 00 f0 01 00
# RELOC-NEXT: {{.*}}R_MICROMIPS_26_S1{{[ \t]+}}callee
