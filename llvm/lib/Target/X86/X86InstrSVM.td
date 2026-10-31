//===-- X86InstrSVM.td - SVM Instruction Set Extension -----*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the instructions that make up the AMD SVM instruction
// set.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// SVM instructions

let SchedRW = [WriteSystem] in {
// 0F 01 D9
def VMMCALL : I<0x01, MRM_D9, (outs), (ins), "vmmcall", []>, TB;
let hasSideEffects = 1, mayLoad = 1, mayStore = 1 in {
let Uses = [RAX, RBX, RCX, RDX, RSI], Defs = [RAX, EFLAGS] in
def VMMCALL_KVM64 : PseudoI<(outs), (ins), []>, Requires<[In64BitMode]>;
let Uses = [EAX, EBX, ECX, EDX, ESI], Defs = [EAX, EFLAGS] in
def VMMCALL_KVM32 : PseudoI<(outs), (ins), []>, Requires<[Not64BitMode]>;
}

// 0F 01 DC
let hasSideEffects = 1 in
def STGI : I<0x01, MRM_DC, (outs), (ins), "stgi", []>, TB;

// 0F 01 DD
let hasSideEffects = 1 in
def CLGI : I<0x01, MRM_DD, (outs), (ins), "clgi", []>, TB;

// 0F 01 DE
let Uses = [EAX], hasSideEffects = 1, mayLoad = 1, mayStore = 1,
    isTerminator = 1, isBarrier = 1 in
def SKINIT : I<0x01, MRM_DE, (outs), (ins), "skinit", []>, TB;

// 0F 01 D8
let hasSideEffects = 1, mayLoad = 1, mayStore = 1 in {
let Uses = [EAX] in
def VMRUN32 : I<0x01, MRM_D8, (outs), (ins), "vmrun", []>, TB,
                Requires<[Not64BitMode]>;
let Uses = [RAX] in
def VMRUN64 : I<0x01, MRM_D8, (outs), (ins), "vmrun", []>, TB,
                Requires<[In64BitMode]>;
}

// The context pointer is saved in a compiler-owned RSP-relative spill slot;
// no guest GPR is borrowed to retain it across VMEXIT. XSAVE/XRSTOR restore
// the host's enabled user xstate before the ordinary compiler epilogue.
let hasSideEffects = 1, mayLoad = 1, mayStore = 1, Uses = [RSP],
    Defs = [RAX, RBX, RCX, RDX, RSI, RDI, RBP, R8, R9, R10, R11, R12,
            R13, R14, R15, EFLAGS] in
def VMRUN_CONTEXT64 : PseudoI<(outs),
    (ins GR64:$context, i64mem:$spill, i32imm:$width), []>,
    Requires<[In64BitMode]>;

// 0F 01 DA
let hasSideEffects = 1, mayLoad = 1 in {
let Uses = [EAX] in
def VMLOAD32 : I<0x01, MRM_DA, (outs), (ins), "vmload", []>, TB,
                 Requires<[Not64BitMode]>;
let Uses = [RAX] in
def VMLOAD64 : I<0x01, MRM_DA, (outs), (ins), "vmload", []>, TB,
                 Requires<[In64BitMode]>;
}

// 0F 01 DB
let hasSideEffects = 1, mayStore = 1 in {
let Uses = [EAX] in
def VMSAVE32 : I<0x01, MRM_DB, (outs), (ins), "vmsave", []>, TB,
                 Requires<[Not64BitMode]>;
let Uses = [RAX] in
def VMSAVE64 : I<0x01, MRM_DB, (outs), (ins), "vmsave", []>, TB,
                 Requires<[In64BitMode]>;
}

// 0F 01 DF
let hasSideEffects = 1 in {
let Uses = [EAX, ECX] in
def INVLPGA32 : I<0x01, MRM_DF, (outs), (ins),
                "invlpga", []>, TB, Requires<[Not64BitMode]>;
let Uses = [RAX, ECX] in
def INVLPGA64 : I<0x01, MRM_DF, (outs), (ins),
                "invlpga", []>, TB, Requires<[In64BitMode]>;
}
// Implicit addresses have no printed operand from which assembly could infer
// width. Keep these pseudos until MC lowering emits the architectural 67 prefix.
// The machine phase still sees the exact consumed AX/EAX and memory effects.
let Uses = [AX], hasSideEffects = 1, mayLoad = 1 in
def VMLOAD32_ADDR16 : PseudoI<(outs), (ins), []>,
                              Requires<[Not64BitMode]>;
let Uses = [EAX], hasSideEffects = 1, mayLoad = 1 in
def VMLOAD64_ADDR32 : PseudoI<(outs), (ins), []>,
                              Requires<[In64BitMode]>;
let Uses = [AX], hasSideEffects = 1, mayStore = 1 in
def VMSAVE32_ADDR16 : PseudoI<(outs), (ins), []>,
                              Requires<[Not64BitMode]>;
let Uses = [EAX], hasSideEffects = 1, mayStore = 1 in
def VMSAVE64_ADDR32 : PseudoI<(outs), (ins), []>,
                              Requires<[In64BitMode]>;
let Uses = [AX, ECX], hasSideEffects = 1 in
def INVLPGA32_ADDR16 : PseudoI<(outs), (ins), []>,
                              Requires<[Not64BitMode]>;
let Uses = [EAX, ECX], hasSideEffects = 1 in
def INVLPGA64_ADDR32 : PseudoI<(outs), (ins), []>,
                              Requires<[In64BitMode]>;
} // SchedRW
