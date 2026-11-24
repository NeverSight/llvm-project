// RUN: %clang_cc1 -triple mips-linux-gnu -emit-llvm  -o  - %s | FileCheck %s
// RUN: %clang_cc1 -triple mips64-linux-gnuabin32 -target-abi n32 -target-cpu mips64r2 -Werror=unknown-attributes -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple mips64el-linux-gnuabin32 -target-abi n32 -target-cpu mips64r6 -target-feature +micromips -Werror=unknown-attributes -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple mips64-linux-gnuabi64 -target-abi n64 -target-cpu mips64r6 -Werror=unknown-attributes -emit-obj -o %t.o %s
// RUN: llvm-objdump -d --no-show-raw-insn %t.o | FileCheck %s --check-prefix=MIXED
// RUN: %clang_cc1 -triple mips64el-linux-gnuabi64 -target-abi n64 -target-cpu mips64r5 -target-feature +micromips -Werror=unknown-attributes -emit-llvm -o - %s | FileCheck %s
// RUN: not %clang_cc1 -triple mips64-linux-gnuabi64 -target-abi n64 -target-cpu mips64 -target-feature +micromips -fsyntax-only %s 2>&1 | FileCheck %s --check-prefix=R1
// R1: error: micromips is not supported for target CPU 'mips64'

#if !__has_attribute(micromips) || !__has_attribute(nomicromips) || !__has_attribute(nomips16)
#error "missing MIPS encoding attributes"
#endif

void __attribute__((micromips,nomips16)) foo (void) {}

// CHECK: define{{.*}} void @foo() [[MICROMIPS:#[0-9]+]]

void __attribute__((nomicromips,nomips16)) nofoo (void) {}

// CHECK: define{{.*}} void @nofoo() [[NOMICROMIPS:#[0-9]+]]

// MIXED-LABEL: <foo>:
// MIXED: j{{rc16|ic}}
// MIXED-LABEL: <nofoo>:
// MIXED: jr

void __attribute__((micromips)) external_micro(void);
void use_micro(void) { external_micro(); }
// CHECK: declare void @external_micro() [[EXTERNAL:#[0-9]+]]

// CHECK: attributes [[MICROMIPS]] = { noinline nounwind {{.*}} "micromips" {{.*}} }
// CHECK: attributes [[NOMICROMIPS]]  = { noinline nounwind {{.*}} "nomicromips" {{.*}} }

// CHECK: attributes [[EXTERNAL]] = { {{.*}}"micromips"
