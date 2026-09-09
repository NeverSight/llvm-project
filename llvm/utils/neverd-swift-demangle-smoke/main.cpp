//===- main.cpp - Installed Swift demangling package smoke ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
// This consumer uses only installed public LLVM headers and exported targets.
#include "llvm/Demangle/SwiftDemangle.h"

#include <cstdlib>
#include <iostream>
#include <string>
#include <string_view>

namespace {
void require(bool Condition, std::string_view Message) {
  if (!Condition) {
    std::cerr << "Swift demangling package smoke failed: " << Message << '\n';
    std::exit(1);
  }
}

bool contains(const llvm::SwiftDemangleNode &Node, std::string_view Kind,
              std::string_view Text = {}) {
  if (Node.Kind == Kind && (Text.empty() || (Node.Text && *Node.Text == Text)))
    return true;
  for (const auto &Child : Node.Children)
    if (contains(Child, Kind, Text))
      return true;
  return false;
}

void rejects(std::string_view Symbol,
             const llvm::SwiftDemangleOptions &Options = {}) {
  const auto Result = llvm::swiftDemangle(Symbol, Options);
  require(!Result.Root, "invalid or over-budget input produced a tree");
  require(!Result.Error.empty(), "rejected input has no diagnostic");
}
} // namespace

int main() {
  const char *Path = std::getenv("PATH");
  require(!Path || !*Path, "CTest must clear PATH for the runtime probe");
  const char *LegacyTool = std::getenv("NEVERD_SWIFT_DEMANGLE");
  require(LegacyTool && *LegacyTool,
          "CTest must supply the invalid legacy demangler setting");
  const char *Version = llvm::swiftDemangleVersion();
  require(Version && std::string_view(Version) == "6.3.3",
          "installed upstream demangler version changed");
  // The name comes from an independently compiled foo(Int32) -> Int32 fixture.
  // Cover both ELF-style and Mach-O-style symbol prefixes without a Swift tool.
  for (const auto Symbol :
       {"$s4main3fooys5Int32VADF", "_$s4main3fooys5Int32VADF"}) {
    const auto Result = llvm::swiftDemangle(Symbol);
    require(Result.Error.empty(), "valid symbol returned an error");
    require(Result.Root.has_value(), "valid symbol produced no tree");
    require(Result.Root->Kind == "Global", "unexpected public root kind");
    require(contains(*Result.Root, "Function"),
            "function declaration is missing");
    require(contains(*Result.Root, "Module", "main"),
            "module identity changed");
    require(contains(*Result.Root, "Identifier", "foo"),
            "function identity changed");
    require(contains(*Result.Root, "Identifier", "Int32"),
            "scalar type identity changed");
  }

  for (const auto Symbol : {"", "plain_symbol_without_mangling", "$s"})
    rejects(Symbol);
  constexpr std::string_view Valid = "$s4main3fooys5Int32VADF";
  llvm::SwiftDemangleOptions InputLimit;
  InputLimit.MaxInputBytes = Valid.size() - 1;
  rejects(Valid, InputLimit);
  llvm::SwiftDemangleOptions Defaults;
  rejects("$s" + std::string(Defaults.MaxInputBytes, 'a'));
  llvm::SwiftDemangleOptions NodeLimit;
  NodeLimit.MaxNodes = 1;
  rejects(Valid, NodeLimit);
  llvm::SwiftDemangleOptions DepthLimit;
  DepthLimit.MaxDepth = 1;
  rejects(Valid, DepthLimit);

  std::cout << "Installed LLVMSwiftDemangle 6.3.3: structured signatures and "
               "bounded rejection passed\n";
  return 0;
}
