//===-- SwiftDemangleTest.cpp
//----------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Demangle/SwiftDemangle.h"
#include "gtest/gtest.h"
#include <atomic>
#include <thread>

using namespace llvm;

namespace {
const SwiftDemangleNode *findNode(const SwiftDemangleNode &Root,
                                  std::string_view Kind) {
  if (Root.Kind == Kind)
    return &Root;
  for (const auto &Child : Root.Children)
    if (auto *Found = findNode(Child, Kind))
      return Found;
  return nullptr;
}

std::string arrayType(size_t Count) {
  std::string Name = "$s";
  for (size_t Index = 0; Index < Count; ++Index)
    Name += "Say";
  Name += "Si";
  Name.append(Count, 'G');
  Name += 'D';
  return Name;
}
} // namespace

TEST(SwiftDemangle, ReturnsOwningFunctionTree) {
  std::string Symbol = "_$s4main3fooys5Int32VADF";
  auto Result = swiftDemangle(Symbol);
  Symbol.clear();
  ASSERT_TRUE(Result.Root) << Result.Error;
  EXPECT_TRUE(Result.Error.empty());
  EXPECT_EQ(Result.Root->Kind, "Global");
  ASSERT_EQ(Result.Root->Children.size(), 1u);
  const auto &Function = Result.Root->Children[0];
  EXPECT_EQ(Function.Kind, "Function");
  ASSERT_EQ(Function.Children.size(), 4u);
  EXPECT_EQ(Function.Children[0].Kind, "Module");
  EXPECT_EQ(Function.Children[0].Text, "main");
  EXPECT_EQ(Function.Children[1].Kind, "Identifier");
  EXPECT_EQ(Function.Children[1].Text, "foo");
  EXPECT_EQ(Function.Children[2].Kind, "LabelList");
  EXPECT_EQ(Function.Children[3].Kind, "Type");
}

TEST(SwiftDemangle, EnforcesParserAllocationBudget) {
  SwiftDemangleOptions Options;
  Options.MaxMemoryBytes = 64;
  auto Result = swiftDemangle("_$s4main3fooys5Int32VADF", Options);
  EXPECT_FALSE(Result.Root);
  EXPECT_NE(Result.Error.find("memory"), std::string::npos);
}

TEST(SwiftDemangle, SupportsBothSymbolPrefixesAndReportsVersion) {
  EXPECT_STREQ(swiftDemangleVersion(), "6.3.3");
  for (const char *Name :
       {"$s4main3fooys5Int32VADF", "_$s4main3fooys5Int32VADF"}) {
    auto Result = swiftDemangle(Name);
    ASSERT_TRUE(Result.Root) << Result.Error;
    EXPECT_EQ(Result.Root->Kind, "Global");
    EXPECT_NE(findNode(*Result.Root, "FunctionType"), nullptr);
  }
}

TEST(SwiftDemangle, PreservesGenericAndIndexInformation) {
  auto Result = swiftDemangle("$s4main2idyxxlF");
  ASSERT_TRUE(Result.Root) << Result.Error;
  auto *Parameter = findNode(*Result.Root, "DependentGenericParamCount");
  ASSERT_NE(Parameter, nullptr);
  EXPECT_EQ(Parameter->Index, 1u);
  EXPECT_NE(findNode(*Result.Root, "DependentGenericParamType"), nullptr);
}

TEST(SwiftDemangle, PreservesMetadataAndLegacyNominalNames) {
  auto Metadata = swiftDemangle("$sSiN");
  ASSERT_TRUE(Metadata.Root) << Metadata.Error;
  EXPECT_NE(findNode(*Metadata.Root, "TypeMetadata"), nullptr);
  auto Legacy = swiftDemangle("_TtC4main3Foo");
  ASSERT_TRUE(Legacy.Root) << Legacy.Error;
  auto *Class = findNode(*Legacy.Root, "Class");
  ASSERT_NE(Class, nullptr);
  ASSERT_EQ(Class->Children.size(), 2u);
  EXPECT_EQ(Class->Children[1].Text, "Foo");
}

TEST(SwiftDemangle, RejectsInvalidTruncatedAndRuntimeReferences) {
  // The last input declares a four-byte identifier but supplies only three.
  // A complete identifier sequence is a parseable fragment, even without a
  // Function node; classification belongs to the caller.
  for (std::string Name : {"", "not_swift", "$s", "$s4mai"}) {
    auto Result = swiftDemangle(Name);
    EXPECT_FALSE(Result.Root) << Name;
    EXPECT_FALSE(Result.Error.empty());
  }
  std::string EmbeddedNUL = "$sSiN";
  EmbeddedNUL += '\0';
  EmbeddedNUL += "$sSiN";
  auto Result = swiftDemangle(EmbeddedNUL);
  EXPECT_FALSE(Result.Root);
  EXPECT_NE(Result.Error.find("control"), std::string::npos);
}

TEST(SwiftDemangle, RejectsOversizedInputBeforeParsing) {
  SwiftDemangleOptions Options;
  Options.MaxInputBytes = 4;
  auto Result = swiftDemangle("$sSiN", Options);
  EXPECT_FALSE(Result.Root);
  EXPECT_NE(Result.Error.find("input"), std::string::npos);
  Result = swiftDemangle(std::string(8001, 'x'));
  EXPECT_FALSE(Result.Root);
  EXPECT_NE(Result.Error.find("input"), std::string::npos);
}

TEST(SwiftDemangle, BoundsParserWorkAndResetsBudgetAfterFailure) {
  SwiftDemangleOptions Options;
  Options.MaxOperations = 32;
  auto Result = swiftDemangle("_$s4main3fooys5Int32VADF", Options);
  EXPECT_FALSE(Result.Root);
  EXPECT_NE(Result.Error.find("operation"), std::string::npos);
  Result = swiftDemangle("_$s4main3fooys5Int32VADF");
  EXPECT_TRUE(Result.Root) << Result.Error;
}

TEST(SwiftDemangle, BoundsParserNodeAllocation) {
  SwiftDemangleOptions Options;
  Options.MaxNodes = 1;
  auto Result = swiftDemangle("$sSiN", Options);
  EXPECT_FALSE(Result.Root);
  EXPECT_NE(Result.Error.find("parser node"), std::string::npos);
}

TEST(SwiftDemangle, BoundsExpandedTreeBeforeAllocatingItsChildren) {
  // Standard-substitution repetition creates a shared parser DAG. The owning
  // output expands each occurrence, so a parser-node limit alone is inadequate.
  const char *Name = "$sS128iD";
  auto Complete = swiftDemangle(Name);
  ASSERT_TRUE(Complete.Root) << Complete.Error;
  ASSERT_GE(Complete.Root->Children.size(), 100u);
  SwiftDemangleOptions Options;
  Options.MaxNodes = 32;
  auto Result = swiftDemangle(Name, Options);
  EXPECT_FALSE(Result.Root);
  EXPECT_NE(Result.Error.find("tree node"), std::string::npos);
}

TEST(SwiftDemangle, BoundsTreeDepthAndRecursiveParsing) {
  auto Name = arrayType(8);
  auto Complete = swiftDemangle(Name);
  ASSERT_TRUE(Complete.Root) << Complete.Error;
  EXPECT_NE(findNode(*Complete.Root, "BoundGenericStructure"), nullptr);
  SwiftDemangleOptions Options;
  Options.MaxDepth = 8;
  auto Limited = swiftDemangle(Name, Options);
  EXPECT_FALSE(Limited.Root);
  EXPECT_NE(Limited.Error.find("limit"), std::string::npos);
  auto Deep = swiftDemangle(arrayType(1000));
  EXPECT_FALSE(Deep.Root);
  EXPECT_NE(Deep.Error.find("limit"), std::string::npos);
}

TEST(SwiftDemangle, RejectsInvalidResourceOptions) {
  SwiftDemangleOptions Options;
  Options.MaxDepth = 257;
  EXPECT_FALSE(swiftDemangle("$sSiN", Options).Root);
  Options = {};
  Options.MaxMemoryBytes = 0;
  EXPECT_FALSE(swiftDemangle("$sSiN", Options).Root);
  Options = {};
  Options.MaxOperations = 0;
  EXPECT_FALSE(swiftDemangle("$sSiN", Options).Root);
}

TEST(SwiftDemangle, KeepsConcurrentContextAndFailureBudgetsIndependent) {
  std::atomic<bool> Valid{true};
  std::vector<std::thread> Threads;
  for (unsigned Index = 0; Index < 4; ++Index)
    Threads.emplace_back([&] {
      for (unsigned Iteration = 0; Iteration < 20; ++Iteration) {
        SwiftDemangleOptions Options;
        Options.MaxMemoryBytes = 64;
        if (swiftDemangle("$sSiN", Options).Root ||
            !swiftDemangle("$s4main2idyxxlF").Root)
          Valid = false;
      }
    });
  for (auto &Thread : Threads)
    Thread.join();
  EXPECT_TRUE(Valid.load());
}
