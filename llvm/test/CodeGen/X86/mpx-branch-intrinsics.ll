; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64 -verify-machineinstrs %t/good.ll -o - | FileCheck %s --check-prefix=ASM
; RUN: llc -mtriple=i386 -verify-machineinstrs %t/good.ll -o - | FileCheck %s --check-prefix=ASM
; RUN: opt -S '-passes=default<O2>' %t/good.ll -o %t/optimized.ll
; RUN: FileCheck %s --check-prefix=IR < %t/optimized.ll
; RUN: llc -mtriple=x86_64 -verify-machineinstrs %t/optimized.ll -filetype=obj -o %t/direct.o
; RUN: llvm-objdump -d %t/direct.o | FileCheck %s --check-prefix=BYTES
; RUN: llc -mtriple=x86_64 %t/optimized.ll -o %t/roundtrip.s
; RUN: llvm-mc -triple=x86_64 -filetype=obj %t/roundtrip.s -o %t/roundtrip.o
; RUN: llvm-objdump -d %t/roundtrip.o | FileCheck %s --check-prefix=BYTES
; RUN: llc -mtriple=i386 -verify-machineinstrs %t/optimized.ll -filetype=obj -o %t/narrow.o
; RUN: llvm-objdump -d %t/narrow.o | FileCheck %s --check-prefix=BYTES
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs %t/optimized.ll -filetype=obj -o %t/coff.obj
; RUN: llvm-objdump -d %t/coff.obj | FileCheck %s --check-prefix=BYTES
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs %t/optimized.ll -filetype=obj -o %t/macho.o
; RUN: llvm-objdump -d %t/macho.o | FileCheck %s --check-prefix=BYTES
; RUN: not --crash llc -mtriple=x86_64 %t/bad.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=BAD
; RUN: not --crash llc -mtriple=i386-pc-linux-code16 %t/good.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64 %t/xray.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=XRAY
;
; An original branch's bank effect survives even when the branch folds away.
; Compiler-created branches preserve the bank. Initialize emits unprefixed E9
; to the next instruction: shortening to EB would lose BNDINIT.
;
; ASM-LABEL: preserve:
; ASM-NOT: jmp
; ASM: repne{{[ \t]+}}ret
; ASM-LABEL: initialize:
; ASM: movb $1,
; ASM: {disp32}{{[ \t]+}}jmp
; ASM: {disp32}{{[ \t]+}}jmp
; ASM: movb $2,
; ASM: repne{{[ \t]+}}ret
; IR-LABEL: define void @initialize
; IR: store volatile i8 1
; IR: call void @llvm.x86.bnd.branch(i32 0)
; IR-NEXT: call void @llvm.x86.bnd.branch(i32 0)
; IR-NEXT: store volatile i8 2
; BYTES-LABEL: <{{_?}}preserve>:
; BYTES-NEXT: {{.*}}f2 c3{{[ \t]+}}repne
; BYTES-LABEL: <{{_?}}initialize>:
; BYTES: e9 00 00 00 00
; BYTES-NEXT: {{.*}}e9 00 00 00 00
; BYTES: f2 c3
; BAD: MPX branch kind must be a constant in [0, 1]
; MODE: MPX branch intrinsic requires 32- or 64-bit mode
; XRAY: MPX bounds state cannot be combined with XRay sleds

;--- good.ll
declare void @llvm.x86.bnd.branch(i32 immarg)

define void @preserve() {
  call void @llvm.x86.bnd.branch(i32 1)
  ret void
}

define void @initialize(ptr %memory, i1 %condition) {
  store volatile i8 1, ptr %memory
  call void @llvm.x86.bnd.branch(i32 0)
  br i1 %condition, label %done, label %done
done:
  call void @llvm.x86.bnd.branch(i32 0)
  store volatile i8 2, ptr %memory
  ret void
}

;--- bad.ll
declare void @llvm.x86.bnd.branch(i32 immarg)
define void @invalid() {
  call void @llvm.x86.bnd.branch(i32 256)
  ret void
}

;--- xray.ll
declare void @llvm.x86.bnd.branch(i32 immarg)
define void @invalid() "function-instrument"="xray-always" {
  call void @llvm.x86.bnd.branch(i32 1)
  ret void
}
