set(LLVM_LINK_COMPONENTS
  SwiftDemangle
  Support
)

add_llvm_unittest(SwiftDemangleTests
  SwiftDemangleTest.cpp
)
