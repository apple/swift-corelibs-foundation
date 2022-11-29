/*      CFBundle_SplitFileName.h
        Copyright (c) 2019, Apple Inc. All rights reserved.
*/

#ifndef CFBundle_SplitFileName_h
#define CFBundle_SplitFileName_h

#include <CoreFoundation/CFPriv.h>
#include <CoreFoundation/CFString.h>

typedef enum {
    _CFBundleFileVersionNoProductNoPlatform = 1,
    _CFBundleFileVersionWithProductNoPlatform,
    _CFBundleFileVersionNoProductWithPlatform,
    _CFBundleFileVersionWithProductWithPlatform,
    _CFBundleFileVersionUnmatched
} _CFBundleFileVersion;

typedef enum {
    _CFBundleSplitFileNameDisableFallbackProductSearch, // Used by test cases to foricbly disable searching for fallback products.
    _CFBundleSplitFileNameEnableFallbackProductSearch, // Used by test cases to forcibly enable searching for fallback products.
    _CFBundleSplitFileNameAutomaticFallbackProductSearch // Automatically checks the current environment for the appropriate behavior.
} _CFBundleSplitFileNameFallbackProductSearchOption;

CF_PRIVATE void _CFBundleSplitFileName(CFStringRef fileName, CFStringRef *noProductOrPlatform, CFStringRef *endType, CFStringRef *startType, CFStringRef expectedProduct, CFStringRef expectedPlatform, _CFBundleSplitFileNameFallbackProductSearchOption fallbackSearchOption, _CFBundleFileVersion *version);

#endif /* CFBundle_SplitFileName_h */
