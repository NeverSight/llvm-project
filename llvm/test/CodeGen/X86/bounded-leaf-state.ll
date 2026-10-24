; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,+sahf -verify-machineinstrs -O0 %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,+sahf -verify-machineinstrs -O2 %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes='default<O2>' %t/64.ll -o %t/optimized64.ll
; RUN: FileCheck %s --check-prefix=IR64 < %t/optimized64.ll
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sgx,+sahf -verify-machineinstrs %t/optimized64.ll -filetype=obj -o %t/64-unknown-linux-gnu.o
; RUN: llc -mtriple=x86_64-pc-windows-msvc -mattr=+sgx,+sahf -verify-machineinstrs %t/optimized64.ll -filetype=obj -o %t/64-pc-windows-msvc.o
; RUN: llc -mtriple=x86_64-apple-darwin -mattr=+sgx,+sahf -verify-machineinstrs %t/optimized64.ll -filetype=obj -o %t/64-apple-darwin.o
; RUN: llc -mtriple=x86_64 -mattr=+sgx,+sahf -verify-machineinstrs -x86-asm-syntax=att %t/64.ll -o - | llvm-mc -triple=x86_64 -filetype=obj -o %t/64-att.o
; RUN: llc -mtriple=x86_64 -mattr=+sgx,+sahf -verify-machineinstrs -x86-asm-syntax=intel %t/64.ll -o - | llvm-mc -triple=x86_64 -filetype=obj -o %t/64-intel.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx,+sahf -verify-machineinstrs -O0 %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx,+sahf -verify-machineinstrs -O2 %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes='default<O2>' %t/32.ll -o %t/optimized32.ll
; RUN: FileCheck %s --check-prefix=IR32 < %t/optimized32.ll
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sgx,+sahf -verify-machineinstrs %t/optimized32.ll -filetype=obj -o %t/32-unknown-linux-gnu.o
; RUN: llc -mtriple=i386-pc-windows-msvc -mattr=+sgx,+sahf -verify-machineinstrs %t/optimized32.ll -filetype=obj -o %t/32-pc-windows-msvc.o
; RUN: llc -mtriple=i386-apple-darwin -mattr=+sgx,+sahf -verify-machineinstrs %t/optimized32.ll -filetype=obj -o %t/32-apple-darwin.o
; RUN: llc -mtriple=i386 -mattr=+sgx,+sahf -verify-machineinstrs -x86-asm-syntax=att %t/32.ll -o - | llvm-mc -triple=i386 -filetype=obj -o %t/32-att.o
; RUN: llc -mtriple=i386 -mattr=+sgx,+sahf -verify-machineinstrs -x86-asm-syntax=intel %t/32.ll -o - | llvm-mc -triple=i386 -filetype=obj -o %t/32-intel.o
; RUN: not --crash llc -mtriple=i386 -mattr=+sgx,+sahf %t/64.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,+sahf %t/32.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-pc-linux-code16 -mattr=+sgx,+sahf %t/32.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64 -mattr=+sgx,-sahf %t/64.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=FLAGS
; RUN: not --crash llc -mtriple=x86_64 -mattr=-sgx,+sahf %t/64.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=SGX
; RUN: llc -mtriple=i386 -mattr=+sgx,-sahf -verify-machineinstrs %t/32.ll -filetype=obj -o %t/no-sahf.o
; RUN: llvm-objdump -d %t/64-unknown-linux-gnu.o | FileCheck %s --check-prefix=BYTES
; RUN: llvm-objdump -d %t/32-unknown-linux-gnu.o | FileCheck %s --check-prefix=BYTES
; BYTES-LABEL: <enclu_0>:
; BYTES: 04 7f
; BYTES-NEXT: 9e
; MODE: bounded leaf state does not match the target code mode
; FLAGS: bounded leaf state requires the sahf target feature
; SGX: bounded ENCLU state requires the sgx target feature

;--- 64.ll
declare { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64, i64, i64, i64, i16)
declare { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64, i64, i64, i64, i16)

define { i64, i64, i64, i64, i16 } @enclu_0(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: enclu_0:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: enclu
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @enclu_0(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 12379814829207060480, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @enclu_1(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: enclu_1:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: enclu
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @enclu_1(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 12379814829207060481, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @enclu_5(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: enclu_5:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: enclu
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @enclu_5(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 12379814829207060485, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @enclu_6(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: enclu_6:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: enclu
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @enclu_6(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 12379814829207060486, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @enclu_7(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: enclu_7:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: enclu
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @enclu_7(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 12379814829207060487, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @enclu_8(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: enclu_8:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: enclu
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @enclu_8(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 12379814829207060488, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @enclu_9(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: enclu_9:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: enclu
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @enclu_9(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 12379814829207060489, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @enclu_10(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: enclu_10:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: enclu
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @enclu_10(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 12379814829207060490, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @enclu_11(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: enclu_11:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: enclu
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @enclu_11(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 12379814829207060491, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @getsec_0(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: getsec_0:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: getsec
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @getsec_0(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 12379814829207060480, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @getsec_6(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: getsec_6:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: getsec
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @getsec_6(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 12379814829207060486, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @getsec_7(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: getsec_7:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: getsec
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @getsec_7(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 12379814829207060487, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define { i64, i64, i64, i64, i16 } @getsec_8(i64 %b, i64 %c, i64 %d, i16 %flags) {
; X64-LABEL: getsec_8:
; X64: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: movq %rsi, %rax
; X64-NEXT: getsec
; X64-NEXT: movq %rax, %rsi
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: movw %ax, %di
; X64-NEXT: movq %rsi, %rax
; IR64-LABEL: define { i64, i64, i64, i64, i16 } @getsec_8(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 12379814829207060488, i64 %b, i64 %c, i64 %d, i16 %flags)
  ret { i64, i64, i64, i64, i16 } %r
}

define void @unused() {
; IR64-LABEL: define void @unused(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(
; IR64: call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(
  call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 8, i64 0, i64 0, i64 0, i16 0)
  call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 8, i64 0, i64 0, i64 0, i16 0)
  ret void
}

;--- 32.ll
declare { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(i32, i32, i32, i32, i16)
declare { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(i32, i32, i32, i32, i16)

define { i32, i32, i32, i32, i16 } @enclu_0(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: enclu_0:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: enclu
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @enclu_0(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(i32 0, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @enclu_1(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: enclu_1:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: enclu
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @enclu_1(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(i32 1, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @enclu_5(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: enclu_5:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: enclu
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @enclu_5(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(i32 5, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @enclu_6(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: enclu_6:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: enclu
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @enclu_6(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(i32 6, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @enclu_7(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: enclu_7:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: enclu
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @enclu_7(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(i32 7, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @enclu_8(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: enclu_8:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: enclu
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @enclu_8(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(i32 8, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @enclu_9(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: enclu_9:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: enclu
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @enclu_9(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(i32 9, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @enclu_10(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: enclu_10:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: enclu
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @enclu_10(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(i32 10, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @enclu_11(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: enclu_11:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: enclu
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @enclu_11(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.enclu.bounded.state32(i32 11, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @getsec_0(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: getsec_0:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: getsec
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @getsec_0(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(i32 0, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @getsec_6(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: getsec_6:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: getsec
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @getsec_6(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(i32 6, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @getsec_7(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: getsec_7:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: getsec
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @getsec_7(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(i32 7, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define { i32, i32, i32, i32, i16 } @getsec_8(i32 %b, i32 %c, i32 %d, i16 %flags) {
; X32-LABEL: getsec_8:
; X32: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: movl %esi, %eax
; X32-NEXT: getsec
; X32-NEXT: movl %eax, %esi
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: movw %ax, %di
; X32-NEXT: movl %esi, %eax
; IR32-LABEL: define { i32, i32, i32, i32, i16 } @getsec_8(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(
  %r = call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(i32 8, i32 %b, i32 %c, i32 %d, i16 %flags)
  ret { i32, i32, i32, i32, i16 } %r
}

define void @unused() {
; IR32-LABEL: define void @unused(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(
; IR32: call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(
  call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(i32 8, i32 0, i32 0, i32 0, i16 0)
  call { i32, i32, i32, i32, i16 } @llvm.x86.getsec.bounded.state32(i32 8, i32 0, i32 0, i32 0, i16 0)
  ret void
}
