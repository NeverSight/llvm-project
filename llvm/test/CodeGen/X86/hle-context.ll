; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -enable-new-pm -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.coff
; RUN: llc -mtriple=x86_64-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.macho
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: HLE context requires 64-bit mode

declare void @llvm.x86.hle.context(ptr, ptr, ptr, i32 immarg, i32 immarg)

define void @acquire_adc(ptr %memory, ptr %gprs, ptr %flags) {
; CHECK-LABEL: acquire_adc:
; CHECK: movq 8(%r10), %rcx
; CHECK: movq (%r11), %rdx
; CHECK: btq $0, %rdx
; CHECK: xacquire
; CHECK: lock
; CHECK: adcq %rcx, (%r9)
; CHECK-NEXT: pause
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %cl
; CHECK: movq %rdx, (%r11)
  call void @llvm.x86.hle.context(ptr %memory, ptr %gprs, ptr %flags, i32 769, i32 8)
  ret void
}

define void @acquire_exchange8(ptr %memory, ptr %gprs, ptr %flags) {
; CHECK-LABEL: acquire_exchange8:
; CHECK: xacquire
; CHECK: lock
; CHECK: xchgb %cl, (%r9)
; CHECK-NEXT: pause
; CHECK-NEXT: movq %rcx, 8(%r10)
; CHECK-NOT: lahf
; CHECK: retq
  call void @llvm.x86.hle.context(ptr %memory, ptr %gprs, ptr %flags, i32 785, i32 1)
  ret void
}

define void @release_compare8b(ptr %memory, ptr %gprs, ptr %flags) {
; CHECK-LABEL: release_compare8b:
; CHECK: movq (%r10), %rax
; CHECK: movq 8(%r10), %rcx
; CHECK: movq 16(%r10), %rdx
; CHECK: movq 24(%r10), %rbx
; CHECK: xrelease
; CHECK: lock
; CHECK: cmpxchg8b (%r9)
; CHECK-NEXT: pause
; CHECK-NEXT: movq %rax, (%r10)
; CHECK-NEXT: movq %rdx, 16(%r10)
; CHECK: andl $64, %eax
  call void @llvm.x86.hle.context(ptr %memory, ptr %gprs, ptr %flags, i32 519, i32 8)
  ret void
}

define void @acquire_bit16(ptr %memory, ptr %gprs, ptr %flags) {
; CHECK-LABEL: acquire_bit16:
; CHECK: xacquire
; CHECK: lock
; CHECK: btsw %cx, (%r9)
; CHECK-NEXT: lahf
; CHECK: andl $2197, %eax
  call void @llvm.x86.hle.context(ptr %memory, ptr %gprs, ptr %flags, i32 261, i32 2)
  ret void
}

define void @release_store64(ptr %memory, ptr %gprs, ptr %flags) {
; CHECK-LABEL: release_store64:
; CHECK: xrelease
; CHECK-NEXT: movq %rcx, (%r9)
; CHECK-NOT: lahf
; CHECK: retq
  call void @llvm.x86.hle.context(ptr %memory, ptr %gprs, ptr %flags, i32 18, i32 8)
  ret void
}

define void @release_dec32(ptr %memory, ptr %gprs, ptr %flags) {
; CHECK-LABEL: release_dec32:
; CHECK: xrelease
; CHECK: lock
; CHECK: decl (%r9)
; CHECK-NEXT: pause
; CHECK-NEXT: lahf
; CHECK: andl $2260, %eax
  call void @llvm.x86.hle.context(ptr %memory, ptr %gprs, ptr %flags, i32 520, i32 4)
  ret void
}
