# RUN: llvm-mc -triple=mips -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %s -o %t
# RUN: llvm-readobj --symbols --arch-specific %t | FileCheck %s
# RUN: llvm-mc -triple=mipsel -mcpu=mips32r2 -mattr=+mips16 -filetype=obj %s -o %t
# RUN: llvm-readobj --symbols --arch-specific %t | FileCheck %s

  .text
initial:
  .insn
  .2byte 0x6500
literal:
  .word 0
  .set push
  .set nomips16
classic:
  nop
  .set micromips
micro:
  nop
  .set pop
restored:
  .insn
  .2byte 0x6500
  .set nomips16
again:
  nop
  .globl alias
alias = restored

# CHECK: Name: initial (
# CHECK: Other [ (0xF0)
# CHECK: Name: literal (
# CHECK: Other: 0
# CHECK: Name: classic (
# CHECK: Other: 0
# CHECK: Name: micro (
# CHECK: Other [ (0x80)
# CHECK: Name: restored (
# CHECK: Other [ (0xF0)
# CHECK: Name: again (
# CHECK: Other: 0
# CHECK: Name: alias (
# CHECK: Other [ (0xF0)
# CHECK: ASEs [ (0xC00)
