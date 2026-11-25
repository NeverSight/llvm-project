; RUN: llc -mtriple=mipsel -mcpu=mips32r2 -mattr=+micromips \
; RUN:   -disable-mips-delay-filler -O3 < %s | FileCheck %s
; RUN: llc -mtriple=mips -mcpu=mips32r6 -mattr=+micromips -relocation-model=static -filetype=obj %s -o - \
; RUN:   | llvm-objdump -d --mcpu=mips32r6 --mattr=+micromips - | FileCheck %s --check-prefixes=R6,R6BE
; RUN: llc -mtriple=mipsel -mcpu=mips32r6 -mattr=+micromips -relocation-model=pic -filetype=obj %s -o - \
; RUN:   | llvm-objdump -d --mcpu=mips32r6 --mattr=+micromips - | FileCheck %s --check-prefixes=R6,R6LE
; RUN: llc -mtriple=mips64-linux-gnuabin32 -mcpu=mips64r6 -mattr=+micromips -relocation-model=pic -filetype=obj %s -o - \
; RUN:   | llvm-objdump -d --mcpu=mips64r6 --mattr=+micromips - | FileCheck %s --check-prefix=R6
; RUN: llc -mtriple=mips64el-linux-gnuabi64 -mcpu=mips64r6 -mattr=+micromips -relocation-model=static -filetype=obj %s -o - \
; RUN:   | llvm-objdump -d --mcpu=mips64r6 --mattr=+micromips - | FileCheck %s --check-prefix=R6

define i32 @foo(i32 signext %a) #0 {
entry:
  ret i32 0
}

declare i32 @bar(i32 signext) #1

; CHECK:      jrc
; R6BE: 47 e3 {{.*}}jrc16 $ra
; R6LE: e3 47 {{.*}}jrc16 $ra

declare i32 @step(i32, i32)

; A local jump from one arm must enter the shared epilogue on R6.
; R6-LABEL: <choose>:
; R6: {{[[:space:]]}}bc {{.*}}<choose+
define i32 @choose(i32 %x, i32 %y) {
entry:
  %sum = add i32 %x, %y
  %odd = trunc i32 %sum to i1
  br i1 %odd, label %a, label %b
a:
  %one = call i32 @step(i32 %y, i32 %x)
  %plus = add i32 %one, %x
  br label %join
b:
  %two = call i32 @step(i32 %x, i32 %y)
  %mask = xor i32 %two, %y
  br label %join
join:
  %value = phi i32 [ %plus, %a ], [ %mask, %b ]
  ret i32 %value
}
