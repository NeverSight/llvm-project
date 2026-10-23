; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes='default<O2>' %s | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -stop-after=finalize-isel -verify-machineinstrs < %s | FileCheck %s --check-prefix=MIR
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-none-code16 < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: ARPL intrinsic requires 32-bit code mode

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
