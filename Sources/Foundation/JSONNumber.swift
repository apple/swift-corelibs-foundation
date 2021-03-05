// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

// _JSONNumber - value type storing a parsed and validated JSON Number
// _NSJSONNumber - internal subclass of NSNumber wrap _JSONNumber

// The underlying problem with parsing numbers in JSON is that a numeric type
// (Int64, UInt64, Double or Decimal) is chosen by JSONSerialization at parse
// time to store in an NSNumber or NSDecimalNumber. However if later on the
// value is extracted as a different type by JSONDecoder via bridging, then this
// can lead to an incorrect value.
//
// This occurs because of loss of accuracy when converting a Decimal to a Double
// and vice-versa, eg:
//
// let double = NSNumber(value: Double("46.984765")!)
// print(double.doubleValue)        -> 46.984765
// print(double.decimalValue)       -> 46.98476500000001024
//
// let nsdecimal = NSDecimalNumber(decimal: Decimal(string: "46.984765")!)
// print(nsdecimal.decimalValue)    -> 46.984765
// print(nsdecimal.doubleValue)     -> 46.984764999999996
//
// The method used by _JSONNumber is to hold the value as a String and delay
// parsing until the value is needed. At this point it is known if the value
// should be parsed as a Decimal or a Double/Float. Although the parsing step is
// repeated if the value is required again, in general JSONDecoder will only
// require the value once when it converts it into the decoded struct.
//
// Parsing
// -------
//
// The initialisation step does the usual JSON number validation according to
// the specification on http://json.org.
//
// As part of the validation the digits are parsed into a UInt64 as integer
// parsing is a simpler case then floating point parsing.
// This allows determining if the input is an integer and also allow parsing of
// integer values expressed with an exponent eg "1e3" (1000) or "0.12e6" (120000).
// This is to match the previous behaviour where although Int.init() would not
// parse these values, they would still bridge to integer types because the input
// would be parsed by the Double or Decimal parser.
//
// Integers
// --------
//
// The integer value is stored in a property to avoid reparsing it and allowing
// faster results for the computed properties that return an integer. This also
// allows determining if the original input is an integer.
//
// Only two properties are stored:
// jsonString: String
//
// - Stores the original (validated) input that can be reparsed for different
//   floating point types as required.
//
// _integerMagnitude: UInt64
//
// - Stores the integer magnitude if the parsed input is an integer.
//   The sign is held in the first character of jsonString if the value is negative.
//   Positive JSON numbers do not store a sign.
//
//   If the input is not an integer then _integerMagnitude == 0. The integer magnitude
//   zero is special cased where _integerMagnitude == 0 and jsonString == "0" or "-0".
//
//   _integerMagnitude is not stored as a UInt64? as the extra byte for the optional flag
//   makes the size of the properties increase from 40 to 41 bytes. However because the class
//   is allocated on the heap and malloc() usually uses a minium multiple of 8 bytes for memory
//   regions, the allocated size would be 48 bytes. This helps reduce the memory usage.
//
// Bridging
// --------
//
// Currently bridging from NSNumber to a number type eg Int uses the Int.init?(exactly:)
// initialiser as below:
//
// public init?(exactly number: NSNumber) {
//    let value = number.intValue
//    guard NSNumber(value: value) == number else { return nil }
//    self = value
// }
//
// The problem with this is that .intValue never fails even if the underlying value will
// not fit into an Int type eg 1.2. This means that a second NSNumber must be created
// just so that an equality check can be performed against the original input.
// Both of these operations involve overhead including a heap allocation for the NSNumber.
//
// _NSJSONNumber provides extra properties to help with bridging, named exactlyInt?,
// exactlyDouble? etc which return either the JSON number value as that type or nil
// if the type will not hold it exactly.
// Integers & Boolean are computed from the _integerMagnitude and isNegative properties.
// Floating point and Decimal are parsed using the type's initialiser which returns nil
// if the value will not fit into that type. nil is also returned for parsed values that
// are not finite. This allows the initialiser to be simplified to:
//
// internal init?(exactly number: _NSJSONNumber) {
//     guard let value = number.exactlyInt else { return nil }
//         self = value
//     }
// }
//

internal struct _JSONNumber: Equatable, CustomStringConvertible, CustomDebugStringConvertible {

    fileprivate let jsonString: String
    fileprivate let _integerMagnitude: UInt64
    // Magnitude of integer value, the sign is held in the first character of jsonString (if negative)
    // nil == not an integer
    fileprivate var integerMagnitude: UInt64? {
        if _integerMagnitude > 0 { return _integerMagnitude }
        if jsonString == "0" || jsonString == "-0" { return 0 }
        return nil
    }

    fileprivate var isNegative: Bool { jsonString.first! == "-" }

    var description: String { jsonString }
    var debugDescription: String { jsonString }

    internal init(jsonString: String, integerMagnitude: UInt64?, exponent: Int) {
        precondition(jsonString.count > 0)

        guard var integerMagnitude = integerMagnitude else {
            self.jsonString = jsonString
            self._integerMagnitude = 0
            return
        }

        if integerMagnitude == 0 {
            let isNegative = jsonString.first! == "-"
            self.jsonString = isNegative ? "-0" : "0"
        } else {
            self.jsonString = jsonString
            // Normalise the exponent
            switch exponent {
                case 0: break
                case -19...19:
                    let multiplier = (1...exponent.magnitude).reduce(into: UInt64(1)) { (result, _) in
                        result = result &* 10   // exponent has already been range checked to avoid overflow.
                    }

                    if exponent > 0 {
                        let (newValue, overflow) = integerMagnitude.multipliedReportingOverflow(by: multiplier)
                        integerMagnitude = overflow ? 0 : newValue
                    } else {
                        let (quotent, remainder) = multiplier.dividingFullWidth((0, integerMagnitude))
                        integerMagnitude = (remainder == 0) ? quotent : 0
                    }
                default:
                // The exponent is too large or small for the parsed integer to be stored in a UInt64.
                integerMagnitude = 0
            }
        }
        self._integerMagnitude = integerMagnitude

    }

    fileprivate init(jsonString: String, _integerMagnitude: UInt64) {
        self.jsonString = jsonString
        self._integerMagnitude = _integerMagnitude
    }

    // Extra methods used for bridging. By returning only exact values or nil otherwise, bridging can be
    // simplified without an intermediate NSNumber needing to be created for an equality check.

    internal var exactlyDecimal: Decimal? {
        if let magnitude = integerMagnitude {
            var d = Decimal(magnitude)
            if isNegative {
                d.negate()
            }
            return d
        }
        return Decimal(string: jsonString)
    }

    // 0 = false, 1 = true, all else is nil
    internal var exactlyBool: Bool? {
        switch self.exactlyUInt {
            case 0: return false
            case 1: return true
            default: return nil
        }
    }

#if !os(macOS)
    internal var exactlyFloat16: Float16? {
        guard let _floatValue = Float16(jsonString), _floatValue.isFinite else { return nil }
        return _floatValue
    }
#endif

    internal var exactlyFloat: Float? {
        guard let _floatValue = Float(jsonString), _floatValue.isFinite else { return nil }
        return _floatValue
    }

    internal var exactlyDouble: Double? {
        if let value = Double(jsonString), value.isFinite {
            return value
        } else {
            return nil
        }
    }

#if arch(x86_64) || arch(i386)
    internal var exactlyFloat80: Float80? {
        guard let _floatValue = Float80(jsonString), _floatValue.isFinite else { return nil }
        return _floatValue
    }
#endif

    internal var exactlyUInt64: UInt64? {
        guard let _integerMagnitude = self.integerMagnitude else { return nil }
        if isNegative && _integerMagnitude > 0 { return nil }  // Allow -0 to return 0
        return _integerMagnitude
    }

    internal var exactlyUInt: UInt? {
        if let uint64Value = exactlyUInt64, uint64Value <= UInt64(UInt.max) {
            return UInt(uint64Value)
        } else {
            return nil
        }
    }

    internal var exactlyUInt32: UInt32? {
        if let uint64Value = exactlyUInt64, uint64Value <= UInt64(UInt32.max) {
            return UInt32(uint64Value)
        } else {
            return nil
        }
    }

    internal var exactlyUInt16: UInt16? {
        if let uint64Value = exactlyUInt64, uint64Value <= UInt64(UInt16.max) {
            return UInt16(uint64Value)
        } else {
            return nil
        }
    }

    internal var exactlyUInt8: UInt8? {
        if let uint64Value = exactlyUInt64, uint64Value <= UInt64(UInt8.max) {
            return UInt8(uint64Value)
        } else {
            return nil
        }
    }

    internal var exactlyInt64: Int64? {
        guard let _integerMagnitude = self.integerMagnitude else { return nil }
        if isNegative {
            if _integerMagnitude == Int64.min.magnitude { return Int64.min }
            if _integerMagnitude < Int64.min.magnitude { return -1 * Int64(_integerMagnitude) }
        } else {
            if _integerMagnitude <= Int64.max.magnitude { return Int64(_integerMagnitude) }
        }
        return nil
    }

    internal var exactlyInt: Int? {
        guard let _integerMagnitude = self.integerMagnitude else { return nil }
        if isNegative {
            if _integerMagnitude == UInt64(Int.min.magnitude) { return Int.min }
            if _integerMagnitude < UInt64(Int.min.magnitude) { return -1 * Int(_integerMagnitude) }
        } else {
            if _integerMagnitude <= UInt64(Int.max.magnitude) { return Int(_integerMagnitude) }
        }
        return nil
    }

    internal var exactlyInt32: Int32? {
        guard let _integerMagnitude = self.integerMagnitude else { return nil }
        if isNegative {
            if _integerMagnitude == UInt64(Int32.min.magnitude) { return Int32.min }
            if _integerMagnitude < UInt64(Int32.min.magnitude) { return -1 * Int32(_integerMagnitude) }
        } else {
            if _integerMagnitude <= UInt64(Int32.max.magnitude) { return Int32(_integerMagnitude) }
        }
        return nil
    }

    internal var exactlyInt16: Int16? {
        guard let _integerMagnitude = self.integerMagnitude else { return nil }
        if isNegative {
            if _integerMagnitude == UInt64(Int16.min.magnitude) { return Int16.min }
            if _integerMagnitude < UInt64(Int16.min.magnitude) { return -1 * Int16(_integerMagnitude) }
        } else {
            if _integerMagnitude <= UInt64(Int16.max.magnitude) { return Int16(_integerMagnitude) }
        }
        return nil
    }

    internal var exactlyInt8: Int8? {
        guard let _integerMagnitude = self.integerMagnitude else { return nil }
        if isNegative {
            if _integerMagnitude == UInt64(Int8.min.magnitude) { return Int8.min }
            if _integerMagnitude < UInt64(Int8.min.magnitude) { return -1 * Int8(_integerMagnitude) }
        } else {
            if _integerMagnitude <= UInt64(Int8.max.magnitude) { return Int8(_integerMagnitude) }
        }
        return nil
    }
}

internal final class _NSJSONNumber: NSNumber {
    internal let jsonNumber: _JSONNumber
    override var description: String { return jsonNumber.jsonString }
    override var stringValue: String { return jsonNumber.jsonString }

    init(jsonNumber: _JSONNumber) {
        self.jsonNumber = jsonNumber
    }

    internal required convenience init(bytes buffer: UnsafeRawPointer, objCType: UnsafePointer<Int8>) {
        fatalError("init(bytes:objCType:) has not been implemented")
    }

    internal required convenience init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal required convenience init(booleanLiteral value: Bool) {
        self.init(value: value)
    }

    internal required convenience init(floatLiteral value: Double) {
        self.init(value: value)
    }

    internal required convenience init(integerLiteral value: Int) {
        self.init(value: value)
    }

    internal init(value: Bool) {
        self.jsonNumber = _JSONNumber(jsonString: value ? "1" : "0", _integerMagnitude: value ? 1 : 0)
    }

#if !os(macOS)
    internal init(value: Float16) {
        precondition(value.isFinite)

        let jsonString: String
        let _integerMagnitude: UInt64

        if value.isZero {
            _integerMagnitude = 0
            jsonString = (value.sign == .plus) ? "0" : "-0"
        } else {
            let u = UInt64(value.magnitude)
            if Float16(u) == value {
                _integerMagnitude = u
            } else {
                _integerMagnitude = 0
            }
            jsonString = value.description
        }
        self.jsonNumber = _JSONNumber(jsonString: jsonString, _integerMagnitude: _integerMagnitude)
    }
#endif

    internal init(value: Float) {
        precondition(value.isFinite)

        let jsonString: String
        let _integerMagnitude: UInt64

        if value.isZero {
            _integerMagnitude = 0
            jsonString = (value.sign == .plus) ? "0" : "-0"
        } else {
            let u = UInt64(value.magnitude)
            if Float(u) == value {
                _integerMagnitude = u
            } else {
                _integerMagnitude = 0
            }
            jsonString = value.description
        }
        self.jsonNumber = _JSONNumber(jsonString: jsonString, _integerMagnitude: _integerMagnitude)
    }

    internal init(value: Double) {
        precondition(value.isFinite)

        let jsonString: String
        let _integerMagnitude: UInt64
        if value.isZero {
            _integerMagnitude = 0
            jsonString = (value.sign == .plus) ? "0" : "-0"
        } else {
            let u = UInt64(value.magnitude)
            if Double(u) == value {
                _integerMagnitude = u
            } else {
                _integerMagnitude = 0
            }
            jsonString = value.description
        }
        self.jsonNumber = _JSONNumber(jsonString: jsonString, _integerMagnitude: _integerMagnitude)
    }

#if arch(x86_64) || arch(i386)
    internal init(value: Float80) {
        precondition(value.isFinite)

        let jsonString: String
        let _integerMagnitude: UInt64

        if value.isZero {
            _integerMagnitude = 0
            jsonString = (value.sign == .plus) ? "0" : "-0"
        } else {
            let u = UInt64(value.magnitude)
            if Float80(u) == value {
                _integerMagnitude = u
            } else {
                _integerMagnitude = 0
            }
            jsonString = value.description
        }
        self.jsonNumber = _JSONNumber(jsonString: jsonString, _integerMagnitude: _integerMagnitude)
    }
#endif

    internal init(value: Int8) {
        self.jsonNumber = _JSONNumber(jsonString: value.description, _integerMagnitude: UInt64(value.magnitude))
    }

    internal init(value: Int16) {
        self.jsonNumber = _JSONNumber(jsonString: value.description, _integerMagnitude: UInt64(value.magnitude))
    }

    internal init(value: Int32) {
        self.jsonNumber = _JSONNumber(jsonString: value.description, _integerMagnitude: UInt64(value.magnitude))
    }
    internal init(value: Int64) {
        self.jsonNumber = _JSONNumber(jsonString: value.description, _integerMagnitude: UInt64(value.magnitude))
    }

    internal init(value: Int) {
        self.jsonNumber = _JSONNumber(jsonString: value.description, _integerMagnitude: UInt64(value.magnitude))
    }

    internal init(value: UInt8) {
        self.jsonNumber = _JSONNumber(jsonString: value.description, _integerMagnitude: UInt64(value.magnitude))
    }

    internal init(value: UInt16) {
        self.jsonNumber = _JSONNumber(jsonString: value.description, _integerMagnitude: UInt64(value.magnitude))
    }

    internal init(value: UInt32) {
        self.jsonNumber = _JSONNumber(jsonString: value.description, _integerMagnitude: UInt64(value.magnitude))
    }

    internal init(value: UInt64) {
        self.jsonNumber = _JSONNumber(jsonString: value.description, _integerMagnitude: UInt64(value.magnitude))
    }

    internal init(value: UInt) {
        self.jsonNumber = _JSONNumber(jsonString: value.description, _integerMagnitude: UInt64(value.magnitude))
    }

    // 0, -0 is false, everything else is true
    override var boolValue: Bool {
        if let i = jsonNumber.integerMagnitude, i == 0 {
            return false
        }
        return true
    }

    override var floatValue: Float {
        return Float(jsonNumber.jsonString) ?? Float.nan
    }

    override var doubleValue: Double {
        return Double(jsonNumber.jsonString) ?? Double.nan
    }

    override var intValue: Int {
        guard let _integerMagnitude = jsonNumber.integerMagnitude else { return 0 }
        let i = Int(truncatingIfNeeded: _integerMagnitude)
        if !jsonNumber.isNegative || i < 0 { return i }
        return -1 * i
    }

    override var int8Value: Int8 {
        return Int8(truncatingIfNeeded: intValue)
    }

    override var int16Value: Int16 {
        return Int16(truncatingIfNeeded: intValue)
    }

    override var int32Value: Int32 {
        return Int32(truncatingIfNeeded: intValue)
    }

    override var int64Value: Int64 {
        guard let _integerMagnitude = jsonNumber.integerMagnitude else { return 0 }
        let i = Int64(truncatingIfNeeded: _integerMagnitude)
        if !jsonNumber.isNegative || i < 0 { return i }
        return -1 * i
    }

    override var uintValue: UInt {
        guard !jsonNumber.isNegative, let _integerMagnitude = jsonNumber.integerMagnitude else { return 0 }
        return UInt(truncatingIfNeeded: _integerMagnitude)
    }

    override var uint8Value: UInt8 {
        guard !jsonNumber.isNegative, let _integerMagnitude = jsonNumber.integerMagnitude else { return 0 }
        return UInt8(truncatingIfNeeded: _integerMagnitude)
    }

    override var uint16Value: UInt16 {
        guard !jsonNumber.isNegative, let _integerMagnitude = jsonNumber.integerMagnitude else { return 0 }
        return UInt16(truncatingIfNeeded: _integerMagnitude)
    }

    override var uint32Value: UInt32 {
        guard !jsonNumber.isNegative, let _integerMagnitude = jsonNumber.integerMagnitude else { return 0 }
        return UInt32(truncatingIfNeeded: _integerMagnitude)
    }

    override var uint64Value: UInt64 {
        guard !jsonNumber.isNegative, let _integerMagnitude = jsonNumber.integerMagnitude else { return 0 }
        return _integerMagnitude
    }

    override internal var int128Value: CFSInt128Struct {
        guard let _integerMagnitude = jsonNumber.integerMagnitude else {
            return CFSInt128Struct(high: Int64.max, low: UInt64.max)
        }

        if !jsonNumber.isNegative {
            return CFSInt128Struct(high: 0, low: _integerMagnitude)
        } else {
            // 2's complement a UInt64 into a S128 - flip the bits and add 1
            let low = ~_integerMagnitude
            let (newValue, overflow) = low.addingReportingOverflow(1)
            let high: Int64 = overflow ? 0 : -1

            return CFSInt128Struct(high: high, low: newValue)
        }
    }

    internal var decimal: Decimal {
        return jsonNumber.exactlyDecimal ?? Decimal.nan
    }
}

extension Bool {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyBool else { return nil }
        self = value
    }
}

#if !os(macOS)
extension Float16 {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyFloat16 else { return nil }
        self = value
    }
}
#endif

extension Float {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyFloat else { return nil }
        self = value
    }
}

extension Double {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyDouble else { return nil }
        self = value
    }
}

#if arch(x86_64) || arch(i386)
extension Float80 {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyFloat80 else { return nil }
        self = value
    }
}
#endif

extension Int8 {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyInt8 else { return nil }
        self = value
    }
}

extension UInt8 {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyUInt8 else { return nil }
        self = value
    }
}

extension Int16 {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyInt16 else { return nil }
        self = value
    }
}

extension UInt16 {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyUInt16 else { return nil }
        self = value
    }
}

extension Int32 {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyInt32 else { return nil }
        self = value
    }
}

extension UInt32 {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyUInt32 else { return nil }
        self = value
    }
}

extension Int64 {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyInt64 else { return nil }
        self = value
    }
}

extension UInt64 {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyUInt64 else { return nil }
        self = value
    }
}

extension Int {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyInt else { return nil }
        self = value
    }
}

extension UInt {
    internal init?(exactly number: _NSJSONNumber) {
        guard let value = number.jsonNumber.exactlyUInt else { return nil }
        self = value
    }
}
