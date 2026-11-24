; RUN: llc -mtriple=mips64-unknown-linux-gnuabin32 -target-abi=n32 -mcpu=mips64r2 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.n32be
; RUN: llvm-objdump -d --no-show-raw-insn --no-print-imm-hex --no-symbolize-operands --triple=mips64-unknown-linux-gnuabin32 --mcpu=mips64r2 --mattr=+micromips %t.n32be | FileCheck %s
; RUN: llc -mtriple=mips64el-unknown-linux-gnuabin32 -target-abi=n32 -mcpu=mips64r2 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.n32el
; RUN: llvm-objdump -d --no-show-raw-insn --no-print-imm-hex --no-symbolize-operands --triple=mips64el-unknown-linux-gnuabin32 --mcpu=mips64r2 --mattr=+micromips %t.n32el | FileCheck %s
; RUN: llc -mtriple=mips64-unknown-linux-gnuabi64 -target-abi=n64 -mcpu=mips64r2 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.n64be
; RUN: llvm-objdump -d --no-show-raw-insn --no-print-imm-hex --no-symbolize-operands --triple=mips64-unknown-linux-gnuabi64 --mcpu=mips64r2 --mattr=+micromips %t.n64be | FileCheck %s
; RUN: llc -mtriple=mips64el-unknown-linux-gnuabi64 -target-abi=n64 -mcpu=mips64r2 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.n64el
; RUN: llvm-objdump -d --no-show-raw-insn --no-print-imm-hex --no-symbolize-operands --triple=mips64el-unknown-linux-gnuabi64 --mcpu=mips64r2 --mattr=+micromips %t.n64el | FileCheck %s

; CHECK-LABEL: <extendword>:
; CHECK: sll $2, $4, 0
define i64 @extendword(i64 %a) nounwind {
  %w = trunc i64 %a to i32
  %r = sext i32 %w to i64
  ret i64 %r
}

define i64 @add_pair(i64 %a, i64 %b) {
; CHECK-LABEL: <add_pair>:
; CHECK:       jr $ra
; CHECK-NEXT:  {{.*}}daddu $2, $4, $5
  %r = add i64 %a, %b
  ret i64 %r
}

define i64 @shift_mix(i64 %a, i64 %b) {
; CHECK-LABEL: <shift_mix>:
; CHECK-DAG:   dsll32 {{.*}}, $4, 5
; CHECK-DAG:   dsrl32 {{.*}}, $5, 0
; CHECK:       or $2,
  %l = shl i64 %a, 37
  %r = lshr i64 %b, 32
  %v = xor i64 %l, %r
  ret i64 %v
}

define i64 @variable(i64 %a, i64 %b) {
; CHECK-LABEL: <variable>:
; CHECK:       dsrav $2, $4, {{.*}}
  %count = and i64 %b, 63
  %r = ashr i64 %a, %count
  ret i64 %r
}

define i64 @increment(ptr %in, ptr %out, i64 %inc) {
; CHECK-LABEL: <increment>:
; CHECK:       ld {{.*}}, -16({{.*}})
; CHECK:       daddu
; CHECK:       sd $2, 8({{.*}})
  %p = getelementptr i8, ptr %in, i32 -16
  %x = load i64, ptr %p, align 8
  %r = add i64 %x, %inc
  %q = getelementptr i8, ptr %out, i32 8
  store i64 %r, ptr %q, align 8
  ret i64 %r
}

; LWU has a signed 12-bit offset in microMIPS, so 4096 must be
; materialized in the base address.
define i64 @word_far(ptr %base) {
; CHECK-LABEL: <word_far>:
; CHECK:       {{d?addiu}} {{.*}}, {{.*}}, 4096
; CHECK:       lwu $2, 0({{.*}})
  %p = getelementptr i8, ptr %base, i32 4096
  %x = load i32, ptr %p, align 4
  %r = zext i32 %x to i64
  ret i64 %r
}

define i64 @product(i64 %a, i64 %b) {
; CHECK-LABEL: <product>:
; CHECK:       dmult
; CHECK:       mflo $2
  %r = mul i64 %a, %b
  ret i64 %r
}

define i64 @remainder(i64 %a, i64 %b) {
; CHECK-LABEL: <remainder>:
; CHECK:       ddivu
; CHECK:       mfhi $2
  %r = urem i64 %a, %b
  ret i64 %r
}

declare i64 @llvm.ctlz.i64(i64, i1)
declare i64 @llvm.bswap.i64(i64)

define i64 @leading(i64 %a) {
; CHECK-LABEL: <leading>:
; CHECK:       dclz $2, $4
  %r = call i64 @llvm.ctlz.i64(i64 %a, i1 false)
  ret i64 %r
}

define i64 @byte_swap(i64 %a) {
; CHECK-LABEL: <byte_swap>:
; CHECK:       dsbh
; CHECK:       dshd $2,
  %r = call i64 @llvm.bswap.i64(i64 %a)
  ret i64 %r
}

define i64 @minimum(i64 %a, i64 %b) {
; CHECK-LABEL: <minimum>:
; CHECK:       sltu
; CHECK:       {{mov[zn]}}
  %lt = icmp ult i64 %a, %b
  %r = select i1 %lt, i64 %a, i64 %b
  ret i64 %r
}

define i64 @unaligned_load(ptr %p) {
; CHECK-LABEL: <unaligned_load>:
; CHECK-DAG:   ldl
; CHECK-DAG:   ldr
  %r = load i64, ptr %p, align 1
  ret i64 %r
}

define i64 @atomic_add(ptr %p, i64 %v) {
; CHECK-LABEL: <atomic_add>:
; CHECK:       lld
; CHECK:       daddu
; CHECK:       scd
  %r = atomicrmw add ptr %p, i64 %v seq_cst
  ret i64 %r
}

define i64 @call_indirect(ptr %f, i64 %v) {
; CHECK-LABEL: <call_indirect>:
; CHECK:       jalr
; CHECK:       daddu
  %r = call i64 %f(i64 %v)
  %sum = add i64 %r, %v
  ret i64 %sum
}

define i64 @fp_payload(double %a) {
; CHECK-LABEL: <fp_payload>:
; CHECK:       dmfc1 $2, $f12
  %bits = bitcast double %a to i64
  ret i64 %bits
}

define double @from_bits(i64 %a) {
; CHECK-LABEL: <from_bits>:
; CHECK:       dmtc1 $4, $f0
  %r = bitcast i64 %a to double
  ret double %r
}

define i64 @trunc_to_integer(double %a) {
; CHECK-LABEL: <trunc_to_integer>:
; CHECK:       trunc.l.d
; CHECK:       dmfc1
  %r = fptosi double %a to i64
  ret i64 %r
}

define double @convert_signed(i64 %a) {
; CHECK-LABEL: <convert_signed>:
; CHECK:       dmtc1
; CHECK:       cvt.d.l
  %r = sitofp i64 %a to double
  ret double %r
}

define double @choose_double(double %a, double %b) {
; CHECK-LABEL: <choose_double>:
; CHECK:       c.olt.d
; CHECK:       mov{{[tf]}}.d
  %c = fcmp olt double %a, %b
  %r = select i1 %c, double %a, double %b
  ret double %r
}
