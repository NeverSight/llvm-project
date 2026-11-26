; RUN: llc -mtriple=mips64-linux-gnuabi64 -target-abi=n64 -mcpu=mips64r2 -mattr=+micromips -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=mips64el-linux-gnuabi64 -target-abi=n64 -mcpu=mips64r2 -mattr=+micromips -verify-machineinstrs -filetype=obj %s -o %t
; RUN: llc -mtriple=mips64-linux-gnuabin32 -target-abi=n32 -mcpu=mips64r2 -mattr=+micromips -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=mipsel-linux-gnu -target-abi=o32 -mcpu=mips32r2 -mattr=+micromips -verify-machineinstrs %s -o - | FileCheck %s

; Only the addressing register class changes width. Keep both compact word
; memory instructions and use the same computed pointer for the store.
; CHECK-LABEL: bump:
; CHECK: lw16 {{\$[0-9]+}}, 0([[BASE:\$[0-9]+]])
; CHECK: sw16 {{\$[0-9]+}}, 0([[BASE]])
define i32 @bump(ptr %base, i64 %index) {
  %p = getelementptr i32, ptr %base, i64 %index
  %v = load volatile i32, ptr %p
  %next = add i32 %v, 7
  store volatile i32 %next, ptr %p
  ret i32 %v
}
