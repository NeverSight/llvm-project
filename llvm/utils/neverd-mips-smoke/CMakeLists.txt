cmake_minimum_required(VERSION 3.20)
project(NeverDMipsPackageSmoke LANGUAGES C CXX)

if(NOT NEVERD_LLVM_PACKAGE_ROOT)
  message(FATAL_ERROR "Pass NEVERD_LLVM_PACKAGE_ROOT for the installed LLVM package")
endif()
get_filename_component(NEVERD_LLVM_PACKAGE_ROOT
  "${NEVERD_LLVM_PACKAGE_ROOT}" ABSOLUTE)
set(LLVM_DIR "${NEVERD_LLVM_PACKAGE_ROOT}/lib/cmake/llvm" CACHE PATH
  "LLVM configuration from the package being validated" FORCE)
find_package(LLVM REQUIRED CONFIG
  PATHS "${NEVERD_LLVM_PACKAGE_ROOT}/lib/cmake/llvm"
  NO_DEFAULT_PATH)
foreach(component LLVMMipsCodeGen LLVMMipsAsmParser LLVMMipsDesc LLVMMipsInfo LLVMAsmParser)
  if(NOT TARGET ${component})
    message(FATAL_ERROR "Installed LLVM package does not export ${component}")
  endif()
  get_target_property(component_type ${component} TYPE)
  get_target_property(component_imported ${component} IMPORTED)
  if(NOT component_imported OR NOT component_type STREQUAL "STATIC_LIBRARY")
    message(FATAL_ERROR "${component} must be an imported static library")
  endif()
endforeach()
if(LLVM_BUILD_BINARY_DIR)
  message(FATAL_ERROR "Validate the installed package, not an LLVM build tree")
endif()

add_executable(neverd-mips-smoke main.cpp)
target_compile_features(neverd-mips-smoke PRIVATE cxx_std_17)
target_include_directories(neverd-mips-smoke SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})
target_link_libraries(neverd-mips-smoke PRIVATE LLVMMipsCodeGen LLVMMipsAsmParser LLVMAsmParser)

enable_testing()
add_test(NAME NeverDMipsPackageSmoke COMMAND neverd-mips-smoke)
set_tests_properties(NeverDMipsPackageSmoke PROPERTIES TIMEOUT 30 ENVIRONMENT "PATH=")
