# RUN: llvm-mc -triple=x86_64 -show-encoding %s | FileCheck %s
# RUN: llvm-mc -triple=x86_64 -filetype=obj %s -o %t
# RUN: llvm-objdump -d %t | FileCheck %s --check-prefix=DIS
# RUN: llvm-mc -triple=i386 -show-encoding %s | FileCheck %s --check-prefix=X32

.code64
# CHECK: bndmk (%rax,%rdx,4), %bnd3 # encoding: [0xf3,0x0f,0x1b,0x1c,0x90]
# DIS: bndmk
bndmk (%rax,%rdx,4), %bnd3
# CHECK: bndcl %r10, %bnd2 # encoding: [0xf3,0x41,0x0f,0x1a,0xd2]
# DIS: bndcl
bndcl %r10, %bnd2
# CHECK: bndcu %r8, %bnd0 # encoding: [0xf2,0x41,0x0f,0x1a,0xc0]
# DIS: bndcu
bndcu %r8, %bnd0
# CHECK: bndcn 8(%rbx), %bnd1 # encoding: [0xf2,0x0f,0x1b,0x4b,0x08]
# DIS: bndcn
bndcn 8(%rbx), %bnd1
# CHECK: bndmov %bnd0, %bnd3 # encoding: [0x66,0x0f,0x1a,0xd8]
# DIS: bndmov
bndmov %bnd0, %bnd3
# CHECK: bndmov (%rbx), %bnd2 # encoding: [0x66,0x0f,0x1a,0x13]
# DIS: bndmov
bndmov (%rbx), %bnd2
# CHECK: bndmov %bnd3, (%rbx) # encoding: [0x66,0x0f,0x1b,0x1b]
# DIS: bndmov
bndmov %bnd3, (%rbx)
# CHECK: bndldx (%rbx,%rsi), %bnd0 # encoding: [0x0f,0x1a,0x04,0x33]
# DIS: bndldx
bndldx (%rbx,%rsi), %bnd0
# CHECK: bndstx %bnd1, (%rbx,%rsi) # encoding: [0x0f,0x1b,0x0c,0x33]
# DIS: bndstx
bndstx %bnd1, (%rbx,%rsi)

.code32
# X32: bndmk (%ebx,%esi), %bnd2 # encoding: [0xf3,0x0f,0x1b,0x14,0x33]
bndmk (%ebx,%esi), %bnd2
# X32: bndcl %ecx, %bnd1 # encoding: [0xf3,0x0f,0x1a,0xc9]
bndcl %ecx, %bnd1
# X32: bndcu %edx, %bnd0 # encoding: [0xf2,0x0f,0x1a,0xc2]
bndcu %edx, %bnd0
# X32: bndcn (%ebx), %bnd3 # encoding: [0xf2,0x0f,0x1b,0x1b]
bndcn (%ebx), %bnd3
# X32: bndmov (%ebx), %bnd0 # encoding: [0x66,0x0f,0x1a,0x03]
bndmov (%ebx), %bnd0
# X32: bndmov %bnd0, (%ebx) # encoding: [0x66,0x0f,0x1b,0x03]
bndmov %bnd0, (%ebx)
# X32: bndldx (%ebx,%esi), %bnd1 # encoding: [0x0f,0x1a,0x0c,0x33]
bndldx (%ebx,%esi), %bnd1
# X32: bndstx %bnd2, (%ebx,%esi) # encoding: [0x0f,0x1b,0x14,0x33]
bndstx %bnd2, (%ebx,%esi)
