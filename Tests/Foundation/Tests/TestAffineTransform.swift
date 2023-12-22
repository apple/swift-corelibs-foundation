// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
    #if canImport(SwiftFoundation) && !DEPLOYMENT_RUNTIME_OBJC
        @testable import SwiftFoundation
    #else
        @testable import Foundation
    #endif
#endif

// MARK: - Vector

// CGVector is only available on Darwin.
public struct Vector {
    let dx: CGFloat
    let dy: CGFloat
}

// MARK: - Tests

class TestAffineTransform: XCTestCase {
    private let accuracyThreshold: CGFloat = 0.001

    static var allTests: [(String, (TestAffineTransform) -> () throws -> Void)] {
        return [
            ("testConstruction", testConstruction),
            ("testBridging", testBridging),
            ("testEqualityHashing", testEqualityHashing),
            ("testVectorTransformations", testVectorTransformations),
            ("testIdentityConstruction", testIdentityConstruction),
            ("testIdentity", testIdentity),
            ("testTranslationConstruction", testTranslationConstruction),
            ("testTranslation", testTranslation),
            ("testScalingConstruction", testScalingConstruction),
            ("testScaling", testScaling),
            ("testRotationConstruction", testRotationConstruction),
            ("testRotation", testRotation),
            ("testTranslationScaling", testTranslationScaling),
            ("testTranslationRotation", testTranslationRotation),
            ("testScalingRotation", testScalingRotation),
            ("testInversion", testInversion),
            ("testPrependTransform", testPrependTransform),
            ("testAppendTransform", testAppendTransform),
            ("testNSCoding", testNSCoding),
        ]
    }
}
 
// MARK: - Helper

extension TestAffineTransform {
    func check(
        vector: Vector,
        withTransform transform: AffineTransform,
        mapsToPoint expectedPoint: CGPoint,
        mapsToSize expectedSize: CGSize,
        _ message: String = "",
        file: StaticString = #file, line: UInt = #line
    ) {
        let point = CGPoint(x: vector.dx, y: vector.dy)
        let size = CGSize(width: vector.dx, height: vector.dy)
        
        let newPoint = transform.transform(point)
        let newSize = transform.transform(size)
        
        let nsTransform = transform as NSAffineTransform
        XCTAssertEqual(
            nsTransform.transform(point).x, newPoint.x,
            accuracy: accuracyThreshold,
            "Expected NSAffineTransform x to match AffineTransform's point-accepting transform(_:)",
            file: file, line: line
        )
        XCTAssertEqual(
            nsTransform.transform(point).y, newPoint.y,
            accuracy: accuracyThreshold,
            "Expected NSAffineTransform y to match AffineTransform's point-accepting transform(_:)",
            file: file, line: line
        )
        XCTAssertEqual(
            nsTransform.transform(size).width, newSize.width,
            accuracy: accuracyThreshold,
            "Expected NSAffineTransform width to match AffineTransform's size-accepting transform(_:)",
            file: file, line: line
        )
        XCTAssertEqual(
            nsTransform.transform(size).height, newSize.height,
            accuracy: accuracyThreshold,
            "Expected NSAffineTransform height to match AffineTransform's size-accepting transform(_:)",
            file: file, line: line
        )
        
        XCTAssertEqual(
            newPoint.x, expectedPoint.x,
            accuracy: accuracyThreshold,
            "Invalid x: \(message)",
            file: file, line: line
        )
        
        XCTAssertEqual(
            newPoint.y, expectedPoint.y,
            accuracy: accuracyThreshold,
            "Invalid y: \(message)",
            file: file, line: line
        )
        
        XCTAssertEqual(
            newSize.width, expectedSize.width,
            accuracy: accuracyThreshold,
            "Invalid width: \(message)",
            file: file, line: line
        )
        XCTAssertEqual(
            newSize.height, expectedSize.height,
            accuracy: accuracyThreshold,
            "Invalid height: \(message)",
            file: file, line: line
        )
    }
}

// MARK: - Construction

extension TestAffineTransform {
    func testConstruction() {
        let transform = AffineTransform(
            m11: 1, m12: 2,
            m21: 3, m22: 4,
             tX: 5,  tY: 6
        )
        
        XCTAssertEqual(transform.m11, 1)
        XCTAssertEqual(transform.m12, 2)
        XCTAssertEqual(transform.m21, 3)
        XCTAssertEqual(transform.m22, 4)
        XCTAssertEqual(transform.tX , 5)
        XCTAssertEqual(transform.tY , 6)
    }
}

// MARK: - Bridging

extension TestAffineTransform {
    func testBridging() {
        let transform = AffineTransform(
            m11: 1, m12: 2,
            m21: 3, m22: 4,
             tX: 5,  tY: 6
        )
        
        let nsTransform = NSAffineTransform(transform: transform)
        
        #if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
        XCTAssertEqual(transform, nsTransform.affineTransform)
        #endif
        
        XCTAssertEqual(nsTransform as AffineTransform, transform)
    }
}

// MARK: Equality

extension TestAffineTransform {
    func testEqualityHashing() {
        let samples = [
            AffineTransform(m11: 1.5, m12: 2.0, m21: 3.0, m22: 4.0, tX: 5.0, tY: 6.0),
            AffineTransform(m11: 1.0, m12: 2.5, m21: 3.0, m22: 4.0, tX: 5.0, tY: 6.0),
            AffineTransform(m11: 1.0, m12: 2.0, m21: 3.5, m22: 4.0, tX: 5.0, tY: 6.0),
            AffineTransform(m11: 1.0, m12: 2.0, m21: 3.0, m22: 4.5, tX: 5.0, tY: 6.0),
            AffineTransform(m11: 1.0, m12: 2.0, m21: 3.0, m22: 4.0, tX: 5.5, tY: 6.0),
            AffineTransform(m11: 1.0, m12: 2.0, m21: 3.0, m22: 4.0, tX: 5.0, tY: 6.5),
        ].map(NSAffineTransform.init)
        
        for (index, sample) in samples.enumerated() {
            let otherSamples: [NSAffineTransform] = {
                var samplesCopy = samples
                samplesCopy.remove(at: index)
                return samplesCopy
            }()
            
            XCTAssertEqual(sample, sample)
            XCTAssertEqual(sample.hashValue, sample.hashValue)
            
            for otherSample in otherSamples {
                XCTAssertNotEqual(sample, otherSample)
                XCTAssertNotEqual(sample.hashValue, otherSample.hashValue)
            }
        }
    }
}

// MARK: - Vector Transformations

extension TestAffineTransform {
    func testVectorTransformations() {
        
        // To transform a given size with coordinates w and h,
        // we do:
        //
        //   [ w' h' ] = [ w   h ]  *  [ m11  m12 ]
        //                             [ m21  m22 ]
        //
        //             = [ w*m11+h*m21  w*m12+h*m22 ]
        //
        // To find the transformed point with coordinates x, y
        // where x=w and y=h, we simply add the translation vector
        // [tX, tX] to our previous result:
        //
        // [ p' y' ] = [ w' h' ] + [ tX  tY ]
        //           = [ x*m11+y*m21+tX  x*m12+y*m22+tY ]
        
        check(
            vector: Vector(dx: 10, dy: 20),
            withTransform: AffineTransform(
                m11: 1, m12: 2,
                m21: 3, m22: 4,
                 tX: 5,  tY: 6
            ),
        
            // [ px*m11+py*m21+tX  px*m12+py*m22+tY ]
            // [   10*1+20*3+5       10*2+20*4+6    ]
            // [       75                106        ]
            mapsToPoint: CGPoint(x: 75, y: 106),
            
            // [ px*m11+py*m21  px*m12+py*m22 ]
            // [   10*1+20*3       10*2+20*4  ]
            // [      70              100     ]
            mapsToSize: CGSize(width: 70, height: 100)
        )
        
        check(
            vector: Vector(dx: 5, dy: 25),
            withTransform: AffineTransform(
                m11: 5, m12: 4,
                m21: 3, m22: 2,
                 tX: 1,  tY: 0
            ),
            
            // [ px*m11+py*m21+tX  px*m12+py*m22+tY ]
            // [   5*5+25*3+1         5*4+25*2+0    ]
            // [      101                 70        ]
            mapsToPoint: CGPoint(x: 101, y: 70),
            
            // [ px*m11+py*m21  px*m12+py*m22 ]
            // [   5*5+25*3       5*4+25*2    ]
            // [     100             70       ]
            mapsToSize: CGSize(width: 100, height: 70)
        )
    }
}

// MARK: - Identity

extension TestAffineTransform {
    func testIdentityConstruction() {
        // Check that the transform matrix is the identity:
        // [ 1 0 0 ]
        // [ 0 1 0 ]
        // [ 0 0 1 ]
        let identity = AffineTransform(
            m11: 1, m12: 0,
            m21: 0, m22: 1,
             tX: 0,  tY: 0
        )
        
        XCTAssertEqual(AffineTransform(), identity)
        XCTAssertEqual(AffineTransform.identity, identity)
        XCTAssertEqual(NSAffineTransform().affineTransform, identity)
    }
    
    func testIdentity() {
        check(
            vector: Vector(dx: 25, dy: 10),
            withTransform: .identity,
            mapsToPoint: CGPoint(x: 25, y: 10),
            mapsToSize: CGSize(width: 25, height: 10)
        )
    }
}

// MARK: - Translation

extension TestAffineTransform {
    func testTranslationConstruction() {
        let translatedIdentity: AffineTransform = {
            var transform = AffineTransform.identity
            transform.translate(x: 15, y: 20)
            return transform
        }()
        
        let translation = AffineTransform(
            translationByX: 15, byY: 20
        )
        
        let nsTranslation: NSAffineTransform = {
            let transform = NSAffineTransform()
            transform.translateX(by: 15, yBy: 20)
            return transform
        }()
        
        XCTAssertEqual(translatedIdentity, translation)
        XCTAssertEqual(nsTranslation.affineTransform, translation)
    }
    
    func testTranslation() {
        check(
            vector: Vector(dx: 10, dy: 10),
            withTransform: AffineTransform(
                translationByX: 0, byY: 0
            ),
            mapsToPoint: CGPoint(x: 10, y: 10),
            mapsToSize: CGSize(width: 10, height: 10)
        )
        
        check(
            vector: Vector(dx: 10, dy: 10),
            withTransform: AffineTransform(
                translationByX: 0, byY: 5
            ),
            mapsToPoint: CGPoint(x: 10, y: 15),
            mapsToSize: CGSize(width: 10, height: 10)
        )
        
        check(
            vector: Vector(dx: 10, dy: 10),
            withTransform: AffineTransform(
                translationByX: 5, byY: 5
            ),
            mapsToPoint: CGPoint(x: 15, y: 15),
            mapsToSize: CGSize(width: 10, height: 10)
        )
        
        check(
            vector: Vector(dx: -2, dy: -3),
            // Translate by 5
            withTransform: {
                var transform = AffineTransform.identity
                
                transform.translate(x: 2, y: 3)
                transform.translate(x: 3, y: 2)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: 3, y: 2),
            mapsToSize: CGSize(width: -2, height: -3)
        )
    }
}

// MARK: - Scaling

extension TestAffineTransform {
    func testScalingConstruction() {
        // Distinct x/y Components
        
        let scaledIdentity: AffineTransform = {
            var transform = AffineTransform.identity
            transform.scale(x: 15, y: 20)
            return transform
        }()
        
        let scaling = AffineTransform(
            scaleByX: 15, byY: 20
        )
        
        let nsScaling: NSAffineTransform = {
            let transform = NSAffineTransform()
            transform.scaleX(by: 15, yBy: 20)
            return transform
        }()
        
        XCTAssertEqual(scaledIdentity, scaling)
        XCTAssertEqual(nsScaling.affineTransform, scaling)
        
        // Same x/y Components
        
        let differentScaledIdentity = AffineTransform(
            scaleByX: 20, byY: 20
        )
        
        let sameScaledIdentity: AffineTransform = {
            var transform = AffineTransform.identity
            transform.scale(20)
            return transform
        }()
        
        let sameScaling = AffineTransform(
            scale: 20
        )
        
        let sameNSScaling: NSAffineTransform = {
            let transform = NSAffineTransform()
            transform.scale(by: 20)
            return transform
        }()
        
        XCTAssertEqual(sameScaling, differentScaledIdentity)
        
        XCTAssertEqual(sameScaledIdentity, sameScaling)
        XCTAssertEqual(sameNSScaling.affineTransform, sameScaling)
    }

    func testScaling() {
        check(
            vector: Vector(dx: 10, dy: 10),
            withTransform: AffineTransform(
                scaleByX: 1, byY: 0
            ),
            mapsToPoint: CGPoint(x: 10, y: 0),
            mapsToSize: CGSize(width: 10, height: 0)
        )
        
        check(
            vector: Vector(dx: 10, dy: 10),
            withTransform: AffineTransform(
                scaleByX: 0.5, byY: 1
            ),
            mapsToPoint: CGPoint(x: 5, y: 10),
            mapsToSize: CGSize(width: 5, height: 10)
        )
        
        check(
            vector: Vector(dx: 10, dy: 10),
            withTransform: AffineTransform(
                scaleByX: 0, byY: 2
            ),
            mapsToPoint: CGPoint(x: 0, y: 20),
            mapsToSize: CGSize(width: 0, height: 20)
        )
        
        check(
            vector: Vector(dx: 10, dy: 10),
            // Scale by (2, 0)
            withTransform: {
                var transform = AffineTransform.identity
                
                transform.scale(x: 4, y: 0)
                transform.scale(x: 0.5, y: 1)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: 20, y: 0),
            mapsToSize: CGSize(width: 20, height: 0)
        )
    }
}

// MARK: - Rotation

extension TestAffineTransform {
    func testRotationConstruction() {
        let baseRotation = AffineTransform(
            rotationByRadians: .pi
        )
        
        func assertPiRotation(
            _ rotation: AffineTransform,
            file: StaticString = #file,
            line: UInt = #line
        ) {
            let vector = Vector(dx: 10, dy: 15)
            
            self.check(
                vector: vector, withTransform: rotation,
                mapsToPoint: baseRotation.transform(
                    CGPoint(x: vector.dx, y: vector.dy)
                ),
                mapsToSize: baseRotation.transform(
                    CGSize(width: vector.dx, height: vector.dy)
                ),
                file: file, line: line
            )
        }
        
        // Radians
        
        assertPiRotation({
            var transform = AffineTransform.identity
            transform.rotate(byRadians: .pi)
            return transform
        }())
        
        assertPiRotation({
            let transform = NSAffineTransform()
            transform.rotate(byRadians: .pi)
            return transform
        }() as NSAffineTransform as AffineTransform)
        
        // Degrees
        
        assertPiRotation({
            var transform = AffineTransform.identity
            transform.rotate(byDegrees: 180)
            return transform
        }())
        
        assertPiRotation(AffineTransform(
            rotationByDegrees: 180
        ))
        
        assertPiRotation({
            let transform = NSAffineTransform()
            transform.rotate(byDegrees: 180)
            return transform
        }() as NSAffineTransform as AffineTransform)
    }
    
    func testRotation() {
        check(
            vector: Vector(dx: 10, dy: 15),
            withTransform: AffineTransform(rotationByDegrees: 0),
            mapsToPoint: CGPoint(x: 10, y: 15),
            mapsToSize: CGSize(width: 10, height: 15)
        )
        
        check(
            vector: Vector(dx: 10, dy: 15),
            withTransform: AffineTransform(rotationByDegrees: 1080),
            mapsToPoint: CGPoint(x: 10, y: 15),
            mapsToSize: CGSize(width: 10, height: 15)
        )
        
        // Counter-clockwise rotation
        check(
            vector: Vector(dx: 15, dy: 10),
            withTransform: AffineTransform(rotationByRadians: .pi / 2),
            mapsToPoint: CGPoint(x: -10, y: 15),
            mapsToSize: CGSize(width: -10, height: 15)
        )
        
        // Clockwise rotation
        check(
            vector: Vector(dx: 15, dy: 10),
            withTransform: AffineTransform(rotationByDegrees: -90),
            mapsToPoint: CGPoint(x: 10, y: -15),
            mapsToSize: CGSize(width: 10, height: -15)
        )
        
        // Reflect about origin
        check(
            vector: Vector(dx: 10, dy: 15),
            withTransform: AffineTransform(rotationByRadians: .pi),
            mapsToPoint: CGPoint(x: -10, y: -15),
            mapsToSize: CGSize(width: -10, height: -15)
        )
        
        // Composed reflection about origin
        check(
            vector: Vector(dx: 10, dy: 15),
            // Rotate by 180º
            withTransform: {
                var transform = AffineTransform.identity
                
                transform.rotate(byDegrees: 90)
                transform.rotate(byDegrees: 90)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: -10, y: -15),
            mapsToSize: CGSize(width: -10, height: -15)
        )
    }
}

// MARK: - Permutations

extension TestAffineTransform {
    func testTranslationScaling() {
        check(
            vector: Vector(dx: 1, dy: 3),
            // Translate by (2, 0) then scale by (5, -5)
            withTransform: {
                var transform = AffineTransform.identity
                
                transform.translate(x: 2, y: 0)
                transform.scale(x: 5, y: -5)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: 15, y: -15),
            // [  5   0 ]
            // [  0  -5 ]
            // [ 10   0 ]
            mapsToSize: CGSize(width: 5, height: -15)
        )
        
        check(
            vector: Vector(dx: 3, dy: 1),
            // Scale by (-5, 5) then scale by (0, 10)
            withTransform: {
                var transform = AffineTransform.identity
                
                transform.scale(x: -5, y: 5)
                transform.translate(x: 0, y: 10)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: -15, y: 15),
            mapsToSize: CGSize(width: -15, height: 5)
        )
    }
    
    func testTranslationRotation() {
        check(
            vector: Vector(dx: 10, dy: 10),
            // Translate by (20, -5) then rotate by 90º
            withTransform: {
                var transform = AffineTransform.identity
                
                transform.translate(x: 20, y: -5)
                transform.rotate(byDegrees: 90)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: -5, y: 30),
            mapsToSize: CGSize(width: -10, height: 10)
        )
        
        check(
            vector: Vector(dx: 10, dy: 10),
            // Rotate by 180º and then translate by (20, 15)
            withTransform: {
                var transform = AffineTransform.identity
                
                transform.rotate(byDegrees: 180)
                transform.translate(x: 20, y: 15)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: 10, y: 5),
            mapsToSize: CGSize(width: -10, height: -10)
        )
    }
    
    func testScalingRotation() {
        check(
            vector: Vector(dx: 20, dy: 5),
            // Scale by (0.5, 3) then rotate by -90º
            withTransform: {
                var transform = AffineTransform.identity
                
                transform.scale(x: 0.5, y: 3)
                transform.rotate(byDegrees: -90)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: 15, y: -10),
            mapsToSize: CGSize(width: 15, height: -10)
        )
        
        check(
            vector: Vector(dx: 20, dy: 5),
            // Rotate by -90º the scale by (0.5, 3)
            withTransform: {
                var transform = AffineTransform.identity
                
                transform.rotate(byDegrees: -90)
                transform.scale(x: 3, y: -0.5)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: 15, y: 10),
            mapsToSize: CGSize(width: 15, height: 10)
        )
    }
}

// MARK: - Inversion

extension TestAffineTransform {
    func testInversion() {
        let transforms = [
            AffineTransform(translationByX: -30, byY: 40),
            AffineTransform(rotationByDegrees: 30),
            AffineTransform(scaleByX: 20, byY: -10),
        ]
        
        let composeTransform: AffineTransform = {
            var transform = AffineTransform.identity
            
            for component in transforms {
                transform.append(component)
            }
            
            return transform
        }()
        
        let recoveredIdentity: AffineTransform = {
            var transform = composeTransform
            
            // Append inverse transformations in reverse order
            for component in transforms.reversed() {
                transform.append(component.inverted()!)
            }
            
            return transform
        }()
        
        check(
            vector: Vector(dx: 10, dy: 10),
            withTransform: recoveredIdentity,
            mapsToPoint: CGPoint(x: 10, y: 10),
            mapsToSize: CGSize(width: 10, height: 10)
        )
    }
}

// MARK: - Concatenation

extension TestAffineTransform {
    func testPrependTransform() {
        check(
            vector: Vector(dx: 10, dy: 15),
            withTransform: {
                var transform = AffineTransform.identity
                transform.prepend(.identity)
                return transform
            }(),
            mapsToPoint: CGPoint(x: 10, y: 15),
            mapsToSize: CGSize(width: 10, height: 15)
        )
        
        check(
            vector: Vector(dx: 10, dy: 15),
            // Scale by 2 then translate by (10, 0)
            withTransform: {
                let scale = AffineTransform(scale: 2)
                
                var transform = AffineTransform(
                    translationByX: 10, byY: 0
                )
                transform.prepend(scale)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: 30, y: 30),
            mapsToSize: CGSize(width: 20, height: 30)
        )
    }
    
    func testAppendTransform() {
        check(
            vector: Vector(dx: 10, dy: 15),
            withTransform: {
                var transform = AffineTransform.identity
                transform.append(.identity)
                return transform
            }(),
            mapsToPoint: CGPoint(x: 10, y: 15),
            mapsToSize: CGSize(width: 10, height: 15)
        )
        
        check(
            vector: Vector(dx: 10, dy: 15),
            // Translate by (10, 0) then scale by 2
            withTransform: {
                let scale = AffineTransform(scale: 2)
                
                var transform = AffineTransform(
                    translationByX: 10, byY: 0
                )
                transform.append(scale)
                
                return transform
            }(),
            mapsToPoint: CGPoint(x: 40, y: 30),
            mapsToSize: CGSize(width: 20, height: 30)
        )
    }
}

// MARK: - Coding

extension TestAffineTransform {
    func testNSCoding() throws {
        let transform = AffineTransform(
            m11: 1, m12: 2,
            m21: 3, m22: 4,
             tX: 5,  tY: 6
        )
        
        let encodedData = try JSONEncoder().encode(transform)
        
        let encodedString = String(
            data: encodedData, encoding: .utf8
        )
        
        let commaSeparatedNumbers = (1...6)
            .map(String.init)
            .joined(separator: ",")
        
        XCTAssertEqual(
            encodedString, "[\(commaSeparatedNumbers)]",
            "Invalid coding representation"
        )
        
        let recovered = try JSONDecoder().decode(
            AffineTransform.self, from: encodedData
        )
        
        XCTAssertEqual(
            transform, recovered,
            "Encoded and then decoded transform does not equal original"
        )
        
        let nsTransform = transform as NSAffineTransform
        let nsRecoveredTransform = NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: nsTransform)) as! NSAffineTransform
        
        XCTAssertEqual(
            nsTransform, nsRecoveredTransform,
            "Archived then unarchived `NSAffineTransform` must be equal."
        )
    }
}
