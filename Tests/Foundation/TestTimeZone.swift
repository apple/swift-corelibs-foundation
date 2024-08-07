// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


class TestTimeZone: XCTestCase {
    
    var initialDefaultTimeZone: TimeZone?
    
    override func setUp() {
        initialDefaultTimeZone = NSTimeZone.default
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
        if let tz = initialDefaultTimeZone {
            NSTimeZone.default = tz
        }
    }

    func test_abbreviation() {
        let tz = NSTimeZone.system
        let abbreviation1 = tz.abbreviation()
        let abbreviation2 = tz.abbreviation(for: Date())
        XCTAssertEqual(abbreviation1, abbreviation2, "\(abbreviation1 as Optional) should be equal to \(abbreviation2 as Optional)")
    }

    func test_abbreviationDictionary() throws {
        throw XCTSkip("Disabled because `CFTimeZoneSetAbbreviationDictionary()` attempts to release non-CF objects while removing values from `__CFTimeZoneCache`")
        #if false
        let oldDictionary = TimeZone.abbreviationDictionary
        let newDictionary = [
            "UTC": "UTC",
            "JST": "Asia/Tokyo",
            "GMT": "GMT",
            "ICT": "Asia/Bangkok",
            "TEST": "Foundation/TestNSTimeZone"
        ]
        TimeZone.abbreviationDictionary = newDictionary
        XCTAssertEqual(TimeZone.abbreviationDictionary, newDictionary)
        TimeZone.abbreviationDictionary = oldDictionary
        XCTAssertEqual(TimeZone.abbreviationDictionary, oldDictionary)
        #endif
    }

    func test_changingDefaultTimeZone() {
        let oldDefault = NSTimeZone.default
        let oldSystem = NSTimeZone.system

        let expectedDefault = TimeZone(identifier: "GMT-0400")!
        NSTimeZone.default = expectedDefault
        let newDefault = NSTimeZone.default
        let newSystem = NSTimeZone.system
        XCTAssertEqual(oldSystem, newSystem)
        XCTAssertEqual(expectedDefault, newDefault)

        let expectedDefault2 = TimeZone(identifier: "GMT+0400")!
        NSTimeZone.default = expectedDefault2
        let newDefault2 = NSTimeZone.default
        XCTAssertEqual(expectedDefault2, newDefault2)
        XCTAssertNotEqual(newDefault, newDefault2)

        NSTimeZone.default = oldDefault
        let revertedDefault = NSTimeZone.default
        XCTAssertEqual(oldDefault, revertedDefault)
    }

    func test_computedPropertiesMatchMethodReturnValues() {
        let tz = NSTimeZone.default
        let obj = tz._bridgeToObjectiveC()

        let secondsFromGMT1 = tz.secondsFromGMT()
        let secondsFromGMT2 = obj.secondsFromGMT
        let secondsFromGMT3 = tz.secondsFromGMT()
        XCTAssert(secondsFromGMT1 == secondsFromGMT2 || secondsFromGMT2 == secondsFromGMT3, "\(secondsFromGMT1) should be equal to \(secondsFromGMT2), or in the rare circumstance where a daylight saving time transition has just occurred, \(secondsFromGMT2) should be equal to \(secondsFromGMT3)")

        let abbreviation1 = tz.abbreviation()
        let abbreviation2 = obj.abbreviation
        XCTAssertEqual(abbreviation1, abbreviation2, "\(abbreviation1 as Optional) should be equal to \(abbreviation2 as Optional)")

        let isDaylightSavingTime1 = tz.isDaylightSavingTime()
        let isDaylightSavingTime2 = obj.isDaylightSavingTime
        let isDaylightSavingTime3 = tz.isDaylightSavingTime()
        XCTAssert(isDaylightSavingTime1 == isDaylightSavingTime2 || isDaylightSavingTime2 == isDaylightSavingTime3, "\(isDaylightSavingTime1) should be equal to \(isDaylightSavingTime2), or in the rare circumstance where a daylight saving time transition has just occurred, \(isDaylightSavingTime2) should be equal to \(isDaylightSavingTime3)")

        let daylightSavingTimeOffset1 = tz.daylightSavingTimeOffset()
        let daylightSavingTimeOffset2 = obj.daylightSavingTimeOffset
        XCTAssertEqual(daylightSavingTimeOffset1, daylightSavingTimeOffset2, "\(daylightSavingTimeOffset1) should be equal to \(daylightSavingTimeOffset2)")

        let nextDaylightSavingTimeTransition1 = tz.nextDaylightSavingTimeTransition
        let nextDaylightSavingTimeTransition2 = obj.nextDaylightSavingTimeTransition
        let nextDaylightSavingTimeTransition3 = tz.nextDaylightSavingTimeTransition(after: Date())
        XCTAssert(nextDaylightSavingTimeTransition1 == nextDaylightSavingTimeTransition2 || nextDaylightSavingTimeTransition2 == nextDaylightSavingTimeTransition3, "\(nextDaylightSavingTimeTransition1 as Optional) should be equal to \(nextDaylightSavingTimeTransition2 as Optional), or in the rare circumstance where a daylight saving time transition has just occurred, \(nextDaylightSavingTimeTransition2 as Optional) should be equal to \(nextDaylightSavingTimeTransition3 as Optional)")
    }

    func test_knownTimeZoneNames() {
        let known = NSTimeZone.knownTimeZoneNames
        XCTAssertNotEqual([], known, "known time zone names not expected to be empty")
    }
    
    func test_localizedName() {
        let initialTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/New_York")!
        let defaultTimeZone = NSTimeZone.default
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(defaultTimeZone.localizedName(for: .standard, locale: locale), "Eastern Standard Time")
        XCTAssertEqual(defaultTimeZone.localizedName(for: .shortStandard, locale: locale), "EST")
        XCTAssertEqual(defaultTimeZone.localizedName(for: .generic, locale: locale), "Eastern Time")
        XCTAssertEqual(defaultTimeZone.localizedName(for: .daylightSaving, locale: locale), "Eastern Daylight Time")
        XCTAssertEqual(defaultTimeZone.localizedName(for: .shortDaylightSaving, locale: locale), "EDT")
        XCTAssertEqual(defaultTimeZone.localizedName(for: .shortGeneric, locale: locale), "ET")
        NSTimeZone.default = initialTimeZone //reset the TimeZone
    }

    func test_initializingTimeZoneWithOffset() {
        let tz = TimeZone(identifier: "GMT-0400")
        XCTAssertNotNil(tz)
        let seconds = tz?.secondsFromGMT(for: Date()) ?? 0
        XCTAssertEqual(seconds, -14400, "GMT-0400 should be -14400 seconds but got \(seconds) instead")

        let tz2 = TimeZone(secondsFromGMT: -14400)
        XCTAssertNotNil(tz2)
        let expectedName = "GMT-0400"
        let actualName = tz2?.identifier
        XCTAssertEqual(actualName, expectedName, "expected name \"\(expectedName)\" is not equal to \"\(actualName as Optional)\"")
        let expectedLocalizedName = "GMT-04:00"
        let actualLocalizedName = tz2?.localizedName(for: .generic, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(actualLocalizedName, expectedLocalizedName, "expected name \"\(expectedLocalizedName)\" is not equal to \"\(actualLocalizedName as Optional)\"")
        let seconds2 = tz2?.secondsFromGMT() ?? 0
        XCTAssertEqual(seconds2, -14400, "GMT-0400 should be -14400 seconds but got \(seconds2) instead")

        let tz3 = TimeZone(identifier: "GMT-9999")
        XCTAssertNil(tz3)

        XCTAssertNotNil(TimeZone(secondsFromGMT:  -18 * 3600))
        XCTAssertNotNil(TimeZone(secondsFromGMT:  18 * 3600))

        XCTAssertNil(TimeZone(secondsFromGMT:  -18 * 3600 - 1))
        XCTAssertNil(TimeZone(secondsFromGMT:  18 * 3600 + 1))
    }

    func test_initializingTimeZoneWithAbbreviation() {
        // Test invalid timezone abbreviation
        var tz = TimeZone(abbreviation: "XXX")
        XCTAssertNil(tz)
        // Test valid timezone abbreviation of "AST" for "America/Halifax"
        tz = TimeZone(abbreviation: "AST")
        let expectedIdentifier = "America/Halifax"
        let actualIdentifier = tz?.identifier
        XCTAssertEqual(actualIdentifier, expectedIdentifier, "expected identifier \"\(expectedIdentifier)\" is not equal to \"\(actualIdentifier as Optional)\"")
    }

// Test disabled due to Amazon Linux failures (rdar://132784697)
#if !os(Windows) && false
    func test_systemTimeZoneUsesSystemTime() {
        tzset()
        var t = time(nil)
        var lt = tm()
        localtime_r(&t, &lt)
        let zoneName = NSTimeZone.system.abbreviation() ?? "Invalid Abbreviation"
        let expectedName = String(cString: lt.tm_zone!, encoding: .ascii) ?? "Invalid Zone"
        XCTAssertEqual(zoneName, expectedName, "expected name \"\(expectedName)\" is not equal to \"\(zoneName)\"")
    }
#endif

    func test_tz_customMirror() {
        let tz = TimeZone.current
        let mirror = Mirror(reflecting: tz as TimeZone)
        var children = [String : Any](minimumCapacity: Int(mirror.children.count))
        mirror.children.forEach {
            if let label = $0.label {
                children[label] = $0.value
            }
        }

        XCTAssertNotNil(children["identifier"])
        XCTAssertNotNil(children["secondsFromGMT"])
        XCTAssertNotNil(children["isDaylightSavingTime"])
    }

    func test_knownTimeZones() {
        let timeZones = TimeZone.knownTimeZoneIdentifiers.sorted()
        XCTAssertTrue(timeZones.count > 0, "No known timezones")
        for tz in timeZones {
            XCTAssertNotNil(TimeZone(identifier: tz), "Cant instantiate valid timeZone: \(tz)")
        }
    }

    func test_systemTimeZoneName() {
        // Ensure that the system time zone creates names the same way as creating them with an identifier.
        // If it isn't the same, bugs in DateFormat can result, but in this specific case, the bad length
        // is only visible to CoreFoundation APIs, and the Swift versions hide it, making it hard to detect.
        let timeZoneName = NSTimeZone.system.identifier as NSString

        let createdTimeZone = TimeZone(identifier: TimeZone.current.identifier)!

        XCTAssertEqual(timeZoneName.length, TimeZone.current.identifier.count)
        XCTAssertEqual(timeZoneName.length, createdTimeZone.identifier.count)
    }
    
    func test_autoupdatingTimeZone() {
        let system = NSTimeZone.system
        let date = Date()
        
        for zone in [NSTimeZone.local, TimeZone.autoupdatingCurrent] {
            XCTAssertEqual(zone.identifier, system.identifier)
            XCTAssertEqual(zone.secondsFromGMT(for: date), system.secondsFromGMT(for: date))
            XCTAssertEqual(zone.abbreviation(for: date), system.abbreviation(for: date))
            XCTAssertEqual(zone.isDaylightSavingTime(for: date), system.isDaylightSavingTime(for: date))
            XCTAssertEqual(zone.daylightSavingTimeOffset(for: date), system.daylightSavingTimeOffset(for: date))
            XCTAssertEqual(zone.nextDaylightSavingTimeTransition(after: date), system.nextDaylightSavingTimeTransition(after: date))
            
            for style in [NSTimeZone.NameStyle.standard,
                          NSTimeZone.NameStyle.shortStandard,
                          NSTimeZone.NameStyle.daylightSaving,
                          NSTimeZone.NameStyle.shortDaylightSaving,
                          NSTimeZone.NameStyle.generic,
                          NSTimeZone.NameStyle.shortGeneric,] {
                XCTAssertEqual(zone.localizedName(for: style, locale: NSLocale.system), system.localizedName(for: style, locale: NSLocale.system), "For style: \(style)")
            }
        }
    }

    func test_nextDaylightSavingTimeTransition() throws {
        // Timezones without DST
        let gmt = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let msk = try XCTUnwrap(TimeZone(identifier: "Europe/Moscow"))

        // Timezones with DST
        let bst = try XCTUnwrap(TimeZone(abbreviation: "BST"))
        let aest = try XCTUnwrap(TimeZone(identifier: "Australia/Sydney"))

        XCTAssertNil(gmt.nextDaylightSavingTimeTransition)
        XCTAssertNil(msk.nextDaylightSavingTimeTransition)
        XCTAssertNotNil(bst.nextDaylightSavingTimeTransition)
        XCTAssertNotNil(aest.nextDaylightSavingTimeTransition)

        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"

        let dt1 = try XCTUnwrap(formatter.date(from: "2018-01-01"))
        XCTAssertNil(gmt.nextDaylightSavingTimeTransition(after: dt1))
        XCTAssertNil(msk.nextDaylightSavingTimeTransition(after: dt1))
        XCTAssertEqual(bst.nextDaylightSavingTimeTransition(after: dt1)?.description, "2018-03-25 01:00:00 +0000")
        XCTAssertEqual(aest.nextDaylightSavingTimeTransition(after: dt1)?.description, "2018-03-31 16:00:00 +0000")

        formatter.timeZone = aest
        let dt2 = try XCTUnwrap(formatter.date(from: "2018-06-06"))
        XCTAssertNil(gmt.nextDaylightSavingTimeTransition(after: dt2))
        XCTAssertNil(msk.nextDaylightSavingTimeTransition(after: dt2))
        XCTAssertEqual(bst.nextDaylightSavingTimeTransition(after: dt2)?.description, "2018-10-28 01:00:00 +0000")
        XCTAssertEqual(aest.nextDaylightSavingTimeTransition(after: dt2)?.description, "2018-10-06 16:00:00 +0000")
    }

    func test_isDaylightSavingTime() throws {
        let eukv = try XCTUnwrap(TimeZone(identifier: "Europe/Kiev"))
        
        let dateNoDST = Date(timeIntervalSince1970: 1585432800.0) // March 29, 2020
        let dateDST = Date(timeIntervalSince1970: 1585515600.0) // March 30, 2020
        
        XCTAssertFalse(eukv.isDaylightSavingTime(for: dateNoDST))
        XCTAssertTrue(eukv.isDaylightSavingTime(for: dateDST))
    }
}
