//===- MicroMips64InstrInfo.td - microMIPS64 instructions --*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

multiclass WideShift<string mnemonic, bits<10> funct, SDPatternOperator op,
                     SDPatternOperator varop> {
  def _MM : MMRel, shift_rotate_imm<mnemonic, uimm6, GPR64Opnd, op, immZExt6>,
            SRA_FM_MM<funct, 0, 0x16>, ISA_MICROMIPS64_PRE_R6;
  def "32_MM" : MMRel, shift_rotate_imm<mnemonic # "32", uimm5, GPR64Opnd>,
              SRA_FM_MM<!or(funct, 0x08), 0, 0x16>, ISA_MICROMIPS64_PRE_R6;
  def V_MM : MMRel, shift_rotate_reg<mnemonic # "v", GPR64Opnd, varop>,
             SRLV_FM_MM<!or(funct, 0x10), 0, 0x16>, ISA_MICROMIPS64_PRE_R6;
}

// The register widths affect instruction selection, but all three views use
// the same physical conditional-move encoding as the word forms.
multiclass WideCondMove<string mnemonic, bits<10> funct> {
  let isCodeGenOnly = 1, DecoderNamespace = "MicroMips64" in {
    def _I_I64_MM : CMov_I_I_FT<mnemonic, GPR32Opnd, GPR64Opnd>,
                    ADD_FM_MM<0, funct>, ISA_MICROMIPS64_PRE_R6;
    def _I64_I_MM : CMov_I_I_FT<mnemonic, GPR64Opnd, GPR32Opnd>,
                    ADD_FM_MM<0, funct>, ISA_MICROMIPS64_PRE_R6;
    def _I64_I64_MM : CMov_I_I_FT<mnemonic, GPR64Opnd, GPR64Opnd>,
                      ADD_FM_MM<0, funct>, ISA_MICROMIPS64_PRE_R6;
  }
}
defm MOVN : WideCondMove<"movn", 0x18>;
defm MOVZ : WideCondMove<"movz", 0x58>;

let DecoderNamespace = "MicroMips64" in {
  def DADD_MM : MMRel, ArithLogicR<"dadd", GPR64Opnd, 1>,
                ADD_FM_MM<0x16, 0x110>, ISA_MICROMIPS64_PRE_R6;
  def DADDu_MM : MMRel, ArithLogicR<"daddu", GPR64Opnd, 1, add>,
                 ADD_FM_MM<0x16, 0x150>, ISA_MICROMIPS64_PRE_R6;
  def DSUB_MM : MMRel, ArithLogicR<"dsub", GPR64Opnd>,
                ADD_FM_MM<0x16, 0x190>, ISA_MICROMIPS64_PRE_R6;
  def DSUBu_MM : MMRel, ArithLogicR<"dsubu", GPR64Opnd, 0, sub>,
                 ADD_FM_MM<0x16, 0x1d0>, ISA_MICROMIPS64_PRE_R6;
  def DADDiu_MM : MMRel, ArithLogicI<"daddiu", simm16_64, GPR64Opnd,
                                     immSExt16, add>,
                  ADDI_FM_MM<0x17>, ISA_MICROMIPS64_PRE_R6, IsAsCheapAsAMove;

  // DADDI has a signed ten-bit immediate in POOL32S.
  def DADDi_MM : InstSE<(outs GPR64Opnd:$rt),
                        (ins GPR64Opnd:$rs, simm10_64:$imm10),
                        "daddi\t$rt, $rs, $imm10", [], FrmI, "daddi">,
                 MMArch, ISA_MICROMIPS64_PRE_R6 {
    bits<5> rt;
    bits<5> rs;
    bits<10> imm10;
    let Inst{31-26} = 0x16;
    let Inst{25-21} = rt;
    let Inst{20-16} = rs;
    let Inst{15-6} = imm10;
    let Inst{5-0} = 0x1c;
  }

  defm DSLL : WideShift<"dsll", 0x00, mshl_64, mshl_64>;
  defm DSRL : WideShift<"dsrl", 0x40, msrl_64, msrl_64>;
  defm DSRA : WideShift<"dsra", 0x80, msra_64, msra_64>;
  defm DROTR : WideShift<"drotr", 0xc0, rotr, rotr>;

  def DMULT_MM : MMRel, Mult<"dmult", GPR64Opnd, [HI0_64, LO0_64]>,
                 MULT_FM_MM<0x22c, 0x16>, ISA_MICROMIPS64_PRE_R6;
  def DMULTu_MM : MMRel, Mult<"dmultu", GPR64Opnd, [HI0_64, LO0_64]>,
                  MULT_FM_MM<0x26c, 0x16>, ISA_MICROMIPS64_PRE_R6;
  def DSDIV_MM : MMRel, Div<"ddiv", GPR64Opnd, [HI0_64, LO0_64]>,
                 MULT_FM_MM<0x2ac, 0x16>, ISA_MICROMIPS64_PRE_R6;
  def DUDIV_MM : MMRel, Div<"ddivu", GPR64Opnd, [HI0_64, LO0_64]>,
                 MULT_FM_MM<0x2ec, 0x16>, ISA_MICROMIPS64_PRE_R6;

  def DCLZ_MM : MMRel, CountLeading0<"dclz", GPR64Opnd>,
                CLO_FM_MM<0x16c, 0x16>, ISA_MICROMIPS64_PRE_R6;
  def DCLO_MM : MMRel, CountLeading1<"dclo", GPR64Opnd>,
                CLO_FM_MM<0x12c, 0x16>, ISA_MICROMIPS64_PRE_R6;
  def DSBH_MM : MMRel, SubwordSwap<"dsbh", GPR64Opnd>,
                SEB_FM_MM<0x1ec, 0x16>, ISA_MICROMIPS64_PRE_R6;
  def DSHD_MM : MMRel, SubwordSwap<"dshd", GPR64Opnd>,
                SEB_FM_MM<0x3ec, 0x16>, ISA_MICROMIPS64_PRE_R6;

  let DecoderMethod = "DecodeDEXT<true>" in {
    def DEXT_MM : MMRel, DEXTDesc, EXT_FM_MM<0x2c, 0x16>,
                  ISA_MICROMIPS64_PRE_R6;
    def DEXTM_MM : MMRel, DEXTMDesc, EXT_FM_MM<0x24, 0x16>,
                  ISA_MICROMIPS64_PRE_R6;
    def DEXTU_MM : MMRel, DEXTUDesc, EXT_FM_MM<0x14, 0x16>,
                  ISA_MICROMIPS64_PRE_R6;
  }
  let DecoderMethod = "DecodeDINS<true>" in {
    def DINS_MM : MMRel, DINSDesc, EXT_FM_MM<0x0c, 0x16>,
                  ISA_MICROMIPS64_PRE_R6;
    def DINSM_MM : MMRel, DINSMDesc, EXT_FM_MM<0x04, 0x16>,
                  ISA_MICROMIPS64_PRE_R6;
    def DINSU_MM : MMRel, DINSUDesc, EXT_FM_MM<0x34, 0x16>,
                  ISA_MICROMIPS64_PRE_R6;
  }

  let AdditionalPredicates = [IsNotSingleFloat] in {
    def DMFC1_MM : MMRel, MFC1_FT<"dmfc1", GPR64Opnd, FGR64Opnd, bitconvert>,
                   MFC1_FM_MM<0x90>, ISA_MICROMIPS64_PRE_R6, FGR_64;
    def DMTC1_MM : MMRel, MTC1_FT<"dmtc1", FGR64Opnd, GPR64Opnd, bitconvert>,
                   MFC1_FM_MM<0xb0>, ISA_MICROMIPS64_PRE_R6, FGR_64;
  }

  let mayRaiseFPException = 1 in {
    let Uses = [FCR31] in {
      def CVT_D64_L_MM : MMRel, ABSS_FT<"cvt.d.l", FGR64Opnd, FGR64Opnd>,
                         ABS_FM_MM<2, 0x4d>, ISA_MICROMIPS64_PRE_R6, FGR_64;
      def CVT_S_L_MM : MMRel, ABSS_FT<"cvt.s.l", FGR32Opnd, FGR64Opnd>,
                       ABS_FM_MM<2, 0x6d>, ISA_MICROMIPS64_PRE_R6, FGR_64;
    }
    def TRUNC_L_S_MM : MMRel, ABSS_FT<"trunc.l.s", FGR64Opnd, FGR32Opnd>,
                       ROUND_W_FM_MM<0, 0x8c>, ISA_MICROMIPS64_PRE_R6, FGR_64;
    def TRUNC_L_D64_MM : MMRel, ABSS_FT<"trunc.l.d", FGR64Opnd, FGR64Opnd>,
                         ROUND_W_FM_MM<1, 0x8c>, ISA_MICROMIPS64_PRE_R6, FGR_64;
  }

  def MOVT_D64_MM : CMov_F_F_FT<"movt.d", FGR64Opnd, MipsCMovFP_T>,
                    CMov_F_F_FM_MM<0x60, 1>, ISA_MICROMIPS64_PRE_R6, FGR_64;
  def MOVF_D64_MM : CMov_F_F_FT<"movf.d", FGR64Opnd, MipsCMovFP_F>,
                    CMov_F_F_FM_MM<0x20, 1>, ISA_MICROMIPS64_PRE_R6, FGR_64;
  def FCMP_D64_MM : CEQS_FT<"d", FGR64, MipsFPCmp>, CEQS_FM_MM<1>,
                    ISA_MICROMIPS64_PRE_R6, FGR_64 {
    let isCodeGenOnly = 1;
    bits<3> fcc = 0;
  }

  let DecoderMethod = "DecodeMemMMImm12<Mips::GPR64RegClassID>" in {
    def LWU64_MM : LoadWordUnsignedMM<GPR64Opnd>, ISA_MICROMIPS64_PRE_R6;
    def LDL_MM : LoadLeftRightMM<"ldl", MipsLDL, GPR64Opnd, mem_simm12>,
                 LWL_FM_MM<0x4>, ISA_MICROMIPS64_PRE_R6;
    def LDR_MM : LoadLeftRightMM<"ldr", MipsLDR, GPR64Opnd, mem_simm12>,
                 LWL_FM_MM<0x5>, ISA_MICROMIPS64_PRE_R6;
    def SDL_MM : StoreLeftRightMM<"sdl", MipsSDL, GPR64Opnd, mem_simm12>,
                 LWL_FM_MM<0xc>, ISA_MICROMIPS64_PRE_R6;
    def SDR_MM : StoreLeftRightMM<"sdr", MipsSDR, GPR64Opnd, mem_simm12>,
                 LWL_FM_MM<0xd>, ISA_MICROMIPS64_PRE_R6;
    def LLD_MM : LLBaseMM<"lld", GPR64Opnd, mem_simm12>, LL_FM_MM<0x7>,
                 ISA_MICROMIPS64_PRE_R6;
    def SCD_MM : SCBaseMM<"scd", GPR64Opnd, mem_simm12>, LL_FM_MM<0xf>,
                 ISA_MICROMIPS64_PRE_R6;
  }

  let DecoderMethod = "DecodeMemMMImm16<Mips::GPR64RegClassID>" in {
    def LD_MM : MMRel, LoadMemory<"ld", GPR64Opnd, mem_simmptr, load>,
                LW_FM_MM<0x37>, ISA_MICROMIPS64_PRE_R6;
    def SD_MM : MMRel, StoreMemory<"sd", GPR64Opnd, mem_simmptr, store>,
                LW_FM_MM<0x36>, ISA_MICROMIPS64_PRE_R6;
  }
}

def : MipsPat<(bswap GPR64:$rt), (DSHD_MM (DSBH_MM GPR64:$rt))>,
      ISA_MICROMIPS64_PRE_R6;

let InsnPredicates = [HasMips64r2, NotMips32r6],
    EncodingPredicates = [InMicroMips] in {
  defm : MovzPats0<GPR32, GPR64, MOVZ_I_I64_MM, SLT, SLTu, SLTi, SLTiu>;
  defm : MovzPats0<GPR64, GPR32, MOVZ_I_MM, SLT64, SLTu64, SLTi64, SLTiu64>;
  defm : MovzPats0<GPR64, GPR64, MOVZ_I_I64_MM, SLT64, SLTu64, SLTi64, SLTiu64>;
  defm : MovzPats1<GPR32, GPR64, MOVZ_I_I64_MM, XOR>;
  defm : MovzPats1<GPR64, GPR32, MOVZ_I64_I_MM, XOR64>;
  defm : MovzPats1<GPR64, GPR64, MOVZ_I64_I64_MM, XOR64>;
  defm : MovzPats2<GPR32, GPR64, MOVZ_I_I64_MM, XORi>;
  defm : MovzPats2<GPR64, GPR32, MOVZ_I64_I_MM, XORi64>;
  defm : MovzPats2<GPR64, GPR64, MOVZ_I64_I64_MM, XORi64>;
  defm : MovnPats<GPR32, GPR64, MOVN_I_I64_MM, XOR>;
  defm : MovnPats<GPR64, GPR32, MOVN_I64_I_MM, XOR64>;
  defm : MovnPats<GPR64, GPR64, MOVN_I64_I64_MM, XOR64>;
}

def : MipsInstAlias<"dins $rt, $rs, $pos, $size",
                    (DINSM_MM GPR64Opnd:$rt, GPR64Opnd:$rs, uimm5:$pos,
                              uimm_range_2_64:$size)>, ISA_MICROMIPS64_PRE_R6;
def : MipsInstAlias<"dins $rt, $rs, $pos, $size",
                    (DINSU_MM GPR64Opnd:$rt, GPR64Opnd:$rs, uimm5_plus32:$pos,
                              uimm5_plus1:$size)>, ISA_MICROMIPS64_PRE_R6;
def : MipsInstAlias<"dext $rt, $rs, $pos, $size",
                    (DEXTM_MM GPR64Opnd:$rt, GPR64Opnd:$rs, uimm5:$pos,
                              uimm5_plus33:$size)>, ISA_MICROMIPS64_PRE_R6;
def : MipsInstAlias<"dext $rt, $rs, $pos, $size",
                    (DEXTU_MM GPR64Opnd:$rt, GPR64Opnd:$rs, uimm5_plus32:$pos,
                              uimm5_plus1:$size)>, ISA_MICROMIPS64_PRE_R6;

def : MipsPat<(MipsTruncIntFP FGR32Opnd:$src), (TRUNC_L_S_MM FGR32Opnd:$src)>,
      ISA_MICROMIPS64_PRE_R6, FGR_64;
def : MipsPat<(MipsTruncIntFP FGR64Opnd:$src), (TRUNC_L_D64_MM FGR64Opnd:$src)>,
      ISA_MICROMIPS64_PRE_R6, FGR_64;
