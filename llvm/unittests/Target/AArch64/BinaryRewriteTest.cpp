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

TEST(AArch64BinaryRewriteTest, PageAndPageOffsetRetainTheirAddressSemantics) {
  LLVMInitializeAArch64TargetInfo();
  LLVMInitializeAArch64Target();
  LLVMInitializeAArch64TargetMC();
  LLVMInitializeAArch64AsmPrinter();
  for (const char *Name :
       {"aarch64-unknown-linux-gnu", "arm64-apple-macosx14.0.0",
        "aarch64-pc-windows-msvc"}) {
    SCOPED_TRACE(Name);
    for (uint64_t Base : {0x100174ull, 0x100ffcull}) {
      for (uint64_t TargetVA : {0x108badull, 0xff5a3ull}) {
        SCOPED_TRACE(Base);
        SCOPED_TRACE(TargetVA);
        LLVMContext Context;
        SMDiagnostic Diagnostic;
        auto Module =
            parseAssemblyString("@address = external dso_local global i8\n"
                                "define ptr @entry() { ret ptr @address }",
                                Diagnostic, Context);
        ASSERT_TRUE(Module);
        Triple TT(Name);
        std::string Error;
        const Target *Target = TargetRegistry::lookupTarget(TT, Error);
        ASSERT_NE(Target, nullptr) << Error;
        std::unique_ptr<TargetMachine> TM(Target->createTargetMachine(
            TT, "generic", "", TargetOptions(), Reloc::Static, std::nullopt,
            CodeGenOptLevel::None));
        ASSERT_TRUE(TM);
        Module->setTargetTriple(TT);
        Module->setDataLayout(TM->createDataLayout());
        mc_rewrite::RewriteOptions Options;
        mc_rewrite::RewriteResult Result;
        Options.Model.TextVA = Base;
        Options.Model.ImageBaseVA = 0x100000;
        Options.Model.getSectionVA = [=](StringRef Section) {
          return Section.contains("text") ? Base : 0x120000ull;
        };
        Options.Model.resolve = [=](StringRef Symbol,
                                    uint32_t) -> std::optional<uint64_t> {
          if (Symbol == "address" || Symbol == "_address")
            return TargetVA;
          return std::nullopt;
        };
        struct AddressFixup {
          std::string Section, Kind;
          uint64_t Offset, PC;
        };
        std::vector<AddressFixup> Fixups;
        Options.onFixup = [&](const mc_rewrite::FixupCtx &Fixup,
                              uint64_t Value) {
          if (Fixup.Sym == "address" || Fixup.Sym == "_address")
            Fixups.push_back({Fixup.SectionName.str(), Fixup.KindName.str(),
                              Fixup.SectionOffset, Fixup.FixupVA});
          return Value;
        };
        legacy::PassManager PM;
        ASSERT_FALSE(TM->addPassesToEmitBinaryRewrite(PM, Options, Result));
        PM.run(*Module);
        ASSERT_TRUE(Result.ImageValid);
        ASSERT_EQ(Fixups.size(), 2u);
        unsigned PageChecks = 0, OffsetChecks = 0;
        for (const auto &Fixup : Fixups)
          for (const auto &Section : Result.Sections) {
            if (Section.Name != Fixup.Section)
              continue;
            ASSERT_LE(Fixup.Offset + 4, Section.Bytes.size());
            const uint32_t Word =
                support::endian::read32le(Section.Bytes.data() + Fixup.Offset);
            if (StringRef(Fixup.Kind).contains("adrp")) {
              // Decode the signed ADRP page displacement from emitted bytes.
              EXPECT_EQ(Word & 0x9f000000u, 0x90000000u);
              const uint32_t Bits =
                  ((Word >> 29) & 3) | (((Word >> 5) & 0x7ffff) << 2);
              const int64_t Delta =
                  (int64_t(Bits ^ (1u << 20)) - (1u << 20)) * 4096;
              EXPECT_EQ((Fixup.PC & ~uint64_t(4095)) + Delta,
                        TargetVA & ~uint64_t(4095));
              ++PageChecks;
            } else if (StringRef(Fixup.Kind).contains("add_imm12")) {
              EXPECT_EQ(Word & 0xffc00000u, 0x91000000u);
              EXPECT_EQ((Word >> 10) & 0xfff, TargetVA & 0xfff);
              ++OffsetChecks;
            }
          }
        EXPECT_EQ(PageChecks, 1u);
        EXPECT_EQ(OffsetChecks, 1u);
      }
    }
  }
}

} // namespace
