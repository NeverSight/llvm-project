// RUN: %clang_cc1 -triple aarch64-none-linux-gnu -target-feature +mte -emit-llvm -o - %s | FileCheck %s

void *subg(void *pointer) {
  // CHECK-LABEL: define{{.*}} ptr @subg
  // CHECK: call ptr @llvm.aarch64.subg(ptr {{.*}}, i64 112, i64 9)
  return __builtin_arm_subg(pointer, 112, 9);
}
