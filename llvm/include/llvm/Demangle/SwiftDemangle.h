//===-- SwiftDemangle.h - Structured Swift symbol demangling ------*- C++
//-*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_DEMANGLE_SWIFTDEMANGLE_H
#define LLVM_DEMANGLE_SWIFTDEMANGLE_H

#include "llvm/Support/Compiler.h"
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace llvm {

/// An owning copy of a Swift demangling node. Kind names follow the pinned
/// Swift demangler version; unknown language constructs remain explicit nodes.
struct SwiftDemangleNode {
  std::string Kind;
  std::optional<std::string> Text;
  std::optional<uint64_t> Index;
  std::vector<SwiftDemangleNode> Children;
};

struct SwiftDemangleOptions {
  size_t MaxInputBytes = 8000;
  size_t MaxNodes = 10000;
  /// Output tree depth, from 1 through 256. Parser recursion is also bounded.
  size_t MaxDepth = 64;
  /// Conservative cumulative parser and returned-tree allocation budget.
  size_t MaxMemoryBytes = 16 * 1024 * 1024;
  /// Parser work and returned-tree traversal budget.
  size_t MaxOperations = 1000000;
};

struct SwiftDemangleResult {
  std::optional<SwiftDemangleNode> Root;
  std::string Error;
};

/// Demangle one symbol without external tools or a Swift runtime. An invalid
/// symbol or exceeded resource limit returns no Root and a nonempty Error.
/// No pointers into the input or the demangler survive this call.
LLVM_ABI SwiftDemangleResult swiftDemangle(
    std::string_view MangledName, const SwiftDemangleOptions &Options = {});

/// Version of the bundled Swift demangling grammar.
LLVM_ABI const char *swiftDemangleVersion();

} // namespace llvm

#endif
