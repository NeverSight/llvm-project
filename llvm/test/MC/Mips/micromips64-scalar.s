# RUN: llvm-mc -triple=mips64-unknown-linux-gnuabin32 -mcpu=mips64r2 -target-abi=n32 -mattr=+micromips -filetype=obj %s -o %t.n32BE
# RUN: llvm-objdump -d --no-print-imm-hex --no-symbolize-operands --triple=mips64-unknown-linux-gnuabin32 --mcpu=mips64r2 --mattr=+micromips %t.n32BE | FileCheck %s --check-prefixes=BE,REG
# RUN: llvm-mc -triple=mips64el-unknown-linux-gnuabin32 -mcpu=mips64r2 -target-abi=n32 -mattr=+micromips -filetype=obj %s -o %t.n32LE
# RUN: llvm-objdump -d --no-print-imm-hex --no-symbolize-operands --triple=mips64el-unknown-linux-gnuabin32 --mcpu=mips64r2 --mattr=+micromips %t.n32LE | FileCheck %s --check-prefixes=LE,REG
# RUN: llvm-mc -triple=mips64-unknown-linux-gnuabi64 -mcpu=mips64r2 -target-abi=n64 -mattr=+micromips -filetype=obj %s -o %t.n64BE
# RUN: llvm-objdump -d --no-print-imm-hex --no-symbolize-operands --triple=mips64-unknown-linux-gnuabi64 --mcpu=mips64r2 --mattr=+micromips %t.n64BE | FileCheck %s --check-prefixes=BE,REG
# RUN: llvm-mc -triple=mips64el-unknown-linux-gnuabi64 -mcpu=mips64r2 -target-abi=n64 -mattr=+micromips -filetype=obj %s -o %t.n64LE
# RUN: llvm-objdump -d --no-print-imm-hex --no-symbolize-operands --triple=mips64el-unknown-linux-gnuabi64 --mcpu=mips64r2 --mattr=+micromips %t.n64LE | FileCheck %s --check-prefixes=LE,REG
# RUN: echo ".byte 0xa4,0x58,0x50,0x11,0x00,0x0c" | llvm-mc -triple=mipsel -mcpu=mips32r2 -mattr=+micromips -filetype=obj -o %t.narrow
# RUN: llvm-objdump -d --mattr=+micromips %t.narrow | FileCheck %s --check-prefix=NARROW
# RUN: echo 'daddi $2,$3,512' | not llvm-mc -triple=mips64el -mcpu=mips64r2 -mattr=+micromips -filetype=obj -o %t.invalid 2>&1 | FileCheck %s --check-prefix=RANGE

# A 32-bit core cannot decode POOL32S doubleword arithmetic. The next
# instruction still starts on the following four-byte boundary.
# NARROW: 0: a4 58 50 11 {{.*}}<unknown>
# NARROW-NEXT: 4: 00 0c {{.*}}nop
# RANGE: error: no microMIPS64 encoding for DADDi

.set noreorder
.set micromips
.text
.globl wide
.ent wide
wide:
# BE: 0: 58 a4 11 50
# LE: 0: a4 58 50 11
# REG-SAME: daddu $2, $4, $5
  daddu $2,$4,$5
# BE: 4: 58 85 19 d0
# LE: 4: 85 58 d0 19
# REG-SAME: dsubu $3, $5, $4
  dsubu $3,$5,$4
# BE: 8: 59 49 89 10
# LE: 8: 49 59 10 89
# REG-SAME: dadd $17, $9, $10
  dadd $17,$9,$10
# BE: c: 59 51 49 90
# LE: c: 51 59 90 49
# REG-SAME: dsub $9, $17, $10
  dsub $9,$17,$10
# BE: 10: 5c 44 80 00
# LE: 10: 44 5c 00 80
# REG-SAME: daddiu $2, $4, -32768
  daddiu $2,$4,-32768
# BE: 14: 59 c6 80 1c
# LE: 14: c6 59 1c 80
# REG-SAME: daddi $14, $6, -512
  daddi $14,$6,-512
# BE: 18: 59 e7 7f dc
# LE: 18: e7 59 dc 7f
# REG-SAME: daddi $15, $7, 511
  daddi $15,$7,511
# BE: 1c: 58 64 f8 00
# LE: 1c: 64 58 00 f8
# REG-SAME: dsll $3, $4, 31
  dsll $3,$4,31
# BE: 20: 58 64 00 08
# LE: 20: 64 58 08 00
# REG-SAME: dsll32 $3, $4, 0
  dsll $3,$4,32
# BE: 24: 59 2a f8 48
# LE: 24: 2a 59 48 f8
# REG-SAME: dsrl32 $9, $10, 31
  dsrl $9,$10,63
# BE: 28: 59 8d 00 88
# LE: 28: 8d 59 88 00
# REG-SAME: dsra32 $12, $13, 0
  dsra32 $12,$13,0
# BE: 2c: 59 cf e8 c0
# LE: 2c: cf 59 c0 e8
# REG-SAME: drotr $14, $15, 29
  drotr $14,$15,29
# BE: 30: 59 cf 18 c8
# LE: 30: cf 59 c8 18
# REG-SAME: drotr32 $14, $15, 3
  drotr32 $14,$15,3
# BE: 34: 59 2a 40 10
# LE: 34: 2a 59 10 40
# REG-SAME: dsllv $8, $9, $10
  dsllv $8,$9,$10
# BE: 38: 59 09 50 50
# LE: 38: 09 59 50 50
# REG-SAME: dsrlv $10, $8, $9
  dsrlv $10,$8,$9
# BE: 3c: 59 28 50 90
# LE: 3c: 28 59 90 50
# REG-SAME: dsrav $10, $9, $8
  dsrav $10,$9,$8
# BE: 40: 59 49 40 d0
# LE: 40: 49 59 d0 40
# REG-SAME: drotrv $8, $10, $9
  drotrv $8,$10,$9
# BE: 44: de 11 80 00
# LE: 44: 11 de 00 80
# REG-SAME: ld $16, -32768($17)
  ld $16,-32768($17)
# BE: 48: d9 22 7f ff
# LE: 48: 22 d9 ff 7f
# REG-SAME: sd $9, 32767($2)
  sd $9,32767($2)
# BE: 4c: 60 44 e8 00
# LE: 4c: 44 60 00 e8
# REG-SAME: lwu $2, -2048($4)
  lwu $2,-2048($4)
# BE: 50: 0c 00
# LE: 50: 00 0c
# REG-SAME: nop
  .short 0x0c00
.end wide

.p2align 2
# The halfword between the two functions is independently executable.
# BE: 52: 0c 00
# LE: 52: 00 0c
# REG-SAME: nop
.globl extended
.ent extended
extended:
# REG-LABEL: <extended>:
# BE: 58 a4 8b 3c
# LE: a4 58 3c 8b
# REG-SAME: dmult $4, $5
  dmult $4,$5
# BE: 58 a4 9b 3c
# LE: a4 58 3c 9b
# REG-SAME: dmultu $4, $5
  dmultu $4,$5
# BE: 58 a4 ab 3c
# LE: a4 58 3c ab
# REG-SAME: ddiv $zero, $4, $5
  ddiv $0,$4,$5
# BE: 58 a4 bb 3c
# LE: a4 58 3c bb
# REG-SAME: ddivu $zero, $4, $5
  ddivu $0,$4,$5
# BE: 59 09 5b 3c
# LE: 09 59 3c 5b
# REG-SAME: dclz $8, $9
  dclz $8,$9
# BE: 59 09 4b 3c
# LE: 09 59 3c 4b
# REG-SAME: dclo $8, $9
  dclo $8,$9
# BE: 59 4b 7b 3c
# LE: 4b 59 3c 7b
# REG-SAME: dsbh $10, $11
  dsbh $10,$11
# BE: 59 4b fb 3c
# LE: 4b 59 3c fb
# REG-SAME: dshd $10, $11
  dshd $10,$11
# BE: 59 09 f8 2c
# LE: 09 59 2c f8
# REG-SAME: dext{{[mu]?}} $8, $9, 0, 32
  dext $8,$9,0,32
# BE: 59 09 19 24
# LE: 09 59 24 19
# REG-SAME: dext{{[mu]?}} $8, $9, 4, 36
  dextm $8,$9,4,36
# BE: 59 09 58 14
# LE: 09 59 14 58
# REG-SAME: dext{{[mu]?}} $8, $9, 32, 12
  dextu $8,$9,32,12
# BE: 59 09 f8 0c
# LE: 09 59 0c f8
# REG-SAME: dins{{[mu]?}} $8, $9, 0, 32
  dins $8,$9,0,32
# BE: 59 09 39 04
# LE: 09 59 04 39
# REG-SAME: dins{{[mu]?}} $8, $9, 4, 36
  dinsm $8,$9,4,36
# BE: 59 09 58 34
# LE: 09 59 34 58
# REG-SAME: dins{{[mu]?}} $8, $9, 32, 12
  dinsu $8,$9,32,12
# BE: 60 64 4f f8
# LE: 64 60 f8 4f
# REG-SAME: ldl $3, -8($4)
  ldl $3,-8($4)
# BE: 60 64 50 07
# LE: 64 60 07 50
# REG-SAME: ldr $3, 7($4)
  ldr $3,7($4)
# BE: 60 64 cf f8
# LE: 64 60 f8 cf
# REG-SAME: sdl $3, -8($4)
  sdl $3,-8($4)
# BE: 60 64 d0 07
# LE: 64 60 07 d0
# REG-SAME: sdr $3, 7($4)
  sdr $3,7($4)
# BE: 60 64 7f f8
# LE: 64 60 f8 7f
# REG-SAME: lld $3, -8($4)
  lld $3,-8($4)
# BE: 60 64 f0 08
# LE: 64 60 08 f0
# REG-SAME: scd $3, 8($4)
  scd $3,8($4)
.end extended

.globl fpwide
.ent fpwide
fpwide:
# REG-LABEL: <fpwide>:
# BE: 54 87 24 3b
# LE: 87 54 3b 24
# REG-SAME: dmfc1 $4, $f7
  dmfc1 $4, $f7
# BE: 54 a6 2c 3b
# LE: a6 54 3b 2c
# REG-SAME: dmtc1 $5, $f6
  dmtc1 $5, $f6
# BE: 54 44 53 7b
# LE: 44 54 7b 53
# REG-SAME: cvt.d.l $f2, $f4
  cvt.d.l $f2, $f4
# BE: 54 44 5b 7b
# LE: 44 54 7b 5b
# REG-SAME: cvt.s.l $f2, $f4
  cvt.s.l $f2, $f4
# BE: 54 44 63 3b
# LE: 44 54 3b 63
# REG-SAME: trunc.l.d $f2, $f4
  trunc.l.d $f2, $f4
# BE: 54 44 23 3b
# LE: 44 54 3b 23
# REG-SAME: trunc.l.s $f2, $f4
  trunc.l.s $f2, $f4
# BE: 54 44 02 60
# LE: 44 54 60 02
# REG-SAME: movt.d $f2, $f4, $fcc0
  movt.d $f2, $f4, $fcc0
# BE: 54 44 62 20
# LE: 44 54 20 62
# REG-SAME: movf.d $f2, $f4, $fcc3
  movf.d $f2, $f4, $fcc3
# BE: 55 ac 05 3c
# LE: ac 55 3c 05
# REG-SAME: c.olt.d {{(\$fcc0, )?}}$f12, $f13
  c.olt.d $fcc0, $f12, $f13
# BE: 54 44 20 7b
# LE: 44 54 7b 20
# REG-SAME: mov.d $f2, $f4
  mov.d $f2, $f4
.end fpwide
