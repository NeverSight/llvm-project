; RUN: split-file %s %t
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/good.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/good.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=i686-pc-windows-msvc -O2 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs < %t/good.ll | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -filetype=obj < %t/good.ll | llvm-objdump -d - | FileCheck %s --check-prefix=BYTES
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -stop-after=finalize-isel -verify-machineinstrs < %t/good.ll | FileCheck %s --check-prefix=MIR
; RUN: opt -S -passes=verify %t/good.ll | FileCheck %s --check-prefix=ATTR
; RUN: not opt -passes=verify -disable-output %t/bad-read.ll 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not opt -passes=verify -disable-output %t/bad-store.ll 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not opt -passes=verify -disable-output %t/bad-clear.ll 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not opt -passes=verify -disable-output %t/bad-init.ll 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not opt -passes=verify -disable-output %t/bad-wait.ll 2>&1 | FileCheck %s --check-prefix=BAD

; The unused register read and repeated waiting operations remain observable.
; The memory form is a single DD /7 access, never an AX read plus MOV.
; CHECK-LABEL: sequence:
; CHECK: movl{{.*}}17,
; CHECK: fnstsw{{[ \t]+}}%ax
; CHECK: fnstsw{{[ \t]+}}(
; CHECK: fnclex
; CHECK: fnstsw{{[ \t]+}}%ax
; CHECK: fninit
; CHECK: wait
; CHECK-NEXT: wait
; CHECK: movl{{.*}}23,
; CHECK: ret
; BYTES: df e0{{[ \t]+}}fnstsw
; BYTES: dd{{.*}}fnstsw
; BYTES: db e2{{[ \t]+}}fnclex
; BYTES: df e0{{[ \t]+}}fnstsw
; BYTES: db e3{{[ \t]+}}fninit
; BYTES: 9b{{[ \t]+}}wait
; BYTES: 9b{{[ \t]+}}wait
; MIR: FNSTSW16r implicit-def{{( dead)?}} $ax, implicit-def{{( dead)?}} $fpsw, implicit $fpsw
; MIR: FNSTSWm {{.*}}implicit-def{{( dead)?}} $fpsw, implicit $fpsw :: (volatile store (s16){{.*}}align 1)
; MIR: FNCLEX implicit-def{{( dead)?}} $fpsw, implicit $fpsw
; MIR: FNINIT implicit-def{{( dead)?}} $fpsw, implicit-def{{( dead)?}} $fpcw, implicit-def{{( dead)?}} $fp0
; MIR: WAIT implicit-def{{( dead)?}} $fpsw, implicit $fpcw, implicit $fpsw
; ATTR: declare i16 @llvm.x86.fnstsw() #[[A:[0-9]+]]
; ATTR: declare void @llvm.x86.fnstsw.mem(ptr) #[[A]]
; ATTR: declare void @llvm.x86.fnclex() #[[A]]
; ATTR: declare void @llvm.x86.fninit() #[[A]]
; ATTR: declare void @llvm.x86.fwait() #[[A]]
; ATTR: attributes #[[A]] = { nounwind }
; BAD: {{[Ii]ntrinsic}}

;--- good.ll
declare i16 @llvm.x86.fnstsw()
declare void @llvm.x86.fnstsw.mem(ptr)
declare void @llvm.x86.fnclex()
declare void @llvm.x86.fninit()
declare void @llvm.x86.fwait()
define i16 @sequence(ptr %out, ptr %marker) {
  store i32 17, ptr %marker
  %unused = call i16 @llvm.x86.fnstsw()
  call void @llvm.x86.fnstsw.mem(ptr %out)
  call void @llvm.x86.fnclex()
  %status = call i16 @llvm.x86.fnstsw()
  call void @llvm.x86.fninit()
  call void @llvm.x86.fwait()
  call void @llvm.x86.fwait()
  store i32 23, ptr %marker
  ret i16 %status
}

;--- bad-read.ll
declare i32 @llvm.x86.fnstsw()
define i32 @bad() {
  %r = call i32 @llvm.x86.fnstsw()
  ret i32 %r
}

;--- bad-store.ll
declare void @llvm.x86.fnstsw.mem(i16)
define void @bad() {
  call void @llvm.x86.fnstsw.mem(i16 0)
  ret void
}

;--- bad-clear.ll
declare void @llvm.x86.fnclex(i32)
define void @bad() {
  call void @llvm.x86.fnclex(i32 0)
  ret void
}

;--- bad-init.ll
declare i16 @llvm.x86.fninit()
define i16 @bad() {
  %r = call i16 @llvm.x86.fninit()
  ret i16 %r
}

;--- bad-wait.ll
declare void @llvm.x86.fwait(ptr)
define void @bad(ptr %p) {
  call void @llvm.x86.fwait(ptr %p)
  ret void
}
