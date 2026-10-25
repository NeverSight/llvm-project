; RUN: llc -mtriple=x86_64-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=x86_64-linux-gnu -mattr=+egpr -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-linux-gnu -stop-after=finalize-isel -verify-machineinstrs < %s | FileCheck %s --check-prefix=MIR
; RUN: not --crash llc -mtriple=i386-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: atomic intrinsic requires 64-bit mode
; Native legacy interfaces retain exact encoding independently of APX allocation.
declare void @llvm.x86.aadd32.legacy.address(i64, i32, i32 immarg, i32 immarg)
; CHECK-LABEL: aadd32:
; CHECK-NOT: {evex}
; CHECK: aaddl{{.*}}%fs:(%ebx)
; MIR: LEGACY_RAO_NATIVE32
define void @aadd32(i64 %address, i32 %value) {
  call void @llvm.x86.aadd32.legacy.address(i64 %address, i32 %value, i32 32, i32 100)
  ret void
}
declare void @llvm.x86.aand32.legacy.address(i64, i32, i32 immarg, i32 immarg)
; CHECK-LABEL: aand32:
; CHECK-NOT: {evex}
; CHECK: aandl{{.*}}%fs:(%ebx)
; MIR: LEGACY_RAO_NATIVE32
define void @aand32(i64 %address, i32 %value) {
  call void @llvm.x86.aand32.legacy.address(i64 %address, i32 %value, i32 32, i32 100)
  ret void
}
declare void @llvm.x86.aor32.legacy.address(i64, i32, i32 immarg, i32 immarg)
; CHECK-LABEL: aor32:
; CHECK-NOT: {evex}
; CHECK: aorl{{.*}}%fs:(%ebx)
; MIR: LEGACY_RAO_NATIVE32
define void @aor32(i64 %address, i32 %value) {
  call void @llvm.x86.aor32.legacy.address(i64 %address, i32 %value, i32 32, i32 100)
  ret void
}
declare void @llvm.x86.axor32.legacy.address(i64, i32, i32 immarg, i32 immarg)
; CHECK-LABEL: axor32:
; CHECK-NOT: {evex}
; CHECK: axorl{{.*}}%fs:(%ebx)
; MIR: LEGACY_RAO_NATIVE32
define void @axor32(i64 %address, i32 %value) {
  call void @llvm.x86.axor32.legacy.address(i64 %address, i32 %value, i32 32, i32 100)
  ret void
}
declare i32 @llvm.x86.cmpccxadd32.legacy.address(i64, i32, i32, i32 immarg, i32 immarg, i32 immarg)
; CHECK-LABEL: compare32:
; CHECK-NOT: {evex}
; CHECK-COUNT-2: cmpgxadd{{.*}}%gs:(%rbx)
; MIR: LEGACY_CMPCCXADD_NATIVE32 {{.*}} implicit-def {{(dead )?}}$eflags
define i32 @compare32(i64 %address, i32 %compare, i32 %add) {
  %first = call i32 @llvm.x86.cmpccxadd32.legacy.address(i64 %address, i32 %compare, i32 %add, i32 15, i32 64, i32 101)
  %dead = call i32 @llvm.x86.cmpccxadd32.legacy.address(i64 %address, i32 %compare, i32 %add, i32 15, i32 64, i32 101)
  ret i32 %first
}
declare void @llvm.x86.aadd64.legacy.address(i64, i64, i32 immarg, i32 immarg)
; CHECK-LABEL: aadd64:
; CHECK-NOT: {evex}
; CHECK: aaddq{{.*}}%fs:(%ebx)
; MIR: LEGACY_RAO_NATIVE64
define void @aadd64(i64 %address, i64 %value) {
  call void @llvm.x86.aadd64.legacy.address(i64 %address, i64 %value, i32 32, i32 100)
  ret void
}
declare void @llvm.x86.aand64.legacy.address(i64, i64, i32 immarg, i32 immarg)
; CHECK-LABEL: aand64:
; CHECK-NOT: {evex}
; CHECK: aandq{{.*}}%fs:(%ebx)
; MIR: LEGACY_RAO_NATIVE64
define void @aand64(i64 %address, i64 %value) {
  call void @llvm.x86.aand64.legacy.address(i64 %address, i64 %value, i32 32, i32 100)
  ret void
}
declare void @llvm.x86.aor64.legacy.address(i64, i64, i32 immarg, i32 immarg)
; CHECK-LABEL: aor64:
; CHECK-NOT: {evex}
; CHECK: aorq{{.*}}%fs:(%ebx)
; MIR: LEGACY_RAO_NATIVE64
define void @aor64(i64 %address, i64 %value) {
  call void @llvm.x86.aor64.legacy.address(i64 %address, i64 %value, i32 32, i32 100)
  ret void
}
declare void @llvm.x86.axor64.legacy.address(i64, i64, i32 immarg, i32 immarg)
; CHECK-LABEL: axor64:
; CHECK-NOT: {evex}
; CHECK: axorq{{.*}}%fs:(%ebx)
; MIR: LEGACY_RAO_NATIVE64
define void @axor64(i64 %address, i64 %value) {
  call void @llvm.x86.axor64.legacy.address(i64 %address, i64 %value, i32 32, i32 100)
  ret void
}
declare i64 @llvm.x86.cmpccxadd64.legacy.address(i64, i64, i64, i32 immarg, i32 immarg, i32 immarg)
; CHECK-LABEL: compare64:
; CHECK-NOT: {evex}
; CHECK-COUNT-2: cmpgxadd{{.*}}%gs:(%rbx)
; MIR: LEGACY_CMPCCXADD_NATIVE64 {{.*}} implicit-def {{(dead )?}}$eflags
define i64 @compare64(i64 %address, i64 %compare, i64 %add) {
  %first = call i64 @llvm.x86.cmpccxadd64.legacy.address(i64 %address, i64 %compare, i64 %add, i32 15, i32 64, i32 101)
  %dead = call i64 @llvm.x86.cmpccxadd64.legacy.address(i64 %address, i64 %compare, i64 %add, i32 15, i32 64, i32 101)
  ret i64 %first
}
