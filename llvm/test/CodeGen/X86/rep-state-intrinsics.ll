; RUN: split-file %s %t
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs -O0 %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs -O2 %t/64.ll -o - | FileCheck %s --check-prefix=X64
; RUN: opt -S -passes='default<O2>' %t/64.ll -o %t/optimized64.ll
; RUN: FileCheck %s --check-prefix=IR64 < %t/optimized64.ll
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs %t/optimized64.ll -filetype=obj -o %t/64.o
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs -stop-after=finalize-isel %t/64.ll -o - | FileCheck %s --check-prefix=M64
; RUN: llc -mtriple=x86_64-pc-windows-msvc -mattr=+sahf -verify-machineinstrs %t/64.ll -filetype=obj -o %t/64-pc-windows-msvc.o
; RUN: llc -mtriple=x86_64-apple-darwin -mattr=+sahf -verify-machineinstrs %t/64.ll -filetype=obj -o %t/64-apple-darwin.o
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs -x86-asm-syntax=att %t/64.ll -o - | llvm-mc -triple=x86_64 -filetype=obj -o %t/64-att.o
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs -x86-asm-syntax=intel %t/64.ll -o - | llvm-mc -triple=x86_64 -filetype=obj -o %t/64-intel.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs -O0 %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs -O2 %t/32.ll -o - | FileCheck %s --check-prefix=X32
; RUN: opt -S -passes='default<O2>' %t/32.ll -o %t/optimized32.ll
; RUN: FileCheck %s --check-prefix=IR32 < %t/optimized32.ll
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs %t/optimized32.ll -filetype=obj -o %t/32.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs -stop-after=finalize-isel %t/32.ll -o - | FileCheck %s --check-prefix=M32
; RUN: llc -mtriple=i386-pc-windows-msvc -mattr=+sahf -verify-machineinstrs %t/32.ll -filetype=obj -o %t/32-pc-windows-msvc.o
; RUN: llc -mtriple=i386-apple-darwin -mattr=+sahf -verify-machineinstrs %t/32.ll -filetype=obj -o %t/32-apple-darwin.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs -x86-asm-syntax=att %t/32.ll -o - | llvm-mc -triple=i386 -filetype=obj -o %t/32-att.o
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sahf -verify-machineinstrs -x86-asm-syntax=intel %t/32.ll -o - | llvm-mc -triple=i386 -filetype=obj -o %t/32-intel.o
; RUN: not --crash llc -mtriple=i386 %t/64.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64 %t/32.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=i386-pc-linux-code16 %t/32.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: not --crash llc -mtriple=x86_64 -mattr=-sahf %t/64.ll -o /dev/null 2>&1 | FileCheck %s --check-prefix=FEATURE
; RUN: llc -mtriple=i386 -mattr=-sahf -verify-machineinstrs %t/32.ll -filetype=obj -o %t/32-no-sahf.o
; MODE: explicit REP intrinsic does not match the target code mode
; FEATURE: explicit REP comparison requires the sahf target feature
;
; The DF window is a single machine pseudo through register allocation. Every
; result uses the full code-mode register, including overridden addresses and
; narrow LODS. Dead-result calls still own the accesses and faults.

;--- 64.ll
declare { i64, i64, i64 } @llvm.x86.rep.movs.state(i64, i64, i64, i8, i32, i32, i32)

define { i64, i64, i64 } @movs(i64 %v0, i64 %v1, i64 %v2, i8 %v3) {
; X64-LABEL: movs:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: rep{{.*}}movsb
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64, i64 } @movs(
; IR64: call { i64, i64, i64 } @llvm.x86.rep.movs.state(
; M64-LABEL: name: movs
; M64: REP_MOVS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64, i64 } @llvm.x86.rep.movs.state(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i32 1, i32 64, i32 0)
  ret { i64, i64, i64 } %result
}

define { i64, i64, i64 } @movs_override(i64 %v0, i64 %v1, i64 %v2, i8 %v3) {
; X64-LABEL: movs_override:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: rep{{.*}}movsl
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64, i64 } @movs_override(
; IR64: call { i64, i64, i64 } @llvm.x86.rep.movs.state(
; M64-LABEL: name: movs_override
; M64: REP_MOVS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64, i64 } @llvm.x86.rep.movs.state(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i32 4, i32 32, i32 100)
  ret { i64, i64, i64 } %result
}

declare { i64, i64 } @llvm.x86.rep.stos.state(i64, i64, i64, i8, i32, i32)

define { i64, i64 } @stos(i64 %v0, i64 %v1, i64 %v2, i8 %v3) {
; X64-LABEL: stos:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: rep{{.*}}stosw
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64 } @stos(
; IR64: call { i64, i64 } @llvm.x86.rep.stos.state(
; M64-LABEL: name: stos
; M64: REP_STOS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64 } @llvm.x86.rep.stos.state(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i32 2, i32 64)
  ret { i64, i64 } %result
}

define { i64, i64 } @stos_override(i64 %v0, i64 %v1, i64 %v2, i8 %v3) {
; X64-LABEL: stos_override:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: rep{{.*}}stosb
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64 } @stos_override(
; IR64: call { i64, i64 } @llvm.x86.rep.stos.state(
; M64-LABEL: name: stos_override
; M64: REP_STOS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64 } @llvm.x86.rep.stos.state(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i32 1, i32 32)
  ret { i64, i64 } %result
}

declare { i64, i64, i64 } @llvm.x86.rep.lods.state(i64, i64, i64, i8, i32, i32, i32)

define { i64, i64, i64 } @lods(i64 %v0, i64 %v1, i64 %v2, i8 %v3) {
; X64-LABEL: lods:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: rep{{.*}}lodsq
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64, i64 } @lods(
; IR64: call { i64, i64, i64 } @llvm.x86.rep.lods.state(
; M64-LABEL: name: lods
; M64: REP_LODS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64, i64 } @llvm.x86.rep.lods.state(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i32 8, i32 64, i32 0)
  ret { i64, i64, i64 } %result
}

define { i64, i64, i64 } @lods_override(i64 %v0, i64 %v1, i64 %v2, i8 %v3) {
; X64-LABEL: lods_override:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: rep{{.*}}lodsw
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64, i64 } @lods_override(
; IR64: call { i64, i64, i64 } @llvm.x86.rep.lods.state(
; M64-LABEL: name: lods_override
; M64: REP_LODS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64, i64 } @llvm.x86.rep.lods.state(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i32 2, i32 32, i32 100)
  ret { i64, i64, i64 } %result
}

declare { i64, i64, i64, i16 } @llvm.x86.rep.cmps.state(i64, i64, i64, i8, i16, i32, i32, i32, i32)

define { i64, i64, i64, i16 } @cmps(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i16 %v4) {
; X64-LABEL: cmps:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: rep{{.*}}cmpsq
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64, i64, i16 } @cmps(
; IR64: call { i64, i64, i64, i16 } @llvm.x86.rep.cmps.state(
; M64-LABEL: name: cmps
; M64: REP_CMPS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64, i64, i16 } @llvm.x86.rep.cmps.state(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i16 %v4, i32 8, i32 64, i32 0, i32 0)
  ret { i64, i64, i64, i16 } %result
}

define { i64, i64, i64, i16 } @cmps_override(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i16 %v4) {
; X64-LABEL: cmps_override:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: repne{{.*}}cmpsl
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64, i64, i16 } @cmps_override(
; IR64: call { i64, i64, i64, i16 } @llvm.x86.rep.cmps.state(
; M64-LABEL: name: cmps_override
; M64: REP_CMPS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64, i64, i16 } @llvm.x86.rep.cmps.state(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i16 %v4, i32 4, i32 32, i32 100, i32 1)
  ret { i64, i64, i64, i16 } %result
}

declare { i64, i64, i16 } @llvm.x86.rep.scas.state(i64, i64, i64, i8, i16, i32, i32, i32)

define { i64, i64, i16 } @scas(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i16 %v4) {
; X64-LABEL: scas:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: xchg
; X64-NEXT: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: mov
; X64-NEXT: rep{{.*}}scasq
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64, i16 } @scas(
; IR64: call { i64, i64, i16 } @llvm.x86.rep.scas.state(
; M64-LABEL: name: scas
; M64: REP_SCAS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64, i16 } @llvm.x86.rep.scas.state(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i16 %v4, i32 8, i32 64, i32 0)
  ret { i64, i64, i16 } %result
}

define { i64, i64, i16 } @scas_override(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i16 %v4) {
; X64-LABEL: scas_override:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: xchg
; X64-NEXT: addb $127, %al
; X64-NEXT: sahf
; X64-NEXT: mov
; X64-NEXT: repne{{.*}}scasw
; X64-NEXT: lahf
; X64-NEXT: seto %al
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64, i16 } @scas_override(
; IR64: call { i64, i64, i16 } @llvm.x86.rep.scas.state(
; M64-LABEL: name: scas_override
; M64: REP_SCAS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64, i16 } @llvm.x86.rep.scas.state(i64 %v0, i64 %v1, i64 %v2, i8 %v3, i16 %v4, i32 2, i32 32, i32 1)
  ret { i64, i64, i16 } %result
}

declare { i64, i64 } @llvm.x86.rep.ins.state(i64, i64, i16, i8, i32, i32)

define { i64, i64 } @ins(i64 %v0, i64 %v1, i16 %v2, i8 %v3) {
; X64-LABEL: ins:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: rep{{.*}}insl
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64 } @ins(
; IR64: call { i64, i64 } @llvm.x86.rep.ins.state(
; M64-LABEL: name: ins
; M64: REP_INS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64 } @llvm.x86.rep.ins.state(i64 %v0, i64 %v1, i16 %v2, i8 %v3, i32 4, i32 64)
  ret { i64, i64 } %result
}

define { i64, i64 } @ins_override(i64 %v0, i64 %v1, i16 %v2, i8 %v3) {
; X64-LABEL: ins_override:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: rep{{.*}}insb
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64 } @ins_override(
; IR64: call { i64, i64 } @llvm.x86.rep.ins.state(
; M64-LABEL: name: ins_override
; M64: REP_INS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64 } @llvm.x86.rep.ins.state(i64 %v0, i64 %v1, i16 %v2, i8 %v3, i32 1, i32 32)
  ret { i64, i64 } %result
}

declare { i64, i64 } @llvm.x86.rep.outs.state(i64, i64, i16, i8, i32, i32, i32)

define { i64, i64 } @outs(i64 %v0, i64 %v1, i16 %v2, i8 %v3) {
; X64-LABEL: outs:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: rep{{.*}}outsw
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64 } @outs(
; IR64: call { i64, i64 } @llvm.x86.rep.outs.state(
; M64-LABEL: name: outs
; M64: REP_OUTS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64 } @llvm.x86.rep.outs.state(i64 %v0, i64 %v1, i16 %v2, i8 %v3, i32 2, i32 64, i32 0)
  ret { i64, i64 } %result
}

define { i64, i64 } @outs_override(i64 %v0, i64 %v1, i16 %v2, i8 %v3) {
; X64-LABEL: outs_override:
; X64: cld
; X64-NEXT: testl
; X64-NEXT: je
; X64-NEXT: std
; X64-NEXT: .Ltmp
; X64-NEXT: rep{{.*}}outsl
; X64-NEXT: cld
; X64: ret
; IR64-LABEL: define { i64, i64 } @outs_override(
; IR64: call { i64, i64 } @llvm.x86.rep.outs.state(
; M64-LABEL: name: outs_override
; M64: REP_OUTS_STATE64 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i64, i64 } @llvm.x86.rep.outs.state(i64 %v0, i64 %v1, i16 %v2, i8 %v3, i32 4, i32 32, i32 100)
  ret { i64, i64 } %result
}

define void @unused(i64 %a, i64 %b, i64 %c) {
; X64-LABEL: unused:
; X64-COUNT-2: rep{{.*}}movsb
; X64: ret
; IR64-LABEL: define void @unused(
; IR64-COUNT-2: call { i64, i64, i64 } @llvm.x86.rep.movs.state
  call { i64, i64, i64 } @llvm.x86.rep.movs.state(i64 %a, i64 %b, i64 %c, i8 0, i32 1, i32 64, i32 0)
  call { i64, i64, i64 } @llvm.x86.rep.movs.state(i64 %a, i64 %b, i64 %c, i8 0, i32 1, i32 64, i32 0)
  ret void
}

;--- 32.ll
declare { i32, i32, i32 } @llvm.x86.rep.movs.state32(i32, i32, i32, i8, i32, i32, i32)

define { i32, i32, i32 } @movs(i32 %v0, i32 %v1, i32 %v2, i8 %v3) {
; X32-LABEL: movs:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: xchgl [[PAIR:.*]]
; X32-NEXT: rep{{.*}}movsb
; X32-NEXT: cld
; X32-NEXT: xchgl [[PAIR]]
; X32: ret
; IR32-LABEL: define { i32, i32, i32 } @movs(
; IR32: call { i32, i32, i32 } @llvm.x86.rep.movs.state32(
; M32-LABEL: name: movs
; M32: REP_MOVS_STATE32_SAVE_ESI {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32, i32 } @llvm.x86.rep.movs.state32(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i32 1, i32 32, i32 0)
  ret { i32, i32, i32 } %result
}

define { i32, i32, i32 } @movs_override(i32 %v0, i32 %v1, i32 %v2, i8 %v3) {
; X32-LABEL: movs_override:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: xchgl [[PAIR:.*]]
; X32-NEXT: rep{{.*}}movsl
; X32-NEXT: cld
; X32-NEXT: xchgl [[PAIR]]
; X32: ret
; IR32-LABEL: define { i32, i32, i32 } @movs_override(
; IR32: call { i32, i32, i32 } @llvm.x86.rep.movs.state32(
; M32-LABEL: name: movs_override
; M32: REP_MOVS_STATE32_SAVE_ESI {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32, i32 } @llvm.x86.rep.movs.state32(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i32 4, i32 16, i32 100)
  ret { i32, i32, i32 } %result
}

declare { i32, i32 } @llvm.x86.rep.stos.state32(i32, i32, i32, i8, i32, i32)

define { i32, i32 } @stos(i32 %v0, i32 %v1, i32 %v2, i8 %v3) {
; X32-LABEL: stos:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: rep{{.*}}stosw
; X32-NEXT: cld
; X32: ret
; IR32-LABEL: define { i32, i32 } @stos(
; IR32: call { i32, i32 } @llvm.x86.rep.stos.state32(
; M32-LABEL: name: stos
; M32: REP_STOS_STATE32 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32 } @llvm.x86.rep.stos.state32(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i32 2, i32 32)
  ret { i32, i32 } %result
}

define { i32, i32 } @stos_override(i32 %v0, i32 %v1, i32 %v2, i8 %v3) {
; X32-LABEL: stos_override:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: rep{{.*}}stosb
; X32-NEXT: cld
; X32: ret
; IR32-LABEL: define { i32, i32 } @stos_override(
; IR32: call { i32, i32 } @llvm.x86.rep.stos.state32(
; M32-LABEL: name: stos_override
; M32: REP_STOS_STATE32 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32 } @llvm.x86.rep.stos.state32(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i32 1, i32 16)
  ret { i32, i32 } %result
}

declare { i32, i32, i32 } @llvm.x86.rep.lods.state32(i32, i32, i32, i8, i32, i32, i32)

define { i32, i32, i32 } @lods(i32 %v0, i32 %v1, i32 %v2, i8 %v3) {
; X32-LABEL: lods:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: xchgl [[PAIR:.*]]
; X32-NEXT: rep{{.*}}lodsl
; X32-NEXT: cld
; X32-NEXT: xchgl [[PAIR]]
; X32: ret
; IR32-LABEL: define { i32, i32, i32 } @lods(
; IR32: call { i32, i32, i32 } @llvm.x86.rep.lods.state32(
; M32-LABEL: name: lods
; M32: REP_LODS_STATE32_SAVE_ESI {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32, i32 } @llvm.x86.rep.lods.state32(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i32 4, i32 32, i32 0)
  ret { i32, i32, i32 } %result
}

define { i32, i32, i32 } @lods_override(i32 %v0, i32 %v1, i32 %v2, i8 %v3) {
; X32-LABEL: lods_override:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: xchgl [[PAIR:.*]]
; X32-NEXT: rep{{.*}}lodsw
; X32-NEXT: cld
; X32-NEXT: xchgl [[PAIR]]
; X32: ret
; IR32-LABEL: define { i32, i32, i32 } @lods_override(
; IR32: call { i32, i32, i32 } @llvm.x86.rep.lods.state32(
; M32-LABEL: name: lods_override
; M32: REP_LODS_STATE32_SAVE_ESI {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32, i32 } @llvm.x86.rep.lods.state32(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i32 2, i32 16, i32 100)
  ret { i32, i32, i32 } %result
}

declare { i32, i32, i32, i16 } @llvm.x86.rep.cmps.state32(i32, i32, i32, i8, i16, i32, i32, i32, i32)

define { i32, i32, i32, i16 } @cmps(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i16 %v4) {
; X32-LABEL: cmps:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: xchgl [[PAIR:.*]]
; X32-NEXT: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: rep{{.*}}cmpsw
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: cld
; X32-NEXT: xchgl [[PAIR]]
; X32: ret
; IR32-LABEL: define { i32, i32, i32, i16 } @cmps(
; IR32: call { i32, i32, i32, i16 } @llvm.x86.rep.cmps.state32(
; M32-LABEL: name: cmps
; M32: REP_CMPS_STATE32_SAVE_ESI {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32, i32, i16 } @llvm.x86.rep.cmps.state32(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i16 %v4, i32 2, i32 32, i32 0, i32 0)
  ret { i32, i32, i32, i16 } %result
}

define { i32, i32, i32, i16 } @cmps_override(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i16 %v4) {
; X32-LABEL: cmps_override:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: xchgl [[PAIR:.*]]
; X32-NEXT: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: repne{{.*}}cmpsl
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: cld
; X32-NEXT: xchgl [[PAIR]]
; X32: ret
; IR32-LABEL: define { i32, i32, i32, i16 } @cmps_override(
; IR32: call { i32, i32, i32, i16 } @llvm.x86.rep.cmps.state32(
; M32-LABEL: name: cmps_override
; M32: REP_CMPS_STATE32_SAVE_ESI {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32, i32, i16 } @llvm.x86.rep.cmps.state32(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i16 %v4, i32 4, i32 16, i32 100, i32 1)
  ret { i32, i32, i32, i16 } %result
}

declare { i32, i32, i16 } @llvm.x86.rep.scas.state32(i32, i32, i32, i8, i16, i32, i32, i32)

define { i32, i32, i16 } @scas(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i16 %v4) {
; X32-LABEL: scas:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: xchg
; X32-NEXT: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: mov
; X32-NEXT: rep{{.*}}scasb
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: cld
; X32: ret
; IR32-LABEL: define { i32, i32, i16 } @scas(
; IR32: call { i32, i32, i16 } @llvm.x86.rep.scas.state32(
; M32-LABEL: name: scas
; M32: REP_SCAS_STATE32 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32, i16 } @llvm.x86.rep.scas.state32(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i16 %v4, i32 1, i32 32, i32 0)
  ret { i32, i32, i16 } %result
}

define { i32, i32, i16 } @scas_override(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i16 %v4) {
; X32-LABEL: scas_override:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: xchg
; X32-NEXT: addb $127, %al
; X32-NEXT: sahf
; X32-NEXT: mov
; X32-NEXT: repne{{.*}}scasw
; X32-NEXT: lahf
; X32-NEXT: seto %al
; X32-NEXT: cld
; X32: ret
; IR32-LABEL: define { i32, i32, i16 } @scas_override(
; IR32: call { i32, i32, i16 } @llvm.x86.rep.scas.state32(
; M32-LABEL: name: scas_override
; M32: REP_SCAS_STATE32 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32, i16 } @llvm.x86.rep.scas.state32(i32 %v0, i32 %v1, i32 %v2, i8 %v3, i16 %v4, i32 2, i32 16, i32 1)
  ret { i32, i32, i16 } %result
}

declare { i32, i32 } @llvm.x86.rep.ins.state32(i32, i32, i16, i8, i32, i32)

define { i32, i32 } @ins(i32 %v0, i32 %v1, i16 %v2, i8 %v3) {
; X32-LABEL: ins:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: rep{{.*}}insl
; X32-NEXT: cld
; X32: ret
; IR32-LABEL: define { i32, i32 } @ins(
; IR32: call { i32, i32 } @llvm.x86.rep.ins.state32(
; M32-LABEL: name: ins
; M32: REP_INS_STATE32 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32 } @llvm.x86.rep.ins.state32(i32 %v0, i32 %v1, i16 %v2, i8 %v3, i32 4, i32 32)
  ret { i32, i32 } %result
}

define { i32, i32 } @ins_override(i32 %v0, i32 %v1, i16 %v2, i8 %v3) {
; X32-LABEL: ins_override:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: rep{{.*}}insb
; X32-NEXT: cld
; X32: ret
; IR32-LABEL: define { i32, i32 } @ins_override(
; IR32: call { i32, i32 } @llvm.x86.rep.ins.state32(
; M32-LABEL: name: ins_override
; M32: REP_INS_STATE32 {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32 } @llvm.x86.rep.ins.state32(i32 %v0, i32 %v1, i16 %v2, i8 %v3, i32 1, i32 16)
  ret { i32, i32 } %result
}

declare { i32, i32 } @llvm.x86.rep.outs.state32(i32, i32, i16, i8, i32, i32, i32)

define { i32, i32 } @outs(i32 %v0, i32 %v1, i16 %v2, i8 %v3) {
; X32-LABEL: outs:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: xchgl [[PAIR:.*]]
; X32-NEXT: rep{{.*}}outsw
; X32-NEXT: cld
; X32-NEXT: xchgl [[PAIR]]
; X32: ret
; IR32-LABEL: define { i32, i32 } @outs(
; IR32: call { i32, i32 } @llvm.x86.rep.outs.state32(
; M32-LABEL: name: outs
; M32: REP_OUTS_STATE32_SAVE_ESI {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32 } @llvm.x86.rep.outs.state32(i32 %v0, i32 %v1, i16 %v2, i8 %v3, i32 2, i32 32, i32 0)
  ret { i32, i32 } %result
}

define { i32, i32 } @outs_override(i32 %v0, i32 %v1, i16 %v2, i8 %v3) {
; X32-LABEL: outs_override:
; X32: cld
; X32-NEXT: testl
; X32-NEXT: je
; X32-NEXT: std
; X32-NEXT: .Ltmp
; X32-NEXT: xchgl [[PAIR:.*]]
; X32-NEXT: rep{{.*}}outsl
; X32-NEXT: cld
; X32-NEXT: xchgl [[PAIR]]
; X32: ret
; IR32-LABEL: define { i32, i32 } @outs_override(
; IR32: call { i32, i32 } @llvm.x86.rep.outs.state32(
; M32-LABEL: name: outs_override
; M32: REP_OUTS_STATE32_SAVE_ESI {{.*}}implicit-def{{( dead)?}} $df
  %result = call { i32, i32 } @llvm.x86.rep.outs.state32(i32 %v0, i32 %v1, i16 %v2, i8 %v3, i32 4, i32 16, i32 100)
  ret { i32, i32 } %result
}

define void @unused(i32 %a, i32 %b, i32 %c) {
; X32-LABEL: unused:
; X32-COUNT-2: rep{{.*}}movsb
; X32: ret
; IR32-LABEL: define void @unused(
; IR32-COUNT-2: call { i32, i32, i32 } @llvm.x86.rep.movs.state
  call { i32, i32, i32 } @llvm.x86.rep.movs.state32(i32 %a, i32 %b, i32 %c, i8 0, i32 1, i32 32, i32 0)
  call { i32, i32, i32 } @llvm.x86.rep.movs.state32(i32 %a, i32 %b, i32 %c, i8 0, i32 1, i32 32, i32 0)
  ret void
}
