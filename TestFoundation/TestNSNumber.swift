// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestNSNumber : XCTestCase {
    static var allTests: [(String, (TestNSNumber) -> () throws -> Void)] {
        return [
            ("test_NumberWithBool", test_NumberWithBool ),
            ("test_CFBoolean", test_CFBoolean ),
            ("test_numberWithChar", test_numberWithChar ),
            ("test_numberWithUnsignedChar", test_numberWithUnsignedChar ),
            ("test_numberWithShort", test_numberWithShort ),
            ("test_numberWithUnsignedShort", test_numberWithUnsignedShort ),
            ("test_numberWithLong", test_numberWithLong ),
            ("test_numberWithUnsignedLong", test_numberWithUnsignedLong ),
            ("test_numberWithLongLong", test_numberWithLongLong ),
            ("test_numberWithUnsignedLongLong", test_numberWithUnsignedLongLong ),
            ("test_numberWithInt", test_numberWithInt ),
            ("test_numberWithUInt", test_numberWithUInt ),
            ("test_numberWithFloat", test_numberWithFloat ),
            ("test_numberWithDouble", test_numberWithDouble ),
            ("test_compareNumberWithBool", test_compareNumberWithBool ),
            ("test_compareNumberWithChar", test_compareNumberWithChar ),
            ("test_compareNumberWithUnsignedChar", test_compareNumberWithUnsignedChar ),
            ("test_compareNumberWithShort", test_compareNumberWithShort ),
            ("test_compareNumberWithFloat", test_compareNumberWithFloat ),
            ("test_compareNumberWithDouble", test_compareNumberWithDouble ),
            ("test_description", test_description ),
            ("test_descriptionWithLocale", test_descriptionWithLocale ),
            ("test_objCType", test_objCType ),
            ("test_stringValue", test_stringValue),
            ("test_Equals", test_Equals),
            ("test_boolValue", test_boolValue),
            ("test_AnyHashable", test_AnyHashable),
        ]
    }
    
    func test_NumberWithBool() {
        XCTAssertEqual(NSNumber(value: true).boolValue, true)
        XCTAssertEqual(NSNumber(value: true).int8Value, Int8(1))
        XCTAssertEqual(NSNumber(value: true).uint8Value, UInt8(1))
        XCTAssertEqual(NSNumber(value: true).int16Value, Int16(1))
        XCTAssertEqual(NSNumber(value: true).uint16Value, UInt16(1))
        XCTAssertEqual(NSNumber(value: true).int32Value, Int32(1))
        XCTAssertEqual(NSNumber(value: true).uint32Value, UInt32(1))
        XCTAssertEqual(NSNumber(value: true).int64Value, Int64(1))
        XCTAssertEqual(NSNumber(value: true).uint64Value, UInt64(1))

        XCTAssertEqual(NSNumber(value: true).floatValue, Float(1))
        XCTAssertEqual(NSNumber(value: true).doubleValue, Double(1))
        
        XCTAssertEqual(NSNumber(value: false).boolValue, false)
        XCTAssertEqual(NSNumber(value: false).int8Value, Int8(0))
        XCTAssertEqual(NSNumber(value: false).uint8Value, UInt8(0))
        XCTAssertEqual(NSNumber(value: false).int16Value, Int16(0))
        XCTAssertEqual(NSNumber(value: false).uint16Value, UInt16(0))
        XCTAssertEqual(NSNumber(value: false).int32Value, Int32(0))
        XCTAssertEqual(NSNumber(value: false).uint32Value, UInt32(0))
        XCTAssertEqual(NSNumber(value: false).int64Value, Int64(0))
        XCTAssertEqual(NSNumber(value: false).uint64Value, UInt64(0))

        XCTAssertEqual(NSNumber(value: false).floatValue, Float(0))
        XCTAssertEqual(NSNumber(value: false).doubleValue, Double(0))
    }
    
    func test_CFBoolean() {
        guard let plist = try? PropertyListSerialization.data(fromPropertyList: ["test" : true], format: .binary, options: 0) else {
            XCTFail()
            return
        }
        guard let obj = (try? PropertyListSerialization.propertyList(from: plist, format: nil)) as? [String : Any] else {
            XCTFail()
            return
        }
        guard let value = obj["test"] else {
            XCTFail()
            return
        }
        guard let boolValue = value as? Bool else {
            XCTFail("Expected de-serialization as round-trip boolean value")
            return
        }
        XCTAssertTrue(boolValue)
    }
    
    func test_numberWithChar() {
        XCTAssertEqual(NSNumber(value: Int8(0)).boolValue, false)
        XCTAssertEqual(NSNumber(value: Int8(0)).int8Value, Int8(0))
        XCTAssertEqual(NSNumber(value: Int8(0)).uint8Value, UInt8(0))
        XCTAssertEqual(NSNumber(value: Int8(0)).int16Value, Int16(0))
        XCTAssertEqual(NSNumber(value: Int8(0)).uint16Value, UInt16(0))
        XCTAssertEqual(NSNumber(value: Int8(0)).int32Value, Int32(0))
        XCTAssertEqual(NSNumber(value: Int8(0)).uint32Value, UInt32(0))
        XCTAssertEqual(NSNumber(value: Int8(0)).int64Value, Int64(0))
        XCTAssertEqual(NSNumber(value: Int8(0)).uint64Value, UInt64(0))
        XCTAssertEqual(NSNumber(value: Int8(-37)).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int8(-37)).int8Value, Int8(-37))
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: Int8(-37)).int16Value, Int16(-37))
        XCTAssertEqual(NSNumber(value: Int8(-37)).int32Value, Int32(-37))
        XCTAssertEqual(NSNumber(value: Int8(-37)).int64Value, Int64(-37))
#endif
        XCTAssertEqual(NSNumber(value: Int8(42)).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int8(42)).int8Value, Int8(42))
        XCTAssertEqual(NSNumber(value: Int8(42)).uint8Value, UInt8(42))
        XCTAssertEqual(NSNumber(value: Int8(42)).int16Value, Int16(42))
        XCTAssertEqual(NSNumber(value: Int8(42)).uint16Value, UInt16(42))
        XCTAssertEqual(NSNumber(value: Int8(42)).int32Value, Int32(42))
        XCTAssertEqual(NSNumber(value: Int8(42)).uint32Value, UInt32(42))
        XCTAssertEqual(NSNumber(value: Int8(42)).int64Value, Int64(42))
        XCTAssertEqual(NSNumber(value: Int8(42)).uint64Value, UInt64(42))
        XCTAssertEqual(NSNumber(value: Int8.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int8.max).int8Value, Int8(Int8.max))
        XCTAssertEqual(NSNumber(value: Int8.max).uint8Value, UInt8(Int8.max))
        XCTAssertEqual(NSNumber(value: Int8.max).int16Value, Int16(Int8.max))
        XCTAssertEqual(NSNumber(value: Int8.max).uint16Value, UInt16(Int8.max))
        XCTAssertEqual(NSNumber(value: Int8.max).int32Value, Int32(Int8.max))
        XCTAssertEqual(NSNumber(value: Int8.max).uint32Value, UInt32(Int8.max))
        XCTAssertEqual(NSNumber(value: Int8.max).int64Value, Int64(Int8.max))
        XCTAssertEqual(NSNumber(value: Int8.max).uint64Value, UInt64(Int8.max))
        XCTAssertEqual(NSNumber(value: Int8.min).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int8.min).int8Value, Int8(Int8.min))
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: Int8.min).int16Value, Int16(Int8.min))
        XCTAssertEqual(NSNumber(value: Int8.min).int32Value, Int32(Int8.min))
        XCTAssertEqual(NSNumber(value: Int8.min).int64Value, Int64(Int8.min))
#endif
        XCTAssertEqual(NSNumber(value: Int8(0)).floatValue, Float(0))
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: Int8(-37)).floatValue, Float(-37))
#endif
        XCTAssertEqual(NSNumber(value: Int8(42)).floatValue, Float(42))
        XCTAssertEqual(NSNumber(value: Int8.max).floatValue, Float(Int8.max))
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: Int8.min).floatValue, Float(Int8.min))
#endif
        XCTAssertEqual(NSNumber(value: Int8(0)).doubleValue, Double(0))
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: Int8(-37)).doubleValue, Double(-37))
#endif
        XCTAssertEqual(NSNumber(value: Int8(42)).doubleValue, Double(42))
        XCTAssertEqual(NSNumber(value: Int8.max).doubleValue, Double(Int8.max))
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: Int8.min).doubleValue, Double(Int8.min))
#endif
    }
    
    func test_numberWithUnsignedChar() {
        XCTAssertEqual(NSNumber(value: UInt8(42)).boolValue, true)
        XCTAssertEqual(NSNumber(value: UInt8(42)).int8Value, Int8(42))
        XCTAssertEqual(NSNumber(value: UInt8(42)).uint8Value, UInt8(42))
        XCTAssertEqual(NSNumber(value: UInt8(42)).int16Value, Int16(42))
        XCTAssertEqual(NSNumber(value: UInt8(42)).uint16Value, UInt16(42))
        XCTAssertEqual(NSNumber(value: UInt8(42)).int32Value, Int32(42))
        XCTAssertEqual(NSNumber(value: UInt8(42)).uint32Value, UInt32(42))
        XCTAssertEqual(NSNumber(value: UInt8(42)).int64Value, Int64(42))
        XCTAssertEqual(NSNumber(value: UInt8(42)).uint64Value, UInt64(42))
        XCTAssertEqual(NSNumber(value: UInt8(42)).floatValue, Float(42))
        XCTAssertEqual(NSNumber(value: UInt8(42)).doubleValue, Double(42))

        XCTAssertEqual(NSNumber(value: UInt8.min).boolValue, false)
        XCTAssertEqual(NSNumber(value: UInt8.min).int8Value, Int8(UInt8.min))
        XCTAssertEqual(NSNumber(value: UInt8.min).int16Value, Int16(UInt8.min))
        XCTAssertEqual(NSNumber(value: UInt8.min).int32Value, Int32(UInt8.min))
        XCTAssertEqual(NSNumber(value: UInt8.min).int64Value, Int64(UInt8.min))
        XCTAssertEqual(NSNumber(value: UInt8.min).floatValue, Float(UInt8.min))
        XCTAssertEqual(NSNumber(value: UInt8.min).doubleValue, Double(UInt8.min))

        //--------

        XCTAssertEqual(NSNumber(value: UInt8(0)).boolValue, false)

        XCTAssertEqual(NSNumber(value: UInt8(0)).int8Value, 0)
        XCTAssertEqual(NSNumber(value: UInt8(0)).int16Value, 0)
        XCTAssertEqual(NSNumber(value: UInt8(0)).int32Value, 0)
        XCTAssertEqual(NSNumber(value: UInt8(0)).int64Value, 0)

        XCTAssertEqual(NSNumber(value: UInt8(0)).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: UInt8(0)).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: UInt8(0)).uint32Value, 0)
        XCTAssertEqual(NSNumber(value: UInt8(0)).uint64Value, 0)

        XCTAssertEqual(NSNumber(value: UInt8(0)).intValue, 0)
        XCTAssertEqual(NSNumber(value: UInt8(0)).uintValue, 0)

        XCTAssertEqual(NSNumber(value: UInt8(0)).floatValue, 0)
        XCTAssertEqual(NSNumber(value: UInt8(0)).doubleValue, 0)

        //------

        XCTAssertEqual(NSNumber(value: UInt8.max).boolValue, true)

        XCTAssertEqual(NSNumber(value: UInt8.max).int8Value, -1)
        XCTAssertEqual(NSNumber(value: UInt8.max).int16Value, 255)
        XCTAssertEqual(NSNumber(value: UInt8.max).int32Value, 255)
        XCTAssertEqual(NSNumber(value: UInt8.max).int64Value, 255)

        XCTAssertEqual(NSNumber(value: UInt8.max).uint8Value, 255)
        XCTAssertEqual(NSNumber(value: UInt8.max).uint16Value, 255)
        XCTAssertEqual(NSNumber(value: UInt8.max).uint32Value, 255)
        XCTAssertEqual(NSNumber(value: UInt8.max).uint64Value, 255)

        XCTAssertEqual(NSNumber(value: UInt8.max).intValue, 255)
        XCTAssertEqual(NSNumber(value: UInt8.max).uintValue, 255)

        XCTAssertEqual(NSNumber(value: UInt8.max).floatValue, Float(UInt8.max))
        XCTAssertEqual(NSNumber(value: UInt8.max).doubleValue, Double(UInt8.max))
    }
    
    func test_numberWithShort() {
        XCTAssertEqual(NSNumber(value: Int16(0)).boolValue, false)
        XCTAssertEqual(NSNumber(value: Int16(0)).int8Value, Int8(0))
        XCTAssertEqual(NSNumber(value: Int16(0)).uint8Value, UInt8(0))
        XCTAssertEqual(NSNumber(value: Int16(0)).int16Value, Int16(0))
        XCTAssertEqual(NSNumber(value: Int16(0)).uint16Value, UInt16(0))
        XCTAssertEqual(NSNumber(value: Int16(0)).int32Value, Int32(0))
        XCTAssertEqual(NSNumber(value: Int16(0)).uint32Value, UInt32(0))
        XCTAssertEqual(NSNumber(value: Int16(0)).int64Value, Int64(0))
        XCTAssertEqual(NSNumber(value: Int16(0)).uint64Value, UInt64(0))
        XCTAssertEqual(NSNumber(value: Int16(-37)).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int16(-37)).int8Value, Int8(-37))
        XCTAssertEqual(NSNumber(value: Int16(-37)).int16Value, Int16(-37))
        XCTAssertEqual(NSNumber(value: Int16(-37)).int32Value, Int32(-37))
        XCTAssertEqual(NSNumber(value: Int16(-37)).int64Value, Int64(-37))
        XCTAssertEqual(NSNumber(value: Int16(42)).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int16(42)).int8Value, Int8(42))
        XCTAssertEqual(NSNumber(value: Int16(42)).uint8Value, UInt8(42))
        XCTAssertEqual(NSNumber(value: Int16(42)).int16Value, Int16(42))
        XCTAssertEqual(NSNumber(value: Int16(42)).uint16Value, UInt16(42))
        XCTAssertEqual(NSNumber(value: Int16(42)).int32Value, Int32(42))
        XCTAssertEqual(NSNumber(value: Int16(42)).uint32Value, UInt32(42))
        XCTAssertEqual(NSNumber(value: Int16(42)).int64Value, Int64(42))
        XCTAssertEqual(NSNumber(value: Int16(42)).uint64Value, UInt64(42))
        XCTAssertEqual(NSNumber(value: Int16.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int16.min).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int16(0)).floatValue, Float(0))
        XCTAssertEqual(NSNumber(value: Int16(-37)).floatValue, Float(-37))
        XCTAssertEqual(NSNumber(value: Int16(42)).floatValue, Float(42))
        XCTAssertEqual(NSNumber(value: Int16(0)).doubleValue, Double(0))
        XCTAssertEqual(NSNumber(value: Int16(-37)).doubleValue, Double(-37))
        XCTAssertEqual(NSNumber(value: Int16(42)).doubleValue, Double(42))

        //------

        XCTAssertEqual(NSNumber(value: Int16(0)).boolValue, false)

        XCTAssertEqual(NSNumber(value: Int16(0)).int8Value, 0)
        XCTAssertEqual(NSNumber(value: Int16(0)).int16Value, 0)
        XCTAssertEqual(NSNumber(value: Int16(0)).int32Value, 0)
        XCTAssertEqual(NSNumber(value: Int16(0)).int64Value, 0)

        XCTAssertEqual(NSNumber(value: Int16(0)).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: Int16(0)).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: Int16(0)).uint32Value, 0)
        XCTAssertEqual(NSNumber(value: Int16(0)).uint64Value, 0)

        XCTAssertEqual(NSNumber(value: Int16(0)).intValue, 0)
        XCTAssertEqual(NSNumber(value: Int16(0)).uintValue, 0)

        XCTAssertEqual(NSNumber(value: Int16(0)).floatValue, 0)
        XCTAssertEqual(NSNumber(value: Int16(0)).doubleValue, 0)

        //------

        XCTAssertEqual(NSNumber(value: Int16.min).boolValue, true)

        XCTAssertEqual(NSNumber(value: Int16.min).int8Value, 0)
        XCTAssertEqual(NSNumber(value: Int16.min).int16Value, -32768)
        XCTAssertEqual(NSNumber(value: Int16.min).int32Value, -32768)
        XCTAssertEqual(NSNumber(value: Int16.min).int64Value, -32768)

        XCTAssertEqual(NSNumber(value: Int16.min).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: Int16.min).uint16Value, 32768)
        XCTAssertEqual(NSNumber(value: Int16.min).uint32Value, 4294934528)
        XCTAssertEqual(NSNumber(value: Int16.min).uint64Value, 18446744073709518848)

        XCTAssertEqual(NSNumber(value: Int16.min).intValue, -32768)
        let uintSize = MemoryLayout<UInt>.size
        switch uintSize {
        case 4: XCTAssertEqual(NSNumber(value: Int16.min).uintValue, 4294934528)
        case 8:
#if arch(arm)
                break
#else
                XCTAssertEqual(NSNumber(value: Int16.min).uintValue, 18446744073709518848)
#endif
        default: XCTFail("Unexpected UInt size: \(uintSize)")
        }

        XCTAssertEqual(NSNumber(value: Int16.min).floatValue, Float(Int16.min))
        XCTAssertEqual(NSNumber(value: Int16.min).doubleValue, Double(Int16.min))

        //------

        XCTAssertEqual(NSNumber(value: Int16.max).boolValue, true)

        XCTAssertEqual(NSNumber(value: Int16.max).int8Value, -1)
        XCTAssertEqual(NSNumber(value: Int16.max).int16Value, 32767)
        XCTAssertEqual(NSNumber(value: Int16.max).int32Value, 32767)
        XCTAssertEqual(NSNumber(value: Int16.max).int64Value, 32767)

        XCTAssertEqual(NSNumber(value: Int16.max).uint8Value, 255)
        XCTAssertEqual(NSNumber(value: Int16.max).uint16Value, 32767)
        XCTAssertEqual(NSNumber(value: Int16.max).uint32Value, 32767)
        XCTAssertEqual(NSNumber(value: Int16.max).uint64Value, 32767)

        XCTAssertEqual(NSNumber(value: Int16.max).intValue, 32767)
        XCTAssertEqual(NSNumber(value: Int16.max).uintValue, 32767)

        XCTAssertEqual(NSNumber(value: Int16.max).floatValue, Float(Int16.max))
        XCTAssertEqual(NSNumber(value: Int16.max).doubleValue, Double(Int16.max))
    }

    func test_numberWithUnsignedShort() {
        XCTAssertEqual(NSNumber(value: UInt16(0)).boolValue, false)

        XCTAssertEqual(NSNumber(value: UInt16(0)).int8Value, 0)
        XCTAssertEqual(NSNumber(value: UInt16(0)).int16Value, 0)
        XCTAssertEqual(NSNumber(value: UInt16(0)).int32Value, 0)
        XCTAssertEqual(NSNumber(value: UInt16(0)).int64Value, 0)

        XCTAssertEqual(NSNumber(value: UInt16(0)).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: UInt16(0)).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: UInt16(0)).uint32Value, 0)
        XCTAssertEqual(NSNumber(value: UInt16(0)).uint64Value, 0)

        XCTAssertEqual(NSNumber(value: UInt16(0)).intValue, 0)
        XCTAssertEqual(NSNumber(value: UInt16(0)).uintValue, 0)

        XCTAssertEqual(NSNumber(value: UInt16(0)).floatValue, 0.0)
        XCTAssertEqual(NSNumber(value: UInt16(0)).doubleValue, 0.0)

        //------

        XCTAssertEqual(NSNumber(value: UInt16.max).boolValue, true)

        XCTAssertEqual(NSNumber(value: UInt16.max).int8Value, -1)
        XCTAssertEqual(NSNumber(value: UInt16.max).int16Value, -1)
        XCTAssertEqual(NSNumber(value: UInt16.max).int32Value, 65535)
        XCTAssertEqual(NSNumber(value: UInt16.max).int64Value, 65535)

        XCTAssertEqual(NSNumber(value: UInt16.max).uint8Value, 255)
        XCTAssertEqual(NSNumber(value: UInt16.max).uint16Value, 65535)
        XCTAssertEqual(NSNumber(value: UInt16.max).uint32Value, 65535)
        XCTAssertEqual(NSNumber(value: UInt16.max).uint64Value, 65535)

        XCTAssertEqual(NSNumber(value: UInt16.max).intValue, 65535)
        XCTAssertEqual(NSNumber(value: UInt16.max).uintValue, 65535)

        XCTAssertEqual(NSNumber(value: UInt16.max).floatValue, Float(UInt16.max))
        XCTAssertEqual(NSNumber(value: UInt16.max).doubleValue, Double(UInt16.max))
    }

    func test_numberWithLong() {
        XCTAssertEqual(NSNumber(value: Int32(0)).boolValue, false)

        XCTAssertEqual(NSNumber(value: Int32(0)).int8Value, 0)
        XCTAssertEqual(NSNumber(value: Int32(0)).int16Value, 0)
        XCTAssertEqual(NSNumber(value: Int32(0)).int32Value, 0)
        XCTAssertEqual(NSNumber(value: Int32(0)).int64Value, 0)

        XCTAssertEqual(NSNumber(value: Int32(0)).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: Int32(0)).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: Int32(0)).uint32Value, 0)
        XCTAssertEqual(NSNumber(value: Int32(0)).uint64Value, 0)

        XCTAssertEqual(NSNumber(value: Int32(0)).intValue, 0)
        XCTAssertEqual(NSNumber(value: Int32(0)).uintValue, 0)

        XCTAssertEqual(NSNumber(value: Int32(0)).floatValue, 0)
        XCTAssertEqual(NSNumber(value: Int32(0)).doubleValue, 0)

        //------

        XCTAssertEqual(NSNumber(value: Int32.min).boolValue, true)

        XCTAssertEqual(NSNumber(value: Int32.min).int8Value, 0)
        XCTAssertEqual(NSNumber(value: Int32.min).int16Value, 0)
        XCTAssertEqual(NSNumber(value: Int32.min).int32Value, -2147483648)
        XCTAssertEqual(NSNumber(value: Int32.min).int64Value, -2147483648)

        XCTAssertEqual(NSNumber(value: Int32.min).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: Int32.min).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: Int32.min).uint32Value, 2147483648)
        XCTAssertEqual(NSNumber(value: Int32.min).uint64Value, 18446744071562067968)

        XCTAssertEqual(NSNumber(value: Int32.min).intValue, -2147483648)
        let uintSize = MemoryLayout<UInt>.size
        switch uintSize {
        case 4: XCTAssertEqual(NSNumber(value: Int32.min).uintValue, 2147483648)
        case 8:
#if arch(arm)
                break
#else
                XCTAssertEqual(NSNumber(value: Int32.min).uintValue, 18446744071562067968)
#endif
        default: XCTFail("Unexpected UInt size: \(uintSize)")
        }

        XCTAssertEqual(NSNumber(value: Int32.min).floatValue, Float(Int32.min))
        XCTAssertEqual(NSNumber(value: Int32.min).doubleValue, Double(Int32.min))

        //------

        XCTAssertEqual(NSNumber(value: Int32.max).boolValue, true)

        XCTAssertEqual(NSNumber(value: Int32.max).int8Value, -1)
        XCTAssertEqual(NSNumber(value: Int32.max).int16Value, -1)
        XCTAssertEqual(NSNumber(value: Int32.max).int32Value, 2147483647)
        XCTAssertEqual(NSNumber(value: Int32.max).int64Value, 2147483647)

        XCTAssertEqual(NSNumber(value: Int32.max).uint8Value, 255)
        XCTAssertEqual(NSNumber(value: Int32.max).uint16Value, 65535)
        XCTAssertEqual(NSNumber(value: Int32.max).uint32Value, 2147483647)
        XCTAssertEqual(NSNumber(value: Int32.max).uint64Value, 2147483647)

        XCTAssertEqual(NSNumber(value: Int32.max).intValue, 2147483647)
        XCTAssertEqual(NSNumber(value: Int32.max).uintValue, 2147483647)

        XCTAssertEqual(NSNumber(value: Int32.max).floatValue, Float(Int32.max))
        XCTAssertEqual(NSNumber(value: Int32.max).doubleValue, Double(Int32.max))
    }

    func test_numberWithUnsignedLong() {
        XCTAssertEqual(NSNumber(value: UInt32(0)).boolValue, false)

        XCTAssertEqual(NSNumber(value: UInt32(0)).int8Value, 0)
        XCTAssertEqual(NSNumber(value: UInt32(0)).int16Value, 0)
        XCTAssertEqual(NSNumber(value: UInt32(0)).int32Value, 0)
        XCTAssertEqual(NSNumber(value: UInt32(0)).int64Value, 0)

        XCTAssertEqual(NSNumber(value: UInt32(0)).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: UInt32(0)).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: UInt32(0)).uint32Value, 0)
        XCTAssertEqual(NSNumber(value: UInt32(0)).uint64Value, 0)

        XCTAssertEqual(NSNumber(value: UInt32(0)).intValue, 0)
        XCTAssertEqual(NSNumber(value: UInt32(0)).uintValue, 0)

        XCTAssertEqual(NSNumber(value: UInt32(0)).floatValue, 0.0)
        XCTAssertEqual(NSNumber(value: UInt32(0)).doubleValue, 0.0)

        //------

        XCTAssertEqual(NSNumber(value: UInt32.max).boolValue, true)

        XCTAssertEqual(NSNumber(value: UInt32.max).int8Value, -1)
        XCTAssertEqual(NSNumber(value: UInt32.max).int16Value, -1)
        XCTAssertEqual(NSNumber(value: UInt32.max).int32Value, -1)
        XCTAssertEqual(NSNumber(value: UInt32.max).int64Value, 4294967295)

        XCTAssertEqual(NSNumber(value: UInt32.max).uint8Value, 255)
        XCTAssertEqual(NSNumber(value: UInt32.max).uint16Value, 65535)
        XCTAssertEqual(NSNumber(value: UInt32.max).uint32Value, 4294967295)
        XCTAssertEqual(NSNumber(value: UInt32.max).uint64Value, 4294967295)

        let intSize = MemoryLayout<Int>.size
        switch intSize {
        case 4: XCTAssertEqual(NSNumber(value: UInt32.max).intValue, -1)
        case 8:
#if arch(arm)
                break
#else
                XCTAssertEqual(NSNumber(value: UInt32.max).intValue, 4294967295)
#endif
        default: XCTFail("Unexpected Int size: \(intSize)")
        }
        XCTAssertEqual(NSNumber(value: UInt32.max).uintValue, 4294967295)

        XCTAssertEqual(NSNumber(value: UInt32.max).floatValue, Float(UInt32.max))
        XCTAssertEqual(NSNumber(value: UInt32.max).doubleValue, Double(UInt32.max))
    }

    func test_numberWithLongLong() {
        XCTAssertEqual(NSNumber(value: Int64(0)).boolValue, false)

        XCTAssertEqual(NSNumber(value: Int64(0)).int8Value, 0)
        XCTAssertEqual(NSNumber(value: Int64(0)).int16Value, 0)
        XCTAssertEqual(NSNumber(value: Int64(0)).int32Value, 0)
        XCTAssertEqual(NSNumber(value: Int64(0)).int64Value, 0)

        XCTAssertEqual(NSNumber(value: Int64(0)).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: Int64(0)).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: Int64(0)).uint32Value, 0)
        XCTAssertEqual(NSNumber(value: Int64(0)).uint64Value, 0)

        XCTAssertEqual(NSNumber(value: Int64(0)).intValue, 0)
        XCTAssertEqual(NSNumber(value: Int64(0)).uintValue, 0)

        XCTAssertEqual(NSNumber(value: Int64(0)).floatValue, 0)
        XCTAssertEqual(NSNumber(value: Int64(0)).doubleValue, 0)

        //------

        XCTAssertEqual(NSNumber(value: Int64.min).boolValue, false)

        XCTAssertEqual(NSNumber(value: Int64.min).int8Value, 0)
        XCTAssertEqual(NSNumber(value: Int64.min).int16Value, 0)
        XCTAssertEqual(NSNumber(value: Int64.min).int32Value, 0)
        XCTAssertEqual(NSNumber(value: Int64.min).int64Value, -9223372036854775808)

        XCTAssertEqual(NSNumber(value: Int64.min).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: Int64.min).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: Int64.min).uint32Value, 0)
        XCTAssertEqual(NSNumber(value: Int64.min).uint64Value, 9223372036854775808)

        let intSize = MemoryLayout<Int>.size
        switch intSize {
        case 4: XCTAssertEqual(NSNumber(value: Int64.min).intValue, 0)
        case 8:
#if arch(arm)
                break
#else
                XCTAssertEqual(NSNumber(value: Int64.min).intValue, -9223372036854775808)
#endif
        default: XCTFail("Unexpected Int size: \(intSize)")
        }

        let uintSize = MemoryLayout<UInt>.size
        switch uintSize {
        case 4: XCTAssertEqual(NSNumber(value: Int64.min).uintValue, 0)
        case 8:
#if arch(arm)
                break
#else
                XCTAssertEqual(NSNumber(value: Int64.min).uintValue, 9223372036854775808)
#endif
        default: XCTFail("Unexpected UInt size: \(uintSize)")
        }

        XCTAssertEqual(NSNumber(value: Int64.min).floatValue, Float(Int64.min))
        XCTAssertEqual(NSNumber(value: Int64.min).doubleValue, Double(Int64.min))

        //------

        XCTAssertEqual(NSNumber(value: Int64.max).boolValue, true)

        XCTAssertEqual(NSNumber(value: Int64.max).int8Value, -1)
        XCTAssertEqual(NSNumber(value: Int64.max).int16Value, -1)
        XCTAssertEqual(NSNumber(value: Int64.max).int32Value, -1)
        XCTAssertEqual(NSNumber(value: Int64.max).int64Value, 9223372036854775807)

        XCTAssertEqual(NSNumber(value: Int64.max).uint8Value, 255)
        XCTAssertEqual(NSNumber(value: Int64.max).uint16Value, 65535)
        XCTAssertEqual(NSNumber(value: Int64.max).uint32Value, 4294967295)
        XCTAssertEqual(NSNumber(value: Int64.max).uint64Value, 9223372036854775807)

        switch intSize {
        case 4: XCTAssertEqual(NSNumber(value: Int64.max).intValue, -1)
        case 8:
#if arch(arm)
                break
#else
                XCTAssertEqual(NSNumber(value: Int64.max).intValue, 9223372036854775807)
#endif
        default: XCTFail("Unexpected Int size: \(intSize)")
        }

        switch uintSize {
        case 4: XCTAssertEqual(NSNumber(value: Int64.max).uintValue, 4294967295)
        case 8:
#if arch(arm)
                break
#else
                XCTAssertEqual(NSNumber(value: Int64.max).uintValue, 9223372036854775807)
#endif
        default: XCTFail("Unexpected UInt size: \(uintSize)")
        }

        XCTAssertEqual(NSNumber(value: Int64.max).floatValue, Float(Int64.max))
        XCTAssertEqual(NSNumber(value: Int64.max).doubleValue, Double(Int64.max))
    }

    func test_numberWithUnsignedLongLong() {
        XCTAssertEqual(NSNumber(value: UInt64(0)).boolValue, false)

        XCTAssertEqual(NSNumber(value: UInt64(0)).int8Value, 0)
        XCTAssertEqual(NSNumber(value: UInt64(0)).int16Value, 0)
        XCTAssertEqual(NSNumber(value: UInt64(0)).int32Value, 0)
        XCTAssertEqual(NSNumber(value: UInt64(0)).int64Value, 0)

        XCTAssertEqual(NSNumber(value: UInt64(0)).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: UInt64(0)).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: UInt64(0)).uint32Value, 0)
        XCTAssertEqual(NSNumber(value: UInt64(0)).uint64Value, 0)

        XCTAssertEqual(NSNumber(value: UInt64(0)).intValue, 0)
        XCTAssertEqual(NSNumber(value: UInt64(0)).uintValue, 0)

        XCTAssertEqual(NSNumber(value: UInt64(0)).floatValue, 0.0)
        XCTAssertEqual(NSNumber(value: UInt64(0)).doubleValue, 0.0)

        //------

        XCTAssertEqual(NSNumber(value: UInt64.max).boolValue, true)

        XCTAssertEqual(NSNumber(value: UInt64.max).int8Value, -1)
        XCTAssertEqual(NSNumber(value: UInt64.max).int16Value, -1)
        XCTAssertEqual(NSNumber(value: UInt64.max).int32Value, -1)
        XCTAssertEqual(NSNumber(value: UInt64.max).int64Value, -1)

        XCTAssertEqual(NSNumber(value: UInt64.max).uint8Value, 255)
        XCTAssertEqual(NSNumber(value: UInt64.max).uint16Value, 65535)
        XCTAssertEqual(NSNumber(value: UInt64.max).uint32Value, 4294967295)
        XCTAssertEqual(NSNumber(value: UInt64.max).uint64Value, 18446744073709551615)

        XCTAssertEqual(NSNumber(value: UInt64.max).intValue, -1)
        let uintSize = MemoryLayout<UInt>.size
        switch uintSize {
        case 4: XCTAssertEqual(NSNumber(value: UInt64.max).uintValue, 4294967295)
        case 8:
#if arch(arm)
                break
#else
                XCTAssertEqual(NSNumber(value: UInt64.max).uintValue, 18446744073709551615)
#endif
        default: XCTFail("Unexpected UInt size: \(uintSize)")
        }

        XCTAssertEqual(NSNumber(value: UInt64.max).floatValue, Float(UInt64.max))
        XCTAssertEqual(NSNumber(value: UInt64.max).doubleValue, Double(UInt64.max))
    }

    func test_numberWithInt() {
        XCTAssertEqual(NSNumber(value: Int(0)).boolValue, false)

        XCTAssertEqual(NSNumber(value: Int(0)).int8Value, 0)
        XCTAssertEqual(NSNumber(value: Int(0)).int16Value, 0)
        XCTAssertEqual(NSNumber(value: Int(0)).int32Value, 0)
        XCTAssertEqual(NSNumber(value: Int(0)).int64Value, 0)

        XCTAssertEqual(NSNumber(value: Int(0)).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: Int(0)).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: Int(0)).uint32Value, 0)
        XCTAssertEqual(NSNumber(value: Int(0)).uint64Value, 0)

        XCTAssertEqual(NSNumber(value: Int(0)).intValue, 0)
        XCTAssertEqual(NSNumber(value: Int(0)).uintValue, 0)

        XCTAssertEqual(NSNumber(value: Int(0)).floatValue, 0)
        XCTAssertEqual(NSNumber(value: Int(0)).doubleValue, 0)

        //------

        let intSize = MemoryLayout<Int>.size
        let uintSize = MemoryLayout<UInt>.size
        switch (intSize, uintSize) {
        case (4, 4):
            XCTAssertEqual(NSNumber(value: Int.min).boolValue, true)

            XCTAssertEqual(NSNumber(value: Int.min).int8Value, 0)
            XCTAssertEqual(NSNumber(value: Int.min).int16Value, 0)
            XCTAssertEqual(NSNumber(value: Int.min).int32Value, -2147483648)
            XCTAssertEqual(NSNumber(value: Int.min).int64Value, -2147483648)

            XCTAssertEqual(NSNumber(value: Int.min).uint8Value, 0)
            XCTAssertEqual(NSNumber(value: Int.min).uint16Value, 0)
            XCTAssertEqual(NSNumber(value: Int.min).uint32Value, 2147483648)
            XCTAssertEqual(NSNumber(value: Int.min).uint64Value, 18446744071562067968)

            XCTAssertEqual(NSNumber(value: Int.min).intValue, -2147483648)
#if !arch(arm)
            XCTAssertEqual(NSNumber(value: Int.min).uintValue, 18446744071562067968)
#endif
            XCTAssertEqual(NSNumber(value: Int.min).floatValue, Float(Int.min))
            XCTAssertEqual(NSNumber(value: Int.min).doubleValue, Double(Int.min))

            //--------

            XCTAssertEqual(NSNumber(value: Int.max).boolValue, true)

            XCTAssertEqual(NSNumber(value: Int.max).int8Value, -1)
            XCTAssertEqual(NSNumber(value: Int.max).int16Value, -1)
            XCTAssertEqual(NSNumber(value: Int.max).int32Value, 2147483647)
            XCTAssertEqual(NSNumber(value: Int.max).int64Value, 2147483647)

            XCTAssertEqual(NSNumber(value: Int.max).uint8Value, 255)
            XCTAssertEqual(NSNumber(value: Int.max).uint16Value, 65535)
            XCTAssertEqual(NSNumber(value: Int.max).uint32Value, 2147483647)
            XCTAssertEqual(NSNumber(value: Int.max).uint64Value, 2147483647)

            XCTAssertEqual(NSNumber(value: Int.max).intValue, 2147483647)
            XCTAssertEqual(NSNumber(value: Int.max).uintValue, 2147483647)

            XCTAssertEqual(NSNumber(value: Int.max).floatValue, Float(Int.max))
            XCTAssertEqual(NSNumber(value: Int.max).doubleValue, Double(Int.max))

        case (8, 8):
#if arch(arm)
            break
#else
            XCTAssertEqual(NSNumber(value: Int.min).boolValue, false)

            XCTAssertEqual(NSNumber(value: Int.min).int8Value, 0)
            XCTAssertEqual(NSNumber(value: Int.min).int16Value, 0)
            XCTAssertEqual(NSNumber(value: Int.min).int32Value, 0)
            XCTAssertEqual(NSNumber(value: Int.min).int64Value, -9223372036854775808)

            XCTAssertEqual(NSNumber(value: Int.min).uint8Value, 0)
            XCTAssertEqual(NSNumber(value: Int.min).uint16Value, 0)
            XCTAssertEqual(NSNumber(value: Int.min).uint32Value, 0)
            XCTAssertEqual(NSNumber(value: Int.min).uint64Value, 9223372036854775808)

            XCTAssertEqual(NSNumber(value: Int.min).intValue, -9223372036854775808)
            XCTAssertEqual(NSNumber(value: Int.min).uintValue, 9223372036854775808)

            XCTAssertEqual(NSNumber(value: Int.min).floatValue, Float(Int.min))
            XCTAssertEqual(NSNumber(value: Int.min).doubleValue, Double(Int.min))

            //--------

            XCTAssertEqual(NSNumber(value: Int.max).boolValue, true)

            XCTAssertEqual(NSNumber(value: Int.max).int8Value, -1)
            XCTAssertEqual(NSNumber(value: Int.max).int16Value, -1)
            XCTAssertEqual(NSNumber(value: Int.max).int32Value, -1)
            XCTAssertEqual(NSNumber(value: Int.max).int64Value, 9223372036854775807)

            XCTAssertEqual(NSNumber(value: Int.max).uint8Value, 255)
            XCTAssertEqual(NSNumber(value: Int.max).uint16Value, 65535)
            XCTAssertEqual(NSNumber(value: Int.max).uint32Value, 4294967295)
            XCTAssertEqual(NSNumber(value: Int.max).uint64Value, 9223372036854775807)

            XCTAssertEqual(NSNumber(value: Int.max).intValue, 9223372036854775807)
            XCTAssertEqual(NSNumber(value: Int.max).uintValue, 9223372036854775807)

            XCTAssertEqual(NSNumber(value: Int.max).floatValue, Float(Int.max))
            XCTAssertEqual(NSNumber(value: Int.max).doubleValue, Double(Int.max))
#endif
        default: XCTFail("Unexpected mismatched Int & UInt sizes: \(intSize) & \(uintSize)")
        }
    }

    func test_numberWithUInt() {
        XCTAssertEqual(NSNumber(value: UInt(0)).boolValue, false)

        XCTAssertEqual(NSNumber(value: UInt(0)).int8Value, 0)
        XCTAssertEqual(NSNumber(value: UInt(0)).int16Value, 0)
        XCTAssertEqual(NSNumber(value: UInt(0)).int32Value, 0)
        XCTAssertEqual(NSNumber(value: UInt(0)).int64Value, 0)

        XCTAssertEqual(NSNumber(value: UInt(0)).uint8Value, 0)
        XCTAssertEqual(NSNumber(value: UInt(0)).uint16Value, 0)
        XCTAssertEqual(NSNumber(value: UInt(0)).uint32Value, 0)
        XCTAssertEqual(NSNumber(value: UInt(0)).uint64Value, 0)

        XCTAssertEqual(NSNumber(value: UInt(0)).intValue, 0)
        XCTAssertEqual(NSNumber(value: UInt(0)).uintValue, 0)

        XCTAssertEqual(NSNumber(value: UInt(0)).floatValue, 0)
        XCTAssertEqual(NSNumber(value: UInt(0)).doubleValue, 0)

        //------

        let intSize = MemoryLayout<Int>.size
        let uintSize = MemoryLayout<UInt>.size
        switch (intSize, uintSize) {
        case (4, 4):
            XCTAssertEqual(NSNumber(value: UInt.max).boolValue, true)

            XCTAssertEqual(NSNumber(value: UInt.max).int8Value, -1)
            XCTAssertEqual(NSNumber(value: UInt.max).int16Value, -1)
            XCTAssertEqual(NSNumber(value: UInt.max).int32Value, -1)
            XCTAssertEqual(NSNumber(value: UInt.max).int64Value, 4294967295)

            XCTAssertEqual(NSNumber(value: UInt.max).uint8Value, 255)
            XCTAssertEqual(NSNumber(value: UInt.max).uint16Value, 65535)
            XCTAssertEqual(NSNumber(value: UInt.max).uint32Value, 4294967295)
            XCTAssertEqual(NSNumber(value: UInt.max).uint64Value, 4294967295)

#if !arch(arm)
            XCTAssertEqual(NSNumber(value: UInt.max).intValue, 4294967295)
#endif
            XCTAssertEqual(NSNumber(value: UInt.max).uintValue, 4294967295)

            XCTAssertEqual(NSNumber(value: UInt.max).floatValue, Float(UInt.max))
            XCTAssertEqual(NSNumber(value: UInt.max).doubleValue, Double(UInt.max))

        case (8, 8):
            XCTAssertEqual(NSNumber(value: UInt.max).boolValue, true)

            XCTAssertEqual(NSNumber(value: UInt.max).int8Value, -1)
            XCTAssertEqual(NSNumber(value: UInt.max).int16Value, -1)
            XCTAssertEqual(NSNumber(value: UInt.max).int32Value, -1)
            XCTAssertEqual(NSNumber(value: UInt.max).int64Value, -1)

            XCTAssertEqual(NSNumber(value: UInt.max).uint8Value, 255)
            XCTAssertEqual(NSNumber(value: UInt.max).uint16Value, 65535)
            XCTAssertEqual(NSNumber(value: UInt.max).uint32Value, 4294967295)
            XCTAssertEqual(NSNumber(value: UInt.max).uint64Value, 18446744073709551615)

            XCTAssertEqual(NSNumber(value: UInt.max).intValue, -1)
#if !arch(arm)
            XCTAssertEqual(NSNumber(value: UInt.max).uintValue, 18446744073709551615)
#endif

            XCTAssertEqual(NSNumber(value: UInt.max).floatValue, Float(UInt.max))
            XCTAssertEqual(NSNumber(value: UInt.max).doubleValue, Double(UInt.max))
            
        default: XCTFail("Unexpected mismatched Int & UInt sizes: \(intSize) & \(uintSize)")
        }
    }

    func test_numberWithFloat() {
        XCTAssertEqual(NSNumber(value: Float(0)).boolValue, false)
        XCTAssertEqual(NSNumber(value: Float(0)).int8Value, Int8(0))
        XCTAssertEqual(NSNumber(value: Float(0)).uint8Value, UInt8(0))
        XCTAssertEqual(NSNumber(value: Float(0)).int16Value, Int16(0))
        XCTAssertEqual(NSNumber(value: Float(0)).uint16Value, UInt16(0))
        XCTAssertEqual(NSNumber(value: Float(0)).int32Value, Int32(0))
        XCTAssertEqual(NSNumber(value: Float(0)).uint32Value, UInt32(0))
        XCTAssertEqual(NSNumber(value: Float(0)).int64Value, Int64(0))
        XCTAssertEqual(NSNumber(value: Float(0)).uint64Value, UInt64(0))
        XCTAssertEqual(NSNumber(value: Float(1)).boolValue, true)
        XCTAssertEqual(NSNumber(value: Float(1)).int8Value, Int8(1))
        XCTAssertEqual(NSNumber(value: Float(1)).uint8Value, UInt8(1))
        XCTAssertEqual(NSNumber(value: Float(1)).int16Value, Int16(1))
        XCTAssertEqual(NSNumber(value: Float(1)).uint16Value, UInt16(1))
        XCTAssertEqual(NSNumber(value: Float(1)).int32Value, Int32(1))
        XCTAssertEqual(NSNumber(value: Float(1)).uint32Value, UInt32(1))
        XCTAssertEqual(NSNumber(value: Float(1)).int64Value, Int64(1))
        XCTAssertEqual(NSNumber(value: Float(1)).uint64Value, UInt64(1))
        XCTAssertEqual(NSNumber(value: Float(-37)).boolValue, true)
        XCTAssertEqual(NSNumber(value: Float(-37)).int8Value, Int8(-37))
        XCTAssertEqual(NSNumber(value: Float(-37)).int16Value, Int16(-37))
        XCTAssertEqual(NSNumber(value: Float(-37)).int32Value, Int32(-37))
        XCTAssertEqual(NSNumber(value: Float(-37)).int64Value, Int64(-37))
        XCTAssertEqual(NSNumber(value: Float(42)).boolValue, true)
        XCTAssertEqual(NSNumber(value: Float(42)).int8Value, Int8(42))
        XCTAssertEqual(NSNumber(value: Float(42)).uint8Value, UInt8(42))
        XCTAssertEqual(NSNumber(value: Float(42)).int16Value, Int16(42))
        XCTAssertEqual(NSNumber(value: Float(42)).uint16Value, UInt16(42))
        XCTAssertEqual(NSNumber(value: Float(42)).int32Value, Int32(42))
        XCTAssertEqual(NSNumber(value: Float(42)).uint32Value, UInt32(42))
        XCTAssertEqual(NSNumber(value: Float(42)).int64Value, Int64(42))
        XCTAssertEqual(NSNumber(value: Float(42)).uint64Value, UInt64(42))
        XCTAssertEqual(NSNumber(value: Float(0)).floatValue, Float(0))
        XCTAssertEqual(NSNumber(value: Float(1)).floatValue, Float(1))
        XCTAssertEqual(NSNumber(value: Float(-37.5)).floatValue, Float(-37.5))
        XCTAssertEqual(NSNumber(value: Float(42.1)).floatValue, Float(42.1))
        XCTAssertEqual(NSNumber(value: Float(0)).doubleValue, Double(0))
        XCTAssertEqual(NSNumber(value: Float(1)).doubleValue, Double(1))
        XCTAssertEqual(NSNumber(value: Float(-37.5)).doubleValue, Double(-37.5))
        XCTAssertEqual(NSNumber(value: Float(42.5)).doubleValue, Double(42.5))
    }
    
    func test_numberWithDouble() {
        XCTAssertEqual(NSNumber(value: Double(0)).boolValue, false)
        XCTAssertEqual(NSNumber(value: Double(0)).int8Value, Int8(0))
        XCTAssertEqual(NSNumber(value: Double(0)).uint8Value, UInt8(0))
        XCTAssertEqual(NSNumber(value: Double(0)).int16Value, Int16(0))
        XCTAssertEqual(NSNumber(value: Double(0)).uint16Value, UInt16(0))
        XCTAssertEqual(NSNumber(value: Double(0)).int32Value, Int32(0))
        XCTAssertEqual(NSNumber(value: Double(0)).uint32Value, UInt32(0))
        XCTAssertEqual(NSNumber(value: Double(0)).int64Value, Int64(0))
        XCTAssertEqual(NSNumber(value: Double(0)).uint64Value, UInt64(0))
        XCTAssertEqual(NSNumber(value: Double(-37)).boolValue, true)
        XCTAssertEqual(NSNumber(value: Double(-37)).int8Value, Int8(-37))
        XCTAssertEqual(NSNumber(value: Double(-37)).int16Value, Int16(-37))
        XCTAssertEqual(NSNumber(value: Double(-37)).int32Value, Int32(-37))
        XCTAssertEqual(NSNumber(value: Double(-37)).int64Value, Int64(-37))
        XCTAssertEqual(NSNumber(value: Double(42)).boolValue, true)
        XCTAssertEqual(NSNumber(value: Double(42)).int8Value, Int8(42))
        XCTAssertEqual(NSNumber(value: Double(42)).uint8Value, UInt8(42))
        XCTAssertEqual(NSNumber(value: Double(42)).int16Value, Int16(42))
        XCTAssertEqual(NSNumber(value: Double(42)).uint16Value, UInt16(42))
        XCTAssertEqual(NSNumber(value: Double(42)).int32Value, Int32(42))
        XCTAssertEqual(NSNumber(value: Double(42)).uint32Value, UInt32(42))
        XCTAssertEqual(NSNumber(value: Double(42)).int64Value, Int64(42))
        XCTAssertEqual(NSNumber(value: Double(42)).uint64Value, UInt64(42))
        XCTAssertEqual(NSNumber(value: Double(0)).floatValue, Float(0))
        XCTAssertEqual(NSNumber(value: Double(-37.5)).floatValue, Float(-37.5))
        XCTAssertEqual(NSNumber(value: Double(42.1)).floatValue, Float(42.1))
        XCTAssertEqual(NSNumber(value: Double(0)).doubleValue, Double(0))
        XCTAssertEqual(NSNumber(value: Double(-37.5)).doubleValue, Double(-37.5))
        XCTAssertEqual(NSNumber(value: Double(42.1)).doubleValue, Double(42.1))
    }

    func test_compareNumberWithBool() {
        XCTAssertEqual(NSNumber(value: true).compare(NSNumber(value: true)), .orderedSame)
        XCTAssertEqual(NSNumber(value: true).compare(NSNumber(value: false)), .orderedDescending)
        XCTAssertEqual(NSNumber(value: false).compare(NSNumber(value: true)), .orderedAscending)

        XCTAssertEqual(NSNumber(value: false).compare(NSNumber(value: Int8(0))), .orderedSame)
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: false).compare(NSNumber(value: Int8(-1))), .orderedDescending)
#endif
        XCTAssertEqual(NSNumber(value: false).compare(NSNumber(value: Int8(1))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: true).compare(NSNumber(value: Int8(1))), .orderedSame)
        XCTAssertEqual(NSNumber(value: true).compare(NSNumber(value: Int8(0))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: true).compare(NSNumber(value: Int8(2))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: false).compare(NSNumber(value: Double(0))), .orderedSame)
        XCTAssertEqual(NSNumber(value: false).compare(NSNumber(value: Double(-0.1))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: false).compare(NSNumber(value: Double(0.1))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: true).compare(NSNumber(value: Double(1))), .orderedSame)
        XCTAssertEqual(NSNumber(value: true).compare(NSNumber(value: Double(0.9))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: true).compare(NSNumber(value: Double(1.1))), .orderedAscending)
    }

    func test_compareNumberWithChar() {
        XCTAssertEqual(NSNumber(value: Int8(42)).compare(NSNumber(value: Int8(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Int8(42)).compare(NSNumber(value: Int8(0))), .orderedDescending)
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: Int8(-37)).compare(NSNumber(value: Int8(16))), .orderedAscending)
#endif

        XCTAssertEqual(NSNumber(value: Int8(1)).compare(NSNumber(value: true)), .orderedSame)
        XCTAssertEqual(NSNumber(value: Int8(1)).compare(NSNumber(value: false)), .orderedDescending)
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: Int8(-37)).compare(NSNumber(value: true)), .orderedAscending)
#endif

        XCTAssertEqual(NSNumber(value: Int8(42)).compare(NSNumber(value: UInt8(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Int8(42)).compare(NSNumber(value: UInt8(16))), .orderedDescending)
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: Int8(-37)).compare(NSNumber(value: UInt8(255))), .orderedAscending)
#endif

        XCTAssertEqual(NSNumber(value: Int8(42)).compare(NSNumber(value: Float(42))), .orderedSame)
#if !(os(Linux) && (arch(arm) || arch(powerpc64) || arch(powerpc64le)))
        // Linux/arm and Linux/power chars are unsigned, so Int8 in Swift, until this issue is resolved, these tests will always fail.
        XCTAssertEqual(NSNumber(value: Int8(-16)).compare(NSNumber(value: Float(-37.5))), .orderedDescending)
#endif
        XCTAssertEqual(NSNumber(value: Int8(16)).compare(NSNumber(value: Float(16.1))), .orderedAscending)
    }

    func test_compareNumberWithUnsignedChar() {
        XCTAssertEqual(NSNumber(value: UInt8(42)).compare(NSNumber(value: UInt8(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: UInt8(42)).compare(NSNumber(value: UInt8(0))), .orderedDescending)
//        XCTAssertEqual(NSNumber(value: UInt8(42)).compare(NSNumber(value: UInt8(255))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: UInt8(1)).compare(NSNumber(value: true)), .orderedSame)
        XCTAssertEqual(NSNumber(value: UInt8(1)).compare(NSNumber(value: false)), .orderedDescending)
        XCTAssertEqual(NSNumber(value: UInt8(0)).compare(NSNumber(value: true)), .orderedAscending)

        XCTAssertEqual(NSNumber(value: UInt8(42)).compare(NSNumber(value: Int16(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: UInt8(0)).compare(NSNumber(value: Int16(-123))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: UInt8(255)).compare(NSNumber(value: Int16(12345))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: UInt8(42)).compare(NSNumber(value: Float(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: UInt8(0)).compare(NSNumber(value: Float(-37.5))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: UInt8(255)).compare(NSNumber(value: Float(1234.5))), .orderedAscending)
    }

    func test_compareNumberWithShort() {
        XCTAssertEqual(NSNumber(value: Int16(42)).compare(NSNumber(value: Int16(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Int16(42)).compare(NSNumber(value: Int16(0))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Int16(-37)).compare(NSNumber(value: Int16(12345))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: Int16(1)).compare(NSNumber(value: true)), .orderedSame)
        XCTAssertEqual(NSNumber(value: Int16(1)).compare(NSNumber(value: false)), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Int16(0)).compare(NSNumber(value: true)), .orderedAscending)

        XCTAssertEqual(NSNumber(value: Int16(42)).compare(NSNumber(value: UInt8(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Int16(42)).compare(NSNumber(value: UInt8(0))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Int16(-37)).compare(NSNumber(value: UInt8(255))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: Int16(42)).compare(NSNumber(value: Float(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Int16(0)).compare(NSNumber(value: Float(-37.5))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Int16(255)).compare(NSNumber(value: Float(1234.5))), .orderedAscending)
    }

    func test_compareNumberWithFloat() {
        XCTAssertEqual(NSNumber(value: Float(42)).compare(NSNumber(value: Float(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Float(42)).compare(NSNumber(value: Float(0))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Float(-37)).compare(NSNumber(value: Float(12345))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: Float(1)).compare(NSNumber(value: true)), .orderedSame)
        XCTAssertEqual(NSNumber(value: Float(0.1)).compare(NSNumber(value: false)), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Float(0.9)).compare(NSNumber(value: true)), .orderedAscending)

        XCTAssertEqual(NSNumber(value: Float(42)).compare(NSNumber(value: UInt8(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Float(0.1)).compare(NSNumber(value: UInt8(0))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Float(-254.9)).compare(NSNumber(value: UInt8(255))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: Float(42)).compare(NSNumber(value: Double(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Float(0)).compare(NSNumber(value: Double(-37.5))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Float(-37.5)).compare(NSNumber(value: Double(1234.5))), .orderedAscending)
    }

    func test_compareNumberWithDouble() {
        XCTAssertEqual(NSNumber(value: Double(42)).compare(NSNumber(value: Double(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Double(42)).compare(NSNumber(value: Double(0))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Double(-37)).compare(NSNumber(value: Double(12345))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: Double(1)).compare(NSNumber(value: true)), .orderedSame)
        XCTAssertEqual(NSNumber(value: Double(0.1)).compare(NSNumber(value: false)), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Double(0.9)).compare(NSNumber(value: true)), .orderedAscending)

        XCTAssertEqual(NSNumber(value: Double(42)).compare(NSNumber(value: UInt8(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Double(0.1)).compare(NSNumber(value: UInt8(0))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Double(-254.9)).compare(NSNumber(value: UInt8(255))), .orderedAscending)

        XCTAssertEqual(NSNumber(value: Double(42)).compare(NSNumber(value: Float(42))), .orderedSame)
        XCTAssertEqual(NSNumber(value: Double(0)).compare(NSNumber(value: Float(-37.5))), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Double(-37.5)).compare(NSNumber(value: Float(1234.5))), .orderedAscending)
    }

    
    func test_description() {
        let nsnumber: NSNumber = 1000
        let expectedDesc = "1000"
        XCTAssertEqual(nsnumber.description, expectedDesc, "expected \(expectedDesc) but received \(nsnumber.description)")
    }
    
    func test_descriptionWithLocale() {
        let nsnumber: NSNumber = 1000
        let values : Dictionary = [
                Locale(identifier: "en_GB") : "1,000",
                Locale(identifier: "de_DE") : "1.000",
        ]
        for (locale, expectedDesc) in values {
            let receivedDesc = nsnumber.description(withLocale: locale)
            XCTAssertEqual(receivedDesc, expectedDesc, "expected \(expectedDesc) but received \(receivedDesc)")
        }
    }

    func test_objCType() {
        let objCType: (NSNumber) -> UnicodeScalar = { number in
            return UnicodeScalar(UInt8(number.objCType.pointee))
        }

        XCTAssertEqual("c" /* 0x63 */, objCType(NSNumber(value: true)))

        XCTAssertEqual("c" /* 0x63 */, objCType(NSNumber(value: Int8.max)))
        XCTAssertEqual("s" /* 0x73 */, objCType(NSNumber(value: UInt8(Int8.max))))
        XCTAssertEqual("s" /* 0x73 */, objCType(NSNumber(value: UInt8(Int8.max) + 1)))

        XCTAssertEqual("s" /* 0x73 */, objCType(NSNumber(value: Int16.max)))
        XCTAssertEqual("i" /* 0x69 */, objCType(NSNumber(value: UInt16(Int16.max))))
        XCTAssertEqual("i" /* 0x69 */, objCType(NSNumber(value: UInt16(Int16.max) + 1)))

        XCTAssertEqual("i" /* 0x69 */, objCType(NSNumber(value: Int32.max)))
        XCTAssertEqual("q" /* 0x71 */, objCType(NSNumber(value: UInt32(Int32.max))))
        XCTAssertEqual("q" /* 0x71 */, objCType(NSNumber(value: UInt32(Int32.max) + 1)))

        XCTAssertEqual("q" /* 0x71 */, objCType(NSNumber(value: Int64.max)))
        // When value is lower equal to `Int64.max`, it returns 'q' even if using `UInt64`
        XCTAssertEqual("q" /* 0x71 */, objCType(NSNumber(value: UInt64(Int64.max))))
        XCTAssertEqual("Q" /* 0x51 */, objCType(NSNumber(value: UInt64(Int64.max) + 1)))

        // Depends on architectures
        #if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
            XCTAssertEqual("q" /* 0x71 */, objCType(NSNumber(value: Int.max)))
            // When value is lower equal to `Int.max`, it returns 'q' even if using `UInt`
            XCTAssertEqual("q" /* 0x71 */, objCType(NSNumber(value: UInt(Int.max))))
            XCTAssertEqual("Q" /* 0x51 */, objCType(NSNumber(value: UInt(Int.max) + 1)))
        #elseif arch(i386) || arch(arm)
            XCTAssertEqual("i" /* 0x71 */, objCType(NSNumber(value: Int.max)))
            XCTAssertEqual("q" /* 0x71 */, objCType(NSNumber(value: UInt(Int.max))))
            XCTAssertEqual("q" /* 0x51 */, objCType(NSNumber(value: UInt(Int.max) + 1)))
        #endif

        XCTAssertEqual("f" /* 0x66 */, objCType(NSNumber(value: Float.greatestFiniteMagnitude)))
        XCTAssertEqual("d" /* 0x64 */, objCType(NSNumber(value: Double.greatestFiniteMagnitude)))
    }

    func test_stringValue() {

        // The following casts on subtraction are required for an Android compile
        // https://bugs.swift.org/browse/SR-7469

        if UInt.max == UInt32.max {
            XCTAssertEqual(NSNumber(value: UInt.min).stringValue, "0")
            XCTAssertEqual(NSNumber(value: UInt.min + 1).stringValue, "1")
            XCTAssertEqual(NSNumber(value: UInt.max).stringValue, "4294967295")
            XCTAssertEqual(NSNumber(value: UInt.max - 1 as UInt).stringValue, "4294967294")
        } else if UInt.max == UInt64.max {
            XCTAssertEqual(NSNumber(value: UInt.min).stringValue, "0")
            XCTAssertEqual(NSNumber(value: UInt.min + 1).stringValue, "1")
            XCTAssertEqual(NSNumber(value: UInt.max).stringValue, "18446744073709551615")
            XCTAssertEqual(NSNumber(value: UInt.max - 1 as UInt).stringValue, "18446744073709551614")
        }

        XCTAssertEqual(NSNumber(value: UInt8.min).stringValue, "0")
        XCTAssertEqual(NSNumber(value: UInt8.min + 1).stringValue, "1")
        XCTAssertEqual(NSNumber(value: UInt8.max).stringValue, "255")
        XCTAssertEqual(NSNumber(value: UInt8.max - 1 as UInt8).stringValue, "254")

        XCTAssertEqual(NSNumber(value: UInt16.min).stringValue, "0")
        XCTAssertEqual(NSNumber(value: UInt16.min + 1).stringValue, "1")
        XCTAssertEqual(NSNumber(value: UInt16.max).stringValue, "65535")
        XCTAssertEqual(NSNumber(value: UInt16.max - 1 as UInt16).stringValue, "65534")

        XCTAssertEqual(NSNumber(value: UInt32.min).stringValue, "0")
        XCTAssertEqual(NSNumber(value: UInt32.min + 1).stringValue, "1")
        XCTAssertEqual(NSNumber(value: UInt32.max).stringValue, "4294967295")
        XCTAssertEqual(NSNumber(value: UInt32.max - 1 as UInt32).stringValue, "4294967294")

        XCTAssertEqual(NSNumber(value: UInt64.min).stringValue, "0")
        XCTAssertEqual(NSNumber(value: UInt64.min + 1).stringValue, "1")
        XCTAssertEqual(NSNumber(value: UInt64.max).stringValue, "18446744073709551615")
        XCTAssertEqual(NSNumber(value: UInt64.max - 1 as UInt64).stringValue, "18446744073709551614")

        if Int.max == Int32.max {
            XCTAssertEqual(NSNumber(value: Int.min).stringValue, "-2147483648")
            XCTAssertEqual(NSNumber(value: Int.min + 1).stringValue, "-2147483647")
            XCTAssertEqual(NSNumber(value: Int.max).stringValue, "2147483647")
            XCTAssertEqual(NSNumber(value: Int.max - 1).stringValue, "2147483646")
        } else if Int.max == Int64.max {
            XCTAssertEqual(NSNumber(value: Int.min).stringValue, "-9223372036854775808")
            XCTAssertEqual(NSNumber(value: Int.min + 1).stringValue, "-9223372036854775807")
            XCTAssertEqual(NSNumber(value: Int.max).stringValue, "9223372036854775807")
            XCTAssertEqual(NSNumber(value: Int.max - 1).stringValue, "9223372036854775806")
        }

        XCTAssertEqual(NSNumber(value: Int8.min).stringValue, "-128")
        XCTAssertEqual(NSNumber(value: Int8.min + 1).stringValue, "-127")
        XCTAssertEqual(NSNumber(value: Int8.max).stringValue, "127")
        XCTAssertEqual(NSNumber(value: Int8.max - 1).stringValue, "126")

        XCTAssertEqual(NSNumber(value: Int16.min).stringValue, "-32768")
        XCTAssertEqual(NSNumber(value: Int16.min + 1).stringValue, "-32767")
        XCTAssertEqual(NSNumber(value: Int16.max).stringValue, "32767")
        XCTAssertEqual(NSNumber(value: Int16.max - 1).stringValue, "32766")

        XCTAssertEqual(NSNumber(value: Int32.min).stringValue, "-2147483648")
        XCTAssertEqual(NSNumber(value: Int32.min + 1).stringValue, "-2147483647")
        XCTAssertEqual(NSNumber(value: Int32.max).stringValue, "2147483647")
        XCTAssertEqual(NSNumber(value: Int32.max - 1).stringValue, "2147483646")

        XCTAssertEqual(NSNumber(value: Int64.min).stringValue, "-9223372036854775808")
        XCTAssertEqual(NSNumber(value: Int64.min + 1).stringValue, "-9223372036854775807")
        XCTAssertEqual(NSNumber(value: Int64.max).stringValue, "9223372036854775807")
        XCTAssertEqual(NSNumber(value: Int64.max - 1).stringValue, "9223372036854775806")
    }

    func test_Equals() {
        // Booleans: false only equals 0, true only equals 1
        XCTAssertTrue(NSNumber(value: true) == NSNumber(value: Bool(true)))
        XCTAssertTrue(NSNumber(value: true) == NSNumber(value: Int(1)))
        XCTAssertTrue(NSNumber(value: true) == NSNumber(value: Float(1)))
        XCTAssertTrue(NSNumber(value: true) == NSNumber(value: Double(1)))
        XCTAssertTrue(NSNumber(value: true) == NSNumber(value: Int8(1)))
        XCTAssertTrue(NSNumber(value: true) != NSNumber(value: false))
        XCTAssertTrue(NSNumber(value: true) != NSNumber(value: Int8(-1)))
        let f: Float = 1.01
        let floatNum = NSNumber(value: f)
        XCTAssertTrue(NSNumber(value: true) != floatNum)
        let d: Double = 1234.56
        let doubleNum = NSNumber(value: d)
        XCTAssertTrue(NSNumber(value: true) != doubleNum)
        XCTAssertTrue(NSNumber(value: true) != NSNumber(value: 2))
        XCTAssertTrue(NSNumber(value: true) != NSNumber(value: Int.max))
        XCTAssertTrue(NSNumber(value: false) == NSNumber(value: Bool(false)))
        XCTAssertTrue(NSNumber(value: false) == NSNumber(value: Int(0)))
        XCTAssertTrue(NSNumber(value: false) == NSNumber(value: Float(0)))
        XCTAssertTrue(NSNumber(value: false) == NSNumber(value: Double(0)))
        XCTAssertTrue(NSNumber(value: false) == NSNumber(value: Int8(0)))
        XCTAssertTrue(NSNumber(value: false) == NSNumber(value: UInt64(0)))
        XCTAssertTrue(NSNumber(value: false) != NSNumber(value: 1))
        XCTAssertTrue(NSNumber(value: false) != NSNumber(value: 2))
        XCTAssertTrue(NSNumber(value: false) != NSNumber(value: Int.max))

        XCTAssertTrue(NSNumber(value: Int8(-1)) == NSNumber(value: Int16(-1)))
        XCTAssertTrue(NSNumber(value: Int16(-1)) == NSNumber(value: Int32(-1)))
        XCTAssertTrue(NSNumber(value: Int32(-1)) == NSNumber(value: Int64(-1)))
        XCTAssertTrue(NSNumber(value: Int8.max) != NSNumber(value: Int16.max))
        XCTAssertTrue(NSNumber(value: Int16.max) != NSNumber(value: Int32.max))
        XCTAssertTrue(NSNumber(value: Int32.max) != NSNumber(value: Int64.max))
        XCTAssertTrue(NSNumber(value: UInt8.min) == NSNumber(value: UInt16.min))
        XCTAssertTrue(NSNumber(value: UInt16.min) == NSNumber(value: UInt32.min))
        XCTAssertTrue(NSNumber(value: UInt32.min) == NSNumber(value: UInt64.min))
        XCTAssertTrue(NSNumber(value: UInt8.max) != NSNumber(value: UInt16.max))
        XCTAssertTrue(NSNumber(value: UInt16.max) != NSNumber(value: UInt32.max))
        XCTAssertTrue(NSNumber(value: UInt32.max) != NSNumber(value: UInt64.max))
        XCTAssertTrue(NSNumber(value: Int8(0)) == NSNumber(value: UInt16(0)))
        XCTAssertTrue(NSNumber(value: UInt16(0)) == NSNumber(value: Int32(0)))
        XCTAssertTrue(NSNumber(value: Int32(0)) == NSNumber(value: UInt64(0)))
        XCTAssertTrue(NSNumber(value: Int(0)) == NSNumber(value: UInt(0)))
        XCTAssertTrue(NSNumber(value: Int8.min) == NSNumber(value: Float(-128)))
        XCTAssertTrue(NSNumber(value: Int8.max) == NSNumber(value: Double(127)))
        XCTAssertTrue(NSNumber(value: UInt16.min) == NSNumber(value: Float(0)))
        XCTAssertTrue(NSNumber(value: UInt16.max) == NSNumber(value: Double(65535)))
        XCTAssertTrue(NSNumber(value: 1.1) != NSNumber(value: Int64(1)))
        let num = NSNumber(value: Int8.min)
        XCTAssertFalse(num == NSNumber(value: num.uint64Value))

        let num1 = NSNumber(value: Float.nan)
        XCTAssertEqual(num1.compare(num1), .orderedSame)

        let num2 = NSNumber(value: num1.uint8Value) // 0
        XCTAssertFalse(num1 == num2)
        XCTAssertFalse(num2 == num1)
        XCTAssertEqual(num1.compare(num2), .orderedAscending)
        XCTAssertEqual(num2.compare(num1), .orderedDescending)

        let num3 = NSNumber(value: Double.nan)
        XCTAssertEqual(num3.compare(num3), .orderedSame)

        let num4 = NSNumber(value: num3.intValue) // 0
        XCTAssertFalse(num3 == num2)
        XCTAssertFalse(num4 == num3)
        XCTAssertEqual(num3.compare(num4), .orderedAscending)
        XCTAssertEqual(num4.compare(num3), .orderedDescending)

        XCTAssertEqual(NSNumber(value: Double.leastNonzeroMagnitude).compare(NSNumber(value: 0)), .orderedDescending)
        XCTAssertEqual(NSNumber(value: Double.greatestFiniteMagnitude).compare(NSNumber(value: 0)), .orderedDescending)
        XCTAssertTrue(NSNumber(value: Double(-0.0)) == NSNumber(value: Double(0.0)))
    }

    func test_boolValue() {
        XCTAssertEqual(NSNumber(value: UInt8.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: UInt8.min).boolValue, false)

        XCTAssertEqual(NSNumber(value: UInt16.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: UInt16.min).boolValue, false)

        XCTAssertEqual(NSNumber(value: UInt32.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: UInt32.min).boolValue, false)

        XCTAssertEqual(NSNumber(value: UInt64.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: UInt64.min).boolValue, false)

        XCTAssertEqual(NSNumber(value: UInt.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: UInt.min).boolValue, false)

        XCTAssertEqual(NSNumber(value: Int8.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int8.max - 1).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int8.min).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int8.min + 1).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int8(-1)).boolValue, true)

        XCTAssertEqual(NSNumber(value: Int16.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int16.max - 1).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int16.min).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int16.min + 1).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int16(-1)).boolValue, true)

        XCTAssertEqual(NSNumber(value: Int32.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int32.max - 1).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int32.min).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int32.min + 1).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int32(-1)).boolValue, true)

        XCTAssertEqual(NSNumber(value: Int64.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int64.max - 1).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int64.min).boolValue, false) // Darwin compatibility
        XCTAssertEqual(NSNumber(value: Int64.min + 1).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int64(-1)).boolValue, true)

        XCTAssertEqual(NSNumber(value: Int.max).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int.max - 1).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int.min).boolValue, false)   // Darwin compatibility
        XCTAssertEqual(NSNumber(value: Int.min + 1).boolValue, true)
        XCTAssertEqual(NSNumber(value: Int(-1)).boolValue, true)
    }

    func test_AnyHashable() {
        func hash(_ seed: Int, _ value: AnyHashable) -> Int {
            var hasher = Hasher()
            hasher.combine(seed)
            hasher.combine(value)
            return hasher.finalize()
        }

        func checkThatHashEncodingsDiffer(
            _ left: AnyHashable, _ right: AnyHashable,
            _ message: @autoclosure () -> String? = nil,
            file: StaticString = #file,
            line: UInt = #line) {
            for i in 0 ..< 10 {
                if hash(i, left) != hash(i, right) {
                    // We found a proof that left and right have
                    // different hash encodings.
                    return
                }
            }
            XCTFail(
                message() ?? "\(left) and \(right) have the same hash encoding",
                file: file, line: line)
        }
        func checkEquivalenceGroups(_ groups: [[AnyHashable]], file: StaticString = #file, line: UInt = #line) {
            // Check that items in the same group compare & hash the same.
            for gi in 0 ..< groups.count {
                let group = groups[gi]
                for i in 0 ..< group.count {
                    for j in 0 ..< i {
                        let a = group[i]
                        let b = group[j]
                        XCTAssertEqual(
                            a, b,
                            "Non-equal values at indices \(gi)/\(i) and \(gi)/\(j)",
                            file: file, line: line)
                        XCTAssertEqual(
                            a.hashValue, b.hashValue,
                            """
                            hashValue mismatch between values at indices \(gi)/\(i) and \(gi)/\(j)
                            \(i): \(a)
                            \(j): \(b)
                            """,
                            file: file, line: line)
                    }
                }
            }
            // Check that items in different groups compare and hash different.
            for gi in 0 ..< groups.count {
                for i in 0 ..< groups[gi].count {
                    for gj in 0 ..< gi {
                        for j in 0 ..< groups[gj].count {
                            XCTAssertNotEqual(groups[gi][i], groups[gj][j],
                                "Equal values at indices \(gi)/\(i) and \(gj)/\(j)",
                                file: file, line: line)
                            checkThatHashEncodingsDiffer(
                                groups[gi][i], groups[gj][j],
                                "Values at indices \(gi)/\(i) and \(gj)/\(j) hash the same",
                                file: file, line: line)
                        }
                    }
                }
            }
        }
        checkEquivalenceGroups([
                [
                    0,
                    NSNumber(value: 0 as Int),
                    NSNumber(value: 0 as Int8),
                    NSNumber(value: 0 as Int16),
                    NSNumber(value: 0 as Int32),
                    NSNumber(value: 0 as Int64),
                    NSNumber(value: 0 as UInt),
                    NSNumber(value: 0 as UInt8),
                    NSNumber(value: 0 as UInt16),
                    NSNumber(value: 0 as UInt32),
                    NSNumber(value: 0 as UInt64),
                    NSNumber(value: 0 as Float),
                    NSNumber(value: 0 as Double)
                ],
                [
                    1,
                    NSNumber(value: 1 as Int),
                    NSNumber(value: 1 as Int8),
                    NSNumber(value: 1 as Int16),
                    NSNumber(value: 1 as Int32),
                    NSNumber(value: 1 as Int64),
                    NSNumber(value: 1 as UInt),
                    NSNumber(value: 1 as UInt8),
                    NSNumber(value: 1 as UInt16),
                    NSNumber(value: 1 as UInt32),
                    NSNumber(value: 1 as UInt64),
                    NSNumber(value: 1 as Float),
                    NSNumber(value: 1 as Double)
                ],
                [
                    42,
                    NSNumber(value: 42 as Int),
                    NSNumber(value: 42 as Int8),
                    NSNumber(value: 42 as Int16),
                    NSNumber(value: 42 as Int32),
                    NSNumber(value: 42 as Int64),
                    NSNumber(value: 42 as UInt),
                    NSNumber(value: 42 as UInt8),
                    NSNumber(value: 42 as UInt16),
                    NSNumber(value: 42 as UInt32),
                    NSNumber(value: 42 as UInt64),
                    NSNumber(value: 42 as Float),
                    NSNumber(value: 42 as Double)
                ],
                [
                    -42,
                    NSNumber(value: -42 as Int),
                    NSNumber(value: -42 as Int8),
                    NSNumber(value: -42 as Int16),
                    NSNumber(value: -42 as Int32),
                    NSNumber(value: -42 as Int64),
                    NSNumber(value: -42 as Float),
                    NSNumber(value: -42 as Double)
                ],
                [
                    NSNumber(value: 4.25 as Float),
                    NSNumber(value: 4.25 as Double)
                ]
            ])
    }
}
