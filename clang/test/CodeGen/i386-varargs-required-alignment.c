// RUN: %clang_cc1 -triple i386-pc-windows-msvc -fms-extensions -emit-llvm -o - %s | FileCheck %s --check-prefixes=CHECK,WIN
// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -fms-extensions -emit-llvm -o - %s | FileCheck %s

struct __declspec(align(32)) Aligned { unsigned value; };

// An unnamed over-aligned record occupies 32 stack bytes. It is not the
// pointer-sized temporary used for the same type as a named Win32 argument.
// CHECK-LABEL: define{{.*}} i32 @read_aligned(
// CHECK: [[CUR:%.*]] = load ptr, ptr {{.*}}, align 4
// CHECK: [[NEXT:%.*]] = getelementptr inbounds i8, ptr [[CUR]], i32 32
// CHECK: store ptr [[NEXT]], ptr {{.*}}, align 4
// CHECK: call void @llvm.memcpy{{.*}}ptr align 4 [[CUR]], i32 32
// CHECK: getelementptr inbounds i8, ptr {{.*}}, i32 4
unsigned read_aligned(unsigned first, ...) {
  __builtin_va_list ap;
  __builtin_va_start(ap, first);
  struct Aligned value = __builtin_va_arg(ap, struct Aligned);
  unsigned last = __builtin_va_arg(ap, unsigned);
  __builtin_va_end(ap);
  return value.value ^ last;
}

#ifdef _WIN32
typedef unsigned V4 __attribute__((vector_size(16)));
extern void consume_vectors(unsigned tag, ...);
// Unnamed Windows vector arguments are pointer slots, including the first
// three vectors that would use SSE registers in a fixed-argument function.
// WIN-LABEL: define{{.*}} void @pass_vectors(
// WIN: call void (i32, ...) @consume_vectors(i32 noundef 1, ptr {{.*}}, ptr {{.*}}, ptr {{.*}}, ptr {{.*}})
void pass_vectors(V4 a, V4 b, V4 c, V4 d) {
  consume_vectors(1, a, b, c, d);
}
#endif
