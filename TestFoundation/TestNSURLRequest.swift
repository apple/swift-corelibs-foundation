// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


#if DEPLOYMENT_RUNTIME_OBJC || os(Linux)
    import Foundation
    import XCTest
#else
    import SwiftFoundation
    import SwiftXCTest
#endif

class TestNSURLRequest : XCTestCase {
    
    var allTests : [(String, () -> ())] {
        return [
            ("test_construction", test_construction),
        ]
    }
    
    func test_construction() {
        let URL = NSURL(string: "http://swift.org")!
        let request = NSURLRequest(URL: URL)
        // Match OS X Foundation responses
        XCTAssertNotNil(request)
        XCTAssertEqual(request.URL, URL)
        XCTAssertEqual(request.HTTPMethod, "GET")
        XCTAssertNil(request.allHTTPHeaderFields)
        XCTAssertNil(request.mainDocumentURL)
    }
}