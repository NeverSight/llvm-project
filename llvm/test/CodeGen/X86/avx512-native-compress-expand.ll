; RUN: llc -mtriple=x86_64 -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64 -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386 -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=x86_64 -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64 -stop-after=finalize-isel -verify-machineinstrs < %s | FileCheck %s --check-prefix=MIR

; Native memory effects survive zero masks, unused results and repetition.
declare void @llvm.x86.avx512.compressstore128.native(ptr, i64, <4 x i32>, i32 immarg, i32 immarg)
declare <4 x i32> @llvm.x86.avx512.expandload128.native(ptr, i64, <4 x i32>, i32 immarg, i32 immarg, i32 immarg)
declare void @llvm.x86.avx512.compressstore256.native(ptr, i64, <8 x i32>, i32 immarg, i32 immarg)
declare <8 x i32> @llvm.x86.avx512.expandload256.native(ptr, i64, <8 x i32>, i32 immarg, i32 immarg, i32 immarg)
declare void @llvm.x86.avx512.compressstore512.native(ptr, i64, <16 x i32>, i32 immarg, i32 immarg)
declare <16 x i32> @llvm.x86.avx512.expandload512.native(ptr, i64, <16 x i32>, i32 immarg, i32 immarg, i32 immarg)

; CHECK-LABEL: compressstore_b128:
; CHECK-COUNT-2: vpcompressb
; MIR-LABEL: name: compressstore_b128
; MIR-COUNT-2: volatile store
define void @compressstore_b128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 0, i32 100)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 0, <4 x i32> %v, i32 0, i32 100)
  ret void
}

; CHECK-LABEL: expandload_b128:
; CHECK-COUNT-2: vpexpandb
; MIR-LABEL: name: expandload_b128
; MIR-COUNT-2: volatile load
define void @expandload_b128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  %r0 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 %k, <4 x i32> %v, i32 0, i32 0, i32 100)
  %r1 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 0, <4 x i32> %v, i32 0, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_b256:
; CHECK-COUNT-2: vpcompressb
; MIR-LABEL: name: compressstore_b256
; MIR-COUNT-2: volatile store
define void @compressstore_b256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 %k, <8 x i32> %v, i32 0, i32 100)
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 0, <8 x i32> %v, i32 0, i32 100)
  ret void
}

; CHECK-LABEL: expandload_b256:
; CHECK-COUNT-2: vpexpandb
; MIR-LABEL: name: expandload_b256
; MIR-COUNT-2: volatile load
define void @expandload_b256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  %r0 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 %k, <8 x i32> %v, i32 0, i32 0, i32 100)
  %r1 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 0, <8 x i32> %v, i32 0, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_b512:
; CHECK-COUNT-2: vpcompressb
; MIR-LABEL: name: compressstore_b512
; MIR-COUNT-2: volatile store
define void @compressstore_b512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 %k, <16 x i32> %v, i32 0, i32 100)
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 0, <16 x i32> %v, i32 0, i32 100)
  ret void
}

; CHECK-LABEL: expandload_b512:
; CHECK-COUNT-2: vpexpandb
; MIR-LABEL: name: expandload_b512
; MIR-COUNT-2: volatile load
define void @expandload_b512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  %r0 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 %k, <16 x i32> %v, i32 0, i32 0, i32 100)
  %r1 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 0, <16 x i32> %v, i32 0, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_w128:
; CHECK-COUNT-2: vpcompressw
; MIR-LABEL: name: compressstore_w128
; MIR-COUNT-2: volatile store
define void @compressstore_w128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 1, i32 100)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 0, <4 x i32> %v, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: expandload_w128:
; CHECK-COUNT-2: vpexpandw
; MIR-LABEL: name: expandload_w128
; MIR-COUNT-2: volatile load
define void @expandload_w128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  %r0 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 %k, <4 x i32> %v, i32 1, i32 0, i32 100)
  %r1 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 0, <4 x i32> %v, i32 1, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_w256:
; CHECK-COUNT-2: vpcompressw
; MIR-LABEL: name: compressstore_w256
; MIR-COUNT-2: volatile store
define void @compressstore_w256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 %k, <8 x i32> %v, i32 1, i32 100)
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 0, <8 x i32> %v, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: expandload_w256:
; CHECK-COUNT-2: vpexpandw
; MIR-LABEL: name: expandload_w256
; MIR-COUNT-2: volatile load
define void @expandload_w256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  %r0 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 %k, <8 x i32> %v, i32 1, i32 0, i32 100)
  %r1 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 0, <8 x i32> %v, i32 1, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_w512:
; CHECK-COUNT-2: vpcompressw
; MIR-LABEL: name: compressstore_w512
; MIR-COUNT-2: volatile store
define void @compressstore_w512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 %k, <16 x i32> %v, i32 1, i32 100)
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 0, <16 x i32> %v, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: expandload_w512:
; CHECK-COUNT-2: vpexpandw
; MIR-LABEL: name: expandload_w512
; MIR-COUNT-2: volatile load
define void @expandload_w512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  %r0 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 %k, <16 x i32> %v, i32 1, i32 0, i32 100)
  %r1 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 0, <16 x i32> %v, i32 1, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_d128:
; CHECK-COUNT-2: vpcompressd
; MIR-LABEL: name: compressstore_d128
; MIR-COUNT-2: volatile store
define void @compressstore_d128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 100)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 0, <4 x i32> %v, i32 2, i32 100)
  ret void
}

; CHECK-LABEL: expandload_d128:
; CHECK-COUNT-2: vpexpandd
; MIR-LABEL: name: expandload_d128
; MIR-COUNT-2: volatile load
define void @expandload_d128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  %r0 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 0, i32 100)
  %r1 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 0, <4 x i32> %v, i32 2, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_d256:
; CHECK-COUNT-2: vpcompressd
; MIR-LABEL: name: compressstore_d256
; MIR-COUNT-2: volatile store
define void @compressstore_d256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 %k, <8 x i32> %v, i32 2, i32 100)
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 0, <8 x i32> %v, i32 2, i32 100)
  ret void
}

; CHECK-LABEL: expandload_d256:
; CHECK-COUNT-2: vpexpandd
; MIR-LABEL: name: expandload_d256
; MIR-COUNT-2: volatile load
define void @expandload_d256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  %r0 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 %k, <8 x i32> %v, i32 2, i32 0, i32 100)
  %r1 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 0, <8 x i32> %v, i32 2, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_d512:
; CHECK-COUNT-2: vpcompressd
; MIR-LABEL: name: compressstore_d512
; MIR-COUNT-2: volatile store
define void @compressstore_d512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 %k, <16 x i32> %v, i32 2, i32 100)
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 0, <16 x i32> %v, i32 2, i32 100)
  ret void
}

; CHECK-LABEL: expandload_d512:
; CHECK-COUNT-2: vpexpandd
; MIR-LABEL: name: expandload_d512
; MIR-COUNT-2: volatile load
define void @expandload_d512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  %r0 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 %k, <16 x i32> %v, i32 2, i32 0, i32 100)
  %r1 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 0, <16 x i32> %v, i32 2, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_q128:
; CHECK-COUNT-2: vpcompressq
; MIR-LABEL: name: compressstore_q128
; MIR-COUNT-2: volatile store
define void @compressstore_q128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 3, i32 100)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 0, <4 x i32> %v, i32 3, i32 100)
  ret void
}

; CHECK-LABEL: expandload_q128:
; CHECK-COUNT-2: vpexpandq
; MIR-LABEL: name: expandload_q128
; MIR-COUNT-2: volatile load
define void @expandload_q128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  %r0 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 %k, <4 x i32> %v, i32 3, i32 0, i32 100)
  %r1 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 0, <4 x i32> %v, i32 3, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_q256:
; CHECK-COUNT-2: vpcompressq
; MIR-LABEL: name: compressstore_q256
; MIR-COUNT-2: volatile store
define void @compressstore_q256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 %k, <8 x i32> %v, i32 3, i32 100)
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 0, <8 x i32> %v, i32 3, i32 100)
  ret void
}

; CHECK-LABEL: expandload_q256:
; CHECK-COUNT-2: vpexpandq
; MIR-LABEL: name: expandload_q256
; MIR-COUNT-2: volatile load
define void @expandload_q256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  %r0 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 %k, <8 x i32> %v, i32 3, i32 0, i32 100)
  %r1 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 0, <8 x i32> %v, i32 3, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_q512:
; CHECK-COUNT-2: vpcompressq
; MIR-LABEL: name: compressstore_q512
; MIR-COUNT-2: volatile store
define void @compressstore_q512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 %k, <16 x i32> %v, i32 3, i32 100)
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 0, <16 x i32> %v, i32 3, i32 100)
  ret void
}

; CHECK-LABEL: expandload_q512:
; CHECK-COUNT-2: vpexpandq
; MIR-LABEL: name: expandload_q512
; MIR-COUNT-2: volatile load
define void @expandload_q512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  %r0 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 %k, <16 x i32> %v, i32 3, i32 0, i32 100)
  %r1 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 0, <16 x i32> %v, i32 3, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_ps128:
; CHECK-COUNT-2: vcompressps
; MIR-LABEL: name: compressstore_ps128
; MIR-COUNT-2: volatile store
define void @compressstore_ps128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 4, i32 100)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 0, <4 x i32> %v, i32 4, i32 100)
  ret void
}

; CHECK-LABEL: expandload_ps128:
; CHECK-COUNT-2: vexpandps
; MIR-LABEL: name: expandload_ps128
; MIR-COUNT-2: volatile load
define void @expandload_ps128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  %r0 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 %k, <4 x i32> %v, i32 4, i32 0, i32 100)
  %r1 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 0, <4 x i32> %v, i32 4, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_ps256:
; CHECK-COUNT-2: vcompressps
; MIR-LABEL: name: compressstore_ps256
; MIR-COUNT-2: volatile store
define void @compressstore_ps256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 %k, <8 x i32> %v, i32 4, i32 100)
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 0, <8 x i32> %v, i32 4, i32 100)
  ret void
}

; CHECK-LABEL: expandload_ps256:
; CHECK-COUNT-2: vexpandps
; MIR-LABEL: name: expandload_ps256
; MIR-COUNT-2: volatile load
define void @expandload_ps256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  %r0 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 %k, <8 x i32> %v, i32 4, i32 0, i32 100)
  %r1 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 0, <8 x i32> %v, i32 4, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_ps512:
; CHECK-COUNT-2: vcompressps
; MIR-LABEL: name: compressstore_ps512
; MIR-COUNT-2: volatile store
define void @compressstore_ps512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 %k, <16 x i32> %v, i32 4, i32 100)
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 0, <16 x i32> %v, i32 4, i32 100)
  ret void
}

; CHECK-LABEL: expandload_ps512:
; CHECK-COUNT-2: vexpandps
; MIR-LABEL: name: expandload_ps512
; MIR-COUNT-2: volatile load
define void @expandload_ps512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  %r0 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 %k, <16 x i32> %v, i32 4, i32 0, i32 100)
  %r1 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 0, <16 x i32> %v, i32 4, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_pd128:
; CHECK-COUNT-2: vcompresspd
; MIR-LABEL: name: compressstore_pd128
; MIR-COUNT-2: volatile store
define void @compressstore_pd128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 5, i32 100)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 0, <4 x i32> %v, i32 5, i32 100)
  ret void
}

; CHECK-LABEL: expandload_pd128:
; CHECK-COUNT-2: vexpandpd
; MIR-LABEL: name: expandload_pd128
; MIR-COUNT-2: volatile load
define void @expandload_pd128(ptr %p, i64 %k, <4 x i32> %v) #0 {
  %r0 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 %k, <4 x i32> %v, i32 5, i32 0, i32 100)
  %r1 = call <4 x i32> @llvm.x86.avx512.expandload128.native(ptr %p, i64 0, <4 x i32> %v, i32 5, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_pd256:
; CHECK-COUNT-2: vcompresspd
; MIR-LABEL: name: compressstore_pd256
; MIR-COUNT-2: volatile store
define void @compressstore_pd256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 %k, <8 x i32> %v, i32 5, i32 100)
  call void @llvm.x86.avx512.compressstore256.native(ptr %p, i64 0, <8 x i32> %v, i32 5, i32 100)
  ret void
}

; CHECK-LABEL: expandload_pd256:
; CHECK-COUNT-2: vexpandpd
; MIR-LABEL: name: expandload_pd256
; MIR-COUNT-2: volatile load
define void @expandload_pd256(ptr %p, i64 %k, <8 x i32> %v) #0 {
  %r0 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 %k, <8 x i32> %v, i32 5, i32 0, i32 100)
  %r1 = call <8 x i32> @llvm.x86.avx512.expandload256.native(ptr %p, i64 0, <8 x i32> %v, i32 5, i32 1, i32 100)
  ret void
}

; CHECK-LABEL: compressstore_pd512:
; CHECK-COUNT-2: vcompresspd
; MIR-LABEL: name: compressstore_pd512
; MIR-COUNT-2: volatile store
define void @compressstore_pd512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 %k, <16 x i32> %v, i32 5, i32 100)
  call void @llvm.x86.avx512.compressstore512.native(ptr %p, i64 0, <16 x i32> %v, i32 5, i32 100)
  ret void
}

; CHECK-LABEL: expandload_pd512:
; CHECK-COUNT-2: vexpandpd
; MIR-LABEL: name: expandload_pd512
; MIR-COUNT-2: volatile load
define void @expandload_pd512(ptr %p, i64 %k, <16 x i32> %v) #0 {
  %r0 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 %k, <16 x i32> %v, i32 5, i32 0, i32 100)
  %r1 = call <16 x i32> @llvm.x86.avx512.expandload512.native(ptr %p, i64 0, <16 x i32> %v, i32 5, i32 1, i32 100)
  ret void
}

attributes #0 = { "target-features"="+avx512f,+avx512vl,+avx512bw,+avx512vbmi2,+evex512" }

; CHECK-LABEL: segment_prefixes:
; CHECK: vpcompressd
; CHECK: vpcompressd{{.*}}%es:(%{{[er][abcd]}}x)
; CHECK: vpcompressd{{.*}}%cs:(%{{[er][abcd]}}x)
; CHECK: vpcompressd{{.*}}%ss:(%{{[er][abcd]}}x)
; CHECK: vpcompressd{{.*}}%ds:(%{{[er][abcd]}}x)
; CHECK: vpcompressd{{.*}}%fs:(%{{[er][abcd]}}x)
; CHECK: vpcompressd{{.*}}%gs:(%{{[er][abcd]}}x)
define void @segment_prefixes(ptr %p, i64 %k, <4 x i32> %v) #0 {
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 0)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 38)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 46)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 54)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 62)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 100)
  call void @llvm.x86.avx512.compressstore128.native(ptr %p, i64 %k, <4 x i32> %v, i32 2, i32 101)
  ret void
}
