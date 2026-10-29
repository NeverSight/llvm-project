# RUN: llvm-mc -triple=x86_64 -show-encoding %s | FileCheck %s
# RUN: llvm-mc -triple=i386 -show-encoding %s | FileCheck %s
# RUN: llvm-mc -triple=x86_64 -filetype=obj %s | llvm-objdump -d - | FileCheck %s --check-prefix=DIS

# CHECK: fnstenvs (%eax) # encoding: [0x{{(67,0x)?}}66,0xd9,0x30]
# CHECK: fldenvs (%eax) # encoding: [0x{{(67,0x)?}}66,0xd9,0x20]
# CHECK: fnsaves (%eax) # encoding: [0x{{(67,0x)?}}66,0xdd,0x30]
# CHECK: frstors (%eax) # encoding: [0x{{(67,0x)?}}66,0xdd,0x20]
# DIS: fnstenvs
# DIS: fldenvs
# DIS: fnsaves
# DIS: frstors
fnstenvs (%eax)
fldenvs (%eax)
fnsaves (%eax)
frstors (%eax)
