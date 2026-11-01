; RUN: not --crash llc -mtriple=x86_64 < %s 2>&1 | FileCheck %s
; CHECK: invalid SNP address/segment control
; RMPUPDATE ignores address-size override, so this API only permits it for
; PVALIDATE; an unsupported control must not silently change instruction meaning.
declare void @llvm.x86.rmpupdate.context(ptr, ptr, i32 immarg)
define void @bad_width(ptr %g, ptr %f) {
  call void @llvm.x86.rmpupdate.context(ptr %g, ptr %f, i32 1)
  ret void
}
