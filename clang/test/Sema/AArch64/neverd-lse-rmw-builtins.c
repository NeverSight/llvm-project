// RUN: %clang_cc1 -triple aarch64-none-elf -target-feature +lse \
// RUN:   -fsyntax-only -verify=expected %s
// RUN: %clang_cc1 -triple aarch64-none-elf -emit-llvm -o /dev/null \
// RUN:   -DNO_LSE -verify=feature %s

#ifdef NO_LSE
unsigned long long no_lse(unsigned long long value, void *address) {
  value += __builtin_arm_ldclr(value, address, 8, __ATOMIC_RELAXED);
  // feature-error@-1 {{'__builtin_arm_ldclr' needs target feature lse}}
  return __builtin_arm_ldumin(value, address, 2, __ATOMIC_SEQ_CST);
  // feature-error@-1 {{'__builtin_arm_ldumin' needs target feature lse}}
}
#else
unsigned long long invalid(unsigned long long value, void *address,
                           unsigned width, unsigned order) {
  value += __builtin_arm_ldclr(value, address, width, __ATOMIC_RELAXED);
  // expected-error@-1 {{argument to '__builtin_arm_ldclr' must be a constant integer}}
  value += __builtin_arm_ldclr(value, address, 8, order);
  // expected-error@-1 {{argument to '__builtin_arm_ldclr' must be a constant integer}}
  value += __builtin_arm_ldclr(value, address, 3, __ATOMIC_RELAXED);
  // expected-error@-1 {{argument value 3 is outside the valid range [1, 2, 4, 8]}}
  value += __builtin_arm_ldclr(value, address, 16, __ATOMIC_RELAXED);
  // expected-error@-1 {{argument value 16 is outside the valid range [1, 2, 4, 8]}}
  value += __builtin_arm_ldeor(value, address, 3, __ATOMIC_ACQUIRE);
  // expected-error@-1 {{argument value 3 is outside the valid range [1, 2, 4, 8]}}
  return __builtin_arm_ldclr(value, address, 8, 6);
  // expected-error@-1 {{argument value 6 is outside the valid range [0, 5]}}
}
#endif
