/*
 NSUnitConverter describes how to convert a unit to and from the base unit of its dimension.  Use the NSUnitConverter protocol to implement new ways of converting a unit.
 */

open class UnitConverter : NSObject {
    
    
    /*
     The following methods perform conversions to and from the base unit of a unit class's dimension.  Each unit is defined against the base unit for the dimension to which the unit belongs.
     
     These methods are implemented differently depending on the type of conversion.  The default implementation in NSUnitConverter simply returns the value.
     
     These methods exist for the sole purpose of creating custom conversions for units in order to support converting a value from one kind of unit to another in the same dimension.  NSUnitConverter is an abstract class that is meant to be subclassed.  There is no need to call these methods directly to do a conversion -- the correct way to convert a measurement is to use [NSMeasurement measurementByConvertingToUnit:].  measurementByConvertingToUnit: uses the following 2 methods internally to perform the conversion.
     
     When creating a custom unit converter, you must override these two methods to implement the conversion to and from a value in terms of a unit and the corresponding value in terms of the base unit of that unit's dimension in order for conversion to work correctly.
     */
    
    /*
     This method takes a value in terms of a unit and returns the corresponding value in terms of the base unit of the original unit's dimension.
     @param value Value in terms of the unit class
     @return Value in terms of the base unit
     */
    open func baseUnitValue(fromValue value: Double) -> Double {
        return value
    }
    
    
    /*
     This method takes in a value in terms of the base unit of a unit's dimension and returns the equivalent value in terms of the unit.
     @param baseUnitValue Value in terms of the base unit
     @return Value in terms of the unit class
     */
    open func value(fromBaseUnitValue baseUnitValue: Double) -> Double {
        return baseUnitValue
    }
}

open class UnitConverterLinear : UnitConverter, NSSecureCoding {
    
    
    open private(set) var coefficient: Double
    
    open private(set) var constant: Double
    
    
    public convenience init(coefficient: Double) {
        self.init(coefficient: coefficient, constant: 0)
    }
    
    
    public init(coefficient: Double, constant: Double) {
        self.coefficient = coefficient
        self.constant = constant
    }
    
    open override func baseUnitValue(fromValue value: Double) -> Double {
        return value * coefficient + constant
    }
    
    open override func value(fromBaseUnitValue baseUnitValue: Double) -> Double {
        return (baseUnitValue - constant) / coefficient
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        let coefficient = aDecoder.decodeDouble(forKey: "NS.coefficient")
        let constant = aDecoder.decodeDouble(forKey: "NS.constant")
        self.init(coefficient: coefficient, constant: constant)
    }
    
    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        aCoder.encode(self.coefficient, forKey:"NS.coefficient")
        aCoder.encode(self.constant, forKey:"NS.constant")
    }
    
    public static var supportsSecureCoding: Bool { return true }
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitConverterLinear else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return self.coefficient == other.coefficient
            && self.constant == other.constant
    }
}

// This must be named with a NS prefix because it can be sometimes encoded by Darwin, and we need to match the name in the archive.
internal class NSUnitConverterReciprocal : UnitConverter, NSSecureCoding {
    
    
    private var reciprocal: Double
    
    
    init(reciprocal: Double) {
        self.reciprocal = reciprocal
    }
    
    override func baseUnitValue(fromValue value: Double) -> Double {
        return reciprocal / value
    }
    
    override func value(fromBaseUnitValue baseUnitValue: Double) -> Double {
        return reciprocal / baseUnitValue
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        let reciprocal = aDecoder.decodeDouble(forKey: "NS.reciprocal")
        self.init(reciprocal: reciprocal)
    }
    
    func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        aCoder.encode(self.reciprocal, forKey:"NS.reciprocal")
    }
    
    static var supportsSecureCoding: Bool { return true }
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? NSUnitConverterReciprocal else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return self.reciprocal == other.reciprocal
    }
}

/*
 NSUnit is the base class for all unit types (dimensional and dimensionless).
 */

open class Unit : NSObject, NSCopying, NSSecureCoding {
    
    
    open private(set) var symbol: String
    
    
    public required init(symbol: String) {
        self.symbol = symbol
    }
    
    open func copy(with zone: NSZone?) -> Any {
        return self
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        guard let symbol = aDecoder.decodeObject(forKey: "NS.symbol") as? String
            else { return nil }
        self.symbol = symbol
    }
    
    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        aCoder.encode(self.symbol._bridgeToObjectiveC(), forKey:"NS.symbol")
    }
    
    public static var supportsSecureCoding: Bool { return true }
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Unit else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return self.symbol == other.symbol
    }
}

open class Dimension : Unit {
    
    
    open private(set) var converter: UnitConverter
    
    public required init(symbol: String, converter: UnitConverter) {
        self.converter = converter
        super.init(symbol: symbol)
    }
    
    /*
     This class method returns an instance of the dimension class that represents the base unit of that dimension.
     e.g.
     NSUnitSpeed *metersPerSecond = [NSUnitSpeed baseUnit];
     */
    open class func baseUnit() -> Self {
        fatalError("*** You must override baseUnit in your class to define its base unit.")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        guard
            let symbol = aDecoder.decodeObject(of: NSString.self, forKey: "NS.symbol")?._swiftObject,
            let converter = aDecoder.decodeObject(of: [UnitConverterLinear.self, NSUnitConverterReciprocal.self], forKey: "NS.converter") as? UnitConverter
            else { return nil }
        self.converter = converter
        super.init(symbol: symbol)
    }
    
    public required init(symbol: String) {
        let T = type(of: self)
        fatalError("\(T) must be initialized with designated initializer \(T).init(symbol: String, converter: UnitConverter)")
    }
    
    open override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        aCoder.encode(self.converter, forKey:"NS.converter")
    }
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Dimension else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object) && self.converter == other.converter
    }
}

public final class UnitAcceleration : Dimension {
    
    /*
     Base unit - metersPerSecondSquared
     */
    
    private struct Symbol {
        static let metersPerSecondSquared   = "m/s²"
        static let gravity                  = "g"
    }
    
    private struct Coefficient {
        static let metersPerSecondSquared   = 1.0
        static let gravity                  = 9.81
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var metersPerSecondSquared: UnitAcceleration {
        get {
            return UnitAcceleration(symbol: Symbol.metersPerSecondSquared, coefficient: Coefficient.metersPerSecondSquared)
        }
    }
    
    public class var gravity: UnitAcceleration {
        get {
            return UnitAcceleration(symbol: Symbol.gravity, coefficient: Coefficient.gravity)
        }
    }
    
    public override class func baseUnit() -> UnitAcceleration {
        return .metersPerSecondSquared
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitAcceleration else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitAngle : Dimension {
    
    /*
     Base unit - degrees
     */
    
    private struct Symbol {
        static let degrees      = "°"
        static let arcMinutes   = "ʹ"
        static let arcSeconds   = "ʹʹ"
        static let radians      = "rad"
        static let gradians     = "grad"
        static let revolutions  = "rev"
    }
    
    private struct Coefficient {
        static let degrees      = 1.0
        static let arcMinutes   = 1.0 / 60.0
        static let arcSeconds   = 1.0 / 3600.0
        static let radians      = 180.0 / .pi
        static let gradians     = 0.9
        static let revolutions  = 360.0
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var degrees: UnitAngle {
        get {
            return UnitAngle(symbol: Symbol.degrees, coefficient: Coefficient.degrees)
        }
    }
    
    public class var arcMinutes: UnitAngle {
        get {
            return UnitAngle(symbol: Symbol.arcMinutes, coefficient: Coefficient.arcMinutes)
        }
    }
    
    public class var arcSeconds: UnitAngle {
        get {
            return UnitAngle(symbol: Symbol.arcSeconds, coefficient: Coefficient.arcSeconds)
        }
    }
    
    public class var radians: UnitAngle {
        get {
            return UnitAngle(symbol: Symbol.radians, coefficient: Coefficient.radians)
        }
    }
    
    public class var gradians: UnitAngle {
        get {
            return UnitAngle(symbol: Symbol.gradians, coefficient: Coefficient.gradians)
        }
    }
    
    public class var revolutions: UnitAngle {
        get {
            return UnitAngle(symbol: Symbol.revolutions, coefficient: Coefficient.revolutions)
        }
    }
    
    public override class func baseUnit() -> UnitAngle {
        return .degrees
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitAngle else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitArea : Dimension {
    
    /*
     Base unit - squareMeters
     */
    
    private struct Symbol {
        static let squareMegameters     = "Mm²"
        static let squareKilometers     = "km²"
        static let squareMeters         = "m²"
        static let squareCentimeters    = "cm²"
        static let squareMillimeters    = "mm²"
        static let squareMicrometers    = "µm²"
        static let squareNanometers     = "nm²"
        static let squareInches         = "in²"
        static let squareFeet           = "ft²"
        static let squareYards          = "yd²"
        static let squareMiles          = "mi²"
        static let acres                = "ac"
        static let ares                 = "a"
        static let hectares             = "ha"
    }
    
    private struct Coefficient {
        static let squareMegameters     = 1e12
        static let squareKilometers     = 1e6
        static let squareMeters         = 1.0
        static let squareCentimeters    = 1e-4
        static let squareMillimeters    = 1e-6
        static let squareMicrometers    = 1e-12
        static let squareNanometers     = 1e-18
        static let squareInches         = 0.00064516
        static let squareFeet           = 0.092903
        static let squareYards          = 0.836127
        static let squareMiles          = 2.59e+6
        static let acres                = 4046.86
        static let ares                 = 100.0
        static let hectares             = 10000.0
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var squareMegameters: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareMegameters, coefficient: Coefficient.squareMegameters)
        }
    }
    
    public class var squareKilometers: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareKilometers, coefficient: Coefficient.squareKilometers)
        }
    }
    
    public class var squareMeters: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareMeters, coefficient: Coefficient.squareMeters)
        }
    }
    
    public class var squareCentimeters: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareCentimeters, coefficient: Coefficient.squareCentimeters)
        }
    }
    
    public class var squareMillimeters: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareMillimeters, coefficient: Coefficient.squareMillimeters)
        }
    }
    
    public class var squareMicrometers: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareMicrometers, coefficient: Coefficient.squareMicrometers)
        }
    }
    
    public class var squareNanometers: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareNanometers, coefficient: Coefficient.squareNanometers)
        }
    }
    
    public class var squareInches: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareInches, coefficient: Coefficient.squareInches)
        }
    }
    
    public class var squareFeet: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareFeet, coefficient: Coefficient.squareFeet)
        }
    }
    
    public class var squareYards: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareYards, coefficient: Coefficient.squareYards)
        }
    }
    
    public class var squareMiles: UnitArea {
        get {
            return UnitArea(symbol: Symbol.squareMiles, coefficient: Coefficient.squareMiles)
        }
    }
    
    public class var acres: UnitArea {
        get {
            return UnitArea(symbol: Symbol.acres, coefficient: Coefficient.acres)
        }
    }
    
    public class var ares: UnitArea {
        get {
            return UnitArea(symbol: Symbol.ares, coefficient: Coefficient.ares)
        }
    }
    
    public class var hectares: UnitArea {
        get {
            return UnitArea(symbol: Symbol.hectares, coefficient: Coefficient.hectares)
        }
    }
    
    public override class func baseUnit() -> UnitArea {
        return .squareMeters
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitArea else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitConcentrationMass : Dimension {
    
    /*
     Base unit - gramsPerLiter
     */
    
    private struct Symbol {
        static let gramsPerLiter            = "g/L"
        static let milligramsPerDeciliter   = "mg/dL"
        static let millimolesPerLiter       = "mmol/L"
    }
    
    private struct Coefficient {
        static let gramsPerLiter            = 1.0
        static let milligramsPerDeciliter   = 0.01
        static let millimolesPerLiter       = 18.0
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var gramsPerLiter: UnitConcentrationMass {
        get {
            return UnitConcentrationMass(symbol: Symbol.gramsPerLiter, coefficient: Coefficient.gramsPerLiter)
        }
    }
    
    public class var milligramsPerDeciliter: UnitConcentrationMass {
        get {
            return UnitConcentrationMass(symbol: Symbol.milligramsPerDeciliter, coefficient: Coefficient.milligramsPerDeciliter)
        }
    }
    
    public class func millimolesPerLiter(withGramsPerMole gramsPerMole: Double) -> UnitConcentrationMass {
        return UnitConcentrationMass(symbol: Symbol.millimolesPerLiter, coefficient: Coefficient.millimolesPerLiter * gramsPerMole)
    }
    
    public override class func baseUnit() -> UnitConcentrationMass {
        return UnitConcentrationMass.gramsPerLiter
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitConcentrationMass else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitDispersion : Dimension {
    
    /*
     Base unit - partsPerMillion
     */
    
    private struct Symbol {
        static let partsPerMillion  = "ppm"
    }
    
    private struct Coefficient {
        static let partsPerMillion  = 1.0
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var partsPerMillion: UnitDispersion {
        get {
            return UnitDispersion(symbol: Symbol.partsPerMillion, coefficient: Coefficient.partsPerMillion)
        }
    }
    
    public override class func baseUnit() -> UnitDispersion {
        return .partsPerMillion
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitDispersion else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitDuration : Dimension {
    
    /*
     Base unit - seconds
     */
    
    private struct Symbol {
        static let picoseconds = "ps"
        static let nanoseconds = "ns"
        static let microseconds = "µs"
        static let milliseconds = "ms"
        static let seconds  = "s"
        static let minutes  = "m"
        static let hours    = "h"
    }
    
    private struct Coefficient {
        static let picoseconds = 1e-12
        static let nanoseconds = 1e-9
        static let microseconds = 1e-6
        static let milliseconds = 1e-3
        static let seconds  = 1.0
        static let minutes  = 60.0
        static let hours    = 3600.0
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var picoseconds: UnitDuration {
        get {
            return UnitDuration(symbol: Symbol.picoseconds, coefficient: Coefficient.picoseconds)
        }
    }

    public class var nanoseconds: UnitDuration {
        get {
            return UnitDuration(symbol: Symbol.nanoseconds, coefficient: Coefficient.nanoseconds)
        }
    }

    public class var microseconds: UnitDuration {
        get {
            return UnitDuration(symbol: Symbol.microseconds, coefficient: Coefficient.microseconds)
        }
    }

    public class var milliseconds: UnitDuration {
        get {
            return UnitDuration(symbol: Symbol.milliseconds, coefficient: Coefficient.milliseconds)
        }
    }

    public class var seconds: UnitDuration {
        get {
            return UnitDuration(symbol: Symbol.seconds, coefficient: Coefficient.seconds)
        }
    }
    
    public class var minutes: UnitDuration {
        get {
            return UnitDuration(symbol: Symbol.minutes, coefficient: Coefficient.minutes)
        }
    }
    
    public class var hours: UnitDuration {
        get {
            return UnitDuration(symbol: Symbol.hours, coefficient: Coefficient.hours)
        }
    }
    
    public override class func baseUnit() -> UnitDuration {
        return .seconds
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitDuration else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitElectricCharge : Dimension {
    /*
     Base unit - coulombs
     */
    
    private struct Symbol {
        static let coulombs         = "C"
        static let megaampereHours  = "MAh"
        static let kiloampereHours  = "kAh"
        static let ampereHours      = "Ah"
        static let milliampereHours = "mAh"
        static let microampereHours = "µAh"
    }
    
    private struct Coefficient {
        static let coulombs         = 1.0
        static let megaampereHours  = 3.6e9
        static let kiloampereHours  = 3600000.0
        static let ampereHours      = 3600.0
        static let milliampereHours = 3.6
        static let microampereHours = 0.0036
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var coulombs: UnitElectricCharge {
        get {
            return UnitElectricCharge(symbol: Symbol.coulombs, coefficient: Coefficient.coulombs)
        }
    }
    
    public class var megaampereHours: UnitElectricCharge {
        get {
            return UnitElectricCharge(symbol: Symbol.megaampereHours, coefficient: Coefficient.megaampereHours)
        }
    }
    
    public class var kiloampereHours: UnitElectricCharge {
        get {
            return UnitElectricCharge(symbol: Symbol.kiloampereHours, coefficient: Coefficient.kiloampereHours)
        }
    }
    
    public class var ampereHours: UnitElectricCharge {
        get {
            return UnitElectricCharge(symbol: Symbol.ampereHours, coefficient: Coefficient.ampereHours)
        }
    }
    
    public class var milliampereHours: UnitElectricCharge {
        get {
            return UnitElectricCharge(symbol: Symbol.milliampereHours, coefficient: Coefficient.milliampereHours)
        }
    }
    
    public class var microampereHours: UnitElectricCharge {
        get {
            return UnitElectricCharge(symbol: Symbol.microampereHours, coefficient: Coefficient.microampereHours)
        }
    }
    
    public override class func baseUnit() -> UnitElectricCharge {
        return .coulombs
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitElectricCharge else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitElectricCurrent : Dimension {
    
    /*
     Base unit - amperes
     */
    
    private struct Symbol {
        static let megaamperes  = "MA"
        static let kiloamperes  = "kA"
        static let amperes      = "A"
        static let milliamperes = "mA"
        static let microamperes = "µA"
    }
    
    private struct Coefficient {
        static let megaamperes  = 1e6
        static let kiloamperes  = 1e3
        static let amperes      = 1.0
        static let milliamperes = 1e-3
        static let microamperes = 1e-6
        
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var megaamperes: UnitElectricCurrent {
        get {
            return UnitElectricCurrent(symbol: Symbol.megaamperes, coefficient: Coefficient.megaamperes)
        }
    }
    
    public class var kiloamperes: UnitElectricCurrent {
        get {
            return UnitElectricCurrent(symbol: Symbol.kiloamperes, coefficient: Coefficient.kiloamperes)
        }
    }
    
    public class var amperes: UnitElectricCurrent {
        get {
            return UnitElectricCurrent(symbol: Symbol.amperes, coefficient: Coefficient.amperes)
        }
    }
    
    public class var milliamperes: UnitElectricCurrent {
        get {
            return UnitElectricCurrent(symbol: Symbol.milliamperes, coefficient: Coefficient.milliamperes)
        }
    }
    
    public class var microamperes: UnitElectricCurrent {
        get {
            return UnitElectricCurrent(symbol: Symbol.microamperes, coefficient: Coefficient.microamperes)
        }
    }
    
    public override class func baseUnit() -> UnitElectricCurrent {
        return .amperes
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitElectricCurrent else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitElectricPotentialDifference : Dimension {
    
    /*
     Base unit - volts
     */
    
    private struct Symbol {
        static let megavolts  = "MV"
        static let kilovolts  = "kV"
        static let volts      = "V"
        static let millivolts = "mV"
        static let microvolts = "µV"
    }
    
    private struct Coefficient {
        static let megavolts  = 1e6
        static let kilovolts  = 1e3
        static let volts      = 1.0
        static let millivolts = 1e-3
        static let microvolts = 1e-6
        
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var megavolts: UnitElectricPotentialDifference {
        get {
            return UnitElectricPotentialDifference(symbol: Symbol.megavolts, coefficient: Coefficient.megavolts)
        }
    }
    
    public class var kilovolts: UnitElectricPotentialDifference {
        get {
            return UnitElectricPotentialDifference(symbol: Symbol.kilovolts, coefficient: Coefficient.kilovolts)
        }
    }
    
    public class var volts: UnitElectricPotentialDifference {
        get {
            return UnitElectricPotentialDifference(symbol: Symbol.volts, coefficient: Coefficient.volts)
        }
    }
    
    public class var millivolts: UnitElectricPotentialDifference {
        get {
            return UnitElectricPotentialDifference(symbol: Symbol.millivolts, coefficient: Coefficient.millivolts)
        }
    }
    
    public class var microvolts: UnitElectricPotentialDifference {
        get {
            return UnitElectricPotentialDifference(symbol: Symbol.microvolts, coefficient: Coefficient.microvolts)
        }
    }
    
    public override class func baseUnit() -> UnitElectricPotentialDifference {
        return .volts
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitElectricPotentialDifference else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitElectricResistance : Dimension {
    
    /*
     Base unit - ohms
     */
    
    private struct Symbol {
        static let megaohms  = "MΩ"
        static let kiloohms  = "kΩ"
        static let ohms      = "Ω"
        static let milliohms = "mΩ"
        static let microohms = "µΩ"
    }
    
    private struct Coefficient {
        static let megaohms  = 1e6
        static let kiloohms  = 1e3
        static let ohms      = 1.0
        static let milliohms = 1e-3
        static let microohms = 1e-6
        
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var megaohms: UnitElectricResistance {
        get {
            return UnitElectricResistance(symbol: Symbol.megaohms, coefficient: Coefficient.megaohms)
        }
    }
    
    public class var kiloohms: UnitElectricResistance {
        get {
            return UnitElectricResistance(symbol: Symbol.kiloohms, coefficient: Coefficient.kiloohms)
        }
    }
    
    public class var ohms: UnitElectricResistance {
        get {
            return UnitElectricResistance(symbol: Symbol.ohms, coefficient: Coefficient.ohms)
        }
    }
    
    public class var milliohms: UnitElectricResistance {
        get {
            return UnitElectricResistance(symbol: Symbol.milliohms, coefficient: Coefficient.milliohms)
        }
    }
    
    public class var microohms: UnitElectricResistance {
        get {
            return UnitElectricResistance(symbol: Symbol.microohms, coefficient: Coefficient.microohms)
        }
    }
    
    public override class func baseUnit() -> UnitElectricResistance {
        return .ohms
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitElectricResistance else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitEnergy : Dimension {
    
    /*
     Base unit - joules
     */
    
    private struct Symbol {
        static let kilojoules       = "kJ"
        static let joules           = "J"
        static let kilocalories     = "kCal"
        static let calories         = "cal"
        static let kilowattHours    = "kWh"
    }
    
    private struct Coefficient {
        static let kilojoules       = 1e3
        static let joules           = 1.0
        static let kilocalories     = 4184.0
        static let calories         = 4.184
        static let kilowattHours    = 3600000.0
        
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var kilojoules: UnitEnergy {
        get {
            return UnitEnergy(symbol: Symbol.kilojoules, coefficient: Coefficient.kilojoules)
        }
    }
    
    public class var joules: UnitEnergy {
        get {
            return UnitEnergy(symbol: Symbol.joules, coefficient: Coefficient.joules)
        }
    }
    
    public class var kilocalories: UnitEnergy {
        get {
            return UnitEnergy(symbol: Symbol.kilocalories, coefficient: Coefficient.kilocalories)
        }
    }
    
    public class var calories: UnitEnergy {
        get {
            return UnitEnergy(symbol: Symbol.calories, coefficient: Coefficient.calories)
        }
    }
    
    public class var kilowattHours: UnitEnergy {
        get {
            return UnitEnergy(symbol: Symbol.kilowattHours, coefficient: Coefficient.kilowattHours)
        }
    }
    
    public override class func baseUnit() -> UnitEnergy {
        return .joules
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitEnergy else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitFrequency : Dimension {
    
    /*
     Base unit - hertz
     */
    
    private struct Symbol {
        static let terahertz    = "THz"
        static let gigahertz    = "GHz"
        static let megahertz    = "MHz"
        static let kilohertz    = "kHz"
        static let hertz        = "Hz"
        static let millihertz   = "mHz"
        static let microhertz   = "µHz"
        static let nanohertz    = "nHz"
    }
    
    private struct Coefficient {
        static let terahertz    = 1e12
        static let gigahertz    = 1e9
        static let megahertz    = 1e6
        static let kilohertz    = 1e3
        static let hertz        = 1.0
        static let millihertz   = 1e-3
        static let microhertz   = 1e-6
        static let nanohertz    = 1e-9
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var terahertz: UnitFrequency {
        get {
            return UnitFrequency(symbol: Symbol.terahertz, coefficient: Coefficient.terahertz)
        }
    }
    
    public class var gigahertz: UnitFrequency {
        get {
            return UnitFrequency(symbol: Symbol.gigahertz, coefficient: Coefficient.gigahertz)
        }
    }
    
    public class var megahertz: UnitFrequency {
        get {
            return UnitFrequency(symbol: Symbol.megahertz, coefficient: Coefficient.megahertz)
        }
    }
    
    public class var kilohertz: UnitFrequency {
        get {
            return UnitFrequency(symbol: Symbol.kilohertz, coefficient: Coefficient.kilohertz)
        }
    }
    
    public class var hertz: UnitFrequency {
        get {
            return UnitFrequency(symbol: Symbol.hertz, coefficient: Coefficient.hertz)
        }
    }
    
    public class var millihertz: UnitFrequency {
        get {
            return UnitFrequency(symbol: Symbol.millihertz, coefficient: Coefficient.millihertz)
        }
    }
    
    public class var microhertz: UnitFrequency {
        get {
            return UnitFrequency(symbol: Symbol.microhertz, coefficient: Coefficient.microhertz)
        }
    }
    
    public class var nanohertz: UnitFrequency {
        get {
            return UnitFrequency(symbol: Symbol.nanohertz, coefficient: Coefficient.nanohertz)
        }
    }
    
    public override class func baseUnit() -> UnitFrequency {
        return .hertz
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitFrequency else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitFuelEfficiency : Dimension {
    
    /*
     Base unit - litersPer100Kilometers
     */
    
    private struct Symbol {
        static let litersPer100Kilometers   = "L/100km"
        static let milesPerImperialGallon   = "mpg"
        static let milesPerGallon           = "mpg"
    }
    
    private struct Coefficient {
        static let litersPer100Kilometers   = 1.0
        static let milesPerImperialGallon   = 282.481
        static let milesPerGallon           = 235.215
    }
    
    private convenience init(symbol: String, reciprocal: Double) {
        self.init(symbol: symbol, converter: NSUnitConverterReciprocal(reciprocal: reciprocal))
    }
    
    public class var litersPer100Kilometers: UnitFuelEfficiency {
        get {
            return UnitFuelEfficiency(symbol: Symbol.litersPer100Kilometers, reciprocal: Coefficient.litersPer100Kilometers)
        }
    }
    
    public class var milesPerImperialGallon: UnitFuelEfficiency {
        get {
            return UnitFuelEfficiency(symbol: Symbol.milesPerImperialGallon, reciprocal: Coefficient.milesPerImperialGallon)
        }
    }
    
    public class var milesPerGallon: UnitFuelEfficiency {
        get {
            return UnitFuelEfficiency(symbol: Symbol.milesPerGallon, reciprocal: Coefficient.milesPerGallon)
        }
    }
    
    public override class func baseUnit() -> UnitFuelEfficiency {
        return .litersPer100Kilometers
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitFuelEfficiency else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitLength : Dimension {
    
    /*
     Base unit - meters
     */
    
    private struct Symbol {
        static let megameters           = "Mm"
        static let kilometers           = "km"
        static let hectometers          = "hm"
        static let decameters           = "dam"
        static let meters               = "m"
        static let decimeters           = "dm"
        static let centimeters          = "cm"
        static let millimeters          = "mm"
        static let micrometers          = "µm"
        static let nanometers           = "nm"
        static let picometers           = "pm"
        static let inches               = "in"
        static let feet                 = "ft"
        static let yards                = "yd"
        static let miles                = "mi"
        static let scandinavianMiles    = "smi"
        static let lightyears           = "ly"
        static let nauticalMiles        = "NM"
        static let fathoms              = "ftm"
        static let furlongs             = "fur"
        static let astronomicalUnits    = "ua"
        static let parsecs              = "pc"
    }
    
    private struct Coefficient {
        static let megameters           = 1e6
        static let kilometers           = 1e3
        static let hectometers          = 1e2
        static let decameters           = 1e1
        static let meters               = 1.0
        static let decimeters           = 1e-1
        static let centimeters          = 1e-2
        static let millimeters          = 1e-3
        static let micrometers          = 1e-6
        static let nanometers           = 1e-9
        static let picometers           = 1e-12
        static let inches               = 0.0254
        static let feet                 = 0.3048
        static let yards                = 0.9144
        static let miles                = 1609.34
        static let scandinavianMiles    = 10000.0
        static let lightyears           = 9.461e+15
        static let nauticalMiles        = 1852.0
        static let fathoms              = 1.8288
        static let furlongs             = 201.168
        static let astronomicalUnits    = 1.496e+11
        static let parsecs              = 3.086e+16
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var megameters: UnitLength {
        get {
            return UnitLength(symbol: Symbol.megameters, coefficient: Coefficient.megameters)
        }
    }
    
    public class var kilometers: UnitLength {
        get {
            return UnitLength(symbol: Symbol.kilometers, coefficient: Coefficient.kilometers)
        }
    }
    
    public class var hectometers: UnitLength {
        get {
            return UnitLength(symbol: Symbol.hectometers, coefficient: Coefficient.hectometers)
        }
    }
    
    public class var decameters: UnitLength {
        get {
            return UnitLength(symbol: Symbol.decameters, coefficient: Coefficient.decameters)
        }
    }
    
    public class var meters: UnitLength {
        get {
            return UnitLength(symbol: Symbol.meters, coefficient: Coefficient.meters)
        }
    }
    
    public class var decimeters: UnitLength {
        get {
            return UnitLength(symbol: Symbol.decimeters, coefficient: Coefficient.decimeters)
        }
    }
    
    public class var centimeters: UnitLength {
        get {
            return UnitLength(symbol: Symbol.centimeters, coefficient: Coefficient.centimeters)
        }
    }
    
    public class var millimeters: UnitLength {
        get {
            return UnitLength(symbol: Symbol.millimeters, coefficient: Coefficient.millimeters)
        }
    }
    
    public class var micrometers: UnitLength {
        get {
            return UnitLength(symbol: Symbol.micrometers, coefficient: Coefficient.micrometers)
        }
    }
    
    public class var nanometers: UnitLength {
        get {
            return UnitLength(symbol: Symbol.nanometers, coefficient: Coefficient.nanometers)
        }
    }
    
    public class var picometers: UnitLength {
        get {
            return UnitLength(symbol: Symbol.picometers, coefficient: Coefficient.picometers)
        }
    }
    
    public class var inches: UnitLength {
        get {
            return UnitLength(symbol: Symbol.inches, coefficient: Coefficient.inches)
        }
    }
    
    public class var feet: UnitLength {
        get {
            return UnitLength(symbol: Symbol.feet, coefficient: Coefficient.feet)
        }
    }
    
    public class var yards: UnitLength {
        get {
            return UnitLength(symbol: Symbol.yards, coefficient: Coefficient.yards)
        }
    }
    
    public class var miles: UnitLength {
        get {
            return UnitLength(symbol: Symbol.miles, coefficient: Coefficient.miles)
        }
    }
    
    public class var scandinavianMiles: UnitLength {
        get {
            return UnitLength(symbol: Symbol.scandinavianMiles, coefficient: Coefficient.scandinavianMiles)
        }
    }
    
    public class var lightyears: UnitLength {
        get {
            return UnitLength(symbol: Symbol.lightyears, coefficient: Coefficient.lightyears)
        }
    }
    
    public class var nauticalMiles: UnitLength {
        get {
            return UnitLength(symbol: Symbol.nauticalMiles, coefficient: Coefficient.nauticalMiles)
        }
    }
    
    public class var fathoms: UnitLength {
        get {
            return UnitLength(symbol: Symbol.fathoms, coefficient: Coefficient.fathoms)
        }
    }
    
    public class var furlongs: UnitLength {
        get {
            return UnitLength(symbol: Symbol.furlongs, coefficient: Coefficient.furlongs)
        }
    }
    
    public class var astronomicalUnits: UnitLength {
        get {
            return UnitLength(symbol: Symbol.astronomicalUnits, coefficient: Coefficient.astronomicalUnits)
        }
    }
    
    public class var parsecs: UnitLength {
        get {
            return UnitLength(symbol: Symbol.parsecs, coefficient: Coefficient.parsecs)
        }
    }
    
    public override class func baseUnit() -> UnitLength {
        return .meters
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitLength else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitIlluminance : Dimension {
    
    /*
     Base unit - lux
     */
    
    private struct Symbol {
        static let lux   = "lx"
    }
    
    private struct Coefficient {
        static let lux   = 1.0
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var lux: UnitIlluminance {
        get {
            return UnitIlluminance(symbol: Symbol.lux, coefficient: Coefficient.lux)
        }
    }
    
    public override class func baseUnit() -> UnitIlluminance {
        return .lux
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitIlluminance else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitInformationStorage : Dimension {
    
    /*
     Base unit - bit
     */
    
    private struct Symbol {
        static let bytes        = "B"
        static let bits         = "bit"
        static let nibbles      = "nibble"
        static let yottabytes   = "YB"
        static let zettabytes   = "ZB"
        static let exabytes     = "EB"
        static let petabytes    = "PB"
        static let terabytes    = "TB"
        static let gigabytes    = "GB"
        static let megabytes    = "MB"
        static let kilobytes    = "kB"

        static let yottabits    = "Yb"
        static let zettabits    = "Zb"
        static let exabits      = "Eb"
        static let petabits     = "Pb"
        static let terabits     = "Tb"
        static let gigabits     = "Gb"
        static let megabits     = "Mb"
        static let kilobits     = "kb"
        
        static let yobibytes    = "YiB"
        static let zebibytes    = "ZiB"
        static let exbibytes    = "EiB"
        static let pebibytes    = "PiB"
        static let tebibytes    = "TiB"
        static let gibibytes    = "GiB"
        static let mebibytes    = "MiB"
        static let kibibytes    = "KiB"
        
        static let yobibits     = "Yib"
        static let zebibits     = "Zib"
        static let exbibits     = "Eib"
        static let pebibits     = "Pib"
        static let tebibits     = "Tib"
        static let gibibits     = "Gib"
        static let mebibits     = "Mib"
        static let kibibits     = "Kib"
    }
    
    private struct Coefficient {
        static let bytes        = 8.0
        static let bits         = 1.0
        static let nibbles      = 4.0
        static let yottabytes   = 8.0*pow(1000.0, 8.0)
        static let zettabytes   = 8.0*pow(1000.0, 7.0)
        static let exabytes     = 8.0*pow(1000.0, 6.0)
        static let petabytes    = 8.0*pow(1000.0, 5.0)
        static let terabytes    = 8.0*pow(1000.0, 4.0)
        static let gigabytes    = 8.0*pow(1000.0, 3.0)
        static let megabytes    = 8.0*pow(1000.0, 2.0)
        static let kilobytes    = 8.0*1000

        static let yottabits    = pow(1000.0, 8.0)
        static let zettabits    = pow(1000.0, 7.0)
        static let exabits      = pow(1000.0, 6.0)
        static let petabits     = pow(1000.0, 5.0)
        static let terabits     = pow(1000.0, 4.0)
        static let gigabits     = pow(1000.0, 3.0)
        static let megabits     = pow(1000.0, 2.0)
        static let kilobits     = 1000.0
        
        static let yobibytes    = 8*pow(1024.0, 8.0)
        static let zebibytes    = 8*pow(1024.0, 7.0)
        static let exbibytes    = 8*pow(1024.0, 6.0)
        static let pebibytes    = 8*pow(1024.0, 5.0)
        static let tebibytes    = 8*pow(1024.0, 4.0)
        static let gibibytes    = 8*pow(1024.0, 3.0)
        static let mebibytes    = 8*pow(1024.0, 2.0)
        static let kibibytes    = 8*1024.0
        
        static let yobibits     = pow(1024.0, 8.0)
        static let zebibits     = pow(1024.0, 7.0)
        static let exbibits     = pow(1024.0, 6.0)
        static let pebibits     = pow(1024.0, 5.0)
        static let tebibits     = pow(1024.0, 4.0)
        static let gibibits     = pow(1024.0, 3.0)
        static let mebibits     = pow(1024.0, 2.0)
        static let kibibits     = 1024.0
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var bytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.bytes, coefficient: Coefficient.bytes)
        }
    }
    
    public class var bits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.bits, coefficient: Coefficient.bits)
        }
    }
    
    public class var nibbles: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.nibbles, coefficient: Coefficient.nibbles)
        }
    }
    
    public class var yottabytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.yottabytes, coefficient: Coefficient.yottabytes)
        }
    }
    
    public class var zettabytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.zettabytes, coefficient: Coefficient.zettabytes)
        }
    }
    
    public class var exabytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.exabytes, coefficient: Coefficient.exabytes)
        }
    }
    
    public class var petabytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.petabytes, coefficient: Coefficient.petabytes)
        }
    }
    
    public class var terabytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.terabytes, coefficient: Coefficient.terabytes)
        }
    }
    
    public class var gigabytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.gigabytes, coefficient: Coefficient.gigabytes)
        }
    }
    
    public class var megabytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.megabytes, coefficient: Coefficient.megabytes)
        }
    }
    
    public class var kilobytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.kilobytes, coefficient: Coefficient.kilobytes)
        }
    }
    
    public class var yottabits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.yottabits, coefficient: Coefficient.yottabits)
        }
    }
    
    public class var zettabits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.zettabits, coefficient: Coefficient.zettabits)
        }
    }
    
    public class var exabits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.exabits, coefficient: Coefficient.exabits)
        }
    }
    
    public class var petabits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.petabits, coefficient: Coefficient.petabits)
        }
    }
    
    public class var terabits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.terabits, coefficient: Coefficient.terabits)
        }
    }
    
    public class var gigabits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.gigabits, coefficient: Coefficient.gigabits)
        }
    }
    
    public class var megabits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.megabits, coefficient: Coefficient.megabits)
        }
    }
    
    public class var kilobits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.kilobits, coefficient: Coefficient.kilobits)
        }
    }
    
    public class var yobibytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.yobibytes, coefficient: Coefficient.yobibytes)
        }
    }
    
    public class var zebibytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.zebibytes, coefficient: Coefficient.zebibytes)
        }
    }
    
    public class var exbibytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.exbibytes, coefficient: Coefficient.exbibytes)
        }
    }
    
    public class var pebibytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.pebibytes, coefficient: Coefficient.pebibytes)
        }
    }
    
    public class var tebibytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.tebibytes, coefficient: Coefficient.tebibytes)
        }
    }
    
    public class var gibibytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.gibibytes, coefficient: Coefficient.gibibytes)
        }
    }
    
    public class var mebibytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.mebibytes, coefficient: Coefficient.mebibytes)
        }
    }
    
    public class var kibibytes: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.kibibytes, coefficient: Coefficient.kibibytes)
        }
    }
    
    public class var yobibits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.yobibits, coefficient: Coefficient.yobibits)
        }
    }
    
    public class var zebibits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.zebibits, coefficient: Coefficient.zebibits)
        }
    }
    
    public class var exbibits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.exbibits, coefficient: Coefficient.exbibits)
        }
    }
    
    public class var pebibits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.pebibits, coefficient: Coefficient.pebibits)
        }
    }
    
    public class var tebibits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.tebibits, coefficient: Coefficient.tebibits)
        }
    }
    
    public class var gibibits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.gibibits, coefficient: Coefficient.gibibits)
        }
    }
    
    public class var mebibits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.mebibits, coefficient: Coefficient.mebibits)
        }
    }
    
    public class var kibibits: UnitInformationStorage {
        get {
            return UnitInformationStorage(symbol: Symbol.kibibits, coefficient: Coefficient.kibibits)
        }
    }
    
    public override class func baseUnit() -> UnitInformationStorage {
        return .bits
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitInformationStorage else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitMass : Dimension {
    
    /*
     Base unit - kilograms
     */
    
    private struct Symbol {
        static let kilograms    = "kg"
        static let grams        = "g"
        static let decigrams    = "dg"
        static let centigrams   = "cg"
        static let milligrams   = "mg"
        static let micrograms   = "µg"
        static let nanograms    = "ng"
        static let picograms    = "pg"
        static let ounces       = "oz"
        static let pounds       = "lb"
        static let stones       = "st"
        static let metricTons   = "t"
        static let shortTons    = "ton"
        static let carats       = "ct"
        static let ouncesTroy   = "oz t"
        static let slugs        = "slug"
    }
    
    private struct Coefficient {
        static let kilograms    = 1.0
        static let grams        = 1e-3
        static let decigrams    = 1e-4
        static let centigrams   = 1e-5
        static let milligrams   = 1e-6
        static let micrograms   = 1e-9
        static let nanograms    = 1e-12
        static let picograms    = 1e-15
        static let ounces       = 0.0283495
        static let pounds       = 0.45359237
        static let stones       = 0.157473
        static let metricTons   = 1000.0
        static let shortTons    = 907.185
        static let carats       = 0.0002
        static let ouncesTroy   = 0.03110348
        static let slugs        = 14.5939
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var kilograms: UnitMass {
        get {
            return UnitMass(symbol: Symbol.kilograms, coefficient: Coefficient.kilograms)
        }
    }
    
    public class var grams: UnitMass {
        get {
            return UnitMass(symbol: Symbol.grams, coefficient: Coefficient.grams)
        }
    }
    
    public class var decigrams: UnitMass {
        get {
            return UnitMass(symbol: Symbol.decigrams, coefficient: Coefficient.decigrams)
        }
    }
    
    public class var centigrams: UnitMass {
        get {
            return UnitMass(symbol: Symbol.centigrams, coefficient: Coefficient.centigrams)
        }
    }
    
    public class var milligrams: UnitMass {
        get {
            return UnitMass(symbol: Symbol.milligrams, coefficient: Coefficient.milligrams)
        }
    }
    
    public class var micrograms: UnitMass {
        get {
            return UnitMass(symbol: Symbol.micrograms, coefficient: Coefficient.micrograms)
        }
    }
    
    public class var nanograms: UnitMass {
        get {
            return UnitMass(symbol: Symbol.nanograms, coefficient: Coefficient.nanograms)
        }
    }
    
    public class var picograms: UnitMass {
        get {
            return UnitMass(symbol: Symbol.picograms, coefficient: Coefficient.picograms)
        }
    }
    
    public class var ounces: UnitMass {
        get {
            return UnitMass(symbol: Symbol.ounces, coefficient: Coefficient.ounces)
        }
    }
    
    public class var pounds: UnitMass {
        get {
            return UnitMass(symbol: Symbol.pounds, coefficient: Coefficient.pounds)
        }
    }
    
    public class var stones: UnitMass {
        get {
            return UnitMass(symbol: Symbol.stones, coefficient: Coefficient.stones)
        }
    }
    
    public class var metricTons: UnitMass {
        get {
            return UnitMass(symbol: Symbol.metricTons, coefficient: Coefficient.metricTons)
        }
    }
    
    public class var shortTons: UnitMass {
        get {
            return UnitMass(symbol: Symbol.shortTons, coefficient: Coefficient.shortTons)
        }
    }
    
    public class var carats: UnitMass {
        get {
            return UnitMass(symbol: Symbol.carats, coefficient: Coefficient.carats)
        }
    }
    
    public class var ouncesTroy: UnitMass {
        get {
            return UnitMass(symbol: Symbol.ouncesTroy, coefficient: Coefficient.ouncesTroy)
        }
    }
    
    public class var slugs: UnitMass {
        get {
            return UnitMass(symbol: Symbol.slugs, coefficient: Coefficient.slugs)
        }
    }
    
    public override class func baseUnit() -> UnitMass {
        return .kilograms
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitMass else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitPower : Dimension {
    
    /*
     Base unit - watts
     */
    
    private struct Symbol {
        static let terawatts  = "TW"
        static let gigawatts  = "GW"
        static let megawatts  = "MW"
        static let kilowatts  = "kW"
        static let watts      = "W"
        static let milliwatts = "mW"
        static let microwatts = "µW"
        static let nanowatts  = "nW"
        static let picowatts  = "pW"
        static let femtowatts = "fW"
        static let horsepower = "hp"
    }
    
    private struct Coefficient {
        static let terawatts  = 1e12
        static let gigawatts  = 1e9
        static let megawatts  = 1e6
        static let kilowatts  = 1e3
        static let watts      = 1.0
        static let milliwatts = 1e-3
        static let microwatts = 1e-6
        static let nanowatts  = 1e-9
        static let picowatts  = 1e-12
        static let femtowatts = 1e-15
        static let horsepower = 745.7
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var terawatts: UnitPower {
        get {
            return UnitPower(symbol: Symbol.terawatts, coefficient: Coefficient.terawatts)
        }
    }
    
    public class var gigawatts: UnitPower {
        get {
            return UnitPower(symbol: Symbol.gigawatts, coefficient: Coefficient.gigawatts)
        }
    }
    
    public class var megawatts: UnitPower {
        get {
            return UnitPower(symbol: Symbol.megawatts, coefficient: Coefficient.megawatts)
        }
    }
    
    public class var kilowatts: UnitPower {
        get {
            return UnitPower(symbol: Symbol.kilowatts, coefficient: Coefficient.kilowatts)
        }
    }
    
    public class var watts: UnitPower {
        get {
            return UnitPower(symbol: Symbol.watts, coefficient: Coefficient.watts)
        }
    }
    
    public class var milliwatts: UnitPower {
        get {
            return UnitPower(symbol: Symbol.milliwatts, coefficient: Coefficient.milliwatts)
        }
    }
    
    public class var microwatts: UnitPower {
        get {
            return UnitPower(symbol: Symbol.microwatts, coefficient: Coefficient.microwatts)
        }
    }
    
    public class var nanowatts: UnitPower {
        get {
            return UnitPower(symbol: Symbol.nanowatts, coefficient: Coefficient.nanowatts)
        }
    }
    
    public class var picowatts: UnitPower {
        get {
            return UnitPower(symbol: Symbol.picowatts, coefficient: Coefficient.picowatts)
        }
    }
    
    public class var femtowatts: UnitPower {
        get {
            return UnitPower(symbol: Symbol.femtowatts, coefficient: Coefficient.femtowatts)
        }
    }
    
    public class var horsepower: UnitPower {
        get {
            return UnitPower(symbol: Symbol.horsepower, coefficient: Coefficient.horsepower)
        }
    }
    
    public override class func baseUnit() -> UnitPower {
        return .watts
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitPower else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitPressure : Dimension {
    
    /*
     Base unit - newtonsPerMetersSquared (equivalent to 1 pascal)
     */
    
    private struct Symbol {
        static let newtonsPerMetersSquared  = "N/m²"
        static let gigapascals              = "GPa"
        static let megapascals              = "MPa"
        static let kilopascals              = "kPa"
        static let hectopascals             = "hPa"
        static let inchesOfMercury          = "inHg"
        static let bars                     = "bar"
        static let millibars                = "mbar"
        static let millimetersOfMercury     = "mmHg"
        static let poundsForcePerSquareInch = "psi"
    }
    
    private struct Coefficient {
        static let newtonsPerMetersSquared  = 1.0
        static let gigapascals              = 1e9
        static let megapascals              = 1e6
        static let kilopascals              = 1e3
        static let hectopascals             = 1e2
        static let inchesOfMercury          = 3386.39
        static let bars                     = 1e5
        static let millibars                = 1e2
        static let millimetersOfMercury     = 133.322
        static let poundsForcePerSquareInch = 6894.76
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var newtonsPerMetersSquared: UnitPressure {
        get {
            return UnitPressure(symbol: Symbol.newtonsPerMetersSquared, coefficient: Coefficient.newtonsPerMetersSquared)
        }
    }
    
    public class var gigapascals: UnitPressure {
        get {
            return UnitPressure(symbol: Symbol.gigapascals, coefficient: Coefficient.gigapascals)
        }
    }
    
    public class var megapascals: UnitPressure {
        get {
            return UnitPressure(symbol: Symbol.megapascals, coefficient: Coefficient.megapascals)
        }
    }
    
    public class var kilopascals: UnitPressure {
        get {
            return UnitPressure(symbol: Symbol.kilopascals, coefficient: Coefficient.kilopascals)
        }
    }
    
    public class var hectopascals: UnitPressure {
        get {
            return UnitPressure(symbol: Symbol.hectopascals, coefficient: Coefficient.hectopascals)
        }
    }
    
    public class var inchesOfMercury: UnitPressure {
        get {
            return UnitPressure(symbol: Symbol.inchesOfMercury, coefficient: Coefficient.inchesOfMercury)
        }
    }
    
    public class var bars: UnitPressure {
        get {
            return UnitPressure(symbol: Symbol.bars, coefficient: Coefficient.bars)
        }
    }
    
    public class var millibars: UnitPressure {
        get {
            return UnitPressure(symbol: Symbol.millibars, coefficient: Coefficient.millibars)
        }
    }
    
    public class var millimetersOfMercury: UnitPressure {
        get {
            return UnitPressure(symbol: Symbol.millimetersOfMercury, coefficient: Coefficient.millimetersOfMercury)
        }
    }
    
    public class var poundsForcePerSquareInch: UnitPressure {
        get {
            return UnitPressure(symbol: Symbol.poundsForcePerSquareInch, coefficient: Coefficient.poundsForcePerSquareInch)
        }
    }
    
    public override class func baseUnit() -> UnitPressure {
        return .newtonsPerMetersSquared
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitPressure else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitSpeed : Dimension {
    
    /*
     Base unit - metersPerSecond
     */
    
    private struct Symbol {
        static let metersPerSecond      = "m/s"
        static let kilometersPerHour    = "km/h"
        static let milesPerHour         = "mph"
        static let knots                = "kn"
    }
    
    private struct Coefficient {
        static let metersPerSecond      = 1.0
        static let kilometersPerHour    = 0.277778
        static let milesPerHour         = 0.44704
        static let knots                = 0.514444
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var metersPerSecond: UnitSpeed {
        get {
            return UnitSpeed(symbol: Symbol.metersPerSecond, coefficient: Coefficient.metersPerSecond)
        }
    }
    
    public class var kilometersPerHour: UnitSpeed {
        get {
            return UnitSpeed(symbol: Symbol.kilometersPerHour, coefficient: Coefficient.kilometersPerHour)
        }
    }
    
    public class var milesPerHour: UnitSpeed {
        get {
            return UnitSpeed(symbol: Symbol.milesPerHour, coefficient: Coefficient.milesPerHour)
        }
    }
    
    public class var knots: UnitSpeed {
        get {
            return UnitSpeed(symbol: Symbol.knots, coefficient: Coefficient.knots)
        }
    }
    
    public override class func baseUnit() -> UnitSpeed {
        return .metersPerSecond
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitSpeed else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitTemperature : Dimension {
    
    /*
     Base unit - kelvin
     */
    
    private struct Symbol {
        static let kelvin     = "K"
        static let celsius    = "°C"
        static let fahrenheit = "°F"
    }
    
    private struct Coefficient {
        static let kelvin     = 1.0
        static let celsius    = 1.0
        static let fahrenheit = 0.55555555555556
    }
    
    private struct Constant {
        static let kelvin     = 0.0
        static let celsius    = 273.15
        static let fahrenheit = 255.37222222222427
    }
    
    private convenience init(symbol: String, coefficient: Double, constant: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient, constant: constant))
    }
    
    public class var kelvin: UnitTemperature {
        get {
            return UnitTemperature(symbol: Symbol.kelvin, coefficient: Coefficient.kelvin, constant: Constant.kelvin)
        }
    }
    
    public class var celsius: UnitTemperature {
        get {
            return UnitTemperature(symbol: Symbol.celsius, coefficient: Coefficient.celsius, constant: Constant.celsius)
        }
    }
    
    public class var fahrenheit: UnitTemperature {
        get {
            return UnitTemperature(symbol: Symbol.fahrenheit, coefficient: Coefficient.fahrenheit, constant: Constant.fahrenheit)
        }
    }
    
    public override class func baseUnit() -> UnitTemperature {
        return .kelvin
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitTemperature else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}

public final class UnitVolume : Dimension {
    
    /*
     Base unit - liters
     */
    
    private struct Symbol {
        static let megaliters           = "ML"
        static let kiloliters           = "kL"
        static let liters               = "L"
        static let deciliters           = "dl"
        static let centiliters          = "cL"
        static let milliliters          = "mL"
        static let cubicKilometers      = "km³"
        static let cubicMeters          = "m³"
        static let cubicDecimeters      = "dm³"
        static let cubicCentimeters     = "cm³"
        static let cubicMillimeters     = "mm³"
        static let cubicInches          = "in³"
        static let cubicFeet            = "ft³"
        static let cubicYards           = "yd³"
        static let cubicMiles           = "mi³"
        static let acreFeet             = "af"
        static let bushels              = "bsh"
        static let teaspoons            = "tsp"
        static let tablespoons          = "tbsp"
        static let fluidOunces          = "fl oz"
        static let cups                 = "cup"
        static let pints                = "pt"
        static let quarts               = "qt"
        static let gallons              = "gal"
        static let imperialTeaspoons    = "tsp Imperial"
        static let imperialTablespoons  = "tbsp Imperial"
        static let imperialFluidOunces  = "fl oz Imperial"
        static let imperialPints        = "pt Imperial"
        static let imperialQuarts       = "qt Imperial"
        static let imperialGallons      = "gal Imperial"
        static let metricCups           = "metric cup Imperial"
    }
    
    private struct Coefficient {
        static let megaliters           = 1e6
        static let kiloliters           = 1e3
        static let liters               = 1.0
        static let deciliters           = 1e-1
        static let centiliters          = 1e-2
        static let milliliters          = 1e-3
        static let cubicKilometers      = 1e12
        static let cubicMeters          = 1000.0
        static let cubicDecimeters      = 1.0
        static let cubicCentimeters     = 1e-3
        static let cubicMillimeters     = 1e-6
        static let cubicInches          = 0.0163871
        static let cubicFeet            = 28.3168
        static let cubicYards           = 764.555
        static let cubicMiles           = 4.168e+12
        static let acreFeet             = 1.233e+6
        static let bushels              = 35.2391
        static let teaspoons            = 0.00492892
        static let tablespoons          = 0.0147868
        static let fluidOunces          = 0.0295735
        static let cups                 = 0.24
        static let pints                = 0.473176
        static let quarts               = 0.946353
        static let gallons              = 3.78541
        static let imperialTeaspoons    = 0.00591939
        static let imperialTablespoons  = 0.0177582
        static let imperialFluidOunces  = 0.0284131
        static let imperialPints        = 0.568261
        static let imperialQuarts       = 1.13652
        static let imperialGallons      = 4.54609
        static let metricCups           = 0.25
    }
    
    private convenience init(symbol: String, coefficient: Double) {
        self.init(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }
    
    public class var megaliters: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.megaliters, coefficient: Coefficient.megaliters)
        }
    }
    
    public class var kiloliters: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.kiloliters, coefficient: Coefficient.kiloliters)
        }
    }
    
    public class var liters: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.liters, coefficient: Coefficient.liters)
        }
    }
    
    public class var deciliters: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.deciliters, coefficient: Coefficient.deciliters)
        }
    }
    
    public class var centiliters: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.centiliters, coefficient: Coefficient.centiliters)
        }
    }
    
    public class var milliliters: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.milliliters, coefficient: Coefficient.milliliters)
        }
    }
    
    public class var cubicKilometers: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.cubicKilometers, coefficient: Coefficient.cubicKilometers)
        }
    }
    
    public class var cubicMeters: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.cubicMeters, coefficient: Coefficient.cubicMeters)
        }
    }
    
    public class var cubicDecimeters: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.cubicDecimeters, coefficient: Coefficient.cubicDecimeters)
        }
    }
    
    public class var cubicCentimeters: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.cubicCentimeters, coefficient: Coefficient.cubicCentimeters)
        }
    }
    
    public class var cubicMillimeters: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.cubicMillimeters, coefficient: Coefficient.cubicMillimeters)
        }
    }
    
    public class var cubicInches: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.cubicInches, coefficient: Coefficient.cubicInches)
        }
    }
    
    public class var cubicFeet: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.cubicFeet, coefficient: Coefficient.cubicFeet)
        }
    }
    
    public class var cubicYards: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.cubicYards, coefficient: Coefficient.cubicYards)
        }
    }
    
    public class var cubicMiles: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.cubicMiles, coefficient: Coefficient.cubicMiles)
        }
    }
    
    public class var acreFeet: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.acreFeet, coefficient: Coefficient.acreFeet)
        }
    }
    
    public class var bushels: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.bushels, coefficient: Coefficient.bushels)
        }
    }
    
    public class var teaspoons: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.teaspoons, coefficient: Coefficient.teaspoons)
        }
    }
    
    public class var tablespoons: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.tablespoons, coefficient: Coefficient.tablespoons)
        }
    }
    
    public class var fluidOunces: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.fluidOunces, coefficient: Coefficient.fluidOunces)
        }
    }
    
    public class var cups: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.cups, coefficient: Coefficient.cups)
        }
    }
    
    public class var pints: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.pints, coefficient: Coefficient.pints)
        }
    }
    
    public class var quarts: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.quarts, coefficient: Coefficient.quarts)
        }
    }
    
    public class var gallons: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.gallons, coefficient: Coefficient.gallons)
        }
    }
    
    public class var imperialTeaspoons: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.imperialTeaspoons, coefficient: Coefficient.imperialTeaspoons)
        }
    }
    
    public class var imperialTablespoons: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.imperialTablespoons, coefficient: Coefficient.imperialTablespoons)
        }
    }
    
    public class var imperialFluidOunces: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.imperialFluidOunces, coefficient: Coefficient.imperialFluidOunces)
        }
    }
    
    public class var imperialPints: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.imperialPints, coefficient: Coefficient.imperialPints)
        }
    }
    
    public class var imperialQuarts: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.imperialQuarts, coefficient: Coefficient.imperialQuarts)
        }
    }
    
    public class var imperialGallons: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.imperialGallons, coefficient: Coefficient.imperialGallons)
        }
    }
    
    public class var metricCups: UnitVolume {
        get {
            return UnitVolume(symbol: Symbol.metricCups, coefficient: Coefficient.metricCups)
        }
    }
    
    public override class func baseUnit() -> UnitVolume {
        return .liters
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? UnitVolume else {
            return false
        }
        
        if self === other {
            return true
        }
        
        return super.isEqual(object)
    }
}
