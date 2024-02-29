// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestURLQueryItem: XCTestCase {

    func test_hashValue() {
        let item1 = URLQueryItem(name: "foo", value: "bar")
        let item2 = URLQueryItem(name: "foo", value: "bar")

        XCTAssertEqual(item1, item2)
        XCTAssertEqual(item1.hashValue, item2.hashValue)
    }

    static var allTests: [(String, (TestURLQueryItem) -> () throws -> Void)] {
        return [
            ("test_hashValue", test_hashValue),
        ]
    }
}
