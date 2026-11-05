// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple i386-unknown-linux-code16 -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -fsyntax-only -verify=MODE %s

// CHECK-LABEL: define{{.*}} i16 @check16(
// CHECK: call void @llvm.x86.bound16(i16
short check16(short index, const void *bounds) {
  __builtin_ia32_bound16(index, bounds); // MODE-error {{this builtin is only available on 32-bit targets}}
  return index;
}

// CHECK-LABEL: define{{.*}} i32 @check32(
// CHECK: call void @llvm.x86.bound32(i32
int check32(int index, const void *bounds) {
  __builtin_ia32_bound32(index, bounds); // MODE-error {{this builtin is only available on 32-bit targets}}
  return index;
}

// CHECK-LABEL: define{{.*}} void @explicit_address(
// CHECK: call void @llvm.x86.bound16.address32(i16 {{.*}}, i32 {{.*}}, i32 16, i32 100)
// CHECK: call void @llvm.x86.bound32.address32(i32 {{.*}}, i32 {{.*}}, i32 32, i32 54)
void explicit_address(short word, int dword, unsigned int offset) {
  __builtin_ia32_bound16_address32(word, offset, 16, 0x64); // MODE-error {{this builtin is only available on 32-bit targets}}
  __builtin_ia32_bound32_address32(dword, offset, 32, 0x36); // MODE-error {{this builtin is only available on 32-bit targets}}
}
