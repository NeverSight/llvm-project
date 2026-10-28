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
; RUN: not opt -passes=verify -disable-output %t/bad-store.ll 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not opt -passes=verify -disable-output %t/bad-load.ll 2>&1 | FileCheck %s --check-prefix=BAD

; Repeated environment reads/writes and surrounding memory operations survive.
; CHECK-LABEL: repeat:
; CHECK: movl{{.*}}17,
; CHECK: fnstcw
; CHECK: fldcw
; CHECK: fnstcw
; CHECK: fldcw
; CHECK: movl{{.*}}23,
; CHECK: ret
; BYTES: d9{{.*}}fnstcw
; BYTES: d9{{.*}}fldcw
; BYTES: d9{{.*}}fnstcw
; BYTES: d9{{.*}}fldcw
; MIR: FNSTCW16m {{.*}}implicit-def{{( dead)?}} $fpsw, implicit $fpcw :: (volatile store (s16){{.*}}align 1)
; MIR: FLDCW16m {{.*}}implicit-def{{( dead)?}} $fpsw, implicit-def{{( dead)?}} $fpcw, implicit $fpcw, implicit $fpsw :: (volatile load (s16){{.*}}align 1)
; ATTR: declare void @llvm.x86.fnstcw(ptr) #[[A:[0-9]+]]
; ATTR: declare void @llvm.x86.fldcw(ptr) #[[A]]
; ATTR: attributes #[[A]] = { nounwind }
; BAD: {{[Ii]ntrinsic}}

;--- good.ll
declare void @llvm.x86.fnstcw(ptr)
declare void @llvm.x86.fldcw(ptr)
define void @repeat(ptr %out, ptr %in, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.fnstcw(ptr %out)
  call void @llvm.x86.fldcw(ptr %in)
  call void @llvm.x86.fnstcw(ptr %out)
  call void @llvm.x86.fldcw(ptr %in)
  store i32 23, ptr %marker
  ret void
}

;--- bad-store.ll
declare i16 @llvm.x86.fnstcw(ptr)
define i16 @bad(ptr %p) {
  %value = call i16 @llvm.x86.fnstcw(ptr %p)
  ret i16 %value
}

;--- bad-load.ll
declare void @llvm.x86.fldcw(i16)
define void @bad() {
  call void @llvm.x86.fldcw(i16 895)
  ret void
}
