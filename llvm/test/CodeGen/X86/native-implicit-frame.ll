; Native leaves borrow RBX only inside a final-emission register window.
; Spill/reload scheduling and dynamic alignment must never see the borrowed base.
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs %s -o - | FileCheck %s
; RUN: llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs %s -o - | FileCheck %s

declare { i64, i64, i64, i64, i8 } @llvm.x86.encls(i64, i64, i64, i64)
declare { i64, i64, i64, i64, i8 } @llvm.x86.enclv(i64, i64, i64, i64)
declare { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64, i64, i64, i64)
declare { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64, i64, i64, i64)
declare { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64, i64, i64, i64, i16)
declare { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64, i64, i64, i64, i16)
declare void @llvm.x86.cpuidex(ptr, i32, i32)

; CHECK-LABEL: probe_encls:
; CHECK: xchgq %[[C:r(8|9|10|11)]], %rbx
; CHECK-NEXT: encls
; CHECK-NEXT: xchgq %[[C]], %rbx
define i64 @probe_encls(i64 %b, i64 %n, ptr %out) #0 {
  %fixed = alloca [16 x i64], align 64
  store volatile i64 305419896, ptr %fixed
  %dynamic = alloca i8, i64 %n, align 32
  store volatile i8 165, ptr %dynamic
  %r = call { i64, i64, i64, i64, i8 } @llvm.x86.encls(i64 0, i64 %b, i64 0, i64 0)
  %r0 = extractvalue { i64, i64, i64, i64, i8 } %r, 0
  %p0 = getelementptr i64, ptr %out, i64 0
  store volatile i64 %r0, ptr %p0
  %r1 = extractvalue { i64, i64, i64, i64, i8 } %r, 1
  %p1 = getelementptr i64, ptr %out, i64 1
  store volatile i64 %r1, ptr %p1
  %r2 = extractvalue { i64, i64, i64, i64, i8 } %r, 2
  %p2 = getelementptr i64, ptr %out, i64 2
  store volatile i64 %r2, ptr %p2
  %r3 = extractvalue { i64, i64, i64, i64, i8 } %r, 3
  %p3 = getelementptr i64, ptr %out, i64 3
  store volatile i64 %r3, ptr %p3
  %canary = load volatile i64, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %value = zext i8 %byte to i64
  %result = xor i64 %canary, %value
  ret i64 %result
}

; CHECK-LABEL: probe_enclv:
; CHECK: xchgq %[[C:r(8|9|10|11)]], %rbx
; CHECK-NEXT: enclv
; CHECK-NEXT: xchgq %[[C]], %rbx
define i64 @probe_enclv(i64 %b, i64 %n, ptr %out) #0 {
  %fixed = alloca [16 x i64], align 64
  store volatile i64 305419896, ptr %fixed
  %dynamic = alloca i8, i64 %n, align 32
  store volatile i8 165, ptr %dynamic
  %r = call { i64, i64, i64, i64, i8 } @llvm.x86.enclv(i64 0, i64 %b, i64 0, i64 0)
  %r0 = extractvalue { i64, i64, i64, i64, i8 } %r, 0
  %p0 = getelementptr i64, ptr %out, i64 0
  store volatile i64 %r0, ptr %p0
  %r1 = extractvalue { i64, i64, i64, i64, i8 } %r, 1
  %p1 = getelementptr i64, ptr %out, i64 1
  store volatile i64 %r1, ptr %p1
  %r2 = extractvalue { i64, i64, i64, i64, i8 } %r, 2
  %p2 = getelementptr i64, ptr %out, i64 2
  store volatile i64 %r2, ptr %p2
  %r3 = extractvalue { i64, i64, i64, i64, i8 } %r, 3
  %p3 = getelementptr i64, ptr %out, i64 3
  store volatile i64 %r3, ptr %p3
  %canary = load volatile i64, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %value = zext i8 %byte to i64
  %result = xor i64 %canary, %value
  ret i64 %result
}

; CHECK-LABEL: probe_enclu_bounded:
; CHECK: xchgq %[[C:r(8|9|10|11)]], %rbx
; CHECK-NEXT: enclu
; CHECK-NEXT: xchgq %[[C]], %rbx
define i64 @probe_enclu_bounded(i64 %b, i64 %n, ptr %out) #0 {
  %fixed = alloca [16 x i64], align 64
  store volatile i64 305419896, ptr %fixed
  %dynamic = alloca i8, i64 %n, align 32
  store volatile i8 165, ptr %dynamic
  %r = call { i64, i64, i64, i64, i8 } @llvm.x86.enclu.bounded(i64 0, i64 %b, i64 0, i64 0)
  %r0 = extractvalue { i64, i64, i64, i64, i8 } %r, 0
  %p0 = getelementptr i64, ptr %out, i64 0
  store volatile i64 %r0, ptr %p0
  %r1 = extractvalue { i64, i64, i64, i64, i8 } %r, 1
  %p1 = getelementptr i64, ptr %out, i64 1
  store volatile i64 %r1, ptr %p1
  %r2 = extractvalue { i64, i64, i64, i64, i8 } %r, 2
  %p2 = getelementptr i64, ptr %out, i64 2
  store volatile i64 %r2, ptr %p2
  %r3 = extractvalue { i64, i64, i64, i64, i8 } %r, 3
  %p3 = getelementptr i64, ptr %out, i64 3
  store volatile i64 %r3, ptr %p3
  %canary = load volatile i64, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %value = zext i8 %byte to i64
  %result = xor i64 %canary, %value
  ret i64 %result
}

; CHECK-LABEL: probe_getsec_bounded:
; CHECK: xchgq %[[C:r(8|9|10|11)]], %rbx
; CHECK-NEXT: getsec
; CHECK-NEXT: xchgq %[[C]], %rbx
define i64 @probe_getsec_bounded(i64 %b, i64 %n, ptr %out) #0 {
  %fixed = alloca [16 x i64], align 64
  store volatile i64 305419896, ptr %fixed
  %dynamic = alloca i8, i64 %n, align 32
  store volatile i8 165, ptr %dynamic
  %r = call { i64, i64, i64, i64 } @llvm.x86.getsec.bounded(i64 0, i64 %b, i64 0, i64 0)
  %r0 = extractvalue { i64, i64, i64, i64 } %r, 0
  %p0 = getelementptr i64, ptr %out, i64 0
  store volatile i64 %r0, ptr %p0
  %r1 = extractvalue { i64, i64, i64, i64 } %r, 1
  %p1 = getelementptr i64, ptr %out, i64 1
  store volatile i64 %r1, ptr %p1
  %r2 = extractvalue { i64, i64, i64, i64 } %r, 2
  %p2 = getelementptr i64, ptr %out, i64 2
  store volatile i64 %r2, ptr %p2
  %r3 = extractvalue { i64, i64, i64, i64 } %r, 3
  %p3 = getelementptr i64, ptr %out, i64 3
  store volatile i64 %r3, ptr %p3
  %canary = load volatile i64, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %value = zext i8 %byte to i64
  %result = xor i64 %canary, %value
  ret i64 %result
}

; CHECK-LABEL: probe_enclu_bounded_state:
; CHECK: xchgq %[[C:r(8|9|10|11)]], %rbx
; CHECK-NEXT: xchgq %rdi, %rax
; CHECK-NEXT: addb $127, %al
; CHECK-NEXT: sahf
; CHECK-NEXT: xchgq %rdi, %rax
; CHECK-NEXT: enclu
; CHECK-NEXT: xchgq %rdi, %rax
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %al
; CHECK-NEXT: xchgq %rdi, %rax
; CHECK-NEXT: xchgq %[[C]], %rbx
define i64 @probe_enclu_bounded_state(i64 %b, i64 %n, ptr %out) #0 {
  %fixed = alloca [16 x i64], align 64
  store volatile i64 305419896, ptr %fixed
  %dynamic = alloca i8, i64 %n, align 32
  store volatile i8 165, ptr %dynamic
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.enclu.bounded.state(i64 0, i64 %b, i64 0, i64 0, i16 54529)
  %r0 = extractvalue { i64, i64, i64, i64, i16 } %r, 0
  %p0 = getelementptr i64, ptr %out, i64 0
  store volatile i64 %r0, ptr %p0
  %r1 = extractvalue { i64, i64, i64, i64, i16 } %r, 1
  %p1 = getelementptr i64, ptr %out, i64 1
  store volatile i64 %r1, ptr %p1
  %r2 = extractvalue { i64, i64, i64, i64, i16 } %r, 2
  %p2 = getelementptr i64, ptr %out, i64 2
  store volatile i64 %r2, ptr %p2
  %r3 = extractvalue { i64, i64, i64, i64, i16 } %r, 3
  %p3 = getelementptr i64, ptr %out, i64 3
  store volatile i64 %r3, ptr %p3
  %canary = load volatile i64, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %value = zext i8 %byte to i64
  %result = xor i64 %canary, %value
  ret i64 %result
}

; CHECK-LABEL: probe_getsec_bounded_state:
; CHECK: xchgq %[[C:r(8|9|10|11)]], %rbx
; CHECK-NEXT: xchgq %rdi, %rax
; CHECK-NEXT: addb $127, %al
; CHECK-NEXT: sahf
; CHECK-NEXT: xchgq %rdi, %rax
; CHECK-NEXT: getsec
; CHECK-NEXT: xchgq %rdi, %rax
; CHECK-NEXT: lahf
; CHECK-NEXT: seto %al
; CHECK-NEXT: xchgq %rdi, %rax
; CHECK-NEXT: xchgq %[[C]], %rbx
define i64 @probe_getsec_bounded_state(i64 %b, i64 %n, ptr %out) #0 {
  %fixed = alloca [16 x i64], align 64
  store volatile i64 305419896, ptr %fixed
  %dynamic = alloca i8, i64 %n, align 32
  store volatile i8 165, ptr %dynamic
  %r = call { i64, i64, i64, i64, i16 } @llvm.x86.getsec.bounded.state(i64 0, i64 %b, i64 0, i64 0, i16 54529)
  %r0 = extractvalue { i64, i64, i64, i64, i16 } %r, 0
  %p0 = getelementptr i64, ptr %out, i64 0
  store volatile i64 %r0, ptr %p0
  %r1 = extractvalue { i64, i64, i64, i64, i16 } %r, 1
  %p1 = getelementptr i64, ptr %out, i64 1
  store volatile i64 %r1, ptr %p1
  %r2 = extractvalue { i64, i64, i64, i64, i16 } %r, 2
  %p2 = getelementptr i64, ptr %out, i64 2
  store volatile i64 %r2, ptr %p2
  %r3 = extractvalue { i64, i64, i64, i64, i16 } %r, 3
  %p3 = getelementptr i64, ptr %out, i64 3
  store volatile i64 %r3, ptr %p3
  %canary = load volatile i64, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %value = zext i8 %byte to i64
  %result = xor i64 %canary, %value
  ret i64 %result
}

; CHECK-LABEL: probe_cpuidex:
; CHECK: xchgq %[[C:r(8|9|10|11)]], %rbx
; CHECK-NEXT: cpuid
; CHECK-NEXT: xchgq %[[C]], %rbx
define i64 @probe_cpuidex(i64 %b, i64 %n, ptr %out) #0 {
  %fixed = alloca [16 x i64], align 64
  store volatile i64 305419896, ptr %fixed
  %dynamic = alloca i8, i64 %n, align 32
  store volatile i8 165, ptr %dynamic
  call void @llvm.x86.cpuidex(ptr %out, i32 0, i32 0)
  %canary = load volatile i64, ptr %fixed
  %byte = load volatile i8, ptr %dynamic
  %value = zext i8 %byte to i64
  %result = xor i64 %canary, %value
  ret i64 %result
}

attributes #0 = { "target-features"="+sgx,+sahf" "no-stack-arg-probe" }
