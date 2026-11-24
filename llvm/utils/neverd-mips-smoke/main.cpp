//===- main.cpp - Installed MIPS code generation smoke test ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/SmallString.h"
#include "llvm/AsmParser/Parser.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/MC/BinaryRewrite.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/MipsABIFlags.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/TargetParser/Triple.h"

#include <cctype>
#include <memory>
#include <string>

using namespace llvm;

static std::string emit(StringRef IR, StringRef TripleName, StringRef CPU,
                        CodeGenFileType Type = CodeGenFileType::AssemblyFile) {
  LLVMContext Context;
  SMDiagnostic Diagnostic;
  auto Module = parseAssemblyString(IR, Diagnostic, Context);
  if (!Module) {
    Diagnostic.print("neverd-mips-smoke", errs());
    return {};
  }
  std::string Error;
  const auto *Target = TargetRegistry::lookupTarget(Triple(TripleName), Error);
  if (!Target) {
    errs() << Error << '\n';
    return {};
  }
  TargetOptions Options;
  std::unique_ptr<TargetMachine> Machine(Target->createTargetMachine(
      Triple(TripleName), CPU, "", Options, Reloc::Static));
  if (!Machine)
    return {};
  Module->setTargetTriple(Triple(TripleName));
  Module->setDataLayout(Machine->createDataLayout());
  SmallString<4096> Output;
  raw_svector_ostream Stream(Output);
  legacy::PassManager Passes;
  if (Machine->addPassesToEmitFile(Passes, Stream, nullptr, Type))
    return {};
  Passes.run(*Module);
  if (Type == CodeGenFileType::ObjectFile)
    return Output.str().str();
  std::string Compact;
  for (unsigned char C : Output)
    if (!std::isspace(C))
      Compact.push_back(C);
  return Compact;
}

static bool compressed(bool Little, bool FP64) {
  std::string IR = R"(
    define double @roundtrip(double %value) #0 { ret double %value }
    define i64 @convert(double %value) #0 {
      %result = fptosi double %value to i64
      ret i64 %result
    }
    attributes #0 = { "mips16" "target-cpu"="mips32r2" "target-features"=")";
  IR += FP64 ? "+fp64" : "-fp64";
  IR += "\" }\n";
  const std::string Assembly =
      emit(IR, Little ? "mipsel-linux-gnu" : "mips-linux-gnu", "mips32");
  const StringRef Text(Assembly);
  const StringRef Low = Little ? "$4" : "$5";
  const StringRef High = Little ? "$5" : "$4";
  const std::string ReadLow = "mfc1" + Low.str() + ",$f12";
  const std::string ReadHigh =
      (FP64 ? "mfhc1" : "mfc1") + High.str() + (FP64 ? ",$f12" : ",$f13");
  const std::string WriteLow = "mtc1" + Low.str() + ",$f12";
  const std::string WriteHigh =
      (FP64 ? "mthc1" : "mtc1") + High.str() + (FP64 ? ",$f12" : ",$f13");
  return Text.contains("__fn_stub_roundtrip:") &&
         Text.contains("jal__mips16_ret_df") &&
         Text.contains(ReadLow + ReadHigh) &&
         Text.contains("__call_stub_fp___fixdfdi:") &&
         Text.contains(WriteLow + WriteHigh);
}

static bool objectModes(bool Little, bool N32) {
  const StringRef IR = N32 ? "define i64 @plain(i64 %x) { ret i64 %x }" : R"(
          @also_compact = hidden alias i32 (), ptr @compact
          @table = global [2 x ptr] [ptr @compact, ptr @plain]
          define hidden i32 @compact() "mips16" { ret i32 17 }
          define i32 @plain() "nomips16" { ret i32 23 }
        )";
  StringRef TT =
      N32 ? (Little ? "mips64el-linux-gnuabin32" : "mips64-linux-gnuabin32")
          : (Little ? "mipsel-linux-gnu" : "mips-linux-gnu");
  std::string Bytes =
      emit(IR, TT, N32 ? "mips64r2" : "mips32r2", CodeGenFileType::ObjectFile);
  auto Object =
      object::ObjectFile::createObjectFile(MemoryBufferRef(Bytes, TT));
  if (!Object) {
    logAllUnhandledErrors(Object.takeError(), errs());
    return false;
  }
  auto *ELF = dyn_cast<object::ELFObjectFileBase>(Object->get());
  if (!ELF || ELF->getEMachine() != ELF::EM_MIPS ||
      ELF->getBytesInAddress() != 4 || ELF->isLittleEndian() != Little ||
      bool(ELF->getPlatformFlags() & ELF::EF_MIPS_ABI2) != N32 ||
      bool(ELF->getPlatformFlags() & ELF::EF_MIPS_ARCH_ASE_M16) != !N32)
    return false;

  bool SawABI = false, SawPlain = false, SawCompact = false, SawAlias = false;
  bool SawCode = false;
  for (const auto &Section : ELF->sections()) {
    bool IsABI =
        object::ELFSectionRef(Section).getType() == ELF::SHT_MIPS_ABIFLAGS;
    if (!IsABI && !Section.isText())
      continue;
    auto Data = Section.getContents();
    if (!Data) {
      logAllUnhandledErrors(Data.takeError(), errs());
      return false;
    }
    if (!IsABI) {
      if (N32)
        SawCode |= !Data->empty();
      else
        SawCode |= Data->starts_with(
            Little ? StringRef("\x00\xf0\x11\x6a\xe0\xe8", 6)
                   : StringRef("\xf0\x00\x6a\x11\xe8\xe0", 6));
      continue;
    }
    if (Data->size() != 24 || (*Data)[2] != (N32 ? 64 : 32))
      return false;
    const uint32_t ASE = Little ? support::endian::read32le(Data->data() + 12)
                                : support::endian::read32be(Data->data() + 12);
    SawABI = bool(ASE & Mips::AFL_ASE_MIPS16) == !N32;
  }
  for (const auto &Sym : ELF->symbols()) {
    auto Name = Sym.getName();
    if (!Name) {
      logAllUnhandledErrors(Name.takeError(), errs());
      return false;
    }
    if (*Name == "compact" || *Name == "also_compact") {
      if (Sym.getOther() != (ELF::STO_MIPS_MIPS16 | ELF::STV_HIDDEN))
        return false;
      if (*Name == "compact")
        SawCompact = true;
      else
        SawAlias = true;
    } else if (*Name == "plain")
      SawPlain = Sym.getOther() == 0;
  }
  return SawCode && SawABI && SawPlain && (N32 || (SawCompact && SawAlias));
}

static bool fixedAddressLeaf(StringRef TargetName, bool Wide, bool Little,
                             bool N32) {
  LLVMContext Context;
  SMDiagnostic Diagnostic;
  auto Module = parseAssemblyString(R"(
    @entry = global ptr @leaf
    define i32 @leaf() uwtable { ret i32 37 }
  )",
                                    Diagnostic, Context);
  if (!Module)
    return false;
  Triple TT(TargetName);
  std::string Err;
  const auto *Target = TargetRegistry::lookupTarget(TT, Err);
  if (!Target)
    return false;
  std::unique_ptr<TargetMachine> TM(Target->createTargetMachine(
      TT, Wide ? "mips64r2" : "mips32r2", "", TargetOptions(), Reloc::Static));
  if (!TM)
    return false;
  Module->setTargetTriple(TT);
  Module->setDataLayout(TM->createDataLayout());
  legacy::PassManager PM;
  mc_rewrite::RewriteOptions Options;
  Options.Model.TextVA = 0x10000;
  Options.Model.getSectionVA = [](StringRef Name) -> uint64_t {
    if (Name == ".text")
      return 0x10000;
    if (Name == ".data")
      return 0x20000;
    return 0x30000;
  };
  mc_rewrite::RewriteResult Result;
  if (TM->addPassesToEmitBinaryRewrite(PM, Options, Result))
    return false;
  PM.run(*Module);
  if (!Result.ImageValid || !Result.FunctionRangesValid ||
      !Result.Unresolved.empty() || Result.FunctionRanges.size() != 1 ||
      Result.SymbolAddrs["leaf"] != 0x10000 ||
      Result.SymbolAddrs["entry"] != 0x20000)
    return false;
  const auto &Range = Result.FunctionRanges.front();
  if (Range.OwnerSymbol != "leaf" || Range.BeginVA != 0x10000 ||
      Range.EndVA != 0x10008)
    return false;
  const auto Order = Little ? endianness::little : endianness::big;
  bool SawText = false, SawPointer = false;
  for (const auto &Sec : Result.Sections) {
    if (Sec.Name == ".text" && Sec.Bytes.size() >= 8)
      SawText =
          support::endian::read32(Sec.Bytes.data(), Order) == 0x03e00008 &&
          support::endian::read32(Sec.Bytes.data() + 4, Order) == 0x24020025;
    const unsigned Width = Wide && !N32 ? 8 : 4;
    if (Sec.Name == ".data" && Sec.Bytes.size() >= Width)
      SawPointer =
          (Width == 8
               ? support::endian::read64(Sec.Bytes.data(), Order)
               : support::endian::read32(Sec.Bytes.data(), Order)) == 0x10000;
  }
  return SawText && SawPointer;
}

int main() {
  LLVMInitializeMipsTargetInfo();
  LLVMInitializeMipsTarget();
  LLVMInitializeMipsTargetMC();
  LLVMInitializeMipsAsmParser();
  LLVMInitializeMipsAsmPrinter();
  for (bool Little : {false, true}) {
    for (StringRef TT :
         {Little ? "mipsel-linux-gnu" : "mips-linux-gnu",
          Little ? "mips64el-linux-gnuabin32" : "mips64-linux-gnuabin32",
          Little ? "mips64el-linux-gnuabi64" : "mips64-linux-gnuabi64"}) {
      if (!fixedAddressLeaf(TT, Triple(TT).isMIPS64(), Little,
                            Triple(TT).isABIN32())) {
        errs() << "MIPS fixed-address code generation failure: " << TT << '\n';
        return 1;
      }
    }
    for (bool N32 : {false, true})
      if (!objectModes(Little, N32)) {
        errs() << "MIPS ELF object identity failure: little=" << Little
               << ", n32=" << N32 << '\n';
        return 1;
      }
    for (bool FP64 : {false, true}) {
      if (!compressed(Little, FP64)) {
        errs() << "MIPS16 hard-float package failure: little=" << Little
               << ", fp64=" << FP64 << '\n';
        return 1;
      }
    }
    for (bool Wide : {false, true}) {
      const StringRef TripleName =
          Wide ? (Little ? "mips64el-linux-gnuabi64" : "mips64-linux-gnuabi64")
               : (Little ? "mipsel-linux-gnu" : "mips-linux-gnu");
      const StringRef IR = Wide ? "define i64 @increment(i64 %x) { %r = add "
                                  "i64 %x, 1 ret i64 %r }"
                                : "define i32 @increment(i32 %x) { %r = add "
                                  "i32 %x, 1 ret i32 %r }";
      const std::string Assembly =
          emit(IR, TripleName, Wide ? "mips64r2" : "mips32r2");
      if (!StringRef(Assembly).contains(Wide ? "daddiu" : "addiu")) {
        errs() << "Classic MIPS package failure: " << TripleName << '\n';
        return 1;
      }
    }
  }
  outs() << "MIPS32/64 BE/LE, n32 ELF, MIPS16 ELF mode and FR=0/1 code "
            "generation passed\n";
  return 0;
}
