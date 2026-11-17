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
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/TargetParser/Triple.h"

#include <cctype>
#include <memory>
#include <string>

using namespace llvm;

static std::string emit(StringRef IR, StringRef TripleName, StringRef CPU) {
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
  SmallString<4096> Assembly;
  raw_svector_ostream Stream(Assembly);
  legacy::PassManager Passes;
  if (Machine->addPassesToEmitFile(Passes, Stream, nullptr,
                                   CodeGenFileType::AssemblyFile))
    return {};
  Passes.run(*Module);
  std::string Compact;
  for (unsigned char C : Assembly)
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

int main() {
  LLVMInitializeMipsTargetInfo();
  LLVMInitializeMipsTarget();
  LLVMInitializeMipsTargetMC();
  LLVMInitializeMipsAsmParser();
  LLVMInitializeMipsAsmPrinter();
  for (bool Little : {false, true}) {
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
  outs() << "MIPS32/64 BE/LE and MIPS16 FR=0/1 code generation passed\n";
  return 0;
}
