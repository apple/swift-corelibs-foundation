##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift open source project
##
## Copyright (c) 2024 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of Swift project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

cmake_minimum_required(VERSION 3.24)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

if(POLICY CMP0156)
    # Deduplicate linked libraries where appropriate
    cmake_policy(SET CMP0156 NEW)
endif()

if(POLICY CMP0157)
    # New Swift build model: improved incremental build performance and LSP support
    cmake_policy(SET CMP0157 NEW)
endif()

if (NOT DEFINED CMAKE_C_COMPILER)
    set(CMAKE_C_COMPILER clang)
endif()

project(Foundation
    LANGUAGES C Swift)

if(NOT SWIFT_SYSTEM_NAME)
  if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
    set(SWIFT_SYSTEM_NAME macosx)
  else()
    set(SWIFT_SYSTEM_NAME "$<LOWER_CASE:${CMAKE_SYSTEM_NAME}>")
  endif()
endif()

# Don't enable WMO on Windows due to linker failures
if(NOT CMAKE_SYSTEM_NAME STREQUAL Windows)
    # Enable whole module optimization for release builds & incremental for debug builds
    if(POLICY CMP0157)
        set(CMAKE_Swift_COMPILATION_MODE "$<IF:$<CONFIG:Release>,wholemodule,incremental>")
    else()
        add_compile_options($<$<AND:$<COMPILE_LANGUAGE:Swift>,$<CONFIG:Release>>:-wmo>)
    endif()
endif()

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

option(BUILD_SHARED_LIBS "build shared libraries" ON)

# Optionally build tools (on by default) but only when building shared libraries
if(BUILD_SHARED_LIBS)
    option(FOUNDATION_BUILD_TOOLS "build tools" ON)
endif()

set(FOUNDATION_BUILD_NETWORKING_default ON)
if(CMAKE_SYSTEM_NAME STREQUAL "WASI")
    # Networking is not supported on WASI
    set(FOUNDATION_BUILD_NETWORKING_default OFF)
endif()
option(FOUNDATION_BUILD_NETWORKING "build FoundationNetworking"
    ${FOUNDATION_BUILD_NETWORKING_default})

set(CMAKE_POSITION_INDEPENDENT_CODE YES)

# Fetchable dependencies
include(FetchContent)
if (_SwiftFoundationICU_SourceDIR)
    FetchContent_Declare(SwiftFoundationICU
        SOURCE_DIR ${_SwiftFoundationICU_SourceDIR})
else()
    FetchContent_Declare(SwiftFoundationICU
        GIT_REPOSITORY https://github.com/apple/swift-foundation-icu.git
        GIT_TAG 0.0.9)
endif()

if (_SwiftFoundation_SourceDIR)
    FetchContent_Declare(SwiftFoundation
        SOURCE_DIR ${_SwiftFoundation_SourceDIR})
else()
    FetchContent_Declare(SwiftFoundation
        GIT_REPOSITORY https://github.com/apple/swift-foundation.git
        GIT_TAG main)
endif()
FetchContent_MakeAvailable(SwiftFoundationICU SwiftFoundation)

include(CheckLinkerFlag)
include(CheckSymbolExists)

check_linker_flag(C "LINKER:--build-id=sha1" LINKER_SUPPORTS_BUILD_ID)

# Detect if the system libc defines symbols for these functions.
# If it is not availble, swift-corelibs-foundation has its own implementations
# that will be used. If it is available, it should not redefine them.
# Note: SwiftPM does not have the ability to introspect the contents of the SDK
#       and therefore will always include these functions in the build and will
#       cause build failures on platforms that define these functions.
check_symbol_exists("strlcat" "string.h" HAVE_STRLCAT)
check_symbol_exists("strlcpy" "string.h" HAVE_STRLCPY)
check_symbol_exists("issetugid" "unistd.h" HAVE_ISSETUGID)
add_compile_definitions(
  $<$<AND:$<COMPILE_LANGUAGE:C>,$<BOOL:${HAVE_STRLCAT}>>:HAVE_STRLCAT>
  $<$<AND:$<COMPILE_LANGUAGE:C>,$<BOOL:${HAVE_STRLCPY}>>:HAVE_STRLCPY>
  $<$<AND:$<COMPILE_LANGUAGE:C>,$<BOOL:${HAVE_ISSETUGID}>>:HAVE_ISSETUGID>)

if(CMAKE_SYSTEM_NAME STREQUAL Linux)
  check_symbol_exists(sched_getaffinity "sched.h" HAVE_SCHED_GETAFFINITY)
  add_compile_definitions($<$<COMPILE_LANGUAGE:C>:HAVE_SCHED_GETAFFINITY>)
endif()

# Precompute module triple for installation
if(NOT SwiftFoundation_MODULE_TRIPLE)
    set(module_triple_command "${CMAKE_Swift_COMPILER}" -print-target-info)
    if(CMAKE_Swift_COMPILER_TARGET)
        list(APPEND module_triple_command -target ${CMAKE_Swift_COMPILER_TARGET})
    endif()
    execute_process(COMMAND ${module_triple_command} OUTPUT_VARIABLE target_info_json)
    string(JSON module_triple GET "${target_info_json}" "target" "moduleTriple")
    set(SwiftFoundation_MODULE_TRIPLE "${module_triple}" CACHE STRING "swift module triple used for installed swiftmodule and swiftinterface files")
    mark_as_advanced(SwiftFoundation_MODULE_TRIPLE)
endif()

# System dependencies

# We know libdispatch is always unavailable on WASI
if(NOT CMAKE_SYSTEM_NAME STREQUAL "WASI")
    find_package(LibRT)
    find_package(dispatch CONFIG)
    if(NOT dispatch_FOUND)
        if(CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_SYSTEM_NAME STREQUAL "Android")
            set(DEFAULT_DISPATCH_INCLUDE_PATH "/usr/lib/swift")
        elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
            set(DEFAULT_DISPATCH_INCLUDE_PATH "$ENV{SDKROOT}usr/include")
        endif()
        set(DISPATCH_INCLUDE_PATH "${DEFAULT_DISPATCH_INCLUDE_PATH}" CACHE STRING "A path to where you can find libdispatch headers")
        message("-- dispatch_DIR not found, using dispatch from SDK at ${DISPATCH_INCLUDE_PATH}")
        list(APPEND _Foundation_common_build_flags
            "-I${DISPATCH_INCLUDE_PATH}"
            "-I${DISPATCH_INCLUDE_PATH}/Block")
    endif()
endif()
find_package(LibXml2 REQUIRED)
if(FOUNDATION_BUILD_NETWORKING)
    find_package(CURL REQUIRED)
endif()

# Common build flags (_CFURLSessionInterface, _CFXMLInterface, CoreFoundation)
list(APPEND _Foundation_common_build_flags
    "-DDEPLOYMENT_RUNTIME_SWIFT"
    "-DCF_BUILDING_CF"
    "-DHAVE_STRUCT_TIMESPEC"
    "-Wno-shorten-64-to-32"
    "-Wno-deprecated-declarations"
    "-Wno-unreachable-code"
    "-Wno-conditional-uninitialized"
    "-Wno-unused-variable"
    "-Wno-unused-function"
    "-Wno-microsoft-enum-forward-reference"
    "-Wno-int-conversion"
    "-Wno-switch"
    "-fblocks")

if(NOT CMAKE_SYSTEM_NAME STREQUAL "WASI")
    list(APPEND _Foundation_common_build_flags
        "-DDEPLOYMENT_ENABLE_LIBDISPATCH"
        "-DSWIFT_CORELIBS_FOUNDATION_HAS_THREADS")
endif()

if(NOT "${CMAKE_C_SIMULATE_ID}" STREQUAL "MSVC")
    list(APPEND _Foundation_common_build_flags
        "-fconstant-cfstrings"
        "-fdollars-in-identifiers"
        "-fno-common"
        "-fcf-runtime-abi=swift")

    if(NOT CMAKE_SYSTEM_NAME STREQUAL OpenBSD)
        list(APPEND _Foundation_common_build_flags
            "-fexceptions")
    endif()
else()
    list(APPEND _Foundation_common_build_flags
        "/EHsc"
        "/clang:-fcf-runtime-abi=swift")
endif()

if(CMAKE_BUILD_TYPE STREQUAL Debug)
    list(APPEND _Foundation_common_build_flags
        "-DDEBUG")
endif()

# Swift build flags (Foundation, FoundationNetworking, FoundationXML)
set(_Foundation_swift_build_flags)
list(APPEND _Foundation_swift_build_flags
    "-swift-version 6"
    "-DDEPLOYMENT_RUNTIME_SWIFT"
    "-Xfrontend"
    "-require-explicit-sendable")

if(CMAKE_SYSTEM_NAME STREQUAL "WASI")
    # Enable wasi-libc emulation features
    set(WASI_EMULATION_DEFS _WASI_EMULATED_MMAN _WASI_EMULATED_SIGNAL _WASI_EMULATED_PROCESS_CLOCKS)
    foreach(def ${WASI_EMULATION_DEFS})
        list(APPEND _Foundation_swift_build_flags "SHELL:-Xcc -D${def}")
        list(APPEND _Foundation_common_build_flags "-D${def}")
    endforeach()
else()
    # Assume we have threads on other platforms
    list(APPEND _Foundation_swift_build_flags
        "-DSWIFT_CORELIBS_FOUNDATION_HAS_THREADS")
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_SYSTEM_NAME STREQUAL "Android")
    list(APPEND _Foundation_common_build_flags
        "-D_GNU_SOURCE")
endif()

include(GNUInstallDirs)
include(FoundationSwiftSupport)

add_subdirectory(Sources)
add_subdirectory(cmake/modules)
