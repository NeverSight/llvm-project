; RUN: llc < %s -mtriple=aarch64 -mattr=+fullfp16 | FileCheck %s

; These intrinsics preserve the scalar GPR <-> FP16 fixed-point forms.  The
; existing AdvSIMD conversion intrinsics use an FP/SIMD source or destination
; register and therefore cannot represent these instructions.

define half @scvtf_w(i32 %value) {
; CHECK-LABEL: scvtf_w:
; CHECK:       scvtf h0, w0, #16
  %result = call half @llvm.aarch64.neverd.scvtf.fixed.i32(i32 %value, i32 16)
  ret half %result
}

define half @scvtf_x(i64 %value) {
; CHECK-LABEL: scvtf_x:
; CHECK:       scvtf h0, x0, #64
  %result = call half @llvm.aarch64.neverd.scvtf.fixed.i64(i64 %value, i32 64)
  ret half %result
}

define half @ucvtf_w(i32 %value) {
; CHECK-LABEL: ucvtf_w:
; CHECK:       ucvtf h0, w0, #16
  %result = call half @llvm.aarch64.neverd.ucvtf.fixed.i32(i32 %value, i32 16)
  ret half %result
}

define half @ucvtf_x(i64 %value) {
; CHECK-LABEL: ucvtf_x:
; CHECK:       ucvtf h0, x0, #64
  %result = call half @llvm.aarch64.neverd.ucvtf.fixed.i64(i64 %value, i32 64)
  ret half %result
}

define i32 @fcvtzs_w(half %value) {
; CHECK-LABEL: fcvtzs_w:
; CHECK:       fcvtzs w0, h0, #16
  %result = call i32 @llvm.aarch64.neverd.fcvtzs.fixed.i32(half %value, i32 16)
  ret i32 %result
}

define i64 @fcvtzs_x(half %value) {
; CHECK-LABEL: fcvtzs_x:
; CHECK:       fcvtzs x0, h0, #64
  %result = call i64 @llvm.aarch64.neverd.fcvtzs.fixed.i64(half %value, i32 64)
  ret i64 %result
}

define i32 @fcvtzu_w(half %value) {
; CHECK-LABEL: fcvtzu_w:
; CHECK:       fcvtzu w0, h0, #16
  %result = call i32 @llvm.aarch64.neverd.fcvtzu.fixed.i32(half %value, i32 16)
  ret i32 %result
}

define i64 @fcvtzu_x(half %value) {
; CHECK-LABEL: fcvtzu_x:
; CHECK:       fcvtzu x0, h0, #64
  %result = call i64 @llvm.aarch64.neverd.fcvtzu.fixed.i64(half %value, i32 64)
  ret i64 %result
}

define void @scvtf_updates_fpsr(i32 %value) {
; CHECK-LABEL: scvtf_updates_fpsr:
; CHECK:       scvtf {{h[0-9]+}}, w0, #16
; CHECK-NEXT:  ret
  %unused = call half @llvm.aarch64.neverd.scvtf.fixed.i32(i32 %value, i32 16)
  ret void
}

declare half @llvm.aarch64.neverd.scvtf.fixed.i32(i32, i32 immarg)
declare half @llvm.aarch64.neverd.scvtf.fixed.i64(i64, i32 immarg)
declare half @llvm.aarch64.neverd.ucvtf.fixed.i32(i32, i32 immarg)
declare half @llvm.aarch64.neverd.ucvtf.fixed.i64(i64, i32 immarg)
declare i32 @llvm.aarch64.neverd.fcvtzs.fixed.i32(half, i32 immarg)
declare i64 @llvm.aarch64.neverd.fcvtzs.fixed.i64(half, i32 immarg)
declare i32 @llvm.aarch64.neverd.fcvtzu.fixed.i32(half, i32 immarg)
declare i64 @llvm.aarch64.neverd.fcvtzu.fixed.i64(half, i32 immarg)
