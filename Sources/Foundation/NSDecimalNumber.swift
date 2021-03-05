// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

/***************	Exceptions		***********/
public struct NSExceptionName : RawRepresentable, Equatable, Hashable {
    public private(set) var rawValue: String
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension NSExceptionName {
    public static let decimalNumberExactnessException = NSExceptionName(rawValue: "NSDecimalNumberExactnessException")
    public static let decimalNumberOverflowException = NSExceptionName(rawValue: "NSDecimalNumberOverflowException")
    public static let decimalNumberUnderflowException = NSExceptionName(rawValue: "NSDecimalNumberUnderflowException")
    public static let decimalNumberDivideByZeroException = NSExceptionName(rawValue: "NSDecimalNumberDivideByZeroException")
}

/***************	Rounding and Exception behavior		***********/

// Rounding policies :
// Original
//    value 1.2  1.21  1.25  1.35  1.27
// Plain    1.2  1.2   1.3   1.4   1.3
// Down     1.2  1.2   1.2   1.3   1.2
// Up       1.2  1.3   1.3   1.4   1.3
// Bankers  1.2  1.2   1.2   1.4   1.3

/***************	Type definitions		***********/
extension NSDecimalNumber {
    public enum RoundingMode : UInt {
        case plain // Round up on a tie
        case down // Always down == truncate
        case up // Always up
        case bankers // on a tie round so last digit is even
    }
    
    public enum CalculationError : UInt {
        case noError
        case lossOfPrecision // Result lost precision
        case underflow // Result became 0
        case overflow // Result exceeds possible representation
        case divideByZero
    }
}

public protocol NSDecimalNumberBehaviors {
    func roundingMode() -> NSDecimalNumber.RoundingMode
    func scale() -> Int16
}

// Receiver can raise, return a new value, or return nil to ignore the exception.

fileprivate func handle(_ error: NSDecimalNumber.CalculationError, _ handler: NSDecimalNumberBehaviors) {
    // handle the error condition, such as throwing an error for over/underflow
}

/***************	NSDecimalNumber: the class		***********/
open class NSDecimalNumber : NSNumber {

    fileprivate let decimal: Decimal
    public convenience init(mantissa: UInt64, exponent: Int16, isNegative: Bool) {
        var d = Decimal(mantissa)
        d._exponent += Int32(exponent)
        d._isNegative = isNegative ? 1 : 0
        self.init(decimal: d)
    }

    public init(decimal dcm: Decimal) {
        self.decimal = dcm
        super.init()
    }

    public convenience init(string numberValue: String?) {
        self.init(decimal: Decimal(string: numberValue ?? "") ?? Decimal.nan)
    }

    public convenience init(string numberValue: String?, locale: Any?) {
        self.init(decimal: Decimal(string: numberValue ?? "", locale: locale as? Locale) ?? Decimal.nan)
    }

    public required init?(coder: NSCoder) {
        guard coder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        let exponent:Int32 = coder.decodeInt32(forKey: "NS.exponent")
        let length:UInt32 = UInt32(coder.decodeInt32(forKey: "NS.length"))
        let isNegative:UInt32 = UInt32(coder.decodeBool(forKey: "NS.negative") ? 1 : 0)
        let isCompact:UInt32 = UInt32(coder.decodeBool(forKey: "NS.compact") ? 1 : 0)
        // let byteOrder:UInt32 = UInt32(coder.decodeInt32(forKey: "NS.bo"))
        guard let mantissaData: Data = coder.decodeObject(forKey: "NS.mantissa") as? Data else {
            return nil // raise "Critical NSDecimalNumber archived data is missing"
        }
        guard mantissaData.count == Int(NSDecimalMaxSize * 2) else {
            return nil  // raise "Critical NSDecimalNumber archived data is wrong size"
        }
        // Byte order?
        let mantissa:(UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16) = (
            UInt16(mantissaData[0]) << 8 & UInt16(mantissaData[1]),
            UInt16(mantissaData[2]) << 8 & UInt16(mantissaData[3]),
            UInt16(mantissaData[4]) << 8 & UInt16(mantissaData[5]),
            UInt16(mantissaData[6]) << 8 & UInt16(mantissaData[7]),
            UInt16(mantissaData[8]) << 8 & UInt16(mantissaData[9]),
            UInt16(mantissaData[10]) << 8 & UInt16(mantissaData[11]),
            UInt16(mantissaData[12]) << 8 & UInt16(mantissaData[13]),
            UInt16(mantissaData[14]) << 8 & UInt16(mantissaData[15])
        )
        self.decimal = Decimal(_exponent: exponent, _length: length, _isNegative: isNegative, _isCompact: isCompact, _reserved: 0, _mantissa: mantissa)
        super.init()
    }

    public init(value: Int) {
        decimal = Decimal(value)
        super.init()
    }

    public init(value: UInt) {
        decimal = Decimal(value)
        super.init()
    }

    public init(value: Int8) {
        decimal = Decimal(value)
        super.init()
    }

    public init(value: UInt8) {
        decimal = Decimal(value)
        super.init()
    }

    public init(value: Int16) {
        decimal = Decimal(value)
        super.init()
    }

    public init(value: UInt16) {
        decimal = Decimal(value)
        super.init()
    }

    public init(value: Int32) {
        decimal = Decimal(value)
        super.init()
    }

    public init(value: UInt32) {
        decimal = Decimal(value)
        super.init()
    }

    public init(value: Int64) {
        decimal = Decimal(value)
        super.init()
    }

    public init(value: UInt64) {
        decimal = Decimal(value)
        super.init()
    }

    public init(value: Bool) {
        decimal = Decimal(value ? 1 : 0)
        super.init()
    }

    public init(value: Float) {
        decimal = Decimal(Double(value))
        super.init()
    }

    public init(value: Double) {
        decimal = Decimal(value)
        super.init()
    }

    public required convenience init(floatLiteral value: Double) {
        self.init(decimal:Decimal(value))
    }

    public required convenience init(booleanLiteral value: Bool) {
        if value {
            self.init(integerLiteral: 1)
        } else {
            self.init(integerLiteral: 0)
        }
    }

    public required convenience init(integerLiteral value: Int) {
        self.init(decimal:Decimal(value))
    }
    
    public required convenience init(bytes buffer: UnsafeRawPointer, objCType type: UnsafePointer<Int8>) {
        NSRequiresConcreteImplementation()
    }

    open override var description: String {
        var number = self.decimal
        return NSDecimalString(&number, nil)
    }

    open override func description(withLocale locale: Locale?) -> String {
        var number = self.decimal
        return NSDecimalString(&number, locale)
    }

    open class var zero: NSDecimalNumber {
        return NSDecimalNumber(integerLiteral: 0)
    }
    open class var one: NSDecimalNumber {
        return NSDecimalNumber(integerLiteral: 1)
    }
    open class var minimum: NSDecimalNumber {
        return NSDecimalNumber(decimal:Decimal.leastFiniteMagnitude)
    }
    open class var maximum: NSDecimalNumber {
        return NSDecimalNumber(decimal:Decimal.greatestFiniteMagnitude)

    }
    open class var notANumber: NSDecimalNumber {
        return NSDecimalNumber(decimal: Decimal.nan)
    }
    
    open func adding(_ other: NSDecimalNumber) -> NSDecimalNumber {
        return adding(other, withBehavior: nil)
    }
    open func adding(_ other: NSDecimalNumber, withBehavior b: NSDecimalNumberBehaviors?) -> NSDecimalNumber {
        var result = Decimal()
        var left = self.decimal
        var right = other.decimal
        let behavior = b ?? NSDecimalNumber.defaultBehavior
        let roundingMode = behavior.roundingMode()
        let error = NSDecimalAdd(&result, &left, &right, roundingMode)
        handle(error,behavior)
        return NSDecimalNumber(decimal: result)
    }

    open func subtracting(_ other: NSDecimalNumber) -> NSDecimalNumber {
        return subtracting(other, withBehavior: nil)
    }
    open func subtracting(_ other: NSDecimalNumber, withBehavior b: NSDecimalNumberBehaviors?) -> NSDecimalNumber {
        var result = Decimal()
        var left = self.decimal
        var right = other.decimal
        let behavior = b ?? NSDecimalNumber.defaultBehavior
        let roundingMode = behavior.roundingMode()
        let error = NSDecimalSubtract(&result, &left, &right, roundingMode)
        handle(error,behavior)
        return NSDecimalNumber(decimal: result)
    }
    open func multiplying(by other: NSDecimalNumber) -> NSDecimalNumber {
        return multiplying(by: other, withBehavior: nil)
    }
    open func multiplying(by other: NSDecimalNumber, withBehavior b: NSDecimalNumberBehaviors?) -> NSDecimalNumber {
        var result = Decimal()
        var left = self.decimal
        var right = other.decimal
        let behavior = b ?? NSDecimalNumber.defaultBehavior
        let roundingMode = behavior.roundingMode()
        let error = NSDecimalMultiply(&result, &left, &right, roundingMode)
        handle(error,behavior)
        return NSDecimalNumber(decimal: result)
    }
    
    open func dividing(by other: NSDecimalNumber) -> NSDecimalNumber {
        return dividing(by: other, withBehavior: nil)
    }
    open func dividing(by other: NSDecimalNumber, withBehavior b: NSDecimalNumberBehaviors?) -> NSDecimalNumber {
        var result = Decimal()
        var left = self.decimal
        var right = other.decimal
        let behavior = b ?? NSDecimalNumber.defaultBehavior
        let roundingMode = behavior.roundingMode()
        let error = NSDecimalDivide(&result, &left, &right, roundingMode)
        handle(error,behavior)
        return NSDecimalNumber(decimal: result)
    }
    
    open func raising(toPower power: Int) -> NSDecimalNumber {
        return raising(toPower:power, withBehavior: nil)
    }
    open func raising(toPower power: Int, withBehavior b: NSDecimalNumberBehaviors?) -> NSDecimalNumber {
        var result = Decimal()
        var input = self.decimal
        let behavior = b ?? NSDecimalNumber.defaultBehavior
        let roundingMode = behavior.roundingMode()
        let error = NSDecimalPower(&result, &input, power, roundingMode)
        handle(error,behavior)
        return NSDecimalNumber(decimal: result)
    }

    open func multiplying(byPowerOf10 power: Int16) -> NSDecimalNumber {
        return multiplying(byPowerOf10: power, withBehavior: nil)
    }

    open func multiplying(byPowerOf10 power: Int16, withBehavior b: NSDecimalNumberBehaviors?) -> NSDecimalNumber {
        var result = Decimal()
        var input = self.decimal
        let behavior = b ?? NSDecimalNumber.defaultBehavior
        let roundingMode = behavior.roundingMode()
        let error = NSDecimalMultiplyByPowerOf10(&result, &input, power, roundingMode)
        handle(error,behavior)
        return NSDecimalNumber(decimal: result)
    }
    
    // Round to the scale of the behavior.
    open func rounding(accordingToBehavior b: NSDecimalNumberBehaviors?) -> NSDecimalNumber {
        var result = Decimal()
        var input = self.decimal
        let behavior = b ?? NSDecimalNumber.defaultBehavior
        let roundingMode = behavior.roundingMode()
        let scale = behavior.scale()
        NSDecimalRound(&result, &input, Int(scale), roundingMode)
        return NSDecimalNumber(decimal: result)
    }

    // compare two NSDecimalNumbers
    open override func compare(_ decimalNumber: NSNumber) -> ComparisonResult {
        if let num = decimalNumber as? NSDecimalNumber {
            return decimal.compare(to: num.decimal)
        } else {
            // NOTE: The lhs must be an NSNumber and not self (an NSDecimalNumber) so that NSNumber.compare() is used
            return decimalNumber.compare(self)
        }
    }

    open class var defaultBehavior: NSDecimalNumberBehaviors {
        return NSDecimalNumberHandler.defaultBehavior
    }
    // One behavior per thread - The default behavior is
    //   rounding mode: NSRoundPlain
    //   scale: No defined scale (full precision)
    //   ignore exactnessException
    //   raise on overflow, underflow and divide by zero.
    static let OBJC_TYPE = "d".utf8CString

    open override var objCType: UnsafePointer<Int8> {
        return NSDecimalNumber.OBJC_TYPE.withUnsafeBufferPointer{ $0.baseAddress! }
    }
    // return 'd' for double
    
    open override var int8Value: Int8 {
        return Int8(truncatingIfNeeded: decimal.int64Value)
    }

    open override var uint8Value: UInt8 {
        return UInt8(truncatingIfNeeded: decimal.uint64Value)
    }

    open override var int16Value: Int16 {
        return Int16(truncatingIfNeeded: decimal.int64Value)
    }

    open override var uint16Value: UInt16 {
        return UInt16(truncatingIfNeeded: decimal.uint64Value)
    }

    open override var int32Value: Int32 {
        return Int32(truncatingIfNeeded: decimal.int64Value)
    }

    open override var uint32Value: UInt32 {
        return UInt32(truncatingIfNeeded: decimal.uint64Value)
    }

    open override var int64Value: Int64 {
        return decimal.int64Value
    }

    open override var uint64Value: UInt64 {
        return decimal.uint64Value
    }

    open override var floatValue: Float {
        return Float(decimal.doubleValue)
    }

    open override var doubleValue: Double {
        return decimal.doubleValue
    }

    open override var boolValue: Bool {
        return !decimal.isZero
    }

    open override var intValue: Int {
        return Int(truncatingIfNeeded: decimal.int64Value)
    }

    open override var uintValue: UInt {
        return UInt(truncatingIfNeeded: decimal.uint64Value)
    }

    open override func isEqual(_ value: Any?) -> Bool {
        if let other = value as? NSDecimalNumber {
            return self.decimal == other.decimal
        }
        if  let other = value as? NSNumber {
            // NOTE: The lhs must be an NSNumber and not self (an NSDecimalNumber) so that NSNumber.compare() is used
            return other.compare(self) == .orderedSame
        }
        return false
    }

    override var _swiftValueOfOptimalType: Any {
      return decimal
    }
}

// return an approximate double value


/***********	A class for defining common behaviors		*******/
open class NSDecimalNumberHandler : NSObject, NSDecimalNumberBehaviors, NSCoding {

    static let defaultBehavior = NSDecimalNumberHandler()

    let _roundingMode: NSDecimalNumber.RoundingMode
    let _scale:Int16

    let _raiseOnExactness: Bool
    let _raiseOnOverflow: Bool
    let _raiseOnUnderflow: Bool
    let _raiseOnDivideByZero: Bool

    public override init() {
        _roundingMode = .plain
        _scale = Int16(NSDecimalNoScale)

        _raiseOnExactness = false
        _raiseOnOverflow = true
        _raiseOnUnderflow = true
        _raiseOnDivideByZero = true
    }
    public required init?(coder: NSCoder) {
        guard coder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        _roundingMode = NSDecimalNumber.RoundingMode(rawValue: UInt(coder.decodeInteger(forKey: "NS.roundingMode")))!
        if coder.containsValue(forKey: "NS.scale") {
            _scale = Int16(coder.decodeInteger(forKey: "NS.scale"))
        } else {
            _scale = Int16(NSDecimalNoScale)
        }
        _raiseOnExactness = coder.decodeBool(forKey: "NS.raise.exactness")
        _raiseOnOverflow = coder.decodeBool(forKey: "NS.raise.overflow")
        _raiseOnUnderflow = coder.decodeBool(forKey: "NS.raise.underflow")
        _raiseOnDivideByZero = coder.decodeBool(forKey: "NS.raise.dividebyzero")
    }
    
    open func encode(with coder: NSCoder) {
        guard coder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        if _roundingMode != .plain {
            coder.encode(Int(_roundingMode.rawValue), forKey: "NS.roundingmode")
        }
        if _scale != Int16(NSDecimalNoScale) {
            coder.encode(_scale, forKey:"NS.scale")
        }
        if _raiseOnExactness {
            coder.encode(_raiseOnExactness, forKey:"NS.raise.exactness")
        }
        if _raiseOnOverflow {
            coder.encode(_raiseOnOverflow, forKey:"NS.raise.overflow")
        }
        if _raiseOnUnderflow {
            coder.encode(_raiseOnUnderflow, forKey:"NS.raise.underflow")
        }
        if _raiseOnDivideByZero {
            coder.encode(_raiseOnDivideByZero, forKey:"NS.raise.dividebyzero")
        }
    }
    
    open class var `default`: NSDecimalNumberHandler {
        return defaultBehavior
    }
    // rounding mode: NSRoundPlain
    // scale: No defined scale (full precision)
    // ignore exactnessException (return nil)
    // raise on overflow, underflow and divide by zero.
    
    public init(roundingMode: NSDecimalNumber.RoundingMode, scale: Int16, raiseOnExactness exact: Bool, raiseOnOverflow overflow: Bool, raiseOnUnderflow underflow: Bool, raiseOnDivideByZero divideByZero: Bool) {
        _roundingMode = roundingMode
        _scale = scale
        _raiseOnExactness = exact
        _raiseOnOverflow = overflow
        _raiseOnUnderflow = underflow
        _raiseOnDivideByZero = divideByZero
    }
    
    open func roundingMode() -> NSDecimalNumber.RoundingMode {
        return _roundingMode
    }
    
    // The scale could return NoScale for no defined scale.
    open func scale() -> Int16 {
        return _scale
    }
}

extension NSNumber {
    
    public var decimalValue: Decimal {
        if let d = self as? NSDecimalNumber {
            return d.decimal
        } else if let d = self as? _NSJSONNumber {
            return d.decimal
        } else {
            return Decimal(self.doubleValue)
        }
    }
}
