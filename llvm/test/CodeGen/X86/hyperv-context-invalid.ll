; RUN: not --crash llc -mtriple=x86_64 < %s 2>&1 | FileCheck %s
; CHECK: Hyper-V XMM stride must be 16, 32 or 64
declare void @llvm.x86.hyperv.call(ptr, ptr, ptr, i32 immarg)
define void @bad_stride(ptr %p) {
  call void @llvm.x86.hyperv.call(ptr %p, ptr %p, ptr %p, i32 8)
  ret void
}
