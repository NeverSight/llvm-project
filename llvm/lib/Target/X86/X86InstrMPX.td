//===-- X86InstrMPX.td - MPX Instruction Set ---------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the X86 MPX instruction set, defining the
// instructions, and properties of the instructions which are needed for code
// generation, machine code emission, and analysis.
//
//===----------------------------------------------------------------------===//

// Restored from LLVM before c2d4fe51bb4f (2021-10-12). MPX operations own
// an ambient bounds bank; even a discarded result can check bounds or fault.
let SchedRW = [WriteSystem], hasSideEffects = 1, OpMap = TB in {

multiclass mpx_bound_make<bits<8> opc, string OpcodeStr> {
  def 32rm: I<opc, MRMSrcMem, (outs BNDR:$dst), (ins anymem:$src),
              OpcodeStr#"\t{$src, $dst|$dst, $src}", []>,
              Requires<[Not64BitMode]>;
  def 64rm: I<opc, MRMSrcMem, (outs BNDR:$dst), (ins anymem:$src),
              OpcodeStr#"\t{$src, $dst|$dst, $src}", []>,
              Requires<[In64BitMode]>;
}

defm BNDMK : mpx_bound_make<0x1B, "bndmk">, XS;

multiclass mpx_bound_check<bits<8> opc, string OpcodeStr> {
  def 32rm: I<opc, MRMSrcMem, (outs), (ins  BNDR:$src1, anymem:$src2),
              OpcodeStr#"\t{$src2, $src1|$src1, $src2}", []>,
              Requires<[Not64BitMode]>;
  def 64rm: I<opc, MRMSrcMem, (outs), (ins  BNDR:$src1, anymem:$src2),
              OpcodeStr#"\t{$src2, $src1|$src1, $src2}", []>,
              Requires<[In64BitMode]>;

  def 32rr: I<opc, MRMSrcReg, (outs), (ins  BNDR:$src1, GR32:$src2),
              OpcodeStr#"\t{$src2, $src1|$src1, $src2}", []>,
              Requires<[Not64BitMode]>;
  def 64rr: I<opc, MRMSrcReg, (outs), (ins  BNDR:$src1, GR64:$src2),
              OpcodeStr#"\t{$src2, $src1|$src1, $src2}", []>,
              Requires<[In64BitMode]>;
}
defm BNDCL : mpx_bound_check<0x1A, "bndcl">, XS;
defm BNDCU : mpx_bound_check<0x1A, "bndcu">, XD;
defm BNDCN : mpx_bound_check<0x1B, "bndcn">, XD;

def BNDMOVrr   : I<0x1A, MRMSrcReg, (outs BNDR:$dst), (ins BNDR:$src),
                  "bndmov\t{$src, $dst|$dst, $src}", []>, PD;
let mayLoad = 1 in {
def BNDMOV32rm : I<0x1A, MRMSrcMem, (outs BNDR:$dst), (ins i64mem:$src),
                  "bndmov\t{$src, $dst|$dst, $src}", []>, PD,
                  Requires<[Not64BitMode]>;
def BNDMOV64rm : I<0x1A, MRMSrcMem, (outs BNDR:$dst), (ins i128mem:$src),
                  "bndmov\t{$src, $dst|$dst, $src}", []>, PD,
                  Requires<[In64BitMode]>;
}
let isCodeGenOnly = 1, ForceDisassemble = 1 in
def BNDMOVrr_REV   : I<0x1B, MRMDestReg, (outs BNDR:$dst), (ins BNDR:$src),
                       "bndmov\t{$src, $dst|$dst, $src}", []>, PD;
let mayStore = 1 in {
def BNDMOV32mr : I<0x1B, MRMDestMem, (outs), (ins i64mem:$dst, BNDR:$src),
                  "bndmov\t{$src, $dst|$dst, $src}", []>, PD,
                  Requires<[Not64BitMode]>;
def BNDMOV64mr : I<0x1B, MRMDestMem, (outs), (ins i128mem:$dst, BNDR:$src),
                  "bndmov\t{$src, $dst|$dst, $src}", []>, PD,
                  Requires<[In64BitMode]>;

def BNDSTXmr:      I<0x1B, MRMDestMem, (outs), (ins anymem:$dst, BNDR:$src),
                    "bndstx\t{$src, $dst|$dst, $src}", []>, PS;
}
let mayLoad = 1 in
def BNDLDXrm:      I<0x1A, MRMSrcMem, (outs BNDR:$dst), (ins anymem:$src),
                    "bndldx\t{$src, $dst|$dst, $src}", []>, PS;
} // SchedRW

// The instruction selector transports GPR inputs only. MC lowering chooses
// fixed BND registers after allocation; the complete bank remains reserved.
// These pseudos retain unknown memory effects and every ambient dependency.
let SchedRW = [WriteSystem], hasSideEffects = 1, mayLoad = 1, mayStore = 1,
    Uses = [BND0, BND1, BND2, BND3], Defs = [BND0, BND1, BND2, BND3] in {
  def MPX_STATE32 : PseudoI<(outs),
      (ins i32imm:$descriptor, GR32:$base, GR32:$index), []>;
  def MPX_STATE64 : PseudoI<(outs),
      (ins i32imm:$descriptor, GR64:$base, GR64:$index), []>;
  def MPX_MOVE_BOUNDS : PseudoI<(outs), (ins i32imm:$descriptor), []>;
  def MPX_BRANCH : PseudoI<(outs), (ins i32imm:$kind), []>;
}
