/*	
	CFLocaleInternal.h
	Copyright (c) 2008-2019, Apple Inc. and the Swift project authors
 
	Portions Copyright (c) 2014-2019, Apple Inc. and the Swift project authors
	Licensed under Apache License v2.0 with Runtime Library Exception
	See http://swift.org/LICENSE.txt for license information
	See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
 */

/*
 This file is for the use of the CoreFoundation project only.
 */

#ifndef __COREFOUNDATION_CFLOCALEINTERNAL__
#define __COREFOUNDATION_CFLOCALEINTERNAL__ 1

#include <CoreFoundation/CFString.h>

CF_EXPORT CFStringRef const kCFLocaleAlternateQuotationBeginDelimiterKey;
CF_EXPORT CFStringRef const kCFLocaleAlternateQuotationEndDelimiterKey;
CF_EXPORT CFStringRef const kCFLocaleQuotationBeginDelimiterKey;
CF_EXPORT CFStringRef const kCFLocaleQuotationEndDelimiterKey;
CF_EXPORT CFStringRef const kCFLocaleCalendarIdentifierKey; // ***
CF_EXPORT CFStringRef const kCFLocaleCalendarKey;
CF_EXPORT CFStringRef const kCFLocaleCollationIdentifierKey; // ***
CF_EXPORT CFStringRef const kCFLocaleCollatorIdentifierKey;
CF_EXPORT CFStringRef const kCFLocaleCountryCodeKey;
CF_EXPORT CFStringRef const kCFLocaleCurrencyCodeKey; // ***
CF_EXPORT CFStringRef const kCFLocaleCurrencySymbolKey;
CF_EXPORT CFStringRef const kCFLocaleDecimalSeparatorKey;
CF_EXPORT CFStringRef const kCFLocaleExemplarCharacterSetKey;
CF_EXPORT CFStringRef const kCFLocaleGroupingSeparatorKey;
CF_EXPORT CFStringRef const kCFLocaleIdentifierKey;
CF_EXPORT CFStringRef const kCFLocaleLanguageCodeKey;
CF_EXPORT CFStringRef const kCFLocaleMeasurementSystemKey;
CF_EXPORT CFStringRef const kCFLocaleTemperatureUnitKey;
CF_EXPORT CFStringRef const kCFLocaleScriptCodeKey;
CF_EXPORT CFStringRef const kCFLocaleUsesMetricSystemKey;
CF_EXPORT CFStringRef const kCFLocaleVariantCodeKey;

CF_EXPORT CFStringRef const kCFDateFormatterAMSymbolKey;
CF_EXPORT CFStringRef const kCFDateFormatterCalendarKey;
CF_EXPORT CFStringRef const kCFDateFormatterCalendarIdentifierKey;
CF_EXPORT CFStringRef const kCFDateFormatterDefaultDateKey;
CF_EXPORT CFStringRef const kCFDateFormatterDefaultFormatKey;
CF_EXPORT CFStringRef const kCFDateFormatterDoesRelativeDateFormattingKey;
CF_EXPORT CFStringRef const kCFDateFormatterEraSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterGregorianStartDateKey;
CF_EXPORT CFStringRef const kCFDateFormatterIsLenientKey;
CF_EXPORT CFStringRef const kCFDateFormatterLongEraSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterMonthSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterPMSymbolKey;
CF_EXPORT CFStringRef const kCFDateFormatterAmbiguousYearStrategyKey;
CF_EXPORT CFStringRef const kCFDateFormatterQuarterSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterShortMonthSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterShortQuarterSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterShortStandaloneMonthSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterShortStandaloneQuarterSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterShortStandaloneWeekdaySymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterShortWeekdaySymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterStandaloneMonthSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterStandaloneQuarterSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterStandaloneWeekdaySymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterTimeZoneKey;
CF_EXPORT CFStringRef const kCFDateFormatterTwoDigitStartDateKey;
CF_EXPORT CFStringRef const kCFDateFormatterVeryShortMonthSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterVeryShortStandaloneMonthSymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterVeryShortStandaloneWeekdaySymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterVeryShortWeekdaySymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterWeekdaySymbolsKey;
CF_EXPORT CFStringRef const kCFDateFormatterUsesCharacterDirectionKey;

CF_EXPORT CFStringRef const kCFNumberFormatterAlwaysShowDecimalSeparatorKey;
CF_EXPORT CFStringRef const kCFNumberFormatterCurrencyCodeKey;
CF_EXPORT CFStringRef const kCFNumberFormatterCurrencyDecimalSeparatorKey;
CF_EXPORT CFStringRef const kCFNumberFormatterCurrencyGroupingSeparatorKey;
CF_EXPORT CFStringRef const kCFNumberFormatterCurrencySymbolKey;
CF_EXPORT CFStringRef const kCFNumberFormatterDecimalSeparatorKey;
CF_EXPORT CFStringRef const kCFNumberFormatterDefaultFormatKey;
CF_EXPORT CFStringRef const kCFNumberFormatterExponentSymbolKey;
CF_EXPORT CFStringRef const kCFNumberFormatterFormatWidthKey;
CF_EXPORT CFStringRef const kCFNumberFormatterGroupingSeparatorKey;
CF_EXPORT CFStringRef const kCFNumberFormatterGroupingSizeKey;
CF_EXPORT CFStringRef const kCFNumberFormatterInfinitySymbolKey;
CF_EXPORT CFStringRef const kCFNumberFormatterInternationalCurrencySymbolKey;
CF_EXPORT CFStringRef const kCFNumberFormatterIsLenientKey;
CF_EXPORT CFStringRef const kCFNumberFormatterMaxFractionDigitsKey;
CF_EXPORT CFStringRef const kCFNumberFormatterMaxIntegerDigitsKey;
CF_EXPORT CFStringRef const kCFNumberFormatterMaxSignificantDigitsKey;
CF_EXPORT CFStringRef const kCFNumberFormatterMinFractionDigitsKey;
CF_EXPORT CFStringRef const kCFNumberFormatterMinIntegerDigitsKey;
CF_EXPORT CFStringRef const kCFNumberFormatterMinSignificantDigitsKey;
CF_EXPORT CFStringRef const kCFNumberFormatterMinusSignKey;
CF_EXPORT CFStringRef const kCFNumberFormatterMultiplierKey;
CF_EXPORT CFStringRef const kCFNumberFormatterNaNSymbolKey;
CF_EXPORT CFStringRef const kCFNumberFormatterNegativePrefixKey;
CF_EXPORT CFStringRef const kCFNumberFormatterNegativeSuffixKey;
CF_EXPORT CFStringRef const kCFNumberFormatterPaddingCharacterKey;
CF_EXPORT CFStringRef const kCFNumberFormatterPaddingPositionKey;
CF_EXPORT CFStringRef const kCFNumberFormatterPerMillSymbolKey;
CF_EXPORT CFStringRef const kCFNumberFormatterPercentSymbolKey;
CF_EXPORT CFStringRef const kCFNumberFormatterPlusSignKey;
CF_EXPORT CFStringRef const kCFNumberFormatterPositivePrefixKey;
CF_EXPORT CFStringRef const kCFNumberFormatterPositiveSuffixKey;
CF_EXPORT CFStringRef const kCFNumberFormatterRoundingIncrementKey;
CF_EXPORT CFStringRef const kCFNumberFormatterRoundingModeKey;
CF_EXPORT CFStringRef const kCFNumberFormatterSecondaryGroupingSizeKey;
CF_EXPORT CFStringRef const kCFNumberFormatterUseGroupingSeparatorKey;
CF_EXPORT CFStringRef const kCFNumberFormatterUseSignificantDigitsKey;
CF_EXPORT CFStringRef const kCFNumberFormatterZeroSymbolKey;
CF_EXPORT CFStringRef const kCFNumberFormatterUsesCharacterDirectionKey;

CF_EXPORT CFStringRef const kCFCalendarIdentifierGregorian;
CF_EXPORT CFStringRef const kCFCalendarIdentifierBuddhist;
CF_EXPORT CFStringRef const kCFCalendarIdentifierJapanese;
CF_EXPORT CFStringRef const kCFCalendarIdentifierIslamic;
CF_EXPORT CFStringRef const kCFCalendarIdentifierIslamicCivil;
CF_EXPORT CFStringRef const kCFCalendarIdentifierIslamicTabular;
CF_EXPORT CFStringRef const kCFCalendarIdentifierIslamicUmmAlQura;
CF_EXPORT CFStringRef const kCFCalendarIdentifierHebrew;
CF_EXPORT CFStringRef const kCFCalendarIdentifierChinese;
CF_EXPORT CFStringRef const kCFCalendarIdentifierRepublicOfChina;
CF_EXPORT CFStringRef const kCFCalendarIdentifierPersian;
CF_EXPORT CFStringRef const kCFCalendarIdentifierIndian;
CF_EXPORT CFStringRef const kCFCalendarIdentifierISO8601;
CF_EXPORT CFStringRef const kCFCalendarIdentifierCoptic;
CF_EXPORT CFStringRef const kCFCalendarIdentifierEthiopicAmeteMihret;
CF_EXPORT CFStringRef const kCFCalendarIdentifierEthiopicAmeteAlem;

#define LOCALE_PREFS_APPLY( F ) \
    F( AppleLanguages ); \
    F( AppleLocale ); \
    F( AppleMetricUnits ); \
    F( AppleMeasurementUnits ); \
    F( AppleTemperatureUnit ); \
    F( AppleCollationOrder ); \
    F( AppleFirstWeekday ); \
    F( AppleMinDaysInFirstWeek ); \
    F( AppleICUDateTimeSymbols ); \
    F( AppleICUForce24HourTime ); \
    F( AppleICUForce12HourTime ); \
    F( AppleICUDateFormatStrings ); \
    F( AppleICUTimeFormatStrings ); \
    F( AppleICUNumberFormatStrings ); \
    F( AppleICUNumberSymbols );
    
typedef struct {
#define DECLARE_PREF(X) CFTypeRef X;
    LOCALE_PREFS_APPLY(DECLARE_PREF);
} __CFLocalePrefs;

CF_PRIVATE __CFLocalePrefs const *__CFLocaleGetPrefs(CFLocaleRef locale);

#define __CFLocaleNonObjCGetPref(locale, key) ({ __CFLocalePrefs const * const prefs = __CFLocaleGetPrefs(locale); prefs ? prefs->key : NULL; })

#if __OBJC__
#import <Foundation/NSLocale.h>
@interface NSLocale(NSInternal)
- (id)_prefForKey:(NSString *)key;
@end

#define __CFLocaleGetPref(locale, key) ( \
    CF_IS_OBJC(CFLocaleGetTypeID(), (const void *)locale) \
        ? ((CFTypeRef(*)(CFTypeRef, SEL, CFStringRef))objc_msgSend)(locale, @selector(_prefForKey:), CFSTR(#key)) \
        : __CFLocaleNonObjCGetPref(locale, key) \
    );
#elif DEPLOYMENT_RUNTIME_SWIFT

// Do not declare this function here so that we avoid reentrancy issues between CFInternal.h defining CF_SWIFT_FUNCDISPATCHV and it importing this very header.
CF_PRIVATE CFTypeRef __CFLocaleSwiftGetPref(CFLocaleRef locale, CFStringRef key, CFTypeRef (^nonobjc)(void));

#define __CFLocaleGetPref(locale, key) \
    __CFLocaleSwiftGetPref((locale), CFSTR(#key), ^{ return __CFLocaleNonObjCGetPref(locale, key); })

#else
#define __CFLocaleGetPref(locale, key) __CFLocaleNonObjCGetPref(locale, key)
#endif

#endif // __COREFOUNDATION_CFLOCALEINTERNAL__
