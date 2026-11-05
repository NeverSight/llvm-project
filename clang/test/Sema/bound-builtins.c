// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -fsyntax-only -verify %s
void invalid(int index, unsigned offset, int control) {
  __builtin_ia32_bound16_address32(index, offset, 64, 0); // expected-error {{invalid argument '64'}}
  __builtin_ia32_bound32_address32(index, offset, 17, 0); // expected-error {{invalid argument '17'}}
  __builtin_ia32_bound16_address32(index, offset, 16, 0x66); // expected-error {{invalid argument '102'}}
  __builtin_ia32_bound32_address32(index, offset, 32, 0x100); // expected-error {{invalid argument '256'}}
  __builtin_ia32_bound16_address32(index, offset, control, 0); // expected-error {{must be a constant integer}}
  __builtin_ia32_bound32_address32(index, offset, 32, control); // expected-error {{must be a constant integer}}
}
