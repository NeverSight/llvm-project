; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.64.obj
; RUN: llc -mtriple=i686-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.32.obj
; RUN: llc -mtriple=x86_64-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.64.macho
; RUN: llc -mtriple=i386-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.32.macho

declare i8 @llvm.x86.inbyte(i16)
define i8 @probe_inbyte(i16 %port) {
; CHECK-LABEL: probe_inbyte:
; CHECK: inb %dx,
; CHECK: ret
  %value = call i8 @llvm.x86.inbyte(i16 %port)
  ret i8 %value
}

define void @dead_inbyte(i16 %port) {
; CHECK-LABEL: dead_inbyte:
; CHECK: inb %dx,
; CHECK: ret
  %value = call i8 @llvm.x86.inbyte(i16 %port)
  ret void
}

declare i16 @llvm.x86.inword(i16)
define i16 @probe_inword(i16 %port) {
; CHECK-LABEL: probe_inword:
; CHECK: inw %dx,
; CHECK: ret
  %value = call i16 @llvm.x86.inword(i16 %port)
  ret i16 %value
}

define void @dead_inword(i16 %port) {
; CHECK-LABEL: dead_inword:
; CHECK: inw %dx,
; CHECK: ret
  %value = call i16 @llvm.x86.inword(i16 %port)
  ret void
}

declare i32 @llvm.x86.indword(i16)
define i32 @probe_indword(i16 %port) {
; CHECK-LABEL: probe_indword:
; CHECK: inl %dx,
; CHECK: ret
  %value = call i32 @llvm.x86.indword(i16 %port)
  ret i32 %value
}

define void @dead_indword(i16 %port) {
; CHECK-LABEL: dead_indword:
; CHECK: inl %dx,
; CHECK: ret
  %value = call i32 @llvm.x86.indword(i16 %port)
  ret void
}

declare void @llvm.x86.outbyte(i16, i8)
define void @probe_outbyte(i16 %port, i8 %value) {
; CHECK-LABEL: probe_outbyte:
; CHECK: outb %al, %dx
; CHECK: ret
  call void @llvm.x86.outbyte(i16 %port, i8 %value)
  ret void
}

declare void @llvm.x86.outword(i16, i16)
define void @probe_outword(i16 %port, i16 %value) {
; CHECK-LABEL: probe_outword:
; CHECK: outw %ax, %dx
; CHECK: ret
  call void @llvm.x86.outword(i16 %port, i16 %value)
  ret void
}

declare void @llvm.x86.outdword(i16, i32)
define void @probe_outdword(i16 %port, i32 %value) {
; CHECK-LABEL: probe_outdword:
; CHECK: outl %eax, %dx
; CHECK: ret
  call void @llvm.x86.outdword(i16 %port, i32 %value)
  ret void
}

declare void @llvm.x86.invlpg(ptr)
define void @probe_invlpg(ptr %address) {
; CHECK-LABEL: probe_invlpg:
; CHECK: invlpg (
; CHECK: ret
  call void @llvm.x86.invlpg(ptr %address)
  ret void
}

declare void @llvm.x86.sgdt(ptr)
define void @probe_sgdt(ptr %address) {
; CHECK-LABEL: probe_sgdt:
; CHECK: sgdt{{[lq]?}} (
; CHECK: ret
  call void @llvm.x86.sgdt(ptr %address)
  ret void
}

declare void @llvm.x86.sidt(ptr)
define void @probe_sidt(ptr %address) {
; CHECK-LABEL: probe_sidt:
; CHECK: sidt{{[lq]?}} (
; CHECK: ret
  call void @llvm.x86.sidt(ptr %address)
  ret void
}

declare void @llvm.x86.lgdt(ptr)
define void @probe_lgdt(ptr %address) {
; CHECK-LABEL: probe_lgdt:
; CHECK: lgdt{{[lq]?}} (
; CHECK: ret
  call void @llvm.x86.lgdt(ptr %address)
  ret void
}

declare void @llvm.x86.lidt(ptr)
define void @probe_lidt(ptr %address) {
; CHECK-LABEL: probe_lidt:
; CHECK: lidt{{[lq]?}} (
; CHECK: ret
  call void @llvm.x86.lidt(ptr %address)
  ret void
}

declare void @llvm.x86.cli()
declare void @llvm.x86.sti()
define void @interrupt_control() {
; CHECK-LABEL: interrupt_control:
; CHECK: cli
; CHECK: sti
; CHECK: ret
  call void @llvm.x86.cli()
  call void @llvm.x86.sti()
  ret void
}

declare void @llvm.x86.cpuidex(ptr, i32, i32)
define void @processor_query(ptr %output, i32 %leaf, i32 %subleaf) {
; CHECK-LABEL: processor_query:
; CHECK: cpuid
; CHECK-DAG: movl %eax,
; CHECK-DAG: movl %ebx,
; CHECK-DAG: movl %ecx,
; CHECK-DAG: movl %edx,
; CHECK: ret
  call void @llvm.x86.cpuidex(ptr %output, i32 %leaf, i32 %subleaf)
  ret void
}
