// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#include <CoreFoundation/CFAsmMacros.h>

#if defined(__ELF__)
.section .rodata
#elif defined(__wasm__)
.section .data.unichar_property_database,"",@
#endif

    .global _C_LABEL(__CFUniCharPropertyDatabase)
_C_LABEL(__CFUniCharPropertyDatabase):
    .incbin CF_CHARACTERSET_UNICHAR_DB
#if defined(__wasm__)
    .size _C_LABEL(__CFUniCharPropertyDatabase), . - _C_LABEL(__CFUniCharPropertyDatabase)
#endif

    .global _C_LABEL(__CFUniCharPropertyDatabaseEnd)
_C_LABEL(__CFUniCharPropertyDatabaseEnd):
    .byte 0
#if defined(__wasm__)
    .size _C_LABEL(__CFUniCharPropertyDatabaseEnd), . - _C_LABEL(__CFUniCharPropertyDatabaseEnd)
#endif

    .global _C_LABEL(__CFUniCharPropertyDatabaseSize)
_C_LABEL(__CFUniCharPropertyDatabaseSize):
    .int _C_LABEL(__CFUniCharPropertyDatabaseEnd) - _C_LABEL(__CFUniCharPropertyDatabase)
#if defined(__wasm__)
    .size _C_LABEL(__CFUniCharPropertyDatabaseSize), . - _C_LABEL(__CFUniCharPropertyDatabaseSize)
#endif

NO_EXEC_STACK_DIRECTIVE
SAFESEH_REGISTRATION_DIRECTIVE
