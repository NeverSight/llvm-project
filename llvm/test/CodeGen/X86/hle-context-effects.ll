; RUN: opt -passes='default<O2>' -S %s | FileCheck %s

declare void @llvm.x86.hle.context(ptr,ptr,ptr,i32 immarg,i32 immarg)

define void @both(ptr %memory, ptr %gprs, ptr %flags, ptr %other) {
; CHECK-LABEL: define void @both(
; CHECK: store i64 71, ptr %other
; CHECK-NEXT: call void @llvm.x86.hle.context(ptr %memory, ptr %gprs, ptr %flags, i32 785, i32 8)
; CHECK-NEXT: store i64 73, ptr %other
; CHECK-NEXT: call void @llvm.x86.hle.context(ptr %memory, ptr %gprs, ptr %flags, i32 530, i32 8)
; CHECK-NEXT: ret void
  store i64 71, ptr %other
  call void @llvm.x86.hle.context(ptr %memory,ptr %gprs,ptr %flags,i32 785,i32 8)
  store i64 73, ptr %other
  call void @llvm.x86.hle.context(ptr %memory,ptr %gprs,ptr %flags,i32 530,i32 8)
  ret void
}

; CHECK: attributes #{{[0-9]+}} = { convergent noduplicate nounwind }
