; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32 -relocation-model=static < %s | FileCheck %s --check-prefixes=ALL,LE
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32 -relocation-model=static < %s | FileCheck %s --check-prefixes=ALL,BE
;
; The function's ISA/FPR attributes must survive on both kinds of generated
; stub; using the module defaults would reject or misencode the high-word move.

define i64 @convert(double %a) #0 {
  %r = fptosi double %a to i64
  ret i64 %r
}

attributes #0 = { "mips16" "target-cpu"="mips32r2" "target-features"="+fp64" }

; ALL-LABEL: __fn_stub_convert:
; LE: mfc1 $4, $f12
; LE-NEXT: mfhc1 $5, $f12
; BE: mfc1 $5, $f12
; BE-NEXT: mfhc1 $4, $f12
; ALL: jr $25
; ALL-LABEL: __call_stub_fp___fixdfdi:
; LE: mtc1 $4, $f12
; LE-NEXT: mthc1 $5, $f12
; BE: mtc1 $5, $f12
; BE-NEXT: mthc1 $4, $f12
; ALL: jal __fixdfdi
; ALL: jr $18
