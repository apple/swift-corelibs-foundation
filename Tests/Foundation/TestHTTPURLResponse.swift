// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestHTTPURLResponse: XCTestCase {

    let url = URL(string: "https://www.swift.org")!

    func test_URL_and_status_1() {
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Length": "5299"])
        XCTAssertEqual(sut?.url, url)
        XCTAssertEqual(sut?.statusCode, 200)
    }

    func test_URL_and_status_2() {
        let url = URL(string: "http://www.apple.com")!
        let sut = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Content-Length": "5299"])
        XCTAssertEqual(sut?.url, url)
        XCTAssertEqual(sut?.statusCode, 302)
    }

    func test_headerFields_1() {
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)
        XCTAssertEqual(sut?.allHeaderFields.count, 0)
    }
    func test_headerFields_2() {
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [:])
        XCTAssertEqual(sut?.allHeaderFields.count, 0)
    }
    func test_headerFields_3() {
        let f = ["A": "1", "B": "2"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.allHeaderFields.count, 2)
        XCTAssertEqual(sut?.allHeaderFields["A"] as! String, "1")
        XCTAssertEqual(sut?.allHeaderFields["B"] as! String, "2")
    }

    // Note that the message content length is different from the message
    // transfer length.
    // The transfer length can only be derived when the Transfer-Encoding is identity (default).
    // For compressed content (Content-Encoding other than identity), there is not way to derive the
    // content length from the transfer length.
    //
    // C.f. <https://tools.ietf.org/html/rfc2616#section-4.4>

    func test_contentLength_available_1() {
        let f = ["Content-Length": "997"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.expectedContentLength, 997)
    }
    func test_contentLength_available_2() {
        let f = ["Content-Length": "997", "Transfer-Encoding": "identity"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.expectedContentLength, 997)
    }
    func test_contentLength_available_3() {
        let f = ["Content-Length": "997", "Content-Encoding": "identity"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.expectedContentLength, 997)
    }
    func test_contentLength_available_4() {
        let f = ["Content-Length": "997", "Content-Encoding": "identity", "Transfer-Encoding": "identity"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.expectedContentLength, 997)
    }

    func test_contentLength_notAvailable() {
        let f = ["Server": "Apache"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.expectedContentLength, -1)
    }
    func test_contentLength_withTransferEncoding() {
        let f = ["Content-Length": "997", "Transfer-Encoding": "chunked"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.expectedContentLength, 997)
    }
    func test_contentLength_withContentEncoding() {
        let f = ["Content-Length": "997", "Content-Encoding": "deflate"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.expectedContentLength, 997)
    }
    func test_contentLength_withContentEncodingAndTransferEncoding() {
        let f = ["Content-Length": "997", "Content-Encoding": "deflate", "Transfer-Encoding": "identity"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.expectedContentLength, 997)
    }
    func test_contentLength_withContentEncodingAndTransferEncoding_2() {
        let f = ["Content-Length": "997", "Content-Encoding": "identity", "Transfer-Encoding": "chunked"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.expectedContentLength, 997)
    }

    // The `suggestedFilename` can be derived from the "Content-Disposition"
    // header as defined in RFC 1806 and more recently RFC 2183
    // https://tools.ietf.org/html/rfc1806
    // https://tools.ietf.org/html/rfc2183
    //
    // Typical use looks like this:
    //     Content-Disposition: attachment; filename="fname.ext"
    //
    // As noted in https://tools.ietf.org/html/rfc2616#section-19.5.1 the
    // receiving user agent SHOULD NOT respect any directory path information
    // present in the filename-parm parameter.
    //

    func test_suggestedFilename_notAvailable_1() {
        let f: [String: String] = [:]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.suggestedFilename, "Unknown")
    }
    func test_suggestedFilename_notAvailable_2() {
        let f = ["Content-Disposition": "inline"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.suggestedFilename, "Unknown")
    }

    func test_suggestedFilename_1() {
        let f = ["Content-Disposition": "attachment; filename=\"fname.ext\""]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.suggestedFilename, "fname.ext")
    }

    func test_suggestedFilename_2() {
        let f = ["Content-Disposition": "attachment; filename=genome.jpeg; modification-date=\"Wed, 12 Feb 1997 16:29:51 -0500\";"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.suggestedFilename, "genome.jpeg")
    }
    func test_suggestedFilename_3() {
        let f = ["Content-Disposition": "attachment; filename=\";.ext\""]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.suggestedFilename, ";.ext")
    }
    func test_suggestedFilename_4() {
        let f = ["Content-Disposition": "attachment; aa=bb\\; filename=\"wrong.ext\"; filename=\"fname.ext\"; cc=dd"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.suggestedFilename, "fname.ext")
    }

    func test_suggestedFilename_removeSlashes_1() {
        let f = ["Content-Disposition": "attachment; filename=\"/a/b/name\""]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.suggestedFilename, "_a_b_name")
    }
    func test_suggestedFilename_removeSlashes_2() {
        let f = ["Content-Disposition": "attachment; filename=\"a/../b/name\""]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.suggestedFilename, "a_.._b_name")
    }

    // The MIME type / character encoding

    func test_MIMETypeAndCharacterEncoding_1() {
        let f = ["Server": "Apache"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertNil(sut?.mimeType)
        XCTAssertNil(sut?.textEncodingName)
    }
    func test_MIMETypeAndCharacterEncoding_2() {
        let f = ["Content-Type": "text/html"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.mimeType, "text/html")
        XCTAssertNil(sut?.textEncodingName)
    }
    func test_MIMETypeAndCharacterEncoding_3() {
        let f = ["Content-Type": "text/HTML; charset=ISO-8859-4"]
        let sut = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)
        XCTAssertEqual(sut?.mimeType, "text/html")
        XCTAssertEqual(sut?.textEncodingName, "iso-8859-4")
    }

    func test_fieldCapitalisation() throws {
        let f = [
            "location": "/newLocation",
            "conTent-lenGTH": "123",
            "CONTENT-type": "text/plAIn; charset=ISO-8891-1",
            "x-extra-HEADER": "my Header",
            "X-UPPERCASE": "UPPERCASE",
            "x-lowercase": "lowercase",
            "X-mixedCASE": "MIXEDcase",
            "vary": "much",
            "X-xss-protection": "1; mode=block",

        ]
        guard let sut = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: f) else {
            XCTFail("Cant create HTTPURLResponse")
            return
        }
        XCTAssertEqual(sut.statusCode, 302)
        XCTAssertEqual(sut.expectedContentLength, 123)
        XCTAssertEqual(sut.mimeType, "text/plain")
        XCTAssertEqual(sut.textEncodingName, "iso-8891-1")

        guard let ahf = sut.allHeaderFields as? [String: String] else {
            XCTFail("Cant read .allheaderFields")
            return
        }

        XCTAssertEqual(sut.value(forHTTPHeaderField: "location"), "/newLocation")
        XCTAssertEqual(sut.value(forHTTPHeaderField: "LOcation"), "/newLocation")
        XCTAssertEqual(sut.value(forHTTPHeaderField: "locATIon"), "/newLocation")
        XCTAssertEqual(sut.value(forHTTPHeaderField: "x-extra-HEADER"), "my Header")
        XCTAssertEqual(sut.value(forHTTPHeaderField: "X-EXTRA-HEADER"), "my Header")
        XCTAssertEqual(sut.value(forHTTPHeaderField: "x-ExTrA-header"), "my Header")

        XCTAssertEqual(ahf["Location"], "/newLocation")
        XCTAssertEqual(ahf["Content-Length"], "123")
        XCTAssertEqual(ahf["Content-Type"], "text/plAIn; charset=ISO-8891-1")
        XCTAssertEqual(ahf["x-extra-HEADER"], "my Header")
        XCTAssertEqual(ahf["X-UPPERCASE"], "UPPERCASE")
        XCTAssertEqual(ahf["x-lowercase"], "lowercase")
        XCTAssertEqual(ahf["X-mixedCASE"], "MIXEDcase")

        XCTAssertNil(ahf["location"])
        XCTAssertNil(ahf["conTent-lenGTH"])
        XCTAssertNil(ahf["CONTENT-type"])
        XCTAssertNil(ahf["X-Extra-Header"])
        XCTAssertNil(ahf["X-Uppercase"])
        XCTAssertNil(ahf["X-Lowercase"])
        XCTAssertNil(ahf["X-Mixedcase"])
    }

    // NSCoding

    func test_NSCoding() {
        let url = URL(string: "https://apple.com")!
        let f = ["Content-Type": "text/HTML; charset=ISO-8859-4",
				 "Content-Disposition": "attachment; filename=fname.ext"]

        let responseA = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: f)!
        let responseB = NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: responseA)) as! HTTPURLResponse

        //On macOS unarchived Archived then unarchived `URLResponse` is not equal.
        XCTAssertEqual(responseA.statusCode, responseB.statusCode, "Archived then unarchived http url response must be equal.")
        XCTAssertEqual(Array(responseA.allHeaderFields.keys), Array(responseB.allHeaderFields.keys), "Archived then unarchived http url response must be equal.")

        for key in responseA.allHeaderFields.keys {
            XCTAssertEqual(responseA.allHeaderFields[key] as? String, responseB.allHeaderFields[key] as? String, "Archived then unarchived http url response must be equal.")
        }

        XCTAssertEqual(responseA.url, responseB.url, "Archived then unarchived http url response must be equal.")
        XCTAssertEqual(responseA.mimeType, responseB.mimeType, "Archived then unarchived http url response must be equal.")
        XCTAssertEqual(responseA.expectedContentLength, responseB.expectedContentLength, "Archived then unarchived http url response must be equal.")
        XCTAssertEqual(responseA.textEncodingName, responseB.textEncodingName, "Archived then unarchived http url response must be equal.")
        XCTAssertEqual(responseA.suggestedFilename, responseB.suggestedFilename, "Archived then unarchived http url response must be equal.")
    }
}
