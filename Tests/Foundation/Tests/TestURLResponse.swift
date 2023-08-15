// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestURLResponse : XCTestCase {

    let testURL = URL(string: "test")!

    func test_URL() {
        let url = URL(string: "a/test/path")!
        let res = URLResponse(url: url, mimeType: "txt", expectedContentLength: 0, textEncodingName: nil)
        XCTAssertEqual(res.url, url, "should be the expected url")
    }

    func test_MIMEType() {
        var mimetype: String? = "text/plain"
        var res = URLResponse(url: testURL, mimeType: mimetype, expectedContentLength: 0, textEncodingName: nil)
        XCTAssertEqual(res.mimeType, mimetype, "should be the passed in mimetype")

        mimetype = "APPlication/wordperFECT"
        res = URLResponse(url: testURL, mimeType: mimetype, expectedContentLength: 0, textEncodingName: nil)
        XCTAssertEqual(res.mimeType, mimetype, "should be the other mimetype")

        mimetype = nil
        res = URLResponse(url: testURL, mimeType: mimetype, expectedContentLength: 0, textEncodingName: nil)
        XCTAssertEqual(res.mimeType, mimetype, "should be the other mimetype")
    }

    func test_ExpectedContentLength() {
        var contentLength = 100
        var res = URLResponse(url: testURL, mimeType: "text/plain", expectedContentLength: contentLength, textEncodingName: nil)
        XCTAssertEqual(res.expectedContentLength, Int64(contentLength), "should be positive Int64 content length")

        contentLength = 0
        res = URLResponse(url: testURL, mimeType: nil, expectedContentLength: contentLength, textEncodingName: nil)
        XCTAssertEqual(res.expectedContentLength, Int64(contentLength), "should be zero Int64 content length")

        contentLength = -1
        res = URLResponse(url: testURL, mimeType: nil, expectedContentLength: contentLength, textEncodingName: nil)
        XCTAssertEqual(res.expectedContentLength, Int64(contentLength), "should be invalid (-1) Int64 content length")
    }

    func test_TextEncodingName() {
        let encoding = "utf8"
        var res = URLResponse(url: testURL, mimeType: nil, expectedContentLength: 0, textEncodingName: encoding)
        XCTAssertEqual(res.textEncodingName, encoding, "should be the utf8 encoding")

        res = URLResponse(url: testURL, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        XCTAssertNil(res.textEncodingName)
    }

    func test_suggestedFilename_1() {
        let url = URL(string: "a/test/name.extension")!
        let res = URLResponse(url: url, mimeType: "txt", expectedContentLength: 0, textEncodingName: nil)
        XCTAssertEqual(res.suggestedFilename, "name.extension")
    }

    func test_suggestedFilename_2() {
        let url = URL(string: "a/test/name.extension?foo=bar")!
        let res = URLResponse(url: url, mimeType: "txt", expectedContentLength: 0, textEncodingName: nil)
        XCTAssertEqual(res.suggestedFilename, "name.extension")
    }

    func test_suggestedFilename_3() {
        let url = URL(string: "a://bar")!
        let res = URLResponse(url: url, mimeType: "txt", expectedContentLength: 0, textEncodingName: nil)
        XCTAssertEqual(res.suggestedFilename, "Unknown")
    }

    func test_copyWithZone() {
        let url = URL(string: "a/test/path")!
        let res = URLResponse(url: url, mimeType: "txt", expectedContentLength: 0, textEncodingName: nil)
        XCTAssertTrue(res.isEqual(res.copy() as! NSObject))
    }

    func test_NSCoding() {
        let url = URL(string: "https://apple.com")!
        let responseA = URLResponse(url: url, mimeType: "txt", expectedContentLength: 0, textEncodingName: nil)
        let responseB = try! NSKeyedUnarchiver.unarchivedObject(ofClass: URLResponse.self, from: NSKeyedArchiver.archivedData(withRootObject: responseA))!

        //On macOS unarchived Archived then unarchived `URLResponse` is not equal.
        XCTAssertEqual(responseA.url, responseB.url, "Archived then unarchived url response must be equal.")
        XCTAssertEqual(responseA.mimeType, responseB.mimeType, "Archived then unarchived url response must be equal.")
        XCTAssertEqual(responseA.expectedContentLength, responseB.expectedContentLength, "Archived then unarchived url response must be equal.")
        XCTAssertEqual(responseA.textEncodingName, responseB.textEncodingName, "Archived then unarchived url response must be equal.")
        XCTAssertEqual(responseA.suggestedFilename, responseB.suggestedFilename, "Archived then unarchived url response must be equal.")
    }

    func test_NSCodingEmptySuggestedFilename() {
        let url = URL(string: "https://apple.com")!
        let responseA = URLResponse(url: url, mimeType: "txt", expectedContentLength: 0, textEncodingName: nil)
        
        // archiving in xml format
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.outputFormat = .xml
        archiver.encode(responseA, forKey: NSKeyedArchiveRootObjectKey)
        var plist = String(data: archiver.encodedData, encoding: .utf8)!
        
        // clearing the filename in the archive
        plist = plist.replacingOccurrences(of: "Unknown", with: "")
        let data = plist.data(using: .utf8)!
        
        // unarchiving
        let responseB = try! NSKeyedUnarchiver.unarchivedObject(ofClass: URLResponse.self, from: data)!
        
        XCTAssertEqual(responseB.suggestedFilename, "Unknown", "Unarchived filename must be valid.")
    }

    func test_NSCodingInvalidSuggestedFilename() {
        let url = URL(string: "https://apple.com")!
        let responseA = URLResponse(url: url, mimeType: "txt", expectedContentLength: 0, textEncodingName: nil)
        
        // archiving in xml format
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.outputFormat = .xml
        archiver.encode(responseA, forKey: NSKeyedArchiveRootObjectKey)
        var plist = String(data: archiver.encodedData, encoding: .utf8)!
        
        // invalidating the filename in the archive
        plist = plist.replacingOccurrences(of: "Unknown", with: "invalid/valid")
        let data = plist.data(using: .utf8)!
        
        // unarchiving
        let responseB = try! NSKeyedUnarchiver.unarchivedObject(ofClass: URLResponse.self, from: data)!
        
        XCTAssertEqual(responseB.suggestedFilename, "valid", "Unarchived filename must be valid.")
    }

    func test_equalWithTheSameInstance() throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/"))
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: -1, textEncodingName: nil)

        XCTAssertTrue(response.isEqual(response))
    }

    func test_equalWithUnrelatedObject() throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/"))
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: -1, textEncodingName: nil)

        XCTAssertFalse(response.isEqual(NSObject()))
    }

    func test_equalCheckingURL() throws {
        let url1 = try XCTUnwrap(URL(string: "http://example.com/"))
        let response1 = URLResponse(url: url1, mimeType: nil, expectedContentLength: -1, textEncodingName: nil)

        let url2 = try XCTUnwrap(URL(string: "http://example.com/second"))
        let response2 = URLResponse(url: url2, mimeType: nil, expectedContentLength: -1, textEncodingName: nil)

        let response3 = URLResponse(url: url1, mimeType: nil, expectedContentLength: -1, textEncodingName: nil)

        XCTAssertFalse(response1.isEqual(response2))
        XCTAssertFalse(response2.isEqual(response1))
        XCTAssertTrue(response1.isEqual(response3))
        XCTAssertTrue(response3.isEqual(response1))
    }

    func test_equalCheckingMimeType() throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/"))
        let response1 = URLResponse(url: url, mimeType: "mimeType1", expectedContentLength: -1, textEncodingName: nil)

        let response2 = URLResponse(url: url, mimeType: "mimeType2", expectedContentLength: -1, textEncodingName: nil)

        let response3 = URLResponse(url: url, mimeType: "mimeType1", expectedContentLength: -1, textEncodingName: nil)

        XCTAssertFalse(response1.isEqual(response2))
        XCTAssertFalse(response2.isEqual(response1))
        XCTAssertTrue(response1.isEqual(response3))
        XCTAssertTrue(response3.isEqual(response1))
    }

    func test_equalCheckingExpectedContentLength() throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/"))
        let response1 = URLResponse(url: url, mimeType: nil, expectedContentLength: 100, textEncodingName: nil)

        let response2 = URLResponse(url: url, mimeType: nil, expectedContentLength: 200, textEncodingName: nil)

        let response3 = URLResponse(url: url, mimeType: nil, expectedContentLength: 100, textEncodingName: nil)

        XCTAssertFalse(response1.isEqual(response2))
        XCTAssertFalse(response2.isEqual(response1))
        XCTAssertTrue(response1.isEqual(response3))
        XCTAssertTrue(response3.isEqual(response1))
    }

    func test_equalCheckingTextEncodingName() throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/"))
        let response1 = URLResponse(url: url, mimeType: nil, expectedContentLength: -1, textEncodingName: "textEncodingName1")

        let response2 = URLResponse(url: url, mimeType: nil, expectedContentLength: -1, textEncodingName: "textEncodingName2")

        let response3 = URLResponse(url: url, mimeType: nil, expectedContentLength: -1, textEncodingName: "textEncodingName1")

        XCTAssertFalse(response1.isEqual(response2))
        XCTAssertFalse(response2.isEqual(response1))
        XCTAssertTrue(response1.isEqual(response3))
        XCTAssertTrue(response3.isEqual(response1))
    }

    func test_hash() throws {
        let url1 = try XCTUnwrap(URL(string: "http://example.com/"))
        let response1 = URLResponse(url: url1, mimeType: "mimeType1", expectedContentLength: 100, textEncodingName: "textEncodingName1")

        let url2 = try XCTUnwrap(URL(string: "http://example.com/"))
        let response2 = URLResponse(url: url2, mimeType: "mimeType1", expectedContentLength: 100, textEncodingName: "textEncodingName1")

        let url3 = try XCTUnwrap(URL(string: "http://example.com/second"))
        let response3 = URLResponse(url: url3, mimeType: "mimeType3", expectedContentLength: 200, textEncodingName: "textEncodingName3")

        XCTAssertEqual(response1.hash, response2.hash)
        XCTAssertNotEqual(response1.hash, response3.hash)
        XCTAssertNotEqual(response2.hash, response3.hash)
    }

    static var allTests: [(String, (TestURLResponse) -> () throws -> Void)] {
        return [
            ("test_URL", test_URL),
            ("test_MIMEType", test_MIMEType),
            ("test_ExpectedContentLength", test_ExpectedContentLength),
            ("test_TextEncodingName", test_TextEncodingName),
            ("test_suggestedFilename_1", test_suggestedFilename_1),
            ("test_suggestedFilename_2", test_suggestedFilename_2),
            ("test_suggestedFilename_3", test_suggestedFilename_3),
            ("test_copywithzone", test_copyWithZone),
            ("test_NSCoding", test_NSCoding),
            ("test_NSCodingEmptySuggestedFilename", test_NSCodingEmptySuggestedFilename),
            ("test_NSCodingInvalidSuggestedFilename", test_NSCodingInvalidSuggestedFilename),
            ("test_equalWithTheSameInstance", test_equalWithTheSameInstance),
            ("test_equalWithUnrelatedObject", test_equalWithUnrelatedObject),
            ("test_equalCheckingURL", test_equalCheckingURL),
            ("test_equalCheckingMimeType", test_equalCheckingMimeType),
            ("test_equalCheckingExpectedContentLength", test_equalCheckingExpectedContentLength),
            ("test_equalCheckingTextEncodingName", test_equalCheckingTextEncodingName),
            ("test_hash", test_hash),
        ]
    }
}
