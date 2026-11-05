// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple i386-pc-windows-msvc -emit-llvm -o - %s | FileCheck %s

typedef unsigned _BitInt(97) U97;

U97 indirect(int count, ...) {
  __builtin_va_list args;
  __builtin_va_start(args, count);
  U97 result = __builtin_va_arg(args, U97);
  __builtin_va_end(args);
  return result;
}
// CHECK-LABEL: define {{.*}}void @indirect(
// CHECK: [[SLOT:%.*]] = load ptr, ptr
// CHECK: [[NEXT:%.*]] = getelementptr inbounds i8, ptr [[SLOT]], i32 4
// CHECK: store ptr [[NEXT]], ptr
// CHECK: [[VALUE:%.*]] = load ptr, ptr [[SLOT]], align 4
// CHECK: load i128, ptr [[VALUE]], align {{[48]}}

struct Pair { unsigned a, b; };
struct Pair direct_record(int count, ...) {
  __builtin_va_list args;
  __builtin_va_start(args, count);
  struct Pair result = __builtin_va_arg(args, struct Pair);
  __builtin_va_end(args);
  return result;
}
// CHECK-LABEL: define {{.*}} @direct_record(
// CHECK: [[SLOT:%.*]] = load ptr, ptr
// CHECK: [[NEXT:%.*]] = getelementptr inbounds i8, ptr [[SLOT]], i32 8
// CHECK: store ptr [[NEXT]], ptr
// CHECK: call void @llvm.memcpy{{.*}}ptr align 4 [[SLOT]], i32 8

unsigned long long direct_integer(int count, ...) {
  __builtin_va_list args;
  __builtin_va_start(args, count);
  unsigned long long result = __builtin_va_arg(args, unsigned long long);
  __builtin_va_end(args);
  return result;
}
// CHECK-LABEL: define {{.*}}i64 @direct_integer(
// CHECK: [[SLOT:%.*]] = load ptr, ptr
// CHECK: [[NEXT:%.*]] = getelementptr inbounds i8, ptr [[SLOT]], i32 8
// CHECK: store ptr [[NEXT]], ptr
// CHECK: load i64, ptr [[SLOT]], align 4
