//===---- X86InstrRAOINT.td -------------------------------*- tablegen -*--===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the instructions that make up the Intel RAO-INT
// instruction set.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// RAO-INT instructions

def SDTRAOBinaryArith : SDTypeProfile<0, 2, [SDTCisPtrTy<0>, SDTCisInt<1>]>;

// Native APX atomics retain EVEX and address-size controls until MC lowering.
// These are indivisible memory effects; CMPccXADD always writes back, including
// when its condition is false. RAO-INT preserves EFLAGS.
let SchedRW = [WriteXCHG], hasSideEffects = 1, mayLoad = 1, mayStore = 1 in {
  def APX_RAO_NATIVE32 : PseudoI<(outs),
      (ins i32imm:$descriptor, i32mem:$address, GR32:$source), []>;
  let Defs = [EFLAGS], Constraints = "$compare = $dst" in
    def APX_CMPCCXADD_NATIVE32 : PseudoI<(outs GR32:$dst),
        (ins GR32:$compare, i32mem:$address, GR32:$add,
             i32imm:$descriptor), []>;
  def APX_RAO_NATIVE64 : PseudoI<(outs),
      (ins i32imm:$descriptor, i64mem:$address, GR64:$source), []>;
  let Defs = [EFLAGS], Constraints = "$compare = $dst" in
    def APX_CMPCCXADD_NATIVE64 : PseudoI<(outs GR64:$dst),
        (ins GR64:$compare, i64mem:$address, GR64:$add,
             i32imm:$descriptor), []>;
}

// The native legacy encodings cannot name EGPRs. Constrain every data operand
// before allocation; changing MC encoding alone could produce REX2/EVEX bytes.
let SchedRW = [WriteXCHG], hasSideEffects = 1, mayLoad = 1, mayStore = 1 in {
  def LEGACY_RAO_NATIVE32 : PseudoI<(outs),
      (ins i32imm:$descriptor, i32mem:$address, GR32_NOREX2:$source), []>;
  def LEGACY_RAO_NATIVE64 : PseudoI<(outs),
      (ins i32imm:$descriptor, i64mem:$address, GR64_NOREX2:$source), []>;
  let Defs = [EFLAGS], Constraints = "$compare = $dst" in {
    def LEGACY_CMPCCXADD_NATIVE32 : PseudoI<(outs GR32_NOREX2:$dst),
        (ins GR32_NOREX2:$compare, i32mem:$address, GR32_NOREX2:$add,
             i32imm:$descriptor), []>;
    def LEGACY_CMPCCXADD_NATIVE64 : PseudoI<(outs GR64_NOREX2:$dst),
        (ins GR64_NOREX2:$compare, i64mem:$address, GR64_NOREX2:$add,
             i32imm:$descriptor), []>;
  }
}


// RAO arithmetic instructions.
// OUTCHAIN = AADD(INCHAIN, PTR, RHS)
def X86rao_add  : SDNode<"X86ISD::AADD", SDTRAOBinaryArith,
                         [SDNPHasChain, SDNPMayStore, SDNPMemOperand]>;
def X86rao_or   : SDNode<"X86ISD::AOR",  SDTRAOBinaryArith,
                         [SDNPHasChain, SDNPMayStore, SDNPMemOperand]>;
def X86rao_xor  : SDNode<"X86ISD::AXOR", SDTRAOBinaryArith,
                         [SDNPHasChain, SDNPMayStore, SDNPMemOperand]>;
def X86rao_and  : SDNode<"X86ISD::AAND", SDTRAOBinaryArith,
                         [SDNPHasChain, SDNPMayStore, SDNPMemOperand]>;

multiclass RaoInt<string m, string suffix = ""> {
  let Pattern = [(!cast<SDNode>("X86rao_" # m) addr:$src1, GR32:$src2)] in
    def 32mr#suffix : BinOpMR_M<0xfc, "a" # m, Xi32>;
  let Pattern = [(!cast<SDNode>("X86rao_" # m) addr:$src1, GR64:$src2)] in
    def 64mr#suffix : BinOpMR_M<0xfc, "a" # m, Xi64>;
}

let Predicates = [HasRAOINT, NoEGPR] in {
  defm AADD : RaoInt<"add">, T8;
  defm AAND : RaoInt<"and">, T8, PD;
  defm AOR  : RaoInt<"or" >, T8, XD;
  defm AXOR : RaoInt<"xor">, T8, XS;
}

let Predicates = [HasRAOINT, HasEGPR, In64BitMode] in {
  defm AADD : RaoInt<"add", "_EVEX">, EVEX, T_MAP4;
  defm AAND : RaoInt<"and", "_EVEX">, EVEX, T_MAP4, PD;
  defm AOR  : RaoInt<"or",  "_EVEX">, EVEX, T_MAP4, XD;
  defm AXOR : RaoInt<"xor", "_EVEX">, EVEX, T_MAP4, XS;
}
