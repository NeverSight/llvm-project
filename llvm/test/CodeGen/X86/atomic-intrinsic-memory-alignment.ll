; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+raoint,+cmpccxadd -verify-machineinstrs -stop-after=finalize-isel < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+raoint,+cmpccxadd,+egpr -verify-machineinstrs -stop-after=finalize-isel < %s | FileCheck %s
; RUN: llc -O0 -mtriple=x86_64-unknown-linux-gnu -mattr=+raoint,+cmpccxadd -verify-machineinstrs -stop-after=finalize-isel < %s | FileCheck %s
;
; An unqualified pointer is not a promise of alignment in bytes equal to the
; integer width in bits. Keep native memory effects and let hardware perform
; any alignment/permission checks. Include register-indexed bit strings and
; arithmetic intrinsics, which share the target memory-info path with RAO.

declare void @llvm.x86.aadd32(ptr, i32)
define void @aadd32(ptr %address, i32 %source) {
; CHECK-LABEL: name: aadd32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  call void @llvm.x86.aadd32(ptr %address, i32 %source)
  ret void
}

declare void @llvm.x86.aand32(ptr, i32)
define void @aand32(ptr %address, i32 %source) {
; CHECK-LABEL: name: aand32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  call void @llvm.x86.aand32(ptr %address, i32 %source)
  ret void
}

declare void @llvm.x86.aor32(ptr, i32)
define void @aor32(ptr %address, i32 %source) {
; CHECK-LABEL: name: aor32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  call void @llvm.x86.aor32(ptr %address, i32 %source)
  ret void
}

declare void @llvm.x86.axor32(ptr, i32)
define void @axor32(ptr %address, i32 %source) {
; CHECK-LABEL: name: axor32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  call void @llvm.x86.axor32(ptr %address, i32 %source)
  ret void
}

declare void @llvm.x86.aadd64(ptr, i64)
define void @aadd64(ptr %address, i64 %source) {
; CHECK-LABEL: name: aadd64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  call void @llvm.x86.aadd64(ptr %address, i64 %source)
  ret void
}

declare void @llvm.x86.aand64(ptr, i64)
define void @aand64(ptr %address, i64 %source) {
; CHECK-LABEL: name: aand64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  call void @llvm.x86.aand64(ptr %address, i64 %source)
  ret void
}

declare void @llvm.x86.aor64(ptr, i64)
define void @aor64(ptr %address, i64 %source) {
; CHECK-LABEL: name: aor64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  call void @llvm.x86.aor64(ptr %address, i64 %source)
  ret void
}

declare void @llvm.x86.axor64(ptr, i64)
define void @axor64(ptr %address, i64 %source) {
; CHECK-LABEL: name: axor64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  call void @llvm.x86.axor64(ptr %address, i64 %source)
  ret void
}

declare i32 @llvm.x86.cmpccxadd32(ptr, i32, i32, i32)
define i32 @compare32(ptr %address, i32 %source) {
; CHECK-LABEL: name: compare32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i32 @llvm.x86.cmpccxadd32(ptr %address, i32 %source, i32 %source, i32 4)
  ret i32 %old
}

declare i64 @llvm.x86.cmpccxadd64(ptr, i64, i64, i32)
define i64 @compare64(ptr %address, i64 %source) {
; CHECK-LABEL: name: compare64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i64 @llvm.x86.cmpccxadd64(ptr %address, i64 %source, i64 %source, i32 4)
  ret i64 %old
}

declare i16 @llvm.x86.atomic.bts.i16(ptr, i8)
define i16 @bts16(ptr %address, i16 %source) {
; CHECK-LABEL: name: bts16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i16 @llvm.x86.atomic.bts.i16(ptr %address, i8 3)
  ret i16 %old
}

declare i8 @llvm.x86.atomic.bts.rm.i16(ptr, i16)
define i8 @bts_rm16(ptr %address, i16 %source) {
; CHECK-LABEL: name: bts_rm16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.bts.rm.i16(ptr %address, i16 %source)
  ret i8 %old
}

declare i16 @llvm.x86.atomic.btc.i16(ptr, i8)
define i16 @btc16(ptr %address, i16 %source) {
; CHECK-LABEL: name: btc16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i16 @llvm.x86.atomic.btc.i16(ptr %address, i8 3)
  ret i16 %old
}

declare i8 @llvm.x86.atomic.btc.rm.i16(ptr, i16)
define i8 @btc_rm16(ptr %address, i16 %source) {
; CHECK-LABEL: name: btc_rm16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.btc.rm.i16(ptr %address, i16 %source)
  ret i8 %old
}

declare i16 @llvm.x86.atomic.btr.i16(ptr, i8)
define i16 @btr16(ptr %address, i16 %source) {
; CHECK-LABEL: name: btr16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i16 @llvm.x86.atomic.btr.i16(ptr %address, i8 3)
  ret i16 %old
}

declare i8 @llvm.x86.atomic.btr.rm.i16(ptr, i16)
define i8 @btr_rm16(ptr %address, i16 %source) {
; CHECK-LABEL: name: btr_rm16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.btr.rm.i16(ptr %address, i16 %source)
  ret i8 %old
}

declare i32 @llvm.x86.atomic.bts.i32(ptr, i8)
define i32 @bts32(ptr %address, i32 %source) {
; CHECK-LABEL: name: bts32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i32 @llvm.x86.atomic.bts.i32(ptr %address, i8 3)
  ret i32 %old
}

declare i8 @llvm.x86.atomic.bts.rm.i32(ptr, i32)
define i8 @bts_rm32(ptr %address, i32 %source) {
; CHECK-LABEL: name: bts_rm32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.bts.rm.i32(ptr %address, i32 %source)
  ret i8 %old
}

declare i32 @llvm.x86.atomic.btc.i32(ptr, i8)
define i32 @btc32(ptr %address, i32 %source) {
; CHECK-LABEL: name: btc32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i32 @llvm.x86.atomic.btc.i32(ptr %address, i8 3)
  ret i32 %old
}

declare i8 @llvm.x86.atomic.btc.rm.i32(ptr, i32)
define i8 @btc_rm32(ptr %address, i32 %source) {
; CHECK-LABEL: name: btc_rm32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.btc.rm.i32(ptr %address, i32 %source)
  ret i8 %old
}

declare i32 @llvm.x86.atomic.btr.i32(ptr, i8)
define i32 @btr32(ptr %address, i32 %source) {
; CHECK-LABEL: name: btr32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i32 @llvm.x86.atomic.btr.i32(ptr %address, i8 3)
  ret i32 %old
}

declare i8 @llvm.x86.atomic.btr.rm.i32(ptr, i32)
define i8 @btr_rm32(ptr %address, i32 %source) {
; CHECK-LABEL: name: btr_rm32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.btr.rm.i32(ptr %address, i32 %source)
  ret i8 %old
}

declare i64 @llvm.x86.atomic.bts.i64(ptr, i8)
define i64 @bts64(ptr %address, i64 %source) {
; CHECK-LABEL: name: bts64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i64 @llvm.x86.atomic.bts.i64(ptr %address, i8 3)
  ret i64 %old
}

declare i8 @llvm.x86.atomic.bts.rm.i64(ptr, i64)
define i8 @bts_rm64(ptr %address, i64 %source) {
; CHECK-LABEL: name: bts_rm64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.bts.rm.i64(ptr %address, i64 %source)
  ret i8 %old
}

declare i64 @llvm.x86.atomic.btc.i64(ptr, i8)
define i64 @btc64(ptr %address, i64 %source) {
; CHECK-LABEL: name: btc64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i64 @llvm.x86.atomic.btc.i64(ptr %address, i8 3)
  ret i64 %old
}

declare i8 @llvm.x86.atomic.btc.rm.i64(ptr, i64)
define i8 @btc_rm64(ptr %address, i64 %source) {
; CHECK-LABEL: name: btc_rm64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.btc.rm.i64(ptr %address, i64 %source)
  ret i8 %old
}

declare i64 @llvm.x86.atomic.btr.i64(ptr, i8)
define i64 @btr64(ptr %address, i64 %source) {
; CHECK-LABEL: name: btr64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i64 @llvm.x86.atomic.btr.i64(ptr %address, i8 3)
  ret i64 %old
}

declare i8 @llvm.x86.atomic.btr.rm.i64(ptr, i64)
define i8 @btr_rm64(ptr %address, i64 %source) {
; CHECK-LABEL: name: btr_rm64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.btr.rm.i64(ptr %address, i64 %source)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.add.cc.i8(ptr, i8, i32)
define i8 @add8(ptr %address, i8 %source) {
; CHECK-LABEL: name: add8
; CHECK: :: (volatile load store (s8) on %ir.address)
  %old = call i8 @llvm.x86.atomic.add.cc.i8(ptr %address, i8 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.sub.cc.i8(ptr, i8, i32)
define i8 @sub8(ptr %address, i8 %source) {
; CHECK-LABEL: name: sub8
; CHECK: :: (volatile load store (s8) on %ir.address)
  %old = call i8 @llvm.x86.atomic.sub.cc.i8(ptr %address, i8 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.and.cc.i8(ptr, i8, i32)
define i8 @and8(ptr %address, i8 %source) {
; CHECK-LABEL: name: and8
; CHECK: :: (volatile load store (s8) on %ir.address)
  %old = call i8 @llvm.x86.atomic.and.cc.i8(ptr %address, i8 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.or.cc.i8(ptr, i8, i32)
define i8 @or8(ptr %address, i8 %source) {
; CHECK-LABEL: name: or8
; CHECK: :: (volatile load store (s8) on %ir.address)
  %old = call i8 @llvm.x86.atomic.or.cc.i8(ptr %address, i8 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.xor.cc.i8(ptr, i8, i32)
define i8 @xor8(ptr %address, i8 %source) {
; CHECK-LABEL: name: xor8
; CHECK: :: (volatile load store (s8) on %ir.address)
  %old = call i8 @llvm.x86.atomic.xor.cc.i8(ptr %address, i8 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.add.cc.i16(ptr, i16, i32)
define i8 @add16(ptr %address, i16 %source) {
; CHECK-LABEL: name: add16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.add.cc.i16(ptr %address, i16 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.sub.cc.i16(ptr, i16, i32)
define i8 @sub16(ptr %address, i16 %source) {
; CHECK-LABEL: name: sub16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.sub.cc.i16(ptr %address, i16 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.and.cc.i16(ptr, i16, i32)
define i8 @and16(ptr %address, i16 %source) {
; CHECK-LABEL: name: and16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.and.cc.i16(ptr %address, i16 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.or.cc.i16(ptr, i16, i32)
define i8 @or16(ptr %address, i16 %source) {
; CHECK-LABEL: name: or16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.or.cc.i16(ptr %address, i16 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.xor.cc.i16(ptr, i16, i32)
define i8 @xor16(ptr %address, i16 %source) {
; CHECK-LABEL: name: xor16
; CHECK: :: (volatile load store (s16) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.xor.cc.i16(ptr %address, i16 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.add.cc.i32(ptr, i32, i32)
define i8 @add32(ptr %address, i32 %source) {
; CHECK-LABEL: name: add32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.add.cc.i32(ptr %address, i32 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.sub.cc.i32(ptr, i32, i32)
define i8 @sub32(ptr %address, i32 %source) {
; CHECK-LABEL: name: sub32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.sub.cc.i32(ptr %address, i32 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.and.cc.i32(ptr, i32, i32)
define i8 @and32(ptr %address, i32 %source) {
; CHECK-LABEL: name: and32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.and.cc.i32(ptr %address, i32 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.or.cc.i32(ptr, i32, i32)
define i8 @or32(ptr %address, i32 %source) {
; CHECK-LABEL: name: or32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.or.cc.i32(ptr %address, i32 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.xor.cc.i32(ptr, i32, i32)
define i8 @xor32(ptr %address, i32 %source) {
; CHECK-LABEL: name: xor32
; CHECK: :: (volatile load store (s32) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.xor.cc.i32(ptr %address, i32 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.add.cc.i64(ptr, i64, i32)
define i8 @add64(ptr %address, i64 %source) {
; CHECK-LABEL: name: add64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.add.cc.i64(ptr %address, i64 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.sub.cc.i64(ptr, i64, i32)
define i8 @sub64(ptr %address, i64 %source) {
; CHECK-LABEL: name: sub64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.sub.cc.i64(ptr %address, i64 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.and.cc.i64(ptr, i64, i32)
define i8 @and64(ptr %address, i64 %source) {
; CHECK-LABEL: name: and64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.and.cc.i64(ptr %address, i64 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.or.cc.i64(ptr, i64, i32)
define i8 @or64(ptr %address, i64 %source) {
; CHECK-LABEL: name: or64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.or.cc.i64(ptr %address, i64 %source, i32 4)
  ret i8 %old
}

declare i8 @llvm.x86.atomic.xor.cc.i64(ptr, i64, i32)
define i8 @xor64(ptr %address, i64 %source) {
; CHECK-LABEL: name: xor64
; CHECK: :: (volatile load store (s64) on %ir.address, align 1)
  %old = call i8 @llvm.x86.atomic.xor.cc.i64(ptr %address, i64 %source, i32 4)
  ret i8 %old
}
