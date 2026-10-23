; RUN: split-file %s %t
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/state32.ll | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes='default<O2>' %t/state32.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/state64.ll | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes='default<O2>' %t/state64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/wrong-sldt.ll 2>&1 | FileCheck %s --check-prefix=ERROR
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/wrong-str.ll 2>&1 | FileCheck %s --check-prefix=ERROR
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/wrong-smsw.ll 2>&1 | FileCheck %s --check-prefix=ERROR
; ERROR: 64-bit descriptor state result requires 64-bit mode

;--- state32.ll

declare i8 @llvm.x86.verr.reg(i16)
; X32-LABEL: probe_verr_reg:
; X32-COUNT-3: verr
define i8 @probe_verr_reg(i16 %input) {
  %a = call i8 @llvm.x86.verr.reg(i16 %input)
  call i8 @llvm.x86.verr.reg(i16 %input)
  %b = call i8 @llvm.x86.verr.reg(i16 %input)
  %sum = add i8 %a, %b
  ret i8 %sum
}

declare i8 @llvm.x86.verr.mem(ptr)
; X32-LABEL: probe_verr_mem:
; X32-COUNT-3: verr
define i8 @probe_verr_mem(ptr %input) {
  %a = call i8 @llvm.x86.verr.mem(ptr %input)
  call i8 @llvm.x86.verr.mem(ptr %input)
  %b = call i8 @llvm.x86.verr.mem(ptr %input)
  %sum = add i8 %a, %b
  ret i8 %sum
}

declare i8 @llvm.x86.verw.reg(i16)
; X32-LABEL: probe_verw_reg:
; X32-COUNT-3: verw
define i8 @probe_verw_reg(i16 %input) {
  %a = call i8 @llvm.x86.verw.reg(i16 %input)
  call i8 @llvm.x86.verw.reg(i16 %input)
  %b = call i8 @llvm.x86.verw.reg(i16 %input)
  %sum = add i8 %a, %b
  ret i8 %sum
}

declare i8 @llvm.x86.verw.mem(ptr)
; X32-LABEL: probe_verw_mem:
; X32-COUNT-3: verw
define i8 @probe_verw_mem(ptr %input) {
  %a = call i8 @llvm.x86.verw.mem(ptr %input)
  call i8 @llvm.x86.verw.mem(ptr %input)
  %b = call i8 @llvm.x86.verw.mem(ptr %input)
  %sum = add i8 %a, %b
  ret i8 %sum
}

declare i16 @llvm.x86.sldt.reg16()
; X32-LABEL: probe_sldt_reg16:
; X32-COUNT-3: sldt
define i16 @probe_sldt_reg16() {
  %a = call i16 @llvm.x86.sldt.reg16()
  call i16 @llvm.x86.sldt.reg16()
  %b = call i16 @llvm.x86.sldt.reg16()
  %sum = add i16 %a, %b
  ret i16 %sum
}

declare i32 @llvm.x86.sldt.reg32()
; X32-LABEL: probe_sldt_reg32:
; X32-COUNT-3: sldt
define i32 @probe_sldt_reg32() {
  %a = call i32 @llvm.x86.sldt.reg32()
  call i32 @llvm.x86.sldt.reg32()
  %b = call i32 @llvm.x86.sldt.reg32()
  %sum = add i32 %a, %b
  ret i32 %sum
}

declare void @llvm.x86.sldt.mem(ptr)
; X32-LABEL: probe_sldt_mem:
; X32-COUNT-3: sldt
define void @probe_sldt_mem(ptr %input) {
  call void @llvm.x86.sldt.mem(ptr %input)
  call void @llvm.x86.sldt.mem(ptr %input)
  call void @llvm.x86.sldt.mem(ptr %input)
  ret void
}

declare i16 @llvm.x86.str.reg16()
; X32-LABEL: probe_str_reg16:
; X32-COUNT-3: str
define i16 @probe_str_reg16() {
  %a = call i16 @llvm.x86.str.reg16()
  call i16 @llvm.x86.str.reg16()
  %b = call i16 @llvm.x86.str.reg16()
  %sum = add i16 %a, %b
  ret i16 %sum
}

declare i32 @llvm.x86.str.reg32()
; X32-LABEL: probe_str_reg32:
; X32-COUNT-3: str
define i32 @probe_str_reg32() {
  %a = call i32 @llvm.x86.str.reg32()
  call i32 @llvm.x86.str.reg32()
  %b = call i32 @llvm.x86.str.reg32()
  %sum = add i32 %a, %b
  ret i32 %sum
}

declare void @llvm.x86.str.mem(ptr)
; X32-LABEL: probe_str_mem:
; X32-COUNT-3: str
define void @probe_str_mem(ptr %input) {
  call void @llvm.x86.str.mem(ptr %input)
  call void @llvm.x86.str.mem(ptr %input)
  call void @llvm.x86.str.mem(ptr %input)
  ret void
}

declare i16 @llvm.x86.smsw.reg16()
; X32-LABEL: probe_smsw_reg16:
; X32-COUNT-3: smsw
define i16 @probe_smsw_reg16() {
  %a = call i16 @llvm.x86.smsw.reg16()
  call i16 @llvm.x86.smsw.reg16()
  %b = call i16 @llvm.x86.smsw.reg16()
  %sum = add i16 %a, %b
  ret i16 %sum
}

declare i32 @llvm.x86.smsw.reg32()
; X32-LABEL: probe_smsw_reg32:
; X32-COUNT-3: smsw
define i32 @probe_smsw_reg32() {
  %a = call i32 @llvm.x86.smsw.reg32()
  call i32 @llvm.x86.smsw.reg32()
  %b = call i32 @llvm.x86.smsw.reg32()
  %sum = add i32 %a, %b
  ret i32 %sum
}

declare void @llvm.x86.smsw.mem(ptr)
; X32-LABEL: probe_smsw_mem:
; X32-COUNT-3: smsw
define void @probe_smsw_mem(ptr %input) {
  call void @llvm.x86.smsw.mem(ptr %input)
  call void @llvm.x86.smsw.mem(ptr %input)
  call void @llvm.x86.smsw.mem(ptr %input)
  ret void
}

declare void @llvm.x86.lldt.reg(i16)
; X32-LABEL: probe_lldt_reg:
; X32-COUNT-3: lldt
define void @probe_lldt_reg(i16 %input) {
  call void @llvm.x86.lldt.reg(i16 %input)
  call void @llvm.x86.lldt.reg(i16 %input)
  call void @llvm.x86.lldt.reg(i16 %input)
  ret void
}

declare void @llvm.x86.lldt.mem(ptr)
; X32-LABEL: probe_lldt_mem:
; X32-COUNT-3: lldt
define void @probe_lldt_mem(ptr %input) {
  call void @llvm.x86.lldt.mem(ptr %input)
  call void @llvm.x86.lldt.mem(ptr %input)
  call void @llvm.x86.lldt.mem(ptr %input)
  ret void
}

declare void @llvm.x86.ltr.reg(i16)
; X32-LABEL: probe_ltr_reg:
; X32-COUNT-3: ltr
define void @probe_ltr_reg(i16 %input) {
  call void @llvm.x86.ltr.reg(i16 %input)
  call void @llvm.x86.ltr.reg(i16 %input)
  call void @llvm.x86.ltr.reg(i16 %input)
  ret void
}

declare void @llvm.x86.ltr.mem(ptr)
; X32-LABEL: probe_ltr_mem:
; X32-COUNT-3: ltr
define void @probe_ltr_mem(ptr %input) {
  call void @llvm.x86.ltr.mem(ptr %input)
  call void @llvm.x86.ltr.mem(ptr %input)
  call void @llvm.x86.ltr.mem(ptr %input)
  ret void
}

declare void @llvm.x86.lmsw.reg(i16)
; X32-LABEL: probe_lmsw_reg:
; X32-COUNT-3: lmsw
define void @probe_lmsw_reg(i16 %input) {
  call void @llvm.x86.lmsw.reg(i16 %input)
  call void @llvm.x86.lmsw.reg(i16 %input)
  call void @llvm.x86.lmsw.reg(i16 %input)
  ret void
}

declare void @llvm.x86.lmsw.mem(ptr)
; X32-LABEL: probe_lmsw_mem:
; X32-COUNT-3: lmsw
define void @probe_lmsw_mem(ptr %input) {
  call void @llvm.x86.lmsw.mem(ptr %input)
  call void @llvm.x86.lmsw.mem(ptr %input)
  call void @llvm.x86.lmsw.mem(ptr %input)
  ret void
}

declare void @llvm.x86.invd()
; X32-LABEL: probe_invd:
; X32-COUNT-3: invd
define void @probe_invd() {
  call void @llvm.x86.invd()
  call void @llvm.x86.invd()
  call void @llvm.x86.invd()
  ret void
}

;--- state64.ll

declare i8 @llvm.x86.verr.reg(i16)
; X64-LABEL: probe_verr_reg:
; X64-COUNT-3: verr
define i8 @probe_verr_reg(i16 %input) {
  %a = call i8 @llvm.x86.verr.reg(i16 %input)
  call i8 @llvm.x86.verr.reg(i16 %input)
  %b = call i8 @llvm.x86.verr.reg(i16 %input)
  %sum = add i8 %a, %b
  ret i8 %sum
}

declare i8 @llvm.x86.verr.mem(ptr)
; X64-LABEL: probe_verr_mem:
; X64-COUNT-3: verr
define i8 @probe_verr_mem(ptr %input) {
  %a = call i8 @llvm.x86.verr.mem(ptr %input)
  call i8 @llvm.x86.verr.mem(ptr %input)
  %b = call i8 @llvm.x86.verr.mem(ptr %input)
  %sum = add i8 %a, %b
  ret i8 %sum
}

declare i8 @llvm.x86.verw.reg(i16)
; X64-LABEL: probe_verw_reg:
; X64-COUNT-3: verw
define i8 @probe_verw_reg(i16 %input) {
  %a = call i8 @llvm.x86.verw.reg(i16 %input)
  call i8 @llvm.x86.verw.reg(i16 %input)
  %b = call i8 @llvm.x86.verw.reg(i16 %input)
  %sum = add i8 %a, %b
  ret i8 %sum
}

declare i8 @llvm.x86.verw.mem(ptr)
; X64-LABEL: probe_verw_mem:
; X64-COUNT-3: verw
define i8 @probe_verw_mem(ptr %input) {
  %a = call i8 @llvm.x86.verw.mem(ptr %input)
  call i8 @llvm.x86.verw.mem(ptr %input)
  %b = call i8 @llvm.x86.verw.mem(ptr %input)
  %sum = add i8 %a, %b
  ret i8 %sum
}

declare i16 @llvm.x86.sldt.reg16()
; X64-LABEL: probe_sldt_reg16:
; X64-COUNT-3: sldt
define i16 @probe_sldt_reg16() {
  %a = call i16 @llvm.x86.sldt.reg16()
  call i16 @llvm.x86.sldt.reg16()
  %b = call i16 @llvm.x86.sldt.reg16()
  %sum = add i16 %a, %b
  ret i16 %sum
}

declare i32 @llvm.x86.sldt.reg32()
; X64-LABEL: probe_sldt_reg32:
; X64-COUNT-3: sldt
define i32 @probe_sldt_reg32() {
  %a = call i32 @llvm.x86.sldt.reg32()
  call i32 @llvm.x86.sldt.reg32()
  %b = call i32 @llvm.x86.sldt.reg32()
  %sum = add i32 %a, %b
  ret i32 %sum
}

declare i64 @llvm.x86.sldt.reg64()
; X64-LABEL: probe_sldt_reg64:
; X64-COUNT-3: sldt
define i64 @probe_sldt_reg64() {
  %a = call i64 @llvm.x86.sldt.reg64()
  call i64 @llvm.x86.sldt.reg64()
  %b = call i64 @llvm.x86.sldt.reg64()
  %sum = add i64 %a, %b
  ret i64 %sum
}

declare void @llvm.x86.sldt.mem(ptr)
; X64-LABEL: probe_sldt_mem:
; X64-COUNT-3: sldt
define void @probe_sldt_mem(ptr %input) {
  call void @llvm.x86.sldt.mem(ptr %input)
  call void @llvm.x86.sldt.mem(ptr %input)
  call void @llvm.x86.sldt.mem(ptr %input)
  ret void
}

declare i16 @llvm.x86.str.reg16()
; X64-LABEL: probe_str_reg16:
; X64-COUNT-3: str
define i16 @probe_str_reg16() {
  %a = call i16 @llvm.x86.str.reg16()
  call i16 @llvm.x86.str.reg16()
  %b = call i16 @llvm.x86.str.reg16()
  %sum = add i16 %a, %b
  ret i16 %sum
}

declare i32 @llvm.x86.str.reg32()
; X64-LABEL: probe_str_reg32:
; X64-COUNT-3: str
define i32 @probe_str_reg32() {
  %a = call i32 @llvm.x86.str.reg32()
  call i32 @llvm.x86.str.reg32()
  %b = call i32 @llvm.x86.str.reg32()
  %sum = add i32 %a, %b
  ret i32 %sum
}

declare i64 @llvm.x86.str.reg64()
; X64-LABEL: probe_str_reg64:
; X64-COUNT-3: str
define i64 @probe_str_reg64() {
  %a = call i64 @llvm.x86.str.reg64()
  call i64 @llvm.x86.str.reg64()
  %b = call i64 @llvm.x86.str.reg64()
  %sum = add i64 %a, %b
  ret i64 %sum
}

declare void @llvm.x86.str.mem(ptr)
; X64-LABEL: probe_str_mem:
; X64-COUNT-3: str
define void @probe_str_mem(ptr %input) {
  call void @llvm.x86.str.mem(ptr %input)
  call void @llvm.x86.str.mem(ptr %input)
  call void @llvm.x86.str.mem(ptr %input)
  ret void
}

declare i16 @llvm.x86.smsw.reg16()
; X64-LABEL: probe_smsw_reg16:
; X64-COUNT-3: smsw
define i16 @probe_smsw_reg16() {
  %a = call i16 @llvm.x86.smsw.reg16()
  call i16 @llvm.x86.smsw.reg16()
  %b = call i16 @llvm.x86.smsw.reg16()
  %sum = add i16 %a, %b
  ret i16 %sum
}

declare i32 @llvm.x86.smsw.reg32()
; X64-LABEL: probe_smsw_reg32:
; X64-COUNT-3: smsw
define i32 @probe_smsw_reg32() {
  %a = call i32 @llvm.x86.smsw.reg32()
  call i32 @llvm.x86.smsw.reg32()
  %b = call i32 @llvm.x86.smsw.reg32()
  %sum = add i32 %a, %b
  ret i32 %sum
}

declare i64 @llvm.x86.smsw.reg64()
; X64-LABEL: probe_smsw_reg64:
; X64-COUNT-3: smsw
define i64 @probe_smsw_reg64() {
  %a = call i64 @llvm.x86.smsw.reg64()
  call i64 @llvm.x86.smsw.reg64()
  %b = call i64 @llvm.x86.smsw.reg64()
  %sum = add i64 %a, %b
  ret i64 %sum
}

declare void @llvm.x86.smsw.mem(ptr)
; X64-LABEL: probe_smsw_mem:
; X64-COUNT-3: smsw
define void @probe_smsw_mem(ptr %input) {
  call void @llvm.x86.smsw.mem(ptr %input)
  call void @llvm.x86.smsw.mem(ptr %input)
  call void @llvm.x86.smsw.mem(ptr %input)
  ret void
}

declare void @llvm.x86.lldt.reg(i16)
; X64-LABEL: probe_lldt_reg:
; X64-COUNT-3: lldt
define void @probe_lldt_reg(i16 %input) {
  call void @llvm.x86.lldt.reg(i16 %input)
  call void @llvm.x86.lldt.reg(i16 %input)
  call void @llvm.x86.lldt.reg(i16 %input)
  ret void
}

declare void @llvm.x86.lldt.mem(ptr)
; X64-LABEL: probe_lldt_mem:
; X64-COUNT-3: lldt
define void @probe_lldt_mem(ptr %input) {
  call void @llvm.x86.lldt.mem(ptr %input)
  call void @llvm.x86.lldt.mem(ptr %input)
  call void @llvm.x86.lldt.mem(ptr %input)
  ret void
}

declare void @llvm.x86.ltr.reg(i16)
; X64-LABEL: probe_ltr_reg:
; X64-COUNT-3: ltr
define void @probe_ltr_reg(i16 %input) {
  call void @llvm.x86.ltr.reg(i16 %input)
  call void @llvm.x86.ltr.reg(i16 %input)
  call void @llvm.x86.ltr.reg(i16 %input)
  ret void
}

declare void @llvm.x86.ltr.mem(ptr)
; X64-LABEL: probe_ltr_mem:
; X64-COUNT-3: ltr
define void @probe_ltr_mem(ptr %input) {
  call void @llvm.x86.ltr.mem(ptr %input)
  call void @llvm.x86.ltr.mem(ptr %input)
  call void @llvm.x86.ltr.mem(ptr %input)
  ret void
}

declare void @llvm.x86.lmsw.reg(i16)
; X64-LABEL: probe_lmsw_reg:
; X64-COUNT-3: lmsw
define void @probe_lmsw_reg(i16 %input) {
  call void @llvm.x86.lmsw.reg(i16 %input)
  call void @llvm.x86.lmsw.reg(i16 %input)
  call void @llvm.x86.lmsw.reg(i16 %input)
  ret void
}

declare void @llvm.x86.lmsw.mem(ptr)
; X64-LABEL: probe_lmsw_mem:
; X64-COUNT-3: lmsw
define void @probe_lmsw_mem(ptr %input) {
  call void @llvm.x86.lmsw.mem(ptr %input)
  call void @llvm.x86.lmsw.mem(ptr %input)
  call void @llvm.x86.lmsw.mem(ptr %input)
  ret void
}

declare void @llvm.x86.invd()
; X64-LABEL: probe_invd:
; X64-COUNT-3: invd
define void @probe_invd() {
  call void @llvm.x86.invd()
  call void @llvm.x86.invd()
  call void @llvm.x86.invd()
  ret void
}

;--- wrong-sldt.ll
declare i64 @llvm.x86.sldt.reg64()
define i64 @bad() {
  %result = call i64 @llvm.x86.sldt.reg64()
  ret i64 %result
}

;--- wrong-str.ll
declare i64 @llvm.x86.str.reg64()
define i64 @bad() {
  %result = call i64 @llvm.x86.str.reg64()
  ret i64 %result
}

;--- wrong-smsw.ll
declare i64 @llvm.x86.smsw.reg64()
define i64 @bad() {
  %result = call i64 @llvm.x86.smsw.reg64()
  ret i64 %result
}
