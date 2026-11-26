; RUN: llc -mtriple=mips -mcpu=mips32r2 -target-abi=o32 -mattr=+mips16,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.be
; RUN: llvm-objdump -s -j .text %t.be | FileCheck %s --check-prefix=BE
; RUN: llc -mtriple=mipsel -mcpu=mips32r2 -target-abi=o32 -mattr=+mips16,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.le
; RUN: llvm-objdump -s -j .text %t.le | FileCheck %s --check-prefix=LE

; The comparison yields a compact BTNEZ at byte 2. Its displacement of four
; halfwords reaches the zero-return block at byte 12, beyond an extended LW.
; BE: 0000 74116104 f0009d40 4a1fe8a0 f0006a00
; LE: 0000 11740461 00f0409d 1f4aa0e8 00f0006a
define i32 @maybe_load(i32 %flag, ptr %p) {
entry:
  %valid = icmp eq i32 %flag, 17
  br i1 %valid, label %dereference, label %empty

empty:
  ret i32 0

dereference:
  %val = load volatile i32, ptr %p
  %mix = add i32 %val, 31
  ret i32 %mix
}
