; RUN: split-file %s %t
; RUN: not --crash llc %t/mixed.ll -O0 -mtriple=x86_64 -mattr=+amx-fp8 -o /dev/null 2>&1 | FileCheck %s --check-prefix=MIXED
; RUN: not --crash llc %t/mixed.ll -O2 -mtriple=x86_64 -mattr=+amx-fp8 -o /dev/null 2>&1 | FileCheck %s --check-prefix=MIXED
; RUN: not --crash llc %t/index.ll -O0 -mtriple=x86_64 -mattr=+amx-tile -o /dev/null 2>&1 | FileCheck %s --check-prefix=INDEX
; RUN: not --crash llc %t/index.ll -O2 -mtriple=x86_64 -mattr=+amx-tile -o /dev/null 2>&1 | FileCheck %s --check-prefix=INDEX
;
; These contract failures must also be diagnosed by assertion-disabled builds.
; MIXED: LLVM ERROR: cannot mix physical AMX tile intrinsics with compiler-managed tiles
; INDEX: LLVM ERROR: AMX intrinsic requires a tile index in [0, 7]

;--- mixed.ll
declare x86_amx @llvm.x86.tileloadd64.internal(i16, i16, ptr, i64)
declare void @llvm.x86.tilestored64.internal(i16, i16, ptr, i64, x86_amx)
declare void @llvm.x86.tdpbf8ps(i8, i8, i8)
define void @mixed(ptr %input, ptr %output) {
  %tile = call x86_amx @llvm.x86.tileloadd64.internal(i16 2, i16 16, ptr %input, i64 64)
  call void @llvm.x86.tdpbf8ps(i8 0, i8 1, i8 2)
  call void @llvm.x86.tilestored64.internal(i16 2, i16 16, ptr %output, i64 64, x86_amx %tile)
  ret void
}

;--- index.ll
declare void @llvm.x86.tilezero(i8)
define void @index() {
  call void @llvm.x86.tilezero(i8 8)
  ret void
}
