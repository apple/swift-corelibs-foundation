/*    CFBundle_Strings.h
    Copyright (c) 2021, Apple Inc. and the Swift project authors

    Portions Copyright (c) 2021, Apple Inc. and the Swift project authors
    Licensed under Apache License v2.0 with Runtime Library Exception
    See http://swift.org/LICENSE.txt for license information
    See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
*/

#ifndef CFBundle_Strings_h
#define CFBundle_Strings_h

#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFAvailability.h>

#define _CFBundleStringTableType CFSTR("strings")
#define _CFBundleStringDictTableType CFSTR("stringsdict")
#define _CFBundleLocTableType CFSTR("loctable")

#define _CFBundleLocTableProvenanceKey CFSTR("LocProvenance")
#define _CFBundleLocTableProvenanceAbsenceMaskKey CFSTR("none")

typedef CF_ENUM(uint8_t, _CFBundleLocTableProvenance) {
    _CFBundleLocTableProvenanceStrings = 1 << 0,
    _CFBundleLocTableProvenanceStringsDict = 1 << 1,
};

#endif /* CFBundle_LocTable_h */
