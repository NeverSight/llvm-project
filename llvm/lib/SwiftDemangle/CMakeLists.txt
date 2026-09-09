# The Swift grammar is a pinned source subset. No Swift toolchain, runtime,
# configure-time download, or subprocess is needed by this component.
set(LLVM_REQUIRES_EH ON)
set(LLVM_REQUIRES_RTTI ON)
set(swift_demangle_vendor_sources
  vendor/swift/lib/Demangling/Demangler.cpp
  vendor/swift/lib/Demangling/Context.cpp
  vendor/swift/lib/Demangling/ManglingUtils.cpp
  vendor/swift/lib/Demangling/NodeDumper.cpp
  vendor/swift/lib/Demangling/NodePrinter.cpp
  vendor/swift/lib/Demangling/OldDemangler.cpp
  vendor/swift/lib/Demangling/OldRemangler.cpp
  vendor/swift/lib/Demangling/Punycode.cpp
  vendor/swift/lib/Demangling/Remangler.cpp
  vendor/swift/lib/Demangling/Errors.cpp
  vendor/swift/lib/Demangling/CrashReporter.cpp
)

add_llvm_component_library(LLVMSwiftDemangle
  SwiftDemangle.cpp
  ${swift_demangle_vendor_sources}

  ADDITIONAL_HEADER_DIRS
  ${LLVM_MAIN_INCLUDE_DIR}/llvm/Demangle

  LINK_COMPONENTS
  Support
)

target_compile_features(LLVMSwiftDemangle PUBLIC cxx_std_17)
target_include_directories(LLVMSwiftDemangle PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
)
target_include_directories(LLVMSwiftDemangle SYSTEM PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/vendor/swift/include
)
target_compile_definitions(LLVMSwiftDemangle PRIVATE
  SWIFT_INLINE_NAMESPACE=llvm_swift_6_3_3
  LLVM_DISABLE_ABI_BREAKING_CHECKS_ENFORCING=1
  SWIFT_SUPPORT_OLD_MANGLING=1
  SWIFT_STDLIB_HAS_TYPE_PRINTING=1
  SWIFT_STDLIB_HAS_ASL=0
  SWIFT_HAVE_CRASHREPORTERCLIENT=0
)
set_target_properties(LLVMSwiftDemangle PROPERTIES
  POSITION_INDEPENDENT_CODE ON
)
if(NOT MSVC)
  # Do not hide the wrapper API. Upstream implementation symbols also have a
  # private inline namespace, avoiding collisions with an installed Swift SDK.
  set_source_files_properties(${swift_demangle_vendor_sources} PROPERTIES
    COMPILE_OPTIONS "-fvisibility=hidden;-fvisibility-inlines-hidden")
endif()
if(ANDROID)
  target_link_libraries(LLVMSwiftDemangle PRIVATE log)
endif()

install(FILES vendor/swift/LICENSE.txt vendor/swift/CONTRIBUTORS.txt UPSTREAM.md
  DESTINATION share/licenses/llvm/swift-demangling
  COMPONENT LLVMSwiftDemangle)
install(FILES ${LLVM_MAIN_SRC_DIR}/LICENSE.TXT
  DESTINATION share/licenses/llvm
  COMPONENT LLVMSwiftDemangle)
