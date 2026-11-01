; RUN: not --crash llc -mtriple=x86_64 < %s 2>&1 | FileCheck %s
; RUN: sed 's/i32 256/i32 -1/' %s | not --crash llc -mtriple=i386 2>&1 | FileCheck %s
; RUN: sed 's/i32 256/i32 0/' %s | not --crash llc -mtriple=i386 -mattr=+16bit-mode 2>&1 | FileCheck %s --check-prefix=MODE
; RUN: sed -e 's/define i32 @invalid()/define i32 @invalid(i32 %%code)/' -e 's/i32 256/i32 %%code/' %s | not opt -passes=verify -disable-output 2>&1 | FileCheck %s --check-prefix=IMM
; CHECK: RTM abort pair requires an imm8 abort code
; MODE: RTM abort pair requires 32-bit or 64-bit code mode
; IMM: immarg operand has non-immediate parameter

declare i32 @llvm.x86.rtm.abort.pair(i32 immarg)
define i32 @invalid() {
  %s = call i32 @llvm.x86.rtm.abort.pair(i32 256)
  ret i32 %s
}
