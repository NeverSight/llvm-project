; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+adx,+egpr,+ndd -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+adx -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -mattr=+adx -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -mattr=+adx -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-apple-darwin -mattr=+adx -verify-machineinstrs < %s | FileCheck %s
;
; Native ADX intrinsics return {unsigned carry, sum}. The input byte is a
; boolean (all 1..255 inputs supply one), and each call owns its flag setup
; and capture. They do not expose ambient CF/OF across calls.

declare { i8, i32 } @llvm.x86.adcx.32(i8, i32, i32)
declare { i8, i64 } @llvm.x86.adcx.64(i8, i64, i64)
declare { i8, i32 } @llvm.x86.adox.32(i8, i32, i32)
declare { i8, i64 } @llvm.x86.adox.64(i8, i64, i64)

; CHECK-LABEL: adcx32:
; CHECK: adcxl
; CHECK: setb
; CHECK: ret
define { i8, i32 } @adcx32(i8 %c, i32 %a, i32 %b) {
  %r = call { i8, i32 } @llvm.x86.adcx.32(i8 %c, i32 %a, i32 %b)
  ret { i8, i32 } %r
}

; CHECK-LABEL: adcx64:
; CHECK: adcxq
; CHECK: setb
; CHECK: ret
define { i8, i64 } @adcx64(i8 %c, i64 %a, i64 %b) {
  %r = call { i8, i64 } @llvm.x86.adcx.64(i8 %c, i64 %a, i64 %b)
  ret { i8, i64 } %r
}

; CHECK-LABEL: adox32:
; CHECK: adoxl
; CHECK: seto
; CHECK: ret
define { i8, i32 } @adox32(i8 %c, i32 %a, i32 %b) {
  %r = call { i8, i32 } @llvm.x86.adox.32(i8 %c, i32 %a, i32 %b)
  ret { i8, i32 } %r
}

; CHECK-LABEL: adox64:
; CHECK: adoxq
; CHECK: seto
; CHECK: ret
define { i8, i64 } @adox64(i8 %c, i64 %a, i64 %b) {
  %r = call { i8, i64 } @llvm.x86.adox.64(i8 %c, i64 %a, i64 %b)
  ret { i8, i64 } %r
}

; CHECK-LABEL: adcx_constant_0:
; CHECK: adcxq
; CHECK: ret
define i64 @adcx_constant_0(i64 %a, i64 %b) {
  %r = call { i8, i64 } @llvm.x86.adcx.64(i8 0, i64 %a, i64 %b)
  %sum = extractvalue { i8, i64 } %r, 1
  ret i64 %sum
}

; CHECK-LABEL: adcx_constant_1:
; CHECK: adcxq
; CHECK: ret
define i64 @adcx_constant_1(i64 %a, i64 %b) {
  %r = call { i8, i64 } @llvm.x86.adcx.64(i8 1, i64 %a, i64 %b)
  %sum = extractvalue { i8, i64 } %r, 1
  ret i64 %sum
}

; CHECK-LABEL: adcx_constant_128:
; CHECK: adcxq
; CHECK: ret
define i64 @adcx_constant_128(i64 %a, i64 %b) {
  %r = call { i8, i64 } @llvm.x86.adcx.64(i8 128, i64 %a, i64 %b)
  %sum = extractvalue { i8, i64 } %r, 1
  ret i64 %sum
}

; CHECK-LABEL: adcx_constant_255:
; CHECK: adcxq
; CHECK: ret
define i64 @adcx_constant_255(i64 %a, i64 %b) {
  %r = call { i8, i64 } @llvm.x86.adcx.64(i8 255, i64 %a, i64 %b)
  %sum = extractvalue { i8, i64 } %r, 1
  ret i64 %sum
}

; CHECK-LABEL: adox_constant_0:
; CHECK: adoxq
; CHECK: ret
define i64 @adox_constant_0(i64 %a, i64 %b) {
  %r = call { i8, i64 } @llvm.x86.adox.64(i8 0, i64 %a, i64 %b)
  %sum = extractvalue { i8, i64 } %r, 1
  ret i64 %sum
}

; CHECK-LABEL: adox_constant_1:
; CHECK: adoxq
; CHECK: ret
define i64 @adox_constant_1(i64 %a, i64 %b) {
  %r = call { i8, i64 } @llvm.x86.adox.64(i8 1, i64 %a, i64 %b)
  %sum = extractvalue { i8, i64 } %r, 1
  ret i64 %sum
}

; CHECK-LABEL: adox_constant_128:
; CHECK: adoxq
; CHECK: ret
define i64 @adox_constant_128(i64 %a, i64 %b) {
  %r = call { i8, i64 } @llvm.x86.adox.64(i8 128, i64 %a, i64 %b)
  %sum = extractvalue { i8, i64 } %r, 1
  ret i64 %sum
}

; CHECK-LABEL: adox_constant_255:
; CHECK: adoxq
; CHECK: ret
define i64 @adox_constant_255(i64 %a, i64 %b) {
  %r = call { i8, i64 } @llvm.x86.adox.64(i8 255, i64 %a, i64 %b)
  %sum = extractvalue { i8, i64 } %r, 1
  ret i64 %sum
}

; CHECK-LABEL: dual_chains:
; CHECK-DAG: adcxq
; CHECK-DAG: adoxq
; CHECK-DAG: adcxq
; CHECK-DAG: adoxq
; CHECK: ret
define void @dual_chains(i8 %cf, i8 %of, i64 %a, i64 %b, i64 %c, ptr %out) {
  %x = call { i8, i64 } @llvm.x86.adcx.64(i8 %cf, i64 %a, i64 %b)
  %y = call { i8, i64 } @llvm.x86.adox.64(i8 %of, i64 %c, i64 %b)
  %xc = extractvalue { i8, i64 } %x, 0
  %xs = extractvalue { i8, i64 } %x, 1
  %yc = extractvalue { i8, i64 } %y, 0
  %ys = extractvalue { i8, i64 } %y, 1
  %xx = call { i8, i64 } @llvm.x86.adcx.64(i8 %xc, i64 %xs, i64 %b)
  %yy = call { i8, i64 } @llvm.x86.adox.64(i8 %yc, i64 %ys, i64 %b)
  store { i8, i64 } %xx, ptr %out
  %next = getelementptr { i8, i64 }, ptr %out, i64 1
  store { i8, i64 } %yy, ptr %next
  ret void
}
