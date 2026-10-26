; RUN: llc -mtriple=i386-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: not --crash llc -mtriple=x86_64-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: legacy RAO address32 requires 32-bit mode
declare void @llvm.x86.aadd32.legacy.address32(i32, i32, i32 immarg, i32 immarg)
; CHECK-LABEL: aadd:
; CHECK: aaddl{{.*}}%ds:(%e{{[abcd]}}x)
; CHECK: aaddl{{.*}}%fs:(%{{[sd]}}i)
define void @aadd(i32 %address, i32 %value) {
  call void @llvm.x86.aadd32.legacy.address32(i32 %address, i32 %value, i32 32, i32 62)
  call void @llvm.x86.aadd32.legacy.address32(i32 %address, i32 %value, i32 16, i32 100)
  ret void
}
declare void @llvm.x86.aand32.legacy.address32(i32, i32, i32 immarg, i32 immarg)
; CHECK-LABEL: aand:
; CHECK: aandl{{.*}}%ds:(%e{{[abcd]}}x)
; CHECK: aandl{{.*}}%fs:(%{{[sd]}}i)
define void @aand(i32 %address, i32 %value) {
  call void @llvm.x86.aand32.legacy.address32(i32 %address, i32 %value, i32 32, i32 62)
  call void @llvm.x86.aand32.legacy.address32(i32 %address, i32 %value, i32 16, i32 100)
  ret void
}
declare void @llvm.x86.aor32.legacy.address32(i32, i32, i32 immarg, i32 immarg)
; CHECK-LABEL: aor:
; CHECK: aorl{{.*}}%ds:(%e{{[abcd]}}x)
; CHECK: aorl{{.*}}%fs:(%{{[sd]}}i)
define void @aor(i32 %address, i32 %value) {
  call void @llvm.x86.aor32.legacy.address32(i32 %address, i32 %value, i32 32, i32 62)
  call void @llvm.x86.aor32.legacy.address32(i32 %address, i32 %value, i32 16, i32 100)
  ret void
}
declare void @llvm.x86.axor32.legacy.address32(i32, i32, i32 immarg, i32 immarg)
; CHECK-LABEL: axor:
; CHECK: axorl{{.*}}%ds:(%e{{[abcd]}}x)
; CHECK: axorl{{.*}}%fs:(%{{[sd]}}i)
define void @axor(i32 %address, i32 %value) {
  call void @llvm.x86.axor32.legacy.address32(i32 %address, i32 %value, i32 32, i32 62)
  call void @llvm.x86.axor32.legacy.address32(i32 %address, i32 %value, i32 16, i32 100)
  ret void
}
