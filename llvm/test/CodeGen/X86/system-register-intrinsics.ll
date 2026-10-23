; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: opt -passes='default<O2>' -S %t/64.ll | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/64.ll -o %t/64.obj
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs -filetype=obj %t/64.ll -o %t/64.macho
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -stop-after=finalize-isel %t/64.ll -o - | FileCheck %s --check-prefix=M64
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: opt -passes='default<O2>' -S %t/32.ll | llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/32.ll -o %t/32.obj
; RUN: llc -mtriple=i386-apple-darwin -verify-machineinstrs -filetype=obj %t/32.ll -o %t/32.macho
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs -stop-after=finalize-isel %t/32.ll -o - | FileCheck %s --check-prefix=M32
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/64.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: LLVM ERROR: CR/DR intrinsic does not match the target code mode
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/invalid-cr.ll 2>&1 | FileCheck %s --check-prefix=INVALID_CR
; INVALID_CR: LLVM ERROR: invalid control register index
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/invalid-dr.ll 2>&1 | FileCheck %s --check-prefix=INVALID_DR
; INVALID_DR: LLVM ERROR: invalid debug register index
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/cr8-32.ll 2>&1 | FileCheck %s --check-prefix=CR8_32
; CR8_32: LLVM ERROR: CR8 intrinsic requires 64-bit mode
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/wrong-write64.ll 2>&1 | FileCheck %s --check-prefix=WRONG_WRITE64
; WRONG_WRITE64: LLVM ERROR: CR/DR intrinsic does not match the target code mode
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/wrong-write32.ll 2>&1 | FileCheck %s --check-prefix=WRONG_WRITE32
; WRONG_WRITE32: LLVM ERROR: CR/DR intrinsic does not match the target code mode
; RUN: not opt -passes=verify -disable-output %t/dynamic.ll 2>&1 | FileCheck %s --check-prefix=IMMEDIATE
; IMMEDIATE: immarg operand has non-immediate parameter

;--- 64.ll
declare i64 @llvm.x86.readcr(i32 immarg)
declare i64 @llvm.x86.readdr(i32 immarg)
declare void @llvm.x86.writecr(i32 immarg, i64)
declare void @llvm.x86.writedr(i32 immarg, i64)

define void @dead_reads() {
; X64-LABEL: dead_reads:
; X64: movq %cr3,
; X64: movq %dr7,
; X64: ret
; M64-LABEL: name: dead_reads
; M64: MOV64rc $cr3, implicit-def{{( dead)?}} $eflags
; M64: MOV64rd $dr7, implicit-def{{( dead)?}} $eflags
  %cr = call i64 @llvm.x86.readcr(i32 3)
  %dr = call i64 @llvm.x86.readdr(i32 7)
  ret void
}

define i64 @two_reads() {
; X64-LABEL: two_reads:
; X64: movq %cr0,
; X64: movq %cr0,
; X64: ret
  %a = call i64 @llvm.x86.readcr(i32 0)
  %b = call i64 @llvm.x86.readcr(i32 0)
  %result = xor i64 %a, %b
  ret i64 %result
}

define void @writes(i64 %value) {
; X64-LABEL: writes:
; X64: movq {{[^,]+}}, %cr2
; X64: movq {{[^,]+}}, %cr3
; X64: movq {{[^,]+}}, %cr3
; X64: movq {{[^,]+}}, %dr4
; X64: movq {{[^,]+}}, %dr5
; X64: movq {{[^,]+}}, %dr7
; X64: movq {{[^,]+}}, %cr8
; X64: ret
; M64-LABEL: name: writes
; M64: $cr2 = MOV64cr {{.*}}, implicit-def{{( dead)?}} $eflags
; M64: $dr4 = MOV64dr {{.*}}, implicit-def{{( dead)?}} $eflags
  call void @llvm.x86.writecr(i32 2, i64 %value)
  call void @llvm.x86.writecr(i32 3, i64 %value)
  call void @llvm.x86.writecr(i32 3, i64 %value)
  call void @llvm.x86.writedr(i32 4, i64 %value)
  call void @llvm.x86.writedr(i32 5, i64 %value)
  call void @llvm.x86.writedr(i32 7, i64 %value)
  call void @llvm.x86.writecr(i32 8, i64 %value)
  ret void
}

;--- 32.ll
declare i32 @llvm.x86.readcr32(i32 immarg)
declare i32 @llvm.x86.readdr32(i32 immarg)
declare void @llvm.x86.writecr32(i32 immarg, i32)
declare void @llvm.x86.writedr32(i32 immarg, i32)

define void @dead_reads() {
; X32-LABEL: dead_reads:
; X32: movl %cr3,
; X32: movl %dr7,
; X32: ret
; M32-LABEL: name: dead_reads
; M32: MOV32rc $cr3, implicit-def{{( dead)?}} $eflags
; M32: MOV32rd $dr7, implicit-def{{( dead)?}} $eflags
  %cr = call i32 @llvm.x86.readcr32(i32 3)
  %dr = call i32 @llvm.x86.readdr32(i32 7)
  ret void
}

define i32 @two_reads() {
; X32-LABEL: two_reads:
; X32: movl %cr0,
; X32: movl %cr0,
; X32: ret
  %a = call i32 @llvm.x86.readcr32(i32 0)
  %b = call i32 @llvm.x86.readcr32(i32 0)
  %result = xor i32 %a, %b
  ret i32 %result
}

define void @writes(i32 %value) {
; X32-LABEL: writes:
; X32: movl {{[^,]+}}, %cr2
; X32: movl {{[^,]+}}, %cr3
; X32: movl {{[^,]+}}, %cr3
; X32: movl {{[^,]+}}, %dr4
; X32: movl {{[^,]+}}, %dr5
; X32: movl {{[^,]+}}, %dr7
; X32: ret
; M32-LABEL: name: writes
; M32: $cr2 = MOV32cr {{.*}}, implicit-def{{( dead)?}} $eflags
; M32: $dr4 = MOV32dr {{.*}}, implicit-def{{( dead)?}} $eflags
  call void @llvm.x86.writecr32(i32 2, i32 %value)
  call void @llvm.x86.writecr32(i32 3, i32 %value)
  call void @llvm.x86.writecr32(i32 3, i32 %value)
  call void @llvm.x86.writedr32(i32 4, i32 %value)
  call void @llvm.x86.writedr32(i32 5, i32 %value)
  call void @llvm.x86.writedr32(i32 7, i32 %value)
  ret void
}

;--- invalid-cr.ll
declare i64 @llvm.x86.readcr(i32 immarg)
define void @probe() {
  %result = call i64 @llvm.x86.readcr(i32 1)
  ret void
}

;--- invalid-dr.ll
declare i64 @llvm.x86.readdr(i32 immarg)
define void @probe() {
  %result = call i64 @llvm.x86.readdr(i32 8)
  ret void
}

;--- cr8-32.ll
declare void @llvm.x86.writecr32(i32 immarg, i32)
define void @probe() {
  call void @llvm.x86.writecr32(i32 8, i32 0)
  ret void
}

;--- wrong-write64.ll
declare void @llvm.x86.writecr(i32 immarg, i64)
define void @probe() {
  call void @llvm.x86.writecr(i32 3, i64 0)
  ret void
}

;--- wrong-write32.ll
declare void @llvm.x86.writedr32(i32 immarg, i32)
define void @probe() {
  call void @llvm.x86.writedr32(i32 7, i32 0)
  ret void
}

;--- dynamic.ll
declare i64 @llvm.x86.readdr(i32 immarg)
define i64 @dynamic(i32 %index) {
  %result = call i64 @llvm.x86.readdr(i32 %index)
  ret i64 %result
}
