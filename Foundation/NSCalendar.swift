// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

import CoreFoundation

#if os(macOS) || os(iOS)
internal let kCFCalendarUnitEra = CFCalendarUnit.era.rawValue
internal let kCFCalendarUnitYear = CFCalendarUnit.year.rawValue
internal let kCFCalendarUnitMonth = CFCalendarUnit.month.rawValue
internal let kCFCalendarUnitDay = CFCalendarUnit.day.rawValue
internal let kCFCalendarUnitHour = CFCalendarUnit.hour.rawValue
internal let kCFCalendarUnitMinute = CFCalendarUnit.minute.rawValue
internal let kCFCalendarUnitSecond = CFCalendarUnit.second.rawValue
internal let kCFCalendarUnitWeekday = CFCalendarUnit.weekday.rawValue
internal let kCFCalendarUnitWeekdayOrdinal = CFCalendarUnit.weekdayOrdinal.rawValue
internal let kCFCalendarUnitQuarter = CFCalendarUnit.quarter.rawValue
internal let kCFCalendarUnitWeekOfMonth = CFCalendarUnit.weekOfMonth.rawValue
internal let kCFCalendarUnitWeekOfYear = CFCalendarUnit.weekOfYear.rawValue
internal let kCFCalendarUnitYearForWeekOfYear = CFCalendarUnit.yearForWeekOfYear.rawValue

internal let kCFDateFormatterNoStyle = CFDateFormatterStyle.noStyle
internal let kCFDateFormatterShortStyle = CFDateFormatterStyle.shortStyle
internal let kCFDateFormatterMediumStyle = CFDateFormatterStyle.mediumStyle
internal let kCFDateFormatterLongStyle = CFDateFormatterStyle.longStyle
internal let kCFDateFormatterFullStyle = CFDateFormatterStyle.fullStyle
#endif

extension NSCalendar {
    public struct Identifier : RawRepresentable, Equatable, Hashable, Comparable {
        public private(set) var rawValue: String
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        public var hashValue: Int {
            return rawValue.hashValue
        }
        
        public static let gregorian = NSCalendar.Identifier("gregorian")
        public static let buddhist = NSCalendar.Identifier("buddhist")
        public static let chinese = NSCalendar.Identifier("chinese")
        public static let coptic = NSCalendar.Identifier("coptic")
        public static let ethiopicAmeteMihret = NSCalendar.Identifier("ethiopic")
        public static let ethiopicAmeteAlem = NSCalendar.Identifier("ethiopic-amete-alem")
        public static let hebrew = NSCalendar.Identifier("hebrew")
        public static let ISO8601 = NSCalendar.Identifier("iso8601")
        public static let indian = NSCalendar.Identifier("indian")
        public static let islamic = NSCalendar.Identifier("islamic")
        public static let islamicCivil = NSCalendar.Identifier("islamic-civil")
        public static let japanese = NSCalendar.Identifier("japanese")
        public static let persian = NSCalendar.Identifier("persian")
        public static let republicOfChina = NSCalendar.Identifier("roc")
        public static let islamicTabular = NSCalendar.Identifier("islamic-tbla")
        public static let islamicUmmAlQura = NSCalendar.Identifier("islamic-umalqura")
    }
    
    public struct Unit: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let era = Unit(rawValue: UInt(kCFCalendarUnitEra))
        public static let year = Unit(rawValue: UInt(kCFCalendarUnitYear))
        public static let month = Unit(rawValue: UInt(kCFCalendarUnitMonth))
        public static let day = Unit(rawValue: UInt(kCFCalendarUnitDay))
        public static let hour = Unit(rawValue: UInt(kCFCalendarUnitHour))
        public static let minute = Unit(rawValue: UInt(kCFCalendarUnitMinute))
        public static let second = Unit(rawValue: UInt(kCFCalendarUnitSecond))
        public static let weekday = Unit(rawValue: UInt(kCFCalendarUnitWeekday))
        public static let weekdayOrdinal = Unit(rawValue: UInt(kCFCalendarUnitWeekdayOrdinal))
        public static let quarter = Unit(rawValue: UInt(kCFCalendarUnitQuarter))
        public static let weekOfMonth = Unit(rawValue: UInt(kCFCalendarUnitWeekOfMonth))
        public static let weekOfYear = Unit(rawValue: UInt(kCFCalendarUnitWeekOfYear))
        public static let yearForWeekOfYear = Unit(rawValue: UInt(kCFCalendarUnitYearForWeekOfYear))

        public static let nanosecond = Unit(rawValue: UInt(1 << 15))
        public static let calendar = Unit(rawValue: UInt(1 << 20))
        public static let timeZone = Unit(rawValue: UInt(1 << 21))

        internal var _cfValue: CFCalendarUnit {
#if os(macOS) || os(iOS)
            return CFCalendarUnit(rawValue: self.rawValue)
#else
            return CFCalendarUnit(self.rawValue)
#endif
        }
    }

    public struct Options : OptionSet {
        public let rawValue : UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        
        public static let wrapComponents = Options(rawValue: 1 << 0)
        public static let matchStrictly = Options(rawValue: 1 << 1)
        public static let searchBackwards = Options(rawValue: 1 << 2)
        public static let matchPreviousTimePreservingSmallerUnits = Options(rawValue: 1 << 8)
        public static let matchNextTimePreservingSmallerUnits = Options(rawValue: 1 << 9)
        public static let matchNextTime = Options(rawValue: 1 << 10)
        public static let matchFirst = Options(rawValue: 1 << 12)
        public static let matchLast = Options(rawValue: 1 << 13)
    }
}

extension NSCalendar.Identifier {
    public static func ==(_ lhs: NSCalendar.Identifier, _ rhs: NSCalendar.Identifier) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

    public static func <(_ lhs: NSCalendar.Identifier, _ rhs: NSCalendar.Identifier) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

open class NSCalendar : NSObject, NSCopying, NSSecureCoding {
    typealias CFType = CFCalendar
    private var _base = _CFInfo(typeID: CFCalendarGetTypeID())
    private var _identifier: UnsafeMutableRawPointer? = nil
    private var _locale: UnsafeMutableRawPointer? = nil
    private var _localeID: UnsafeMutableRawPointer? = nil
    private var _tz: UnsafeMutableRawPointer? = nil
    private var _cal: UnsafeMutableRawPointer? = nil
    
    internal var _cfObject: CFType {
        return unsafeBitCast(self, to: CFCalendar.self)
    }
    
    public convenience required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        guard let calendarIdentifier = aDecoder.decodeObject(of: NSString.self, forKey: "NS.identifier") else {
            return nil
        }

        self.init(identifier: NSCalendar.Identifier.init(rawValue: calendarIdentifier._swiftObject))

        if let timeZone = aDecoder.decodeObject(of: NSTimeZone.self, forKey: "NS.timezone") {
            self.timeZone = timeZone._swiftObject
        }
        if let locale = aDecoder.decodeObject(of: NSLocale.self, forKey: "NS.locale") {
            self.locale = locale._swiftObject
        }
        self.firstWeekday = aDecoder.decodeInteger(forKey: "NS.firstwkdy")
        self.minimumDaysInFirstWeek = aDecoder.decodeInteger(forKey: "NS.mindays")
        if let startDate = aDecoder.decodeObject(of: NSDate.self, forKey: "NS.gstartdate") {
            self._startDate = startDate._swiftObject
        }
    }
    
    private var _startDate : Date? {
        get {
            return CFCalendarCopyGregorianStartDate(self._cfObject)?._swiftObject
        }
        set {
            if let startDate = newValue {
                CFCalendarSetGregorianStartDate(self._cfObject, startDate._cfObject)
            }
        }
    }
    
    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        aCoder.encode(self.calendarIdentifier.rawValue._bridgeToObjectiveC(), forKey: "NS.identifier")
        aCoder.encode(self.timeZone._nsObject, forKey: "NS.timezone")
        aCoder.encode(self.locale?._bridgeToObjectiveC(), forKey: "NS.locale")
        aCoder.encode(self.firstWeekday, forKey: "NS.firstwkdy")
        aCoder.encode(self.minimumDaysInFirstWeek, forKey: "NS.mindays")
        aCoder.encode(self._startDate?._nsObject, forKey: "NS.gstartdate")
    }
    
    static public var supportsSecureCoding: Bool {
        return true
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        let copy = NSCalendar(identifier: calendarIdentifier)!
        copy.locale = locale
        copy.timeZone = timeZone
        copy.firstWeekday = firstWeekday
        copy.minimumDaysInFirstWeek = minimumDaysInFirstWeek
        copy._startDate = _startDate
        return copy
    }
    

    open class var current: Calendar {
        return CFCalendarCopyCurrent()._swiftObject
    }
    
    open class var autoupdatingCurrent: Calendar { NSUnimplemented() }  // tracks changes to user's preferred calendar identifier
    
    public /*not inherited*/ init?(identifier calendarIdentifierConstant: Identifier) {
        super.init()
        if !_CFCalendarInitWithIdentifier(_cfObject, calendarIdentifierConstant.rawValue._cfObject) {
            return nil
        }
    }
    
    public init?(calendarIdentifier ident: Identifier) {
        super.init()
        if !_CFCalendarInitWithIdentifier(_cfObject, ident.rawValue._cfObject) {
            return nil
        }
    }
    
    open override var hash: Int {
        return Int(bitPattern: CFHash(_cfObject))
    }
    
    open override func isEqual(_ value: Any?) -> Bool {
        switch value {
        case let other as Calendar:
            return CFEqual(_cfObject, other._cfObject)
        case let other as NSCalendar:
            return other === self || CFEqual(_cfObject, other._cfObject)
        default:
            return false
        }
    }
    
    open override var description: String {
        return CFCopyDescription(_cfObject)._swiftObject
    }

    deinit {
        _CFDeinit(self)
    }
    
    open var calendarIdentifier: Identifier  {
        get {
            return Identifier(rawValue: CFCalendarGetIdentifier(_cfObject)._swiftObject)
        }
    }
    
    /*@NSCopying*/ open var locale: Locale? {
        get {
            return CFCalendarCopyLocale(_cfObject)._swiftObject
        }
        set {
            CFCalendarSetLocale(_cfObject, newValue?._cfObject)
        }
    }
    /*@NSCopying*/ open var timeZone: TimeZone {
        get {
            return CFCalendarCopyTimeZone(_cfObject)._swiftObject
        }
        set {
            CFCalendarSetTimeZone(_cfObject, newValue._cfObject)
        }
    }
    
    open var firstWeekday: Int {
        get {
            return CFCalendarGetFirstWeekday(_cfObject)
        }
        set {
            CFCalendarSetFirstWeekday(_cfObject, CFIndex(newValue))
        }
    }
    
    open var minimumDaysInFirstWeek: Int {
        get {
            return CFCalendarGetMinimumDaysInFirstWeek(_cfObject)
        }
        set {
            CFCalendarSetMinimumDaysInFirstWeek(_cfObject, CFIndex(newValue))
        }
    }
    
    // Methods to return component name strings localized to the calendar's locale
    
    private func _symbols(_ key: CFString) -> [String] {
        let dateFormatter = CFDateFormatterCreate(kCFAllocatorSystemDefault, locale?._cfObject, kCFDateFormatterNoStyle, kCFDateFormatterNoStyle)
        CFDateFormatterSetProperty(dateFormatter, kCFDateFormatterCalendarKey, _cfObject)
        let result = (CFDateFormatterCopyProperty(dateFormatter, key) as! CFArray)._swiftObject
        return result.map {
            return ($0 as! NSString)._swiftObject
        }
    }
    
    private func _symbol(_ key: CFString) -> String {
        let dateFormatter = CFDateFormatterCreate(kCFAllocatorSystemDefault, locale?._bridgeToObjectiveC()._cfObject, kCFDateFormatterNoStyle, kCFDateFormatterNoStyle)
        CFDateFormatterSetProperty(dateFormatter, kCFDateFormatterCalendarKey, self._cfObject)
        return (CFDateFormatterCopyProperty(dateFormatter, key) as! NSString)._swiftObject
    }
    
    open var eraSymbols: [String] {
        return _symbols(kCFDateFormatterEraSymbolsKey)
    }
    
    open var longEraSymbols: [String] {
        return _symbols(kCFDateFormatterLongEraSymbolsKey)
    }
    
    open var monthSymbols: [String] {
        return _symbols(kCFDateFormatterMonthSymbolsKey)
    }
    
    open var shortMonthSymbols: [String] {
        return _symbols(kCFDateFormatterShortMonthSymbolsKey)
    }
    
    open var veryShortMonthSymbols: [String] {
        return _symbols(kCFDateFormatterVeryShortMonthSymbolsKey)
    }
    
    open var standaloneMonthSymbols: [String] {
        return _symbols(kCFDateFormatterStandaloneMonthSymbolsKey)
    }
    
    open var shortStandaloneMonthSymbols: [String] {
        return _symbols(kCFDateFormatterShortStandaloneMonthSymbolsKey)
    }
    
    open var veryShortStandaloneMonthSymbols: [String] {
        return _symbols(kCFDateFormatterVeryShortStandaloneMonthSymbolsKey)
    }
    
    open var weekdaySymbols: [String] {
        return _symbols(kCFDateFormatterWeekdaySymbolsKey)
    }
    
    open var shortWeekdaySymbols: [String] {
        return _symbols(kCFDateFormatterShortWeekdaySymbolsKey)
    }
    
    open var veryShortWeekdaySymbols: [String] {
        return _symbols(kCFDateFormatterVeryShortWeekdaySymbolsKey)
    }
    
    open var standaloneWeekdaySymbols: [String] {
        return _symbols(kCFDateFormatterStandaloneWeekdaySymbolsKey)
    }
    
    open var shortStandaloneWeekdaySymbols: [String] {
        return _symbols(kCFDateFormatterShortStandaloneWeekdaySymbolsKey)
    }

    open var veryShortStandaloneWeekdaySymbols: [String] {
        return _symbols(kCFDateFormatterVeryShortStandaloneWeekdaySymbolsKey)
    }
    
    open var quarterSymbols: [String] {
        return _symbols(kCFDateFormatterQuarterSymbolsKey)
    }
    
    open var shortQuarterSymbols: [String] {
        return _symbols(kCFDateFormatterShortQuarterSymbolsKey)
    }
    
    open var standaloneQuarterSymbols: [String] {
        return _symbols(kCFDateFormatterStandaloneQuarterSymbolsKey)
    }
    
    open var shortStandaloneQuarterSymbols: [String] {
        return _symbols(kCFDateFormatterShortStandaloneQuarterSymbolsKey)
    }
    
    open var amSymbol: String {
        return _symbol(kCFDateFormatterAMSymbolKey)
    }
    
    open var pmSymbol: String {
        return _symbol(kCFDateFormatterPMSymbolKey)
    }
    
    // Calendrical calculations
    
    open func minimumRange(of unit: Unit) -> NSRange {
        let r = CFCalendarGetMinimumRangeOfUnit(self._cfObject, unit._cfValue)
        if (r.location == kCFNotFound) {
            return NSRange(location: NSNotFound, length: NSNotFound)
        }
        return NSRange(location: r.location, length: r.length)
    }
    
    open func maximumRange(of unit: Unit) -> NSRange {
        let r = CFCalendarGetMaximumRangeOfUnit(_cfObject, unit._cfValue)
        if r.location == kCFNotFound {
            return NSRange(location: NSNotFound, length: NSNotFound)
        }
        return NSRange(location: r.location, length: r.length)
    }
    
    open func range(of smaller: Unit, in larger: Unit, for date: Date) -> NSRange {
        let r = CFCalendarGetRangeOfUnit(_cfObject, smaller._cfValue, larger._cfValue, date.timeIntervalSinceReferenceDate)
        if r.location == kCFNotFound {
            return NSRange(location: NSNotFound, length: NSNotFound)
        }
        return NSRange(location: r.location, length: r.length)
    }
    
    open func ordinality(of smaller: Unit, in larger: Unit, for date: Date) -> Int {
        return Int(CFCalendarGetOrdinalityOfUnit(_cfObject, smaller._cfValue, larger._cfValue, date.timeIntervalSinceReferenceDate))
    }
    
    /// Revised API for avoiding usage of AutoreleasingUnsafeMutablePointer.
    /// The current exposed API in Foundation on Darwin platforms is:
    /// open func rangeOfUnit(_ unit: Unit, startDate datep: AutoreleasingUnsafeMutablePointer<NSDate?>, interval tip: UnsafeMutablePointer<NSTimeInterval>, forDate date: NSDate) -> Bool
    /// which is not implementable on Linux due to the lack of being able to properly implement AutoreleasingUnsafeMutablePointer.
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation as a suitable alternative
    /// - Note: Since this API is under consideration it may be either removed or revised in the near future
    open func range(of unit: Unit, for date: Date) -> DateInterval? {
        var start: CFAbsoluteTime = 0.0
        var ti: CFTimeInterval = 0.0
        let res: Bool = withUnsafeMutablePointer(to: &start) { startp in
            withUnsafeMutablePointer(to: &ti) { tip in
                return CFCalendarGetTimeRangeOfUnit(_cfObject, unit._cfValue, date.timeIntervalSinceReferenceDate, startp, tip)
            }
        }
        
        if res {
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: start), duration: ti)
        }
        return nil
    }
    
    private func _convert(_ comp: Int?, type: String, vector: inout [Int32], compDesc: inout [Int8]) {
        if let component = comp {
            vector.append(Int32(component))
            compDesc.append(Int8(type.utf8[type.utf8.startIndex]))
        }
    }
    
    private func _convert(_ comp: Bool?, type: String, vector: inout [Int32], compDesc: inout [Int8]) {
        if let component = comp {
            vector.append(Int32(component ? 0 : 1))
            compDesc.append(Int8(type.utf8[type.utf8.startIndex]))
        }
    }
    
    private func _convert(_ comps: DateComponents) -> (Array<Int32>, Array<Int8>) {
        var vector = [Int32]()
        var compDesc = [Int8]()
        _convert(comps.era, type: "G", vector: &vector, compDesc: &compDesc)
        _convert(comps.year, type: "y", vector: &vector, compDesc: &compDesc)
        _convert(comps.quarter, type: "Q", vector: &vector, compDesc: &compDesc)
        if comps.weekOfYear != NSDateComponentUndefined {
            _convert(comps.weekOfYear, type: "w", vector: &vector, compDesc: &compDesc)
        } else {
            // _convert(comps.week, type: "^", vector: &vector, compDesc: &compDesc)
        }
        _convert(comps.weekOfMonth, type: "W", vector: &vector, compDesc: &compDesc)
        _convert(comps.yearForWeekOfYear, type: "Y", vector: &vector, compDesc: &compDesc)
        _convert(comps.weekday, type: "E", vector: &vector, compDesc: &compDesc)
        _convert(comps.weekdayOrdinal, type: "F", vector: &vector, compDesc: &compDesc)
        _convert(comps.month, type: "M", vector: &vector, compDesc: &compDesc)
        _convert(comps.isLeapMonth, type: "l", vector: &vector, compDesc: &compDesc)
        _convert(comps.day, type: "d", vector: &vector, compDesc: &compDesc)
        _convert(comps.hour, type: "H", vector: &vector, compDesc: &compDesc)
        _convert(comps.minute, type: "m", vector: &vector, compDesc: &compDesc)
        _convert(comps.second, type: "s", vector: &vector, compDesc: &compDesc)
        _convert(comps.nanosecond, type: "#", vector: &vector, compDesc: &compDesc)
        compDesc.append(0)
        return (vector, compDesc)
    }
    
    open func date(from comps: DateComponents) -> Date? {
        var (vector, compDesc) = _convert(comps)
        
        self.timeZone = comps.timeZone ?? timeZone
        
        var at: CFAbsoluteTime = 0.0
        let res: Bool = withUnsafeMutablePointer(to: &at) { t in
            return vector.withUnsafeMutableBufferPointer { (vectorBuffer: inout UnsafeMutableBufferPointer<Int32>) in
                return _CFCalendarComposeAbsoluteTimeV(_cfObject, t, compDesc, vectorBuffer.baseAddress!, Int32(vectorBuffer.count))
            }
        }
        
        if res {
            return Date(timeIntervalSinceReferenceDate: at)
        } else {
            return nil
        }
    }
    
    private func _setup(_ unitFlags: Unit, field: Unit, type: String, compDesc: inout [Int8]) {
        if unitFlags.contains(field) {
            compDesc.append(Int8(type.utf8[type.utf8.startIndex]))
        }
    }
    
    private func _setup(_ unitFlags: Unit) -> [Int8] {
        var compDesc = [Int8]()
        _setup(unitFlags, field: .era, type: "G", compDesc: &compDesc)
        _setup(unitFlags, field: .year, type: "y", compDesc: &compDesc)
        _setup(unitFlags, field: .quarter, type: "Q", compDesc: &compDesc)
        _setup(unitFlags, field: .month, type: "M", compDesc: &compDesc)
        _setup(unitFlags, field: .month, type: "l", compDesc: &compDesc)
        _setup(unitFlags, field: .day, type: "d", compDesc: &compDesc)
        _setup(unitFlags, field: .weekOfYear, type: "w", compDesc: &compDesc)
        _setup(unitFlags, field: .weekOfMonth, type: "W", compDesc: &compDesc)
        _setup(unitFlags, field: .yearForWeekOfYear, type: "Y", compDesc: &compDesc)
        _setup(unitFlags, field: .weekday, type: "E", compDesc: &compDesc)
        _setup(unitFlags, field: .weekdayOrdinal, type: "F", compDesc: &compDesc)
        _setup(unitFlags, field: .hour, type: "H", compDesc: &compDesc)
        _setup(unitFlags, field: .minute, type: "m", compDesc: &compDesc)
        _setup(unitFlags, field: .second, type: "s", compDesc: &compDesc)
        _setup(unitFlags, field: .nanosecond, type: "#", compDesc: &compDesc)
        compDesc.append(0)
        return compDesc
    }
    
    private func _setComp(_ unitFlags: Unit, field: Unit, vector: [Int32], compIndex: inout Int, setter: (Int32) -> Void) {
        if unitFlags.contains(field) {
            if vector[compIndex] != -1 {
                setter(vector[compIndex])
            }
            compIndex += 1
        }
    }
    
    private func _components(_ unitFlags: Unit, vector: [Int32]) -> DateComponents {
        var compIdx = 0
        var comps = DateComponents()
        _setComp(unitFlags, field: .era, vector: vector, compIndex: &compIdx) { comps.era = Int($0) }
        _setComp(unitFlags, field: .year, vector: vector, compIndex: &compIdx) { comps.year = Int($0) }
        _setComp(unitFlags, field: .quarter, vector: vector, compIndex: &compIdx) { comps.quarter = Int($0) }
        _setComp(unitFlags, field: .month, vector: vector, compIndex: &compIdx) { comps.month = Int($0) }
        _setComp(unitFlags, field: .month, vector: vector, compIndex: &compIdx) { comps.isLeapMonth = $0 != 0 }
        _setComp(unitFlags, field: .day, vector: vector, compIndex: &compIdx) { comps.day = Int($0) }
        _setComp(unitFlags, field: .weekOfYear, vector: vector, compIndex: &compIdx) { comps.weekOfYear = Int($0) }
        _setComp(unitFlags, field: .weekOfMonth, vector: vector, compIndex: &compIdx) { comps.weekOfMonth = Int($0) }
        _setComp(unitFlags, field: .yearForWeekOfYear, vector: vector, compIndex: &compIdx) { comps.yearForWeekOfYear = Int($0) }
        _setComp(unitFlags, field: .weekday, vector: vector, compIndex: &compIdx) { comps.weekday = Int($0) }
        _setComp(unitFlags, field: .weekdayOrdinal, vector: vector, compIndex: &compIdx) { comps.weekdayOrdinal = Int($0) }
        _setComp(unitFlags, field: .hour, vector: vector, compIndex: &compIdx) { comps.hour = Int($0) }
        _setComp(unitFlags, field: .minute, vector: vector, compIndex: &compIdx) { comps.minute = Int($0) }
        _setComp(unitFlags, field: .second, vector: vector, compIndex: &compIdx) { comps.second = Int($0) }
        _setComp(unitFlags, field: .nanosecond, vector: vector, compIndex: &compIdx) { comps.nanosecond = Int($0) }
        
        if unitFlags.contains(.calendar) {
            comps.calendar = self._swiftObject
        }
        if unitFlags.contains(.timeZone) {
            comps.timeZone = timeZone
        }
        return comps
    }
    
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation as a suitable alternative
    /// The Darwin version is not nullable but this one is since the conversion from the date and unit flags can potentially return nil
    open func components(_ unitFlags: Unit, from date: Date) -> DateComponents {
        let compDesc = _setup(unitFlags)
        
        // _CFCalendarDecomposeAbsoluteTimeV requires a bit of a funky vector layout; which does not express well in swift; this is the closest I can come up with to the required format
        // int32_t ints[20];
        // int32_t *vector[20] = {&ints[0], &ints[1], &ints[2], &ints[3], &ints[4], &ints[5], &ints[6], &ints[7], &ints[8], &ints[9], &ints[10], &ints[11], &ints[12], &ints[13], &ints[14], &ints[15], &ints[16], &ints[17], &ints[18], &ints[19]};
        var ints = [Int32](repeating: 0, count: 20)
        let res = ints.withUnsafeMutableBufferPointer { (intArrayBuffer: inout UnsafeMutableBufferPointer<Int32>) -> Bool in
            var vector: [UnsafeMutablePointer<Int32>] = (0..<20).map { idx in
                intArrayBuffer.baseAddress!.advanced(by: idx)
            }

            return vector.withUnsafeMutableBufferPointer { (vecBuffer: inout UnsafeMutableBufferPointer<UnsafeMutablePointer<Int32>>) in
                return _CFCalendarDecomposeAbsoluteTimeV(_cfObject, date.timeIntervalSinceReferenceDate, compDesc, vecBuffer.baseAddress!, Int32(compDesc.count - 1))
            }
        }
        if res {
            return _components(unitFlags, vector: ints)
        }
        
        fatalError()
    }
    
    open func date(byAdding comps: DateComponents, to date: Date, options opts: Options = []) -> Date? {
        var (vector, compDesc) = _convert(comps)
        var at: CFAbsoluteTime = date.timeIntervalSinceReferenceDate
        
        let res: Bool = withUnsafeMutablePointer(to: &at) { t in
            let count = Int32(vector.count)
            return vector.withUnsafeMutableBufferPointer { (vectorBuffer: inout UnsafeMutableBufferPointer<Int32>) in
                return _CFCalendarAddComponentsV(_cfObject, t, CFOptionFlags(opts.rawValue), compDesc, vectorBuffer.baseAddress!, count)
            }
        }
        
        if res {
            return Date(timeIntervalSinceReferenceDate: at)
        }
        
        return nil
    }
    
    open func components(_ unitFlags: Unit, from startingDate: Date, to resultDate: Date, options opts: Options = []) -> DateComponents {
        let compDesc = _setup(unitFlags)
        var ints = [Int32](repeating: 0, count: 20)
        let res = ints.withUnsafeMutableBufferPointer { (intArrayBuffer: inout UnsafeMutableBufferPointer<Int32>) -> Bool in
            var vector: [UnsafeMutablePointer<Int32>] = (0..<20).map { idx in
                return intArrayBuffer.baseAddress!.advanced(by: idx)
            }

            let count = Int32(vector.count)
            return vector.withUnsafeMutableBufferPointer { (vecBuffer: inout UnsafeMutableBufferPointer<UnsafeMutablePointer<Int32>>) in
                return _CFCalendarGetComponentDifferenceV(_cfObject, startingDate.timeIntervalSinceReferenceDate, resultDate.timeIntervalSinceReferenceDate, CFOptionFlags(opts.rawValue), compDesc, vecBuffer.baseAddress!, count)
            }
        }
        if res {
            return _components(unitFlags, vector: ints)
        }
        fatalError()
    }
    
    /*
    This API is a convenience for getting era, year, month, and day of a given date.
    Pass NULL for a NSInteger pointer parameter if you don't care about that value.
    */
    open func getEra(_ eraValuePointer: UnsafeMutablePointer<Int>?, year yearValuePointer: UnsafeMutablePointer<Int>?, month monthValuePointer: UnsafeMutablePointer<Int>?, day dayValuePointer: UnsafeMutablePointer<Int>?, from date: Date) {
        let comps = components([.era, .year, .month, .day], from: date)
        if let value = comps.era {
            eraValuePointer?.pointee = value
        } else {
            eraValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.year {
            yearValuePointer?.pointee = value
        } else {
            yearValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.month {
            monthValuePointer?.pointee = value
        } else {
            monthValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.day {
            dayValuePointer?.pointee = value
        } else {
            dayValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.year {
            yearValuePointer?.pointee = value
        } else {
            yearValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.month {
            monthValuePointer?.pointee = value
        } else {
            monthValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.day {
            dayValuePointer?.pointee = value
        } else {
            dayValuePointer?.pointee = NSDateComponentUndefined
        }
    }
    
    /*
    This API is a convenience for getting era, year for week-of-year calculations, week of year, and weekday of a given date.
    Pass NULL for a NSInteger pointer parameter if you don't care about that value.
    */
    open func getEra(_ eraValuePointer: UnsafeMutablePointer<Int>?, yearForWeekOfYear yearValuePointer: UnsafeMutablePointer<Int>?, weekOfYear weekValuePointer: UnsafeMutablePointer<Int>?, weekday weekdayValuePointer: UnsafeMutablePointer<Int>?, from date: Date) {
        let comps = components([.era, .yearForWeekOfYear, .weekOfYear, .weekday], from: date)
        if let value = comps.era {
            eraValuePointer?.pointee = value
        } else  {
            eraValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.yearForWeekOfYear {
            yearValuePointer?.pointee = value
        } else {
            yearValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.weekOfYear {
            weekValuePointer?.pointee = value
        } else {
            weekValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.weekday {
            weekdayValuePointer?.pointee = value
        } else {
            weekdayValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.yearForWeekOfYear {
            yearValuePointer?.pointee = value
        } else {
            yearValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.weekOfYear {
            weekValuePointer?.pointee = value
        } else {
            weekValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.weekday {
            weekdayValuePointer?.pointee = value
        } else {
            weekdayValuePointer?.pointee = NSDateComponentUndefined
        }
    }
    
    /*
    This API is a convenience for getting hour, minute, second, and nanoseconds of a given date.
    Pass NULL for a NSInteger pointer parameter if you don't care about that value.
    */
    open func getHour(_ hourValuePointer: UnsafeMutablePointer<Int>?, minute minuteValuePointer: UnsafeMutablePointer<Int>?, second secondValuePointer: UnsafeMutablePointer<Int>?, nanosecond nanosecondValuePointer: UnsafeMutablePointer<Int>?, from date: Date) {
        let comps = components([.hour, .minute, .second, .nanosecond], from: date)
        if let value = comps.hour {
            hourValuePointer?.pointee = value
        } else {
            hourValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.minute {
            minuteValuePointer?.pointee = value
        } else {
            minuteValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.second {
            secondValuePointer?.pointee = value
        } else {
            secondValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.nanosecond {
            nanosecondValuePointer?.pointee = value
        } else {
            nanosecondValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.minute {
            minuteValuePointer?.pointee = value
        } else {
            minuteValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.second {
            secondValuePointer?.pointee = value
        } else {
            secondValuePointer?.pointee = NSDateComponentUndefined
        }
        if let value = comps.nanosecond {
            nanosecondValuePointer?.pointee = value
        } else {
            nanosecondValuePointer?.pointee = NSDateComponentUndefined
        }
    }
    
    /*
    Get just one component's value.
    */
    open func component(_ unit: Unit, from date: Date) -> Int {
        let comps = components(unit, from: date)
        if let res = comps.value(for: Calendar._fromCalendarUnit(unit)) {
            return res
        } else {
            return NSDateComponentUndefined
        }
    }
    
    /*
    Create a date with given components.
    Current era is assumed.
    */
    open func date(era eraValue: Int, year yearValue: Int, month monthValue: Int, day dayValue: Int, hour hourValue: Int, minute minuteValue: Int, second secondValue: Int, nanosecond nanosecondValue: Int) -> Date? {
        var comps = DateComponents()
        comps.era = eraValue
        comps.year = yearValue
        comps.month = monthValue
        comps.day = dayValue
        comps.hour = hourValue
        comps.minute = minuteValue
        comps.second = secondValue
        comps.nanosecond = nanosecondValue
        return date(from: comps)
    }
    
    /*
    Create a date with given components.
    Current era is assumed.
    */
    open func date(era eraValue: Int, yearForWeekOfYear yearValue: Int, weekOfYear weekValue: Int, weekday weekdayValue: Int, hour hourValue: Int, minute minuteValue: Int, second secondValue: Int, nanosecond nanosecondValue: Int) -> Date? {
        var comps = DateComponents()
        comps.era = eraValue
        comps.yearForWeekOfYear = yearValue
        comps.weekOfYear = weekValue
        comps.weekday = weekdayValue
        comps.hour = hourValue
        comps.minute = minuteValue
        comps.second = secondValue
        comps.nanosecond = nanosecondValue
        return date(from: comps)
    }
    
    /*
    This API returns the first moment date of a given date.
    Pass in [NSDate date], for example, if you want the start of "today".
    If there were two midnights, it returns the first.  If there was none, it returns the first moment that did exist.
    */
    open func startOfDay(for date: Date) -> Date {
        return range(of: .day, for: date)!.start
    }
    
    /*
    This API returns all the date components of a date, as if in a given time zone (instead of the receiving calendar's time zone).
    The time zone overrides the time zone of the NSCalendar for the purposes of this calculation.
    Note: if you want "date information in a given time zone" in order to display it, you should use NSDateFormatter to format the date.
    */
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation as a suitable alternative
    /// The Darwin version is not nullable but this one is since the conversion from the date and unit flags can potentially return nil
    open func components(in timezone: TimeZone, from date: Date) -> DateComponents {
        let oldTz = self.timeZone
        self.timeZone = timezone
        let comps = components([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar, .timeZone], from: date)
        self.timeZone = oldTz
        return comps
    }
    
    /*
    This API compares the given dates down to the given unit, reporting them equal if they are the same in the given unit and all larger units, otherwise either less than or greater than.
    */
    open func compare(_ date1: Date, to date2: Date, toUnitGranularity unit: Unit) -> ComparisonResult {
        switch (unit) {
            case .calendar:
                return .orderedSame
            case .timeZone:
                return .orderedSame
            case .day:
                fallthrough
            case .hour:
                let range = self.range(of: unit, for: date1)
                let ats = range!.start.timeIntervalSinceReferenceDate
                let at2 = date2.timeIntervalSinceReferenceDate
                if ats <= at2 && at2 < ats + range!.duration {
                    return .orderedSame
                }
                if at2 < ats {
                    return .orderedDescending
                }
                return .orderedAscending
            case .minute:
                var int1 = 0.0
                var int2 = 0.0
                modf(date1.timeIntervalSinceReferenceDate, &int1)
                modf(date2.timeIntervalSinceReferenceDate, &int2)
                int1 = floor(int1 / 60.0)
                int2 = floor(int2 / 60.0)
                if int1 == int2 {
                    return .orderedSame
                }
                if int2 < int1 {
                    return .orderedDescending
                }
                return .orderedAscending
            case .second:
                var int1 = 0.0
                var int2 = 0.0
                modf(date1.timeIntervalSinceReferenceDate, &int1)
                modf(date2.timeIntervalSinceReferenceDate, &int2)
                if int1 == int2 {
                    return .orderedSame
                }
                if int2 < int1 {
                    return .orderedDescending
                }
                return .orderedAscending
            case .nanosecond:
                var int1 = 0.0
                var int2 = 0.0
                let frac1 = modf(date1.timeIntervalSinceReferenceDate, &int1)
                let frac2 = modf(date2.timeIntervalSinceReferenceDate, &int2)
                int1 = floor(frac1 * 1000000000.0)
                int2 = floor(frac2 * 1000000000.0)
                if int1 == int2 {
                    return .orderedSame
                }
                if int2 < int1 {
                    return .orderedDescending
                }
                return .orderedAscending
            default:
                break
        }

        let calendarUnits1: [Unit] = [.era, .year, .month, .day]
        let calendarUnits2: [Unit] = [.era, .year, .month, .weekdayOrdinal, .day]
        let calendarUnits3: [Unit] = [.era, .year, .month, .weekOfMonth, .weekday]
        let calendarUnits4: [Unit] = [.era, .yearForWeekOfYear, .weekOfYear, .weekday]
        var units: [Unit]
        if unit == .yearForWeekOfYear || unit == .weekOfYear {
            units = calendarUnits4
        } else if unit == .weekdayOrdinal {
            units = calendarUnits2
        } else if unit == .weekday || unit == .weekOfMonth {
            units = calendarUnits3
        } else {
            units = calendarUnits1
        }
        
        // TODO: verify that the return value here is never going to be nil; it seems like it may - thusly making the return value here optional which would result in sadness and regret
        let reducedUnits = units.reduce(Unit()) { $0.union($1) }
        let comp1 = components(reducedUnits, from: date1)
        let comp2 = components(reducedUnits, from: date2)
    
        for unit in units {
            let value1 = comp1.value(for: Calendar._fromCalendarUnit(unit))
            let value2 = comp2.value(for: Calendar._fromCalendarUnit(unit))
            if value1! > value2! {
                return .orderedDescending
            } else if value1! < value2! {
                return .orderedAscending
            }
            if unit == .month && calendarIdentifier == .chinese {
                if let leap1 = comp1.isLeapMonth {
                    if let leap2 = comp2.isLeapMonth {
                        if !leap1 && leap2 {
                            return .orderedAscending
                        } else if leap1 && !leap2 {
                            return .orderedDescending
                        }
                    }
                }
                
            }
            if unit == reducedUnits {
                return .orderedSame
            }
        }
        return .orderedSame
    }
    
    /*
    This API compares the given dates down to the given unit, reporting them equal if they are the same in the given unit and all larger units.
    */
    open func isDate(_ date1: Date, equalTo date2: Date, toUnitGranularity unit: Unit) -> Bool {
        return compare(date1, to: date2, toUnitGranularity: unit) == .orderedSame
    }
    
    /*
    This API compares the Days of the given dates, reporting them equal if they are in the same Day.
    */
    open func isDate(_ date1: Date, inSameDayAs date2: Date) -> Bool {
        return compare(date1, to: date2, toUnitGranularity: .day) == .orderedSame
    }
    
    /*
    This API reports if the date is within "today".
    */
    open func isDateInToday(_ date: Date) -> Bool {
        return compare(date, to: Date(), toUnitGranularity: .day) == .orderedSame
    }
    
    /*
    This API reports if the date is within "yesterday".
    */
    open func isDateInYesterday(_ date: Date) -> Bool {
        if let interval = range(of: .day, for: Date()) {
            let inYesterday = interval.start - 60.0
            return compare(date, to: inYesterday, toUnitGranularity: .day) == .orderedSame
        } else {
            return false
        }
    }
    
    /*
    This API reports if the date is within "tomorrow".
    */
    open func isDateInTomorrow(_ date: Date) -> Bool {
        if let interval = range(of: .day, for: Date()) {
            let inTomorrow = interval.end + 60.0
            return compare(date, to: inTomorrow, toUnitGranularity: .day) == .orderedSame
        } else {
            return false
        }
    }
    
    /*
    This API reports if the date is within a weekend period, as defined by the calendar and calendar's locale.
    */
    open func isDateInWeekend(_ date: Date) -> Bool {
        return _CFCalendarIsWeekend(_cfObject, date.timeIntervalSince1970)
    }
    
    /// Revised API for avoiding usage of AutoreleasingUnsafeMutablePointer.
    /// The current exposed API in Foundation on Darwin platforms is:
    /// open func rangeOfWeekendStartDate(_ datep: AutoreleasingUnsafeMutablePointer<NSDate?>, interval tip: UnsafeMutablePointer<NSTimeInterval>, containingDate date: NSDate) -> Bool
    /// which is not implementable on Linux due to the lack of being able to properly implement AutoreleasingUnsafeMutablePointer.
    /// Find the range of the weekend around the given date, returned via two by-reference parameters.
    /// Returns nil if the given date is not in a weekend.
    /// - Note: A given entire Day within a calendar is not necessarily all in a weekend or not; weekends can start in the middle of a Day in some calendars and locales.
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation as a suitable alternative
    /// - Note: Since this API is under consideration it may be either removed or revised in the near future
    open func range(ofWeekendContaining date: Date) -> DateInterval? {
        if let next = nextWeekendAfter(date, options: []) {
            if let prev = nextWeekendAfter(next.start, options: .searchBackwards) {
                if prev.start.timeIntervalSinceReferenceDate <= date.timeIntervalSinceReferenceDate && date.timeIntervalSinceReferenceDate <= prev.end.timeIntervalSinceReferenceDate {
                    return prev
                }
            }
        }
        return nil
    }
    
    /// Revised API for avoiding usage of AutoreleasingUnsafeMutablePointer.
    /// The current exposed API in Foundation on Darwin platforms is:
    /// open func nextWeekendStartDate(_ datep: AutoreleasingUnsafeMutablePointer<NSDate?>, interval tip: UnsafeMutablePointer<NSTimeInterval>, options: Options, afterDate date: NSDate) -> Bool
    /// Returns the range of the next weekend, via two by-reference parameters, which starts strictly after the given date.
    /// The .SearchBackwards option can be used to find the previous weekend range strictly before the date.
    /// Returns nil if there are no such things as weekend in the calendar and its locale.
    /// - Note: A given entire Day within a calendar is not necessarily all in a weekend or not; weekends can start in the middle of a Day in some calendars and locales.
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation as a suitable alternative
    /// - Note: Since this API is under consideration it may be either removed or revised in the near future
    open func nextWeekendAfter(_ date: Date, options: Options) -> DateInterval? {
        var range = _CFCalendarWeekendRange()
        let res = withUnsafeMutablePointer(to: &range) { rangep in
            return _CFCalendarGetNextWeekend(_cfObject, rangep)
        }
        if res {
            var comp = DateComponents()
            comp.weekday = range.start
            if let nextStart = nextDate(after: date, matching: comp, options: options.union(.matchNextTime)) {
                let start = nextStart + range.onsetTime
                comp.weekday = range.end
                if let nextEnd = nextDate(after: date, matching: comp, options: options.union(.matchNextTime)) {
                    var end = nextEnd
                    if end.compare(start) == .orderedAscending {
                        if let nextOrderedEnd = nextDate(after: end, matching: comp, options: options.union(.matchNextTime)) {
                            end = nextOrderedEnd
                        } else {
                            return nil
                        }
                    }
                    if range.ceaseTime > 0 {
                        end = end + range.ceaseTime
                    } else {
                        if let dayEnd = self.range(of: .day, for: end) {
                            end = startOfDay(for: dayEnd.end)
                        } else {
                            return nil
                        }
                    }
                    return DateInterval(start: start, end: end)
                }
            }
        }
        return nil
    }
    
    /*
    This API returns the difference between two dates specified as date components.
    For units which are not specified in each NSDateComponents, but required to specify an absolute date, the base value of the unit is assumed.  For example, for an NSDateComponents with just a Year and a Month specified, a Day of 1, and an Hour, Minute, Second, and Nanosecond of 0 are assumed.
    Calendrical calculations with unspecified Year or Year value prior to the start of a calendar are not advised.
    For each date components object, if its time zone property is set, that time zone is used for it; if the calendar property is set, that is used rather than the receiving calendar, and if both the calendar and time zone are set, the time zone property value overrides the time zone of the calendar property.
    No options are currently defined; pass 0.
    */
    open func components(_ unitFlags: Unit, from startingDateComp: DateComponents, to resultDateComp: DateComponents, options: Options = []) -> DateComponents {
        var startDate: Date?
        var toDate: Date?
        if let startCalendar = startingDateComp.calendar {
            startDate = startCalendar.date(from: startingDateComp)
        } else {
            startDate = date(from: startingDateComp)
        }
        if let toCalendar = resultDateComp.calendar {
            toDate = toCalendar.date(from: resultDateComp)
        } else {
            toDate = date(from: resultDateComp)
        }
        if let start = startDate {
            if let end = toDate {
                return components(unitFlags, from: start, to: end, options: options)
            }
        }
        fatalError()
    }
    
    /*
    This API returns a new NSDate object representing the date calculated by adding an amount of a specific component to a given date.
    The NSCalendarWrapComponents option specifies if the component should be incremented and wrap around to zero/one on overflow, and should not cause higher units to be incremented.
    */
    open func date(byAdding unit: Unit, value: Int, to date: Date, options: Options = []) -> Date? {
        var comps = DateComponents()
        comps.setValue(value, for: Calendar._fromCalendarUnit(unit))
        return self.date(byAdding: comps, to: date, options: options)
    }
    
    /*
    This method computes the dates which match (or most closely match) a given set of components, and calls the block once for each of them, until the enumeration is stopped.
    There will be at least one intervening date which does not match all the components (or the given date itself must not match) between the given date and any result.
    If the NSCalendarSearchBackwards option is used, this method finds the previous match before the given date.  The intent is that the same matches as for a forwards search will be found (that is, if you are enumerating forwards or backwards for each hour with minute "27", the seconds in the date you will get in forwards search would obviously be 00, and the same will be true in a backwards search in order to implement this rule.  Similarly for DST backwards jumps which repeats times, you'll get the first match by default, where "first" is defined from the point of view of searching forwards.  So, when searching backwards looking for a particular hour, with no minute and second specified, you don't get a minute and second of 59:59 for the matching hour (which would be the nominal first match within a given hour, given the other rules here, when searching backwards).
    If the NSCalendarMatchStrictly option is used, the algorithm travels as far forward or backward as necessary looking for a match, but there are ultimately implementation-defined limits in how far distant the search will go.  If the NSCalendarMatchStrictly option is not specified, the algorithm searches up to the end of the next instance of the next higher unit to the highest specified unit in the NSDateComponents argument.  If you want to find the next Feb 29 in the Gregorian calendar, for example, you have to specify the NSCalendarMatchStrictly option to guarantee finding it.
    If an exact match is not possible, and requested with the NSCalendarMatchStrictly option, nil is passed to the block and the enumeration ends.  (Logically, since an exact match searches indefinitely into the future, if no match is found there's no point in continuing the enumeration.)
    
    If the NSCalendarMatchStrictly option is NOT used, exactly one option from the set {NSCalendarMatchPreviousTimePreservingSmallerUnits, NSCalendarMatchNextTimePreservingSmallerUnits, NSCalendarMatchNextTime} must be specified, or an illegal argument exception will be thrown.
    
    If the NSCalendarMatchPreviousTimePreservingSmallerUnits option is specified, and there is no matching time before the end of the next instance of the next higher unit to the highest specified unit in the NSDateComponents argument, the method will return the previous existing value of the missing unit and preserves the lower units' values (e.g., no 2:37am results in 1:37am, if that exists).
    
    If the NSCalendarMatchNextTimePreservingSmallerUnits option is specified, and there is no matching time before the end of the next instance of the next higher unit to the highest specified unit in the NSDateComponents argument, the method will return the next existing value of the missing unit and preserves the lower units' values (e.g., no 2:37am results in 3:37am, if that exists).
    
    If the NSCalendarMatchNextTime option is specified, and there is no matching time before the end of the next instance of the next higher unit to the highest specified unit in the NSDateComponents argument, the method will return the next existing time which exists (e.g., no 2:37am results in 3:00am, if that exists).
    If the NSCalendarMatchFirst option is specified, and there are two or more matching times (all the components are the same, including isLeapMonth) before the end of the next instance of the next higher unit to the highest specified unit in the NSDateComponents argument, the method will return the first occurrence.
    If the NSCalendarMatchLast option is specified, and there are two or more matching times (all the components are the same, including isLeapMonth) before the end of the next instance of the next higher unit to the highest specified unit in the NSDateComponents argument, the method will return the last occurrence.
    If neither the NSCalendarMatchFirst or NSCalendarMatchLast option is specified, the default behavior is to act as if NSCalendarMatchFirst was specified.
    There is no option to return middle occurrences of more than two occurrences of a matching time, if such exist.
    
    Result dates have an integer number of seconds (as if 0 was specified for the nanoseconds property of the NSDateComponents matching parameter), unless a value was set in the nanoseconds property, in which case the result date will have that number of nanoseconds (or as close as possible with floating point numbers).
    The enumeration is stopped by setting *stop = YES in the block and return.  It is not necessary to set *stop to NO to keep the enumeration going.
    */
    open func enumerateDates(startingAfter start: Date, matching comps: DateComponents, options opts: NSCalendar.Options = [], using block: (Date?, Bool, UnsafeMutablePointer<ObjCBool>) -> Swift.Void) {
        NSUnimplemented()
    }
    
    /*
    This method computes the next date which matches (or most closely matches) a given set of components.
    The general semantics follow those of the -enumerateDatesStartingAfterDate:... method above.
    To compute a sequence of results, use the -enumerateDatesStartingAfterDate:... method above, rather than looping and calling this method with the previous loop iteration's result.
    */
    open func nextDate(after date: Date, matching comps: DateComponents, options: Options = []) -> Date? {
        var result: Date?
        enumerateDates(startingAfter: date, matching: comps, options: options) { date, exactMatch, stop in
            result = date
            stop.pointee = true
        }
        return result
    }
    
    /*
    This API returns a new NSDate object representing the date found which matches a specific component value.
    The general semantics follow those of the -enumerateDatesStartingAfterDate:... method above.
    To compute a sequence of results, use the -enumerateDatesStartingAfterDate:... method above, rather than looping and calling this method with the previous loop iteration's result.
    */
    open func nextDate(after date: Date, matching unit: Unit, value: Int, options: Options = []) -> Date? {
        var comps = DateComponents()
        comps.setValue(value, for: Calendar._fromCalendarUnit(unit))
        return nextDate(after:date, matching: comps, options: options)
    }
    
    /*
    This API returns a new NSDate object representing the date found which matches the given hour, minute, and second values.
    The general semantics follow those of the -enumerateDatesStartingAfterDate:... method above.
    To compute a sequence of results, use the -enumerateDatesStartingAfterDate:... method above, rather than looping and calling this method with the previous loop iteration's result.
    */
    open func nextDate(after date: Date, matchingHour hourValue: Int, minute minuteValue: Int, second secondValue: Int, options: Options = []) -> Date? {
        var comps = DateComponents()
        comps.hour = hourValue
        comps.minute = minuteValue
        comps.second = secondValue
        return nextDate(after: date, matching: comps, options: options)
    }
    
    /*
    This API returns a new NSDate object representing the date calculated by setting a specific component to a given time, and trying to keep lower components the same.  If the unit already has that value, this may result in a date which is the same as the given date.
    Changing a component's value often will require higher or coupled components to change as well.  For example, setting the Weekday to Thursday usually will require the Day component to change its value, and possibly the Month and Year as well.
    If no such time exists, the next available time is returned (which could, for example, be in a different day, week, month, ... than the nominal target date).  Setting a component to something which would be inconsistent forces other units to change; for example, setting the Weekday to Thursday probably shifts the Day and possibly Month and Year.
    The specific behaviors here are as yet unspecified; for example, if I change the weekday to Thursday, does that move forward to the next, backward to the previous, or to the nearest Thursday?  A likely rule is that the algorithm will try to produce a result which is in the next-larger unit to the one given (there's a table of this mapping at the top of this document).  So for the "set to Thursday" example, find the Thursday in the Week in which the given date resides (which could be a forwards or backwards move, and not necessarily the nearest Thursday).  For forwards or backwards behavior, one can use the -nextDateAfterDate:matchingUnit:value:options: method above.
    */
    open func date(bySettingUnit unit: Unit, value v: Int, of date: Date, options opts: Options = []) -> Date? {
        let currentValue = component(unit, from: date)
        if currentValue == v {
            return date
        }
        var targetComp = DateComponents()
        targetComp.setValue(v, for: Calendar._fromCalendarUnit(unit))
        var result: Date?
        enumerateDates(startingAfter: date, matching: targetComp, options: .matchNextTime) { date, match, stop in
            result = date
            stop.pointee = true
        }
        return result
    }
    
    /*
    This API returns a new NSDate object representing the date calculated by setting hour, minute, and second to a given time.
    If no such time exists, the next available time is returned (which could, for example, be in a different day than the nominal target date).
    The intent is to return a date on the same day as the original date argument.  This may result in a date which is earlier than the given date, of course.
    */
    open func date(bySettingHour h: Int, minute m: Int, second s: Int, of date: Date, options opts: Options = []) -> Date? {
        if let range = range(of: .day, for: date) {
            var comps = DateComponents()
            comps.hour = h
            comps.minute = m
            comps.second = s
            var options: Options = .matchNextTime
            options.formUnion(opts.contains(.matchLast) ? .matchLast : .matchFirst)
            if opts.contains(.matchStrictly) {
                options.formUnion(.matchStrictly)
            }
            if let result = nextDate(after: range.start - 0.5, matching: comps, options: options) {
                if result.compare(range.start) == .orderedAscending {
                    return nextDate(after: range.start, matching: comps, options: options)
                }
                return result
            }
            
        }
        return nil
    }
    
    /*
    This API returns YES if the date has all the matched components. Otherwise, it returns NO.
    It is useful to test the return value of the -nextDateAfterDate:matchingUnit:value:options:, to find out if the components were obeyed or if the method had to fudge the result value due to missing time.
    */
    open func date(_ date: Date, matchesComponents components: DateComponents) -> Bool {
        let units: [Unit] = [.era, .year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .nanosecond]
        var unitFlags: Unit = []
        for unit in units {
            if components.value(for: Calendar._fromCalendarUnit(unit)) != NSDateComponentUndefined {
                unitFlags.formUnion(unit)
            }
        }
        if unitFlags == [] {
            if components.isLeapMonth != nil {
                let comp = self.components(.month, from: date)
                if let leap = comp.isLeapMonth {
                    return leap
                }
                return false
            }
        }
        let comp = self.components(unitFlags, from: date)
        var compareComp = comp
        var tempComp = components
        tempComp.isLeapMonth = comp.isLeapMonth
        if let nanosecond = comp.value(for: .nanosecond) {
            if labs(nanosecond - tempComp.value(for: .nanosecond)!) > 500 {
                return false
            } else {
                compareComp.nanosecond = 0
                tempComp.nanosecond = 0
            }
            return tempComp == compareComp
        }
        return false
    }
    
}

// This notification is posted through [NSNotificationCenter defaultCenter]
// when the system day changes. Register with "nil" as the object of this
// notification. If the computer/device is asleep when the day changed,
// this will be posted on wakeup. You'll get just one of these if the
// machine has been asleep for several days. The definition of "Day" is
// relative to the current calendar ([NSCalendar currentCalendar]) of the
// process and its locale and time zone. There are no guarantees that this
// notification is received by observers in a "timely" manner, same as
// with distributed notifications.

extension NSNotification.Name {
    public static let NSCalendarDayChanged = NSNotification.Name(rawValue: "NSCalendarDayChangedNotification")
}

// This is a just used as an extensible struct, basically;
// note that there are two uses: one for specifying a date
// via components (some components may be missing, making the
// specific date ambiguous), and the other for specifying a
// set of component quantities (like, 3 months and 5 hours).
// Undefined fields have (or fields can be set to) the value
// NSDateComponentUndefined.

// NSDateComponents is not responsible for answering questions
// about a date beyond the information it has been initialized
// with; for example, if you initialize one with May 6, 2004,
// and then ask for the weekday, you'll get Undefined, not Thurs.
// A NSDateComponents is meaningless in itself, because you need
// to know what calendar it is interpreted against, and you need
// to know whether the values are absolute values of the units,
// or quantities of the units.
// When you create a new one of these, all values begin Undefined.

public var NSDateComponentUndefined: Int = Int.max

open class NSDateComponents : NSObject, NSCopying, NSSecureCoding {
    internal var _calendar: Calendar?
    internal var _timeZone: TimeZone?
    internal var _values = [Int](repeating: NSDateComponentUndefined, count: 19)
    public override init() {
        super.init()
    }
    
    open override var hash: Int {
        var calHash = 0
        if let cal = calendar {
            calHash = cal.hashValue
        }
        if let tz = timeZone {
            calHash ^= tz.hashValue
        }
        var y = year
        if NSDateComponentUndefined == y {
            y = 0
        }
        var m = month
        if NSDateComponentUndefined == m {
            m = 0
        }
        var d = day
        if NSDateComponentUndefined == d {
            d = 0
        }
        var h = hour
        if NSDateComponentUndefined == h {
            h = 0
        }
        var mm = minute
        if NSDateComponentUndefined == mm {
            mm = 0 
        }
        var s = second
        if NSDateComponentUndefined == s {
            s = 0 
        }
        var yy = yearForWeekOfYear
        if NSDateComponentUndefined == yy {
            yy = 0
        }
        return calHash + (32832013 * (y + yy) + 2678437 * m + 86413 * d + 3607 * h + 61 * mm + s) + (41 * weekOfYear + 11 * weekOfMonth + 7 * weekday + 3 * weekdayOrdinal + quarter) * (1 << 5)
    }
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? NSDateComponents else { return false }
        
        return self === other
            || (era == other.era
                && year == other.year
                && quarter == other.quarter
                && month == other.month
                && day == other.day
                && hour == other.hour
                && minute == other.minute
                && second == other.second
                && nanosecond == other.nanosecond
                && weekOfYear == other.weekOfYear
                && weekOfMonth == other.weekOfMonth
                && yearForWeekOfYear == other.yearForWeekOfYear
                && weekday == other.weekday
                && weekdayOrdinal == other.weekdayOrdinal
                && isLeapMonth == other.isLeapMonth
                && calendar == other.calendar
                && timeZone == other.timeZone)
    }
    
    public convenience required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }

        self.init()

        self.era = aDecoder.decodeInteger(forKey: "NS.era")
        self.year = aDecoder.decodeInteger(forKey: "NS.year")
        self.quarter = aDecoder.decodeInteger(forKey: "NS.quarter")
        self.month = aDecoder.decodeInteger(forKey: "NS.month")
        self.day = aDecoder.decodeInteger(forKey: "NS.day")
        self.hour = aDecoder.decodeInteger(forKey: "NS.hour")
        self.minute = aDecoder.decodeInteger(forKey: "NS.minute")
        self.second = aDecoder.decodeInteger(forKey: "NS.second")
        self.nanosecond = aDecoder.decodeInteger(forKey: "NS.nanosec")
        self.weekOfYear = aDecoder.decodeInteger(forKey: "NS.weekOfYear")
        self.weekOfMonth = aDecoder.decodeInteger(forKey: "NS.weekOfMonth")
        self.yearForWeekOfYear = aDecoder.decodeInteger(forKey: "NS.yearForWOY")
        self.weekday = aDecoder.decodeInteger(forKey: "NS.weekday")
        self.weekdayOrdinal = aDecoder.decodeInteger(forKey: "NS.weekdayOrdinal")
        self.isLeapMonth = aDecoder.decodeBool(forKey: "NS.isLeapMonth")
        self.calendar = aDecoder.decodeObject(of: NSCalendar.self, forKey: "NS.calendar")?._swiftObject
        self.timeZone = aDecoder.decodeObject(of: NSTimeZone.self, forKey: "NS.timezone")?._swiftObject
    }
    
    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        aCoder.encode(self.era, forKey: "NS.era")
        aCoder.encode(self.year, forKey: "NS.year")
        aCoder.encode(self.quarter, forKey: "NS.quarter")
        aCoder.encode(self.month, forKey: "NS.month")
        aCoder.encode(self.day, forKey: "NS.day")
        aCoder.encode(self.hour, forKey: "NS.hour")
        aCoder.encode(self.minute, forKey: "NS.minute")
        aCoder.encode(self.second, forKey: "NS.second")
        aCoder.encode(self.nanosecond, forKey: "NS.nanosec")
        aCoder.encode(self.weekOfYear, forKey: "NS.weekOfYear")
        aCoder.encode(self.weekOfMonth, forKey: "NS.weekOfMonth")
        aCoder.encode(self.yearForWeekOfYear, forKey: "NS.yearForWOY")
        aCoder.encode(self.weekday, forKey: "NS.weekday")
        aCoder.encode(self.weekdayOrdinal, forKey: "NS.weekdayOrdinal")
        aCoder.encode(self.isLeapMonth, forKey: "NS.isLeapMonth")
        aCoder.encode(self.calendar?._nsObject, forKey: "NS.calendar")
        aCoder.encode(self.timeZone?._nsObject, forKey: "NS.timezone")
    }
    
    static public var supportsSecureCoding: Bool {
        return true
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        let newObj = NSDateComponents()
        newObj.calendar = calendar
        newObj.timeZone = timeZone
        newObj.era = era
        newObj.year = year
        newObj.month = month
        newObj.day = day
        newObj.hour = hour
        newObj.minute = minute
        newObj.second = second
        newObj.nanosecond = nanosecond
        newObj.weekOfYear = weekOfYear
        newObj.weekOfMonth = weekOfMonth
        newObj.yearForWeekOfYear = yearForWeekOfYear
        newObj.weekday = weekday
        newObj.weekdayOrdinal = weekdayOrdinal
        newObj.quarter = quarter
        if leapMonthSet {
            newObj.isLeapMonth = isLeapMonth
        }
        return newObj
    }
    
    /*@NSCopying*/ open var calendar: Calendar? {
        get {
            return _calendar
        }
        set {
            if let val = newValue {
                _calendar = val
            } else {
                _calendar = nil
            }
        }
    }
    /*@NSCopying*/ open var timeZone: TimeZone?
    
    open var era: Int {
        get {
            return _values[0]
        }
        set {
            _values[0] = newValue
        }
    }
    
    open var year: Int {
        get {
            return _values[1]
        }
        set {
            _values[1] = newValue
        }
    }
    
    open var month: Int {
        get {
            return _values[2]
        }
        set {
            _values[2] = newValue
        }
    }
    
    open var day: Int {
        get {
            return _values[3]
        }
        set {
            _values[3] = newValue
        }
    }
    
    open var hour: Int {
        get {
            return _values[4]
        }
        set {
            _values[4] = newValue
        }
    }
    
    open var minute: Int {
        get {
            return _values[5]
        }
        set {
            _values[5] = newValue
        }
    }
    
    open var second: Int {
        get {
            return _values[6]
        }
        set {
            _values[6] = newValue
        }
    }
    
    open var weekday: Int {
        get {
            return _values[8]
        }
        set {
            _values[8] = newValue
        }
    }
    
    open var weekdayOrdinal: Int {
        get {
            return _values[9]
        }
        set {
            _values[9] = newValue
        }
    }
    
    open var quarter: Int {
        get {
            return _values[10]
        }
        set {
            _values[10] = newValue
        }
    }
    
    open var nanosecond: Int {
        get {
            return _values[11]
        }
        set {
            _values[11] = newValue
        }
    }
    
    open var weekOfYear: Int {
        get {
            return _values[12]
        }
        set {
            _values[12] = newValue
        }
    }
    
    open var weekOfMonth: Int {
        get {
            return _values[13]
        }
        set {
            _values[13] = newValue
        }
    }
    
    open var yearForWeekOfYear: Int {
        get {
            return _values[14]
        }
        set {
            _values[14] = newValue
        }
    }
    
    open var isLeapMonth: Bool {
        get {
            return _values[15] == 1
        }
        set {
            _values[15] = newValue ? 1 : 0
        }
    }
    
    internal var leapMonthSet: Bool {
        return _values[15] != NSDateComponentUndefined
    }
    
    /*@NSCopying*/ open var date: Date? {
        if let tz = timeZone {
            calendar?.timeZone = tz
        }
        return calendar?.date(from: self._swiftObject)
    }
    
    /*
    This API allows one to set a specific component of NSDateComponents, by enum constant value rather than property name.
    The calendar and timeZone and isLeapMonth properties cannot be set by this method.
    */
    open func setValue(_ value: Int, forComponent unit: NSCalendar.Unit) {
        switch unit {
            case .era:
                era = value
            case .year:
                year = value
            case .month:
                month = value
            case .day:
                day = value
            case .hour:
                hour = value
            case .minute:
                minute = value
            case .second:
                second = value
            case .nanosecond:
                nanosecond = value
            case .weekday:
                weekday = value
            case .weekdayOrdinal:
                weekdayOrdinal = value
            case .quarter:
                quarter = value
            case .weekOfMonth:
                weekOfMonth = value
            case .weekOfYear:
                weekOfYear = value
            case .yearForWeekOfYear:
                yearForWeekOfYear = value
            case .calendar:
                print(".Calendar cannot be set via \(#function)")
            case .timeZone:
                print(".TimeZone cannot be set via \(#function)")
            default:
                break
        }
    }
    
    /*
    This API allows one to get the value of a specific component of NSDateComponents, by enum constant value rather than property name.
    The calendar and timeZone and isLeapMonth property values cannot be gotten by this method.
    */
    open func value(forComponent unit: NSCalendar.Unit) -> Int {
        switch unit {
            case .era:
                return era
            case .year:
                return year
            case .month:
                return month
            case .day:
                return day
            case .hour:
                return hour
            case .minute:
                return minute
            case .second:
                return second
            case .nanosecond:
                return nanosecond
            case .weekday:
                return weekday
            case .weekdayOrdinal:
                return weekdayOrdinal
            case .quarter:
                return quarter
            case .weekOfMonth:
                return weekOfMonth
            case .weekOfYear:
                return weekOfYear
            case .yearForWeekOfYear:
                return yearForWeekOfYear
            default:
                break
        }
        return NSDateComponentUndefined
    }
    
    /*
    Reports whether or not the combination of properties which have been set in the receiver is a date which exists in the calendar.
    This method is not appropriate for use on NSDateComponents objects which are specifying relative quantities of calendar components.
    Except for some trivial cases (e.g., 'seconds' should be 0 - 59 in any calendar), this method is not necessarily cheap.
    If the time zone property is set in the NSDateComponents object, it is used.
    The calendar property must be set, or NO is returned.
    */
    open var isValidDate: Bool {
        if let cal = calendar {
            return isValidDate(in: cal)
        }
        return false
    }
    
    /*
    Reports whether or not the combination of properties which have been set in the receiver is a date which exists in the calendar.
    This method is not appropriate for use on NSDateComponents objects which are specifying relative quantities of calendar components.
    Except for some trivial cases (e.g., 'seconds' should be 0 - 59 in any calendar), this method is not necessarily cheap.
    If the time zone property is set in the NSDateComponents object, it is used.
    */
    open func isValidDate(in calendar: Calendar) -> Bool {
        var cal = calendar
        if let tz = timeZone {
            cal.timeZone = tz
        }
        let ns = nanosecond
        if ns != NSDateComponentUndefined && 1000 * 1000 * 1000 <= ns {
            return false
        }
        if ns != NSDateComponentUndefined && 0 < ns {
            nanosecond = 0
        }
        let d = calendar.date(from: self._swiftObject)
        if ns != NSDateComponentUndefined && 0 < ns {
            nanosecond = ns
        }
        if let date = d {
            let all: NSCalendar.Unit = [.era, .year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear]
            let comps = calendar._bridgeToObjectiveC().components(all, from: date)
            var val = era
            if val != NSDateComponentUndefined {
                if comps.era != val {
                    return false
                }
            }
            val = year
            if val != NSDateComponentUndefined {
                if comps.year != val {
                    return false
                }
            }
            val = month
            if val != NSDateComponentUndefined {
                if comps.month != val {
                    return false
                }
            }
            if leapMonthSet {
                if comps.isLeapMonth != isLeapMonth {
                    return false
                }
            }
            val = day
            if val != NSDateComponentUndefined {
                if comps.day != val {
                    return false
                }
            }
            val = hour
            if val != NSDateComponentUndefined {
                if comps.hour != val {
                    return false
                }
            }
            val = minute
            if val != NSDateComponentUndefined {
                if comps.minute != val {
                    return false
                }
            }
            val = second
            if val != NSDateComponentUndefined {
                if comps.second != val {
                    return false
                }
            }
            val = weekday
            if val != NSDateComponentUndefined {
                if comps.weekday != val {
                    return false
                }
            }
            val = weekdayOrdinal
            if val != NSDateComponentUndefined {
                if comps.weekdayOrdinal != val {
                    return false
                }
            }
            val = quarter
            if val != NSDateComponentUndefined {
                if comps.quarter != val {
                    return false
                }
            }
            val = weekOfMonth
            if val != NSDateComponentUndefined {
                if comps.weekOfMonth != val {
                    return false
                }
            }
            val = weekOfYear
            if val != NSDateComponentUndefined {
                if comps.weekOfYear != val {
                    return false
                }
            }
            val = yearForWeekOfYear
            if val != NSDateComponentUndefined {
                if comps.yearForWeekOfYear != val {
                    return false
                }
            }
            
            return true
        }
        return false
    }
}

extension NSDateComponents : _SwiftBridgeable {
    typealias SwiftType = DateComponents
    var _swiftObject: SwiftType { return DateComponents(reference: self) }
}

extension DateComponents : _NSBridgeable {
    typealias NSType = NSDateComponents
    var _nsObject: NSType { return _bridgeToObjectiveC() }
}

extension NSCalendar: _SwiftBridgeable, _CFBridgeable {
    typealias SwiftType = Calendar
    var _swiftObject: SwiftType { return Calendar(reference: self) }
}
extension Calendar: _NSBridgeable, _CFBridgeable {
    typealias NSType = NSCalendar
    typealias CFType = CFCalendar
    var _nsObject: NSCalendar { return _bridgeToObjectiveC() }
    var _cfObject: CFCalendar { return _nsObject._cfObject }
}

extension CFCalendar : _NSBridgeable, _SwiftBridgeable {
    typealias NSType = NSCalendar
    internal var _nsObject: NSType { return unsafeBitCast(self, to: NSType.self) }
    internal var _swiftObject: Calendar { return _nsObject._swiftObject }
}

extension NSCalendar : _StructTypeBridgeable {
    public typealias _StructType = Calendar
    
    public func _bridgeToSwift() -> Calendar {
        return Calendar._unconditionallyBridgeFromObjectiveC(self)
    }
}

extension NSDateComponents : _StructTypeBridgeable {
    public typealias _StructType = DateComponents
    
    public func _bridgeToSwift() -> DateComponents {
        return DateComponents._unconditionallyBridgeFromObjectiveC(self)
    }
}

extension NSCalendar : _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as Calendar)
    }
}

extension NSDateComponents : _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(_bridgeToSwift())
    }
}
