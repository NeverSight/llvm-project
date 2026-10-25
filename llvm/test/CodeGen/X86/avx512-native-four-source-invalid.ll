; RUN: split-file %s %t
; RUN: not --crash llc -mtriple=x86_64 < %t/zero.ll 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=x86_64 < %t/segment.ll 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=x86_64 < %t/features.ll 2>&1 | FileCheck %s --check-prefix=FEATURE
; CONTROL: invalid native four-source controls
; FEATURE: native four-source instructions require AVX-512 carriers

;--- zero.ll
declare <4 x i32> @llvm.x86.avx512.v4fmaddss.native(ptr, <4 x i32>, <4 x i32>, <4 x i32>, <4 x i32>, <4 x i32>, i16, i32 immarg, i32 immarg)
define <4 x i32> @bad(ptr %p, <4 x i32> %a) #0 {
  %r = call <4 x i32> @llvm.x86.avx512.v4fmaddss.native(ptr %p, <4 x i32> %a, <4 x i32> %a, <4 x i32> %a, <4 x i32> %a, <4 x i32> %a, i16 1, i32 2, i32 0)
  ret <4 x i32> %r
}
attributes #0 = { "target-features"="+avx512f" }

;--- segment.ll
declare <4 x i32> @llvm.x86.avx512.v4fmaddss.native(ptr, <4 x i32>, <4 x i32>, <4 x i32>, <4 x i32>, <4 x i32>, i16, i32 immarg, i32 immarg)
define <4 x i32> @bad(ptr %p, <4 x i32> %a) #0 {
  %r = call <4 x i32> @llvm.x86.avx512.v4fmaddss.native(ptr %p, <4 x i32> %a, <4 x i32> %a, <4 x i32> %a, <4 x i32> %a, <4 x i32> %a, i16 1, i32 0, i32 1)
  ret <4 x i32> %r
}
attributes #0 = { "target-features"="+avx512f" }

;--- features.ll
declare <4 x i32> @llvm.x86.avx512.v4fmaddss.native(ptr, <4 x i32>, <4 x i32>, <4 x i32>, <4 x i32>, <4 x i32>, i16, i32 immarg, i32 immarg)
define <4 x i32> @bad(ptr %p, <4 x i32> %a) #0 {
  %r = call <4 x i32> @llvm.x86.avx512.v4fmaddss.native(ptr %p, <4 x i32> %a, <4 x i32> %a, <4 x i32> %a, <4 x i32> %a, <4 x i32> %a, i16 1, i32 0, i32 0)
  ret <4 x i32> %r
}
attributes #0 = { "target-features"="+sse2" }
