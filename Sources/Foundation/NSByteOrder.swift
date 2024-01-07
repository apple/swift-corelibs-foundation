// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation

/// The byte order is unknown.
public let NS_UnknownByteOrder: Int = Int(CFByteOrderUnknown.rawValue)
/// The byte order is little endian.
public let NS_LittleEndian: Int = Int(CFByteOrderLittleEndian.rawValue)
/// The byte order is big endian.
public let NS_BigEndian: Int = Int(CFByteOrderBigEndian.rawValue)

/// Returns the endian format.
@inline(__always) public func NSHostByteOrder() -> Int {
    return CFByteOrderGetCurrent()
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapShort(_ inv: UInt16) -> UInt16 {
    return CFSwapInt16(inv)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapInt(_ inv: UInt32) -> UInt32 {
    return CFSwapInt32(inv)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapLong(_ inv: UInt) -> UInt {
#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
    return UInt(CFSwapInt64(UInt64(inv)))
#else
    return CFSwapInt32(inv)
#endif
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapLongLong(_ inv: UInt64) -> UInt64 {
    return CFSwapInt64(inv)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapBigShortToHost(_ x: UInt16) -> UInt16 {
    return CFSwapInt16BigToHost(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapBigIntToHost(_ x: UInt32) -> UInt32 {
    return CFSwapInt32BigToHost(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapBigLongToHost(_ x: UInt) -> UInt {
#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
    return UInt(CFSwapInt64BigToHost(UInt64(x)))
#else
    return CFSwapInt32BigToHost(x)
#endif
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapBigLongLongToHost(_ x: UInt64) -> UInt64 {
    return CFSwapInt64BigToHost(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostShortToBig(_ x: UInt16) -> UInt16 {
    return CFSwapInt16HostToBig(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostIntToBig(_ x: UInt32) -> UInt32 {
    return CFSwapInt32HostToBig(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostLongToBig(_ x: UInt) -> UInt {
#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
    return UInt(CFSwapInt64HostToBig(UInt64(x)))
#else
    return CFSwapInt32HostToBig(x)
#endif
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostLongLongToBig(_ x: UInt64) -> UInt64 {
    return CFSwapInt64HostToBig(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapLittleShortToHost(_ x: UInt16) -> UInt16 {
    return CFSwapInt16LittleToHost(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapLittleIntToHost(_ x: UInt32) -> UInt32 {
    return CFSwapInt32LittleToHost(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapLittleLongToHost(_ x: UInt) -> UInt {
#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
    return UInt(CFSwapInt64LittleToHost(UInt64(x)))
#else
    return CFSwapInt32LittleToHost(x)
#endif
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapLittleLongLongToHost(_ x: UInt64) -> UInt64 {
    return CFSwapInt64LittleToHost(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostShortToLittle(_ x: UInt16) -> UInt16 {
    return CFSwapInt16HostToLittle(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostIntToLittle(_ x: UInt32) -> UInt32 {
    return CFSwapInt32HostToLittle(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostLongToLittle(_ x: UInt) -> UInt {
#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
    return UInt(CFSwapInt64HostToLittle(UInt64(x)))
#else
    return CFSwapInt32HostToLittle(x)
#endif
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostLongLongToLittle(_ x: UInt64) -> UInt64 {
    return CFSwapInt64HostToLittle(x)
}

/// Opaque type containing an endian-independent `float` value.
public struct NSSwappedFloat : @unchecked Sendable {
    public var v: UInt32

    public init() {
        self.v = 0
    }

    public init(v: UInt32) {
        self.v = v
    }
}

/// Opaque structure containing endian-independent `double` value.
public struct NSSwappedDouble : @unchecked Sendable {
    public var v: UInt64

    public init() {
        self.v = 0
    }

    public init(v: UInt64) {
        self.v = v
    }
}

/// Performs a type conversion.
@inline(__always) public func NSConvertHostFloatToSwapped(_ x: Float) -> NSSwappedFloat {
    return NSSwappedFloat(v: x.bitPattern)
}

/// Performs a type conversion.
@inline(__always) public func NSConvertSwappedFloatToHost(_ x: NSSwappedFloat) -> Float {
    return Float(bitPattern: x.v)
}

/// Performs a type conversion.
@inline(__always) public func NSConvertHostDoubleToSwapped(_ x: Double) -> NSSwappedDouble {
    return NSSwappedDouble(v: x.bitPattern)
}

/// Performs a type conversion.
@inline(__always) public func NSConvertSwappedDoubleToHost(_ x: NSSwappedDouble) -> Double {
    return Double(bitPattern: x.v)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapFloat(_ x: NSSwappedFloat) -> NSSwappedFloat {
    return NSSwappedFloat(v: NSSwapInt(x.v))
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapDouble(_ x: NSSwappedDouble) -> NSSwappedDouble {
    return NSSwappedDouble(v: NSSwapLongLong(x.v))
}

#if _endian(big)

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapBigDoubleToHost(_ x: NSSwappedDouble) -> Double {
    return NSConvertSwappedDoubleToHost(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapBigFloatToHost(_ x: NSSwappedFloat) -> Float {
    return NSConvertSwappedFloatToHost(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostDoubleToBig(_ x: Double) -> NSSwappedDouble {
    return NSConvertHostDoubleToSwapped(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostFloatToBig(_ x: Float) -> NSSwappedFloat {
    return NSConvertHostFloatToSwapped(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapLittleDoubleToHost(_ x: NSSwappedDouble) -> Double {
    return NSConvertSwappedDoubleToHost(NSSwapDouble(x))
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapLittleFloatToHost(_ x: NSSwappedFloat) -> Float {
    return NSConvertSwappedFloatToHost(NSSwapFloat(x))
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostDoubleToLittle(_ x: Double) -> NSSwappedDouble {
    return NSSwapDouble(NSConvertHostDoubleToSwapped(x))
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostFloatToLittle(_ x: Float) -> NSSwappedFloat {
    return NSSwapFloat(NSConvertHostFloatToSwapped(x))
}

#elseif _endian(little)

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapBigDoubleToHost(_ x: NSSwappedDouble) -> Double {
    return NSConvertSwappedDoubleToHost(NSSwapDouble(x))
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapBigFloatToHost(_ x: NSSwappedFloat) -> Float {
    return NSConvertSwappedFloatToHost(NSSwapFloat(x))
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostDoubleToBig(_ x: Double) -> NSSwappedDouble {
    return NSSwapDouble(NSConvertHostDoubleToSwapped(x))
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostFloatToBig(_ x: Float) -> NSSwappedFloat {
    return NSSwapFloat(NSConvertHostFloatToSwapped(x))
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapLittleDoubleToHost(_ x: NSSwappedDouble) -> Double {
    return NSConvertSwappedDoubleToHost(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapLittleFloatToHost(_ x: NSSwappedFloat) -> Float {
    return NSConvertSwappedFloatToHost(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostDoubleToLittle(_ x: Double) -> NSSwappedDouble {
    return NSConvertHostDoubleToSwapped(x)
}

/// Swaps the bytes of a number.
@inline(__always) public func NSSwapHostFloatToLittle(_ x: Float) -> NSSwappedFloat {
    return NSConvertHostFloatToSwapped(x)
}

#else
#errors("Do not know the endianess of this architecture")
#endif
