; REP sources must not replace the compiler-owned ESI realignment base.
; Keep the exchange window contiguous through allocation and final MC emission.
; RUN: llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=i386-pc-windows-msvc -O0 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=i386-pc-windows-msvc -O2 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=i386-apple-darwin -O0 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=i386-unknown-linux-gnu -relocation-model=pic -O2 -verify-machineinstrs %s -o - | FileCheck %s

; CHECK-LABEL: probe_movs_state:
; CHECK: xchgl [[PAIR:.*]]
; CHECK-NEXT: rep{{.*}}movsb
; CHECK-NEXT: cld
; CHECK-NEXT: xchgl [[PAIR]]
declare { i32, i32, i32 } @llvm.x86.rep.movs.state32(i32, i32, i32, i8, i32, i32, i32)
define i32 @probe_movs_state(i32 %src, i32 %dst, i32 %count, i32 %value, i8 %direction, i16 %flags, i32 %n, ptr %out) "no-stack-arg-probe" {
  %fixed = alloca [16 x i32], align 64
  store volatile i32 305419896, ptr %fixed
  %dynamic = alloca i8, i32 %n, align 32
  store volatile i8 165, ptr %dynamic
  %src_ptr = inttoptr i32 %src to ptr
  %dst_ptr = inttoptr i32 %dst to ptr
  %port = trunc i32 %value to i16
  %r = call { i32, i32, i32 } @llvm.x86.rep.movs.state32(i32 %src, i32 %dst, i32 %count, i8 %direction, i32 1, i32 32, i32 0)
  %r0 = extractvalue { i32, i32, i32 } %r, 0
  %p0 = getelementptr i32, ptr %out, i32 0
  store volatile i32 %r0, ptr %p0
  %r1 = extractvalue { i32, i32, i32 } %r, 1
  %p1 = getelementptr i32, ptr %out, i32 1
  store volatile i32 %r1, ptr %p1
  %r2 = extractvalue { i32, i32, i32 } %r, 2
  %p2 = getelementptr i32, ptr %out, i32 2
  store volatile i32 %r2, ptr %p2
  %canary = load volatile i32, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %b = zext i8 %byte to i32
  %ret = xor i32 %canary, %b
  ret i32 %ret
}

; CHECK-LABEL: probe_lods_state:
; CHECK: xchgl [[PAIR:.*]]
; CHECK-NEXT: rep{{.*}}lodsw
; CHECK-NEXT: cld
; CHECK-NEXT: xchgl [[PAIR]]
declare { i32, i32, i32 } @llvm.x86.rep.lods.state32(i32, i32, i32, i8, i32, i32, i32)
define i32 @probe_lods_state(i32 %src, i32 %dst, i32 %count, i32 %value, i8 %direction, i16 %flags, i32 %n, ptr %out) "no-stack-arg-probe" {
  %fixed = alloca [16 x i32], align 64
  store volatile i32 305419896, ptr %fixed
  %dynamic = alloca i8, i32 %n, align 32
  store volatile i8 165, ptr %dynamic
  %src_ptr = inttoptr i32 %src to ptr
  %dst_ptr = inttoptr i32 %dst to ptr
  %port = trunc i32 %value to i16
  %r = call { i32, i32, i32 } @llvm.x86.rep.lods.state32(i32 %src, i32 %count, i32 %value, i8 %direction, i32 2, i32 16, i32 0)
  %r0 = extractvalue { i32, i32, i32 } %r, 0
  %p0 = getelementptr i32, ptr %out, i32 0
  store volatile i32 %r0, ptr %p0
  %r1 = extractvalue { i32, i32, i32 } %r, 1
  %p1 = getelementptr i32, ptr %out, i32 1
  store volatile i32 %r1, ptr %p1
  %r2 = extractvalue { i32, i32, i32 } %r, 2
  %p2 = getelementptr i32, ptr %out, i32 2
  store volatile i32 %r2, ptr %p2
  %canary = load volatile i32, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %b = zext i8 %byte to i32
  %ret = xor i32 %canary, %b
  ret i32 %ret
}

; CHECK-LABEL: probe_cmps_state:
; CHECK: xchgl [[PAIR:.*]]
; CHECK-NEXT: addb $127, %al
; CHECK-NEXT: sahf
; CHECK-NEXT: rep{{.*}}cmpsl
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %al
; CHECK-NEXT: cld
; CHECK-NEXT: xchgl [[PAIR]]
declare { i32, i32, i32, i16 } @llvm.x86.rep.cmps.state32(i32, i32, i32, i8, i16, i32, i32, i32, i32)
define i32 @probe_cmps_state(i32 %src, i32 %dst, i32 %count, i32 %value, i8 %direction, i16 %flags, i32 %n, ptr %out) "no-stack-arg-probe" {
  %fixed = alloca [16 x i32], align 64
  store volatile i32 305419896, ptr %fixed
  %dynamic = alloca i8, i32 %n, align 32
  store volatile i8 165, ptr %dynamic
  %src_ptr = inttoptr i32 %src to ptr
  %dst_ptr = inttoptr i32 %dst to ptr
  %port = trunc i32 %value to i16
  %r = call { i32, i32, i32, i16 } @llvm.x86.rep.cmps.state32(i32 %src, i32 %dst, i32 %count, i8 %direction, i16 %flags, i32 4, i32 32, i32 0, i32 0)
  %r0 = extractvalue { i32, i32, i32, i16 } %r, 0
  %p0 = getelementptr i32, ptr %out, i32 0
  store volatile i32 %r0, ptr %p0
  %r1 = extractvalue { i32, i32, i32, i16 } %r, 1
  %p1 = getelementptr i32, ptr %out, i32 1
  store volatile i32 %r1, ptr %p1
  %r2 = extractvalue { i32, i32, i32, i16 } %r, 2
  %p2 = getelementptr i32, ptr %out, i32 2
  store volatile i32 %r2, ptr %p2
  %r3 = extractvalue { i32, i32, i32, i16 } %r, 3
  %flags_out = zext i16 %r3 to i32
  %p3 = getelementptr i32, ptr %out, i32 3
  store volatile i32 %flags_out, ptr %p3
  %canary = load volatile i32, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %b = zext i8 %byte to i32
  %ret = xor i32 %canary, %b
  ret i32 %ret
}

; CHECK-LABEL: probe_outs_state:
; CHECK: xchgl [[PAIR:.*]]
; CHECK-NEXT: rep{{.*}}outsb
; CHECK-NEXT: cld
; CHECK-NEXT: xchgl [[PAIR]]
declare { i32, i32 } @llvm.x86.rep.outs.state32(i32, i32, i16, i8, i32, i32, i32)
define i32 @probe_outs_state(i32 %src, i32 %dst, i32 %count, i32 %value, i8 %direction, i16 %flags, i32 %n, ptr %out) "no-stack-arg-probe" {
  %fixed = alloca [16 x i32], align 64
  store volatile i32 305419896, ptr %fixed
  %dynamic = alloca i8, i32 %n, align 32
  store volatile i8 165, ptr %dynamic
  %src_ptr = inttoptr i32 %src to ptr
  %dst_ptr = inttoptr i32 %dst to ptr
  %port = trunc i32 %value to i16
  %r = call { i32, i32 } @llvm.x86.rep.outs.state32(i32 %src, i32 %count, i16 %port, i8 %direction, i32 1, i32 16, i32 0)
  %r0 = extractvalue { i32, i32 } %r, 0
  %p0 = getelementptr i32, ptr %out, i32 0
  store volatile i32 %r0, ptr %p0
  %r1 = extractvalue { i32, i32 } %r, 1
  %p1 = getelementptr i32, ptr %out, i32 1
  store volatile i32 %r1, ptr %p1
  %canary = load volatile i32, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %b = zext i8 %byte to i32
  %ret = xor i32 %canary, %b
  ret i32 %ret
}

; CHECK-LABEL: probe_movs_raw:
; CHECK: xchgl [[PAIR:.*]]
; CHECK-NEXT: rep{{.*}}movsw
; CHECK-NEXT: xchgl [[PAIR]]
declare void @llvm.x86.movsw32(ptr, ptr, i32)
define i32 @probe_movs_raw(i32 %src, i32 %dst, i32 %count, i32 %value, i8 %direction, i16 %flags, i32 %n, ptr %out) "no-stack-arg-probe" {
  %fixed = alloca [16 x i32], align 64
  store volatile i32 305419896, ptr %fixed
  %dynamic = alloca i8, i32 %n, align 32
  store volatile i8 165, ptr %dynamic
  %src_ptr = inttoptr i32 %src to ptr
  %dst_ptr = inttoptr i32 %dst to ptr
  %port = trunc i32 %value to i16
  call void @llvm.x86.movsw32(ptr %dst_ptr, ptr %src_ptr, i32 %count)
  %canary = load volatile i32, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %b = zext i8 %byte to i32
  %ret = xor i32 %canary, %b
  ret i32 %ret
}

; CHECK-LABEL: probe_outs_raw:
; CHECK: xchgl [[PAIR:.*]]
; CHECK-NEXT: rep{{.*}}outsl
; CHECK-NEXT: xchgl [[PAIR]]
declare void @llvm.x86.outdwordstring(i16, ptr, i32)
define i32 @probe_outs_raw(i32 %src, i32 %dst, i32 %count, i32 %value, i8 %direction, i16 %flags, i32 %n, ptr %out) "no-stack-arg-probe" {
  %fixed = alloca [16 x i32], align 64
  store volatile i32 305419896, ptr %fixed
  %dynamic = alloca i8, i32 %n, align 32
  store volatile i8 165, ptr %dynamic
  %src_ptr = inttoptr i32 %src to ptr
  %dst_ptr = inttoptr i32 %dst to ptr
  %port = trunc i32 %value to i16
  call void @llvm.x86.outdwordstring(i16 %port, ptr %src_ptr, i32 %count)
  %canary = load volatile i32, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %b = zext i8 %byte to i32
  %ret = xor i32 %canary, %b
  ret i32 %ret
}
