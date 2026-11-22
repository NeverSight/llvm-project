; RUN: llc -mtriple=arm64-apple-darwin -verify-machineinstrs -global-isel=0 < %s | FileCheck %s --check-prefixes=CHECK,DAG
; RUN: llc -mtriple=arm64-apple-darwin -verify-machineinstrs -O0 -global-isel -global-isel-abort=1 < %s | FileCheck %s --check-prefixes=CHECK,GI
;
; Both selectors pass the unrounded byte count to the helper; the helper
; must see even those sizes for which rounding to stack alignment overflows.
define void @variable(i64 %n) {
; CHECK-LABEL: _variable:
; DAG: mov x9, x0
; GI: {{lsr|mov}} [[SIZE:x[0-9]+]], x0{{(, #0)?$}}
; GI: mov x9, [[SIZE]]
; CHECK: ___chkstk_darwin@GOTPAGE
; CHECK: blr x16
  %p = alloca i8, i64 %n, align 32
  call void @consume(ptr %p)
  ret void
}

define void @small() {
; CHECK-LABEL: _small:
; CHECK-NOT: ___chkstk_darwin
; CHECK: ret
  %p = alloca [32 x i8], align 16
  call void @consume(ptr %p)
  ret void
}

define void @override() #0 {
; CHECK-LABEL: _override:
; CHECK-NOT: ___chkstk_darwin
; CHECK: ret
  %p = alloca [4096 x i8], align 16
  call void @consume(ptr %p)
  ret void
}

declare void @consume(ptr)
attributes #0 = { "stack-probe-size"="65536" }
!llvm.module.flags = !{!0, !1}
!0 = !{i32 1, !"probe-stack", !"__chkstk_darwin"}
!1 = !{i32 1, !"stack-probe-size", i32 4096}
