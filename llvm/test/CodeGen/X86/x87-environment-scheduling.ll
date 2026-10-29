; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes='default<O2>' < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s

; TOP/tag changes invalidate compiler-owned stack values, even for FLDENV,
; which leaves physical payloads intact. MMX aliases need the same boundary.
declare void @llvm.x86.fninit()
declare <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64>, <1 x i64>)
declare <1 x i64> @llvm.x86.mmx.pxor(<1 x i64>, <1 x i64>)

declare void @llvm.x86.fldenv16(ptr)
define x86_fp80 @live_x87_fldenv16(ptr %state, ptr %in, ptr %other) {
; CHECK-LABEL: live_x87_fldenv16:
; CHECK: fldt
; CHECK: fstpt
; CHECK: fldenvs
; CHECK: fldt
; CHECK: fadd
; CHECK: ret
  %a = load volatile x86_fp80, ptr %in, align 1
  call void @llvm.x86.fldenv16(ptr %state)
  %b = load volatile x86_fp80, ptr %other, align 1
  %r = fadd x86_fp80 %a, %b
  ret x86_fp80 %r
}
define i64 @live_mmx_fldenv16(ptr %state, i64 %a, i64 %b) #0 {
; CHECK-LABEL: live_mmx_fldenv16:
; CHECK: paddb
; CHECK: movq %mm{{[0-7]}},
; CHECK: fldenvs
; CHECK: movq {{.*}}, %mm{{[0-7]}}
; CHECK: pxor
; CHECK: fninit
; CHECK-NOT: %mm
; CHECK: ret
  %x = bitcast i64 %a to <1 x i64>
  %y = bitcast i64 %b to <1 x i64>
  %sum = call <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64> %x, <1 x i64> %y)
  call void @llvm.x86.fldenv16(ptr %state)
  %mixed = call <1 x i64> @llvm.x86.mmx.pxor(<1 x i64> %sum, <1 x i64> %x)
  %bits = bitcast <1 x i64> %mixed to i64
  call void @llvm.x86.fninit()
  ret i64 %bits
}

declare void @llvm.x86.fldenv32(ptr)
define x86_fp80 @live_x87_fldenv32(ptr %state, ptr %in, ptr %other) {
; CHECK-LABEL: live_x87_fldenv32:
; CHECK: fldt
; CHECK: fstpt
; CHECK: fldenv
; CHECK: fldt
; CHECK: fadd
; CHECK: ret
  %a = load volatile x86_fp80, ptr %in, align 1
  call void @llvm.x86.fldenv32(ptr %state)
  %b = load volatile x86_fp80, ptr %other, align 1
  %r = fadd x86_fp80 %a, %b
  ret x86_fp80 %r
}
define i64 @live_mmx_fldenv32(ptr %state, i64 %a, i64 %b) #0 {
; CHECK-LABEL: live_mmx_fldenv32:
; CHECK: paddb
; CHECK: movq %mm{{[0-7]}},
; CHECK: fldenv
; CHECK: movq {{.*}}, %mm{{[0-7]}}
; CHECK: pxor
; CHECK: fninit
; CHECK-NOT: %mm
; CHECK: ret
  %x = bitcast i64 %a to <1 x i64>
  %y = bitcast i64 %b to <1 x i64>
  %sum = call <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64> %x, <1 x i64> %y)
  call void @llvm.x86.fldenv32(ptr %state)
  %mixed = call <1 x i64> @llvm.x86.mmx.pxor(<1 x i64> %sum, <1 x i64> %x)
  %bits = bitcast <1 x i64> %mixed to i64
  call void @llvm.x86.fninit()
  ret i64 %bits
}

declare void @llvm.x86.fnsave16(ptr)
define x86_fp80 @live_x87_fnsave16(ptr %state, ptr %in, ptr %other) {
; CHECK-LABEL: live_x87_fnsave16:
; CHECK: fldt
; CHECK: fstpt
; CHECK: fnsaves
; CHECK: fldt
; CHECK: fadd
; CHECK: ret
  %a = load volatile x86_fp80, ptr %in, align 1
  call void @llvm.x86.fnsave16(ptr %state)
  %b = load volatile x86_fp80, ptr %other, align 1
  %r = fadd x86_fp80 %a, %b
  ret x86_fp80 %r
}
define i64 @live_mmx_fnsave16(ptr %state, i64 %a, i64 %b) #0 {
; CHECK-LABEL: live_mmx_fnsave16:
; CHECK: paddb
; CHECK: movq %mm{{[0-7]}},
; CHECK: fnsaves
; CHECK: movq {{.*}}, %mm{{[0-7]}}
; CHECK: pxor
; CHECK: fninit
; CHECK-NOT: %mm
; CHECK: ret
  %x = bitcast i64 %a to <1 x i64>
  %y = bitcast i64 %b to <1 x i64>
  %sum = call <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64> %x, <1 x i64> %y)
  call void @llvm.x86.fnsave16(ptr %state)
  %mixed = call <1 x i64> @llvm.x86.mmx.pxor(<1 x i64> %sum, <1 x i64> %x)
  %bits = bitcast <1 x i64> %mixed to i64
  call void @llvm.x86.fninit()
  ret i64 %bits
}

declare void @llvm.x86.fnsave32(ptr)
define x86_fp80 @live_x87_fnsave32(ptr %state, ptr %in, ptr %other) {
; CHECK-LABEL: live_x87_fnsave32:
; CHECK: fldt
; CHECK: fstpt
; CHECK: fnsave
; CHECK: fldt
; CHECK: fadd
; CHECK: ret
  %a = load volatile x86_fp80, ptr %in, align 1
  call void @llvm.x86.fnsave32(ptr %state)
  %b = load volatile x86_fp80, ptr %other, align 1
  %r = fadd x86_fp80 %a, %b
  ret x86_fp80 %r
}
define i64 @live_mmx_fnsave32(ptr %state, i64 %a, i64 %b) #0 {
; CHECK-LABEL: live_mmx_fnsave32:
; CHECK: paddb
; CHECK: movq %mm{{[0-7]}},
; CHECK: fnsave
; CHECK: movq {{.*}}, %mm{{[0-7]}}
; CHECK: pxor
; CHECK: fninit
; CHECK-NOT: %mm
; CHECK: ret
  %x = bitcast i64 %a to <1 x i64>
  %y = bitcast i64 %b to <1 x i64>
  %sum = call <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64> %x, <1 x i64> %y)
  call void @llvm.x86.fnsave32(ptr %state)
  %mixed = call <1 x i64> @llvm.x86.mmx.pxor(<1 x i64> %sum, <1 x i64> %x)
  %bits = bitcast <1 x i64> %mixed to i64
  call void @llvm.x86.fninit()
  ret i64 %bits
}

declare void @llvm.x86.frstor16(ptr)
define x86_fp80 @live_x87_frstor16(ptr %state, ptr %in, ptr %other) {
; CHECK-LABEL: live_x87_frstor16:
; CHECK: fldt
; CHECK: fstpt
; CHECK: frstors
; CHECK: fldt
; CHECK: fadd
; CHECK: ret
  %a = load volatile x86_fp80, ptr %in, align 1
  call void @llvm.x86.frstor16(ptr %state)
  %b = load volatile x86_fp80, ptr %other, align 1
  %r = fadd x86_fp80 %a, %b
  ret x86_fp80 %r
}
define i64 @live_mmx_frstor16(ptr %state, i64 %a, i64 %b) #0 {
; CHECK-LABEL: live_mmx_frstor16:
; CHECK: paddb
; CHECK: movq %mm{{[0-7]}},
; CHECK: frstors
; CHECK: movq {{.*}}, %mm{{[0-7]}}
; CHECK: pxor
; CHECK: fninit
; CHECK-NOT: %mm
; CHECK: ret
  %x = bitcast i64 %a to <1 x i64>
  %y = bitcast i64 %b to <1 x i64>
  %sum = call <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64> %x, <1 x i64> %y)
  call void @llvm.x86.frstor16(ptr %state)
  %mixed = call <1 x i64> @llvm.x86.mmx.pxor(<1 x i64> %sum, <1 x i64> %x)
  %bits = bitcast <1 x i64> %mixed to i64
  call void @llvm.x86.fninit()
  ret i64 %bits
}

declare void @llvm.x86.frstor32(ptr)
define x86_fp80 @live_x87_frstor32(ptr %state, ptr %in, ptr %other) {
; CHECK-LABEL: live_x87_frstor32:
; CHECK: fldt
; CHECK: fstpt
; CHECK: frstor
; CHECK: fldt
; CHECK: fadd
; CHECK: ret
  %a = load volatile x86_fp80, ptr %in, align 1
  call void @llvm.x86.frstor32(ptr %state)
  %b = load volatile x86_fp80, ptr %other, align 1
  %r = fadd x86_fp80 %a, %b
  ret x86_fp80 %r
}
define i64 @live_mmx_frstor32(ptr %state, i64 %a, i64 %b) #0 {
; CHECK-LABEL: live_mmx_frstor32:
; CHECK: paddb
; CHECK: movq %mm{{[0-7]}},
; CHECK: frstor
; CHECK: movq {{.*}}, %mm{{[0-7]}}
; CHECK: pxor
; CHECK: fninit
; CHECK-NOT: %mm
; CHECK: ret
  %x = bitcast i64 %a to <1 x i64>
  %y = bitcast i64 %b to <1 x i64>
  %sum = call <1 x i64> @llvm.x86.mmx.padd.b(<1 x i64> %x, <1 x i64> %y)
  call void @llvm.x86.frstor32(ptr %state)
  %mixed = call <1 x i64> @llvm.x86.mmx.pxor(<1 x i64> %sum, <1 x i64> %x)
  %bits = bitcast <1 x i64> %mixed to i64
  call void @llvm.x86.fninit()
  ret i64 %bits
}

attributes #0 = { "target-features"="+mmx" }
