// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -fsyntax-only -verify %s
void invalid(unsigned int p, unsigned short s, int control) {
  __builtin_ia32_arpl_mem_address32(p, s, 64, 0); // expected-error {{invalid argument}}
  __builtin_ia32_arpl_mem_address32(p, s, 16, 0x66); // expected-error {{invalid argument}}
  __builtin_ia32_arpl_mem_address32(p, s, control, 0); // expected-error {{must be a constant integer}}
  __builtin_ia32_arpl_mem_address32(p, s, 16, control); // expected-error {{must be a constant integer}}
}
