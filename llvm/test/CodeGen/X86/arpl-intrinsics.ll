; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes='default<O2>' %s | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -stop-after=finalize-isel -verify-machineinstrs < %s | FileCheck %s --check-prefix=MIR
; RUN: llc -mtriple=i386-unknown-linux-code16 -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes='default<O2>' %s | llc -mtriple=i386-unknown-linux-code16 -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-code16 -stop-after=finalize-isel -verify-machineinstrs < %s | FileCheck %s --check-prefix=MIR
; RUN: llc -mtriple=i386-unknown-linux-code16 -O0 -verify-machineinstrs -filetype=obj %s -o %t.o
; RUN: llvm-objdump -d --mattr=+16bit-mode,-32bit-mode %t.o | FileCheck %s --check-prefix=CODE16
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: sed 's/i32 16, i32 100/i32 64, i32 100/' %s | not --crash llc -mtriple=i386-unknown-linux-gnu 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: sed 's/i32 16, i32 100/i32 16, i32 256/' %s | not --crash llc -mtriple=i386-unknown-linux-gnu 2>&1 | FileCheck %s --check-prefix=PREFIX
; WIDTH: native memory address width is invalid for this code mode
; PREFIX: invalid native memory segment prefix or stack-reference control
; MODE: ARPL intrinsic requires 16- or 32-bit code mode
; CODE16-LABEL: <adjust>:
; CODE16: 63 {{[0-9a-f]+}} {{.*}}arpl
; CODE16-LABEL: <adjust_memory>:
; CODE16: 67 63 {{[0-9a-f]+}} {{.*}}arpl

declare { i16, i8 } @llvm.x86.arpl.reg(i16, i16)
declare i8 @llvm.x86.arpl.mem(ptr, i16)

; CHECK-LABEL: adjust:
; CHECK: arpl
; CHECK: sete
; CHECK: ret
; MIR-LABEL: name: adjust
; MIR: ARPL16rr {{.*}}, {{.*}}, implicit-def $eflags
define i32 @adjust(i16 %destination, i16 %source) {
  %r = call { i16, i8 } @llvm.x86.arpl.reg(i16 %destination, i16 %source)
  %v = extractvalue { i16, i8 } %r, 0
  %f = extractvalue { i16, i8 } %r, 1
  %value = zext i16 %v to i32
  %flag = zext i8 %f to i32
  %shift = shl i32 %flag, 16
  %result = or i32 %value, %shift
  ret i32 %result
}

; CHECK-LABEL: adjust_memory:
; CHECK: arpl {{.*}}, (
; CHECK: sete
; CHECK: ret
; MIR-LABEL: name: adjust_memory
; MIR: NATIVE_ADDRESS32
; MIR: ARPL16mr {{.*}}, implicit-def $eflags
define i8 @adjust_memory(ptr %destination, i16 %source) {
  %zf = call i8 @llvm.x86.arpl.mem(ptr %destination, i16 %source)
  ret i8 %zf
}

; CHECK-LABEL: dead:
; CHECK-COUNT-2: arpl
; CHECK: ret
define void @dead(i16 %destination, i16 %source, ptr %memory) {
  %r = call { i16, i8 } @llvm.x86.arpl.reg(i16 %destination, i16 %source)
  %zf = call i8 @llvm.x86.arpl.mem(ptr %memory, i16 %source)
  ret void
}

declare i8 @llvm.x86.arpl.mem.address32(i32, i16, i32 immarg, i32 immarg)

; CHECK-LABEL: explicit16:
; CHECK: arpl {{.*}}, %fs:(%{{si|di}})
; CHECK: sete
; MIR-LABEL: name: explicit16
; MIR: NATIVE_ADDRESS16
; MIR: ARPL16mr_ADDR16
; CODE16-LABEL: <explicit16>:
; CODE16: 64 63 {{.*}}arpl
define i8 @explicit16(i32 %offset, i16 %source) {
  %f = call i8 @llvm.x86.arpl.mem.address32(i32 %offset, i16 %source, i32 16, i32 100)
  ret i8 %f
}

; CHECK-LABEL: explicit32:
; CHECK: arpl {{.*}}, %ss:(%{{e[a-z]+}})
; CHECK: sete
; MIR-LABEL: name: explicit32
; MIR: NATIVE_ADDRESS32
; MIR: ARPL16mr
; CODE16-LABEL: <explicit32>:
; CODE16: {{(67 36|36 67)}} 63 {{.*}}arpl
define i8 @explicit32(i32 %offset, i16 %source) {
  %f = call i8 @llvm.x86.arpl.mem.address32(i32 %offset, i16 %source, i32 32, i32 54)
  ret i8 %f
}

; A fixed BP producer must be copied to a DS carrier before dereferencing.
; Without NATIVE_ADDRESS32, coalescing can silently choose an SS operand.
; CHECK-LABEL: bp_pointer:
; CHECK: movl %ebp, [[BASE:%e[acds][xip]]]
; CHECK: arpl {{.*}}, ([[BASE]])
; CHECK: sete
; MIR-LABEL: name: bp_pointer
; MIR: NATIVE_ADDRESS32
; MIR: ARPL16mr
define i8 @bp_pointer(i32 %pointer, i16 %source) {
  %fixed = call ptr asm sideeffect "", "={bp},0"(i32 %pointer)
  %zf = call i8 @llvm.x86.arpl.mem(ptr %fixed, i16 %source)
  ret i8 %zf
}
