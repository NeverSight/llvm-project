// RUN: %clang_cc1 -triple mips-linux-gnu -target-cpu mips32r2 -DMODE=mips16 -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple mipsel-linux-gnu -target-cpu mips32r2 -DMODE=mips16 -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple mips-linux-gnu -target-cpu mips32r2 -DMODE=micromips -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple mipsel-linux-gnu -target-cpu mips32r2 -DMODE=micromips -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple mips-linux-gnu -target-cpu mips32r2 -DMODE=mips16 -O2 -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple mipsel-linux-gnu -target-cpu mips32r2 -DMODE=mips16 -O2 -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple mips-linux-gnu -target-cpu mips32r2 -DMODE=micromips -O2 -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple mipsel-linux-gnu -target-cpu mips32r2 -DMODE=micromips -O2 -emit-llvm -o - %s | FileCheck %s

// A compressed function's pointer carries an ISA tag even if its instructions
// have a stronger alignment. Do not fold the tag using the code alignment.
typedef __UINTPTR_TYPE__ uptr;
__attribute__((MODE, noinline, aligned(16))) int target(int x) { return x + 7; }

// CHECK: @initial_pointer = {{.*}}global i32 ptrtoint (ptr @target to i32)
uptr initial_pointer = (uptr)&target;

// CHECK-LABEL: define{{.*}} i32 @pointer_tag(
// CHECK-NOT: ret i32 0
// CHECK: [[TAG:%.*]] = and i32 ptrtoint (ptr @target to i32), 1
// CHECK: ret i32 [[TAG]]
uptr pointer_tag(void) { return (uptr)&target & 1; }
