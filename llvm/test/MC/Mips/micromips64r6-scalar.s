# RUN: split-file %s %t
# RUN: llvm-mc -triple=mips64-linux-gnuabin32 -mcpu=mips64r6 -target-abi=n32 -mattr=+micromips -filetype=obj %t/scalar.s -o %t.n32BE
# RUN: llvm-objdump -d --no-print-imm-hex --no-symbolize-operands --mcpu=mips64r6 --mattr=+micromips %t.n32BE | FileCheck %s --check-prefixes=BE,REG
# RUN: llvm-mc -triple=mips64el-linux-gnuabin32 -mcpu=mips64r6 -target-abi=n32 -mattr=+micromips -filetype=obj %t/scalar.s -o %t.n32LE
# RUN: llvm-objdump -d --no-print-imm-hex --no-symbolize-operands --mcpu=mips64r6 --mattr=+micromips %t.n32LE | FileCheck %s --check-prefixes=LE,REG
# RUN: llvm-mc -triple=mips64-linux-gnuabi64 -mcpu=mips64r6 -target-abi=n64 -mattr=+micromips -filetype=obj %t/scalar.s -o %t.n64BE
# RUN: llvm-objdump -d --no-print-imm-hex --no-symbolize-operands --mcpu=mips64r6 --mattr=+micromips %t.n64BE | FileCheck %s --check-prefixes=BE,REG
# RUN: llvm-mc -triple=mips64el-linux-gnuabi64 -mcpu=mips64r6 -target-abi=n64 -mattr=+micromips -filetype=obj %t/scalar.s -o %t.n64LE
# RUN: llvm-objdump -d --no-print-imm-hex --no-symbolize-operands --mcpu=mips64r6 --mattr=+micromips %t.n64LE | FileCheck %s --check-prefixes=LE,REG
# RUN: llvm-mc -triple=mips64 -mcpu=mips64r2 -filetype=obj %t/directives.s -o %t.directives
# RUN: llvm-objdump -d --mcpu=mips64r6 --mattr=+micromips %t.directives | FileCheck %s --check-prefix=MODE
# RUN: not llvm-mc -triple=mips64 -mcpu=mips64r6 -mattr=+micromips -filetype=obj %t/removed.s -o %t.bad 2>&1 | FileCheck %s --check-prefix=REMOVED
# RUN: not llvm-mc -triple=mips -mcpu=mips32r6 -mattr=+micromips -filetype=obj %t/wide.s -o %t.bad32 2>&1 | FileCheck %s --check-prefix=NARROW
# RUN: llvm-mc -triple=mips64 -mcpu=mips64r6 -filetype=obj %t/mixed.s -o %t.mixed
# RUN: llvm-objdump -d --symbolize-operands --no-print-imm-hex %t.mixed | FileCheck %s --check-prefix=MIXED
# RUN: llvm-objdump -d --disassemble-symbols=within_classic --no-print-imm-hex %t.mixed | FileCheck %s --check-prefix=WITHIN
# RUN: not llvm-mc -triple=mips64 -mcpu=mips64r6 -filetype=obj %t/cross.s -o %t.badbranch 2>&1 | FileCheck %s --check-prefix=CROSS

#--- scalar.s
.set noreorder
.text
.globl wide
.ent wide
wide:
# BE: 58 a4 10 18
# LE: a4 58 18 10
# REG-SAME: dmul $2, $4, $5
  dmul $2, $4, $5
# BE: 58 a4 10 58
# LE: a4 58 58 10
# REG-SAME: dmuh $2, $4, $5
  dmuh $2, $4, $5
# BE: 58 a4 10 98
# LE: a4 58 98 10
# REG-SAME: dmulu $2, $4, $5
  dmulu $2, $4, $5
# BE: 58 a4 10 d8
# LE: a4 58 d8 10
# REG-SAME: dmuhu $2, $4, $5
  dmuhu $2, $4, $5
# BE: 58 a4 11 18
# LE: a4 58 18 11
# REG-SAME: ddiv $2, $4, $5
  ddiv $2, $4, $5
# BE: 58 a4 11 58
# LE: a4 58 58 11
# REG-SAME: dmod $2, $4, $5
  dmod $2, $4, $5
# BE: 58 a4 11 98
# LE: a4 58 98 11
# REG-SAME: ddivu $2, $4, $5
  ddivu $2, $4, $5
# BE: 58 a4 11 d8
# LE: a4 58 d8 11
# REG-SAME: dmodu $2, $4, $5
  dmodu $2, $4, $5
# BE: 58 a4 11 50
# LE: a4 58 50 11
# REG-SAME: daddu $2, $4, $5
  daddu $2, $4, $5
# BE: 58 a4 11 d0
# LE: a4 58 d0 11
# REG-SAME: dsubu $2, $4, $5
  dsubu $2, $4, $5
# BE: 58 44 5b 3c
# LE: 44 58 3c 5b
# REG-SAME: dclz $2, $4
  dclz $2, $4
# BE: 58 44 4b 3c
# LE: 44 58 3c 4b
# REG-SAME: dclo $2, $4
  dclo $2, $4
# BE: 58 44 7b 3c
# LE: 44 58 3c 7b
# REG-SAME: dsbh $2, $4
  dsbh $2, $4
# BE: 58 44 fb 3c
# LE: 44 58 3c fb
# REG-SAME: dshd $2, $4
  dshd $2, $4
# BE: dc 44 00 08
# LE: 44 dc 08 00
# REG-SAME: ld $2, 8($4)
  ld $2, 8($4)
# BE: d8 44 00 08
# LE: 44 d8 08 00
# REG-SAME: sd $2, 8($4)
  sd $2, 8($4)
# BE: 60 44 e4 00
# LE: 44 60 00 e4
# REG-SAME: lwu $2, 1024($4)
  lwu $2, 1024($4)
# BE: 60 44 71 08
# LE: 44 60 08 71
# REG-SAME: lld $2, -248($4)
  lld $2, -248($4)
# BE: 60 64 f0 f8
# LE: 64 60 f8 f0
# REG-SAME: scd $3, 248($4)
  scd $3, 248($4)
# BE: a0 19 00 00
# LE: 19 a0 00 00
# REG-SAME: jialc $25, 0
  jialc $25, 0
# BE: 80 1f 00 00
# LE: 1f 80 00 00
# REG-SAME: jic $ra, 0
  jic $ra, 0
# BE: 47 e3
# LE: e3 47
# REG-SAME: jrc16 $ra
  jrc16 $ra
.end wide

#--- directives.s
.set noreorder
.set micromips
.set mips64r6
  dmul $2, $4, $5
.set arch=mips64r6
  ddivu $2, $4, $5
# MODE: dmul $2, $4, $5
# MODE-NEXT: {{.*}}ddivu $2, $4, $5

#--- removed.s
  dmult $4, $5
# REMOVED: error:
  dsra32 $2, $4, 1
# REMOVED: error:
  dsra $2, $4, 33
# REMOVED: error:
  dlsa $2, $4, $5, 1
# REMOVED: error:

#--- wide.s
  dmuh $2, $4, $5
# NARROW: error:

#--- mixed.s
.set noreorder
.set nomicromips
.ent classic
classic:
  daddiu $2, $4, 5
within_classic:
  daddiu $2, $2, 1
.end classic
.set micromips
.ent micro
micro:
  daddiu $2, $4, 7
.end micro
# MIXED-LABEL: <classic>:
# MIXED: daddiu $2, $4, 5
# MIXED-LABEL: <within_classic>:
# MIXED: daddiu $2, $2, 1
# MIXED-LABEL: <micro>:
# MIXED: daddiu $2, $4, 7
# WITHIN-LABEL: <within_classic>:
# WITHIN: daddiu $2, $2, 1

#--- cross.s
.set noreorder
.set nomicromips
.ent classic
classic:
  balc micro
.end classic
.set micromips
.ent micro
micro:
  balc classic
.end micro
# CROSS-COUNT-2: error: MIPS branch cannot change ISA mode
