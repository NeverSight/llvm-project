//===- WinEHCompressedTest.cpp - Windows EH compression tests ------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCObjectFileInfo.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/MCTargetOptions.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Object/Binary.h"
#include "llvm/Object/ObjectFile.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/TargetSelect.h"
#include "gtest/gtest.h"

using namespace llvm;

namespace {

class WinEHCompressedTest : public ::testing::Test {
protected:
  static constexpr char TripleName[] = "x86_64-pc-linux";

  struct StreamerContext {
    std::unique_ptr<MCObjectFileInfo> MOFI;
    std::unique_ptr<MCContext> Ctx;
    std::unique_ptr<const MCInstrInfo> MII;
    std::unique_ptr<MCStreamer> Streamer;
  };

  WinEHCompressedTest() : TT(TripleName) {
    InitializeAllTargetInfos();
    InitializeAllTargetMCs();

    std::string Error;
    TheTarget = TargetRegistry::lookupTarget(TT, Error);
    if (!TheTarget)
      return;
    MRI.reset(TheTarget->createMCRegInfo(TT));
    MAI.reset(TheTarget->createMCAsmInfo(*MRI, TT, MCOptions));
    STI.reset(TheTarget->createMCSubtargetInfo(TT, "", ""));
  }

  StreamerContext createStreamer(raw_pwrite_stream &OS) {
    StreamerContext Result;
    Result.Ctx = std::make_unique<MCContext>(TT, *MAI, *MRI, *STI);
    Result.MOFI.reset(
        TheTarget->createMCObjectFileInfo(*Result.Ctx, /*PIC=*/false));
    Result.Ctx->setObjectFileInfo(Result.MOFI.get());

    Result.MII.reset(TheTarget->createMCInstrInfo());
    MCCodeEmitter *Emitter =
        TheTarget->createMCCodeEmitter(*Result.MII, *Result.Ctx);
    MCAsmBackend *Backend =
        TheTarget->createMCAsmBackend(*STI, *MRI, MCTargetOptions());
    std::unique_ptr<MCObjectWriter> Writer = Backend->createObjectWriter(OS);
    Result.Streamer.reset(TheTarget->createMCObjectStreamer(
        TT, *Result.Ctx, std::unique_ptr<MCAsmBackend>(Backend),
        std::move(Writer), std::unique_ptr<MCCodeEmitter>(Emitter), *STI));
    return Result;
  }

  Triple TT;
  MCTargetOptions MCOptions;
  std::unique_ptr<MCRegisterInfo> MRI;
  std::unique_ptr<MCAsmInfo> MAI;
  std::unique_ptr<const MCSubtargetInfo> STI;
  const Target *TheTarget = nullptr;
};

TEST_F(WinEHCompressedTest, EmitsCanonicalBoundaryEncodings) {
  if (!TheTarget)
    GTEST_SKIP();

  SmallString<0> ObjectBytes;
  raw_svector_ostream OS(ObjectBytes);
  StreamerContext C = createStreamer(OS);
  C.Streamer->initSections(*STI);
  C.Streamer->switchSection(C.MOFI->getDataSection());

  for (uint64_t Value : {0x7fULL, 0x80ULL, 0x3fffULL, 0x4000ULL, 0x1fffffULL,
                         0x200000ULL, 0xfffffffULL, 0x10000000ULL})
    C.Streamer->emitWinEHCompressedValue(MCConstantExpr::create(Value, *C.Ctx));
  C.Streamer->finish();

  std::unique_ptr<MemoryBuffer> Buffer = MemoryBuffer::getMemBuffer(
      ObjectBytes.str(), "", /*RequiresNullTerminator=*/false);
  auto BinaryOrErr = object::createBinary(Buffer->getMemBufferRef());
  ASSERT_TRUE(static_cast<bool>(BinaryOrErr));
  auto *Object = dyn_cast<object::ObjectFile>(&**BinaryOrErr);
  ASSERT_NE(Object, nullptr);

  constexpr uint8_t Expected[] = {
      0xfe,                         // 0x7f
      0x01, 0x02,                   // 0x80
      0xfd, 0xff,                   // 0x3fff
      0x03, 0x00, 0x02,             // 0x4000
      0xfb, 0xff, 0xff,             // 0x1fffff
      0x07, 0x00, 0x00, 0x02,       // 0x200000
      0xf7, 0xff, 0xff, 0xff,       // 0xfffffff
      0x0f, 0x00, 0x00, 0x00, 0x10, // 0x10000000
  };
  for (const object::SectionRef &Section : Object->sections()) {
    auto NameOrErr = Section.getName();
    ASSERT_TRUE(static_cast<bool>(NameOrErr));
    if (*NameOrErr != ".data")
      continue;
    auto ContentsOrErr = Section.getContents();
    ASSERT_TRUE(static_cast<bool>(ContentsOrErr));
    EXPECT_EQ(arrayRefFromStringRef(*ContentsOrErr), ArrayRef(Expected));
    return;
  }
  FAIL() << ".data section was not emitted";
}

TEST_F(WinEHCompressedTest, RelaxesForwardSymbolDifferencesCanonically) {
  if (!TheTarget)
    GTEST_SKIP();

  SmallString<0> ObjectBytes;
  raw_svector_ostream OS(ObjectBytes);
  StreamerContext C = createStreamer(OS);
  C.Streamer->initSections(*STI);
  C.Streamer->switchSection(C.MOFI->getDataSection());

  for (uint64_t Value : {0x7fULL, 0x80ULL, 0x3fffULL, 0x4000ULL, 0x1fffffULL,
                         0x200000ULL, 0xfffffffULL, 0x10000000ULL}) {
    MCSymbol *Begin = C.Ctx->createTempSymbol();
    MCSymbol *End = C.Ctx->createTempSymbol();
    const MCExpr *Delta =
        MCBinaryExpr::createSub(MCSymbolRefExpr::create(End, *C.Ctx),
                                MCSymbolRefExpr::create(Begin, *C.Ctx), *C.Ctx);
    C.Streamer->emitWinEHCompressedValue(MCBinaryExpr::createAdd(
        Delta, MCConstantExpr::create(Value, *C.Ctx), *C.Ctx));
    C.Streamer->emitLabel(Begin);
    C.Streamer->emitLabel(End);
  }
  C.Streamer->finish();

  std::unique_ptr<MemoryBuffer> Buffer = MemoryBuffer::getMemBuffer(
      ObjectBytes.str(), "", /*RequiresNullTerminator=*/false);
  auto BinaryOrErr = object::createBinary(Buffer->getMemBufferRef());
  ASSERT_TRUE(static_cast<bool>(BinaryOrErr));
  auto *Object = dyn_cast<object::ObjectFile>(&**BinaryOrErr);
  ASSERT_NE(Object, nullptr);

  constexpr uint8_t Expected[] = {
      0xfe,                         // 0x7f
      0x01, 0x02,                   // 0x80
      0xfd, 0xff,                   // 0x3fff
      0x03, 0x00, 0x02,             // 0x4000
      0xfb, 0xff, 0xff,             // 0x1fffff
      0x07, 0x00, 0x00, 0x02,       // 0x200000
      0xf7, 0xff, 0xff, 0xff,       // 0xfffffff
      0x0f, 0x00, 0x00, 0x00, 0x10, // 0x10000000
  };
  for (const object::SectionRef &Section : Object->sections()) {
    auto NameOrErr = Section.getName();
    ASSERT_TRUE(static_cast<bool>(NameOrErr));
    if (*NameOrErr != ".data")
      continue;
    auto ContentsOrErr = Section.getContents();
    ASSERT_TRUE(static_cast<bool>(ContentsOrErr));
    EXPECT_EQ(arrayRefFromStringRef(*ContentsOrErr), ArrayRef(Expected));
    return;
  }
  FAIL() << ".data section was not emitted";
}

} // namespace
