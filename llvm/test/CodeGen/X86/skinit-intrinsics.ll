; RUN: split-file %s %t
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/launch.ll | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/launch.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/launch.ll | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/launch.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=i686-pc-windows-msvc -O0 -verify-machineinstrs < %t/launch.ll | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/launch.ll | llc -mtriple=i686-pc-windows-msvc -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs < %t/launch.ll | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/launch.ll | llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=i386-apple-darwin -O0 -verify-machineinstrs < %t/launch.ll | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/launch.ll | llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs < %t/launch.ll | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/launch.ll | llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=i386-unknown-none-code16 -O0 -verify-machineinstrs < %t/launch.ll | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=i386-unknown-linux-gnu -filetype=obj -verify-machineinstrs < %t/launch.ll | llvm-objdump -d - | FileCheck %s --check-prefix=BINARY
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -filetype=obj -verify-machineinstrs < %t/launch.ll | llvm-objdump -d - | FileCheck %s --check-prefix=BINARY
; RUN: llc -mtriple=i686-pc-windows-msvc -filetype=obj -verify-machineinstrs < %t/launch.ll | llvm-objdump -d - | FileCheck %s --check-prefix=BINARY
; RUN: llc -mtriple=x86_64-pc-windows-msvc -filetype=obj -verify-machineinstrs < %t/launch.ll | llvm-objdump -d - | FileCheck %s --check-prefix=BINARY
; RUN: llc -mtriple=i386-apple-darwin -filetype=obj -verify-machineinstrs < %t/launch.ll | llvm-objdump -d - | FileCheck %s --check-prefix=BINARY
; RUN: llc -mtriple=x86_64-apple-darwin -filetype=obj -verify-machineinstrs < %t/launch.ll | llvm-objdump -d - | FileCheck %s --check-prefix=BINARY
; RUN: opt -S -passes=verify %t/launch.ll | FileCheck %s --check-prefix=ATTR
; RUN: not opt -passes=verify -disable-output %t/wrong-argument.ll 2>&1 | FileCheck %s --check-prefix=ARGUMENT
; RUN: not opt -passes=verify -disable-output %t/wrong-result.ll 2>&1 | FileCheck %s --check-prefix=RESULT

; AMD APM Vol.3 revision 3.38: SKINIT reads EAX unchanged, then resets
; processor state and jumps to the SLB entry. No host execution is required.
; COMMON-LABEL: launch:
; COMMON: movl {{.*}}, %eax
; COMMON-NEXT: {{^[ \t]*skinit$}}
; COMMON-NOT: {{call[lq]?[ \t]}}
; COMMON-NOT: {{^[ \t]*ret[lq]?$}}
; COMMON-LABEL: launch_constant:
; COMMON: movl ${{(2271596015|-2023371281)}}, %eax
; COMMON-NEXT: {{^[ \t]*skinit$}}
; COMMON-NOT: {{call[lq]?[ \t]}}
; COMMON-NOT: {{^[ \t]*ret[lq]?$}}
; COMMON-LABEL: launch_store:
; COMMON: movl $1,
; COMMON: {{^[ \t]*skinit$}}
; COMMON-NOT: {{call[lq]?[ \t]}}
; COMMON-NOT: {{^[ \t]*ret[lq]?$}}

; BINARY: 0f 01 de{{[ \t]+}}skinit
; BINARY: 0f 01 de{{[ \t]+}}skinit
; BINARY: 0f 01 de{{[ \t]+}}skinit

; ATTR: declare void @llvm.x86.skinit(i32) #[[A:[0-9]+]]
; ATTR: attributes #[[A]] = { convergent noduplicate noreturn nounwind }
; ARGUMENT: intrinsic argument 0 type expected i32, but got i64
; RESULT: intrinsic return type expected void, but got i32

;--- launch.ll
@sl_observed = external global i32
declare void @llvm.x86.skinit(i32)

define void @launch(i32 %base) {
  call void @llvm.x86.skinit(i32 %base)
  unreachable
}

define void @launch_constant() {
  call void @llvm.x86.skinit(i32 2271596015)
  unreachable
}

define void @launch_store(i32 %base) {
  store i32 1, ptr @sl_observed
  call void @llvm.x86.skinit(i32 %base)
  unreachable
}

;--- wrong-argument.ll
declare void @llvm.x86.skinit(i64)
define void @bad(i64 %base) {
  call void @llvm.x86.skinit(i64 %base)
  unreachable
}

;--- wrong-result.ll
declare i32 @llvm.x86.skinit(i32)
define void @bad(i32 %base) {
  %result = call i32 @llvm.x86.skinit(i32 %base)
  unreachable
}
