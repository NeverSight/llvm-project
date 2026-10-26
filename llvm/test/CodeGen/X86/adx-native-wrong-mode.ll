; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu -mattr=+adx < %s 2>&1 | FileCheck %s
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu -mattr=+adx -O0 < %s 2>&1 | FileCheck %s
; CHECK: native ADX intrinsic does not match the target code mode

declare {i8, i64} @llvm.x86.adcx.64(i8, i64, i64)
define {i8, i64} @wrong_mode(i8 %c,i64 %a,i64 %b) {
 %r=call {i8, i64} @llvm.x86.adcx.64(i8 %c,i64 %a,i64 %b)
 ret {i8, i64} %r
}
