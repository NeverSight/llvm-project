; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sse2 -O0 -verify-machineinstrs -stop-after=finalize-isel %s -o - | FileCheck %s
; RUN: llc -mtriple=i386-apple-macosx10.13 -mattr=+sse2 -O0 -verify-machineinstrs -stop-after=finalize-isel %s -o - | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -mattr=+sse2 -O0 -fast-isel=false -verify-machineinstrs -stop-after=finalize-isel %s -o - | FileCheck %s
; RUN: llc -mtriple=i386-apple-macosx10.13 -mattr=+sse2 -O0 -fast-isel=false -verify-machineinstrs -stop-after=finalize-isel %s -o - | FileCheck %s
;
; Four vector arguments exhaust XMM0..2. The fourth vector plus three dwords
; consume 28 argument bytes, but the caller reserves 32 bytes for alignment.
; The callee's RET pops 28. Charging it for the padding corrupts the caller's
; saved registers and return address when it restores its reserved call frame.

; CHECK-LABEL: name: caller
; CHECK: ADJCALLSTACKDOWN32 32, 0
; CHECK: ADJCALLSTACKUP32 32, 28
; CHECK-LABEL: name: callee
; CHECK: RET{{(I32)?}} 28

define void @caller(ptr %fn, <4 x i32> %a, <4 x i32> %b, <4 x i32> %c,
                    <4 x i32> %d, i32 %tag, ptr %out, ptr %seen) {
  %result = call x86_stdcallcc <4 x i32> %fn(<4 x i32> %a, <4 x i32> %b,
                                           <4 x i32> %c, <4 x i32> %d,
                                           i32 %tag, ptr %out, ptr %seen)
  store <4 x i32> %result, ptr %out
  ret void
}

define x86_stdcallcc <4 x i32> @callee(<4 x i32> %a, <4 x i32> %b,
                                     <4 x i32> %c, <4 x i32> %d,
                                     i32 %tag, ptr %out, ptr %seen) {
  store i32 %tag, ptr %seen
  store <4 x i32> %a, ptr %out
  ret <4 x i32> %d
}
