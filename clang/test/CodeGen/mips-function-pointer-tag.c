// RUN: %clang_cc1 -triple mips-linux-gnu -target-cpu mips32r2 -DMODE=mips16 -emit-llvm -o - %s | FileCheck %s -DPTR=i32
// RUN: %clang_cc1 -triple mipsel-linux-gnu -target-cpu mips32r2 -DMODE=mips16 -emit-llvm -o - %s | FileCheck %s -DPTR=i32
// RUN: %clang_cc1 -triple mips-linux-gnu -target-cpu mips32r2 -DMODE=micromips -emit-llvm -o - %s | FileCheck %s -DPTR=i32
// RUN: %clang_cc1 -triple mipsel-linux-gnu -target-cpu mips32r2 -DMODE=micromips -emit-llvm -o - %s | FileCheck %s -DPTR=i32
// RUN: %clang_cc1 -triple mips-linux-gnu -target-cpu mips32r2 -DMODE=mips16 -O2 -emit-llvm -o - %s | FileCheck %s -DPTR=i32
// RUN: %clang_cc1 -triple mipsel-linux-gnu -target-cpu mips32r2 -DMODE=mips16 -O2 -emit-llvm -o - %s | FileCheck %s -DPTR=i32
// RUN: %clang_cc1 -triple mips-linux-gnu -target-cpu mips32r2 -DMODE=micromips -O2 -emit-llvm -o - %s | FileCheck %s -DPTR=i32
// RUN: %clang_cc1 -triple mipsel-linux-gnu -target-cpu mips32r2 -DMODE=micromips -O2 -emit-llvm -o - %s | FileCheck %s -DPTR=i32
// RUN: %clang_cc1 -triple mips64-linux-gnuabin32 -target-abi n32 -target-cpu mips64r3 -DMODE=micromips -O2 -emit-llvm -o - %s | FileCheck %s -DPTR=i32
// RUN: %clang_cc1 -triple mips64el-linux-gnuabin32 -target-abi n32 -target-cpu mips64r6 -DMODE=micromips -O2 -emit-llvm -o - %s | FileCheck %s -DPTR=i32
// RUN: %clang_cc1 -triple mips64-linux-gnuabi64 -target-abi n64 -target-cpu mips64r6 -DMODE=micromips -O2 -emit-llvm -o - %s | FileCheck %s -DPTR=i64
// RUN: %clang_cc1 -triple mips64el-linux-gnuabi64 -target-abi n64 -target-cpu mips64r2 -DMODE=micromips -O2 -emit-llvm -o - %s | FileCheck %s -DPTR=i64

// A compressed function's pointer carries an ISA tag even if its instructions
// have a stronger alignment. Do not fold the tag using the code alignment.
typedef __UINTPTR_TYPE__ uptr;
__attribute__((MODE, noinline, aligned(16))) int target(int x) { return x + 7; }

// CHECK: @initial_pointer = {{.*}}global [[PTR]] ptrtoint (ptr @target to [[PTR]])
uptr initial_pointer = (uptr)&target;

// CHECK-LABEL: define{{.*}} {{i32|i64}} @pointer_tag(
// CHECK-NOT: ret [[PTR]] 0
// CHECK: [[TAG:%.*]] = and [[PTR]] ptrtoint (ptr @target to [[PTR]]), 1
// CHECK: ret [[PTR]] [[TAG]]
uptr pointer_tag(void) { return (uptr)&target & 1; }
