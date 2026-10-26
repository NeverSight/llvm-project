; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=x86_64-unknown-linux-gnu -mattr=+egpr -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -stop-after=finalize-isel -verify-machineinstrs < %s | FileCheck %s --check-prefix=MIR
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE

; Address APIs retain APX EVEX even when low registers could encode RAO-INT or
; VEX CMPccXADD. The native instruction owns memory and dead-result effects.
; MODE: APX atomic intrinsic requires 64-bit mode
declare void @llvm.x86.aadd32.address(i64, i32, i32 immarg, i32 immarg)
declare void @llvm.x86.aand64.address(i64, i64, i32 immarg, i32 immarg)
declare void @llvm.x86.aor32.address(i64, i32, i32 immarg, i32 immarg)
declare void @llvm.x86.axor64.address(i64, i64, i32 immarg, i32 immarg)
declare i32 @llvm.x86.cmpccxadd32.address(i64, i32, i32, i32 immarg, i32 immarg, i32 immarg)
declare i64 @llvm.x86.cmpccxadd64.address(i64, i64, i64, i32 immarg, i32 immarg, i32 immarg)

; CHECK-LABEL: atomic_effects:
; CHECK: {evex} aaddl
; CHECK: {evex} aandq{{.*}}%fs:(%e{{[abcd]}}x)
; CHECK: {evex} aorl{{.*}}%gs:(%r{{[abcd]}}x)
; CHECK: {evex} axorq
; MIR: APX_RAO_NATIVE32
; MIR: APX_RAO_NATIVE64
define void @atomic_effects(i64 %address, i32 %x, i64 %y) {
  call void @llvm.x86.aadd32.address(i64 %address, i32 %x, i32 64, i32 0)
  call void @llvm.x86.aand64.address(i64 %address, i64 %y, i32 32, i32 100)
  call void @llvm.x86.aor32.address(i64 %address, i32 %x, i32 64, i32 101)
  call void @llvm.x86.axor64.address(i64 %address, i64 %y, i32 32, i32 0)
  ret void
}

; CHECK-LABEL: conditional:
; CHECK: {evex} cmpgxadd{{.*}}%gs:(%e{{[abcd]}}x)
; MIR: APX_CMPCCXADD_NATIVE64 {{.*}} implicit-def {{(dead )?}}$eflags
define i64 @conditional(i64 %address, i64 %compare, i64 %add) {
  %old = call i64 @llvm.x86.cmpccxadd64.address(i64 %address, i64 %compare, i64 %add, i32 15, i32 32, i32 101)
  ret i64 %old
}

; CHECK-LABEL: dead:
; CHECK-COUNT-2: {evex} cmpexadd
; MIR: APX_CMPCCXADD_NATIVE32 {{.*}} implicit-def {{(dead )?}}$eflags
define void @dead(i64 %address, i32 %compare, i32 %add) {
  %old0 = call i32 @llvm.x86.cmpccxadd32.address(i64 %address, i32 %compare, i32 %add, i32 4, i32 64, i32 0)
  %old1 = call i32 @llvm.x86.cmpccxadd32.address(i64 %address, i32 %compare, i32 %add, i32 4, i32 64, i32 0)
  ret void
}

