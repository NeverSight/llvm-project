; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs %s -o - | FileCheck %s --check-prefix=ASM
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs -filetype=obj %s -o %t.o
; RUN: llvm-objdump -d %t.o | FileCheck %s --check-prefix=BYTES
;
; The direction branch is compiler-created and must preserve the native MPX
; bank. The complete DF window starts after the stackmap's patchable shadow.

declare void @llvm.x86.bnd.branch(i32 immarg)
declare void @llvm.experimental.stackmap(i64, i32, ...)
declare { i64, i64, i64 } @llvm.x86.rep.movs.state(i64, i64, i64, i8, i32 immarg, i32 immarg, i32 immarg)

define void @shadow(i64 %si, i64 %di, i64 %cx, i8 %df) {
; BYTES-LABEL: <shadow>:
; The stackmap starts at offset 7; its 64-byte shadow ends at 0x47.
; BYTES: 47: fc{{[ \t]+}}cld
; BYTES-NEXT: {{.*}}testl
; BYTES-NEXT: {{.*}}je
; BYTES-NEXT: {{.*}}std
; BYTES-NEXT: {{.*}}rep
; BYTES-NEXT: {{.*}}cld
; ASM-LABEL: shadow:
; ASM: .Ltmp0:
; ASM: nop
; ASM: cld
; ASM-NEXT: testl
; ASM-NEXT: je
; ASM-NEXT: std
; ASM-NEXT: .Ltmp
; ASM-NEXT: rep{{.*}}movsb
; ASM-NEXT: cld
  call void (i64, i32, ...) @llvm.experimental.stackmap(i64 0, i32 64)
  call { i64, i64, i64 } @llvm.x86.rep.movs.state(i64 %si, i64 %di, i64 %cx, i8 %df, i32 1, i32 64, i32 0)
  ret void
}

define void @bank(i64 %si, i64 %di, i64 %cx, i8 %df) {
; ASM-LABEL: bank:
; ASM: cld
; ASM-NEXT: testl
; ASM-NEXT: repne{{[ \t]+}}je
; ASM-NEXT: std
; ASM-NEXT: .Ltmp
; ASM-NEXT: rep{{.*}}movsb
; ASM-NEXT: cld
; BYTES-LABEL: <bank>:
; BYTES: f2 74 01
; BYTES-NEXT: {{.*}}fd{{[ \t]+}}std
; BYTES-NEXT: {{.*}}f3 a4{{[ \t]+}}rep
; BYTES-NEXT: {{.*}}fc{{[ \t]+}}cld
  call void @llvm.x86.bnd.branch(i32 1)
  call { i64, i64, i64 } @llvm.x86.rep.movs.state(i64 %si, i64 %di, i64 %cx, i8 %df, i32 1, i32 64, i32 0)
  ret void
}
