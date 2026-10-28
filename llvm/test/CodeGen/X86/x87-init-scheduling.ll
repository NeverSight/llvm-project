; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes='default<O2>' < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s

; Volatile input must be read before FNINIT, but its compiler-owned value must
; survive the emptied x87 bank. A native instruction without pseudo FP clobbers
; leaves it on the now-empty physical stack.
define x86_fp80 @live_x87(ptr %in, ptr %other) {
; CHECK-LABEL: live_x87:
; CHECK: fldt
; CHECK: fstpt
; CHECK: fninit
; CHECK: fldt
; CHECK: fadd
; CHECK: ret
  %a = load volatile x86_fp80, ptr %in, align 1
  call void @llvm.x86.fninit()
  %b = load volatile x86_fp80, ptr %other, align 1
  %r = fadd x86_fp80 %a, %b
  ret x86_fp80 %r
}

define i64 @live_mmx(i64 %a, i64 %b) #0 {
; CHECK-LABEL: live_mmx:
; CHECK: paddb
; CHECK: movq %mm{{[0-7]}},
; CHECK: fninit
; CHECK: movq {{.*}}, %mm{{[0-7]}}
; CHECK: pxor
; CHECK: fninit
; CHECK-NOT: %mm
; CHECK: ret
  %x = bitcast i64 %a to <1 x i64>
  %y = bitcast i64 %b to <1 x i64>
  %sum = call <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64> %x, <1 x i64> %y)
  call void @llvm.x86.fninit()
  %mixed = call <1 x i64> @llvm.x86.mmx.pxor(<1 x i64> %sum, <1 x i64> %x)
  %bits = bitcast <1 x i64> %mixed to i64
  call void @llvm.x86.fninit()
  ret i64 %bits
}

declare void @llvm.x86.fninit()
declare <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64>, <1 x i64>)
declare <1 x i64> @llvm.x86.mmx.pxor(<1 x i64>, <1 x i64>)
attributes #0 = { "target-features"="+mmx" }
