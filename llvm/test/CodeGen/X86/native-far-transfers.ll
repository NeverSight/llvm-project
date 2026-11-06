; RUN: split-file %s %t
; RUN: opt -S -passes="default<O0>" %t/mode64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M64
; RUN: opt -S -passes="default<O2>" %t/mode64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M64
; RUN: opt -S -passes="default<O0>" %t/mode64.ll | llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M64
; RUN: opt -S -passes="default<O2>" %t/mode64.ll | llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M64
; RUN: opt -S -passes="default<O0>" %t/mode64.ll | llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M64
; RUN: opt -S -passes="default<O2>" %t/mode64.ll | llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M64
; RUN: opt -S -passes="default<O0>" %t/mode64.ll | llc -mtriple=x86_64-unknown-linux-gnux32 -O0 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M64
; RUN: opt -S -passes="default<O2>" %t/mode64.ll | llc -mtriple=x86_64-unknown-linux-gnux32 -O2 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -filetype=obj -verify-machineinstrs %t/mode64.ll -o %t/64.o
; RUN: llvm-objdump -d %t/64.o | FileCheck %s --check-prefix=B64
; RUN: opt -S -passes="default<O0>" %t/mode32.ll | llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M32
; RUN: opt -S -passes="default<O2>" %t/mode32.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M32
; RUN: opt -S -passes="default<O0>" %t/mode32.ll | llc -mtriple=i686-pc-windows-msvc -O0 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M32
; RUN: opt -S -passes="default<O2>" %t/mode32.ll | llc -mtriple=i686-pc-windows-msvc -O2 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M32
; RUN: opt -S -passes="default<O0>" %t/mode32.ll | llc -mtriple=i386-apple-darwin -O0 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M32
; RUN: opt -S -passes="default<O2>" %t/mode32.ll | llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M32
; RUN: opt -S -passes="default<O0>" %t/mode32.ll | llc -mtriple=i386-unknown-linux-code16 -O0 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M32
; RUN: opt -S -passes="default<O2>" %t/mode32.ll | llc -mtriple=i386-unknown-linux-code16 -O2 -verify-machineinstrs -o - | FileCheck %s --check-prefix=M32
; RUN: llc -mtriple=i386-unknown-linux-gnu -filetype=obj -verify-machineinstrs %t/mode32.ll -o %t/32.o
; RUN: llvm-objdump -d %t/32.o | FileCheck %s --check-prefix=B32
; RUN: opt -S -passes=verify %t/mode32.ll -o - | FileCheck %s --check-prefix=ATTR
; RUN: not --crash llc -mtriple=i386-linux-gnu %t/wide.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-linux-gnu %t/immediate.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not opt -passes=verify %t/dynamic.ll -disable-output 2>&1 | FileCheck %s --check-prefix=IMM
; RUN: not opt -passes=verify %t/wrong.ll -disable-output 2>&1 | FileCheck %s --check-prefix=TYPE

; MODE: native far-transfer intrinsic does not match the target code mode
; IMM: immarg operand has non-immediate parameter
; TYPE: intrinsic return type expected i16, but got i64
; ATTR-DAG: convergent noduplicate nounwind
; ATTR-DAG: convergent noduplicate noreturn nounwind
; ATTR-NOT: willreturn
; M64-LABEL: lcall16:
; M64: lcallw
; M64: ret
; B64-LABEL: <lcall16>:
; B64: lcallw
; M64-LABEL: lcall32:
; M64: lcalll
; M64: ret
; B64-LABEL: <lcall32>:
; B64: lcalll
; M64-LABEL: lcall64:
; M64: lcallq
; M64: ret
; B64-LABEL: <lcall64>:
; B64: lcallq
; M64-LABEL: ljmp16:
; M64: movb $17,
; M64: mov{{[lq]}}{{.*}}, %{{[er]}}sp
; M64-NEXT: ljmpw
; B64-LABEL: <ljmp16>:
; B64: ljmpw
; M64-LABEL: ljmp32:
; M64: movb $17,
; M64: mov{{[lq]}}{{.*}}, %{{[er]}}sp
; M64-NEXT: ljmpl
; B64-LABEL: <ljmp32>:
; B64: ljmpl
; M64-LABEL: ljmp64:
; M64: movb $17,
; M64: mov{{[lq]}}{{.*}}, %{{[er]}}sp
; M64-NEXT: ljmpq
; B64-LABEL: <ljmp64>:
; B64: ljmpq
; M32-LABEL: lcall16:
; M32: lcallw
; M32: ret
; B32-LABEL: <lcall16>:
; B32: lcallw
; M32-LABEL: lcall32:
; M32: lcalll
; M32: ret
; B32-LABEL: <lcall32>:
; B32: lcalll
; M32-LABEL: lcall16_imm:
; M32: lcallw
; M32: ret
; B32-LABEL: <lcall16_imm>:
; B32: lcallw
; M32-LABEL: lcall32_imm:
; M32: lcalll
; M32: ret
; B32-LABEL: <lcall32_imm>:
; B32: lcalll
; M32-LABEL: ljmp16:
; M32: movb $17,
; M32: mov{{[lq]}}{{.*}}, %{{[er]}}sp
; M32-NEXT: ljmpw
; B32-LABEL: <ljmp16>:
; B32: ljmpw
; M32-LABEL: ljmp32:
; M32: movb $17,
; M32: mov{{[lq]}}{{.*}}, %{{[er]}}sp
; M32-NEXT: ljmpl
; B32-LABEL: <ljmp32>:
; B32: ljmpl
; M32-LABEL: ljmp16_imm:
; M32: movb $17,
; M32: mov{{[lq]}}{{.*}}, %{{[er]}}sp
; M32-NEXT: ljmpw
; B32-LABEL: <ljmp16_imm>:
; B32: ljmpw
; M32-LABEL: ljmp32_imm:
; M32: movb $17,
; M32: mov{{[lq]}}{{.*}}, %{{[er]}}sp
; M32-NEXT: ljmpl
; B32-LABEL: <ljmp32_imm>:
; B32: ljmpl

;--- mode64.ll
declare i16 @llvm.x86.lcall16(ptr)
define i16 @lcall16(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  %value = call i16 @llvm.x86.lcall16(ptr %target)
  store volatile i32 %old, ptr %marker
  ret i16 %value
}
declare i32 @llvm.x86.lcall32(ptr)
define i32 @lcall32(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  %value = call i32 @llvm.x86.lcall32(ptr %target)
  store volatile i32 %old, ptr %marker
  ret i32 %value
}
declare i64 @llvm.x86.lcall64(ptr)
define i64 @lcall64(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  %value = call i64 @llvm.x86.lcall64(ptr %target)
  store volatile i32 %old, ptr %marker
  ret i64 %value
}
declare void @llvm.x86.ljmp16(ptr, ptr)
define void @ljmp16(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  call void @llvm.x86.ljmp16(ptr %target, ptr %stack)
  unreachable
}
declare void @llvm.x86.ljmp32(ptr, ptr)
define void @ljmp32(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  call void @llvm.x86.ljmp32(ptr %target, ptr %stack)
  unreachable
}
declare void @llvm.x86.ljmp64(ptr, ptr)
define void @ljmp64(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  call void @llvm.x86.ljmp64(ptr %target, ptr %stack)
  unreachable
}

;--- mode32.ll
declare i16 @llvm.x86.lcall16(ptr)
define i16 @lcall16(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  %value = call i16 @llvm.x86.lcall16(ptr %target)
  store volatile i32 %old, ptr %marker
  ret i16 %value
}
declare i32 @llvm.x86.lcall32(ptr)
define i32 @lcall32(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  %value = call i32 @llvm.x86.lcall32(ptr %target)
  store volatile i32 %old, ptr %marker
  ret i32 %value
}
declare i16 @llvm.x86.lcall16.imm(i16, i16)
define i16 @lcall16_imm(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  %value = call i16 @llvm.x86.lcall16.imm(i16 6144, i16 48)
  store volatile i32 %old, ptr %marker
  ret i16 %value
}
declare i32 @llvm.x86.lcall32.imm(i32, i16)
define i32 @lcall32_imm(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  %value = call i32 @llvm.x86.lcall32.imm(i32 6144, i16 48)
  store volatile i32 %old, ptr %marker
  ret i32 %value
}
declare void @llvm.x86.ljmp16(ptr, ptr)
define void @ljmp16(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  call void @llvm.x86.ljmp16(ptr %target, ptr %stack)
  unreachable
}
declare void @llvm.x86.ljmp32(ptr, ptr)
define void @ljmp32(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  call void @llvm.x86.ljmp32(ptr %target, ptr %stack)
  unreachable
}
declare void @llvm.x86.ljmp16.imm(i16, i16, ptr)
define void @ljmp16_imm(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  call void @llvm.x86.ljmp16.imm(i16 6144, i16 48, ptr %stack)
  unreachable
}
declare void @llvm.x86.ljmp32.imm(i32, i16, ptr)
define void @ljmp32_imm(ptr %target, ptr %stack, i32 %size, ptr %marker) {
  %local = alloca i8, i32 %size, align 32
  store volatile i8 17, ptr %local
  %old = load volatile i32, ptr %marker
  call void @llvm.x86.ljmp32.imm(i32 6144, i16 48, ptr %stack)
  unreachable
}

;--- wide.ll
declare i64 @llvm.x86.lcall64(ptr)
define i64 @f(ptr %p) {
 %v = call i64 @llvm.x86.lcall64(ptr %p)
 ret i64 %v
}
;--- immediate.ll
declare i32 @llvm.x86.lcall32.imm(i32, i16)
define i32 @f() {
 %v = call i32 @llvm.x86.lcall32.imm(i32 6144, i16 48)
 ret i32 %v
}
;--- dynamic.ll
declare void @llvm.x86.ljmp32.imm(i32, i16, ptr)
define void @f(i32 %pc, ptr %sp) {
 call void @llvm.x86.ljmp32.imm(i32 %pc, i16 48, ptr %sp)
 unreachable
}
;--- wrong.ll
declare i64 @llvm.x86.lcall16(ptr)
define i64 @f(ptr %p) {
 %v = call i64 @llvm.x86.lcall16(ptr %p)
 ret i64 %v
}
