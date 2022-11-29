/*      CFBundle_Strings.c
	Copyright (c) 1999-2019, Apple Inc. and the Swift project authors
 
	Portions Copyright (c) 2014-2019, Apple Inc. and the Swift project authors
	Licensed under Apache License v2.0 with Runtime Library Exception
	See http://swift.org/LICENSE.txt for license information
	See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
        Responsibility: Tony Parker
*/

#include "CFBundle_Internal.h"
#include "CFBundle_Strings.h"
#include "CFBundle_SplitFileName.h"
#include "CFCollections_Internal.h"

#include <CoreFoundation/CFString_Private.h>
#include <CoreFoundation/CFPropertyList_Private.h>

#if TARGET_OS_OSX

#endif

#include <dlfcn.h>

#include <CoreFoundation/CFPreferences.h>
#include <CoreFoundation/CFURLAccess.h>

#pragma mark -
#pragma mark Localized Strings

static void __CFStringsDictAddFunction(const void *key, const void *value, void *context) {
    CFDictionaryAddValue((CFMutableDictionaryRef)context, key, value);
}


CF_EXPORT CFStringRef CFBundleCopyLocalizedString(CFBundleRef bundle, CFStringRef key, CFStringRef value, CFStringRef tableName) {
    return CFBundleCopyLocalizedStringForLocalization(bundle, key, value, tableName, NULL);
}


static CFStringRef _CFBundleCopyLanguageForStringsResourceURL(CFURLRef url) {
    CFStringRef pathString = CFURLCopyPath(url);
    CFIndex length = CFStringGetLength(pathString);

    CFStringRef result = NULL;
    CFRange foundRange;
    CFRange slashRange;
    if (CFStringFindWithOptions(pathString, _CFBundleLprojExtensionWithDot, CFRangeMake(0, length), kCFCompareBackwards, &foundRange)) {
        if (CFStringFindWithOptions(pathString, CFSTR("/"), CFRangeMake(0, foundRange.location), kCFCompareBackwards, &slashRange)) {
            CFIndex endOfSlash = slashRange.location + slashRange.length;
            result = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, pathString, CFRangeMake(endOfSlash, foundRange.location - endOfSlash));
        }
    }
    CFRelease(pathString);
    return result;
}

static _CFBundleFileVersion _CFBundleGetFileVersionForStringsResourceURL(CFURLRef _Nullable url) {
    if (url == NULL) return 0;

    _CFBundleFileVersion result = 0;
    CFStringRef lastPathComponent = CFURLCopyLastPathComponent(url);
    if (lastPathComponent) {
        CFStringRef unused = NULL;
        _CFBundleSplitFileName(lastPathComponent, &unused, NULL, NULL, _CFBundleGetProductNameSuffix(), _CFBundleGetPlatformNameSuffix(), _CFBundleSplitFileNameAutomaticFallbackProductSearch, &result);
        if (unused) CFRelease(unused);
        CFRelease(lastPathComponent);
    }
    return result;
}

static CFMutableArrayRef _mappedStringsFiles = NULL;
static os_unfair_lock _mappedStringsFilesLock = OS_UNFAIR_LOCK_INIT;

CFDataRef _CFBundleGetMappedStringsFile(CFIndex idx) {
    os_unfair_lock_lock_with_options(&_mappedStringsFilesLock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    CFDataRef result = CFArrayGetValueAtIndex(_mappedStringsFiles, idx);
    os_unfair_lock_unlock(&_mappedStringsFilesLock);
    return result;
}

static CFIndex _CFBundleInstallMappedStringsData(CFDataRef data) {
    CFIndex result = kCFNotFound;
    os_unfair_lock_lock_with_options(&_mappedStringsFilesLock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (data) {
        if (!_mappedStringsFiles) {
            _mappedStringsFiles = CFArrayCreateMutable(kCFAllocatorSystemDefault, 0, &kCFTypeArrayCallBacks);
        }
        result = CFArrayGetCount(_mappedStringsFiles);
        CFArrayAppendValue(_mappedStringsFiles, data);
    }
    os_unfair_lock_unlock(&_mappedStringsFilesLock);
    return result;
}

extern CFDataRef __NSCreateBPlistMappedDataFromURL(CFURLRef url, CFIndex (^mappingIndexProvider)(CFDataRef), CFErrorRef *outError) CF_RETURNS_RETAINED;

static CFDataRef _CFBundleMapStringsFile(CFURLRef url) CF_RETURNS_RETAINED {
    static __typeof__(__NSCreateBPlistMappedDataFromURL) *__weak__NSCreateBPlistMappedDataFromURL = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#ifdef RTLD_NOLOAD
        void * handle = dlopen("/System/Library/Frameworks/Foundation.framework/Foundation", RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD);
#else
        void * handle = dlopen("/System/Library/Frameworks/Foundation.framework/Foundation", RTLD_LAZY | RTLD_LOCAL);
#endif
        __weak__NSCreateBPlistMappedDataFromURL = dlsym(handle, "__NSCreateBPlistMappedDataFromURL");
        if (!__weak__NSCreateBPlistMappedDataFromURL) {
            os_log_info(_CFBundleLocalizedStringLogger(), "CFBundle unable to map strings files, because Foundation is not linked");
        }
    });
    if (!__weak__NSCreateBPlistMappedDataFromURL) return nil;

    CFErrorRef error = NULL;
    CFDataRef data = __weak__NSCreateBPlistMappedDataFromURL(url, ^CFIndex(CFDataRef data) {
        return _CFBundleInstallMappedStringsData(data);
    }, &error);
    if (error) CFRelease(error);
    return data;
}

CF_PRIVATE bool __CFBinaryPlistCreateObjectFiltered(const uint8_t *databytes, uint64_t datalen, uint64_t startOffset, const CFBinaryPlistTrailer *trailer, CFAllocatorRef allocator, CFOptionFlags mutabilityOption, CFDataRef backingDataForNoCopy, CFMutableDictionaryRef objects, CFMutableSetRef set, CFIndex curDepth, CFSetRef keyPaths, CFPropertyListRef *plist, CFTypeID *outPlistTypeID);

static void _CFBundleGetLocTableProvenanceForLanguage(CFDataRef mappingData, CFStringRef lang, Boolean *containsStrings, Boolean *containsStringsDict) {
    CFMutableStringRef key = CFStringCreateMutableCopy(kCFAllocatorSystemDefault, 0, _CFBundleLocTableProvenanceKey);
    CFStringAppend(key, CFSTR(":"));
    CFStringAppend(key, lang);

    CFSetRef keySet = CFSetCreate(kCFAllocatorSystemDefault, (const void **)&key, 1, NULL);
    CFDictionaryRef result = NULL;

    Boolean foundRelevantProvenance = false;
    if (_CFPropertyListCreateFiltered(kCFAllocatorDefault, mappingData, 0, keySet, (CFPropertyListRef *)&result, NULL)) {
        CFNumberRef num = _CFPropertyListGetValueWithKeyPath(result, key);
        uint8_t numVal = 0;
        if (num && CFGetTypeID(num) == _kCFRuntimeIDCFNumber && CFNumberGetValue(num, kCFNumberCharType, &numVal)) {
            foundRelevantProvenance = true;
            *containsStrings = (numVal & _CFBundleLocTableProvenanceStrings) != 0;
            *containsStringsDict = (numVal & _CFBundleLocTableProvenanceStringsDict) != 0;
        } else if (CFEqual(lang, _CFBundleLocTableProvenanceAbsenceMaskKey)) {
            // `none` can be missing.
            foundRelevantProvenance = true;
        }
        if (result) CFRelease(result);
    }

    if (!foundRelevantProvenance) {
        // A malformed .loctable. Assume that if the language exists at the top level that it has both.
        // We might also use this in tests for added convenience.
        CFSetRef allKeys = _CFPropertyListCopyTopLevelKeys(kCFAllocatorSystemDefault, mappingData, 0, NULL);
        if (allKeys) {
            if (CFSetContainsValue(allKeys, lang)) {
                *containsStrings = true;
                *containsStringsDict = true;
            }
            CFRelease(allKeys);
        }
    }

    CFRelease(key);
    CFRelease(keySet);
}

static void _CFBundleAddProvenanceKeyPathIfPresent(CFSetRef allKeys, CFMutableSetRef keyPaths, CFStringRef name) {
    if (CFSetContainsValue(allKeys, name)) {
        CFStringRef keyPath = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@:%@"), _CFBundleLocTableProvenanceKey, name);
        CFSetAddValue(keyPaths, keyPath);
        CFRelease(keyPath);
    }
}

static CFDictionaryRef _CFBundleCopyLocTableProvenanceForDeviceAndPlatformVariants(CFDataRef mappingData, CFStringRef lang) {
    CFSetRef allKeys = _CFPropertyListCopyTopLevelKeys(kCFAllocatorSystemDefault, mappingData, 0, NULL);
    if (!allKeys) {
        return NULL;
    }
    CFMutableSetRef keyPaths = CFSetCreateMutable(kCFAllocatorSystemDefault, 5, &kCFTypeSetCallBacks);

    CFStringRef product = _CFBundleGetProductNameSuffix();
    CFStringRef platform = _CFBundleGetPlatformNameSuffix();
    
    // Include both orders of device and platform, just in case.
    CFStringRef productThenPlatform = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@%@%@"), lang, product, platform);
    CFStringRef platformThenProduct = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@%@%@"), lang, platform, product);

    CFStringRef platformOnly = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@%@"), lang, platform);
    CFStringRef productOnly = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@%@"), lang, product);

    _CFBundleAddProvenanceKeyPathIfPresent(allKeys, keyPaths, productThenPlatform);
    _CFBundleAddProvenanceKeyPathIfPresent(allKeys, keyPaths, platformThenProduct);
    _CFBundleAddProvenanceKeyPathIfPresent(allKeys, keyPaths, platformOnly);
    _CFBundleAddProvenanceKeyPathIfPresent(allKeys, keyPaths, productOnly);
    _CFBundleAddProvenanceKeyPathIfPresent(allKeys, keyPaths, lang);

    CFDictionaryRef result = NULL;
    if (CFSetGetCount(keyPaths) > 0) {
        CFDictionaryRef filterResult = NULL;
        if (_CFPropertyListCreateFiltered(kCFAllocatorSystemDefault, mappingData, 0, keyPaths, (CFPropertyListRef *)&filterResult, NULL) && filterResult != NULL) {
            CFDictionaryRef provenances = CFDictionaryGetValue(filterResult, _CFBundleLocTableProvenanceKey);
            if (!provenances || CFDictionaryGetCount(provenances) != CFSetGetCount(keyPaths)) {
                // A malformed .loctable. Assume that if the language exists at the top level that it has both.
                CFMutableDictionaryRef adjusted = CFDictionaryCreateMutable(kCFAllocatorSystemDefault, CFSetGetCount(keyPaths), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                uint8_t bothProvenance = _CFBundleLocTableProvenanceStringsDict | _CFBundleLocTableProvenanceStrings;
                CFNumberRef num = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberSInt8Type, &bothProvenance);
                CFIndex const keyRangeStart = CFStringGetLength(_CFBundleLocTableProvenanceKey) + 1; // length of "LocProvenance:"
                CFSetApply(keyPaths, ^(const void * _Nonnull keyPath, Boolean * _Nonnull stop) {
                    CFRange keyRange = CFRangeMake(keyRangeStart, CFStringGetLength(keyPath) - keyRangeStart);
                    CFStringRef key = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, keyPath, keyRange);
                    if (!CFDictionaryGetValue(adjusted, key)) {
                        CFDictionarySetValue(adjusted, key, num);
                    }
                    CFRelease(key);
                });
                CFRelease(num);

                result = adjusted; // Transfer retain.
            } else {
                result = CFRetain(provenances);
            }
            CFRelease(filterResult);
        }
    }

    CFRelease(productThenPlatform);
    CFRelease(platformThenProduct);
    CFRelease(platformOnly);
    CFRelease(productOnly);

    CFRelease(allKeys);
    CFRelease(keyPaths);

    return result;
}

static void _CFBundleGetMostAppropriateLocTableDeviceAndPlatformSpecificVariants(CFDataRef mappingData, CFStringRef lang, CFStringRef *stringsVariantName, _CFBundleFileVersion *stringsVariant, CFStringRef *stringsDictVariantName, _CFBundleFileVersion *stringsDictVariant) {
    CFDictionaryRef provenances = _CFBundleCopyLocTableProvenanceForDeviceAndPlatformVariants(mappingData, lang);
    if (provenances == NULL || CFDictionaryGetCount(provenances) == 0) {
        *stringsVariantName = NULL;
        *stringsDictVariantName = NULL;
        *stringsVariant = 0;
        *stringsDictVariant = 0;
        if (provenances) CFRelease(provenances);
        return;
    }

    __block _CFBundleFileVersion mostAppropriateStringsVariant = 0;
    __block CFStringRef mostAppropriateStringsVariantName = NULL;
    __block _CFBundleFileVersion mostAppropriateStringsDictVariant = 0;
    __block CFStringRef mostAppropriateStringsDictVariantName = NULL;
    CFDictionaryApply(provenances, ^(const void * _Nullable languageVariant, const void * _Nullable provenance, Boolean * _Nonnull stop) {
        CFStringRef unused = NULL;
        _CFBundleFileVersion variant = 0;
        _CFBundleSplitFileName(languageVariant, &unused, NULL, NULL, _CFBundleGetProductNameSuffix(), _CFBundleGetPlatformNameSuffix(), _CFBundleSplitFileNameAutomaticFallbackProductSearch, &variant);
        if (unused) CFRelease(unused);

        uint8_t mask = 0;
        CFNumberGetValue(CFDictionaryGetValue(provenances, languageVariant), kCFNumberSInt8Type, &mask);
        if ((mask & _CFBundleLocTableProvenanceStrings) && variant > mostAppropriateStringsVariant) {
            if (mostAppropriateStringsVariantName) CFRelease(mostAppropriateStringsVariantName);
            mostAppropriateStringsVariantName = CFRetain(languageVariant);
            mostAppropriateStringsVariant = variant;
        }
        if ((mask & _CFBundleLocTableProvenanceStringsDict) && variant > mostAppropriateStringsDictVariant) {
            if (mostAppropriateStringsDictVariantName) CFRelease(mostAppropriateStringsDictVariantName);
            mostAppropriateStringsDictVariantName = CFRetain(languageVariant);
            mostAppropriateStringsDictVariant = variant;
        }
    });

    *stringsVariantName = mostAppropriateStringsVariantName; // Transfer retain.
    *stringsVariant = mostAppropriateStringsVariant;
    *stringsDictVariantName = mostAppropriateStringsDictVariantName; // Transfer retain.
    *stringsDictVariant = mostAppropriateStringsDictVariant;

    CFRelease(provenances);
}

static CFDataRef __CFBundleMapOrLoadPlistData(CFBundleRef bundle, CFURLRef url, Boolean attemptToMap, Boolean *didMap, CFErrorRef *outError) CF_RETURNS_RETAINED {
    CFDataRef tableData = NULL;

    // If we are caching, then we want to map the file in, so we can load it piecemeal.
    if (attemptToMap) {
        tableData = _CFBundleMapStringsFile(url);
        *didMap = (tableData != NULL);
    } else {
        *didMap = false;
    }
    if (!tableData) {
        tableData = _CFDataCreateFromURL(url, outError);
    }
    return tableData;
}

static void _releaseStringsSource(CFAllocatorRef alloc, const void *obj) {
    _CFBundleStringsSourceResult result = *(_CFBundleStringsSourceResult *)obj;
    _CFBundleReleaseStringsSources(result);
    free((void *)obj);
}

static void _CFBundleLoadNonLocTableData(CFBundleRef bundle, CFStringRef tableName, _CFBundleStringsSourceResult *localResult, Boolean attemptToMap) {
    // Refuse to map bundles that are unique and are therefore likely temporary.
    if (bundle->_isUnique) {
        attemptToMap = false;
    }

    CFErrorRef error = NULL;
    if (!localResult->stringsData && localResult->stringsTableURL) {
        localResult->stringsData = __CFBundleMapOrLoadPlistData(bundle, localResult->stringsTableURL, attemptToMap, &localResult->stringsMapped, &error);
        if (!localResult->stringsData) {
            os_log_error(_CFBundleLocalizedStringLogger(), "Unable to load .strings file: %@ / %@: %@", bundle, tableName, error);
            if (error) CFRelease(error);
            error = NULL;
        }
    }
    if (!localResult->stringsDictData && localResult->stringsDictTableURL) {
        localResult->stringsDictData = __CFBundleMapOrLoadPlistData(bundle, localResult->stringsDictTableURL, attemptToMap, &localResult->stringsDictMapped, &error);
        if (!localResult->stringsDictData) {
            os_log_error(_CFBundleLocalizedStringLogger(), "Unable to load .stringsdict file: %@ / %@: %@", bundle, tableName, error);
            if (error) CFRelease(error);
            error = NULL;
        }
    }
}

CF_PRIVATE _CFBundleStringsSourceResult _CFBundleGetStringsSources(CFBundleRef bundle, CFStringRef tableName, CFStringRef localizationName) {
    _CFBundleStringsSourceResult result = { 0 };
    CFDataRef loctableData = NULL;

    // Map in the loctable if it exists.
    os_unfair_lock_lock_with_options(&bundle->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (!bundle->_stringSourceTable) {
        CFDictionaryValueCallBacks stringSourceCallbacks = {
            .release = _releaseStringsSource
        };
        bundle->_stringSourceTable = CFDictionaryCreateMutable(kCFAllocatorSystemDefault, 0, &kCFCopyStringDictionaryKeyCallBacks, &stringSourceCallbacks);
    }
    _CFBundleStringsSourceResult *cachedResult = (_CFBundleStringsSourceResult *)CFDictionaryGetValue(bundle->_stringSourceTable, tableName);
    os_unfair_lock_unlock(&bundle->_lock);

    if (!cachedResult || !cachedResult->locTableData) {
        CFURLRef locTableURL = NULL;
        if (cachedResult) {
            locTableURL = cachedResult->locTableURL ? CFRetain(cachedResult->locTableURL) : NULL;
        } else {
            locTableURL = CFBundleCopyResourceURL(bundle, tableName, _CFBundleLocTableType, NULL);
        }
        if (locTableURL) {
            // Only attempt to map the the loctable file if we're going to cache the mapping. We won't do so either when the caller requested a non-preferred localization, or when we've already cached results for this table, which indicates that we failed to map the loctable previously.
            // Also, refuse to map the file if the bundle is unique, and therefore likely temporary.
            if (localizationName == NULL && cachedResult == NULL && !bundle->_isUnique) {
                loctableData = _CFBundleMapStringsFile(locTableURL);
            }
            if (loctableData) {
                result.locTableMapped = true;
            } else {
                // A loctable exists, but we failed to map it for some reason. We need to fall back to reading it in fully to get the data.
                CFErrorRef error = NULL;
                loctableData = _CFDataCreateFromURL(locTableURL, &error);
                if (loctableData) {
                    result.locTableMapped = false;
                } else {
                    CFStringRef errorDesc = _CFErrorCreateUnlocalizedDebugDescription(error);
                    os_log_error(_CFBundleLocalizedStringLogger(), "loctable failed to load for bundle: %@, table: %@: %@", bundle, tableName, errorDesc);
                    CFRelease(errorDesc);
                    CFRelease(error);
                }
            }
            result.locTableURL = locTableURL; // Transfer retain.
        }
    } else {
        loctableData = CFRetain(cachedResult->locTableData);
        result.locTableMapped = cachedResult->locTableMapped;
    }

    // MOST scenarios have us preferring .stringsdict content over .strings content, but there are some where we'll switch this around.
    result.preferStringsDictContent = true;

    if (localizationName) {
        // This is easy. The caller is asking for a specific localization, so we just look up the files and determine whether we use the loctable at all.
        // IGNORE the cachedResult in this case, as it only applies to the preferred localization.
        CFURLRef stringsTableURL = CFBundleCopyResourceURLForLocalization(bundle, tableName, _CFBundleStringTableType, NULL, localizationName);
        CFURLRef stringsDictTableURL = CFBundleCopyResourceURLForLocalization(bundle, tableName, _CFBundleStringDictTableType, NULL, localizationName);
        result.stringsTableURL = stringsTableURL;
        result.stringsLang = CFRetain(localizationName);
        result.stringsDictTableURL = stringsDictTableURL;
        result.stringsDictLang = CFRetain(localizationName);

        if (loctableData) {
            // It's rare, but possible, for a loctable to contain BOTH .strings and .stringsdict content, but a root that was installed has only one or the other. This ensures that we use the loctable for the data that it provides in addition to the one file that's on disk.
            // Or if both files exist, then we completely ignore the loctable.
            CFStringRef loctableStringsVariantName = NULL;
            _CFBundleFileVersion loctableStringsVersion = 0;
            CFStringRef loctableStringsDictVariantName = NULL;
            _CFBundleFileVersion loctableStringsDictVersion = 0;
            _CFBundleGetMostAppropriateLocTableDeviceAndPlatformSpecificVariants(loctableData, localizationName, &loctableStringsVariantName, &loctableStringsVersion, &loctableStringsDictVariantName, &loctableStringsDictVersion);

            // We may choose to use the loctable if we find a more appropriate language variant in it than the actual file on disk.
            Boolean useLocTableForStrings = false;
            if (loctableStringsVariantName) {
                if (stringsTableURL) {
                    _CFBundleFileVersion version = _CFBundleGetFileVersionForStringsResourceURL(stringsTableURL);
                    useLocTableForStrings = loctableStringsVersion > version;
                } else {
                    useLocTableForStrings = true;
                }
            }
            if (useLocTableForStrings) {
                if (result.stringsTableURL) CFRelease(result.stringsTableURL);
                result.stringsTableURL = NULL;
                if (result.stringsLang) CFRelease(result.stringsLang);
                result.stringsLang = CFRetain(loctableStringsVariantName);
            }

            Boolean useLocTableForStringsDict = false;
            if (loctableStringsDictVariantName) {
                if (stringsDictTableURL) {
                    _CFBundleFileVersion version = _CFBundleGetFileVersionForStringsResourceURL(stringsDictTableURL);
                    useLocTableForStringsDict = loctableStringsDictVersion > version;
                } else {
                    useLocTableForStringsDict = true;
                }
            }
            if (useLocTableForStringsDict) {
                if (result.stringsDictTableURL) CFRelease(result.stringsDictTableURL);
                result.stringsDictTableURL = NULL;
                if (result.stringsDictLang) CFRelease(result.stringsDictLang);
                result.stringsDictLang = CFRetain(loctableStringsDictVariantName);

                if (stringsTableURL) result.preferStringsDictContent = false;  // A lone .strings file should take precedence over .loctable .stringsdict content.
            }

            if (useLocTableForStrings || useLocTableForStringsDict) {
                result.locTableData = CFRetain(loctableData);
            }

            if ((result.stringsTableURL && !useLocTableForStrings) || (result.stringsDictTableURL && !useLocTableForStringsDict)) {
                os_log_debug(_CFBundleLocalizedStringLogger(), "loctable overridden by installed files. Bundle: %@, table: %@, language: %@", bundle, tableName, localizationName);
            }
        }
        _CFBundleLoadNonLocTableData(bundle, tableName, &result, false /* do not map */);

    } else if (cachedResult) {
        // We've already calculated some results, just adopt it all.
        _CFBundleReleaseStringsSources(result);
        result = *cachedResult;
        _CFBundleRetainStringsSources(result);

        if (loctableData && !result.locTableIgnoredForPreferredLanguage) {
            result.locTableData = CFRetain(loctableData);
        }

        // If we have a cached result, but no cached strings data, then we know mapping failed earlier. Read them in directly for this attempt only.
        _CFBundleLoadNonLocTableData(bundle, tableName, &result, false /* do not map */);

    } else {
        CFURLRef stringsTableURL = CFBundleCopyResourceURL(bundle, tableName, _CFBundleStringTableType, NULL);
        CFURLRef stringsDictTableURL = CFBundleCopyResourceURL(bundle, tableName, _CFBundleStringDictTableType, NULL);

        if (loctableData == NULL) {
            // Fast-path the external app/framework case where there is no .loctable.
            if (stringsTableURL) {
                result.stringsTableURL = CFRetain(stringsTableURL);
                result.stringsLang = _CFBundleCopyLanguageForStringsResourceURL(stringsTableURL);
            }
            if (stringsDictTableURL) {
                result.stringsDictTableURL = CFRetain(stringsDictTableURL);
                result.stringsDictLang = _CFBundleCopyLanguageForStringsResourceURL(stringsDictTableURL);
            }
            if (result.stringsLang && result.stringsDictLang && !CFEqual(result.stringsLang, result.stringsDictLang)) {
                // If the langauges are not the same, then determine which one to prioritize based on the preferred language index.
                CFArrayRef preferredLocs = _CFBundleCopyLanguageSearchListInBundle(bundle);
                CFRange range = { 0, CFArrayGetCount(preferredLocs) };
                CFIndex stringsIdx = CFArrayGetFirstIndexOfValue(preferredLocs, range, result.stringsLang);
                CFIndex stringsDictIdx = CFArrayGetFirstIndexOfValue(preferredLocs, range, result.stringsDictLang);
                if (stringsIdx < stringsDictIdx) result.preferStringsDictContent = false;
                CFRelease(preferredLocs);
            }
        } else {
            // We have a .loctable, but we may or may not have .strings/.stringsdict content. In either case, we need to identify which language is the highest priority for both .strings source and .stringsdict source, each of which could come from an actual file on disk, or a .loctable's language sub-table, depending on its provenance.
            CFArrayRef preferredLocs = _CFBundleCopyLanguageSearchListInBundle(bundle);
            CFIndex preferredLocCount = CFArrayGetCount(preferredLocs);
            Boolean foundStrings = false;
            Boolean foundStringsDict = false;
            CFStringRef stringsTableLoc = stringsTableURL ? _CFBundleCopyLanguageForStringsResourceURL(stringsTableURL) : NULL;
            CFStringRef stringsDictTableLoc = stringsDictTableURL ? _CFBundleCopyLanguageForStringsResourceURL(stringsDictTableURL) : NULL;
            Boolean emitMappingData = false;

            _CFBundleFileVersion stringsURLTableVersion = _CFBundleGetFileVersionForStringsResourceURL(stringsTableURL);
            _CFBundleFileVersion stringsDictURLTableVersion = _CFBundleGetFileVersionForStringsResourceURL(stringsDictTableURL);

            // LocProvenance has an extra key that tells us whether an entire loctable has absolutely no .strings content or no .stringsdict content.
            Boolean noLocTableLangHasStrings = false;
            Boolean noLocTableLangHasStringsDict = false;
            _CFBundleGetLocTableProvenanceForLanguage(loctableData, _CFBundleLocTableProvenanceAbsenceMaskKey, &noLocTableLangHasStrings, &noLocTableLangHasStringsDict);

            for (CFIndex idx = 0; idx < preferredLocCount; idx++) {
                CFStringRef lang = CFArrayGetValueAtIndex(preferredLocs, idx);

                // Parse the loctable data for the provenance of the current language's loctable content, but only if we know there's potential data to be found.
                CFStringRef loctableStringsVariantName = NULL;
                _CFBundleFileVersion loctableStringsVersion = 0;
                CFStringRef loctableStringsDictVariantName = NULL;
                _CFBundleFileVersion loctableStringsDictVersion = 0;
                if ((!foundStrings && !noLocTableLangHasStrings) || (!foundStringsDict && !noLocTableLangHasStringsDict)) {
                    _CFBundleGetMostAppropriateLocTableDeviceAndPlatformSpecificVariants(loctableData, lang, &loctableStringsVariantName, &loctableStringsVersion, &loctableStringsDictVariantName, &loctableStringsDictVersion);
                }

                // First look for .stringsdict content in this language, either from a file, or from the .loctable.
                if (!foundStringsDict) {
                    if (stringsDictTableLoc && CFEqual(lang, stringsDictTableLoc) && stringsDictURLTableVersion >= loctableStringsDictVersion) {
                        foundStringsDict = true;
                        result.stringsDictTableURL = CFRetain(stringsDictTableURL);
                        result.stringsDictLang = CFRetain(lang);
                    } else if (loctableStringsDictVariantName) {
                        foundStringsDict = true;
                        emitMappingData = true;
                        result.stringsDictLang = CFRetain(loctableStringsDictVariantName);
                    }
                }

                // Next look for .strings content in the same way.
                if (!foundStrings) {
                    if (stringsTableLoc && CFEqual(lang, stringsTableLoc) && stringsURLTableVersion >= loctableStringsVersion) {
                        foundStrings = true;
                        result.stringsTableURL = CFRetain(stringsTableURL);
                        result.stringsLang = CFRetain(lang);
                    } else if (loctableStringsVariantName) {
                        foundStrings = true;
                        emitMappingData = true;
                        result.stringsLang = CFRetain(loctableStringsVariantName);
                    }

                    // If we found a higher-priority .strings content source, prefer it.
                    if (foundStrings && !foundStringsDict) {
                        result.preferStringsDictContent = false;
                    }
                }

                if (loctableStringsDictVariantName) CFRelease(loctableStringsDictVariantName);
                if (loctableStringsVariantName) CFRelease(loctableStringsVariantName);

                // It's very common for a table to consist of only .strings files. These checks ensure that if we have already found .strings content, and there isn't ANY .stringsdict to find, we stop the enumeration.
                Boolean noMoreStringsToLookFor = (foundStrings || (noLocTableLangHasStrings && stringsTableLoc == NULL));
                Boolean noMoreStringsDictToLookFor = (foundStringsDict || (noLocTableLangHasStringsDict && stringsDictTableLoc == NULL));
                if (noMoreStringsToLookFor && noMoreStringsDictToLookFor) {
                    break;
                }
            }

            result.locTableData = CFRetain(loctableData);
            if (!emitMappingData) {
                os_log_debug(_CFBundleLocalizedStringLogger(), "loctable overridden by installed files. Bundle: %@, table: %@", bundle, tableName);
                result.locTableIgnoredForPreferredLanguage = true;
            }

            if (stringsTableLoc) CFRelease(stringsTableLoc);
            if (stringsDictTableLoc) CFRelease(stringsDictTableLoc);
            CFRelease(preferredLocs);
        }

        _CFBundleLoadNonLocTableData(bundle, tableName, &result, true /* attempt to map */);

        if (stringsTableURL) CFRelease(stringsTableURL);
        if (stringsDictTableURL) CFRelease(stringsDictTableURL);

        os_unfair_lock_lock_with_options(&bundle->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
        _CFBundleStringsSourceResult *existingCachedResult = (_CFBundleStringsSourceResult *)CFDictionaryGetValue(bundle->_stringSourceTable, tableName);
        if (!existingCachedResult) {
            _CFBundleStringsSourceResult *newCachedResult = malloc(sizeof(_CFBundleStringsSourceResult));
            memcpy(newCachedResult, &result, sizeof(_CFBundleStringsSourceResult));

            // Don't cache non-mapped data.
            if (!result.stringsMapped) {
                newCachedResult->stringsData = NULL;
            }
            if (!result.stringsDictMapped) {
                newCachedResult->stringsDictData = NULL;
            }
            if (!result.locTableMapped) {
                newCachedResult->locTableData = NULL;
            }

            _CFBundleRetainStringsSources(*newCachedResult);
            CFDictionarySetValue(bundle->_stringSourceTable, tableName, newCachedResult);
        }
        os_unfair_lock_unlock(&bundle->_lock);

        // After caching this result, we might need to clear out the loctable data if it was overridden.
        if (result.locTableIgnoredForPreferredLanguage && result.locTableData) {
            CFRelease(result.locTableData);
            result.locTableData = NULL;
        }

    }
    if (loctableData) CFRelease(loctableData);

    return result;
}

CF_PRIVATE void _CFBundleFlushStringSourceCache(CFBundleRef bundle) {
    os_unfair_lock_lock_with_options(&bundle->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (bundle->_stringSourceTable) {
        CFRelease(bundle->_stringSourceTable);
        bundle->_stringSourceTable = NULL;
    }
    os_unfair_lock_unlock(&bundle->_lock);
}

static CFTypeRef __CFBundleCreateStringsFromPlistData(CFBundleRef bundle, CFArrayRef keyPath, CFDataRef tableData, Boolean mapped, CFStringRef tableName) CF_RETURNS_RETAINED {
    CFTypeRef result = NULL;
    CFErrorRef error = NULL;
    if (keyPath) {
        CFSetRef keySet = CFSetCreate(kCFAllocatorSystemDefault, (const void **)&keyPath, 1, &kCFTypeSetCallBacks);
        CFMutableDictionaryRef values = NULL;
        CFOptionFlags options = kCFPropertyListMutableContainers;
        if (mapped) {
            options |= kCFPropertyListAllowNoCopyLeaves;
        }
        if (_CFPropertyListCreateFiltered(CFGetAllocator(bundle), tableData, options, keySet, (CFPropertyListRef *)&values, &error)) {
            result = values;
        } else if (error) {
            os_log_error(_CFBundleLocalizedStringLogger(), "Unable to read key-path %@ from .strings file: %@ / %@: %@", keyPath, bundle, tableName, error);
            CFRelease(error);
            error = NULL;
        }
        CFRelease(keySet);
    } else {
        CFOptionFlags options = kCFPropertyListImmutable;
        if (mapped) {
            options |= kCFPropertyListAllowNoCopyLeaves;
        }
        CFDictionaryRef entireTable = (CFDictionaryRef)CFPropertyListCreateWithData(CFGetAllocator(bundle), tableData, options, NULL, &error);

        if (entireTable && CFDictionaryGetTypeID() != CFGetTypeID(entireTable)) {
            os_log_error(_CFBundleLocalizedStringLogger(), "Unable to load .strings file: %@ / %@: Top-level object was not a dictionary", bundle, tableName);
            CFRelease(entireTable);
        } else if (!entireTable && error) {
            os_log_error(_CFBundleLocalizedStringLogger(), "Unable to load .strings file: %@ / %@: %@", bundle, tableName, error);
            CFRelease(error);
            error = NULL;
        } else {
            result = entireTable;
        }
    }
    return result;
}

/* outActualTableFile is the URL to a localization table file we're getting strings from. It may be set to NULL on return to mean that we have pulled this from the cache of the preferred language, which is fine since we want this URL to determine which localization was picked. */
static CFDictionaryRef _copyStringTable(CFBundleRef bundle, CFStringRef tableName, CFStringRef _Nullable key, CFStringRef localizationName, Boolean preventMarkdownParsing, CFURLRef *outActualLocalizationFile) {

    // Check the cache first. If it's not there, populate the cache and check again.

    Boolean useCache = (!CFStringHasSuffix(tableName, CFSTR(".nocache")) || !_CFExecutableLinkedOnOrAfter(CFSystemVersionLeopard)) && localizationName == NULL;

    os_unfair_lock_lock_with_options(&bundle->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    // Only consult the cache when a specific localization has not been requested. We only cache results for the preferred language as determined by normal bundle lookup rules.
    if (useCache && bundle->_stringTable) {
        CFDictionaryRef stringTable = (CFDictionaryRef)CFDictionaryGetValue(bundle->_stringTable, tableName);
        if (stringTable) {
            if (key) {
                Boolean result = CFDictionaryContainsKey(stringTable, key);
                if (result) {
                    if (outActualLocalizationFile) {
                        *outActualLocalizationFile = NULL; // Preferred localization.
                    }
                }

                // Keep track of misses so that we don't repeatedly try lazily loading non-existent keys.
                Boolean knownMiss = false;
                if (!result && bundle->_stringTableMisses) {
                    CFSetRef misses = CFDictionaryGetValue(bundle->_stringTableMisses, tableName);
                    if (misses) {
                        knownMiss = CFSetContainsValue(misses, key);
                    }
                }

                if (result || knownMiss || (bundle->_completeStringTables && CFSetContainsValue(bundle->_completeStringTables, tableName))) {
                    CFDictionaryRef copy = CFDictionaryCreateCopy(kCFAllocatorSystemDefault, stringTable); // Copy required since otherwise we return the lock-protected internal mutable dictionary outside the lock! Fortunately, this should be CoW'd.
                    os_unfair_lock_unlock(&bundle->_lock);
                    return copy;
                } else {
                    os_log_debug(_CFBundleLocalizedStringLogger(), "Lazy cache miss for bundle: %@ key: %@ table: %@", bundle, key, tableName);
                } // fall through to get lazy value from the mapped data.
            } else if (bundle->_completeStringTables && CFSetContainsValue(bundle->_completeStringTables, tableName)) {
                CFDictionaryRef copy = CFDictionaryCreateCopy(kCFAllocatorSystemDefault, stringTable); // Copy required since otherwise we return the lock-protected internal mutable dictionary outside the lock! Fortunately, this should be CoW'd.
                os_unfair_lock_unlock(&bundle->_lock);
                return copy;
            } // else client has asked for the whole table, but the whole table hasn't been fetched yet.
        } else if (bundle->_completeStringTables && CFSetContainsValue(bundle->_completeStringTables, tableName)) {
            os_unfair_lock_unlock(&bundle->_lock);
            // No content was ever found for this table.
            return NULL;
        }
    }

    // Not in the local cache, so load the table. Unlock so we don't hold the lock across file system access.
    os_unfair_lock_unlock(&bundle->_lock);

    // Grab all the sources that we might use to load this string (.strings URL, .stringsdict URL, and/or .loctable)
    _CFBundleStringsSourceResult sources = _CFBundleGetStringsSources(bundle, tableName, localizationName);

    // If any one data source turns out to not be mapped, implying that we're going to end up reading and caching the entire plist, we need to make sure that we do the same for ALL applicable sources, even if they are mapped. Otherwise we run the risk of calling the table "complete" when one of the sources was actually loaded lazily.
    __block Boolean fullyLoadAllSources = false;

    // If we've loaded all content for this table, then we can mark it as complete, assuming we intend to cache it.
    __block Boolean markTableComplete = false;

    // Returns whether this source provided the requested key.
    Boolean (^_loadStringsFromData)(CFStringRef, CFDataRef, Boolean, CFMutableDictionaryRef) = ^Boolean(CFStringRef key, CFDataRef tableData, Boolean mapped, CFMutableDictionaryRef result) {
        Boolean didLoad = false;
        CFStringRef requestedKey = key;
        if (fullyLoadAllSources && useCache) {
            // If we're caching strings (preferred localization), but we're unable to map for whatever reason, we should fall back to loading ALL the strings. Otherwise we're likely to hit the disk and load the entire file contents MANY times, which would be horrible for perf.
            key = NULL;
        }

        // If we only need one specific key, and it's already present, bail out early.
        if (key && CFDictionaryGetValue(result, key) != NULL) return false;

        CFArrayRef keyPath = NULL;
        if (key) {
            keyPath = CFArrayCreate(kCFAllocatorSystemDefault, (const void **)&key, 1, &kCFTypeArrayCallBacks);
        }
        CFTypeRef stringsResult = __CFBundleCreateStringsFromPlistData(bundle, keyPath, tableData, mapped, tableName);
        if (stringsResult && CFGetTypeID(stringsResult) == _kCFRuntimeIDCFDictionary) {
            if (key) {
                // Don't use CFDictionaryApplyFunction + __CFStringsDictAddFunction on the entire `stringsResult` here, because sometimes _CFPropertyListCreateFiltered fetches more than requested, which can mess up the effective priorities of string values.
                CFTypeRef value = CFDictionaryGetValue(stringsResult, key);
                if (value) {
                    didLoad = true;
                    CFDictionaryAddValue(result, key, value);
                }
            } else {
                // We explicitly requested the whole plist, so just lay it all down here.
                CFDictionaryApplyFunction(stringsResult, __CFStringsDictAddFunction, (void *)result);
                didLoad = CFDictionaryGetValue(result, requestedKey) != NULL;

                // We loaded the entire table. Do not attempt to do any more lazy loading of this table.
                markTableComplete = true;
            }
        }
        if (keyPath) CFRelease(keyPath);
        if (stringsResult) CFRelease(stringsResult);

        return didLoad;
    };

    // Collect all the algorithms for loading strings from .strings/.stringsdict files as well as the .loctable
typedef void (^_CFStringsValueLoader)(CFStringRef key, CFStringRef language, CFMutableDictionaryRef result, CFURLRef *outSourceURL);
    _CFStringsValueLoader stringsTableLoader = NULL;
    _CFStringsValueLoader stringsDictTableLoader = NULL;
    _CFStringsValueLoader locTableFileLoader = NULL;

    CFMutableDictionaryRef stringsTable = CFDictionaryCreateMutable(kCFAllocatorSystemDefault, 0, &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    if (sources.stringsData) {
        if (!sources.stringsMapped) fullyLoadAllSources = true;
        stringsTableLoader = ^(CFStringRef key, CFStringRef languageIgnored, CFMutableDictionaryRef result, CFURLRef *outSrcURL) {
            if (_loadStringsFromData(key, sources.stringsData, sources.stringsMapped, stringsTable)) {
                if (outSrcURL && !*outSrcURL) *outSrcURL = CFRetain(sources.stringsTableURL);
            }
            CFDictionaryApplyFunction(stringsTable, __CFStringsDictAddFunction, (void *)result);
        };
    }

    __block Boolean hasStringsDictContent = false;
    if (sources.stringsDictData) {
        if (!sources.stringsDictMapped) fullyLoadAllSources = true;
        stringsDictTableLoader = ^(CFStringRef key, CFStringRef languageIgnored, CFMutableDictionaryRef result, CFURLRef *outSrcURL) {
            CFIndex originalCount = CFDictionaryGetCount(result);
            if (_loadStringsFromData(key, sources.stringsDictData, sources.stringsDictMapped, result)) {
                if (outSrcURL && !*outSrcURL) *outSrcURL = CFRetain(sources.stringsDictTableURL);
            }
            // We might have loaded and cached some stringsdict contents, even if we didn't find the key in question.
            if (CFDictionaryGetCount(result) > originalCount) {
                hasStringsDictContent = true;
            }
        };
    }

    if (sources.locTableData != NULL) {
        if (!sources.locTableMapped) fullyLoadAllSources = true;
        locTableFileLoader = ^(CFStringRef key, CFStringRef language, CFMutableDictionaryRef result, CFURLRef *outSrcURL) {
            if (!language) return;

            // If the loctable got mapped, or if we're not caching this table, just load the one requested key. Otherwise, load everything so we don't re-read the entire file more times than necessary.
            Boolean success = false;
            if (key != NULL && (!fullyLoadAllSources || !useCache)) {
                if (CFDictionaryGetValue(result, key)) return;
                
                const void *keys[2] = { (const void *)language, (const void *)key };
                CFArrayRef keyPath = CFArrayCreate(kCFAllocatorSystemDefault, keys, 2, &kCFTypeArrayCallBacks);
                CFDictionaryRef singleKeyResult = __CFBundleCreateStringsFromPlistData(bundle, keyPath, sources.locTableData, sources.locTableMapped, tableName);
                CFTypeRef value = _CFPropertyListGetValueWithKeyPath(singleKeyResult, keyPath);
                if (value) {
                    if (CFGetTypeID(value) == _kCFRuntimeIDCFDictionary) {
                        hasStringsDictContent = true;
                    }

                    CFDictionarySetValue(result, key, value);
                    success = true;
                }
                if (singleKeyResult) CFRelease(singleKeyResult);
                CFRelease(keyPath);
            } else {
                CFArrayRef keyPath = CFArrayCreate(kCFAllocatorSystemDefault, (const void **)&language, 1, &kCFTypeArrayCallBacks);
                CFTypeRef nestedLanguageTable = __CFBundleCreateStringsFromPlistData(bundle, keyPath, sources.locTableData, sources.locTableMapped, tableName);
                CFTypeRef justLanguageTable = _CFPropertyListGetValueWithKeyPath(nestedLanguageTable, language);
                if (justLanguageTable && CFGetTypeID(justLanguageTable) == _kCFRuntimeIDCFDictionary && CFDictionaryGetCount(justLanguageTable) > 0) {
                    Boolean containsStrings = false;
                    Boolean containsStringsDict = false;
                    _CFBundleGetLocTableProvenanceForLanguage(sources.locTableData, language, &containsStrings, &containsStringsDict);
                    if (containsStringsDict) {
                        hasStringsDictContent = true;
                    }

                    CFDictionaryApplyFunction(justLanguageTable, __CFStringsDictAddFunction, (void *)result);
                    success = true;

                    // We loaded the entire table. Do not attempt to do any more lazy loading of this table.
                    markTableComplete = true;
                }
                CFRelease(keyPath);
                if (nestedLanguageTable) CFRelease(nestedLanguageTable);
            }

            if (outSrcURL && !*outSrcURL && success) {
                // Create a fake URL for outActualLocalizationFile. All we need is for it to contain an <lang>.lproj component for the upper layers to use it.
                CFStringRef path = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("/LocTable/%@.lproj"), language);
                *outSrcURL = CFURLCreateWithFileSystemPath(kCFAllocatorSystemDefault, path, kCFURLPOSIXPathStyle, true);
                CFRelease(path);
            }

        };
    }

    CFMutableDictionaryRef mutableStringsTable = CFDictionaryCreateMutable(kCFAllocatorSystemDefault, 0, &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    void (^loadStringsInOrder)(CFStringRef, CFMutableDictionaryRef, CFURLRef *) = ^(CFStringRef key, CFMutableDictionaryRef result, CFURLRef *outSrcURL) {
        // 1. If higher priority, load stringsdict content first. A file, if present, always takes precedence over the loctable.
        if (sources.preferStringsDictContent) {
            if (stringsDictTableLoader) stringsDictTableLoader(key, NULL, result, outSrcURL);
            else if (locTableFileLoader) locTableFileLoader(key, sources.stringsDictLang, result, outSrcURL);
        }
        // 2. Load strings strings. A file, if present, always takes precedence over the loctable.
        if (stringsTableLoader) stringsTableLoader(key, NULL, result, outSrcURL);
        else if (locTableFileLoader) locTableFileLoader(key, sources.stringsLang, result, outSrcURL);
        // 3. If lower priority, load stringsdict content last. A file, if present, always takes precedence over the loctable.
        if (!sources.preferStringsDictContent) {
            if (stringsDictTableLoader) stringsDictTableLoader(key, NULL, result, outSrcURL);
            else if (locTableFileLoader) locTableFileLoader(key, sources.stringsDictLang, result, outSrcURL);
        }
    };

    // Load the requesetd key.
    loadStringsInOrder(key, mutableStringsTable, outActualLocalizationFile);


    CFDictionaryRef finalStringsTable = NULL;
    if (hasStringsDictContent) {


        finalStringsTable = CFRetain(mutableStringsTable);

    } else {
        finalStringsTable = CFRetain(mutableStringsTable);
    }
    CFRelease(mutableStringsTable);

    _CFBundleReleaseStringsSources(sources);
    if (stringsTable) CFRelease(stringsTable);

    // Insert the result into our local cache
    if (useCache) {
        // Take lock again, because this we will unlock after getting the value out of the table.
        os_unfair_lock_lock_with_options(&bundle->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
        if (!bundle->_stringTable) bundle->_stringTable = CFDictionaryCreateMutable(CFGetAllocator(bundle), 0, &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

        CFMutableDictionaryRef table = (CFMutableDictionaryRef)CFDictionaryGetValue(bundle->_stringTable, tableName);
        if (!table) {
            table = CFDictionaryCreateMutable(CFGetAllocator(bundle), 0, &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            CFDictionarySetValue(bundle->_stringTable, tableName, table);
            CFRelease(table);
        }

        if (!stringsTableLoader && !stringsDictTableLoader && !locTableFileLoader) {
            // Record this table as "complete", and remove it from the overall string table.
            markTableComplete = true;
            CFDictionaryRemoveValue(bundle->_stringTable, tableName);
            table = NULL;
        } else if (CFDictionaryGetCount(finalStringsTable) > 0) {
            CFDictionaryApplyFunction(finalStringsTable, __CFStringsDictAddFunction, (void *)table);
        } else if (key) {
            // Lazy loading requires recording misses so we don't lookup for them.
            if (!bundle->_stringTableMisses) {
                bundle->_stringTableMisses = CFDictionaryCreateMutable(kCFAllocatorSystemDefault, 0, &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            }
            CFMutableSetRef misses = (CFMutableSetRef)CFDictionaryGetValue(bundle->_stringTableMisses, tableName);
            if (!misses) {
                misses = CFSetCreateMutable(kCFAllocatorSystemDefault, 0, &kCFCopyStringSetCallBacks);
                CFDictionarySetValue(bundle->_stringTableMisses, tableName, misses);
                CFRelease(misses);
            }
            CFSetAddValue(misses, key);
        } else {
            // Similar situation as when no files exist. The caller requested to load the entire table; files were found, but there's nothing in them.
            // Mark the table as complete and remove it from the overall string table.
            markTableComplete = true;
            CFDictionaryRemoveValue(bundle->_stringTable, tableName);
            table = NULL;
        }

        if (markTableComplete) {
            // We never need to load anything from this table ever again. This would be a good place to compact the dictionary down if/when we ever gain that capability.
            if (!bundle->_completeStringTables) {
                bundle->_completeStringTables = CFSetCreateMutable(kCFAllocatorSystemDefault, 0, &kCFCopyStringSetCallBacks);
            }
            CFSetAddValue(bundle->_completeStringTables, tableName);
        }

        CFDictionaryRef copy = table ? CFDictionaryCreateCopy(kCFAllocatorSystemDefault, table) : NULL;
        os_unfair_lock_unlock(&bundle->_lock);
        CFRelease(finalStringsTable);
        return copy;

    } else {
        return finalStringsTable;
    }
}

CF_EXPORT CFStringRef _CFBundleCopyLocalizedStringForLocalizationTableURLAndMarkdownOption(CFBundleRef bundle, CFStringRef key, CFStringRef value, CFStringRef tableName, CFStringRef localizationName, Boolean preventMarkdownParsing, CFURLRef *outActualTableURL) {

    CF_ASSERT_TYPE(_kCFRuntimeIDCFBundle, bundle);
    if (!key) { return (value ? (CFStringRef)CFRetain(value) : (CFStringRef)CFRetain(CFSTR(""))); }
    
    // Make sure to check the mixed localizations key early -- if the main bundle has not yet been cached, then we need to create the cache of the Info.plist before we start asking for resources (11172381)
    (void)CFBundleAllowMixedLocalizations();
    
    if (!tableName || CFEqual(tableName, CFSTR(""))) tableName = _CFBundleDefaultStringTableName;
    
    CFURLRef actualTableURL = NULL;
    CFDictionaryRef tableResult = _copyStringTable(bundle, tableName, key, localizationName, preventMarkdownParsing, &actualTableURL);
    CFStringRef result = NULL;
    if (tableResult) {
        result = CFDictionaryGetValue(tableResult, key);
        if (result) CFRetain(result);
        CFRelease(tableResult);
    }
    
    if (!result) {
        if (!value) {
            result = (CFStringRef)CFRetain(key);
        } else if (CFEqual(value, CFSTR(""))) {
            result = (CFStringRef)CFRetain(key);
        } else {
            result = (CFStringRef)CFRetain(value);
        }
        static Boolean capitalize = false;
        if (capitalize) {
            CFMutableStringRef capitalizedResult = CFStringCreateMutableCopy(kCFAllocatorSystemDefault, 0, result);
            os_log_error(_CFBundleLocalizedStringLogger(), "ERROR: %@ not found in table %@ of bundle %@", key, tableName, bundle);
            CFStringUppercase(capitalizedResult, NULL);
            CFRelease(result);
            result = capitalizedResult;
        }
    }
    if (outActualTableURL) {
        *outActualTableURL = actualTableURL;
    } else if (actualTableURL) {
        CFRelease(actualTableURL);
    }
    
    os_log_debug(_CFBundleLocalizedStringLogger(), "Bundle: %{private}@, key: %{public}@, value: %{public}@, table: %{public}@, localizationName: %{public}@, result: %{public}@", bundle, key, value, tableName, localizationName, result);
    return result;
}

CF_EXPORT CFStringRef _CFBundleCopyLocalizedStringForLocalizationAndTableURL(CFBundleRef bundle, CFStringRef key, CFStringRef value, CFStringRef tableName, CFStringRef localizationName, CFURLRef *outActualTableURL) {
    return _CFBundleCopyLocalizedStringForLocalizationTableURLAndMarkdownOption(bundle, key, value, tableName, localizationName, false, outActualTableURL);
}

CF_EXPORT CFStringRef CFBundleCopyLocalizedStringForLocalization(CFBundleRef bundle, CFStringRef key, CFStringRef value, CFStringRef tableName, CFStringRef localizationName) {
    return _CFBundleCopyLocalizedStringForLocalizationTableURLAndMarkdownOption(bundle, key, value, tableName, localizationName, false, NULL);
}

CF_EXPORT CFDictionaryRef CFBundleCopyLocalizedStringTableForLocalization(CFBundleRef bundle, CFStringRef tableName, CFStringRef localizationName) {
    CF_ASSERT_TYPE(_kCFRuntimeIDCFBundle, bundle);

    // Make sure to check the mixed localizations key early -- if the main bundle has not yet been cached, then we need to create the cache of the Info.plist before we start asking for resources (11172381)
    (void)CFBundleAllowMixedLocalizations();

    if (!tableName || CFEqual(tableName, CFSTR(""))) tableName = _CFBundleDefaultStringTableName;

    CFDictionaryRef tableResult = _copyStringTable(bundle, tableName, NULL /* Fetch everything */, localizationName, false, NULL);
    return tableResult ?: CFDictionaryCreate(kCFAllocatorSystemDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}
