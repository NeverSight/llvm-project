; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs %t/good.ll -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs %t/good.ll -o - | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/good.ll | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/good.ll -o %t/win.o
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs -filetype=obj %t/good.ll -o %t/mac.o
; RUN: not --crash llc -mtriple=x86_64 -mattr=+amx-tile %t/mixed.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MIXED
; RUN: not --crash llc -mtriple=x86_64 -mattr=+amx-tile %t/forged.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=FRAME
; RUN: not --crash llc -mtriple=x86_64 -mattr=+amx-tile %t/width.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=x86_64 -mattr=+amx-tile %t/segment.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=CONTROL
; MIXED: cannot mix physical AMX tile intrinsics with compiler-managed tiles
; FRAME: AMX stack memory requires an RSP-based helper frame
; CONTROL: invalid native memory segment prefix or stack-reference control

; BP is an ordinary callee-saved GPR in each isolated leaf. The surrounding
; function may own a dynamically realigned frame. Both native restart and
; exception unwinding must see the leaf's saved registers, not a borrowed
; frame pointer or a stride that has had an unrelated frame offset added.

;--- good.ll
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
declare void @llvm.x86.tileloaddt164.address(i8, i64, i64, i32, i32, i32)
declare void @llvm.x86.tileloaddrs64.address(i8, i64, i64, i32, i32, i32)
declare void @llvm.x86.tileloaddrst164.address(i8, i64, i64, i32, i32, i32)
declare void @llvm.x86.tilestored64.address(i8, i64, i64, i32, i32, i32)
declare void @use(ptr)
define i64 @dynamic_frame(i64 %base, i64 %stride, i64 %n) #0 {
; CHECK-LABEL: dynamic_frame:
; CHECK: movq %rsp, %rbp
; CHECK: andq $-64, %rsp
; CHECK: callq __llvm_x86_amx_stack
  %fixed = alloca i64, align 64
  %dynamic = alloca i8, i64 %n, align 32
  store volatile i64 42, ptr %fixed
  call void @use(ptr %dynamic)
  call void @llvm.x86.tileloadd64.address(i8 0, i64 %base, i64 %stride, i32 64, i32 256, i32 0)
  call void @llvm.x86.tileloaddt164.address(i8 1, i64 %base, i64 %stride, i32 64, i32 294, i32 1)
  call void @llvm.x86.tileloaddrs64.address(i8 2, i64 %base, i64 %stride, i32 64, i32 302, i32 0)
  call void @llvm.x86.tileloaddrst164.address(i8 3, i64 %base, i64 %stride, i32 64, i32 310, i32 1)
  call void @llvm.x86.tilestored64.address(i8 7, i64 %base, i64 %stride, i32 64, i32 318, i32 0)
  call void @use(ptr %dynamic)
  %r = load volatile i64, ptr %fixed
  ret i64 %r
}

declare void @llvm.x86.bndmk(i32, i64, i64, i32, i32)
declare void @llvm.x86.bndcl.reg(i32, i64)
define void @bounds_and_tiles(i64 %base, i64 %stride) #0 {
; CHECK-LABEL: bounds_and_tiles:
; CHECK: bndmk
; CHECK: repne{{[ \t]+}}callq __llvm_x86_amx_stack
; CHECK: bndcl
; CHECK: repne{{[ \t]+}}ret
  call void @llvm.x86.bndmk(i32 0, i64 %base, i64 %stride, i32 64, i32 0)
  call void @llvm.x86.tileloadd64.address(i8 0, i64 %base, i64 %stride, i32 64, i32 256, i32 0)
  call void @llvm.x86.bndcl.reg(i32 0, i64 %base)
  ret void
}
; CHECK-LABEL: __llvm_x86_amx_stack:
; CHECK: pushq %rbp
; CHECK: .cfi_offset %rbp,
; CHECK-NOT: movq %rsp, %rbp
; CHECK: tileloadd (%rbp,%rcx), %tmm0
; CHECK: popq %rbp
; CHECK: repne{{[ \t]+}}ret
; CHECK: tileloaddt1 %es:(%rbp,%rcx), %tmm1
; CHECK: tileloaddrs %cs:(%rbp,%rcx), %tmm2
; CHECK: tileloaddrst1 %ss:(%rbp,%rcx), %tmm3
; CHECK: tilestored %tmm7, %ds:(%rbp,%rcx)
attributes #0 = { "frame-pointer"="all" "target-features"="+amx-tile,+amx-movrs,+egpr" }

;--- mixed.ll
declare x86_amx @llvm.x86.tileloadd64.internal(i16, i16, ptr, i64)
declare void @llvm.x86.tilestored64.internal(i16, i16, ptr, i64, x86_amx)
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
define void @mixed(ptr %input, ptr %output) {
  %tile = call x86_amx @llvm.x86.tileloadd64.internal(i16 2, i16 16, ptr %input, i64 64)
  call void @llvm.x86.tileloadd64.address(i8 0, i64 0, i64 64, i32 64, i32 256, i32 0)
  call void @llvm.x86.tilestored64.internal(i16 2, i16 16, ptr %output, i64 64, x86_amx %tile)
  ret void
}

;--- forged.ll
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
define internal preserve_allcc void @forged(i64 %p, i64 %stride) #0 {
  call void @llvm.x86.tileloadd64.address(i8 0, i64 %p, i64 %stride, i32 64, i32 256, i32 0)
  ret void
}
attributes #0 = { "x86-amx-stack-memory" "frame-pointer"="none" "stackrealign" }

;--- width.ll
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
define void @bad(i64 %p, i64 %stride) {
  call void @llvm.x86.tileloadd64.address(i8 0, i64 %p, i64 %stride, i32 32, i32 256, i32 0)
  ret void
}

;--- segment.ll
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
define void @bad(i64 %p, i64 %stride) {
  call void @llvm.x86.tileloadd64.address(i8 0, i64 %p, i64 %stride, i32 64, i32 357, i32 0)
  ret void
}
