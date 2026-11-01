; RUN: split-file %s %t
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: llc -mtriple=i686-pc-windows-msvc -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=i686-pc-windows-msvc -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: llc -mtriple=i386-apple-darwin -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=i386-apple-darwin -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/wide.ll | FileCheck %s --check-prefix=WIDE --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/wide.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=WIDE --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=x86_64-pc-windows-msvc -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs < %t/wide.ll | FileCheck %s --check-prefix=WIDE --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/wide.ll | llc -mtriple=x86_64-pc-windows-msvc -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=WIDE --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=x86_64-apple-darwin -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs < %t/wide.ll | FileCheck %s --check-prefix=WIDE --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/wide.ll | llc -mtriple=x86_64-apple-darwin -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=WIDE --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: llc -mtriple=x86_64-unknown-linux-gnux32 -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=x86_64-unknown-linux-gnux32 -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=COMMON --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: llc -mtriple=x86_64-unknown-linux-gnux32 -O0 -verify-machineinstrs < %t/wide.ll | FileCheck %s --check-prefix=WIDE --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes='default<O2>' %t/wide.ll | llc -mtriple=x86_64-unknown-linux-gnux32 -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=WIDE --implicit-check-not="#APP" --implicit-check-not="call"
; RUN: opt -S -passes=verify %t/common.ll | FileCheck %s --check-prefix=ATTR
; RUN: not --crash llc -mtriple=i386 %t/wide.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386 -mattr=+16bit-mode,-32bit-mode %t/common.ll 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not opt -passes=verify -disable-output %t/bad.ll 2>&1 | FileCheck %s --check-prefix=BAD
; MODE: native division intrinsic does not match target code mode
; BAD: intrinsic argument 0 type expected i8, but got i16
; ATTR: declare { i8, i8 } @llvm.x86.udivrem8(i8, i8, i8) #[[A:[0-9]+]]
; ATTR: attributes #[[A]] = { convergent noduplicate nounwind }
; COMMON-LABEL: probe_udivrem8:
; COMMON: movb $17,
; COMMON: divb
; COMMON: movb $23,
; COMMON: divb
; COMMON: movb $29,
; COMMON: ret
; COMMON-LABEL: probe_sdivrem8:
; COMMON: movb $17,
; COMMON: idivb
; COMMON: movb $23,
; COMMON: idivb
; COMMON: movb $29,
; COMMON: ret
; COMMON-LABEL: probe_udivrem16:
; COMMON: movb $17,
; COMMON: divw
; COMMON: movb $23,
; COMMON: divw
; COMMON: movb $29,
; COMMON: ret
; COMMON-LABEL: probe_sdivrem16:
; COMMON: movb $17,
; COMMON: idivw
; COMMON: movb $23,
; COMMON: idivw
; COMMON: movb $29,
; COMMON: ret
; COMMON-LABEL: probe_udivrem32:
; COMMON: movb $17,
; COMMON: divl
; COMMON: movb $23,
; COMMON: divl
; COMMON: movb $29,
; COMMON: ret
; COMMON-LABEL: probe_sdivrem32:
; COMMON: movb $17,
; COMMON: idivl
; COMMON: movb $23,
; COMMON: idivl
; COMMON: movb $29,
; COMMON: ret
; WIDE-LABEL: probe_udivrem64:
; WIDE: movb $17,
; WIDE: divq
; WIDE: movb $23,
; WIDE: divq
; WIDE: movb $29,
; WIDE: ret
; WIDE-LABEL: probe_sdivrem64:
; WIDE: movb $17,
; WIDE: idivq
; WIDE: movb $23,
; WIDE: idivq
; WIDE: movb $29,
; WIDE: ret

;--- common.ll
declare { i8, i8 } @llvm.x86.udivrem8(i8, i8, i8)
define { i8, i8 } @probe_udivrem8(i8 %low, i8 %high, i8 %divisor, ptr %marker) {
  store i8 17, ptr %marker
  %unused = call { i8, i8 } @llvm.x86.udivrem8(i8 %low, i8 %high, i8 %divisor)
  store i8 23, ptr %marker
  %result = call { i8, i8 } @llvm.x86.udivrem8(i8 %low, i8 %high, i8 %divisor)
  store i8 29, ptr %marker
  ret { i8, i8 } %result
}
declare { i8, i8 } @llvm.x86.sdivrem8(i8, i8, i8)
define { i8, i8 } @probe_sdivrem8(i8 %low, i8 %high, i8 %divisor, ptr %marker) {
  store i8 17, ptr %marker
  %unused = call { i8, i8 } @llvm.x86.sdivrem8(i8 %low, i8 %high, i8 %divisor)
  store i8 23, ptr %marker
  %result = call { i8, i8 } @llvm.x86.sdivrem8(i8 %low, i8 %high, i8 %divisor)
  store i8 29, ptr %marker
  ret { i8, i8 } %result
}
declare { i16, i16 } @llvm.x86.udivrem16(i16, i16, i16)
define { i16, i16 } @probe_udivrem16(i16 %low, i16 %high, i16 %divisor, ptr %marker) {
  store i8 17, ptr %marker
  %unused = call { i16, i16 } @llvm.x86.udivrem16(i16 %low, i16 %high, i16 %divisor)
  store i8 23, ptr %marker
  %result = call { i16, i16 } @llvm.x86.udivrem16(i16 %low, i16 %high, i16 %divisor)
  store i8 29, ptr %marker
  ret { i16, i16 } %result
}
declare { i16, i16 } @llvm.x86.sdivrem16(i16, i16, i16)
define { i16, i16 } @probe_sdivrem16(i16 %low, i16 %high, i16 %divisor, ptr %marker) {
  store i8 17, ptr %marker
  %unused = call { i16, i16 } @llvm.x86.sdivrem16(i16 %low, i16 %high, i16 %divisor)
  store i8 23, ptr %marker
  %result = call { i16, i16 } @llvm.x86.sdivrem16(i16 %low, i16 %high, i16 %divisor)
  store i8 29, ptr %marker
  ret { i16, i16 } %result
}
declare { i32, i32 } @llvm.x86.udivrem32(i32, i32, i32)
define { i32, i32 } @probe_udivrem32(i32 %low, i32 %high, i32 %divisor, ptr %marker) {
  store i8 17, ptr %marker
  %unused = call { i32, i32 } @llvm.x86.udivrem32(i32 %low, i32 %high, i32 %divisor)
  store i8 23, ptr %marker
  %result = call { i32, i32 } @llvm.x86.udivrem32(i32 %low, i32 %high, i32 %divisor)
  store i8 29, ptr %marker
  ret { i32, i32 } %result
}
declare { i32, i32 } @llvm.x86.sdivrem32(i32, i32, i32)
define { i32, i32 } @probe_sdivrem32(i32 %low, i32 %high, i32 %divisor, ptr %marker) {
  store i8 17, ptr %marker
  %unused = call { i32, i32 } @llvm.x86.sdivrem32(i32 %low, i32 %high, i32 %divisor)
  store i8 23, ptr %marker
  %result = call { i32, i32 } @llvm.x86.sdivrem32(i32 %low, i32 %high, i32 %divisor)
  store i8 29, ptr %marker
  ret { i32, i32 } %result
}

;--- wide.ll
declare { i64, i64 } @llvm.x86.udivrem64(i64, i64, i64)
define { i64, i64 } @probe_udivrem64(i64 %low, i64 %high, i64 %divisor, ptr %marker) {
  store i8 17, ptr %marker
  %unused = call { i64, i64 } @llvm.x86.udivrem64(i64 %low, i64 %high, i64 %divisor)
  store i8 23, ptr %marker
  %result = call { i64, i64 } @llvm.x86.udivrem64(i64 %low, i64 %high, i64 %divisor)
  store i8 29, ptr %marker
  ret { i64, i64 } %result
}
declare { i64, i64 } @llvm.x86.sdivrem64(i64, i64, i64)
define { i64, i64 } @probe_sdivrem64(i64 %low, i64 %high, i64 %divisor, ptr %marker) {
  store i8 17, ptr %marker
  %unused = call { i64, i64 } @llvm.x86.sdivrem64(i64 %low, i64 %high, i64 %divisor)
  store i8 23, ptr %marker
  %result = call { i64, i64 } @llvm.x86.sdivrem64(i64 %low, i64 %high, i64 %divisor)
  store i8 29, ptr %marker
  ret { i64, i64 } %result
}

;--- bad.ll
declare { i8, i8 } @llvm.x86.udivrem8(i16, i8, i8)
define void @bad() {
  %pair = call { i8, i8 } @llvm.x86.udivrem8(i16 0, i8 1, i8 1)
  ret void
}
