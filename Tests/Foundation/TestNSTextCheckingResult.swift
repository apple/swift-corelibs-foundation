// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestNSTextCheckingResult: XCTestCase {
    func test_textCheckingResult() {
       let patternString = "(a|b)x|123|(?<aname>c|d)y"
       do {
           let patternOptions: NSRegularExpression.Options = []
           let regex = try NSRegularExpression(pattern: patternString, options: patternOptions)
           let searchString = "1x030cy"
           let searchOptions: NSRegularExpression.MatchingOptions = []
           let searchRange = NSRange(location: 0, length: 7)
           let match: NSTextCheckingResult =  regex.firstMatch(in: searchString, options: searchOptions, range: searchRange)!
           //Positive offset
           var result = match.adjustingRanges(offset: 1)
           XCTAssertEqual(result.range(at: 0).location, 6)
           XCTAssertEqual(result.range(at: 1).location, NSNotFound)
           XCTAssertEqual(result.range(at: 2).location, 6)
           if #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
               XCTAssertEqual(result.range(withName: "aname").location, 6)
           }
           //Negative offset
           result = match.adjustingRanges(offset: -2)
           XCTAssertEqual(result.range(at: 0).location, 3)
           XCTAssertEqual(result.range(at: 1).location, NSNotFound)
           XCTAssertEqual(result.range(at: 2).location, 3)
           if #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
               XCTAssertEqual(result.range(withName: "aname").location, 3)
           }
           //ZeroOffset
           result = match.adjustingRanges(offset: 0)
           XCTAssertEqual(result.range(at: 0).location, 5)
           XCTAssertEqual(result.range(at: 1).location, NSNotFound)
           XCTAssertEqual(result.range(at: 2).location, 5)
           if #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
               XCTAssertEqual(result.range(withName: "aname").location, 5)
           }
       } catch {
            XCTFail("Unable to build regular expression for pattern \(patternString)")
       }
    }

    func test_multipleMatches() {
        let patternString = "(?<name>hello)[0-9]"

        do {
            let regex = try NSRegularExpression(pattern: patternString, options: [])
            let searchString = "hello1 hello2"
            let searchRange = NSRange(location: 0, length: searchString.count)
            let matches = regex.matches(in: searchString, options: [], range: searchRange)
            XCTAssertEqual(matches.count, 2)
            XCTAssertEqual(matches[0].numberOfRanges, 2)
            XCTAssertEqual(matches[0].range, NSRange(location: 0, length: 6))
            XCTAssertEqual(matches[0].range(at: 0), NSRange(location: 0, length: 6))
            XCTAssertEqual(matches[0].range(at: 1), NSRange(location: 0, length: 5))
            if #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
                XCTAssertEqual(matches[0].range(withName: "name"), NSRange(location: 0, length: 5))
            }
            XCTAssertEqual(matches[1].numberOfRanges, 2)
            XCTAssertEqual(matches[1].range, NSRange(location: 7, length: 6))
            XCTAssertEqual(matches[1].range(at: 0), NSRange(location: 7, length: 6))
            XCTAssertEqual(matches[1].range(at: 1), NSRange(location: 7, length: 5))
            if #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
                XCTAssertEqual(matches[1].range(withName: "name"), NSRange(location: 7, length: 5))
            }
        } catch {
            XCTFail("Unable to build regular expression for pattern \(patternString)")
        }
    }


    func test_rangeWithName() {
        guard #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) else {
            return
        }

        let patternString = "(?<name1>hel)lo, (?<name2>worl)d"

        do {
            let regex = try NSRegularExpression(pattern: patternString, options: [])
            let searchString = "hello, world"
            let searchRange = NSRange(location: 0, length: searchString.count)
            let matches = regex.matches(in: searchString, options: [], range: searchRange)
            XCTAssertEqual(matches.count, 1)
            XCTAssertEqual(matches[0].numberOfRanges, 3)
            XCTAssertEqual(matches[0].range(withName: "incorrect").location, NSNotFound)
            XCTAssertEqual(matches[0].range(withName: "name1"), NSRange(location: 0, length: 3))
            XCTAssertEqual(matches[0].range(withName: "name2"), NSRange(location: 7, length: 4))
        } catch {
            XCTFail("Unable to build regular expression for pattern \(patternString)")
        }
    }
    
    let fixtures = [
        Fixtures.textCheckingResultSimpleRegex,
        Fixtures.textCheckingResultExtendedRegex,
        Fixtures.textCheckingResultComplexRegex,
    ]
    
    private func areEqual(_ lhs: NSTextCheckingResult, _ rhs: NSTextCheckingResult) -> Bool {
        guard lhs.resultType == rhs.resultType else { return false }
        guard lhs.numberOfRanges == rhs.numberOfRanges else { return false }
        
        for i in 0 ..< lhs.numberOfRanges {
            guard lhs.range(at: i) == rhs.range(at: i) else {
                return false
            }
        }
        
        guard lhs.regularExpression == rhs.regularExpression else {
            return false
        }
        
        return true
    }
    
    func test_codingRoundtrip() throws {
        for fixture in fixtures {
            try fixture.assertValueRoundtripsInCoder(secureCoding: true, matchingWith: areEqual(_:_:))
        }
    }
    
    func test_loadedValuesMatch() throws {
        for fixture in fixtures {
            try fixture.assertLoadedValuesMatch(areEqual(_:_:))
        }
    }
}
