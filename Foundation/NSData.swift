// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

import CoreFoundation

#if os(OSX) || os(iOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

public struct NSDataReadingOptions : OptionSetType {
    public let rawValue : UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    
    public static let DataReadingMappedIfSafe = NSDataReadingOptions(rawValue: UInt(1 << 0))
    public static let DataReadingUncached = NSDataReadingOptions(rawValue: UInt(1 << 1))
    public static let DataReadingMappedAlways = NSDataReadingOptions(rawValue: UInt(1 << 2))
}

public struct NSDataWritingOptions : OptionSetType {
    public let rawValue : UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    
    public static let DataWritingAtomic = NSDataWritingOptions(rawValue: UInt(1 << 0))
    public static let DataWritingWithoutOverwriting = NSDataWritingOptions(rawValue: UInt(1 << 1))
}

public struct NSDataSearchOptions : OptionSetType {
    public let rawValue : UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    
    public static let Backwards = NSDataSearchOptions(rawValue: UInt(1 << 0))
    public static let Anchored = NSDataSearchOptions(rawValue: UInt(1 << 1))
}

public struct NSDataBase64EncodingOptions : OptionSetType {
    public let rawValue : UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    
    public static let Encoding64CharacterLineLength = NSDataBase64EncodingOptions(rawValue: UInt(1 << 0))
    public static let Encoding76CharacterLineLength = NSDataBase64EncodingOptions(rawValue: UInt(1 << 1))
    public static let EncodingEndLineWithCarriageReturn = NSDataBase64EncodingOptions(rawValue: UInt(1 << 4))
    public static let EncodingEndLineWithLineFeed = NSDataBase64EncodingOptions(rawValue: UInt(1 << 5))
}

public struct NSDataBase64DecodingOptions : OptionSetType {
    public let rawValue : UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    
    public static let IgnoreUnknownCharacters = NSDataBase64DecodingOptions(rawValue: UInt(1 << 0))
    public static let Anchored = NSDataSearchOptions(rawValue: UInt(1 << 1))
}

private class _NSDataDeallocator {
    var handler: (() -> ())?
    init(handler: (() -> ())?) {
        self.handler = handler
    }
    
    deinit {
        handler?()
    }
}

public class NSData : NSObject, NSCopying, NSMutableCopying, NSSecureCoding {
    typealias CFType = CFDataRef
    private var _base = _CFInfo(typeID: CFDataGetTypeID())
    private var _length: CFIndex = 0
    private var _capacity: CFIndex = 0
    private var deallocHandler: _NSDataDeallocator?
    private var _bytes: UnsafeMutablePointer<UInt8> = nil
    
    internal var _cfObject: CFType {
        get {
            if self.dynamicType === NSData.self || self.dynamicType === NSMutableData.self {
                return unsafeBitCast(self, CFType.self)
            } else {
                return CFDataCreate(kCFAllocatorSystemDefault, unsafeBitCast(self.bytes, UnsafePointer<UInt8>.self), self.length)
            }
        }
    }
    
    public override required convenience init() {
        self.init(bytes: nil, length: 0, copy: false, deallocator: nil)
    }
    
    deinit {
        deallocHandler = nil
        _CFDeinit(self)
    }
    
    internal init(bytes: UnsafeMutablePointer<Void>, length: Int, copy: Bool, deallocator: ((UnsafeMutablePointer<Void>, Int) -> Void)?) {
        deallocHandler = _NSDataDeallocator {
            deallocator?(bytes, length)
        }
        
        super.init()
        let options : CFOptionFlags = (self.dynamicType == NSMutableData.self) ? 0x1 | 0x2 : 0x0
        if copy {
            _CFDataInit(unsafeBitCast(self, CFMutableDataRef.self), options, length, UnsafeMutablePointer<UInt8>(bytes), length, false)
            deallocHandler = nil

            deallocator?(bytes, length)
        } else {
            _CFDataInit(unsafeBitCast(self, CFMutableDataRef.self), options, length, UnsafeMutablePointer<UInt8>(bytes), length, true)
        }
    }
    
    public var length: Int {
        get {
            return CFDataGetLength(_cfObject)
        }
    }

    public var bytes: UnsafePointer<Void> {
        get {
            return UnsafePointer<Void>(CFDataGetBytePtr(_cfObject))
        }
    }
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        return self
    }
    
    public func mutableCopyWithZone(zone: NSZone) -> AnyObject {
        return NSMutableData(bytes: UnsafeMutablePointer<Void>(bytes), length: length, copy: true, deallocator: nil)
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        NSUnimplemented()
    }
    
    public static func supportsSecureCoding() -> Bool {
        return true
    }
    
    private func byteDescription(limit limit: Int? = nil) -> String {
        var s = ""
        let buffer = UnsafePointer<UInt8>(bytes)
        var i = 0
        while i < self.length {
            if i > 0 && i % 4 == 0 {
                // if there's a limit, and we're at the barrier where we'd add the ellipses, don't add a space.
                if let limit = limit where self.length > limit && i == self.length - (limit / 2) { /* do nothing */ }
                else { s += " " }
            }
            let byte = buffer[i]
            var byteStr = String(byte, radix: 16, uppercase: false)
            if byte <= 0xf { byteStr = "0\(byteStr)" }
            s += byteStr
            // if we've hit the midpoint of the limit, skip to the last (limit / 2) bytes.
            if let limit = limit where self.length > limit && i == (limit / 2) - 1 {
                s += " ... "
                i = self.length - (limit / 2)
            } else {
                i += 1
            }
        }
        return s
    }
    
    override public var debugDescription: String {
        return "<\(byteDescription(limit: 1024))>"
    }
    
    override public var description: String {
        return "<\(byteDescription())>"
    }
    
    override internal var _cfTypeID: CFTypeID {
        return CFDataGetTypeID()
    }
}

extension NSData {
    
    public convenience init(bytes: UnsafePointer<Void>, length: Int) {
        self.init(bytes: UnsafeMutablePointer<Void>(bytes), length: length, copy: true, deallocator: nil)
    }

    public convenience init(bytesNoCopy bytes: UnsafeMutablePointer<Void>, length: Int) {
        self.init(bytes: bytes, length: length, copy: false, deallocator: nil)
    }
    
    public convenience init(bytesNoCopy bytes: UnsafeMutablePointer<Void>, length: Int, freeWhenDone b: Bool) {
        self.init(bytes: bytes, length: length, copy: true) { buffer, length in
            if b {
                free(buffer)
            }
        }
    }

    public convenience init(bytesNoCopy bytes: UnsafeMutablePointer<Void>, length: Int, deallocator: ((UnsafeMutablePointer<Void>, Int) -> Void)?) {
        self.init(bytes: bytes, length: length, copy: false, deallocator: deallocator)
    }
    
    
    internal struct NSDataReadResult {
        var bytes: UnsafeMutablePointer<Void>
        var length: Int
        var deallocator: ((buffer: UnsafeMutablePointer<Void>, length: Int) -> Void)?
    }
    
    internal static func readBytesFromFileWithExtendedAttributes(path: String, options: NSDataReadingOptions) throws -> NSDataReadResult {
        let fd = _CFOpenFile(path, O_RDONLY)
        if fd < 0 {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        
        var info = stat()
        let ret = withUnsafeMutablePointer(&info) { infoPointer -> Bool in
            if fstat(fd, infoPointer) < 0 {
                return false
            }
            return true
        }
        
        if !ret {
            close(fd)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        
        let length = Int(info.st_size)
        
        if options.contains(.DataReadingMappedAlways) {
            let data = mmap(nil, length, PROT_READ, MAP_PRIVATE, fd, 0)
            
            // Swift does not currently expose MAP_FAILURE
            if data != UnsafeMutablePointer<Void>(bitPattern: -1) {
                close(fd)
                return NSDataReadResult(bytes: data, length: length) { buffer, length in
                    munmap(data, length)
                }
            }
            
        }
        
        let data = malloc(length)
        var remaining = Int(info.st_size)
        var total = 0
        while remaining > 0 {
            let amt = read(fd, data.advancedBy(total), remaining)
            if amt < 0 {
                break
            }
            remaining -= amt
            total += amt
        }
        if remaining != 0 {
            close(fd)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        
        return NSDataReadResult(bytes: data, length: length) { buffer, length in
            free(buffer)
        }
    }
    
    public convenience init(contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions) throws {
        let readResult = try NSData.readBytesFromFileWithExtendedAttributes(path, options: readOptionsMask)
        self.init(bytes: readResult.bytes, length: readResult.length, copy: false, deallocator: readResult.deallocator)
    }

    public convenience init?(contentsOfFile path: String) {
        do {
            let readResult = try NSData.readBytesFromFileWithExtendedAttributes(path, options: [])
            self.init(bytes: readResult.bytes, length: readResult.length, copy: false, deallocator: readResult.deallocator)
        } catch {
            return nil
        }
    }

    public convenience init(data: NSData) {
        self.init(bytes:data.bytes, length: data.length)
    }
    
    public convenience init(contentsOfURL url: NSURL, options readOptionsMask: NSDataReadingOptions) throws {
        if url.fileURL {
            try self.init(contentsOfFile: url.path!, options: readOptionsMask)
        } else {
            let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
            let cond = NSCondition()
            var resError: NSError?
            var resData: NSData?
            let task = session.dataTaskWithURL(url, completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
                resData = data
                resError = error
                cond.broadcast()
            })
            task.resume()
            cond.wait()
            if resData == nil {
                throw resError!
            }
            self.init(data: resData!)
        }
    }
    
    public convenience init?(contentsOfURL url: NSURL) {
        do {
            try self.init(contentsOfURL: url, options: [])
        } catch {
            return nil
        }
    }
}

extension NSData {
    public func getBytes(buffer: UnsafeMutablePointer<Void>, length: Int) {
        CFDataGetBytes(_cfObject, CFRangeMake(0, length), UnsafeMutablePointer<UInt8>(buffer))
    }
    
    public func getBytes(buffer: UnsafeMutablePointer<Void>, range: NSRange) {
        CFDataGetBytes(_cfObject, CFRangeMake(range.location, range.length), UnsafeMutablePointer<UInt8>(buffer))
    }
    
    public func isEqualToData(other: NSData) -> Bool {
        if self === other {
            return true
        }
        
        if length != other.length {
            return false
        }
        
        let bytes1 = bytes
        let bytes2 = other.bytes
        if bytes1 == bytes2 {
            return true
        }
        
        return memcmp(bytes1, bytes2, length) == 0
    }
    public func subdataWithRange(range: NSRange) -> NSData {
        if range.length == 0 {
            return NSData()
        }
        if range.location == 0 && range.length == self.length {
            return copyWithZone(nil) as! NSData
        }
        return NSData(bytes: bytes.advancedBy(range.location), length: range.length)
    }
    
    internal func makeTemporaryFileInDirectory(dirPath: String) throws -> (Int32, String) {
        let template = dirPath._nsObject.stringByAppendingPathComponent("tmp.XXXXXX")
        let maxLength = Int(PATH_MAX) + 1
        var buf = [Int8](count: maxLength, repeatedValue: 0)
        template._nsObject.getFileSystemRepresentation(&buf, maxLength: maxLength)
        let fd = mkstemp(&buf)
        if fd == -1 {
            throw _NSErrorWithErrno(errno, reading: false, path: dirPath)
        }
        let pathResult = NSFileManager.defaultManager().stringWithFileSystemRepresentation(buf, length: Int(strlen(buf)))
        return (fd, pathResult)
    }
    
    internal class func writeToFileDescriptor(fd: Int32, path: String? = nil, buf: UnsafePointer<Void>, length: Int) throws {
        var bytesRemaining = length
        while bytesRemaining > 0 {
            var bytesWritten : Int
            repeat {
                bytesWritten = write(fd, buf.advancedBy(length - bytesRemaining), bytesRemaining)
            } while (bytesWritten < 0 && errno == EINTR)
            if bytesWritten <= 0 {
                throw _NSErrorWithErrno(errno, reading: false, path: path)
            } else {
                bytesRemaining -= bytesWritten
            }
        }
    }
    
    public func writeToFile(path: String, options writeOptionsMask: NSDataWritingOptions) throws {
        var fd : Int32
        var mode : mode_t? = nil
        let useAuxiliaryFile = writeOptionsMask.contains(.DataWritingAtomic)
        var auxFilePath : String? = nil
        if useAuxiliaryFile {
            // Preserve permissions.
            var info = stat()
            if lstat(path, &info) == 0 {
                mode = info.st_mode
            } else if errno != ENOENT && errno != ENAMETOOLONG {
                throw _NSErrorWithErrno(errno, reading: false, path: path)
            }
            let (newFD, path) = try self.makeTemporaryFileInDirectory(path._nsObject.stringByDeletingLastPathComponent)
            fd = newFD
            auxFilePath = path
            fchmod(fd, 0o666)
        } else {
            var flags = O_WRONLY | O_CREAT | O_TRUNC
            if writeOptionsMask.contains(.DataWritingWithoutOverwriting) {
                flags |= O_EXCL
            }
            fd = _CFOpenFileWithMode(path, flags, 0o666)
        }
        if fd == -1 {
            throw _NSErrorWithErrno(errno, reading: false, path: path)
        }
        defer {
            close(fd)
        }

        try self.enumerateByteRangesUsingBlockRethrows { (buf, range, stop) in
            if range.length > 0 {
                do {
                    try NSData.writeToFileDescriptor(fd, path: path, buf: buf, length: range.length)
                    if fsync(fd) < 0 {
                        throw _NSErrorWithErrno(errno, reading: false, path: path)
                    }
                } catch let err {
                    if let auxFilePath = auxFilePath {
                        do {
                            try NSFileManager.defaultManager().removeItemAtPath(auxFilePath)
                        } catch _ {}
                    }
                    throw err
                }
            }
        }
        if let auxFilePath = auxFilePath {
            if rename(auxFilePath, path) != 0 {
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(auxFilePath)
                } catch _ {}
                throw _NSErrorWithErrno(errno, reading: false, path: path)
            }
            if let mode = mode {
                chmod(path, mode)
            }
        }
    }
    
    public func writeToFile(path: String, atomically useAuxiliaryFile: Bool) -> Bool {
        do {
            try writeToFile(path, options: useAuxiliaryFile ? .DataWritingAtomic : [])
        } catch {
            return false
        }
        return true
    }
    
    public func writeToURL(url: NSURL, atomically: Bool) -> Bool {
        if url.fileURL {
            if let path = url.path {
                return writeToFile(path, atomically: atomically)
            }
        }
        return false
    }

    ///    Write the contents of the receiver to a location specified by the given file URL.
    ///
    ///    - parameter url:              The location to which the receiver’s contents will be written.
    ///    - parameter writeOptionsMask: An option set specifying file writing options.
    ///
    ///    - throws: This method returns Void and is marked with the `throws` keyword to indicate that it throws an error in the event of failure.
    ///
    ///      This method is invoked in a `try` expression and the caller is responsible for handling any errors in the `catch` clauses of a `do` statement, as described in [Error Handling](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/ErrorHandling.html#//apple_ref/doc/uid/TP40014097-CH42) in [The Swift Programming Language](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/index.html#//apple_ref/doc/uid/TP40014097) and [Error Handling](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/BuildingCocoaApps/AdoptingCocoaDesignPatterns.html#//apple_ref/doc/uid/TP40014216-CH7-ID10) in [Using Swift with Cocoa and Objective-C](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/BuildingCocoaApps/index.html#//apple_ref/doc/uid/TP40014216).
    public func writeToURL(url: NSURL, options writeOptionsMask: NSDataWritingOptions) throws {
        guard let path = url.path where url.fileURL == true else {
            let userInfo = [NSLocalizedDescriptionKey : "The folder at “\(url)” does not exist or is not a file URL.", // NSLocalizedString() not yet available
                            NSURLErrorKey             : url.absoluteString ?? ""] as Dictionary<String, Any>
            throw NSError(domain: NSCocoaErrorDomain, code: 4, userInfo: userInfo)
        }
        try writeToFile(path, options: writeOptionsMask)
    }
    
    internal func enumerateByteRangesUsingBlockRethrows(block: (UnsafePointer<Void>, NSRange, UnsafeMutablePointer<Bool>) throws -> Void) throws {
        var err : ErrorType? = nil
        self.enumerateByteRangesUsingBlock() { (buf, range, stop) -> Void in
            do {
                try block(buf, range, stop)
            } catch let e {
                err = e
            }
        }
        if let err = err {
            throw err
        }
    }

    public func enumerateByteRangesUsingBlock(block: (UnsafePointer<Void>, NSRange, UnsafeMutablePointer<Bool>) -> Void) {
        var stop = false
        withUnsafeMutablePointer(&stop) { stopPointer in
            block(bytes, NSMakeRange(0, length), stopPointer)
        }
    }
}

extension NSData : _CFBridgable { }

extension CFDataRef : _NSBridgable {
    typealias NSType = NSData
    internal var _nsObject: NSType { return unsafeBitCast(self, NSType.self) }
}

extension NSMutableData {
    internal var _cfMutableObject: CFMutableDataRef { return unsafeBitCast(self, CFMutableDataRef.self) }
}

public class NSMutableData : NSData {

    public required convenience init() {
        self.init(bytes: nil, length: 0)
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        NSUnimplemented()
    }

    
    internal override init(bytes: UnsafeMutablePointer<Void>, length: Int, copy: Bool, deallocator: ((UnsafeMutablePointer<Void>, Int) -> Void)?) {
        super.init(bytes: bytes, length: length, copy: copy, deallocator: deallocator)
    }
    
    public var mutableBytes: UnsafeMutablePointer<Void> {
        get {
            return UnsafeMutablePointer(CFDataGetMutableBytePtr(_cfMutableObject))
        }
    }
    
    public override var length: Int {
        get {
            return CFDataGetLength(_cfObject)
        }
        set {
            CFDataSetLength(_cfMutableObject, newValue)
        }
    }
    
    public override func copyWithZone(zone: NSZone) -> AnyObject {
        return NSData(data: self)
    }
}

extension NSData {
    
    /* Create an NSData from a Base-64 encoded NSString using the given options. By default, returns nil when the input is not recognized as valid Base-64.
    */
    public convenience init?(base64EncodedString base64String: String, options: NSDataBase64DecodingOptions) {
        NSUnimplemented()
    }
    
    /* Create a Base-64 encoded NSString from the receiver's contents using the given options.
    */
    public func base64EncodedStringWithOptions(options: NSDataBase64EncodingOptions) -> String {
        NSUnimplemented()
    }
    
    /* Create an NSData from a Base-64, UTF-8 encoded NSData. By default, returns nil when the input is not recognized as valid Base-64.
    */
    public convenience init?(base64EncodedData base64Data: NSData, options: NSDataBase64DecodingOptions) {
        NSUnimplemented()
    }
    
    /* Create a Base-64, UTF-8 encoded NSData from the receiver's contents using the given options.
    */
    public func base64EncodedDataWithOptions(options: NSDataBase64EncodingOptions) -> NSData {
        NSUnimplemented()
    }
}

extension NSMutableData {

    public func appendBytes(bytes: UnsafePointer<Void>, length: Int) {
        CFDataAppendBytes(_cfMutableObject, UnsafePointer<UInt8>(bytes), length)
    }
    
    public func appendData(other: NSData) {
        appendBytes(other.bytes, length: other.length)
    }
    
    public func increaseLengthBy(extraLength: Int) {
        CFDataSetLength(_cfMutableObject, CFDataGetLength(_cfObject) + extraLength)
    }
    
    public func replaceBytesInRange(range: NSRange, withBytes bytes: UnsafePointer<Void>) {
        CFDataReplaceBytes(_cfMutableObject, CFRangeMake(range.location, range.length), UnsafePointer<UInt8>(bytes), length)
    }
    
    public func resetBytesInRange(range: NSRange) {
        bzero(mutableBytes.advancedBy(range.location), range.length)
    }
    
    public func setData(data: NSData) {
        length = data.length
        replaceBytesInRange(NSMakeRange(0, data.length), withBytes: data.bytes)
    }
    
    public func replaceBytesInRange(range: NSRange, withBytes replacementBytes: UnsafePointer<Void>, length replacementLength: Int) {
        CFDataReplaceBytes(_cfMutableObject, CFRangeMake(range.location, range.length), UnsafePointer<UInt8>(bytes), replacementLength)
    }
}

extension NSMutableData {
    
    public convenience init?(capacity: Int) {
        self.init(bytes: nil, length: 0)
    }
    
    public convenience init?(length: Int) {
        let memory = malloc(length)
        self.init(bytes: memory, length: length, copy: false) { buffer, amount in
            free(buffer)
        }
    }
}
