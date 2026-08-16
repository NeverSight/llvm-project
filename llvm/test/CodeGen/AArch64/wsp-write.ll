; RUN: llc -mtriple=aarch64-none-elf -O0 < %s | FileCheck %s
; RUN: llc -mtriple=aarch64-none-elf -O2 < %s | FileCheck %s

declare void @llvm.aarch64.wsp.write(i32)
declare i32 @llvm.aarch64.wsp.read()

define i32 @read_wsp() {
; CHECK-LABEL: read_wsp:
; CHECK: mov w0, wsp
  %value = call i32 @llvm.aarch64.wsp.read()
  ret i32 %value
}

define void @write_wsp(i32 %value) {
; CHECK-LABEL: write_wsp:
; CHECK: mov wsp, w0
  call void @llvm.aarch64.wsp.write(i32 %value)
  ret void
}
