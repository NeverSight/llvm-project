; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: opt -passes='default<O2>' -S < %s | llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.64.obj
; RUN: llc -mtriple=i686-pc-windows-msvc -filetype=obj -verify-machineinstrs < %s -o %t.32.obj
; RUN: llc -mtriple=x86_64-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.64.macho
; RUN: llc -mtriple=i386-apple-darwin -filetype=obj -verify-machineinstrs < %s -o %t.32.macho
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -stop-after=finalize-isel < %s | FileCheck %s --check-prefix=EFFECTS

declare i8 @llvm.x86.vmclear(ptr)
declare i8 @llvm.x86.vmlaunch()
declare i8 @llvm.x86.vmptrld(ptr)
declare void @llvm.x86.vmptrst(ptr)
declare i8 @llvm.x86.vmresume()
declare void @llvm.x86.vmxoff()
declare i8 @llvm.x86.vmxon(ptr)

define i8 @clear(ptr %operand) {
; CHECK-LABEL: clear:
; CHECK-NOT: #APP
; CHECK: vmclear (
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK: ret
; EFFECTS: VMCLEARm {{.*}}implicit-def $eflags
  %status = call i8 @llvm.x86.vmclear(ptr %operand)
  ret i8 %status
}

define i8 @launch() {
; CHECK-LABEL: launch:
; CHECK-NOT: #APP
; CHECK: vmlaunch
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK: ret
; EFFECTS: VMLAUNCH implicit-def $eflags
  %status = call i8 @llvm.x86.vmlaunch()
  ret i8 %status
}

define i8 @load(ptr %operand) {
; CHECK-LABEL: load:
; CHECK-NOT: #APP
; CHECK: vmptrld (
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK: ret
; EFFECTS: VMPTRLDm {{.*}}implicit-def $eflags
  %status = call i8 @llvm.x86.vmptrld(ptr %operand)
  ret i8 %status
}

define void @store(ptr %operand) {
; CHECK-LABEL: store:
; CHECK-NOT: #APP
; CHECK: vmptrst (
; CHECK: ret
; EFFECTS: VMPTRSTm {{.*}}implicit-def dead $eflags
  call void @llvm.x86.vmptrst(ptr %operand)
  ret void
}

define i8 @resume() {
; CHECK-LABEL: resume:
; CHECK-NOT: #APP
; CHECK: vmresume
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK: ret
; EFFECTS: VMRESUME implicit-def $eflags
  %status = call i8 @llvm.x86.vmresume()
  ret i8 %status
}

define void @off() {
; CHECK-LABEL: off:
; CHECK-NOT: #APP
; CHECK: vmxoff
; CHECK: ret
; EFFECTS: VMXOFF implicit-def dead $eflags
  call void @llvm.x86.vmxoff()
  ret void
}

define i8 @on(ptr %operand) {
; CHECK-LABEL: on:
; CHECK-NOT: #APP
; CHECK: vmxon (
; CHECK-NEXT: sete
; CHECK-NEXT: setb
; CHECK: ret
; EFFECTS: VMXON {{.*}}implicit-def $eflags
  %status = call i8 @llvm.x86.vmxon(ptr %operand)
  ret i8 %status
}

define void @dead_status(ptr %operand) {
; CHECK-LABEL: dead_status:
; CHECK: vmclear
; CHECK-NOT: set
; CHECK: vmptrld
; CHECK-NOT: set
; CHECK: vmxon
; CHECK-NOT: set
; CHECK: vmlaunch
; CHECK-NOT: set
; CHECK: vmresume
; CHECK-NOT: set
; CHECK: ret
  %a = call i8 @llvm.x86.vmclear(ptr %operand)
  %b = call i8 @llvm.x86.vmptrld(ptr %operand)
  %c = call i8 @llvm.x86.vmxon(ptr %operand)
  %d = call i8 @llvm.x86.vmlaunch()
  %e = call i8 @llvm.x86.vmresume()
  ret void
}

define i64 @observe_store(ptr %operand) {
; CHECK-LABEL: observe_store:
; CHECK: mov
; CHECK: vmptrst
; CHECK: mov
; CHECK: ret
  store i64 13, ptr %operand, align 1
  call void @llvm.x86.vmptrst(ptr %operand)
  %value = load i64, ptr %operand, align 1
  ret i64 %value
}
