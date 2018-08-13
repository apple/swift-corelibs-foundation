// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestAffineTransform : XCTestCase {
    private let accuracyThreshold = 0.001

    static var allTests: [(String, (TestAffineTransform) -> () throws -> Void)] {
        return [
            ("test_BasicConstruction", test_BasicConstruction),
            ("test_IdentityTransformation", test_IdentityTransformation),
            ("test_Scale", test_Scale),
            ("test_Scaling", test_Scaling),
            ("test_TranslationScaling", test_TranslationScaling),
            ("test_ScalingTranslation", test_ScalingTranslation),
            ("test_Rotation_Degrees", test_Rotation_Degrees),
            ("test_Rotation_Radians", test_Rotation_Radians),
            ("test_Inversion", test_Inversion),
            ("test_IdentityTransformation", test_IdentityTransformation),
            ("test_Translation", test_Translation),
            ("test_TranslationComposed", test_TranslationComposed),
            ("test_AppendTransform", test_AppendTransform),
            ("test_PrependTransform", test_PrependTransform),
            ("test_TransformComposition", test_TransformComposition),
            ("test_hashing_identity", test_hashing_identity),
            ("test_hashing_values", test_hashing_values),
            ("test_rotation_compose", test_rotation_compose),
            ("test_translation_and_rotation", test_translation_and_rotation),
            ("test_Equal", test_Equal),
            ("test_NSCoding", test_NSCoding),
        ]
    }
    
    func checkPointTransformation(_ transform: NSAffineTransform, point: NSPoint, expectedPoint: NSPoint, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        let newPoint = transform.transform(point)
        XCTAssertEqual(Double(newPoint.x), Double(expectedPoint.x), accuracy: accuracyThreshold,
                       "x (expected: \(expectedPoint.x), was: \(newPoint.x)): \(message)", file: file, line: line)
        XCTAssertEqual(Double(newPoint.y), Double(expectedPoint.y), accuracy: accuracyThreshold,
                       "y (expected: \(expectedPoint.y), was: \(newPoint.y)): \(message)", file: file, line: line)
    }
    
    func checkSizeTransformation(_ transform: NSAffineTransform, size: NSSize, expectedSize: NSSize, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        let newSize = transform.transform(size)
        XCTAssertEqual(Double(newSize.width), Double(expectedSize.width), accuracy: accuracyThreshold,
                       "width (expected: \(expectedSize.width), was: \(newSize.width)): \(message)", file: file, line: line)
        XCTAssertEqual(Double(newSize.height), Double(expectedSize.height), accuracy: accuracyThreshold,
                       "height (expected: \(expectedSize.height), was: \(newSize.height)): \(message)", file: file, line: line)
    }
    
    func checkRectTransformation(_ transform: NSAffineTransform, rect: NSRect, expectedRect: NSRect, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        let newRect = transform.transformRect(rect)
        
        checkPointTransformation(transform, point: newRect.origin, expectedPoint: expectedRect.origin,
                                 "origin (expected: \(expectedRect.origin), was: \(newRect.origin)): \(message)", file: file, line: line)
        checkSizeTransformation(transform, size: newRect.size, expectedSize: expectedRect.size,
                                "size (expected: \(expectedRect.size), was: \(newRect.size)): \(message)", file: file, line: line)
    }

    func test_BasicConstruction() {
        let identityTransform = NSAffineTransform()
        let transformStruct = identityTransform.transformStruct

        // The diagonal entries (1,1) and (2,2) of the identity matrix are ones. The other entries are zeros.
        // TODO: These should use DBL_MAX but it's not available as part of Glibc on Linux
        XCTAssertEqual(Double(transformStruct.m11), Double(1), accuracy: accuracyThreshold)
        XCTAssertEqual(Double(transformStruct.m22), Double(1), accuracy: accuracyThreshold)

        XCTAssertEqual(Double(transformStruct.m12), Double(0), accuracy: accuracyThreshold)
        XCTAssertEqual(Double(transformStruct.m21), Double(0), accuracy: accuracyThreshold)
        XCTAssertEqual(Double(transformStruct.tX), Double(0), accuracy: accuracyThreshold)
        XCTAssertEqual(Double(transformStruct.tY), Double(0), accuracy: accuracyThreshold)
    }

    func test_IdentityTransformation() {
        let identityTransform = NSAffineTransform()

        func checkIdentityPointTransformation(_ point: NSPoint) {
            checkPointTransformation(identityTransform, point: point, expectedPoint: point)
        }
        
        checkIdentityPointTransformation(NSPoint())
        checkIdentityPointTransformation(NSMakePoint(CGFloat(24.5), CGFloat(10.0)))
        checkIdentityPointTransformation(NSMakePoint(CGFloat(-7.5), CGFloat(2.0)))

        func checkIdentitySizeTransformation(_ size: NSSize) {
            checkSizeTransformation(identityTransform, size: size, expectedSize: size)
        }

        checkIdentitySizeTransformation(NSSize())
        checkIdentitySizeTransformation(NSMakeSize(CGFloat(13.0), CGFloat(12.5)))
        checkIdentitySizeTransformation(NSMakeSize(CGFloat(100.0), CGFloat(-100.0)))
    }
    
    func test_Translation() {
        let point = NSPoint(x: CGFloat(0.0), y: CGFloat(0.0))

        let noop = NSAffineTransform()
        noop.translateX(by: CGFloat(), yBy: CGFloat())
        checkPointTransformation(noop, point: point, expectedPoint: point)
        
        let translateH = NSAffineTransform()
        translateH.translateX(by: CGFloat(10.0), yBy: CGFloat())
        checkPointTransformation(translateH, point: point, expectedPoint: NSPoint(x: CGFloat(10.0), y: CGFloat()))
        
        let translateV = NSAffineTransform()
        translateV.translateX(by: CGFloat(), yBy: CGFloat(20.0))
        checkPointTransformation(translateV, point: point, expectedPoint: NSPoint(x: CGFloat(), y: CGFloat(20.0)))
        
        let translate = NSAffineTransform()
        translate.translateX(by: CGFloat(-30.0), yBy: CGFloat(40.0))
        checkPointTransformation(translate, point: point, expectedPoint: NSPoint(x: CGFloat(-30.0), y: CGFloat(40.0)))
    }
    
    func test_Scale() {
        let size = NSSize(width: CGFloat(10.0), height: CGFloat(10.0))
        
        let noop = NSAffineTransform()
        noop.scale(by: CGFloat(1.0))
        checkSizeTransformation(noop, size: size, expectedSize: size)
        
        let shrink = NSAffineTransform()
        shrink.scale(by: CGFloat(0.5))
        checkSizeTransformation(shrink, size: size, expectedSize: NSSize(width: CGFloat(5.0), height: CGFloat(5.0)))
        
        let grow = NSAffineTransform()
        grow.scale(by: CGFloat(3.0))
        checkSizeTransformation(grow, size: size, expectedSize: NSSize(width: CGFloat(30.0), height: CGFloat(30.0)))
        
        let stretch = NSAffineTransform()
        stretch.scaleX(by: CGFloat(2.0), yBy: CGFloat(0.5))
        checkSizeTransformation(stretch, size: size, expectedSize: NSSize(width: CGFloat(20.0), height: CGFloat(5.0)))
    }
    
    func test_Rotation_Degrees() {
        let point = NSPoint(x: CGFloat(10.0), y: CGFloat(10.0))
        
        let noop = NSAffineTransform()
        noop.rotate(byDegrees: CGFloat())
        checkPointTransformation(noop, point: point, expectedPoint: point)
        
        let tenEighty = NSAffineTransform()
        tenEighty.rotate(byDegrees: CGFloat(1080.0))
        checkPointTransformation(tenEighty, point: point, expectedPoint: point)
        
        let rotateCounterClockwise = NSAffineTransform()
        rotateCounterClockwise.rotate(byDegrees: CGFloat(90.0))
        checkPointTransformation(rotateCounterClockwise, point: point, expectedPoint: NSPoint(x: CGFloat(-10.0), y: CGFloat(10.0)))
        
        let rotateClockwise = NSAffineTransform()
        rotateClockwise.rotate(byDegrees: CGFloat(-90.0))
        checkPointTransformation(rotateClockwise, point: point, expectedPoint: NSPoint(x: CGFloat(10.0), y: CGFloat(-10.0)))
        
        let reflectAboutOrigin = NSAffineTransform()
        reflectAboutOrigin.rotate(byDegrees: CGFloat(180.0))
        checkPointTransformation(reflectAboutOrigin, point: point, expectedPoint: NSPoint(x: CGFloat(-10.0), y: CGFloat(-10.0)))
    }
    
    func test_Rotation_Radians() {
        let point = NSPoint(x: CGFloat(10.0), y: CGFloat(10.0))
        
        let noop = NSAffineTransform()
        noop.rotate(byRadians: CGFloat())
        checkPointTransformation(noop, point: point, expectedPoint: point)
        
        let tenEighty = NSAffineTransform()
        tenEighty.rotate(byRadians: 6 * .pi)
        checkPointTransformation(tenEighty, point: point, expectedPoint: point)
        
        let rotateCounterClockwise = NSAffineTransform()
        rotateCounterClockwise.rotate(byRadians: .pi / 2)
        checkPointTransformation(rotateCounterClockwise, point: point, expectedPoint: NSPoint(x: CGFloat(-10.0), y: CGFloat(10.0)))
        
        let rotateClockwise = NSAffineTransform()
        rotateClockwise.rotate(byRadians: -.pi / 2)
        checkPointTransformation(rotateClockwise, point: point, expectedPoint: NSPoint(x: CGFloat(10.0), y: CGFloat(-10.0)))
        
        let reflectAboutOrigin = NSAffineTransform()
        reflectAboutOrigin.rotate(byRadians: .pi)
        checkPointTransformation(reflectAboutOrigin, point: point, expectedPoint: NSPoint(x: CGFloat(-10.0), y: CGFloat(-10.0)))
    }
    
    func test_Inversion() {
        let point = NSPoint(x: CGFloat(10.0), y: CGFloat(10.0))
        
        var translate = AffineTransform()
        translate.translate(x: CGFloat(-30.0), y: CGFloat(40.0))
        
        var rotate = AffineTransform()
        translate.rotate(byDegrees: CGFloat(30.0))
        
        var scale = AffineTransform()
        scale.scale(CGFloat(2.0))
        
        let identityTransform = NSAffineTransform()
        
        // append transformations
        identityTransform.append(translate)
        identityTransform.append(rotate)
        identityTransform.append(scale)
        
        // invert transformations
        scale.invert()
        rotate.invert()
        translate.invert()
        
        // append inverse transformations in reverse order
        identityTransform.append(scale)
        identityTransform.append(rotate)
        identityTransform.append(translate)
        
        checkPointTransformation(identityTransform, point: point, expectedPoint: point)
    }

    func test_TranslationComposed() {
        let xyPlus5 = NSAffineTransform()
        xyPlus5.translateX(by: CGFloat(2.0), yBy: CGFloat(3.0))
        xyPlus5.translateX(by: CGFloat(3.0), yBy: CGFloat(2.0))

        checkPointTransformation(xyPlus5, point: NSMakePoint(CGFloat(-2.0), CGFloat(-3.0)),
                                  expectedPoint: NSMakePoint(CGFloat(3.0), CGFloat(2.0)))
    }

    func test_Scaling() {
        let xyTimes5 = NSAffineTransform()
        xyTimes5.scale(by: CGFloat(5.0))

        checkPointTransformation(xyTimes5, point: NSMakePoint(CGFloat(-2.0), CGFloat(3.0)),
                                   expectedPoint: NSMakePoint(CGFloat(-10.0), CGFloat(15.0)))

        let xTimes2YTimes3 = NSAffineTransform()
        xTimes2YTimes3.scaleX(by: CGFloat(2.0), yBy: CGFloat(-3.0))

        checkPointTransformation(xTimes2YTimes3, point: NSMakePoint(CGFloat(-1.0), CGFloat(3.5)),
                                         expectedPoint: NSMakePoint(CGFloat(-2.0), CGFloat(-10.5)))
    }

    func test_TranslationScaling() {
        let xPlus2XYTimes5 = NSAffineTransform()
        xPlus2XYTimes5.translateX(by: CGFloat(2.0), yBy: CGFloat())
        xPlus2XYTimes5.scaleX(by: CGFloat(5.0), yBy: CGFloat(-5.0))

        checkPointTransformation(xPlus2XYTimes5, point: NSMakePoint(CGFloat(1.0), CGFloat(2.0)),
                                         expectedPoint: NSMakePoint(CGFloat(7.0), CGFloat(-10.0)))
    }

    func test_ScalingTranslation() {
        let xyTimes5XPlus3 = NSAffineTransform()
        xyTimes5XPlus3.scale(by: CGFloat(5.0))
        xyTimes5XPlus3.translateX(by: CGFloat(3.0), yBy: CGFloat())

        checkPointTransformation(xyTimes5XPlus3, point: NSMakePoint(CGFloat(1.0), CGFloat(2.0)),
                                         expectedPoint: NSMakePoint(CGFloat(20.0), CGFloat(10.0)))
    }
    
    func test_AppendTransform() {
        let point = NSPoint(x: CGFloat(10.0), y: CGFloat(10.0))
        
        var identityTransform = AffineTransform()
        identityTransform.append(identityTransform)
        checkPointTransformation(NSAffineTransform(transform: identityTransform), point: point, expectedPoint: point)
        
        var translate = AffineTransform()
        translate.translate(x: CGFloat(10.0), y: CGFloat())
        
        var scale = AffineTransform()
        scale.scale(CGFloat(2.0))
        
        let translateThenScale = NSAffineTransform(transform: translate)
        translateThenScale.append(scale)
        checkPointTransformation(translateThenScale, point: point, expectedPoint: NSPoint(x: CGFloat(40.0), y: CGFloat(20.0)))
    }
    
    func test_PrependTransform() {
        let point = NSPoint(x: CGFloat(10.0), y: CGFloat(10.0))
        
        var identityTransform = AffineTransform()
        identityTransform.prepend(identityTransform)
        checkPointTransformation(NSAffineTransform(transform: identityTransform), point: point, expectedPoint: point)
        
        var translate = AffineTransform()
        translate.translate(x: CGFloat(10.0), y: CGFloat())
        
        var scale = AffineTransform()
        scale.scale(CGFloat(2.0))
        
        let scaleThenTranslate = NSAffineTransform(transform: translate)
        scaleThenTranslate.prepend(scale)
        checkPointTransformation(scaleThenTranslate, point: point, expectedPoint: NSPoint(x: CGFloat(30.0), y: CGFloat(20.0)))
    }
    
    
    func test_TransformComposition() {
        let origin = NSPoint(x: CGFloat(10.0), y: CGFloat(10.0))
        let size = NSSize(width: CGFloat(40.0), height: CGFloat(20.0))
        let rect = NSRect(origin: origin, size: size)
        let center = NSPoint(x: NSMidX(rect), y: NSMidY(rect))
        
        let rotate = NSAffineTransform()
        rotate.rotate(byDegrees: CGFloat(90.0))
        
        var moveOrigin = AffineTransform()
        moveOrigin.translate(x: -center.x, y: -center.y)
        
        var moveBack = moveOrigin
        moveBack.invert()
        
        let rotateAboutCenter = rotate
        rotateAboutCenter.prepend(moveOrigin)
        rotateAboutCenter.append(moveBack)
        
        // center of rect shouldn't move as its the rotation anchor
        checkPointTransformation(rotateAboutCenter, point: center, expectedPoint: center)
    }

    func test_hashing_identity() {
        let ref = NSAffineTransform()
        let val = AffineTransform.identity
        XCTAssertEqual(ref.hashValue, val.hashValue)
        XCTAssertEqual(ref as AnyHashable, val as AnyHashable)
        XCTAssertEqual((ref as AnyHashable).hashValue, (val as AnyHashable).hashValue)
    }

    func test_hashing_values() {
        // the transforms are made up and the values don't matter
        let values = [
            AffineTransform(m11: CGFloat(1.0), m12: CGFloat(2.5), m21: CGFloat(66.2), m22: CGFloat(40.2), tX: CGFloat(-5.5), tY: CGFloat(3.7)),
            AffineTransform(m11: CGFloat(-55.66), m12: CGFloat(22.7), m21: CGFloat(1.5), m22: CGFloat(0.0), tX: CGFloat(-22.0), tY: CGFloat(-33.0)),
            AffineTransform(m11: CGFloat(4.5), m12: CGFloat(1.1), m21: CGFloat(0.025), m22: CGFloat(0.077), tX: CGFloat(-0.55), tY: CGFloat(33.2)),
            AffineTransform(m11: CGFloat(7.0), m12: CGFloat(-2.3), m21: CGFloat(6.7), m22: CGFloat(0.25), tX: CGFloat(0.556), tY: CGFloat(0.99)),
            AffineTransform(m11: CGFloat(0.498), m12: CGFloat(-0.284), m21: CGFloat(-0.742), m22: CGFloat(0.3248), tX: CGFloat(12.0), tY: CGFloat(44.0))
        ]
        for val in values {
            let ref = NSAffineTransform()
            ref.transformStruct = NSAffineTransformStruct(m11: val.m11, m12: val.m12, m21: val.m21, m22: val.m22, tX: val.tX, tY: val.tY)
            XCTAssertEqual(ref.hashValue, val.hashValue)
            XCTAssertEqual(ref as AnyHashable, val as AnyHashable)
            XCTAssertEqual((ref as AnyHashable).hashValue, (val as AnyHashable).hashValue)
        }
    }

    func test_rotation_compose() {
        var t = AffineTransform.identity
        t.translate(x: 1.0, y: 1.0)
        t.rotate(byDegrees: 90)
        t.translate(x: -1.0, y: -1.0)
        let result = t.transform(NSPoint(x: 1.0, y: 2.0))
        XCTAssertEqual(0.0, Double(result.x), accuracy: accuracyThreshold)
        XCTAssertEqual(1.0, Double(result.y), accuracy: accuracyThreshold)
    }

    func test_translation_and_rotation() {
        let point = NSPoint(x: CGFloat(10), y: CGFloat(10))
        var translateThenRotate = AffineTransform(translationByX: 20, byY: -30)
        translateThenRotate.rotate(byRadians: .pi / 2)
        checkPointTransformation(NSAffineTransform(transform: translateThenRotate), point: point, expectedPoint: NSPoint(x: CGFloat(10), y: CGFloat(-20)))
    }

    func test_Equal() {
        let transform = NSAffineTransform()
        let transform1 = NSAffineTransform()
        
        XCTAssertEqual(transform1, transform)
        XCTAssertFalse(transform === transform1)
    }
    
    func test_NSCoding() {
        let transformA = NSAffineTransform()
        transformA.scale(by: 2)
        let transformB = NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: transformA)) as! NSAffineTransform
        XCTAssertEqual(transformA, transformB, "Archived then unarchived `NSAffineTransform` must be equal.")
    }
}

extension NSAffineTransform {
    func transformRect(_ aRect: NSRect) -> NSRect {
        return NSRect(origin: transform(aRect.origin), size: transform(aRect.size))
    }
}
