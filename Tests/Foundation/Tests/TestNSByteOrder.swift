// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
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

class TestNSByteOrder: XCTestCase {
    func test_NSHostByteOrder() throws {
#if _endian(big)
        XCTAssertEqual(NSHostByteOrder(), NS_BigEndian)
#elseif _endian(little)
        XCTAssertEqual(NSHostByteOrder(), NS_LittleEndian)
#endif
    }

    func test_NSSwapShort() throws {
        XCTAssertEqual(NSSwapShort(0x0001), 0x0100)
    }

    func test_NSSwapInt() throws {
        XCTAssertEqual(NSSwapInt(0x00000001), 0x01000000)
    }

    func test_NSSwapLong() throws {
#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        XCTAssertEqual(NSSwapLong(0x0000000000000001), 0x0100000000000000)
#else
        XCTAssertEqual(NSSwapLong(0x00000001), 0x01000000)
#endif
    }

    func test_NSSwapLongLong() throws {
        XCTAssertEqual(NSSwapLongLong(0x0000000000000001), 0x0100000000000000)
    }

    func test_NSSwapBigShortToHost() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapBigShortToHost(0x0001), 0x0001)
#elseif _endian(little)
        XCTAssertEqual(NSSwapBigShortToHost(0x0001), 0x0100)
#endif
    }

    func test_NSSwapBigIntToHost() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapBigIntToHost(0x00000001), 0x00000001)
#elseif _endian(little)
        XCTAssertEqual(NSSwapBigIntToHost(0x00000001), 0x01000000)
#endif
    }

    func test_NSSwapBigLongToHost() throws {
#if _endian(big) && arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        XCTAssertEqual(NSSwapBigLongToHost(0x0000000000000001), 0x0000000000000001)
#elseif _endian(big)
        XCTAssertEqual(NSSwapBigLongToHost(0x00000001), 0x00000001)
#elseif _endian(little) && arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        XCTAssertEqual(NSSwapBigLongToHost(0x0000000000000001), 0x0100000000000000)
#elseif _endian(little)
        XCTAssertEqual(NSSwapBigLongToHost(0x00000001), 0x01000000)
#endif
    }

    func test_NSSwapBigLongLongToHost() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapBigLongLongToHost(0x0000000000000001), 0x0000000000000001)
#elseif _endian(little)
        XCTAssertEqual(NSSwapBigLongLongToHost(0x0000000000000001), 0x0100000000000000)
#endif
    }

    func test_NSSwapHostShortToBig() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapHostShortToBig(0x0001), 0x0001)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostShortToBig(0x0001), 0x0100)
#endif
    }

    func test_NSSwapHostIntToBig() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapHostIntToBig(0x00000001), 0x00000001)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostIntToBig(0x00000001), 0x01000000)
#endif
    }

    func test_NSSwapHostLongToBig() throws {
#if _endian(big) && arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        XCTAssertEqual(NSSwapHostLongToBig(0x0000000000000001), 0x0000000000000001)
#elseif _endian(big)
        XCTAssertEqual(NSSwapHostLongToBig(0x00000001), 0x00000001)
#elseif _endian(little) && arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        XCTAssertEqual(NSSwapHostLongToBig(0x0000000000000001), 0x0100000000000000)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostLongToBig(0x00000001), 0x01000000)
#endif
    }

    func test_NSSwapHostLongLongToBig() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapHostLongLongToBig(0x0000000000000001), 0x0000000000000001)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostLongLongToBig(0x0000000000000001), 0x0100000000000000)
#endif
    }

    func test_NSSwapLittleShortToHost() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapLittleShortToHost(0x0001), 0x0100)
#elseif _endian(little)
        XCTAssertEqual(NSSwapLittleShortToHost(0x0001), 0x0001)
#endif
    }

    func test_NSSwapLittleIntToHost() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapLittleIntToHost(0x00000001), 0x01000000)
#elseif _endian(little)
        XCTAssertEqual(NSSwapLittleIntToHost(0x00000001), 0x00000001)
#endif
    }

    func test_NSSwapLittleLongToHost() throws {
#if _endian(big) && arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        XCTAssertEqual(NSSwapLittleLongToHost(0x0000000000000001), 0x0100000000000000)
#elseif _endian(big)
        XCTAssertEqual(NSSwapLittleLongToHost(0x00000001), 0x01000000)
#elseif _endian(little) && arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        XCTAssertEqual(NSSwapLittleLongToHost(0x0000000000000001), 0x0000000000000001)
#elseif _endian(little)
        XCTAssertEqual(NSSwapLittleLongToHost(0x00000001), 0x00000001)
#endif
    }

    func test_NSSwapLittleLongLongToHost() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapLittleLongLongToHost(0x0000000000000001), 0x0100000000000000)
#elseif _endian(little)
        XCTAssertEqual(NSSwapLittleLongLongToHost(0x0000000000000001), 0x0000000000000001)
#endif
    }

    func test_NSSwapHostShortToLittle() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapHostShortToLittle(0x0001), 0x0100)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostShortToLittle(0x0001), 0x0001)
#endif
    }

    func test_NSSwapHostIntToLittle() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapHostIntToLittle(0x00000001), 0x01000000)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostIntToLittle(0x00000001), 0x00000001)
#endif
    }

    func test_NSSwapHostLongToLittle() throws {
#if _endian(big) && arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        XCTAssertEqual(NSSwapHostLongToLittle(0x0000000000000001), 0x0100000000000000)
#elseif _endian(big)
        XCTAssertEqual(NSSwapHostLongToLittle(0x00000001), 0x01000000)
#elseif _endian(little) && arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        XCTAssertEqual(NSSwapHostLongToLittle(0x0000000000000001), 0x0000000000000001)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostLongToLittle(0x00000001), 0x00000001)
#endif
    }

    func test_NSSwapHostLongLongToLittle() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapHostLongLongToLittle(0x0000000000000001), 0x0100000000000000)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostLongLongToLittle(0x0000000000000001), 0x0000000000000001)
#endif
    }

    func test_NSConvertHostFloatToSwapped() throws {
        XCTAssertEqual(NSConvertHostFloatToSwapped(Float(bitPattern: 0x00000001)).v, 0x00000001)
    }

    func test_NSConvertSwappedFloatToHost() throws {
        XCTAssertEqual(NSConvertSwappedFloatToHost(NSSwappedFloat(v: 0x00000001)), Float(bitPattern: 0x00000001))
    }

    func test_NSConvertHostDoubleToSwapped() throws {
        XCTAssertEqual(NSConvertHostDoubleToSwapped(Double(bitPattern: 0x0100000000000000)).v, 0x0100000000000000)
    }

    func test_NSConvertSwappedDoubleToHost() throws {
        XCTAssertEqual(NSConvertSwappedDoubleToHost(NSSwappedDouble(v: 0x0100000000000000)), Double(bitPattern: 0x0100000000000000))
    }

    func test_NSSwapFloat() throws {
        XCTAssertEqual(NSSwapFloat(NSSwappedFloat(v: 0x00000001)).v, 0x01000000)
    }

    func test_NSSwapDouble() throws {
        XCTAssertEqual(NSSwapDouble(NSSwappedDouble(v: 0x0000000000000001)).v, 0x0100000000000000)
    }

    func test_NSSwapBigDoubleToHost() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapBigDoubleToHost(NSSwappedDouble(v: 0x0000000000000001)), Double(bitPattern: 0x0000000000000001))
#elseif _endian(little)
        XCTAssertEqual(NSSwapBigDoubleToHost(NSSwappedDouble(v: 0x0000000000000001)), Double(bitPattern: 0x0100000000000000))
#endif
    }

    func test_NSSwapBigFloatToHost() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapBigFloatToHost(NSSwappedFloat(v: 0x00000001)), Float(bitPattern: 0x00000001))
#elseif _endian(little)
        XCTAssertEqual(NSSwapBigFloatToHost(NSSwappedFloat(v: 0x00000001)), Float(bitPattern: 0x01000000))
#endif
    }

    func test_NSSwapHostDoubleToBig() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapHostDoubleToBig(Double(bitPattern: 0x0000000000000001)).v, 0x0000000000000001)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostDoubleToBig(Double(bitPattern: 0x0000000000000001)).v, 0x0100000000000000)
#endif
    }

    func test_NSSwapHostFloatToBig() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapHostFloatToBig(Float(bitPattern: 0x00000001)).v, 0x00000001)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostFloatToBig(Float(bitPattern: 0x00000001)).v, 0x01000000)
#endif
    }

    func test_NSSwapLittleDoubleToHost() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapLittleDoubleToHost(NSSwappedDouble(v: 0x0000000000000001)), Double(bitPattern: 0x0100000000000000))
#elseif _endian(little)
        XCTAssertEqual(NSSwapLittleDoubleToHost(NSSwappedDouble(v: 0x0000000000000001)), Double(bitPattern: 0x0000000000000001))
#endif
    }

    func test_NSSwapLittleFloatToHost() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapLittleFloatToHost(NSSwappedFloat(v: 0x00000001)), Float(bitPattern: 0x01000000))
#elseif _endian(little)
        XCTAssertEqual(NSSwapLittleFloatToHost(NSSwappedFloat(v: 0x00000001)), Float(bitPattern: 0x00000001))
#endif
    }

    func test_NSSwapHostDoubleToLittle() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapHostDoubleToLittle(Double(bitPattern: 0x0000000000000001)).v, 0x0100000000000000)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostDoubleToLittle(Double(bitPattern: 0x0000000000000001)).v, 0x0000000000000001)
#endif
    }

    func test_NSSwapHostFloatToLittle() throws {
#if _endian(big)
        XCTAssertEqual(NSSwapHostFloatToLittle(Float(bitPattern: 0x00000001)).v, 0x01000000)
#elseif _endian(little)
        XCTAssertEqual(NSSwapHostFloatToLittle(Float(bitPattern: 0x00000001)).v, 0x00000001)
#endif
    }

    static var allTests: [(String, (TestNSByteOrder) -> () throws -> Void)] {
        return [
            ("test_NSHostByteOrder", test_NSHostByteOrder),
            ("test_NSSwapShort", test_NSSwapShort),
            ("test_NSSwapInt", test_NSSwapInt),
            ("test_NSSwapLong", test_NSSwapLong),
            ("test_NSSwapLongLong", test_NSSwapLongLong),
            ("test_NSSwapBigShortToHost", test_NSSwapBigShortToHost),
            ("test_NSSwapBigIntToHost", test_NSSwapBigIntToHost),
            ("test_NSSwapBigLongToHost", test_NSSwapBigLongToHost),
            ("test_NSSwapBigLongLongToHost", test_NSSwapBigLongLongToHost),
            ("test_NSSwapHostShortToBig", test_NSSwapHostShortToBig),
            ("test_NSSwapHostIntToBig", test_NSSwapHostIntToBig),
            ("test_NSSwapHostLongToBig", test_NSSwapHostLongToBig),
            ("test_NSSwapHostLongLongToBig", test_NSSwapHostLongLongToBig),
            ("test_NSSwapLittleShortToHost", test_NSSwapLittleShortToHost),
            ("test_NSSwapLittleIntToHost", test_NSSwapLittleIntToHost),
            ("test_NSSwapLittleLongToHost", test_NSSwapLittleLongToHost),
            ("test_NSSwapLittleLongLongToHost", test_NSSwapLittleLongLongToHost),
            ("test_NSSwapHostShortToLittle", test_NSSwapHostShortToLittle),
            ("test_NSSwapHostIntToLittle", test_NSSwapHostIntToLittle),
            ("test_NSSwapHostLongToLittle", test_NSSwapHostLongToLittle),
            ("test_NSSwapHostLongLongToLittle", test_NSSwapHostLongLongToLittle),
            ("test_NSConvertHostFloatToSwapped", test_NSConvertHostFloatToSwapped),
            ("test_NSConvertSwappedFloatToHost", test_NSConvertSwappedFloatToHost),
            ("test_NSConvertHostDoubleToSwapped", test_NSConvertHostDoubleToSwapped),
            ("test_NSConvertSwappedDoubleToHost", test_NSConvertSwappedDoubleToHost),
            ("test_NSSwapFloat", test_NSSwapFloat),
            ("test_NSSwapDouble", test_NSSwapDouble),
            ("test_NSSwapBigDoubleToHost", test_NSSwapBigDoubleToHost),
            ("test_NSSwapBigFloatToHost", test_NSSwapBigFloatToHost),
            ("test_NSSwapHostDoubleToBig", test_NSSwapHostDoubleToBig),
            ("test_NSSwapHostFloatToBig", test_NSSwapHostFloatToBig),
            ("test_NSSwapLittleDoubleToHost", test_NSSwapLittleDoubleToHost),
            ("test_NSSwapLittleFloatToHost", test_NSSwapLittleFloatToHost),
            ("test_NSSwapHostDoubleToLittle", test_NSSwapHostDoubleToLittle),
            ("test_NSSwapHostFloatToLittle", test_NSSwapHostFloatToLittle),
        ]
    }
}