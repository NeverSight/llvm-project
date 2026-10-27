; RUN: llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: opt -S -passes="default<O2>" < %s | llc -mtriple=x86_64-unknown-linux-gnu -verify-machineinstrs | FileCheck %s
; RUN: opt -S -passes="default<O2>" < %s | llc -mtriple=i386-unknown-linux-gnu -verify-machineinstrs | FileCheck %s

; Value intrinsics retain native 3DNow arithmetic; no ordinary floating-point
; approximation, inline assembly or unresolved call supplies the operation.

define void @pavgusb_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pavgusb_reg:
; CHECK: pavgusb
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pavgusb(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pavgusb_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pavgusb_mem:
; CHECK: pavgusb
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pavgusb(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pf2id_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pf2id_reg:
; CHECK: pf2id
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pf2id(x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pf2id_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pf2id_mem:
; CHECK: pf2id
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pf2id(<1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfacc_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfacc_reg:
; CHECK: pfacc
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfacc(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfacc_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfacc_mem:
; CHECK: pfacc
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfacc(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfadd_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfadd_reg:
; CHECK: pfadd
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfadd(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfadd_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfadd_mem:
; CHECK: pfadd
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfadd(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfcmpeq_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfcmpeq_reg:
; CHECK: pfcmpeq
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfcmpeq(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfcmpeq_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfcmpeq_mem:
; CHECK: pfcmpeq
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfcmpeq(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfcmpge_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfcmpge_reg:
; CHECK: pfcmpge
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfcmpge(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfcmpge_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfcmpge_mem:
; CHECK: pfcmpge
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfcmpge(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfcmpgt_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfcmpgt_reg:
; CHECK: pfcmpgt
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfcmpgt(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfcmpgt_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfcmpgt_mem:
; CHECK: pfcmpgt
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfcmpgt(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfmax_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfmax_reg:
; CHECK: pfmax
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfmax(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfmax_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfmax_mem:
; CHECK: pfmax
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfmax(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfmin_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfmin_reg:
; CHECK: pfmin
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfmin(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfmin_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfmin_mem:
; CHECK: pfmin
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfmin(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfmul_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfmul_reg:
; CHECK: pfmul
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfmul(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfmul_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfmul_mem:
; CHECK: pfmul
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfmul(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfrcp_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfrcp_reg:
; CHECK: pfrcp
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfrcp(x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfrcp_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfrcp_mem:
; CHECK: pfrcp
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfrcp(<1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfrcpit1_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfrcpit1_reg:
; CHECK: pfrcpit1
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfrcpit1(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfrcpit1_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfrcpit1_mem:
; CHECK: pfrcpit1
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfrcpit1(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfrcpit2_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfrcpit2_reg:
; CHECK: pfrcpit2
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfrcpit2(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfrcpit2_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfrcpit2_mem:
; CHECK: pfrcpit2
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfrcpit2(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfrsqit1_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfrsqit1_reg:
; CHECK: pfrsqit1
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfrsqit1(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfrsqit1_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfrsqit1_mem:
; CHECK: pfrsqit1
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfrsqit1(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfrsqrt_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfrsqrt_reg:
; CHECK: pfrsqrt
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfrsqrt(x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfrsqrt_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfrsqrt_mem:
; CHECK: pfrsqrt
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfrsqrt(<1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfsub_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfsub_reg:
; CHECK: {{pfsubr?}}
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfsub(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfsub_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfsub_mem:
; CHECK: {{pfsubr?}}
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfsub(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfsubr_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfsubr_reg:
; CHECK: {{pfsubr?}}
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pfsubr(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfsubr_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfsubr_mem:
; CHECK: {{pfsubr?}}
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pfsubr(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pi2fd_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pi2fd_reg:
; CHECK: pi2fd
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pi2fd(x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pi2fd_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pi2fd_mem:
; CHECK: pi2fd
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pi2fd(<1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pmulhrw_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pmulhrw_reg:
; CHECK: pmulhrw
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnow.pmulhrw(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pmulhrw_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pmulhrw_mem:
; CHECK: pmulhrw
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnow.pmulhrw(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pf2iw_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pf2iw_reg:
; CHECK: pf2iw
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnowa.pf2iw(x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pf2iw_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pf2iw_mem:
; CHECK: pf2iw
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnowa.pf2iw(<1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfnacc_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfnacc_reg:
; CHECK: pfnacc
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnowa.pfnacc(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfnacc_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfnacc_mem:
; CHECK: pfnacc
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnowa.pfnacc(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfpnacc_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfpnacc_reg:
; CHECK: pfpnacc
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnowa.pfpnacc(x86_mmx %left, x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pfpnacc_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pfpnacc_mem:
; CHECK: pfpnacc
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnowa.pfpnacc(<1 x i64> %left, <1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pi2fw_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pi2fw_reg:
; CHECK: pi2fw
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnowa.pi2fw(x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pi2fw_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pi2fw_mem:
; CHECK: pi2fw
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnowa.pi2fw(<1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pswapd_reg(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pswapd_reg:
; CHECK: pswapd
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to x86_mmx
  %right = bitcast i64 %b to x86_mmx
  %result = call x86_mmx @llvm.x86.3dnowa.pswapd(x86_mmx %right)
  store x86_mmx %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

define void @pswapd_mem(i64 %a, i64 %b, ptr %source, ptr %out) #0 {
; CHECK-LABEL: pswapd_mem:
; CHECK: pswapd
; CHECK: femms
; CHECK-NOT: call
; CHECK: ret
  %left = bitcast i64 %a to <1 x i64>
  %right = load <1 x i64>, ptr %source, align 1
  %result = call <1 x i64> @llvm.x86.3dnowa.pswapd(<1 x i64> %right)
  store <1 x i64> %result, ptr %out, align 1
  call void @llvm.x86.mmx.femms()
  ret void
}

declare x86_mmx @llvm.x86.3dnow.pavgusb(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pf2id(x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfacc(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfadd(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfcmpeq(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfcmpge(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfcmpgt(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfmax(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfmin(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfmul(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfrcp(x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfrcpit1(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfrcpit2(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfrsqit1(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfrsqrt(x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfsub(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pfsubr(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pi2fd(x86_mmx)
declare x86_mmx @llvm.x86.3dnow.pmulhrw(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnowa.pf2iw(x86_mmx)
declare x86_mmx @llvm.x86.3dnowa.pfnacc(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnowa.pfpnacc(x86_mmx, x86_mmx)
declare x86_mmx @llvm.x86.3dnowa.pi2fw(x86_mmx)
declare x86_mmx @llvm.x86.3dnowa.pswapd(x86_mmx)
declare void @llvm.x86.mmx.femms()
attributes #0 = { "target-features"="+3dnowa" }
