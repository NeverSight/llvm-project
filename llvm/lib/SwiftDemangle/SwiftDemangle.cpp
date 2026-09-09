//===-- SwiftDemangle.cpp - Structured Swift demangling
//--------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Demangle/SwiftDemangle.h"
#include "SwiftDemangleBudget.h"
#include "swift/Demangling/Demangle.h"
#include <exception>

namespace llvm::swift_demangle_detail {
thread_local Budget *CurrentBudget = nullptr;
} // namespace llvm::swift_demangle_detail

namespace {
using namespace llvm;
using namespace llvm::swift_demangle_detail;

SwiftDemangleNode copyTree(swift::Demangle::NodePointer Root, Budget &Limits) {
  struct Frame {
    swift::Demangle::NodePointer Input;
    SwiftDemangleNode *Output;
    size_t Depth;
    size_t Child = 0;
    bool Initialized = false;
  };
  SwiftDemangleNode Result;
  Vector<Frame> Stack;
  Stack.push_back({Root, &Result, 1});
  size_t AllocatedNodes = 1;
  Limits.memory(sizeof(Result));
  while (!Stack.empty()) {
    Limits.work();
    Frame &Current = Stack.back();
    if (!Current.Initialized) {
      if (Current.Depth > Limits.Options.MaxDepth)
        throw LimitError{"Swift demangler tree depth limit exceeded"};
      auto *Input = Current.Input;
      if (!Input || Input->hasRemoteAddress())
        throw LimitError{"Swift demangler unsupported symbolic reference"};
      auto &Output = *Current.Output;
      Output.Kind =
          copyString(swift::Demangle::getNodeKindString(Input->getKind()));
      if (Input->hasText())
        Output.Text = copyString(std::string_view(Input->getText()));
      if (Input->hasIndex())
        Output.Index = Input->getIndex();
      size_t Children = Input->getNumChildren();
      if (Children > Limits.Options.MaxNodes - AllocatedNodes)
        throw LimitError{"Swift demangler tree node limit exceeded"};
      AllocatedNodes += Children;
      Limits.memory(checkedSize(Children, sizeof(SwiftDemangleNode)));
      Output.Children.resize(Children);
      Current.Initialized = true;
    }
    if (Current.Child == Current.Output->Children.size()) {
      Stack.pop_back();
      continue;
    }
    size_t ChildIndex = Current.Child++;
    Frame Child{Current.Input->getChild(ChildIndex),
                &Current.Output->Children[ChildIndex], Current.Depth + 1};
    Stack.push_back(Child);
  }
  return Result;
}
} // namespace

llvm::SwiftDemangleResult
llvm::swiftDemangle(std::string_view Name,
                    const SwiftDemangleOptions &Options) {
  if (Name.empty())
    return {std::nullopt, "empty Swift mangled symbol"};
  if (Name.size() > Options.MaxInputBytes)
    return {std::nullopt, "Swift demangler input byte limit exceeded"};
  if (!Options.MaxNodes || !Options.MaxDepth || Options.MaxDepth > 256 ||
      !Options.MaxMemoryBytes || !Options.MaxOperations)
    return {std::nullopt, "invalid Swift demangler resource limits"};
  if (Name.size() > Options.MaxOperations)
    return {std::nullopt, "Swift demangler operation limit exceeded"};
  // Runtime symbolic references contain control bytes and require access to
  // another binary's address space. This API accepts symbol-table names only.
  for (unsigned char Character : Name)
    if (Character < 0x20 || Character == 0x7f)
      return {std::nullopt, "Swift symbol contains NUL or control bytes"};
  try {
    Budget Limits{Options};
    BudgetScope Scope(Limits);
    Limits.work(Name.size());
    swift::Demangle::Context Context;
    auto *Root = Context.demangleSymbolAsNode(llvm::StringRef(Name));
    if (!Root)
      return {std::nullopt, "invalid Swift mangled symbol"};
    return {copyTree(Root, Limits), {}};
  } catch (const LimitError &Error) {
    return {std::nullopt, Error.Message};
  } catch (const std::bad_alloc &) {
    return {std::nullopt, "Swift demangler allocation failed"};
  } catch (const std::exception &) {
    return {std::nullopt, "Swift demangler failed"};
  } catch (...) {
    return {std::nullopt, "Swift demangler failed"};
  }
}

const char *llvm::swiftDemangleVersion() { return "6.3.3"; }
