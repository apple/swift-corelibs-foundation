// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


@_implementationOnly import CoreFoundation

open class NSUUID : NSObject, NSCopying, NSSecureCoding, NSCoding {
    internal var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 16)

    deinit {
         buffer.deinitialize(count: 1)
         buffer.deallocate()
    }
    
    public override init() {
        _cf_uuid_generate_random(buffer)
    }
    
    public convenience init?(uuidString string: String) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 16)
        defer {
            buffer.deinitialize(count: 1)
            buffer.deallocate()
        }
        if _cf_uuid_parse(string, buffer) != 0 {
            return nil
        }
        self.init(uuidBytes: buffer)
    }
    
    public init(uuidBytes bytes: UnsafePointer<UInt8>) {
        memcpy(UnsafeMutableRawPointer(buffer), UnsafeRawPointer(bytes), 16)
    }
    
    open func getBytes(_ uuid: UnsafeMutablePointer<UInt8>) {
        _cf_uuid_copy(uuid, buffer)
    }
    
    open var uuidString: String {
        let strPtr = UnsafeMutablePointer<Int8>.allocate(capacity: 37)
        defer {
            strPtr.deinitialize(count: 1)
            strPtr.deallocate()
        }
        _cf_uuid_unparse_upper(buffer, strPtr)
        return String(cString: strPtr)
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    public convenience required init?(coder: NSCoder) {
        guard coder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        let decodedData : Data? = coder.withDecodedUnsafeBufferPointer(forKey: "NS.uuidbytes") {
            guard let buffer = $0 else { return nil }
            return Data(buffer: buffer)
        }

        guard let data = decodedData else { return nil }
        guard data.count == 16 else { return nil }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 16)
        defer {
            buffer.deinitialize(count: 1)
            buffer.deallocate()
        }
        data.copyBytes(to: buffer, count: 16)
        self.init(uuidBytes: buffer)
    }
    
    open func encode(with aCoder: NSCoder) {
        aCoder.encodeBytes(buffer, length: 16, forKey: "NS.uuidbytes")
    }
    
    open override func isEqual(_ value: Any?) -> Bool {
        switch value {
        case let other as UUID:
            return other.uuid.0 == buffer[0] &&
                other.uuid.1 == buffer[1] &&
                other.uuid.2 == buffer[2] &&
                other.uuid.3 == buffer[3] &&
                other.uuid.4 == buffer[4] &&
                other.uuid.5 == buffer[5] &&
                other.uuid.6 == buffer[6] &&
                other.uuid.7 == buffer[7] &&
                other.uuid.8 == buffer[8] &&
                other.uuid.9 == buffer[9] &&
                other.uuid.10 == buffer[10] &&
                other.uuid.11 == buffer[11] &&
                other.uuid.12 == buffer[12] &&
                other.uuid.13 == buffer[13] &&
                other.uuid.14 == buffer[14] &&
                other.uuid.15 == buffer[15]
        case let other as NSUUID:
            return other === self || _cf_uuid_compare(buffer, other.buffer) == 0
        default:
            return false
        }
    }

    open func compare(_ otherUUID: UUID) -> ComparisonResult {
        if buffer[0] != otherUUID.uuid.0 { return buffer[0] < otherUUID.uuid.0 ? .orderedAscending : .orderedDescending }
        if buffer[1] != otherUUID.uuid.1 { return buffer[1] < otherUUID.uuid.1 ? .orderedAscending : .orderedDescending }
        if buffer[2] != otherUUID.uuid.2 { return buffer[2] < otherUUID.uuid.2 ? .orderedAscending : .orderedDescending }
        if buffer[3] != otherUUID.uuid.3 { return buffer[3] < otherUUID.uuid.3 ? .orderedAscending : .orderedDescending }
        if buffer[4] != otherUUID.uuid.4 { return buffer[4] < otherUUID.uuid.4 ? .orderedAscending : .orderedDescending }
        if buffer[5] != otherUUID.uuid.5 { return buffer[5] < otherUUID.uuid.5 ? .orderedAscending : .orderedDescending }
        if buffer[6] != otherUUID.uuid.6 { return buffer[6] < otherUUID.uuid.6 ? .orderedAscending : .orderedDescending }
        if buffer[7] != otherUUID.uuid.7 { return buffer[7] < otherUUID.uuid.7 ? .orderedAscending : .orderedDescending }
        if buffer[8] != otherUUID.uuid.8 { return buffer[8] < otherUUID.uuid.8 ? .orderedAscending : .orderedDescending }
        if buffer[9] != otherUUID.uuid.9 { return buffer[9] < otherUUID.uuid.9 ? .orderedAscending : .orderedDescending }
        if buffer[10] != otherUUID.uuid.10 { return buffer[10] < otherUUID.uuid.10 ? .orderedAscending : .orderedDescending }
        if buffer[11] != otherUUID.uuid.11 { return buffer[11] < otherUUID.uuid.11 ? .orderedAscending : .orderedDescending }
        if buffer[12] != otherUUID.uuid.12 { return buffer[12] < otherUUID.uuid.12 ? .orderedAscending : .orderedDescending }
        if buffer[13] != otherUUID.uuid.13 { return buffer[13] < otherUUID.uuid.13 ? .orderedAscending : .orderedDescending }
        if buffer[14] != otherUUID.uuid.14 { return buffer[14] < otherUUID.uuid.14 ? .orderedAscending : .orderedDescending }
        if buffer[15] != otherUUID.uuid.15 { return buffer[15] < otherUUID.uuid.15 ? .orderedAscending : .orderedDescending }
        return .orderedSame
    }

    open override var hash: Int {
        return Int(bitPattern: CFHashBytes(buffer, 16))
    }
    
    open override var description: String {
        return uuidString
    }
}

extension NSUUID : _StructTypeBridgeable {
    public typealias _StructType = UUID
    
    public func _bridgeToSwift() -> UUID {
        return UUID._unconditionallyBridgeFromObjectiveC(self)
    }
}
