// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


// NSURLQueryItem encapsulates a single query name-value pair. The name and value strings of a query name-value pair are not percent encoded. For use with the NSURLComponents queryItems property.
open class NSURLQueryItem: NSObject, NSSecureCoding, NSCopying {

    open private(set) var name: String
    open private(set) var value: String?

    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }

    open override func copy() -> Any {
        return copy(with: nil)
    }

    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }

    open override var hash: Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(value)
        return hasher.finalize()
    }

    public static var supportsSecureCoding: Bool {
        return true
    }

    required public init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }

        let encodedName = aDecoder.decodeObject(forKey: "NS.name") as! NSString
        self.name = encodedName._swiftObject

        let encodedValue = aDecoder.decodeObject(forKey: "NS.value") as? NSString
        self.value = encodedValue?._swiftObject
    }

    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }

        aCoder.encode(self.name._bridgeToObjectiveC(), forKey: "NS.name")
        aCoder.encode(self.value?._bridgeToObjectiveC(), forKey: "NS.value")
    }

    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? NSURLQueryItem else { return false }
        return other === self
                || (other.name == self.name
                    && other.value == self.value)
    }
}

extension NSURLQueryItem: _StructTypeBridgeable {
    public typealias _StructType = URLQueryItem

    public func _bridgeToSwift() -> _StructType {
        return _StructType._unconditionallyBridgeFromObjectiveC(self)
    }
}
