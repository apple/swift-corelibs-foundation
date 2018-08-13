// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestNSDictionary : XCTestCase {
    
    static var allTests: [(String, (TestNSDictionary) -> () throws -> Void)] {
        return [
            ("test_BasicConstruction", test_BasicConstruction),
            ("test_ArrayConstruction", test_ArrayConstruction),
            ("test_description", test_description),
            ("test_enumeration", test_enumeration),
            ("test_equality", test_equality),
            ("test_copying", test_copying),
            ("test_mutableCopying", test_mutableCopying),
            ("test_writeToFile", test_writeToFile),
            ("test_initWithContentsOfFile", test_initWithContentsOfFile),
            ("test_settingWithStringKey", test_settingWithStringKey),
            ("test_AnyHashable", test_AnyHashable),
        ]
    }
        
    func test_BasicConstruction() {
        let dict = NSDictionary()
        let dict2: NSDictionary = ["foo": "bar"]
        XCTAssertEqual(dict.count, 0)
        XCTAssertEqual(dict2.count, 1)
    }
    

    func test_description() {
        let d1: NSDictionary = [ "foo": "bar", "baz": "qux"]
        XCTAssertTrue(d1.description == "{\n    baz = qux;\n    foo = bar;\n}" ||
                      d1.description == "{\n    foo = bar;\n    baz = qux;\n}")
        let d2: NSDictionary = ["1" : ["1" : ["1" : "1"]]]
        XCTAssertEqual(d2.description, "{\n    1 =     {\n        1 =         {\n            1 = 1;\n        };\n    };\n}")
    }

    func test_HeterogeneousConstruction() {
        let dict2: NSDictionary = [
            "foo": "bar",
            1 : 2
        ]
        XCTAssertEqual(dict2.count, 2)
        XCTAssertEqual(dict2["foo"] as? String, "bar")
        XCTAssertEqual(dict2[1] as? NSNumber, NSNumber(value: 2))
    }
    
    func test_ArrayConstruction() {
        let objects = ["foo", "bar", "baz"]
        let keys: [NSString] = ["foo", "bar", "baz"]
        let dict = NSDictionary(objects: objects, forKeys: keys)
        XCTAssertEqual(dict.count, 3)
    }
    
    func test_enumeration() {
        let dict : NSDictionary = ["foo" : "bar", "whiz" : "bang", "toil" : "trouble"]
        let e = dict.keyEnumerator()
        var keys = Set<String>()
        keys.insert((e.nextObject()! as! String))
        keys.insert((e.nextObject()! as! String))
        keys.insert((e.nextObject()! as! String))
        XCTAssertNil(e.nextObject())
        XCTAssertNil(e.nextObject())
        XCTAssertEqual(keys, ["foo", "whiz", "toil"])
        
        let o = dict.objectEnumerator()
        var objs = Set<String>()
        objs.insert((o.nextObject()! as! String))
        objs.insert((o.nextObject()! as! String))
        objs.insert((o.nextObject()! as! String))
        XCTAssertNil(o.nextObject())
        XCTAssertNil(o.nextObject())
        XCTAssertEqual(objs, ["bar", "bang", "trouble"])
    }
    
    func test_sequenceType() {
        let dict : NSDictionary = ["foo" : "bar", "whiz" : "bang", "toil" : "trouble"]
        var result = [String:String]()
        for (key, value) in dict {
            result[key as! String] = (value as! String)
        }
        XCTAssertEqual(result, ["foo" : "bar", "whiz" : "bang", "toil" : "trouble"])
    }

    func test_equality() {
        let dict1 = NSDictionary(dictionary: [
            "foo":"bar",
            "whiz":"bang",
            "toil":"trouble",
        ])
        let dict2 = NSDictionary(dictionary: [
            "foo":"bar",
            "whiz":"bang",
            "toil":"trouble",
        ])
        let dict3 = NSDictionary(dictionary: [
            "foo":"bar",
            "whiz":"bang",
            "toil":"troubl",
        ])

        XCTAssertTrue(dict1 == dict2)
        XCTAssertTrue(dict1.isEqual(dict2))
        XCTAssertTrue(dict1.isEqual(to: [
            "foo":"bar",
            "whiz":"bang",
            "toil":"trouble",
        ]))
        XCTAssertEqual(dict1.hash, dict2.hash)
        XCTAssertEqual(dict1.hashValue, dict2.hashValue)

        XCTAssertFalse(dict1 == dict3)
        XCTAssertFalse(dict1.isEqual(dict3))
        XCTAssertFalse(dict1.isEqual(to:[
            "foo":"bar",
            "whiz":"bang",
            "toil":"troubl",
        ]))

        XCTAssertFalse(dict1.isEqual(nil))
        XCTAssertFalse(dict1.isEqual(NSObject()))

        let nestedDict1 = NSDictionary(dictionary: [
            "key.entities": [
                ["key": 0]
            ]
        ])
        let nestedDict2 = NSDictionary(dictionary: [
            "key.entities": [
                ["key": 1]
            ]
        ])
        XCTAssertFalse(nestedDict1 == nestedDict2)
        XCTAssertFalse(nestedDict1.isEqual(nestedDict2))
        XCTAssertFalse(nestedDict1.isEqual(to: [
            "key.entities": [
                ["key": 1]
            ]
        ]))
    }

    func test_copying() {
        let inputDictionary : NSDictionary = ["foo" : "bar", "whiz" : "bang", "toil" : "trouble"]

        let copy: NSDictionary = inputDictionary.copy() as! NSDictionary
        XCTAssertTrue(inputDictionary === copy)

        let dictMutableCopy = inputDictionary.mutableCopy() as! NSMutableDictionary
        let dictCopy2 = dictMutableCopy.copy() as! NSDictionary
        XCTAssertTrue(type(of: dictCopy2) === NSDictionary.self)
        XCTAssertFalse(dictMutableCopy === dictCopy2)
        XCTAssertTrue(dictMutableCopy == dictCopy2)
    }

    func test_mutableCopying() {
        let inputDictionary : NSDictionary = ["foo" : "bar", "whiz" : "bang", "toil" : "trouble"]

        let dictMutableCopy1 = inputDictionary.mutableCopy() as! NSMutableDictionary
        XCTAssertTrue(type(of: dictMutableCopy1) === NSMutableDictionary.self)
        XCTAssertFalse(inputDictionary === dictMutableCopy1)
        XCTAssertTrue(inputDictionary == dictMutableCopy1)

        let dictMutableCopy2 = dictMutableCopy1.mutableCopy() as! NSMutableDictionary
        XCTAssertTrue(type(of: dictMutableCopy2) === NSMutableDictionary.self)
        XCTAssertFalse(dictMutableCopy2 === dictMutableCopy1)
        XCTAssertTrue(dictMutableCopy2 == dictMutableCopy1)
    }

    func test_writeToFile() {
        let testFilePath = createTestFile("TestFileOut.txt", _contents: Data(capacity: 256))
        if let _ = testFilePath {
            let d1: NSDictionary = [ "foo": "bar", "baz": "qux"]
            let isWritten = d1.write(toFile: testFilePath!, atomically: true)
            if isWritten {
                do {
                    let plistDoc = try XMLDocument(contentsOf: URL(fileURLWithPath: testFilePath!, isDirectory: false), options: [])
                    XCTAssert(plistDoc.rootElement()?.name == "plist")
                    let plist = try PropertyListSerialization.propertyList(from: plistDoc.xmlData, options: [], format: nil) as! [String: Any]
                    XCTAssert((plist["foo"] as? String) == d1["foo"] as? String)
                    XCTAssert((plist["baz"] as? String) == d1["baz"] as? String)
                } catch {
                    XCTFail("Failed to read and parse XMLDocument")
                }
            } else {
                XCTFail("Write to file failed")
            }
            removeTestFile(testFilePath!)
        } else {
            XCTFail("Temporary file creation failed")
        }
    }
    
    func test_initWithContentsOfFile() {
        let testFilePath = createTestFile("TestFileOut.txt", _contents: Data(capacity: 256))
        if let _ = testFilePath {
            let d1: NSDictionary = ["Hello":["world":"again"]]
            let isWritten = d1.write(toFile: testFilePath!, atomically: true)
            if(isWritten) {
                let dict = NSDictionary(contentsOfFile: testFilePath!)
                XCTAssert(dict == d1)
            } else {
                XCTFail("Write to file failed")
            }
            removeTestFile(testFilePath!)
        } else {
            XCTFail("Temporary file creation failed")
        }
    }

    func test_settingWithStringKey() {
        let dict = NSMutableDictionary()
        // has crashed in the past
        dict["stringKey"] = "value"
    }

    private func createTestFile(_ path: String, _contents: Data) -> String? {
        let tempDir = NSTemporaryDirectory() + "TestFoundation_Playground_" + NSUUID().uuidString + "/"
        do {
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: false, attributes: nil)
            if FileManager.default.createFile(atPath: tempDir + "/" + path, contents: _contents,
                                              attributes: nil) {
                return tempDir + path
            } else {
                return nil
            }
        } catch _ {
            return nil
        }
    }
    
    private func removeTestFile(_ location: String) {
        do {
            try FileManager.default.removeItem(atPath: location)
        } catch _ {
            
        }
    }

    func test_AnyHashable() {
        let a1: AnyHashable = ["foo": 1, "bar": 2]
        let a2: AnyHashable = NSDictionary(
            objects: [NSNumber(value: 1), NSNumber(value: 2)],
            forKeys: [NSString(string: "foo"), NSString(string: "bar")])
        let b1: AnyHashable = ["foo": 2, "bar": 1]
        let b2: AnyHashable = NSDictionary(
            objects: [NSNumber(value: 2), NSNumber(value: 1)],
            forKeys: [NSString(string: "foo"), NSString(string: "bar")])
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
