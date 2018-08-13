// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestNotification : XCTestCase {

    static var allTests: [(String, (TestNotification) -> () throws -> Void)] {
        return [
            ("test_customReflection", test_customReflection),
            ("test_AnyHashable", test_AnyHashable),
        ]
    }

    func test_customReflection() {
        let someName = "somenotifname"
        let targetObject = NSObject()
        let userInfo = ["hello": "world", "indexThis": 350] as [AnyHashable: Any]
        let notif = Notification(name: Notification.Name(rawValue: someName), object: targetObject, userInfo: userInfo)
        let mirror = notif.customMirror

        XCTAssertEqual(mirror.displayStyle, .class)
        XCTAssertNil(mirror.superclassMirror)

        var children = Array(mirror.children).makeIterator()
        let firstChild = children.next()
        let secondChild = children.next()
        let thirdChild = children.next()
        XCTAssertEqual(firstChild?.label, "name")
        XCTAssertEqual(firstChild?.value as? String, someName)

        XCTAssertEqual(secondChild?.label, "object")
        XCTAssertEqual(secondChild?.value as? NSObject, targetObject)

        XCTAssertEqual(thirdChild?.label, "userInfo")
        XCTAssertEqual((thirdChild?.value as? [AnyHashable: Any])?["hello"] as? String, "world")
        XCTAssertEqual((thirdChild?.value as? [AnyHashable: Any])?["indexThis"] as? Int, 350)

    }

    func test_AnyHashable() {
        let n1 = Notification(
            name: Notification.Name(rawValue: "foo"),
            object: NSObject(),
            userInfo: ["a": 1, "b": 2])
        let n2 = Notification(
            name: Notification.Name(rawValue: "bar"),
            object: NSObject(),
            userInfo: ["c": 1, "d": 2])

        let a1: AnyHashable = n1
        let a2: AnyHashable = NSNotification(name: n1.name, object: n1.object, userInfo: n1.userInfo)
        let b1: AnyHashable = n2
        let b2: AnyHashable = NSNotification(name: n2.name, object: n2.object, userInfo: n2.userInfo)
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
