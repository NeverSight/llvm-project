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
; CHECK-LABEL: feature_enabled:
; CHECK: jal __mips16_ret_sf
; CHECK-LABEL: cpu_only:
; CHECK-NOT: __mips16_ret_sf
; CHECK-LABEL: feature_disabled:
; CHECK-NOT: __mips16_ret_sf
; CHECK-LABEL: attribute_enabled:
; CHECK: jal __mips16_ret_sf
; CHECK-LABEL: __fn_stub_compressed:
; CHECK: mfc1 $4, $f12
; CHECK-NOT: __fn_stub_classic
; CHECK-NOT: __fn_stub_soft
; CHECK-LABEL: __fn_stub_feature_enabled:
; CHECK: mfc1 $4, $f12
; CHECK-NOT: __fn_stub_cpu_only
; CHECK-NOT: __fn_stub_feature_disabled
; CHECK-LABEL: __fn_stub_attribute_enabled:
; CHECK: mfc1 $4, $f12

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

define float @feature_enabled(float %x) #3 {
  ret float %x
}

define float @cpu_only(float %x) #4 {
  ret float %x
}

define float @feature_disabled(float %x) #5 {
  ret float %x
}

define float @attribute_enabled(float %x) #6 {
  ret float %x
}

attributes #0 = { "mips16" }
attributes #1 = { "mips16" "use-soft-float"="true" }
attributes #2 = { "nomips16" "use-soft-float"="true" }
attributes #3 = { "target-features"="+mips16" }
attributes #4 = { "target-cpu"="mips32r2" }
attributes #5 = { "target-features"="+mips16,-mips16" }
attributes #6 = { "mips16" "target-features"="-mips16" }
