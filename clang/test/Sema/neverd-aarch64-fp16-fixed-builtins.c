// RUN: %clang_cc1 -triple aarch64-none-linux-gnu -target-feature +fullfp16 \
// RUN:   -fsyntax-only -verify %s

void valid(unsigned long long x, unsigned short h) {
  (void)__builtin_arm_scvtf_fixed(x, 1, 0);
  (void)__builtin_arm_scvtf_fixed(x, 32, 0);
  (void)__builtin_arm_ucvtf_fixed(x, 1, 1);
  (void)__builtin_arm_ucvtf_fixed(x, 64, 1);
  (void)__builtin_arm_fcvtzs_fixed(h, 32, 0);
  (void)__builtin_arm_fcvtzu_fixed(h, 64, 1);
}

void invalid(unsigned long long x, unsigned short h, unsigned runtime) {
  (void)__builtin_arm_scvtf_fixed(x, 0, 0);  // expected-error {{argument value 0 is outside the valid range [1, 32]}}
  (void)__builtin_arm_scvtf_fixed(x, 33, 0); // expected-error {{argument value 33 is outside the valid range [1, 32]}}
  (void)__builtin_arm_ucvtf_fixed(x, 65, 1); // expected-error {{argument value 65 is outside the valid range [1, 64]}}
  (void)__builtin_arm_fcvtzs_fixed(h, 1, 2); // expected-error {{argument value 2 is outside the valid range [0, 1]}}
  (void)__builtin_arm_fcvtzu_fixed(h, runtime, 0); // expected-error {{must be a constant integer}}
  (void)__builtin_arm_fcvtzu_fixed(h, 1, runtime); // expected-error {{must be a constant integer}}
}
