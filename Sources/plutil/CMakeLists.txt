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

add_executable(plutil
	main.swift
	PLUContext_Arguments.swift
	PLUContext_KeyPaths.swift
	PLUContext.swift
	PLULiteralOutput.swift)

target_link_libraries(plutil PRIVATE
	Foundation)

set_target_properties(plutil PROPERTIES
	INSTALL_RPATH "$ORIGIN/../lib/swift/${SWIFT_SYSTEM_NAME}")

set_property(GLOBAL APPEND PROPERTY Foundation_EXPORTS plutil)
install(TARGETS plutil
	DESTINATION ${CMAKE_INSTALL_BINDIR})
if(MSVC)
	install(FILES $<TARGET_FILE_DIR:plutil>/$<TARGET_FILE_BASE_NAME:plutil>.pdb
		DESTINATION ${CMAKE_INSTALL_BINDIR}
		OPTIONAL)
endif()
