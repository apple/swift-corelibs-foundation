// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


extension ByteCountFormatter {
    public struct Units : OptionSet {
        public let rawValue : UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        
        //  Specifying any of the following causes the specified units to be used in showing the number.
        public static let useBytes = Units(rawValue: 1 << 0)
        public static let useKB = Units(rawValue: 1 << 1)
        public static let useMB = Units(rawValue: 1 << 2)
        public static let useGB = Units(rawValue: 1 << 3)
        public static let useTB = Units(rawValue: 1 << 4)
        public static let usePB = Units(rawValue: 1 << 5)
        public static let useEB = Units(rawValue: 1 << 6)
        public static let useZB = Units(rawValue: 1 << 7)
        public static let useYBOrHigher = Units(rawValue: 0x0FF << 8)
        // Can use any unit in showing the number.
        public static let useAll = Units(rawValue: 0x0FFFF)
    }
    
    public enum CountStyle : Int {
        
        // Specifies display of file or storage byte counts. The actual behavior for this is platform-specific; on OS X 10.8, this uses the decimal style, but that may change over time.
        case file
        // Specifies display of memory byte counts. The actual behavior for this is platform-specific; on OS X 10.8, this uses the binary style, but that may change over time.
        case memory
        // The following two allow specifying the number of bytes for KB explicitly. It's better to use one of the above values in most cases.
        case decimal // 1000 bytes are shown as 1 KB
        case binary // 1024 bytes are shown as 1 KB
    }
}

open class ByteCountFormatter : Formatter {
    public override init() {
        super.init()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        precondition(coder.allowsKeyedCoding)
        
        if let context = Formatter.Context(rawValue: Int(coder.decodeInt32(forKey: "NSFormattingContext"))) {
            self.formattingContext = context
        }
        
        self.allowedUnits = Units(rawValue: UInt(coder.decodeInt32(forKey: "NSUnits")))
        
        if let countStyle = CountStyle(rawValue: Int(coder.decodeInt32(forKey: "NSKBSize"))) {
            self.countStyle = countStyle
        }
        
        self.zeroPadsFractionDigits = coder.decodeBool(forKey: "NSZeroPad")
        self.includesActualByteCount = coder.decodeBool(forKey: "NSActual")
        
        // These are written in the reverse sense
        self.allowsNonnumericFormatting = !coder.decodeBool(forKey: "NSNoNonnumeric")
        self.includesUnit = !coder.decodeBool(forKey: "NSNoUnit")
        self.includesCount = !coder.decodeBool(forKey: "NSNoCount")
        self.isAdaptive = !coder.decodeBool(forKey: "NSNoAdaptive")
    }

    open override func copy(with zone: NSZone? = nil) -> Any {
        let copied = ByteCountFormatter()
        copied.allowedUnits = allowedUnits
        copied.countStyle = countStyle
        copied.allowsNonnumericFormatting = allowsNonnumericFormatting
        copied.includesUnit = includesUnit
        copied.includesCount = includesCount
        copied.includesActualByteCount = includesActualByteCount
        copied.isAdaptive = isAdaptive
        copied.zeroPadsFractionDigits = zeroPadsFractionDigits
        copied.formattingContext = formattingContext
        copied.actualBytes = actualBytes
        copied.numberFormatter = numberFormatter.copy(with: zone) as? NumberFormatter ?? NumberFormatter()
        return copied
    }

    open override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        precondition(coder.allowsKeyedCoding)
        
        // The following have 0 as a sentinel raw value, so check
        if self.allowedUnits.rawValue != 0 {
            coder.encode(Int32(self.allowedUnits.rawValue), forKey: "NSUnits")
        }
        if self.countStyle.rawValue != 0 {
            coder.encode(Int32(self.countStyle.rawValue), forKey: "NSKBSize")
        }
        if self.formattingContext.rawValue != 0 {
            coder.encode(Int32(self.formattingContext.rawValue), forKey: "NSFormattingContext")
        }
        
        if self.zeroPadsFractionDigits {
            coder.encode(true, forKey: "NSZeroPad")
        }
        if self.includesActualByteCount {
            coder.encode(true, forKey: "NSActual")
        }
        
        // The following have true as their default values, so check and write the reverse sense
        if !self.allowsNonnumericFormatting {
            coder.encode(true, forKey: "NSNoNonnumeric")
        }
        if !self.includesUnit {
            coder.encode(true, forKey: "NSNoUnit")
        }
        if !self.includesCount {
            coder.encode(true, forKey: "NSNoCount")
        }
        if !self.isAdaptive {
            coder.encode(true, forKey: "NSNoAdaptive")
        }
    }
    
    /* Specify the units that can be used in the output. If ByteCountFormatter.Units is empty, uses platform-appropriate settings; otherwise will only use the specified units. This is the default value. Note that ZB and YB cannot be covered by the range of possible values, but you can still choose to use these units to get fractional display ("0.0035 ZB" for instance).
     */
    open var allowedUnits: Units = []
    
    /* Specify how the count is displayed by indicating the number of bytes to be used for kilobyte. The default setting is ByteCountFormatter.CountStyle.fileCount, which is the system specific value for file and storage sizes.
     */
    open var countStyle: CountStyle = .file
    
    /* Choose whether to allow more natural display of some values, such as zero, where it may be displayed as "Zero KB," ignoring all other flags or options (with the exception of ByteCountFormatter.Units.useBytes, which would generate "Zero bytes"). The result is appropriate for standalone output. Default value is YES. Special handling of certain values such as zero is especially important in some languages, so it's highly recommended that this property be left in its default state.
     */
    open var allowsNonnumericFormatting: Bool = true
    
    /* Choose whether to include the number or the units in the resulting formatted string. (For example, instead of 723 KB, returns "723" or "KB".) You can call the API twice to get both parts, separately. But note that putting them together yourself via string concatenation may be wrong for some locales; so use this functionality with care.  Both of these values are YES by default.  Setting both to NO will unsurprisingly result in an empty string.
     */
    open var includesUnit: Bool = true
    open var includesCount: Bool = true
    
    /* Choose whether to parenthetically (localized as appropriate) display the actual number of bytes as well, for instance "723 KB (722,842 bytes)".  This will happen only if needed, that is, the first part is already not showing the exact byte count.  If includesUnit or includesCount are NO, then this setting has no effect.  Default value is NO.
     */
    open var includesActualByteCount: Bool = false
    
    /* Choose the display style. The "adaptive" algorithm is platform specific and uses a different number of fraction digits based on the magnitude (in 10.8: 0 fraction digits for bytes and KB; 1 fraction digits for MB; 2 for GB and above). Otherwise the result always tries to show at least three significant digits, introducing fraction digits as necessary. Default is YES.
     */
    open var isAdaptive: Bool = true
    
    /* Choose whether to zero pad fraction digits so a consistent number of fraction digits are displayed, causing updating displays to remain more stable. For instance, if the adaptive algorithm is used, this option formats 1.19 and 1.2 GB as "1.19 GB" and "1.20 GB" respectively, while without the option the latter would be displayed as "1.2 GB". Default value is NO.
     */
    open var zeroPadsFractionDigits: Bool = false
    
    /* Specify the formatting context for the formatted string. Default is NSFormattingContextUnknown.
     */
    open var formattingContext: Context = .unknown
    
    /* A variable to store the actual bytes passed into the methods. This value is used if the includesActualByteCount property is set.
     */
    private var actualBytes: String = ""
    
    /* Create an instance of NumberFormatter for use in various methods
     */
    private var numberFormatter = NumberFormatter()
    
    /* Shortcut for converting a byte count into a string without creating an ByteCountFormatter and an NSNumber. If you need to specify options other than countStyle, create an instance of ByteCountFormatter first.
     */
    open class func string(fromByteCount byteCount: Int64, countStyle: ByteCountFormatter.CountStyle) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = countStyle
        return formatter.string(fromByteCount: byteCount)
    }
    
    /* Convenience method on string(for:):. Convert a byte count into a string without creating an NSNumber.
     */
    open func string(fromByteCount byteCount: Int64) -> String {
        //Convert actual bytes to a formatted string for use later
        numberFormatter.numberStyle = .decimal
        actualBytes = numberFormatter.string(from: NSNumber(value: byteCount))!

        if countStyle == .decimal || countStyle == .file {
            return convertValue(fromByteCount: byteCount, for: decimalByteSize)
        } else {
            return convertValue(fromByteCount: byteCount, for: binaryByteSize)
        }
    }
    
    /* Convenience method on string(for:):. Convert a byte count into a string without creating an NSNumber.
     */
    open override func string(for obj: Any?) -> String? {
        guard let value = obj as? Double else {
            return nil
        }
        
        return string(fromByteCount: Int64(value))
    }
    
    /* This method accepts a byteCount and a byteSize value. Checks to see what range the byteCount falls into and then converts to the units determined by that range. The range to be used is decided by the byteSize parameter. The conversion is done by making use of the divide method.
     */
    private func convertValue(fromByteCount byteCount: Int64, for byteSize: [Unit: Double]) -> String {
        let byte = Double(byteCount)
        if byte == 0, allowsNonnumericFormatting, allowedUnits == [], includesUnit, includesCount {
            return partsToIncludeFor(value: "Zero", unit: .KB)
        } else if allowedUnits.contains(.useAll) || allowedUnits == [] {
            if byte == 1 || byte == -1 {
                return formatNumberFor(bytes: byte, unit: .byte)
            } else if byte < byteSize[.KB]! && byte > -byteSize[.KB]! {
                return formatNumberFor(bytes: byte, unit: .bytes)
            } else if byte < byteSize[.MB]! && byte > -byteSize[.MB]! {
                return divide(byte, by: byteSize, for: .KB)
            } else if byte < byteSize[.GB]! && byte > -byteSize[.GB]! {
                return divide(byte, by: byteSize, for: .MB)
            } else if byte < byteSize[.TB]! && byte > -byteSize[.TB]! {
                return divide(byte, by: byteSize, for: .GB)
            } else if byte < byteSize[.PB]! && byte > -byteSize[.PB]! {
                return divide(byte, by: byteSize, for: .TB)
            } else if byte < byteSize[.EB]! && byte > -byteSize[.EB]! {
                return divide(byte, by: byteSize, for: .PB)
            } else {
                return divide(byte, by: byteSize, for: .EB)
            }
        }

        return valueToUseFor(byteCount: byte, unit: allowedUnits)
    }
    
    /*
        A helper method to deal with the Option Set, caters for setting an individual value or passing in an array of values.
        Returns the correct value based on the units that are allowed for use.
    */
    private func valueToUseFor(byteCount: Double, unit: ByteCountFormatter.Units) -> String {
        var byteSize: [Unit: Double]
        
        //Check to see whether we're using 1000bytes per KB or 1024 per KB
        if countStyle == .decimal || countStyle == .file {
            byteSize = decimalByteSize
        } else {
            byteSize = binaryByteSize
        }
        if byteCount == 0,  allowsNonnumericFormatting, includesCount, includesUnit {
            return partsToIncludeFor(value: "Zero", unit: .KB)
        }
        //Handles the cases where allowedUnits is set to a specific individual value. e.g. allowedUnits = .useTB
        switch allowedUnits {
        case .useBytes: return partsToIncludeFor(value: actualBytes, unit: .bytes)
        case .useKB: return divide(byteCount, by: byteSize, for: .KB)
        case .useMB: return divide(byteCount, by: byteSize, for: .MB)
        case .useGB: return divide(byteCount, by: byteSize, for: .GB)
        case .useTB: return divide(byteCount, by: byteSize, for: .TB)
        case .usePB: return divide(byteCount, by: byteSize, for: .PB)
        case .useEB: return divide(byteCount, by: byteSize, for: .EB)
        case .useZB: return divide(byteCount, by: byteSize, for: .ZB)
        case .useYBOrHigher: return divide(byteCount, by: byteSize, for: .YB)
        default: break
        }
        
        //Initialise an array that will hold all the units we can use
        var unitsToUse: [Unit] = []
        
        //Based on what units have been selected for use, build an array out of them.
        if unit.contains(.useBytes) && byteCount == 1 {
            unitsToUse.append(.byte)
        } else if unit.contains(.useBytes) {
            unitsToUse.append(.bytes)
        }
        if unit.contains(.useKB) {
            unitsToUse.append(.KB)
        }
        if unit.contains(.useMB) {
            unitsToUse.append(.MB)
        }
        if unit.contains(.useGB) {
            unitsToUse.append(.GB)
        }
        if unit.contains(.useTB) {
            unitsToUse.append(.TB)
        }
        if unit.contains(.usePB) {
            unitsToUse.append(.PB)
        }
        if unit.contains(.useEB) {
            unitsToUse.append(.EB)
        }
        if unit.contains(.useZB) {
            unitsToUse.append(.ZB)
        }
        if unit.contains(.useYBOrHigher) {
            unitsToUse.append(.YB)
        }
        
        
        var counter = 0
        for _ in unitsToUse {
            counter += 1
            if counter > unitsToUse.count - 1 {
                counter = unitsToUse.count - 1
            }
            /*
                The units are appended to the array in ascending order, so if the value for byteCount is smaller than the byteSize value of the next unit
                in the Array we use the previous unit. e.g. if byteCount = 1000, and AllowedUnits = [.useKB, .useGB] check to see if byteCount is smaller
                than a GB in bytes(pow(1000, 3)) and if so, we'll use the previous unit which is KB in this case. 
            */
            if byteCount < byteSize[unitsToUse[counter]]! {
                return divide(byteCount, by: byteSize, for: unitsToUse[counter - 1])
            }
        }
        return divide(byteCount, by: byteSize, for: unitsToUse[counter])
    }
    
    // Coverts the number of bytes to the correct value given a specified unit, then passes the value and unit to formattedValue
    private func divide(_ bytes: Double, by byteSize: [Unit: Double], for unit: Unit) -> String {
        guard let byteSizeUnit = byteSize[unit] else {
            fatalError("Cannot find value \(unit)")
        }
        let result = bytes/byteSizeUnit
        return formatNumberFor(bytes: result, unit: unit)
    }
    
    //Formats the byte value using the NumberFormatter class based on set properties and the unit passed in as a parameter.
    private func formatNumberFor(bytes: Double, unit: Unit) -> String {
        
        switch (zeroPadsFractionDigits, isAdaptive) {
        //zeroPadsFractionDigits is true, isAdaptive is true
        case (true, true):
            switch unit {
            case .bytes, .byte, .KB:
                let result = String(format: "%.0f", bytes)
                return partsToIncludeFor(value: result, unit: unit)
            case .MB:
                let result = String(format: "%.1f", bytes)
                return partsToIncludeFor(value: result, unit: unit)
            default:
                let result = String(format: "%.2f", bytes)
                return partsToIncludeFor(value: result, unit: unit)
            }
        //zeroPadsFractionDigits is true, isAdaptive is false
        case (true, false):
            if unit == .byte || unit == .bytes {
                numberFormatter.maximumFractionDigits = 0
                let result = numberFormatter.string(from: NSNumber(value: bytes))
                return partsToIncludeFor(value: result!, unit: unit)
            } else {
                if lengthOfInt(number: Int(bytes)) == 3 {
                    numberFormatter.usesSignificantDigits = false
                    numberFormatter.maximumFractionDigits = 0
                } else {
                    numberFormatter.maximumSignificantDigits = 3
                    numberFormatter.minimumSignificantDigits = 3
                }
                let result = numberFormatter.string(from: NSNumber(value: bytes))
                return partsToIncludeFor(value: result!, unit: unit)
            }
        //zeroPadsFractionDigits is false, isAdaptive is true
        case (false, true):
            switch unit {
            case .bytes, .byte, .KB:
                numberFormatter.minimumFractionDigits = 0
                numberFormatter.maximumFractionDigits = 0
                let result = numberFormatter.string(from: NSNumber(value: bytes))
                return partsToIncludeFor(value: result!, unit: unit)
            case .MB:
                numberFormatter.minimumFractionDigits = 0
                numberFormatter.maximumFractionDigits = 1
                let result = numberFormatter.string(from: NSNumber(value: bytes))
                return partsToIncludeFor(value: result!, unit: unit)
            default:
                let result: String
                //Need to add in an extra case for negative numbers as NumberFormatter formats 0.005 to 0 rather than
                // 0.01
                numberFormatter.minimumFractionDigits = 0
                numberFormatter.maximumFractionDigits = 2
                if bytes < 0 {
                    let negBytes = round(bytes * 100) / 100
                    result = numberFormatter.string(from: NSNumber(value: negBytes))!
                } else {
                    result = numberFormatter.string(from: NSNumber(value: bytes))!
                }
                return partsToIncludeFor(value: result, unit: unit)
            }
        //zeroPadsFractionDigits is false, isAdaptive is false
        case (false, false):
            if unit == .byte || unit == .bytes {
                numberFormatter.minimumFractionDigits = 0
                numberFormatter.maximumFractionDigits = 0
                let result = numberFormatter.string(from: NSNumber(value: bytes))
                return partsToIncludeFor(value: result!, unit: unit)
            } else {
                if lengthOfInt(number: Int(bytes)) > 3 {
                    numberFormatter.maximumFractionDigits = 0
                } else {
                    numberFormatter.maximumSignificantDigits = 3
                }
                let result = numberFormatter.string(from: NSNumber(value: bytes))
                return partsToIncludeFor(value: result!, unit: unit)
            }
        }
    }
    
    // A helper method to return the length of an int
    private func lengthOfInt(number: Int) -> Int {
        guard number != 0 else {
            return 1
        }
        var num = abs(number)
        var length = 0
        
        while num > 0 {
            length += 1
            num /= 10
        }
        return length
    }
    
    // Returns the correct string based on the includesValue and includesUnit properties
    private func partsToIncludeFor(value: String, unit: Unit) -> String {
        if includesActualByteCount, includesUnit, includesCount {
            switch unit {
            case .byte, .bytes: return "\(value) \(unit)"
            default: return "\(value) \(unit) (\(actualBytes) \(Unit.bytes))"
            }
        } else if includesCount, includesUnit {
            return "\(value) \(unit)"
        } else if includesCount, !includesUnit {
            if value == "Zero", allowedUnits == [] {
                return "0"
            } else {
                return value
            }
        } else if !includesCount, includesUnit {
            return "\(unit)"
        } else {
            return ""
        }
    }
    
    //Enum containing available byte units
    private enum Unit: String {
        case byte
        case bytes
        case KB
        case MB
        case GB
        case TB
        case PB
        case EB
        case ZB
        case YB
    }
    // Maps each unit to it's corresponding value in bytes for decimal
    private let decimalByteSize: [Unit: Double] = [.byte: 1, .bytes: 1, .KB: 1000, .MB: pow(1000, 2), .GB: pow(1000, 3), .TB: pow(1000, 4), .PB: pow(1000, 5), .EB: pow(1000, 6), .ZB: pow(1000, 7), .YB: pow(1000, 8)]
    
    // Maps each unit to it's corresponding value in bytes for binary
    private let binaryByteSize: [Unit: Double] = [.byte: 1, .bytes: 1, .KB: 1024, .MB: pow(1024, 2), .GB: pow(1024, 3), .TB: pow(1024, 4), .PB: pow(1024, 5), .EB: pow(1024, 6), .ZB: pow(1024, 7), .YB: pow(1024, 8)]
    
}
