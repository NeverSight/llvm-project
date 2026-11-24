; RUN: llc -mtriple=mips64-linux-gnuabin32 -mcpu=mips64r6 -target-abi=n32 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.mips64n32
; RUN: llvm-objdump -d --no-symbolize-operands --no-print-imm-hex --mcpu=mips64r6 %t.mips64n32 | FileCheck %s --check-prefixes=CHECK,N32
; RUN: llc -mtriple=mips64el-linux-gnuabin32 -mcpu=mips64r6 -target-abi=n32 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.mips64eln32
; RUN: llvm-objdump -d --no-symbolize-operands --no-print-imm-hex --mcpu=mips64r6 %t.mips64eln32 | FileCheck %s --check-prefixes=CHECK,N32
; RUN: llc -mtriple=mips64-linux-gnuabi64 -mcpu=mips64r6 -target-abi=n64 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.mips64n64
; RUN: llvm-objdump -d --no-symbolize-operands --no-print-imm-hex --mcpu=mips64r6 %t.mips64n64 | FileCheck %s --check-prefixes=CHECK,N64
; RUN: llc -mtriple=mips64el-linux-gnuabi64 -mcpu=mips64r6 -target-abi=n64 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.mips64eln64
; RUN: llvm-objdump -d --no-symbolize-operands --no-print-imm-hex --mcpu=mips64r6 %t.mips64eln64 | FileCheck %s --check-prefixes=CHECK,N64

; CHECK-LABEL: <signed_div>:
; CHECK: ddiv $2, $4, $5
; CHECK-NEXT: {{.*}}teq $5, $zero, 7
; CHECK-NEXT: {{.*}}jic $ra, 0
define i64 @signed_div(i64 %a, i64 %b) nounwind {
  %v = sdiv i64 %a, %b
  ret i64 %v
}

; CHECK-LABEL: <unsigned_mod>:
; CHECK: dmodu $2, $4, $5
define i64 @unsigned_mod(i64 %a, i64 %b) nounwind {
  %v = urem i64 %a, %b
  ret i64 %v
}

; CHECK-LABEL: <shift33>:
; CHECK: ori [[COUNT:\$[0-9]+]], $zero, 33
; CHECK: dsrav $2, $4, [[COUNT]]
define i64 @shift33(i64 %a) nounwind {
  %v = ashr i64 %a, 33
  ret i64 %v
}

; CHECK-LABEL: <shift63>:
; CHECK: ori [[MAXCOUNT:\$[0-9]+]], $zero, 63
; CHECK: dsrav $2, $4, [[MAXCOUNT]]
define i64 @shift63(i64 %a) nounwind {
  %v = ashr i64 %a, 63
  ret i64 %v
}

; CHECK-LABEL: <wide_load>:
; N32: sll [[PTR:\$[0-9]+]], $4, 0
; N32-NEXT: {{.*}}lwu $2, 1024([[PTR]])
; N64: lwu $2, 1024($4)
define i64 @wide_load(ptr %base) nounwind {
  %p = getelementptr i8, ptr %base, i32 1024
  %v = load i32, ptr %p, align 4
  %r = zext i32 %v to i64
  ret i64 %r
}

; CHECK-LABEL: <atomic_add>:
; CHECK: lld
; CHECK: daddu
; CHECK: scd
; CHECK: beqzc
define i64 @atomic_add(ptr %p, i64 %n) nounwind {
  %v = atomicrmw add ptr %p, i64 %n seq_cst
  ret i64 %v
}

; CHECK-LABEL: <indirect>:
; CHECK: sd $ra,
; N32: jalr $25
; N64: jialc $25, 0
; CHECK: ld $ra,
; CHECK: jic $ra, 0
define i64 @indirect(ptr %callee, i64 %a, i64 %b) nounwind {
  %v = call i64 %callee(i64 %a, i64 %b)
  %r = add i64 %v, %a
  ret i64 %r
}

; CHECK-LABEL: <extract_cross>:
; CHECK: dext $2, $4, 4, 36
define i64 @extract_cross(i64 %a) nounwind {
  %shift = lshr i64 %a, 4
  %field = and i64 %shift, 68719476735
  ret i64 %field
}

; CHECK-LABEL: <signed_to_double>:
; CHECK: dmtc1
; CHECK: cvt.d.l
define double @signed_to_double(i64 %a) nounwind {
  %result = sitofp i64 %a to double
  ret double %result
}

; CHECK-LABEL: <signed_to_float>:
; CHECK: dmtc1
; CHECK: cvt.s.l
define float @signed_to_float(i64 %a) nounwind {
  %result = sitofp i64 %a to float
  ret float %result
}

; A direct R6 branch keeps its ISA. Call a known opposite-mode definition
; through its callable address, even with a short-call attribute or an alias.
; CHECK-LABEL: <classic_helper>:
; CHECK: jr $ra
define internal i64 @classic_helper(i64 %x) noinline nounwind "nomicromips" "short-call" {
  %v = add i64 %x, 5
  ret i64 %v
}

@classic_alias = internal alias i64 (i64), ptr @classic_helper

; CHECK-LABEL: <micro_caller>:
; N32: lui $1,
; N32: jalr $25
; N64: jialc $25, 0
define i64 @micro_caller(i64 %x) nounwind "micromips" {
  %v = notail call i64 @classic_alias(i64 %x)
  ret i64 %v
}

; CHECK-LABEL: <classic_caller>:
; CHECK: {{jalr(c)?}} $25
define i64 @classic_caller(i64 %x) nounwind "nomicromips" {
  %v = notail call i64 @micro_caller(i64 %x)
  ret i64 %v
}
