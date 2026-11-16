; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32r2 -relocation-model=static < %s | FileCheck %s
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32r2 -relocation-model=static < %s | FileCheck %s
;
; A function attribute must enable the hard-float pass even when the default
; translation-unit mode is classic MIPS. Classic and soft-float definitions
; must not receive compressed entry stubs or return helpers.

; CHECK-LABEL: compressed:
; CHECK: jal __mips16_ret_sf
; CHECK-LABEL: classic:
; CHECK-NOT: __mips16_ret_sf
; CHECK-LABEL: soft:
; CHECK-NOT: __mips16_ret_sf
; CHECK-LABEL: classic_soft:
; CHECK-NOT: __mips16_ret_sf
; CHECK-LABEL: __fn_stub_compressed:
; CHECK: mfc1 $4, $f12
; CHECK-NOT: __fn_stub_classic
; CHECK-NOT: __fn_stub_soft

define float @compressed(float %x) #0 {
  ret float %x
}

define float @classic(float %x) {
  ret float %x
}

define float @soft(float %x) #1 {
  ret float %x
}

define float @classic_soft(float %x) #2 {
  ret float %x
}

attributes #0 = { "mips16" }
attributes #1 = { "mips16" "use-soft-float"="true" }
attributes #2 = { "nomips16" "use-soft-float"="true" }
