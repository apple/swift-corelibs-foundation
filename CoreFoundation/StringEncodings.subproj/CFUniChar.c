/*	CFUniChar.c
	Copyright (c) 2001-2019, Apple Inc. and the Swift project authors
 
	Portions Copyright (c) 2014-2019, Apple Inc. and the Swift project authors
	Licensed under Apache License v2.0 with Runtime Library Exception
	See http://swift.org/LICENSE.txt for license information
	See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
	Responsibility: Foundation Team
*/

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFByteOrder.h>
#include "CFInternal.h"
#include "CFUniChar.h" 
#include "CFStringEncodingConverterExt.h"
#include "CFUnicodeDecomposition.h"
#include "CFUniCharPriv.h"

#include "CFUniCharBitmapData.inc.h"
#include "CFUniCharPropertyDatabase.inc.h"
#if __LITTLE_ENDIAN__
#include "CFUnicodeCaseMapping-L.inc.h"
#include "CFUnicodeData-L.inc.h"
#else
#include "CFUnicodeCaseMapping-B.inc.h"
#include "CFUnicodeData-B.inc.h"
#endif

enum {
    kCFUniCharLastExternalSet = kCFUniCharNewlineCharacterSet,
    kCFUniCharFirstInternalSet = kCFUniCharCompatibilityDecomposableCharacterSet,
    kCFUniCharLastInternalSet = kCFUniCharGraphemeExtendCharacterSet,
    kCFUniCharFirstBitmapSet = kCFUniCharDecimalDigitCharacterSet
};

CF_INLINE uint32_t __CFUniCharMapExternalSetToInternalIndex(uint32_t cset) { return ((kCFUniCharFirstInternalSet <= cset) ? ((cset - kCFUniCharFirstInternalSet) + kCFUniCharLastExternalSet) : cset) - kCFUniCharFirstBitmapSet; }
CF_INLINE uint32_t __CFUniCharMapCompatibilitySetID(uint32_t cset) { return ((cset == kCFUniCharControlCharacterSet) ? kCFUniCharControlAndFormatterCharacterSet : (((cset > kCFUniCharLastExternalSet) && (cset < kCFUniCharFirstInternalSet)) ? ((cset - kCFUniCharLastExternalSet) + kCFUniCharFirstInternalSet) : cset)); }


// Bitmap functions
/*
 Currently unused but left in for symmetry/informative purposes
 CF_INLINE bool isControl(UTF32Char theChar, uint16_t charset, const void *data) { // ISO Control
    return (((theChar <= 0x001F) || (theChar >= 0x007F && theChar <= 0x009F)) ? true : false);
}*/

CF_INLINE bool isWhitespace(UTF32Char theChar, uint16_t charset, const void *data) { // Space
    return (((theChar == 0x0020) || (theChar == 0x0009) || (theChar == 0x00A0) || (theChar == 0x1680) || (theChar >= 0x2000 && theChar <= 0x200B) || (theChar == 0x202F) || (theChar == 0x205F) || (theChar == 0x3000)) ? true : false);
}

CF_INLINE bool isNewline(UTF32Char theChar, uint16_t charset, const void *data) { // White space
    return (((theChar >= 0x000A && theChar <= 0x000D) || (theChar == 0x0085) || (theChar == 0x2028) || (theChar == 0x2029)) ? true : false);
}

CF_INLINE bool isWhitespaceAndNewline(UTF32Char theChar, uint16_t charset, const void *data) { // White space
    return ((isWhitespace(theChar, charset, data) || isNewline(theChar, charset, data)) ? true : false);
}

bool CFUniCharIsMemberOf(UTF32Char theChar, uint32_t charset) {
    charset = __CFUniCharMapCompatibilitySetID(charset);

    switch (charset) {
        case kCFUniCharWhitespaceCharacterSet:
            return isWhitespace(theChar, charset, NULL);

        case kCFUniCharWhitespaceAndNewlineCharacterSet:
            return isWhitespaceAndNewline(theChar, charset, NULL);

        case kCFUniCharNewlineCharacterSet:
            return isNewline(theChar, charset, NULL);

        default: {
            uint32_t tableIndex = __CFUniCharMapExternalSetToInternalIndex(charset);

            if (tableIndex < __CFUniCharNumberOfBitmaps) {
                const __CFUniCharBitmapData *data = __CFUniCharBitmapDataArray + tableIndex;
                uint8_t planeNo = (theChar >> 16) & 0xFF;

                // The bitmap data for kCFUniCharIllegalCharacterSet is actually LEGAL set less Plane 14 ~ 16
                if (charset == kCFUniCharIllegalCharacterSet) {
                    if (planeNo == 0x0E) { // Plane 14
                        theChar &= 0xFF;
                        return (((theChar == 0x01) || ((theChar > 0x1F) && (theChar < 0x80))) ? false : true);
                    } else if (planeNo == 0x0F || planeNo == 0x10) { // Plane 15 & 16
                        return ((theChar & 0xFF) > 0xFFFD ? true : false);
                    } else {
                        return (planeNo < data->_numPlanes && data->_planes[planeNo] ? !CFUniCharIsMemberOfBitmap(theChar, data->_planes[planeNo]) : true);
                    }
                } else if (charset == kCFUniCharControlAndFormatterCharacterSet) {
                    if (planeNo == 0x0E) { // Plane 14
                        theChar &= 0xFF;
                        return (((theChar == 0x01) || ((theChar > 0x1F) && (theChar < 0x80))) ? true : false);
                    } else {
                        return (planeNo < data->_numPlanes && data->_planes[planeNo] ? CFUniCharIsMemberOfBitmap(theChar, data->_planes[planeNo]) : false);
                    }
                } else {
                    return (planeNo < data->_numPlanes && data->_planes[planeNo] ? CFUniCharIsMemberOfBitmap(theChar, data->_planes[planeNo]) : false);
                }
            }
            return false;
        }
    }
}

const uint8_t *CFUniCharGetBitmapPtrForPlane(uint32_t charset, uint32_t plane) {

    charset = __CFUniCharMapCompatibilitySetID(charset);

    if ((charset > kCFUniCharWhitespaceAndNewlineCharacterSet) && (charset != kCFUniCharIllegalCharacterSet) && (charset != kCFUniCharNewlineCharacterSet)) {
        uint32_t tableIndex = __CFUniCharMapExternalSetToInternalIndex(charset);

        if (tableIndex < __CFUniCharNumberOfBitmaps) {
            const __CFUniCharBitmapData *data = __CFUniCharBitmapDataArray + tableIndex;

            return (plane < data->_numPlanes ? data->_planes[plane] : NULL);
        }
    }
    return NULL;
}

CF_PRIVATE uint8_t CFUniCharGetBitmapForPlane(uint32_t charset, uint32_t plane, void *bitmap, bool isInverted) {
    const uint8_t *src = CFUniCharGetBitmapPtrForPlane(charset, plane);
    int numBytes = (8 * 1024);

    if (src) {
        if (isInverted) {
#if defined (__cplusplus)
			while (numBytes-- > 0) *(((uint8_t *&)bitmap)++) = ~(*(src++));
#else
			while (numBytes-- > 0) *((uint8_t *)bitmap++) = ~(*(src++));
#endif
        } else {
#if defined (__cplusplus)
            while (numBytes-- > 0) *(((uint8_t *&)bitmap)++) = *(src++);
#else
			while (numBytes-- > 0) *((uint8_t *)bitmap++) = *(src++);
#endif
        }
        return kCFUniCharBitmapFilled;
    } else if (charset == kCFUniCharIllegalCharacterSet) {
        const __CFUniCharBitmapData *data = __CFUniCharBitmapDataArray + __CFUniCharMapExternalSetToInternalIndex(__CFUniCharMapCompatibilitySetID(charset));

        if (plane < data->_numPlanes && (src = data->_planes[plane])) {
            if (isInverted) {
#if defined (__cplusplus)                
				while (numBytes-- > 0) *(((uint8_t *&)bitmap)++) = *(src++);
#else
				while (numBytes-- > 0) *((uint8_t *)bitmap++) = *(src++);
#endif
            } else {
#if defined (__cplusplus)                
                while (numBytes-- > 0) *(((uint8_t *&)bitmap)++) = ~(*(src++));
#else
				while (numBytes-- > 0) *((uint8_t *)bitmap++) = ~(*(src++));
#endif
            }
            return kCFUniCharBitmapFilled;
        } else if (plane == 0x0E) { // Plane 14
            int idx;
            uint8_t asciiRange = (isInverted ? (uint8_t)0xFF : (uint8_t)0);
            uint8_t otherRange = (isInverted ? (uint8_t)0 : (uint8_t)0xFF);

#if defined (__cplusplus)
			*(((uint8_t *&)bitmap)++) = 0x02; // UE0001 LANGUAGE TAG
#else
			*((uint8_t *)bitmap++) = 0x02; // UE0001 LANGUAGE TAG
#endif
            for (idx = 1;idx < numBytes;idx++) {
#if defined (__cplusplus)                
				*(((uint8_t *&)bitmap)++) = ((idx >= (0x20 / 8) && (idx < (0x80 / 8))) ? asciiRange : otherRange);
#else
				*((uint8_t *)bitmap++) = ((idx >= (0x20 / 8) && (idx < (0x80 / 8))) ? asciiRange : otherRange);
#endif
            }
            return kCFUniCharBitmapFilled;
        } else if (plane == 0x0F || plane == 0x10) { // Plane 15 & 16
            uint32_t value = (isInverted ? ~0 : 0);
            numBytes /= 4; // for 32bit

            while (numBytes-- > 0) {
                _CFUnalignedStore32(bitmap, value);
#if defined (__cplusplus)
				bitmap = (uint8_t *)bitmap + sizeof(uint32_t);				
#else
				bitmap += sizeof(uint32_t);
#endif
            }
            *(((uint8_t *)bitmap) - 5) = (isInverted ? 0x3F : 0xC0); // 0xFFFE & 0xFFFF
            return kCFUniCharBitmapFilled;
        }
        return (isInverted ? kCFUniCharBitmapEmpty : kCFUniCharBitmapAll);
    } else if ((charset < kCFUniCharDecimalDigitCharacterSet) || (charset == kCFUniCharNewlineCharacterSet)) {
        if (plane) return (isInverted ? kCFUniCharBitmapAll : kCFUniCharBitmapEmpty);

        uint8_t *bitmapBase = (uint8_t *)bitmap;
        CFIndex idx;
        uint8_t nonFillValue = (isInverted ? (uint8_t)0xFF : (uint8_t)0);

#if defined (__cplusplus)
                    while (numBytes-- > 0) *(((uint8_t *&)bitmap)++) = nonFillValue;
#else
                    while (numBytes-- > 0) *((uint8_t *)bitmap++) = nonFillValue;
#endif

        if ((charset == kCFUniCharWhitespaceAndNewlineCharacterSet) || (charset == kCFUniCharNewlineCharacterSet)) {
            const UniChar newlines[] = {0x000A, 0x000B, 0x000C, 0x000D, 0x0085, 0x2028, 0x2029};

            for (idx = 0;idx < (int)(sizeof(newlines) / sizeof(*newlines)); idx++) {
                if (isInverted) {
                    CFUniCharRemoveCharacterFromBitmap(newlines[idx], bitmapBase);
                } else {
                    CFUniCharAddCharacterToBitmap(newlines[idx], bitmapBase);
                }
            }

            if (charset == kCFUniCharNewlineCharacterSet) return kCFUniCharBitmapFilled;
        }

        if (isInverted) {
            CFUniCharRemoveCharacterFromBitmap(0x0009, bitmapBase);
            CFUniCharRemoveCharacterFromBitmap(0x0020, bitmapBase);
            CFUniCharRemoveCharacterFromBitmap(0x00A0, bitmapBase);
            CFUniCharRemoveCharacterFromBitmap(0x1680, bitmapBase);
            CFUniCharRemoveCharacterFromBitmap(0x202F, bitmapBase);
            CFUniCharRemoveCharacterFromBitmap(0x205F, bitmapBase);
            CFUniCharRemoveCharacterFromBitmap(0x3000, bitmapBase);
        } else {
            CFUniCharAddCharacterToBitmap(0x0009, bitmapBase);
            CFUniCharAddCharacterToBitmap(0x0020, bitmapBase);
            CFUniCharAddCharacterToBitmap(0x00A0, bitmapBase);
            CFUniCharAddCharacterToBitmap(0x1680, bitmapBase);
            CFUniCharAddCharacterToBitmap(0x202F, bitmapBase);
            CFUniCharAddCharacterToBitmap(0x205F, bitmapBase);
            CFUniCharAddCharacterToBitmap(0x3000, bitmapBase);
        }

        for (idx = 0x2000;idx <= 0x200B;idx++) {
            if (isInverted) {
                CFUniCharRemoveCharacterFromBitmap(idx, bitmapBase);
            } else {
                CFUniCharAddCharacterToBitmap(idx, bitmapBase);
            }
        }
        return kCFUniCharBitmapFilled;
    }
    return (isInverted ? kCFUniCharBitmapAll : kCFUniCharBitmapEmpty);
}

CF_PRIVATE uint32_t CFUniCharGetNumberOfPlanes(uint32_t charset) {
    if ((charset == kCFUniCharControlCharacterSet) || (charset == kCFUniCharControlAndFormatterCharacterSet)) {
        return 15; // 0 to 14
    } else if (charset < kCFUniCharDecimalDigitCharacterSet) {
        return 1;
    } else if (charset == kCFUniCharIllegalCharacterSet) {
        return 17;
    } else {
        uint32_t numPlanes;

        numPlanes = __CFUniCharBitmapDataArray[__CFUniCharMapExternalSetToInternalIndex(__CFUniCharMapCompatibilitySetID(charset))]._numPlanes;

        return numPlanes;
    }
}

/*
type:
    kCFUniCharToLowercase = 0
    kCFUniCharToUppercase = 1
    kCFUniCharToTitlecase = 2
    kCFUniCharCaseFold
    kCFUniCharCanonicalDecompMapping
    kCFUniCharCanonicalPrecompMapping
    kCFUniCharCompatibilityDecompMapping

This order follows that specified by the `mapping` array in UnicodeData/MergeFiles.xml.
*/
CF_PRIVATE const void *CFUniCharGetMappingData(uint32_t type) {

    return __CFUniCharMappingTables[type];
}

// Case mapping functions
#define DO_SPECIAL_CASE_MAPPING 1


typedef struct {
    uint32_t _key;
    uint32_t _value;
} __CFUniCharCaseMappings;

/* Binary searches CFStringEncodingUnicodeTo8BitCharMap */
static uint32_t __CFUniCharGetMappedCase(const __CFUniCharCaseMappings *theTable, uint32_t numElem, UTF32Char character) {
    const __CFUniCharCaseMappings *p, *q, *divider;

#define READ_KEY(x)     _CFUnalignedLoad32(((uint8_t *)x) + offsetof(__CFUniCharCaseMappings, _key))
#define READ_VALUE(x)   _CFUnalignedLoad32(((uint8_t *)x) + offsetof(__CFUniCharCaseMappings, _value))

    if ((character < READ_KEY(&theTable[0])) || (character > READ_KEY(&theTable[numElem-1]))) {
        return 0;
    }
    p = theTable;
    q = p + (numElem-1);
    while (p <= q) {
        divider = p + ((q - p) >> 1);	/* divide by 2 */
        if (character < READ_KEY(divider)) { q = divider - 1; }
        else if (character > READ_KEY(divider)) { p = divider + 1; }
        else { return READ_VALUE(divider); }
    }
    return 0;

#undef READ_KEY
#undef READ_VALUE
}

#if __CF_BIG_ENDIAN__
#define TURKISH_LANG_CODE	(0x7472) // tr
#define LITHUANIAN_LANG_CODE	(0x6C74) // lt
#define AZERI_LANG_CODE		(0x617A) // az
#define DUTCH_LANG_CODE		(0x6E6C) // nl
#define GREEK_LANG_CODE		(0x656C) // el
#else
#define TURKISH_LANG_CODE	(0x7274) // tr
#define LITHUANIAN_LANG_CODE	(0x746C) // lt
#define AZERI_LANG_CODE		(0x7A61) // az
#define DUTCH_LANG_CODE		(0x6C6E) // nl
#define GREEK_LANG_CODE		(0x6C65) // el
#endif

CFIndex CFUniCharMapCaseTo(UTF32Char theChar, UTF16Char *convertedChar, CFIndex maxLength, uint32_t ctype, uint32_t flags, const uint8_t *langCode) {
    const __CFUniCharBitmapData *data;
    uint8_t planeNo = (theChar >> 16) & 0xFF;

caseFoldRetry:

#if DO_SPECIAL_CASE_MAPPING
    if (flags & kCFUniCharCaseMapFinalSigma) {
        if (theChar == 0x03A3) { // Final sigma
            *convertedChar = (ctype == kCFUniCharToLowercase ? 0x03C2 : 0x03A3);
            return 1;
        }
    }

    if (langCode) {
        if (flags & kCFUniCharCaseMapGreekTonos) { // localized Greek uppercasing
            if (theChar == 0x0301) { // GREEK TONOS
                return 0;
            } else if (theChar == 0x0344) {// COMBINING GREEK DIALYTIKA TONOS
                *convertedChar = 0x0308; // COMBINING GREEK DIALYTIKA
                return 1;
            } else if (CFUniCharIsMemberOf(theChar, kCFUniCharDecomposableCharacterSet)) {
                UTF32Char buffer[MAX_DECOMPOSED_LENGTH];
                CFIndex length = CFUniCharDecomposeCharacter(theChar, buffer, MAX_DECOMPOSED_LENGTH);

                if (length > 1) {
                    UTF32Char *characters = buffer + 1;
                    UTF32Char *tail = buffer + length;

                    while (characters < tail) {
                        if (*characters == 0x0301) break;
                        ++characters;
                    }

                    if (characters < tail) { // found a tonos
                        CFIndex convertedLength = CFUniCharMapCaseTo(*buffer, convertedChar, maxLength, ctype, 0, langCode);

                        if (convertedLength == 0) {
                            *convertedChar = (UTF16Char)*buffer;
                            convertedLength = 1;
                        }

                        characters = buffer + 1;

                        while (characters < tail) {
                            if (*characters != 0x0301) { // not tonos
                                if (*characters < 0x10000) { // BMP
                                    convertedChar[convertedLength] = (UTF16Char)*characters;
                                    ++convertedLength;
                                } else {
                                    UTF32Char character = *characters - 0x10000;
                                    convertedChar[convertedLength++] = (UTF16Char)((character >> 10) + 0xD800UL);
                                    convertedChar[convertedLength++] = (UTF16Char)((character & 0x3FF) + 0xDC00UL);
                                }
                            }
                            ++characters;
                        }

                        return convertedLength;
                    }
                }
            }
        }
        switch (*(uint16_t *)langCode) {
            case LITHUANIAN_LANG_CODE:
                if (theChar == 0x0307 && (flags & kCFUniCharCaseMapAfter_i)) {
                    return 0;
                } else if (ctype == kCFUniCharToLowercase) {
                    if (flags & kCFUniCharCaseMapMoreAbove) {
                        switch (theChar) {
                            case 0x0049: // LATIN CAPITAL LETTER I
                                *(convertedChar++) = 0x0069;
                                *(convertedChar++) = 0x0307;
                                return 2;

                            case 0x004A: // LATIN CAPITAL LETTER J
                                *(convertedChar++) = 0x006A;
                                *(convertedChar++) = 0x0307;
                                return 2;

                            case 0x012E: // LATIN CAPITAL LETTER I WITH OGONEK
                                *(convertedChar++) = 0x012F;
                                *(convertedChar++) = 0x0307;
                                return 2;

                            default: break;
                        }
                    }
                    switch (theChar) {
                        case 0x00CC: // LATIN CAPITAL LETTER I WITH GRAVE
                            *(convertedChar++) = 0x0069;
                            *(convertedChar++) = 0x0307;
                            *(convertedChar++) = 0x0300;
                            return 3;

                        case 0x00CD: // LATIN CAPITAL LETTER I WITH ACUTE
                            *(convertedChar++) = 0x0069;
                            *(convertedChar++) = 0x0307;
                            *(convertedChar++) = 0x0301;
                            return 3;

                        case 0x0128: // LATIN CAPITAL LETTER I WITH TILDE
                            *(convertedChar++) = 0x0069;
                            *(convertedChar++) = 0x0307;
                            *(convertedChar++) = 0x0303;
                            return 3;

                        default: break;
                    }
                }
            break;

            case TURKISH_LANG_CODE:
            case AZERI_LANG_CODE:
                if ((theChar == 0x0049) || (theChar == 0x0131)) { // LATIN CAPITAL LETTER I & LATIN SMALL LETTER DOTLESS I
                    *convertedChar = (((ctype == kCFUniCharToLowercase) || (ctype == kCFUniCharCaseFold))  ? ((kCFUniCharCaseMapMoreAbove & flags) ? 0x0069 : 0x0131) : 0x0049);
                    return 1;
                } else if ((theChar == 0x0069) || (theChar == 0x0130)) { // LATIN SMALL LETTER I & LATIN CAPITAL LETTER I WITH DOT ABOVE
                    *convertedChar = (((ctype == kCFUniCharToLowercase) || (ctype == kCFUniCharCaseFold)) ? 0x0069 : 0x0130);
                    return 1;
                } else if (theChar == 0x0307 && (kCFUniCharCaseMapAfter_i & flags)) { // COMBINING DOT ABOVE AFTER_i
                    if (ctype == kCFUniCharToLowercase) {
                        return 0;
                    } else {
                        *convertedChar = 0x0307;
                        return 1;
                    }
                }
                break;

	    case DUTCH_LANG_CODE:
		if ((theChar == 0x004A) || (theChar == 0x006A)) {
                    *convertedChar = (((ctype == kCFUniCharToUppercase) || (ctype == kCFUniCharToTitlecase) || (kCFUniCharCaseMapDutchDigraph & flags)) ? 0x004A  : 0x006A);
                    return 1;
		}
		break;

            default: break;
        }
    }
#endif // DO_SPECIAL_CASE_MAPPING

    data = __CFUniCharBitmapDataArray + __CFUniCharMapExternalSetToInternalIndex(__CFUniCharMapCompatibilitySetID(ctype + kCFUniCharHasNonSelfLowercaseCharacterSet));

    if (planeNo < data->_numPlanes && data->_planes[planeNo] && CFUniCharIsMemberOfBitmap(theChar, data->_planes[planeNo])) {
        uint32_t value = __CFUniCharGetMappedCase((const __CFUniCharCaseMappings *)__CFUniCharCaseMappingTable[ctype], __CFUniCharCaseMappingTableCounts[ctype], theChar);

        if (!value && ctype == kCFUniCharToTitlecase) {
            value = __CFUniCharGetMappedCase((const __CFUniCharCaseMappings *)__CFUniCharCaseMappingTable[kCFUniCharToUppercase], __CFUniCharCaseMappingTableCounts[kCFUniCharToUppercase], theChar);
            if (value) ctype = kCFUniCharToUppercase;
        }

        if (value) {
            CFIndex count = CFUniCharConvertFlagToCount(value);

            if (count == 1) {
                if (value & kCFUniCharNonBmpFlag) {
                    if (maxLength > 1) {
                        value = (value & 0xFFFFFF) - 0x10000;
                        *(convertedChar++) = (UTF16Char)(value >> 10) + 0xD800UL;
                        *(convertedChar++) = (UTF16Char)(value & 0x3FF) + 0xDC00UL;
                        return 2;
                    }
                } else {
                    *convertedChar = (UTF16Char)value;
                    return 1;
                }
            } else if (count < maxLength) {
                const uint32_t *extraMapping = __CFUniCharCaseMappingExtraTable[ctype] + (value & 0xFFFFFF);

                if (value & kCFUniCharNonBmpFlag) {
                    CFIndex copiedLen = 0;

                    while (count-- > 0) {
                        value = *(extraMapping++);
                        if (value > 0xFFFF) {
                            if (copiedLen + 2 >= maxLength) break;
                            value = (value & 0xFFFFFF) - 0x10000;
                            convertedChar[copiedLen++] = (UTF16Char)(value >> 10) + 0xD800UL;
                            convertedChar[copiedLen++] = (UTF16Char)(value & 0x3FF) + 0xDC00UL;
                        } else {
                            if (copiedLen + 1 >= maxLength) break;
                            convertedChar[copiedLen++] = value;
                        }
                    }
                    if (!count) return copiedLen;
                } else {
                    CFIndex idx;

                    for (idx = 0;idx < count;idx++) *(convertedChar++) = (UTF16Char)_CFUnalignedLoad32(extraMapping++);
                    return count;
                }
            }
        }
    } else if (ctype == kCFUniCharCaseFold) {
        ctype = kCFUniCharToLowercase;
        goto caseFoldRetry;
    }

    if (theChar > 0xFFFF) { // non-BMP
        theChar = (theChar & 0xFFFFFF) - 0x10000;
        *(convertedChar++) = (UTF16Char)(theChar >> 10) + 0xD800UL;
        *(convertedChar++) = (UTF16Char)(theChar & 0x3FF) + 0xDC00UL;
        return 2;
    } else {
        *convertedChar = theChar;
        return 1;
    }
}

CFIndex CFUniCharMapTo(UniChar theChar, UniChar *convertedChar, CFIndex maxLength, uint16_t ctype, uint32_t flags) {
    if (ctype == kCFUniCharCaseFold + 1) { // kCFUniCharDecompose
        if (CFUniCharIsDecomposableCharacter(theChar, false)) {
            UTF32Char buffer[MAX_DECOMPOSED_LENGTH];
            CFIndex usedLength = CFUniCharDecomposeCharacter(theChar, buffer, MAX_DECOMPOSED_LENGTH);
            CFIndex idx;

            for (idx = 0;idx < usedLength;idx++) *(convertedChar++) = buffer[idx];
            return usedLength;
        } else {
            *convertedChar = theChar;
            return 1;
        }
    } else {
        return CFUniCharMapCaseTo(theChar, convertedChar, maxLength, ctype, flags, NULL);
    }
}

CF_INLINE bool __CFUniCharIsMoreAbove(UTF16Char *buffer, CFIndex length) {
    UTF32Char currentChar;
    uint32_t property;

    while (length-- > 0) {
        currentChar = *(buffer)++;
        if (CFUniCharIsSurrogateHighCharacter(currentChar) && (length > 0) && CFUniCharIsSurrogateLowCharacter(*(buffer + 1))) {
            currentChar = CFUniCharGetLongCharacterForSurrogatePair(currentChar, *(buffer++));
            --length;
        }
        if (!CFUniCharIsMemberOf(currentChar, kCFUniCharNonBaseCharacterSet)) break;

        property = CFUniCharGetCombiningPropertyForCharacter(currentChar, (const uint8_t *)CFUniCharGetUnicodePropertyDataForPlane(kCFUniCharCombiningProperty, (currentChar >> 16) & 0xFF));

        if (property == 230) return true; // Above priority
    }
    return false;
}

CF_INLINE bool __CFUniCharIsAfter_i(UTF16Char *buffer, CFIndex length) {
    UTF32Char currentChar = 0;
    uint32_t property;
    UTF32Char decomposed[MAX_DECOMPOSED_LENGTH];
    CFIndex decompLength;
    CFIndex idx;

    if (length < 1) return 0;

    buffer += length;
    while (length-- > 1) {
        currentChar = *(--buffer);
        if (CFUniCharIsSurrogateLowCharacter(currentChar)) {
            if ((length > 1) && CFUniCharIsSurrogateHighCharacter(*(buffer - 1))) {
                currentChar = CFUniCharGetLongCharacterForSurrogatePair(*(--buffer), currentChar);
                --length;
            } else {
                break;
            }
        }
        if (!CFUniCharIsMemberOf(currentChar, kCFUniCharNonBaseCharacterSet)) break;

        property = CFUniCharGetCombiningPropertyForCharacter(currentChar, (const uint8_t *)CFUniCharGetUnicodePropertyDataForPlane(kCFUniCharCombiningProperty, (currentChar >> 16) & 0xFF));

        if (property == 230) return false; // Above priority
    }
    if (length == 0) {
        currentChar = *(--buffer);
    } else if (CFUniCharIsSurrogateLowCharacter(currentChar) && CFUniCharIsSurrogateHighCharacter(*(--buffer))) {
        currentChar = CFUniCharGetLongCharacterForSurrogatePair(*buffer, currentChar);
    }

    decompLength = CFUniCharDecomposeCharacter(currentChar, decomposed, MAX_DECOMPOSED_LENGTH);
    currentChar = *decomposed;


    for (idx = 1;idx < decompLength;idx++) {
        currentChar = decomposed[idx];
        property = CFUniCharGetCombiningPropertyForCharacter(currentChar, (const uint8_t *)CFUniCharGetUnicodePropertyDataForPlane(kCFUniCharCombiningProperty, (currentChar >> 16) & 0xFF));

        if (property == 230) return false; // Above priority
    }
    return true;
}

CF_PRIVATE uint32_t CFUniCharGetConditionalCaseMappingFlags(UTF32Char theChar, UTF16Char *buffer, CFIndex currentIndex, CFIndex length, uint32_t type, const uint8_t *langCode, uint32_t lastFlags) {
    if (theChar == 0x03A3) { // GREEK CAPITAL LETTER SIGMA
        if ((type == kCFUniCharToLowercase) && (currentIndex > 0)) {
            UTF16Char *start = buffer;
            UTF16Char *end = buffer + length;
            UTF32Char otherChar;

            // First check if we're after a cased character
            buffer += (currentIndex - 1);
            while (start <= buffer) {
                otherChar = *(buffer--);
                if (CFUniCharIsSurrogateLowCharacter(otherChar) && (start <= buffer) && CFUniCharIsSurrogateHighCharacter(*buffer)) {
                    otherChar = CFUniCharGetLongCharacterForSurrogatePair(*(buffer--), otherChar);
                }
                if (!CFUniCharIsMemberOf(otherChar, kCFUniCharCaseIgnorableCharacterSet)) {
                    if (!CFUniCharIsMemberOf(otherChar, kCFUniCharUppercaseLetterCharacterSet) && !CFUniCharIsMemberOf(otherChar, kCFUniCharLowercaseLetterCharacterSet)) return 0; // Uppercase set contains titlecase
                    break;
                }
            }

            // Next check if we're before a cased character
            buffer = start + currentIndex + 1;
            while (buffer < end) {
                otherChar = *(buffer++);
                if (CFUniCharIsSurrogateHighCharacter(otherChar) && (buffer < end) && CFUniCharIsSurrogateLowCharacter(*buffer)) {
                    otherChar = CFUniCharGetLongCharacterForSurrogatePair(otherChar, *(buffer++));
                }
                if (!CFUniCharIsMemberOf(otherChar, kCFUniCharCaseIgnorableCharacterSet)) {
                    if (CFUniCharIsMemberOf(otherChar, kCFUniCharUppercaseLetterCharacterSet) || CFUniCharIsMemberOf(otherChar, kCFUniCharLowercaseLetterCharacterSet)) return 0; // Uppercase set contains titlecase
                    break;
                }
            }
            return kCFUniCharCaseMapFinalSigma;
        }
    } else if (langCode) {
        if (*((const uint16_t *)langCode) == LITHUANIAN_LANG_CODE) {
            if ((theChar == 0x0307) && ((kCFUniCharCaseMapAfter_i|kCFUniCharCaseMapMoreAbove) & lastFlags) == (kCFUniCharCaseMapAfter_i|kCFUniCharCaseMapMoreAbove)) {
                return (__CFUniCharIsAfter_i(buffer, currentIndex) ? kCFUniCharCaseMapAfter_i : 0);
            } else if (type == kCFUniCharToLowercase) {
                if ((theChar == 0x0049) || (theChar == 0x004A) || (theChar == 0x012E)) {
                    ++currentIndex;
                    return (__CFUniCharIsMoreAbove(buffer + currentIndex, length - currentIndex) ? kCFUniCharCaseMapMoreAbove : 0);
                }
            } else if ((theChar == 'i') || (theChar == 'j')) {
                ++currentIndex;
                return (__CFUniCharIsMoreAbove(buffer + currentIndex, length - currentIndex) ? (kCFUniCharCaseMapAfter_i|kCFUniCharCaseMapMoreAbove) : 0);
            }
        } else if ((*((const uint16_t *)langCode) == TURKISH_LANG_CODE) || (*((const uint16_t *)langCode) == AZERI_LANG_CODE)) {
            if (type == kCFUniCharToLowercase) {
                if (theChar == 0x0307) {
                    return (kCFUniCharCaseMapMoreAbove & lastFlags ? kCFUniCharCaseMapAfter_i : 0);
                } else if (theChar == 0x0049) {
                    return (((++currentIndex < length) && (buffer[currentIndex] == 0x0307)) ? kCFUniCharCaseMapMoreAbove : 0);
                }
            }
        } else if (*((const uint16_t *)langCode) == DUTCH_LANG_CODE) {
	    if (kCFUniCharCaseMapDutchDigraph & lastFlags) {
		return (((theChar == 0x006A) || (theChar == 0x004A)) ? kCFUniCharCaseMapDutchDigraph : 0);
	    } else {
		if ((type == kCFUniCharToTitlecase) && ((theChar == 0x0069) || (theChar == 0x0049))) {
		    return (((++currentIndex < length) && ((buffer[currentIndex] == 0x006A) || (buffer[currentIndex] == 0x004A))) ? kCFUniCharCaseMapDutchDigraph : 0);
		}
	    }
	}

        if (kCFUniCharCaseMapGreekTonos & lastFlags) { // still searching for tonos
            if (CFUniCharIsMemberOf(theChar, kCFUniCharNonBaseCharacterSet)) {
                return kCFUniCharCaseMapGreekTonos;
            }
        }
        if (((theChar >= 0x0370) && (theChar < 0x0400)) || ((theChar >= 0x1F00) && (theChar < 0x2000))) { // Greek/Coptic & Greek extended ranges
            if ((type == kCFUniCharToUppercase) && (CFUniCharIsMemberOf(theChar, kCFUniCharLetterCharacterSet))) return kCFUniCharCaseMapGreekTonos;
        }
    }
    return 0;
}

// Unicode property database

const void *CFUniCharGetUnicodePropertyDataForPlane(uint32_t propertyType, uint32_t plane) {
    return (plane < __CFUniCharUnicodePropertyTable[propertyType]._numPlanes ? __CFUniCharUnicodePropertyTable[propertyType]._planes[plane] : NULL);
}

CF_PRIVATE uint32_t CFUniCharGetNumberOfPlanesForUnicodePropertyData(uint32_t propertyType) {
    (void)CFUniCharGetUnicodePropertyDataForPlane(propertyType, 0);
    return __CFUniCharUnicodePropertyTable[propertyType]._numPlanes;
}

CF_PRIVATE uint32_t CFUniCharGetUnicodeProperty(UTF32Char character, uint32_t propertyType) {
    if (propertyType == kCFUniCharCombiningProperty) {
        return CFUniCharGetCombiningPropertyForCharacter(character, (const uint8_t *)CFUniCharGetUnicodePropertyDataForPlane(propertyType, (character >> 16) & 0xFF));
    } else if (propertyType == kCFUniCharBidiProperty) {
        return CFUniCharGetBidiPropertyForCharacter(character, (const uint8_t *)CFUniCharGetUnicodePropertyDataForPlane(propertyType, (character >> 16) & 0xFF));
    } else {
        return 0;
    }
}



/*
    The UTF8 conversion in the following function is derived from ConvertUTF.c
*/
/*
 * Copyright 2001 Unicode, Inc.
 * 
 * Disclaimer
 * 
 * This source code is provided as is by Unicode, Inc. No claims are
 * made as to fitness for any particular purpose. No warranties of any
 * kind are expressed or implied. The recipient agrees to determine
 * applicability of information provided. If this file has been
 * purchased on magnetic or optical media from Unicode, Inc., the
 * sole remedy for any claim will be exchange of defective media
 * within 90 days of receipt.
 * 
 * Limitations on Rights to Redistribute This Code
 * 
 * Unicode, Inc. hereby grants the right to freely use the information
 * supplied in this file in the creation of products supporting the
 * Unicode Standard, and to make copies of this file in any form
 * for internal or external distribution as long as this notice
 * remains attached.
 */
#define UNI_REPLACEMENT_CHAR (0x0000FFFDUL)

bool CFUniCharFillDestinationBuffer(const UTF32Char *src, CFIndex srcLength, void **dst, CFIndex dstLength, CFIndex *filledLength, uint32_t dstFormat) {
    UTF32Char currentChar;
    CFIndex usedLength = *filledLength;

    if (dstFormat == kCFUniCharUTF16Format) {
        UTF16Char *dstBuffer = (UTF16Char *)*dst;

        while (srcLength-- > 0) {
            currentChar = *(src++);

            if (currentChar > 0xFFFF) { // Non-BMP
                usedLength += 2;
                if (dstLength) {
                    if (usedLength > dstLength) return false;
                    currentChar -= 0x10000;
                    *(dstBuffer++) = (UTF16Char)((currentChar >> 10) + 0xD800UL);
                    *(dstBuffer++) = (UTF16Char)((currentChar & 0x3FF) + 0xDC00UL);
                }
            } else {
                ++usedLength;
                if (dstLength) {
                    if (usedLength > dstLength) return false;
                    *(dstBuffer++) = (UTF16Char)currentChar;
                }
            }
        }

        *dst = dstBuffer;
    } else if (dstFormat == kCFUniCharUTF8Format) {
        uint8_t *dstBuffer = (uint8_t *)*dst;
        uint16_t bytesToWrite = 0;
        const UTF32Char byteMask = 0xBF;
        const UTF32Char byteMark = 0x80; 
        static const uint8_t firstByteMark[7] = { 0x00, 0x00, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC };

        while (srcLength-- > 0) {
            currentChar = *(src++);

            /* Figure out how many bytes the result will require */
            if (currentChar < (UTF32Char)0x80) {
                bytesToWrite = 1;
            } else if (currentChar < (UTF32Char)0x800) {
                bytesToWrite = 2;
            } else if (currentChar < (UTF32Char)0x10000) {
                bytesToWrite = 3;
            } else if (currentChar < (UTF32Char)0x200000) {
                bytesToWrite = 4;
            } else {
                bytesToWrite = 2;
                currentChar = UNI_REPLACEMENT_CHAR;
            }

            usedLength += bytesToWrite;

            if (dstLength) {
                if (usedLength > dstLength) return false;

                dstBuffer += bytesToWrite;
                switch (bytesToWrite) {	/* note: everything falls through. */
                    case 4:	*--dstBuffer = (currentChar | byteMark) & byteMask; currentChar >>= 6;
                    CF_FALLTHROUGH;
                    case 3:	*--dstBuffer = (currentChar | byteMark) & byteMask; currentChar >>= 6;
                    CF_FALLTHROUGH;
                    case 2:	*--dstBuffer = (currentChar | byteMark) & byteMask; currentChar >>= 6;
                    CF_FALLTHROUGH;
                    case 1:	*--dstBuffer =  currentChar | firstByteMark[bytesToWrite];
                }
                dstBuffer += bytesToWrite;
            }
        }

        *dst = dstBuffer;
    } else {
        UTF32Char *dstBuffer = (UTF32Char *)*dst;

        while (srcLength-- > 0) {
            currentChar = *(src++);

            ++usedLength;
            if (dstLength) {
                if (usedLength > dstLength) return false;
                *(dstBuffer++) = currentChar;
            }
        }

        *dst = dstBuffer;
    }

    *filledLength = usedLength;

    return true;
}

