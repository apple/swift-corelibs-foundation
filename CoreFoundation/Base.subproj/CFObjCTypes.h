// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


#ifndef __COREFOUNDATION_CFOBJCTYPES__
#define __COREFOUNDATION_CFOBJCTYPES__ 1

// In swift-corelibs-foundation, the 'id' type needs to be available to contexts like the clang importer when it imports private headers like ForFoundationOnly.h.
// These types used to be defined in the prefix header, but that is not available in those contexts.

    
#if _CF_OBJC
#include <objc/objc.h>
#else
typedef signed char    BOOL;
typedef char * id;
typedef char * Class;
#ifndef YES
#define YES (BOOL)1
#endif
#ifndef NO
#define NO (BOOL)0
#endif
#ifndef nil
#define nil NULL
#endif
#endif

#endif // __COREFOUNDATION_CFOBJCTYPES__
