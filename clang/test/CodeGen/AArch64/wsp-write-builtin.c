// RUN: %clang_cc1 -triple aarch64-none-elf -emit-llvm -o - %s \
// RUN:   | FileCheck %s --check-prefix=IR
// RUN: %clang -target aarch64-none-elf -O2 -S -o - %s \
// RUN:   | FileCheck %s --check-prefix=ASM

unsigned long long write_wsp(unsigned value) {
  return __builtin_arm_wsp_write(value);
}

unsigned long long zero_extend_wsp(void) {
  return __builtin_arm_wsp_zero_extend();
}

// IR-LABEL: define{{.*}} i64 @write_wsp(i32{{.*}} %value)
// IR: call void @llvm.aarch64.wsp.write(i32 %{{.*}})
// IR: zext i32 %{{.*}} to i64
// IR: ret i64 %{{.*}}

// ASM-LABEL: write_wsp:
// ASM: mov wsp, w0

// IR-LABEL: define{{.*}} i64 @zero_extend_wsp()
// IR: call i32 @llvm.aarch64.wsp.read()
// IR: call void @llvm.aarch64.wsp.write(i32 %{{.*}})
// IR: zext i32 %{{.*}} to i64
// IR: ret i64 %{{.*}}

// ASM-LABEL: zero_extend_wsp:
// ASM: mov w[[REG:[0-9]+]], wsp
// ASM: mov wsp, w[[REG]]
