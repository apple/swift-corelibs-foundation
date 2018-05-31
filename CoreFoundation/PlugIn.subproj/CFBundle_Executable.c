/*  CFBundle_Executable.c
    Copyright (c) 1999-2018, Apple Inc. and the Swift project authors

    Portions Copyright (c) 2014-2017, Apple Inc. and the Swift project authors
    Licensed under Apache License v2.0 with Runtime Library Exception
    See http://swift.org/LICENSE.txt for license information
    See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
    Responsibility: Tony Parker
 */

#include <CoreFoundation/CFBundle.h>
#include "CFBundle_Internal.h"

#if DEPLOYMENT_TARGET_EMBEDDED || DEPLOYMENT_TARGET_EMBEDDED_MINI
#include <dlfcn.h>
#endif

#if FHS_BUNDLES
    #define _CFBundleFHSExecutablesDirectorySuffix CFSTR(".executables")
    #define _CFBundleFHSDirectoryCLiteral_libexec "libexec"

    CONST_STRING_DECL(_kCFBundleFHSDirectory_bin, "bin");
    CONST_STRING_DECL(_kCFBundleFHSDirectory_sbin, "sbin");
    CONST_STRING_DECL(_kCFBundleFHSDirectory_lib, "lib");

    #if DEPLOYMENT_TARGET_LINUX
        #if __LP64__
            #define _CFBundleFHSArchDirectorySuffix "64"
        #else // !__LP64__
            #define _CFBundleFHSArchDirectorySuffix "32"
        #endif // __LP64__

        CONST_STRING_DECL(_kCFBundleFHSDirectory_libWithArchSuffix, "lib" _CFBundleFHSArchDirectorySuffix);
    #endif

    #if DEPLOYMENT_TARGET_LINUX
        #define _CFBundleFHSDirectoriesInExecutableSearchOrder \
        _kCFBundleFHSDirectory_bin, \
        _kCFBundleFHSDirectory_sbin, \
        _kCFBundleFHSDirectory_libWithArchSuffix, \
        _kCFBundleFHSDirectory_lib
    #else
        #define _CFBundleFHSDirectoriesInExecutableSearchOrder \
        _kCFBundleFHSDirectory_bin, \
        _kCFBundleFHSDirectory_sbin, \
        _kCFBundleFHSDirectory_lib
    #endif
#endif // FHS_BUNDLES

// This is here because on iPhoneOS with the dyld shared cache, we remove binaries from their
// original locations on disk, so checking whether a binary's path exists is no longer sufficient.
// For performance reasons, we only call dlopen_preflight() after we've verified that the binary
// does not exist at its original path with _CFURLExists().
// See <rdar://problem/6956670>
static Boolean _binaryLoadable(CFURLRef url) {
    Boolean loadable = _CFURLExists(url);
#if DEPLOYMENT_TARGET_EMBEDDED || DEPLOYMENT_TARGET_EMBEDDED_MINI
    if (!loadable) {
        uint8_t path[PATH_MAX];
        if (url && CFURLGetFileSystemRepresentation(url, true, path, sizeof(path))) {
            loadable = dlopen_preflight((char *)path);
        }
    }
#endif
    return loadable;
}

static CFURLRef _CFBundleCopyExecutableURLRaw(CFURLRef urlPath, CFStringRef exeName) {
    // Given an url to a folder and a name, this returns the url to the executable in that folder
    // with that name, if it exists, and NULL otherwise.
    // This function deals with appending the library and executable prefix/suffixes of each platform.
    
    CFURLRef executableURL = NULL;
    if (!urlPath || !exeName) return NULL;
    
#if DEPLOYMENT_TARGET_MACOSX || DEPLOYMENT_TARGET_EMBEDDED || DEPLOYMENT_TARGET_EMBEDDED_MINI
    const uint8_t *image_suffix = (uint8_t *)__CFgetenvIfNotRestricted("DYLD_IMAGE_SUFFIX");
    
    if (image_suffix) {
        CFStringRef newExeName, imageSuffix;
        imageSuffix = CFStringCreateWithCString(kCFAllocatorSystemDefault, (char *)image_suffix, kCFStringEncodingUTF8);
        if (CFStringHasSuffix(exeName, CFSTR(".dylib"))) {
            CFStringRef bareExeName = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, exeName, CFRangeMake(0, CFStringGetLength(exeName)-6));
            newExeName = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@%@.dylib"), bareExeName, imageSuffix);
            CFRelease(bareExeName);
        } else {
            newExeName = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@%@"), exeName, imageSuffix);
        }
        executableURL = CFURLCreateWithFileSystemPathRelativeToBase(kCFAllocatorSystemDefault, newExeName, PLATFORM_PATH_STYLE, false, urlPath);
        if (executableURL && !_binaryLoadable(executableURL)) {
            CFRelease(executableURL);
            executableURL = NULL;
        }
        CFRelease(newExeName);
        CFRelease(imageSuffix);
    }
#endif
    
    if (!executableURL) {
        // Try finding the executable with input name.
        executableURL = CFURLCreateWithFileSystemPathRelativeToBase(kCFAllocatorSystemDefault, exeName, PLATFORM_PATH_STYLE, false, urlPath);
        
        if (executableURL && !_binaryLoadable(executableURL)) {
            CFRelease(executableURL);
            executableURL = NULL;
        }
    }
    
#if FHS_BUNDLES || FREESTANDING_BUNDLES
    if (!executableURL) {
        // Try finding the executable using library prefix/suffix.
        CFStringRef sharedLibraryName = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@%@%@"), _CFBundleSharedLibraryFilenamePrefix, exeName, _CFBundleSharedLibraryFilenameSuffix);
        
        executableURL = CFURLCreateWithFileSystemPathRelativeToBase(kCFAllocatorSystemDefault, sharedLibraryName, PLATFORM_PATH_STYLE, false, urlPath);
        
        if (!_binaryLoadable(executableURL)) {
            CFRelease(executableURL);
            executableURL = NULL;
        }
        
        CFRelease(sharedLibraryName);
    }
    
    if (!executableURL) {
        // Try finding the executable using executable prefix/suffix.
        CFStringRef executableName = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@%@%@"), _CFBundleExecutableFilenamePrefix, exeName, _CFBundleExecutableFilenameSuffix);
        
        executableURL = CFURLCreateWithFileSystemPathRelativeToBase(kCFAllocatorSystemDefault, executableName, PLATFORM_PATH_STYLE, false, urlPath);
        
        if (!_binaryLoadable(executableURL)) {
            CFRelease(executableURL);
            executableURL = NULL;
        }
        
        CFRelease(executableName);
    }
#endif
    
    return executableURL;
}

static CFURLRef _CFBundleCopyExecutableURLInDirectory2(CFBundleRef bundle, CFURLRef url, CFStringRef executableName, Boolean ignoreCache) {
    uint8_t version = 0;
    CFDictionaryRef infoDict = NULL;
    CFStringRef executablePath = NULL;
    CFURLRef executableURL = NULL;
    Boolean lookupMainExe = (executableName ? false : true);
    
    if (bundle) {
        infoDict = CFBundleGetInfoDictionary(bundle);
        version = bundle->_version;
    } else {
        infoDict = _CFBundleCopyInfoDictionaryInDirectory(kCFAllocatorSystemDefault, url, &version);
    }
    
    // If we have a bundle instance and an info dict, see if we have already cached the path
    if (lookupMainExe && !ignoreCache && bundle && bundle->_executablePath) {
        __CFLock(&bundle->_lock);
        executablePath = bundle->_executablePath;
        if (executablePath) CFRetain(executablePath);
        __CFUnlock(&bundle->_lock);
        if (executablePath) {
            executableURL = CFURLCreateWithFileSystemPath(kCFAllocatorSystemDefault, executablePath, PLATFORM_PATH_STYLE, false);
            CFRelease(executablePath);
        }
    }
    
    if (!executableURL) {
        if (lookupMainExe) executableName = _CFBundleCopyExecutableName(bundle, url, infoDict);
        if (executableName) {
#if (DEPLOYMENT_TARGET_EMBEDDED && !TARGET_IPHONE_SIMULATOR)
            Boolean doExecSearch = false;
#else
            Boolean doExecSearch = true;
#endif
            
#if FHS_BUNDLES
            if (bundle && bundle->_isFHSInstalledBundle) {
                
                if (lookupMainExe) {
                    // For a FHS installed bundles we try to find the main executable in the different prefix locations:
                    CFURLRef sharePath = CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorSystemDefault, url);
                    CFURLRef prefixPath = CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorSystemDefault, sharePath);
                    CFRelease(sharePath);
                    
                    CFStringRef directories[] = { _CFBundleFHSDirectoriesInExecutableSearchOrder };
                    size_t directoriesCount = sizeof(directories) / sizeof(directories[0]);
                    
                    for (size_t i = 0; i < directoriesCount; i++) {
                        CFURLRef where = CFURLCreateCopyAppendingPathComponent(kCFAllocatorSystemDefault, prefixPath, directories[i], true);
                        executableURL = _CFBundleCopyExecutableURLRaw(where, executableName);
                        CFRelease(where);
                    }
                    
                    CFRelease(prefixPath);
                }
                else {
                    // For FHS bundles we try to find the auxiliary executables in `prefix/libexec` if.
                    
                    CFURLRef withoutExtension = CFURLCreateCopyDeletingPathExtension(kCFAllocatorSystemDefault, url);
                    CFStringRef lastPathComponent = CFURLCopyLastPathComponent(withoutExtension);
                    
                    CFURLRef libexec = CFURLCreateWithString(kCFAllocatorSystemDefault, CFSTR("../../" _CFBundleFHSDirectoryCLiteral_libexec), url);
                    
                    CFStringRef exeDirName = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@%@"), lastPathComponent, _CFBundleFHSExecutablesDirectorySuffix);
                    CFURLRef exeDirURL = CFURLCreateCopyAppendingPathComponent(kCFAllocatorSystemDefault, libexec, exeDirName, true);
                    executableURL = _CFBundleCopyExecutableURLRaw(exeDirURL, executableName);
                    
                    CFRelease(withoutExtension);
                    CFRelease(lastPathComponent);
                    CFRelease(libexec);
                    CFRelease(exeDirName);
                    CFRelease(exeDirURL);
                }
            }
            else {
#endif
                
                // Now, look for the executable inside the bundle.
                if (!executableURL && doExecSearch && 0 != version) {
                    CFURLRef exeDirURL = NULL;
                    
                    // First, we find the executable directory:
                    
                    if (1 == version) {
                        exeDirURL = CFURLCreateWithString(kCFAllocatorSystemDefault, _CFBundleExecutablesURLFromBase1, url);
                    }
                    else if (2 == version) {
                        exeDirURL = CFURLCreateWithString(kCFAllocatorSystemDefault, _CFBundleExecutablesURLFromBase2, url);
                    }
                    else {
                        
#if FREESTANDING_BUNDLES
                        // For freestanding bundles if the directory has a `.resources` extension, the executable is at the same level.
                        CFStringRef extension = CFURLCopyPathExtension(url);
                        if (extension && CFEqual(extension, _CFBundleSiblingResourceDirectoryExtension)) {
                            exeDirURL = CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorSystemDefault, url);
                        }
#endif
                        
                        if (!exeDirURL) {
                            exeDirURL = (CFURLRef)CFRetain(url);
                        }
                    }
                    
                    // After finding the executable directory, we search the executable:
                    //
                    // Historical note: This used to search the directories "Mac OS X", "MacOSClassic", then "MacOS8".
                    // As of 10.13 we only look in "MacOS".
                    CFURLRef exeSubdirURL = CFURLCreateWithFileSystemPathRelativeToBase(kCFAllocatorSystemDefault, _CFBundleGetPlatformExecutablesSubdirectoryName(), PLATFORM_PATH_STYLE, true, exeDirURL);
                    executableURL = _CFBundleCopyExecutableURLRaw(exeSubdirURL, executableName);
                    CFRelease(exeSubdirURL);
                    
                    if (!executableURL) {
                        executableURL = _CFBundleCopyExecutableURLRaw(exeDirURL, executableName);
                    }
                    
                    CFRelease(exeDirURL);
                    
                    // If this was an old bundle, or we did not find the executable in the Executables subdirectory, look directly in the bundle wrapper.
                    if (!executableURL) {
                        executableURL = _CFBundleCopyExecutableURLRaw(url, executableName);
                    }
                    
#if DEPLOYMENT_TARGET_WINDOWS
                    // Windows only: If we still haven't found the exe, look in the Executables folder.
                    // But only for the main bundle exe
                    if (lookupMainExe && !executableURL) {
                        CFURLRef exeDirURL = CFURLCreateWithString(kCFAllocatorSystemDefault, CFSTR("../../Executables"), url);
                        executableURL = _CFBundleCopyExecutableURLRaw(exeDirURL, executableName);
                        CFRelease(exeDirURL);
                    }
#endif
                }
#if FHS_BUNDLES
            }
#endif
            
            if (lookupMainExe && !ignoreCache && bundle && executableURL) {
                // We found it. Cache the path.
                CFURLRef absURL = CFURLCopyAbsoluteURL(executableURL);
                executablePath = CFURLCopyFileSystemPath(absURL, PLATFORM_PATH_STYLE);
                CFRelease(absURL);
                __CFLock(&bundle->_lock);
                bundle->_executablePath = (CFStringRef)CFRetain(executablePath);
                __CFUnlock(&bundle->_lock);
                CFRelease(executablePath);
            }
            
            if (lookupMainExe && bundle && !executableURL) bundle->_binaryType = __CFBundleNoBinary;
            if (lookupMainExe) CFRelease(executableName);
        }
    }
    
    if (!bundle && infoDict) CFRelease(infoDict);
    return executableURL;
}

static CFStringRef _CFBundleCopyNameByRemovingExcutablePlatformPrefixSuffix(CFStringRef str, CFStringRef prefix, CFStringRef suffix) {
    CFStringRef bundleName = NULL;
    
    // For plaforms without prefix/suffix we must return NULL so it is checked with other type of prefix/suffix.
    if (!(CFEqual(prefix, CFSTR("")) && CFEqual(suffix, CFSTR("")))) {
        
        // Check if the executable has shared library prefix/suffix.
        CFRange prefixRange = CFStringFind(str,
                                           _CFBundleSharedLibraryFilenamePrefix,
                                           kCFCompareAnchored);
        CFRange suffixRange = CFStringFind(str,
                                           _CFBundleSharedLibraryFilenameSuffix,
                                           kCFCompareAnchored|kCFCompareBackwards);
        
        // Only return the stripped string if both the prefix and suffix are found.
        CFIndex inputStringLength = CFStringGetLength(str);
        
        if (prefixRange.location != kCFNotFound &&
            suffixRange.location != kCFNotFound &&
            prefixRange.location == 0 &&
            suffixRange.location + suffixRange.length == inputStringLength) {
            
            CFRange bundleNameRange = CFRangeMake(prefixRange.length,
                                                  inputStringLength - prefixRange.length - suffixRange.length);
            
            bundleName = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, str, bundleNameRange);
        }
    }
    
    return bundleName;
}

static CFURLRef _CFBundleCopyBundleURLForExecutablePath(CFStringRef str) {
    // Needs to handle:
    // - Classic NEXTStep-style bundles (`.framework`, `.app`, `.appex`)
    // - Freestanding bundles (`Bundle.resource` as sibling of the library/executable)
    // - FHS bundles (`prefix/share/Bundle.resource`)
    //
    // Note:
    // For freestanding and FHS bundles, this function has to support removing library/executable prefix/suffix
    // on each platform. For example, it has to detect to the bundle name as `Bundle` for executables
    // like `Bundle.exe` in Windows or `libBundle.so` on Linux.
    
    CFURLRef url = NULL;
    
#if FREESTANDING_BUNDLES
    if (!url) {
        CFStringRef bundleName = NULL;
        
        CFURLRef executableURL = CFURLCreateWithFileSystemPath(kCFAllocatorSystemDefault, str, PLATFORM_PATH_STYLE, false);
        CFStringRef executableName = CFURLCopyLastPathComponent(executableURL);
        
        // Check if the executable has shared library prefix/suffix (libCF.dylib, libCF.so, CF.dll).
        if (!bundleName) {
            bundleName = _CFBundleCopyNameByRemovingExcutablePlatformPrefixSuffix(executableName,
                                                                                  _CFBundleSharedLibraryFilenamePrefix,
                                                                                  _CFBundleSharedLibraryFilenameSuffix);
        }
        
        // Check if the executable has executable-style prefix/suffix (CF.exe).
        if (!bundleName) {
            bundleName = _CFBundleCopyNameByRemovingExcutablePlatformPrefixSuffix(executableName,
                                                                                  _CFBundleExecutableFilenamePrefix,
                                                                                  _CFBundleExecutableFilenameSuffix);
        }
        
        // Otherwise, use the executable name as bundle name (CF).
        if (!bundleName) {
            bundleName = CFStringCreateCopy(kCFAllocatorSystemDefault, executableName);
        }
        
        // Find the sibling `.resources` directory (CF.resources).
        CFURLRef parentDirectory = CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorSystemDefault, executableURL);
        
        CFRelease(executableName);
        CFRelease(executableURL);
        
        CFStringRef siblingResourceDirectoryName = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@.%@"), bundleName, _CFBundleSiblingResourceDirectoryExtension);
        CFRelease(bundleName);
        
        CFURLRef siblingResourceDirectoryURL = CFURLCreateCopyAppendingPathComponent(kCFAllocatorSystemDefault, parentDirectory, siblingResourceDirectoryName, true);
        
        CFRelease(parentDirectory);
        CFRelease(siblingResourceDirectoryName);
        
        // Check that the bundle directory exists.
        if (_CFURLExists(siblingResourceDirectoryURL)) {
            url = siblingResourceDirectoryURL;
        }
        else {
            CFRelease(siblingResourceDirectoryURL);
        }
    }
#endif
    
    if (!url) {
        UniChar buff[CFMaxPathSize];
        CFIndex buffLen;
        CFStringRef outstr;
        
        buffLen = CFStringGetLength(str);
        if (buffLen > CFMaxPathSize) buffLen = CFMaxPathSize;
        CFStringGetCharacters(str, CFRangeMake(0, buffLen), buff);
        
        buffLen = _CFLengthAfterDeletingLastPathComponent(buff, buffLen);  // Remove exe name
        
        if (buffLen > 0) {
            // See if this is a new bundle.  If it is, we have to remove more path components.
            CFIndex startOfLastDir = _CFStartOfLastPathComponent(buff, buffLen);
            if (startOfLastDir > 0 && startOfLastDir < buffLen) {
                CFStringRef lastDirName = CFStringCreateWithCharacters(kCFAllocatorSystemDefault, &(buff[startOfLastDir]), buffLen - startOfLastDir);
                
                if (CFEqual(lastDirName, _CFBundleGetPlatformExecutablesSubdirectoryName())) {
                    // This is a new bundle.  Back off a few more levels
                    if (buffLen > 0) {
                        // Remove platform folder
                        buffLen = _CFLengthAfterDeletingLastPathComponent(buff, buffLen);
                    }
                    if (buffLen > 0) {
                        // Remove executables folder (if present)
                        CFIndex startOfNextDir = _CFStartOfLastPathComponent(buff, buffLen);
                        if (startOfNextDir > 0 && startOfNextDir < buffLen) {
                            CFStringRef nextDirName = CFStringCreateWithCharacters(kCFAllocatorSystemDefault, &(buff[startOfNextDir]), buffLen - startOfNextDir);
                            if (CFEqual(nextDirName, _CFBundleExecutablesDirectoryName)) buffLen = _CFLengthAfterDeletingLastPathComponent(buff, buffLen);
                            CFRelease(nextDirName);
                        }
                    }
                    if (buffLen > 0) {
                        // Remove support files folder
                        buffLen = _CFLengthAfterDeletingLastPathComponent(buff, buffLen);
                    }
                }
                CFRelease(lastDirName);
            }
        }
        
        if (buffLen > 0) {
            outstr = CFStringCreateWithCharactersNoCopy(kCFAllocatorSystemDefault, buff, buffLen, kCFAllocatorNull);
            url = CFURLCreateWithFileSystemPath(kCFAllocatorSystemDefault, outstr, PLATFORM_PATH_STYLE, true);
            CFRelease(outstr);
        }
    }
    
    return url;
}

static CFURLRef _CFBundleCopyResolvedURLForExecutableURL(CFURLRef url) {
    // this is necessary so that we match any sanitization CFURL may perform on the result of _CFBundleCopyBundleURLForExecutableURL()
    CFURLRef absoluteURL, url1, url2, outURL = NULL;
    CFStringRef str, str1, str2;
    absoluteURL = CFURLCopyAbsoluteURL(url);
    str = CFURLCopyFileSystemPath(absoluteURL, PLATFORM_PATH_STYLE);
    if (str) {
        UniChar buff[CFMaxPathSize];
        CFIndex buffLen = CFStringGetLength(str), len1;
        if (buffLen > CFMaxPathSize) buffLen = CFMaxPathSize;
        CFStringGetCharacters(str, CFRangeMake(0, buffLen), buff);
        len1 = _CFLengthAfterDeletingLastPathComponent(buff, buffLen);
        if (len1 > 0 && len1 + 1 < buffLen) {
            str1 = CFStringCreateWithCharacters(kCFAllocatorSystemDefault, buff, len1);
            CFIndex skipSlashCount = 1;
            
#if DEPLOYMENT_TARGET_WINDOWS
            // On Windows, _CFLengthAfterDeletingLastPathComponent will return a value of 3 if the path is at the root (e.g. C:\). This includes the \, which is not the case for URLs with subdirectories
            if (len1 == 3 && buff[1] == ':' && buff[2] == '\\') {
                skipSlashCount = 0;
            }
#endif
            
            str2 = CFStringCreateWithCharacters(kCFAllocatorSystemDefault, buff + len1 + skipSlashCount, buffLen - len1 - skipSlashCount);
            if (str1 && str2) {
                url1 = CFURLCreateWithFileSystemPath(kCFAllocatorSystemDefault, str1, PLATFORM_PATH_STYLE, true);
                if (url1) {
                    url2 = CFURLCreateWithFileSystemPathRelativeToBase(kCFAllocatorSystemDefault, str2, PLATFORM_PATH_STYLE, false, url1);
                    if (url2) {
                        outURL = CFURLCopyAbsoluteURL(url2);
                        CFRelease(url2);
                    }
                    CFRelease(url1);
                }
            }
            if (str1) CFRelease(str1);
            if (str2) CFRelease(str2);
        }
        CFRelease(str);
    }
    if (!outURL) {
        outURL = absoluteURL;
    } else {
        CFRelease(absoluteURL);
    }
    return outURL;
}

// MARK: - Exported Functions

CF_EXPORT CFURLRef _CFBundleCopyExecutableURLInDirectory(CFURLRef url) {
    return _CFBundleCopyExecutableURLInDirectory2(NULL, url, NULL, true);
}

CF_EXPORT CFURLRef _CFBundleCopyOtherExecutableURLInDirectory(CFURLRef url) {
    // As of 10.13, there does not appear to be anyone actually invoking this function (either in the OS or other apps). The search list is also pretty far out of date.
    // Therefore we will just return the same result as _CFBundleCopyExecutableURLInDirectory.
    return _CFBundleCopyExecutableURLInDirectory(url);
}

CF_EXPORT CFURLRef CFBundleCopyExecutableURL(CFBundleRef bundle) {
    return _CFBundleCopyExecutableURLInDirectory2(bundle, bundle->_url, NULL, false);
}

CF_EXPORT CFURLRef CFBundleCopyAuxiliaryExecutableURL(CFBundleRef bundle, CFStringRef executableName) {
    return _CFBundleCopyExecutableURLInDirectory2(bundle, bundle->_url, executableName, true);
}

CF_EXPORT CFURLRef _CFBundleCopyBundleURLForExecutableURL(CFURLRef url) {
    CFURLRef resolvedURL, outurl = NULL;
    CFStringRef str;
    resolvedURL = _CFBundleCopyResolvedURLForExecutableURL(url);
    str = CFURLCopyFileSystemPath(resolvedURL, PLATFORM_PATH_STYLE);
    if (str) {
        outurl = _CFBundleCopyBundleURLForExecutablePath(str);
        CFRelease(str);
    }
    CFRelease(resolvedURL);
    return outurl;
}

CF_EXPORT CFBundleRef _CFBundleCreateWithExecutableURLIfLooksLikeBundle(CFAllocatorRef allocator, CFURLRef url) {
    CFBundleRef bundle = NULL;
    CFURLRef bundleURL = _CFBundleCopyBundleURLForExecutableURL(url), resolvedURL = _CFBundleCopyResolvedURLForExecutableURL(url);
    if (bundleURL && resolvedURL) {
        // We used to call _CFBundleCreateIfLooksLikeBundle here, but switched to the regular CFBundleCreate because we want this to return a result for certain flat bundles as well.
        // It is assumed that users of this SPI do not want this bundle to persist forever, so we use the Unique version of CFBundleCreate.
        bundle = _CFBundleCreateUnique(allocator, bundleURL);
        if (bundle) {
            CFURLRef executableURL = _CFBundleCopyExecutableURLInDirectory2(bundle, bundle->_url, NULL, true);
            char buff1[CFMaxPathSize], buff2[CFMaxPathSize];
            if (!executableURL || !CFURLGetFileSystemRepresentation(resolvedURL, true, (uint8_t *)buff1, CFMaxPathSize) || !CFURLGetFileSystemRepresentation(executableURL, true, (uint8_t *)buff2, CFMaxPathSize) || 0 != strcmp(buff1, buff2)) {
                CFRelease(bundle);
                bundle = NULL;
            }
            if (executableURL) CFRelease(executableURL);
        }
    }
    if (bundleURL) CFRelease(bundleURL);
    if (resolvedURL) CFRelease(resolvedURL);
    return bundle;
}

CF_EXPORT CFBundleRef _CFBundleCreateWithExecutableURLIfMightBeBundle(CFAllocatorRef allocator, CFURLRef url) {
    CFBundleRef result = _CFBundleCreateWithExecutableURLIfLooksLikeBundle(allocator, url);
    
    // This function applies additional requirements on a bundle to return a result
    // The above makes sure that:
    //  0. CFBundleCreate must succeed using a URL derived from the executable URL
    //  1. The bundle must have an executableURL, and it must match the passed in executable URL
    
    // This function additionally requires that
    //  2. If flat, the bundle must have a non-empty Info.plist. (15663535)
    if (result) {
        uint8_t localVersion = _CFBundleEffectiveLayoutVersion(result);
        if (3 == localVersion || 4 == localVersion) {
            CFDictionaryRef infoPlist = CFBundleGetInfoDictionary(result);
            if (!infoPlist || (infoPlist && CFDictionaryGetCount(infoPlist) == 0)) {
                CFRelease(result);
                result = NULL;
            }
        }
    }
    return result;
}
