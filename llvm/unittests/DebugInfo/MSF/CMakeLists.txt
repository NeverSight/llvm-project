set(LLVM_LINK_COMPONENTS
  DebugInfoMSF
  )

add_llvm_unittest(DebugInfoMSFTests
  MappedBlockStreamTest.cpp
  MSF2Test.cpp
  MSFBuilderTest.cpp
  MSFCommonTest.cpp
  )

target_link_libraries(DebugInfoMSFTests PRIVATE LLVMTestingSupport)
