// RUN: %clang_cc1 -triple aarch64-none-linux-gnu -target-feature +fullfp16 \
// RUN:   -disable-O0-optnone -emit-llvm -o - %s \
// RUN:   | opt -S -passes=mem2reg | FileCheck %s

unsigned short scvtf_w(unsigned long long value) {
  return __builtin_arm_scvtf_fixed(value, 16, 0);
// CHECK-LABEL: define{{.*}} i16 @scvtf_w(i64{{.*}} %value)
// CHECK: [[W:%.*]] = trunc i64 %value to i32
// CHECK: [[H:%.*]] = call half @llvm.aarch64.scvtf.fixed.i32(i32 [[W]], i32 16)
// CHECK: [[BITS:%.*]] = bitcast half [[H]] to i16
// CHECK: ret i16 [[BITS]]
}

unsigned short scvtf_x(unsigned long long value) {
  return __builtin_arm_scvtf_fixed(value, 64, 1);
// CHECK-LABEL: define{{.*}} i16 @scvtf_x(i64{{.*}} %value)
// CHECK: [[H:%.*]] = call half @llvm.aarch64.scvtf.fixed.i64(i64 %value, i32 64)
// CHECK: [[BITS:%.*]] = bitcast half [[H]] to i16
// CHECK: ret i16 [[BITS]]
}

unsigned short ucvtf_w(unsigned long long value) {
  return __builtin_arm_ucvtf_fixed(value, 16, 0);
// CHECK-LABEL: define{{.*}} i16 @ucvtf_w(i64{{.*}} %value)
// CHECK: [[W:%.*]] = trunc i64 %value to i32
// CHECK: call half @llvm.aarch64.ucvtf.fixed.i32(i32 [[W]], i32 16)
}

unsigned short ucvtf_x(unsigned long long value) {
  return __builtin_arm_ucvtf_fixed(value, 64, 1);
// CHECK-LABEL: define{{.*}} i16 @ucvtf_x(i64{{.*}} %value)
// CHECK: call half @llvm.aarch64.ucvtf.fixed.i64(i64 %value, i32 64)
}

unsigned long long fcvtzs_w(unsigned short value) {
  return __builtin_arm_fcvtzs_fixed(value, 16, 0);
// CHECK-LABEL: define{{.*}} i64 @fcvtzs_w(i16{{.*}} %value)
// CHECK: [[H:%.*]] = bitcast i16 %value to half
// CHECK: [[W:%.*]] = call i32 @llvm.aarch64.fcvtzs.fixed.i32(half [[H]], i32 16)
// CHECK: [[X:%.*]] = zext i32 [[W]] to i64
// CHECK: ret i64 [[X]]
}

unsigned long long fcvtzs_x(unsigned short value) {
  return __builtin_arm_fcvtzs_fixed(value, 64, 1);
// CHECK-LABEL: define{{.*}} i64 @fcvtzs_x(i16{{.*}} %value)
// CHECK: [[H:%.*]] = bitcast i16 %value to half
// CHECK: [[X:%.*]] = call i64 @llvm.aarch64.fcvtzs.fixed.i64(half [[H]], i32 64)
// CHECK: ret i64 [[X]]
}

unsigned long long fcvtzu_w(unsigned short value) {
  return __builtin_arm_fcvtzu_fixed(value, 16, 0);
// CHECK-LABEL: define{{.*}} i64 @fcvtzu_w(i16{{.*}} %value)
// CHECK: call i32 @llvm.aarch64.fcvtzu.fixed.i32(half {{%.*}}, i32 16)
}

unsigned long long fcvtzu_x(unsigned short value) {
  return __builtin_arm_fcvtzu_fixed(value, 64, 1);
// CHECK-LABEL: define{{.*}} i64 @fcvtzu_x(i16{{.*}} %value)
// CHECK: call i64 @llvm.aarch64.fcvtzu.fixed.i64(half {{%.*}}, i32 64)
}
