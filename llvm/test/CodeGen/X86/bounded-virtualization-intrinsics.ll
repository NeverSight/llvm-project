; RUN: split-file %s %t
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/code32.ll | FileCheck %s --check-prefix=CHECK32
; RUN: opt -S -passes='default<O2>' %t/code32.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=CHECK32
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/code64.ll | FileCheck %s --check-prefix=CHECK64
; RUN: opt -S -passes='default<O2>' %t/code64.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=CHECK64
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu < %t/code32.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/code64.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %t/swapgs.ll 2>&1 | FileCheck %s --check-prefix=SWAPGS
; MODE: SVM intrinsic does not match the target code mode
; SWAPGS: SWAPGS intrinsic requires 64-bit mode

;--- code32.ll

declare void @llvm.x86.vmload32(i32)
; CHECK32-LABEL: probe_vmload:
; CHECK32-COUNT-2: vmload
; CHECK32: ret
define i32 @probe_vmload(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.vmload32(i32 %a)
  call void @llvm.x86.vmload32(i32 %a)
  %loaded = load i32, ptr %p
  %result = xor i32 %loaded, %a
  ret i32 %result
}

declare void @llvm.x86.vmsave32(i32)
; CHECK32-LABEL: probe_vmsave:
; CHECK32-COUNT-2: vmsave
; CHECK32: ret
define i32 @probe_vmsave(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.vmsave32(i32 %a)
  call void @llvm.x86.vmsave32(i32 %a)
  %loaded = load i32, ptr %p
  %result = xor i32 %loaded, %a
  ret i32 %result
}

declare void @llvm.x86.invlpga32(i32, i32)
; CHECK32-LABEL: probe_invlpga:
; CHECK32-COUNT-2: invlpga
; CHECK32: ret
define i32 @probe_invlpga(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.invlpga32(i32 %a, i32 %b)
  call void @llvm.x86.invlpga32(i32 %a, i32 %b)
  %loaded = load i32, ptr %p
  %result = xor i32 %loaded, %a
  ret i32 %result
}

declare void @llvm.x86.stgi()
; CHECK32-LABEL: probe_stgi:
; CHECK32-COUNT-2: stgi
; CHECK32: ret
define i32 @probe_stgi(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.stgi()
  call void @llvm.x86.stgi()
  %loaded = load i32, ptr %p
  %result = xor i32 %loaded, %a
  ret i32 %result
}

declare void @llvm.x86.clgi()
; CHECK32-LABEL: probe_clgi:
; CHECK32-COUNT-2: clgi
; CHECK32: ret
define i32 @probe_clgi(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.clgi()
  call void @llvm.x86.clgi()
  %loaded = load i32, ptr %p
  %result = xor i32 %loaded, %a
  ret i32 %result
}

declare void @llvm.x86.stac()
; CHECK32-LABEL: probe_stac:
; CHECK32-COUNT-2: stac
; CHECK32: ret
define i32 @probe_stac(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.stac()
  call void @llvm.x86.stac()
  %loaded = load i32, ptr %p
  %result = xor i32 %loaded, %a
  ret i32 %result
}

declare void @llvm.x86.clac()
; CHECK32-LABEL: probe_clac:
; CHECK32-COUNT-2: clac
; CHECK32: ret
define i32 @probe_clac(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.clac()
  call void @llvm.x86.clac()
  %loaded = load i32, ptr %p
  %result = xor i32 %loaded, %a
  ret i32 %result
}

declare void @llvm.x86.hlt()
; CHECK32-LABEL: probe_hlt:
; CHECK32-COUNT-2: hlt
; CHECK32: ret
define i32 @probe_hlt(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.hlt()
  call void @llvm.x86.hlt()
  %loaded = load i32, ptr %p
  %result = xor i32 %loaded, %a
  ret i32 %result
}

declare void @llvm.x86.vmfunc.eptp.switch(i32)
; CHECK32-LABEL: probe_vmfunc_eptp_switch:
; CHECK32-COUNT-2: vmfunc
; CHECK32: ret
define i32 @probe_vmfunc_eptp_switch(i32 %a, i32 %b, ptr %p) {
  store i32 %a, ptr %p
  call void @llvm.x86.vmfunc.eptp.switch(i32 %b)
  call void @llvm.x86.vmfunc.eptp.switch(i32 %b)
  %loaded = load i32, ptr %p
  %result = xor i32 %loaded, %a
  ret i32 %result
}


;--- code64.ll

declare void @llvm.x86.vmload(i64)
; CHECK64-LABEL: probe_vmload:
; CHECK64-COUNT-2: vmload
; CHECK64: ret
define i64 @probe_vmload(i64 %a, i32 %b, ptr %p) {
  store i64 %a, ptr %p
  call void @llvm.x86.vmload(i64 %a)
  call void @llvm.x86.vmload(i64 %a)
  %loaded = load i64, ptr %p
  %result = xor i64 %loaded, %a
  ret i64 %result
}

declare void @llvm.x86.vmsave(i64)
; CHECK64-LABEL: probe_vmsave:
; CHECK64-COUNT-2: vmsave
; CHECK64: ret
define i64 @probe_vmsave(i64 %a, i32 %b, ptr %p) {
  store i64 %a, ptr %p
  call void @llvm.x86.vmsave(i64 %a)
  call void @llvm.x86.vmsave(i64 %a)
  %loaded = load i64, ptr %p
  %result = xor i64 %loaded, %a
  ret i64 %result
}

declare void @llvm.x86.invlpga(i64, i32)
; CHECK64-LABEL: probe_invlpga:
; CHECK64-COUNT-2: invlpga
; CHECK64: ret
define i64 @probe_invlpga(i64 %a, i32 %b, ptr %p) {
  store i64 %a, ptr %p
  call void @llvm.x86.invlpga(i64 %a, i32 %b)
  call void @llvm.x86.invlpga(i64 %a, i32 %b)
  %loaded = load i64, ptr %p
  %result = xor i64 %loaded, %a
  ret i64 %result
}

declare void @llvm.x86.stgi()
; CHECK64-LABEL: probe_stgi:
; CHECK64-COUNT-2: stgi
; CHECK64: ret
define i64 @probe_stgi(i64 %a, i32 %b, ptr %p) {
  store i64 %a, ptr %p
  call void @llvm.x86.stgi()
  call void @llvm.x86.stgi()
  %loaded = load i64, ptr %p
  %result = xor i64 %loaded, %a
  ret i64 %result
}

declare void @llvm.x86.clgi()
; CHECK64-LABEL: probe_clgi:
; CHECK64-COUNT-2: clgi
; CHECK64: ret
define i64 @probe_clgi(i64 %a, i32 %b, ptr %p) {
  store i64 %a, ptr %p
  call void @llvm.x86.clgi()
  call void @llvm.x86.clgi()
  %loaded = load i64, ptr %p
  %result = xor i64 %loaded, %a
  ret i64 %result
}

declare void @llvm.x86.swapgs()
; CHECK64-LABEL: probe_swapgs:
; CHECK64-COUNT-2: swapgs
; CHECK64: ret
define i64 @probe_swapgs(i64 %a, i32 %b, ptr %p) {
  store i64 %a, ptr %p
  call void @llvm.x86.swapgs()
  call void @llvm.x86.swapgs()
  %loaded = load i64, ptr %p
  %result = xor i64 %loaded, %a
  ret i64 %result
}

declare void @llvm.x86.stac()
; CHECK64-LABEL: probe_stac:
; CHECK64-COUNT-2: stac
; CHECK64: ret
define i64 @probe_stac(i64 %a, i32 %b, ptr %p) {
  store i64 %a, ptr %p
  call void @llvm.x86.stac()
  call void @llvm.x86.stac()
  %loaded = load i64, ptr %p
  %result = xor i64 %loaded, %a
  ret i64 %result
}

declare void @llvm.x86.clac()
; CHECK64-LABEL: probe_clac:
; CHECK64-COUNT-2: clac
; CHECK64: ret
define i64 @probe_clac(i64 %a, i32 %b, ptr %p) {
  store i64 %a, ptr %p
  call void @llvm.x86.clac()
  call void @llvm.x86.clac()
  %loaded = load i64, ptr %p
  %result = xor i64 %loaded, %a
  ret i64 %result
}

declare void @llvm.x86.hlt()
; CHECK64-LABEL: probe_hlt:
; CHECK64-COUNT-2: hlt
; CHECK64: ret
define i64 @probe_hlt(i64 %a, i32 %b, ptr %p) {
  store i64 %a, ptr %p
  call void @llvm.x86.hlt()
  call void @llvm.x86.hlt()
  %loaded = load i64, ptr %p
  %result = xor i64 %loaded, %a
  ret i64 %result
}

declare void @llvm.x86.vmfunc.eptp.switch(i32)
; CHECK64-LABEL: probe_vmfunc_eptp_switch:
; CHECK64-COUNT-2: vmfunc
; CHECK64: ret
define i64 @probe_vmfunc_eptp_switch(i64 %a, i32 %b, ptr %p) {
  store i64 %a, ptr %p
  call void @llvm.x86.vmfunc.eptp.switch(i32 %b)
  call void @llvm.x86.vmfunc.eptp.switch(i32 %b)
  %loaded = load i64, ptr %p
  %result = xor i64 %loaded, %a
  ret i64 %result
}

;--- swapgs.ll
declare void @llvm.x86.swapgs()
define void @probe() {
  call void @llvm.x86.swapgs()
  ret void
}
