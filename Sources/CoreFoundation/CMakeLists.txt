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

add_library(CoreFoundation STATIC
    CFApplicationPreferences.c
    CFArray.c
    CFAttributedString.c
    CFBag.c
    CFBase.c
    CFBasicHash.c
    CFBigNumber.c
    CFBinaryHeap.c
    CFBinaryPList.c
    CFBitVector.c
    CFBuiltinConverters.c
    CFBundle_Binary.c
    CFBundle_DebugStrings.c
    CFBundle_Executable.c
    CFBundle_Grok.c
    CFBundle_InfoPlist.c
    CFBundle_Locale.c
    CFBundle_Main.c
    CFBundle_ResourceFork.c
    CFBundle_Resources.c
    CFBundle_SplitFileName.c
    CFBundle_Strings.c
    CFBundle_Tables.c
    CFBundle.c
    CFBurstTrie.c
    CFCalendar_Enumerate.c
    CFCalendar.c
    CFCharacterSet.c
    CFConcreteStreams.c
    CFData.c
    CFDate.c
    CFDateComponents.c
    CFDateFormatter.c
    CFDateInterval.c
    CFDateIntervalFormatter.c
    CFDictionary.c
    CFError.c
    CFFileUtilities.c
    CFICUConverters.c
    CFKnownLocations.c
    CFListFormatter.c
    CFLocale.c
    CFLocaleIdentifier.c
    CFLocaleKeys.c
    CFNumber.c
    CFNumberFormatter.c
    CFOldStylePList.c
    CFPlatform.c
    CFPlatformConverters.c
    CFPlugIn.c
    CFPreferences.c
    CFPropertyList.c
    CFRegularExpression.c
    CFRelativeDateTimeFormatter.c
    CFRunArray.c
    CFRunLoop.c
    CFRuntime.c
    CFSet.c
    CFSocket.c
    CFSocketStream.c
    CFSortFunctions.c
    CFStorage.c
    CFStream.c
    CFString.c
    CFStringEncodingConverter.c
    CFStringEncodingDatabase.c
    CFStringEncodings.c
    CFStringScanner.c
    CFStringTransform.c
    CFStringUtilities.c
    CFSystemDirectories.c
    CFTimeZone.c
    CFTimeZone_WindowsMapping.c
    CFTree.c
    CFUniChar.c
    CFUnicodeDecomposition.c
    CFUnicodePrecomposition.c
    CFURL.c
    CFURLAccess.c
    CFURLComponents_URIParser.c
    CFURLComponents.c
    CFUtilities.c
    CFUUID.c
    CFWindowsUtilities.c
    CFXMLPreferencesDomain.c
    uuid.c)
target_compile_definitions(CoreFoundation PRIVATE
  $<$<AND:$<PLATFORM_ID:Windows>,$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>>:CF_WINDOWS_EXECUTABLE_INITIALIZER>)
target_include_directories(CoreFoundation
    PUBLIC
        include
    PRIVATE
        internalInclude)

target_compile_options(CoreFoundation INTERFACE
  "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${CMAKE_CURRENT_SOURCE_DIR}/include/module.modulemap>")

target_compile_options(CoreFoundation PRIVATE
    "SHELL:$<$<COMPILE_LANGUAGE:C>:${_Foundation_common_build_flags}>")

target_precompile_headers(CoreFoundation PRIVATE internalInclude/CoreFoundation_Prefix.h)

target_link_libraries(CoreFoundation
    PRIVATE
        _FoundationICU
        dispatch)

if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    # CFLog calls __android_log_print, which lives in liblog.
    target_link_libraries(CoreFoundation PRIVATE log)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "WASI")
    # On WASI, we use vendored BlocksRuntime instead of the one from libdispatch
    add_subdirectory(BlockRuntime)
    # Add BlocksRuntime object library to CoreFoundation static archive
    target_link_libraries(CoreFoundation PRIVATE BlocksRuntime)
endif()

set_property(GLOBAL APPEND PROPERTY Foundation_EXPORTS CoreFoundation)

# Copy Headers to known directory for direct client (XCTest) test builds
file(COPY
        include/
    DESTINATION
        ${CMAKE_BINARY_DIR}/_CModulesForClients/CoreFoundation)

if(NOT BUILD_SHARED_LIBS)
    set(swift swift_static)
else()
    set(swift swift)
endif()

install(DIRECTORY
            include/
        DESTINATION
            lib/${swift}/CoreFoundation)

if(NOT BUILD_SHARED_LIBS)
    install(TARGETS CoreFoundation
        ARCHIVE DESTINATION lib/swift_static/${SWIFT_SYSTEM_NAME}
        LIBRARY DESTINATION lib/swift_static/${SWIFT_SYSTEM_NAME}
        RUNTIME DESTINATION bin)
    if(MSVC)
        install(FILES $<TARGET_FILE_DIR:CoreFoundation>/$<TARGET_FILE_BASE_NAME:CoreFoundation>.pdb
            DESTINATION bin
            OPTIONAL)
    endif()
endif()
