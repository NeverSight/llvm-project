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
; RUN: not opt -passes=verify -disable-output %t/bad.ll 2>&1 | FileCheck %s --check-prefix=BAD

; FNOP is an observable waiting x87 instruction. Neither repeated calls nor
; surrounding stores disappear. It must not become an external call or NOP.
; CHECK-LABEL: repeat:
; CHECK: movl
; CHECK: fnop
; CHECK-NEXT: fnop
; CHECK: movl $0,
; CHECK: ret
; BYTES: d9 d0{{[ \t]+}}fnop
; BYTES: d9 d0{{[ \t]+}}fnop
; MIR: FNOP implicit-def{{( dead)?}} $fpsw, implicit $fpcw, implicit $fpsw
; MIR: FNOP implicit-def{{( dead)?}} $fpsw, implicit $fpcw, implicit $fpsw
; ATTR: declare void @llvm.x86.fnop() #[[A:[0-9]+]]
; ATTR: attributes #[[A]] = { nounwind }
; BAD: {{[Ii]ntrinsic}}

;--- good.ll
declare void @llvm.x86.fnop()
define void @repeat(ptr %p, i32 %value) {
  store i32 %value, ptr %p
  call void @llvm.x86.fnop()
  call void @llvm.x86.fnop()
  store i32 0, ptr %p
  ret void
}

;--- bad.ll
declare void @llvm.x86.fnop(i32)
define void @bad() {
  call void @llvm.x86.fnop(i32 0)
  ret void
}
