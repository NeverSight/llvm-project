; RUN: not llc -mtriple=mips64-unknown-linux -mcpu=mips64 -mattr=+micromips  %s 2>&1 | FileCheck %s --check-prefix=MICROMIPS64

; Test that The original MIPS64 ISA has no microMIPS64 profile.

; MICROMIPS64: LLVM ERROR: microMIPS64 is not supported
