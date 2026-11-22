; RUN: llc -mtriple=arm64e-apple-darwin -verify-machineinstrs -global-isel=0 < %s | FileCheck %s
; RUN: llc -mtriple=arm64e-apple-darwin -verify-machineinstrs -O0 -global-isel -global-isel-abort=1 < %s | FileCheck %s
;
; The address and integer parts of the field discriminator must both survive.
define i32 @db(ptr %field, i32 %x) {
; CHECK-LABEL: _db:
; CHECK: movk [[DISC:x[0-9]+]], #17185, lsl #48
; CHECK: autdb [[IP:x1[67]]], [[DISC]]
; CHECK-NEXT: blr [[IP]]
  %f = load ptr, ptr %field
  %a = ptrtoint ptr %field to i64
  %d = call i64 @llvm.ptrauth.blend(i64 %a, i64 17185)
  %v = call i32 %f(i32 %x) [ "ptrauth"(i32 3, i64 %d) ]
  %out = add i32 %v, 1
  ret i32 %out
}

define i32 @da_tail(ptr %f) {
; CHECK-LABEL: _da_tail:
; CHECK: autdza [[IP:x1[67]]]
; CHECK-NEXT: br [[IP]]
  %v = musttail call i32 %f(ptr %f) [ "ptrauth"(i32 2, i64 0) ]
  ret i32 %v
}

define i32 @invoke_db(ptr %f, i64 %disc) personality ptr @personality {
; CHECK-LABEL: _invoke_db:
; CHECK: autdb [[IP:x1[67]]], {{x[0-9]+}}
; CHECK-NEXT: blr [[IP]]
  %v = invoke i32 %f() [ "ptrauth"(i32 3, i64 %disc) ]
      to label %ok unwind label %cleanup
ok:
  ret i32 %v
cleanup:
  %exn = landingpad { ptr, i32 } cleanup
  resume { ptr, i32 } %exn
}

declare i32 @personality(...)
declare i64 @llvm.ptrauth.blend(i64, i64)
