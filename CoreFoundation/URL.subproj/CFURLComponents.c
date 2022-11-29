/*	CFURLComponents.c
	Copyright (c) 2015-2022, Apple Inc. All rights reserved.
 
	Portions Copyright (c) 2014-2019, Apple Inc. and the Swift project authors
	Licensed under Apache License v2.0 with Runtime Library Exception
	See http://swift.org/LICENSE.txt for license information
	See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
	Responsibility: Jim Luther/Chris Linn
*/

#include <unicode/uidna.h>

#include <CoreFoundation/CFURLComponents.h>
#include "CFInternal.h"
#include "CFRuntime_Internal.h"
#include "CFURLComponents_Internal.h"


struct __CFURLComponents {
    CFRuntimeBase _base;
    
    os_unfair_lock _lock;
    
    // if inited from URL, I need to keep the URL string and the parsing info
    CFStringRef _urlString;
    struct _URIParseInfo _parseInfo;
    
    /*
     Getters will get from either the URL or the set value, so if there's a url string, I need to know if we've attempted to get the value from the url. These flags indicate if the NSURLComponents' _xxxxComponent instance variables can be used.
     
     Setters will set the _xxxxComponent ivar. Components that can be percent-encoded will be percent-encoded in the _xxxxComponent ivar. For example, [NSURLComponents setPath:] will percent-encode the path argument and set _pathComponent; [NSURLComponents setPercentEncodedPath:] will simply copy the path argument and set _pathComponent.
     
     [NSURLComponents URL] and [NSURLComponents URLRelativeToURL:] will first set all components and mark them all valid.
     
     [NSURLComponents init] will set _urlString to nil, all _XXXXComponentValid flags to true, and all _XXXXComponent ivars to nil.
     */
    
    // these flags indicate if the _schemeComponent through _fragmentComponent ivars are valid or not.
    uint32_t	_schemeComponentValid	: 1;
    uint32_t	_userComponentValid     : 1;
    uint32_t	_passwordComponentValid	: 1;
    uint32_t	_hostComponentValid     : 1;
    uint32_t	_portComponentValid     : 1;
    uint32_t	_pathComponentValid     : 1;
    uint32_t	_queryComponentValid	: 1;
    uint32_t	_fragmentComponentValid	: 1;

    // These ivars are used by the getters and by [NSURLComponents URL] and [NSURLComponents URLRelativeToURL:]. The values (if not nil) are always correctly percent-encoded.
    CFStringRef _schemeComponent;
    CFStringRef _userComponent;
    CFStringRef _passwordComponent;
    CFStringRef _hostComponent;
    CFNumberRef _portComponent;
    CFStringRef _pathComponent;
    CFStringRef _queryComponent;
    CFStringRef _fragmentComponent;
};

static Boolean __CFURLComponentsEqual(CFTypeRef left, CFTypeRef right);
static CFHashCode __CFURLComponentsHash(CFTypeRef cf);

static CFStringRef __CFURLComponentsCopyDescription(CFTypeRef cf) {
    CFURLComponentsRef components = (CFURLComponentsRef)cf;
    CFStringRef scheme = _CFURLComponentsCopyScheme(components);
    CFStringRef percentEncodedUser = _CFURLComponentsCopyPercentEncodedUser(components);
    CFStringRef percentEncodedPassword = _CFURLComponentsCopyPercentEncodedPassword(components);
    CFStringRef percentEncodedHost = _CFURLComponentsCopyPercentEncodedHost(components);
    CFNumberRef port = _CFURLComponentsCopyPort(components);
    CFStringRef percentEncodedPath = _CFURLComponentsCopyPercentEncodedPath(components);
    CFStringRef percentEncodedQuery = _CFURLComponentsCopyPercentEncodedQuery(components);
    CFStringRef percentEncodedFragment = _CFURLComponentsCopyPercentEncodedFragment(components);
    CFStringRef result = CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("<URLComponents %p> {scheme = %@, user = %@, password = %@, host = %@, port = %@, path = %@, query = %@, fragment = %@}"), cf, scheme, percentEncodedUser, percentEncodedPassword, percentEncodedHost, port, percentEncodedPath, percentEncodedQuery, percentEncodedFragment);
    if ( scheme ) CFRelease(scheme);
    if ( percentEncodedUser ) CFRelease(percentEncodedUser);
    if ( percentEncodedPassword ) CFRelease(percentEncodedPassword);
    if ( percentEncodedHost ) CFRelease(percentEncodedHost);
    if ( port ) CFRelease(port);
    if ( percentEncodedPath ) CFRelease(percentEncodedPath);
    if ( percentEncodedQuery ) CFRelease(percentEncodedQuery);
    if ( percentEncodedFragment ) CFRelease(percentEncodedFragment);
    return ( result );
}

CF_EXPORT_NONOBJC_ONLY void __CFURLComponentsDeallocate(CFTypeRef cf) {
    CFURLComponentsRef instance = (CFURLComponentsRef)cf;
    __CFGenericValidateType(cf, _CFURLComponentsGetTypeID());
    
    if (instance->_urlString) CFRelease(instance->_urlString);
    if (instance->_schemeComponent) CFRelease(instance->_schemeComponent);
    if (instance->_userComponent) CFRelease(instance->_userComponent);
    if (instance->_passwordComponent) CFRelease(instance->_passwordComponent);
    if (instance->_hostComponent) CFRelease(instance->_hostComponent);
    if (instance->_portComponent) CFRelease(instance->_portComponent);
    if (instance->_pathComponent) CFRelease(instance->_pathComponent);
    if (instance->_queryComponent) CFRelease(instance->_queryComponent);
    if (instance->_fragmentComponent) CFRelease(instance->_fragmentComponent);
}

const CFRuntimeClass __CFURLComponentsClass = {
    0,
    "CFURLComponents",
    NULL,      // init
    NULL,      // copy
    __CFURLComponentsDeallocate,
    __CFURLComponentsEqual,
    __CFURLComponentsHash,
    NULL,      //
    __CFURLComponentsCopyDescription
};

CFTypeID _CFURLComponentsGetTypeID(void) {
    return _kCFRuntimeIDCFURLComponents;
}

// Taken from WebKit URLParser.h
#define URL_MAX_BUFFER_LEN 2048

/// Taken from WebKit URLParser.h
static UIDNA* __CFURLComponentsDomainTranscoder() {
    static UIDNA* encoder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UErrorCode status = U_ZERO_ERROR;
        encoder = uidna_openUTS46(UIDNA_CHECK_BIDI | UIDNA_CHECK_CONTEXTJ | UIDNA_NONTRANSITIONAL_TO_UNICODE | UIDNA_NONTRANSITIONAL_TO_ASCII, &status);
        if (!U_SUCCESS(status)) {
            os_log_error(_CFOSLog(), "CFURLComponents failed to create ICU Domain Transcoder(UIDNA) with error: %d", status);
            encoder = NULL;
        }
    });
    return encoder;
}

static inline void __CFURLComponentsPercentEncodeComponent(CFMutableStringRef string, CFRange componentRange, CFCharacterSetRef allowedCharacters) {
    CFStringRef componentString = CFStringCreateWithSubstring(kCFAllocatorDefault, string, componentRange);
    CFStringRef encodedString = _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorDefault, componentString, allowedCharacters);
    CFStringReplace(string, componentRange, encodedString);
    CFRelease(componentString);
    CFRelease(encodedString);
}

static inline Boolean __CFURLComponentsEncodeDecodeHost(CFMutableStringRef urlString, CFRange hostRange, Boolean shouldEncode, Boolean shouldUsePercentEncode) {
    // Attempts to encode the host
    Boolean result = false;
    CFStringRef hostString = CFStringCreateWithSubstring(kCFAllocatorDefault, urlString, hostRange);
    if (shouldUsePercentEncode) {
        CFStringRef codedHostName = shouldEncode ?
            _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, hostString, _CFURLComponentsGetURLHostAllowedCharacterSet()) :
            _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, hostString);
        CFStringReplace(urlString, hostRange, codedHostName);
        CFRelease(codedHostName);
        CFRelease(hostString);
        return true;
    }

    CFStringRef rawHostString = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorDefault, hostString);
    if (rawHostString == NULL) {
        // If the hostString contains `%` that are not part of the percent encoding,
        // _CFStringCreateByRemovingPercentEncoding will return NULL.
        // In that case use hostString instead.
        rawHostString = CFStringCreateCopy(kCFAllocatorSystemDefault, hostString);
    }

    STACK_BUFFER_DECL(UChar, destinationBuffer, URL_MAX_BUFFER_LEN);
    UIDNAInfo processingDetails = UIDNA_INFO_INITIALIZER;
    UErrorCode error = U_ZERO_ERROR;

    const UChar *ucharBuffer = CFStringGetCharactersPtr(rawHostString);
    SAFE_STACK_BUFFER_DECL(UChar, ucharCharactersBuffer, CFStringGetLength(rawHostString), sizeof(UChar) * URL_MAX_BUFFER_LEN);
    if (ucharBuffer == NULL) {
        // Fallback to CFStringGetCharacters
        CFStringGetCharacters(rawHostString,
                              CFRangeMake(0, CFStringGetLength(rawHostString)),
                              (UniChar *)ucharCharactersBuffer);
        ucharBuffer = ucharCharactersBuffer;
    }

    UIDNA *transcoder = __CFURLComponentsDomainTranscoder();
    if (transcoder == NULL) {
        // Failed to create the transcoder, bail out
        SAFE_STACK_BUFFER_CLEANUP(ucharCharactersBuffer);
        CFRelease(rawHostString);
        CFRelease(hostString);
        return false;
    }

    int32_t numCharactersConverted = (shouldEncode ? uidna_nameToASCII : uidna_nameToUnicode)(
        transcoder,
        ucharBuffer,
        CFStringGetLength(rawHostString), destinationBuffer, URL_MAX_BUFFER_LEN, &processingDetails, &error);

    SAFE_STACK_BUFFER_CLEANUP(ucharCharactersBuffer);

    int allowedNameToUnicodeErrors = UIDNA_ERROR_EMPTY_LABEL
        | UIDNA_ERROR_LABEL_TOO_LONG
        | UIDNA_ERROR_DOMAIN_NAME_TOO_LONG
        | UIDNA_ERROR_LEADING_HYPHEN
        | UIDNA_ERROR_TRAILING_HYPHEN
        | UIDNA_ERROR_HYPHEN_3_4;
    int allowedErrors = shouldEncode ? 0 : allowedNameToUnicodeErrors;
    if (U_SUCCESS(error) && (processingDetails.errors & ~allowedErrors) == 0) {
        CFStringRef encodedHostName = CFStringCreateWithCharacters(kCFAllocatorDefault, destinationBuffer, numCharactersConverted);
        // Replace the host name with the encoded version
        CFStringReplace(urlString, hostRange, encodedHostName);
        CFRelease(encodedHostName);
        result = true;
    }
    CFRelease(hostString);
    CFRelease(rawHostString);
    return result;
}

// This method creates a scheme "exception list" so we can percent encode the
// host for these special URLs.
static inline Boolean __CFURLComponentsHostShouldPercentEncodeHostBasedOnScheme(CFStringRef scheme) {
    // These values are taken from TelephonyUtilities
    // They represent the list of schemes that TUDialRequest uses.
    const CFStringRef telephonySchemes[] = {
        CFSTR("tel"),
        CFSTR("telemergencycall"),
        CFSTR("telprompt"),
        CFSTR("callto"),
        CFSTR("facetime"),
        CFSTR("facetime-prompt"),
        CFSTR("facetime-audio"),
        CFSTR("facetime-audio-prompt"),
        CFSTR("imap"),
        CFSTR("pop"),
        CFSTR("addressbook"),
        CFSTR("contact"),
        CFSTR("phasset")
    };
    for (int index = 0; index < sizeof(telephonySchemes) / sizeof(*telephonySchemes); index++) {
        CFStringRef targetScheme = telephonySchemes[index];
        if (CFEqual(targetScheme, scheme)) {
            return true;
        }
    }

    return false;
}

static inline Boolean __CFURLComponentsIsHostIPv6Literal(CFStringRef hostString) {
    if (hostString == NULL || CFStringGetLength(hostString) < 2) {
        return false;
    }
    return CFStringGetCharacterAtIndex(hostString, 0) == '[' &&
        CFStringGetCharacterAtIndex(hostString, CFStringGetLength(hostString) - 1) == ']';
}

/// Creates a URL from string by automatically encode the host name and the rest of the components.
static void __CFURLComponentsEncodeURL(CFMutableStringRef urlString, struct _URIParseInfo *parseInfo) {
    // Validate and encode each component if necessary
    // Validate and encode the scheme
    if (parseInfo->schemeExists) {
        CFRange schemeRange = _CFURIParserGetSchemeRange(parseInfo, false);
        if (!_CFURIParserValidateComponent(urlString, schemeRange, kURLSchemeAllowed, false)) {
            // If the scheme is invalid there's nothing we could do since we can't percent encode it
            return;
        }
    }

    // Validate and encode the user name
    if (parseInfo->userinfoNameExists) {
        CFRange nameRange = _CFURIParserGetUserinfoNameRange(parseInfo, false);
        if (!_CFURIParserValidateComponent(urlString, nameRange, kURLUserAllowed, true)) {
            __CFURLComponentsPercentEncodeComponent(urlString, nameRange, _CFURLComponentsGetURLUserAllowedCharacterSet());
            // Reparse the string to get the most up-to-date offsets
            _CFURIParserParseURIReference(urlString, parseInfo);
        }
    }
    // Validate and encode the password
    if (parseInfo->userinfoPasswordExists) {
        CFRange passwordRange = _CFURIParserGetUserinfoPasswordRange(parseInfo, false);
        if (!_CFURIParserValidateComponent(urlString, passwordRange, kURLPasswordAllowed, true)) {
            __CFURLComponentsPercentEncodeComponent(urlString, passwordRange, _CFURLComponentsGetURLPasswordAllowedCharacterSet());
            // Reparse the string to get the most up-to-date offsets
            _CFURIParserParseURIReference(urlString, parseInfo);
        }
    }
    // Validate and encode the host. Host names are encoded via UIDNA
    if (parseInfo->hostExists) {
        CFRange hostRange = _CFURIParserGetHostRange(parseInfo, false);
        if (!_CFURIParserValidateComponent(urlString, hostRange, kURLHostAllowed, true)) {
            Boolean usePercentEncode = false;
            if (parseInfo->schemeExists) {
                CFRange schemeRange = _CFURIParserGetSchemeRange(parseInfo, false);
                CFStringRef scheme = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, urlString, schemeRange);
                usePercentEncode = __CFURLComponentsHostShouldPercentEncodeHostBasedOnScheme(scheme);
                CFRelease(scheme);
            }
            // Even though kURLHostAllowed does NOT contain `%`, RFC6874 (https://datatracker.ietf.org/doc/html/rfc6874)
            // specifies that IPv6 literals can contain a "Zone ID", separated by `%` (for example,
            // `[fe80::3221:5634:6544%en0]` where en0 is the Zone ID). This percent sign must also be percent-encoded,
            // turning the final out put to `[fe80::3221:5634:6544%25en0]`.
            // Use percentEncode here if the hostString is a IPv6 literal
            CFStringRef hostString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, urlString, hostRange);
            usePercentEncode = usePercentEncode || __CFURLComponentsIsHostIPv6Literal(hostString);
            CFRelease(hostString);

            if (__CFURLComponentsEncodeDecodeHost(urlString, hostRange, true, usePercentEncode)) {
                // Host succesfully encoded. Reparse the string to get the most up-to-date-offsets
                _CFURIParserParseURIReference(urlString, parseInfo);
            } else {
                // If we can't encode the host name, there's nothing we can do now...
                return;
            }
        }
    }
    // Validate the port. Nothing we can do if the port is invalid
    // since we can't encode it
    if (parseInfo->portExists) {
        CFRange portRange = _CFURIParserGetPortRange(parseInfo, false);
        if (!_CFURIParserValidateComponent(urlString, portRange, kURLPortAllowed, true)) {
            return;
        }
    }
    // Validate and encode the path
    CFRange pathRange = _CFURIParserGetPathRange(parseInfo, false);
    if (pathRange.location != kCFNotFound && pathRange.length > 0) {
        if (!_CFURIParserValidateComponent(urlString, pathRange, kURLPathAllowed, true)) {
            __CFURLComponentsPercentEncodeComponent(urlString, pathRange, _CFURLComponentsGetURLPathAllowedCharacterSet());
            // Reparse the string to get the most up-to-date offsets
            _CFURIParserParseURIReference(urlString, parseInfo);
        }
    }
    // Validate and encode the query
    if (parseInfo->queryExists) {
        CFRange queryRange = _CFURIParserGetQueryRange(parseInfo, false);
        if (!_CFURIParserValidateComponent(urlString, queryRange, kURLQueryAllowed, true)) {
            __CFURLComponentsPercentEncodeComponent(urlString, queryRange, _CFURLComponentsGetURLQueryAllowedCharacterSet());
            // Reparse the string to get the most up-to-date offsets
            _CFURIParserParseURIReference(urlString, parseInfo);
        }
    }
    // Validate and encode the fragment
    if (parseInfo->fragmentExists) {
        CFRange fragmentRange = _CFURIParserGetFragmentRange(parseInfo, false);
        if (!_CFURIParserValidateComponent(urlString, fragmentRange, kURLFragmentAllowed, true)) {
            __CFURLComponentsPercentEncodeComponent(urlString, fragmentRange, _CFURLComponentsGetURLFragmentAllowedCharacterSet());
            // Reparse the string to get the most up-to-date offsets
            _CFURIParserParseURIReference(urlString, parseInfo);
        }
    }
}

CF_EXPORT CFURLComponentsRef _CFURLComponentsCreate(CFAllocatorRef alloc) {
    CFIndex size = sizeof(struct __CFURLComponents) - sizeof(CFRuntimeBase);
    CFURLComponentsRef memory = (CFURLComponentsRef)_CFRuntimeCreateInstance(alloc, _CFURLComponentsGetTypeID(), size, NULL);
    if (NULL == memory) {
        return NULL;
    }
    
    memory->_lock = OS_UNFAIR_LOCK_INIT;
    
    memory->_schemeComponentValid = true;
    memory->_userComponentValid = true;
    memory->_passwordComponentValid = true;
    memory->_hostComponentValid = true;
    memory->_portComponentValid = true;
    memory->_pathComponentValid = true;
    memory->_queryComponentValid = true;
    memory->_fragmentComponentValid = true;

    return memory;
}

CF_EXPORT CFURLComponentsRef _CFURLComponentsCreateWithURL(CFAllocatorRef alloc, CFURLRef url, Boolean resolveAgainstBaseURL) {
    CFURLComponentsRef result = NULL;
    if (resolveAgainstBaseURL) {
        CFURLRef absoluteURL = CFURLCopyAbsoluteURL(url);
        if (absoluteURL) {
            result = _CFURLComponentsCreateWithString(alloc, CFURLGetString(absoluteURL));
            CFRelease(absoluteURL);
        }
    } else {
        result = _CFURLComponentsCreateWithString(alloc, CFURLGetString(url));
    }
    return result;
}

// This method is equivalent to `_CFURLComponentsCreateWithString` prior to
// rdar://89327583 (Introduce URL.FormatStyle and URL.ParseStrategy for Pattern Matching)
//
// We keep it here for backward-compatibility. All apps linked prior to Sydrome will
// fall back to this method instead of the new one.
static CFURLComponentsRef __CFURLComponentsCreateWithStringCompatibility(CFAllocatorRef alloc, CFStringRef string) {
    CFURLComponentsRef result = NULL;
    struct _URIParseInfo parseInfo;
    _CFURIParserParseURIReference(string, &parseInfo);
    if ( _CFURIParserURLStringIsValid(string, &parseInfo) ) {
        CFIndex size = sizeof(struct __CFURLComponents) - sizeof(CFRuntimeBase);
        result = (CFURLComponentsRef)_CFRuntimeCreateInstance(alloc, _CFURLComponentsGetTypeID(), size, NULL);
        if ( result) {
            // copy the _URIParseInfo into the result
            memcpy(&result->_parseInfo, &parseInfo, sizeof(parseInfo));

            result->_lock = OS_UNFAIR_LOCK_INIT;

            result->_urlString = CFStringCreateCopy(alloc, string);

            // if there's a semi-colon in the path (what used to delimit the deprecated param component)
            if (result->_parseInfo.semicolonInPathExists) {
                // this will percent-encode it
                CFStringRef path = _CFURLComponentsCopyPath(result);
                _CFURLComponentsSetPath(result, path);
                if ( path ) {
                    CFRelease(path);
                }
            }
        }
    }
    return ( result );
}

CF_EXPORT CFURLComponentsRef _CFURLComponentsCreateWithString(CFAllocatorRef alloc, CFStringRef string) {
    Boolean useCompatibilityMode = false;
    if (useCompatibilityMode) {
        return __CFURLComponentsCreateWithStringCompatibility(alloc, string);
    }
    CFURLComponentsRef result = NULL;
    struct _URIParseInfo parseInfo;
    CFMutableStringRef urlString = CFStringCreateMutableCopy(alloc, URL_MAX_BUFFER_LEN, string);
    _CFURIParserParseURIReference(urlString, &parseInfo);
    Boolean urlValid = _CFURIParserURLStringIsValid(urlString, &parseInfo);
    if (!urlValid) {
        // Attemps to encode the URL
        __CFURLComponentsEncodeURL(urlString, &parseInfo);
    }
    if ( _CFURIParserURLStringIsValid(urlString, &parseInfo) ) {
        CFIndex size = sizeof(struct __CFURLComponents) - sizeof(CFRuntimeBase);
        result = (CFURLComponentsRef)_CFRuntimeCreateInstance(alloc, _CFURLComponentsGetTypeID(), size, NULL);
        if ( result) {
            // copy the _URIParseInfo into the result
            memcpy(&result->_parseInfo, &parseInfo, sizeof(parseInfo));
            
            result->_lock = OS_UNFAIR_LOCK_INIT;
            
            result->_urlString = CFStringCreateCopy(alloc, urlString);
            
            // if there's a semi-colon in the path (what used to delimit the deprecated param component)
            if (result->_parseInfo.semicolonInPathExists) {
                // this will percent-encode it
                CFStringRef path = _CFURLComponentsCopyPath(result);
                _CFURLComponentsSetPath(result, path);
                if ( path ) {
                    CFRelease(path);
                }
            }
        }
    }
    CFRelease(urlString);
    return ( result );
}

CF_EXPORT CFURLComponentsRef _CFURLComponentsCreateCopy(CFAllocatorRef alloc, CFURLComponentsRef components) {
    CFIndex size = sizeof(struct __CFURLComponents) - sizeof(CFRuntimeBase);
    CFURLComponentsRef memory = (CFURLComponentsRef)_CFRuntimeCreateInstance(alloc, _CFURLComponentsGetTypeID(), size, NULL);
    if (NULL == memory) {
        return NULL;
    }
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    memory->_lock = OS_UNFAIR_LOCK_INIT;
    memory->_urlString = components->_urlString ? CFStringCreateCopy(alloc, components->_urlString) : NULL;
    
    memory->_parseInfo = components->_parseInfo;
    
    memory->_schemeComponentValid = components->_schemeComponentValid;
    memory->_userComponentValid = components->_userComponentValid;
    memory->_hostComponentValid = components->_hostComponentValid;
    memory->_portComponentValid = components->_portComponentValid;
    memory->_pathComponentValid = components->_pathComponentValid;
    memory->_queryComponentValid = components->_queryComponentValid;
    memory->_fragmentComponentValid = components->_fragmentComponentValid;

    if (components->_schemeComponent) {
        memory->_schemeComponent = CFStringCreateCopy(alloc, components->_schemeComponent);
    }
    if (components->_userComponent) {
        memory->_userComponent = CFStringCreateCopy(alloc, components->_userComponent);
    }
    if (components->_passwordComponent) {
        memory->_passwordComponent = CFStringCreateCopy(alloc, components->_passwordComponent);
    }
    if (components->_hostComponent) {
        memory->_hostComponent = CFStringCreateCopy(alloc, components->_hostComponent);
    }
    if (components->_portComponent) {
        long long port = 0;
        CFNumberGetValue(components->_portComponent, kCFNumberLongLongType, &port);
        memory->_portComponent = CFNumberCreate(alloc, kCFNumberLongLongType, &port);
    }
    if (components->_pathComponent) {
        memory->_pathComponent = CFStringCreateCopy(alloc, components->_pathComponent);
    }
    if (components->_queryComponent) {
        memory->_queryComponent = CFStringCreateCopy(alloc, components->_queryComponent);
    }
    if (components->_fragmentComponent) {
        memory->_fragmentComponent = CFStringCreateCopy(alloc, components->_fragmentComponent);
    }
    os_unfair_lock_unlock(&components->_lock);
    
    return memory;
}

#pragma mark -

static Boolean __CFURLComponentsEqual(CFTypeRef cf1, CFTypeRef cf2) {
    CFURLComponentsRef left = (CFURLComponentsRef)cf1;
    CFURLComponentsRef right = (CFURLComponentsRef)cf2;
    
    __CFGenericValidateType(left, _CFURLComponentsGetTypeID());
    __CFGenericValidateType(right, _CFURLComponentsGetTypeID());
    
    if (left == right) {
        return true;
    }
    
    Boolean (^componentEqual)(CFTypeRef l, CFTypeRef r) = ^(CFTypeRef l, CFTypeRef r) {
        // if pointers are equal (including both nil), they are equal; otherwise, use isEqual if both l and r are not NULL; otherwise return false
        if (l == r) {
            return (Boolean)true;
        } else if ( l && r ){
            return CFEqual(l, r);
        }
        else {
            return (Boolean)false;
        }
    };
    
    Boolean result = false;
    
    // check in the order of mostly likely to fail (or even exist) so that if they are different, we spend less time here.
    CFStringRef leftPath = _CFURLComponentsCopyPercentEncodedPath(left);
    CFStringRef rightPath = _CFURLComponentsCopyPercentEncodedPath(right);
    if ( componentEqual(leftPath, rightPath) ) {
        CFStringRef leftScheme = _CFURLComponentsCopyScheme(left);
        CFStringRef rightScheme = _CFURLComponentsCopyScheme(right);
        if ( componentEqual(leftScheme, rightScheme) ) {
            CFStringRef leftHost = _CFURLComponentsCopyPercentEncodedHost(left);
            CFStringRef rightHost = _CFURLComponentsCopyPercentEncodedHost(right);
            if ( componentEqual(leftHost, rightHost) ) {
                CFNumberRef leftPort = _CFURLComponentsCopyPort(left);
                CFNumberRef rightPort = _CFURLComponentsCopyPort(right);
                if ( componentEqual(leftPort, rightPort) ) {
                    CFStringRef leftQuery = _CFURLComponentsCopyPercentEncodedQuery(left);
                    CFStringRef rightQuery = _CFURLComponentsCopyPercentEncodedQuery(right);
                    if ( componentEqual(leftQuery, rightQuery) ) {
                        CFStringRef leftFragment = _CFURLComponentsCopyPercentEncodedFragment(left);
                        CFStringRef rightFragment = _CFURLComponentsCopyPercentEncodedFragment(right);
                        if ( componentEqual(leftFragment, rightFragment) ) {
                            CFStringRef leftUser = _CFURLComponentsCopyPercentEncodedUser(left);
                            CFStringRef rightUser = _CFURLComponentsCopyPercentEncodedUser(right);
                            if ( componentEqual(leftUser, rightUser) ) {
                                CFStringRef leftPassword = _CFURLComponentsCopyPercentEncodedPassword(left);
                                CFStringRef rightPassword = _CFURLComponentsCopyPercentEncodedPassword(right);
                                if ( componentEqual(leftPassword, rightPassword) ) {
                                    result = true;
                                }
                                if (leftPassword) CFRelease(leftPassword);
                                if (rightPassword) CFRelease(rightPassword);
                            }
                            if (leftUser) CFRelease(leftUser);
                            if (rightUser) CFRelease(rightUser);
                        }
                        if (leftFragment) CFRelease(leftFragment);
                        if (rightFragment) CFRelease(rightFragment);
                    }
                    if (leftQuery) CFRelease(leftQuery);
                    if (rightQuery) CFRelease(rightQuery);
                }
                if (leftPort) CFRelease(leftPort);
                if (rightPort) CFRelease(rightPort);
            }
            if (leftHost) CFRelease(leftHost);
            if (rightHost) CFRelease(rightHost);
        }
        if (leftScheme) CFRelease(leftScheme);
        if (rightScheme) CFRelease(rightScheme);
    }
    if (leftPath) CFRelease(leftPath);
    if (rightPath) CFRelease(rightPath);
    
    return result;
}

static CFHashCode __CFURLComponentsHash(CFTypeRef cf) {
    CFHashCode result = 0;
    // there is always a path (it might be an empty string) and that's enough to get a hash
    CFStringRef strComponent = _CFURLComponentsCopyPercentEncodedPath((CFURLComponentsRef)cf);
    result = CFHash(strComponent);
    CFRelease(strComponent);
    return ( result );
}

CF_EXPORT CFURLRef _CFURLComponentsCopyURL(CFURLComponentsRef components) {
    return _CFURLComponentsCopyURLRelativeToURL(components, NULL);
}

CF_EXPORT CFURLRef _CFURLComponentsCopyURLRelativeToURL(CFURLComponentsRef components, CFURLRef relativeToURL) {
    CFURLRef result = NULL;
    CFStringRef urlString = _CFURLComponentsCopyString(components);
    if (urlString) {
        result = CFURLCreateWithString(kCFAllocatorSystemDefault, urlString, relativeToURL);
        CFRelease(urlString);
    }
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyString(CFURLComponentsRef components) {
    CFStringRef result = NULL;
    
    // make sure all of the _XXXXComponent ivars are initialized
    if ( !components->_schemeComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyScheme(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_userComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedUser(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_passwordComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedPassword(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_hostComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedHost(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_portComponentValid ) {
        CFNumberRef temp = _CFURLComponentsCopyPort(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_pathComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedPath(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_queryComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedQuery(components);
        if (temp) CFRelease(temp);
    }
    if ( !components->_fragmentComponentValid ) {
        CFStringRef temp = _CFURLComponentsCopyPercentEncodedFragment(components);
        if (temp) CFRelease(temp);
    }

    CFStringRef hostString = NULL;
    if (components->_hostComponent) {
        // Retrieve the hostString
        CFRange hostRange = CFRangeMake(0, CFStringGetLength(components->_hostComponent));
        // Remove `[` and `]` for IPv6 literals
        if (hostRange.length > 2 &&
            CFStringGetCharacterAtIndex(components->_hostComponent, 0) == '[' &&
            CFStringGetCharacterAtIndex(components->_hostComponent, hostRange.length - 1) == ']') {
            hostRange = CFRangeMake(1, hostRange.length - 2);
        }
        Boolean hostValid = _CFURIParserValidateComponent(
            components->_hostComponent,
            hostRange,
            kURLHostAllowed, true);
        // Even though kURLHostAllowed contains `:`, it can only be part of
        // an IPv6 literal
        if (hostValid && hostRange.location == 0) {
            hostValid = CFStringFind(components->_hostComponent, CFSTR(":"), 0).location == kCFNotFound;
        }

        if (components->_schemeComponent != NULL &&
            __CFURLComponentsHostShouldPercentEncodeHostBasedOnScheme(components->_schemeComponent) && !hostValid) {
            hostString = _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, components->_hostComponent, _CFURLComponentsGetURLHostAllowedCharacterSet());
        } else if (hostValid) {
            hostString = CFStringCreateCopy(kCFAllocatorSystemDefault, components->_hostComponent);
        }
    }
    
    Boolean hasAuthority = (components->_userComponent || components->_passwordComponent || hostString || components->_portComponent);
    // If there's an authority component and a path component, then the path must either begin with "/" or be an empty string.
    if ( hasAuthority && components->_pathComponent && CFStringGetLength(components->_pathComponent) && (CFStringGetCharacterAtIndex(components->_pathComponent, 0) != '/') ) {
        result = NULL;
        if (hostString) {
            CFRelease(hostString);
        }
    }
    // If there's no authority component and a path component, the path component must not start with "//".
    else if ( !hasAuthority && components->_pathComponent && CFStringGetLength(components->_pathComponent) >= 2 && (CFStringGetCharacterAtIndex(components->_pathComponent, 0) == '/') && (CFStringGetCharacterAtIndex(components->_pathComponent, 1) == '/') ) {
        result = NULL;
        if (hostString) {
            CFRelease(hostString);
        }
    }
    else {
        os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
        
        CFStringAppendBuffer buf;
        UniChar chars[2];
        
        // create the URL string
        CFStringInitAppendBuffer(kCFAllocatorDefault, &buf);
        
        if ( components->_schemeComponent ) {
            // append "<scheme>:"
            CFStringAppendStringToAppendBuffer(&buf, components->_schemeComponent);
            chars[0] = ':';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
        }
        if ( components->_userComponent || components->_passwordComponent || hostString || components->_portComponent ) {
            // append "//"
            chars[0] = chars[1] = '/';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 2);
        }
        if ( components->_userComponent ) {
            // append "<user>"
            CFStringAppendStringToAppendBuffer(&buf, components->_userComponent);
        }
        if ( components->_passwordComponent ) {
            // append ":<password>"
            chars[0] = ':';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
            CFStringAppendStringToAppendBuffer(&buf, components->_passwordComponent);
        }
        if ( components->_userComponent || components->_passwordComponent ) {
            // append "@"
            chars[0] = '@';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
        }
        if ( hostString ) {
            CFStringAppendStringToAppendBuffer(&buf, hostString);
            CFRelease(hostString);
        }
        if ( components->_portComponent ) {
            // append ":<port>"
            chars[0] = ':';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
#define LONG_LONG_MAX_DIGITS 19
            long long num;
            if (!CFNumberGetValue(components->_portComponent, kCFNumberLongLongType, &num)) {
                num = 0;
            }
            char numStr[LONG_LONG_MAX_DIGITS + 1] = {0};
            snprintf(numStr, LONG_LONG_MAX_DIGITS, "%lld", num);
            CFStringRef portStr = CFStringCreateWithBytes(kCFAllocatorSystemDefault, (const UInt8 *)numStr, strlen(numStr), kCFStringEncodingASCII, false);
            CFStringAppendStringToAppendBuffer(&buf, (CFStringRef)portStr);
            CFRelease(portStr);
#undef LONG_LONG_MAX_DIGITS
        }
        if ( components->_pathComponent ) {
            // append "<path>"
            CFStringAppendStringToAppendBuffer(&buf, components->_pathComponent);
        }
        if ( components->_queryComponent ) {
            // append "?<query>"
            chars[0] = '?';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
            CFStringAppendStringToAppendBuffer(&buf, components->_queryComponent);
        }
        if ( components->_fragmentComponent ) {
            // append "#<fragment>"
            chars[0] = '#';
            CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
            CFStringAppendStringToAppendBuffer(&buf, components->_fragmentComponent);
        }
        result = CFStringCreateMutableWithAppendBuffer(&buf);
        os_unfair_lock_unlock(&components->_lock);
    }
    
    return ( result );
}

static inline CFStringRef CreateComponentWithURLStringRange(CFStringRef urlString, CFRange range)
{
    // the component has never been set so no nee to release it
    if ( range.location != kCFNotFound ) {
        CFRange theRange;
        theRange.location = range.location;
        theRange.length = range.length;
        return CFStringCreateWithSubstring(kCFAllocatorSystemDefault, urlString, theRange);
    }
    else {
        return NULL;
    }
}

CF_EXPORT CFStringRef _CFURLComponentsCopyScheme(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_schemeComponentValid ) {
        components->_schemeComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetSchemeRange(&components->_parseInfo, false));
        components->_schemeComponentValid = true;
    }
    result = components->_schemeComponent ? CFRetain(components->_schemeComponent) : NULL;
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyUser(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_userComponentValid ) {
        components->_userComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoNameRange(&components->_parseInfo, false));
        components->_userComponentValid = true;
    }
    if ( components->_userComponent ) {
        result = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_userComponent);
    }
    else {
        // ensure the password subcomponent is valid
        if ( !components->_passwordComponentValid ) {
            components->_passwordComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoPasswordRange(&components->_parseInfo, false));
            components->_passwordComponentValid = true;
        }
        if ( components->_passwordComponent ) {
            // if there's a password subcomponent, then there has to be a user subcomponent
            result = CFRetain(CFSTR(""));
        }
        else {
            result = NULL;
        }
    }
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPassword(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_passwordComponentValid ) {
        components->_passwordComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoPasswordRange(&components->_parseInfo, false));
        components->_passwordComponentValid = true;
    }
    result = components->_passwordComponent ? _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_passwordComponent) : NULL;
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

static void _SetValidPortComponent(CFURLComponentsRef components) {
    enum {
        kDefaultBuffersize = 20, // The maximum port number we can represent is 9223372036854775807 (LLONG_MAX) which is 19 digits, so the stack allocated buffer will work for all valid port numbers with no leading zeros
    };
    if ( !components->_portComponentValid ) {
        // if there's not a valid port, _portComponent should be nil
        components->_portComponent = NULL;
        
        CFRange range = _CFURIParserGetPortRange(&components->_parseInfo, false);
        // rfc3986 says URI producers should omit the port component and its ":" delimiter if port is empty.
        if ( (range.location != kCFNotFound) && (range.length != 0) ) {
            // _CFURIParserURLStringIsValid has already ensured the characters in the port range are valid DIGIT characters.
            
            // determine the buffer size needed, and use either the stack allocated buffer or a malloced buffer
            CFIndex neededBufSize = CFStringGetMaximumSizeForEncoding(range.length, kCFStringEncodingASCII) + 1;
            STACK_BUFFER_DECL(char, stackBuffer, kDefaultBuffersize);
            char *buf = NULL;
            CFIndex bufSize;
            if ( neededBufSize <= kDefaultBuffersize ) {
                // use stackBuffer
                buf = &stackBuffer[0];
                bufSize = kDefaultBuffersize;
            }
            else {
                // buf not big enough? malloc it.
                buf = (char *)malloc(neededBufSize);
                bufSize = neededBufSize;
            }
            
            if ( buf ) {
                // get the bytes into buf
                CFIndex usedBufLen;
                if ( CFStringGetBytes(components->_urlString, range, kCFStringEncodingASCII, 0, false, (UInt8 *)buf, bufSize, &usedBufLen) != 0 ) {
                    buf[usedBufLen] = '\0'; // null terminate the string
                    // convert to a long long
                    errno = 0;
                    long long value = strtoll(buf, NULL, 10);
                    // make sure there wasn't underflow or overflow (ERANGE), and value is not negative
                    if ( (errno != ERANGE) && (value >= 0) ) {
                        // create the port number
                        components->_portComponent = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberLongLongType, &value);
                    }
                }
                
                // free the buf if malloced
                if ( buf != stackBuffer ) {
                    free(buf);
                }
            }
        }
        components->_portComponentValid = true;
    }
}

CF_EXPORT CFStringRef _CFURLComponentsCopyHost(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_hostComponentValid ) {
        components->_hostComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetHostRange(&components->_parseInfo, false));
        components->_hostComponentValid = true;
    }
    if ( components->_hostComponent ) {
        CFMutableStringRef decoded = CFStringCreateMutableCopy(kCFAllocatorSystemDefault, URL_MAX_BUFFER_LEN, components->_hostComponent);
        os_unfair_lock_unlock(&components->_lock);
        CFStringRef scheme = _CFURLComponentsCopyScheme(components);
        os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
        Boolean usePercentEncode = scheme != NULL &&
            __CFURLComponentsHostShouldPercentEncodeHostBasedOnScheme(scheme);
        if (scheme) {
            CFRelease(scheme);
        }
        if (!__CFURLComponentsEncodeDecodeHost(decoded, CFRangeMake(0, CFStringGetLength(decoded)), false, usePercentEncode)) {
            // Failed to decode
            result = NULL;
            CFRelease(decoded);
        } else {
            // According to RFC 4343 (https://www.ietf.org/rfc/rfc4343.txt), URL host
            // names are case-insensitive. However, many apps uses non-standard URLs
            // such as `amexapp://makePayment` that relies on the host portion
            // being case sensitive for comparison.
            //
            // ICU's IDN encoder (UIDNA) always returns lower case strings
            // even if the original host name contains uppercase letters (it's
            // supposed to be case-insensitive after all). Here we perform
            // a case-insensitive comparison between the decoded string and
            // the original string and use the original string if the host
            // name didn't need to be decoded at all.
            CFComparisonResult decodedMatchesOriginal = CFStringCompare(
                decoded, components->_hostComponent,
                kCFCompareCaseInsensitive);
            if (decodedMatchesOriginal == kCFCompareEqualTo) {
                result = CFStringCreateCopy(kCFAllocatorSystemDefault, components->_hostComponent);
                CFRelease(decoded);
            } else {
                result = decoded;
            }
        }
    }
    else {
        // force initialization of the other authority subcomponents in the order I think they are likely to be present: port, user, password
        
        // ensure the port subcomponent is valid
        _SetValidPortComponent(components);
        
        if ( components->_portComponent ) {
            // if there's a port subcomponent, then there has to be a host subcomponent
            result = CFRetain(CFSTR(""));
        }
        else {
            // ensure the user subcomponent is valid
            if ( !components->_userComponentValid ) {
                components->_userComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoNameRange(&components->_parseInfo, false));
                components->_userComponentValid = true;
            }
            if ( components->_userComponent ) {
                // if there's a user subcomponent, then there has to be a host subcomponent
                result = CFRetain(CFSTR(""));
            }
            else {
                // ensure the password subcomponent is valid
                if ( !components->_passwordComponentValid ) {
                    components->_passwordComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoPasswordRange(&components->_parseInfo, false));
                    components->_passwordComponentValid = true;
                }
                if ( components->_passwordComponent ) {
                    // if there's a password subcomponent, then there has to be a host subcomponent
                    result = CFRetain(CFSTR(""));
                }
                else {
                    result = NULL;
                }
            }
        }
    }
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFNumberRef _CFURLComponentsCopyPort(CFURLComponentsRef components) {
    CFNumberRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    _SetValidPortComponent(components);
    result = components->_portComponent ? CFRetain(components->_portComponent) : NULL;
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPath(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_pathComponentValid ) {
        components->_pathComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetPathRange(&components->_parseInfo, false));
        components->_pathComponentValid = true;
    }
    if (!components->_pathComponent) {
        result = CFRetain(CFSTR(""));
    } else {
        result = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_pathComponent);
        if (!result) {
            result = CFRetain(CFSTR(""));
        }
    }
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyQuery(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_queryComponentValid ) {
        components->_queryComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetQueryRange(&components->_parseInfo, false));
        components->_queryComponentValid = true;
    }
    result = components->_queryComponent ? _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_queryComponent) : NULL;
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyFragment(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_fragmentComponentValid ) {
        components->_fragmentComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetFragmentRange(&components->_parseInfo, false));
        components->_fragmentComponentValid = true;
    }
    result = components->_fragmentComponent ? _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, components->_fragmentComponent) : NULL;
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT Boolean _CFURLComponentsSchemeIsValid(CFStringRef scheme) {
    Boolean valid = false;
    if ( scheme ) {
        CFIndex length = CFStringGetLength(scheme);
        if ( length != 0 ) {
            UniChar ch = CFStringGetCharacterAtIndex(scheme, 0);
            valid = (ch <= 127) && _CFURIParserAlphaAllowed(ch) && _CFURIParserValidateComponent(scheme, CFRangeMake(1, length - 1), kURLSchemeAllowed, false);
        }
    }
    else {
        // NULL is valid because it can be passed to _CFURLComponentsSetScheme to clear the scheme component
        valid = true;
    }
    return ( valid );
}

CF_EXPORT Boolean _CFURLComponentsSetScheme(CFURLComponentsRef components, CFStringRef scheme) {
    Boolean result;
    if ( _CFURLComponentsSchemeIsValid(scheme) ) {
        os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
        if (components->_schemeComponent) {
            CFRelease(components->_schemeComponent);
        }
        components->_schemeComponent = scheme ? CFStringCreateCopy(kCFAllocatorSystemDefault, scheme) : NULL;
        components->_schemeComponentValid = true;
        os_unfair_lock_unlock(&components->_lock);
        result = true;
    }
    else {
        result = false;
    }
    return ( result );
}

CF_EXPORT Boolean _CFURLComponentsSetUser(CFURLComponentsRef components, CFStringRef user) {
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_userComponent) CFRelease(components->_userComponent);
    components->_userComponent = user ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, user, _CFURLComponentsGetURLUserAllowedCharacterSet()) : NULL;
    components->_userComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPassword(CFURLComponentsRef components, CFStringRef password) {
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_passwordComponent) CFRelease(components->_passwordComponent);
    components->_passwordComponent = password ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, password, _CFURLComponentsGetURLPasswordAllowedCharacterSet()) : NULL;
    components->_passwordComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetHost(CFURLComponentsRef components, CFStringRef host) {
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_hostComponent) {
        CFRelease(components->_hostComponent);
        components->_hostComponent = NULL;
    }

    if (host != NULL) {
        CFRange hostRange = CFRangeMake(0, CFStringGetLength(host));
        // Encode the host if necessary
        if (!_CFURIParserValidateComponent(host, hostRange, kURLHostAllowed, true)) {
            CFMutableStringRef hostString = CFStringCreateMutableCopy(kCFAllocatorSystemDefault, URL_MAX_BUFFER_LEN, host);
            // Since we might not know the scheme when host is set, always
            // use Punycode encoding unless the host is an IPv6 literal. RFC6874
            // (https://datatracker.ietf.org/doc/html/rfc6874) specifies that IPv6 literals can
            // contain a "Zone ID", separated by `%` (for example,`[fe80::3221:5634:6544%en0]`
            // where en0 is the Zone ID). This percent sign must also be percent-encoded,
            // turning the final out put to `[fe80::3221:5634:6544%25en0]`.
            Boolean usePercentEncode = __CFURLComponentsIsHostIPv6Literal(hostString);
            if (__CFURLComponentsEncodeDecodeHost(hostString, hostRange, true, usePercentEncode)) {
                components->_hostComponent = hostString;
            } else {
                // Failed to encode the host, bailout.
                os_unfair_lock_unlock(&components->_lock);
                CFRelease(hostString);
                return false;
            }
        } else {
            components->_hostComponent = CFStringCreateCopy(kCFAllocatorSystemDefault, host);
        }
    } else {
        components->_hostComponent = NULL;
    }

    components->_hostComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPort(CFURLComponentsRef components, CFNumberRef port) {
    long long portNumber = 0;
    if ( port ) {
        // make sure the port number is a non-negative integer
        if ( !CFNumberGetValue(port, kCFNumberLongLongType, &portNumber) || portNumber < 0 ) {
            // negative port number
            return false;
        }
    }
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_portComponent) CFRelease(components->_portComponent);
    if (port) {
        components->_portComponent = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberLongLongType, &portNumber);
    } else {
        components->_portComponent = NULL;
    }
    components->_portComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPath(CFURLComponentsRef components, CFStringRef path) {
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_pathComponent) CFRelease(components->_pathComponent);
    components->_pathComponent = path ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, path, _CFURLComponentsGetURLPathAllowedCharacterSet()) : NULL;
    components->_pathComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetQuery(CFURLComponentsRef components, CFStringRef query) {
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_queryComponent) CFRelease(components->_queryComponent);
    components->_queryComponent = query ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, query, _CFURLComponentsGetURLQueryAllowedCharacterSet()) : NULL;
    components->_queryComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetFragment(CFURLComponentsRef components, CFStringRef fragment) {
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_fragmentComponent) CFRelease(components->_fragmentComponent);
    components->_fragmentComponent = fragment ? _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, fragment, _CFURLComponentsGetURLFragmentAllowedCharacterSet()) : NULL;
    components->_fragmentComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedUser(CFURLComponentsRef components) {
    CFStringRef result;

    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_userComponentValid ) {
        components->_userComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoNameRange(&components->_parseInfo, false));
        components->_userComponentValid = true;
    }
    if ( components->_userComponent ) {
        result = CFRetain(components->_userComponent);
    }
    else {
        // ensure the password subcomponent is valid
        if ( !components->_passwordComponentValid ) {
            components->_passwordComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoPasswordRange(&components->_parseInfo, false));
            components->_passwordComponentValid = true;
        }
        if ( components->_passwordComponent ) {
            // if there's a password subcomponent, then there has to be a user subcomponent
            result = CFRetain(CFSTR(""));
        }
        else {
            result = NULL;
        }
    }
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedPassword(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_passwordComponentValid ) {
        components->_passwordComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoPasswordRange(&components->_parseInfo, false));
        components->_passwordComponentValid = true;
    }
    result = components->_passwordComponent ? CFRetain(components->_passwordComponent) : NULL;
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT _Nullable CFStringRef _CFURLComponentsCopyEncodedHost(CFURLComponentsRef components) {
    CFStringRef result;

    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_hostComponentValid ) {
        components->_hostComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetHostRange(&components->_parseInfo, false));
        components->_hostComponentValid = true;
    }
    if ( components->_hostComponent ) {
        // At this point _hostComponent should have already been either percent or Punycode encoded.
        // However, it's still possible that _hostComponent is invalid because Punycode encoder does
        // not encode "invalid" IDN characters, such as spaces that might appear in a phone number.
        // In these cases, we'll need to percent-encode.
        CFIndex hostLength = CFStringGetLength(components->_hostComponent);
        CFRange hostRange = __CFURLComponentsIsHostIPv6Literal(components->_hostComponent) ?
            CFRangeMake(1, hostLength - 2) : CFRangeMake(0, hostLength);
        if (hostLength >= 2 && !_CFURIParserValidateComponent(components->_hostComponent, hostRange, kURLHostAllowed, true)) {
            result = _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, components->_hostComponent, _CFURLComponentsGetURLHostAllowedCharacterSet());
        } else {
            result = CFRetain(components->_hostComponent);
        }
    }
    else {
        // force initialization of the other authority subcomponents in the order I think they are likely to be present: port, user, password

        // ensure the port subcomponent is valid
        _SetValidPortComponent(components);

        if ( components->_portComponent ) {
            // if there's a port subcomponent, then there has to be a host subcomponent
            result = CFRetain(CFSTR(""));
        }
        else {
            // ensure the user subcomponent is valid
            if ( !components->_userComponentValid ) {
                components->_userComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoNameRange(&components->_parseInfo, false));
                components->_userComponentValid = true;
            }
            if ( components->_userComponent ) {
                // if there's a user subcomponent, then there has to be a host subcomponent
                result = CFRetain(CFSTR(""));
            }
            else {
                // ensure the password subcomponent is valid
                if ( !components->_passwordComponentValid ) {
                    components->_passwordComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetUserinfoPasswordRange(&components->_parseInfo, false));
                    components->_passwordComponentValid = true;
                }
                if ( components->_passwordComponent ) {
                    // if there's a password subcomponent, then there has to be a host subcomponent
                    result = CFRetain(CFSTR(""));
                }
                else {
                    result = NULL;
                }
            }
        }
    }
    os_unfair_lock_unlock(&components->_lock);

    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedHost(CFURLComponentsRef components) {
    CFStringRef host = _CFURLComponentsCopyHost(components);
    CFStringRef encodedHost = NULL;
    if (host) {
        encodedHost = _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, host, _CFURLComponentsGetURLHostAllowedCharacterSet());
        CFRelease(host);
    }
    return encodedHost;
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedPath(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_pathComponentValid ) {
        components->_pathComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetPathRange(&components->_parseInfo, false));
        components->_pathComponentValid = true;
    }
    result = components->_pathComponent ? CFRetain(components->_pathComponent) : NULL;
    os_unfair_lock_unlock(&components->_lock);
    
    if (!result) result = CFRetain(CFSTR(""));
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedQuery(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_queryComponentValid ) {
        components->_queryComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetQueryRange(&components->_parseInfo, false));
        components->_queryComponentValid = true;
    }
    result = components->_queryComponent ? CFRetain(components->_queryComponent) : NULL;
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT CFStringRef _CFURLComponentsCopyPercentEncodedFragment(CFURLComponentsRef components) {
    CFStringRef result;
    
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if ( !components->_fragmentComponentValid ) {
        components->_fragmentComponent = CreateComponentWithURLStringRange(components->_urlString, _CFURIParserGetFragmentRange(&components->_parseInfo, false));
        components->_fragmentComponentValid = true;
    }
    result = components->_fragmentComponent ? CFRetain(components->_fragmentComponent) : NULL;
    os_unfair_lock_unlock(&components->_lock);
    
    return ( result );
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedUser(CFURLComponentsRef components, CFStringRef percentEncodedUser) {
    if ( percentEncodedUser ) {
        if ( !_CFURIParserValidateComponent(percentEncodedUser, CFRangeMake(0, CFStringGetLength(percentEncodedUser)), kURLUserAllowed, true) ) {
            //  invalid characters in percentEncodedUser
            return false;
        }
    }
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_userComponent) CFRelease(components->_userComponent);
    components->_userComponent = percentEncodedUser ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedUser) : NULL;
    components->_userComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedPassword(CFURLComponentsRef components, CFStringRef percentEncodedPassword) {
    if ( percentEncodedPassword ) {
        if ( !_CFURIParserValidateComponent(percentEncodedPassword, CFRangeMake(0, CFStringGetLength(percentEncodedPassword)), kURLPasswordAllowed, true) ) {
            // invalid characters in percentEncodedPassword
            return false;
        }
    }
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_passwordComponent) CFRelease(components->_passwordComponent);
    components->_passwordComponent = percentEncodedPassword ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedPassword) : NULL;
    components->_passwordComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetEncodedHost(CFURLComponentsRef components, _Nullable CFStringRef host) {
    CFStringRef uidnaEncodedHost = NULL;
    if ( host ) {
        // If the decoded string doesn't contain any invalid characters, we don't have
        // to encode at all!
        CFIndex decodedLength = CFStringGetLength(host);
        CFRange hostRange;
        if (decodedLength >= 2 &&
            (CFStringGetCharacterAtIndex(host, 0) == '[') &&
            (CFStringGetCharacterAtIndex(host, decodedLength - 1) == ']')) {
            // the host is an IP-Literal -- only validate the characters inside brackets
            hostRange = CFRangeMake(1, decodedLength - 2);
        } else {
            hostRange = CFRangeMake(0, decodedLength);
        }
        if (_CFURIParserValidateComponent(host, hostRange, kURLHostAllowed, true)) {
            uidnaEncodedHost = CFStringCreateCopy(kCFAllocatorSystemDefault, host);
        } else {
            // The host is indeed invalid. Encode it now.
            CFMutableStringRef hostString = CFStringCreateMutableCopy(kCFAllocatorSystemDefault, URL_MAX_BUFFER_LEN, host);
            // Since we might not know the scheme when host is set, always use Punycode encoding
            // unless the host is an IPv6 literal. IPv6 literals should be percent-encoded because
            // they may contain a Zone ID separated by a special character `%`.
            Boolean usePercentEncode = __CFURLComponentsIsHostIPv6Literal(hostString);
            if (__CFURLComponentsEncodeDecodeHost(hostString, hostRange, true, usePercentEncode)) {
                uidnaEncodedHost = hostString;
            } else {
                // Failed to encode host, bailout
                if (hostString) {
                    CFRelease(hostString);
                }
                return false;
            }
        }
    }
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_hostComponent) CFRelease(components->_hostComponent);
    components->_hostComponent = uidnaEncodedHost ? CFStringCreateCopy(kCFAllocatorSystemDefault, uidnaEncodedHost) : NULL;
    components->_hostComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);

    if (uidnaEncodedHost) {
        CFRelease(uidnaEncodedHost);
    }
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedHost(CFURLComponentsRef components, CFStringRef percentEncodedHost) {
    // Hosts must be encoded via unicode (UIDNA) as opposed to percent encoding,
    // unless the host is an IPv6 literal. IPv6 literals need to be percent-encoded
    // because they may contain a Zone ID separated by a special character `%`.
    CFStringRef decoded = NULL;
    if (percentEncodedHost) {
        if (__CFURLComponentsIsHostIPv6Literal(percentEncodedHost)) {
            decoded = CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedHost);
        } else {
            decoded = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, percentEncodedHost);
        }
    }
    Boolean result = _CFURLComponentsSetEncodedHost(components, decoded);
    if (decoded) {
        CFRelease(decoded);
    }
    return result;
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedPath(CFURLComponentsRef components, CFStringRef percentEncodedPath) {
    if ( percentEncodedPath ) {
        if ( !_CFURIParserValidateComponent(percentEncodedPath, CFRangeMake(0, CFStringGetLength(percentEncodedPath)), kURLPathAllowed, true) ) {
            // invalid characters in percentEncodedPath
            return false;
        }
    }
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_pathComponent) CFRelease(components->_pathComponent);
    components->_pathComponent = percentEncodedPath ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedPath) : NULL;
    components->_pathComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedQuery(CFURLComponentsRef components, CFStringRef percentEncodedQuery) {
    if ( percentEncodedQuery ) {
        if ( !_CFURIParserValidateComponent(percentEncodedQuery, CFRangeMake(0, CFStringGetLength(percentEncodedQuery)), kURLQueryAllowed, true) ) {
            // invalid characters in percentEncodedQuery
            return false;
        }
    }
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_queryComponent) CFRelease(components->_queryComponent);
    components->_queryComponent = percentEncodedQuery ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedQuery) : NULL;
    components->_queryComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedFragment(CFURLComponentsRef components, CFStringRef percentEncodedFragment) {
    if ( percentEncodedFragment ) {
        if ( !_CFURIParserValidateComponent(percentEncodedFragment, CFRangeMake(0, CFStringGetLength(percentEncodedFragment)), kURLFragmentAllowed, true) ) {
            // invalid characters in percentEncodedFragment
            return false;
        }
    }
    os_unfair_lock_lock_with_options(&components->_lock, OS_UNFAIR_LOCK_DATA_SYNCHRONIZATION);
    if (components->_fragmentComponent) CFRelease(components->_fragmentComponent);
    components->_fragmentComponent = percentEncodedFragment ? CFStringCreateCopy(kCFAllocatorSystemDefault, percentEncodedFragment) : NULL;
    components->_fragmentComponentValid = true;
    os_unfair_lock_unlock(&components->_lock);
    return true;
}

static Boolean _CFURLComponentsParseInfoIsValid(CFURLComponentsRef components) {
    // if all _xxxxComponentValid flags are false, then _urlString is the string and _parseInfo is valid
    return ( !components->_schemeComponentValid && !components->_userComponentValid && !components->_passwordComponentValid && !components->_hostComponentValid && !components->_portComponentValid && !components->_pathComponentValid && !components->_queryComponentValid && !components->_fragmentComponentValid);
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfScheme(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetSchemeRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfUser(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetUserinfoNameRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfPassword(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetUserinfoPasswordRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfHost(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetHostRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfPort(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetPortRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfPath(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetPathRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfQuery(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetQueryRange(theParseInfo, false) );
}

CF_EXPORT CFRange _CFURLComponentsGetRangeOfFragment(CFURLComponentsRef components) {
    struct _URIParseInfo stringParseInfo;
    struct _URIParseInfo *theParseInfo;
    if ( _CFURLComponentsParseInfoIsValid(components) ) {
        // use the range info in _URIParseInfo is valid
        theParseInfo = &components->_parseInfo;
    }
    else {
        // we need to get the current string, parse it, and use its range info
        theParseInfo = &stringParseInfo;
        CFStringRef str = _CFURLComponentsCopyString(components);
        _CFURIParserParseURIReference(str, theParseInfo);
        CFRelease(str);
    }
    return ( _CFURIParserGetFragmentRange(theParseInfo, false) );
}

// keys for dictionaries returned by _CFURLComponentsCopyQueryItems
CONST_STRING_DECL(_kCFURLComponentsNameKey, "name")
CONST_STRING_DECL(_kCFURLComponentsValueKey, "value")

// Returns an array of dictionaries; each dictionary has two keys: _kCFURLComponentsNameKey for the name, and _kCFURLComponentsValueKey for the value. If one of the keys is missing then we did not populate that part of the entry.
static CFArrayRef _CFURLComponentsCopyQueryItemsInternal(CFURLComponentsRef components, Boolean removePercentEncoding) {
    CFStringRef queryString = _CFURLComponentsCopyPercentEncodedQuery(components);
    CFArrayRef result = NULL;
    
    if ( queryString ) {
        CFIndex len = CFStringGetLength(queryString);
        if ( len ) {
            CFMutableArrayRef intermediateResult = CFArrayCreateMutable(kCFAllocatorSystemDefault, 0, &kCFTypeArrayCallBacks);
            
            CFStringInlineBuffer buf;
            CFStringInitInlineBuffer((CFStringRef)queryString, &buf, CFRangeMake(0, len));
            CFStringRef nameString;
            CFStringRef valueString;
            CFRange nameRange;
            CFRange valueRange;
            nameRange.location = 0;
            valueRange.location = kCFNotFound;
            CFIndex idx = 0;
            Boolean sawPercent = false;
            for ( idx = 0; idx < len; ++idx ) {
                UniChar ch = CFStringGetCharacterFromInlineBuffer(&buf, idx);
                if ( ch == '=' ) {
                    if ( nameRange.location != kCFNotFound ) {
                        // found the end of the name string
                        nameRange.length = idx - nameRange.location;
                        if ( nameRange.length ) {
                            nameString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, queryString, nameRange);
                            if ( removePercentEncoding && sawPercent ) {
                                CFStringRef temp = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, nameString);
                                CFRelease(nameString);
                                if ( temp ) {
                                    nameString = temp;
                                }
                                else {
                                    // the percent-decoded string had invalid UTF8 bytes - return an empty name string
                                    nameString = CFRetain(CFSTR(""));
                                }
                                sawPercent = false;
                            }
                        }
                        else {
                            nameString = CFRetain(CFSTR(""));
                        }
                        nameRange.location = kCFNotFound;
                        valueRange.location = idx + 1;
                    }
                    // else found an '=' that is part of the value string
                }
                else if ( ch == '&' ) {
                    // found end of name-value pair
                    if ( valueRange.location != kCFNotFound ) {
                        // found the end of the value string
                        valueRange.length = idx - valueRange.location;
                        if ( valueRange.length ) {
                            valueString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, queryString, valueRange);
                            if ( removePercentEncoding && sawPercent ) {
                                CFStringRef temp = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, valueString);
                                CFRelease(valueString);
                                valueString = temp;
                                sawPercent = false;
                            }
                        }
                        else {
                            valueString = CFRetain(CFSTR(""));
                        }
                        CFTypeRef keys[] = {_kCFURLComponentsNameKey, _kCFURLComponentsValueKey};
                        CFTypeRef values[] = {nameString, valueString};
                        // valueString will be NULL if the percent-decoded string had invalid UTF8 bytes
                        CFDictionaryRef entry = CFDictionaryCreate(kCFAllocatorSystemDefault, keys, values, valueString ? 2 : 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                        CFArrayAppendValue(intermediateResult, entry);
                        CFRelease(entry);
                        valueRange.location = kCFNotFound;
                        CFRelease(nameString);
                        if ( valueString ) {
                            CFRelease(valueString);
                        }
                    }
                    else {
                        // there was no value string, so this was the end of the name string
                        nameRange.length = idx - nameRange.location;
                        if ( nameRange.length ) {
                            nameString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, queryString, nameRange);
                            if ( removePercentEncoding && sawPercent ) {
                                CFStringRef temp = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, nameString);
                                CFRelease(nameString);
                                if ( temp ) {
                                    nameString = temp;
                                }
                                else {
                                    // the percent-decoded string had invalid UTF8 bytes - return an empty name string
                                    nameString = CFRetain(CFSTR(""));
                                }
                                sawPercent = false;
                            }
                        }
                        else {
                            nameString = CFRetain(CFSTR(""));
                        }
                        CFTypeRef keys[] = {_kCFURLComponentsNameKey};
                        CFTypeRef values[] = {nameString};
                        CFDictionaryRef entry = CFDictionaryCreate(kCFAllocatorSystemDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                        CFArrayAppendValue(intermediateResult, entry);
                        CFRelease(entry);
                        CFRelease(nameString);
                    }
                    nameRange.location = idx + 1;
                }
                else if ( removePercentEncoding && (ch == '%') ) {
                    sawPercent = true;
                }
            }
            
            if ( valueRange.location != kCFNotFound ) {
                // at end of query while parsing the value string
                valueRange.length = idx - valueRange.location;
                if ( valueRange.length ) {
                    valueString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, queryString, valueRange);
                    if ( removePercentEncoding && sawPercent ) {
                        CFStringRef temp = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, valueString);
                        CFRelease(valueString);
                        valueString = temp;
                        sawPercent = false;
                    }
                }
                else {
                    valueString = CFRetain(CFSTR(""));
                }
                CFTypeRef keys[] = {_kCFURLComponentsNameKey, _kCFURLComponentsValueKey};
                CFTypeRef values[] = {nameString, valueString};
                // valueString will be NULL if the percent-decoded string had invalid UTF8 bytes
                CFDictionaryRef entry = CFDictionaryCreate(kCFAllocatorSystemDefault, keys, values, valueString ? 2 : 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                CFArrayAppendValue(intermediateResult, entry);
                CFRelease(entry);
                CFRelease(nameString);
                if ( valueString ) {
                    CFRelease(valueString);
                }
            }
            else {
                // at end of query while parsing the name string
                nameRange.length = idx - nameRange.location;
                if ( nameRange.length ) {
                    nameString = CFStringCreateWithSubstring(kCFAllocatorSystemDefault, queryString, nameRange);
                    if ( removePercentEncoding && sawPercent ) {
                        CFStringRef temp = _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, nameString);
                        CFRelease(nameString);
                        if ( temp ) {
                            nameString = temp;
                        }
                        else {
                            // the percent-decoded string had invalid UTF8 bytes - return an empty name string
                            nameString = CFRetain(CFSTR(""));
                        }
                        sawPercent = false;
                    }
                }
                else {
                    nameString = CFRetain(CFSTR(""));
                }
                CFTypeRef keys[] = {_kCFURLComponentsNameKey};
                CFTypeRef values[] = {nameString};
                CFDictionaryRef entry = CFDictionaryCreate(kCFAllocatorSystemDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                CFArrayAppendValue(intermediateResult, entry);
                CFRelease(entry);
                CFRelease(nameString);
            }
            
            result = (CFArrayRef)intermediateResult;
        }
        else {
            // If the query component is an empty string, return an empty array
            result = CFArrayCreate(kCFAllocatorSystemDefault, NULL, 0, &kCFTypeArrayCallBacks);
        }
        
        CFRelease(queryString);
    }
    else {
        // If there is no query component, return nothing
    }
    return ( result );
}

CF_EXPORT CFArrayRef _CFURLComponentsCopyQueryItems(CFURLComponentsRef components) {
    return ( _CFURLComponentsCopyQueryItemsInternal(components, true) );
}

CF_EXPORT CFArrayRef _CFURLComponentsCopyPercentEncodedQueryItems(CFURLComponentsRef components) {
    return ( _CFURLComponentsCopyQueryItemsInternal(components, false) );
}

// n.b. names and values must have the same length
static Boolean _CFURLComponentsSetQueryItemsInternal(CFURLComponentsRef components, CFArrayRef names, CFArrayRef values, Boolean addPercentEncoding ) {
    Boolean result = true;
    if ( names != NULL ) {
        if ( CFArrayGetCount(names) != CFArrayGetCount(values) ) HALT;
        if ( CFArrayGetCount(names) ) {
            CFStringAppendBuffer buf;
            CFStringInitAppendBuffer(kCFAllocatorDefault, &buf);
            UniChar chars[1];
            static CFMutableCharacterSetRef queryNameValueAllowed = NULL;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                queryNameValueAllowed = CFCharacterSetCreateMutableCopy(kCFAllocatorSystemDefault, _CFURLComponentsGetURLQueryAllowedCharacterSet());
                CFCharacterSetRemoveCharactersInString(queryNameValueAllowed, CFSTR("&="));
            });
            CFIndex namesLength = CFArrayGetCount(names);
            Boolean first = true;
            for (CFIndex i = 0; i < namesLength; i++) {
                if ( !first ) {
                    chars[0] = '&';
                    CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
                }
                else {
                    first = false;
                }
                CFTypeRef name = CFArrayGetValueAtIndex(names, i);
                CFTypeRef value = CFArrayGetValueAtIndex(values, i);
                if ( name && name != kCFNull ) {
                    if ( addPercentEncoding ) {
                        CFStringRef stringWithPercentEncoding = _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, name, queryNameValueAllowed);
                        if ( !stringWithPercentEncoding ) {
                            stringWithPercentEncoding = (CFStringRef)CFRetain(CFSTR(""));
                        }
                        CFStringAppendStringToAppendBuffer(&buf, stringWithPercentEncoding);
                        CFRelease(stringWithPercentEncoding);
                    }
                    else {
                        // verify name string contains no illegal characters
                        if ( !_CFURIParserValidateComponent(name, CFRangeMake(0, CFStringGetLength(name)), kURLQueryItemNameAllowed, true) ) {
                            result = false;
                            break;
                        }
                        CFStringAppendStringToAppendBuffer(&buf, name);
                    }
                }
                if ( value && value != kCFNull ) {
                    chars[0] = '=';
                    CFStringAppendCharactersToAppendBuffer(&buf, chars, 1);
                    if ( addPercentEncoding ) {
                        CFStringRef stringWithPercentEncoding = _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, value, queryNameValueAllowed);
                        if ( !stringWithPercentEncoding ) {
                            stringWithPercentEncoding = (CFStringRef)CFRetain(CFSTR(""));
                        }
                        CFStringAppendStringToAppendBuffer(&buf, stringWithPercentEncoding);
                        CFRelease(stringWithPercentEncoding);
                    }
                    else {
                        // verify value string contains no illegal characters
                        if ( !_CFURIParserValidateComponent(value, CFRangeMake(0, CFStringGetLength(value)), kURLQueryAllowed, true) ) {
                            result = false;
                            break;
                        }
                        CFStringAppendStringToAppendBuffer(&buf, value);
                    }
                }
                // else the query item string will be simply "name"
            }
            // even if the result is false, CFStringCreateMutableWithAppendBuffer has to be called so the CFStringAppendBuffer's string can be obtained and released
            CFStringRef queryString = CFStringCreateMutableWithAppendBuffer(&buf);
            if ( result ) {
                _CFURLComponentsSetPercentEncodedQuery(components, queryString);
            }
            if ( queryString ) {
                CFRelease(queryString);
            }
        }
        else {
            // If there's an array but the count is zero, set the query to a zero length string
            _CFURLComponentsSetPercentEncodedQuery(components, CFSTR(""));
        }
    }
    else {
        // If there is no items array, set the query to nil
        _CFURLComponentsSetPercentEncodedQuery(components, NULL);
    }
    return ( result );
}

CF_EXPORT void _CFURLComponentsSetQueryItems(CFURLComponentsRef components, CFArrayRef names, CFArrayRef values ) {
    (void)_CFURLComponentsSetQueryItemsInternal(components, names, values, true); // _CFURLComponentsSetQueryItemsInternal cannot fail if addPercentEncoding is true
}

CF_EXPORT Boolean _CFURLComponentsSetPercentEncodedQueryItems(CFURLComponentsRef components, CFArrayRef names, CFArrayRef values ) {
    return ( _CFURLComponentsSetQueryItemsInternal(components, names, values, false) );
}

/// `implication` is used to validate an URL in `lenient` parsing mode with the requirements on the left side and whether
/// a component exists on the right side. It produces the following truth table:
/// Requirement     Exists      Result
/// true                    true        true
/// true                    false       false
/// false                   true        true
/// false                   false       true
/// This means it will only return false if a component is required but it does not exist.
static inline Boolean implication(Boolean left, Boolean right) {
    return !left || right;
}

/// Validate whether the parsed URL contains the required components.
/// In `lenient` mode, URLs must have all the required components while optionally having all other components;
/// In `strict` mode, URLs must contains exactly the required components.
static Boolean __CFURLComponentsValidateRequiredComponents(const struct _URIParseInfo *parseInfo, _CFURLRequiredComponents requiredComponents) {
    CFRange pathRange = _CFURIParserGetPathRange(parseInfo, false);
    Boolean pathExists = pathRange.location != kCFNotFound && pathRange.length > 0;

    return implication(requiredComponents & kCFURLRequiredComponentScheme, parseInfo->schemeExists) &&
        implication(requiredComponents & kCFURLRequiredComponentUser, parseInfo->userinfoNameExists) &&
        implication(requiredComponents & kCFURLRequiredComponentPassword, parseInfo->userinfoPasswordExists) &&
        implication(requiredComponents & kCFURLRequiredComponentHost, parseInfo->hostExists) &&
        implication(requiredComponents & kCFURLRequiredComponentPort, parseInfo->portExists) &&
        implication(requiredComponents & kCFURLRequiredComponentPath, pathExists) &&
        implication(requiredComponents & kCFURLRequiredComponentQuery, parseInfo->queryExists) &&
        implication(requiredComponents & kCFURLRequiredComponentFragment, parseInfo->fragmentExists);
}

static void __CFURLComponentsFillInDefaultValues(CFURLComponentsRef components, CFDictionaryRef defaultValues) {
    if (defaultValues == NULL || CFDictionaryGetCount(defaultValues) == 0) {
        return;
    }
#define FILL_IN(GETTER, SETTER, REQUIREMENT) ({ \
    CFStringRef value = GETTER(components); \
    if (value == NULL || CFStringGetLength(value) == 0) { \
        CFOptionFlags keyValue = REQUIREMENT; \
        CFNumberRef key = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberLongType, &keyValue); \
        SETTER(components, CFDictionaryGetValue(defaultValues, (void *)key)); \
        if (key) { \
            CFRelease(key); \
        } \
    } \
    if (value) { \
        CFRelease(value); \
    } \
})

    // Fill in scheme
    FILL_IN(_CFURLComponentsCopyScheme,
            _CFURLComponentsSetScheme,
            kCFURLRequiredComponentScheme);

    // Fill in username
    FILL_IN(_CFURLComponentsCopyUser,
            _CFURLComponentsSetUser,
            kCFURLRequiredComponentUser);
    // Fill in password
    FILL_IN(_CFURLComponentsCopyPassword,
            _CFURLComponentsSetPassword,
            kCFURLRequiredComponentPassword);
    // Fill in host
    FILL_IN(_CFURLComponentsCopyHost,
            _CFURLComponentsSetHost,
            kCFURLRequiredComponentHost);
    // Fill in port, which is a special case because it accepts `CFNumber` instead
    // of `CFStringRef`.
    CFNumberRef currentPort = _CFURLComponentsCopyPort(components);
    if (currentPort == NULL) {
        CFOptionFlags port = kCFURLRequiredComponentPort;
        CFNumberRef key = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberLongType, &port);
        const void *value = CFDictionaryGetValue(defaultValues, (void *)key);
        if (key) {
            CFRelease(key);
        }
        if (value) {
            CFTypeID type = CFGetTypeID(value);
            if (type == CFNumberGetTypeID()) {
                _CFURLComponentsSetPort(components, (CFNumberRef)value);
            } else if (type == CFStringGetTypeID()) {
                // We need to convert CFStringRef to CFNumberRef
                CFLocaleRef locale = CFLocaleCopyCurrent();
                CFNumberFormatterRef formatter = CFNumberFormatterCreate(kCFAllocatorSystemDefault, locale, kCFNumberFormatterDecimalStyle);
                if (formatter) {
                    CFNumberRef portValue = CFNumberFormatterCreateNumberFromString(kCFAllocatorSystemDefault, formatter, (CFStringRef)value, NULL, kCFNumberFormatterParseIntegersOnly);
                    _CFURLComponentsSetPort(components, portValue);

                    if (portValue) {
                        CFRelease(portValue);
                    }
                    CFRelease(formatter);
                }

                if (locale) {
                    CFRelease(locale);
                }
            }
        }
    } else {
        CFRelease(currentPort);
    }
    // Fill in path
    FILL_IN(_CFURLComponentsCopyPath,
            _CFURLComponentsSetPath,
            kCFURLRequiredComponentPath);
    // Fill in query
    FILL_IN(_CFURLComponentsCopyQuery,
            _CFURLComponentsSetQuery,
            kCFURLRequiredComponentQuery);
    // Fill in fragment
    FILL_IN(_CFURLComponentsCopyFragment,
            _CFURLComponentsSetFragment,
            kCFURLRequiredComponentFragment);

#undef FILL_IN
}

CF_EXPORT CFRange _CFURLComponentsMatchURLInString(CFStringRef string, _CFURLRequiredComponents requiredComponents, CFDictionaryRef defaultValues, CFURLRef *outURL) {
    // First split the string by whitespaces newlines. Whitespaces will mark the end of the URL
    CFRange whitespaceRange;
    Boolean containsWhitespace = CFStringFindCharacterFromSet(string, CFCharacterSetGetPredefined(kCFCharacterSetWhitespaceAndNewline), CFRangeMake(0, CFStringGetLength(string)), 0, &whitespaceRange);
    CFStringRef urlString;
    if (containsWhitespace) {
        urlString = CFStringCreateWithSubstring(kCFAllocatorDefault, string, CFRangeMake(0, whitespaceRange.location));
    } else {
        urlString = CFStringCreateCopy(kCFAllocatorDefault, string);
    }

    CFRange notFound = CFRangeMake(kCFNotFound, 0);
    struct _URIParseInfo parseInfo;
    _CFURIParserParseURIReference(urlString, &parseInfo);
    if (!__CFURLComponentsValidateRequiredComponents(&parseInfo, requiredComponents)) {
        if (outURL) {
            *outURL = NULL;
        }
        if (urlString) {
            CFRelease(urlString);
        }
        return notFound;
    }

    CFURLRef url = NULL;
    CFURLComponentsRef components = _CFURLComponentsCreateWithString(kCFAllocatorDefault, urlString);
    if (components) {
        // Fill in the defaultValues
        __CFURLComponentsFillInDefaultValues(components, defaultValues);

        url = _CFURLComponentsCopyURL(components);
        CFRelease(components);
    }
    if (urlString) {
        CFRelease(urlString);
    }

    if (url == NULL) {
        if (outURL) {
            *outURL = NULL;
        }
        return notFound;
    }
    if (outURL) {
        *outURL = url;
    } else {
        CFRelease(url);
    }
    return containsWhitespace ? CFRangeMake(0, whitespaceRange.location) : CFRangeMake(0, CFStringGetLength(string));
}
