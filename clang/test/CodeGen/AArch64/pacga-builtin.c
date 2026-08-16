// RUN: %clang_cc1 -triple aarch64-none-elf -target-feature +pauth \
// RUN:   -emit-llvm -o - %s | FileCheck %s --check-prefix=IR
// RUN: %clang -target aarch64-none-elf -march=armv8.3-a+pauth -O2 -S \
// RUN:   -o - %s | FileCheck %s --check-prefix=ASM

unsigned long long pacga(unsigned long long value,
                         unsigned long long discriminator) {
  return __builtin_arm_pacga(value, discriminator);
}

// IR-LABEL: define{{.*}} i64 @pacga(i64{{.*}} %value, i64{{.*}} %discriminator)
// IR: call i64 @llvm.ptrauth.sign.generic(i64 %{{.*}}, i64 %{{.*}})

// ASM-LABEL: pacga:
// ASM: pacga x0, x0, x1
