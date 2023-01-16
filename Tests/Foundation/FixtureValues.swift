// This source file is part of the Swift.org open source project
//
// Copyright (c) 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

// Please keep this import statement as-is; this file is also used by the GenerateTestFixtures project, which doesn't have TestImports.swift.

#if canImport(SwiftFoundation)
    import SwiftFoundation
#else
    import Foundation
#endif

// -----

extension Calendar {
    static var neutral: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = NSLocale.system
        return calendar
    }
}

enum Fixtures {
    static let mutableAttributedString = TypedFixture<NSMutableAttributedString>("NSMutableAttributedString") {
        let string = NSMutableAttributedString(string: "0123456789")
        // Should have:                                 .xyyzzxyx.
        
        let attrs1: [NSAttributedString.Key: Any] = [.init("Font"): "Helvetica", .init("Size"): 123]
        let attrs2: [NSAttributedString.Key: Any] = [.init("Font"): "Times", .init("Size"): 456]
        
        let attrs3NS = attrs2 as NSDictionary
        let attrs3Maybe: [NSAttributedString.Key: Any]?
        if let attrs3Swift = attrs3NS as? [String: Any] {
            attrs3Maybe = Dictionary(attrs3Swift.map { (NSAttributedString.Key($0.key), $0.value) }, uniquingKeysWith: { $1 })
        } else {
            attrs3Maybe = nil
        }
        
        let attrs3 = try XCTUnwrap(attrs3Maybe)
        
        string.setAttributes(attrs1, range: NSMakeRange(1, string.length - 2))
        string.setAttributes(attrs2, range: NSMakeRange(2, 2))
        string.setAttributes(attrs3, range: NSMakeRange(4, 2))
        string.setAttributes(attrs2, range: NSMakeRange(8, 1))
        
        return string
    }
    
    static let attributedString = TypedFixture<NSAttributedString>("NSAttributedString") {
        return NSAttributedString(attributedString: try Fixtures.mutableAttributedString.make())
    }
    
    // ===== ByteCountFormatter =====
    
    static let byteCountFormatterDefault = TypedFixture<ByteCountFormatter>("ByteCountFormatter-Default") {
        return ByteCountFormatter()
    }
    
    static let byteCountFormatterAllFieldsSet = TypedFixture<ByteCountFormatter>("ByteCountFormatter-AllFieldsSet") {
        let f = ByteCountFormatter()
        
        f.allowedUnits = [.useBytes, .useKB]
        f.countStyle = .decimal
        f.formattingContext = .beginningOfSentence
        
        f.zeroPadsFractionDigits = true
        f.includesCount = true
        
        f.allowsNonnumericFormatting = false
        f.includesUnit = false
        f.includesCount = false
        f.isAdaptive = false
        
        return f
    }
    
    // ===== DateIntervalFormatter =====
    
    static let dateIntervalFormatterDefault = TypedFixture<DateIntervalFormatter>("DateIntervalFormatter-Default") {
        let dif = DateIntervalFormatter()
        
        let calendar = Calendar.neutral
        
        dif.calendar = calendar
        dif.timeZone = calendar.timeZone
        dif.locale = calendar.locale
        
        return dif
    }
    
    static let dateIntervalFormatterValuesSetWithoutTemplate = TypedFixture<DateIntervalFormatter>("DateIntervalFormatter-ValuesSetWithoutTemplate") {
        let dif = DateIntervalFormatter()
        
        var calendar = Calendar.neutral
        calendar.locale = Locale(identifier: "ja-JP")
        
        dif.calendar = calendar
        dif.timeZone = calendar.timeZone
        dif.locale = calendar.locale
        dif.dateStyle = .long
        dif.timeStyle = .none
        dif.timeZone = TimeZone(secondsFromGMT: 60 * 60)
        
        return dif
    }
    
    static let dateIntervalFormatterValuesSetWithTemplate = TypedFixture<DateIntervalFormatter>("DateIntervalFormatter-ValuesSetWithTemplate") {
        let dif = DateIntervalFormatter()

        var calendar = Calendar.neutral
        calendar.locale = Locale(identifier: "ja-JP")

        dif.calendar = calendar
        dif.timeZone = calendar.timeZone
        dif.locale = calendar.locale
        dif.dateTemplate = "dd mm yyyy HH:MM"
        dif.timeZone = TimeZone(secondsFromGMT: 60 * 60)
        
        return dif
    }
    
    // ===== ISO8601DateFormatter =====
    
    static let iso8601FormatterDefault = TypedFixture<ISO8601DateFormatter>("ISO8601DateFormatter-Default") {
        let idf = ISO8601DateFormatter()
        idf.timeZone = Calendar.neutral.timeZone
        
        return idf
    }
    
    static let iso8601FormatterOptionsSet = TypedFixture<ISO8601DateFormatter>("ISO8601DateFormatter-OptionsSet") {
        let idf = ISO8601DateFormatter()
        idf.timeZone = Calendar.neutral.timeZone
        
        idf.formatOptions = [ .withDay, .withWeekOfYear, .withMonth, .withTimeZone, .withColonSeparatorInTimeZone, .withDashSeparatorInDate ]
        
        return idf
    }
    
    // ===== NSTextCheckingResult =====
    
    static let textCheckingResultSimpleRegex = TypedFixture<NSTextCheckingResult>("NSTextCheckingResult-SimpleRegex") {
        let string = "aaa"
        let regexp = try NSRegularExpression(pattern: "aaa", options: [])
        let result = try XCTUnwrap(regexp.matches(in: string, range: NSRange(string.startIndex ..< string.endIndex, in: string)).first)
        
        return result
    }
    
    
    static let textCheckingResultExtendedRegex = TypedFixture<NSTextCheckingResult>("NSTextCheckingResult-ExtendedRegex") {
        let string = "aaaaaa"
        let regexp = try NSRegularExpression(pattern: "a(a(a(a(a(a)))))", options: [])
        let result = try XCTUnwrap(regexp.matches(in: string, range: NSRange(string.startIndex ..< string.endIndex, in: string)).first)
        
        return result
    }
    
    static let textCheckingResultComplexRegex = TypedFixture<NSTextCheckingResult>("NSTextCheckingResult-ComplexRegex") {
        let string = "aaaaaaaaa"
        let regexp = try NSRegularExpression(pattern: "a(a(a(a(a(a(a(a(a))))))))", options: [])
        let result = try XCTUnwrap(regexp.matches(in: string, range: NSRange(string.startIndex ..< string.endIndex, in: string)).first)
        
        return result
    }
    
    // ===== NSIndexSet =====
    
    static let indexSetEmpty = TypedFixture<NSIndexSet>("NSIndexSet-Empty") {
        return NSIndexSet(indexesIn: NSMakeRange(0, 0))
    }
    
    static let indexSetOneRange = TypedFixture<NSIndexSet>("NSIndexSet-OneRange") {
        return NSIndexSet(indexesIn: NSMakeRange(0, 50))
    }
    
    static let indexSetManyRanges = TypedFixture<NSIndexSet>("NSIndexSet-ManyRanges") {
        let indexSet = NSMutableIndexSet()
        indexSet.add(in: NSMakeRange(0, 50))
        indexSet.add(in: NSMakeRange(100, 50))
        indexSet.add(in: NSMakeRange(1000, 50))
        indexSet.add(in: NSMakeRange(Int.max - 50, 50))
        return indexSet.copy() as! NSIndexSet
    }
    
    static let mutableIndexSetEmpty = TypedFixture<NSMutableIndexSet>("NSMutableIndexSet-Empty") {
        return (try Fixtures.indexSetEmpty.make()).mutableCopy() as! NSMutableIndexSet
    }
    
    static let mutableIndexSetOneRange = TypedFixture<NSMutableIndexSet>("NSMutableIndexSet-OneRange") {
        return (try Fixtures.indexSetOneRange.make()).mutableCopy() as! NSMutableIndexSet
    }
    
    static let mutableIndexSetManyRanges = TypedFixture<NSMutableIndexSet>("NSMutableIndexSet-ManyRanges") {
        return (try Fixtures.indexSetManyRanges.make()).mutableCopy() as! NSMutableIndexSet
    }
    
    // ===== NSIndexPath =====
    
    static let indexPathEmpty = TypedFixture<NSIndexPath>("NSIndexPath-Empty") {
        return NSIndexPath()
    }
    
    static let indexPathOneIndex = TypedFixture<NSIndexPath>("NSIndexPath-OneIndex") {
        return NSIndexPath(index: 52)
    }
    
    static let indexPathManyIndices = TypedFixture<NSIndexPath>("NSIndexPath-ManyIndices") {
        var indexPath = IndexPath()
        indexPath.append([4, 8, 15, 16, 23, 42])
        return indexPath as NSIndexPath
    }
    
    // ===== NSSet, NSMutableSet =====
    
    static let setOfNumbers = TypedFixture<NSSet>("NSSet-Numbers") {
        let numbers = [1, 2, 3, 4, 5].map { NSNumber(value: $0) }
        return NSSet(array: numbers)
    }
    
    static let setEmpty = TypedFixture<NSSet>("NSSet-Empty") {
        return NSSet()
    }
    
    static let mutableSetOfNumbers = TypedFixture<NSMutableSet>("NSMutableSet-Numbers") {
        let numbers = [1, 2, 3, 4, 5].map { NSNumber(value: $0) }
        return NSMutableSet(array: numbers)
    }
    
    static let mutableSetEmpty = TypedFixture<NSMutableSet>("NSMutableSet-Empty") {
        return NSMutableSet()
    }
    
    // ===== NSCountedSet =====
    
    static let countedSetOfNumbersAppearingOnce = TypedFixture<NSCountedSet>("NSCountedSet-NumbersAppearingOnce") {
        let numbers = [1, 2, 3, 4, 5].map { NSNumber(value: $0) }
        return NSCountedSet(array: numbers)
    }
    
    static let countedSetOfNumbersAppearingSeveralTimes = TypedFixture<NSCountedSet>("NSCountedSet-NumbersAppearingSeveralTimes") {
        let numbers = [1, 2, 3, 4, 5].map { NSNumber(value: $0) }
        let set = NSCountedSet()
        for _ in 0 ..< 5 {
            for number in numbers {
                set.add(number)
            }
        }
        return set
    }
    
    static let countedSetEmpty = TypedFixture<NSCountedSet>("NSCountedSet-Empty") {
        return NSCountedSet()
    }
    
    // ===== NSCharacterSet, NSMutableCharacterSet =====
    
    static let characterSetEmpty = TypedFixture<NSCharacterSet>("NSCharacterSet-Empty") {
        return NSCharacterSet()
    }
    
    static let characterSetRange = TypedFixture<NSCharacterSet>("NSCharacterSet-Range") {
        return NSCharacterSet(range: NSMakeRange(0, 255))
    }
    
    static let characterSetString = TypedFixture<NSCharacterSet>("NSCharacterSet-String") {
        return NSCharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")
    }
    
    static let characterSetBitmap = TypedFixture<NSCharacterSet>("NSCharacterSet-Bitmap") {
        let someSet = NSCharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        return NSCharacterSet(bitmapRepresentation: someSet.bitmapRepresentation)
    }
    
    static let characterSetBuiltin = TypedFixture<NSCharacterSet>("NSCharacterSet-Builtin") {
        return NSCharacterSet.alphanumerics as NSCharacterSet
    }
    
    // ===== NSOrderedSet, NSMutableOrderedSet =====
    
    static let orderedSetOfNumbers = TypedFixture<NSOrderedSet>("NSOrderedSet-Numbers") {
        let numbers = [1, 2, 3, 4, 5].map { NSNumber(value: $0) }
        return NSOrderedSet(array: numbers)
    }
    
    static let orderedSetEmpty = TypedFixture<NSOrderedSet>("NSOrderedSet-Empty") {
        return NSOrderedSet()
    }
    
    static let mutableOrderedSetOfNumbers = TypedFixture<NSMutableOrderedSet>("NSMutableOrderedSet-Numbers") {
        let numbers = [1, 2, 3, 4, 5].map { NSNumber(value: $0) }
        return NSMutableOrderedSet(array: numbers)
    }
    
    static let mutableOrderedSetEmpty = TypedFixture<NSMutableOrderedSet>("NSMutableOrderedSet-Empty") {
        return NSMutableOrderedSet()
    }
    
    // ===== NSMeasurement =====
    
    static let zeroMeasurement = TypedFixture<NSMeasurement>("NSMeasurement-Zero") {
        let noUnit = Unit(symbol: "")
        return NSMeasurement(doubleValue: 0, unit: noUnit)
    }
    
    static let lengthMeasurement = TypedFixture<NSMeasurement>("NSMeasurement-Length") {
        return NSMeasurement(doubleValue: 45, unit: UnitLength.miles)
    }
    
    static let frequencyMeasurement = TypedFixture<NSMeasurement>("NSMeasurement-Frequency") {
        return NSMeasurement(doubleValue: 1400, unit: UnitFrequency.megahertz)
    }
    
    static let angleMeasurement = TypedFixture<NSMeasurement>("NSMeasurement-Angle") {
        return NSMeasurement(doubleValue: 90, unit: UnitAngle.degrees)
    }
    
    // ===== Fixture list =====
    
    static let _listOfAllFixtures: [AnyFixture] = [
        AnyFixture(Fixtures.mutableAttributedString),
        AnyFixture(Fixtures.attributedString),
        AnyFixture(Fixtures.byteCountFormatterDefault),
        AnyFixture(Fixtures.byteCountFormatterAllFieldsSet),
        AnyFixture(Fixtures.dateIntervalFormatterDefault),
        AnyFixture(Fixtures.dateIntervalFormatterValuesSetWithTemplate),
        AnyFixture(Fixtures.dateIntervalFormatterValuesSetWithoutTemplate),
        AnyFixture(Fixtures.iso8601FormatterDefault),
        AnyFixture(Fixtures.iso8601FormatterOptionsSet),
        AnyFixture(Fixtures.textCheckingResultSimpleRegex),
        AnyFixture(Fixtures.textCheckingResultExtendedRegex),
        AnyFixture(Fixtures.textCheckingResultComplexRegex),
        AnyFixture(Fixtures.indexSetEmpty),
        AnyFixture(Fixtures.indexSetOneRange),
        AnyFixture(Fixtures.indexSetManyRanges),
        AnyFixture(Fixtures.mutableIndexSetEmpty),
        AnyFixture(Fixtures.mutableIndexSetOneRange),
        AnyFixture(Fixtures.mutableIndexSetManyRanges),
        AnyFixture(Fixtures.indexPathEmpty),
        AnyFixture(Fixtures.indexPathOneIndex),
        AnyFixture(Fixtures.indexPathManyIndices),
        AnyFixture(Fixtures.setOfNumbers),
        AnyFixture(Fixtures.setEmpty),
        AnyFixture(Fixtures.mutableSetOfNumbers),
        AnyFixture(Fixtures.mutableSetEmpty),
        AnyFixture(Fixtures.countedSetOfNumbersAppearingOnce),
        AnyFixture(Fixtures.countedSetOfNumbersAppearingSeveralTimes),
        AnyFixture(Fixtures.countedSetEmpty),
        AnyFixture(Fixtures.characterSetEmpty),
        AnyFixture(Fixtures.characterSetRange),
        AnyFixture(Fixtures.characterSetString),
        AnyFixture(Fixtures.characterSetBitmap),
        AnyFixture(Fixtures.characterSetBuiltin),
        AnyFixture(Fixtures.orderedSetOfNumbers),
        AnyFixture(Fixtures.orderedSetEmpty),
        AnyFixture(Fixtures.mutableOrderedSetOfNumbers),
        AnyFixture(Fixtures.mutableOrderedSetEmpty),
        AnyFixture(Fixtures.zeroMeasurement),
        AnyFixture(Fixtures.lengthMeasurement),
        AnyFixture(Fixtures.frequencyMeasurement),
        AnyFixture(Fixtures.angleMeasurement),
    ]
    
    // This ensures that we do not have fixtures with duplicate identifiers:
    
    static var all: [AnyFixture] {
        return Array(Fixtures.allFixturesByIdentifier.values)
    }
    
    static var allFixturesByIdentifier: [String: AnyFixture] = {
        let keysAndValues = Fixtures._listOfAllFixtures.map { ($0.identifier, $0) }
        return Dictionary(keysAndValues, uniquingKeysWith: { _, _ in fatalError("No two keys should be the same in fixtures. Double-check keys in FixtureValues.swift to make sure they're all unique.") })
    }()
}

// -----

// Support for the above:

enum FixtureVariant: String, CaseIterable {
    case macOS10_14 = "macOS-10.14"
    
    func url(fixtureRepository: URL) -> URL {
        return URL(fileURLWithPath: self.rawValue, relativeTo: fixtureRepository)
    }
}

protocol Fixture {
    associatedtype ValueType
    var identifier: String { get }
    func make() throws -> ValueType
    var supportsSecureCoding: Bool { get }
}

struct TypedFixture<ValueType: NSObject & NSCoding>: Fixture {
    var identifier: String
    private var creationHandler: () throws -> ValueType
    
    init(_ identifier: String, creationHandler: @escaping () throws -> ValueType) {
        self.identifier = identifier
        self.creationHandler = creationHandler
    }
    
    func make() throws -> ValueType {
        return try creationHandler()
    }
    
    var supportsSecureCoding: Bool {
        let kind: Any.Type
        if let made = try? make() {
            kind = type(of: made)
        } else {
            kind = ValueType.self
        }
        
        return (kind as? NSSecureCoding.Type)?.supportsSecureCoding == true
    }
}

struct AnyFixture: Fixture {
    var identifier: String
    private var creationHandler: () throws -> NSObject & NSCoding
    let supportsSecureCoding: Bool
    
    init<T: Fixture>(_ fixture: T) {
        self.identifier = fixture.identifier
        self.creationHandler = { return try fixture.make() as! NSObject & NSCoding }
        self.supportsSecureCoding = fixture.supportsSecureCoding
    }
    
    func make() throws -> NSObject & NSCoding {
        return try creationHandler()
    }
}

enum FixtureError: Error {
    case noneFound
}

extension Fixture where ValueType: NSObject & NSCoding {
    func load(fixtureRepository: URL, variant: FixtureVariant) throws -> ValueType? {
        let data = try Data(contentsOf: url(inFixtureRepository: fixtureRepository, variant: variant))
        let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
        unarchiver.requiresSecureCoding = self.supportsSecureCoding
        unarchiver.decodingFailurePolicy = .setErrorAndReturn
        
        let value = unarchiver.decodeObject(of: ValueType.self, forKey: NSKeyedArchiveRootObjectKey)
        if let error = unarchiver.error {
            throw error
        }
        return value
    }
    
    func url(inFixtureRepository fixtureRepository: URL, variant: FixtureVariant) -> URL {
        return variant.url(fixtureRepository: fixtureRepository)
            .appendingPathComponent(identifier)
            .appendingPathExtension("archive")
    }
    
    func loadEach(fixtureRepository: URL, handler: (ValueType, FixtureVariant) throws -> Void) throws {
        var foundAny = false
        
        for variant in FixtureVariant.allCases {
            let fileURL = url(inFixtureRepository: fixtureRepository, variant: variant)
            guard (try? fileURL.checkResourceIsReachable()) == true else { continue }
            
            foundAny = true
            
            if let value = try load(fixtureRepository: fixtureRepository, variant: variant) {
                try handler(value, variant)
            }
        }
        
        guard foundAny else { throw FixtureError.noneFound }
    }
}
