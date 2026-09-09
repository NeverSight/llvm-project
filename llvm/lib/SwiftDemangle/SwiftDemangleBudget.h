//===-- SwiftDemangleBudget.h - Private parser resource accounting --------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_SWIFTDEMANGLE_BUDGET_H
#define LLVM_LIB_SWIFTDEMANGLE_BUDGET_H

#include "llvm/Demangle/SwiftDemangle.h"
#include <algorithm>
#include <limits>
#include <memory>
#include <new>
#include <unordered_map>

namespace llvm::swift_demangle_detail {

struct LimitError {
  const char *Message;
};

inline size_t checkedSize(size_t Count, size_t Width) {
  if (Count > std::numeric_limits<size_t>::max() / Width)
    throw LimitError{"Swift demangler allocation size overflow"};
  return Count * Width;
}

struct Budget {
  const SwiftDemangleOptions &Options;
  size_t Bytes = 0;
  size_t Operations = 0;
  size_t ParserNodes = 0;
  size_t ParserDepth = 0;

  void work(size_t Count = 1) {
    if (Count > Options.MaxOperations - Operations)
      throw LimitError{"Swift demangler operation limit exceeded"};
    Operations += Count;
  }

  void memory(size_t Count) {
    if (Count > Options.MaxMemoryBytes - Bytes)
      throw LimitError{"Swift demangler memory limit exceeded"};
    Bytes += Count;
  }

  void node() {
    work();
    if (ParserNodes == Options.MaxNodes)
      throw LimitError{"Swift demangler parser node limit exceeded"};
    ++ParserNodes;
  }

  void enter() {
    work();
    // Parser helper frames do not correspond one-to-one to output nodes.
    // Keep their independent stack bound finite even for a caller that allows
    // a larger owning tree. Output depth is checked separately and exactly.
    size_t Limit = std::min<size_t>(512, Options.MaxDepth * 4 + 32);
    if (ParserDepth == Limit)
      throw LimitError{"Swift demangler parser recursion limit exceeded"};
    ++ParserDepth;
  }
};

extern thread_local Budget *CurrentBudget;

inline void work(size_t Count = 1) {
  if (CurrentBudget)
    CurrentBudget->work(Count);
}

inline void memory(size_t Count) {
  if (CurrentBudget)
    CurrentBudget->memory(Count);
}

inline void parserNode() {
  if (CurrentBudget)
    CurrentBudget->node();
}

class ParserScope {
  Budget *Active = CurrentBudget;

public:
  ParserScope() {
    if (Active)
      Active->enter();
  }
  ~ParserScope() {
    if (Active)
      --Active->ParserDepth;
  }
};

class BudgetScope {
  Budget *Previous = CurrentBudget;

public:
  explicit BudgetScope(Budget &Active) { CurrentBudget = &Active; }
  ~BudgetScope() { CurrentBudget = Previous; }
};

/// Standard containers used by parser and remangling helpers charge each
/// actual allocation before it is attempted. Deallocation does not refund the
/// conservative cumulative budget.
template <class T> struct Allocator {
  using value_type = T;
  Allocator() = default;
  template <class U> Allocator(const Allocator<U> &) {}
  T *allocate(size_t Count) {
    work();
    memory(checkedSize(Count, sizeof(T)));
    return std::allocator<T>{}.allocate(Count);
  }
  void deallocate(T *Pointer, size_t Count) {
    std::allocator<T>{}.deallocate(Pointer, Count);
  }
  template <class U> bool operator==(const Allocator<U> &) const {
    return true;
  }
};

template <class T> using Vector = std::vector<T, Allocator<T>>;
template <class K, class V, class Hash = std::hash<K>>
using UnorderedMap = std::unordered_map<K, V, Hash, std::equal_to<K>,
                                        Allocator<std::pair<const K, V>>>;

inline void reserveString(std::string &String, size_t Capacity) {
  if (Capacity <= String.capacity())
    return;
  // Account for a conservative upper bound on the implementation's growth,
  // plus the NUL byte, before std::string is allowed to allocate.
  size_t Requested = std::max(Capacity, checkedSize(String.capacity(), 2));
  if (Requested == std::numeric_limits<size_t>::max())
    throw LimitError{"Swift demangler string size overflow"};
  memory(checkedSize(Requested + 1, 2));
  String.reserve(Requested);
}

template <class T> void appendChar(std::string &String, T Character) {
  work();
  if (String.size() == std::numeric_limits<size_t>::max())
    throw LimitError{"Swift demangler string size overflow"};
  reserveString(String, String.size() + 1);
  String.push_back(static_cast<char>(Character));
}

inline void appendString(std::string &String, std::string_view Suffix) {
  work(Suffix.size());
  if (Suffix.size() > std::numeric_limits<size_t>::max() - String.size())
    throw LimitError{"Swift demangler string size overflow"};
  reserveString(String, String.size() + Suffix.size());
  String.append(Suffix.data(), Suffix.size());
}

inline std::string copyString(std::string_view String) {
  if (String.size() == std::numeric_limits<size_t>::max())
    throw LimitError{"Swift demangler string size overflow"};
  work(String.size());
  memory(checkedSize(String.size() + 1, 2));
  return std::string(String);
}

} // namespace llvm::swift_demangle_detail

#endif
