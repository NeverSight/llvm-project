//===- BinaryRewriteTest.cpp - Binary rewrite interface tests ------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/MC/BinaryRewrite.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCTargetOptions.h"
#include "gtest/gtest.h"

using namespace llvm;

namespace {

class TestMCAsmInfo final : public MCAsmInfo {
public:
  explicit TestMCAsmInfo(const MCTargetOptions &Options) : MCAsmInfo(Options) {
    static const AtSpecifier Specifiers[] = {{7, "GOT"}};
    initializeAtSpecifiers(Specifiers);
  }
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

} // namespace
