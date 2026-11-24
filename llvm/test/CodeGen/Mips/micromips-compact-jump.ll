; RUN: llc -mtriple=mipsel -mcpu=mips32r2 -mattr=+micromips \
; RUN:   -disable-mips-delay-filler -O3 < %s | FileCheck %s
; RUN: llc -mtriple=mips -mcpu=mips32r6 -mattr=+micromips -filetype=obj %s -o - \
; RUN:   | llvm-objdump -d --mcpu=mips32r6 --mattr=+micromips - | FileCheck %s --check-prefix=R6BE
; RUN: llc -mtriple=mipsel -mcpu=mips32r6 -mattr=+micromips -filetype=obj %s -o - \
; RUN:   | llvm-objdump -d --mcpu=mips32r6 --mattr=+micromips - | FileCheck %s --check-prefix=R6LE

define i32 @foo(i32 signext %a) #0 {
entry:
  ret i32 0
}

declare i32 @bar(i32 signext) #1

; CHECK:      jrc
; R6BE: 47 e3 {{.*}}jrc16 $ra
; R6LE: e3 47 {{.*}}jrc16 $ra
