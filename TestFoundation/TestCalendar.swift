// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestCalendar: XCTestCase {
    
    static var allTests: [(String, (TestCalendar) -> () throws -> Void)] {
        return [
            ("test_allCalendars", test_allCalendars),
            ("test_gettingDatesOnGregorianCalendar", test_gettingDatesOnGregorianCalendar ),
            ("test_gettingDatesOnHebrewCalendar", test_gettingDatesOnHebrewCalendar ),
            ("test_gettingDatesOnChineseCalendar", test_gettingDatesOnChineseCalendar),
            ("test_gettingDatesOnISO8601Calendar", test_gettingDatesOnISO8601Calendar),
            ("test_copy",test_copy),
            ("test_addingDates", test_addingDates),
            ("test_datesNotOnWeekend", test_datesNotOnWeekend),
            ("test_datesOnWeekend", test_datesOnWeekend),
            ("test_customMirror", test_customMirror),
            ("test_ampmSymbols", test_ampmSymbols),
            ("test_currentCalendarRRstability", test_currentCalendarRRstability),
            ("test_AnyHashable", test_AnyHashable),
        ]
    }

    func test_allCalendars() {
        for identifier in [
            Calendar.Identifier.buddhist,
            Calendar.Identifier.chinese,
            Calendar.Identifier.coptic,
            Calendar.Identifier.ethiopicAmeteAlem,
            Calendar.Identifier.ethiopicAmeteMihret,
            Calendar.Identifier.gregorian,
            Calendar.Identifier.hebrew,
            Calendar.Identifier.indian,
            Calendar.Identifier.islamic,
            Calendar.Identifier.islamicCivil,
            Calendar.Identifier.islamicTabular,
            Calendar.Identifier.islamicUmmAlQura,
            Calendar.Identifier.iso8601,
            Calendar.Identifier.japanese,
            Calendar.Identifier.persian,
            Calendar.Identifier.republicOfChina
            ] {
                let calendar = Calendar(identifier: identifier)
                XCTAssertEqual(identifier,calendar.identifier)
        }
    }

    func test_gettingDatesOnGregorianCalendar() {
        let date = Date(timeIntervalSince1970: 1449332351)
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        XCTAssertEqual(components.year, 2015)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 5)

        // Test for problem reported by Malcolm Barclay via swift-corelibs-dev
        // https://lists.swift.org/pipermail/swift-corelibs-dev/Week-of-Mon-20161128/001031.html
        let fromDate = Date()
        let interval = 200
        let toDate = Date(timeInterval: TimeInterval(interval), since: fromDate)
        let fromToComponents = calendar.dateComponents([.second], from: fromDate, to: toDate)
        XCTAssertEqual(fromToComponents.second, interval);

        // Issue with 32-bit CF calendar vector on Linux
        // Crashes on macOS 10.12.2/Foundation 1349.25
        // (Possibly related) rdar://24384757
        /*
        let interval2 = Int(INT32_MAX) + 1
        let toDate2 = Date(timeInterval: TimeInterval(interval2), since: fromDate)
        let fromToComponents2 = calendar.dateComponents([.second], from: fromDate, to: toDate2)
        XCTAssertEqual(fromToComponents2.second, interval2);
        */
    }

    func test_gettingDatesOnISO8601Calendar() {
        let date = Date(timeIntervalSince1970: 1449332351)

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        XCTAssertEqual(components.year, 2015)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 5)
    }

    
    func test_gettingDatesOnHebrewCalendar() {
        let date = Date(timeIntervalSince1970: 1552580351)
        
        var calendar = Calendar(identifier: .hebrew)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        XCTAssertEqual(components.year, 5779)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 7)
        XCTAssertEqual(components.isLeapMonth, false)
    }
    
    func test_gettingDatesOnChineseCalendar() {
        let date = Date(timeIntervalSince1970: 1591460351.0)
        
        var calendar = Calendar(identifier: .chinese)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        XCTAssertEqual(components.year, 37)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.isLeapMonth, true)
    }

    func test_ampmSymbols() {
        let calendar = Calendar(identifier: .gregorian)
        XCTAssertEqual(calendar.amSymbol, "AM")
        XCTAssertEqual(calendar.pmSymbol, "PM")
    }

    func test_currentCalendarRRstability() {
        var AMSymbols = [String]()
        for _ in 1...10 {
            let cal = Calendar.current
            AMSymbols.append(cal.amSymbol)
        }
        
        XCTAssertEqual(AMSymbols.count, 10, "Accessing current calendar should work over multiple callouts")
    }
    
    func test_copy() {
        var calendar = Calendar.current

        //Mutate below fields and check if change is being reflected in copy.
        calendar.firstWeekday = 2 
        calendar.minimumDaysInFirstWeek = 2

        let copy = calendar
        XCTAssertTrue(copy == calendar)

        //verify firstWeekday and minimumDaysInFirstWeek of 'copy'. 
        XCTAssertEqual(copy.firstWeekday, 2)
        XCTAssertEqual(copy.minimumDaysInFirstWeek, 2)
    }
    
    func test_addingDates() {
        let calendar = Calendar(identifier: .gregorian)
        let thisDay = calendar.date(from: DateComponents(year: 2016, month: 10, day: 4))!
        let diffComponents = DateComponents(day: 1)
        let dayAfter = calendar.date(byAdding: diffComponents, to: thisDay)
        
        let dayAfterComponents = calendar.dateComponents([.year, .month, .day], from: dayAfter!)
        XCTAssertEqual(dayAfterComponents.year, 2016)
        XCTAssertEqual(dayAfterComponents.month, 10)
        XCTAssertEqual(dayAfterComponents.day, 5)
    }
    
    func test_datesNotOnWeekend() {
        let calendar = Calendar(identifier: .gregorian)
        let mondayInDecember = calendar.date(from: DateComponents(year: 2018, month: 12, day: 10))!
        XCTAssertFalse(calendar.isDateInWeekend(mondayInDecember))
        let tuesdayInNovember = calendar.date(from: DateComponents(year: 2017, month: 11, day: 14))!
        XCTAssertFalse(calendar.isDateInWeekend(tuesdayInNovember))
        let wednesdayInFebruary = calendar.date(from: DateComponents(year: 2016, month: 2, day: 17))!
        XCTAssertFalse(calendar.isDateInWeekend(wednesdayInFebruary))
        let thursdayInOctober = calendar.date(from: DateComponents(year: 2015, month: 10, day: 22))!
        XCTAssertFalse(calendar.isDateInWeekend(thursdayInOctober))
        let fridayInSeptember = calendar.date(from: DateComponents(year: 2014, month: 9, day: 26))!
        XCTAssertFalse(calendar.isDateInWeekend(fridayInSeptember))
    }
    
    func test_datesOnWeekend() {
        let calendar = Calendar(identifier: .gregorian)
        let saturdayInJanuary = calendar.date(from: DateComponents(year:2017, month: 1, day: 7))!
        XCTAssertTrue(calendar.isDateInWeekend(saturdayInJanuary))
        let sundayInFebruary = calendar.date(from: DateComponents(year: 2016, month: 2, day: 14))!
        XCTAssertTrue(calendar.isDateInWeekend(sundayInFebruary))
    }
    
    func test_customMirror() {
        let calendar = Calendar(identifier: .gregorian)
        let calendarMirror = calendar.customMirror
        
        XCTAssertEqual(calendar.identifier, calendarMirror.descendant("identifier") as? Calendar.Identifier)
        XCTAssertEqual(calendar.locale, calendarMirror.descendant("locale") as? Locale)
        XCTAssertEqual(calendar.timeZone, calendarMirror.descendant("timeZone") as? TimeZone)
        XCTAssertEqual(calendar.firstWeekday, calendarMirror.descendant("firstWeekday") as? Int)
        XCTAssertEqual(calendar.minimumDaysInFirstWeek, calendarMirror.descendant("minimumDaysInFirstWeek") as? Int)
    }

    func test_AnyHashable() {
        let a1: AnyHashable = Calendar(identifier: Calendar.Identifier.buddhist)
        let a2: AnyHashable = NSCalendar(identifier: NSCalendar.Identifier.buddhist)!
        let b1: AnyHashable = Calendar(identifier: Calendar.Identifier.chinese)
        let b2: AnyHashable = NSCalendar(identifier: NSCalendar.Identifier.chinese)!
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

class TestNSDateComponents: XCTestCase {

    static var allTests: [(String, (TestNSDateComponents) -> () throws -> Void)] {
        return [
            ("test_copyNSDateComponents", test_copyNSDateComponents),
            ("test_AnyHashable", test_AnyHashable),
        ]
    }

    func test_copyNSDateComponents() {
        let components = NSDateComponents()
        components.year = 1987
        components.month = 3
        components.day = 17
        components.hour = 14
        components.minute = 20
        components.second = 0
        let copy = components.copy(with: nil) as! NSDateComponents
        XCTAssertTrue(components.isEqual(copy))
        XCTAssertTrue(components == copy)
        XCTAssertFalse(components === copy)
        XCTAssertEqual(copy.year, 1987)
        XCTAssertEqual(copy.month, 3)
        XCTAssertEqual(copy.day, 17)
        XCTAssertEqual(copy.isLeapMonth, false)
        //Mutate NSDateComponents and verify that it does not reflect in the copy
        components.hour = 12
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(copy.hour, 14)
    }

    func test_AnyHashable() {
        let d1 = DateComponents(year: 2018, month: 8, day: 1)
        let d2 = DateComponents(year: 2014, month: 6, day: 2)
        let a1: AnyHashable = d1
        let a2: AnyHashable = d1._bridgeToObjectiveC()
        let b1: AnyHashable = d2
        let b2: AnyHashable = d2._bridgeToObjectiveC()
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
