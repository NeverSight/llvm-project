; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=i686-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.obj
; RUN: llc -mtriple=i386-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.macho
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: LLVM ERROR: 32-bit VMCS intrinsic requires 32-bit mode

declare i8 @llvm.x86.vmread32(i32, ptr)
declare i8 @llvm.x86.vmwrite32(i32, i32)

define i8 @read32(i32 %field, ptr %destination) {
; CHECK-LABEL: read32:
; CHECK-NOT: #APP
; CHECK: vmreadl
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK: retl
  %status = call i8 @llvm.x86.vmread32(i32 %field, ptr %destination)
  ret i8 %status
}

define i8 @write32(i32 %field, i32 %value) {
; CHECK-LABEL: write32:
; CHECK-NOT: #APP
; CHECK: vmwritel
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK: retl
  %status = call i8 @llvm.x86.vmwrite32(i32 %field, i32 %value)
  ret i8 %status
}

define void @read32_dead_status(i32 %field, ptr %destination) {
; CHECK-LABEL: read32_dead_status:
; CHECK: vmreadl
; CHECK: retl
  %status = call i8 @llvm.x86.vmread32(i32 %field, ptr %destination)
  ret void
}

define void @write32_dead_status(i32 %field, i32 %value) {
; CHECK-LABEL: write32_dead_status:
; CHECK: vmwritel
; CHECK: retl
  %status = call i8 @llvm.x86.vmwrite32(i32 %field, i32 %value)
  ret void
}
