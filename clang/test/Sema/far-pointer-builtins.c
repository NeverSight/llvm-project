// RUN: %clang_cc1 -triple i386-unknown-linux-gnu -fsyntax-only -verify=common,legacy %s
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -fsyntax-only -verify=common,long %s

void invalid(const void *p) {
  __builtin_ia32_lfs16(); // common-error {{too few arguments}}
  __builtin_ia32_lfs16(p, p); // common-error {{too many arguments}}
  __builtin_ia32_lfs16(42); // common-error {{incompatible integer to pointer conversion}}
  __builtin_ia32_lfs32(); // common-error {{too few arguments}}
  __builtin_ia32_lfs32(p, p); // common-error {{too many arguments}}
  __builtin_ia32_lfs32(42); // common-error {{incompatible integer to pointer conversion}}
  __builtin_ia32_lgs16(); // common-error {{too few arguments}}
  __builtin_ia32_lgs16(p, p); // common-error {{too many arguments}}
  __builtin_ia32_lgs16(42); // common-error {{incompatible integer to pointer conversion}}
  __builtin_ia32_lgs32(); // common-error {{too few arguments}}
  __builtin_ia32_lgs32(p, p); // common-error {{too many arguments}}
  __builtin_ia32_lgs32(42); // common-error {{incompatible integer to pointer conversion}}
  __builtin_ia32_lss16(); // common-error {{too few arguments}}
  __builtin_ia32_lss16(p, p); // common-error {{too many arguments}}
  __builtin_ia32_lss16(42); // common-error {{incompatible integer to pointer conversion}}
  __builtin_ia32_lss32(); // common-error {{too few arguments}}
  __builtin_ia32_lss32(p, p); // common-error {{too many arguments}}
  __builtin_ia32_lss32(42); // common-error {{incompatible integer to pointer conversion}}
#ifdef __x86_64__
  __builtin_ia32_lds16(p); // long-error {{only available on 32-bit targets}}
  __builtin_ia32_lds32(p); // long-error {{only available on 32-bit targets}}
  __builtin_ia32_les16(p); // long-error {{only available on 32-bit targets}}
  __builtin_ia32_les32(p); // long-error {{only available on 32-bit targets}}
#else
  __builtin_ia32_lfs64(p); // legacy-error {{unknown builtin}}
  __builtin_ia32_lgs64(p); // legacy-error {{unknown builtin}}
  __builtin_ia32_lss64(p); // legacy-error {{unknown builtin}}
#endif
}
