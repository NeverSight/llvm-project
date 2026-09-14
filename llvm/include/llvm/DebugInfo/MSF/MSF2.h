//===- MSF2.h - PDB 2.00 JG / MSF 2.00 container ----------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// VC6 wrote "Microsoft C/C++ program database 2.00" JG files.  The on-disk
/// directory uses 16-bit page numbers.  This parser widens that layout into
/// the MSF 7 \c MSFLayout used by MappedBlockStream so the rest of the native
/// PDB reader can address individual streams.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_DEBUGINFO_MSF_MSF2_H
#define LLVM_DEBUGINFO_MSF_MSF2_H

#include "llvm/ADT/StringRef.h"
#include "llvm/DebugInfo/MSF/MSFCommon.h"
#include "llvm/Support/Allocator.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/Error.h"

namespace llvm {
class BinaryStream;
class StringRef;

namespace msf {

struct SuperBlockJG {
  char Magic[sizeof(MagicJG)];
  support::ulittle32_t BlockSize;
  support::ulittle16_t FreePageMap;
  support::ulittle16_t BlockCount;
  support::ulittle32_t DirectoryBytes;
  support::ulittle32_t Reserved;
};
static_assert(sizeof(SuperBlockJG) == 60, "JG superblock must be 60 bytes");

inline bool isJgMsfMagic(StringRef Bytes) {
  return Bytes.starts_with(StringRef(MagicJG, sizeof(MagicJG)));
}

/// Parse a JG/MSF 2.00 file into an MSF 7-shaped layout.  SuperBlock, stream
/// sizes, and block lists are allocated on \p Alloc.  Free-page-map bits are
/// left empty; they are not required to read streams.
LLVM_ABI Error parseJgMsf(BinaryStream &Buffer, BumpPtrAllocator &Alloc,
                          MSFLayout &Layout);

} // namespace msf
} // namespace llvm

#endif // LLVM_DEBUGINFO_MSF_MSF2_H
