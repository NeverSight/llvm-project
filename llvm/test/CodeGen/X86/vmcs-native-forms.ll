; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -O0 %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: opt -passes='default<O2>' -S %t/64.ll | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/64.ll -o %t/64-pc-windows-msvc.o
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs -filetype=obj %t/64.ll -o %t/64-apple-darwin.o
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -stop-after=finalize-isel %t/64.ll -o - | FileCheck %s --check-prefix=M64
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs -O0 %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: opt -passes='default<O2>' -S %t/32.ll | llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/32.ll -o %t/32-pc-windows-msvc.o
; RUN: llc -mtriple=i386-apple-darwin -verify-machineinstrs -filetype=obj %t/32.ll -o %t/32-apple-darwin.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs -stop-after=finalize-isel %t/32.ll -o - | FileCheck %s --check-prefix=M32
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/64.ll 2>&1 | FileCheck %s --check-prefix=MODE64
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/32.ll 2>&1 | FileCheck %s --check-prefix=MODE32
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/memory64.ll 2>&1 | FileCheck %s --check-prefix=MODE64
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/memory32.ll 2>&1 | FileCheck %s --check-prefix=MODE32
; MODE64: LLVM ERROR: 64-bit VMCS intrinsic requires 64-bit mode
; MODE32: LLVM ERROR: 32-bit VMCS intrinsic requires 32-bit mode

; VMREAD register results remain chained when either/both results are dead.
; VMWRITE must read the source through the instruction itself.

;--- 64.ll
declare { i64, i8 } @llvm.x86.vmread.reg(i64, i64)
declare i8 @llvm.x86.vmwrite.mem(i64, ptr)

define i64 @read_value(i64 %field, i64 %prior) {
; X64-LABEL: read_value:
; X64: vmreadq %{{[^,]+}}, %{{[a-z0-9]+}}
; X64: ret
; M64-LABEL: name: read_value
; M64: VMREAD64rr {{.*}}implicit-def $eflags
  %first = call { i64, i8 } @llvm.x86.vmread.reg(i64 %field, i64 %prior)
  %value = extractvalue { i64, i8 } %first, 0
  ret i64 %value
}

define i8 @read_status(i64 %field, i64 %prior) {
; X64-LABEL: read_status:
; X64: vmreadq %{{[^,]+}}, %{{[a-z0-9]+}}
; X64: ret
; M64-LABEL: name: read_status
; M64: VMREAD64rr {{.*}}implicit-def $eflags
  %first = call { i64, i8 } @llvm.x86.vmread.reg(i64 %field, i64 %prior)
  %status = extractvalue { i64, i8 } %first, 1
  ret i8 %status
}

define void @read_dead(i64 %field, i64 %prior) {
; X64-LABEL: read_dead:
; X64: vmreadq %{{[^,]+}}, %{{[a-z0-9]+}}
; X64: ret
; M64-LABEL: name: read_dead
; M64: VMREAD64rr {{.*}}implicit-def dead $eflags
  %first = call { i64, i8 } @llvm.x86.vmread.reg(i64 %field, i64 %prior)
  ret void
}

define i64 @read_twice(i64 %field, i64 %prior) {
; X64-LABEL: read_twice:
; X64: vmreadq %{{[^,]+}}, %{{[a-z0-9]+}}
; X64: vmreadq %{{[^,]+}}, %{{[a-z0-9]+}}
; X64: ret
; M64-LABEL: name: read_twice
; M64: VMREAD64rr {{.*}}implicit-def $eflags
  %first = call { i64, i8 } @llvm.x86.vmread.reg(i64 %field, i64 %prior)
  %value = extractvalue { i64, i8 } %first, 0
  %second = call { i64, i8 } @llvm.x86.vmread.reg(i64 %field, i64 %prior)
  %other = extractvalue { i64, i8 } %second, 0
  %result = xor i64 %value, %other
  ret i64 %result
}

define i8 @write_memory(i64 %field, ptr %source) {
; X64-LABEL: write_memory:
; X64: vmwriteq ({{%[a-z0-9]+}}), %
; X64: ret
; M64-LABEL: name: write_memory
; M64: VMWRITE64rm {{.*}}implicit-def $eflags
  %status = call i8 @llvm.x86.vmwrite.mem(i64 %field, ptr %source)
  ret i8 %status
}

;--- 32.ll
declare { i32, i8 } @llvm.x86.vmread.reg32(i32, i32)
declare i8 @llvm.x86.vmwrite.mem32(i32, ptr)

define i32 @read_value(i32 %field, i32 %prior) {
; X32-LABEL: read_value:
; X32: vmreadl %{{[^,]+}}, %{{[a-z0-9]+}}
; X32: ret
; M32-LABEL: name: read_value
; M32: VMREAD32rr {{.*}}implicit-def $eflags
  %first = call { i32, i8 } @llvm.x86.vmread.reg32(i32 %field, i32 %prior)
  %value = extractvalue { i32, i8 } %first, 0
  ret i32 %value
}

define i8 @read_status(i32 %field, i32 %prior) {
; X32-LABEL: read_status:
; X32: vmreadl %{{[^,]+}}, %{{[a-z0-9]+}}
; X32: ret
; M32-LABEL: name: read_status
; M32: VMREAD32rr {{.*}}implicit-def $eflags
  %first = call { i32, i8 } @llvm.x86.vmread.reg32(i32 %field, i32 %prior)
  %status = extractvalue { i32, i8 } %first, 1
  ret i8 %status
}

define void @read_dead(i32 %field, i32 %prior) {
; X32-LABEL: read_dead:
; X32: vmreadl %{{[^,]+}}, %{{[a-z0-9]+}}
; X32: ret
; M32-LABEL: name: read_dead
; M32: VMREAD32rr {{.*}}implicit-def dead $eflags
  %first = call { i32, i8 } @llvm.x86.vmread.reg32(i32 %field, i32 %prior)
  ret void
}

define i32 @read_twice(i32 %field, i32 %prior) {
; X32-LABEL: read_twice:
; X32: vmreadl %{{[^,]+}}, %{{[a-z0-9]+}}
; X32: vmreadl %{{[^,]+}}, %{{[a-z0-9]+}}
; X32: ret
; M32-LABEL: name: read_twice
; M32: VMREAD32rr {{.*}}implicit-def $eflags
  %first = call { i32, i8 } @llvm.x86.vmread.reg32(i32 %field, i32 %prior)
  %value = extractvalue { i32, i8 } %first, 0
  %second = call { i32, i8 } @llvm.x86.vmread.reg32(i32 %field, i32 %prior)
  %other = extractvalue { i32, i8 } %second, 0
  %result = xor i32 %value, %other
  ret i32 %result
}

define i8 @write_memory(i32 %field, ptr %source) {
; X32-LABEL: write_memory:
; X32: vmwritel ({{%[a-z0-9]+}}), %
; X32: ret
; M32-LABEL: name: write_memory
; M32: VMWRITE32rm {{.*}}implicit-def $eflags
  %status = call i8 @llvm.x86.vmwrite.mem32(i32 %field, ptr %source)
  ret i8 %status
}

;--- memory64.ll
declare i8 @llvm.x86.vmwrite.mem(i64, ptr)
define i8 @wrong_mode(i64 %field, ptr %source) {
  %result = call i8 @llvm.x86.vmwrite.mem(i64 %field, ptr %source)
  ret i8 %result
}

;--- memory32.ll
declare i8 @llvm.x86.vmwrite.mem32(i32, ptr)
define i8 @wrong_mode(i32 %field, ptr %source) {
  %result = call i8 @llvm.x86.vmwrite.mem32(i32 %field, ptr %source)
  ret i8 %result
}
