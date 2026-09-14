//===- MSF2Test.cpp - PDB 2.00 JG container tests -------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/DebugInfo/MSF/MSF2.h"
#include "llvm/Support/Allocator.h"
#include "llvm/Support/BinaryByteStream.h"
#include "llvm/Support/Endian.h"
#include "llvm/Testing/Support/Error.h"
#include "gtest/gtest.h"

#include <cstring>
#include <vector>

using namespace llvm;
using namespace llvm::msf;

namespace {

void appendU16(std::vector<uint8_t> &Out, uint16_t Value) {
  Out.push_back(static_cast<uint8_t>(Value));
  Out.push_back(static_cast<uint8_t>(Value >> 8));
}

void appendU32(std::vector<uint8_t> &Out, uint32_t Value) {
  Out.push_back(static_cast<uint8_t>(Value));
  Out.push_back(static_cast<uint8_t>(Value >> 8));
  Out.push_back(static_cast<uint8_t>(Value >> 16));
  Out.push_back(static_cast<uint8_t>(Value >> 24));
}

std::vector<uint8_t> writeTinyJg() {
  constexpr uint32_t BlockSize = 512;
  // stream 0 empty, stream 1 = "INFO"
  const uint8_t Info[] = {'I', 'N', 'F', 'O'};
  std::vector<uint8_t> Root;
  appendU16(Root, 2);
  appendU16(Root, 0);
  appendU32(Root, 0);
  appendU32(Root, 0);
  appendU32(Root, 4);
  appendU32(Root, 0);
  appendU16(Root, 1); // stream 1 lives on page 1

  const uint16_t RootPage = 2;
  const uint16_t NumPages = 3;
  std::vector<uint8_t> File(NumPages * BlockSize, 0);
  std::memcpy(File.data(), MagicJG, sizeof(MagicJG));
  std::memcpy(File.data() + 44, &BlockSize, 4);
  const uint16_t FreePage = 1;
  std::memcpy(File.data() + 48, &FreePage, 2);
  std::memcpy(File.data() + 50, &NumPages, 2);
  const uint32_t RootSize = static_cast<uint32_t>(Root.size());
  std::memcpy(File.data() + 52, &RootSize, 4);
  std::memcpy(File.data() + 60, &RootPage, 2);
  std::memcpy(File.data() + BlockSize, Info, sizeof(Info));
  std::memcpy(File.data() + 2 * BlockSize, Root.data(), Root.size());
  return File;
}

TEST(MSF2, ParsesJgDirectoryAndWidensPages) {
  std::vector<uint8_t> Bytes = writeTinyJg();
  BinaryByteStream Stream(Bytes, llvm::endianness::little);
  BumpPtrAllocator Alloc;
  MSFLayout Layout;
  ASSERT_THAT_ERROR(parseJgMsf(Stream, Alloc, Layout), Succeeded());
  ASSERT_NE(Layout.SB, nullptr);
  EXPECT_EQ(512u, uint32_t(Layout.SB->BlockSize));
  ASSERT_EQ(2u, Layout.StreamSizes.size());
  EXPECT_EQ(0u, uint32_t(Layout.StreamSizes[0]));
  EXPECT_EQ(4u, uint32_t(Layout.StreamSizes[1]));
  ASSERT_EQ(2u, Layout.StreamMap.size());
  EXPECT_TRUE(Layout.StreamMap[0].empty());
  ASSERT_EQ(1u, Layout.StreamMap[1].size());
  EXPECT_EQ(1u, uint32_t(Layout.StreamMap[1][0]));
}

TEST(MSF2, RejectsMsf7Magic) {
  std::vector<uint8_t> Bytes(64, 0);
  std::memcpy(Bytes.data(), Magic, sizeof(Magic));
  BinaryByteStream Stream(Bytes, llvm::endianness::little);
  BumpPtrAllocator Alloc;
  MSFLayout Layout;
  EXPECT_THAT_ERROR(parseJgMsf(Stream, Alloc, Layout), Failed());
}

} // namespace
