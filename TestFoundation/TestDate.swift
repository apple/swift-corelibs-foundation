// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestDate : XCTestCase {
    
    static var allTests: [(String, (TestDate) -> () throws -> Void)] {
        return [
            ("test_BasicConstruction", test_BasicConstruction),
            ("test_InitTimeIntervalSince1970", test_InitTimeIntervalSince1970),
            ("test_InitTimeIntervalSinceSinceDate", test_InitTimeIntervalSinceSinceDate),
            ("test_TimeIntervalSinceSinceDate", test_TimeIntervalSinceSinceDate),
            ("test_descriptionWithLocale", test_descriptionWithLocale),
            ("test_DistantFuture", test_DistantFuture),
            ("test_DistantPast", test_DistantPast),
            ("test_DateByAddingTimeInterval", test_DateByAddingTimeInterval),
            ("test_EarlierDate", test_EarlierDate),
            ("test_LaterDate", test_LaterDate),
            ("test_Compare", test_Compare),
            ("test_IsEqualToDate", test_IsEqualToDate),
            ("test_timeIntervalSinceReferenceDate", test_timeIntervalSinceReferenceDate),
            ("test_recreateDateComponentsFromDate", test_recreateDateComponentsFromDate),
            ("test_AnyHashable", test_AnyHashable),
        ]
    }
    
    func test_BasicConstruction() {
        let d = Date()
        XCTAssert(d.timeIntervalSince1970 != 0)
        XCTAssert(d.timeIntervalSinceReferenceDate != 0)
    }

    func test_descriptionWithLocale() {
        let d = NSDate(timeIntervalSince1970: 0)
        XCTAssertEqual(d.description(with: nil), "1970-01-01 00:00:00 +0000")
        XCTAssertFalse(d.description(with: Locale(identifier: "ja_JP")).isEmpty)
    }
    
    func test_InitTimeIntervalSince1970() {
        let ti: TimeInterval = 1
        let d = Date(timeIntervalSince1970: ti)
        XCTAssert(d.timeIntervalSince1970 == ti)
    }
    
    func test_InitTimeIntervalSinceSinceDate() {
        let ti: TimeInterval = 1
        let d1 = Date()
        let d2 = Date(timeInterval: ti, since: d1)
        XCTAssertNotNil(d2.timeIntervalSince1970 == d1.timeIntervalSince1970 + ti)
    }
    
    func test_TimeIntervalSinceSinceDate() {
        let ti: TimeInterval = 1
        let d1 = Date()
        let d2 = Date(timeInterval: ti, since: d1)
        XCTAssertEqual(d2.timeIntervalSince(d1), ti)
    }
    
    func test_DistantFuture() {
        let d = Date.distantFuture
        let now = Date()
        XCTAssertGreaterThan(d, now)
    }
    
    func test_DistantPast() {
        let now = Date()
        let d = Date.distantPast

        XCTAssertLessThan(d, now)
    }
    
    func test_DateByAddingTimeInterval() {
        let ti: TimeInterval = 1
        let d1 = Date()
        let d2 = d1 + ti
        XCTAssertNotNil(d2.timeIntervalSince1970 == d1.timeIntervalSince1970 + ti)
    }
    
    func test_EarlierDate() {
        let ti: TimeInterval = 1
        let d1 = Date()
        let d2 = d1 + ti
        XCTAssertLessThan(d1, d2)
    }
    
    func test_LaterDate() {
        let ti: TimeInterval = 1
        let d1 = Date()
        let d2 = d1 + ti
        XCTAssertGreaterThan(d2, d1)
    }
    
    func test_Compare() {
        let ti: TimeInterval = 1
        let d1 = Date()
        let d2 = d1 + ti
        XCTAssertEqual(d1.compare(d2), .orderedAscending)
    }
    
    func test_IsEqualToDate() {
        let ti: TimeInterval = 1
        let d1 = Date()
        let d2 = d1 + ti
        let d3 = d1 + ti
        XCTAssertEqual(d2, d3)
    }

    func test_timeIntervalSinceReferenceDate() {
        let d1 = Date().timeIntervalSinceReferenceDate
        let sinceReferenceDate = Date.timeIntervalSinceReferenceDate
        let d2 = Date().timeIntervalSinceReferenceDate
        XCTAssertTrue(d1 <= sinceReferenceDate)
        XCTAssertTrue(d2 >= sinceReferenceDate)
    }
    
    func test_recreateDateComponentsFromDate() {
        let components = DateComponents(calendar: Calendar(identifier: .gregorian),
                                        timeZone: .current,
                                        era: 1,
                                        year: 2017,
                                        month: 11,
                                        day: 5,
                                        hour: 20,
                                        minute: 38,
                                        second: 11,
                                        nanosecond: 40)
        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            XCTFail()
            return
        }
        let recreatedComponents = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        XCTAssertEqual(recreatedComponents.era, 1)
        XCTAssertEqual(recreatedComponents.year, 2017)
        XCTAssertEqual(recreatedComponents.month, 11)
        XCTAssertEqual(recreatedComponents.hour, 20)
        XCTAssertEqual(recreatedComponents.minute, 38)
        
        // Nanoseconds are currently not supported by UCalendar C API, returns nil
        // XCTAssertEqual(recreatedComponents.nanosecond, 40)
        
        XCTAssertEqual(recreatedComponents.weekday, 1)
        XCTAssertEqual(recreatedComponents.weekdayOrdinal, 1)
        
        // Quarter is currently not supported by UCalendar C API, returns nil
        // XCTAssertEqual(recreatedComponents.quarter, 3)
        
        XCTAssertEqual(recreatedComponents.weekOfMonth, 2)
        XCTAssertEqual(recreatedComponents.weekOfYear, 45)
        XCTAssertEqual(recreatedComponents.yearForWeekOfYear, 2017)
    }

    func test_AnyHashable() {
        let a1: AnyHashable = Date(timeIntervalSinceReferenceDate: 1000)
        let a2: AnyHashable = NSDate(timeIntervalSinceReferenceDate: 1000)
        let b1: AnyHashable = Date(timeIntervalSinceReferenceDate: 5000)
        let b2: AnyHashable = NSDate(timeIntervalSinceReferenceDate: 5000)
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
