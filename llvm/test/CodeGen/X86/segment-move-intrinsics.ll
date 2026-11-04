; RUN: split-file %s %t
; RUN: opt -S -passes='default<O0>' %t/common.ll | llc -mtriple=i386-unknown-linux-code16 -O0 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=i386-unknown-linux-code16 -O2 -enable-new-pm -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: llc -mtriple=i386-unknown-linux-code16 -stop-after=finalize-isel -verify-machineinstrs %t/common.ll -o - | FileCheck %s --check-prefix=MIR --implicit-check-not=INLINEASM
; RUN: llc -mtriple=i386-unknown-linux-code16 -O0 -verify-machineinstrs -filetype=obj %t/common.ll -o %t.o
; RUN: llvm-objdump -d --mattr=+16bit-mode,-32bit-mode %t.o | FileCheck %s --check-prefix=CODE16
; RUN: opt -S -passes='default<O0>' %t/common.ll | llc -mtriple=i386-unknown-linux-gnu -O0 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=i386-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O0>' %t/common.ll | llc -mtriple=x86_64-unknown-linux-gnu -O0 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=x86_64-unknown-linux-gnu -O2 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O0>' %t/common.ll | llc -mtriple=i686-pc-windows-msvc -O0 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=i686-pc-windows-msvc -O2 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O0>' %t/common.ll | llc -mtriple=x86_64-pc-windows-msvc -O0 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=x86_64-pc-windows-msvc -O2 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O0>' %t/common.ll | llc -mtriple=i386-apple-darwin -O0 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=i386-apple-darwin -O2 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O0>' %t/common.ll | llc -mtriple=x86_64-apple-darwin -O0 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -mtriple=x86_64-apple-darwin -O2 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O0>' %t/common.ll | llc -enable-new-pm -mtriple=i386 -O0 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -enable-new-pm -mtriple=i386 -O2 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O0>' %t/common.ll | llc -enable-new-pm -mtriple=x86_64 -O0 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: opt -S -passes='default<O2>' %t/common.ll | llc -enable-new-pm -mtriple=x86_64 -O2 -verify-machineinstrs | FileCheck %s --check-prefix=ASM --implicit-check-not='#APP'
; RUN: llc -mtriple=x86_64 -stop-after=finalize-isel -verify-machineinstrs %t/common.ll -o - | FileCheck %s --check-prefix=MIR --implicit-check-not=INLINEASM
; RUN: opt -S -passes=verify %t/common.ll | FileCheck %s --check-prefix=ATTR
; RUN: not --crash llc -mtriple=x86_64 %t/bad-index.ll 2>&1 | FileCheck %s --check-prefix=BADINDEX
; RUN: not --crash llc -mtriple=i386 %t/bad-index.ll 2>&1 | FileCheck %s --check-prefix=BADINDEX
; RUN: not --crash llc -mtriple=x86_64 %t/bad-write.ll 2>&1 | FileCheck %s --check-prefix=BADWRITE
; RUN: not --crash llc -mtriple=i386 %t/bad-write.ll 2>&1 | FileCheck %s --check-prefix=BADWRITE
; RUN: not --crash llc -mtriple=i386-unknown-linux-code16 %t/bad-index.ll 2>&1 | FileCheck %s --check-prefix=BADINDEX
; RUN: not --crash llc -mtriple=i386-unknown-linux-code16 %t/bad-write.ll 2>&1 | FileCheck %s --check-prefix=BADWRITE
; RUN: not opt -passes=verify -disable-output %t/dynamic.ll 2>&1 | FileCheck %s --check-prefix=DYNAMIC
; RUN: not opt -passes=verify -disable-output %t/bad-type.ll 2>&1 | FileCheck %s --check-prefix=BADTYPE

; BADINDEX: segment register index must be in [0, 5]
; BADWRITE: MOV cannot write the CS segment register
; DYNAMIC: immarg operand has non-immediate parameter
; BADTYPE: intrinsic argument 1 type expected i16, but got i64
; ATTR: declare i16 @llvm.x86.readseg(i32 immarg) #[[A:[0-9]+]]
; ATTR: declare void @llvm.x86.readseg.mem(i32 immarg, ptr) #[[A]]
; ATTR: declare void @llvm.x86.writeseg(i32 immarg, i16) #[[A]]
; ATTR: declare void @llvm.x86.writeseg.mem(i32 immarg, ptr) #[[A]]
; ATTR: attributes #[[A]] = { nounwind }
; CODE16-LABEL: <readseg_es>:
; CODE16-COUNT-2: : 8c {{[0-9a-f]+}} {{.*}}movw
; CODE16-LABEL: <readseg_mem_es>:
; CODE16-COUNT-2: : 67 8c {{[0-9a-f]+}} {{.*}}movw
; CODE16-LABEL: <writeseg_es>:
; CODE16-COUNT-2: : 8e {{[0-9a-f]+}} {{.*}}movw
; CODE16-LABEL: <writeseg_mem_es>:
; CODE16-COUNT-2: : 67 8e {{[0-9a-f]+}} {{.*}}movw

;--- common.ll
declare i16 @llvm.x86.readseg(i32 immarg)
declare void @llvm.x86.readseg.mem(i32 immarg, ptr)
declare void @llvm.x86.writeseg(i32 immarg, i16)
declare void @llvm.x86.writeseg.mem(i32 immarg, ptr)

; ASM-LABEL: readseg_es:
; ASM-COUNT-2: movw{{.*}}%es
; ASM: ret
; MIR-LABEL: name: readseg_es
; MIR: MOV16rs $es
define i16 @readseg_es(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  %result = call i16 @llvm.x86.readseg(i32 0)
  call i16 @llvm.x86.readseg(i32 0)
  store i32 23, ptr %marker
  ret i16 %result
}

; ASM-LABEL: readseg_mem_es:
; ASM-COUNT-2: movw{{.*}}%es
; ASM: ret
; MIR-LABEL: name: readseg_mem_es
; MIR: MOV16ms {{.*}}$es{{.*}}volatile store (s16)
define void @readseg_mem_es(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.readseg.mem(i32 0, ptr %p)
  call void @llvm.x86.readseg.mem(i32 0, ptr %p)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: writeseg_es:
; ASM-COUNT-2: movw{{.*}}%es
; ASM: ret
; MIR-LABEL: name: writeseg_es
; MIR: $es = MOV16sr{{.*}}volatile load store unknown-size
define void @writeseg_es(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.writeseg(i32 0, i16 %value)
  call void @llvm.x86.writeseg(i32 0, i16 %value)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: writeseg_mem_es:
; ASM-COUNT-2: movw{{.*}}%es
; ASM: ret
; MIR-LABEL: name: writeseg_mem_es
; MIR: $es = MOV16sm{{.*}}volatile load store unknown-size
define void @writeseg_mem_es(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.writeseg.mem(i32 0, ptr %p)
  call void @llvm.x86.writeseg.mem(i32 0, ptr %p)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: readseg_cs:
; ASM-COUNT-2: movw{{.*}}%cs
; ASM: ret
; MIR-LABEL: name: readseg_cs
; MIR: MOV16rs $cs
define i16 @readseg_cs(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  %result = call i16 @llvm.x86.readseg(i32 1)
  call i16 @llvm.x86.readseg(i32 1)
  store i32 23, ptr %marker
  ret i16 %result
}

; ASM-LABEL: readseg_mem_cs:
; ASM-COUNT-2: movw{{.*}}%cs
; ASM: ret
; MIR-LABEL: name: readseg_mem_cs
; MIR: MOV16ms {{.*}}$cs{{.*}}volatile store (s16)
define void @readseg_mem_cs(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.readseg.mem(i32 1, ptr %p)
  call void @llvm.x86.readseg.mem(i32 1, ptr %p)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: readseg_ss:
; ASM-COUNT-2: movw{{.*}}%ss
; ASM: ret
; MIR-LABEL: name: readseg_ss
; MIR: MOV16rs $ss
define i16 @readseg_ss(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  %result = call i16 @llvm.x86.readseg(i32 2)
  call i16 @llvm.x86.readseg(i32 2)
  store i32 23, ptr %marker
  ret i16 %result
}

; ASM-LABEL: readseg_mem_ss:
; ASM-COUNT-2: movw{{.*}}%ss
; ASM: ret
; MIR-LABEL: name: readseg_mem_ss
; MIR: MOV16ms {{.*}}$ss{{.*}}volatile store (s16)
define void @readseg_mem_ss(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.readseg.mem(i32 2, ptr %p)
  call void @llvm.x86.readseg.mem(i32 2, ptr %p)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: writeseg_ss:
; ASM-COUNT-2: movw{{.*}}%ss
; ASM: ret
; MIR-LABEL: name: writeseg_ss
; MIR: $ss = MOV16sr{{.*}}volatile load store unknown-size
define void @writeseg_ss(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.writeseg(i32 2, i16 %value)
  call void @llvm.x86.writeseg(i32 2, i16 %value)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: writeseg_mem_ss:
; ASM-COUNT-2: movw{{.*}}%ss
; ASM: ret
; MIR-LABEL: name: writeseg_mem_ss
; MIR: $ss = MOV16sm{{.*}}volatile load store unknown-size
define void @writeseg_mem_ss(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.writeseg.mem(i32 2, ptr %p)
  call void @llvm.x86.writeseg.mem(i32 2, ptr %p)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: readseg_ds:
; ASM-COUNT-2: movw{{.*}}%ds
; ASM: ret
; MIR-LABEL: name: readseg_ds
; MIR: MOV16rs $ds
define i16 @readseg_ds(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  %result = call i16 @llvm.x86.readseg(i32 3)
  call i16 @llvm.x86.readseg(i32 3)
  store i32 23, ptr %marker
  ret i16 %result
}

; ASM-LABEL: readseg_mem_ds:
; ASM-COUNT-2: movw{{.*}}%ds
; ASM: ret
; MIR-LABEL: name: readseg_mem_ds
; MIR: MOV16ms {{.*}}$ds{{.*}}volatile store (s16)
define void @readseg_mem_ds(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.readseg.mem(i32 3, ptr %p)
  call void @llvm.x86.readseg.mem(i32 3, ptr %p)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: writeseg_ds:
; ASM-COUNT-2: movw{{.*}}%ds
; ASM: ret
; MIR-LABEL: name: writeseg_ds
; MIR: $ds = MOV16sr{{.*}}volatile load store unknown-size
define void @writeseg_ds(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.writeseg(i32 3, i16 %value)
  call void @llvm.x86.writeseg(i32 3, i16 %value)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: writeseg_mem_ds:
; ASM-COUNT-2: movw{{.*}}%ds
; ASM: ret
; MIR-LABEL: name: writeseg_mem_ds
; MIR: $ds = MOV16sm{{.*}}volatile load store unknown-size
define void @writeseg_mem_ds(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.writeseg.mem(i32 3, ptr %p)
  call void @llvm.x86.writeseg.mem(i32 3, ptr %p)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: readseg_fs:
; ASM-COUNT-2: movw{{.*}}%fs
; ASM: ret
; MIR-LABEL: name: readseg_fs
; MIR: MOV16rs $fs
define i16 @readseg_fs(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  %result = call i16 @llvm.x86.readseg(i32 4)
  call i16 @llvm.x86.readseg(i32 4)
  store i32 23, ptr %marker
  ret i16 %result
}

; ASM-LABEL: readseg_mem_fs:
; ASM-COUNT-2: movw{{.*}}%fs
; ASM: ret
; MIR-LABEL: name: readseg_mem_fs
; MIR: MOV16ms {{.*}}$fs{{.*}}volatile store (s16)
define void @readseg_mem_fs(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.readseg.mem(i32 4, ptr %p)
  call void @llvm.x86.readseg.mem(i32 4, ptr %p)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: writeseg_fs:
; ASM-COUNT-2: movw{{.*}}%fs
; ASM: ret
; MIR-LABEL: name: writeseg_fs
; MIR: $fs = MOV16sr{{.*}}volatile load store unknown-size
define void @writeseg_fs(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.writeseg(i32 4, i16 %value)
  call void @llvm.x86.writeseg(i32 4, i16 %value)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: writeseg_mem_fs:
; ASM-COUNT-2: movw{{.*}}%fs
; ASM: ret
; MIR-LABEL: name: writeseg_mem_fs
; MIR: $fs = MOV16sm{{.*}}volatile load store unknown-size
define void @writeseg_mem_fs(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.writeseg.mem(i32 4, ptr %p)
  call void @llvm.x86.writeseg.mem(i32 4, ptr %p)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: readseg_gs:
; ASM-COUNT-2: movw{{.*}}%gs
; ASM: ret
; MIR-LABEL: name: readseg_gs
; MIR: MOV16rs $gs
define i16 @readseg_gs(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  %result = call i16 @llvm.x86.readseg(i32 5)
  call i16 @llvm.x86.readseg(i32 5)
  store i32 23, ptr %marker
  ret i16 %result
}

; ASM-LABEL: readseg_mem_gs:
; ASM-COUNT-2: movw{{.*}}%gs
; ASM: ret
; MIR-LABEL: name: readseg_mem_gs
; MIR: MOV16ms {{.*}}$gs{{.*}}volatile store (s16)
define void @readseg_mem_gs(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.readseg.mem(i32 5, ptr %p)
  call void @llvm.x86.readseg.mem(i32 5, ptr %p)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: writeseg_gs:
; ASM-COUNT-2: movw{{.*}}%gs
; ASM: ret
; MIR-LABEL: name: writeseg_gs
; MIR: $gs = MOV16sr{{.*}}volatile load store unknown-size
define void @writeseg_gs(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.writeseg(i32 5, i16 %value)
  call void @llvm.x86.writeseg(i32 5, i16 %value)
  store i32 23, ptr %marker
  ret void
}

; ASM-LABEL: writeseg_mem_gs:
; ASM-COUNT-2: movw{{.*}}%gs
; ASM: ret
; MIR-LABEL: name: writeseg_mem_gs
; MIR: $gs = MOV16sm{{.*}}volatile load store unknown-size
define void @writeseg_mem_gs(ptr %p, i16 %value, ptr %marker) {
  store i32 17, ptr %marker
  call void @llvm.x86.writeseg.mem(i32 5, ptr %p)
  call void @llvm.x86.writeseg.mem(i32 5, ptr %p)
  store i32 23, ptr %marker
  ret void
}

;--- bad-index.ll
declare i16 @llvm.x86.readseg(i32)
define void @bad() {
  call i16 @llvm.x86.readseg(i32 6)
  ret void
}
;--- bad-write.ll
declare void @llvm.x86.writeseg.mem(i32, ptr)
define void @bad(ptr %p) {
  call void @llvm.x86.writeseg.mem(i32 1, ptr %p)
  ret void
}
;--- dynamic.ll
declare i16 @llvm.x86.readseg(i32)
define i16 @bad(i32 %index) {
  %v = call i16 @llvm.x86.readseg(i32 %index)
  ret i16 %v
}
;--- bad-type.ll
declare void @llvm.x86.writeseg(i32, i64)
define void @bad(i64 %value) {
  call void @llvm.x86.writeseg(i32 2, i64 %value)
  ret void
}
