; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32r2 -mattr=+mips16,-fp64 -relocation-model=static < %s -o %t
; RUN: FileCheck %s --check-prefix=FIX-LE32 < %t
; RUN: FileCheck %s --check-prefix=RET-LE32 < %t
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32r2 -mattr=+mips16,+fp64 -relocation-model=static < %s -o %t
; RUN: FileCheck %s --check-prefix=FIX-LE64 < %t
; RUN: FileCheck %s --check-prefix=RET-LE64 < %t
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32r2 -mattr=+mips16,-fp64 -relocation-model=static < %s -o %t
; RUN: FileCheck %s --check-prefix=FIX-BE32 < %t
; RUN: FileCheck %s --check-prefix=RET-BE32 < %t
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32r2 -mattr=+mips16,+fp64 -relocation-model=static < %s -o %t
; RUN: FileCheck %s --check-prefix=FIX-BE64 < %t
; RUN: FileCheck %s --check-prefix=RET-BE64 < %t
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32r2 -mattr=+mips16,-fp64 -relocation-model=static < %s | FileCheck %s --check-prefixes=ALL,LE32
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32r2 -mattr=+mips16,-fp64 -relocation-model=static < %s | FileCheck %s --check-prefixes=ALL,BE32
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32r2 -mattr=+mips16,+fp64 -relocation-model=static < %s | FileCheck %s --check-prefixes=ALL,LE64
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32r2 -mattr=+mips16,+fp64 -relocation-model=static < %s | FileCheck %s --check-prefixes=ALL,BE64
;
; Parameter and return transports must agree between raw IR stubs and MC
; libcall stubs. Only the words of a double change order on big endian;
; separate float values retain argument/component order. FR=1 uses the high
; half of the same FPR instead of the adjacent FR=0 register.

define void @entry_f(float %a) { ret void }
define void @entry_ff(float %a, float %b) { ret void }
define void @entry_fd(float %a, double %b) { ret void }
define void @entry_d(double %a) { ret void }
define void @entry_dd(double %a, double %b) { ret void }
define void @entry_df(double %a, float %b) { ret void }

declare double @external_double(double)
define void @call_double(double %a) {
  %r = call double @external_double(double %a)
  ret void
}

define i64 @convert_double(double %a) {
  %r = fptosi double %a to i64
  ret i64 %r
}

define double @convert_integer(i64 %a) {
  %r = sitofp i64 %a to double
  ret double %r
}

; ALL-LABEL: __fn_stub_entry_f:
; ALL: mfc1 $4, $f12
; ALL: jr $25

; ALL-LABEL: __fn_stub_entry_ff:
; ALL: mfc1 $4, $f12
; ALL: mfc1 $5, $f14
; ALL: jr $25

; ALL-LABEL: __fn_stub_entry_fd:
; ALL: mfc1 $4, $f12
; LE32: mfc1 $6, $f14
; LE32-NEXT: mfc1 $7, $f15
; LE64: mfc1 $6, $f14
; LE64-NEXT: mfhc1 $7, $f14
; BE32: mfc1 $7, $f14
; BE32-NEXT: mfc1 $6, $f15
; BE64: mfc1 $7, $f14
; BE64-NEXT: mfhc1 $6, $f14
; ALL: jr $25

; ALL-LABEL: __fn_stub_entry_d:
; LE32: mfc1 $4, $f12
; LE32-NEXT: mfc1 $5, $f13
; LE64: mfc1 $4, $f12
; LE64-NEXT: mfhc1 $5, $f12
; BE32: mfc1 $5, $f12
; BE32-NEXT: mfc1 $4, $f13
; BE64: mfc1 $5, $f12
; BE64-NEXT: mfhc1 $4, $f12
; ALL: jr $25

; ALL-LABEL: __fn_stub_entry_dd:
; LE32: mfc1 $4, $f12
; LE32-NEXT: mfc1 $5, $f13
; LE64: mfc1 $4, $f12
; LE64-NEXT: mfhc1 $5, $f12
; BE32: mfc1 $5, $f12
; BE32-NEXT: mfc1 $4, $f13
; BE64: mfc1 $5, $f12
; BE64-NEXT: mfhc1 $4, $f12
; LE32: mfc1 $6, $f14
; LE32-NEXT: mfc1 $7, $f15
; LE64: mfc1 $6, $f14
; LE64-NEXT: mfhc1 $7, $f14
; BE32: mfc1 $7, $f14
; BE32-NEXT: mfc1 $6, $f15
; BE64: mfc1 $7, $f14
; BE64-NEXT: mfhc1 $6, $f14
; ALL: jr $25

; ALL-LABEL: __fn_stub_entry_df:
; LE32: mfc1 $4, $f12
; LE32-NEXT: mfc1 $5, $f13
; LE64: mfc1 $4, $f12
; LE64-NEXT: mfhc1 $5, $f12
; BE32: mfc1 $5, $f12
; BE32-NEXT: mfc1 $4, $f13
; BE64: mfc1 $5, $f12
; BE64-NEXT: mfhc1 $4, $f12
; ALL: mfc1 $6, $f14
; ALL: jr $25

; ALL-LABEL: __call_stub_fp_external_double:
; LE32: mtc1 $4, $f12
; LE32-NEXT: mtc1 $5, $f13
; LE64: mtc1 $4, $f12
; LE64-NEXT: mthc1 $5, $f12
; BE32: mtc1 $5, $f12
; BE32-NEXT: mtc1 $4, $f13
; BE64: mtc1 $5, $f12
; BE64-NEXT: mthc1 $4, $f12
; ALL: jal external_double
; LE32: mfc1 $2, $f0
; LE32-NEXT: mfc1 $3, $f1
; LE64: mfc1 $2, $f0
; LE64-NEXT: mfhc1 $3, $f0
; BE32: mfc1 $3, $f0
; BE32-NEXT: mfc1 $2, $f1
; BE64: mfc1 $3, $f0
; BE64-NEXT: mfhc1 $2, $f0
; ALL: jr $18


; FIX-LE32-LABEL: __call_stub_fp___fixdfdi:
; FIX-LE32: mtc1 $4, $f12
; FIX-LE32-NEXT: mtc1 $5, $f13
; FIX-LE32: jal __fixdfdi
; FIX-LE32: jr $18

; RET-LE32-LABEL: __call_stub_fp___floatdidf:
; RET-LE32: jal __floatdidf
; RET-LE32: mfc1 $2, $f0
; RET-LE32-NEXT: mfc1 $3, $f1
; RET-LE32: jr $18

; FIX-LE64-LABEL: __call_stub_fp___fixdfdi:
; FIX-LE64: mtc1 $4, $f12
; FIX-LE64-NEXT: mthc1 $5, $f12
; FIX-LE64: jal __fixdfdi
; FIX-LE64: jr $18

; RET-LE64-LABEL: __call_stub_fp___floatdidf:
; RET-LE64: jal __floatdidf
; RET-LE64: mfc1 $2, $f0
; RET-LE64-NEXT: mfhc1 $3, $f0
; RET-LE64: jr $18

; FIX-BE32-LABEL: __call_stub_fp___fixdfdi:
; FIX-BE32: mtc1 $5, $f12
; FIX-BE32-NEXT: mtc1 $4, $f13
; FIX-BE32: jal __fixdfdi
; FIX-BE32: jr $18

; RET-BE32-LABEL: __call_stub_fp___floatdidf:
; RET-BE32: jal __floatdidf
; RET-BE32: mfc1 $3, $f0
; RET-BE32-NEXT: mfc1 $2, $f1
; RET-BE32: jr $18

; FIX-BE64-LABEL: __call_stub_fp___fixdfdi:
; FIX-BE64: mtc1 $5, $f12
; FIX-BE64-NEXT: mthc1 $4, $f12
; FIX-BE64: jal __fixdfdi
; FIX-BE64: jr $18

; RET-BE64-LABEL: __call_stub_fp___floatdidf:
; RET-BE64: jal __floatdidf
; RET-BE64: mfc1 $3, $f0
; RET-BE64-NEXT: mfhc1 $2, $f0
; RET-BE64: jr $18

