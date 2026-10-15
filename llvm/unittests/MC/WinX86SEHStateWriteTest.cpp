//===- WinX86SEHStateWriteTest.cpp - SEH write receipt tests -------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/MC/BinaryRewrite.h"
#include "gtest/gtest.h"
#include <climits>
#include <map>
#include <vector>

using namespace llvm;
using namespace llvm::mc_rewrite;

namespace {

struct SEHStateWriteFixture {
  std::vector<RewriteSourceFunctionOwner> Owners = {
      {"parent", "_parent", 0x1000, false},
      {"callback", "_callback", 0x2000, true}};
  std::map<std::string, uint64_t> Addrs = {{"_parent", 0x1000},
                                           {"_callback", 0x2000}};
  std::vector<RewriteFunctionRange> Ranges = {
      {1, "_parent", 0x1000, "_parent", 0x1000, "parent.end", 0x1100},
      {2, "_callback", 0x2000, "_callback", 0x2000, "callback.end", 0x2040}};
  std::vector<RewriteWinEHSemanticRecord> Rows;
  std::vector<RewriteWinX86SEHFrame> Frames;
  std::vector<RewriteWinX86SEHStateWrite> Writes;

  explicit SEHStateWriteFixture(bool EH4 = true) {
    const auto Encoding = EH4 ? RewriteWinEHSemanticEncoding::X86SEH4
                              : RewriteWinEHSemanticEncoding::X86SEH3;
    const int32_t BaseState = EH4 ? -2 : -1;
    const uint32_t HeaderSize = EH4 ? 16 : 0;
    for (unsigned I = 0; I != 2; ++I) {
      RewriteWinEHSemanticRecord Row;
      // State numbering is independent of the source level and digest.
      Row.Token.Region = I ? 4 : 9;
      Row.Token.Digest = {1, 2, 3, I + 4};
      Row.SourceFunction = "parent";
      Row.OwnerSymbol = "_parent";
      Row.OwnerVA = 0x1000;
      Row.ContainerSymbol = "table";
      Row.ContainerVA = 0x3000;
      Row.RecordVA = 0x3000 + HeaderSize + I * 12;
      Row.RecordSize = 12;
      Row.HandlerSymbol = "handler";
      Row.HandlerVA = 0x1030;
      Row.Encoding = Encoding;
      Row.ContainerEndSymbol = "table.end";
      Row.ContainerEndVA = 0x3000 + HeaderSize + 24;
      Row.GeneratedState = I;
      Row.EnclosingState = I ? 0 : BaseState;
      if (EH4)
        Row.RegistrationCookieOffsets = {-2, 0, -36, 0};
      if (I) {
        Row.FilterSymbol = "_callback";
        Row.FilterVA = 0x2000;
      }
      Rows.push_back(Row);
    }
    Frames.push_back({"parent", "_parent", 0x1000, -48, 24, 20, Encoding});
    Writes.push_back({7, "callback", "_callback", 0x2000, Frames.front(),
                      Rows.front().Token, 0, 0, "write.begin", 0x2008,
                      "write.end", 0x200f});
    Writes.push_back({8, "callback", "_callback", 0x2000, Frames.front(),
                      std::nullopt, BaseState, 0, "reset.begin", 0x2010,
                      "reset.end", 0x2017});
  }

  bool valid() const {
    return validateRewriteWinX86SEHStateWrites(Frames, Writes, Rows, Owners,
                                               Ranges, Addrs);
  }
};

TEST(WinX86SEHStateWriteTest, ResolvesSourceTokensAndPersonalitySentinels) {
  EXPECT_TRUE(SEHStateWriteFixture(false).valid());
  EXPECT_TRUE(SEHStateWriteFixture(true).valid());
  EXPECT_TRUE(validateRewriteWinX86SEHStateWrites({}, {}, {}, {}, {}, {}));
}

TEST(WinX86SEHStateWriteTest, AcceptsFullWidthOpaqueIdentities) {
  SEHStateWriteFixture Fixture;
  Fixture.Writes[0].WriteID = UINT64_MAX;
  Fixture.Writes[1].WriteID = UINT64_MAX - 1;
  Fixture.Rows[0].Token.Digest = {UINT64_MAX, UINT64_MAX - 1, uint64_t(1) << 63,
                                  4};
  Fixture.Writes[0].Semantic = Fixture.Rows[0].Token;
  EXPECT_TRUE(Fixture.valid());
}

TEST(WinX86SEHStateWriteTest, RequiresExactParentTokenAndGeneratedState) {
  auto Reject = [](auto Mutate) {
    SEHStateWriteFixture Fixture;
    Mutate(Fixture);
    EXPECT_FALSE(Fixture.valid());
  };
  Reject([](auto &F) { F.Writes[0].Semantic->Region = 0; });
  Reject([](auto &F) { ++F.Writes[0].Semantic->Digest[3]; });
  Reject([](auto &F) { F.Writes[0].Semantic->Digest = {}; });
  Reject([](auto &F) { F.Writes[0].Semantic->Clause = 1; });
  Reject([](auto &F) {
    F.Writes[0].Semantic->Kind = RewriteWinEHSemanticKind::CxxCatch;
  });
  Reject([](auto &F) { F.Writes[0].GeneratedState = 1; });
  Reject([](auto &F) { F.Writes[0].GeneratedState = -2; });
  Reject([](auto &F) { F.Writes[1].GeneratedState = -1; });
  Reject([](auto &F) { F.Writes[1].Semantic = F.Rows[0].Token; });
  Reject([](auto &F) { F.Rows.push_back(F.Rows.front()); });
  Reject([](auto &F) { F.Rows.clear(); });
  SEHStateWriteFixture EH3(false);
  EH3.Writes[1].GeneratedState = -2;
  EXPECT_FALSE(EH3.valid());
}

TEST(WinX86SEHStateWriteTest, RequiresUniquePhysicalParentLayout) {
  auto Reject = [](auto Mutate) {
    SEHStateWriteFixture Fixture;
    Mutate(Fixture);
    EXPECT_FALSE(Fixture.valid());
  };
  Reject([](auto &F) { F.Frames.clear(); });
  Reject([](auto &F) { F.Frames.push_back(F.Frames.front()); });
  Reject([](auto &F) { F.Frames[0].SourceFunction = "callback"; });
  Reject([](auto &F) { F.Frames[0].OwnerVA += 4; });
  Reject([](auto &F) { F.Frames[0].RegistrationSize = 28; });
  Reject([](auto &F) { F.Frames[0].StateOffset = 16; });
  Reject([](auto &F) { F.Frames[0].RegistrationOffset = -47; });
  Reject([](auto &F) { F.Frames[0].RegistrationOffset = INT32_MAX - 3; });
  Reject([](auto &F) { F.Writes[0].ParentFrame.RegistrationOffset -= 4; });
  Reject([](auto &F) { F.Writes[0].ParentFrame.OwnerSymbol = "other"; });
  Reject([](auto &F) {
    F.Frames[0].Encoding = RewriteWinEHSemanticEncoding::X86SEH3;
  });
}

TEST(WinX86SEHStateWriteTest, BindsEachOccurrenceToItsCallbackInstructions) {
  auto Reject = [](auto Mutate) {
    SEHStateWriteFixture Fixture;
    Mutate(Fixture);
    EXPECT_FALSE(Fixture.valid());
  };
  Reject([](auto &F) { F.Writes[0].WriteID = 0; });
  Reject([](auto &F) { F.Writes[0].AddressRegister = 8; });
  Reject([](auto &F) { F.Writes[0].AddressRegister = UINT8_MAX; });
  Reject([](auto &F) { F.Writes[1].WriteID = F.Writes[0].WriteID; });
  Reject([](auto &F) { F.Writes[0].SourceFunction = "parent"; });
  Reject([](auto &F) { F.Writes[0].OwnerVA += 4; });
  Reject([](auto &F) { F.Writes[0].BeginSymbol.clear(); });
  Reject([](auto &F) { F.Writes[0].EndSymbol.clear(); });
  Reject([](auto &F) { F.Writes[0].BeginVA = F.Writes[0].EndVA; });
  Reject([](auto &F) { F.Writes[0].BeginVA = 0x1fff; });
  Reject([](auto &F) { F.Writes[0].EndVA = 0x2041; });
  Reject([](auto &F) { F.Writes[1].BeginVA = F.Writes[0].EndVA - 1; });
  Reject([](auto &F) {
    F.Writes[1].BeginVA = F.Writes[0].BeginVA;
    F.Writes[1].EndVA = F.Writes[0].EndVA;
  });
  Reject([](auto &F) { F.Ranges[1].OwnerSymbol = "_parent"; });
  for (uint8_t Reg = 0; Reg != 8; ++Reg) {
    SEHStateWriteFixture Register;
    Register.Writes[0].AddressRegister = Reg;
    EXPECT_TRUE(Register.valid());
  }
  SEHStateWriteFixture Adjacent;
  Adjacent.Writes[1].BeginVA = Adjacent.Writes[0].EndVA;
  EXPECT_TRUE(Adjacent.valid());
}

} // namespace
