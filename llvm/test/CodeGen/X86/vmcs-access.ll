; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.obj
; RUN: llc -mtriple=x86_64-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.macho
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: LLVM ERROR: 64-bit VMCS intrinsic requires 64-bit mode

declare i8 @llvm.x86.vmread(i64, ptr)
declare i8 @llvm.x86.vmwrite(i64, i64)

define i8 @read(i64 %field, ptr %destination) {
; CHECK-LABEL: read:
; CHECK-NOT: #APP
; CHECK: vmreadq %rdi, (%rsi)
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK-NOT: mov{{.*}}, (%rsi)
; CHECK: retq
  %status = call i8 @llvm.x86.vmread(i64 %field, ptr %destination)
  ret i8 %status
}

define i8 @write(i64 %field, i64 %value) {
; CHECK-LABEL: write:
; CHECK-NOT: #APP
; CHECK: vmwriteq %rsi, %rdi
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK: retq
  %status = call i8 @llvm.x86.vmwrite(i64 %field, i64 %value)
  ret i8 %status
}

define void @read_dead_status(i64 %field, ptr %destination) {
; CHECK-LABEL: read_dead_status:
; CHECK: vmreadq %rdi, (%rsi)
; CHECK-NOT: mov{{.*}}, (%rsi)
; CHECK: retq
  %status = call i8 @llvm.x86.vmread(i64 %field, ptr %destination)
  ret void
}

define void @write_dead_status(i64 %field, i64 %value) {
; CHECK-LABEL: write_dead_status:
; CHECK: vmwriteq %rsi, %rdi
; CHECK: retq
  %status = call i8 @llvm.x86.vmwrite(i64 %field, i64 %value)
  ret void
}

define i64 @observe_memory(i64 %field, ptr %destination) {
; CHECK-LABEL: observe_memory:
; CHECK: movq $13, (%rsi)
; CHECK: vmreadq %rdi, (%rsi)
; CHECK: movq (%rsi), %rax
; CHECK: retq
  store i64 13, ptr %destination, align 1
  %status = call i8 @llvm.x86.vmread(i64 %field, ptr %destination)
  %value = load i64, ptr %destination, align 1
  ret i64 %value
}
