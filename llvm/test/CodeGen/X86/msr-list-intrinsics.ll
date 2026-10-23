; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.obj
; RUN: llc -mtriple=x86_64-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.macho
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: LLVM ERROR: MSRLIST intrinsic requires 64-bit mode

declare i64 @llvm.x86.rdmsrlist(ptr, ptr, i64)
declare i64 @llvm.x86.wrmsrlist(ptr, ptr, i64)

define i64 @read_list(ptr %indices, ptr %values, i64 %mask) {
; CHECK-LABEL: read_list:
; CHECK-NOT: #APP
; CHECK: rdmsrlist
; CHECK-NEXT: movq %rcx, %rax
; CHECK: ret
  %remaining = call i64 @llvm.x86.rdmsrlist(ptr %indices, ptr %values, i64 %mask)
  ret i64 %remaining
}

define i64 @write_list(ptr %indices, ptr %values, i64 %mask) {
; CHECK-LABEL: write_list:
; CHECK-NOT: #APP
; CHECK: wrmsrlist
; CHECK-NEXT: movq %rcx, %rax
; CHECK: ret
  %remaining = call i64 @llvm.x86.wrmsrlist(ptr %indices, ptr %values, i64 %mask)
  ret i64 %remaining
}

define void @read_list_dead(ptr %indices, ptr %values, i64 %mask) {
; CHECK-LABEL: read_list_dead:
; CHECK: rdmsrlist
; CHECK: ret
  %remaining = call i64 @llvm.x86.rdmsrlist(ptr %indices, ptr %values, i64 %mask)
  ret void
}

define void @write_list_dead(ptr %indices, ptr %values, i64 %mask) {
; CHECK-LABEL: write_list_dead:
; CHECK: wrmsrlist
; CHECK: ret
  %remaining = call i64 @llvm.x86.wrmsrlist(ptr %indices, ptr %values, i64 %mask)
  ret void
}

define i64 @read_list_preserve_mask(ptr %indices, ptr %values, i64 %mask) {
; CHECK-LABEL: read_list_preserve_mask:
; CHECK: rdmsrlist
; CHECK: xorq
; CHECK: ret
  %remaining = call i64 @llvm.x86.rdmsrlist(ptr %indices, ptr %values, i64 %mask)
  %result = xor i64 %remaining, %mask
  ret i64 %result
}

define i64 @ordered_list_access(ptr %indices, ptr %values, i64 %mask) {
; CHECK-LABEL: ordered_list_access:
; CHECK: movq $16,
; CHECK: rdmsrlist
; CHECK: movq (
; CHECK: wrmsrlist
; CHECK: ret
  store i64 16, ptr %indices, align 8
  %remaining = call i64 @llvm.x86.rdmsrlist(ptr %indices, ptr %values, i64 %mask)
  %data = load i64, ptr %values, align 8
  %written = call i64 @llvm.x86.wrmsrlist(ptr %indices, ptr %values, i64 %mask)
  ret i64 %data
}
