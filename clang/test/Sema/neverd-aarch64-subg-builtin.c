// RUN: %clang_cc1 -triple aarch64-none-linux-gnu -target-feature +mte -fsyntax-only -verify %s

void *valid(void *pointer) {
  return __builtin_arm_subg(pointer, 112, 9);
}

void *bad_pointer(unsigned long pointer) {
  // expected-error@+1 {{first argument of MTE builtin function must be a pointer}}
  return __builtin_arm_subg(pointer, 112, 9);
}

void *nonconstant_address(void *pointer, unsigned address_offset) {
  // expected-error@+1 {{argument to '__builtin_arm_subg' must be a constant integer}}
  return __builtin_arm_subg(pointer, address_offset, 9);
}

void *unaligned_address(void *pointer) {
  // expected-error@+1 {{argument should be a multiple of 16}}
  return __builtin_arm_subg(pointer, 17, 9);
}

void *large_address(void *pointer) {
  // expected-error@+1 {{argument value 1024 is outside the valid range [0, 1008]}}
  return __builtin_arm_subg(pointer, 1024, 9);
}

void *bad_tag(void *pointer) {
  // expected-error@+1 {{argument value 16 is outside the valid range [0, 15]}}
  return __builtin_arm_subg(pointer, 112, 16);
}
