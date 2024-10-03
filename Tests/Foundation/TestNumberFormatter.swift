// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


class TestNumberFormatter: XCTestCase {

    let currencySpacing = "\u{00A0}"


    func test_defaultPropertyValues() {
        let numberFormatter = NumberFormatter()
        XCTAssertEqual(numberFormatter.numberStyle, .none)
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.locale, Locale.current)
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 1)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 42)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, -1)
        XCTAssertEqual(numberFormatter.format, "#########################################0;0;#########################################0")
        XCTAssertEqual(numberFormatter.positiveFormat, "#########################################0")
        XCTAssertEqual(numberFormatter.negativeFormat, "#########################################0")
        XCTAssertNil(numberFormatter.multiplier)
        XCTAssertFalse(numberFormatter.usesGroupingSeparator)
        XCTAssertEqual(numberFormatter.groupingSize, 0)
        XCTAssertEqual(numberFormatter.secondaryGroupingSize, 0)
    }

    func test_defaultDecimalPropertyValues() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.locale, Locale.current)
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 1)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 2_000_000_000)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 3)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, -1)
        XCTAssertEqual(numberFormatter.format, "#,##0.###;0;#,##0.###")
        XCTAssertEqual(numberFormatter.positiveFormat, "#,##0.###")
        XCTAssertEqual(numberFormatter.negativeFormat, "#,##0.###")
        XCTAssertNil(numberFormatter.multiplier)
        XCTAssertTrue(numberFormatter.usesGroupingSeparator)
        XCTAssertEqual(numberFormatter.groupingSize, 3)
        XCTAssertEqual(numberFormatter.secondaryGroupingSize, 0)
    }

    func test_defaultCurrencyPropertyValues() {
        let numberFormatter = NumberFormatter()
        let currency = Locale.current.currencySymbol ?? ""
        numberFormatter.numberStyle = .currency
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.locale, Locale.current)
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 1)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 2_000_000_000)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 2)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 2)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, -1)
        XCTAssertEqual(numberFormatter.format, "¤#,##0.00;\(currency)0.00;¤#,##0.00")
        XCTAssertEqual(numberFormatter.positiveFormat, "¤#,##0.00")
        XCTAssertEqual(numberFormatter.negativeFormat, "¤#,##0.00")
        XCTAssertNil(numberFormatter.multiplier)
        XCTAssertTrue(numberFormatter.usesGroupingSeparator)
        XCTAssertEqual(numberFormatter.groupingSize, 3)
        XCTAssertEqual(numberFormatter.secondaryGroupingSize, 0)
    }

    func test_defaultPercentPropertyValues() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .percent
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.locale, Locale.current)
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 1)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 2_000_000_000)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, -1)
        XCTAssertEqual(numberFormatter.format, "#,##0%;0%;#,##0%")
        XCTAssertEqual(numberFormatter.positiveFormat, "#,##0%")
        XCTAssertEqual(numberFormatter.negativeFormat, "#,##0%")
        XCTAssertEqual(numberFormatter.multiplier, NSNumber(100))
        XCTAssertTrue(numberFormatter.usesGroupingSeparator)
        XCTAssertEqual(numberFormatter.groupingSize, 3)
        XCTAssertEqual(numberFormatter.secondaryGroupingSize, 0)
    }

    func test_defaultScientificPropertyValues() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .scientific
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.locale, Locale.current)
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 1)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 1)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, -1)
#if !DARWIN_COMPATIBILITY_TESTS
        XCTAssertEqual(numberFormatter.format, "#E0;0E0;#E0")
#else
        XCTAssertEqual(numberFormatter.format, "#E0;1E-100;#E0")
#endif
        XCTAssertEqual(numberFormatter.positiveFormat, "#E0")
        XCTAssertEqual(numberFormatter.negativeFormat, "#E0")
        XCTAssertNil(numberFormatter.multiplier)
        XCTAssertFalse(numberFormatter.usesGroupingSeparator)
        XCTAssertEqual(numberFormatter.groupingSize, 0)
        XCTAssertEqual(numberFormatter.secondaryGroupingSize, 0)
    }

    func test_defaultSpelloutPropertyValues() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .spellOut
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.locale, Locale.current)
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 0)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 0)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, 0)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, 0)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, 0)
#if !DARWIN_COMPATIBILITY_TESTS
        XCTAssertEqual(numberFormatter.format, "(null);zero;(null)")
#else
        XCTAssertEqual(numberFormatter.format, "(null);zero point zero;(null)")
#endif
        XCTAssertEqual(numberFormatter.positiveFormat, nil)
        XCTAssertEqual(numberFormatter.negativeFormat, nil)
        XCTAssertNil(numberFormatter.multiplier)
        XCTAssertFalse(numberFormatter.usesGroupingSeparator)
        XCTAssertEqual(numberFormatter.groupingSize, 0)
        XCTAssertEqual(numberFormatter.secondaryGroupingSize, 0)
    }

    func test_defaultOrdinalPropertyValues() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .ordinal
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.locale, Locale.current)
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 0)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 0)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, 0)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, 0)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, 0)
        XCTAssertEqual(numberFormatter.format, "(null);0th;(null)")
        XCTAssertEqual(numberFormatter.positiveFormat, nil)
        XCTAssertEqual(numberFormatter.negativeFormat, nil)
        XCTAssertNil(numberFormatter.multiplier)
        XCTAssertFalse(numberFormatter.usesGroupingSeparator)
        XCTAssertEqual(numberFormatter.groupingSize, 0)
        XCTAssertEqual(numberFormatter.secondaryGroupingSize, 0)
    }

    func test_defaultCurrencyISOCodePropertyValues() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currencyISOCode
        numberFormatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.locale, Locale(identifier: "en_US"))
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 1)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 2_000_000_000)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 2)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 2)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, -1)
        XCTAssertEqual(numberFormatter.format, "¤¤#,##0.00;USD\(currencySpacing)0.00;¤¤#,##0.00")
        XCTAssertEqual(numberFormatter.positiveFormat, "¤¤#,##0.00")
        XCTAssertEqual(numberFormatter.negativeFormat, "¤¤#,##0.00")
        XCTAssertNil(numberFormatter.multiplier)
        XCTAssertTrue(numberFormatter.usesGroupingSeparator)
        XCTAssertEqual(numberFormatter.groupingSize, 3)
        XCTAssertEqual(numberFormatter.secondaryGroupingSize, 0)
        XCTAssertEqual(numberFormatter.string(from: NSNumber(1234567890)), "USD\(currencySpacing)1,234,567,890.00")
    }

    func test_defaultCurrencyPluralPropertyValues() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currencyPlural
        numberFormatter.locale = Locale(identifier: "en_GB")
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.locale, Locale(identifier: "en_GB"))
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 0)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 0)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, 0)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, 0)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, 0)
        XCTAssertEqual(numberFormatter.format, "(null);0.00 British pounds;(null)")
        XCTAssertEqual(numberFormatter.positiveFormat, nil)
        XCTAssertEqual(numberFormatter.negativeFormat, nil)
        XCTAssertNil(numberFormatter.multiplier)
        XCTAssertFalse(numberFormatter.usesGroupingSeparator)
        XCTAssertEqual(numberFormatter.groupingSize, 0)
        XCTAssertEqual(numberFormatter.secondaryGroupingSize, 0)
    }

    func test_defaultCurrencyAccountingPropertyValues() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currencyAccounting
        numberFormatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 1)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 2_000_000_000)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 2)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 2)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, -1)
        XCTAssertEqual(numberFormatter.format, "¤#,##0.00;$0.00;(¤#,##0.00)")
        XCTAssertEqual(numberFormatter.positiveFormat, "¤#,##0.00")
        XCTAssertEqual(numberFormatter.negativeFormat, "(¤#,##0.00)")
        XCTAssertNil(numberFormatter.multiplier)
        XCTAssertTrue(numberFormatter.usesGroupingSeparator)
        XCTAssertEqual(numberFormatter.groupingSize, 3)
        XCTAssertEqual(numberFormatter.secondaryGroupingSize, 0)
    }

    func test_currencyCode() {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "en_GB")
        numberFormatter.numberStyle = .currency
        XCTAssertEqual(numberFormatter.format, "¤#,##0.00;£0.00;¤#,##0.00")
        XCTAssertEqual(numberFormatter.string(from: 1.1), "£1.10")
        XCTAssertEqual(numberFormatter.string(from: 0), "£0.00")
        XCTAssertEqual(numberFormatter.string(from: -1.1), "-£1.10")

        numberFormatter.currencyCode = "T"
        XCTAssertEqual(numberFormatter.currencyCode, "T")
        XCTAssertEqual(numberFormatter.currencySymbol, "£")
        XCTAssertEqual(numberFormatter.format, "¤#,##0.00;£0.00;¤#,##0.00")
        numberFormatter.currencyDecimalSeparator = "_"
        XCTAssertEqual(numberFormatter.format, "¤#,##0.00;£0_00;¤#,##0.00")

        let formattedString = numberFormatter.string(from: 42)
        XCTAssertEqual(formattedString, "£42_00")

        // Check that the currencyCode is preferred over the locale when no currencySymbol is set
        let codeFormatter = NumberFormatter()
        codeFormatter.numberStyle = .currency
        codeFormatter.locale = Locale(identifier: "en_US")
        codeFormatter.currencyCode = "GBP"
        XCTAssertEqual(codeFormatter.string(from: 3.02), "£3.02")
    }

    func test_decimalSeparator() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        XCTAssertEqual(numberFormatter.format, "#,##0.###;0;#,##0.###")

        let separator = "-"
        numberFormatter.decimalSeparator = separator
        XCTAssertEqual(numberFormatter.format, "#,##0.###;0;#,##0.###")
        XCTAssertEqual(numberFormatter.decimalSeparator, separator)

        let formattedString = numberFormatter.string(from: 42.42)
        XCTAssertEqual(formattedString, "42-42")
    }
    
    func test_currencyDecimalSeparator() {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "fr_FR")
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyDecimalSeparator = "-"
        numberFormatter.currencyCode = "T"
        XCTAssertEqual(numberFormatter.format, "#,##0.00 ¤;0-00\(currencySpacing)€;#,##0.00 ¤")
        let formattedString = numberFormatter.string(from: 42.42)
        XCTAssertEqual(formattedString, "42-42\(currencySpacing)€")
    }
    
    func test_alwaysShowDecimalSeparator() {
        let numberFormatter = NumberFormatter()
        numberFormatter.decimalSeparator = "-"
        numberFormatter.alwaysShowsDecimalSeparator = true
        XCTAssertEqual(numberFormatter.format, "#########################################0.;0-;#########################################0.")
        let formattedString = numberFormatter.string(from: 42)
        XCTAssertEqual(formattedString, "42-")
    }
    
    func test_groupingSeparator() {
        let decFormatter1 = NumberFormatter()
        XCTAssertEqual(decFormatter1.groupingSize, 0)
        decFormatter1.numberStyle = .decimal
        XCTAssertEqual(decFormatter1.groupingSize, 3)
        XCTAssertEqual(decFormatter1.format, "#,##0.###;0;#,##0.###")

        let decFormatter2 = NumberFormatter()
        XCTAssertEqual(decFormatter2.groupingSize, 0)
        decFormatter2.groupingSize = 1
        decFormatter2.numberStyle = .decimal
        XCTAssertEqual(decFormatter2.groupingSize, 1)
        XCTAssertEqual(decFormatter2.format, "#,0.###;0;#,0.###")

        let numberFormatter = NumberFormatter()
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.groupingSeparator = "_"
        XCTAssertEqual(numberFormatter.groupingSize, 0)
        XCTAssertEqual(numberFormatter.format, "#########################################0;0;#########################################0")
        numberFormatter.groupingSize = 3
        XCTAssertEqual(numberFormatter.format, "#######################################,##0;0;#######################################,##0")

        let formattedString = numberFormatter.string(from: 42_000)
        XCTAssertEqual(formattedString, "42_000")
    }
    
    func test_percentSymbol() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .percent
        numberFormatter.percentSymbol = "💯"
        XCTAssertEqual(numberFormatter.format, "#,##0%;0💯;#,##0%")

        let formattedString = numberFormatter.string(from: 0.42)
        XCTAssertEqual(formattedString, "42💯")
    }
    
    func test_zeroSymbol() {
        let numberFormatter = NumberFormatter()
        XCTAssertEqual(numberFormatter.numberStyle, .none)
        XCTAssertEqual(numberFormatter.generatesDecimalNumbers, false)
        XCTAssertEqual(numberFormatter.localizesFormat, true)
        XCTAssertEqual(numberFormatter.locale, Locale.current)
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 1)
        XCTAssertEqual(numberFormatter.maximumIntegerDigits, 42)
        XCTAssertEqual(numberFormatter.minimumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.maximumFractionDigits, 0)
        XCTAssertEqual(numberFormatter.minimumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, -1)
        XCTAssertEqual(numberFormatter.usesSignificantDigits, false)
        XCTAssertEqual(numberFormatter.formatWidth, -1)
        XCTAssertEqual(numberFormatter.format, "#########################################0;0;#########################################0")
        numberFormatter.zeroSymbol = "⚽️"
        XCTAssertEqual(numberFormatter.format, "#########################################0;⚽️;#########################################0")

        let formattedString = numberFormatter.string(from: 0)
        XCTAssertEqual(formattedString, "⚽️")
    }
    var unknownZero: Int = 0
    
    func test_notANumberSymbol() {
        let numberFormatter = NumberFormatter()
        numberFormatter.notANumberSymbol = "👽"
        XCTAssertEqual(numberFormatter.format, "#########################################0;0;#########################################0")
        let number: Double = -42
        let numberObject = NSNumber(value: sqrt(number))
        let formattedString = numberFormatter.string(from: numberObject)
        XCTAssertEqual(formattedString, "👽")
    }
    
    func test_positiveInfinitySymbol() {
        let numberFormatter = NumberFormatter()
        numberFormatter.positiveInfinitySymbol = "🚀"
        XCTAssertEqual(numberFormatter.format, "#########################################0;0;#########################################0")

        let numberObject = NSNumber(value: Double(42.0) / Double(0))
        let formattedString = numberFormatter.string(from: numberObject)
        XCTAssertEqual(formattedString, "🚀")
    }
    
    func test_minusSignSymbol() {
        let numberFormatter = NumberFormatter()
        numberFormatter.minusSign = "👎"
        XCTAssertEqual(numberFormatter.format, "#########################################0;0;#########################################0")
        let formattedString = numberFormatter.string(from: -42)
        XCTAssertEqual(formattedString, "👎42")
    }
    
    func test_plusSignSymbol() {
        // ex. 1.0E+1 in scientific notation
        let numberFormatter = NumberFormatter()
        let format = "#E+0"
        numberFormatter.format = format
        XCTAssertEqual(numberFormatter.positiveFormat, "#E+0")
        XCTAssertEqual(numberFormatter.negativeFormat, "-#E+0")
#if !DARWIN_COMPATIBILITY_TESTS
        XCTAssertEqual(numberFormatter.zeroSymbol, "0E+0")
        XCTAssertEqual(numberFormatter.format, "#E+0;0E+0;-#E+0")
        XCTAssertEqual(numberFormatter.string(from: 0), "0E+0")
#else
        XCTAssertEqual(numberFormatter.zeroSymbol, "1E-100")
        XCTAssertEqual(numberFormatter.format, "#E+0;1E-100;-#E+0")
        XCTAssertEqual(numberFormatter.string(from: 0), "1E-100")
#endif
        XCTAssertEqual(numberFormatter.plusSign, "+")
        let sign = "👍"
        numberFormatter.plusSign = sign
        XCTAssertEqual(numberFormatter.plusSign, sign)

        let formattedString = numberFormatter.string(from: 420000000000000000)
        XCTAssertNotNil(formattedString)
        XCTAssertEqual(formattedString, "4.2E👍17")

        // Verify a negative exponent does not have the 👍
        let noPlusString = numberFormatter.string(from: -0.420)
        XCTAssertNotNil(noPlusString)
        if let fmt = noPlusString {
            let contains: Bool = fmt.contains(sign)
            XCTAssertFalse(contains, "Expected format of -0.420 (-4.2E-1) shouldn't have a plus sign which was set as \(sign)")
        }
    }

    func test_currencySymbol() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencySymbol = "🍯"
        numberFormatter.currencyDecimalSeparator = "_"
        XCTAssertEqual(numberFormatter.format, "¤#,##0.00;🍯0_00;¤#,##0.00")
        let formattedString = numberFormatter.string(from: 42)
        XCTAssertEqual(formattedString, "🍯42_00")
    }
    
    func test_exponentSymbol() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .scientific
        numberFormatter.exponentSymbol = "⬆️"
#if DARWIN_COMPATIBILITY_TESTS
        XCTAssertEqual(numberFormatter.format, "#E0;1⬆️-100;#E0")
#else
        XCTAssertEqual(numberFormatter.format, "#E0;0⬆️0;#E0")
#endif
        let formattedString = numberFormatter.string(from: 42)
        XCTAssertEqual(formattedString, "4.2⬆️1")
    }
    
    func test_decimalMinimumIntegerDigits() {
        let numberFormatter1 = NumberFormatter()
        XCTAssertEqual(numberFormatter1.minimumIntegerDigits, 1)
        numberFormatter1.minimumIntegerDigits = 3
        numberFormatter1.numberStyle = .decimal
        XCTAssertEqual(numberFormatter1.minimumIntegerDigits, 3)
        XCTAssertEqual(numberFormatter1.format, "#,000.###;000;#,000.###")

        let numberFormatter = NumberFormatter()
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 1)
        numberFormatter.numberStyle = .decimal
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 1)
        numberFormatter.minimumIntegerDigits = 3
        XCTAssertEqual(numberFormatter.format, "#,000.###;000;#,000.###")
        var formattedString = numberFormatter.string(from: 0)
        XCTAssertEqual(formattedString, "000")

        numberFormatter.numberStyle = .decimal
        XCTAssertEqual(numberFormatter.minimumIntegerDigits, 3)
        XCTAssertEqual(numberFormatter.format, "#,000.###;000;#,000.###")
        formattedString = numberFormatter.string(from: 0.1)
        XCTAssertEqual(formattedString, "000.1")
    }

    func test_currencyMinimumIntegerDigits() {
        // If .minimumIntegerDigits is set to 0 before .numberStyle change, preserve the value
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        XCTAssertEqual(formatter.minimumIntegerDigits, 1)
        formatter.minimumIntegerDigits = 0
        formatter.numberStyle = .currency
        XCTAssertEqual(formatter.format, "¤#,###.00;£.00;¤#,###.00")
        XCTAssertEqual(formatter.minimumIntegerDigits, 0)
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter.format, "¤#,###.00;$.00;¤#,###.00")
        XCTAssertEqual(formatter.string(from: 0), "$.00")
        XCTAssertEqual(formatter.string(from: 1.23), "$1.23")
        XCTAssertEqual(formatter.string(from: 123.4), "$123.40")

        // If .minimumIntegerDigits is not set before .numberStyle change, update the value
        let formatter2 = NumberFormatter()
        formatter2.locale = Locale(identifier: "en_GB")
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.numberStyle = .currency
        XCTAssertEqual(formatter2.format, "¤#,##0.00;£0.00;¤#,##0.00")
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter2.string(from: 0.001), "$0.00")
        XCTAssertEqual(formatter2.string(from: 1.234), "$1.23")
        XCTAssertEqual(formatter2.string(from: 123456.7), "$123,456.70")
    }

    func test_percentMinimumIntegerDigits() {
        // If .minimumIntegerDigits is set to 0 before .numberStyle change, preserve the value
        let formatter = NumberFormatter()
        XCTAssertEqual(formatter.minimumIntegerDigits, 1)
        formatter.minimumIntegerDigits = 0
        formatter.numberStyle = .percent
        XCTAssertEqual(formatter.minimumIntegerDigits, 0)
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter.string(from: 0), "0%")
        XCTAssertEqual(formatter.string(from: 1.234), "123%")
        XCTAssertEqual(formatter.string(from: 123.4), "12,340%")

        // If .minimumIntegerDigits is not set before .numberStyle change, update the value
        let formatter2 = NumberFormatter()
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.numberStyle = .percent
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter2.string(from: 0.01), "1%")
        XCTAssertEqual(formatter2.string(from: 1.234), "123%")
        XCTAssertEqual(formatter2.string(from: 123456.7), "12,345,670%")
    }

    func test_scientificMinimumIntegerDigits() {
        // If .minimumIntegerDigits is set to 0 before .numberStyle change, preserve the value
        let formatter = NumberFormatter()
        XCTAssertEqual(formatter.minimumIntegerDigits, 1)
        formatter.minimumIntegerDigits = 0
        formatter.numberStyle = .scientific
        XCTAssertEqual(formatter.minimumIntegerDigits, 0)
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter.string(from: 0), "0E0")
        XCTAssertEqual(formatter.string(from: 1.23), "1.23E0")
        XCTAssertEqual(formatter.string(from: 123.4), "1.234E2")

        // If .minimumIntegerDigits is not set before .numberStyle change, update the value
        let formatter2 = NumberFormatter()
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.numberStyle = .scientific
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter2.string(from: 0.01), "1E-2")
        XCTAssertEqual(formatter2.string(from: 1.234), "1.234E0")
        XCTAssertEqual(formatter2.string(from: 123456.7), "1.234567E5")
    }

    func test_spellOutMinimumIntegerDigits() {
        // If .minimumIntegerDigits is set to 0 before .numberStyle change, preserve the value
        let formatter = NumberFormatter()
        XCTAssertEqual(formatter.minimumIntegerDigits, 1)
        formatter.minimumIntegerDigits = 0
        formatter.numberStyle = .spellOut
        XCTAssertEqual(formatter.minimumIntegerDigits, 0)
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter.string(from: 0), "zero")
        XCTAssertEqual(formatter.string(from: 1.23), "one point two three")
        XCTAssertEqual(formatter.string(from: 123.4), "one hundred twenty-three point four")

        // If .minimumIntegerDigits is not set before .numberStyle change, update the value
        let formatter2 = NumberFormatter()
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.numberStyle = .spellOut
        XCTAssertEqual(formatter2.minimumIntegerDigits, 0)
        formatter2.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter2.string(from: 0.01), "zero point zero one")
        XCTAssertEqual(formatter2.string(from: 1.234), "one point two three four")
        XCTAssertEqual(formatter2.string(from: 123456.7), "one hundred twenty-three thousand four hundred fifty-six point seven")
    }

    func test_ordinalMinimumIntegerDigits() {
        // If .minimumIntegerDigits is set to 0 before .numberStyle change, preserve the value
        let formatter = NumberFormatter()
        XCTAssertEqual(formatter.minimumIntegerDigits, 1)
        formatter.minimumIntegerDigits = 0
        formatter.numberStyle = .ordinal
        XCTAssertEqual(formatter.minimumIntegerDigits, 0)
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter.string(from: 0), "0th")
        XCTAssertEqual(formatter.string(from: 1.23), "1st")
        XCTAssertEqual(formatter.string(from: 123.4), "123rd")

        // If .minimumIntegerDigits is not set before .numberStyle change, update the value
        let formatter2 = NumberFormatter()
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.numberStyle = .ordinal
        XCTAssertEqual(formatter2.minimumIntegerDigits, 0)
        formatter2.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter2.string(from: 0.01), "0th")
        XCTAssertEqual(formatter2.string(from: 4.234), "4th")
        XCTAssertEqual(formatter2.string(from: 42), "42nd")
    }

    func test_currencyPluralMinimumIntegerDigits() {
        // If .minimumIntegerDigits is set to 0 before .numberStyle change, preserve the value
        let formatter = NumberFormatter()
        XCTAssertEqual(formatter.minimumIntegerDigits, 1)
        formatter.minimumIntegerDigits = 0
        formatter.numberStyle = .currencyPlural
        XCTAssertEqual(formatter.minimumIntegerDigits, 0)
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter.string(from: 0), "0.00 US dollars")
        XCTAssertEqual(formatter.string(from: 1.23), "1.23 US dollars")
        XCTAssertEqual(formatter.string(from: 123.4), "123.40 US dollars")

        // If .minimumIntegerDigits is not set before .numberStyle change, update the value
        let formatter2 = NumberFormatter()
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.numberStyle = .currencyPlural
        XCTAssertEqual(formatter2.minimumIntegerDigits, 0)
        formatter2.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter2.string(from: 0.01), "0.01 US dollars")
        XCTAssertEqual(formatter2.string(from: 1.234), "1.23 US dollars")
        XCTAssertEqual(formatter2.string(from: 123456.7), "123,456.70 US dollars")
    }

    func test_currencyISOCodeMinimumIntegerDigits() {
        // If .minimumIntegerDigits is set to 0 before .numberStyle change, preserve the value
        let formatter = NumberFormatter()
        XCTAssertEqual(formatter.minimumIntegerDigits, 1)
        formatter.minimumIntegerDigits = 0
        formatter.numberStyle = .currencyISOCode
        XCTAssertEqual(formatter.minimumIntegerDigits, 0)
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter.string(from: 0), "USD.00")
        XCTAssertEqual(formatter.string(from: 1.23), "USD\(currencySpacing)1.23")
        XCTAssertEqual(formatter.string(from: 123.4), "USD\(currencySpacing)123.40")

        // If .minimumIntegerDigits is not set before .numberStyle change, update the value
        let formatter2 = NumberFormatter()
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.numberStyle = .currencyISOCode
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter2.string(from: 0.01), "USD\(currencySpacing)0.01")
        XCTAssertEqual(formatter2.string(from: 1.234), "USD\(currencySpacing)1.23")
        XCTAssertEqual(formatter2.string(from: 123456.7), "USD\(currencySpacing)123,456.70")
    }

    func test_currencyAccountingMinimumIntegerDigits() {
        // If .minimumIntegerDigits is set to 0 before .numberStyle change, preserve the value
        let formatter = NumberFormatter()
        XCTAssertEqual(formatter.minimumIntegerDigits, 1)
        formatter.minimumIntegerDigits = 0
        formatter.numberStyle = .currencyAccounting
        XCTAssertEqual(formatter.minimumIntegerDigits, 0)
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter.string(from: 0), "$.00")
        XCTAssertEqual(formatter.string(from: 1.23), "$1.23")
        XCTAssertEqual(formatter.string(from: 123.4), "$123.40")

        // If .minimumIntegerDigits is not set before .numberStyle change, update the value
        let formatter2 = NumberFormatter()
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.numberStyle = .currencyAccounting
        XCTAssertEqual(formatter2.minimumIntegerDigits, 1)
        formatter2.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter2.string(from: 0), "$0.00")
        XCTAssertEqual(formatter2.string(from: 1.23), "$1.23")
        XCTAssertEqual(formatter2.string(from: 123.4), "$123.40")
    }

    func test_maximumIntegerDigits() {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumIntegerDigits = 3
        numberFormatter.minimumIntegerDigits = 3
        let formattedString = numberFormatter.string(from: 1_000)
        XCTAssertEqual(formattedString, "000")
    }
    
    func test_minimumFractionDigits() {
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 3
        numberFormatter.decimalSeparator = "-"
        let formattedString = numberFormatter.string(from: 42)
        XCTAssertEqual(formattedString, "42-000")
    }
    
    func test_maximumFractionDigits() {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 3
        numberFormatter.decimalSeparator = "-"
        let formattedString = numberFormatter.string(from: 42.4242)
        XCTAssertEqual(formattedString, "42-424")
    }
    
    func test_groupingSize() {
        let numberFormatter = NumberFormatter()
        XCTAssertEqual(numberFormatter.groupingSize, 0)
        numberFormatter.groupingSize = 4
        numberFormatter.groupingSeparator = "_"
        numberFormatter.usesGroupingSeparator = true
        let formattedString = numberFormatter.string(from: 42_000)
        XCTAssertEqual(formattedString, "4_2000")
    }
    
    func test_secondaryGroupingSize() {
        let numberFormatter = NumberFormatter()
        numberFormatter.groupingSize = 3
        numberFormatter.secondaryGroupingSize = 2
        numberFormatter.groupingSeparator = "_"
        numberFormatter.usesGroupingSeparator = true
        let formattedString = numberFormatter.string(from: 42_000_000)
        XCTAssertEqual(formattedString, "4_20_00_000")
    }
    
    func test_roundingMode() {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 0
        numberFormatter.roundingMode = .ceiling
        let formattedString = numberFormatter.string(from: 41.0001)
        XCTAssertEqual(formattedString, "42")
    }
    
    func test_roundingIncrement() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.roundingIncrement = 0.2
        let formattedString = numberFormatter.string(from: 4.25)
        XCTAssertEqual(formattedString, "4.2")
    }
    
    func test_formatWidth() {
        let numberFormatter = NumberFormatter()
        numberFormatter.paddingCharacter = "_"
        numberFormatter.formatWidth = 5
        let formattedString = numberFormatter.string(from: 42)
        XCTAssertEqual(formattedString, "___42")
    }
    
    func test_formatPosition() {
        let numberFormatter = NumberFormatter()
        numberFormatter.paddingCharacter = "_"
        numberFormatter.formatWidth = 5
        numberFormatter.paddingPosition = .afterPrefix
        let formattedString = numberFormatter.string(from: -42)
        XCTAssertEqual(formattedString, "-__42")
    }
    
    func test_multiplier() {
        let numberFormatter = NumberFormatter()
        numberFormatter.multiplier = 2
        let formattedString = numberFormatter.string(from: 21)
        XCTAssertEqual(formattedString, "42")
    }
    
    func test_positivePrefix() {
        let numberFormatter = NumberFormatter()
        numberFormatter.positivePrefix = "👍"
        let formattedString = numberFormatter.string(from: 42)
        XCTAssertEqual(formattedString, "👍42")
    }
    
    func test_positiveSuffix() {
        let numberFormatter = NumberFormatter()
        numberFormatter.positiveSuffix = "👍"
        let formattedString = numberFormatter.string(from: 42)
        XCTAssertEqual(formattedString, "42👍")
    }
    
    func test_negativePrefix() {
        let numberFormatter = NumberFormatter()
        numberFormatter.negativePrefix = "👎"
        let formattedString = numberFormatter.string(from: -42)
        XCTAssertEqual(formattedString, "👎42")
    }
    
    func test_negativeSuffix() {
        let numberFormatter = NumberFormatter()
        numberFormatter.negativeSuffix = "👎"
        let formattedString = numberFormatter.string(from: -42)
        XCTAssertEqual(formattedString, "-42👎")
    }
    
    func test_internationalCurrencySymbol() {
        // What does internationalCurrencySymbol actually do?
#if false
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currencyPlural
        numberFormatter.internationalCurrencySymbol = "💵"
        numberFormatter.currencyDecimalSeparator = "_"
        let formattedString = numberFormatter.string(from: 42)
        XCTAssertEqual(formattedString, "💵42_00")
#endif
    }
    
    func test_currencyGroupingSeparator() {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "en_GB")
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyGroupingSeparator = "_"
        numberFormatter.currencyCode = "T"
        numberFormatter.currencyDecimalSeparator = "/"
        let formattedString = numberFormatter.string(from: 42_000)
        XCTAssertEqual(formattedString, "£42_000/00")

    }

    func test_lenient() {
        let numberFormatter = NumberFormatter()
        // Not lenient by default
        XCTAssertFalse(numberFormatter.isLenient)

        // Lenient allows wrong style -- not lenient here
        numberFormatter.numberStyle = .spellOut
        XCTAssertEqual(numberFormatter.numberStyle, .spellOut)
//        let nilNumber = numberFormatter.number(from: "2.22")
        // FIXME: Not nil on Linux?
        //XCTAssertNil(nilNumber)
        // Lenient allows wrong style
        numberFormatter.isLenient = true
        XCTAssertTrue(numberFormatter.isLenient)
        let number = numberFormatter.number(from: "2.22")
        XCTAssertEqual(number, 2.22)

        // TODO: Add some tests with currency after [SR-250] resolved
        numberFormatter.numberStyle = .currency
        numberFormatter.isLenient = false
        let nilNumberBeforeLenient = numberFormatter.number(from: "42")

        XCTAssertNil(nilNumberBeforeLenient)
        numberFormatter.isLenient = true
        let numberAfterLenient = numberFormatter.number(from: "42.42")
        XCTAssertEqual(numberAfterLenient, 42.42)
    }
    
    func test_minimumSignificantDigits() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, -1)
        numberFormatter.minimumSignificantDigits = 3
        XCTAssertEqual(numberFormatter.maximumSignificantDigits, 999)
        let formattedString = numberFormatter.string(from: 42)
        XCTAssertEqual(formattedString, "42.0")
    }
    
    func test_maximumSignificantDigits() {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        var formattedString = numberFormatter.string(from: 987654321)
        XCTAssertEqual(formattedString, "987,654,321")
        
        numberFormatter.usesSignificantDigits = true
        numberFormatter.maximumSignificantDigits = 3
        formattedString = numberFormatter.string(from: 42.42424242)
        XCTAssertEqual(formattedString, "42.4")
    }

    func test_stringFor() {
        let numberFormatter = NumberFormatter()
        XCTAssertEqual(numberFormatter.string(for: 10)!, "10")
        XCTAssertEqual(numberFormatter.string(for: 3.14285714285714)!, "3")
        XCTAssertEqual(numberFormatter.string(for: true)!, "1")
        XCTAssertEqual(numberFormatter.string(for: false)!, "0")
        XCTAssertNil(numberFormatter.string(for: [1,2]))
        XCTAssertEqual(numberFormatter.string(for: NSNumber(value: 99.1))!, "99")
        XCTAssertNil(numberFormatter.string(for: "NaN"))
        XCTAssertNil(numberFormatter.string(for: NSString(string: "NaN")))

        numberFormatter.numberStyle = .spellOut
        XCTAssertEqual(numberFormatter.string(for: 234), "two hundred thirty-four")
        XCTAssertEqual(numberFormatter.string(for: 2007), "two thousand seven")
        XCTAssertEqual(numberFormatter.string(for: 3), "three")
        XCTAssertEqual(numberFormatter.string(for: 0.3), "zero point three")

        numberFormatter.numberStyle = .decimal
        XCTAssertEqual(numberFormatter.string(for: 234.5678), "234.568")
        
        numberFormatter.locale = Locale(identifier: "zh_CN")
        numberFormatter.numberStyle = .spellOut
        XCTAssertEqual(numberFormatter.string(from: 11.4), "十一点四")

        numberFormatter.locale = Locale(identifier: "fr_FR")
        numberFormatter.numberStyle = .spellOut
        XCTAssertEqual(numberFormatter.string(from: 11.4), "onze virgule quatre")

    }

    func test_numberFrom() {
        let numberFormatter = NumberFormatter()
        XCTAssertEqual(numberFormatter.number(from: "10"), 10)
        XCTAssertEqual(numberFormatter.number(from: "3.14"), 3.14)
        XCTAssertEqual(numberFormatter.number(from: "0.01"), 0.01)
        XCTAssertEqual(numberFormatter.number(from: ".01"), 0.01)

        // These don't work unless lenient/style set
        numberFormatter.numberStyle = .decimal
        XCTAssertEqual(numberFormatter.number(from: "1,001"), 1001)
        XCTAssertEqual(numberFormatter.number(from: "1,050,001"), 1050001)

        numberFormatter.numberStyle = .spellOut
        XCTAssertEqual(numberFormatter.number(from: "two thousand and seven"), 2007)
        XCTAssertEqual(numberFormatter.number(from: "one point zero"), 1.0)
        XCTAssertEqual(numberFormatter.number(from: "one hundred million"), 1E8)

        numberFormatter.locale = Locale(identifier: "zh_CN")
        numberFormatter.numberStyle = .spellOut
        XCTAssertEqual(numberFormatter.number(from: "十一点四"), 11.4)

        numberFormatter.locale = Locale(identifier: "fr_FR")
        numberFormatter.numberStyle = .spellOut
        XCTAssertEqual(numberFormatter.number(from: "onze virgule quatre"), 11.4)
    }

    func test_en_US_initialValues() {
        // Symbols should be extractable
        // At one point, none of this passed!

        let numberFormatter = NumberFormatter();
        numberFormatter.locale = Locale(identifier: "en_US")

        // TODO: Check if this is true for all versions...
        XCTAssertEqual(numberFormatter.format, "#########################################0;0;#########################################0")

        XCTAssertEqual(numberFormatter.plusSign, "+")
        XCTAssertEqual(numberFormatter.minusSign, "-")
        XCTAssertEqual(numberFormatter.decimalSeparator, ".")
        XCTAssertEqual(numberFormatter.groupingSeparator, ",")
        XCTAssertEqual(numberFormatter.nilSymbol, "")
        XCTAssertEqual(numberFormatter.notANumberSymbol, "NaN")
        XCTAssertEqual(numberFormatter.positiveInfinitySymbol, "+∞")
        XCTAssertEqual(numberFormatter.negativeInfinitySymbol, "-∞")
        XCTAssertEqual(numberFormatter.positivePrefix, "")
        XCTAssertEqual(numberFormatter.negativePrefix, "-")
        XCTAssertEqual(numberFormatter.positiveSuffix, "")
        XCTAssertEqual(numberFormatter.negativeSuffix, "")
        XCTAssertEqual(numberFormatter.percentSymbol, "%")
        XCTAssertEqual(numberFormatter.perMillSymbol, "‰")
        XCTAssertEqual(numberFormatter.exponentSymbol, "E")
        XCTAssertEqual(numberFormatter.groupingSeparator, ",")
        XCTAssertEqual(numberFormatter.paddingCharacter, " ")
        XCTAssertEqual(numberFormatter.currencyCode, "USD")
        XCTAssertEqual(numberFormatter.currencySymbol, "$")
        XCTAssertEqual(numberFormatter.currencyDecimalSeparator, ".")
        XCTAssertEqual(numberFormatter.currencyGroupingSeparator, ",")
        XCTAssertEqual(numberFormatter.internationalCurrencySymbol, "USD")
        XCTAssertNil(numberFormatter.zeroSymbol)
    }

    func test_pt_BR_initialValues() {
        let numberFormatter = NumberFormatter();
        numberFormatter.locale = Locale(identifier: "pt_BR")

        XCTAssertEqual(numberFormatter.format, "#########################################0;0;#########################################0")
        XCTAssertEqual(numberFormatter.plusSign, "+")
        XCTAssertEqual(numberFormatter.minusSign, "-")
        XCTAssertEqual(numberFormatter.decimalSeparator, ",")
        XCTAssertEqual(numberFormatter.groupingSeparator, ".")
        XCTAssertEqual(numberFormatter.nilSymbol, "")
        XCTAssertEqual(numberFormatter.notANumberSymbol, "NaN")
        XCTAssertEqual(numberFormatter.positiveInfinitySymbol, "+∞")
        XCTAssertEqual(numberFormatter.negativeInfinitySymbol, "-∞")
        XCTAssertEqual(numberFormatter.positivePrefix, "")
        XCTAssertEqual(numberFormatter.negativePrefix, "-")
        XCTAssertEqual(numberFormatter.positiveSuffix, "")
        XCTAssertEqual(numberFormatter.negativeSuffix, "")
        XCTAssertEqual(numberFormatter.percentSymbol, "%")
        XCTAssertEqual(numberFormatter.perMillSymbol, "‰")
        XCTAssertEqual(numberFormatter.exponentSymbol, "E")
        XCTAssertEqual(numberFormatter.groupingSeparator, ".")
        XCTAssertEqual(numberFormatter.paddingCharacter, " ")
        XCTAssertEqual(numberFormatter.currencyCode, "BRL")
        XCTAssertEqual(numberFormatter.currencySymbol, "R$")
        XCTAssertEqual(numberFormatter.currencyDecimalSeparator, ",")
        XCTAssertEqual(numberFormatter.currencyGroupingSeparator, ".")
        XCTAssertEqual(numberFormatter.internationalCurrencySymbol, "BRL")
        XCTAssertNil(numberFormatter.zeroSymbol)
    }

    func test_changingLocale() {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "fr_FR")

        XCTAssertEqual(numberFormatter.currencyCode, "EUR")
        XCTAssertEqual(numberFormatter.currencySymbol, "€")
        numberFormatter.currencySymbol = "E"
        XCTAssertEqual(numberFormatter.currencySymbol, "E")

        numberFormatter.locale = Locale(identifier: "fr_FR")
        XCTAssertEqual(numberFormatter.currencySymbol, "E")

        numberFormatter.locale = Locale(identifier: "en_GB")

        XCTAssertEqual(numberFormatter.currencyCode, "GBP")
        XCTAssertEqual(numberFormatter.currencySymbol, "E")
        numberFormatter.currencySymbol = nil
        XCTAssertEqual(numberFormatter.currencySymbol, "£")
    }

    func test_settingFormat() {
        let formatter = NumberFormatter()

        XCTAssertEqual(formatter.format, "#########################################0;0;#########################################0")
        XCTAssertEqual(formatter.positiveFormat, "#########################################0")
        XCTAssertEqual(formatter.zeroSymbol, nil)
        XCTAssertEqual(formatter.negativeFormat, "#########################################0")

        formatter.positiveFormat = "#"
        XCTAssertEqual(formatter.format, "#;0;0")
        XCTAssertEqual(formatter.positiveFormat, "#")
        XCTAssertEqual(formatter.zeroSymbol, nil)
        XCTAssertEqual(formatter.negativeFormat, "0")

        formatter.positiveFormat = "##.##"
        XCTAssertEqual(formatter.format, "##.##;0;0.##")
        XCTAssertEqual(formatter.positiveFormat, "##.##")
        XCTAssertEqual(formatter.zeroSymbol, nil)
        XCTAssertEqual(formatter.negativeFormat, "0.##")

        formatter.positiveFormat = "##;##"
        XCTAssertEqual(formatter.format, "##;##;0;0")
        XCTAssertEqual(formatter.positiveFormat, "##;##")
        XCTAssertEqual(formatter.zeroSymbol, nil)
        XCTAssertEqual(formatter.negativeFormat, "0")

        formatter.positiveFormat = "+#.#########"
        XCTAssertEqual(formatter.format, "+#.#########;+0;+0.#########")
        XCTAssertEqual(formatter.positiveFormat, "+#.#########")
        XCTAssertEqual(formatter.zeroSymbol, nil)
        XCTAssertEqual(formatter.negativeFormat, "+0.#########")

        formatter.negativeFormat = "-#.#########"
        XCTAssertEqual(formatter.format, "+#.#########;+0;-#.#########")
        XCTAssertEqual(formatter.positiveFormat, "+#.#########")
        XCTAssertEqual(formatter.zeroSymbol, nil)
        XCTAssertEqual(formatter.negativeFormat, "-#.#########")

        formatter.format = "+++#;000;---#.##"
        XCTAssertEqual(formatter.format, "+++#;000;---#.##")
        XCTAssertEqual(formatter.positiveFormat, "+++#")
        XCTAssertEqual(formatter.zeroSymbol, "000")
        XCTAssertEqual(formatter.negativeFormat, "---#.##")

        formatter.positiveFormat = nil
        XCTAssertEqual(formatter.positiveFormat, "0")
        XCTAssertEqual(formatter.format, "0;000;---#.##")

        formatter.zeroSymbol = "00"
        formatter.positiveFormat = "+++#.#"
        XCTAssertEqual(formatter.format, "+++#.#;00;---#.##")
        XCTAssertEqual(formatter.positiveFormat, "+++#.#")
        XCTAssertEqual(formatter.zeroSymbol, "00")
        XCTAssertEqual(formatter.negativeFormat, "---#.##")

        formatter.negativeFormat = "---#.#"
        XCTAssertEqual(formatter.format, "+++#.#;00;---#.#")
        XCTAssertEqual(formatter.positiveFormat, "+++#.#")
        XCTAssertEqual(formatter.zeroSymbol, "00")
        XCTAssertEqual(formatter.negativeFormat, "---#.#")

        // Test setting only first 2 parts
        formatter.format = "+##.##;0.00"
#if !DARWIN_COMPATIBILITY_TESTS
        XCTAssertEqual(formatter.format, "+##.##;00;0.00")
        XCTAssertEqual(formatter.zeroSymbol, "00")
#else
        XCTAssertEqual(formatter.format, "+##.##;+0;0.00")
        XCTAssertEqual(formatter.zeroSymbol, "+0")
#endif
        XCTAssertEqual(formatter.positiveFormat, "+##.##")
        XCTAssertEqual(formatter.negativeFormat, "0.00")

        formatter.format = "+##.##;+0;0.00"
        XCTAssertEqual(formatter.format, "+##.##;+0;0.00")
        XCTAssertEqual(formatter.positiveFormat, "+##.##")
        XCTAssertEqual(formatter.zeroSymbol, "+0")
        XCTAssertEqual(formatter.negativeFormat, "0.00")

        formatter.format = "#;0;#"
        formatter.positiveFormat = "1"
        XCTAssertEqual(formatter.format, "1;0;#")
        XCTAssertEqual(formatter.positiveFormat, "1")
        XCTAssertEqual(formatter.zeroSymbol, "0")
        XCTAssertEqual(formatter.negativeFormat, "#")

        formatter.format = "1"
        XCTAssertEqual(formatter.format, "1;0;-1")
        XCTAssertEqual(formatter.positiveFormat, "1")
        XCTAssertEqual(formatter.zeroSymbol, "0")
        XCTAssertEqual(formatter.negativeFormat, "-1")

        formatter.format = "1;2;3"
        XCTAssertEqual(formatter.format, "1;2;3")
        XCTAssertEqual(formatter.positiveFormat, "1")
        XCTAssertEqual(formatter.zeroSymbol, "2")
        XCTAssertEqual(formatter.negativeFormat, "3")

        formatter.format = ""
        XCTAssertEqual(formatter.format, ";0;-")
        XCTAssertEqual(formatter.zeroSymbol, "0")
        XCTAssertEqual(formatter.positiveFormat, "")
        XCTAssertEqual(formatter.negativeFormat, "-")
    }

    func test_usingFormat() {
        var formatter = NumberFormatter()

        formatter.format = "+++#.#;00;-+-#.#"
        XCTAssertEqual(formatter.string(from: 1), "+++1")
        XCTAssertEqual(formatter.string(from: Int.max as NSNumber), "+++9223372036854775807")
        XCTAssertEqual(formatter.string(from: 0), "00")
        XCTAssertEqual(formatter.string(from: -1), "-+-1")
        XCTAssertEqual(formatter.string(from: Int.min as NSNumber), "-+-9223372036854775808")


        formatter.format = "+#.##;0.00;-#.##"
        XCTAssertEqual(formatter.string(from: 0.5), "+0.5")
        XCTAssertEqual(formatter.string(from: 0), "0.00")
        XCTAssertEqual(formatter.string(from: -0.2), "-0.2")

        formatter.positiveFormat = "#.##"
        formatter.negativeFormat = "-#.##"
        XCTAssertEqual(formatter.string(from: NSNumber(value: Double.pi)), "3.14")
        XCTAssertEqual(formatter.string(from: NSNumber(value: -Double.pi)), "-3.14")

        formatter = NumberFormatter()
        formatter.negativeFormat = "--#.##"
        XCTAssertEqual(formatter.string(from: NSNumber(value: -Double.pi)), "--3")
        formatter.positiveFormat = "#.###"
        XCTAssertEqual(formatter.string(from: NSNumber(value: Double.pi)), "3.142")

        formatter.positiveFormat = "#.####"
        XCTAssertEqual(formatter.string(from: NSNumber(value: Double.pi)), "3.1416")

        formatter.positiveFormat = "#.#####"
        XCTAssertEqual(formatter.string(from: NSNumber(value: Double.pi)), "3.14159")

        formatter = NumberFormatter()
        formatter.positiveFormat = "#.#########"
        formatter.negativeFormat = "#.#########"
        XCTAssertEqual(formatter.string(from: NSNumber(value: 0.5)), "0.5")
        XCTAssertEqual(formatter.string(from: NSNumber(value: -0.5)), "0.5")
        formatter.negativeFormat = "-#.#########"
        XCTAssertEqual(formatter.string(from: NSNumber(value: -0.5)), "-0.5")
    }

    func test_propertyChanges() {
        let formatter = NumberFormatter()
        XCTAssertNil(formatter.multiplier)
        formatter.numberStyle = .percent
        XCTAssertEqual(formatter.multiplier, NSNumber(100))
        formatter.numberStyle = .decimal
        XCTAssertNil(formatter.multiplier)
        formatter.multiplier = NSNumber(1)
        formatter.numberStyle = .percent
        XCTAssertEqual(formatter.multiplier, NSNumber(1))
        formatter.multiplier = NSNumber(27)
        formatter.numberStyle = .decimal
        XCTAssertEqual(formatter.multiplier, NSNumber(27))
    }

    func test_scientificStrings() {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle = .scientific
        formatter.positiveInfinitySymbol = ".inf"
        formatter.negativeInfinitySymbol = "-.inf"
        formatter.notANumberSymbol = ".nan"
        XCTAssertEqual(formatter.string(for: Double.infinity), ".inf")
        XCTAssertEqual(formatter.string(for: -1 * Double.infinity), "-.inf")
        XCTAssertEqual(formatter.string(for: Double.nan), ".nan")
#if (arch(i386) || arch(x86_64)) && !(os(Android) || os(Windows))
        XCTAssertNil(formatter.string(for: Float80.infinity))
#endif
    }

    func test_copy() throws {
        let original = NumberFormatter()
        let copied = try XCTUnwrap(original.copy() as? NumberFormatter)
        XCTAssertFalse(original === copied)

        func __assert<T>(_ property: KeyPath<NumberFormatter, T>,
                         original expectedValueOfOriginalFormatter: T,
                         copy expectedValueOfCopiedFormatter: T,
                         file: StaticString = #file,
                         line: UInt = #line) where T: Equatable {
            XCTAssertEqual(original[keyPath: property], expectedValueOfOriginalFormatter,
                           "Unexpected value in `original`.", file: file, line: line)
            XCTAssertEqual(copied[keyPath: property], expectedValueOfCopiedFormatter,
                           "Unexpected value in `copied`.", file: file, line: line)
        }

        copied.numberStyle = .decimal
        __assert(\.numberStyle, original: .none, copy: .decimal)
        __assert(\.maximumIntegerDigits, original: 42, copy: 2_000_000_000)
        __assert(\.maximumFractionDigits, original: 0, copy: 3)
        __assert(\.groupingSize, original: 0, copy: 3)

        original.numberStyle = .percent
        original.percentSymbol = "％"
        __assert(\.numberStyle, original: .percent, copy: .decimal)
        __assert(\.format, original: "#,##0%;0％;#,##0%", copy: "#,##0.###;0;#,##0.###")
    }
}
