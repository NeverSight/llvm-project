; RUN: split-file %s %t
; RUN: opt -S -passes='default<O0>' %t/returns.ll | llc -mtriple=x86_64-unknown-linux-gnu -mattr=+uintr -O0 -verify-machineinstrs -o - | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/returns.ll | llc -mtriple=x86_64-unknown-linux-gnu -mattr=+uintr -O2 -verify-machineinstrs -o - | FileCheck %s
; RUN: opt -S -passes='default<O0>' %t/returns.ll | llc -mtriple=x86_64-pc-windows-msvc -mattr=+uintr -O0 -verify-machineinstrs -o - | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/returns.ll | llc -mtriple=x86_64-pc-windows-msvc -mattr=+uintr -O2 -verify-machineinstrs -o - | FileCheck %s
; RUN: opt -S -passes='default<O0>' %t/returns.ll | llc -mtriple=x86_64-apple-darwin -mattr=+uintr -O0 -verify-machineinstrs -o - | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/returns.ll | llc -mtriple=x86_64-apple-darwin -mattr=+uintr -O2 -verify-machineinstrs -o - | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs %t/protected.ll -o - | FileCheck %s --check-prefix=PROTECTED
; RUN: llc -mtriple=i686-pc-windows-msvc -O2 -verify-machineinstrs %t/protected.ll -o - | FileCheck %s --check-prefix=PROTECTED
; RUN: llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs %t/protected.ll -o - | FileCheck %s --check-prefix=PROTECTED
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+uintr -filetype=obj %t/returns.ll -o %t/returns.o
; RUN: llvm-objdump -d --mattr=+uintr %t/returns.o | FileCheck %s --check-prefix=BINARY
; RUN: opt -S -passes=verify %t/returns.ll -o - | FileCheck %s --check-prefix=ATTR
; RUN: llc -mtriple=x86_64-unknown-linux-gnux32 -O2 -verify-machineinstrs %t/x32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/wide.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-linux-code16 %t/protected.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64-unknown-linux-gnu -mattr=-uintr %t/uiret.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=FEATURE
; RUN: not opt -passes=verify %t/dynamic.ll -disable-output 2>&1 | FileCheck %s --check-prefix=IMM
; RUN: not opt -passes=verify %t/wrong.ll -disable-output 2>&1 | FileCheck %s --check-prefix=ARG
; RUN: llc -mtriple=x86_64-unknown-linux-gnu %t/old-system.ll -o - | FileCheck %s --check-prefix=OLD

; The native transfer and final stack assignment remain adjacent even with
; variable-size compiler frames. No ordinary return epilogue is emitted.
; CHECK-LABEL: iret16:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: iretw
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: iret32:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: iretl
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: iret64:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: iretq
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: retf16:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: lretw
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: retf32:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: lretl
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: retf64:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: lretq
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: retf16_imm:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: lretw $65535
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: retf32_imm:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: lretl $0
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: retf64_imm:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: lretq $32
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: erets:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: erets
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: eretu:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: eretu
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: uiret:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: uiret
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: sysenter:
; CHECK: movb $17,
; CHECK: sysenter
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: rsm:
; CHECK: movb $17,
; CHECK: rsm
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; PROTECTED-LABEL: iret16:
; PROTECTED: movb $17,
; PROTECTED: movl {{.*}}, %esp
; PROTECTED-NEXT: iretw
; PROTECTED-LABEL: iret32:
; PROTECTED: movb $17,
; PROTECTED: movl {{.*}}, %esp
; PROTECTED-NEXT: iretl
; PROTECTED-LABEL: retf16:
; PROTECTED: movb $17,
; PROTECTED: movl {{.*}}, %esp
; PROTECTED-NEXT: lretw
; PROTECTED-LABEL: retf32:
; PROTECTED: movb $17,
; PROTECTED: movl {{.*}}, %esp
; PROTECTED-NEXT: lretl
; PROTECTED-LABEL: retf16_imm:
; PROTECTED: movb $17,
; PROTECTED: movl {{.*}}, %esp
; PROTECTED-NEXT: lretw
; PROTECTED-LABEL: retf32_imm:
; PROTECTED: movb $17,
; PROTECTED: movl {{.*}}, %esp
; PROTECTED-NEXT: lretl
; PROTECTED-LABEL: sysenter:
; PROTECTED: movb $17,
; PROTECTED: sysenter
; PROTECTED-LABEL: rsm:
; PROTECTED: movb $17,
; PROTECTED: rsm
; BINARY: 66 cf{{[ \t]+}}iretw
; BINARY: cf{{[ \t]+}}iretl
; BINARY: 48 cf{{[ \t]+}}iretq
; BINARY: 66 cb{{[ \t]+}}lretw
; BINARY: cb{{[ \t]+}}lretl
; BINARY: 48 cb{{[ \t]+}}lretq
; BINARY: 66 ca ff ff{{[ \t]+}}lretw
; BINARY: ca 00 00{{[ \t]+}}lretl
; BINARY: 48 ca 20 00{{[ \t]+}}lretq
; BINARY: f2 0f 01 ca{{[ \t]+}}erets
; BINARY: f3 0f 01 ca{{[ \t]+}}eretu
; BINARY: f3 0f 01 ec{{[ \t]+}}uiret
; BINARY: 0f 34{{[ \t]+}}sysenter
; BINARY: 0f aa{{[ \t]+}}rsm
; ATTR-DAG: declare void @llvm.x86.iret64(ptr) #[[A:[0-9]+]]
; ATTR-DAG: declare void @llvm.x86.retf64.imm(ptr, i16 immarg) #[[A]]
; ATTR-DAG: declare void @llvm.x86.sysenter() #[[A]]
; ATTR-DAG: declare void @llvm.x86.rsm() #[[A]]
; ATTR: attributes #[[A]] = { convergent noduplicate noreturn nounwind }
; MODE: native frame-return intrinsic does not match the target code mode
; FEATURE: UIRET intrinsic requires the UINTR target feature
; IMM: immarg operand has non-immediate parameter
; ARG: intrinsic argument 0 type expected ptr, but got i64
; X32-LABEL: x32:
; X32: movl %edi, %e{{[a-z]+}}
; X32: movq {{.*}}, %rsp
; X32-NEXT: iretq
; OLD-LABEL: old_system:
; OLD: hlt
; OLD: clac
; OLD: stac
; OLD: swapgs

;--- wide.ll
declare void @llvm.x86.iret64(ptr)
define void @wide(ptr %frame) {
  call void @llvm.x86.iret64(ptr %frame)
  unreachable
}
;--- x32.ll
target datalayout = "e-m:e-p:32:32-i64:64-n8:16:32:64-S128"
declare void @llvm.x86.iret64(ptr)
define void @x32(i64 %address) {
  %frame = inttoptr i64 %address to ptr
  call void @llvm.x86.iret64(ptr %frame)
  unreachable
}
;--- uiret.ll
declare void @llvm.x86.uiret(ptr)
define void @user_return(ptr %frame) {
  call void @llvm.x86.uiret(ptr %frame)
  unreachable
}
;--- dynamic.ll
declare void @llvm.x86.retf64.imm(ptr, i16)
define void @dynamic(ptr %frame, i16 %amount) {
  call void @llvm.x86.retf64.imm(ptr %frame, i16 %amount)
  unreachable
}
;--- wrong.ll
declare void @llvm.x86.iret64(i64)
define void @wrong(i64 %frame) {
  call void @llvm.x86.iret64(i64 %frame)
  unreachable
}
;--- old-system.ll
declare void @llvm.x86.hlt()
declare void @llvm.x86.clac()
declare void @llvm.x86.stac()
declare void @llvm.x86.swapgs()
define void @old_system() {
  call void @llvm.x86.hlt()
  call void @llvm.x86.clac()
  call void @llvm.x86.stac()
  call void @llvm.x86.swapgs()
  ret void
}

;--- returns.ll
@observed = external global i8
declare void @llvm.x86.iret16(ptr)
define void @iret16(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.iret16(ptr %frame)
  unreachable
}
declare void @llvm.x86.iret32(ptr)
define void @iret32(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.iret32(ptr %frame)
  unreachable
}
declare void @llvm.x86.iret64(ptr)
define void @iret64(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.iret64(ptr %frame)
  unreachable
}
declare void @llvm.x86.retf16(ptr)
define void @retf16(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.retf16(ptr %frame)
  unreachable
}
declare void @llvm.x86.retf32(ptr)
define void @retf32(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.retf32(ptr %frame)
  unreachable
}
declare void @llvm.x86.retf64(ptr)
define void @retf64(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.retf64(ptr %frame)
  unreachable
}
declare void @llvm.x86.retf16.imm(ptr, i16)
define void @retf16_imm(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.retf16.imm(ptr %frame, i16 65535)
  unreachable
}
declare void @llvm.x86.retf32.imm(ptr, i16)
define void @retf32_imm(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.retf32.imm(ptr %frame, i16 0)
  unreachable
}
declare void @llvm.x86.retf64.imm(ptr, i16)
define void @retf64_imm(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.retf64.imm(ptr %frame, i16 32)
  unreachable
}
declare void @llvm.x86.erets(ptr)
define void @erets(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.erets(ptr %frame)
  unreachable
}
declare void @llvm.x86.eretu(ptr)
define void @eretu(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.eretu(ptr %frame)
  unreachable
}
declare void @llvm.x86.uiret(ptr)
define void @uiret(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.uiret(ptr %frame)
  unreachable
}
declare void @llvm.x86.sysenter()
define void @sysenter(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.sysenter()
  unreachable
}
declare void @llvm.x86.rsm()
define void @rsm(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.rsm()
  unreachable
}
attributes #0 = { "frame-pointer"="all" }

;--- protected.ll
@observed = external global i8
declare void @llvm.x86.iret16(ptr)
define void @iret16(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.iret16(ptr %frame)
  unreachable
}
declare void @llvm.x86.iret32(ptr)
define void @iret32(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.iret32(ptr %frame)
  unreachable
}
declare void @llvm.x86.retf16(ptr)
define void @retf16(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.retf16(ptr %frame)
  unreachable
}
declare void @llvm.x86.retf32(ptr)
define void @retf32(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.retf32(ptr %frame)
  unreachable
}
declare void @llvm.x86.retf16.imm(ptr, i16)
define void @retf16_imm(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.retf16.imm(ptr %frame, i16 65535)
  unreachable
}
declare void @llvm.x86.retf32.imm(ptr, i16)
define void @retf32_imm(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.retf32.imm(ptr %frame, i16 0)
  unreachable
}
declare void @llvm.x86.sysenter()
define void @sysenter(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.sysenter()
  unreachable
}
declare void @llvm.x86.rsm()
define void @rsm(ptr %frame, i64 %size) #0 {
  %local = alloca i8, i64 %size, align 32
  store volatile i8 17, ptr %local
  %loaded = load volatile i8, ptr %local
  store volatile i8 %loaded, ptr @observed
  call void @llvm.x86.rsm()
  unreachable
}
attributes #0 = { "frame-pointer"="all" }
