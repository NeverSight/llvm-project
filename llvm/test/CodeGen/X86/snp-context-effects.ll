; RUN: opt -S -passes='default<O2>' < %s | FileCheck %s
; Every invocation and each surrounding memory access remains observable.
@shared = external global i64
declare void @llvm.x86.rmpquery.context(ptr, ptr, i32 immarg)
declare void @llvm.x86.vmgexit.sev(i64)
define i64 @effects(ptr %g, ptr %f) {
; CHECK-LABEL: define i64 @effects
; CHECK: store i64 17, ptr @shared
; CHECK: call void @llvm.x86.rmpquery.context
; CHECK: call void @llvm.x86.rmpquery.context
; CHECK: %a = load i64, ptr @shared
; CHECK: call void @llvm.x86.vmgexit.sev(i64 %a)
; CHECK: %b = load i64, ptr @shared
  store i64 17, ptr @shared
  call void @llvm.x86.rmpquery.context(ptr %g, ptr %f, i32 0)
  call void @llvm.x86.rmpquery.context(ptr %g, ptr %f, i32 0)
  %a = load i64, ptr @shared
  call void @llvm.x86.vmgexit.sev(i64 %a)
  %b = load i64, ptr @shared
  ret i64 %b
}
; CHECK: attributes {{.*}}convergent noduplicate nounwind
; CHECK-NOT: memory(
