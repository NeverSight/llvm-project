; RUN: llc -mtriple=i686-unknown-linux-gnu -mattr=+adx -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i686-unknown-linux-gnu -mattr=+adx -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: not --crash llc -mtriple=i686-unknown-linux-gnu -mattr=-adx < %s 2>&1 | FileCheck %s --check-prefix=NOADX
; NOADX: native ADX intrinsic requires the adx target feature

declare { i8, i32 } @llvm.x86.adcx.32(i8, i32, i32)
declare { i8, i32 } @llvm.x86.adox.32(i8, i32, i32)

; CHECK-LABEL: adcx32:
; CHECK: adcxl
; CHECK: setb
; CHECK: ret
define { i8, i32 } @adcx32(i8 %carry, i32 %a, i32 %b) {
 %r = call { i8, i32 } @llvm.x86.adcx.32(i8 %carry, i32 %a, i32 %b)
 ret { i8, i32 } %r
}

; CHECK-LABEL: adox32:
; CHECK: adoxl
; CHECK: seto
; CHECK: ret
define { i8, i32 } @adox32(i8 %carry, i32 %a, i32 %b) {
 %r = call { i8, i32 } @llvm.x86.adox.32(i8 %carry, i32 %a, i32 %b)
 ret { i8, i32 } %r
}
