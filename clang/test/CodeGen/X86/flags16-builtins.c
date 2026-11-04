// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -emit-llvm -o - %s | FileCheck %s

// CHECK-LABEL: define{{.*}} i16 @read_flags(
// CHECK: call i16 @llvm.x86.flags.read.u16()
unsigned short read_flags(void) {
  return __builtin_ia32_readeflags_u16();
}

// CHECK-LABEL: define{{.*}} void @write_flags(
// CHECK: call void @llvm.x86.flags.write.u16(i16
void write_flags(unsigned short flags) {
  __builtin_ia32_writeeflags_u16(flags);
}
