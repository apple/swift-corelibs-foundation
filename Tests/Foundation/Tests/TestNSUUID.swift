// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestNSUUID : XCTestCase {
    
    static var allTests: [(String, (TestNSUUID) -> () throws -> Void)] {
        return [
            ("test_Equality", test_Equality),
            ("test_InvalidUUID", test_InvalidUUID),
            ("test_uuidString", test_uuidString),
            ("test_description", test_description),
            ("test_NSCoding", test_NSCoding),
            ("test_compare", test_compare),
        ]
    }
    
    func test_Equality() {
        let uuidA = NSUUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let uuidB = NSUUID(uuidString: "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")
        let uuidC = NSUUID(uuidBytes: [0xe6,0x21,0xe1,0xf8,0xc3,0x6c,0x49,0x5a,0x93,0xfc,0x0c,0x24,0x7a,0x3e,0x6e,0x5f])
        let uuidD = NSUUID()
        
        XCTAssertEqual(uuidA, uuidB, "String case must not matter.")
        XCTAssertEqual(uuidA, uuidC, "A UUID initialized with a string must be equal to the same UUID initialized with its UnsafePointer<UInt8> equivalent representation.")
        XCTAssertNotEqual(uuidC, uuidD, "Two different UUIDs must not be equal.")
    }
    
    func test_InvalidUUID() {
        let uuid = NSUUID(uuidString: "Invalid UUID")
        XCTAssertNil(uuid, "The convenience initializer `init?(uuidString string:)` must return nil for an invalid UUID string.")
    }
    
    // `uuidString` should return an uppercase string
    // See: https://bugs.swift.org/browse/SR-865
    func test_uuidString() {
        let uuid = NSUUID(uuidBytes: [0xe6,0x21,0xe1,0xf8,0xc3,0x6c,0x49,0x5a,0x93,0xfc,0x0c,0x24,0x7a,0x3e,0x6e,0x5f])
        XCTAssertEqual(uuid.uuidString, "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "The uuidString representation must be uppercase.")
    }
    
    func test_description() {
        let uuid = NSUUID()
        XCTAssertEqual(uuid.description, uuid.uuidString, "The description must be the same as the uuidString.")
    }
    
    func test_NSCoding() {
        let uuidA = NSUUID()
        let uuidB = NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: uuidA)) as! NSUUID
        XCTAssertEqual(uuidA, uuidB, "Archived then unarchived uuid must be equal.")
    }

    func test_compare() {
        let uuidA = NSUUID(uuidBytes: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01])
        let uuidB = NSUUID(uuidBytes: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02])
        XCTAssertEqual(uuidA.compare(uuidA as UUID), .orderedSame)
        XCTAssertEqual(uuidA.compare(uuidB as UUID), .orderedAscending)
        XCTAssertEqual(uuidB.compare(uuidA as UUID), .orderedDescending)
    }
}
