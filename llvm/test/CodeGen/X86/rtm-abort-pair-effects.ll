; RUN: opt -passes='default<O2>' -S %s | FileCheck %s

declare i32 @llvm.x86.rtm.abort.pair(i32 immarg)

define void @observable(ptr %p) {
; CHECK-LABEL: define void @observable(
; CHECK: store i32 71, ptr %p
; CHECK-NEXT: %a = {{.*}}call i32 @llvm.x86.rtm.abort.pair(i32 0)
; CHECK-NEXT: store i32 73, ptr %p
; CHECK-NEXT: %b = {{.*}}call i32 @llvm.x86.rtm.abort.pair(i32 255)
; CHECK-NEXT: ret void
  store i32 71, ptr %p
  %a = call i32 @llvm.x86.rtm.abort.pair(i32 0)
  store i32 73, ptr %p
  %b = call i32 @llvm.x86.rtm.abort.pair(i32 255)
  ret void
}

; CHECK: attributes #{{[0-9]+}} = { convergent noduplicate nounwind }
