// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
    #if canImport(SwiftFoundation) && !DEPLOYMENT_RUNTIME_OBJC
        @testable import SwiftFoundation
    #else
        @testable import Foundation
    #endif
#endif

class TestJSONNumber: XCTestCase {

    #if !NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT    // _JSONNumber is an internal type
    static let allTests: [(String, (TestJSONNumber) -> () throws -> Void)] = []
    #else

    private func initFromString(_ value: String, endIndex: Int? = nil) throws -> _JSONNumber {
        var source = JSONParser(bytes: Array<UInt8>(value.utf8))
        let jsonNumber = try source.reader.readNumber()
        let index = source.reader.readerIndex
        let _endIndex = endIndex ?? value.count
        XCTAssertEqual(_endIndex, index, "endIndex of parsing \(value) should be \(_endIndex) not \(index)")
        return jsonNumber
    }

    #if !os(macOS)
    typealias _Float16 = Float16
    #else
    typealias _Float16 = Double
    #endif

    func testInit() throws {
        func jsonFloat<T: BinaryFloatingPoint>(_ value: T?) -> T? {
            if let value = value, !value.isNaN, value.isFinite {
                return value
            }
            return nil
        }

        let testIntegers: [CustomStringConvertible] = [
            "0", "-0", "1", "-1",
            Int8.min, Int8.max, Int16.min, Int16.max, Int32.min, Int32.max, Int64.min, Int64.max, Int.min, Int.max,
            Int64(Int8.min) - 2, Int64(Int8.min) - 1, Int64(Int8.min) + 1, Int64(Int8.min) + 2,
            Int64(Int8.max) - 2, Int64(Int8.max) - 1, Int64(Int8.max) + 1, Int64(Int8.max) + 2,
            Int64(Int16.min) - 2, Int64(Int16.min) - 1, Int64(Int16.min) + 1, Int64(Int16.min) + 2,
            Int64(Int16.max) - 2, Int64(Int16.max) - 1, Int64(Int16.max) + 1, Int64(Int16.max) + 2,
            Int64(Int32.min) - 2, Int64(Int32.min) - 1, Int64(Int32.min) + 1, Int64(Int32.min) + 2,
            Int64(Int32.max) - 2, Int64(Int32.max) - 1, Int64(Int32.max) + 1, Int64(Int32.max) + 2,
            "-9223372036854775810", "-9223372036854775809", Int64(Int64.min) + 1, Int64(Int64.min) + 2,
            Int64(Int64.max) - 2, Int64(Int64.max) - 1, "9223372036854775808", "9223372036854775809",
        ]

        let testFloats: [CustomStringConvertible] = [
            _Float16.leastNormalMagnitude, _Float16.leastNonzeroMagnitude, _Float16.greatestFiniteMagnitude,
            Float.leastNormalMagnitude, Float.leastNonzeroMagnitude, Float.greatestFiniteMagnitude,
            Double.leastNormalMagnitude, Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude,
            "1e100", "1e200",
        ]

        for _testValue in testIntegers {
            let testValue = _testValue.description

            do {
                let number = try initFromString(testValue)
                let nsnumber = _NSJSONNumber(jsonNumber: number)
                XCTAssertEqual(nsnumber.description, testValue, "'\(testValue)' .description")
                XCTAssertEqual(nsnumber.stringValue, testValue, "'\(testValue)' .stringValue")

                #if !os(macOS)
                XCTAssertEqual(number.exactlyFloat16, jsonFloat(Float16(testValue)), "'\(testValue)' .exactlyFloat16")
                #endif

                XCTAssertEqual(number.exactlyFloat, jsonFloat(Float32(testValue)), "'\(testValue)' .exactlyFloat")
                XCTAssertEqual(number.exactlyDouble, jsonFloat(Double(testValue)), "'\(testValue)' .exactlyDouble")

                #if arch(x86_64) || arch(i386)
                XCTAssertEqual(number.exactlyFloat80, jsonFloat(Float80(testValue)), "'\(testValue)' .exactlyFloat80")
                #endif

                XCTAssertEqual(number.exactlyInt8, Int8(testValue), "'\(testValue)' .exactlyInt8")
                XCTAssertEqual(number.exactlyInt16, Int16(testValue), "'\(testValue)' .exactlIint16")
                XCTAssertEqual(number.exactlyInt32, Int32(testValue), "'\(testValue)' .exactlyInt32")
                XCTAssertEqual(number.exactlyInt64, Int64(testValue), "'\(testValue)' .exactlyInt64")
                XCTAssertEqual(number.exactlyInt, Int(testValue), "'\(testValue)' .exactlyInt")

                XCTAssertEqual(number.exactlyUInt8, UInt8(testValue), "'\(testValue)' .exactlyUint8")
                XCTAssertEqual(number.exactlyUInt16, UInt16(testValue), "'\(testValue)' .exactlyUint16")
                XCTAssertEqual(number.exactlyUInt32, UInt32(testValue), "'\(testValue)' .exactlyUint32")
                XCTAssertEqual(number.exactlyUInt64, UInt64(testValue), "'\(testValue)' .exactlyUint64")
                XCTAssertEqual(number.exactlyUInt, UInt(testValue), "'\(testValue)' .exactlyUint")

                let _decimal = Decimal(string: testValue)
                let decimal =  _decimal?.isFinite == true ? _decimal : nil
                XCTAssertEqual(number.exactlyDecimal, decimal, "'\(testValue)' .exactlyDecimal")
            } catch {
                XCTFail("Could not parse \(testValue): \(error)")
            }
        }
    }

    func testBool() throws {
        // Bools can have different interpretations of true and false so test equivalence to NSNumber

        XCTAssertTrue(NSNumber(value: true).boolValue)
        XCTAssertTrue(_NSJSONNumber(value: true).boolValue)
        XCTAssertEqual(_NSJSONNumber(value: true).jsonNumber.exactlyBool, true)

        XCTAssertFalse(NSNumber(value: false).boolValue)
        XCTAssertFalse(_NSJSONNumber(value: false).boolValue)
        XCTAssertEqual(_NSJSONNumber(value: false).jsonNumber.exactlyBool, false)

        let testValues: [(Double, Bool?)] = [ (-0.0, false), (0.0, false), (1.0, true), (-1.0, nil), (-2, nil), (1e6, nil)]
        for value in testValues {
            XCTAssertEqual(NSNumber(value: value.0) as? Bool, value.1, "\(value) as? Bool")
            XCTAssertEqual(_NSJSONNumber(value: value.0) as? Bool, value.1, "\(value) as? Bool")
            XCTAssertEqual(_NSJSONNumber(value: value.0).jsonNumber.exactlyBool, value.1, "\(value) .exactlyBool")
        }

        for value in -10...10 {
            XCTAssertEqual(NSNumber(value: value), _NSJSONNumber(value: value), "value: \(value)")
            XCTAssertEqual(NSNumber(value: value).boolValue, _NSJSONNumber(value: value).boolValue, "value: \(value)")
            XCTAssertEqual(NSNumber(value: value) as? Bool, _NSJSONNumber(value: value) as? Bool, "value: \(value)")
        }
    }

    func testIntegers() {
        let testInputs = [
            ("-0.000e100", 0),
            ("-0", 0),
            ("0.0e0", 0),
            ("0.0000e+000", 0),
            ("0.0E-0000", 0),
            ("0.00012e5", 12),
        ]

        for (input, intValue) in testInputs {
            do {
                let number = try initFromString(input)
                XCTAssertEqual(number.exactlyInt, intValue, "Testing \(input)")
            } catch {
                XCTFail("Cant parse: \(input), \(error)")
            }
        }

        XCTAssertEqual(_NSJSONNumber(value: 0.0).uintValue, 0)
        XCTAssertEqual(_NSJSONNumber(value: 0.0).intValue, 0)
        XCTAssertEqual(_NSJSONNumber(value: -0.0).uintValue, 0)
        XCTAssertEqual(_NSJSONNumber(value: -0.0).intValue, 0)
    }

    // A Number can end validly with non number characters
    func testTrailingCharacters() {
        let goodInputs = [
            ("0}", "0"),
            ("0.1 ", "0.1"),
            ("0.12 ", "0.12"),
            ("12.345e-12 ", "12.345e-12"),
            ("0.1e-3]", "0.1e-3"),
            ("-0 }", "-0")
        ]

        for (input, description) in goodInputs {
            do {
                let number = _NSJSONNumber(jsonNumber: try initFromString(input, endIndex: description.count))
                XCTAssertEqual(number.description, description)
            } catch {
                XCTFail("Cant parse \(input), \(error)")
            }
        }
    }

    func testInvalidNumbers() {
        let badInputs = [
            ("0.e-000", JSONError.unexpectedCharacter(ascii: 101, characterIndex: 2)),
          //  (" 1", JSONError.numberWithLeadingZero(index: 1)),
          //  (".23", JSONError.numberWithLeadingZero(index: 1)),
            ("01.2", JSONError.numberWithLeadingZero(index: 1)),
            ("0.", JSONError.unexpectedEndOfFile),
          //  ("+1", JSONError.numberWithLeadingZero(index: 1)),
            ("00", JSONError.numberWithLeadingZero(index: 1)),
            ("0e", JSONError.unexpectedEndOfFile),
            ("0eE", JSONError.unexpectedCharacter(ascii: 69, characterIndex: 2)),
            ("0ex1", JSONError.unexpectedCharacter(ascii: 120, characterIndex: 2)),
            ("0E+", JSONError.unexpectedEndOfFile),
            ("0e-", JSONError.unexpectedEndOfFile),
        ]

        for (badInput, expectedError) in badInputs {
            XCTAssertThrowsError(try initFromString(badInput), "Parsing \(badInput)") {
                let msg = "Testing \(badInput)"
                guard let jsonError = $0 as? JSONError else {
                    XCTFail("Expected a JSONError \(msg)")
                    return
                }
                XCTAssertEqual(jsonError, expectedError, "with input \(badInput)")
            }
        }
    }

    static let allTests: [(String, (TestJSONNumber) -> () throws -> Void)] = [
        ("testInit", testInit),
        ("testBool", testBool),
        ("testIntegers", testIntegers),
        ("testTrailingCharacters", testTrailingCharacters),
        ("testInvalidNumbers", testInvalidNumbers),
    ]
    #endif  // NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
}
