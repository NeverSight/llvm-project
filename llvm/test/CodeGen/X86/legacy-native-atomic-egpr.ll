; RUN: llc -mtriple=x86_64-linux-gnu -mattr=+egpr -verify-machineinstrs -stop-after=finalize-isel < %s | FileCheck %s --check-prefix=MIR
; RUN: llc -mtriple=x86_64-linux-gnu -mattr=+egpr -verify-machineinstrs -filetype=obj < %s -o %t
; RUN: llvm-objdump -d --mattr=+egpr %t | FileCheck %s
;
; Inputs arrive in APX-only registers. Native legacy operations must copy them
; into a low register class before allocation; MC encoding alone is too late.
declare void @llvm.x86.aadd64.legacy.address(i64, i64, i32 immarg, i32 immarg)
declare i64 @llvm.x86.cmpccxadd64.legacy.address(i64, i64, i64, i32 immarg, i32 immarg, i32 immarg)

; MIR-LABEL: name: pressure
; MIR: [[ADD:%[0-9]+]]:gr64_norex2 = COPY $r20
; MIR: [[CMP:%[0-9]+]]:gr64_norex2 = COPY $r21
; MIR: LEGACY_RAO_NATIVE64 {{.*}}[[ADD]]
; MIR: LEGACY_CMPCCXADD_NATIVE64 [[CMP]]{{.*}}[[ADD]]
; CHECK-LABEL: <pressure>:
; CHECK-NOT: {evex}
; CHECK: aaddq %r{{(ax|bx|cx|dx|si|di|bp|8|9|10|11|12|13|14|15)}}, (%rbx)
; CHECK-NOT: {evex}
; CHECK: cmpexadd %r{{(ax|bx|cx|dx|si|di|bp|8|9|10|11|12|13|14|15)}}, %r{{(ax|bx|cx|dx|si|di|bp|8|9|10|11|12|13|14|15)}}, (%rbx)
define i64 @pressure() {
  %add = call i64 asm sideeffect "", "={r20}"()
  %compare = call i64 asm sideeffect "", "={r21}"()
  %address = call i64 asm sideeffect "", "={r22}"()
  call void @llvm.x86.aadd64.legacy.address(i64 %address, i64 %add, i32 64, i32 0)
  %old = call i64 @llvm.x86.cmpccxadd64.legacy.address(i64 %address, i64 %compare, i64 %add, i32 4, i32 64, i32 0)
  ret i64 %old
}
