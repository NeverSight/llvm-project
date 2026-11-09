; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sse2 -O0 -verify-machineinstrs -stop-after=finalize-isel %s -o - | FileCheck %s --check-prefixes=CHECK,LINUX
; RUN: llc -mtriple=i386-apple-macosx10.13 -mattr=+sse2 -O0 -verify-machineinstrs -stop-after=finalize-isel %s -o - | FileCheck %s --check-prefixes=CHECK,DARWIN
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sse2 -O0 -fast-isel=false -verify-machineinstrs -stop-after=finalize-isel %s -o - | FileCheck %s --check-prefixes=CHECK,LINUX
; RUN: llc -mtriple=i386-apple-macosx10.13 -mattr=+sse2 -O0 -fast-isel=false -verify-machineinstrs -stop-after=finalize-isel %s -o - | FileCheck %s --check-prefixes=CHECK,DARWIN
;
; Five vectors exhaust XMM0..2 on Linux and XMM0..3 on Darwin. Stack vectors
; plus three dwords consume 44/28 argument bytes, padded to 48/32 by the caller.
; Charging the callee for that padding corrupts the caller's
; saved registers and return address when it restores its reserved call frame.

; CHECK-LABEL: name: caller
; LINUX: ADJCALLSTACKDOWN32 48, 0
; LINUX: ADJCALLSTACKUP32 48, 44
; DARWIN: ADJCALLSTACKDOWN32 32, 0
; DARWIN: ADJCALLSTACKUP32 32, 28
; CHECK-LABEL: name: callee
; LINUX: RET{{(I32)?}} 44
; DARWIN: RET{{(I32)?}} 28

define void @caller(ptr %fn, <4 x i32> %a, <4 x i32> %b, <4 x i32> %c,
                    <4 x i32> %d, <4 x i32> %e, i32 %tag, ptr %out, ptr %seen) {
  %result = call x86_stdcallcc <4 x i32> %fn(<4 x i32> %a, <4 x i32> %b,
                                           <4 x i32> %c, <4 x i32> %d, <4 x i32> %e,
                                           i32 %tag, ptr %out, ptr %seen)
  store <4 x i32> %result, ptr %out
  ret void
}

define x86_stdcallcc <4 x i32> @callee(<4 x i32> %a, <4 x i32> %b,
                                     <4 x i32> %c, <4 x i32> %d, <4 x i32> %e,
                                     i32 %tag, ptr %out, ptr %seen) {
  store i32 %tag, ptr %seen
  store <4 x i32> %a, ptr %out
  ret <4 x i32> %e
}
