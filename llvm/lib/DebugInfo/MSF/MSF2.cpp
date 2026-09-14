//===- MSF2.cpp - PDB 2.00 JG / MSF 2.00 container ------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/DebugInfo/MSF/MSF2.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Twine.h"
#include "llvm/DebugInfo/MSF/MSFError.h"
#include "llvm/Support/BinaryStream.h"
#include "llvm/Support/BinaryStreamReader.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/Error.h"
#include <algorithm>
#include <cstring>

using namespace llvm;
using namespace llvm::msf;
using llvm::support::ulittle32_t;

static Error jgError(const Twine &Message) {
  return make_error<MSFError>(msf_error_code::invalid_format, Message);
}

Error llvm::msf::parseJgMsf(BinaryStream &Buffer, BumpPtrAllocator &Alloc,
                            MSFLayout &Layout) {
  BinaryStreamReader Reader(Buffer);
  const SuperBlockJG *JG = nullptr;
  if (auto EC = Reader.readObject(JG))
    return joinErrors(std::move(EC), jgError("JG superblock is missing"));

  if (std::memcmp(JG->Magic, MagicJG, sizeof(MagicJG)) != 0)
    return jgError("JG magic header doesn't match");
  if (!isValidBlockSize(JG->BlockSize))
    return jgError("Unsupported JG block size");
  if (JG->BlockCount == 0)
    return jgError("JG block count is zero");
  if (JG->DirectoryBytes == 0)
    return jgError("JG directory is empty");

  const uint32_t BlockSize = JG->BlockSize;
  const uint32_t NumBlocks = JG->BlockCount;
  const uint64_t FileSize = Buffer.getLength();
  if (FileSize < (uint64_t)NumBlocks * BlockSize &&
      FileSize < BlockSize)
    return jgError("JG file is smaller than one block");

  const uint32_t NumDirBlocks =
      static_cast<uint32_t>(bytesToBlocks(JG->DirectoryBytes, BlockSize));
  if (NumDirBlocks == 0)
    return jgError("JG directory block count is zero");

  const uint64_t DirListBytes = (uint64_t)NumDirBlocks * sizeof(uint16_t);
  if (sizeof(SuperBlockJG) + DirListBytes > FileSize)
    return jgError("JG directory page list overruns the file");

  SmallVector<uint16_t, 16> DirPages16;
  DirPages16.resize(NumDirBlocks);
  Reader.setOffset(sizeof(SuperBlockJG));
  for (uint32_t I = 0; I < NumDirBlocks; ++I) {
    uint16_t Page = 0;
    if (auto EC = Reader.readInteger(Page))
      return EC;
    if (Page >= NumBlocks)
      return jgError("JG directory page is out of range");
    DirPages16[I] = Page;
  }

  auto *SB = Alloc.Allocate<SuperBlock>();
  std::memset(SB, 0, sizeof(*SB));
  std::memcpy(SB->MagicBytes, Magic, sizeof(Magic));
  SB->BlockSize = BlockSize;
  SB->FreeBlockMapBlock = 1;
  SB->NumBlocks = NumBlocks;
  SB->NumDirectoryBytes = JG->DirectoryBytes;
  SB->Unknown1 = JG->Reserved;
  SB->BlockMapAddr = 1;
  Layout.SB = SB;

  auto *Dir32 = Alloc.Allocate<ulittle32_t>(NumDirBlocks);
  for (uint32_t I = 0; I < NumDirBlocks; ++I)
    Dir32[I] = DirPages16[I];
  Layout.DirectoryBlocks = ArrayRef(Dir32, NumDirBlocks);

  std::vector<uint8_t> Directory;
  Directory.resize(JG->DirectoryBytes);
  uint32_t Copied = 0;
  for (uint16_t Page : DirPages16) {
    const uint64_t Off = (uint64_t)Page * BlockSize;
    const uint32_t Chunk =
        std::min<uint32_t>(BlockSize, JG->DirectoryBytes - Copied);
    if (Off + Chunk > FileSize)
      return jgError("JG directory page overruns the file");
    ArrayRef<uint8_t> Bytes;
    if (auto EC = Buffer.readBytes(Off, Chunk, Bytes))
      return EC;
    std::memcpy(Directory.data() + Copied, Bytes.data(), Chunk);
    Copied += Chunk;
  }

  if (Directory.size() < 4)
    return jgError("JG directory is truncated");

  const uint16_t NumStreams =
      support::endian::read16le(Directory.data());
  uint32_t Cursor = 4;
  const uint64_t TableBytes = (uint64_t)NumStreams * 8;
  if (Cursor + TableBytes > Directory.size())
    return jgError("JG stream size table overruns the directory");

  auto *Sizes = Alloc.Allocate<ulittle32_t>(static_cast<size_t>(NumStreams));
  SmallVector<uint32_t, 8> RawSizes;
  RawSizes.resize(NumStreams);
  for (uint32_t I = 0; I < NumStreams; ++I) {
    uint32_t Size =
        support::endian::read32le(Directory.data() + Cursor);
    Cursor += 8; // size + unused pointer
    if (Size == UINT32_MAX)
      Size = 0;
    RawSizes[I] = Size;
    Sizes[I] = Size;
  }
  Layout.StreamSizes = ArrayRef(Sizes, NumStreams);
  Layout.StreamMap.clear();
  Layout.StreamMap.reserve(NumStreams);

  for (uint32_t I = 0; I < NumStreams; ++I) {
    const uint32_t NumStreamBlocks =
        RawSizes[I] == 0
            ? 0
            : static_cast<uint32_t>(bytesToBlocks(RawSizes[I], BlockSize));
    if (Cursor + NumStreamBlocks * 2 > Directory.size())
      return jgError("JG stream block map overruns the directory");
    auto *Blocks = Alloc.Allocate<ulittle32_t>(
        std::max<uint32_t>(NumStreamBlocks, 1));
    for (uint32_t B = 0; B < NumStreamBlocks; ++B) {
      const uint16_t Page =
          support::endian::read16le(Directory.data() + Cursor);
      Cursor += 2;
      if (Page >= NumBlocks)
        return jgError("JG stream page is out of range");
      const uint64_t End = (uint64_t)(Page + 1) * BlockSize;
      if (End > FileSize)
        return jgError("JG stream page overruns the file");
      Blocks[B] = Page;
    }
    Layout.StreamMap.push_back(ArrayRef(Blocks, NumStreamBlocks));
  }

  return Error::success();
}
