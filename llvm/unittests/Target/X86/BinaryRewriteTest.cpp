//===- BinaryRewriteTest.cpp - Final-address relocation tests ------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/MC/BinaryRewrite.h"
#include "llvm/AsmParser/Parser.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Target/TargetMachine.h"
#include "gtest/gtest.h"

using namespace llvm;

namespace {

TEST(X86BinaryRewriteTest, PLTDisplacementsRetainBothPageOffsets) {
  LLVMInitializeX86TargetInfo();
  LLVMInitializeX86Target();
  LLVMInitializeX86TargetMC();
  LLVMInitializeX86AsmPrinter();
  for (uint64_t Base : {0x100173ull, 0x100ffbull}) {
    for (uint64_t TargetVA : {0x108badull, 0xff5a3ull}) {
      SCOPED_TRACE(Base);
      SCOPED_TRACE(TargetVA);
      LLVMContext Context;
      SMDiagnostic Diagnostic;
      auto Module = parseAssemblyString(
          "declare void @callee()\n"
          "define void @entry() { call void @callee() ret void }",
          Diagnostic, Context);
      ASSERT_TRUE(Module);
      Triple TT("x86_64-unknown-linux-gnu");
      std::string Error;
      const Target *Target = TargetRegistry::lookupTarget(TT, Error);
      ASSERT_NE(Target, nullptr) << Error;
      std::unique_ptr<TargetMachine> TM(Target->createTargetMachine(
          TT, "generic", "", TargetOptions(), Reloc::PIC_, std::nullopt,
          CodeGenOptLevel::None));
      ASSERT_TRUE(TM);
      Module->setTargetTriple(TT);
      Module->setDataLayout(TM->createDataLayout());
      mc_rewrite::RewriteOptions Options;
      mc_rewrite::RewriteResult Result;
      Options.Model.TextVA = Base;
      Options.Model.getSectionVA = [=](StringRef Section) {
        return Section.starts_with(".text") ? Base : 0x120000ull;
      };
      Options.Model.resolveWithContext =
          [=](const mc_rewrite::RewriteSymbolResolveRequest &Request)
          -> std::optional<uint64_t> {
        if (Request.Symbol != "callee")
          return std::nullopt;
        EXPECT_EQ(Request.SpecifierName, "PLT");
        return TargetVA;
      };
      struct CallFixup {
        std::string Section;
        uint64_t Offset, PC;
        int64_t Addend;
      };
      std::vector<CallFixup> Fixups;
      Options.onFixup = [&](const mc_rewrite::FixupCtx &Fixup, uint64_t Value) {
        if (Fixup.Sym == "callee") {
          EXPECT_TRUE(Fixup.IsPCRel);
          EXPECT_EQ(Fixup.BitWidth, 32u);
          Fixups.push_back({Fixup.SectionName.str(), Fixup.SectionOffset,
                            Fixup.FixupVA, Fixup.Addend});
        }
        return Value;
      };
      legacy::PassManager PM;
      ASSERT_FALSE(TM->addPassesToEmitBinaryRewrite(PM, Options, Result));
      PM.run(*Module);
      ASSERT_TRUE(Result.ImageValid);
      ASSERT_EQ(Fixups.size(), 1u);
      unsigned Checked = 0;
      for (const auto &Fixup : Fixups)
        for (const auto &Section : Result.Sections) {
          if (Section.Name != Fixup.Section)
            continue;
          ASSERT_LE(Fixup.Offset + 4, Section.Bytes.size());
          const int32_t Displacement =
              support::endian::read32le(Section.Bytes.data() + Fixup.Offset);
          EXPECT_EQ(Fixup.PC + 4 + Displacement, TargetVA + Fixup.Addend);
          ++Checked;
        }
      EXPECT_EQ(Checked, 1u);
    }
  }
}

} // namespace
