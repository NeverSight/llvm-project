// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -ffreestanding -O0 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X32 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -ffreestanding -O2 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X32 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple i386-unknown-linux-code16 -ffreestanding -O0 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X32 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple i386-unknown-linux-code16 -ffreestanding -O2 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X32 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -ffreestanding -O0 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X64 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -ffreestanding -O2 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X64 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple i386-pc-windows-msvc -ffreestanding -O0 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X32 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple i386-pc-windows-msvc -ffreestanding -O2 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X32 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -ffreestanding -O0 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X64 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -ffreestanding -O2 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X64 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple i386-apple-darwin -ffreestanding -O0 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X32 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple i386-apple-darwin -ffreestanding -O2 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X32 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple x86_64-apple-darwin -ffreestanding -O0 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X64 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple x86_64-apple-darwin -ffreestanding -O2 -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,X64 --implicit-check-not=asm --implicit-check-not="memory(none)"
// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -ffreestanding -O0 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM32
// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -ffreestanding -O2 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM32
// RUN: %clang_cc1 -triple i386-unknown-linux-code16 -ffreestanding -O0 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM32
// RUN: %clang_cc1 -triple i386-unknown-linux-code16 -ffreestanding -O2 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM32
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -ffreestanding -O0 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM64
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -ffreestanding -O2 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM64
// RUN: %clang_cc1 -triple i386-pc-windows-msvc -ffreestanding -O0 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM32
// RUN: %clang_cc1 -triple i386-pc-windows-msvc -ffreestanding -O2 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM32
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -ffreestanding -O0 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM64
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -ffreestanding -O2 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM64
// RUN: %clang_cc1 -triple i386-apple-darwin -ffreestanding -O0 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM32
// RUN: %clang_cc1 -triple i386-apple-darwin -ffreestanding -O2 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM32
// RUN: %clang_cc1 -triple x86_64-apple-darwin -ffreestanding -O0 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM64
// RUN: %clang_cc1 -triple x86_64-apple-darwin -ffreestanding -O2 -S -o - %s | FileCheck %s --check-prefixes=ASM,ASM64

#if !defined(__x86_64__)
#if !__has_builtin(__builtin_ia32_lds16)
#error Missing native far-pointer load
#endif
// ASM32-LABEL: lds16:
// ASM32: ldsw
// ASM32: ldsw
// X32-LABEL: define{{.*}} @lds16(
// X32: store i32 17, ptr
// X32: call i16 @llvm.x86.lds16(ptr
// X32: call i16 @llvm.x86.lds16(ptr
// X32: store i32 29, ptr
unsigned short lds16(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lds16(p), unsigned short: 1, default: 0), "result type");
  *marker = 17;
  unsigned short value = __builtin_ia32_lds16(p);
  __builtin_ia32_lds16(p);
  *marker = 29;
  return value;
}
#endif

#if !defined(__x86_64__)
#if !__has_builtin(__builtin_ia32_lds32)
#error Missing native far-pointer load
#endif
// ASM32-LABEL: lds32:
// ASM32: ldsl
// ASM32: ldsl
// X32-LABEL: define{{.*}} @lds32(
// X32: store i32 17, ptr
// X32: call i32 @llvm.x86.lds32(ptr
// X32: call i32 @llvm.x86.lds32(ptr
// X32: store i32 29, ptr
unsigned int lds32(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lds32(p), unsigned int: 1, default: 0), "result type");
  *marker = 17;
  unsigned int value = __builtin_ia32_lds32(p);
  __builtin_ia32_lds32(p);
  *marker = 29;
  return value;
}
#endif

#if !defined(__x86_64__)
#if !__has_builtin(__builtin_ia32_les16)
#error Missing native far-pointer load
#endif
// ASM32-LABEL: les16:
// ASM32: lesw
// ASM32: lesw
// X32-LABEL: define{{.*}} @les16(
// X32: store i32 17, ptr
// X32: call i16 @llvm.x86.les16(ptr
// X32: call i16 @llvm.x86.les16(ptr
// X32: store i32 29, ptr
unsigned short les16(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_les16(p), unsigned short: 1, default: 0), "result type");
  *marker = 17;
  unsigned short value = __builtin_ia32_les16(p);
  __builtin_ia32_les16(p);
  *marker = 29;
  return value;
}
#endif

#if !defined(__x86_64__)
#if !__has_builtin(__builtin_ia32_les32)
#error Missing native far-pointer load
#endif
// ASM32-LABEL: les32:
// ASM32: lesl
// ASM32: lesl
// X32-LABEL: define{{.*}} @les32(
// X32: store i32 17, ptr
// X32: call i32 @llvm.x86.les32(ptr
// X32: call i32 @llvm.x86.les32(ptr
// X32: store i32 29, ptr
unsigned int les32(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_les32(p), unsigned int: 1, default: 0), "result type");
  *marker = 17;
  unsigned int value = __builtin_ia32_les32(p);
  __builtin_ia32_les32(p);
  *marker = 29;
  return value;
}
#endif

#if !__has_builtin(__builtin_ia32_lss16)
#error Missing native far-pointer load
#endif
// ASM-LABEL: lss16:
// ASM: lssw
// ASM: lssw
// CHECK-LABEL: define{{.*}} @lss16(
// CHECK: store i32 17, ptr
// CHECK: call i16 @llvm.x86.lss16(ptr
// CHECK: call i16 @llvm.x86.lss16(ptr
// CHECK: store i32 29, ptr
unsigned short lss16(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lss16(p), unsigned short: 1, default: 0), "result type");
  *marker = 17;
  unsigned short value = __builtin_ia32_lss16(p);
  __builtin_ia32_lss16(p);
  *marker = 29;
  return value;
}

#if !__has_builtin(__builtin_ia32_lss32)
#error Missing native far-pointer load
#endif
// ASM-LABEL: lss32:
// ASM: lssl
// ASM: lssl
// CHECK-LABEL: define{{.*}} @lss32(
// CHECK: store i32 17, ptr
// CHECK: call i32 @llvm.x86.lss32(ptr
// CHECK: call i32 @llvm.x86.lss32(ptr
// CHECK: store i32 29, ptr
unsigned int lss32(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lss32(p), unsigned int: 1, default: 0), "result type");
  *marker = 17;
  unsigned int value = __builtin_ia32_lss32(p);
  __builtin_ia32_lss32(p);
  *marker = 29;
  return value;
}

#if defined(__x86_64__)
#if !__has_builtin(__builtin_ia32_lss64)
#error Missing native far-pointer load
#endif
// ASM64-LABEL: lss64:
// ASM64: lssq
// ASM64: lssq
// X64-LABEL: define{{.*}} @lss64(
// X64: store i32 17, ptr
// X64: call i64 @llvm.x86.lss64(ptr
// X64: call i64 @llvm.x86.lss64(ptr
// X64: store i32 29, ptr
unsigned long long lss64(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lss64(p), unsigned long long: 1, default: 0), "result type");
  *marker = 17;
  unsigned long long value = __builtin_ia32_lss64(p);
  __builtin_ia32_lss64(p);
  *marker = 29;
  return value;
}
#endif

#if !__has_builtin(__builtin_ia32_lfs16)
#error Missing native far-pointer load
#endif
// ASM-LABEL: lfs16:
// ASM: lfsw
// ASM: lfsw
// CHECK-LABEL: define{{.*}} @lfs16(
// CHECK: store i32 17, ptr
// CHECK: call i16 @llvm.x86.lfs16(ptr
// CHECK: call i16 @llvm.x86.lfs16(ptr
// CHECK: store i32 29, ptr
unsigned short lfs16(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lfs16(p), unsigned short: 1, default: 0), "result type");
  *marker = 17;
  unsigned short value = __builtin_ia32_lfs16(p);
  __builtin_ia32_lfs16(p);
  *marker = 29;
  return value;
}

#if !__has_builtin(__builtin_ia32_lfs32)
#error Missing native far-pointer load
#endif
// ASM-LABEL: lfs32:
// ASM: lfsl
// ASM: lfsl
// CHECK-LABEL: define{{.*}} @lfs32(
// CHECK: store i32 17, ptr
// CHECK: call i32 @llvm.x86.lfs32(ptr
// CHECK: call i32 @llvm.x86.lfs32(ptr
// CHECK: store i32 29, ptr
unsigned int lfs32(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lfs32(p), unsigned int: 1, default: 0), "result type");
  *marker = 17;
  unsigned int value = __builtin_ia32_lfs32(p);
  __builtin_ia32_lfs32(p);
  *marker = 29;
  return value;
}

#if defined(__x86_64__)
#if !__has_builtin(__builtin_ia32_lfs64)
#error Missing native far-pointer load
#endif
// ASM64-LABEL: lfs64:
// ASM64: lfsq
// ASM64: lfsq
// X64-LABEL: define{{.*}} @lfs64(
// X64: store i32 17, ptr
// X64: call i64 @llvm.x86.lfs64(ptr
// X64: call i64 @llvm.x86.lfs64(ptr
// X64: store i32 29, ptr
unsigned long long lfs64(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lfs64(p), unsigned long long: 1, default: 0), "result type");
  *marker = 17;
  unsigned long long value = __builtin_ia32_lfs64(p);
  __builtin_ia32_lfs64(p);
  *marker = 29;
  return value;
}
#endif

#if !__has_builtin(__builtin_ia32_lgs16)
#error Missing native far-pointer load
#endif
// ASM-LABEL: lgs16:
// ASM: lgsw
// ASM: lgsw
// CHECK-LABEL: define{{.*}} @lgs16(
// CHECK: store i32 17, ptr
// CHECK: call i16 @llvm.x86.lgs16(ptr
// CHECK: call i16 @llvm.x86.lgs16(ptr
// CHECK: store i32 29, ptr
unsigned short lgs16(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lgs16(p), unsigned short: 1, default: 0), "result type");
  *marker = 17;
  unsigned short value = __builtin_ia32_lgs16(p);
  __builtin_ia32_lgs16(p);
  *marker = 29;
  return value;
}

#if !__has_builtin(__builtin_ia32_lgs32)
#error Missing native far-pointer load
#endif
// ASM-LABEL: lgs32:
// ASM: lgsl
// ASM: lgsl
// CHECK-LABEL: define{{.*}} @lgs32(
// CHECK: store i32 17, ptr
// CHECK: call i32 @llvm.x86.lgs32(ptr
// CHECK: call i32 @llvm.x86.lgs32(ptr
// CHECK: store i32 29, ptr
unsigned int lgs32(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lgs32(p), unsigned int: 1, default: 0), "result type");
  *marker = 17;
  unsigned int value = __builtin_ia32_lgs32(p);
  __builtin_ia32_lgs32(p);
  *marker = 29;
  return value;
}

#if defined(__x86_64__)
#if !__has_builtin(__builtin_ia32_lgs64)
#error Missing native far-pointer load
#endif
// ASM64-LABEL: lgs64:
// ASM64: lgsq
// ASM64: lgsq
// X64-LABEL: define{{.*}} @lgs64(
// X64: store i32 17, ptr
// X64: call i64 @llvm.x86.lgs64(ptr
// X64: call i64 @llvm.x86.lgs64(ptr
// X64: store i32 29, ptr
unsigned long long lgs64(const void *p, unsigned *marker) {
  _Static_assert(_Generic(__builtin_ia32_lgs64(p), unsigned long long: 1, default: 0), "result type");
  *marker = 17;
  unsigned long long value = __builtin_ia32_lgs64(p);
  __builtin_ia32_lgs64(p);
  *marker = 29;
  return value;
}
#endif

