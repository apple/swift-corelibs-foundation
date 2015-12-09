// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

// TODO: It's not clear who is responsibile for defining these CGTypes, but we'll do it here.

public struct CGFloat {
    /// The native type used to store the CGFloat, which is Float on
    /// 32-bit architectures and Double on 64-bit architectures.
    /// We assume 64 bit for now
    public typealias NativeType = Double
    public init() {
        self.native = 0.0
    }
    public init(_ value: Float) {
        self.native = NativeType(value)
    }
    public init(_ value: Double) {
        self.native = NativeType(value)
    }
    /// The native value.
    public var native: NativeType
}

extension CGFloat: Comparable { }

public func ==(lhs: CGFloat, rhs: CGFloat) -> Bool {
    return lhs.native == rhs.native
}

public func <(lhs: CGFloat, rhs: CGFloat) -> Bool {
    return lhs.native < rhs.native
}

public func *(lhs: CGFloat, rhs: CGFloat) -> CGFloat {
    return CGFloat(lhs.native * rhs.native)
}

public func +(lhs: CGFloat, rhs: CGFloat) -> CGFloat {
    return CGFloat(lhs.native + rhs.native)
}

@_transparent extension Double {
    public init(_ value: CGFloat) {
        self = Double(value.native)
    }
}

public struct CGPoint {
    public var x: CGFloat
    public var y: CGFloat
    public init() {
        self.init(x: CGFloat(), y: CGFloat())
    }
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

extension CGPoint: Equatable { }

public func ==(lhs: CGPoint, rhs: CGPoint) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y
}

public struct CGSize {
    public var width: CGFloat
    public var height: CGFloat
    public init() {
        self.init(width: CGFloat(), height: CGFloat())
    }
    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
}

extension CGSize: Equatable { }

public func ==(lhs: CGSize, rhs: CGSize) -> Bool {
    return lhs.width == rhs.width && lhs.height == rhs.height
}

public struct CGRect {
    public var origin: CGPoint
    public var size: CGSize
    public init() {
        self.init(origin: CGPoint(), size: CGSize())
    }
    public init(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
    }
}

extension CGRect: Equatable { }

public func ==(lhs: CGRect, rhs: CGRect) -> Bool {
    return lhs.origin == rhs.origin && lhs.size == rhs.size
}

public typealias NSPoint = CGPoint

public typealias NSPointPointer = UnsafeMutablePointer<NSPoint>
public typealias NSPointArray = UnsafeMutablePointer<NSPoint>

public typealias NSSize = CGSize

public typealias NSSizePointer = UnsafeMutablePointer<NSSize>
public typealias NSSizeArray = UnsafeMutablePointer<NSSize>

public typealias NSRect = CGRect

public typealias NSRectPointer = UnsafeMutablePointer<NSRect>
public typealias NSRectArray = UnsafeMutablePointer<NSRect>

public enum NSRectEdge : UInt {
    
    case MinX
    case MinY
    case MaxX
    case MaxY
}

public enum CGRectEdge : UInt32 {
    
    case MinXEdge
    case MinYEdge
    case MaxXEdge
    case MaxYEdge
}

extension NSRectEdge {
    public init(rectEdge: CGRectEdge) {
        switch rectEdge {
        case .MinXEdge: self = .MinX
        case .MinYEdge: self = .MinY
        case .MaxXEdge: self = .MaxX
        case .MaxYEdge: self = .MaxY
        }
    }
}

public struct NSEdgeInsets {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat

    public init() {
        self.init(top: CGFloat(), left: CGFloat(), bottom: CGFloat(), right: CGFloat())
    }

    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

public struct NSAlignmentOptions : OptionSetType {
    public var rawValue : UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    
    public static let AlignMinXInward = NSAlignmentOptions(rawValue: 1 << 0)
    public static let AlignMinYInward = NSAlignmentOptions(rawValue: 1 << 1)
    public static let AlignMaxXInward = NSAlignmentOptions(rawValue: 1 << 2)
    public static let AlignMaxYInward = NSAlignmentOptions(rawValue: 1 << 3)
    public static let AlignWidthInward = NSAlignmentOptions(rawValue: 1 << 4)
    public static let AlignHeightInward = NSAlignmentOptions(rawValue: 1 << 5)
    
    public static let AlignMinXOutward = NSAlignmentOptions(rawValue: 1 << 8)
    public static let AlignMinYOutward = NSAlignmentOptions(rawValue: 1 << 9)
    public static let AlignMaxXOutward = NSAlignmentOptions(rawValue: 1 << 10)
    public static let AlignMaxYOutward = NSAlignmentOptions(rawValue: 1 << 11)
    public static let AlignWidthOutward = NSAlignmentOptions(rawValue: 1 << 12)
    public static let AlignHeightOutward = NSAlignmentOptions(rawValue: 1 << 13)
    
    public static let AlignMinXNearest = NSAlignmentOptions(rawValue: 1 << 16)
    public static let AlignMinYNearest = NSAlignmentOptions(rawValue: 1 << 17)
    public static let AlignMaxXNearest = NSAlignmentOptions(rawValue: 1 << 18)
    public static let AlignMaxYNearest = NSAlignmentOptions(rawValue: 1 << 19)
    public static let AlignWidthNearest = NSAlignmentOptions(rawValue: 1 << 20)
    public static let AlignHeightNearest = NSAlignmentOptions(rawValue: 1 << 21)

    // pass this if the rect is in a flipped coordinate system. This allows 0.5 to be treated in a visually consistent way.
    public static let AlignRectFlipped = NSAlignmentOptions(rawValue: 1 << 63)
    
    // convenience combinations
    public static let AlignAllEdgesInward = [NSAlignmentOptions.AlignMinXInward, NSAlignmentOptions.AlignMaxXInward, NSAlignmentOptions.AlignMinYInward, NSAlignmentOptions.AlignMaxYInward]
    public static let AlignAllEdgesOutward = [NSAlignmentOptions.AlignMinXOutward, NSAlignmentOptions.AlignMaxXOutward, NSAlignmentOptions.AlignMinYOutward, NSAlignmentOptions.AlignMaxYOutward]
    public static let AlignAllEdgesNearest = [NSAlignmentOptions.AlignMinXNearest, NSAlignmentOptions.AlignMaxXNearest, NSAlignmentOptions.AlignMinYNearest, NSAlignmentOptions.AlignMaxYNearest]
}

public let NSZeroPoint: NSPoint = NSPoint()
public let NSZeroSize: NSSize = NSSize()
public let NSZeroRect: NSRect = NSRect()
public let NSEdgeInsetsZero: NSEdgeInsets = NSEdgeInsets()

public func NSMakePoint(x: CGFloat, _ y: CGFloat) -> NSPoint {
    return NSPoint(x: x, y: y)
}

public func NSMakeSize(w: CGFloat, _ h: CGFloat) -> NSSize {
    return NSSize(width: w, height: h)
}

public func NSMakeRect(x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    return NSRect(origin: NSPoint(x: x, y: y), size: NSSize(width: w, height: h))
}

public func NSMaxX(aRect: NSRect) -> CGFloat { return CGFloat(aRect.origin.x.native + aRect.size.width.native) }

public func NSMaxY(aRect: NSRect) -> CGFloat { return CGFloat(aRect.origin.y.native + aRect.size.height.native) }

public func NSMidX(aRect: NSRect) -> CGFloat { return CGFloat(aRect.origin.x.native + (aRect.size.width.native / 2)) }

public func NSMidY(aRect: NSRect) -> CGFloat { return CGFloat(aRect.origin.y.native + (aRect.size.height.native / 2)) }

public func NSMinX(aRect: NSRect) -> CGFloat { return aRect.origin.x }

public func NSMinY(aRect: NSRect) -> CGFloat { return aRect.origin.y }

public func NSWidth(aRect: NSRect) -> CGFloat { return aRect.size.width }

public func NSHeight(aRect: NSRect) -> CGFloat { return aRect.size.height }

public func NSRectFromCGRect(cgrect: CGRect) -> NSRect { return cgrect }

public func NSRectToCGRect(nsrect: NSRect) -> CGRect { return nsrect }

public func NSPointFromCGPoint(cgpoint: CGPoint) -> NSPoint { return cgpoint }

public func NSPointToCGPoint(nspoint: NSPoint) -> CGPoint { return nspoint }

public func NSSizeFromCGSize(cgsize: CGSize) -> NSSize { return cgsize }

public func NSSizeToCGSize(nssize: NSSize) -> CGSize { return nssize }

public func NSEdgeInsetsMake(top: CGFloat, _ left: CGFloat, _ bottom: CGFloat, _ right: CGFloat) -> NSEdgeInsets {
    return NSEdgeInsets(top: top, left: left, bottom: bottom, right: right)
}

public func NSEqualPoints(aPoint: NSPoint, _ bPoint: NSPoint) -> Bool { return aPoint == bPoint }

public func NSEqualSizes(aSize: NSSize, _ bSize: NSSize) -> Bool { return aSize == bSize }

public func NSEqualRects(aRect: NSRect, _ bRect: NSRect) -> Bool { return aRect == bRect }

public func NSIsEmptyRect(aRect: NSRect) -> Bool { return (aRect.size.width.native <= 0) || (aRect.size.height.native <= 0) }

public func NSEdgeInsetsEqual(aInsets: NSEdgeInsets, _ bInsets: NSEdgeInsets) -> Bool {
    return (aInsets.top == bInsets.top) && (aInsets.left == bInsets.left) && (aInsets.bottom == bInsets.bottom) && (aInsets.right == bInsets.right)
}

public func NSInsetRect(aRect: NSRect, _ dX: CGFloat, _ dY: CGFloat) -> NSRect {
    let x = CGFloat(aRect.origin.x.native + dX.native)
    let y = CGFloat(aRect.origin.y.native + dY.native)
    let w = CGFloat(aRect.size.width.native - (dX.native * 2))
    let h = CGFloat(aRect.size.height.native - (dY.native * 2))
    return NSMakeRect(x, y, w, h)
}

public func NSIntegralRect(aRect: NSRect) -> NSRect { NSUnimplemented() }
public func NSIntegralRectWithOptions(aRect: NSRect, _ opts: NSAlignmentOptions) -> NSRect { NSUnimplemented() }

public func NSUnionRect(aRect: NSRect, _ bRect: NSRect) -> NSRect { NSUnimplemented() }
public func NSIntersectionRect(aRect: NSRect, _ bRect: NSRect) -> NSRect { NSUnimplemented() }
public func NSOffsetRect(aRect: NSRect, _ dX: CGFloat, _ dY: CGFloat) -> NSRect { NSUnimplemented() }
public func NSDivideRect(inRect: NSRect, _ slice: UnsafeMutablePointer<NSRect>, _ rem: UnsafeMutablePointer<NSRect>, _ amount: CGFloat, _ edge: NSRectEdge) { NSUnimplemented() }
public func NSPointInRect(aPoint: NSPoint, _ aRect: NSRect) -> Bool { NSUnimplemented() }
public func NSMouseInRect(aPoint: NSPoint, _ aRect: NSRect, _ flipped: Bool) -> Bool { NSUnimplemented() }
public func NSContainsRect(aRect: NSRect, _ bRect: NSRect) -> Bool { NSUnimplemented() }
public func NSIntersectsRect(aRect: NSRect, _ bRect: NSRect) -> Bool { NSUnimplemented() }

public func NSStringFromPoint(aPoint: NSPoint) -> String { NSUnimplemented() }
public func NSStringFromSize(aSize: NSSize) -> String { NSUnimplemented() }
public func NSStringFromRect(aRect: NSRect) -> String { NSUnimplemented() }
public func NSPointFromString(aString: String) -> NSPoint { NSUnimplemented() }
public func NSSizeFromString(aString: String) -> NSSize { NSUnimplemented() }
public func NSRectFromString(aString: String) -> NSRect { NSUnimplemented() }

extension NSValue {
    
    public convenience init(point: NSPoint) { NSUnimplemented() }
    public convenience init(size: NSSize) { NSUnimplemented() }
    public convenience init(rect: NSRect) { NSUnimplemented() }
    public convenience init(edgeInsets insets: NSEdgeInsets) { NSUnimplemented() }
    
    public var pointValue: NSPoint { NSUnimplemented() }
    public var sizeValue: NSSize { NSUnimplemented() }
    
    public var rectValue: NSRect { NSUnimplemented() }
    public var edgeInsetsValue: NSEdgeInsets { NSUnimplemented() }
}

extension NSCoder {
    
    public func encodePoint(point: NSPoint) { NSUnimplemented() }
    public func decodePoint() -> NSPoint { NSUnimplemented() }
    
    public func encodeSize(size: NSSize) { NSUnimplemented() }
    public func decodeSize() -> NSSize { NSUnimplemented() }
    
    public func encodeRect(rect: NSRect) { NSUnimplemented() }
    public func decodeRect() -> NSRect { NSUnimplemented() }
}

extension NSCoder {
    
    public func encodePoint(point: NSPoint, forKey key: String) { NSUnimplemented() }
    public func encodeSize(size: NSSize, forKey key: String) { NSUnimplemented() }
    public func encodeRect(rect: NSRect, forKey key: String) { NSUnimplemented() }
    
    public func decodePointForKey(key: String) -> NSPoint { NSUnimplemented() }
    public func decodeSizeForKey(key: String) -> NSSize { NSUnimplemented() }
    public func decodeRectForKey(key: String) -> NSRect { NSUnimplemented() }
}
