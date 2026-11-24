; RUN: llc -mtriple=mips64-linux-gnuabin32 -target-abi=n32 -mcpu=mips64r3 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.n32bestatic
; RUN: llvm-readobj -r %t.n32bestatic | FileCheck %s --check-prefix=N32-STATIC
; RUN: llc -mtriple=mips64-linux-gnuabin32 -target-abi=n32 -mcpu=mips64r3 -mattr=+micromips -relocation-model=pic -verify-machineinstrs -filetype=obj %s -o %t.n32bepic
; RUN: llvm-readobj -r %t.n32bepic | FileCheck %s --check-prefix=N32-PIC
; RUN: llc -mtriple=mips64el-linux-gnuabin32 -target-abi=n32 -mcpu=mips64r3 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.n32lestatic
; RUN: llvm-readobj -r %t.n32lestatic | FileCheck %s --check-prefix=N32-STATIC
; RUN: llc -mtriple=mips64el-linux-gnuabin32 -target-abi=n32 -mcpu=mips64r3 -mattr=+micromips -relocation-model=pic -verify-machineinstrs -filetype=obj %s -o %t.n32lepic
; RUN: llvm-readobj -r %t.n32lepic | FileCheck %s --check-prefix=N32-PIC
; RUN: llc -mtriple=mips64-linux-gnuabi64 -target-abi=n64 -mcpu=mips64r5 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.n64bestatic
; RUN: llvm-readobj -r %t.n64bestatic | FileCheck %s --check-prefix=N64-STATIC
; RUN: llc -mtriple=mips64-linux-gnuabi64 -target-abi=n64 -mcpu=mips64r5 -mattr=+micromips -relocation-model=pic -verify-machineinstrs -filetype=obj %s -o %t.n64bepic
; RUN: llvm-readobj -r %t.n64bepic | FileCheck %s --check-prefix=N64-PIC
; RUN: llc -mtriple=mips64el-linux-gnuabi64 -target-abi=n64 -mcpu=mips64r5 -mattr=+micromips,+noabicalls -relocation-model=static -verify-machineinstrs -filetype=obj %s -o %t.n64lestatic
; RUN: llvm-readobj -r %t.n64lestatic | FileCheck %s --check-prefix=N64-STATIC
; RUN: llc -mtriple=mips64el-linux-gnuabi64 -target-abi=n64 -mcpu=mips64r5 -mattr=+micromips -relocation-model=pic -verify-machineinstrs -filetype=obj %s -o %t.n64lepic
; RUN: llvm-readobj -r %t.n64lepic | FileCheck %s --check-prefix=N64-PIC

@g = external global i64
@t = external thread_local global i64

; N64-STATIC: R_MICROMIPS_HIGHEST{{.*}} g
; N64-STATIC-NEXT: {{.*}}R_MICROMIPS_HIGHER{{.*}} g
; N64-STATIC-NEXT: {{.*}}R_MICROMIPS_HI16{{.*}} g
; N64-STATIC-NEXT: {{.*}}R_MICROMIPS_LO16{{.*}} g
; N32-STATIC: R_MICROMIPS_HI16 g
; N32-STATIC-NEXT: {{.*}}R_MICROMIPS_LO16 g
; N64-PIC: R_MICROMIPS_GPREL16/R_MICROMIPS_SUB/R_MICROMIPS_HI16 global_address
; N64-PIC-NEXT: {{.*}}R_MICROMIPS_GPREL16/R_MICROMIPS_SUB/R_MICROMIPS_LO16 global_address
; N64-PIC-NEXT: {{.*}}R_MICROMIPS_GOT_DISP{{.*}} g
; N32-PIC: R_MICROMIPS_GPREL16 global_address
; N32-PIC-NEXT: {{.*}}R_MICROMIPS_SUB
; N32-PIC-NEXT: {{.*}}R_MICROMIPS_HI16
; N32-PIC: R_MICROMIPS_GPREL16 global_address
; N32-PIC-NEXT: {{.*}}R_MICROMIPS_SUB
; N32-PIC-NEXT: {{.*}}R_MICROMIPS_LO16
; N32-PIC-NEXT: {{.*}}R_MICROMIPS_GOT_DISP g
define ptr @global_address() {
  ret ptr @g
}

define ptr @tls_address() {
  ret ptr @t
}
