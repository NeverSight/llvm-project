//===- WinEHX86State.cpp - Rewrite-owned x86 SEH states -------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "WinEHX86State.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/CodeGen/WinEHFuncInfo.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/TargetParser/Triple.h"
#include <numeric>

using namespace llvm;

void llvm::orderWinX86SEHRewriteStates(const Function &F, WinEHFuncInfo &Info) {
  const Triple &Target = F.getParent()->getTargetTriple();
  if (!F.hasFnAttribute(mc_rewrite::RewriteWinX86RegistrationStateAttribute) ||
      Target.getArch() != Triple::x86 || !Target.isWindowsMSVCEnvironment() ||
      Info.SEHUnwindMap.empty())
    return;

  // The CRT stops local unwind when the current numeric state is at or below
  // the saved state. A depth-first ordering preserves enclosing edges but can
  // reverse two sibling regions, changing setjmp/longjmp behavior. Complete
  // source scope identities also specify the ordering of those siblings.
  // Unannotated frontend graphs retain their normal numbering.
  if (llvm::any_of(Info.SEHUnwindMap,
                   [](const auto &Entry) { return !Entry.RewriteSemantic; }))
    return;
  SmallVector<unsigned, 4> Order(Info.SEHUnwindMap.size());
  std::iota(Order.begin(), Order.end(), 0);
  for (const auto &Entry : Info.SEHUnwindMap) {
    const auto &Token = *Entry.RewriteSemantic;
    if (Token.Kind != mc_rewrite::RewriteWinEHSemanticKind::SEHScope ||
        Token.Clause)
      report_fatal_error("invalid x86 SEH rewrite state identity");
  }
  auto SourceState = [&](unsigned Old) {
    return Info.SEHUnwindMap[Old].RewriteSemantic->Region;
  };
  llvm::sort(Order, [&](unsigned A, unsigned B) {
    return SourceState(A) < SourceState(B);
  });
  SmallVector<int, 4> Remap(Order.size());
  for (unsigned New = 0; New != Order.size(); ++New) {
    if (New && SourceState(Order[New - 1]) == SourceState(Order[New]))
      report_fatal_error("duplicate x86 SEH rewrite state identity");
    Remap[Order[New]] = New;
  }
  auto MapState = [&](int State) {
    if (State < 0)
      return State;
    if (unsigned(State) >= Remap.size())
      report_fatal_error("invalid x86 SEH rewrite state reference");
    return Remap[State];
  };
  SmallVector<SEHUnwindMapEntry, 4> Ordered;
  for (unsigned Old : Order) {
    auto Entry = Info.SEHUnwindMap[Old];
    Entry.ToState = MapState(Entry.ToState);
    if (Entry.ToState >= int(Ordered.size()))
      report_fatal_error(
          "x86 SEH rewrite enclosing state must precede its scope");
    Ordered.push_back(std::move(Entry));
  }
  for (auto &[Pad, State] : Info.EHPadStateMap)
    State = MapState(State);
  for (auto &[Pad, State] : Info.FuncletBaseStateMap)
    State = MapState(State);
  Info.SEHUnwindMap = std::move(Ordered);
}
