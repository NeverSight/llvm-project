; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64 -verify-machineinstrs %t/valid.ll -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -filetype=obj %t/valid.ll -o %t/windows.obj
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs -filetype=obj %t/valid.ll -o %t/darwin.o
; RUN: not --crash llc -mtriple=x86_64 %t/mib.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash llc -mtriple=x86_64 %t/fs.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=INVALID
; RUN: not --crash llc -mtriple=i386 %t/narrow.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=INVALID
;
; 67H narrows the encoding, not MPX's address arithmetic. An unmodified RBP
; preserves SS provenance. Allocated carriers cannot replace a reserved RBX
; realignment base; the independent execution matrix verifies local canaries.
; INVALID: invalid MPX segment prefix or stack-reference control
; CHECK-LABEL: stack:
; CHECK: movq %rsp, %rbp
; CHECK: subq %rbp,
; CHECK: bndmov (%rbp,%r{{[abcd]x}}), %bnd0
; CHECK: bndmov %bnd1, (%ebp,%e{{[abcd]x}})
; CHECK: lock
; CHECK: bndmov %bnd2, %ss:(%rbp,%r{{[abcd]x}})
; CHECK: repne{{[ \t]+}}ret
; CHECK-LABEL: realigned:
; CHECK: movq %rsp, %rbx
; CHECK-NOT: movq %rdi, %rbx
; CHECK: bndmov
; CHECK-NOT: movq %rdi, %rbx
; CHECK: movzbl (%rbx),
; CHECK: repne{{[ \t]+}}ret

;--- valid.ll
declare void @llvm.x86.bndmov.load(i32, i64, i32, i32)
declare void @llvm.x86.bndmov.store(i32, i64, i32, i32)
declare void @llvm.x86.bndmov.store.lock(i32, i64, i32, i32)
define void @stack(i64 %p) {
  call void @llvm.x86.bndmov.load(i32 0, i64 %p, i32 64, i32 256)
  call void @llvm.x86.bndmov.store(i32 1, i64 %p, i32 32, i32 256)
  call void @llvm.x86.bndmov.store.lock(i32 2, i64 %p, i32 64, i32 310)
  ret void
}
define i8 @realigned(i64 %p, i64 %n) {
  %fixed = alloca [64 x i8], align 64
  %dynamic = alloca i8, i64 %n, align 16
  store volatile i8 33, ptr %fixed
  store volatile i8 44, ptr %dynamic
  call void @llvm.x86.bndmov.load(i32 0, i64 %p, i32 64, i32 0)
  %a = load volatile i8, ptr %fixed
  %b = load volatile i8, ptr %dynamic
  %result = add i8 %a, %b
  ret i8 %result
}
;--- mib.ll
declare void @llvm.x86.bndldx(i32, i64, i64, i32, i32)
define void @mib(i64 %base, i64 %value) {
  call void @llvm.x86.bndldx(i32 0, i64 %base, i64 %value, i32 64, i32 256)
  ret void
}
;--- fs.ll
declare void @llvm.x86.bndmov.load(i32, i64, i32, i32)
define void @fs(i64 %p) {
  call void @llvm.x86.bndmov.load(i32 0, i64 %p, i32 64, i32 356)
  ret void
}
;--- narrow.ll
declare void @llvm.x86.bndmov.load32(i32, i32, i32, i32)
define void @narrow(i32 %p) {
  call void @llvm.x86.bndmov.load32(i32 0, i32 %p, i32 32, i32 256)
  ret void
}
