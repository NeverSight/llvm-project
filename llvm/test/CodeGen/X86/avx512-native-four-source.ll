; RUN: llc -mtriple=x86_64 -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64 -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386 -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=x86_64 -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64 -stop-after=finalize-isel -verify-machineinstrs < %s | FileCheck %s --check-prefix=MIR

; Each source is independently live. The implicit physical uses must retain
; members 5..7 when scheduling the copies into the aligned four-register block.
; Zero masks and unused results still execute the native instruction.

declare <16 x i32> @llvm.x86.avx512.v4fmaddps.native(ptr, <16 x i32>, <16 x i32>, <16 x i32>, <16 x i32>, <16 x i32>, i16, i32 immarg, i32 immarg)

; CHECK-LABEL: four_v4fmaddps:
; CHECK-COUNT-3: v4fmaddps
; MIR-LABEL: name: four_v4fmaddps
; MIR: V4FMADDPSrmk {{.*}}implicit $zmm5, implicit $zmm6, implicit $zmm7{{.*}}volatile load
define <16 x i32> @four_v4fmaddps(ptr %p, i16 %k, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3) #0 {
  %r0 = call <16 x i32> @llvm.x86.avx512.v4fmaddps.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 %k, i32 0, i32 100)
  %r1 = call <16 x i32> @llvm.x86.avx512.v4fmaddps.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 0, i32 1, i32 100)
  %r2 = call <16 x i32> @llvm.x86.avx512.v4fmaddps.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 -1, i32 0, i32 100)
  ret <16 x i32> %r0
}

declare <16 x i32> @llvm.x86.avx512.v4fnmaddps.native(ptr, <16 x i32>, <16 x i32>, <16 x i32>, <16 x i32>, <16 x i32>, i16, i32 immarg, i32 immarg)

; CHECK-LABEL: four_v4fnmaddps:
; CHECK-COUNT-3: v4fnmaddps
; MIR-LABEL: name: four_v4fnmaddps
; MIR: V4FNMADDPSrmk {{.*}}implicit $zmm5, implicit $zmm6, implicit $zmm7{{.*}}volatile load
define <16 x i32> @four_v4fnmaddps(ptr %p, i16 %k, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3) #0 {
  %r0 = call <16 x i32> @llvm.x86.avx512.v4fnmaddps.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 %k, i32 0, i32 100)
  %r1 = call <16 x i32> @llvm.x86.avx512.v4fnmaddps.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 0, i32 1, i32 100)
  %r2 = call <16 x i32> @llvm.x86.avx512.v4fnmaddps.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 -1, i32 0, i32 100)
  ret <16 x i32> %r0
}

declare <4 x i32> @llvm.x86.avx512.v4fmaddss.native(ptr, <4 x i32>, <4 x i32>, <4 x i32>, <4 x i32>, <4 x i32>, i16, i32 immarg, i32 immarg)

; CHECK-LABEL: four_v4fmaddss:
; CHECK-COUNT-3: v4fmaddss
; MIR-LABEL: name: four_v4fmaddss
; MIR: V4FMADDSSrmk {{.*}}implicit $xmm5, implicit $xmm6, implicit $xmm7{{.*}}volatile load
define <4 x i32> @four_v4fmaddss(ptr %p, i16 %k, <4 x i32> %a, <4 x i32> %s0, <4 x i32> %s1, <4 x i32> %s2, <4 x i32> %s3) #0 {
  %r0 = call <4 x i32> @llvm.x86.avx512.v4fmaddss.native(ptr %p, <4 x i32> %a, <4 x i32> %s0, <4 x i32> %s1, <4 x i32> %s2, <4 x i32> %s3, i16 %k, i32 0, i32 100)
  %r1 = call <4 x i32> @llvm.x86.avx512.v4fmaddss.native(ptr %p, <4 x i32> %a, <4 x i32> %s0, <4 x i32> %s1, <4 x i32> %s2, <4 x i32> %s3, i16 0, i32 1, i32 100)
  %r2 = call <4 x i32> @llvm.x86.avx512.v4fmaddss.native(ptr %p, <4 x i32> %a, <4 x i32> %s0, <4 x i32> %s1, <4 x i32> %s2, <4 x i32> %s3, i16 -1, i32 0, i32 100)
  ret <4 x i32> %r0
}

declare <4 x i32> @llvm.x86.avx512.v4fnmaddss.native(ptr, <4 x i32>, <4 x i32>, <4 x i32>, <4 x i32>, <4 x i32>, i16, i32 immarg, i32 immarg)

; CHECK-LABEL: four_v4fnmaddss:
; CHECK-COUNT-3: v4fnmaddss
; MIR-LABEL: name: four_v4fnmaddss
; MIR: V4FNMADDSSrmk {{.*}}implicit $xmm5, implicit $xmm6, implicit $xmm7{{.*}}volatile load
define <4 x i32> @four_v4fnmaddss(ptr %p, i16 %k, <4 x i32> %a, <4 x i32> %s0, <4 x i32> %s1, <4 x i32> %s2, <4 x i32> %s3) #0 {
  %r0 = call <4 x i32> @llvm.x86.avx512.v4fnmaddss.native(ptr %p, <4 x i32> %a, <4 x i32> %s0, <4 x i32> %s1, <4 x i32> %s2, <4 x i32> %s3, i16 %k, i32 0, i32 100)
  %r1 = call <4 x i32> @llvm.x86.avx512.v4fnmaddss.native(ptr %p, <4 x i32> %a, <4 x i32> %s0, <4 x i32> %s1, <4 x i32> %s2, <4 x i32> %s3, i16 0, i32 1, i32 100)
  %r2 = call <4 x i32> @llvm.x86.avx512.v4fnmaddss.native(ptr %p, <4 x i32> %a, <4 x i32> %s0, <4 x i32> %s1, <4 x i32> %s2, <4 x i32> %s3, i16 -1, i32 0, i32 100)
  ret <4 x i32> %r0
}

declare <16 x i32> @llvm.x86.avx512.vp4dpwssd.native(ptr, <16 x i32>, <16 x i32>, <16 x i32>, <16 x i32>, <16 x i32>, i16, i32 immarg, i32 immarg)

; CHECK-LABEL: four_vp4dpwssd:
; CHECK-COUNT-3: vp4dpwssd
; MIR-LABEL: name: four_vp4dpwssd
; MIR: VP4DPWSSDrmk {{.*}}implicit $zmm5, implicit $zmm6, implicit $zmm7{{.*}}volatile load
define <16 x i32> @four_vp4dpwssd(ptr %p, i16 %k, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3) #0 {
  %r0 = call <16 x i32> @llvm.x86.avx512.vp4dpwssd.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 %k, i32 0, i32 100)
  %r1 = call <16 x i32> @llvm.x86.avx512.vp4dpwssd.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 0, i32 1, i32 100)
  %r2 = call <16 x i32> @llvm.x86.avx512.vp4dpwssd.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 -1, i32 0, i32 100)
  ret <16 x i32> %r0
}

declare <16 x i32> @llvm.x86.avx512.vp4dpwssds.native(ptr, <16 x i32>, <16 x i32>, <16 x i32>, <16 x i32>, <16 x i32>, i16, i32 immarg, i32 immarg)

; CHECK-LABEL: four_vp4dpwssds:
; CHECK-COUNT-3: vp4dpwssds
; MIR-LABEL: name: four_vp4dpwssds
; MIR: VP4DPWSSDSrmk {{.*}}implicit $zmm5, implicit $zmm6, implicit $zmm7{{.*}}volatile load
define <16 x i32> @four_vp4dpwssds(ptr %p, i16 %k, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3) #0 {
  %r0 = call <16 x i32> @llvm.x86.avx512.vp4dpwssds.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 %k, i32 0, i32 100)
  %r1 = call <16 x i32> @llvm.x86.avx512.vp4dpwssds.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 0, i32 1, i32 100)
  %r2 = call <16 x i32> @llvm.x86.avx512.vp4dpwssds.native(ptr %p, <16 x i32> %a, <16 x i32> %s0, <16 x i32> %s1, <16 x i32> %s2, <16 x i32> %s3, i16 -1, i32 0, i32 100)
  ret <16 x i32> %r0
}

attributes #0 = { "target-features"="+avx512f,+evex512" }
