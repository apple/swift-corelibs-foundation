// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestTimeZone: XCTestCase {

    static var allTests: [(String, (TestTimeZone) -> () throws -> Void)] {
        return [
            // Disabled see https://bugs.swift.org/browse/SR-300
            // ("test_abbreviation", test_abbreviation),

            // Disabled because `CFTimeZoneSetAbbreviationDictionary()` attempts
            // to release non-CF objects while removing values from
            // `__CFTimeZoneCache`
            // ("test_abbreviationDictionary", test_abbreviationDictionary),

            ("test_changingDefaultTimeZone", test_changingDefaultTimeZone),
            ("test_computedPropertiesMatchMethodReturnValues", test_computedPropertiesMatchMethodReturnValues),
            ("test_initializingTimeZoneWithOffset", test_initializingTimeZoneWithOffset),
            ("test_initializingTimeZoneWithAbbreviation", test_initializingTimeZoneWithAbbreviation),
            ("test_localizedName", test_localizedName),
            // Also disabled due to https://bugs.swift.org/browse/SR-300
            // ("test_systemTimeZoneUsesSystemTime", test_systemTimeZoneUsesSystemTime),

            ("test_customMirror", test_tz_customMirror),
            ("test_knownTimeZones", test_knownTimeZones),
            ("test_AnyHashable", test_AnyHashable),
        ]
    }

    func test_abbreviation() {
        let tz = NSTimeZone.system
        let abbreviation1 = tz.abbreviation()
        let abbreviation2 = tz.abbreviation(for: Date())
        XCTAssertEqual(abbreviation1, abbreviation2, "\(abbreviation1 as Optional) should be equal to \(abbreviation2 as Optional)")
    }

    func test_abbreviationDictionary() {
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
#if os(Android)
	XCTFail("Named timezones not available on Android")
#else
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
#endif
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

    func test_systemTimeZoneUsesSystemTime() {
        tzset()
        var t = time(nil)
        var lt = tm()
        localtime_r(&t, &lt)
        let zoneName = NSTimeZone.system.abbreviation() ?? "Invalid Abbreviation"
        let expectedName = String(cString: lt.tm_zone, encoding: .ascii) ?? "Invalid Zone"
        XCTAssertEqual(zoneName, expectedName, "expected name \"\(expectedName)\" is not equal to \"\(zoneName)\"")
    }

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
        XCTAssertNotNil(children["kind"])
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

    func test_AnyHashable() {
        let a1: AnyHashable = TimeZone(identifier: "GMT+0000")!
        let a2: AnyHashable = NSTimeZone(name: "GMT+0000")!
        let b1: AnyHashable = TimeZone(identifier: "GMT-0400")!
        let b2: AnyHashable = NSTimeZone(name: "GMT-0400")!
        XCTAssertEqual(a1, a2)
        XCTAssertEqual(b1, b2)
        XCTAssertNotEqual(a1, b1)
        XCTAssertNotEqual(a1, b2)
        XCTAssertNotEqual(a2, b1)
        XCTAssertNotEqual(a2, b2)

        XCTAssertEqual(a1.hashValue, a2.hashValue)
        XCTAssertEqual(b1.hashValue, b2.hashValue)
    }
}
