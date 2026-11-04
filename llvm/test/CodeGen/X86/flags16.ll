; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-code16 -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | FileCheck %s --check-prefix=IR

; Word POPF must retain AC/ID. Extending the value to a natural-width write
; clears them and is not equivalent. Each pair also owns a two-byte stack slot.
declare i16 @llvm.x86.flags.read.u16()
declare void @llvm.x86.flags.write.u16(i16)

; CHECK-LABEL: read_flags:
; CHECK: pushfw
; CHECK-NEXT: popw
; CHECK-NOT: pushfq
; CHECK-NOT: pushfl
; CHECK: ret
; IR-LABEL: define i16 @read_flags(
; IR: call i16 @llvm.x86.flags.read.u16()
define i16 @read_flags() {
  %flags = call i16 @llvm.x86.flags.read.u16()
  ret i16 %flags
}

; CHECK-LABEL: write_flags:
; CHECK: pushw
; CHECK-NEXT: popfw
; CHECK-NOT: popfq
; CHECK-NOT: popfl
; CHECK: ret
; IR-LABEL: define void @write_flags(
; IR: call void @llvm.x86.flags.write.u16(i16 %flags)
define void @write_flags(i16 %flags) {
  call void @llvm.x86.flags.write.u16(i16 %flags)
  ret void
}

; CHECK-LABEL: unused_reads:
; CHECK: pushfw
; CHECK-NEXT: popw
; CHECK: pushfw
; CHECK-NEXT: popw
; CHECK: ret
; IR-LABEL: define void @unused_reads(
; IR: call i16 @llvm.x86.flags.read.u16()
; IR: call i16 @llvm.x86.flags.read.u16()
define void @unused_reads() {
  %a = call i16 @llvm.x86.flags.read.u16()
  %b = call i16 @llvm.x86.flags.read.u16()
  ret void
}

; CHECK-LABEL: memory_order:
; CHECK: {{mov[lw]}} $17,
; CHECK: pushw
; CHECK-NEXT: popfw
; CHECK: {{mov[lw]}} $34,
; CHECK: pushfw
; CHECK-NEXT: popw
; CHECK: ret
; IR-LABEL: define i16 @memory_order(
; IR: store i32 17,
; IR: call void @llvm.x86.flags.write.u16(i16 %flags)
; IR: store i32 34,
; IR: call i16 @llvm.x86.flags.read.u16()
define i16 @memory_order(ptr %p, i16 %flags) {
  store i32 17, ptr %p
  call void @llvm.x86.flags.write.u16(i16 %flags)
  store i32 34, ptr %p
  %after = call i16 @llvm.x86.flags.read.u16()
  ret i16 %after
}
