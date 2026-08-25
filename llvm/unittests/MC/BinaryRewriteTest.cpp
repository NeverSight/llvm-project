//===- BinaryRewriteTest.cpp - Binary rewrite interface tests ------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/MC/BinaryRewrite.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCTargetOptions.h"
#include "llvm/TargetParser/Triple.h"
#include "gtest/gtest.h"
#include <map>
#include <vector>

using namespace llvm;

namespace {

class TestMCAsmInfo final : public MCAsmInfo {
public:
  explicit TestMCAsmInfo(const MCTargetOptions &Options) : MCAsmInfo(Options) {
    static const AtSpecifier Specifiers[] = {{7, "GOT"}};
    initializeAtSpecifiers(Specifiers);
  }
};

class RewriteOwnerAssemblerFixture {
private:
  Triple TT;
  MCTargetOptions Options;
  TestMCAsmInfo MAI;
  MCRegisterInfo MRI;
  MCSubtargetInfo STI;
  MCContext Context;

public:
  RewriteOwnerAssemblerFixture()
      : TT("x86_64-pc-windows-msvc"), MAI(Options),
        STI(TT, "", "", "", {}, {}, {}, nullptr, nullptr, nullptr, nullptr,
            nullptr, nullptr),
        Context(TT, MAI, MRI, STI),
        Assembler(Context, nullptr, nullptr, nullptr) {}

  MCSymbol *symbol(StringRef Name) { return Context.getOrCreateSymbol(Name); }

  MCAssembler Assembler;
};

TEST(BinaryRewriteTest, SpecifierNameLookupCanFailClosedWithoutAsserting) {
  MCTargetOptions Options;
  TestMCAsmInfo Info(Options);
  EXPECT_EQ(Info.getSpecifierNameOrEmpty(7), "GOT");
  EXPECT_TRUE(Info.getSpecifierNameOrEmpty(0xfeed).empty());
}

TEST(BinaryRewriteTest, ContextResolverReceivesCompleteRequest) {
  mc_rewrite::RewriteAddressModel Model;
  bool LegacyCalled = false;
  Model.resolve = [&](StringRef, uint32_t) -> std::optional<uint64_t> {
    LegacyCalled = true;
    return 0x1111;
  };
  Model.resolveWithContext =
      [&](const mc_rewrite::RewriteSymbolResolveRequest &Request)
      -> std::optional<uint64_t> {
    EXPECT_EQ(Request.Symbol, "_target");
    EXPECT_EQ(Request.Specifier, 0x40au);
    EXPECT_EQ(Request.SpecifierName, "TLVPPAGEOFF");
    EXPECT_EQ(Request.FixupKind, 129u);
    EXPECT_EQ(Request.FixupKindName, "fixup_aarch64_pcrel_branch26");
    EXPECT_EQ(Request.SectionName, "__compact_unwind");
    EXPECT_EQ(Request.SectionOffset, 0x28u);
    EXPECT_EQ(Request.FixupVA, 0x100028u);
    EXPECT_TRUE(Request.IsPCRel);
    EXPECT_TRUE(Request.IsSubtrahend);
    EXPECT_EQ(Request.BitWidth, 32u);
    return 0x2222;
  };

  mc_rewrite::RewriteSymbolResolveRequest Request;
  Request.Symbol = "_target";
  Request.Specifier = 0x40a;
  Request.SpecifierName = "TLVPPAGEOFF";
  Request.FixupKind = 129;
  Request.FixupKindName = "fixup_aarch64_pcrel_branch26";
  Request.SectionName = "__compact_unwind";
  Request.SectionOffset = 0x28;
  Request.FixupVA = 0x100028;
  Request.IsPCRel = true;
  Request.IsSubtrahend = true;
  Request.BitWidth = 32;

  EXPECT_EQ(Model.resolveSymbol(Request), 0x2222u);
  EXPECT_FALSE(LegacyCalled);
}

TEST(BinaryRewriteTest, ContextResolverCanRejectWithoutLegacyFallback) {
  mc_rewrite::RewriteAddressModel Model;
  bool LegacyCalled = false;
  Model.resolve = [&](StringRef, uint32_t) -> std::optional<uint64_t> {
    LegacyCalled = true;
    return 0x1111;
  };
  Model.resolveWithContext = [](const mc_rewrite::RewriteSymbolResolveRequest &)
      -> std::optional<uint64_t> { return std::nullopt; };

  mc_rewrite::RewriteSymbolResolveRequest Request;
  Request.Symbol = "_unsupported_auth_reference";
  EXPECT_FALSE(Model.resolveSymbol(Request).has_value());
  EXPECT_FALSE(LegacyCalled);
}

TEST(BinaryRewriteTest, LegacyResolverRemainsTheFallback) {
  mc_rewrite::RewriteAddressModel Model;
  Model.resolve = [](StringRef Symbol,
                     uint32_t Specifier) -> std::optional<uint64_t> {
    EXPECT_EQ(Symbol, "legacy_symbol");
    EXPECT_EQ(Specifier, 7u);
    return 0x3333;
  };

  mc_rewrite::RewriteSymbolResolveRequest Request;
  Request.Symbol = "legacy_symbol";
  Request.Specifier = 7;
  Request.FixupKind = 130;
  Request.IsPCRel = true;
  Request.BitWidth = 64;

  EXPECT_EQ(Model.resolveSymbol(Request), 0x3333u);
}

TEST(BinaryRewriteTest, SymbolIndexMetadataUsesExplicitNoFixupContract) {
  mc_rewrite::RewriteAddressModel Model;
  Model.resolveWithContext =
      [](const mc_rewrite::RewriteSymbolResolveRequest &Request)
      -> std::optional<uint64_t> {
    EXPECT_EQ(Request.Symbol, "metadata_target");
    EXPECT_EQ(Request.Specifier, 0u);
    EXPECT_TRUE(Request.SpecifierName.empty());
    EXPECT_EQ(Request.FixupKind, static_cast<unsigned>(FK_NONE));
    EXPECT_EQ(Request.FixupKindName, "FK_NONE");
    EXPECT_EQ(Request.SectionName, ".gfids$y");
    EXPECT_EQ(Request.SectionOffset, 0x10u);
    EXPECT_EQ(Request.FixupVA, 0x200010u);
    EXPECT_FALSE(Request.IsPCRel);
    EXPECT_FALSE(Request.IsSubtrahend);
    EXPECT_EQ(Request.BitWidth, 32u);
    return 0x4444;
  };

  mc_rewrite::RewriteSymbolResolveRequest Request;
  Request.Symbol = "metadata_target";
  Request.FixupKind = FK_NONE;
  Request.FixupKindName = "FK_NONE";
  Request.SectionName = ".gfids$y";
  Request.SectionOffset = 0x10;
  Request.FixupVA = 0x200010;
  Request.BitWidth = 32;
  EXPECT_EQ(Model.resolveSymbol(Request), 0x4444u);
}

TEST(BinaryRewriteTest, SourceOwnerKindsRequireExactParentEntry) {
  using Kind = mc_rewrite::RewriteSourceFunctionOwnerKind;
  using Owner = mc_rewrite::RewriteSourceFunctionOwner;
  const std::vector<Owner> Valid = {
      {"parent", "parent$entry", 0x1000, false, Kind::FunctionEntry, {}},
      {"source_catch", "parent$catch", 0x1100, true, Kind::WinCxxCatchFunclet,
       "parent"}};
  EXPECT_TRUE(mc_rewrite::validateRewriteSourceFunctionOwners(Valid));

  auto Invalid = Valid;
  Invalid[1].ParentSourceFunction.clear();
  EXPECT_FALSE(mc_rewrite::validateRewriteSourceFunctionOwners(Invalid));

  Invalid = Valid;
  Invalid[1].ParentSourceFunction = "source_catch";
  EXPECT_FALSE(mc_rewrite::validateRewriteSourceFunctionOwners(Invalid));

  Invalid = Valid;
  Invalid[1].ParentSourceFunction = "missing";
  EXPECT_FALSE(mc_rewrite::validateRewriteSourceFunctionOwners(Invalid));

  Invalid = Valid;
  Invalid[1].IsPrivate = false;
  EXPECT_FALSE(mc_rewrite::validateRewriteSourceFunctionOwners(Invalid));

  Invalid = Valid;
  Invalid[0].ParentSourceFunction = "unexpected";
  EXPECT_FALSE(mc_rewrite::validateRewriteSourceFunctionOwners(Invalid));

  Invalid = Valid;
  Invalid[1].Kind = static_cast<Kind>(0xff);
  EXPECT_FALSE(mc_rewrite::validateRewriteSourceFunctionOwners(Invalid));
}

TEST(BinaryRewriteTest, WinEHSemanticRowsRequireExactSourceAndRangeClosure) {
  using Encoding = mc_rewrite::RewriteWinEHSemanticEncoding;
  using Kind = mc_rewrite::RewriteWinEHSemanticKind;
  using OwnerKind = mc_rewrite::RewriteSourceFunctionOwnerKind;
  using Record = mc_rewrite::RewriteWinEHSemanticRecord;

  const std::vector<mc_rewrite::RewriteSourceFunctionOwner> Owners = {
      {"source", "source$entry", 0x1000, false, OwnerKind::FunctionEntry, {}},
      {"source_catch", "source$catch", 0x1100, true,
       OwnerKind::WinCxxCatchFunclet, "source"}};
  const std::map<std::string, uint64_t> OwnerAddrs = {{"source$entry", 0x1000},
                                                      {"source$catch", 0x1100}};
  const std::vector<mc_rewrite::RewriteFunctionRange> Ranges = {
      {1,
       "source$entry",
       0x1000,
       "source$begin",
       0x1000,
       "source$end",
       0x1100,
       {},
       0},
      {2, "source$catch", 0x1100, "catch$begin", 0x1100, "catch$end", 0x1200,
       "source$entry", 0x1000}};

  mc_rewrite::RewriteWinEHSemanticToken SEHToken;
  SEHToken.Kind = Kind::SEHScope;
  SEHToken.Region = 7;
  SEHToken.Digest = {1, 2, 3, 4};
  mc_rewrite::RewriteWinEHSemanticToken CatchToken;
  CatchToken.Kind = Kind::CxxCatch;
  CatchToken.Region = 2;
  CatchToken.Clause = 1;
  CatchToken.Digest = {5, 6, 7, 8};

  const std::vector<Record> Valid = {{SEHToken, "source", "source$entry",
                                      0x1000, "seh$table", 0x2ff0, 0x3000, 16,
                                      "try$begin", 0x1010, "try$end", 0x1020,
                                      "source$catch", 0x1100, Encoding::SEH},
                                     {CatchToken,
                                      "source",
                                      "source$entry",
                                      0x1000,
                                      "try$row.2",
                                      0x3010,
                                      0x3020,
                                      20,
                                      {},
                                      0,
                                      {},
                                      0,
                                      "source$catch",
                                      0x1100,
                                      Encoding::CxxFH3}};
  EXPECT_TRUE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Valid, Owners, Ranges, OwnerAddrs));

  auto ValidFH4 = Valid;
  ValidFH4[1].RecordSize = 6;
  ValidFH4[1].Encoding = Encoding::CxxFH4;
  EXPECT_TRUE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      ValidFH4, Owners, Ranges, OwnerAddrs));

  auto ValidTypedFH4 = ValidFH4;
  ValidTypedFH4[1].RecordSize = 10;
  EXPECT_TRUE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      ValidTypedFH4, Owners, Ranges, OwnerAddrs));

  for (uint32_t InvalidSize : {7u, 8u, 15u}) {
    auto InvalidFH4Size = ValidFH4;
    InvalidFH4Size[1].RecordSize = InvalidSize;
    EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
        InvalidFH4Size, Owners, Ranges, OwnerAddrs));
  }

  auto InvalidEncoding = ValidFH4;
  InvalidEncoding[1].Encoding = Encoding::CxxFH3;
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      InvalidEncoding, Owners, Ranges, OwnerAddrs));

  auto Invalid = Valid;
  Invalid[0].SourceFunction = "other";
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Invalid, Owners, Ranges, OwnerAddrs));

  Invalid = Valid;
  Invalid[1].RecordVA = 0x3008;
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Invalid, Owners, Ranges, OwnerAddrs));

  Invalid = Valid;
  Invalid[0].Token.Digest = {};
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Invalid, Owners, Ranges, OwnerAddrs));

  Invalid = Valid;
  Invalid[0].Token.Clause = 1;
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Invalid, Owners, Ranges, OwnerAddrs));

  Invalid = Valid;
  Invalid[0].ContainerSymbol.clear();
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Invalid, Owners, Ranges, OwnerAddrs));

  Invalid = Valid;
  Invalid[1].ContainerVA = 0x4000;
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Invalid, Owners, Ranges, OwnerAddrs));

  Invalid = Valid;
  Invalid[1].HandlerVA = 0x1000;
  Invalid[1].HandlerSymbol = "source$entry";
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Invalid, Owners, Ranges, OwnerAddrs));

  Invalid = Valid;
  Invalid.push_back(Valid[1]);
  Invalid.back().RecordVA = 0x3040;
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Invalid, Owners, Ranges, OwnerAddrs));

  Invalid = Valid;
  Invalid[1].Token.Kind = static_cast<Kind>(0xff);
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Invalid, Owners, Ranges, OwnerAddrs));

  Invalid = Valid;
  Invalid.push_back(Valid[1]);
  Invalid.back().RecordVA = 0x3040;
  Invalid.back().Token.Region = 3;
  Invalid.back().Token.Clause = 0;
  Invalid.back().Token.Digest = {9, 10, 11, 12};
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Invalid, Owners, Ranges, OwnerAddrs));
}

TEST(BinaryRewriteTest,
     ProvisionalCxxHandlerRangeSelectionIsIndependentOfRangeOrder) {
  using Kind = mc_rewrite::RewriteWinEHSemanticKind;
  using OwnerKind = mc_rewrite::RewriteSourceFunctionOwnerKind;
  using Range = mc_rewrite::RewriteFunctionRange;

  const std::vector<mc_rewrite::RewriteSourceFunctionOwner> Owners = {
      {"source", "source$entry", 0x1000, false, OwnerKind::FunctionEntry, {}},
      {"source_catch", "source$catch", 0x1000, true,
       OwnerKind::WinCxxCatchFunclet, "source"}};
  const std::map<std::string, uint64_t> OwnerAddrs = {{"source$entry", 0x1000},
                                                      {"source$catch", 0x1000}};
  const Range Direct = {1,      "source$entry", 0x1000, "source$begin",
                        0x1000, "source$end",   0x1100, {},
                        0};
  const Range Catch = {2,      "source$catch", 0x1000, "catch$begin",
                       0x1000, "catch$end",    0x1080, "source$entry",
                       0x1000};

  mc_rewrite::RewriteWinEHSemanticToken Token;
  Token.Kind = Kind::CxxCatch;
  Token.Region = 2;
  Token.Clause = 1;
  Token.Digest = {1, 2, 3, 4};
  const std::vector<mc_rewrite::RewriteWinEHSemanticRecord> Records = {
      {Token,
       "source",
       "source$entry",
       0x1000,
       "try$row.2",
       0x3000,
       0x3020,
       20,
       {},
       0,
       {},
       0,
       "source$catch",
       0x1000,
       mc_rewrite::RewriteWinEHSemanticEncoding::CxxFH3}};

  for (bool DirectFirst : {false, true}) {
    SCOPED_TRACE(DirectFirst);
    const std::vector<Range> Ranges = DirectFirst
                                          ? std::vector<Range>{Direct, Catch}
                                          : std::vector<Range>{Catch, Direct};
    EXPECT_TRUE(mc_rewrite::validateRewriteWinEHSemanticRecords(
        Records, Owners, Ranges, OwnerAddrs,
        /*ValidateGlobalFunctionRangeOverlap=*/false));
  }
}

TEST(BinaryRewriteTest,
     CompilerCreatedCxxCatchRequiresItsExactDerivedOwnerRange) {
  using Kind = mc_rewrite::RewriteWinEHSemanticKind;
  using OwnerKind = mc_rewrite::RewriteSourceFunctionOwnerKind;
  using Range = mc_rewrite::RewriteFunctionRange;
  using Record = mc_rewrite::RewriteWinEHSemanticRecord;

  const std::vector<mc_rewrite::RewriteSourceFunctionOwner> Owners = {
      {"source", "source$entry", 0x1000, false, OwnerKind::FunctionEntry, {}}};
  const std::map<std::string, uint64_t> OwnerAddrs = {
      {"source$entry", 0x1000},
      {"source$catch", 0x1100},
      {"source$catch.other", 0x1100}};
  const Range Direct = {1,      "source$entry", 0x1000, "source$begin",
                        0x1000, "source$end",   0x1100, {},
                        0};
  const Range Catch = {2,      "source$catch", 0x1100, "catch$begin",
                       0x1100, "catch$end",    0x1200, "source$entry",
                       0x1000};

  mc_rewrite::RewriteWinEHSemanticToken Token;
  Token.Kind = Kind::CxxCatch;
  Token.Region = 2;
  Token.Clause = 1;
  Token.Digest = {1, 2, 3, 4};
  const std::vector<Record> Records = {
      {Token,
       "source",
       "source$entry",
       0x1000,
       "try$row.2",
       0x3000,
       0x3020,
       20,
       {},
       0,
       {},
       0,
       "source$catch",
       0x1100,
       mc_rewrite::RewriteWinEHSemanticEncoding::CxxFH3}};

  const std::vector<Range> ValidRanges = {Direct, Catch};
  EXPECT_TRUE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Records, Owners, ValidRanges, OwnerAddrs));

  Range Interior = Catch;
  Interior.BeginVA = 0x1080;
  const std::vector<Range> InteriorRanges = {Direct, Interior};
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Records, Owners, InteriorRanges, OwnerAddrs,
      /*ValidateGlobalFunctionRangeOverlap=*/false));

  Range Borrowed = Catch;
  Borrowed.OwnerSymbol = "source$catch.other";
  const std::vector<Range> BorrowedRanges = {Direct, Borrowed};
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Records, Owners, BorrowedRanges, OwnerAddrs));
}

TEST(BinaryRewriteTest, CxxCatchReceiptCannotBorrowAnotherDerivedOwnerRange) {
  using Kind = mc_rewrite::RewriteWinEHSemanticKind;
  using OwnerKind = mc_rewrite::RewriteSourceFunctionOwnerKind;
  using Record = mc_rewrite::RewriteWinEHSemanticRecord;

  const std::vector<mc_rewrite::RewriteSourceFunctionOwner> Owners = {
      {"source", "source$entry", 0x1000, false, OwnerKind::FunctionEntry, {}},
      {"source_catch", "source$catch.a", 0x1100, true,
       OwnerKind::WinCxxCatchFunclet, "source"}};
  const std::map<std::string, uint64_t> OwnerAddrs = {
      {"source$entry", 0x1000},
      {"source$catch.a", 0x1100},
      {"source$catch.b", 0x1080}};
  const std::vector<mc_rewrite::RewriteFunctionRange> Ranges = {
      {1,
       "source$entry",
       0x1000,
       "source$begin",
       0x1000,
       "source$end",
       0x1080,
       {},
       0},
      {2, "source$catch.b", 0x1080, "catch$b.begin", 0x1080, "catch$b.end",
       0x1200, "source$entry", 0x1000}};

  mc_rewrite::RewriteWinEHSemanticToken Token;
  Token.Kind = Kind::CxxCatch;
  Token.Digest = {1, 2, 3, 4};
  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      ArrayRef<Record>(), Owners, Ranges, OwnerAddrs));

  const std::vector<Record> Records = {
      {Token,
       "source",
       "source$entry",
       0x1000,
       "try$row.0",
       0x3000,
       0x3020,
       20,
       {},
       0,
       {},
       0,
       "source$catch.a",
       0x1100,
       mc_rewrite::RewriteWinEHSemanticEncoding::CxxFH3}};

  EXPECT_FALSE(mc_rewrite::validateRewriteWinEHSemanticRecords(
      Records, Owners, Ranges, OwnerAddrs));
}

TEST(BinaryRewriteTest, WinEHSemanticRegistrationPreservesContainerSymbol) {
  RewriteOwnerAssemblerFixture Fixture;
  mc_rewrite::RewriteWinEHSemanticToken Token;
  Token.Digest = {1, 2, 3, 4};
  MCSymbol *Owner = Fixture.symbol("source$entry");
  MCSymbol *Container = Fixture.symbol("seh$table");
  MCSymbol *RecordBegin = Fixture.symbol("seh$row.begin");
  MCSymbol *RecordEnd = Fixture.symbol("seh$row.end");
  MCSymbol *Begin = Fixture.symbol("try$begin");
  MCSymbol *End = Fixture.symbol("try$end");
  MCSymbol *Handler = Fixture.symbol("catch$handler");
  Fixture.Assembler.registerRewriteWinEHSemanticRecord(
      Token, mc_rewrite::RewriteWinEHSemanticEncoding::SEH, "source", Owner,
      Container, RecordBegin, RecordEnd, Begin, End, Handler);

  ASSERT_EQ(Fixture.Assembler.getRewriteWinEHSemanticRecords().size(), 1u);
  EXPECT_EQ(
      Fixture.Assembler.getRewriteWinEHSemanticRecords().front().Container,
      Container);
}

TEST(BinaryRewriteTest, DelegatedOwnerExpectationIsOrderIndependent) {
  using Kind = mc_rewrite::RewriteSourceFunctionOwnerKind;
  for (bool ExpectFirst : {false, true}) {
    SCOPED_TRACE(ExpectFirst);
    RewriteOwnerAssemblerFixture Fixture;
    MCSymbol *Parent = Fixture.symbol("parent$entry");
    MCSymbol *Catch = Fixture.symbol("parent$catch");
    Fixture.Assembler.registerRewriteSourceFunctionOwner("parent", Parent,
                                                         /*IsPrivate=*/false);
    if (ExpectFirst)
      Fixture.Assembler.expectRewriteSourceFunctionOwner(
          "source_catch", Kind::WinCxxCatchFunclet, "parent");
    Fixture.Assembler.registerRewriteSourceFunctionOwner(
        "source_catch", Catch, /*IsPrivate=*/true, Kind::WinCxxCatchFunclet,
        "parent");
    if (!ExpectFirst)
      Fixture.Assembler.expectRewriteSourceFunctionOwner(
          "source_catch", Kind::WinCxxCatchFunclet, "parent");

    EXPECT_TRUE(
        Fixture.Assembler.validateRewriteSourceFunctionOwnerRegistrations());
    ASSERT_EQ(Fixture.Assembler.getRewriteSourceFunctionOwners().size(), 2u);
    const auto &Receipt =
        Fixture.Assembler.getRewriteSourceFunctionOwners().back();
    EXPECT_EQ(Receipt.SourceFunction, "source_catch");
    EXPECT_EQ(Receipt.Owner, Catch);
    EXPECT_EQ(Receipt.Kind, Kind::WinCxxCatchFunclet);
    EXPECT_EQ(Receipt.ParentSourceFunction, "parent");
  }
}

TEST(BinaryRewriteTest, MissingDelegatedOwnerReceiptFailsSharedGate) {
  using Kind = mc_rewrite::RewriteSourceFunctionOwnerKind;
  RewriteOwnerAssemblerFixture Fixture;
  Fixture.Assembler.registerRewriteSourceFunctionOwner(
      "parent", Fixture.symbol("parent$entry"), /*IsPrivate=*/false);
  Fixture.Assembler.expectRewriteSourceFunctionOwner(
      "source_catch", Kind::WinCxxCatchFunclet, "parent");

  EXPECT_FALSE(
      Fixture.Assembler.validateRewriteSourceFunctionOwnerRegistrations());
  ASSERT_EQ(Fixture.Assembler.getRewriteSourceFunctionOwners().size(), 2u);
  EXPECT_EQ(Fixture.Assembler.getRewriteSourceFunctionOwners().back().Owner,
            nullptr);
}

TEST(BinaryRewriteTest, DelegatedOwnerReceiptWithoutExpectationFails) {
  using Kind = mc_rewrite::RewriteSourceFunctionOwnerKind;
  RewriteOwnerAssemblerFixture Fixture;
  Fixture.Assembler.registerRewriteSourceFunctionOwner(
      "parent", Fixture.symbol("parent$entry"), /*IsPrivate=*/false);
  Fixture.Assembler.registerRewriteSourceFunctionOwner(
      "source_catch", Fixture.symbol("parent$catch"), /*IsPrivate=*/true,
      Kind::WinCxxCatchFunclet, "parent");

  EXPECT_FALSE(
      Fixture.Assembler.validateRewriteSourceFunctionOwnerRegistrations());
}

TEST(BinaryRewriteTest, DuplicateDelegatedOwnerExpectationFails) {
  using Kind = mc_rewrite::RewriteSourceFunctionOwnerKind;
  RewriteOwnerAssemblerFixture Fixture;
  Fixture.Assembler.registerRewriteSourceFunctionOwner(
      "parent", Fixture.symbol("parent$entry"), /*IsPrivate=*/false);
  Fixture.Assembler.expectRewriteSourceFunctionOwner(
      "source_catch", Kind::WinCxxCatchFunclet, "parent");
  Fixture.Assembler.expectRewriteSourceFunctionOwner(
      "source_catch", Kind::WinCxxCatchFunclet, "parent");
  Fixture.Assembler.registerRewriteSourceFunctionOwner(
      "source_catch", Fixture.symbol("parent$catch"), /*IsPrivate=*/true,
      Kind::WinCxxCatchFunclet, "parent");

  EXPECT_FALSE(
      Fixture.Assembler.validateRewriteSourceFunctionOwnerRegistrations());
}

TEST(BinaryRewriteTest, DuplicateDelegatedOwnerReceiptFails) {
  using Kind = mc_rewrite::RewriteSourceFunctionOwnerKind;
  RewriteOwnerAssemblerFixture Fixture;
  Fixture.Assembler.registerRewriteSourceFunctionOwner(
      "parent", Fixture.symbol("parent$entry"), /*IsPrivate=*/false);
  Fixture.Assembler.expectRewriteSourceFunctionOwner(
      "source_catch", Kind::WinCxxCatchFunclet, "parent");
  Fixture.Assembler.registerRewriteSourceFunctionOwner(
      "source_catch", Fixture.symbol("parent$catch"), /*IsPrivate=*/true,
      Kind::WinCxxCatchFunclet, "parent");
  Fixture.Assembler.registerRewriteSourceFunctionOwner(
      "source_catch", Fixture.symbol("parent$catch.duplicate"),
      /*IsPrivate=*/true, Kind::WinCxxCatchFunclet, "parent");

  EXPECT_FALSE(
      Fixture.Assembler.validateRewriteSourceFunctionOwnerRegistrations());
}

} // namespace
