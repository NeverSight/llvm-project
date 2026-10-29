; RUN: split-file %s %t
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/good.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/good.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=i686-pc-windows-msvc -O2 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -stop-after=finalize-isel -verify-machineinstrs < %t/good.ll | FileCheck %s --check-prefix=MIR
; RUN: opt -S -passes=verify %t/good.ll | FileCheck %s --check-prefix=ATTR
; RUN: not opt -passes=verify -disable-output %t/bad.ll 2>&1 | FileCheck %s --check-prefix=BAD

; Repeated operations have ambient effects and may fault. The format suffix
; selects operand size independently of the native-width address.
; CHECK-LABEL: sequence:
; CHECK: movl{{.*}}17,
; CHECK: fnstenvs
; CHECK: fnstenvs
; CHECK: fnstenv{{[ \t]}}
; CHECK: fldenvs
; CHECK: fldenv{{[ \t]}}
; CHECK: fnsaves
; CHECK: fnsave{{[ \t]}}
; CHECK: frstors
; CHECK: frstor{{[ \t]}}
; CHECK: movl{{.*}}23,
; CHECK: ret
; MIR: FSTENV16m {{.*}} :: (volatile store (s112){{.*}}align 1)
; MIR: FSTENV16m {{.*}} :: (volatile store (s112){{.*}}align 1)
; MIR: FSTENVm {{.*}} :: (volatile store (s224){{.*}}align 1)
; MIR: FLDENV16m {{.*}}implicit-def{{( dead)?}} $fp0{{.*}} :: (volatile load (s112){{.*}}align 1)
; MIR: FLDENVm {{.*}} :: (volatile load (s224){{.*}}align 1)
; MIR: FSAVE16m {{.*}} :: (volatile store (s752){{.*}}align 1)
; MIR: FSAVEm {{.*}} :: (volatile store (s864){{.*}}align 1)
; MIR: FRSTOR16m {{.*}} :: (volatile load (s752){{.*}}align 1)
; MIR: FRSTORm {{.*}} :: (volatile load (s864){{.*}}align 1)
; ATTR: declare void @llvm.x86.fnstenv16(ptr) #[[A:[0-9]+]]
; ATTR: declare void @llvm.x86.fnstenv32(ptr) #[[A]]
; ATTR: declare void @llvm.x86.fldenv16(ptr) #[[A]]
; ATTR: declare void @llvm.x86.fldenv32(ptr) #[[A]]
; ATTR: declare void @llvm.x86.fnsave16(ptr) #[[A]]
; ATTR: declare void @llvm.x86.fnsave32(ptr) #[[A]]
; ATTR: declare void @llvm.x86.frstor16(ptr) #[[A]]
; ATTR: declare void @llvm.x86.frstor32(ptr) #[[A]]
; ATTR: attributes #[[A]] = { nounwind }
; BAD-COUNT-8: intrinsic argument 0 type expected ptr, but got i64

;--- good.ll
declare void @llvm.x86.fnstenv16(ptr)
declare void @llvm.x86.fnstenv32(ptr)
declare void @llvm.x86.fldenv16(ptr)
declare void @llvm.x86.fldenv32(ptr)
declare void @llvm.x86.fnsave16(ptr)
declare void @llvm.x86.fnsave32(ptr)
declare void @llvm.x86.frstor16(ptr)
declare void @llvm.x86.frstor32(ptr)
define void @sequence(ptr %out, ptr %in, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.fnstenv16(ptr %out)
  call void @llvm.x86.fnstenv16(ptr %out)
  call void @llvm.x86.fnstenv32(ptr %out)
  call void @llvm.x86.fldenv16(ptr %in)
  call void @llvm.x86.fldenv32(ptr %in)
  call void @llvm.x86.fnsave16(ptr %out)
  call void @llvm.x86.fnsave32(ptr %out)
  call void @llvm.x86.frstor16(ptr %in)
  call void @llvm.x86.frstor32(ptr %in)
  store i32 23, ptr %marker
  ret void
}

;--- bad.ll
declare void @llvm.x86.fnstenv16(i64)
declare void @llvm.x86.fnstenv32(i64)
declare void @llvm.x86.fldenv16(i64)
declare void @llvm.x86.fldenv32(i64)
declare void @llvm.x86.fnsave16(i64)
declare void @llvm.x86.fnsave32(i64)
declare void @llvm.x86.frstor16(i64)
declare void @llvm.x86.frstor32(i64)
define void @bad() {
  call void @llvm.x86.fnstenv16(i64 0)
  call void @llvm.x86.fnstenv32(i64 0)
  call void @llvm.x86.fldenv16(i64 0)
  call void @llvm.x86.fldenv32(i64 0)
  call void @llvm.x86.fnsave16(i64 0)
  call void @llvm.x86.fnsave32(i64 0)
  call void @llvm.x86.frstor16(i64 0)
  call void @llvm.x86.frstor32(i64 0)
  ret void
}
