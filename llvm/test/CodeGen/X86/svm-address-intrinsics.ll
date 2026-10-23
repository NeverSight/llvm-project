; RUN: split-file %s %t
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/code32.ll | FileCheck %s --check-prefix=CHECK32
; RUN: opt -S -passes='default<O2>' %t/code32.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=CHECK32
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/code32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-none-code16 < %t/code32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/code64.ll | FileCheck %s --check-prefix=CHECK64
; RUN: opt -S -passes='default<O2>' %t/code64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=CHECK64
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/code64.ll 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: SVM address-size override does not match the target code mode

;--- code32.ll

declare void @llvm.x86.vmload.addr16(i16)
; CHECK32-LABEL: probe_vmload:
; CHECK32-COUNT-2: addr16{{[ \t]+}}vmload
; CHECK32: ret
define i16 @probe_vmload(i16 %a, i32 %b, ptr %p) {
  store i16 %a, ptr %p
  call void @llvm.x86.vmload.addr16(i16 %a)
  call void @llvm.x86.vmload.addr16(i16 %a)
  %result = load i16, ptr %p
  ret i16 %result
}

declare void @llvm.x86.vmsave.addr16(i16)
; CHECK32-LABEL: probe_vmsave:
; CHECK32-COUNT-2: addr16{{[ \t]+}}vmsave
; CHECK32: ret
define i16 @probe_vmsave(i16 %a, i32 %b, ptr %p) {
  store i16 %a, ptr %p
  call void @llvm.x86.vmsave.addr16(i16 %a)
  call void @llvm.x86.vmsave.addr16(i16 %a)
  %result = load i16, ptr %p
  ret i16 %result
}

declare void @llvm.x86.invlpga.addr16(i16, i32)
; CHECK32-LABEL: probe_invlpga:
; CHECK32-COUNT-2: addr16{{[ \t]+}}invlpga
; CHECK32: ret
define i16 @probe_invlpga(i16 %a, i32 %b, ptr %p) {
  store i16 %a, ptr %p
  call void @llvm.x86.invlpga.addr16(i16 %a, i32 %b)
  call void @llvm.x86.invlpga.addr16(i16 %a, i32 %b)
  %result = load i16, ptr %p
  ret i16 %result
}


;--- code64.ll

declare void @llvm.x86.vmload.addr32(i32)
; CHECK64-LABEL: probe_vmload:
; CHECK64-COUNT-2: addr32{{[ \t]+}}vmload
; CHECK64: ret
define i32 @probe_vmload(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.vmload.addr32(i32 %a)
  call void @llvm.x86.vmload.addr32(i32 %a)
  %result = load i32, ptr %p
  ret i32 %result
}

declare void @llvm.x86.vmsave.addr32(i32)
; CHECK64-LABEL: probe_vmsave:
; CHECK64-COUNT-2: addr32{{[ \t]+}}vmsave
; CHECK64: ret
define i32 @probe_vmsave(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.vmsave.addr32(i32 %a)
  call void @llvm.x86.vmsave.addr32(i32 %a)
  %result = load i32, ptr %p
  ret i32 %result
}

declare void @llvm.x86.invlpga.addr32(i32, i32)
; CHECK64-LABEL: probe_invlpga:
; CHECK64-COUNT-2: addr32{{[ \t]+}}invlpga
; CHECK64: ret
define i32 @probe_invlpga(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.invlpga.addr32(i32 %a, i32 %b)
  call void @llvm.x86.invlpga.addr32(i32 %a, i32 %b)
  %result = load i32, ptr %p
  ret i32 %result
}

