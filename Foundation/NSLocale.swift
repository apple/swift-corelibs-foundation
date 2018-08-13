// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


import CoreFoundation

open class NSLocale: NSObject, NSCopying, NSSecureCoding {
    typealias CFType = CFLocale
    private var _base = _CFInfo(typeID: CFLocaleGetTypeID())
    private var _identifier: UnsafeMutableRawPointer? = nil
    private var _cache: UnsafeMutableRawPointer? = nil
    private var _prefs: UnsafeMutableRawPointer? = nil
#if os(macOS) || os(iOS)
    private var _lock = pthread_mutex_t()
#elseif os(Linux) || os(Android) || CYGWIN
    private var _lock = Int32(0)
#endif
    private var _nullLocale = false
    
    internal var _cfObject: CFType {
        return unsafeBitCast(self, to: CFType.self)
    }
    
    open func object(forKey key: NSLocale.Key) -> Any? {
        return _SwiftValue.fetch(CFLocaleGetValue(_cfObject, key.rawValue._cfObject))
    }
    
    open func displayName(forKey key: Key, value: String) -> String? {
        return CFLocaleCopyDisplayNameForPropertyValue(_cfObject, key.rawValue._cfObject, value._cfObject)?._swiftObject
    }
    
    public init(localeIdentifier string: String) {
        super.init()
        _CFLocaleInit(_cfObject, string._cfObject)
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        guard let identifier = aDecoder.decodeObject(of: NSString.self, forKey: "NS.identifier") else {
            return nil
        }
        self.init(localeIdentifier: String._unconditionallyBridgeFromObjectiveC(identifier))
    }
    
    deinit {
        _CFDeinit(self)
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any { 
        return self 
    }
    
    override open func isEqual(_ object: Any?) -> Bool {
        guard let locale = object as? NSLocale else {
            return false
        }
        
        return locale.localeIdentifier == localeIdentifier
    }

    override open var hash: Int {
        return localeIdentifier.hash
    }

    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        let identifier = CFLocaleGetIdentifier(self._cfObject)._nsObject
        aCoder.encode(identifier, forKey: "NS.identifier")
    }
    
    public static var supportsSecureCoding: Bool {
        return true
    }
}

extension NSLocale {
    open class var current: Locale {
        return CFLocaleCopyCurrent()._swiftObject
    }
    
    open class var system: Locale {
        return CFLocaleGetSystem()._swiftObject
    }
}

extension NSLocale {
    public var localeIdentifier: String {
        return object(forKey: .identifier) as! String
    }
    
    open class var availableLocaleIdentifiers: [String] {
        return _SwiftValue.fetch(CFLocaleCopyAvailableLocaleIdentifiers()) as? [String] ?? []
    }
    
    open class var isoLanguageCodes: [String] {
        return _SwiftValue.fetch(CFLocaleCopyISOLanguageCodes()) as? [String] ?? []
    }
    
    open class var isoCountryCodes: [String] {
        return _SwiftValue.fetch(CFLocaleCopyISOCountryCodes()) as? [String] ?? []
    }
    
    open class var isoCurrencyCodes: [String] {
        return _SwiftValue.fetch(CFLocaleCopyISOCurrencyCodes()) as? [String] ?? []
    }
    
    open class var commonISOCurrencyCodes: [String] {
        return _SwiftValue.fetch(CFLocaleCopyCommonISOCurrencyCodes()) as? [String] ?? []
    }
    
    open class var preferredLanguages: [String] {
        return _SwiftValue.fetch(CFLocaleCopyPreferredLanguages()) as? [String] ?? []
    }
    
    open class func components(fromLocaleIdentifier string: String) -> [String : String] {
        return _SwiftValue.fetch(CFLocaleCreateComponentsFromLocaleIdentifier(kCFAllocatorSystemDefault, string._cfObject)) as? [String : String] ?? [:] 
    }
    
    open class func localeIdentifier(fromComponents dict: [String : String]) -> String {
        return CFLocaleCreateLocaleIdentifierFromComponents(kCFAllocatorSystemDefault, dict._cfObject)._swiftObject
    }
    
    open class func canonicalLocaleIdentifier(from string: String) -> String {
        return CFLocaleCreateCanonicalLocaleIdentifierFromString(kCFAllocatorSystemDefault, string._cfObject)._swiftObject
    }
    
    open class func canonicalLanguageIdentifier(from string: String) -> String {
        return CFLocaleCreateCanonicalLanguageIdentifierFromString(kCFAllocatorSystemDefault, string._cfObject)._swiftObject
    }
    
    open class func localeIdentifier(fromWindowsLocaleCode lcid: UInt32) -> String? {
        return CFLocaleCreateLocaleIdentifierFromWindowsLocaleCode(kCFAllocatorSystemDefault, lcid)._swiftObject
    }
    
    open class func windowsLocaleCode(fromLocaleIdentifier localeIdentifier: String) -> UInt32 {
        return CFLocaleGetWindowsLocaleCodeFromLocaleIdentifier(localeIdentifier._cfObject)
    }
    
    open class func characterDirection(forLanguage isoLangCode: String) -> NSLocale.LanguageDirection {
        let dir = CFLocaleGetLanguageCharacterDirection(isoLangCode._cfObject)
#if os(macOS) || os(iOS)
        return NSLocale.LanguageDirection(rawValue: UInt(dir.rawValue))!
#else
        return NSLocale.LanguageDirection(rawValue: UInt(dir))!
#endif
    }
    
    open class func lineDirection(forLanguage isoLangCode: String) -> NSLocale.LanguageDirection {
        let dir = CFLocaleGetLanguageLineDirection(isoLangCode._cfObject)
#if os(macOS) || os(iOS)
        return NSLocale.LanguageDirection(rawValue: UInt(dir.rawValue))!
#else
        return NSLocale.LanguageDirection(rawValue: UInt(dir))!
#endif
    }
}

extension NSLocale {

    public struct Key : RawRepresentable, Equatable, Hashable {
        public private(set) var rawValue: String
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        public var hashValue: Int {
            return rawValue.hashValue
        }
        
        public static let identifier = NSLocale.Key(rawValue: "kCFLocaleIdentifierKey")
        public static let languageCode = NSLocale.Key(rawValue: "kCFLocaleLanguageCodeKey")
        public static let countryCode = NSLocale.Key(rawValue: "kCFLocaleCountryCodeKey")
        public static let scriptCode = NSLocale.Key(rawValue: "kCFLocaleScriptCodeKey")
        public static let variantCode = NSLocale.Key(rawValue: "kCFLocaleVariantCodeKey")
        public static let exemplarCharacterSet = NSLocale.Key(rawValue: "kCFLocaleExemplarCharacterSetKey")
        public static let calendar = NSLocale.Key(rawValue: "kCFLocaleCalendarKey")
        public static let collationIdentifier = NSLocale.Key(rawValue: "collation")
        public static let usesMetricSystem = NSLocale.Key(rawValue: "kCFLocaleUsesMetricSystemKey")
        public static let measurementSystem = NSLocale.Key(rawValue: "kCFLocaleMeasurementSystemKey")
        public static let decimalSeparator = NSLocale.Key(rawValue: "kCFLocaleDecimalSeparatorKey")
        public static let groupingSeparator = NSLocale.Key(rawValue: "kCFLocaleGroupingSeparatorKey")
        public static let currencySymbol = NSLocale.Key(rawValue: "kCFLocaleCurrencySymbolKey")
        public static let currencyCode = NSLocale.Key(rawValue: "currency")
        public static let collatorIdentifier = NSLocale.Key(rawValue: "kCFLocaleCollatorIdentifierKey")
        public static let quotationBeginDelimiterKey = NSLocale.Key(rawValue: "kCFLocaleQuotationBeginDelimiterKey")
        public static let quotationEndDelimiterKey = NSLocale.Key(rawValue: "kCFLocaleQuotationEndDelimiterKey")
        public static let calendarIdentifier = NSLocale.Key(rawValue: "kCFLocaleCalendarIdentifierKey")
        public static let alternateQuotationBeginDelimiterKey = NSLocale.Key(rawValue: "kCFLocaleAlternateQuotationBeginDelimiterKey")
        public static let alternateQuotationEndDelimiterKey = NSLocale.Key(rawValue: "kCFLocaleAlternateQuotationEndDelimiterKey")
    }
    
    public enum LanguageDirection : UInt {
        case unknown
        case leftToRight
        case rightToLeft
        case topToBottom
        case bottomToTop
    }
}


extension NSLocale.Key {
    public static func ==(_ lhs: NSLocale.Key, _ rhs: NSLocale.Key) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}


public extension NSLocale {
    public static let currentLocaleDidChangeNotification = NSNotification.Name(rawValue: "kCFLocaleCurrentLocaleDidChangeNotification")
}


extension CFLocale : _NSBridgeable, _SwiftBridgeable {
    typealias NSType = NSLocale
    typealias SwiftType = Locale
    internal var _nsObject: NSLocale {
        return unsafeBitCast(self, to: NSType.self)
    }
    internal var _swiftObject: Locale {
        return _nsObject._swiftObject
    }
}

extension NSLocale : _SwiftBridgeable {
    typealias SwiftType = Locale
    internal var _swiftObject: Locale {
        return Locale(reference: self)
    }
}

extension Locale : _CFBridgeable {
    typealias CFType = CFLocale
    internal var _cfObject: CFLocale {
        return _bridgeToObjectiveC()._cfObject
    }
}

extension NSLocale : _StructTypeBridgeable {
    public typealias _StructType = Locale
    
    public func _bridgeToSwift() -> Locale {
        return Locale._unconditionallyBridgeFromObjectiveC(self)
    }
}

extension NSLocale : _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as Locale)
    }
}
