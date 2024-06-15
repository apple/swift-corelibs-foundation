
cmake_minimum_required(VERSION 3.15.1)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

# NOTE(compnerd) enable CMP0091 - select MSVC runtime based on
# CMAKE_MSVC_RUNTIME_LIBRARY.  Requires CMake 3.15 or newer
if(POLICY CMP0091)
  cmake_policy(SET CMP0091 NEW)
endif()

project(Foundation
  LANGUAGES C Swift)
enable_testing()

if(NOT SWIFT_SYSTEM_NAME)
  if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
    set(SWIFT_SYSTEM_NAME macosx)
  else()
    set(SWIFT_SYSTEM_NAME "$<LOWER_CASE:${CMAKE_SYSTEM_NAME}>")
  endif()
endif()

# NOTE(compnerd) default to /MD or /MDd by default based on the configuration.
# Cache the variable to allow the user to alter the configuration.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL" CACHE
  STRING "MSVC Runtime Library")

if(CMAKE_VERSION VERSION_LESS 3.16.0)
  if(NOT (CMAKE_SYSTEM_NAME STREQUAL Windows OR CMAKE_SYSTEM_NAME STREQUAL Darwin))
    set(CMAKE_SHARED_LIBRARY_RUNTIME_Swift_FLAG "-Xlinker -rpath -Xlinker ")
    set(CMAKE_SHARED_LIBRARY_RUNTIME_Swift_FLAG_SEP ":")
  endif()
  # Workaround for CMake 3.15 which doesn't link libraries properly on Windows
  set(CMAKE_LINK_LIBRARY_FLAG "-l")
endif()

if(CMAKE_VERSION VERSION_LESS 3.16 AND CMAKE_SYSTEM_NAME STREQUAL Windows)
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
else()
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
endif()
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

option(BUILD_SHARED_LIBS "build shared libraries" ON)
option(BUILD_FULLY_STATIC "build fully static" NO)
option(HAS_LIBDISPATCH_API "has libdispatch API" ON)
option(FOUNDATION_ENABLE_FOUNDATION_NETWORKING "build FoundationNetworking module" ON)
option(FOUNDATION_BUILD_TOOLS "build tools" ON)
option(NS_CURL_ASSUME_FEATURES_MISSING "Assume that optional libcurl features are missing rather than test the library's version, for build debugging" NO)

if(HAS_LIBDISPATCH_API)
  find_package(dispatch CONFIG REQUIRED)
endif()

find_package(ICU COMPONENTS uc i18n REQUIRED OPTIONAL_COMPONENTS data)

# This is needed if we're statically linking, otherwise we can't pull in Dispatch
# because we won't have RT::rt as a CMake target.
if(NOT CMAKE_SYSTEM_NAME STREQUAL Android)
  find_package(LibRT)
endif()

include(SwiftSupport)
include(GNUInstallDirs)
include(XCTest)

set(CF_DEPLOYMENT_SWIFT YES CACHE BOOL "Build for Swift" FORCE)

if(HAS_LIBDISPATCH_API)
  set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
  set(THREADS_PREFER_PTHREAD_FLAG OFF)
  if(ANDROID)
    set(CMAKE_THREAD_LIBS_INIT "-lc")
    set(THREADS_HAVE_PTHREAD_ARG FALSE)
  endif()
  find_package(Threads REQUIRED)
endif()

set(SAVED_BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS})
set(BUILD_SHARED_LIBS NO)
add_subdirectory(CoreFoundation EXCLUDE_FROM_ALL)
set(BUILD_SHARED_LIBS ${SAVED_BUILD_SHARED_LIBS})

# BlocksRuntime is already in libdispatch so it is only needed if libdispatch is
# NOT being used
if(NOT HAS_LIBDISPATCH_API)
  add_subdirectory(Sources/BlocksRuntime)
endif()

# Setup include paths for uuid/uuid.h
add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/uuid-headers/uuid/uuid.h
  COMMAND
    ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/uuid-headers/uuid
  COMMAND
    ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_SOURCE_DIR}/Sources/UUID/uuid.h ${CMAKE_BINARY_DIR}/uuid-headers/uuid/uuid.h)
add_custom_target(uuid-headers
  DEPENDS ${CMAKE_BINARY_DIR}/uuid-headers/uuid/uuid.h)
add_dependencies(CoreFoundation uuid-headers)
target_include_directories(CoreFoundation PRIVATE
  ${CMAKE_BINARY_DIR}/uuid-headers
  ${CMAKE_CURRENT_BINARY_DIR}/CoreFoundation.framework/Headers)

add_subdirectory(Sources)
if(ENABLE_TESTING)
  find_package(XCTest CONFIG REQUIRED)
  add_subdirectory(Tests)
endif()

if(NOT BUILD_SHARED_LIBS)
  set_property(GLOBAL APPEND PROPERTY Foundation_EXPORTS
    CoreFoundation CFXMLInterface)

  if(NOT HAS_LIBDISPATCH_API)
    set_property(GLOBAL APPEND PROPERTY Foundation_EXPORTS
      BlocksRuntime)
  endif()

  install(TARGETS CoreFoundation CFXMLInterface
    DESTINATION lib/swift_static/${SWIFT_SYSTEM_NAME})

  if(FOUNDATION_ENABLE_FOUNDATION_NETWORKING)
    set_property(GLOBAL APPEND PROPERTY Foundation_EXPORTS
      CFURLSessionInterface)
    install(TARGETS CFURLSessionInterface
      DESTINATION lib/swift_static/${SWIFT_SYSTEM_NAME})
  endif()
endif()

set(swift_lib_dir "lib/swift")
if(NOT BUILD_SHARED_LIBS)
  set(swift_lib_dir "lib/swift_static")
endif()

# TODO(compnerd) install as a Framework as that is how swift actually is built
install(DIRECTORY
          ${CMAKE_CURRENT_BINARY_DIR}/CoreFoundation.framework/Headers/
        DESTINATION
          ${swift_lib_dir}/CoreFoundation
        FILES_MATCHING PATTERN "*.h")
install(FILES
          CoreFoundation/Base.subproj/$<$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>:static/>module.map
        DESTINATION
          ${swift_lib_dir}/CoreFoundation)
install(DIRECTORY
          ${CMAKE_CURRENT_BINARY_DIR}/CFURLSessionInterface.framework/Headers/
        DESTINATION
          ${swift_lib_dir}/CFURLSessionInterface
        FILES_MATCHING PATTERN "*.h")
install(FILES
          CoreFoundation/URL.subproj/$<$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>:static/>module.map
        DESTINATION
          ${swift_lib_dir}/CFURLSessionInterface)
install(DIRECTORY
          ${CMAKE_CURRENT_BINARY_DIR}/CFXMLInterface.framework/Headers/
        DESTINATION
          ${swift_lib_dir}/CFXMLInterface
        FILES_MATCHING PATTERN "*.h")
install(FILES
          CoreFoundation/Parsing.subproj/$<$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>:static/>module.map
        DESTINATION
          ${swift_lib_dir}/CFXMLInterface)

add_subdirectory(cmake/modules)
