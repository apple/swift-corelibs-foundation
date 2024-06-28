// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation
#if !os(WASI)
import Dispatch
#endif
#if canImport(Android)
import Android
#endif

extension NSData {
    public typealias ReadingOptions = Data.ReadingOptions
    public typealias WritingOptions = Data.WritingOptions
    public typealias SearchOptions = Data.SearchOptions
    public typealias Base64EncodingOptions = Data.Base64EncodingOptions
    public typealias Base64DecodingOptions = Data.Base64DecodingOptions
}

private final class _NSDataDeallocator {
    var handler: (UnsafeMutableRawPointer, Int) -> Void = {_,_ in }
}

private let __kCFMutable: CFOptionFlags = 0x01
private let __kCFGrowable: CFOptionFlags = 0x02

private let __kCFBytesInline: CFOptionFlags = 2
private let __kCFUseAllocator: CFOptionFlags = 3
private let __kCFDontDeallocate: CFOptionFlags = 4

open class NSData : NSObject, NSCopying, NSMutableCopying, NSSecureCoding {
    typealias CFType = CFData

    private var _base = _CFInfo(typeID: CFDataGetTypeID())
    private var _length: Int = 0 // CFIndex
    private var _capacity: Int = 0 // CFIndex
    private var _deallocator: UnsafeMutableRawPointer? = nil // for CF only
    private var _deallocHandler: _NSDataDeallocator? = _NSDataDeallocator() // for Swift
    private var _bytes: UnsafeMutablePointer<UInt8>? = nil

    internal final var _cfObject: CFType {
        if type(of: self) === NSData.self || type(of: self) === NSMutableData.self {
            return unsafeBitCast(self, to: CFType.self)
        } else {
            let bytePtr = self.bytes.bindMemory(to: UInt8.self, capacity: self.length)
            return CFDataCreate(kCFAllocatorSystemDefault, bytePtr, self.length)
        }
    }

    internal func _providesConcreteBacking() -> Bool {
        return type(of: self) === NSData.self || type(of: self) === NSMutableData.self
    }

    internal override var _cfTypeID: CFTypeID {
        return CFDataGetTypeID()
    }

    // NOTE: the deallocator block here is implicitly @escaping by virtue of it being optional     
    private func _init(bytes: UnsafeMutableRawPointer?, length: Int, copy: Bool = false, deallocator: ((UnsafeMutableRawPointer, Int) -> Void)? = nil) {
        let options : CFOptionFlags = (type(of: self) == NSMutableData.self) ? __kCFMutable | __kCFGrowable : 0x0
        let bytePtr = bytes?.bindMemory(to: UInt8.self, capacity: length)
        if copy {
            _CFDataInit(unsafeBitCast(self, to: CFMutableData.self), options, length, bytePtr, length, false)
            if let handler = deallocator {
                handler(bytes!, length)
            }
        } else {
            if let handler = deallocator {
                _deallocHandler!.handler = handler
            }
            // The data initialization should flag that CF should not deallocate which leaves the handler a chance to deallocate instead
            _CFDataInit(unsafeBitCast(self, to: CFMutableData.self), options | __kCFDontDeallocate, length, bytePtr, length, true)
        }
    }

    fileprivate init(bytes: UnsafeMutableRawPointer?, length: Int, copy: Bool = false, deallocator: ((UnsafeMutableRawPointer, Int) -> Void)? = nil) {
        super.init()
        _init(bytes: bytes, length: length, copy: copy, deallocator: deallocator)
    }
    
    public override init() {
        super.init()
        _init(bytes: nil, length: 0)
    }

    /// Initializes a data object filled with a given number of bytes copied from a given buffer.
    public init(bytes: UnsafeRawPointer?, length: Int) {
        super.init()
        _init(bytes: UnsafeMutableRawPointer(mutating: bytes), length: length, copy: true)
    }

    /// Initializes a data object filled with a given number of bytes of data from a given buffer.
    public init(bytesNoCopy bytes: UnsafeMutableRawPointer, length: Int) {
        super.init()
        _init(bytes: bytes, length: length)
    }

    /// Initializes a data object filled with a given number of bytes of data from a given buffer.
    public init(bytesNoCopy bytes: UnsafeMutableRawPointer, length: Int, freeWhenDone: Bool) {
        super.init()
        _init(bytes: bytes, length: length, copy: false) { buffer, length in
            if freeWhenDone {
                free(buffer)
            }
        }
    }

    /// Initializes a data object filled with a given number of bytes of data from a given buffer, with a custom deallocator block.
    /// NOTE: the deallocator block here is implicitly @escaping by virtue of it being optional
    public init(bytesNoCopy bytes: UnsafeMutableRawPointer, length: Int, deallocator: ((UnsafeMutableRawPointer, Int) -> Void)? = nil) {
        super.init()
        _init(bytes: bytes, length: length, copy: false, deallocator: deallocator)
    }

    /// Initializes a data object with the contents of the file at a given path.
    public init(contentsOfFile path: String, options readOptionsMask: ReadingOptions = []) throws {
        super.init()
        let readResult = try NSData.readBytesFromFileWithExtendedAttributes(path, options: readOptionsMask)

        withExtendedLifetime(readResult) {
            _init(bytes: readResult.bytes, length: readResult.length, copy: false, deallocator: readResult.deallocator)
        }
    }

    /// Initializes a data object with the contents of the file at a given path.
    public init?(contentsOfFile path: String) {
        do {
            super.init()
            let readResult = try NSData.readBytesFromFileWithExtendedAttributes(path, options: [])
            withExtendedLifetime(readResult) {
                _init(bytes: readResult.bytes, length: readResult.length, copy: false, deallocator: readResult.deallocator)
            }
        } catch {
            return nil
        }
    }

    /// Initializes a data object with the contents of another data object.
    public init(data: Data) {
        super.init()
        data.withUnsafeBytes {
            _init(bytes: UnsafeMutableRawPointer(mutating: $0.baseAddress), length: $0.count, copy: true)
        }
    }

    /// Initializes a data object with the data from the location specified by a given URL.
    public init(contentsOf url: URL, options readOptionsMask: ReadingOptions = []) throws {
        super.init()
        let (data, _) = try NSData.contentsOf(url: url, options: readOptionsMask)
        withExtendedLifetime(data) {
            _init(bytes: UnsafeMutableRawPointer(mutating: data.bytes), length: data.length, copy: true)
        }
    }

    /// Initializes a data object with the data from the location specified by a given URL.
    public init?(contentsOf url: URL) {
        super.init()
        do {
            let (data, _) = try NSData.contentsOf(url: url)
            withExtendedLifetime(data) {
                _init(bytes: UnsafeMutableRawPointer(mutating: data.bytes), length: data.length, copy: true)
            }
        } catch {
            return nil
        }
    }

    internal static func contentsOf(url: URL, options readOptionsMask: ReadingOptions = []) throws -> (result: NSData, textEncodingNameIfAvailable: String?) {
        if url.isFileURL {
#if os(Windows)
            return try url.withUnsafeNTPath {
                return (try NSData.readBytesFromFileWithExtendedAttributes(String(decodingCString: $0, as: UTF16.self), options: readOptionsMask).toNSData(), nil)
            }
#else
            return try url.withUnsafeFileSystemRepresentation { (fsRep) -> (result: NSData, textEncodingNameIfAvailable: String?) in
              let data = try NSData.readBytesFromFileWithExtendedAttributes(String(cString: fsRep!), options: readOptionsMask)
              return (data.toNSData(), nil)
            }
#endif
        } else {
            return try _NSNonfileURLContentLoader.current.contentsOf(url: url)
        }
    }

    /// Initializes a data object with the given Base64 encoded string.
    public init?(base64Encoded base64String: String, options: Base64DecodingOptions = []) {

        let result: UnsafeMutableRawBufferPointer?
        if let _result = base64String.utf8.withContiguousStorageIfAvailable({ buffer -> UnsafeMutableRawBufferPointer? in
            let rawBuffer = UnsafeRawBufferPointer(start: buffer.baseAddress!, count: buffer.count)
            return NSData.base64DecodeBytes(rawBuffer, options: options)
        }) {
            result = _result
        } else {
            // Slow path, unlikely that withContiguousStorageIfAvailable will fail but if it does, fall back to .utf8CString.
            // This will allocate and copy but it is the simplest way to get a contiguous buffer.
            result = base64String.utf8CString.withUnsafeBufferPointer { buffer -> UnsafeMutableRawBufferPointer? in
                let rawBuffer = UnsafeRawBufferPointer(start: buffer.baseAddress!, count: buffer.count - 1) // -1 to ignore the terminating NUL
                return NSData.base64DecodeBytes(rawBuffer, options: options)
            }
        }
        guard let decodedBytes = result else { return nil }
        super.init()
        _init(bytes: decodedBytes.baseAddress!, length: decodedBytes.count, copy: false, deallocator: { (ptr, length) in
            ptr.deallocate()
        })
    }

    /// Initializes a data object with the given Base64 encoded data.
    public init?(base64Encoded base64Data: Data, options: Base64DecodingOptions = []) {
        guard let decodedBytes = base64Data.withUnsafeBytes({ rawBuffer in
                NSData.base64DecodeBytes(rawBuffer, options: options)
        }) else {
            return nil
        }
        super.init()
        _init(bytes: decodedBytes.baseAddress!, length: decodedBytes.count, copy: false, deallocator: { (ptr, length) in
            ptr.deallocate()
        })
    }
    
    deinit {
        if let allocatedBytes = _bytes {
            _deallocHandler?.handler(allocatedBytes, _length)
        }
        if type(of: self) === NSData.self || type(of: self) === NSMutableData.self {
            _CFDeinit(self._cfObject)
        }
    }

    // MARK: - Funnel methods

    /// The number of bytes contained by the data object.
    open var length: Int {
        requireFunnelOverridden()
        return CFDataGetLength(_cfObject)
    }

    /// A pointer to the data object's contents.
    open var bytes: UnsafeRawPointer {
        requireFunnelOverridden()
        guard let bytePtr = CFDataGetBytePtr(_cfObject) else {
            //This could occure on empty data being encoded.
            //TODO: switch with nil when signature is fixed
            return UnsafeRawPointer(bitPattern: 0x7f00dead)! //would not result in 'nil unwrapped optional'
        }
        return UnsafeRawPointer(bytePtr)
    }

    // MARK: - NSObject methods
    open override var hash: Int {
        return Int(bitPattern: _CFNonObjCHash(_cfObject))
    }

    /// Returns a Boolean value indicating whether this data object is the same as another.
    open override func isEqual(_ value: Any?) -> Bool {
        if let data = value as? Data {
            return isEqual(to: data)
        } else if let data = value as? NSData {
            return isEqual(to: data._swiftObject)
        }

#if !os(WASI)
        if let data = value as? DispatchData {
            if data.count != length {
                return false
            }
            return data.withUnsafeBytes { (bytes2: UnsafePointer<UInt8>) -> Bool in
                let bytes1 = bytes
                return memcmp(bytes1, bytes2, length) == 0
            }
        }
#endif

        return false
    }

    open func isEqual(to other: Data) -> Bool {
        if length != other.count {
            return false
        }
        
        return other.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Bool in
            let bytes1 = bytes
            let bytes2 = rawBuffer.baseAddress!
            return memcmp(bytes1, bytes2, length) == 0
        }
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
    
    open override func mutableCopy() -> Any {
        return mutableCopy(with: nil)
    }
    
    open func mutableCopy(with zone: NSZone? = nil) -> Any {
        return NSMutableData(bytes: UnsafeMutableRawPointer(mutating: bytes), length: length, copy: true, deallocator: nil)
    }
    
    private func byteDescription(limit: Int? = nil) -> String {
        var s = ""
        var i = 0
        while i < self.length {
            if i > 0 && i % 4 == 0 {
                // if there's a limit, and we're at the barrier where we'd add the ellipses, don't add a space.
                if let limit = limit, self.length > limit && i == self.length - (limit / 2) { /* do nothing */ }
                else { s += " " }
            }
            let byte = bytes.load(fromByteOffset: i, as: UInt8.self)
            var byteStr = String(byte, radix: 16, uppercase: false)
            if byte <= 0xf { byteStr = "0\(byteStr)" }
            s += byteStr
            // if we've hit the midpoint of the limit, skip to the last (limit / 2) bytes.
            if let limit = limit, self.length > limit && i == (limit / 2) - 1 {
                s += " ... "
                i = self.length - (limit / 2)
            } else {
                i += 1
            }
        }
        return s
    }
    
    override open var debugDescription: String {
        return "<\(byteDescription(limit: 1024))>"
    }

    /// A string that contains a hexadecimal representation of the data object’s contents in a property list format.
    override open var description: String {
        return "<\(byteDescription())>"
    }

    // MARK: - NSCoding methods
    open func encode(with aCoder: NSCoder) {
        if let aKeyedCoder = aCoder as? NSKeyedArchiver {
            aKeyedCoder._encodePropertyList(self, forKey: "NS.data")
        } else {
            let bytePtr = self.bytes.bindMemory(to: UInt8.self, capacity: self.length)
            aCoder.encodeBytes(bytePtr, length: self.length)
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init()
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        if type(of: aDecoder) == NSKeyedUnarchiver.self || aDecoder.containsValue(forKey: "NS.data") {
            guard let data = aDecoder._decodePropertyListForKey("NS.data") as? NSData else {
                return nil
            }
            withExtendedLifetime(data) {
                _init(bytes: UnsafeMutableRawPointer(mutating: data.bytes), length: data.length, copy: true)
            }
        } else {
            let result : Data? = aDecoder.withDecodedUnsafeBufferPointer(forKey: "NS.bytes") {
                guard let buffer = $0 else { return nil }
                return Data(buffer: buffer)
            }
            
            guard var r = result else { return nil }
            r.withUnsafeMutableBytes {
                _init(bytes: $0.baseAddress, length: $0.count, copy: true)
            }
        }
    }
    
    public static var supportsSecureCoding: Bool {
        return true
    }

    // MARK: - IO
    internal struct NSDataReadResult {
        var bytes: UnsafeMutableRawPointer?
        var length: Int
        var deallocator: ((_ buffer: UnsafeMutableRawPointer, _ length: Int) -> Void)!

        func toNSData() -> NSData {
            if bytes == nil {
                return NSData()
            }
            return NSData(bytesNoCopy: bytes!, length: length, deallocator: deallocator)
        }

        func toData() -> Data {
            guard let bytes = bytes else {
                return Data()
            }
            return Data(bytesNoCopy: bytes, count: length, deallocator: Data.Deallocator.custom(deallocator))
        }
    }

    internal static func readBytesFromFileWithExtendedAttributes(_ path: String, options: ReadingOptions) throws -> NSDataReadResult {
        guard let handle = FileHandle(path: path, flags: O_RDONLY, createMode: 0) else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        let result = try handle._readDataOfLength(Int.max, untilEOF: true)
        return result
    }


    /// Writes the data object's bytes to the file specified by a given path.
    open func write(toFile path: String, options writeOptionsMask: WritingOptions = []) throws {

        func doWrite(_ fh: FileHandle) throws {
            try self.enumerateByteRangesUsingBlockRethrows { (buf, range, stop) in
                if range.length > 0 {
                    try fh._writeBytes(buf: buf, length: range.length)
                }
            }
            try fh.synchronize()
        }

        let fm = FileManager.default
#if os(WASI)
        // WASI does not have permission concept
        let permissions: Int? = nil
#else
        let permissions = try? fm.attributesOfItem(atPath: path)[.posixPermissions] as? Int
#endif
        if writeOptionsMask.contains(.atomic) {
            let (newFD, auxFilePath) = try _NSCreateTemporaryFile(path)
            let fh = FileHandle(fileDescriptor: newFD, closeOnDealloc: true)
            do {
                try doWrite(fh)
                // Moving a file on Windows (via _NSCleanupTemporaryFile)
                // requires that there be no open handles to the file
                fh.closeFile()
                try _NSCleanupTemporaryFile(auxFilePath, path)
                if let permissions = permissions {
                    try fm.setAttributes([.posixPermissions: NSNumber(value: permissions)], ofItemAtPath: path)
                }
            } catch {
                let savedErrno = errno
                try? fm.removeItem(atPath: auxFilePath)
                throw _NSErrorWithErrno(savedErrno, reading: false, path: path)
            }
        } else {
            var flags = O_WRONLY | O_CREAT | O_TRUNC
            if writeOptionsMask.contains(.withoutOverwriting) {
                flags |= O_EXCL
            }

            // NOTE: Each flag such as `S_IRUSR` may be literal depends on the system.
            // Without explicity type them as `Int`, type inference will not complete in reasonable time
            // and the compiler will throw an error.
#if os(Windows)
            let createMode = Int(ucrt.S_IREAD) | Int(ucrt.S_IWRITE)
#elseif canImport(Darwin)
            let createMode = Int(S_IRUSR) | Int(S_IWUSR) | Int(S_IRGRP) | Int(S_IWGRP) | Int(S_IROTH) | Int(S_IWOTH)
#elseif canImport(Glibc)
            let createMode = Int(Glibc.S_IRUSR) | Int(Glibc.S_IWUSR) | Int(Glibc.S_IRGRP) | Int(Glibc.S_IWGRP) | Int(Glibc.S_IROTH) | Int(Glibc.S_IWOTH)
#elseif canImport(Musl)
            let createMode = Int(Musl.S_IRUSR) | Int(Musl.S_IWUSR) | Int(Musl.S_IRGRP) | Int(Musl.S_IWGRP) | Int(Musl.S_IROTH) | Int(Musl.S_IWOTH)
#elseif canImport(WASILibc)
            let createMode = Int(WASILibc.S_IRUSR) | Int(WASILibc.S_IWUSR) | Int(WASILibc.S_IRGRP) | Int(WASILibc.S_IWGRP) | Int(WASILibc.S_IROTH) | Int(WASILibc.S_IWOTH)
#elseif canImport(Android)
            let createMode = Int(Android.S_IRUSR) | Int(Android.S_IWUSR) | Int(Android.S_IRGRP) | Int(Android.S_IWGRP) | Int(Android.S_IROTH) | Int(Android.S_IWOTH)
#endif
            guard let fh = FileHandle(path: path, flags: flags, createMode: createMode) else {
                throw _NSErrorWithErrno(errno, reading: false, path: path)
            }
            try doWrite(fh)
            if let permissions = permissions {
                try fm.setAttributes([.posixPermissions: NSNumber(value: permissions)], ofItemAtPath: path)
            }
        }
    }

    /// Writes the data object's bytes to the file specified by a given path.
    /// NOTE: the 'atomically' flag is ignored if the url is not of a type the supports atomic writes
    open func write(toFile path: String, atomically useAuxiliaryFile: Bool) -> Bool {
        do {
            try write(toFile: path, options: useAuxiliaryFile ? .atomic : [])
        } catch {
            return false
        }
        return true
    }

    /// Writes the data object's bytes to the location specified by a given URL.
    /// NOTE: the 'atomically' flag is ignored if the url is not of a type the supports atomic writes
    open func write(to url: URL, atomically: Bool) -> Bool {
        if url.isFileURL {
            return write(toFile: url.path, atomically: atomically)
        }
        return false
    }

    ///    Writes the data object's bytes to the location specified by a given URL.
    ///
    ///    - parameter url:              The location to which the data objects's contents will be written.
    ///    - parameter writeOptionsMask: An option set specifying file writing options.
    ///
    ///    - throws: This method returns Void and is marked with the `throws` keyword to indicate that it throws an error in the event of failure.
    ///
    ///      This method is invoked in a `try` expression and the caller is responsible for handling any errors in the `catch` clauses of a `do` statement, as described in [Error Handling](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/ErrorHandling.html#//apple_ref/doc/uid/TP40014097-CH42) in [The Swift Programming Language](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/index.html#//apple_ref/doc/uid/TP40014097) and [Error Handling](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/BuildingCocoaApps/AdoptingCocoaDesignPatterns.html#//apple_ref/doc/uid/TP40014216-CH7-ID10) in [Using Swift with Cocoa and Objective-C](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/BuildingCocoaApps/index.html#//apple_ref/doc/uid/TP40014216).
    open func write(to url: URL, options writeOptionsMask: WritingOptions = []) throws {
        guard url.isFileURL else {
            let userInfo = [NSLocalizedDescriptionKey : "The folder at “\(url)” does not exist or is not a file URL.", // NSLocalizedString() not yet available
                            NSURLErrorKey             : url.absoluteString] as Dictionary<String, Any>
            throw NSError(domain: NSCocoaErrorDomain, code: 4, userInfo: userInfo)
        }
        try write(toFile: url.path, options: writeOptionsMask)
    }

    // MARK: - Bytes
    /// Copies a number of bytes from the start of the data object into a given buffer.
    open func getBytes(_ buffer: UnsafeMutableRawPointer, length: Int) {
        if funnelsAreAbstract {
            let actualCount = Swift.min(length, self.length)
            let sourceBuffer = UnsafeRawBufferPointer(start: bytes, count: actualCount)
            let destinationBuffer = UnsafeMutableRawBufferPointer(start: buffer, count: actualCount)
            sourceBuffer.copyBytes(to: destinationBuffer)
        } else {
            let bytePtr = buffer.bindMemory(to: UInt8.self, capacity: length)
            CFDataGetBytes(_cfObject, CFRangeMake(0, length), bytePtr)
        }
    }

    /// Copies a range of bytes from the data object into a given buffer.
    open func getBytes(_ buffer: UnsafeMutableRawPointer, range: NSRange) {
        if funnelsAreAbstract {
            precondition(range.location >= 0 && range.length >= 0)
            let actualCount = Swift.min(range.length, self.length - range.location)
            let sourceBuffer = UnsafeRawBufferPointer(start: bytes.advanced(by: range.location), count: actualCount)
            let destinationBuffer = UnsafeMutableRawBufferPointer(start: buffer, count: actualCount)
            sourceBuffer.copyBytes(to: destinationBuffer)
        } else {
            let bytePtr = buffer.bindMemory(to: UInt8.self, capacity: range.length)
            CFDataGetBytes(_cfObject, CFRangeMake(range.location, range.length), bytePtr)
        }
    }

    /// Returns a new data object containing the data object's bytes that fall within the limits specified by a given range.
    open func subdata(with range: NSRange) -> Data {
        if range.length == 0 {
            return Data()
        }
        if range.location == 0 && range.length == self.length {
            return Data(self)
        }
        let p = self.bytes.advanced(by: range.location).bindMemory(to: UInt8.self, capacity: range.length)
        return Data(bytes: p, count: range.length)
    }

    /// Finds and returns the range of the first occurrence of the given data, within the given range, subject to given options.
    open func range(of dataToFind: Data, options mask: SearchOptions = [], in searchRange: NSRange) -> NSRange {
        let dataToFind = dataToFind._nsObject

        return withExtendedLifetime(dataToFind) {
            guard dataToFind.length > 0 else {return NSRange(location: NSNotFound, length: 0)}
            guard let searchRange = Range(searchRange) else {fatalError("invalid range")}

            precondition(searchRange.upperBound <= self.length, "range outside the bounds of data")

            let basePtr = self.bytes.bindMemory(to: UInt8.self, capacity: self.length)
            let baseData = UnsafeBufferPointer<UInt8>(start: basePtr, count: self.length)[searchRange]
            let searchPtr = dataToFind.bytes.bindMemory(to: UInt8.self, capacity: dataToFind.length)
            let search = UnsafeBufferPointer<UInt8>(start: searchPtr, count: dataToFind.length)

            let location : Int?
            let anchored = mask.contains(.anchored)
            if mask.contains(.backwards) {
                location = NSData.searchSubSequence(search.reversed(), inSequence: baseData.reversed(),anchored : anchored).map {$0.base-search.count}
            } else {
                location = NSData.searchSubSequence(search, inSequence: baseData,anchored : anchored)
            }
            return location.map {NSRange(location: $0, length: search.count)} ?? NSRange(location: NSNotFound, length: 0)
        }
    }

    private static func searchSubSequence<T : Collection, T2 : Sequence>(_ subSequence : T2, inSequence seq: T,anchored : Bool) -> T.Index? where T.Iterator.Element : Equatable, T.Iterator.Element == T2.Iterator.Element {
        for index in seq.indices {
            if seq.suffix(from: index).starts(with: subSequence) {
                return index
            }
            if anchored {return nil}
        }
        return nil
    }
    
    internal func enumerateByteRangesUsingBlockRethrows(_ block: (UnsafeRawPointer, NSRange, UnsafeMutablePointer<Bool>) throws -> Void) throws {
        var err : Swift.Error? = nil
        self.enumerateBytes() { (buf, range, stop) -> Void in
            do {
                try block(buf, range, stop)
            } catch {
                err = error
            }
        }
        if let err = err {
            throw err
        }
    }

    /// Enumerates each range of bytes in the data object using a block.
    /// 'block' is called once for each contiguous region of memory in the data object (once total for contiguous NSDatas),
    /// until either all bytes have been enumerated, or the 'stop' parameter is set to true.
    open func enumerateBytes(_ block: (UnsafeRawPointer, NSRange, UnsafeMutablePointer<Bool>) -> Void) {
        var stop = false
        withUnsafeMutablePointer(to: &stop) { stopPointer in
            if (stopPointer.pointee) {
                return
            }
            block(bytes, NSRange(location: 0, length: length), stopPointer)
        }
    }

    // MARK: - Base64 Methods

    internal static func estimateBase64Size(length: Int) -> Int {
        // Worst case allow for 64bytes + \r\n per line  48 input bytes => 66 output bytes
        return ((length + 47) * 66) / 48
    }

    /// Creates a Base64 encoded String from the data object using the given options.
    open func base64EncodedString(options: Base64EncodingOptions = []) -> String {
        let dataLength = self.length
        if dataLength == 0 { return "" }

        let inputBuffer = UnsafeRawBufferPointer(start: self.bytes, count: dataLength)
        let capacity = NSData.estimateBase64Size(length: dataLength)
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: 4)
        defer { ptr.deallocate() }
        let outputBuffer = UnsafeMutableRawBufferPointer(start: ptr, count: capacity)
        let length = NSData.base64EncodeBytes(inputBuffer, options: options, buffer: outputBuffer)

        return String(decoding: UnsafeRawBufferPointer(start: ptr, count: length), as: Unicode.UTF8.self)
    }

    /// Creates a Base64, UTF-8 encoded Data from the data object using the given options.
    open func base64EncodedData(options: Base64EncodingOptions = []) -> Data {
        let dataLength = self.length
        if dataLength == 0 { return Data() }

        let inputBuffer = UnsafeRawBufferPointer(start: self.bytes, count: self.length)

        let capacity = NSData.estimateBase64Size(length: dataLength)
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: 4)
        let outputBuffer = UnsafeMutableRawBufferPointer(start: ptr, count: capacity)

        let length = NSData.base64EncodeBytes(inputBuffer, options: options, buffer: outputBuffer)
        return Data(bytesNoCopy: ptr, count: length, deallocator: .custom({ (ptr, length) in
            ptr.deallocate()
        }))
    }

    /**
     Padding character used when the number of bytes to encode is not divisible by 3
     */
    private static let base64Padding : UInt8 = 61 // =

    /**
     This method decodes Base64-encoded data.

     If the input contains any bytes that are not valid Base64 characters,
     this will return nil.

     - parameter bytes:      The Base64 bytes
     - parameter options:    Options for handling invalid input
     - returns:              The decoded bytes.
     */
    private static func base64DecodeBytes(_ bytes: UnsafeRawBufferPointer, options: Base64DecodingOptions = []) -> UnsafeMutableRawBufferPointer? {

        // This table maps byte values 0-127, input bytes >127 are always invalid.
        // Map the ASCII characters "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" -> 0...63
        // Map '=' (ASCII 61) to 0x40.
        // All other values map to 0x7f. This allows '=' and invalid bytes to be checked together by testing bit 6 (0x40).
        let base64Decode: StaticString = """
\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\
\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\
\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{3e}\u{7f}\u{7f}\u{7f}\u{3f}\
\u{34}\u{35}\u{36}\u{37}\u{38}\u{39}\u{3a}\u{3b}\u{3c}\u{3d}\u{7f}\u{7f}\u{7f}\u{40}\u{7f}\u{7f}\
\u{7f}\u{00}\u{01}\u{02}\u{03}\u{04}\u{05}\u{06}\u{07}\u{08}\u{09}\u{0a}\u{0b}\u{0c}\u{0d}\u{0e}\
\u{0f}\u{10}\u{11}\u{12}\u{13}\u{14}\u{15}\u{16}\u{17}\u{18}\u{19}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\
\u{7f}\u{1a}\u{1b}\u{1c}\u{1d}\u{1e}\u{1f}\u{20}\u{21}\u{22}\u{23}\u{24}\u{25}\u{26}\u{27}\u{28}\
\u{29}\u{2a}\u{2b}\u{2c}\u{2d}\u{2e}\u{2f}\u{30}\u{31}\u{32}\u{33}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}
"""
        assert(base64Decode.isASCII)
        assert(base64Decode.utf8CodeUnitCount == 128)
        assert(base64Decode.hasPointerRepresentation)

        let ignoreUnknown = options.contains(.ignoreUnknownCharacters)
        if !ignoreUnknown && !bytes.count.isMultiple(of: 4) {
            return nil
        }

        let capacity = (bytes.count * 3) / 4    // Every 4 valid ASCII bytes maps to 3 output bytes.
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: 1)
        var outputIndex = 0

        func append(_ byte: UInt8) {
            assert(outputIndex < capacity)
            buffer.storeBytes(of: byte, toByteOffset: outputIndex, as: UInt8.self)
            outputIndex += 1
        }

        var currentByte: UInt8 = 0
        var validCharacterCount = 0
        var paddingCount = 0
        var index = 0
        var error = false

        for base64Char in bytes {
            var value: UInt8 = 0

            var invalid = false
            if base64Char >= base64Decode.utf8CodeUnitCount {
                invalid = true
            } else {
                value = base64Decode.utf8Start[Int(base64Char)]
                if value & 0x40 == 0x40 {       // Input byte is either '=' or an invalid value.
                    if value == 0x7f {
                        invalid = true
                    } else if value == 0x40 {   // '=' padding at end of input.
                        paddingCount += 1
                        continue
                    }
                }
            }

            if invalid {
                if ignoreUnknown {
                    continue
                } else {
                    error = true
                    break
                }
            }
            validCharacterCount += 1

            // Padding found in the middle of the sequence is invalid.
            if paddingCount > 0 {
                error = true
                break
            }

            switch index {
            case 0:
                currentByte = (value << 2)
            case 1:
                currentByte |= (value >> 4)
                append(currentByte)
                currentByte = (value << 4)
            case 2:
                currentByte |= (value >> 2)
                append(currentByte)
                currentByte = (value << 6)
            case 3:
                currentByte |= value
                append(currentByte)
                index = -1
            default:
                fatalError()
            }

            index += 1
        }

        guard error == false && (validCharacterCount + paddingCount) % 4 == 0 else {
            // Invalid character count of valid input characters.
            buffer.deallocate()
            return nil
        }
        return UnsafeMutableRawBufferPointer(start: buffer, count: outputIndex)
    }

    /**
     This method encodes data in Base64.
     
     - parameter dataBuffer: The UnsafeRawBufferPointer buffer to encode
     - parameter options:    Options for formatting the result
     - parameter buffer:     The buffer to write the bytes into
     - returns:              The number of bytes written into the buffer

       NOTE: dataBuffer would be better expressed as a <T: Collection> where T.Element == UInt8, T.Index == Int but this currently gives much poorer performance.
     */
    static func base64EncodeBytes(_ dataBuffer: UnsafeRawBufferPointer, options: Base64EncodingOptions = [], buffer: UnsafeMutableRawBufferPointer) -> Int {
        // Use a StaticString for lookup of values 0-63 -> ASCII values
        let base64Chars = StaticString("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
        assert(base64Chars.utf8CodeUnitCount == 64)
        assert(base64Chars.hasPointerRepresentation)
        assert(base64Chars.isASCII)
        let base64CharsPtr = base64Chars.utf8Start

        let lineLength: Int
        var currentLineCount = 0
        let separatorByte1: UInt8
        var separatorByte2: UInt8? = nil

        if options.isEmpty {
            lineLength = 0
            separatorByte1 = 0
        } else {
            if options.contains(.lineLength64Characters) {
                lineLength = 64
            } else if options.contains(.lineLength76Characters) {
                lineLength = 76
            } else {
                lineLength = 0
            }

            if options.contains(.endLineWithCarriageReturn) && options.contains(.endLineWithLineFeed) {
                separatorByte1 = UInt8(ascii: "\r")
                separatorByte2 = UInt8(ascii: "\n")
            } else if options.contains(.endLineWithCarriageReturn) {
                separatorByte1 = UInt8(ascii: "\r")
            } else if options.contains(.endLineWithLineFeed) {
                separatorByte1 = UInt8(ascii: "\n")
            } else {
                separatorByte1 = UInt8(ascii: "\r")
                separatorByte2 = UInt8(ascii: "\n")
            }
        }

        func lookupBase64Value(_ value: UInt16) -> UInt32 {
            let byte = base64CharsPtr[Int(value & 63)]
            return UInt32(byte)
        }

        // Read three bytes at a time, which convert to 4 ASCII characters, allowing for byte2 and byte3 being nil

        var inputIndex = 0
        var outputIndex = 0
        var bytesLeft = dataBuffer.count

        while bytesLeft > 0 {

            let byte1 = dataBuffer[inputIndex]

            // outputBytes is a UInt32 to allow 4 bytes to be written out at once.
            var outputBytes = lookupBase64Value(UInt16(byte1 >> 2))

            if bytesLeft > 2 {
                // This is the main loop converting 3 bytes at a time.
                let byte2 = dataBuffer[inputIndex + 1]
                let byte3 = dataBuffer[inputIndex + 2]
                var value = UInt16(byte1 & 0x3) << 8
                value |= UInt16(byte2)

                let outputByte2 = lookupBase64Value(value >> 4)
                outputBytes |= (outputByte2 << 8)
                value = (value << 8) | UInt16(byte3)

                let outputByte3 = lookupBase64Value(value >> 6)
                outputBytes |= (outputByte3 << 16)

                let outputByte4 = lookupBase64Value(value)
                outputBytes |= (outputByte4 << 24)
                inputIndex += 3
            } else {
                // This runs once at the end of there were 1 or 2 bytes left, byte1 having already been read.
                // Read byte2 or 0 if there isnt another byte
                let byte2 = bytesLeft == 1 ? 0 : dataBuffer[inputIndex + 1]
                var value = UInt16(byte1 & 0x3) << 8
                value |= UInt16(byte2)

                let outputByte2 = lookupBase64Value(value >> 4)
                outputBytes |= (outputByte2 << 8)

                let outputByte3 = bytesLeft == 1 ? UInt32(self.base64Padding) : lookupBase64Value(value << 2)
                outputBytes |= (outputByte3 << 16)
                outputBytes |= (UInt32(self.base64Padding) << 24)
                inputIndex += bytesLeft
                assert(inputIndex == dataBuffer.count)
            }

            // The lowest byte of outputBytes needs to be stored at the lowest address, so make sure
            // the bytes are in the correct order on big endian CPUs.
            outputBytes = outputBytes.littleEndian

            // The output isnt guaranteed to be aligned on a 4 byte boundary if EOL markers (CR, LF or CRLF)
            // are written out so use .copyMemory() for safety. On x86 this still translates to a single store
            // anyway.
            buffer.baseAddress!.advanced(by: outputIndex).copyMemory(from: &outputBytes, byteCount: 4)
            outputIndex += 4
            bytesLeft = dataBuffer.count - inputIndex
            
            if lineLength != 0 {
                // Add required EOL markers.
                currentLineCount += 4
                assert(currentLineCount <= lineLength)

                if currentLineCount == lineLength && bytesLeft > 0 {
                    buffer[outputIndex] = separatorByte1
                    outputIndex += 1

                    if let byte2 = separatorByte2 {
                        buffer[outputIndex] = byte2
                        outputIndex += 1
                    }
                    currentLineCount = 0
                }
            }
        }

        // Return the number of ASCII bytes written to the buffer
        return outputIndex
    }
}

// MARK: -
extension NSData : _SwiftBridgeable {
    typealias SwiftType = Data
    internal var _swiftObject: SwiftType { return Data(self) }
}

extension Data : _NSBridgeable {
    typealias CFType = CFData
    typealias NSType = NSData
    internal var _cfObject: CFType { return _nsObject._cfObject }
    internal var _nsObject: NSType { return _bridgeToObjectiveC() }
}

extension CFData : _NSBridgeable, _SwiftBridgeable {
    typealias NSType = NSData
    typealias SwiftType = Data
    internal var _nsObject: NSType { return unsafeBitCast(self, to: NSType.self) }
    internal var _swiftObject: SwiftType { return Data(self._nsObject) }
}

// MARK: -
open class NSMutableData : NSData {
    internal final var _cfMutableObject: CFMutableData { return unsafeBitCast(self, to: CFMutableData.self) }

    public override init() {
        super.init(bytes: nil, length: 0)
    }

    // NOTE: the deallocator block here is implicitly @escaping by virtue of it being optional
    fileprivate override init(bytes: UnsafeMutableRawPointer?, length: Int, copy: Bool = false, deallocator: (/*@escaping*/ (UnsafeMutableRawPointer, Int) -> Void)? = nil) {
        super.init(bytes: bytes, length: length, copy: copy, deallocator: deallocator)
    }

    /// Initializes a data object filled with a given number of bytes copied from a given buffer.
    public override init(bytes: UnsafeRawPointer?, length: Int) {
        super.init(bytes: UnsafeMutableRawPointer(mutating: bytes), length: length, copy: true, deallocator: nil)
    }

    /// Returns an initialized mutable data object capable of holding the specified number of bytes.
    public init?(capacity: Int) {
        super.init(bytes: nil, length: 0)
    }

    /// Initializes and returns a mutable data object containing a given number of zeroed bytes.
    public init?(length: Int) {
        super.init(bytes: nil, length: 0)
        self.length = length
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override init(bytesNoCopy bytes: UnsafeMutableRawPointer, length: Int) {
        super.init(bytesNoCopy: bytes, length: length)
    }

    public override init(bytesNoCopy bytes: UnsafeMutableRawPointer, length: Int, deallocator: ((UnsafeMutableRawPointer, Int) -> Void)? = nil) {
        super.init(bytesNoCopy: bytes, length: length, deallocator: deallocator)
    }

    public override init(bytesNoCopy bytes: UnsafeMutableRawPointer, length: Int, freeWhenDone: Bool) {
        super.init(bytesNoCopy: bytes, length: length, freeWhenDone: freeWhenDone)
    }

    public override init(data: Data) {
        super.init(data: data)
    }

    public override init?(contentsOfFile path: String) {
        super.init(contentsOfFile: path)
    }

    public override init(contentsOfFile path: String, options: NSData.ReadingOptions = []) throws {
        try super.init(contentsOfFile: path, options: options)
    }

    public override init?(contentsOf url: URL) {
        super.init(contentsOf: url)
    }

    public override init(contentsOf url: URL, options: NSData.ReadingOptions = []) throws {
        try super.init(contentsOf: url, options: options)
    }

    public override init?(base64Encoded base64Data: Data, options: NSData.Base64DecodingOptions = []) {
        super.init(base64Encoded: base64Data, options: options)
    }

    public override init?(base64Encoded base64Data: String, options: NSData.Base64DecodingOptions = []) {
        super.init(base64Encoded: base64Data, options: options)
    }


    // MARK: - Funnel Methods
    /// A pointer to the data contained by the mutable data object.
    open var mutableBytes: UnsafeMutableRawPointer {
        requireFunnelOverridden()
        return UnsafeMutableRawPointer(CFDataGetMutableBytePtr(_cfMutableObject))
    }

    /// The number of bytes contained in the mutable data object.
    open override var length: Int {
        get {
            requireFunnelOverridden()
            return CFDataGetLength(_cfObject)
        }
        set {
            requireFunnelOverridden()
            CFDataSetLength(_cfMutableObject, newValue)
        }
    }
    
    // MARK: - NSObject
    open override func copy(with zone: NSZone? = nil) -> Any {
        return NSData(bytes: bytes, length: length)
    }

    // MARK: - Mutability
    /// Appends to the data object a given number of bytes from a given buffer.
    open func append(_ bytes: UnsafeRawPointer, length: Int) {
        guard length > 0 else { return }
        
        if funnelsAreAbstract {
            self.length += length
            UnsafeRawBufferPointer(start: bytes, count: length).copyBytes(to: UnsafeMutableRawBufferPointer(start: mutableBytes, count: length))
        } else {
            let bytePtr = bytes.bindMemory(to: UInt8.self, capacity: length)
            CFDataAppendBytes(_cfMutableObject, bytePtr, length)
        }
    }

    /// Appends the content of another data object to the data object.
    open func append(_ other: Data) {
        let otherLength = other.count
        other.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            let bytes = rawBuffer.baseAddress!
            append(bytes, length: otherLength)
        }
    }

    /// Increases the length of the data object by a given number of bytes.
    open func increaseLength(by extraLength: Int) {
        if funnelsAreAbstract {
            self.length += extraLength
        } else {
            CFDataSetLength(_cfMutableObject, CFDataGetLength(_cfObject) + extraLength)
        }
    }

    /// Replaces with a given set of bytes a given range within the contents of the data object.
    open func replaceBytes(in range: NSRange, withBytes bytes: UnsafeRawPointer) {
        if funnelsAreAbstract {
            replaceBytes(in: range, withBytes: bytes, length: range.length)
        } else {
            let bytePtr = bytes.bindMemory(to: UInt8.self, capacity: length)
            CFDataReplaceBytes(_cfMutableObject, CFRangeMake(range.location, range.length), bytePtr, length)
        }
    }

    /// Replaces with zeroes the contents of the data object in a given range.
    open func resetBytes(in range: NSRange) {
        memset(mutableBytes.advanced(by: range.location), 0, range.length)
    }

    /// Replaces the entire contents of the data object with the contents of another data object.
    open func setData(_ data: Data) {
        length = data.count
        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            let bytes = rawBuffer.baseAddress!
            replaceBytes(in: NSRange(location: 0, length: length), withBytes: bytes)
        }
    }

    /// Replaces with a given set of bytes a given range within the contents of the data object.
    open func replaceBytes(in range: NSRange, withBytes replacementBytes: UnsafeRawPointer?, length replacementLength: Int) {
        precondition(range.location + range.length <= self.length)
        if funnelsAreAbstract {
            let delta = replacementLength - range.length
            if delta != 0 {
                let originalLength = self.length
                self.length += delta
                
                if delta > 0 {
                    UnsafeRawBufferPointer(start: mutableBytes.advanced(by: range.location), count: originalLength).copyBytes(to: UnsafeMutableRawBufferPointer(start: mutableBytes.advanced(by: range.location + range.length), count: originalLength))
                }
            }
            UnsafeRawBufferPointer(start: replacementBytes, count: replacementLength).copyBytes(to: UnsafeMutableRawBufferPointer(start: mutableBytes.advanced(by: range.location), count: replacementLength))
        } else {
            let bytePtr = replacementBytes?.bindMemory(to: UInt8.self, capacity: replacementLength)
            CFDataReplaceBytes(_cfMutableObject, CFRangeMake(range.location, range.length), bytePtr, replacementLength)
        }
    }
}

extension NSData {
    internal func _isCompact() -> Bool {
        var regions = 0
        enumerateBytes { (_, _, stop) in
            regions += 1
            if regions > 1 {
                stop.pointee = true
            }
        }
        return regions <= 1
    }
}

extension NSData : _StructTypeBridgeable {
    public typealias _StructType = Data
    public func _bridgeToSwift() -> Data {
        return Data._unconditionallyBridgeFromObjectiveC(self)
    }
}

internal func _CFSwiftDataCreateCopy(_ data: CFTypeRef) -> Unmanaged<AnyObject> {
    return Unmanaged<AnyObject>.passRetained((data as! NSData).copy() as! NSObject)
}

internal func _CFSwiftDataGetLength(_ data: CFTypeRef) -> CFIndex {
    return (data as! NSData).length
}

internal func _CFSwiftDataGetBytesPtr(_ data: CFTypeRef) -> UnsafeRawPointer? {
    return (data as! NSData).bytes
}

internal func _CFSwiftDataGetMutableBytesPtr(_ data: CFTypeRef) -> UnsafeMutableRawPointer? {
    return (data as! NSMutableData).mutableBytes
}

internal func _CFSwiftDataGetBytes(_ data: CFTypeRef, _ range: CFRange, _ buffer: UnsafeMutableRawPointer) -> Void {
    (data as! NSData).getBytes(buffer, range: NSMakeRange(range.location, range.length))
}

internal func _CFSwiftDataSetLength(_ data: CFTypeRef, _ newLength: CFIndex) {
    (data as! NSMutableData).length = newLength
}

internal func _CFSwiftDataIncreaseLength(_ data: CFTypeRef, _ extraLength: CFIndex) {
    (data as! NSMutableData).increaseLength(by: extraLength)
}

internal func _CFSwiftDataAppendBytes(_ data: CFTypeRef, _ buffer: UnsafeRawPointer, length: CFIndex) {
    (data as! NSMutableData).append(buffer, length: length)
}

internal func _CFSwiftDataReplaceBytes(_ data: CFTypeRef, _ range: CFRange, _ buffer: UnsafeRawPointer?, _ count: CFIndex) {
    (data as! NSMutableData).replaceBytes(in: NSMakeRange(range.location, range.length), withBytes: buffer, length: count)
}

extension NSData {
    var funnelsAreAbstract: Bool {
        return type(of: self) != NSData.self && type(of: self) != NSMutableData.self
    }
    
    func requireFunnelOverridden() {
        if funnelsAreAbstract {
            NSRequiresConcreteImplementation()
        }
    }
}

// MARK: - Bridging

extension Data {
    @available(*, unavailable, renamed: "copyBytes(to:count:)")
    public func getBytes<UnsafeMutablePointerVoid: _Pointer>(_ buffer: UnsafeMutablePointerVoid, length: Int) { }
    
    @available(*, unavailable, renamed: "copyBytes(to:from:)")
    public func getBytes<UnsafeMutablePointerVoid: _Pointer>(_ buffer: UnsafeMutablePointerVoid, range: NSRange) { }
}


extension Data {
    public init(referencing d: NSData) {
        self = Data(d)
    }
}

extension Data : _ObjectiveCBridgeable {
    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSData {
        return self.withUnsafeBytes {
            NSData(bytes: $0.baseAddress, length: $0.count)
        }
    }
    
    public static func _forceBridgeFromObjectiveC(_ input: NSData, result: inout Data?) {
        // We must copy the input because it might be mutable; just like storing a value type in ObjC
        result = Data(input)
    }
    
    public static func _conditionallyBridgeFromObjectiveC(_ input: NSData, result: inout Data?) -> Bool {
        // We must copy the input because it might be mutable; just like storing a value type in ObjC
        result = Data(input)
        return true
    }

//    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSData?) -> Data {
        guard let src = source else { return Data() }
        return Data(src)
    }
}

extension NSData : _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(Data._unconditionallyBridgeFromObjectiveC(self))
    }
}

// MARK: -
// Temporary extension on Data until this implementation lands in swift-foundation
extension Data {
        /// Find the given `Data` in the content of this `Data`.
    ///
    /// - parameter dataToFind: The data to be searched for.
    /// - parameter options: Options for the search. Default value is `[]`.
    /// - parameter range: The range of this data in which to perform the search. Default value is `nil`, which means the entire content of this data.
    /// - returns: A `Range` specifying the location of the found data, or nil if a match could not be found.
    /// - precondition: `range` must be in the bounds of the Data.
    public func range(of dataToFind: Data, options: Data.SearchOptions = [], in range: Range<Index>? = nil) -> Range<Index>? {
        let nsRange : NSRange
        if let r = range {
            nsRange = NSRange(location: r.lowerBound - startIndex, length: r.upperBound - r.lowerBound)
        } else {
            nsRange = NSRange(location: 0, length: count)
        }

        let ns = self as NSData
        var opts = NSData.SearchOptions()
        if options.contains(.anchored) { opts.insert(.anchored) }
        if options.contains(.backwards) { opts.insert(.backwards) }

        let result = ns.range(of: dataToFind, options: opts, in: nsRange)
        if result.location == NSNotFound {
            return nil
        }
        return (result.location + startIndex)..<((result.location + startIndex) + result.length)
    }
}
