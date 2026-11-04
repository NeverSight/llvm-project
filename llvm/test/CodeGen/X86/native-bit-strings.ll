; Native signed-index bit strings retain the full memory operation and CF.
; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/legacy.ll | FileCheck %s --check-prefix=LEGACY
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %t/legacy.ll | FileCheck %s --check-prefix=LEGACY
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/legacy.ll | FileCheck %s --check-prefix=LEGACY
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs < %t/legacy.ll | FileCheck %s --check-prefix=LEGACY
; RUN: llc -mtriple=i386-unknown-linux-code16 -O0 -verify-machineinstrs < %t/legacy.ll | FileCheck %s --check-prefix=LEGACY
; RUN: llc -mtriple=i386-unknown-linux-code16 -O2 -verify-machineinstrs < %t/legacy.ll | FileCheck %s --check-prefix=LEGACY
; RUN: llc -mtriple=x86_64 -O0 -verify-machineinstrs < %t/wide.ll | FileCheck %s --check-prefix=WIDE
; RUN: llc -mtriple=x86_64 -O2 -verify-machineinstrs < %t/wide.ll | FileCheck %s --check-prefix=WIDE
; RUN: opt -passes="default<O2>" -S < %t/legacy.ll | llc -mtriple=x86_64 -verify-machineinstrs | FileCheck %s --check-prefix=LEGACY
; RUN: not --crash llc -mtriple=i386 < %t/wide.ll 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: native bit test intrinsic does not match target code mode

;--- legacy.ll
declare i8 @llvm.x86.bt.mem16(ptr, i16)

; LEGACY-LABEL: bt16_live:
; LEGACY: btw
; LEGACY: setb
; LEGACY: ret
define i8 @bt16_live(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.bt.mem16(ptr %p, i16 %i)
  ret i8 %cf
}

; LEGACY-LABEL: bt16_dead:
; LEGACY: btw
; LEGACY: ret
define void @bt16_dead(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.bt.mem16(ptr %p, i16 %i)
  ret void
}

; LEGACY-LABEL: bt16_negative:
; LEGACY: btw
; LEGACY: setb
; LEGACY: ret
define i8 @bt16_negative(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.bt.mem16(ptr %p, i16 -1)
  ret i8 %cf
}
declare i8 @llvm.x86.bts.mem16(ptr, i16)

; LEGACY-LABEL: bts16_live:
; LEGACY: btsw
; LEGACY: setb
; LEGACY: ret
define i8 @bts16_live(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.bts.mem16(ptr %p, i16 %i)
  ret i8 %cf
}

; LEGACY-LABEL: bts16_dead:
; LEGACY: btsw
; LEGACY: ret
define void @bts16_dead(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.bts.mem16(ptr %p, i16 %i)
  ret void
}

; LEGACY-LABEL: bts16_negative:
; LEGACY: btsw
; LEGACY: setb
; LEGACY: ret
define i8 @bts16_negative(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.bts.mem16(ptr %p, i16 -1)
  ret i8 %cf
}
declare i8 @llvm.x86.btr.mem16(ptr, i16)

; LEGACY-LABEL: btr16_live:
; LEGACY: btrw
; LEGACY: setb
; LEGACY: ret
define i8 @btr16_live(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.btr.mem16(ptr %p, i16 %i)
  ret i8 %cf
}

; LEGACY-LABEL: btr16_dead:
; LEGACY: btrw
; LEGACY: ret
define void @btr16_dead(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.btr.mem16(ptr %p, i16 %i)
  ret void
}

; LEGACY-LABEL: btr16_negative:
; LEGACY: btrw
; LEGACY: setb
; LEGACY: ret
define i8 @btr16_negative(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.btr.mem16(ptr %p, i16 -1)
  ret i8 %cf
}
declare i8 @llvm.x86.btc.mem16(ptr, i16)

; LEGACY-LABEL: btc16_live:
; LEGACY: btcw
; LEGACY: setb
; LEGACY: ret
define i8 @btc16_live(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.btc.mem16(ptr %p, i16 %i)
  ret i8 %cf
}

; LEGACY-LABEL: btc16_dead:
; LEGACY: btcw
; LEGACY: ret
define void @btc16_dead(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.btc.mem16(ptr %p, i16 %i)
  ret void
}

; LEGACY-LABEL: btc16_negative:
; LEGACY: btcw
; LEGACY: setb
; LEGACY: ret
define i8 @btc16_negative(ptr %p, i16 %i) {
  %cf = call i8 @llvm.x86.btc.mem16(ptr %p, i16 -1)
  ret i8 %cf
}
declare i8 @llvm.x86.bt.mem32(ptr, i32)

; LEGACY-LABEL: bt32_live:
; LEGACY: btl
; LEGACY: setb
; LEGACY: ret
define i8 @bt32_live(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.bt.mem32(ptr %p, i32 %i)
  ret i8 %cf
}

; LEGACY-LABEL: bt32_dead:
; LEGACY: btl
; LEGACY: ret
define void @bt32_dead(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.bt.mem32(ptr %p, i32 %i)
  ret void
}

; LEGACY-LABEL: bt32_negative:
; LEGACY: btl
; LEGACY: setb
; LEGACY: ret
define i8 @bt32_negative(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.bt.mem32(ptr %p, i32 -1)
  ret i8 %cf
}
declare i8 @llvm.x86.bts.mem32(ptr, i32)

; LEGACY-LABEL: bts32_live:
; LEGACY: btsl
; LEGACY: setb
; LEGACY: ret
define i8 @bts32_live(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.bts.mem32(ptr %p, i32 %i)
  ret i8 %cf
}

; LEGACY-LABEL: bts32_dead:
; LEGACY: btsl
; LEGACY: ret
define void @bts32_dead(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.bts.mem32(ptr %p, i32 %i)
  ret void
}

; LEGACY-LABEL: bts32_negative:
; LEGACY: btsl
; LEGACY: setb
; LEGACY: ret
define i8 @bts32_negative(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.bts.mem32(ptr %p, i32 -1)
  ret i8 %cf
}
declare i8 @llvm.x86.btr.mem32(ptr, i32)

; LEGACY-LABEL: btr32_live:
; LEGACY: btrl
; LEGACY: setb
; LEGACY: ret
define i8 @btr32_live(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.btr.mem32(ptr %p, i32 %i)
  ret i8 %cf
}

; LEGACY-LABEL: btr32_dead:
; LEGACY: btrl
; LEGACY: ret
define void @btr32_dead(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.btr.mem32(ptr %p, i32 %i)
  ret void
}

; LEGACY-LABEL: btr32_negative:
; LEGACY: btrl
; LEGACY: setb
; LEGACY: ret
define i8 @btr32_negative(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.btr.mem32(ptr %p, i32 -1)
  ret i8 %cf
}
declare i8 @llvm.x86.btc.mem32(ptr, i32)

; LEGACY-LABEL: btc32_live:
; LEGACY: btcl
; LEGACY: setb
; LEGACY: ret
define i8 @btc32_live(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.btc.mem32(ptr %p, i32 %i)
  ret i8 %cf
}

; LEGACY-LABEL: btc32_dead:
; LEGACY: btcl
; LEGACY: ret
define void @btc32_dead(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.btc.mem32(ptr %p, i32 %i)
  ret void
}

; LEGACY-LABEL: btc32_negative:
; LEGACY: btcl
; LEGACY: setb
; LEGACY: ret
define i8 @btc32_negative(ptr %p, i32 %i) {
  %cf = call i8 @llvm.x86.btc.mem32(ptr %p, i32 -1)
  ret i8 %cf
}

;--- wide.ll
declare i8 @llvm.x86.bt.mem64(ptr, i64)

; WIDE-LABEL: bt64_live:
; WIDE: btq
; WIDE: setb
; WIDE: ret
define i8 @bt64_live(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.bt.mem64(ptr %p, i64 %i)
  ret i8 %cf
}

; WIDE-LABEL: bt64_dead:
; WIDE: btq
; WIDE: ret
define void @bt64_dead(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.bt.mem64(ptr %p, i64 %i)
  ret void
}

; WIDE-LABEL: bt64_negative:
; WIDE: btq
; WIDE: setb
; WIDE: ret
define i8 @bt64_negative(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.bt.mem64(ptr %p, i64 -1)
  ret i8 %cf
}
declare i8 @llvm.x86.bts.mem64(ptr, i64)

; WIDE-LABEL: bts64_live:
; WIDE: btsq
; WIDE: setb
; WIDE: ret
define i8 @bts64_live(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.bts.mem64(ptr %p, i64 %i)
  ret i8 %cf
}

; WIDE-LABEL: bts64_dead:
; WIDE: btsq
; WIDE: ret
define void @bts64_dead(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.bts.mem64(ptr %p, i64 %i)
  ret void
}

; WIDE-LABEL: bts64_negative:
; WIDE: btsq
; WIDE: setb
; WIDE: ret
define i8 @bts64_negative(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.bts.mem64(ptr %p, i64 -1)
  ret i8 %cf
}
declare i8 @llvm.x86.btr.mem64(ptr, i64)

; WIDE-LABEL: btr64_live:
; WIDE: btrq
; WIDE: setb
; WIDE: ret
define i8 @btr64_live(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.btr.mem64(ptr %p, i64 %i)
  ret i8 %cf
}

; WIDE-LABEL: btr64_dead:
; WIDE: btrq
; WIDE: ret
define void @btr64_dead(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.btr.mem64(ptr %p, i64 %i)
  ret void
}

; WIDE-LABEL: btr64_negative:
; WIDE: btrq
; WIDE: setb
; WIDE: ret
define i8 @btr64_negative(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.btr.mem64(ptr %p, i64 -1)
  ret i8 %cf
}
declare i8 @llvm.x86.btc.mem64(ptr, i64)

; WIDE-LABEL: btc64_live:
; WIDE: btcq
; WIDE: setb
; WIDE: ret
define i8 @btc64_live(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.btc.mem64(ptr %p, i64 %i)
  ret i8 %cf
}

; WIDE-LABEL: btc64_dead:
; WIDE: btcq
; WIDE: ret
define void @btc64_dead(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.btc.mem64(ptr %p, i64 %i)
  ret void
}

; WIDE-LABEL: btc64_negative:
; WIDE: btcq
; WIDE: setb
; WIDE: ret
define i8 @btc64_negative(ptr %p, i64 %i) {
  %cf = call i8 @llvm.x86.btc.mem64(ptr %p, i64 -1)
  ret i8 %cf
}
