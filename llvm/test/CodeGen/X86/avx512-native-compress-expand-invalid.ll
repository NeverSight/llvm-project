; RUN: split-file %s %t
; RUN: not --crash llc -mtriple=x86_64 -verify-machineinstrs < %t/kind.ll 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=x86_64 < %t/zero.ll 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=x86_64 < %t/segment.ll 2>&1 | FileCheck %s --check-prefix=CONTROL
; RUN: not --crash llc -mtriple=x86_64 < %t/features.ll 2>&1 | FileCheck %s --check-prefix=FEATURE
; CONTROL: invalid native compress/expand controls
; FEATURE: native compress/expand requires its AVX-512 features

;--- kind.ll
declare <4 x i32> @llvm.x86.avx512.expandload128.native(ptr,i64,<4 x i32>,i32 immarg,i32 immarg,i32 immarg)
define <4 x i32> @f(ptr %p, i64 %k, <4 x i32> %v) #0 {
  %r = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 %k, <4 x i32> %v, i32 6, i32 0, i32 0)
  ret <4 x i32> %r
}
attributes #0 = { "target-features"="+avx512f,+avx512vl" }

;--- zero.ll
declare <4 x i32> @llvm.x86.avx512.expandload128.native(ptr,i64,<4 x i32>,i32 immarg,i32 immarg,i32 immarg)
define <4 x i32> @f(ptr %p, i64 %k, <4 x i32> %v) #0 {
  %r = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 2, i32 0)
  ret <4 x i32> %r
}
attributes #0 = { "target-features"="+avx512f,+avx512vl" }

;--- segment.ll
declare <4 x i32> @llvm.x86.avx512.expandload128.native(ptr,i64,<4 x i32>,i32 immarg,i32 immarg,i32 immarg)
define <4 x i32> @f(ptr %p, i64 %k, <4 x i32> %v) #0 {
  %r = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 0, i32 1)
  ret <4 x i32> %r
}
attributes #0 = { "target-features"="+avx512f,+avx512vl" }

;--- features.ll
declare <4 x i32> @llvm.x86.avx512.expandload128.native(ptr,i64,<4 x i32>,i32 immarg,i32 immarg,i32 immarg)
define <4 x i32> @f(ptr %p, i64 %k, <4 x i32> %v) #0 {
  %r = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 %k, <4 x i32> %v, i32 0, i32 0, i32 0)
  ret <4 x i32> %r
}
attributes #0 = { "target-features"="+avx512f,+avx512vl" }
