//===- WinX86SEHStateWrite.cpp - SEH state write provenance --------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/STLExtras.h"
#include "llvm/MC/BinaryRewrite.h"
#include "llvm/Support/MathExtras.h"
#include <map>
#include <set>
#include <tuple>

using namespace llvm;
using namespace llvm::mc_rewrite;

bool llvm::mc_rewrite::validateRewriteWinX86SEHStateWrites(
    ArrayRef<RewriteWinX86SEHFrame> Frames,
    ArrayRef<RewriteWinX86SEHStateWrite> Writes,
    ArrayRef<RewriteWinEHSemanticRecord> Records,
    ArrayRef<RewriteSourceFunctionOwner> SourceOwners,
    ArrayRef<RewriteFunctionRange> FunctionRanges,
    const std::map<std::string, uint64_t> &FunctionOwnerAddrs,
    bool ValidateGlobalFunctionRangeOverlap) {
  if (Frames.empty() && Writes.empty())
    return true;
  if (!validateRewriteSourceFunctionOwners(SourceOwners) ||
      !validateRewriteFunctionRanges(FunctionRanges, FunctionOwnerAddrs,
                                     ValidateGlobalFunctionRangeOverlap) ||
      !validateRewriteWinEHSemanticRecords(Records, SourceOwners,
                                           FunctionRanges, FunctionOwnerAddrs,
                                           ValidateGlobalFunctionRangeOverlap))
    return false;

  auto HasSourceOwner = [&](StringRef SourceFunction, StringRef OwnerSymbol,
                            uint64_t OwnerVA) {
    return llvm::any_of(SourceOwners, [&](const auto &Owner) {
      return Owner.SourceFunction == SourceFunction &&
             Owner.OwnerSymbol == OwnerSymbol && Owner.OwnerVA == OwnerVA &&
             Owner.Kind == RewriteSourceFunctionOwnerKind::FunctionEntry;
    });
  };
  std::map<StringRef, const RewriteWinX86SEHFrame *> ParentFrames;
  for (const RewriteWinX86SEHFrame &Frame : Frames) {
    if (Frame.SourceFunction.empty() || Frame.OwnerSymbol.empty() ||
        (Frame.Encoding != RewriteWinEHSemanticEncoding::X86SEH3 &&
         Frame.Encoding != RewriteWinEHSemanticEncoding::X86SEH4) ||
        Frame.RegistrationSize != 24 || Frame.StateOffset != 20 ||
        Frame.RegistrationOffset % 4 ||
        !isInt<32>(int64_t(Frame.RegistrationOffset) + Frame.StateOffset) ||
        !isInt<32>(int64_t(Frame.RegistrationOffset) + Frame.RegistrationSize -
                   1) ||
        !HasSourceOwner(Frame.SourceFunction, Frame.OwnerSymbol,
                        Frame.OwnerVA) ||
        !ParentFrames.emplace(Frame.OwnerSymbol, &Frame).second)
      return false;
    bool HasScope = false;
    for (const RewriteWinEHSemanticRecord &Record : Records) {
      if (Record.OwnerSymbol != Frame.OwnerSymbol)
        continue;
      if (Record.SourceFunction != Frame.SourceFunction ||
          Record.OwnerVA != Frame.OwnerVA ||
          Record.Encoding != Frame.Encoding ||
          Record.Token.Kind != RewriteWinEHSemanticKind::SEHScope)
        return false;
      HasScope = true;
    }
    if (!HasScope)
      return false;
  }

  std::set<std::pair<StringRef, uint64_t>> WriteIDs;
  std::set<std::tuple<StringRef, uint64_t, uint64_t>> Extents;
  for (const RewriteWinX86SEHStateWrite &Write : Writes) {
    const auto Parent = ParentFrames.find(Write.ParentFrame.OwnerSymbol);
    if (!Write.WriteID || Write.AddressRegister > 7 ||
        Write.SourceFunction.empty() || Write.OwnerSymbol.empty() ||
        Write.BeginSymbol.empty() || Write.EndSymbol.empty() ||
        Write.BeginVA >= Write.EndVA ||
        Write.OwnerSymbol == Write.ParentFrame.OwnerSymbol ||
        !HasSourceOwner(Write.SourceFunction, Write.OwnerSymbol,
                        Write.OwnerVA) ||
        Parent == ParentFrames.end() ||
        !(*Parent->second == Write.ParentFrame) ||
        !WriteIDs.emplace(Write.OwnerSymbol, Write.WriteID).second ||
        !Extents.emplace(Write.OwnerSymbol, Write.BeginVA, Write.EndVA).second)
      return false;
    if (!llvm::any_of(FunctionRanges, [&](const RewriteFunctionRange &Range) {
          return Range.OwnerSymbol == Write.OwnerSymbol &&
                 Range.OwnerVA == Write.OwnerVA &&
                 Range.ParentOwnerSymbol.empty() &&
                 Range.BeginVA <= Write.BeginVA && Write.EndVA <= Range.EndVA;
        }))
      return false;

    if (!Write.Semantic) {
      const int32_t BaseState =
          Write.ParentFrame.Encoding == RewriteWinEHSemanticEncoding::X86SEH4
              ? -2
              : -1;
      if (Write.GeneratedState != BaseState)
        return false;
      continue;
    }
    if (Write.GeneratedState < 0 ||
        Write.Semantic->Kind != RewriteWinEHSemanticKind::SEHScope ||
        Write.Semantic->Clause != 0)
      return false;
    unsigned MatchingRows = 0;
    for (const RewriteWinEHSemanticRecord &Record : Records)
      if (Record.SourceFunction == Write.ParentFrame.SourceFunction &&
          Record.OwnerSymbol == Write.ParentFrame.OwnerSymbol &&
          Record.OwnerVA == Write.ParentFrame.OwnerVA &&
          Record.Encoding == Write.ParentFrame.Encoding &&
          Record.Token == *Write.Semantic &&
          Record.GeneratedState == uint32_t(Write.GeneratedState))
        ++MatchingRows;
    if (MatchingRows != 1)
      return false;
  }

  // Two independently authenticated writes cannot claim the same instruction
  // bytes, even if they use different source occurrence IDs.
  for (auto I = Extents.begin(); I != Extents.end();) {
    auto Previous = I++;
    if (I != Extents.end() && std::get<0>(*Previous) == std::get<0>(*I) &&
        std::get<2>(*Previous) > std::get<1>(*I))
      return false;
  }
  return true;
}
