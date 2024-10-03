// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation
@_spi(SwiftCorelibsFoundation) import FoundationEssentials
internal import Synchronization

open class DateFormatter : Formatter, @unchecked Sendable {
    private let _lock: Mutex<State> = .init(.init())

    public override init() {
        super.init()
    }

    private convenience init(state: consuming sending State) {
        self.init()
        
        // work around issue that state needs to be reinitialized after consuming
        struct Wrapper : ~Copyable, @unchecked Sendable {
            var value: State? = nil
        }
        var w = Wrapper(value: consume state)
        
        _lock.withLock {
            $0 = w.value.take()!
        }
    }

    open override func copy(with zone: NSZone? = nil) -> Any {
        return _lock.withLock { state in
            // Zone is not Sendable, so just ignore it here
            let copy = state.copy()
            return DateFormatter(state: copy)
        }
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    struct State : ~Copyable {
        class Box {
            var formatter: CFDateFormatter?
            init() {}
        }
        
        private var _formatter = Box()
        
        func copy(with zone: NSZone? = nil) -> sending State {
            var copied = State()

            copied.formattingContext = formattingContext
            copied.dateStyle = dateStyle
            copied.timeStyle = timeStyle
            copied._locale = _locale
            copied.generatesCalendarDates = generatesCalendarDates
            copied._timeZone = _timeZone
            copied._calendar = _calendar
            copied.isLenient = isLenient
            copied._twoDigitStartDate = _twoDigitStartDate
            copied._eraSymbols = _eraSymbols
            copied._monthSymbols = _monthSymbols
            copied._shortMonthSymbols = _shortMonthSymbols
            copied._weekdaySymbols = _weekdaySymbols
            copied._shortWeekdaySymbols = _shortWeekdaySymbols
            copied._amSymbol = _amSymbol
            copied._pmSymbol = _pmSymbol
            copied._longEraSymbols = _longEraSymbols
            copied._veryShortMonthSymbols = _veryShortMonthSymbols
            copied._standaloneMonthSymbols = _standaloneMonthSymbols
            copied._shortStandaloneMonthSymbols = _shortStandaloneMonthSymbols
            copied._veryShortStandaloneMonthSymbols = _veryShortStandaloneMonthSymbols
            copied._veryShortWeekdaySymbols = _veryShortWeekdaySymbols
            copied._standaloneWeekdaySymbols = _standaloneWeekdaySymbols
            copied._shortStandaloneWeekdaySymbols = _shortStandaloneWeekdaySymbols
            copied._veryShortStandaloneWeekdaySymbols = _veryShortStandaloneWeekdaySymbols
            copied._quarterSymbols = _quarterSymbols
            copied._shortQuarterSymbols = _shortQuarterSymbols
            copied._standaloneQuarterSymbols = _standaloneQuarterSymbols
            copied._shortStandaloneQuarterSymbols = _shortStandaloneQuarterSymbols
            copied._gregorianStartDate = _gregorianStartDate
            copied.doesRelativeDateFormatting = doesRelativeDateFormatting

            // The last is `_dateFormat` because setting `dateStyle` and `timeStyle` make it `nil`.
            copied._dateFormat = _dateFormat

            return copied
        }
        
        func formatter() -> CFDateFormatter {
            guard let obj = _formatter.formatter else {
                let dateStyle = CFDateFormatterStyle(rawValue: CFIndex(dateStyle.rawValue))!
                let timeStyle = CFDateFormatterStyle(rawValue: CFIndex(timeStyle.rawValue))!

                let obj = CFDateFormatterCreate(kCFAllocatorSystemDefault, locale._cfObject, dateStyle, timeStyle)!
                _setFormatterAttributes(obj)
                if let dateFormat = _dateFormat {
                    CFDateFormatterSetFormat(obj, dateFormat._cfObject)
                }
                _formatter.formatter = obj
                return obj
            }
            return obj
        }
        
        private mutating func _reset() {
            _formatter.formatter = nil
        }
        
        // MARK: -
        
        var formattingContext: Context = .unknown // default is NSFormattingContextUnknown

        internal func _setFormatterAttributes(_ formatter: CFDateFormatter) {
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterIsLenient, value: isLenient._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterTimeZone, value: _timeZone?._cfObject)
            if let ident = _calendar?.identifier {
                _setFormatterAttribute(formatter, attributeName: kCFDateFormatterCalendarName, value: ident._cfCalendarIdentifier._cfObject)
            } else {
                _setFormatterAttribute(formatter, attributeName: kCFDateFormatterCalendarName, value: nil)
            }
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterTwoDigitStartDate, value: _twoDigitStartDate?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterDefaultDate, value: defaultDate?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterCalendar, value: _calendar?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterEraSymbols, value: _eraSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterMonthSymbols, value: _monthSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterShortMonthSymbols, value: _shortMonthSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterWeekdaySymbols, value: _weekdaySymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterShortWeekdaySymbols, value: _shortWeekdaySymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterAMSymbol, value: _amSymbol?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterPMSymbol, value: _pmSymbol?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterLongEraSymbols, value: _longEraSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterVeryShortMonthSymbols, value: _veryShortMonthSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterStandaloneMonthSymbols, value: _standaloneMonthSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterShortStandaloneMonthSymbols, value: _shortStandaloneMonthSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterVeryShortStandaloneMonthSymbols, value: _veryShortStandaloneMonthSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterVeryShortWeekdaySymbols, value: _veryShortWeekdaySymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterStandaloneWeekdaySymbols, value: _standaloneWeekdaySymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterShortStandaloneWeekdaySymbols, value: _shortStandaloneWeekdaySymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterVeryShortStandaloneWeekdaySymbols, value: _veryShortStandaloneWeekdaySymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterQuarterSymbols, value: _quarterSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterShortQuarterSymbols, value: _shortQuarterSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterStandaloneQuarterSymbols, value: _standaloneQuarterSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterShortStandaloneQuarterSymbols, value: _shortStandaloneQuarterSymbols?._cfObject)
            _setFormatterAttribute(formatter, attributeName: kCFDateFormatterGregorianStartDate, value: _gregorianStartDate?._cfObject)
        }

        internal func _setFormatterAttribute(_ formatter: CFDateFormatter, attributeName: CFString, value: AnyObject?) {
            if let value = value {
                CFDateFormatterSetProperty(formatter, attributeName, value)
            }
        }

        private var _dateFormat: String? { willSet { _reset() } }
        var dateFormat: String! {
            get {
                guard let format = _dateFormat else {
                    return CFDateFormatterGetFormat(formatter())._swiftObject
                }
                return format
            }
            set {
                _dateFormat = newValue
            }
        }

        var dateStyle: Style = .none {
            willSet {
                _dateFormat = nil
            }
        }

        var timeStyle: Style = .none {
            willSet {
                _dateFormat = nil
            }
        }

        internal var _locale: Locale? { willSet { _reset() } }
        var locale: Locale! {
            get {
                guard let locale = _locale else { return .current }
                return locale
            }
            set {
                _locale = newValue
            }
        }

        var generatesCalendarDates = false { willSet { _reset() } }

        internal var _timeZone: TimeZone? { willSet { _reset() } }
        var timeZone: TimeZone! {
            get {
                guard let tz = _timeZone else {
                    // The returned value is a CFTimeZone
                    let property = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterTimeZone)
                    let propertyTZ = unsafeBitCast(property, to: CFTimeZone.self)
                    return propertyTZ._swiftObject
                }
                return tz
            }
            set {
                _timeZone = newValue
            }
        }

        internal var _calendar: Calendar! { willSet { _reset() } }
        var calendar: Calendar! {
            get {
                guard let calendar = _calendar else {
                    // The returned value is a CFCalendar
                    let property = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterCalendar)
                    let propertyCalendar = unsafeBitCast(property, to: CFCalendar.self)
                    return propertyCalendar._swiftObject
                }
                return calendar
            }
            set {
                _calendar = newValue
            }
        }

        var isLenient = false { willSet { _reset() } }

        internal var _twoDigitStartDate: Date? { willSet { _reset() } }
        var twoDigitStartDate: Date? {
            get {
                guard let startDate = _twoDigitStartDate else {
                    return (CFDateFormatterCopyProperty(formatter(), kCFDateFormatterTwoDigitStartDate) as? NSDate)?._swiftObject
                }
                return startDate
            }
            set {
                _twoDigitStartDate = newValue
            }
        }

        var defaultDate: Date? { willSet { _reset() } }
        
        internal var _eraSymbols: [String]? { willSet { _reset() } }
        var eraSymbols: [String] {
            get {
                guard let symbols = _eraSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterEraSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _eraSymbols = newValue
            }
        }
        
        internal var _monthSymbols: [String]? { willSet { _reset() } }
        var monthSymbols: [String] {
            get {
                guard let symbols = _monthSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterMonthSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _monthSymbols = newValue
            }
        }

        internal var _shortMonthSymbols: [String]? { willSet { _reset() } }
        var shortMonthSymbols: [String] {
            get {
                guard let symbols = _shortMonthSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterShortMonthSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _shortMonthSymbols = newValue
            }
        }
        

        internal var _weekdaySymbols: [String]? { willSet { _reset() } }
        var weekdaySymbols: [String] {
            get {
                guard let symbols = _weekdaySymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterWeekdaySymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _weekdaySymbols = newValue
            }
        }

        internal var _shortWeekdaySymbols: [String]? { willSet { _reset() } }
        var shortWeekdaySymbols: [String] {
            get {
                guard let symbols = _shortWeekdaySymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterShortWeekdaySymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _shortWeekdaySymbols = newValue
            }
        }

        internal var _amSymbol: String? { willSet { _reset() } }
        var amSymbol: String {
            get {
                guard let symbol = _amSymbol else {
                    return (CFDateFormatterCopyProperty(formatter(), kCFDateFormatterAMSymbol) as! NSString)._swiftObject
                }
                return symbol
            }
            set {
                _amSymbol = newValue
            }
        }

        internal var _pmSymbol: String? { willSet { _reset() } }
        var pmSymbol: String {
            get {
                guard let symbol = _pmSymbol else {
                    return (CFDateFormatterCopyProperty(formatter(), kCFDateFormatterPMSymbol) as! NSString)._swiftObject
                }
                return symbol
            }
            set {
                _pmSymbol = newValue
            }
        }

        internal var _longEraSymbols: [String]? { willSet { _reset() } }
        var longEraSymbols: [String] {
            get {
                guard let symbols = _longEraSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterLongEraSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _longEraSymbols = newValue
            }
        }

        internal var _veryShortMonthSymbols: [String]? { willSet { _reset() } }
        var veryShortMonthSymbols: [String] {
            get {
                guard let symbols = _veryShortMonthSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterVeryShortMonthSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _veryShortMonthSymbols = newValue
            }
        }

        internal var _standaloneMonthSymbols: [String]? { willSet { _reset() } }
        var standaloneMonthSymbols: [String] {
            get {
                guard let symbols = _standaloneMonthSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterStandaloneMonthSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _standaloneMonthSymbols = newValue
            }
        }

        internal var _shortStandaloneMonthSymbols: [String]? { willSet { _reset() } }
        var shortStandaloneMonthSymbols: [String] {
            get {
                guard let symbols = _shortStandaloneMonthSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterShortStandaloneMonthSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _shortStandaloneMonthSymbols = newValue
            }
        }

        internal var _veryShortStandaloneMonthSymbols: [String]? { willSet { _reset() } }
        var veryShortStandaloneMonthSymbols: [String] {
            get {
                guard let symbols = _veryShortStandaloneMonthSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterVeryShortStandaloneMonthSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _veryShortStandaloneMonthSymbols = newValue
            }
        }

        internal var _veryShortWeekdaySymbols: [String]? { willSet { _reset() } }
        var veryShortWeekdaySymbols: [String] {
            get {
                guard let symbols = _veryShortWeekdaySymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterVeryShortWeekdaySymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _veryShortWeekdaySymbols = newValue
            }
        }

        internal var _standaloneWeekdaySymbols: [String]? { willSet { _reset() } }
        var standaloneWeekdaySymbols: [String] {
            get {
                guard let symbols = _standaloneWeekdaySymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterStandaloneWeekdaySymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _standaloneWeekdaySymbols = newValue
            }
        }

        internal var _shortStandaloneWeekdaySymbols: [String]? { willSet { _reset() } }
        var shortStandaloneWeekdaySymbols: [String] {
            get {
                guard let symbols = _shortStandaloneWeekdaySymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterShortStandaloneWeekdaySymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _shortStandaloneWeekdaySymbols = newValue
            }
        }
        
        internal var _veryShortStandaloneWeekdaySymbols: [String]? { willSet { _reset() } }
        var veryShortStandaloneWeekdaySymbols: [String] {
            get {
                guard let symbols = _veryShortStandaloneWeekdaySymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterVeryShortStandaloneWeekdaySymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _veryShortStandaloneWeekdaySymbols = newValue
            }
        }

        internal var _quarterSymbols: [String]? { willSet { _reset() } }
        var quarterSymbols: [String] {
            get {
                guard let symbols = _quarterSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterQuarterSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _quarterSymbols = newValue
            }
        }
        
        internal var _shortQuarterSymbols: [String]? { willSet { _reset() } }
        var shortQuarterSymbols: [String] {
            get {
                guard let symbols = _shortQuarterSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterShortQuarterSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _shortQuarterSymbols = newValue
            }
        }

        internal var _standaloneQuarterSymbols: [String]? { willSet { _reset() } }
        var standaloneQuarterSymbols: [String] {
            get {
                guard let symbols = _standaloneQuarterSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterStandaloneQuarterSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _standaloneQuarterSymbols = newValue
            }
        }

        internal var _shortStandaloneQuarterSymbols: [String]? { willSet { _reset() } }
        var shortStandaloneQuarterSymbols: [String] {
            get {
                guard let symbols = _shortStandaloneQuarterSymbols else {
                    let cfSymbols = CFDateFormatterCopyProperty(formatter(), kCFDateFormatterShortStandaloneQuarterSymbols) as! NSArray
                    return cfSymbols.allObjects as! [String]
                }
                return symbols
            }
            set {
                _shortStandaloneQuarterSymbols = newValue
            }
        }

        internal var _gregorianStartDate: Date? { willSet { _reset() } }
        var gregorianStartDate: Date? {
            get {
                guard let startDate = _gregorianStartDate else {
                    return (CFDateFormatterCopyProperty(formatter(), kCFDateFormatterGregorianStartDate) as? NSDate)?._swiftObject
                }
                return startDate
            }
            set {
                _gregorianStartDate = newValue
            }
        }

        var doesRelativeDateFormatting = false { willSet { _reset() } }

        // MARK: -
        
        func string(for obj: Any) -> String? {
            guard let date = obj as? Date else { return nil }
            return string(from: date)
        }

        func string(from date: Date) -> String {
            return CFDateFormatterCreateStringWithDate(kCFAllocatorSystemDefault, formatter(), date._cfObject)._swiftObject
        }

        func date(from string: String) -> Date? {
            var range = CFRange(location: 0, length: string.length)
            let date = withUnsafeMutablePointer(to: &range) { (rangep: UnsafeMutablePointer<CFRange>) -> Date? in
                guard let res = CFDateFormatterCreateDateFromString(kCFAllocatorSystemDefault, formatter(), string._cfObject, rangep) else {
                    return nil
                }
                return res._swiftObject
            }

            // range.length is updated with the last position of the input string that was parsed
            guard let swiftRange = Range(NSRange(range), in: string) else {
                fatalError("Incorrect range \(range) in \(string)")
            }
            
            // Apple DateFormatter implementation returns nil
            // if non-whitespace characters are left after parsed content.
            let remainder = String(string[swiftRange.upperBound...])
            let characterSet = CharacterSet(charactersIn: remainder)
            guard CharacterSet.whitespaces.isSuperset(of: characterSet) else {
                return nil
            }
            return date
        }
    }
    
    open override func string(for obj: Any) -> String? {
        guard let date = obj as? Date else { return nil }
        return string(from: date)
    }

    open func string(from date: Date) -> String {
        _lock.withLock { $0.string(from: date) }
    }

    open func date(from string: String) -> Date? {
        _lock.withLock { $0.date(from: string) }
    }

    open class func localizedString(from date: Date, dateStyle dstyle: Style, timeStyle tstyle: Style) -> String {
        let df = DateFormatter()
        df.dateStyle = dstyle
        df.timeStyle = tstyle
        return df.string(for: date._nsObject)!
    }

    open class func dateFormat(fromTemplate template: String, options opts: Int, locale: Locale?) -> String? {
        guard let res = CFDateFormatterCreateDateFormatFromTemplate(kCFAllocatorSystemDefault, template._cfObject, CFOptionFlags(opts), locale?._cfObject) else {
            return nil
        }
        return res._swiftObject
    }

    open func setLocalizedDateFormatFromTemplate(_ dateFormatTemplate: String) {
        if let format = DateFormatter.dateFormat(fromTemplate: dateFormatTemplate, options: 0, locale: locale) {
            dateFormat = format
        }
    }

    // MARK: -
    
    open var dateFormat: String! {
        get { _lock.withLock { $0.dateFormat } }
        set { _lock.withLock { $0.dateFormat = newValue } }
    }

    open var dateStyle: Style {
        get { _lock.withLock { $0.dateStyle } }
        set { _lock.withLock { $0.dateStyle = newValue } }
    }

    open var timeStyle: Style {
        get { _lock.withLock { $0.timeStyle } }
        set { _lock.withLock { $0.timeStyle = newValue } }
    }

    open var locale: Locale! {
        get { _lock.withLock { $0.locale } }
        set { _lock.withLock { $0.locale = newValue } }
    }

    open var generatesCalendarDates: Bool {
        get { _lock.withLock { $0.generatesCalendarDates } }
        set { _lock.withLock { $0.generatesCalendarDates = newValue } }
    }

    open var timeZone: TimeZone! {
        get { _lock.withLock { $0.timeZone } }
        set { _lock.withLock { $0.timeZone = newValue } }
    }

    open var calendar: Calendar! {
        get { _lock.withLock { $0.calendar } }
        set { _lock.withLock { $0.calendar = newValue } }
    }

    open var isLenient: Bool {
        get { _lock.withLock { $0.isLenient } }
        set { _lock.withLock { $0.isLenient = newValue } }
    }

    open var twoDigitStartDate: Date? {
        get { _lock.withLock { $0.twoDigitStartDate } }
        set { _lock.withLock { $0.twoDigitStartDate = newValue } }
    }

    open var defaultDate: Date? {
        get { _lock.withLock { $0.defaultDate } }
        set { _lock.withLock { $0.defaultDate = newValue } }
    }

    open var eraSymbols: [String] {
        get { _lock.withLock { $0.eraSymbols } }
        set { _lock.withLock { $0.eraSymbols = newValue } }
    }

    open var monthSymbols: [String] {
        get { _lock.withLock { $0.monthSymbols } }
        set { _lock.withLock { $0.monthSymbols = newValue } }
    }

    open var shortMonthSymbols: [String] {
        get { _lock.withLock { $0.shortMonthSymbols } }
        set { _lock.withLock { $0.shortMonthSymbols = newValue } }
    }

    open var weekdaySymbols: [String] {
        get { _lock.withLock { $0.weekdaySymbols } }
        set { _lock.withLock { $0.weekdaySymbols = newValue } }
    }

    open var shortWeekdaySymbols: [String] {
        get { _lock.withLock { $0.shortWeekdaySymbols } }
        set { _lock.withLock { $0.shortWeekdaySymbols = newValue } }
    }

    open var amSymbol: String {
        get { _lock.withLock { $0.amSymbol } }
        set { _lock.withLock { $0.amSymbol = newValue } }
    }

    open var pmSymbol: String {
        get { _lock.withLock { $0.pmSymbol } }
        set { _lock.withLock { $0.pmSymbol = newValue } }
    }

    open var longEraSymbols: [String] {
        get { _lock.withLock { $0.longEraSymbols } }
        set { _lock.withLock { $0.longEraSymbols = newValue } }
    }

    open var veryShortMonthSymbols: [String] {
        get { _lock.withLock { $0.veryShortMonthSymbols } }
        set { _lock.withLock { $0.veryShortMonthSymbols = newValue } }
    }

    open var standaloneMonthSymbols: [String] {
        get { _lock.withLock { $0.standaloneMonthSymbols } }
        set { _lock.withLock { $0.standaloneMonthSymbols = newValue } }
    }

    open var shortStandaloneMonthSymbols: [String] {
        get { _lock.withLock { $0.shortStandaloneMonthSymbols } }
        set { _lock.withLock { $0.shortStandaloneMonthSymbols = newValue } }
    }

    open var veryShortStandaloneMonthSymbols: [String] {
        get { _lock.withLock { $0.veryShortStandaloneMonthSymbols } }
        set { _lock.withLock { $0.veryShortStandaloneMonthSymbols = newValue } }
    }

    open var veryShortWeekdaySymbols: [String] {
        get { _lock.withLock { $0.veryShortWeekdaySymbols } }
        set { _lock.withLock { $0.veryShortWeekdaySymbols = newValue } }
    }

    open var standaloneWeekdaySymbols: [String] {
        get { _lock.withLock { $0.standaloneWeekdaySymbols } }
        set { _lock.withLock { $0.standaloneWeekdaySymbols = newValue } }
    }

    open var shortStandaloneWeekdaySymbols: [String] {
        get { _lock.withLock { $0.shortStandaloneWeekdaySymbols } }
        set { _lock.withLock { $0.shortStandaloneWeekdaySymbols = newValue } }
    }

    open var veryShortStandaloneWeekdaySymbols: [String] {
        get { _lock.withLock { $0.veryShortStandaloneWeekdaySymbols } }
        set { _lock.withLock { $0.veryShortStandaloneWeekdaySymbols = newValue } }
    }

    open var quarterSymbols: [String] {
        get { _lock.withLock { $0.quarterSymbols } }
        set { _lock.withLock { $0.quarterSymbols = newValue } }
    }

    open var shortQuarterSymbols: [String] {
        get { _lock.withLock { $0.shortQuarterSymbols } }
        set { _lock.withLock { $0.shortQuarterSymbols = newValue } }
    }

    open var standaloneQuarterSymbols: [String] {
        get { _lock.withLock { $0.standaloneQuarterSymbols } }
        set { _lock.withLock { $0.standaloneQuarterSymbols = newValue } }
    }

    open var shortStandaloneQuarterSymbols: [String] {
        get { _lock.withLock { $0.shortStandaloneQuarterSymbols } }
        set { _lock.withLock { $0.shortStandaloneQuarterSymbols = newValue } }
    }

    open var gregorianStartDate: Date? {
        get { _lock.withLock { $0.gregorianStartDate } }
        set { _lock.withLock { $0.gregorianStartDate = newValue } }
    }

    open var doesRelativeDateFormatting: Bool {
        get { _lock.withLock { $0.doesRelativeDateFormatting } }
        set { _lock.withLock { $0.doesRelativeDateFormatting = newValue } }
    }
}

extension DateFormatter {
    public enum Style : UInt, Sendable {
        case none
        case short
        case medium
        case long
        case full
    }
}
