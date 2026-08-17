// RUN: %clang_cc1 -triple aarch64-none-elf -target-feature +lse -O1 \
// RUN:   -emit-llvm -o - %s | FileCheck %s
// RUN: %clang -target aarch64-none-elf -march=armv8.1-a+lse -O2 -S -o - %s \
// RUN:   | FileCheck %s --check-prefix=ASM

unsigned long long ldclral(unsigned long long value, void *address) {
  return __builtin_arm_ldclr(value, address, 8, __ATOMIC_ACQ_REL);
}

unsigned long long ldeorb(unsigned long long value, void *address) {
  return __builtin_arm_ldeor(value, address, 1, __ATOMIC_RELAXED);
}

unsigned long long ldseth(unsigned long long value, void *address) {
  return __builtin_arm_ldset(value, address, 2, __ATOMIC_CONSUME);
}

unsigned long long ldsmaxa(unsigned long long value, void *address) {
  return __builtin_arm_ldsmax(value, address, 4, __ATOMIC_ACQUIRE);
}

unsigned long long ldsminl(unsigned long long value, void *address) {
  return __builtin_arm_ldsmin(value, address, 8, __ATOMIC_RELEASE);
}

unsigned long long ldumaxalb(unsigned long long value, void *address) {
  return __builtin_arm_ldumax(value, address, 1, __ATOMIC_ACQ_REL);
}

unsigned long long lduminseqh(unsigned long long value, void *address) {
  return __builtin_arm_ldumin(value, address, 2, __ATOMIC_SEQ_CST);
}

// CHECK-LABEL: define{{.*}} i64 @ldclral(
// CHECK: %[[MASK:.*]] = xor i64 %value, -1
// CHECK: %[[OLD:.*]] = atomicrmw and ptr %address, i64 %[[MASK]] acq_rel, align 8
// CHECK: ret i64 %[[OLD]]

// CHECK-LABEL: define{{.*}} i64 @ldeorb(
// CHECK: %[[VALUE8:.*]] = trunc i64 %value to i8
// CHECK: %[[OLD8:.*]] = atomicrmw xor ptr %address, i8 %[[VALUE8]] monotonic, align 1
// CHECK: %[[EXT8:.*]] = zext i8 %[[OLD8]] to i64
// CHECK: ret i64 %[[EXT8]]

// CHECK-LABEL: define{{.*}} i64 @ldseth(
// CHECK: %[[VALUE16:.*]] = trunc i64 %value to i16
// CHECK: %[[OLD16:.*]] = atomicrmw or ptr %address, i16 %[[VALUE16]] acquire, align 2
// CHECK: %[[EXT16:.*]] = zext i16 %[[OLD16]] to i64
// CHECK: ret i64 %[[EXT16]]

// CHECK-LABEL: define{{.*}} i64 @ldsmaxa(
// CHECK: %[[VALUE32:.*]] = trunc i64 %value to i32
// CHECK: %[[OLD32:.*]] = atomicrmw max ptr %address, i32 %[[VALUE32]] acquire, align 4
// CHECK: %[[EXT32:.*]] = zext i32 %[[OLD32]] to i64
// CHECK: ret i64 %[[EXT32]]

// CHECK-LABEL: define{{.*}} i64 @ldsminl(
// CHECK: %[[OLDMIN:.*]] = atomicrmw min ptr %address, i64 %value release, align 8
// CHECK: ret i64 %[[OLDMIN]]

// CHECK-LABEL: define{{.*}} i64 @ldumaxalb(
// CHECK: %[[UMAX8:.*]] = trunc i64 %value to i8
// CHECK: %[[OLDUMAX:.*]] = atomicrmw umax ptr %address, i8 %[[UMAX8]] acq_rel, align 1
// CHECK: %[[EXTUMAX:.*]] = zext i8 %[[OLDUMAX]] to i64
// CHECK: ret i64 %[[EXTUMAX]]

// CHECK-LABEL: define{{.*}} i64 @lduminseqh(
// CHECK: %[[UMIN16:.*]] = trunc i64 %value to i16
// CHECK: %[[OLDUMIN:.*]] = atomicrmw umin ptr %address, i16 %[[UMIN16]] seq_cst, align 2
// CHECK: %[[EXTUMIN:.*]] = zext i16 %[[OLDUMIN]] to i64
// CHECK: ret i64 %[[EXTUMIN]]

// ASM-LABEL: ldclral:
// ASM: ldclral x0, x0, [x1]
// ASM-LABEL: ldeorb:
// ASM: ldeorb w0, w0, [x1]
// ASM-LABEL: ldseth:
// ASM: ldsetah w0, w0, [x1]
// ASM-LABEL: ldsmaxa:
// ASM: ldsmaxa w0, w0, [x1]
// ASM-LABEL: ldsminl:
// ASM: ldsminl x0, x0, [x1]
// ASM-LABEL: ldumaxalb:
// ASM: ldumaxalb w0, w0, [x1]
// ASM-LABEL: lduminseqh:
// ASM: lduminalh w0, w0, [x1]
