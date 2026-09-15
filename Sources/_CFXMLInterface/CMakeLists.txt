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

add_library(_CFXMLInterface STATIC CFXMLInterface.c)

target_include_directories(_CFXMLInterface
    PUBLIC
        include
        ../CoreFoundation/include
    PRIVATE
        ../CoreFoundation/internalInclude)

target_compile_options(_CFXMLInterface INTERFACE
  "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${CMAKE_CURRENT_SOURCE_DIR}/../CoreFoundation/include/module.modulemap>"
  "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${CMAKE_CURRENT_SOURCE_DIR}/include/module.modulemap>")

target_compile_options(_CFXMLInterface PRIVATE
    "SHELL:$<$<COMPILE_LANGUAGE:C>:${_Foundation_common_build_flags}>")

target_link_libraries(_CFXMLInterface PRIVATE
    dispatch
    LibXml2::LibXml2)

if(CMAKE_SYSTEM_NAME STREQUAL "WASI")
    target_link_libraries(_CFXMLInterface PRIVATE BlocksRuntime)
endif()

if(NOT BUILD_SHARED_LIBS)
    set_property(GLOBAL APPEND PROPERTY Foundation_EXPORTS _CFXMLInterface)
    install(TARGETS _CFXMLInterface
        ARCHIVE DESTINATION lib/swift_static/${SWIFT_SYSTEM_NAME}
        LIBRARY DESTINATION lib/swift_static/${SWIFT_SYSTEM_NAME}
        RUNTIME DESTINATION bin)
    if(MSVC)
        install(FILES $<TARGET_FILE_DIR:_CFXMLInterface>/$<TARGET_FILE_BASE_NAME:_CFXMLInterface>.pdb
            DESTINATION bin
            OPTIONAL)
    endif()
endif()
