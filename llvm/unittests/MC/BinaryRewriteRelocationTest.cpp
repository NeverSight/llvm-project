//===- BinaryRewriteRelocationTest.cpp - Final-address MC fixups ---------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/MC/BinaryRewrite.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCObjectFileInfo.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCParser/MCAsmParser.h"
#include "llvm/MC/MCParser/MCTargetAsmParser.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/TargetSelect.h"
#include "gtest/gtest.h"
#include <memory>
#include <optional>

using namespace llvm;

namespace {

#define REWRITE_TEST_STRING(Name, Value) constexpr StringLiteral Name = Value;
#define REWRITE_TEST_INTEGER(Name, Value) constexpr uint64_t Name = Value;
#include "BinaryRewriteRelocationFixtures.def"

bool hasTarget(StringRef TripleName) {
  InitializeAllTargetInfos();
  std::string Error;
  return TargetRegistry::lookupTarget(Triple(TripleName), Error);
}

std::optional<mc_rewrite::RewriteResult>
assemble(StringRef TripleName, StringRef Assembly,
         const mc_rewrite::RewriteOptions &Options) {
  InitializeAllTargetInfos();
  InitializeAllTargetMCs();
  InitializeAllAsmParsers();
  Triple TT(TripleName);
  std::string Error;
  const Target *T = TargetRegistry::lookupTarget(TT, Error);
  if (!T) {
    ADD_FAILURE() << Error;
    return std::nullopt;
  }
  MCTargetOptions MCOptions;
  std::unique_ptr<MCRegisterInfo> MRI(T->createMCRegInfo(TT));
  std::unique_ptr<MCAsmInfo> MAI(T->createMCAsmInfo(*MRI, TT, MCOptions));
  std::unique_ptr<MCSubtargetInfo> STI(T->createMCSubtargetInfo(TT, {}, {}));
  std::unique_ptr<MCInstrInfo> MII(T->createMCInstrInfo());
  SourceMgr Sources;
  Sources.AddNewSourceBuffer(MemoryBuffer::getMemBuffer(Assembly), SMLoc());
  MCContext Context(TT, *MAI, *MRI, *STI, &Sources);
  std::unique_ptr<MCObjectFileInfo> MOFI(
      T->createMCObjectFileInfo(Context, /*PIC=*/false));
  Context.setObjectFileInfo(MOFI.get());
  mc_rewrite::RewriteResult Result;
  auto Backend = mc_rewrite::createAddressModelBackend(
      std::unique_ptr<MCAsmBackend>(
          T->createMCAsmBackend(*STI, *MRI, MCOptions)),
      Options, Result);
  std::unique_ptr<MCCodeEmitter> Emitter(T->createMCCodeEmitter(*MII, Context));
  std::unique_ptr<MCStreamer> Streamer(T->createMCObjectStreamer(
      TT, Context, std::move(Backend),
      mc_rewrite::createFinalImageObjectWriter(Options, Result),
      std::move(Emitter), *STI));
  std::unique_ptr<MCAsmParser> Parser(
      createMCAsmParser(Sources, Context, *Streamer, *MAI));
  std::unique_ptr<MCTargetAsmParser> TargetParser(
      T->createMCAsmParser(*STI, *Parser, *MII));
  Parser->setTargetParser(*TargetParser);
  if (Parser->Run(/*NoInitialTextSection=*/false))
    return std::nullopt;
  return Result;
}

mc_rewrite::RewriteOptions options(uint64_t Base, uint64_t TargetVA) {
  mc_rewrite::RewriteOptions Options;
  Options.Model.TextVA = Base;
  Options.Model.getSectionVA = [=](StringRef Section) {
    return Base + (Section.contains(DataSectionSelector) ? DataOffset : 0);
  };
  Options.Model.resolveWithContext =
      [=](const mc_rewrite::RewriteSymbolResolveRequest &Request)
      -> std::optional<uint64_t> {
    if (Request.Symbol == GOTSymbol)
      return GOTBase;
    if (Request.Symbol == Symbol || Request.Symbol == MachOSymbol)
      return Request.SpecifierName == GOTSpecifier ? GOTSlot : TargetVA;
    return std::nullopt;
  };
  return Options;
}

ArrayRef<uint8_t> bytes(const mc_rewrite::RewriteResult &Result,
                        StringRef SectionName) {
  for (const auto &Section : Result.Sections)
    if (Section.Name == SectionName)
      return Section.Bytes;
  ADD_FAILURE() << SectionName;
  return {};
}

TEST(BinaryRewriteRelocationTest,
     X64PLTRetainsUnalignedForwardAndBackwardTargets) {
  if (!hasTarget(X64ELF))
    GTEST_SKIP();
  for (uint64_t Base : {FirstBase, SecondBase})
    for (uint64_t TargetVA : {ForwardTarget, BackwardTarget}) {
      SCOPED_TRACE(Base);
      SCOPED_TRACE(TargetVA);
      auto Result = assemble(X64ELF, PLTAssembly, options(Base, TargetVA));
      ASSERT_TRUE(Result);
      ASSERT_TRUE(Result->ImageValid);
      EXPECT_TRUE(Result->Unresolved.empty());
      auto Text = bytes(*Result, TextSection);
      ASSERT_EQ(Text.size(), CallBytes);
      const int32_t Delta =
          support::endian::read32le(Text.data() + CallFieldOffset);
      EXPECT_EQ(Base + CallBytes + Delta, TargetVA);
    }
}

TEST(BinaryRewriteRelocationTest, I386GOTPCUsesTheRelocationWordAddress) {
  if (!hasTarget(I386ELF))
    GTEST_SKIP();
  for (uint64_t Base : {FirstBase, SecondBase}) {
    SCOPED_TRACE(Base);
    auto Result =
        assemble(I386ELF, GOTPCAssembly, options(Base, ForwardTarget));
    ASSERT_TRUE(Result);
    ASSERT_TRUE(Result->ImageValid);
    EXPECT_TRUE(Result->Unresolved.empty());
    auto Text = bytes(*Result, TextSection);
    ASSERT_EQ(Text.size(), WordBytes);
    const int32_t Delta = support::endian::read32le(Text.data());
    EXPECT_EQ(Base + Delta, GOTBase);
  }
}

TEST(BinaryRewriteRelocationTest, I386GOTOFFAndGOTSubtractTheResolvedAnchor) {
  if (!hasTarget(I386ELF))
    GTEST_SKIP();
  for (uint64_t TargetVA : {ForwardTarget, BackwardTarget}) {
    SCOPED_TRACE(TargetVA);
    auto Result =
        assemble(I386ELF, GOTOffsetsAssembly, options(FirstBase, TargetVA));
    ASSERT_TRUE(Result);
    ASSERT_TRUE(Result->ImageValid);
    EXPECT_TRUE(Result->Unresolved.empty());
    auto Text = bytes(*Result, TextSection);
    ASSERT_EQ(Text.size(), WordBytes + WordBytes);
    const int32_t Offset = support::endian::read32le(Text.data());
    const int32_t SlotOffset =
        support::endian::read32le(Text.data() + WordBytes);
    EXPECT_EQ(GOTBase + Offset, TargetVA);
    EXPECT_EQ(GOTBase + SlotOffset, GOTSlot);
  }
}

TEST(BinaryRewriteRelocationTest, I386GOTPCInstructionRetainsItsInlineAddend) {
  if (!hasTarget(I386ELF))
    GTEST_SKIP();
  auto Options = options(FirstBase, ForwardTarget);
  bool SawInstruction = false;
  Options.onFixup = [&](const mc_rewrite::FixupCtx &Fixup, uint64_t Value) {
    if (Fixup.Sym == GOTSymbol) {
      EXPECT_EQ(Fixup.KindName, GOTPCFixupName);
      EXPECT_EQ(Fixup.SectionOffset, AddFieldOffset);
      EXPECT_EQ(Fixup.Addend, AddFieldOffset);
      SawInstruction = true;
    }
    return Value;
  };
  auto Result = assemble(I386ELF, GOTPCInstructionAssembly, Options);
  ASSERT_TRUE(Result);
  ASSERT_TRUE(Result->ImageValid);
  EXPECT_TRUE(Result->Unresolved.empty());
  EXPECT_TRUE(SawInstruction);
  auto Text = bytes(*Result, TextSection);
  ASSERT_EQ(Text.size(), AddBytes);
  const int32_t Delta = support::endian::read32le(Text.data() + AddFieldOffset);
  EXPECT_EQ(FirstBase + Delta, GOTBase);
}

TEST(BinaryRewriteRelocationTest, I386GOTOffsetsRequireAResolvedAnchor) {
  if (!hasTarget(I386ELF))
    GTEST_SKIP();
  auto Options = options(FirstBase, ForwardTarget);
  bool RequestedAnchor = false;
  Options.Model.resolveWithContext =
      [&](const mc_rewrite::RewriteSymbolResolveRequest &Request)
      -> std::optional<uint64_t> {
    if (Request.Symbol == GOTSymbol) {
      RequestedAnchor = true;
      return std::nullopt;
    }
    return ForwardTarget;
  };
  auto Result = assemble(I386ELF, GOTOffsetsAssembly, Options);
  EXPECT_TRUE(RequestedAnchor);
  EXPECT_TRUE(!Result || !Result->ImageValid || !Result->Unresolved.empty());
}

TEST(BinaryRewriteRelocationTest,
     MachOGOTDataAndInstructionHaveDistinctPCBias) {
  if (!hasTarget(X64MachO))
    GTEST_SKIP();
  for (uint64_t Base : {FirstBase, SecondBase})
    for (uint64_t TargetVA : {ForwardTarget, BackwardTarget}) {
      SCOPED_TRACE(Base);
      SCOPED_TRACE(TargetVA);
      auto Result =
          assemble(X64MachO, MachOGOTAssembly, options(Base, TargetVA));
      ASSERT_TRUE(Result);
      ASSERT_TRUE(Result->ImageValid);
      EXPECT_TRUE(Result->Unresolved.empty());
      auto Text = bytes(*Result, MachOTextSection);
      auto Data = bytes(*Result, MachODataSection);
      ASSERT_EQ(Text.size(), MovBytes);
      ASSERT_EQ(Data.size(), WordBytes + WordBytes);
      const int32_t InstructionDelta =
          support::endian::read32le(Text.data() + MovFieldOffset);
      const int32_t CompensatedDelta = support::endian::read32le(Data.data());
      const int32_t UncompensatedDelta =
          support::endian::read32le(Data.data() + WordBytes);
      EXPECT_EQ(Base + MovBytes + InstructionDelta, TargetVA);
      EXPECT_EQ(Base + DataOffset + CompensatedDelta, TargetVA);
      EXPECT_EQ(Base + DataOffset + WordBytes + WordBytes + UncompensatedDelta,
                TargetVA);
    }
}

TEST(BinaryRewriteRelocationTest, AArch64StillUsesPageAndPageOffsetArithmetic) {
  if (!hasTarget(AArch64ELF))
    GTEST_SKIP();
  for (uint64_t Base : {AArch64FirstBase, AArch64SecondBase})
    for (uint64_t TargetVA : {ForwardTarget, BackwardTarget}) {
      SCOPED_TRACE(Base);
      SCOPED_TRACE(TargetVA);
      auto Result =
          assemble(AArch64ELF, AArch64Assembly, options(Base, TargetVA));
      ASSERT_TRUE(Result);
      ASSERT_TRUE(Result->ImageValid);
      EXPECT_TRUE(Result->Unresolved.empty());
      auto Text = bytes(*Result, TextSection);
      ASSERT_EQ(Text.size(), WordBytes + WordBytes);
      const uint32_t ADRP = support::endian::read32le(Text.data());
      const uint32_t Add = support::endian::read32le(Text.data() + WordBytes);
      const uint32_t Bits =
          ((ADRP >> ADRPImmediateLowShift) & ADRPImmediateLowMask) |
          (((ADRP >> ADRPImmediateHighShift) & ADRPImmediateHighMask)
           << ADRPImmediateHighOffset);
      const int64_t Delta =
          (int64_t(Bits ^ ADRPSignBit) - ADRPSignBit) * PageBytes;
      EXPECT_EQ((Base & ~PageMask) + Delta, TargetVA & ~PageMask);
      EXPECT_EQ((Add >> AddImmediateShift) & PageMask, TargetVA & PageMask);
    }
}

} // namespace
