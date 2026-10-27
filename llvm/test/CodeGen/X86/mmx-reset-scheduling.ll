; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes='default<O2>' < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s

; Physical clobbers alone cannot order virtual MMX registers before allocation.
; The final reset must follow even the MMX-to-integer copy: a late reload would
; recreate nonempty tags, although the returned integer could still be correct.

define i64 @finish_emms(i64 %a, i64 %b, ptr %memory) #0 {
; CHECK-LABEL: finish_emms:
; CHECK: paddb
; CHECK: femms
; CHECK: pxor
; CHECK: emms
; CHECK-NOT: %mm
; CHECK: ret
  %first = alloca i64, align 64
  %last = alloca i64, align 8
  %count = and i64 %a, 255
  %size = add i64 %count, 65
  %dynamic = alloca i8, i64 %size, align 16
  store volatile i64 1311768467463790320, ptr %first, align 64
  store volatile i64 -81985529216486896, ptr %last, align 8
  store volatile i8 -91, ptr %dynamic
  store i64 %a, ptr %memory, align 8
  %left = bitcast i64 %a to <1 x i64>
  %right = bitcast i64 %b to <1 x i64>
  %sum = call <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64> %left, <1 x i64> %right)
  call void @llvm.x86.mmx.femms()
  %mixed = call <1 x i64> @llvm.x86.mmx.pxor(<1 x i64> %sum, <1 x i64> %left)
  %bits = bitcast <1 x i64> %mixed to i64
  call void @llvm.x86.mmx.emms()
  %f = load volatile i64, ptr %first, align 64
  %l = load volatile i64, ptr %last, align 8
  %d = load volatile i8, ptr %dynamic
  %extended = zext i8 %d to i64
  %x = xor i64 %bits, %f
  %y = xor i64 %x, %l
  %result = xor i64 %y, %extended
  ret i64 %result
}

define i64 @finish_femms(i64 %a, i64 %b, ptr %memory) #0 {
; CHECK-LABEL: finish_femms:
; CHECK: paddb
; CHECK: femms
; CHECK: pxor
; CHECK: femms
; CHECK-NOT: %mm
; CHECK: ret
  %first = alloca i64, align 64
  %last = alloca i64, align 8
  %count = and i64 %a, 255
  %size = add i64 %count, 65
  %dynamic = alloca i8, i64 %size, align 16
  store volatile i64 1311768467463790320, ptr %first, align 64
  store volatile i64 -81985529216486896, ptr %last, align 8
  store volatile i8 -91, ptr %dynamic
  store i64 %a, ptr %memory, align 8
  %left = bitcast i64 %a to <1 x i64>
  %right = bitcast i64 %b to <1 x i64>
  %sum = call <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64> %left, <1 x i64> %right)
  call void @llvm.x86.mmx.femms()
  %mixed = call <1 x i64> @llvm.x86.mmx.pxor(<1 x i64> %sum, <1 x i64> %left)
  %bits = bitcast <1 x i64> %mixed to i64
  call void @llvm.x86.mmx.femms()
  %f = load volatile i64, ptr %first, align 64
  %l = load volatile i64, ptr %last, align 8
  %d = load volatile i8, ptr %dynamic
  %extended = zext i8 %d to i64
  %x = xor i64 %bits, %f
  %y = xor i64 %x, %l
  %result = xor i64 %y, %extended
  ret i64 %result
}

declare void @llvm.x86.mmx.femms()
declare void @llvm.x86.mmx.emms()
declare <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64>, <1 x i64>)
declare <1 x i64> @llvm.x86.mmx.pxor(<1 x i64>, <1 x i64>)
attributes #0 = { noinline nounwind "min-legal-vector-width"="64" "target-cpu"="x86-64" "target-features"="+3dnow,+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
