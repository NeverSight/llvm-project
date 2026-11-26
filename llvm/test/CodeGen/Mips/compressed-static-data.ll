; RUN: split-file %s %t
; RUN: llc -filetype=obj -mtriple=mips -mcpu=mips32r2 -mattr=+mips16 -relocation-model=pic %t/tls.ll -o %t/be.o
; RUN: llc -filetype=obj -mtriple=mipsel -mcpu=mips32r2 -mattr=+mips16 -relocation-model=pic %t/tls.ll -o %t/le.o
; RUN: llvm-readobj -r %t/be.o | FileCheck %s --check-prefix=M16-TLS
; RUN: llvm-readobj -r %t/le.o | FileCheck %s --check-prefix=M16-TLS
; RUN: llvm-objdump -d --mcpu=mips32r2 --mattr=-mips16 -j .text.__llvm_mips16_read_tp %t/le.o | FileCheck %s --check-prefix=TP
; RUN: llc -filetype=obj -mtriple=mips64el -target-abi=n64 -mcpu=mips64r6 -mattr=+micromips -relocation-model=pic %t/tls.ll -o %t/n64.o
; RUN: llvm-readobj -r %t/n64.o | FileCheck %s --check-prefix=MM-TLS
; RUN: llc -filetype=obj -mtriple=mipsel -mcpu=mips32r2 -mattr=+micromips,+noabicalls -mgpopt %t/small.ll -o %t/mm.o
; RUN: llvm-readobj -r %t/mm.o | FileCheck %s --check-prefix=MM-GP
; RUN: llc -filetype=obj -mtriple=mips -mcpu=mips32r2 -mattr=+mips16,+noabicalls -mgpopt %t/small.ll -o %t/m16.o
; RUN: llvm-readobj -r %t/m16.o | FileCheck %s --check-prefix=M16-GP

; M16-TLS-DAG: R_MIPS16_TLS_TPREL_HI16 local_exec
; M16-TLS-DAG: R_MIPS16_TLS_TPREL_LO16 local_exec
; M16-TLS-DAG: R_MIPS16_TLS_GOTTPREL initial_exec
; M16-TLS-DAG: R_MIPS16_CALL16 __llvm_mips16_read_tp
; TP-LABEL: <__llvm_mips16_read_tp>:
; TP:       rdhwr $3, $29
; TP:       jr $ra
; TP-NEXT:  {{.*}}move $2, $3
; MM-TLS-DAG: R_MICROMIPS_TLS_TPREL_HI16{{[^ ]*}} local_exec
; MM-TLS-DAG: R_MICROMIPS_TLS_TPREL_LO16{{[^ ]*}} local_exec
; MM-TLS-DAG: R_MICROMIPS_TLS_GOTTPREL{{[^ ]*}} initial_exec
; MM-GP: R_MICROMIPS_GPREL16 seed
; M16-GP: R_MIPS16_GPREL seed

;--- tls.ll
@local_exec = external thread_local(localexec) global i64
@initial_exec = external thread_local(initialexec) global i64

define i64 @local() nounwind {
  %v = load volatile i64, ptr @local_exec
  ret i64 %v
}

define i64 @initial() nounwind {
  %v = load volatile i64, ptr @initial_exec
  ret i64 %v
}

;--- small.ll
@seed = external global i64
define i64 @load_seed() nounwind {
  %v = load volatile i64, ptr @seed
  ret i64 %v
}
