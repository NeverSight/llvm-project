// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -ffreestanding -O2 -emit-llvm -o - %s | FileCheck %s --implicit-check-not=asm
// RUN: %clang_cc1 -triple i386-unknown-linux-code16 -ffreestanding -O2 -emit-llvm -o - %s | FileCheck %s --implicit-check-not=asm
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -ffreestanding -O2 -emit-llvm -o - %s | FileCheck %s --implicit-check-not=asm
// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -DNOFEATURE -ffreestanding -emit-llvm -o - -verify %s
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -DNOFEATURE -ffreestanding -emit-llvm -o - -verify %s

#include <x86gprintrin.h>

#if !defined(__NEVERSIGHT_X86_HRESET__) || __NEVERSIGHT_X86_HRESET__ != 1
#error Native HRESET availability must not require global CPU features
#endif

#ifdef NOFEATURE
void unavailable(unsigned x) {
  __builtin_ia32_hreset(x); // expected-error {{needs target feature hreset}}
}
#else
// CHECK-LABEL: define{{.*}} void @reset(
// CHECK: store i32 1, ptr
// CHECK: call void @llvm.x86.hreset(i32
// CHECK: call void @llvm.x86.hreset(i32
// CHECK: store i32 2, ptr
__attribute__((target("hreset"))) void reset(unsigned x, unsigned *marker) {
  *marker = 1;
  __builtin_ia32_hreset(x);
  _hreset(x + 1);
  *marker = 2;
}
#endif
