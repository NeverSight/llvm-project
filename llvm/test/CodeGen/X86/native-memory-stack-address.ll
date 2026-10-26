; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs %t/64.ll -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs %t/64.ll -o - | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/64.ll | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/64.ll -o %t/win.o
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs -filetype=obj %t/64.ll -o %t/mac.o
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -stop-after=finalize-isel -verify-machineinstrs %t/64.ll -o - | FileCheck %s --check-prefix=MIR
; RUN: llc -mtriple=i386-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/32.ll -o %t/win32.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -relocation-model=pic -verify-machineinstrs %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: not --crash llc -mtriple=x86_64 %t/width.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=x86_64 %t/fs.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=x86_64 %t/gs.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=x86_64 %t/bits.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=i386 %t/mode.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=x86_64 -mattr=+amx-tile %t/stride.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=STRIDE
; CONTROL: invalid native memory segment prefix or stack-reference control
; STRIDE: native stack address requires an ordinary SIB index

; 0x100 requests a real stack-default operand. Low segment bytes retain their
; independent meaning: an ignored SS prefix alone still has DS fault identity.
; Carrier classes must survive coalescing, register allocation and post-RA copy
; propagation. Dynamic realignment must keep its reserved BX stack base intact.

;--- 64.ll
declare {i32, i8} @llvm.x86.lar.mem32.address(i64, i32 immarg, i32 immarg, i32)
declare void @use(ptr)
declare void @sink(i64)

define {i32, i8} @stack_lar(i64 %p, i32 %prior) {
; CHECK-LABEL: stack_lar:
; CHECK: pushq %rbp
; CHECK: movq %rsp, %rbp
; CHECK: larl (%rbp,%r{{[abcd]}}x),
; CHECK: popq %rbp
; MIR-LABEL: name: stack_lar
; MIR: isFrameAddressTaken: true
; MIR: NATIVE_ADDRESS64
; MIR: LAR32rm $rbp, 1,
  %r = call {i32, i8} @llvm.x86.lar.mem32.address(i64 %p, i32 64, i32 256, i32 %prior)
  ret {i32, i8} %r
}

define {i32, i8} @ss_prefix_data(i64 %p, i32 %prior) {
; CHECK-LABEL: ss_prefix_data:
; CHECK: larl %ss:(%r{{[abcd]}}x),
  %r = call {i32, i8} @llvm.x86.lar.mem32.address(i64 %p, i32 64, i32 54, i32 %prior)
  ret {i32, i8} %r
}

define {i32, i8} @dynamic_stack(i64 %p, i32 %prior, i64 %n) {
; CHECK-LABEL: dynamic_stack:
; CHECK: andq $-64, %rsp
; CHECK: movq %rsp, %rbx
; CHECK: larl (%r{{[acd]}}x),
; CHECK: larl %ds:(%rbp,%r{{[acd]}}x),
; CHECK: callq sink
  %fixed = alloca [16 x i64], align 64
  store volatile i64 305419896, ptr %fixed
  %a = alloca i8, i64 %n, align 32
  call void @use(ptr %a)
  %data = call {i32, i8} @llvm.x86.lar.mem32.address(i64 %p, i32 64, i32 0, i32 %prior)
  %r = call {i32, i8} @llvm.x86.lar.mem32.address(i64 %p, i32 64, i32 318, i32 %prior)
  call void @use(ptr %a)
  %canary = load volatile i64, ptr %fixed
  call void @sink(i64 %canary)
  ret {i32, i8} %r
}

declare void @llvm.x86.ldtilecfg.address(i64, i32, i32, i32)
declare void @llvm.x86.sttilecfg.address(i64, i32, i32, i32)
define void @tile_config(i64 %p) #0 {
; CHECK-LABEL: tile_config:
; CHECK: ldtilecfg (%rbp,%r{{[abcd]}}x)
; CHECK: sttilecfg %es:(%rbp,%r{{[abcd]}}x)
  call void @llvm.x86.ldtilecfg.address(i64 %p, i32 64, i32 256, i32 0)
  call void @llvm.x86.sttilecfg.address(i64 %p, i32 64, i32 294, i32 0)
  ret void
}

declare i8 @llvm.x86.vmwrite.mem.address(i64, i64, i32, i32)
declare i8 @llvm.x86.verr.mem.address(i64, i32, i32)
define void @system_stack(i64 %p, i64 %selector) {
; CHECK-LABEL: system_stack:
; CHECK: vmwriteq %ss:(%rbp,%r{{[abcd]}}x),
; CHECK: verr (%rbp,%r{{[abcd]}}x)
  %vmx = call i8 @llvm.x86.vmwrite.mem.address(i64 %selector, i64 %p, i32 64, i32 310)
  %verify = call i8 @llvm.x86.verr.mem.address(i64 %p, i32 64, i32 256)
  ret void
}

declare void @llvm.x86.avx512.compressstore128.native(ptr, i64, <4 x i32>, i32, i32)
declare <4 x i32> @llvm.x86.avx512.expandload128.native(ptr, i64, <4 x i32>, i32, i32, i32)
define void @compact_stack(ptr %p, <4 x i32> %v) #1 {
; CHECK-LABEL: compact_stack:
; CHECK: vpcompressd {{.*}}(%rbp,%r{{[abcd]}}x)
; CHECK: vpexpandd %cs:(%rbp,%r{{[abcd]}}x)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 0, <4 x i32> %v, i32 2, i32 256)
  %r = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 0, <4 x i32> %v, i32 2, i32 1, i32 302)
  ret void
}

declare <16 x i32> @llvm.x86.avx512.vp4dpwssd.native(ptr, <16 x i32>, <16 x i32>, <16 x i32>, <16 x i32>, <16 x i32>, i16, i32, i32)
define void @four_stack(ptr %p, <16 x i32> %v) #1 {
; CHECK-LABEL: four_stack:
; CHECK: vp4dpwssd (%rbp,%r{{[abcd]}}x), %zmm4,
  %r = call <16 x i32> @llvm.x86.avx512.vp4dpwssd.native(ptr %p, <16 x i32> %v, <16 x i32> %v, <16 x i32> %v, <16 x i32> %v, <16 x i32> %v, i16 0, i32 0, i32 256)
  ret void
}

declare void @llvm.x86.aadd64.legacy.address(i64, i64, i32, i32)
define void @atomic_stack(i64 %p, i64 %v) {
; CHECK-LABEL: atomic_stack:
; CHECK: aaddq {{.*}}(%rbp,%r{{[abcd]}}x)
  call void @llvm.x86.aadd64.legacy.address(i64 %p, i64 %v, i32 64, i32 256)
  ret void
}
attributes #0 = { "target-features"="+amx-tile" }
attributes #1 = { "target-features"="+avx512f,+avx512vl,+evex512" }

;--- 32.ll
declare {i32, i8} @llvm.x86.lar.mem32.address32(i32, i32, i32, i32)
declare void @use(ptr)
declare void @sink(i64)
define {i32, i8} @pic_realign(i32 %p, i32 %prior, i32 %n) {
; X32-LABEL: pic_realign:
; X32: larl %fs:(%{{[sd]}}i),
  %fixed = alloca [16 x i64], align 64
  store volatile i64 305419896, ptr %fixed
  %a = alloca i8, i32 %n, align 32
  call void @use(ptr %a)
  %r = call {i32, i8} @llvm.x86.lar.mem32.address32(i32 %p, i32 16, i32 100, i32 %prior)
  call void @use(ptr %a)
  %canary = load volatile i64, ptr %fixed
  call void @sink(i64 %canary)
  ret {i32, i8} %r
}

;--- width.ll
declare i8 @llvm.x86.verr.mem.address(i64, i32, i32)
define i8 @bad(i64 %p) {
  %r = call i8 @llvm.x86.verr.mem.address(i64 %p, i32 32, i32 256)
  ret i8 %r
}
;--- fs.ll
declare i8 @llvm.x86.verr.mem.address(i64, i32, i32)
define i8 @bad(i64 %p) {
  %r = call i8 @llvm.x86.verr.mem.address(i64 %p, i32 64, i32 356)
  ret i8 %r
}
;--- gs.ll
declare i8 @llvm.x86.verr.mem.address(i64, i32, i32)
define i8 @bad(i64 %p) {
  %r = call i8 @llvm.x86.verr.mem.address(i64 %p, i32 64, i32 357)
  ret i8 %r
}
;--- bits.ll
declare i8 @llvm.x86.verr.mem.address(i64, i32, i32)
define i8 @bad(i64 %p) {
  %r = call i8 @llvm.x86.verr.mem.address(i64 %p, i32 64, i32 512)
  ret i8 %r
}
;--- mode.ll
declare i8 @llvm.x86.verr.mem.address32(i32, i32, i32)
define i8 @bad(i32 %p) {
  %r = call i8 @llvm.x86.verr.mem.address32(i32 %p, i32 32, i32 256)
  ret i8 %r
}
;--- stride.ll
declare void @llvm.x86.tileloadd64.address(i8, i64, i64, i32, i32, i32)
define void @bad(i64 %p, i64 %stride) {
  call void @llvm.x86.tileloadd64.address(i8 0, i64 %p, i64 %stride, i32 64, i32 256, i32 0)
  ret void
}
