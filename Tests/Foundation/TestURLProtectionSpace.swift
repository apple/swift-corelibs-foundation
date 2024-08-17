// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
    #if canImport(SwiftFoundationNetworking) && !DEPLOYMENT_RUNTIME_OBJC
    @testable import SwiftFoundationNetworking
    #else
        #if canImport(FoundationNetworking)
        @testable import FoundationNetworking
        #endif
    #endif
#endif

class TestURLProtectionSpace : XCTestCase {
    func test_description() {
        var space = URLProtectionSpace(
            host: "apple.com",
            port: 80,
            protocol: "http",
            realm: nil,
            authenticationMethod: "basic"
        )
        XCTAssert(space.description.hasPrefix("<\(type(of: space))"))
        XCTAssert(space.description.hasSuffix(": Host:apple.com, Server:http, Auth-Scheme:NSURLAuthenticationMethodDefault, Realm:(null), Port:80, Proxy:NO, Proxy-Type:(null)"))

        space = URLProtectionSpace(
            host: "apple.com",
            port: 80,
            protocol: "http",
            realm: nil,
            authenticationMethod: "NSURLAuthenticationMethodHTMLForm"
        )
        XCTAssert(space.description.hasPrefix("<\(type(of: space))"))
        XCTAssert(space.description.hasSuffix(": Host:apple.com, Server:http, Auth-Scheme:NSURLAuthenticationMethodHTMLForm, Realm:(null), Port:80, Proxy:NO, Proxy-Type:(null)"))
    }

    #if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
    func test_createWithHTTPURLresponse() throws {
        // Real response from outlook.office365.com
        let headerFields1 = [
            "Server": "Microsoft-IIS/10.0",
            "request-id": "c71c2202-4013-4d64-9319-d40aba6bbe5c",
            "WWW-Authenticate": "Basic Realm=\"\"",
            "X-Powered-By": "ASP.NET",
            "X-FEServer": "AM6PR0502CA0062",
            "Date": "Sat, 04 Apr 2020 16:19:39 GMT",
            "Content-Length": "0",
        ]
        let response1 = try XCTUnwrap(HTTPURLResponse(url: URL(string: "https://outlook.office365.com/Microsoft-Server-ActiveSync")!,
                                                      statusCode: 401,
                                                      httpVersion: "HTTP/1.1",
                                                      headerFields: headerFields1))
        let space1 = try XCTUnwrap(URLProtectionSpace.create(with: response1), "Failed to create protection space from valid response")

        XCTAssertEqual(space1.authenticationMethod, NSURLAuthenticationMethodHTTPBasic)
        XCTAssertEqual(space1.protocol, "https")
        XCTAssertEqual(space1.host, "outlook.office365.com")
        XCTAssertEqual(space1.port, 443)
        XCTAssertEqual(space1.realm, "")

        // Real response from jigsaw.w3.org
        let headerFields2 = [
            "date": "Sat, 04 Apr 2020 17:24:23 GMT",
            "content-length": "261",
            "content-type": "text/html;charset=ISO-8859-1",
            "server": "Jigsaw/2.3.0-beta3",
            "www-authenticate": "Basic realm=\"test\"",
            "strict-transport-security": "max-age=15552015; includeSubDomains; preload",
            "public-key-pins": "pin-sha256=\"cN0QSpPIkuwpT6iP2YjEo1bEwGpH/yiUn6yhdy+HNto=\"; pin-sha256=\"WGJkyYjx1QMdMe0UqlyOKXtydPDVrk7sl2fV+nNm1r4=\"; pin-sha256=\"LrKdTxZLRTvyHM4/atX2nquX9BeHRZMCxg3cf4rhc2I=\"; max-age=864000",
            "x-frame-options": "deny",
            "x-xss-protection": "1; mode=block",
        ]
        let response2 = try XCTUnwrap(HTTPURLResponse(url: URL(string: "https://jigsaw.w3.org/HTTP/Basic/")!,
                                                      statusCode: 401,
                                                      httpVersion: "HTTP/2",
                                                      headerFields: headerFields2))
        let space2 = try XCTUnwrap(URLProtectionSpace.create(with: response2), "Failed to create protection space from valid response")

        XCTAssertEqual(space2.authenticationMethod, NSURLAuthenticationMethodHTTPBasic)
        XCTAssertEqual(space2.protocol, "https")
        XCTAssertEqual(space2.host, "jigsaw.w3.org")
        XCTAssertEqual(space2.port, 443)
        XCTAssertEqual(space2.realm, "test")

        // Digest is not supported
        let authenticate3 = "Digest realm=\"Test\", domain=\"/HTTP/Digest\", nonce=\"be2e96ad8ab8acb7ccfb49bc7e162914\""
        let response3 = try XCTUnwrap(HTTPURLResponse(url: URL(string: "http://jigsaw.w3.org/HTTP/Basic/")!,
                                                      statusCode: 401,
                                                      httpVersion: "HTTP/1.1",
                                                      headerFields: ["www-authenticate" : authenticate3]))
        XCTAssertNil(URLProtectionSpace.create(with: response3), "Digest scheme is not supported, should not create protection space")

        // NTLM is not supported
        let response4 = try XCTUnwrap(HTTPURLResponse(url: URL(string: "http://apple.com:333")!,
                                                      statusCode: 401,
                                                      httpVersion: "HTTP/1.1",
                                                      headerFields: ["www-authenTicate" : "NTLM realm=\"\""]))
        XCTAssertNil(URLProtectionSpace.create(with: response4), "NTLM scheme is not supported, should not create protection space")

        // Some broken headers
        let response5 = try XCTUnwrap(HTTPURLResponse(url: URL(string: "http://apple.com")!,
                                                      statusCode: 401,
                                                      httpVersion: "HTTP/1.1",
                                                      headerFields: ["www-authenicate" : "Basic"]))
        XCTAssertNil(URLProtectionSpace.create(with: response5), "Should not create protection space from invalid header")

        let response6 = try XCTUnwrap(HTTPURLResponse(url: URL(string: "http://apple.com")!,
                                                      statusCode: 401,
                                                      httpVersion: "HTTP/1.1",
                                                      headerFields: ["www-authenticate" : "NT LM realm="]))
        XCTAssertNil(URLProtectionSpace.create(with: response6), "Should not create protection space from invalid header")

    }

    func test_challenge() throws {
        XCTAssertEqual(_HTTPURLProtocol._HTTPMessage._Challenge.challenges(from: "").count, 0, "No challenges should be parsed from empty string")
        
        // This is valid challenges list as per RFC-7235, but it doesn't contain any known auth scheme
        XCTAssertEqual(_HTTPURLProtocol._HTTPMessage._Challenge.challenges(from: "maybe challenge, maybe not").count, 0, "String doesn't contain any of supported schemes")
        
        let challenges1 = _HTTPURLProtocol._HTTPMessage._Challenge.challenges(from: "Basic Realm=\"Test\",charset=\"utf-8\", other=\"be2e96ad8ab8acb7ccfb49bc7e162914\"")
        XCTAssertEqual(challenges1.count, 1, "String contains valid challenge")
        let challenge1_1 = try XCTUnwrap(challenges1.first)
        XCTAssertEqual(challenge1_1.authScheme, "Basic")
        XCTAssertEqual(challenge1_1.authParameters.count, 3, "Wrong number of parameters in challenge")
        let param1_1_1 = try XCTUnwrap(challenge1_1.parameter(withName: "realm"))
        XCTAssertEqual(param1_1_1.name, "Realm")
        XCTAssertEqual(param1_1_1.value, "Test")
        let param1_1_2 = try XCTUnwrap(challenge1_1.parameter(withName: "chaRSet"))
        XCTAssertEqual(param1_1_2.name, "charset")
        XCTAssertEqual(param1_1_2.value, "utf-8")
        let param1_1_3 = try XCTUnwrap(challenge1_1.parameter(withName: "OTHER"))
        XCTAssertEqual(param1_1_3.name, "other")
        XCTAssertEqual(param1_1_3.value, "be2e96ad8ab8acb7ccfb49bc7e162914")
        
        // Several challenges, but only two of them should be valid
        let challenges2 = _HTTPURLProtocol._HTTPMessage._Challenge.challenges(from: "Digest realm=\"Unsupported\", Basic, basic realm =    \"First \\\" realm\", Basic realm=\"Second realm\"")
        XCTAssertEqual(challenges2.count, 2, "String contains 2 valid challenges")
        let challenge2_1 = try XCTUnwrap(challenges2.first)
        XCTAssertEqual(challenge2_1.authScheme, "basic")
        XCTAssertEqual(challenge2_1.authParameters.count, 1, "Wrong number of parameters in challenge")
        let param2_1_1 = try XCTUnwrap(challenge2_1.parameter(withName: "realm"))
        XCTAssertEqual(param2_1_1.name, "realm")
        XCTAssertEqual(param2_1_1.value, "First \" realm") // contains escaped quote
        
        let challenge2_2 = try XCTUnwrap(challenges2.last)
        XCTAssertEqual(challenge2_2.authScheme, "Basic")
        XCTAssertEqual(challenge2_2.authParameters.count, 1, "Wrong number of parameters in challenge")
        let param2_2_1 = try XCTUnwrap(challenge2_2.parameter(withName: "realm"))
        XCTAssertEqual(param2_2_1.name, "realm")
        XCTAssertEqual(param2_2_1.value, "Second realm")
        
        // Some tricky and broken strings to test edge cases in parse process
        let challenges3 = _HTTPURLProtocol._HTTPMessage._Challenge.challenges(from: "not real, Basic realm=\"Second realm\"")
        XCTAssertEqual(challenges3.count, 1, "String contains 1 valid challenge")
        
        let challenges4 = _HTTPURLProtocol._HTTPMessage._Challenge.challenges(from: "Basic realm=\"Second realm\"charset=")
        XCTAssertEqual(challenges4.count, 1, "String contains 1 valid challenge")
        let challenge4_1 = try XCTUnwrap(challenges4.first)
        XCTAssertEqual(challenge4_1.authScheme, "Basic")
        XCTAssertEqual(challenge4_1.authParameters.count, 1, "Wrong number of parameters in challenge")
        let param4_1_1 = try XCTUnwrap(challenge4_1.parameter(withName: "realm"))
        XCTAssertEqual(param4_1_1.name, "realm")
        XCTAssertEqual(param4_1_1.value, "Second realm")
        
        let challenges5 = _HTTPURLProtocol._HTTPMessage._Challenge.challenges(from: "Basic reALm = \"Second realm\",charset=")
        XCTAssertEqual(challenges5.count, 1, "String contains 1 valid challenge")
        let challenge5_1 = try XCTUnwrap(challenges5.first)
        XCTAssertEqual(challenge5_1.authScheme, "Basic")
        XCTAssertEqual(challenge5_1.authParameters.count, 1, "Wrong number of parameters in challenge")
        let param5_1_1 = try XCTUnwrap(challenge5_1.parameter(withName: "realm"))
        XCTAssertEqual(param5_1_1.name, "reALm")
        XCTAssertEqual(param5_1_1.value, "Second realm")
        
        let challenges6 = _HTTPURLProtocol._HTTPMessage._Challenge.challenges(from: "Basic realm=\"Broken realm")
        XCTAssertTrue(challenges6.isEmpty, "String doesn't contains a valid challenge")
        
        let challenges7 = _HTTPURLProtocol._HTTPMessage._Challenge.challenges(from: "Basic charset=\"utf-8\"")
        XCTAssertTrue(challenges7.isEmpty, "String doesn't contains a valid challenge")
        
        let challenges8 = _HTTPURLProtocol._HTTPMessage._Challenge.challenges(from: "Basic realm=\"Oh no,basic REALM=\"World's okayest realm\", param=\"\"")
        XCTAssertEqual(challenges8.count, 2, "String contains 2 valid challenge")
        let challenge8_1 = try XCTUnwrap(challenges8.first)
        XCTAssertEqual(challenge8_1.authScheme, "Basic")
        XCTAssertEqual(challenge8_1.authParameters.count, 1, "Wrong number of parameters in challenge")
        let param8_1_1 = try XCTUnwrap(challenge8_1.parameter(withName: "realm"))
        XCTAssertEqual(param8_1_1.name, "realm")
        XCTAssertEqual(param8_1_1.value, "Oh no,basic REALM=")
        
        let challenge8_2 = try XCTUnwrap(challenges8.last)
        XCTAssertEqual(challenge8_2.authScheme, "basic")
        XCTAssertEqual(challenge8_2.authParameters.count, 2, "Wrong number of parameters in challenge")
        let param8_2_1 = try XCTUnwrap(challenge8_2.parameter(withName: "realm"))
        XCTAssertEqual(param8_2_1.name, "REALM")
        XCTAssertEqual(param8_2_1.value, "World's okayest realm")
        let param8_2_2 = try XCTUnwrap(challenge8_2.parameter(withName: "param"))
        XCTAssertEqual(param8_2_2.name, "param")
        XCTAssertEqual(param8_2_2.value, "")
    }
    #endif
}
