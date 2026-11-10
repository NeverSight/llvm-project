; RUN: llc -mtriple=arm64e-apple-macosx14.0 -mattr=+pauth-lr -verify-machineinstrs < %s | FileCheck %s --check-prefix=MACHO
; RUN: llc -mtriple=aarch64-linux-gnu -mattr=+v8.3a,+pauth-lr -verify-machineinstrs < %s | FileCheck %s --check-prefix=ELF

; Classic arm64e uses Darwin's implicit B-key return-address ABI. ELF must
; retain its explicit RA-state transitions; PAuthLR must retain its signing-PC
; directive on both formats.

declare i32 @callee(i32)
declare void @cleanup()
declare i32 @__gxx_personality_v0(...)

define i32 @classic_catch(i32 %x) #0 personality ptr @__gxx_personality_v0 {
; MACHO-LABEL: _classic_catch:
; MACHO-NOT: .cfi_negate_ra_state
; MACHO: pacibsp
; MACHO-NOT: .cfi_negate_ra_state
; MACHO: retab
; MACHO-NOT: .cfi_negate_ra_state
; MACHO: .cfi_endproc
; ELF-LABEL: classic_catch:
; ELF: .cfi_b_key_frame
; ELF: pacibsp
; ELF-NEXT: .cfi_negate_ra_state
; ELF: retab
  %result = invoke i32 @callee(i32 %x) to label %normal unwind label %cleanup
normal:
  ret i32 %result
cleanup:
  %exception = landingpad { ptr, i32 } cleanup
  call void @cleanup()
  resume { ptr, i32 } %exception
}

define i32 @classic_tail(i32 %x) #0 {
; MACHO-LABEL: _classic_tail:
; MACHO-NOT: .cfi_negate_ra_state
; MACHO: pacibsp
; MACHO-NOT: .cfi_negate_ra_state
; MACHO: autibsp
; MACHO-NOT: .cfi_negate_ra_state
; MACHO: b _callee
; MACHO-NOT: .cfi_negate_ra_state
; MACHO: .cfi_endproc
; ELF-LABEL: classic_tail:
; ELF: pacibsp
; ELF-NEXT: .cfi_negate_ra_state
; ELF: autibsp
; ELF-NEXT: .cfi_negate_ra_state
  %result = musttail call i32 @callee(i32 %x)
  ret i32 %result
}

define i32 @pc_diversified(i32 %x) #1 {
; MACHO-LABEL: _pc_diversified:
; MACHO: .cfi_negate_ra_state_with_pc
; MACHO: pacibsppc
; ELF-LABEL: pc_diversified:
; ELF: .cfi_negate_ra_state_with_pc
; ELF: pacibsppc
  %result = call i32 @callee(i32 %x)
  ret i32 %result
}

define i32 @darwin_return(i32 %x) #2 {
; MACHO-LABEL: _darwin_return:
; MACHO-NOT: .cfi_negate_ra_state
; MACHO: pacibsp
; MACHO-NOT: .cfi_negate_ra_state
; MACHO: retab
; MACHO-NOT: .cfi_negate_ra_state
; MACHO: .cfi_endproc
  %result = call i32 @callee(i32 %x)
  ret i32 %result
}

attributes #0 = { uwtable(async) "sign-return-address"="all" "sign-return-address-key"="b_key" "frame-pointer"="all" }
attributes #1 = { uwtable(async) "sign-return-address"="all" "sign-return-address-key"="b_key" "branch-protection-pauth-lr" "frame-pointer"="all" }
attributes #2 = { uwtable(sync) "ptrauth-returns" "frame-pointer"="all" }
