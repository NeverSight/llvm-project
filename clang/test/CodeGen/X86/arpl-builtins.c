// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple i386-unknown-linux-code16 -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -fsyntax-only -verify=MODE %s

// CHECK-LABEL: define{{.*}} i16 @adjust(
// CHECK: [[PAIR:%.*]] = call { i16, i8 } @llvm.x86.arpl.reg(i16 {{.*}}, i16 {{.*}})
// CHECK: [[ZF:%.*]] = extractvalue { i16, i8 } [[PAIR]], 1
// CHECK: store i8 [[ZF]], ptr {{.*}}, align 1
// CHECK: extractvalue { i16, i8 } [[PAIR]], 0
unsigned short adjust(unsigned short dst, unsigned short src, unsigned char *zf) {
  return __builtin_ia32_arpl_reg(dst, src, zf); // MODE-error {{this builtin is only available on 32-bit targets}}
}

// CHECK-LABEL: define{{.*}} i8 @memory(
// CHECK: call i8 @llvm.x86.arpl.mem(ptr {{.*}}, i16 {{.*}})
unsigned char memory(void *dst, unsigned short src) {
  return __builtin_ia32_arpl_mem(dst, src); // MODE-error {{this builtin is only available on 32-bit targets}}
}

// CHECK-LABEL: define{{.*}} i8 @explicit_address(
// CHECK: call i8 @llvm.x86.arpl.mem.address32(i32 {{.*}}, i16 {{.*}}, i32 16, i32 100)
unsigned char explicit_address(unsigned int offset, unsigned short src) {
  return __builtin_ia32_arpl_mem_address32(offset, src, 16, 0x64); // MODE-error {{this builtin is only available on 32-bit targets}}
}
