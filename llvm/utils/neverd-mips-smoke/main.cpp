//===- main.cpp - Installed MIPS code generation smoke test ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/AsmParser/Parser.h"
#include "llvm/IR/DiagnosticInfo.h"
#include "llvm/IR/DiagnosticPrinter.h"
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
  const Triple TT(Triple::normalize(TripleName));
  const auto *Target = TargetRegistry::lookupTarget(TT, Error);
  if (!Target) {
    errs() << Error << '\n';
    return {};
  }
  TargetOptions Options;
  std::unique_ptr<TargetMachine> Machine(
      Target->createTargetMachine(TT, CPU, "", Options, Reloc::Static));
  if (!Machine)
    return {};
  Module->setTargetTriple(TT);
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
            Little ? StringRef("\x00\xf0\x11\x6a\xa0\xe8", 6)
                   : StringRef("\xf0\x00\x6a\x11\xe8\xa0", 6));
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

static bool fixedAddressLeaf(const Triple &TT, StringRef CPU,
                             StringRef Mode = {}) {
  LLVMContext Context;
  SMDiagnostic Diagnostic;
  auto Module = parseAssemblyString(R"(
    @entry = global [2 x ptr] [ptr @leaf, ptr getelementptr (i8, ptr @leaf, i32 1)]
    define i32 @leaf() uwtable { ret i32 37 }
  )",
                                    Diagnostic, Context);
  if (!Module)
    return false;
  if (!Mode.empty())
    Module->getFunction("leaf")->addFnAttr(Mode);
  const bool Wide = TT.isMIPS64(), Little = TT.isLittleEndian(),
             N32 = TT.isABIN32();
  std::string Err;
  const auto *Target = TargetRegistry::lookupTarget(TT, Err);
  if (!Target)
    return false;
  std::unique_ptr<TargetMachine> TM(
      Target->createTargetMachine(TT, CPU, "", TargetOptions(), Reloc::Static));
  if (!TM)
    return false;
  Module->setTargetTriple(TT);
  Module->setDataLayout(TM->createDataLayout());
  legacy::PassManager PM;
  mc_rewrite::RewriteOptions Options;
  const uint64_t Base = Wide && !N32 ? 0x1200000000ULL : 0;
  Options.Model.TextVA = Base + 0x10000;
  Options.Model.getSectionVA = [Base](StringRef Name) -> uint64_t {
    if (Name == ".text")
      return Base + 0x10000;
    if (Name == ".data")
      return Base + 0x20000;
    return Base + 0x30000;
  };
  mc_rewrite::RewriteResult Result;
  if (TM->addPassesToEmitBinaryRewrite(PM, Options, Result))
    return false;
  PM.run(*Module);
  if (!Result.ImageValid || !Result.FunctionRangesValid ||
      !Result.Unresolved.empty() || Result.FunctionRanges.size() != 1 ||
      Result.SymbolAddrs["leaf"] != Base + 0x10000 ||
      Result.SymbolAddrs["entry"] != Base + 0x20000) {
    errs() << TT.str() << " " << CPU << " " << Mode
           << ": image=" << Result.ImageValid
           << ", ranges=" << Result.FunctionRangesValid << "/"
           << Result.FunctionRanges.size()
           << ", unresolved=" << Result.Unresolved.size()
           << ", leaf=" << utohexstr(Result.SymbolAddrs["leaf"])
           << ", entry=" << utohexstr(Result.SymbolAddrs["entry"]) << '\n';
    return false;
  }
  const unsigned BodySize = Mode == "mips16" ? 6 : Mode == "micromips" ? 4 : 8;
  const auto &Range = Result.FunctionRanges.front();
  if (Range.OwnerSymbol != "leaf" || Range.BeginVA != Base + 0x10000 ||
      Range.EndVA != Base + 0x10000 + BodySize) {
    errs() << TT.str() << " " << CPU << " " << Mode << ": range "
           << Range.OwnerSymbol << " [" << utohexstr(Range.BeginVA) << ","
           << utohexstr(Range.EndVA) << ")\n";
    return false;
  }
  const auto Order = Little ? endianness::little : endianness::big;
  bool SawText = false, SawPointer = false;
  for (const auto &Sec : Result.Sections) {
    if (Sec.Name == ".text" && Sec.Bytes.size() >= BodySize) {
      const uint8_t *Text = Sec.Bytes.data();
      if (Mode == "mips16")
        SawText = support::endian::read16(Text, Order) == 0xf020 &&
                  support::endian::read16(Text + 2, Order) == 0x6a05 &&
                  support::endian::read16(Text + 4, Order) == 0xe8a0;
      else if (Mode == "micromips")
        SawText = support::endian::read16(Text, Order) == 0xed25 &&
                  support::endian::read16(Text + 2, Order) == 0x45bf;
      else
        SawText = support::endian::read32(Text, Order) == 0x03e00008 &&
                  support::endian::read32(Text + 4, Order) == 0x24020025;
    }
    const unsigned Width = Wide && !N32 ? 8 : 4;
    if (Sec.Name == ".data" && Sec.Bytes.size() >= 2 * Width) {
      const auto Read = [&](unsigned Offset) {
        const uint8_t *Word = Sec.Bytes.data() + Offset;
        return Width == 8 ? support::endian::read64(Word, Order)
                          : support::endian::read32(Word, Order);
      };
      const uint64_t Entry = Base + 0x10000 + !Mode.empty();
      SawPointer = Read(0) == Entry && Read(Width) == Entry + 1;
    }
  }
  if (!SawText || !SawPointer) {
    errs() << TT.str() << " " << CPU << " " << Mode << ": ";
    for (const auto &Section : Result.Sections)
      if (Section.Name == ".text" || Section.Name == ".data")
        errs() << Section.Name << "=" << toHex(Section.Bytes) << " ";
    errs() << '\n';
  }
  return SawText && SawPointer;
}

static bool fixedAddressCall(bool Little, StringRef Mode, uint64_t TextVA,
                             uint64_t TargetVA,
                             std::optional<uint32_t> Expected,
                             bool PIC = false) {
  LLVMContext Context;
  std::string Errors;
  Context.setDiagnosticHandlerCallBack(
      [](const DiagnosticInfo *Info, void *State) {
        if (Info->getSeverity() == DS_Error) {
          raw_string_ostream Stream(*static_cast<std::string *>(State));
          DiagnosticPrinterRawOStream Printer(Stream);
          Info->print(Printer);
        }
      },
      &Errors);
  SMDiagnostic Diag;
  auto M = parseAssemblyString(R"(
    declare i32 @callee(i32)
    define i32 @caller(i32 %x) {
      %r = notail call i32 @callee(i32 %x)
      %s = add i32 %r, 1
      ret i32 %s
    }
  )",
                               Diag, Context);
  if (!M)
    return false;
  if (!Mode.empty())
    M->getFunction("caller")->addFnAttr(Mode);
  Triple TT(Little ? "mipsel-unknown-linux-gnu" : "mips-unknown-linux-gnu");
  std::string Err;
  auto *Target = TargetRegistry::lookupTarget(TT, Err);
  if (!Target)
    return false;
  std::unique_ptr<TargetMachine> TM(Target->createTargetMachine(
      TT, "mips32r2", PIC ? "+soft-float" : "+soft-float,+noabicalls",
      TargetOptions(), PIC ? Reloc::PIC_ : Reloc::Static));
  if (!TM)
    return false;
  M->setTargetTriple(TT);
  M->setDataLayout(TM->createDataLayout());
  mc_rewrite::RewriteOptions Options;
  Options.Model.TextVA = TextVA;
  Options.Model.getSectionVA = [TextVA](StringRef Name) -> uint64_t {
    return Name == ".text" ? TextVA : 0x20000;
  };
  std::optional<uint64_t> CallOffset;
  Options.Model.resolveWithContext =
      [&](const mc_rewrite::RewriteSymbolResolveRequest &Request)
      -> std::optional<uint64_t> {
    if (Request.Symbol != "callee")
      return std::nullopt;
    CallOffset = Request.SectionOffset;
    return TargetVA;
  };
  legacy::PassManager PM;
  mc_rewrite::RewriteResult R;
  if (TM->addPassesToEmitBinaryRewrite(PM, Options, R))
    return false;
  PM.run(*M);
  if (CallOffset && !Expected && !R.ImageValid &&
      StringRef(Errors).contains(PIC ? "requires an ELF linker"
                                     : "outside the PC region"))
    return true;
  if (CallOffset && Expected && R.ImageValid && R.Unresolved.empty() &&
      Errors.empty()) {
    auto Order = Little ? endianness::little : endianness::big;
    for (const auto &Sec : R.Sections) {
      if (Sec.Name != ".text" || *CallOffset + 4 > Sec.Bytes.size())
        continue;
      const uint8_t *At = Sec.Bytes.data() + *CallOffset;
      uint32_t Word =
          Mode.empty() ? support::endian::read32(At, Order)
                       : (uint32_t(support::endian::read16(At, Order)) << 16) |
                             support::endian::read16(At + 2, Order);
      if (Word == *Expected)
        return true;
      errs() << "encoded " << utohexstr(Word) << " expected "
             << utohexstr(*Expected) << "; ";
    }
  }
  errs() << TT.str() << " " << Mode << " fixed call at 0x" << utohexstr(TextVA)
         << " to 0x" << utohexstr(TargetVA) << ": " << Errors << '\n';
  return false;
}

int main() {
  LLVMInitializeMipsTargetInfo();
  LLVMInitializeMipsTarget();
  LLVMInitializeMipsTargetMC();
  LLVMInitializeMipsAsmParser();
  LLVMInitializeMipsAsmPrinter();
  for (bool Little : {false, true}) {
    if (!fixedAddressCall(Little, "", 0x10000, 0x180000, std::nullopt, true) ||
        !fixedAddressCall(Little, "", 0x10000, 0x180000, 0x0c060000) ||
        !fixedAddressCall(Little, "", 0x10000, 0x180001, 0x74060000) ||
        !fixedAddressCall(Little, "", 0x10000, 0x10018000, std::nullopt) ||
        !fixedAddressCall(Little, "", 0x10000, 0x180002, std::nullopt) ||
        !fixedAddressCall(Little, "", 0x0ffffff4, 0x10018000, 0x0c006000) ||
        !fixedAddressCall(Little, "mips16", 0x10000, 0x180001, 0x18c00000) ||
        !fixedAddressCall(Little, "mips16", 0x10000, 0x180000, 0x1cc00000) ||
        !fixedAddressCall(Little, "mips16", 0x10000, 0x10018001,
                          std::nullopt) ||
        !fixedAddressCall(Little, "micromips", 0x10000, 0x180003, 0xf40c0001) ||
        !fixedAddressCall(Little, "micromips", 0x10000, 0x180000, 0xf0060000) ||
        !fixedAddressCall(Little, "micromips", 0x10000, 0x08018001,
                          std::nullopt))
      return 1;
    for (StringRef TT :
         {Little ? "mipsel-linux-gnu" : "mips-linux-gnu",
          Little ? "mips64el-linux-gnuabin32" : "mips64-linux-gnuabin32",
          Little ? "mips64el-linux-gnuabi64" : "mips64-linux-gnuabi64"}) {
      Triple Target(Triple::normalize(TT));
      if (!fixedAddressLeaf(Target,
                            Target.isMIPS64() ? "mips64r2" : "mips32r2") ||
          (Target.isMIPS64() && !fixedAddressLeaf(Target, "mips5")) ||
          (!Target.isMIPS64() &&
           (!fixedAddressLeaf(Target, "mips32r2", "mips16") ||
            !fixedAddressLeaf(Target, "mips32r2", "micromips")))) {
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
  outs() << "MIPS ELF object and final-address checks passed for both byte "
            "orders\n";
  return 0;
}
