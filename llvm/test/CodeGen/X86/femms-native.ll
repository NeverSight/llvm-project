; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes='default<O2>' < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -stop-after=finalize-isel -verify-machineinstrs < %s | FileCheck %s --check-prefix=MIR
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+3dnowa -O2 -verify-machineinstrs < %s 2>&1 | FileCheck %s --implicit-check-not='not a recognized feature'

; This must remain a native state operation, not an unresolved llvm.* call
; or a substitution with EMMS. Its complete physical clobber set lets the
; allocator preserve virtual MMX values which remain live across FEMMS.
define void @repeat(ptr %p, i32 %value) {
; CHECK-LABEL: repeat:
; CHECK: movl
; CHECK: femms
; CHECK-NEXT: femms
; CHECK: movl $0,
; CHECK: ret
; MIR-LABEL: name: repeat
; MIR: FEMMS implicit-def dead $mm0, implicit-def dead $mm1, implicit-def dead $mm2, implicit-def dead $mm3, implicit-def dead $mm4, implicit-def dead $mm5, implicit-def dead $mm6, implicit-def dead $mm7, implicit-def dead $st0, implicit-def dead $st1, implicit-def dead $st2, implicit-def dead $st3, implicit-def dead $st4, implicit-def dead $st5, implicit-def dead $st6, implicit-def dead $st7
; MIR: FEMMS implicit-def dead $mm0, implicit-def dead $mm1, implicit-def dead $mm2, implicit-def dead $mm3, implicit-def dead $mm4, implicit-def dead $mm5, implicit-def dead $mm6, implicit-def dead $mm7, implicit-def dead $st0, implicit-def dead $st1, implicit-def dead $st2, implicit-def dead $st3, implicit-def dead $st4, implicit-def dead $st5, implicit-def dead $st6, implicit-def dead $st7
  store i32 %value, ptr %p
  call void @llvm.x86.mmx.femms()
  call void @llvm.x86.mmx.femms()
  store i32 0, ptr %p
  ret void
}

define i64 @live_mmx(i64 %x, i64 %y) #0 {
; CHECK-LABEL: live_mmx:
; CHECK: paddb
; CHECK: movq %mm{{[0-7]}},
; CHECK: femms
; CHECK: movq {{.*}}, %mm{{[0-7]}}
; CHECK: pxor
; CHECK: emms
; CHECK: ret
  %a = bitcast i64 %x to x86_mmx
  %b = bitcast i64 %y to x86_mmx
  %sum = call x86_mmx @llvm.x86.mmx.padd.b(x86_mmx %a, x86_mmx %b)
  call void @llvm.x86.mmx.femms()
  %mixed = call x86_mmx @llvm.x86.mmx.pxor(x86_mmx %sum, x86_mmx %a)
  %result = bitcast x86_mmx %mixed to i64
  call void @llvm.x86.mmx.emms()
  ret i64 %result
}

declare void @llvm.x86.mmx.femms()
declare void @llvm.x86.mmx.emms()
declare x86_mmx @llvm.x86.mmx.padd.b(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.mmx.pxor(x86_mmx, x86_mmx)

attributes #0 = { "target-features"="+mmx" }
