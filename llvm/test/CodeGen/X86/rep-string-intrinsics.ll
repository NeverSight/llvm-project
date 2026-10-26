; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -O0 %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: opt -passes='default<O2>' -S %t/64.ll | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/64.ll -o %t/64-pc-windows-msvc.o
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs -filetype=obj %t/64.ll -o %t/64-apple-darwin.o
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -stop-after=finalize-isel %t/64.ll -o - | FileCheck %s --check-prefix=M64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -x86-asm-syntax=att %t/64.ll -o - | llvm-mc -triple=x86_64-unknown-linux-gnu -filetype=obj -o %t/64-att.o
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -x86-asm-syntax=intel %t/64.ll -o - | llvm-mc -triple=x86_64-unknown-linux-gnu -filetype=obj -o %t/64-intel.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs -O0 %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: opt -passes='default<O2>' -S %t/32.ll | llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/32.ll -o %t/32-pc-windows-msvc.o
; RUN: llc -mtriple=i386-apple-darwin -verify-machineinstrs -filetype=obj %t/32.ll -o %t/32-apple-darwin.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs -stop-after=finalize-isel %t/32.ll -o - | FileCheck %s --check-prefix=M32
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs -x86-asm-syntax=att %t/32.ll -o - | llvm-mc -triple=i386-unknown-linux-gnu -filetype=obj -o %t/32-att.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs -x86-asm-syntax=intel %t/32.ll -o - | llvm-mc -triple=i386-unknown-linux-gnu -filetype=obj -o %t/32-intel.o
; RUN: llc -mtriple=x86_64-unknown-linux-gnux32 -verify-machineinstrs -filetype=obj %t/64.ll -o %t/x32.o
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/64.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu %t/32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/qword.ll 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: LLVM ERROR: REP memory-string intrinsic does not match the target code mode

; Each call owns one native REP instruction, including implicit DF and the
; modified count/address registers. Neither optimization nor object emission
; may turn these operations into library calls or inline assembly.

;--- 64.ll
declare void @llvm.x86.movsb(ptr, ptr, i64)

define void @movsb(ptr %first, ptr %second, i64 %count) {
; X64-LABEL: movsb:
; X64: rep;movsb
; X64: ret
; M64-LABEL: name: movsb
; M64: REP_MOVSB_64 {{.*}}implicit $df
  call void @llvm.x86.movsb(ptr %first, ptr %second, i64 %count)
  ret void
}
declare void @llvm.x86.movsw(ptr, ptr, i64)

define void @movsw(ptr %first, ptr %second, i64 %count) {
; X64-LABEL: movsw:
; X64: rep;movsw
; X64: ret
; M64-LABEL: name: movsw
; M64: REP_MOVSW_64 {{.*}}implicit $df
  call void @llvm.x86.movsw(ptr %first, ptr %second, i64 %count)
  ret void
}
declare void @llvm.x86.movsd.rep(ptr, ptr, i64)

define void @movsd_rep(ptr %first, ptr %second, i64 %count) {
; X64-LABEL: movsd_rep:
; X64: rep;movsl
; X64: ret
; M64-LABEL: name: movsd_rep
; M64: REP_MOVSD_64 {{.*}}implicit $df
  call void @llvm.x86.movsd.rep(ptr %first, ptr %second, i64 %count)
  ret void
}
declare void @llvm.x86.movsq(ptr, ptr, i64)

define void @movsq(ptr %first, ptr %second, i64 %count) {
; X64-LABEL: movsq:
; X64: rep;movsq
; X64: ret
; M64-LABEL: name: movsq
; M64: REP_MOVSQ_64 {{.*}}implicit $df
  call void @llvm.x86.movsq(ptr %first, ptr %second, i64 %count)
  ret void
}
declare void @llvm.x86.stosb(ptr, i8, i64)

define void @stosb(ptr %first, i8 %second, i64 %count) {
; X64-LABEL: stosb:
; X64: rep;stosb
; X64: ret
; M64-LABEL: name: stosb
; M64: REP_STOSB_64 {{.*}}implicit $df
  call void @llvm.x86.stosb(ptr %first, i8 %second, i64 %count)
  ret void
}
declare void @llvm.x86.stosw(ptr, i16, i64)

define void @stosw(ptr %first, i16 %second, i64 %count) {
; X64-LABEL: stosw:
; X64: rep;stosw
; X64: ret
; M64-LABEL: name: stosw
; M64: REP_STOSW_64 {{.*}}implicit $df
  call void @llvm.x86.stosw(ptr %first, i16 %second, i64 %count)
  ret void
}
declare void @llvm.x86.stosd(ptr, i32, i64)

define void @stosd(ptr %first, i32 %second, i64 %count) {
; X64-LABEL: stosd:
; X64: rep;stosl
; X64: ret
; M64-LABEL: name: stosd
; M64: REP_STOSD_64 {{.*}}implicit $df
  call void @llvm.x86.stosd(ptr %first, i32 %second, i64 %count)
  ret void
}
declare void @llvm.x86.stosq(ptr, i64, i64)

define void @stosq(ptr %first, i64 %second, i64 %count) {
; X64-LABEL: stosq:
; X64: rep;stosq
; X64: ret
; M64-LABEL: name: stosq
; M64: REP_STOSQ_64 {{.*}}implicit $df
  call void @llvm.x86.stosq(ptr %first, i64 %second, i64 %count)
  ret void
}
declare void @llvm.x86.inbytestring(i16, ptr, i32)

define void @inbytestring(i16 %first, ptr %second, i32 %count) {
; X64-LABEL: inbytestring:
; X64: rep;insb
; X64: ret
; M64-LABEL: name: inbytestring
; M64: REP_INSB_64 {{.*}}implicit $df
  call void @llvm.x86.inbytestring(i16 %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.inwordstring(i16, ptr, i32)

define void @inwordstring(i16 %first, ptr %second, i32 %count) {
; X64-LABEL: inwordstring:
; X64: rep;insw
; X64: ret
; M64-LABEL: name: inwordstring
; M64: REP_INSW_64 {{.*}}implicit $df
  call void @llvm.x86.inwordstring(i16 %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.indwordstring(i16, ptr, i32)

define void @indwordstring(i16 %first, ptr %second, i32 %count) {
; X64-LABEL: indwordstring:
; X64: rep;insl
; X64: ret
; M64-LABEL: name: indwordstring
; M64: REP_INSL_64 {{.*}}implicit $df
  call void @llvm.x86.indwordstring(i16 %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.outbytestring(i16, ptr, i32)

define void @outbytestring(i16 %first, ptr %second, i32 %count) {
; X64-LABEL: outbytestring:
; X64: rep;outsb
; X64: ret
; M64-LABEL: name: outbytestring
; M64: REP_OUTSB_64 {{.*}}implicit $df
  call void @llvm.x86.outbytestring(i16 %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.outwordstring(i16, ptr, i32)

define void @outwordstring(i16 %first, ptr %second, i32 %count) {
; X64-LABEL: outwordstring:
; X64: rep;outsw
; X64: ret
; M64-LABEL: name: outwordstring
; M64: REP_OUTSW_64 {{.*}}implicit $df
  call void @llvm.x86.outwordstring(i16 %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.outdwordstring(i16, ptr, i32)

define void @outdwordstring(i16 %first, ptr %second, i32 %count) {
; X64-LABEL: outdwordstring:
; X64: rep;outsl
; X64: ret
; M64-LABEL: name: outdwordstring
; M64: REP_OUTSL_64 {{.*}}implicit $df
  call void @llvm.x86.outdwordstring(i16 %first, ptr %second, i32 %count)
  ret void
}

;--- 32.ll
declare void @llvm.x86.movsb32(ptr, ptr, i32)

define void @movsb(ptr %first, ptr %second, i32 %count) {
; X32-LABEL: movsb:
; X32: rep;movsb
; X32: ret
; M32-LABEL: name: movsb
; M32: REP_MOVS32_SAVE_ESI {{.*}}implicit $df
  call void @llvm.x86.movsb32(ptr %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.movsw32(ptr, ptr, i32)

define void @movsw(ptr %first, ptr %second, i32 %count) {
; X32-LABEL: movsw:
; X32: rep;movsw
; X32: ret
; M32-LABEL: name: movsw
; M32: REP_MOVS32_SAVE_ESI {{.*}}implicit $df
  call void @llvm.x86.movsw32(ptr %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.movsd.rep32(ptr, ptr, i32)

define void @movsd_rep(ptr %first, ptr %second, i32 %count) {
; X32-LABEL: movsd_rep:
; X32: rep;movsl
; X32: ret
; M32-LABEL: name: movsd_rep
; M32: REP_MOVS32_SAVE_ESI {{.*}}implicit $df
  call void @llvm.x86.movsd.rep32(ptr %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.stosb32(ptr, i8, i32)

define void @stosb(ptr %first, i8 %second, i32 %count) {
; X32-LABEL: stosb:
; X32: rep;stosb
; X32: ret
; M32-LABEL: name: stosb
; M32: REP_STOSB_32 {{.*}}implicit $df
  call void @llvm.x86.stosb32(ptr %first, i8 %second, i32 %count)
  ret void
}
declare void @llvm.x86.stosw32(ptr, i16, i32)

define void @stosw(ptr %first, i16 %second, i32 %count) {
; X32-LABEL: stosw:
; X32: rep;stosw
; X32: ret
; M32-LABEL: name: stosw
; M32: REP_STOSW_32 {{.*}}implicit $df
  call void @llvm.x86.stosw32(ptr %first, i16 %second, i32 %count)
  ret void
}
declare void @llvm.x86.stosd32(ptr, i32, i32)

define void @stosd(ptr %first, i32 %second, i32 %count) {
; X32-LABEL: stosd:
; X32: rep;stosl
; X32: ret
; M32-LABEL: name: stosd
; M32: REP_STOSD_32 {{.*}}implicit $df
  call void @llvm.x86.stosd32(ptr %first, i32 %second, i32 %count)
  ret void
}
declare void @llvm.x86.inbytestring(i16, ptr, i32)

define void @inbytestring(i16 %first, ptr %second, i32 %count) {
; X32-LABEL: inbytestring:
; X32: rep;insb
; X32: ret
; M32-LABEL: name: inbytestring
; M32: REP_INSB_32 {{.*}}implicit $df
  call void @llvm.x86.inbytestring(i16 %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.inwordstring(i16, ptr, i32)

define void @inwordstring(i16 %first, ptr %second, i32 %count) {
; X32-LABEL: inwordstring:
; X32: rep;insw
; X32: ret
; M32-LABEL: name: inwordstring
; M32: REP_INSW_32 {{.*}}implicit $df
  call void @llvm.x86.inwordstring(i16 %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.indwordstring(i16, ptr, i32)

define void @indwordstring(i16 %first, ptr %second, i32 %count) {
; X32-LABEL: indwordstring:
; X32: rep;insl
; X32: ret
; M32-LABEL: name: indwordstring
; M32: REP_INSL_32 {{.*}}implicit $df
  call void @llvm.x86.indwordstring(i16 %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.outbytestring(i16, ptr, i32)

define void @outbytestring(i16 %first, ptr %second, i32 %count) {
; X32-LABEL: outbytestring:
; X32: rep;outsb
; X32: ret
; M32-LABEL: name: outbytestring
; M32: REP_OUTS32_SAVE_ESI {{.*}}implicit $df
  call void @llvm.x86.outbytestring(i16 %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.outwordstring(i16, ptr, i32)

define void @outwordstring(i16 %first, ptr %second, i32 %count) {
; X32-LABEL: outwordstring:
; X32: rep;outsw
; X32: ret
; M32-LABEL: name: outwordstring
; M32: REP_OUTS32_SAVE_ESI {{.*}}implicit $df
  call void @llvm.x86.outwordstring(i16 %first, ptr %second, i32 %count)
  ret void
}
declare void @llvm.x86.outdwordstring(i16, ptr, i32)

define void @outdwordstring(i16 %first, ptr %second, i32 %count) {
; X32-LABEL: outdwordstring:
; X32: rep;outsl
; X32: ret
; M32-LABEL: name: outdwordstring
; M32: REP_OUTS32_SAVE_ESI {{.*}}implicit $df
  call void @llvm.x86.outdwordstring(i16 %first, ptr %second, i32 %count)
  ret void
}

;--- qword.ll
declare void @llvm.x86.stosq(ptr, i64, i64)
define void @qword(ptr %p, i64 %value, i64 %count) {
  call void @llvm.x86.stosq(ptr %p, i64 %value, i64 %count)
  ret void
}
