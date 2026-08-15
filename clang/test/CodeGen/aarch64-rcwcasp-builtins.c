// RUN: %clang_cc1 -triple aarch64-none-linux-gnu -target-feature +the \
// RUN:   -target-feature +d128 -O1 -emit-llvm -o - %s | FileCheck %s

typedef unsigned __int128 uint128_t;

#define TEST(name)                                                             \
  uint128_t test_##name(uint128_t expected, uint128_t desired, void *address) { \
    return __builtin_arm_##name(expected, desired, address);                    \
  }

TEST(rcwcasp)
TEST(rcwcaspa)
TEST(rcwcaspal)
TEST(rcwcaspl)
TEST(rcwscasp)
TEST(rcwscaspa)
TEST(rcwscaspal)
TEST(rcwscaspl)

// CHECK-LABEL: define{{.*}} i128 @test_rcwcasp(
// CHECK: call { i64, i64 } asm sideeffect "rcwcasp x0, x1, x2, x3, [x4]"
// CHECK-LABEL: define{{.*}} i128 @test_rcwcaspa(
// CHECK: call { i64, i64 } asm sideeffect "rcwcaspa x0, x1, x2, x3, [x4]"
// CHECK-LABEL: define{{.*}} i128 @test_rcwcaspal(
// CHECK: call { i64, i64 } asm sideeffect "rcwcaspal x0, x1, x2, x3, [x4]"
// CHECK-LABEL: define{{.*}} i128 @test_rcwcaspl(
// CHECK: call { i64, i64 } asm sideeffect "rcwcaspl x0, x1, x2, x3, [x4]"
// CHECK-LABEL: define{{.*}} i128 @test_rcwscasp(
// CHECK: call { i64, i64 } asm sideeffect "rcwscasp x0, x1, x2, x3, [x4]"
// CHECK-LABEL: define{{.*}} i128 @test_rcwscaspa(
// CHECK: call { i64, i64 } asm sideeffect "rcwscaspa x0, x1, x2, x3, [x4]"
// CHECK-LABEL: define{{.*}} i128 @test_rcwscaspal(
// CHECK: call { i64, i64 } asm sideeffect "rcwscaspal x0, x1, x2, x3, [x4]"
// CHECK-LABEL: define{{.*}} i128 @test_rcwscaspl(
// CHECK: call { i64, i64 } asm sideeffect "rcwscaspl x0, x1, x2, x3, [x4]"
