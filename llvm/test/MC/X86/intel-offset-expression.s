# RUN: llvm-mc -triple=i386-linux-gnu -filetype=obj %s -o %t.o
# RUN: llvm-objdump -dr %t.o | FileCheck %s

.intel_syntax noprefix
.Lbase:
  nop
.Lhere:
  add eax, offset _GLOBAL_OFFSET_TABLE_+(.Lhere-.Lbase)
# CHECK: addl
# CHECK: R_386_GOTPC _GLOBAL_OFFSET_TABLE_
  mov eax, dword ptr [offset global+ebx]
# CHECK: movl (%ebx), %eax
# CHECK: R_386_32 global
  mov eax, offset global+(.Lhere-.Lbase)
# CHECK: movl $0x1, %eax
# CHECK: R_386_32 global
