// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
    #if canImport(SwiftFoundation) && !DEPLOYMENT_RUNTIME_OBJC
        @testable import SwiftFoundation
    #else
        @testable import Foundation
    #endif
#endif

class TestListFormatter: XCTestCase {
    private var formatter: ListFormatter!

    override func setUp() {
        super.setUp()

        formatter = ListFormatter()
    }

    override func tearDown() {
        formatter = nil

        super.tearDown()
    }

    func test_locale() throws {
        XCTAssertEqual(formatter.locale, Locale.autoupdatingCurrent)

        formatter.locale = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(formatter.locale, Locale(identifier: "en_US_POSIX"))

        formatter.locale = nil
        XCTAssertEqual(formatter.locale, Locale.autoupdatingCurrent)
    }

    func test_copy() throws {
        formatter.itemFormatter = NumberFormatter()

        let copied = try XCTUnwrap(formatter.copy() as? ListFormatter)
        XCTAssertEqual(formatter.locale, copied.locale)
        XCTAssert(copied.itemFormatter is NumberFormatter)

        copied.locale = Locale(identifier: "en_US_POSIX")
        copied.itemFormatter = DateFormatter()
        XCTAssertNotEqual(formatter.locale, copied.locale)
        XCTAssert(formatter.itemFormatter is NumberFormatter)
        XCTAssertFalse(copied.itemFormatter is NumberFormatter)
    }

    func test_stringFromItemsWithItemFormatter() throws {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "en_US_POSIX")
        numberFormatter.numberStyle = .percent

        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.itemFormatter = numberFormatter
        XCTAssertEqual(formatter.string(from: [1, 2, 3]), "100%, 200%, and 300%")
    }

    func test_stringFromDescriptionsWithLocale() throws {
        formatter.locale = Locale(identifier: "en_US")
        XCTAssertEqual(formatter.string(from: [1000, 2000, 3000]), "1,000, 2,000, and 3,000")
    }

    func test_stringFromLocalizedDescriptions() throws {
        struct Item: LocalizedError {
            let errorDescription: String? = "item"
        }

        formatter.locale = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(formatter.string(from: [Item(), Item(), Item()]), "item, item, and item")
    }

    func test_stringFromItems() throws {
        struct Item {}

        formatter.locale = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(formatter.string(from: [Item(), Item(), Item()]), "Item(), Item(), and Item()")
    }

    func test_stringForList() throws {
        XCTAssertEqual(formatter.string(for: [42]), "42")
    }

    func test_stringForNonList() throws {
        XCTAssertNil(formatter.string(for: 42))
    }

    static var allTests: [(String, (TestListFormatter) -> () throws -> Void)] {
        return [
            ("test_locale", test_locale),
            ("test_copy", test_copy),
            ("test_stringFromItemsWithItemFormatter", test_stringFromItemsWithItemFormatter),
            ("test_stringFromDescriptionsWithLocale", test_stringFromDescriptionsWithLocale),
            ("test_stringFromLocalizedDescriptions", test_stringFromLocalizedDescriptions),
            ("test_stringFromItems", test_stringFromItems),
            ("test_stringForList", test_stringForList),
            ("test_stringForNonList", test_stringForNonList),
        ]
    }
}
