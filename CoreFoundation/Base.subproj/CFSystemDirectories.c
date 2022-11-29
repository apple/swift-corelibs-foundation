/*	CFSystemDirectories.c
	Copyright (c) 1997-2019, Apple Inc. and the Swift project authors
 
	Portions Copyright (c) 2014-2019, Apple Inc. and the Swift project authors
	Licensed under Apache License v2.0 with Runtime Library Exception
	See http://swift.org/LICENSE.txt for license information
	See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
	Responsibility: Kevin Perry
*/

/*
        This file defines CFCopySearchPathForDirectoriesInDomains().
        On MacOS 8, this function returns empty array.
        On Mach, it calls the System.framework enumeration functions.
        On Windows, it calls the enumeration functions defined here.
*/

#include <CoreFoundation/CFPriv.h>
#include "CFInternal.h"

#if TARGET_OS_MAC

/* We use the System framework implementation on Mach.
*/
#include <libc.h>
#include <stdio.h>
#include <stdlib.h>
#include <pwd.h>
#include <sysdir.h>

CFSearchPathEnumerationState __CFGetNextSearchPathEnumeration(CFSearchPathEnumerationState state, uint8_t *path, CFIndex pathSize) {
    CFSearchPathEnumerationState result;
    // NSGetNextSearchPathEnumeration requires a MAX_PATH size
    if (pathSize < PATH_MAX) {
        uint8_t tempPath[PATH_MAX];
        result = sysdir_get_next_search_path_enumeration(state, (char *)tempPath);
        strlcpy((char *)path, (char *)tempPath, pathSize);
    } else {
        result = sysdir_get_next_search_path_enumeration(state, (char *)path);
    }
    return result;
}

#endif



#undef numDirs
#undef numApplicationDirs
#undef numLibraryDirs
#undef numDomains
#undef invalidDomains
#undef invalidDomains

