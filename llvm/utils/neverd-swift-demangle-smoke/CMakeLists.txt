cmake_minimum_required(VERSION 3.20)
project(NeverDSwiftDemanglePackageSmoke LANGUAGES C CXX)

if(NOT NEVERD_LLVM_PACKAGE_ROOT)
  message(FATAL_ERROR "Pass NEVERD_LLVM_PACKAGE_ROOT for the installed LLVM package")
endif()
get_filename_component(NEVERD_LLVM_PACKAGE_ROOT
  "${NEVERD_LLVM_PACKAGE_ROOT}" ABSOLUTE)
set(LLVM_DIR "${NEVERD_LLVM_PACKAGE_ROOT}/lib/cmake/llvm" CACHE PATH
  "LLVM configuration from the package being validated" FORCE)

# Never fall back to a host LLVM or an in-tree build. The smoke test must prove
# that the archive's public headers, exported target, and transitive dependencies
# suffice for an independent consumer.
find_package(LLVM REQUIRED CONFIG
  PATHS "${NEVERD_LLVM_PACKAGE_ROOT}/lib/cmake/llvm"
  NO_DEFAULT_PATH)
if(NOT TARGET LLVMSwiftDemangle)
  message(FATAL_ERROR "Installed LLVM package does not export LLVMSwiftDemangle")
endif()
get_target_property(swift_demangle_type LLVMSwiftDemangle TYPE)
get_target_property(swift_demangle_imported LLVMSwiftDemangle IMPORTED)
if(NOT swift_demangle_imported OR NOT swift_demangle_type STREQUAL "STATIC_LIBRARY")
  message(FATAL_ERROR "LLVMSwiftDemangle must be an imported static library")
endif()
foreach(required
    include/llvm/Demangle/SwiftDemangle.h
    share/licenses/llvm/LICENSE.TXT
    share/licenses/llvm/swift-demangling/LICENSE.txt
    share/licenses/llvm/swift-demangling/CONTRIBUTORS.txt
    share/licenses/llvm/swift-demangling/UPSTREAM.md)
  if(NOT EXISTS "${NEVERD_LLVM_PACKAGE_ROOT}/${required}")
    message(FATAL_ERROR "Installed LLVM package is missing ${required}")
  endif()
  file(SIZE "${NEVERD_LLVM_PACKAGE_ROOT}/${required}" required_size)
  if(required_size EQUAL 0)
    message(FATAL_ERROR "Installed LLVM package has an empty ${required}")
  endif()
endforeach()

add_executable(neverd-swift-demangle-smoke main.cpp)
target_compile_features(neverd-swift-demangle-smoke PRIVATE cxx_std_20)
target_include_directories(neverd-swift-demangle-smoke SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})
target_link_libraries(neverd-swift-demangle-smoke PRIVATE LLVMSwiftDemangle)

enable_testing()
add_test(NAME NeverDSwiftDemanglePackageSmoke COMMAND neverd-swift-demangle-smoke)
set_tests_properties(NeverDSwiftDemanglePackageSmoke PROPERTIES
  TIMEOUT 30
  ENVIRONMENT "PATH=;NEVERD_SWIFT_DEMANGLE=${CMAKE_CURRENT_BINARY_DIR}/missing-swift-demangle")
