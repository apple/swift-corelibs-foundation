/*      CFNumberConstants.c
        Copyright (c) 2022, Apple Inc. and the Swift project authors

        Portions Copyright (c) 2014-2019, Apple Inc. and the Swift project authors
        Licensed under Apache License v2.0 with Runtime Library Exception
        See http://swift.org/LICENSE.txt for license information
        See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
*/

#include <CoreFoundation/CFNumber.h>

extern const struct __CFBoolean __kCFBooleanTrue;
extern const struct __CFBoolean __kCFBooleanFalse;

const CFBooleanRef kCFBooleanTrue = &__kCFBooleanTrue;
const CFBooleanRef kCFBooleanFalse = &__kCFBooleanFalse;
