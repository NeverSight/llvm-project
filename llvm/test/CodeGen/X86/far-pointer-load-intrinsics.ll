; RUN: split-file %s %t
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %t/legacy.ll | FileCheck %s --check-prefix=LEGACY
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/legacy.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=LEGACY
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %t/wide.ll | FileCheck %s --check-prefix=WIDE
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/wide.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=WIDE
; RUN: llc -mtriple=i686-pc-windows-msvc -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=i686-pc-windows-msvc -O0 -verify-machineinstrs < %t/legacy.ll | FileCheck %s --check-prefix=LEGACY
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=i686-pc-windows-msvc -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/legacy.ll | llc -mtriple=i686-pc-windows-msvc -O2 -verify-machineinstrs | FileCheck %s --check-prefix=LEGACY
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs < %t/wide.ll | FileCheck %s --check-prefix=WIDE
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/wide.ll | llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs | FileCheck %s --check-prefix=WIDE
; RUN: llc -mtriple=i386-apple-darwin -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=i386-apple-darwin -O0 -verify-machineinstrs < %t/legacy.ll | FileCheck %s --check-prefix=LEGACY
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/legacy.ll | llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs | FileCheck %s --check-prefix=LEGACY
; RUN: llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs < %t/common.ll | FileCheck %s --check-prefix=COMMON
; RUN: llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs < %t/wide.ll | FileCheck %s --check-prefix=WIDE
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs | FileCheck %s --check-prefix=COMMON
; RUN: opt -S -passes='default<O2>' %t/wide.ll | llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs | FileCheck %s --check-prefix=WIDE
; RUN: llc -mtriple=x86_64 -stop-after=finalize-isel -verify-machineinstrs -o - %t/common.ll | FileCheck %s --check-prefix=MIR
; RUN: opt -S -passes=verify %t/common.ll | FileCheck %s --check-prefix=ATTR
; RUN: not --crash llc -mtriple=x86_64 %t/legacy.ll 2>&1 | FileCheck %s --check-prefix=BADLEGACY
; RUN: not --crash llc -mtriple=i386 %t/bad-lfs.ll 2>&1 | FileCheck %s --check-prefix=BADWIDE
; RUN: not --crash llc -mtriple=i386 %t/bad-lgs.ll 2>&1 | FileCheck %s --check-prefix=BADWIDE
; RUN: not --crash llc -mtriple=i386 %t/bad-lss.ll 2>&1 | FileCheck %s --check-prefix=BADWIDE
; RUN: not --crash llc -mtriple=i386 -mattr=+16bit-mode,-32bit-mode %t/common.ll 2>&1 | FileCheck %s --check-prefix=BAD16
; RUN: not opt -passes=verify -disable-output %t/bad.ll 2>&1 | FileCheck %s --check-prefix=BADSIG

; BADLEGACY: LDS/LES intrinsic requires 32-bit code mode
; BADWIDE: 64-bit far-pointer load intrinsic requires 64-bit code mode
; BAD16: far-pointer load intrinsic requires 32- or 64-bit code mode
; BADSIG: intrinsic argument 0 type expected ptr, but got i64
; ATTR: declare i16 @llvm.x86.lss16(ptr) #[[A:[0-9]+]]
; ATTR: attributes #[[A]] = { nounwind }
; COMMON-LABEL: probe_lss16:
; COMMON: lssw
; COMMON: lssw
; COMMON: ret
; MIR: LSS16rm {{.*}}implicit-def{{( dead)?}} $ss {{.*}}volatile load (s32){{.*}}align 1
; COMMON-LABEL: probe_lss32:
; COMMON: lssl
; COMMON: lssl
; COMMON: ret
; MIR: LSS32rm {{.*}}implicit-def{{( dead)?}} $ss {{.*}}volatile load (s48){{.*}}align 1
; COMMON-LABEL: probe_lfs16:
; COMMON: lfsw
; COMMON: lfsw
; COMMON: ret
; MIR: LFS16rm {{.*}}implicit-def{{( dead)?}} $fs {{.*}}volatile load (s32){{.*}}align 1
; COMMON-LABEL: probe_lfs32:
; COMMON: lfsl
; COMMON: lfsl
; COMMON: ret
; MIR: LFS32rm {{.*}}implicit-def{{( dead)?}} $fs {{.*}}volatile load (s48){{.*}}align 1
; COMMON-LABEL: probe_lgs16:
; COMMON: lgsw
; COMMON: lgsw
; COMMON: ret
; MIR: LGS16rm {{.*}}implicit-def{{( dead)?}} $gs {{.*}}volatile load (s32){{.*}}align 1
; COMMON-LABEL: probe_lgs32:
; COMMON: lgsl
; COMMON: lgsl
; COMMON: ret
; MIR: LGS32rm {{.*}}implicit-def{{( dead)?}} $gs {{.*}}volatile load (s48){{.*}}align 1

;--- common.ll
declare i16 @llvm.x86.lss16(ptr)
define i16 @probe_lss16(ptr %p) {
  %first = call i16 @llvm.x86.lss16(ptr %p)
  %second = call i16 @llvm.x86.lss16(ptr %p)
  ret i16 %first
}
declare i32 @llvm.x86.lss32(ptr)
define i32 @probe_lss32(ptr %p) {
  %first = call i32 @llvm.x86.lss32(ptr %p)
  %second = call i32 @llvm.x86.lss32(ptr %p)
  ret i32 %first
}
declare i16 @llvm.x86.lfs16(ptr)
define i16 @probe_lfs16(ptr %p) {
  %first = call i16 @llvm.x86.lfs16(ptr %p)
  %second = call i16 @llvm.x86.lfs16(ptr %p)
  ret i16 %first
}
declare i32 @llvm.x86.lfs32(ptr)
define i32 @probe_lfs32(ptr %p) {
  %first = call i32 @llvm.x86.lfs32(ptr %p)
  %second = call i32 @llvm.x86.lfs32(ptr %p)
  ret i32 %first
}
declare i16 @llvm.x86.lgs16(ptr)
define i16 @probe_lgs16(ptr %p) {
  %first = call i16 @llvm.x86.lgs16(ptr %p)
  %second = call i16 @llvm.x86.lgs16(ptr %p)
  ret i16 %first
}
declare i32 @llvm.x86.lgs32(ptr)
define i32 @probe_lgs32(ptr %p) {
  %first = call i32 @llvm.x86.lgs32(ptr %p)
  %second = call i32 @llvm.x86.lgs32(ptr %p)
  ret i32 %first
}
; WIDE-LABEL: probe_lss64:
; WIDE: lssq
; WIDE: lssq
; WIDE: ret
; WIDE-LABEL: probe_lfs64:
; WIDE: lfsq
; WIDE: lfsq
; WIDE: ret
; WIDE-LABEL: probe_lgs64:
; WIDE: lgsq
; WIDE: lgsq
; WIDE: ret

;--- wide.ll
declare i64 @llvm.x86.lss64(ptr)
define i64 @probe_lss64(ptr %p) {
  %first = call i64 @llvm.x86.lss64(ptr %p)
  %second = call i64 @llvm.x86.lss64(ptr %p)
  ret i64 %first
}
declare i64 @llvm.x86.lfs64(ptr)
define i64 @probe_lfs64(ptr %p) {
  %first = call i64 @llvm.x86.lfs64(ptr %p)
  %second = call i64 @llvm.x86.lfs64(ptr %p)
  ret i64 %first
}
declare i64 @llvm.x86.lgs64(ptr)
define i64 @probe_lgs64(ptr %p) {
  %first = call i64 @llvm.x86.lgs64(ptr %p)
  %second = call i64 @llvm.x86.lgs64(ptr %p)
  ret i64 %first
}
; LEGACY-LABEL: probe_lds16:
; LEGACY: ldsw
; LEGACY: ldsw
; LEGACY: ret
; LEGACY-LABEL: probe_lds32:
; LEGACY: ldsl
; LEGACY: ldsl
; LEGACY: ret
; LEGACY-LABEL: probe_les16:
; LEGACY: lesw
; LEGACY: lesw
; LEGACY: ret
; LEGACY-LABEL: probe_les32:
; LEGACY: lesl
; LEGACY: lesl
; LEGACY: ret

;--- legacy.ll
declare i16 @llvm.x86.lds16(ptr)
define i16 @probe_lds16(ptr %p) {
  %first = call i16 @llvm.x86.lds16(ptr %p)
  %second = call i16 @llvm.x86.lds16(ptr %p)
  ret i16 %first
}
declare i32 @llvm.x86.lds32(ptr)
define i32 @probe_lds32(ptr %p) {
  %first = call i32 @llvm.x86.lds32(ptr %p)
  %second = call i32 @llvm.x86.lds32(ptr %p)
  ret i32 %first
}
declare i16 @llvm.x86.les16(ptr)
define i16 @probe_les16(ptr %p) {
  %first = call i16 @llvm.x86.les16(ptr %p)
  %second = call i16 @llvm.x86.les16(ptr %p)
  ret i16 %first
}
declare i32 @llvm.x86.les32(ptr)
define i32 @probe_les32(ptr %p) {
  %first = call i32 @llvm.x86.les32(ptr %p)
  %second = call i32 @llvm.x86.les32(ptr %p)
  ret i32 %first
}

;--- bad.ll
declare i16 @llvm.x86.lfs16(i64)
define i16 @bad(i64 %p) {
  %v = call i16 @llvm.x86.lfs16(i64 %p)
  ret i16 %v
}

;--- bad-lfs.ll
declare i64 @llvm.x86.lfs64(ptr)
define i64 @bad(ptr %p) {
  %v = call i64 @llvm.x86.lfs64(ptr %p)
  ret i64 %v
}

;--- bad-lgs.ll
declare i64 @llvm.x86.lgs64(ptr)
define i64 @bad(ptr %p) {
  %v = call i64 @llvm.x86.lgs64(ptr %p)
  ret i64 %v
}

;--- bad-lss.ll
declare i64 @llvm.x86.lss64(ptr)
define i64 @bad(ptr %p) {
  %v = call i64 @llvm.x86.lss64(ptr %p)
  ret i64 %v
}
