// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016, 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation

extension NumberFormatter {
    public enum Style : UInt {
        case none               = 0
        case decimal            = 1
        case currency           = 2
        case percent            = 3
        case scientific         = 4
        case spellOut           = 5
        case ordinal            = 6
        case currencyISOCode    = 8     // 7 is not used
        case currencyPlural     = 9
        case currencyAccounting = 10
    }

    public enum PadPosition : UInt {
        case beforePrefix
        case afterPrefix
        case beforeSuffix
        case afterSuffix
    }

    public enum RoundingMode : UInt {
        case ceiling
        case floor
        case down
        case up
        case halfEven
        case halfDown
        case halfUp
    }
}

open class NumberFormatter : Formatter {

    typealias CFType = CFNumberFormatter
    private final var _currentCfFormatter: CFType?
    private final var _cfFormatter: CFType {
        if let obj = _currentCfFormatter {
            return obj
        } else {
            let numberStyle = CFNumberFormatterStyle(rawValue: CFIndex(self.numberStyle.rawValue))!

            let obj = CFNumberFormatterCreate(kCFAllocatorSystemDefault, locale._cfObject, numberStyle)!
            _setFormatterAttributes(obj)
            if _positiveFormat != nil  || _negativeFormat != nil {
                var format = _positiveFormat ?? "#"
                if let negative = _negativeFormat {
                    format.append(";")
                    format.append(negative)
                }
                CFNumberFormatterSetFormat(obj, format._cfObject)
            }
            _currentCfFormatter = obj
            return obj
        }
    }

    open override func copy(with zone: NSZone? = nil) -> Any {
        let copied = NumberFormatter()

        func __copy<T>(_ keyPath: ReferenceWritableKeyPath<NumberFormatter, T>) {
            copied[keyPath: keyPath] = self[keyPath: keyPath]
        }

        func __copy<T>(_ keyPath: ReferenceWritableKeyPath<NumberFormatter, T>) where T: NSCopying {
            copied[keyPath: keyPath] = self[keyPath: keyPath].copy(with: zone) as! T
        }

        func __copy<T>(_ keyPath: ReferenceWritableKeyPath<NumberFormatter, T?>) where T: NSCopying {
            copied[keyPath: keyPath] = self[keyPath: keyPath]?.copy(with: zone) as! T?
        }

        __copy(\.formattingContext)
        __copy(\._numberStyle)
        __copy(\._locale)
        __copy(\._generatesDecimalNumbers)
        __copy(\._textAttributesForNegativeValues)
        __copy(\._textAttributesForPositiveValues)
        __copy(\._allowsFloats)
        __copy(\._decimalSeparator)
        __copy(\._alwaysShowsDecimalSeparator)
        __copy(\._currencyDecimalSeparator)
        __copy(\._usesGroupingSeparator)
        __copy(\._groupingSeparator)
        __copy(\._zeroSymbol)
        __copy(\._textAttributesForZero)
        __copy(\._nilSymbol)
        __copy(\._textAttributesForNil)
        __copy(\._notANumberSymbol)
        __copy(\._textAttributesForNotANumber)
        __copy(\._positiveInfinitySymbol)
        __copy(\._textAttributesForPositiveInfinity)
        __copy(\._negativeInfinitySymbol)
        __copy(\._textAttributesForNegativeInfinity)
        __copy(\._positivePrefix)
        __copy(\._positiveSuffix)
        __copy(\._negativePrefix)
        __copy(\._negativeSuffix)
        __copy(\._currencyCode)
        __copy(\._currencySymbol)
        __copy(\._internationalCurrencySymbol)
        __copy(\._percentSymbol)
        __copy(\._perMillSymbol)
        __copy(\._minusSign)
        __copy(\._plusSign)
        __copy(\._exponentSymbol)
        __copy(\._groupingSize)
        __copy(\._secondaryGroupingSize)
        __copy(\._multiplier)
        __copy(\._formatWidth)
        __copy(\._paddingCharacter)
        __copy(\._paddingPosition)
        __copy(\._roundingMode)
        __copy(\._roundingIncrement)
        __copy(\._minimumIntegerDigits)
        __copy(\._maximumIntegerDigits)
        __copy(\._minimumFractionDigits)
        __copy(\._maximumFractionDigits)
        __copy(\._minimum)
        __copy(\._maximum)
        __copy(\._currencyGroupingSeparator)
        __copy(\._lenient)
        __copy(\._usesSignificantDigits)
        __copy(\._minimumSignificantDigits)
        __copy(\._maximumSignificantDigits)
        __copy(\._partialStringValidationEnabled)
        __copy(\._hasThousandSeparators)
        __copy(\._thousandSeparator)
        __copy(\._localizesFormat)
        __copy(\._positiveFormat)
        __copy(\._negativeFormat)
        __copy(\._attributedStringForZero)
        __copy(\._attributedStringForNotANumber)
        __copy(\._roundingBehavior)

        return copied
    }

    // this is for NSUnitFormatter

    open var formattingContext: Context = .unknown // default is NSFormattingContextUnknown

    @available(*, unavailable, renamed: "number(from:)")
    func getObjectValue(_ obj: UnsafeMutablePointer<AnyObject?>?,
                        for string: String,
                        range rangep: UnsafeMutablePointer<NSRange>?) throws {
        NSUnsupported()
    }

    open override func string(for obj: Any) -> String? {
        //we need to allow Swift's numeric types here - Int, Double et al.
        guard let number = __SwiftValue.store(obj) as? NSNumber else { return nil }
        return string(from: number)
    }

    // Even though NumberFormatter responds to the usual Formatter methods,
    //   here are some convenience methods which are a little more obvious.
    open func string(from number: NSNumber) -> String? {
        return CFNumberFormatterCreateStringWithNumber(kCFAllocatorSystemDefault, _cfFormatter, number._cfObject)._swiftObject
    }

    open func number(from string: String) -> NSNumber? {
        var range = CFRange(location: 0, length: string.length)
        let number = withUnsafeMutablePointer(to: &range) { (rangePointer: UnsafeMutablePointer<CFRange>) -> NSNumber? in

            let parseOption = allowsFloats ? 0 : CFNumberFormatterOptionFlags.parseIntegersOnly.rawValue
            let result = CFNumberFormatterCreateNumberFromString(kCFAllocatorSystemDefault, _cfFormatter, string._cfObject, rangePointer, parseOption)

            return result?._nsObject
        }
        return number
    }

    open class func localizedString(from num: NSNumber, number nstyle: Style) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = nstyle
        return numberFormatter.string(for: num)!
    }

    private func _reset() {
        _currentCfFormatter = nil
    }

    private final func _setFormatterAttributes(_ formatter: CFNumberFormatter) {
        if numberStyle == .currency {
            // Prefer currencySymbol, then currencyCode then locale.currencySymbol
            if let symbol = _currencySymbol {
                _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterCurrencySymbol, value: symbol._cfObject)
            } else if let code = _currencyCode, code.count == 3 {
                _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterCurrencyCode, value: code._cfObject)
            } else {
                _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterCurrencySymbol, value: locale.currencySymbol?._cfObject)
            }
       }
       if numberStyle == .currencyISOCode {
          let code = _currencyCode ?? _currencySymbol ?? locale.currencyCode ?? locale.currencySymbol
           _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterCurrencyCode, value: code?._cfObject)
        }
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterDecimalSeparator, value: _decimalSeparator?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterCurrencyDecimalSeparator, value: _currencyDecimalSeparator?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterAlwaysShowDecimalSeparator, value: _alwaysShowsDecimalSeparator._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterGroupingSeparator, value: _groupingSeparator?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterUseGroupingSeparator, value: usesGroupingSeparator._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterPercentSymbol, value: _percentSymbol?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterZeroSymbol, value: _zeroSymbol?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterNaNSymbol, value: _notANumberSymbol?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterInfinitySymbol, value: _positiveInfinitySymbol._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterMinusSign, value: _minusSign?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterPlusSign, value: _plusSign?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterExponentSymbol, value: _exponentSymbol?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterMinIntegerDigits, value: _minimumIntegerDigits?._bridgeToObjectiveC()._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterMaxIntegerDigits, value: _maximumIntegerDigits?._bridgeToObjectiveC()._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterMinFractionDigits, value: _minimumFractionDigits?._bridgeToObjectiveC()._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterMaxFractionDigits, value: maximumFractionDigits._bridgeToObjectiveC()._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterGroupingSize, value: groupingSize._bridgeToObjectiveC()._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterSecondaryGroupingSize, value: _secondaryGroupingSize._bridgeToObjectiveC()._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterRoundingMode, value: _roundingMode.rawValue._bridgeToObjectiveC()._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterRoundingIncrement, value: _roundingIncrement?._cfObject)

        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterFormatWidth, value: _formatWidth?._bridgeToObjectiveC()._cfObject)
        if self.formatWidth > 0 {
            _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterPaddingCharacter, value: _paddingCharacter?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterPaddingPosition, value: _paddingPosition.rawValue._bridgeToObjectiveC()._cfObject)
        } else {
           _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterPaddingCharacter, value: ""._cfObject)
        }
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterMultiplier, value: multiplier?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterPositivePrefix, value: _positivePrefix?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterPositiveSuffix, value: _positiveSuffix?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterNegativePrefix, value: _negativePrefix?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterNegativeSuffix, value: _negativeSuffix?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterPerMillSymbol, value: _percentSymbol?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterInternationalCurrencySymbol, value: _internationalCurrencySymbol?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterCurrencyGroupingSeparator, value: _currencyGroupingSeparator?._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterIsLenient, value: _lenient._cfObject)
        _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterUseSignificantDigits, value: usesSignificantDigits._cfObject)
        if usesSignificantDigits {
            _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterMinSignificantDigits, value: minimumSignificantDigits._bridgeToObjectiveC()._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFNumberFormatterMaxSignificantDigits, value: maximumSignificantDigits._bridgeToObjectiveC()._cfObject)
        }
    }

    private final func _setFormatterAttribute(_ formatter: CFNumberFormatter, attributeName: CFString, value: AnyObject?) {
        if let value = value {
            CFNumberFormatterSetProperty(formatter, attributeName, value)
        }
    }

    private final func _getFormatterAttribute(_ formatter: CFNumberFormatter, attributeName: CFString) -> String? {
        return CFNumberFormatterCopyProperty(formatter, attributeName) as? String
    }

    // Attributes of a NumberFormatter. Many attributes have default values but if they are set by the caller
    // the new value needs to be retained even if the .numberStyle is changed. Attributes are backed by an optional
    // to indicate to use the default value (if nil) or the caller-supplied value (if not nil).
    private func defaultMinimumIntegerDigits() -> Int {
        switch numberStyle {
        case .ordinal, .spellOut, .currencyPlural:
            return 0

        case .none, .currency, .currencyISOCode, .currencyAccounting, .decimal, .percent, .scientific:
            return 1
        }
    }

    private func defaultMaximumIntegerDigits() -> Int {
        switch numberStyle {
        case .none:
            return 42

        case .ordinal, .spellOut, .currencyPlural:
            return 0

        case .currency, .currencyISOCode, .currencyAccounting, .decimal, .percent:
            return 2_000_000_000

        case .scientific:
            return 1
        }
    }

    private func defaultMinimumFractionDigits() -> Int {
        switch numberStyle {
        case .none, .ordinal, .spellOut, .currencyPlural, .decimal, .percent, .scientific:
            return 0

        case .currency, .currencyISOCode, .currencyAccounting:
            return 2
        }
    }

    private func defaultMaximumFractionDigits() -> Int {
        switch numberStyle {
        case .none, .ordinal, .spellOut, .currencyPlural, .percent, .scientific:
            return 0

        case .currency, .currencyISOCode, .currencyAccounting:
            return 2

        case .decimal:
            return 3
        }
    }

    private func defaultMinimumSignificantDigits() -> Int {
        switch numberStyle {
        case .ordinal, .spellOut, .currencyPlural:
            return 0

        case .currency, .none, .currencyISOCode, .currencyAccounting, .decimal, .percent, .scientific:
            return -1
        }
    }

    private func defaultMaximumSignificantDigits() -> Int {
        switch numberStyle {
        case .none, .currency, .currencyISOCode, .currencyAccounting, .decimal, .percent, .scientific:
            return -1

        case .ordinal, .spellOut, .currencyPlural:
            return 0
        }
    }

    private func defaultUsesGroupingSeparator() -> Bool {
        switch numberStyle {
        case .none, .scientific, .spellOut, .ordinal, .currencyPlural:
            return false

        case .decimal, .currency, .percent, .currencyAccounting, .currencyISOCode:
            return true
        }
    }

    private func defaultGroupingSize() -> Int {
        switch numberStyle {
        case .none, .ordinal, .spellOut, .currencyPlural, .scientific:
            return 0

        case .currency, .currencyISOCode, .currencyAccounting, .decimal, .percent:
            return 3
        }
    }

    private func defaultMultiplier() -> NSNumber? {
        switch numberStyle {
        case .percent:  return NSNumber(100)
        default:        return nil
        }
    }

    private func defaultFormatWidth() -> Int {
        switch numberStyle {
        case .ordinal, .spellOut, .currencyPlural:
            return 0

        case .none, .decimal, .currency, .percent, .scientific, .currencyISOCode, .currencyAccounting:
            return -1
        }
    }

    private var _numberStyle: Style = .none
    open var numberStyle: Style {
        get {
            return _numberStyle
        }

        set {
            _reset()
            _numberStyle = newValue
        }
    }

    private var _locale: Locale = Locale.current
    /*@NSCopying*/ open var locale: Locale! {
        get {
            return _locale
        }
        set {
            _reset()
            _locale = newValue
        }
    }

    private var _generatesDecimalNumbers: Bool = false
    open var generatesDecimalNumbers: Bool {
        get {
            return _generatesDecimalNumbers
        }
        set {
            _reset()
            _generatesDecimalNumbers = newValue
        }
    }

    private var _textAttributesForNegativeValues: [String : Any]?
    open var textAttributesForNegativeValues: [String : Any]? {
        get {
            return _textAttributesForNegativeValues
        }
        set {
            _reset()
            _textAttributesForNegativeValues = newValue
        }
    }

    private var _textAttributesForPositiveValues: [String : Any]?
    open var textAttributesForPositiveValues: [String : Any]? {
        get {
            return _textAttributesForPositiveValues
        }
        set {
            _reset()
            _textAttributesForPositiveValues = newValue
        }
    }

    private var _allowsFloats: Bool = true
    open var allowsFloats: Bool {
        get {
            return _allowsFloats
        }
        set {
            _reset()
            _allowsFloats = newValue
        }
    }

    private var _decimalSeparator: String!
    open var decimalSeparator: String! {
        get {
            return _decimalSeparator ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterDecimalSeparator)
        }
        set {
            _reset()
            _decimalSeparator = newValue
        }
    }

    private var _alwaysShowsDecimalSeparator: Bool = false
    open var alwaysShowsDecimalSeparator: Bool {
        get {
            return _alwaysShowsDecimalSeparator
        }
        set {
            _reset()
            _alwaysShowsDecimalSeparator = newValue
        }
    }

    private var _currencyDecimalSeparator: String!
    open var currencyDecimalSeparator: String! {
        get {
            return _currencyDecimalSeparator ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterCurrencyDecimalSeparator)
        }
        set {
            _reset()
            _currencyDecimalSeparator = newValue
        }
    }

    private var _usesGroupingSeparator: Bool?
    open var usesGroupingSeparator: Bool {
        get {
            return _usesGroupingSeparator ?? defaultUsesGroupingSeparator()
        }
        set {
            _reset()
            _usesGroupingSeparator = newValue
        }
    }

    private var _groupingSeparator: String!
    open var groupingSeparator: String! {
        get {
            return _groupingSeparator ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterGroupingSeparator)
        }
        set {
            _reset()
            _groupingSeparator = newValue
        }
    }

    private var _zeroSymbol: String?
    open var zeroSymbol: String? {
        get {
            return _zeroSymbol
        }
        set {
            _reset()
            _zeroSymbol = newValue
        }
    }

    private var _textAttributesForZero: [String : Any]?
    open var textAttributesForZero: [String : Any]? {
        get {
            return _textAttributesForZero
        }
        set {
            _reset()
            _textAttributesForZero = newValue
        }
    }

    private var _nilSymbol: String = ""
    open var nilSymbol: String {
        get {
            return _nilSymbol
        }
        set {
            _reset()
            _nilSymbol = newValue
        }
    }

    private var _textAttributesForNil: [String : Any]?
    open var textAttributesForNil: [String : Any]? {
        get {
            return _textAttributesForNil
        }
        set {
            _reset()
            _textAttributesForNil = newValue
        }
    }

    private var _notANumberSymbol: String!
    open var notANumberSymbol: String! {
        get {
            return _notANumberSymbol ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterNaNSymbol)
        }
        set {
            _reset()
            _notANumberSymbol = newValue
        }
    }

    private var _textAttributesForNotANumber: [String : Any]?
    open var textAttributesForNotANumber: [String : Any]? {
        get {
            return _textAttributesForNotANumber
        }
        set {
            _reset()
            _textAttributesForNotANumber = newValue
        }
    }

    private var _positiveInfinitySymbol: String = "+∞"
    open var positiveInfinitySymbol: String {
        get {
            return _positiveInfinitySymbol
        }
        set {
            _reset()
            _positiveInfinitySymbol = newValue
        }
    }

    private var _textAttributesForPositiveInfinity: [String : Any]?
    open var textAttributesForPositiveInfinity: [String : Any]? {
        get {
            return _textAttributesForPositiveInfinity
        }
        set {
            _reset()
            _textAttributesForPositiveInfinity = newValue
        }
    }

    private var _negativeInfinitySymbol: String = "-∞"
    open var negativeInfinitySymbol: String {
        get {
            return _negativeInfinitySymbol
        }
        set {
            _reset()
            _negativeInfinitySymbol = newValue
        }
    }

    private var _textAttributesForNegativeInfinity: [String : Any]?
    open var textAttributesForNegativeInfinity: [String : Any]? {
        get {
            return _textAttributesForNegativeInfinity
        }
        set {
            _reset()
            _textAttributesForNegativeInfinity = newValue
        }
    }

    private var _positivePrefix: String!
    open var positivePrefix: String! {
        get {
            return _positivePrefix ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterPositivePrefix)
        }
        set {
            _reset()
            _positivePrefix = newValue
        }
    }

    private var _positiveSuffix: String!
    open var positiveSuffix: String! {
        get {
            return _positiveSuffix ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterPositiveSuffix)
        }
        set {
            _reset()
            _positiveSuffix = newValue
        }
    }

    private var _negativePrefix: String!
    open var negativePrefix: String! {
        get {
            return _negativePrefix ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterNegativePrefix)
        }
        set {
            _reset()
            _negativePrefix = newValue
        }
    }

    private var _negativeSuffix: String!
    open var negativeSuffix: String! {
        get {
            return _negativeSuffix ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterNegativeSuffix)
        }
        set {
            _reset()
            _negativeSuffix = newValue
        }
    }

    private var _currencyCode: String!
    open var currencyCode: String! {
        get {
            return _currencyCode ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterCurrencyCode)
        }
        set {
            _reset()
            _currencyCode = newValue
        }
    }

    private var _currencySymbol: String!
    open var currencySymbol: String! {
        get {
            return _currencySymbol ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterCurrencySymbol)
        }
        set {
            _reset()
            _currencySymbol = newValue
        }
    }

    private var _internationalCurrencySymbol: String!
    open var internationalCurrencySymbol: String! {
        get {
            return _internationalCurrencySymbol ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterInternationalCurrencySymbol)
        }
        set {
            _reset()
            _internationalCurrencySymbol = newValue
        }
    }

    private var _percentSymbol: String!
    open var percentSymbol: String! {
        get {
            return _percentSymbol ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterPercentSymbol) ?? "%"
        }
        set {
            _reset()
            _percentSymbol = newValue
        }
    }

    private var _perMillSymbol: String!
    open var perMillSymbol: String! {
        get {
            return _perMillSymbol ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterPerMillSymbol)
        }
        set {
            _reset()
            _perMillSymbol = newValue
        }
    }

    private var _minusSign: String!
    open var minusSign: String! {
        get {
            return _minusSign ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterMinusSign)
        }
        set {
            _reset()
            _minusSign = newValue
        }
    }

    private var _plusSign: String!
    open var plusSign: String! {
        get {
            return _plusSign ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterPlusSign)
        }
        set {
            _reset()
            _plusSign = newValue
        }
    }

    private var _exponentSymbol: String!
    open var exponentSymbol: String! {
        get {
            return _exponentSymbol ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterExponentSymbol)
        }
        set {
            _reset()
            _exponentSymbol = newValue
        }
    }

    private var _groupingSize: Int?
    open var groupingSize: Int {
        get {
            return _groupingSize ?? defaultGroupingSize()
        }
        set {
            _reset()
            _groupingSize = newValue
        }
    }

    private var _secondaryGroupingSize: Int = 0
    open var secondaryGroupingSize: Int {
        get {
            return _secondaryGroupingSize
        }
        set {
            _reset()
            _secondaryGroupingSize = newValue
        }
    }

    private var _multiplier: NSNumber?
    /*@NSCopying*/ open var multiplier: NSNumber? {
        get {
            return _multiplier ?? defaultMultiplier()
        }
        set {
            _reset()
            _multiplier = newValue
        }
    }

    private var _formatWidth: Int?
    open var formatWidth: Int {
        get {
            return _formatWidth ?? defaultFormatWidth()
        }
        set {
            _reset()
            _formatWidth = newValue
        }
    }

    private var _paddingCharacter: String! = " "
    open var paddingCharacter: String! {
        get {
            return _paddingCharacter ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterPaddingCharacter)
        }
        set {
            _reset()
            _paddingCharacter = newValue
        }
    }

    private var _paddingPosition: PadPosition = .beforePrefix
    open var paddingPosition: PadPosition {
        get {
            return _paddingPosition
        }
        set {
            _reset()
            _paddingPosition = newValue
        }
    }

    private var _roundingMode: RoundingMode = .halfEven
    open var roundingMode: RoundingMode {
        get {
            return _roundingMode
        }
        set {
            _reset()
            _roundingMode = newValue
        }
    }

    private var _roundingIncrement: NSNumber! = 0
    /*@NSCopying*/ open var roundingIncrement: NSNumber! {
        get {
            return _roundingIncrement
        }
        set {
            _reset()
            _roundingIncrement = newValue
        }
    }

    // Use an optional for _minimumIntegerDigits to track if the value is
    // set BEFORE the .numberStyle is changed. This allows preserving a setting
    // of 0.
    private var _minimumIntegerDigits: Int?
    open var minimumIntegerDigits: Int {
        get {
            return _minimumIntegerDigits ?? defaultMinimumIntegerDigits()
        }
        set {
            _reset()
            _minimumIntegerDigits = newValue
        }
    }

    private var _maximumIntegerDigits: Int?
    open var maximumIntegerDigits: Int {
        get {
            return _maximumIntegerDigits ?? defaultMaximumIntegerDigits()
        }
        set {
            _reset()
            _maximumIntegerDigits = newValue
        }
    }

    private var _minimumFractionDigits: Int?
    open var minimumFractionDigits: Int {
        get {
            return _minimumFractionDigits ?? defaultMinimumFractionDigits()
        }
        set {
            _reset()
            _minimumFractionDigits = newValue
        }
    }

    private var _maximumFractionDigits: Int?
    open var maximumFractionDigits: Int {
        get {
            return _maximumFractionDigits ?? defaultMaximumFractionDigits()
        }
        set {
            _reset()
            _maximumFractionDigits = newValue
        }
    }

    private var _minimum: NSNumber?
    /*@NSCopying*/ open var minimum: NSNumber? {
        get {
            return _minimum
        }
        set {
            _reset()
            _minimum = newValue
        }
    }

    private var _maximum: NSNumber?
    /*@NSCopying*/ open var maximum: NSNumber? {
        get {
            return _maximum
        }
        set {
            _reset()
            _maximum = newValue
        }
    }

    private var _currencyGroupingSeparator: String!
    open var currencyGroupingSeparator: String! {
        get {
            return _currencyGroupingSeparator ?? _getFormatterAttribute(_cfFormatter, attributeName: kCFNumberFormatterCurrencyGroupingSeparator)
        }
        set {
            _reset()
            _currencyGroupingSeparator = newValue
        }
    }

    private var _lenient: Bool = false
    open var isLenient: Bool {
        get {
            return _lenient
        }
        set {
            _reset()
            _lenient = newValue
        }
    }

    private var _usesSignificantDigits: Bool?
    open var usesSignificantDigits: Bool {
        get {
            return _usesSignificantDigits ?? false
        }
        set {
            _reset()
            _usesSignificantDigits = newValue
        }
    }

    private var _minimumSignificantDigits: Int?
    open var minimumSignificantDigits: Int {
        get {
            return _minimumSignificantDigits ?? defaultMinimumSignificantDigits()
        }
        set {
            _reset()
            _usesSignificantDigits = true
            _minimumSignificantDigits = newValue
            if _maximumSignificantDigits == nil && newValue > defaultMinimumSignificantDigits() {
                _maximumSignificantDigits = (newValue < 1000) ? 999 : newValue
            }
        }
    }

    private var _maximumSignificantDigits: Int?
    open var maximumSignificantDigits: Int {
        get {
            return _maximumSignificantDigits ?? defaultMaximumSignificantDigits()
        }
        set {
            _reset()
            _usesSignificantDigits = true
            _maximumSignificantDigits = newValue
        }
    }

    private var _partialStringValidationEnabled: Bool = false
    open var isPartialStringValidationEnabled: Bool {
        get {
            return _partialStringValidationEnabled
        }
        set {
            _reset()
            _partialStringValidationEnabled = newValue
        }
    }

    private var _hasThousandSeparators: Bool = false
    open var hasThousandSeparators: Bool {
        get {
            return _hasThousandSeparators
        }
        set {
            _reset()
            _hasThousandSeparators = newValue
        }
    }

    private var _thousandSeparator: String!
    open var thousandSeparator: String! {
        get {
            return _thousandSeparator
        }
        set {
            _reset()
            _thousandSeparator = newValue
        }
    }

    private var _localizesFormat: Bool = true
    open var localizesFormat: Bool {
        get {
            return _localizesFormat
        }
        set {
            _reset()
            _localizesFormat = newValue
        }
    }

    private func getFormatterComponents() -> (String?, String?) {
        guard let format = CFNumberFormatterGetFormat(_cfFormatter)?._swiftObject else {
            return (nil, nil)
        }
        let components = format.components(separatedBy: ";")
        let positive = _positiveFormat ?? components.first ?? "#"
        let negative = _negativeFormat ?? components.last ?? "#"
        return (positive, negative)
    }

    private func getZeroFormat() -> String {
        return string(from: 0) ?? "0"
    }

    open var format: String {
        get {
            let (p, n) = getFormatterComponents()
            let z = _zeroSymbol ?? getZeroFormat()
            return "\(p ?? "(null)");\(z);\(n ?? "(null)")"
        }
        set {
            // Special case empty string
            if newValue == "" {
                _positiveFormat = ""
                _negativeFormat = "-"
                _zeroSymbol = "0"
                _reset()
            } else {
                let components = newValue.components(separatedBy: ";")
                let count = components.count
                guard count <= 3 else { return }
                _reset()

                _positiveFormat = components.first ?? ""
                if count == 1 {
                    _negativeFormat = "-\(_positiveFormat ?? "")"
                }
                else if count == 2 {
                    _negativeFormat = components[1]
                    _zeroSymbol = getZeroFormat()
                }
                else if count == 3 {
                    _zeroSymbol = components[1]
                    _negativeFormat = components[2]
                }

                if _negativeFormat == nil {
                    _negativeFormat = getFormatterComponents().1
                }

                if _zeroSymbol == nil {
                    _zeroSymbol = getZeroFormat()
                }
            }
        }
    }

    private var _positiveFormat: String!
    open var positiveFormat: String! {
        get {
            return getFormatterComponents().0
        }
        set {
            _reset()
            _positiveFormat = newValue
        }
    }

    private var _negativeFormat: String!
    open var negativeFormat: String! {
        get {
            return getFormatterComponents().1
        }
        set {
            _reset()
            _negativeFormat = newValue
        }
    }

    private var _attributedStringForZero: NSAttributedString = NSAttributedString(string: "0")
    /*@NSCopying*/ open var attributedStringForZero: NSAttributedString {
        get {
            return _attributedStringForZero
        }
        set {
            _reset()
            _attributedStringForZero = newValue
        }
    }

    private var _attributedStringForNil: NSAttributedString = NSAttributedString(string: "")
    /*@NSCopying*/ open var attributedStringForNil: NSAttributedString {
        get {
            return _attributedStringForNil
        }
        set {
            _reset()
            _attributedStringForNil = newValue
        }
    }

    private var _attributedStringForNotANumber: NSAttributedString = NSAttributedString(string: "NaN")
    /*@NSCopying*/ open var attributedStringForNotANumber: NSAttributedString {
        get {
            return _attributedStringForNotANumber
        }
        set {
            _reset()
            _attributedStringForNotANumber = newValue
        }
    }

    private var _roundingBehavior: NSDecimalNumberHandler = NSDecimalNumberHandler.default
    /*@NSCopying*/ open var roundingBehavior: NSDecimalNumberHandler {
        get {
            return _roundingBehavior
        }
        set {
            _reset()
            _roundingBehavior = newValue
        }
    }
}
