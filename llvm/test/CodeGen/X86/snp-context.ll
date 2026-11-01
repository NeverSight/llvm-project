; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -enable-new-pm -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O2 -filetype=obj -verify-machineinstrs < %s -o %t.obj
; RUN: llc -mtriple=x86_64-apple-darwin -O2 -filetype=obj -verify-machineinstrs < %s -o %t.o
; RUN: not --crash llc -mtriple=i386-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=MODE
; MODE: SNP context requires 64-bit mode
;
; Outputs must reach their separate, possibly unaligned objects before flag
; capture clobbers RAX/RCX/RDX. Unchanged flags remain the caller's snapshot.

declare void @llvm.x86.psmash.context(ptr, ptr, i32 immarg)
define void @psmash(ptr %g, ptr %f) {
; CHECK-LABEL: psmash:
; CHECK: movq (%r10), %rax
; CHECK-NEXT: psmash
; CHECK-NEXT: movq %rax, (%r10)
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %cl
; CHECK-NEXT: movzbl %ah, %eax
; CHECK-NEXT: movzbl %cl, %ecx
; CHECK-NEXT: shll $11, %ecx
; CHECK-NEXT: orl %ecx, %eax
; CHECK-NEXT: andl $2260, %eax
; CHECK-NEXT: movq (%r11), %rdx
; CHECK-NEXT: andq $-2261, %rdx
; CHECK-NEXT: orq %rax, %rdx
; CHECK-NEXT: movq %rdx, (%r11)
; CHECK: retq
  call void @llvm.x86.psmash.context(ptr %g, ptr %f, i32 0)
  ret void
}

declare void @llvm.x86.pvalidate.context(ptr, ptr, i32 immarg)
define void @pvalidate(ptr %g, ptr %f) {
; CHECK-LABEL: pvalidate:
; CHECK: movq (%r10), %rax
; CHECK: movq 8(%r10), %rcx
; CHECK: movq 16(%r10), %rdx
; CHECK-NEXT: pvalidate
; CHECK-NEXT: movq %rax, (%r10)
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %cl
; CHECK-NEXT: movzbl %ah, %eax
; CHECK-NEXT: movzbl %cl, %ecx
; CHECK-NEXT: shll $11, %ecx
; CHECK-NEXT: orl %ecx, %eax
; CHECK-NEXT: andl $2261, %eax
; CHECK-NEXT: movq (%r11), %rdx
; CHECK-NEXT: andq $-2262, %rdx
; CHECK-NEXT: orq %rax, %rdx
; CHECK-NEXT: movq %rdx, (%r11)
; CHECK: retq
  call void @llvm.x86.pvalidate.context(ptr %g, ptr %f, i32 0)
  ret void
}

declare void @llvm.x86.rmpadjust.context(ptr, ptr, i32 immarg)
define void @rmpadjust(ptr %g, ptr %f) {
; CHECK-LABEL: rmpadjust:
; CHECK: movq (%r10), %rax
; CHECK: movq 8(%r10), %rcx
; CHECK: movq 16(%r10), %rdx
; CHECK-NEXT: rmpadjust
; CHECK-NEXT: movq %rax, (%r10)
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %cl
; CHECK-NEXT: movzbl %ah, %eax
; CHECK-NEXT: movzbl %cl, %ecx
; CHECK-NEXT: shll $11, %ecx
; CHECK-NEXT: orl %ecx, %eax
; CHECK-NEXT: andl $2260, %eax
; CHECK-NEXT: movq (%r11), %rdx
; CHECK-NEXT: andq $-2261, %rdx
; CHECK-NEXT: orq %rax, %rdx
; CHECK-NEXT: movq %rdx, (%r11)
; CHECK: retq
  call void @llvm.x86.rmpadjust.context(ptr %g, ptr %f, i32 0)
  ret void
}

declare void @llvm.x86.rmpupdate.context(ptr, ptr, i32 immarg)
define void @rmpupdate(ptr %g, ptr %f) {
; CHECK-LABEL: rmpupdate:
; CHECK: movq (%r10), %rax
; CHECK: movq 8(%r10), %rcx
; CHECK-NEXT: rmpupdate
; CHECK-NEXT: movq %rax, (%r10)
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %cl
; CHECK-NEXT: movzbl %ah, %eax
; CHECK-NEXT: movzbl %cl, %ecx
; CHECK-NEXT: shll $11, %ecx
; CHECK-NEXT: orl %ecx, %eax
; CHECK-NEXT: andl $2260, %eax
; CHECK-NEXT: movq (%r11), %rdx
; CHECK-NEXT: andq $-2261, %rdx
; CHECK-NEXT: orq %rax, %rdx
; CHECK-NEXT: movq %rdx, (%r11)
; CHECK: retq
  call void @llvm.x86.rmpupdate.context(ptr %g, ptr %f, i32 0)
  ret void
}

declare void @llvm.x86.rmpquery.context(ptr, ptr, i32 immarg)
define void @rmpquery(ptr %g, ptr %f) {
; CHECK-LABEL: rmpquery:
; CHECK: movq (%r10), %rax
; CHECK: movq 16(%r10), %rdx
; CHECK-NEXT: rmpquery
; CHECK-NEXT: movq %rax, (%r10)
; CHECK-NEXT: movq %rcx, 8(%r10)
; CHECK-NEXT: movq %rdx, 16(%r10)
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %cl
; CHECK-NEXT: movzbl %ah, %eax
; CHECK-NEXT: movzbl %cl, %ecx
; CHECK-NEXT: shll $11, %ecx
; CHECK-NEXT: orl %ecx, %eax
; CHECK-NEXT: andl $2260, %eax
; CHECK-NEXT: movq (%r11), %rdx
; CHECK-NEXT: andq $-2261, %rdx
; CHECK-NEXT: orq %rax, %rdx
; CHECK-NEXT: movq %rdx, (%r11)
; CHECK: retq
  call void @llvm.x86.rmpquery.context(ptr %g, ptr %f, i32 0)
  ret void
}

declare void @llvm.x86.rmpread.context(ptr, ptr, i32 immarg)
define void @rmpread(ptr %g, ptr %f) {
; CHECK-LABEL: rmpread:
; CHECK: movq (%r10), %rax
; CHECK: movq 8(%r10), %rcx
; CHECK-NEXT: rmpread
; CHECK-NEXT: movq %rax, (%r10)
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %cl
; CHECK-NEXT: movzbl %ah, %eax
; CHECK-NEXT: movzbl %cl, %ecx
; CHECK-NEXT: shll $11, %ecx
; CHECK-NEXT: orl %ecx, %eax
; CHECK-NEXT: andl $2260, %eax
; CHECK-NEXT: movq (%r11), %rdx
; CHECK-NEXT: andq $-2261, %rdx
; CHECK-NEXT: orq %rax, %rdx
; CHECK-NEXT: movq %rdx, (%r11)
; CHECK: retq
  call void @llvm.x86.rmpread.context(ptr %g, ptr %f, i32 0)
  ret void
}

declare void @llvm.x86.rmpopt.context(ptr, ptr, i32 immarg)
define void @rmpopt(ptr %g, ptr %f) {
; CHECK-LABEL: rmpopt:
; CHECK: movq (%r10), %rax
; CHECK: movq 8(%r10), %rcx
; CHECK-NEXT: rmpopt
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %cl
; CHECK-NEXT: movzbl %ah, %eax
; CHECK-NEXT: movzbl %cl, %ecx
; CHECK-NEXT: shll $11, %ecx
; CHECK-NEXT: orl %ecx, %eax
; CHECK-NEXT: andl $1, %eax
; CHECK-NEXT: movq (%r11), %rdx
; CHECK-NEXT: andq $-2, %rdx
; CHECK-NEXT: orq %rax, %rdx
; CHECK-NEXT: movq %rdx, (%r11)
; CHECK: retq
  call void @llvm.x86.rmpopt.context(ptr %g, ptr %f, i32 0)
  ret void
}

declare void @llvm.x86.rmpchkd.context(ptr, ptr, i32 immarg)
define void @rmpchkd(ptr %g, ptr %f) {
; CHECK-LABEL: rmpchkd:
; CHECK: movq (%r10), %rax
; CHECK: movq 8(%r10), %rcx
; CHECK-NEXT: rmpchkd
; CHECK-NEXT: movq %rax, (%r10)
; CHECK-NEXT: movq %rcx, 8(%r10)
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %cl
; CHECK-NEXT: movzbl %ah, %eax
; CHECK-NEXT: movzbl %cl, %ecx
; CHECK-NEXT: shll $11, %ecx
; CHECK-NEXT: orl %ecx, %eax
; CHECK-NEXT: andl $2261, %eax
; CHECK-NEXT: movq (%r11), %rdx
; CHECK-NEXT: andq $-2262, %rdx
; CHECK-NEXT: orq %rax, %rdx
; CHECK-NEXT: movq %rdx, (%r11)
; CHECK: retq
  call void @llvm.x86.rmpchkd.context(ptr %g, ptr %f, i32 0)
  ret void
}

define void @address32(ptr %g, ptr %f) {
; CHECK-LABEL: address32:
; CHECK: addr32
; CHECK-NEXT: pvalidate
  call void @llvm.x86.pvalidate.context(ptr %g, ptr %f, i32 1)
  ret void
}
define void @segmented(ptr %g, ptr %f) {
; CHECK-LABEL: segmented:
; CHECK: gs
; CHECK-NEXT: rmpread
  call void @llvm.x86.rmpread.context(ptr %g, ptr %f, i32 25856)
  ret void
}
declare void @llvm.x86.vmgexit.sev(i64)
define void @guest_exit(i64 %parameter) {
; CHECK-LABEL: guest_exit:
; CHECK: movq %rdi, %rax
; CHECK-NEXT: vmgexit
; CHECK-NEXT: retq
  call void @llvm.x86.vmgexit.sev(i64 %parameter)
  ret void
}
