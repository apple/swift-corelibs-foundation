// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestDateInterval : XCTestCase {

    static var allTests: [(String, (TestDateInterval) -> () throws -> Void)] {
        return [
            ("test_AnyHashable", test_AnyHashable),
        ]
    }

    func test_AnyHashable() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let a1: AnyHashable = DateInterval(start: start, duration: 1000)
        let a2: AnyHashable = NSDateInterval(start: start, duration: 1000)
        let b1: AnyHashable = DateInterval(start: start, duration: 5000)
        let b2: AnyHashable = NSDateInterval(start: start, duration: 5000)
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
