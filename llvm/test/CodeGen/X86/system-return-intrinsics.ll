; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs %t/returns.ll -o - | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/returns.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs %t/returns.ll -o - | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/returns.ll | llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs %t/returns.ll -o - | FileCheck %s
; RUN: opt -S -passes='default<O2>' %t/returns.ll | llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs -o - | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs %t/protected.ll -o - | FileCheck %s --check-prefix=PROTECTED
; RUN: llc -mtriple=i686-pc-windows-msvc -O2 -verify-machineinstrs %t/protected.ll -o - | FileCheck %s --check-prefix=PROTECTED
; RUN: llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs %t/protected.ll -o - | FileCheck %s --check-prefix=PROTECTED
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -filetype=obj %t/returns.ll -o %t/returns.o
; RUN: llvm-objdump -d %t/returns.o | FileCheck %s --check-prefix=BINARY
; RUN: opt -S -passes=verify %t/returns.ll -o - | FileCheck %s --check-prefix=ATTR
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/sysret-mode.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu %t/sysexit-mode.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-unknown-linux-code16 %t/protected.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not opt -passes=verify %t/wrong-argument.ll -disable-output 2>&1 | FileCheck %s --check-prefix=ARGUMENT
; RUN: not opt -passes=verify %t/wrong-result.ll -disable-output 2>&1 | FileCheck %s --check-prefix=RESULT

; The compiler frame is abandoned. In particular, no spill, reload, or epilogue
; may use the destination RSP before SYSRET. SYSEXIT installs RSP itself.
; CHECK-LABEL: return32:
; CHECK-NOT: #APP
; CHECK: movl $305419896, %ecx
; CHECK: movl $582, %r11d
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: sysretl
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: return64:
; CHECK-NOT: #APP
; CHECK: movl $305419896, %ecx
; CHECK: movl $582, %r11d
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: sysretq
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: exit32:
; CHECK-NOT: #APP
; CHECK-DAG: movl $305419896, %edx
; CHECK-DAG: movl $589824, %ecx
; CHECK: sysexitl
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: exit64:
; CHECK-NOT: #APP
; CHECK-DAG: movl $305419896, %edx
; CHECK-DAG: movl $589824, %ecx
; CHECK: sysexitq
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: return_frame:
; CHECK: movb $17,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: sysretq
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; CHECK-LABEL: return_dynamic_frame:
; CHECK: movb $19,
; CHECK: movq {{.*}}, %rsp
; CHECK-NEXT: sysretl
; CHECK-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}

; PROTECTED-LABEL: exit32:
; PROTECTED-DAG: movl $305419896, %edx
; PROTECTED-DAG: movl $589824, %ecx
; PROTECTED: sysexitl
; PROTECTED-NOT: {{^[ \t]*ret[lq]?[ \t]*$}}
; BINARY: 0f 07{{[ \t]+}}sysretl
; BINARY: 48 0f 07{{[ \t]+}}sysretq
; BINARY: 0f 35{{[ \t]+}}sysexitl
; BINARY: 48 0f 35{{[ \t]+}}sysexitq
; ATTR-DAG: declare void @llvm.x86.sysret32(i32, i32, i64) #[[A:[0-9]+]]
; ATTR-DAG: declare void @llvm.x86.sysret64(i64, i64, i64) #[[A]]
; ATTR-DAG: declare void @llvm.x86.sysexit32(i32, i32) #[[A]]
; ATTR-DAG: declare void @llvm.x86.sysexit64(i64, i64) #[[A]]
; ATTR: attributes #[[A]] = { convergent noduplicate noreturn nounwind }
; MODE: system-return intrinsic does not match the target code mode
; ARGUMENT: intrinsic argument 2 type expected i64, but got i32
; RESULT: intrinsic return type expected void, but got i32

;--- returns.ll
declare void @llvm.x86.sysret32(i32, i32, i64)
declare void @llvm.x86.sysret64(i64, i64, i64)
declare void @llvm.x86.sysexit32(i32, i32)
declare void @llvm.x86.sysexit64(i64, i64)

define void @return32(i64 %sp) {
  call void @llvm.x86.sysret32(i32 305419896, i32 582, i64 %sp)
  unreachable
}
define void @return64(i64 %sp) {
  call void @llvm.x86.sysret64(i64 305419896, i64 582, i64 %sp)
  unreachable
}
define void @exit32() {
  call void @llvm.x86.sysexit32(i32 305419896, i32 589824)
  unreachable
}
define void @exit64() {
  call void @llvm.x86.sysexit64(i64 305419896, i64 589824)
  unreachable
}
define void @return_frame(i64 %pc, i64 %flags, i64 %sp) #0 {
  %frame = alloca [512 x i8], align 32
  store volatile i8 17, ptr %frame
  %x = load volatile i8, ptr %frame
  %wide = zext i8 %x to i64
  %target = add i64 %pc, %wide
  call void @llvm.x86.sysret64(i64 %target, i64 %flags, i64 %sp)
  unreachable
}
define void @return_dynamic_frame(i32 %pc, i32 %flags, i64 %sp, i64 %size) #0 {
  %frame = alloca i8, i64 %size, align 32
  store volatile i8 19, ptr %frame
  %x = load volatile i8, ptr %frame
  %wide = zext i8 %x to i32
  %target = add i32 %pc, %wide
  call void @llvm.x86.sysret32(i32 %target, i32 %flags, i64 %sp)
  unreachable
}
attributes #0 = { "frame-pointer"="all" }

;--- protected.ll
declare void @llvm.x86.sysexit32(i32, i32)
define void @exit32() {
  call void @llvm.x86.sysexit32(i32 305419896, i32 589824)
  unreachable
}
;--- sysret-mode.ll
declare void @llvm.x86.sysret32(i32, i32, i64)
define void @bad(i32 %pc, i32 %flags, i64 %sp) {
  call void @llvm.x86.sysret32(i32 %pc, i32 %flags, i64 %sp)
  unreachable
}
;--- sysexit-mode.ll
declare void @llvm.x86.sysexit64(i64, i64)
define void @bad(i64 %pc, i64 %sp) {
  call void @llvm.x86.sysexit64(i64 %pc, i64 %sp)
  unreachable
}
;--- wrong-argument.ll
declare void @llvm.x86.sysret32(i32, i32, i32)
define void @bad(i32 %pc, i32 %flags, i32 %sp) {
  call void @llvm.x86.sysret32(i32 %pc, i32 %flags, i32 %sp)
  unreachable
}
;--- wrong-result.ll
declare i32 @llvm.x86.sysexit64(i64, i64)
define void @bad(i64 %pc, i64 %sp) {
  %r = call i32 @llvm.x86.sysexit64(i64 %pc, i64 %sp)
  unreachable
}
