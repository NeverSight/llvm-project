; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32r2 -mattr=+mips16,-fp64 -relocation-model=static < %s | FileCheck %s --check-prefixes=ALL,LE32
; RUN: llc -mtriple=mipsel-linux-gnu -mcpu=mips32r2 -mattr=+mips16,+fp64 -relocation-model=static < %s | FileCheck %s --check-prefixes=ALL,LE64
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32r2 -mattr=+mips16,-fp64 -relocation-model=static < %s | FileCheck %s --check-prefixes=ALL,BE32
; RUN: llc -mtriple=mips-linux-gnu -mcpu=mips32r2 -mattr=+mips16,+fp64 -relocation-model=static < %s | FileCheck %s --check-prefixes=ALL,BE64

declare { float, float } @complex_single()
declare { double, double } @complex_double()

define void @caller() {
  %s = call { float, float } @complex_single()
  %d = call { double, double } @complex_double()
  ret void
}

; ALL-LABEL: __call_stub_fp_complex_single:
; ALL: jal complex_single
; ALL: mfc1 $2, $f0
; ALL-NEXT: mfc1 $3, $f2
; ALL: jr $18
; ALL-LABEL: __call_stub_fp_complex_double:
; ALL: jal complex_double
; LE32: mfc1 $2, $f0
; LE32-NEXT: mfc1 $3, $f1
; LE32-NEXT: mfc1 $4, $f2
; LE32-NEXT: mfc1 $5, $f3
; LE64: mfc1 $2, $f0
; LE64-NEXT: mfhc1 $3, $f0
; LE64-NEXT: mfc1 $4, $f2
; LE64-NEXT: mfhc1 $5, $f2
; BE32: mfc1 $3, $f0
; BE32-NEXT: mfc1 $2, $f1
; BE32-NEXT: mfc1 $5, $f2
; BE32-NEXT: mfc1 $4, $f3
; BE64: mfc1 $3, $f0
; BE64-NEXT: mfhc1 $2, $f0
; BE64-NEXT: mfc1 $5, $f2
; BE64-NEXT: mfhc1 $4, $f2
; ALL: jr $18
