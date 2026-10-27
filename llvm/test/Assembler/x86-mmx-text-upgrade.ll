; RUN: opt -S -passes=verify < %s | FileCheck %s --implicit-check-not=x86_mmx

; Textual input upgrades to the same representation as TYPE_CODE_X86_MMX
; bitcode records. Intrinsic calls, bitcasts and aggregate fields agree.
; CHECK: %legacy = type { <1 x i64>, i8 }
%legacy = type { x86_mmx, i8 }
@record = external global %legacy

; CHECK-LABEL: define i64 @add(i64 %a, i64 %b)
; CHECK: %left = bitcast i64 %a to <1 x i64>
; CHECK: %right = bitcast i64 %b to <1 x i64>
; CHECK: %sum = call <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64> %left, <1 x i64> %right)
; CHECK: %result = bitcast <1 x i64> %sum to i64
define i64 @add(i64 %a, i64 %b) {
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %sum = call x86_mmx @llvm.x86.mmx.padd.b(x86_mmx %left, x86_mmx %right)
  %result = bitcast x86_mmx %sum to i64
  ret i64 %result
}

declare x86_mmx @llvm.x86.mmx.padd.b(x86_mmx, x86_mmx)
