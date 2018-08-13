// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if os(macOS) || os(iOS)
    import Darwin
#elseif os(Linux) || CYGWIN
    import Glibc
#endif

private let ε: CGFloat = CGFloat(2.22045e-16)


/**
 AffineTransform represents an affine transformation matrix of the following form:

 [ m11  m12  0 ]
 [ m21  m22  0 ]
 [  tX   tY  1 ]
 */
public struct AffineTransform : ReferenceConvertible, Hashable, CustomStringConvertible {
    public typealias ReferenceType = NSAffineTransform

    public var m11: CGFloat
    public var m12: CGFloat
    public var m21: CGFloat
    public var m22: CGFloat
    public var tX: CGFloat
    public var tY: CGFloat

    /// Creates an affine transformation matrix with identity values.
    public init() {
        self.init(m11: 1.0, m12: 0.0,
                  m21: 0.0, m22: 1.0,
                   tX: 0.0,  tY: 0.0)
    }

    /// Creates an affine transformation.
    public init(m11: CGFloat, m12: CGFloat, m21: CGFloat, m22: CGFloat, tX: CGFloat, tY: CGFloat) {
        (self.m11, self.m12, self.m21, self.m22) = (m11, m12, m21, m22)
        (self.tX, self.tY) = (tX, tY)
    }

    /**
     Creates an affine transformation matrix from translation values.
     The matrix takes the following form:

     [ 1  0  0 ]
     [ 0  1  0 ]
     [ x  y  1 ]
     */
    public init(translationByX x: CGFloat, byY y: CGFloat) {
        self.init(m11: CGFloat(1.0), m12: CGFloat(0.0),
                  m21: CGFloat(0.0), m22: CGFloat(1.0),
                  tX: x,             tY: y)
    }

    /**
     Creates an affine transformation matrix from scaling values.
     The matrix takes the following form:

     [ x  0  0 ]
     [ 0  y  0 ]
     [ 0  0  1 ]
     */
    public init(scaleByX x: CGFloat, byY y: CGFloat) {
        self.init(m11: x,            m12: CGFloat(0.0),
                  m21: CGFloat(0.0), m22: y,
                  tX: CGFloat(0.0),  tY: CGFloat(0.0))
    }

    /**
     Creates an affine transformation matrix from scaling a single value.
     The matrix takes the following form:

     [ f  0  0 ]
     [ 0  f  0 ]
     [ 0  0  1 ]
     */
    public init(scale factor: CGFloat) {
        self.init(scaleByX: factor, byY: factor)
    }

    /**
     Creates an affine transformation matrix from rotation value (angle in radians).
     The matrix takes the following form:

     [  cos α   sin α  0 ]
     [ -sin α   cos α  0 ]
     [    0       0    1 ]
     */
    public init(rotationByRadians angle: CGFloat) {
        let sine = sin(angle)
        let cosine = cos(angle)

        self.init(m11: cosine, m12: sine, m21: -sine, m22: cosine, tX: CGFloat(0.0), tY: CGFloat(0.0))
    }

    /**
     Creates an affine transformation matrix from a rotation value (angle in degrees).
     The matrix takes the following form:

     [  cos α   sin α  0 ]
     [ -sin α   cos α  0 ]
     [    0       0    1 ]
     */
    public init(rotationByDegrees angle: CGFloat) {
        let α = angle * .pi / 180.0
        self.init(rotationByRadians: α)
    }

    /**
     An identity affine transformation matrix

     [ 1  0  0 ]
     [ 0  1  0 ]
     [ 0  0  1 ]
     */
    public static let identity = AffineTransform(m11: CGFloat(1.0), m12: CGFloat(0.0), m21: CGFloat(0.0), m22: CGFloat(1.0), tX: CGFloat(0.0), tY: CGFloat(0.0))

    // Translating
    public mutating func translate(x: CGFloat, y: CGFloat) {
        tX += m11 * x + m21 * y
        tY += m12 * x + m22 * y
    }

    /**
     Mutates an affine transformation matrix from a rotation value (angle α in degrees).
     The matrix takes the following form:

     [  cos α   sin α  0 ]
     [ -sin α   cos α  0 ]
     [    0       0    1 ]
     */
    public mutating func rotate(byDegrees angle: CGFloat) {
        let α = angle * .pi / 180.0
        return rotate(byRadians: α)
    }

    /**
     Mutates an affine transformation matrix from a rotation value (angle α in radians).
     The matrix takes the following form:

     [  cos α   sin α  0 ]
     [ -sin α   cos α  0 ]
     [    0       0    1 ]
     */
    public mutating func rotate(byRadians angle: CGFloat) {
        let sine = sin(angle)
        let cosine = cos(angle)

        m11 = cosine
        m12 = sine
        m21 = -sine
        m22 = cosine
    }

    /**
     Creates an affine transformation matrix by combining the receiver with `transformStruct`.
     That is, it computes `T * M` and returns the result, where `T` is the receiver's and `M` is
     the `transformStruct`'s affine transformation matrix.
     The resulting matrix takes the following form:

     [ m11_T  m12_T  0 ] [ m11_M  m12_M  0 ]
     T * M = [ m21_T  m22_T  0 ] [ m21_M  m22_M  0 ]
     [  tX_T   tY_T  1 ] [  tX_M   tY_M  1 ]
     
     [    (m11_T*m11_M + m12_T*m21_M)       (m11_T*m12_M + m12_T*m22_M)    0 ]
     = [    (m21_T*m11_M + m22_T*m21_M)       (m21_T*m12_M + m22_T*m22_M)    0 ]
     [ (tX_T*m11_M + tY_T*m21_M + tX_M)  (tX_T*m12_M + tY_T*m22_M + tY_M)  1 ]
     */
    internal func concatenated(_ other: AffineTransform) -> AffineTransform {
        let (t, m) = (self, other)
        
        // this could be optimized with a vector version
        return AffineTransform(
            m11: (t.m11 * m.m11) + (t.m12 * m.m21), m12: (t.m11 * m.m12) + (t.m12 * m.m22),
            m21: (t.m21 * m.m11) + (t.m22 * m.m21), m22: (t.m21 * m.m12) + (t.m22 * m.m22),
            tX: (t.tX * m.m11) + (t.tY * m.m21) + m.tX,
            tY: (t.tX * m.m12) + (t.tY * m.m22) + m.tY
        )
    }

    /// Mutates an affine transformation matrix to perform the given scaling in both x and y dimensions.
    public mutating func scale(_ scale: CGFloat) {
        self.scale(x: scale, y: scale)
    }

    /// Mutates an affine transformation matrix to perform a scaling in each of the x and y dimensions.
    public mutating func scale(x: CGFloat, y: CGFloat) {
        m11 = CGFloat(m11.native * x.native)
        m12 = CGFloat(m12.native * x.native)
        m21 = CGFloat(m21.native * y.native)
        m22 = CGFloat(m22.native * y.native)
    }

    /**
     Inverts the transformation matrix if possible. Matrices with a determinant that is less than
     the smallest valid representation of a double value greater than zero are considered to be
     invalid for representing as an inverse. If the input AffineTransform can potentially fall into
     this case then the inverted() method is suggested to be used instead since that will return
     an optional value that will be nil in the case that the matrix cannot be inverted.

     D = (m11 * m22) - (m12 * m21)

     D < ε the inverse is undefined and will be nil
     */
    public mutating func invert() {
        guard let inverse = inverted() else {
            fatalError("Transform has no inverse")
        }
        self = inverse
    }

    /// Returns an inverted version of the matrix if possible, or nil if not.
    public func inverted() -> AffineTransform? {
        let determinant = (m11 * m22) - (m12 * m21)
        if fabs(determinant.native) <= ε.native {
            return nil
        }
        var inverse = AffineTransform()
        inverse.m11 = m22 / determinant
        inverse.m12 = -m12 / determinant
        inverse.m21 = -m21 / determinant
        inverse.m22 = m11 / determinant
        inverse.tX = (m21 * tY - m22 * tX) / determinant
        inverse.tY = (m12 * tX - m11 * tY) / determinant
        return inverse
    }

    /// Mutates an affine transformation by appending the specified matrix.
    public mutating func append(_ transform: AffineTransform) {
        self = concatenated(transform)
    }

    /// Mutates an affine transformation by prepending the specified matrix.
    public mutating func prepend(_ transform: AffineTransform) {
        self = transform.concatenated(self)
    }

    /// Applies the transform to the specified point and returns the result.
    public func transform(_ point: NSPoint) -> NSPoint {
        var newPoint = NSPoint()
        newPoint.x = (m11 * point.x) + (m21 * point.y) + tX
        newPoint.y = (m12 * point.x) + (m22 * point.y) + tY
        return newPoint
    }

    /// Applies the transform to the specified size and returns the result.
    public func transform(_ size: NSSize) -> NSSize {
        var newSize = NSSize()
        newSize.width = (m11 * size.width) + (m21 * size.height)
        newSize.height = (m12 * size.width) + (m22 * size.height)
        return newSize
    }

    /// The computed hash value for the transform.
    public var hashValue : Int {
        return Int((m11 + m12 + m21 + m22 + tX + tY).native)
    }

    /// A textual description of the transform.
    public var description: String {
        return "{m11:\(m11), m12:\(m12), m21:\(m21), m22:\(m22), tX:\(tX), tY:\(tY)}"
    }

    /// A textual description of the transform suitable for debugging.
    public var debugDescription: String {
        return description
    }

    public static func ==(lhs: AffineTransform, rhs: AffineTransform) -> Bool {
        return lhs.m11 == rhs.m11 && lhs.m12 == rhs.m12 &&
            lhs.m21 == rhs.m21 && lhs.m22 == rhs.m22 &&
            lhs.tX == rhs.tX && lhs.tY == rhs.tY
    }
}


/// A structure that defines the three-by-three matrix that performs an affine transform between two coordinate systems.
public struct NSAffineTransformStruct {
    public var m11: CGFloat
    public var m12: CGFloat
    public var m21: CGFloat
    public var m22: CGFloat
    public var tX: CGFloat
    public var tY: CGFloat

    /// Initializes a zero-filled transformation matrix.
    public init() {
        m11 = 0.0
        m12 = 0.0
        m21 = 0.0
        m22 = 0.0
        tX = 0.0
        tY = 0.0
    }

    /// Initializes a transformation matrix with the given values.
    public init(m11: CGFloat, m12: CGFloat, m21: CGFloat, m22: CGFloat, tX: CGFloat, tY: CGFloat) {
        self.m11 = m11
        self.m12 = m12
        self.m21 = m21
        self.m22 = m22
        self.tX = tX
        self.tY = tY
    }
}

open class NSAffineTransform : NSObject, NSCopying, NSSecureCoding {

    private var affineTransform: AffineTransform

    /// The matrix coefficients stored as the transformation matrix.
    public var transformStruct: NSAffineTransformStruct {
        get {
            return NSAffineTransformStruct(m11: affineTransform.m11,
                                           m12: affineTransform.m12,
                                           m21: affineTransform.m21,
                                           m22: affineTransform.m22,
                                           tX: affineTransform.tX,
                                           tY: affineTransform.tY)
        }
        set {
            affineTransform.m11 = newValue.m11
            affineTransform.m12 = newValue.m12
            affineTransform.m21 = newValue.m21
            affineTransform.m22 = newValue.m22
            affineTransform.tX = newValue.tX
            affineTransform.tY = newValue.tY
        }
    }

    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        
        let array = [
            Float(transformStruct.m11),
            Float(transformStruct.m12),
            Float(transformStruct.m21),
            Float(transformStruct.m22),
            Float(transformStruct.tX),
            Float(transformStruct.tY),
        ]
        
        array.withUnsafeBytes { pointer in
            aCoder.encodeValue(ofObjCType: "[6f]", at: UnsafeRawPointer(pointer.baseAddress!))
        }
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return NSAffineTransform(transform: affineTransform)
    }
    
    // Necessary because `NSObject.copy()` returns `self`.
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<Float>.stride * 6, alignment: 1)
        defer {
            pointer.deallocate()
        }
        aDecoder.decodeValue(ofObjCType: "[6f]", at: pointer)
        
        let floatPointer = pointer.bindMemory(to: Float.self, capacity: 6)
        let m11 = floatPointer[0]
        let m12 = floatPointer[1]
        let m21 = floatPointer[2]
        let m22 = floatPointer[3]
        let tX = floatPointer[4]
        let tY = floatPointer[5]

        affineTransform = AffineTransform(m11: CGFloat(m11), m12: CGFloat(m12),
                                          m21: CGFloat(m21), m22: CGFloat(m22),
                                          tX: CGFloat(tX), tY: CGFloat(tY))
    }
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? NSAffineTransform else { return false }
        return other === self || (other.affineTransform == self.affineTransform)
    }

    open override var hashValue: Int {
        return affineTransform.hashValue
    }
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    /// Initializes an affine transform matrix using another transform object.
    public convenience init(transform: AffineTransform) {
        self.init()
        affineTransform = transform
    }

    /// Initializes an affine transform matrix to the identity matrix.
    public override init() {
        affineTransform = AffineTransform(
            m11: CGFloat(1.0), m12: CGFloat(),
            m21: CGFloat(), m22: CGFloat(1.0),
            tX: CGFloat(), tY: CGFloat()
        )
    }

    /// Applies the specified translation factors to the transformation matrix.
    open func translateX(by deltaX: CGFloat, yBy deltaY: CGFloat) {
        let translation = AffineTransform(translationByX: deltaX, byY: deltaY)
        affineTransform = translation.concatenated(affineTransform)
    }
    
    /// Applies a rotation factor (measured in degrees) to the transformation matrix.
    open func rotate(byDegrees angle: CGFloat) {
        let rotation = AffineTransform(rotationByDegrees: angle)
        affineTransform = rotation.concatenated(affineTransform)
    }

    /// Applies a rotation factor (measured in radians) to the transformation matrix.
    open func rotate(byRadians angle: CGFloat) {
        let rotation = AffineTransform(rotationByRadians: angle)
        affineTransform = rotation.concatenated(affineTransform)
    }
    
    /// Applies the specified scaling factor along both x and y axes to the transformation matrix.
    open func scale(by scale: CGFloat) {
        scaleX(by: scale, yBy: scale)
    }

    /// Applies scaling factors to each axis of the transformation matrix.
    open func scaleX(by scaleX: CGFloat, yBy scaleY: CGFloat) {
        let scale = AffineTransform(scaleByX: scaleX, byY: scaleY)
        affineTransform = scale.concatenated(affineTransform)
    }
    
    /// Replaces the matrix with its inverse matrix.
    open func invert() {
        if let inverse = affineTransform.inverted() {
            affineTransform = inverse
        }
        else {
            preconditionFailure("NSAffineTransform: Transform has no inverse")
        }
    }
    
    /// Appends the specified matrix.
    open func append(_ transform: AffineTransform) {
        affineTransform = affineTransform.concatenated(transform)
    }

    /// Prepends the specified matrix.
    open func prepend(_ transform: AffineTransform) {
        affineTransform = transform.concatenated(affineTransform)
    }
    
    /// Applies the transform to the specified point and returns the result.
    open func transform(_ aPoint: NSPoint) -> NSPoint {
        return affineTransform.transform(aPoint)
    }

    /// Applies the transform to the specified size and returns the result.
    open func transform(_ aSize: NSSize) -> NSSize {
        return affineTransform.transform(aSize)
    }
}

extension AffineTransform : _ObjectiveCBridgeable {
    public static func _isBridgedToObjectiveC() -> Bool {
        return true
    }

    public static func _getObjectiveCType() -> Any.Type {
        return NSAffineTransform.self
    }

    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSAffineTransform {
        return NSAffineTransform(transform: self)
    }

    public static func _forceBridgeFromObjectiveC(_ x: NSAffineTransform, result: inout AffineTransform?) {
        if !_conditionallyBridgeFromObjectiveC(x, result: &result) {
            fatalError("Unable to bridge type")
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ x: NSAffineTransform, result: inout AffineTransform?) -> Bool {
        let ts = x.transformStruct
        result = AffineTransform(m11: ts.m11, m12: ts.m12, m21: ts.m21, m22: ts.m22, tX: ts.tX, tY: ts.tY)
        return true // Can't fail
    }

    public static func _unconditionallyBridgeFromObjectiveC(_ x: NSAffineTransform?) -> AffineTransform {
        var result: AffineTransform?
        _forceBridgeFromObjectiveC(x!, result: &result)
        return result!
    }
}

extension NSAffineTransform : _StructTypeBridgeable {
    public typealias _StructType = AffineTransform
    
    public func _bridgeToSwift() -> AffineTransform {
        return AffineTransform._unconditionallyBridgeFromObjectiveC(self)
    }
}

extension NSAffineTransform : _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as AffineTransform)
    }
}

extension AffineTransform : Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        m11 = try container.decode(CGFloat.self)
        m12 = try container.decode(CGFloat.self)
        m21 = try container.decode(CGFloat.self)
        m22 = try container.decode(CGFloat.self)
        tX  = try container.decode(CGFloat.self)
        tY  = try container.decode(CGFloat.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.m11)
        try container.encode(self.m12)
        try container.encode(self.m21)
        try container.encode(self.m22)
        try container.encode(self.tX)
        try container.encode(self.tY)
    }
}
