; RUN: llc -mattr=+pauth-lr -global-isel=0 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mattr=+pauth-lr -global-isel -global-isel-abort=1 -O0 -verify-machineinstrs %s -o - | FileCheck %s

target triple = "arm64e-apple-macos15"
define i32 @db_lr(ptr %p, i64 %disc) #0 {
; CHECK-LABEL: _db_lr:
; CHECK: autiasppc
; CHECK: autdb x17, [[DISC:x[0-9]+]]
; CHECK-NEXT: br x17
  %v = musttail call i32 %p(ptr %p, i64 %disc) [ "ptrauth"(i32 3, i64 %disc) ]
  ret i32 %v
}
attributes #0 = { "sign-return-address"="all" "branch-protection-pauth-lr" "branch-target-enforcement" }

define i32 @ia_lr(ptr %p) #1 {
; CHECK-LABEL: _ia_lr:
; CHECK: autiasppc
; CHECK: braaz x17
  %v = musttail call i32 %p(ptr %p) [ "ptrauth"(i32 0, i64 0) ]
  ret i32 %v
}
attributes #1 = { "sign-return-address"="all" "branch-protection-pauth-lr" }
