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


class TestNSGeometry : XCTestCase {

    var allTests : [(String, () -> ())] {
        return [
            ("test_CGFloat_BasicConstruction", test_CGFloat_BasicConstruction),
            ("test_CGFloat_Equality", test_CGFloat_Equality),
            ("test_CGFloat_LessThanOrEqual", test_CGFloat_LessThanOrEqual),
            ("test_CGFloat_GreaterThanOrEqual", test_CGFloat_GreaterThanOrEqual),
            ("test_CGPoint_BasicConstruction", test_CGPoint_BasicConstruction),
            ("test_CGSize_BasicConstruction", test_CGSize_BasicConstruction),
            ("test_CGRect_BasicConstruction", test_CGRect_BasicConstruction),
            ("test_NSMakePoint", test_NSMakePoint),
            ("test_NSMakeSize", test_NSMakeSize),
            ("test_NSMakeRect", test_NSMakeRect),
            ("test_NSUnionRect", test_NSUnionRect),
            ("test_NSIntersectionRect", test_NSIntersectionRect),
            ("test_NSOffsetRect", test_NSOffsetRect),
            ("test_NSPointInRect", test_NSPointInRect),
            ("test_NSMouseInRect", test_NSMouseInRect),
            ("test_NSContainsRect", test_NSContainsRect),
            ("test_NSIntersectsRect", test_NSIntersectsRect),
            ("test_NSIntegralRect", test_NSIntegralRect),
            ("test_NSIntegralRectWithOptions", test_NSIntegralRectWithOptions),
        ]
    }

    func test_CGFloat_BasicConstruction() {
        XCTAssertEqual(CGFloat().native, 0.0)
        XCTAssertEqual(CGFloat(Double(3.0)).native, 3.0)
    }

    func test_CGFloat_Equality() {
        XCTAssertEqual(CGFloat(), CGFloat())
        XCTAssertEqual(CGFloat(1.0), CGFloat(1.0))
        XCTAssertEqual(CGFloat(-42.0), CGFloat(-42.0))

        XCTAssertNotEqual(CGFloat(1.0), CGFloat(1.4))
        XCTAssertNotEqual(CGFloat(37.3), CGFloat(-42.0))
        XCTAssertNotEqual(CGFloat(1.345), CGFloat())
    }

    func test_CGFloat_LessThanOrEqual() {
        let w = CGFloat(-4.5)
        let x = CGFloat(1.0)
        let y = CGFloat(2.2)

        XCTAssertLessThanOrEqual(CGFloat(), CGFloat())
        XCTAssertLessThanOrEqual(w, w)
        XCTAssertLessThanOrEqual(y, y)

        XCTAssertLessThan(w, x)
        XCTAssertLessThanOrEqual(w, x)
        XCTAssertLessThan(x, y)
        XCTAssertLessThanOrEqual(x, y)
        XCTAssertLessThan(w, y)
        XCTAssertLessThanOrEqual(w, y)
    }

    func test_CGFloat_GreaterThanOrEqual() {
        let w = CGFloat(-4.5)
        let x = CGFloat(1.0)
        let y = CGFloat(2.2)

        XCTAssertGreaterThanOrEqual(CGFloat(), CGFloat())
        XCTAssertGreaterThanOrEqual(w, w)
        XCTAssertGreaterThanOrEqual(y, y)

        XCTAssertGreaterThan(x, w)
        XCTAssertGreaterThanOrEqual(x, w)
        XCTAssertGreaterThan(y, x)
        XCTAssertGreaterThanOrEqual(y, x)
        XCTAssertGreaterThan(y, w)
        XCTAssertGreaterThanOrEqual(y, w)
    }

    func test_CGPoint_BasicConstruction() {
        let p1 = CGPoint()
        XCTAssertEqual(p1.x, CGFloat(0.0))
        XCTAssertEqual(p1.y, CGFloat(0.0))

        let p2 = CGPoint(x: CGFloat(3.6), y: CGFloat(4.5))
        XCTAssertEqual(p2.x, CGFloat(3.6))
        XCTAssertEqual(p2.y, CGFloat(4.5))
    }

    func test_CGSize_BasicConstruction() {
        let s1 = CGSize()
        XCTAssertEqual(s1.width, CGFloat(0.0))
        XCTAssertEqual(s1.height, CGFloat(0.0))

        let s2 = CGSize(width: CGFloat(3.6), height: CGFloat(4.5))
        XCTAssertEqual(s2.width, CGFloat(3.6))
        XCTAssertEqual(s2.height, CGFloat(4.5))
    }

    func test_CGRect_BasicConstruction() {
        let r1 = CGRect()
        XCTAssertEqual(r1.origin.x, CGFloat(0.0))
        XCTAssertEqual(r1.origin.y, CGFloat(0.0))
        XCTAssertEqual(r1.size.width, CGFloat(0.0))
        XCTAssertEqual(r1.size.height, CGFloat(0.0))

        let p = CGPoint(x: CGFloat(2.2), y: CGFloat(3.0))
        let s = CGSize(width: CGFloat(5.0), height: CGFloat(5.0))
        let r2 = CGRect(origin: p, size: s)
        XCTAssertEqual(r2.origin.x, p.x)
        XCTAssertEqual(r2.origin.y, p.y)
        XCTAssertEqual(r2.size.width, s.width)
        XCTAssertEqual(r2.size.height, s.height)
    }

    func test_NSMakePoint() {
        let p2 = NSMakePoint(CGFloat(3.6), CGFloat(4.5))
        XCTAssertEqual(p2.x, CGFloat(3.6))
        XCTAssertEqual(p2.y, CGFloat(4.5))
    }

    func test_NSMakeSize() {
        let s2 = NSMakeSize(CGFloat(3.6), CGFloat(4.5))
        XCTAssertEqual(s2.width, CGFloat(3.6))
        XCTAssertEqual(s2.height, CGFloat(4.5))
    }

    func test_NSMakeRect() {
        let r2 = NSMakeRect(CGFloat(2.2), CGFloat(3.0), CGFloat(5.0), CGFloat(5.0))
        XCTAssertEqual(r2.origin.x, CGFloat(2.2))
        XCTAssertEqual(r2.origin.y, CGFloat(3.0))
        XCTAssertEqual(r2.size.width, CGFloat(5.0))
        XCTAssertEqual(r2.size.height, CGFloat(5.0))
    }

    func test_NSUnionRect() {
        let r1 = NSMakeRect(CGFloat(1.2), CGFloat(3.1), CGFloat(10.0), CGFloat(10.0))
        let r2 = NSMakeRect(CGFloat(10.2), CGFloat(2.5), CGFloat(5.0), CGFloat(5.0))

        XCTAssertTrue(NSIsEmptyRect(NSUnionRect(NSZeroRect, NSZeroRect)))
        XCTAssertTrue(NSEqualRects(r1, NSUnionRect(r1, NSZeroRect)))
        XCTAssertTrue(NSEqualRects(r2, NSUnionRect(NSZeroRect, r2)))

        let r3 = NSUnionRect(r1, r2)
        XCTAssertEqual(r3.origin.x, CGFloat(1.2))
        XCTAssertEqual(r3.origin.y, CGFloat(2.5))
        XCTAssertEqual(r3.size.width, CGFloat(14.0))
        XCTAssertEqual(r3.size.height, CGFloat(10.6))
    }

    func test_NSIntersectionRect() {
        let r1 = NSMakeRect(CGFloat(1.2), CGFloat(3.1), CGFloat(10.0), CGFloat(10.0))
        let r2 = NSMakeRect(CGFloat(-2.3), CGFloat(-1.5), CGFloat(1.0), CGFloat(1.0))
        let r3 = NSMakeRect(CGFloat(10.2), CGFloat(2.5), CGFloat(5.0), CGFloat(5.0))

        XCTAssertTrue(NSIsEmptyRect(NSIntersectionRect(r1, r2)))

        let r4 = NSIntersectionRect(r1, r3)
        XCTAssertEqual(r4.origin.x, CGFloat(10.2))
        XCTAssertEqual(r4.origin.y, CGFloat(3.1))
        XCTAssertEqual(r4.size.width, CGFloat(1.0))
        XCTAssertEqual(r4.size.height, CGFloat(4.4))
    }

    func test_NSOffsetRect() {
        let r1 = NSMakeRect(CGFloat(1.2), CGFloat(3.1), CGFloat(10.0), CGFloat(10.0))
        let r2 = NSOffsetRect(r1, CGFloat(2.0), CGFloat(-5.0))
        let expectedRect = NSMakeRect(CGFloat(3.2), CGFloat(-1.9), CGFloat(10.0), CGFloat(10.0))
        
        XCTAssertTrue(NSEqualRects(r2, expectedRect))
    }

    func test_NSPointInRect() {
        let p1 = NSMakePoint(CGFloat(2.2), CGFloat(5.3))
        let p2 = NSMakePoint(CGFloat(1.2), CGFloat(3.1))
        let p3 = NSMakePoint(CGFloat(1.2), CGFloat(5.3))
        let p4 = NSMakePoint(CGFloat(5.2), CGFloat(3.1))
        let p5 = NSMakePoint(CGFloat(11.2), CGFloat(13.1))
        let r1 = NSMakeRect(CGFloat(1.2), CGFloat(3.1), CGFloat(10.0), CGFloat(10.0))
        let r2 = NSMakeRect(CGFloat(-2.3), CGFloat(-1.5), CGFloat(1.0), CGFloat(1.0))

        XCTAssertFalse(NSPointInRect(NSZeroPoint, NSZeroRect))
        XCTAssertFalse(NSPointInRect(p1, r2))
        XCTAssertTrue(NSPointInRect(p1, r1))
        XCTAssertTrue(NSPointInRect(p2, r1))
        XCTAssertTrue(NSPointInRect(p3, r1))
        XCTAssertTrue(NSPointInRect(p4, r1))
        XCTAssertFalse(NSPointInRect(p5, r1))
    }

    func test_NSMouseInRect() {
        let p1 = NSMakePoint(CGFloat(2.2), CGFloat(5.3))
        let r1 = NSMakeRect(CGFloat(1.2), CGFloat(3.1), CGFloat(10.0), CGFloat(10.0))
        let r2 = NSMakeRect(CGFloat(-2.3), CGFloat(-1.5), CGFloat(1.0), CGFloat(1.0))

        XCTAssertFalse(NSMouseInRect(NSZeroPoint, NSZeroRect, true))
        XCTAssertFalse(NSMouseInRect(p1, r2, true))
        XCTAssertTrue(NSMouseInRect(p1, r1, true))

        let p2 = NSMakePoint(NSMinX(r1), NSMaxY(r1))
        XCTAssertFalse(NSMouseInRect(p2, r1, true))
        XCTAssertTrue(NSMouseInRect(p2, r1, false))

        let p3 = NSMakePoint(NSMinX(r1), NSMinY(r1))
        XCTAssertFalse(NSMouseInRect(p3, r1, false))
        XCTAssertTrue(NSMouseInRect(p3, r1, true))
    }

    func test_NSContainsRect() {
        let r1 = NSMakeRect(CGFloat(1.2), CGFloat(3.1), CGFloat(10.0), CGFloat(10.0))
        let r2 = NSMakeRect(CGFloat(-2.3), CGFloat(-1.5), CGFloat(1.0), CGFloat(1.0))
        let r3 = NSMakeRect(CGFloat(10.2), CGFloat(5.5), CGFloat(0.5), CGFloat(5.0))

        XCTAssertFalse(NSContainsRect(r1, NSZeroRect))
        XCTAssertFalse(NSContainsRect(r1, r2))
        XCTAssertFalse(NSContainsRect(r2, r1))
        XCTAssertTrue(NSContainsRect(r1, r3))
    }

    func test_NSIntersectsRect() {
        let r1 = NSMakeRect(CGFloat(1.2), CGFloat(3.1), CGFloat(10.0), CGFloat(10.0))
        let r2 = NSMakeRect(CGFloat(-2.3), CGFloat(-1.5), CGFloat(1.0), CGFloat(1.0))
        let r3 = NSMakeRect(CGFloat(10.2), CGFloat(2.5), CGFloat(5.0), CGFloat(5.0))

        XCTAssertFalse(NSIntersectsRect(NSZeroRect, NSZeroRect))
        XCTAssertFalse(NSIntersectsRect(r1, NSZeroRect))
        XCTAssertFalse(NSIntersectsRect(NSZeroRect, r2))
        XCTAssertFalse(NSIntersectsRect(r1, r2))
        XCTAssertTrue(NSIntersectsRect(r1, r3))
    }

    func test_NSIntegralRect() {
        let referenceNegativeRect = NSMakeRect(CGFloat(-0.6), CGFloat(-5.4), CGFloat(-105.7), CGFloat(-24.3))
        XCTAssertEqual(NSIntegralRect(referenceNegativeRect), NSZeroRect)

        
        let referenceRect = NSMakeRect(CGFloat(0.6), CGFloat(5.4), CGFloat(105.7), CGFloat(24.3))
        let referenceNegativeOriginRect = NSMakeRect(CGFloat(-0.6), CGFloat(-5.4), CGFloat(105.7), CGFloat(24.3))
        
        var expectedResult = NSMakeRect(CGFloat(0.0), CGFloat(5.0), CGFloat(107.0), CGFloat(25.0))
        var result = NSIntegralRect(referenceRect)
        XCTAssertEqual(result, expectedResult)

        expectedResult = NSMakeRect(CGFloat(-1.0), CGFloat(-6.0), CGFloat(107.0), CGFloat(25.0))
        result = NSIntegralRect(referenceNegativeOriginRect)
        XCTAssertEqual(result, expectedResult)
    
    }
    
    func test_NSIntegralRectWithOptions() {
        let referenceRect = NSMakeRect(CGFloat(0.6), CGFloat(5.4), CGFloat(105.7), CGFloat(24.3))
        let referenceNegativeRect = NSMakeRect(CGFloat(-0.6), CGFloat(-5.4), CGFloat(-105.7), CGFloat(-24.3))
        let referenceNegativeOriginRect = NSMakeRect(CGFloat(-0.6), CGFloat(-5.4), CGFloat(105.7), CGFloat(24.3))

        var options: NSAlignmentOptions = [.AlignMinXInward, .AlignMinYInward, .AlignHeightInward, .AlignWidthInward]
        var expectedResult = NSMakeRect(CGFloat(1.0), CGFloat(6.0), CGFloat(105.0), CGFloat(24.0))
        var result = NSIntegralRectWithOptions(referenceRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMinXOutward, .AlignMinYOutward, .AlignHeightOutward, .AlignWidthOutward]
        expectedResult = NSMakeRect(CGFloat(0.0), CGFloat(5.0), CGFloat(106.0), CGFloat(25.0))
        result = NSIntegralRectWithOptions(referenceRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMinXInward, .AlignMinYInward, .AlignHeightInward, .AlignWidthInward]
        expectedResult = NSMakeRect(CGFloat(0.0), CGFloat(-5.0), CGFloat(0.0), CGFloat(0.0))
        result = NSIntegralRectWithOptions(referenceNegativeRect, options)
        XCTAssertEqual(result, expectedResult)
        
        options = [.AlignMinXInward, .AlignMinYInward, .AlignHeightInward, .AlignWidthInward]
        expectedResult = NSMakeRect(CGFloat(0.0), CGFloat(-5.0), CGFloat(105.0), CGFloat(24.0))
        result = NSIntegralRectWithOptions(referenceNegativeOriginRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMinXOutward, .AlignMinYOutward, .AlignHeightOutward, .AlignWidthOutward]
        expectedResult = NSMakeRect(CGFloat(-1.0), CGFloat(-6.0), CGFloat(106.0), CGFloat(25.0))
        result = NSIntegralRectWithOptions(referenceNegativeOriginRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMaxXOutward, .AlignMaxYOutward, .AlignHeightOutward, .AlignWidthOutward]
        expectedResult = NSMakeRect(CGFloat(0.0), CGFloat(-6.0), CGFloat(106.0), CGFloat(25.0))
        result = NSIntegralRectWithOptions(referenceNegativeOriginRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMinXOutward, .AlignMaxXOutward, .AlignMinYOutward, .AlignMaxYOutward]
        expectedResult = NSMakeRect(CGFloat(-1.0), CGFloat(-6.0), CGFloat(107.0), CGFloat(25.0))
        result = NSIntegralRectWithOptions(referenceNegativeOriginRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMaxXOutward, .AlignMaxYOutward, .AlignHeightOutward, .AlignWidthOutward]
        expectedResult = NSMakeRect(CGFloat(1.0), CGFloat(5.0), CGFloat(106.0), CGFloat(25.0))
        result = NSIntegralRectWithOptions(referenceRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMaxXInward, .AlignMaxYInward, .AlignHeightOutward, .AlignWidthOutward]
        expectedResult = NSMakeRect(CGFloat(-1.0), CGFloat(-7.0), CGFloat(106.0), CGFloat(25.0))
        result = NSIntegralRectWithOptions(referenceNegativeOriginRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMaxXInward, .AlignMaxYInward, .AlignHeightOutward, .AlignWidthOutward]
        expectedResult = NSMakeRect(CGFloat(0.0), CGFloat(4.0), CGFloat(106.0), CGFloat(25.0))
        result = NSIntegralRectWithOptions(referenceRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMinXNearest, .AlignMinYNearest, .AlignHeightNearest, .AlignWidthNearest]
        expectedResult = NSMakeRect(CGFloat(1.0), CGFloat(5.0), CGFloat(106.0), CGFloat(24.0))
        result = NSIntegralRectWithOptions(referenceRect, options)
        XCTAssertEqual(result, expectedResult)
        
        options = [.AlignMinXNearest, .AlignMinYNearest, .AlignHeightNearest, .AlignWidthNearest]
        expectedResult = NSMakeRect(CGFloat(-1.0), CGFloat(-5.0), CGFloat(106.0), CGFloat(24.0))
        result = NSIntegralRectWithOptions(referenceNegativeOriginRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMaxXNearest, .AlignMaxYNearest, .AlignHeightNearest, .AlignWidthNearest]
        expectedResult = NSMakeRect(CGFloat(0.0), CGFloat(6.0), CGFloat(106.0), CGFloat(24.0))
        result = NSIntegralRectWithOptions(referenceRect, options)
        XCTAssertEqual(result, expectedResult)
        
        options = [.AlignMaxXNearest, .AlignMaxYNearest, .AlignHeightNearest, .AlignWidthNearest]
        expectedResult = NSMakeRect(CGFloat(-1.0), CGFloat(-5.0), CGFloat(106.0), CGFloat(24.0))
        result = NSIntegralRectWithOptions(referenceNegativeOriginRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMinXInward, .AlignMaxXInward, .AlignMinYInward, .AlignMaxYInward]
        expectedResult = NSMakeRect(CGFloat(1.0), CGFloat(6.0), CGFloat(105.0), CGFloat(23.0))
        result = NSIntegralRectWithOptions(referenceRect, options)
        XCTAssertEqual(result, expectedResult)
        
        options = [.AlignMinXInward, .AlignMaxXInward, .AlignMinYInward, .AlignMaxYInward]
        expectedResult = NSMakeRect(CGFloat(0.0), CGFloat(-5.0), CGFloat(105.0), CGFloat(23.0))
        result = NSIntegralRectWithOptions(referenceNegativeOriginRect, options)
        XCTAssertEqual(result, expectedResult)

        options = [.AlignMinXNearest, .AlignMaxXInward, .AlignMinYInward, .AlignMaxYNearest]
        expectedResult = NSMakeRect(CGFloat(-1.0), CGFloat(-5.0), CGFloat(106.0), CGFloat(24.0))
        result = NSIntegralRectWithOptions(referenceNegativeOriginRect, options)
        XCTAssertEqual(result, expectedResult)

    }
}
