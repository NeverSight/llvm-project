; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs < %t/wide.ll | FileCheck %s --check-prefix=WIDE
; RUN: llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs < %t/narrow.ll | FileCheck %s --check-prefix=NARROW
; RUN: llc -mtriple=x86_64-pc-windows-msvc -verify-machineinstrs -filetype=obj < %t/wide.ll -o %t/wide.obj
; RUN: llc -mtriple=x86_64-apple-darwin -verify-machineinstrs -filetype=obj < %t/wide.ll -o %t/wide.macho
; RUN: opt -S '-passes=default<O2>' %t/wide.ll | FileCheck %s --check-prefix=ORDER
; RUN: not --crash llc -mtriple=i386 %t/wide.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64 %t/bad-register.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=REGISTER
; RUN: not --crash llc -mtriple=x86_64 %t/bad-width.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=WIDTH
; RUN: not --crash llc -mtriple=x86_64 %t/bad-segment.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=SEGMENT
; RUN: not --crash llc -mtriple=x86_64 %t/xray.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=XRAY
;
; Bounds are architectural state, not v2i64 values. No ordinary loads or stores
; replace native bounds-table access, and neither a dead nor repeated check may
; disappear. MPX ignores 67H in long mode, so the complete base/index survives.
; Compiler-created branches preserve the bounds bank even if BNDPRESERVE=0.
;
; MODE: MPX intrinsic does not match the target code mode
; REGISTER: MPX bounds register must be a constant in [0, 3]
; WIDTH: invalid MPX address encoding width for this code mode
; SEGMENT: invalid MPX segment prefix
; XRAY: MPX bounds state cannot be combined with XRay sleds
;
; WIDE-LABEL: bank:
; WIDE: bndmk
; WIDE: bndmov
; WIDE: bndmov
; WIDE: bndcl
; WIDE: bndcu
; WIDE: bndcn
; WIDE: bndcl
; WIDE: bndcu
; WIDE: bndcn
; WIDE: bndldx
; WIDE: bndstx
; WIDE: bndmov
; WIDE: lock
; WIDE: bndcl
; WIDE: bndcl
; WIDE: repne{{[ \t]+}}ret
; NARROW-LABEL: bank:
; NARROW: bndmk
; NARROW: bndmov
; NARROW: bndmov
; NARROW: bndcl
; NARROW: bndcu
; NARROW: bndcn
; NARROW: bndcl
; NARROW: bndcu
; NARROW: bndcn
; NARROW: bndldx
; NARROW: bndstx
; NARROW: bndmov
; NARROW: lock
; NARROW: bndcl
; NARROW: bndcl
; NARROW: repne{{[ \t]+}}ret
; WIDE-LABEL: narrow_encoding:
; WIDE: movq %rdi, %r[[CARRIER:ax|bx|cx|dx]]
; WIDE-NOT: movl
; WIDE: bndcl %fs:(%e[[CARRIER]]), %bnd2
; WIDE: repne{{[ \t]+}}ret
; WIDE-LABEL: across_branch:
; WIDE: bndmov
; WIDE: repne{{[ \t]+}}j
; WIDE: bndmov
; WIDE: repne{{[ \t]+}}ret
; ORDER-LABEL: define void @bank
; ORDER: store volatile i8 1
; ORDER: call void @llvm.x86.bndcl.reg(i32 1,
; ORDER-NEXT: call void @llvm.x86.bndcl.reg(i32 1,
; ORDER-NEXT: store volatile i8 2
;
;--- wide.ll
declare void @llvm.x86.bndmk(i32, i64, i64, i32, i32)
declare void @llvm.x86.bndmov.load(i32, i64, i32, i32)
declare void @llvm.x86.bndmov.reg(i32, i32)
declare void @llvm.x86.bndcl.reg(i32, i64)
declare void @llvm.x86.bndcu.reg(i32, i64)
declare void @llvm.x86.bndcn.reg(i32, i64)
declare void @llvm.x86.bndcl.address(i32, i64, i32, i32)
declare void @llvm.x86.bndcu.address(i32, i64, i32, i32)
declare void @llvm.x86.bndcn.address(i32, i64, i32, i32)
declare void @llvm.x86.bndldx(i32, i64, i64, i32, i32)
declare void @llvm.x86.bndstx(i32, i64, i64, i32, i32)
declare void @llvm.x86.bndmov.store(i32, i64, i32, i32)
declare void @llvm.x86.bndmov.store.lock(i32, i64, i32, i32)

define void @bank(i64 %base, i64 %value, ptr %memory) {
  call void @llvm.x86.bndmk(i32 0, i64 %base, i64 %value, i32 64, i32 0)
  call void @llvm.x86.bndmov.load(i32 1, i64 %base, i32 64, i32 101)
  call void @llvm.x86.bndmov.reg(i32 1, i32 0)
  call void @llvm.x86.bndcl.reg(i32 1, i64 %value)
  call void @llvm.x86.bndcu.reg(i32 1, i64 %value)
  call void @llvm.x86.bndcn.reg(i32 1, i64 %value)
  call void @llvm.x86.bndcl.address(i32 1, i64 %base, i32 64, i32 101)
  call void @llvm.x86.bndcu.address(i32 1, i64 %base, i32 64, i32 101)
  call void @llvm.x86.bndcn.address(i32 1, i64 %base, i32 64, i32 101)
  call void @llvm.x86.bndldx(i32 0, i64 %base, i64 %value, i32 64, i32 0)
  call void @llvm.x86.bndstx(i32 0, i64 %base, i64 %value, i32 64, i32 0)
  call void @llvm.x86.bndmov.store(i32 1, i64 %base, i32 64, i32 101)
  call void @llvm.x86.bndmov.store.lock(i32 1, i64 %base, i32 64, i32 101)
  store volatile i8 1, ptr %memory
  call void @llvm.x86.bndcl.reg(i32 1, i64 %value)
  call void @llvm.x86.bndcl.reg(i32 1, i64 %value)
  store volatile i8 2, ptr %memory
  ret void
}

define void @narrow_encoding(i64 %base) {
  call void @llvm.x86.bndcl.address(i32 2, i64 %base, i32 32, i32 100)
  ret void
}

define void @across_branch(i64 %base, ptr %predicate) {
  call void @llvm.x86.bndmov.load(i32 2, i64 %base, i32 64, i32 0)
  %value = load volatile i8, ptr %predicate
  %test = icmp ne i8 %value, 0
  br i1 %test, label %copy, label %done
copy:
  call void @llvm.x86.bndmov.reg(i32 3, i32 2)
  br label %done
done:
  ret void
}

;--- narrow.ll
declare void @llvm.x86.bndmk32(i32, i32, i32, i32, i32)
declare void @llvm.x86.bndmov.load32(i32, i32, i32, i32)
declare void @llvm.x86.bndmov.reg(i32, i32)
declare void @llvm.x86.bndcl.reg32(i32, i32)
declare void @llvm.x86.bndcu.reg32(i32, i32)
declare void @llvm.x86.bndcn.reg32(i32, i32)
declare void @llvm.x86.bndcl.address32(i32, i32, i32, i32)
declare void @llvm.x86.bndcu.address32(i32, i32, i32, i32)
declare void @llvm.x86.bndcn.address32(i32, i32, i32, i32)
declare void @llvm.x86.bndldx32(i32, i32, i32, i32, i32)
declare void @llvm.x86.bndstx32(i32, i32, i32, i32, i32)
declare void @llvm.x86.bndmov.store32(i32, i32, i32, i32)
declare void @llvm.x86.bndmov.store.lock32(i32, i32, i32, i32)

define void @bank(i32 %base, i32 %value, ptr %memory) {
  call void @llvm.x86.bndmk32(i32 0, i32 %base, i32 %value, i32 32, i32 0)
  call void @llvm.x86.bndmov.load32(i32 1, i32 %base, i32 32, i32 101)
  call void @llvm.x86.bndmov.reg(i32 1, i32 0)
  call void @llvm.x86.bndcl.reg32(i32 1, i32 %value)
  call void @llvm.x86.bndcu.reg32(i32 1, i32 %value)
  call void @llvm.x86.bndcn.reg32(i32 1, i32 %value)
  call void @llvm.x86.bndcl.address32(i32 1, i32 %base, i32 32, i32 101)
  call void @llvm.x86.bndcu.address32(i32 1, i32 %base, i32 32, i32 101)
  call void @llvm.x86.bndcn.address32(i32 1, i32 %base, i32 32, i32 101)
  call void @llvm.x86.bndldx32(i32 0, i32 %base, i32 %value, i32 32, i32 0)
  call void @llvm.x86.bndstx32(i32 0, i32 %base, i32 %value, i32 32, i32 0)
  call void @llvm.x86.bndmov.store32(i32 1, i32 %base, i32 32, i32 101)
  call void @llvm.x86.bndmov.store.lock32(i32 1, i32 %base, i32 32, i32 101)
  store volatile i8 1, ptr %memory
  call void @llvm.x86.bndcl.reg32(i32 1, i32 %value)
  call void @llvm.x86.bndcl.reg32(i32 1, i32 %value)
  store volatile i8 2, ptr %memory
  ret void
}

;--- bad-register.ll
declare void @llvm.x86.bndmov.reg(i32, i32)
define void @bad() {
  call void @llvm.x86.bndmov.reg(i32 256, i32 0)
  ret void
}
;--- bad-width.ll
declare void @llvm.x86.bndmov.load(i32, i64, i32, i32)
define void @bad(i64 %base) {
  call void @llvm.x86.bndmov.load(i32 0, i64 %base, i32 16, i32 0)
  ret void
}
;--- bad-segment.ll
declare void @llvm.x86.bndmov.load(i32, i64, i32, i32)
define void @bad(i64 %base) {
  call void @llvm.x86.bndmov.load(i32 0, i64 %base, i32 64, i32 128)
  ret void
}

;--- xray.ll
declare void @llvm.x86.bndmov.reg(i32, i32)
define void @bad() "function-instrument"="xray-always" {
  call void @llvm.x86.bndmov.reg(i32 0, i32 1)
  ret void
}
