// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


@_implementationOnly import CoreFoundation
#if os(Windows)
import WinSDK
#endif

internal let kCFURLPOSIXPathStyle = CFURLPathStyle.cfurlposixPathStyle
internal let kCFURLWindowsPathStyle = CFURLPathStyle.cfurlWindowsPathStyle

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#endif

// NOTE: this represents PLATFORM_PATH_STYLE
#if os(Windows)
internal let kCFURLPlatformPathStyle = kCFURLWindowsPathStyle
#else
internal let kCFURLPlatformPathStyle = kCFURLPOSIXPathStyle
#endif

private func _standardizedPath(_ path: String) -> String {
    if !path.isAbsolutePath {
        return path._nsObject.standardizingPath
    }
#if os(Windows)
    return path.unixPath
#else
    return path
#endif
}

internal func _pathComponents(_ path: String?) -> [String]? {
    guard let p = path else {
        return nil
    }

    var result = [String]()
    if p.length == 0 {
        return result
    } else {
        let characterView = p
        var curPos = characterView.startIndex
        let endPos = characterView.endIndex
        if characterView[curPos] == "/" {
            result.append("/")
        }

        while curPos < endPos {
            while curPos < endPos && characterView[curPos] == "/" {
                curPos = characterView.index(after: curPos)
            }
            if curPos == endPos {
                break
            }
            var curEnd = curPos
            while curEnd < endPos && characterView[curEnd] != "/" {
                curEnd = characterView.index(after: curEnd)
            }
            result.append(String(characterView[curPos ..< curEnd]))
            curPos = curEnd
        }
    }
    if p.length > 1 && p.hasSuffix("/") {
        result.append("/")
    }
    return result
}

open class NSURL : NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    typealias CFType = CFURL
    internal var _base = _CFInfo(typeID: CFURLGetTypeID())
    internal var _flags : UInt32 = 0
    internal var _encoding : UInt32 = 0 // CFStringEncoding
    internal var _string : UnsafeMutablePointer<AnyObject>? = nil // CFString
    internal var _baseURL : UnsafeMutablePointer<AnyObject>? = nil // CFURL
    internal var _extra : OpaquePointer? = nil
    internal var _resourceInfo : OpaquePointer? = nil
    internal var _range1 = NSRange(location: 0, length: 0)
    internal var _range2 = NSRange(location: 0, length: 0)
    internal var _range3 = NSRange(location: 0, length: 0)
    internal var _range4 = NSRange(location: 0, length: 0)
    internal var _range5 = NSRange(location: 0, length: 0)
    internal var _range6 = NSRange(location: 0, length: 0)
    internal var _range7 = NSRange(location: 0, length: 0)
    internal var _range8 = NSRange(location: 0, length: 0)
    internal var _range9 = NSRange(location: 0, length: 0)
    
    internal final var _cfObject : CFType {
        if type(of: self) === NSURL.self {
            return unsafeBitCast(self, to: CFType.self)
        } else {
            return CFURLCreateWithString(kCFAllocatorSystemDefault, relativeString._cfObject, self.baseURL?._cfObject)
        }
    }
    
    var _resourceStorage: URLResourceValuesStorage? {
        guard isFileURL else { return nil }
        
        if let storage = _resourceStorageIfPresent {
            return storage
        } else {
            let me = unsafeBitCast(self, to: CFURL.self)
            let initial = URLResourceValuesStorage()
            let result = _CFURLCopyResourceInfoInitializingAtomicallyIfNeeded(me, initial)
            return Unmanaged<URLResourceValuesStorage>.fromOpaque(result).takeRetainedValue()
        }
    }
    
    var _resourceStorageIfPresent: URLResourceValuesStorage? {
        guard isFileURL else { return nil }
        
        let me = unsafeBitCast(self, to: CFURL.self)
        if let storage = _CFURLCopyResourceInfo(me) {
            return Unmanaged<URLResourceValuesStorage>.fromOpaque(storage).takeRetainedValue()
        } else {
            return nil
        }
    }
    
    open override var hash: Int {
        return Int(bitPattern: CFHash(_cfObject))
    }
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? NSURL else { return false }
        return CFEqual(_cfObject, other._cfObject)
    }
    
    open override var description: String {
        if self.relativeString != self.absoluteString {
            return "\(self.relativeString) -- \(self.baseURL!)"
        } else {
            return self.absoluteString
        }
    }

    deinit {
        _CFDeinit(self)
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        if isFileURL {
            let newURL = CFURLCreateWithString(kCFAllocatorSystemDefault, relativeString._cfObject, self.baseURL?._cfObject)!
            if let storage = _resourceStorageIfPresent {
                let newStorage = URLResourceValuesStorage(copying: storage)
                _CFURLSetResourceInfo(newURL, newStorage)
            }
            return newURL._nsObject
        } else {
            return self
        }
    }
    
    public static var supportsSecureCoding: Bool { return true }
    
    public convenience required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        let base = aDecoder.decodeObject(of: NSURL.self, forKey:"NS.base")?._swiftObject
        let relative = aDecoder.decodeObject(of: NSString.self, forKey:"NS.relative")

        if relative == nil {
            return nil
        }

        self.init(string: String._unconditionallyBridgeFromObjectiveC(relative!), relativeTo: base)
    }
    
    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        aCoder.encode(self.baseURL?._nsObject, forKey:"NS.base")
        aCoder.encode(self.relativeString._bridgeToObjectiveC(), forKey:"NS.relative")
    }
    
    public init(fileURLWithPath path: String, isDirectory isDir: Bool, relativeTo baseURL: URL?) {
        super.init()
        
        let thePath = _standardizedPath(path)
        if thePath.length > 0 {
            
            _CFURLInitWithFileSystemPathRelativeToBase(_cfObject, thePath._cfObject, kCFURLPlatformPathStyle, isDir, baseURL?._cfObject)
        } else if let baseURL = baseURL {
            _CFURLInitWithFileSystemPathRelativeToBase(_cfObject, baseURL.path._cfObject, kCFURLPlatformPathStyle, baseURL.hasDirectoryPath, nil)
        }
    }
    
    public convenience init(fileURLWithPath path: String, relativeTo baseURL: URL?) {
        let thePath = _standardizedPath(path)
        
        var isDir: ObjCBool = false
        if validPathSeps.contains(where: { thePath.hasSuffix(String($0)) }) {
            isDir = true
        } else {
#if !os(WASI)
            let absolutePath: String
            if let absPath = baseURL?.appendingPathComponent(path).path {
                absolutePath = absPath
            } else {
                absolutePath = path
            }
            
            let _ = FileManager.default.fileExists(atPath: absolutePath, isDirectory: &isDir)
#endif
        }

        self.init(fileURLWithPath: thePath, isDirectory: isDir.boolValue, relativeTo: baseURL)
    }

    public convenience init(fileURLWithPath path: String, isDirectory isDir: Bool) {
        self.init(fileURLWithPath: path, isDirectory: isDir, relativeTo: nil)
    }

    public init(fileURLWithPath path: String) {
        let thePath: String = _standardizedPath(path)

        var isDir: ObjCBool = false
        if validPathSeps.contains(where: { thePath.hasSuffix(String($0)) }) {
            isDir = true
        } else {
#if !os(WASI)
            if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                isDir = false
            }
#endif
        }
        super.init()
        _CFURLInitWithFileSystemPathRelativeToBase(_cfObject, thePath._cfObject, kCFURLPlatformPathStyle, isDir.boolValue, nil)
    }
    
    public convenience init(fileURLWithFileSystemRepresentation path: UnsafePointer<Int8>, isDirectory isDir: Bool, relativeTo baseURL: URL?) {

        let pathString = String(cString: path)
        self.init(fileURLWithPath: pathString, isDirectory: isDir, relativeTo: baseURL)
    }
    
    public convenience init?(string URLString: String) {
        self.init(string: URLString, relativeTo:nil)
    }
    
    public init?(string URLString: String, relativeTo baseURL: URL?) {
        super.init()
        if !_CFURLInitWithURLString(_cfObject, URLString._cfObject, true, baseURL?._cfObject) {
            return nil
        }
    }
    
    public init(dataRepresentation data: Data, relativeTo baseURL: URL?) {
        super.init()
        
        // _CFURLInitWithURLString does not fail if checkForLegalCharacters == false
        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Void in
            let ptr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            if let str = CFStringCreateWithBytes(kCFAllocatorSystemDefault, ptr, data.count, CFStringEncoding(kCFStringEncodingUTF8), false) {
                _CFURLInitWithURLString(_cfObject, str, false, baseURL?._cfObject)
            } else if let str = CFStringCreateWithBytes(kCFAllocatorSystemDefault, ptr, data.count, CFStringEncoding(kCFStringEncodingISOLatin1), false) {
                _CFURLInitWithURLString(_cfObject, str, false, baseURL?._cfObject)
            } else {
                fatalError()
            }
        }
    }
    
    public init(absoluteURLWithDataRepresentation data: Data, relativeTo baseURL: URL?) {
        super.init()
        
        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Void in
            let ptr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            if _CFURLInitAbsoluteURLWithBytes(_cfObject, ptr, data.count, CFStringEncoding(kCFStringEncodingUTF8), baseURL?._cfObject) {
                return
            }
            if _CFURLInitAbsoluteURLWithBytes(_cfObject, ptr, data.count, CFStringEncoding(kCFStringEncodingISOLatin1), baseURL?._cfObject) {
                return
            }
            fatalError()
        }
    }
    
    /* Returns the data representation of the URL's relativeString. If the URL was initialized with -initWithData:relativeTo:, the data representation returned are the same bytes as those used at initialization; otherwise, the data representation returned are the bytes of the relativeString encoded with NSUTF8StringEncoding.
    */
    open var dataRepresentation: Data {
        let bytesNeeded = CFURLGetBytes(_cfObject, nil, 0)
        assert(bytesNeeded > 0)
        
        let buffer = malloc(bytesNeeded)!.bindMemory(to: UInt8.self, capacity: bytesNeeded)
        let bytesFilled = CFURLGetBytes(_cfObject, buffer, bytesNeeded)
        if bytesFilled == bytesNeeded {
            return Data(bytesNoCopy: buffer, count: bytesNeeded, deallocator: .free)
        } else {
            fatalError()
        }
    }
    
    open var absoluteString: String {
        if let absURL = CFURLCopyAbsoluteURL(_cfObject) {
            return CFURLGetString(absURL)._swiftObject
        }

        return CFURLGetString(_cfObject)._swiftObject
    }
    
    // The relative portion of a URL.  If baseURL is nil, or if the receiver is itself absolute, this is the same as absoluteString
    open var relativeString: String {
        return CFURLGetString(_cfObject)._swiftObject
    }
    
    open var baseURL: URL? {
        return CFURLGetBaseURL(_cfObject)?._swiftObject
    }
    
    // if the receiver is itself absolute, this will return self.
    open var absoluteURL: URL? {
        return CFURLCopyAbsoluteURL(_cfObject)?._swiftObject
    }
    
    /* Any URL is composed of these two basic pieces.  The full URL would be the concatenation of [myURL scheme], ':', [myURL resourceSpecifier]
    */
    open var scheme: String? {
        return CFURLCopyScheme(_cfObject)?._swiftObject
    }
    
    internal var _isAbsolute : Bool {
        return self.baseURL == nil && self.scheme != nil
    }
    
    open var resourceSpecifier: String? {
        // Note that this does NOT have the same meaning as CFURL's resource specifier, which, for decomposeable URLs is merely that portion of the URL which comes after the path.  NSURL means everything after the scheme.
        if !_isAbsolute {
            return self.relativeString
        } else {
            let cf = _cfObject
            guard CFURLCanBeDecomposed(cf) else {
                return CFURLCopyResourceSpecifier(cf)?._swiftObject
            }
            guard baseURL == nil else {
                return CFURLGetString(cf)?._swiftObject
            }
            
            let netLoc = CFURLCopyNetLocation(cf)?._swiftObject
            let path = CFURLCopyPath(cf)?._swiftObject
            let theRest = CFURLCopyResourceSpecifier(cf)?._swiftObject
            
            if let netLoc = netLoc {
                let p = path ?? ""
                let rest = theRest ?? ""
                return "//\(netLoc)\(p)\(rest)"
            } else if let path = path {
                let rest = theRest ?? ""
                return "\(path)\(rest)"
            } else {
                return theRest
            }
        }
    }
    
    /* If the URL conforms to rfc 1808 (the most common form of URL), the following accessors will return the various components; otherwise they return nil.  The litmus test for conformance is as recommended in RFC 1808 - whether the first two characters of resourceSpecifier is @"//".  In all cases, they return the component's value after resolving the receiver against its base URL.
    */
    open var host: String? {
        return CFURLCopyHostName(_cfObject)?._swiftObject
    }
    
    open var port: NSNumber? {
        let port = CFURLGetPortNumber(_cfObject)
        if port == -1 {
            return nil
        } else {
            return NSNumber(value: port)
        }
    }
    
    open var user: String? {
        return CFURLCopyUserName(_cfObject)?._swiftObject
    }
    
    open var password: String? {
        let absoluteURL = CFURLCopyAbsoluteURL(_cfObject)
        let passwordRange = CFURLGetByteRangeForComponent(absoluteURL, .password, nil)
        guard passwordRange.location != kCFNotFound else {
            return nil
        }
        
        // For historical reasons, the password string should _not_ have its percent escapes removed.
        let bufSize = CFURLGetBytes(absoluteURL, nil, 0)
        let buf = [UInt8](unsafeUninitializedCapacity: bufSize) { buffer, initializedCount in
            initializedCount = CFURLGetBytes(absoluteURL, buffer.baseAddress, buffer.count)
            precondition(initializedCount == bufSize, "Inconsistency in CFURLGetBytes")
        }

        let passwordBuf = buf[passwordRange.location ..< passwordRange.location+passwordRange.length]
        return passwordBuf.withUnsafeBufferPointer { ptr in
            NSString(bytes: ptr.baseAddress!, length: passwordBuf.count, encoding: String.Encoding.utf8.rawValue)?._swiftObject
        }
    }
    
    open var path: String? {
        let absURL = CFURLCopyAbsoluteURL(_cfObject)
        guard var url = CFURLCopyFileSystemPath(absURL, kCFURLPOSIXPathStyle)?._swiftObject else {
            return nil
        }
#if os(Windows)
        // Per RFC 8089:E.2, if we have an absolute Windows/DOS path we can
        // begin the URL with a drive letter rather than a `/`
        let scalars = Array(url.unicodeScalars)
        if isFileURL, url.isAbsolutePath,
           scalars.count >= 3, scalars[0] == "/", scalars[2] == ":" {
            url.removeFirst()
        }
#endif
        return url
    }
    
    open var fragment: String? {
        return CFURLCopyFragment(_cfObject, nil)?._swiftObject
    }
    
    @available(swift, deprecated: 5.3, message: "The parameterString property is deprecated. When executing on Swift 5.3 or later, parameterString will always return nil, and the path method will return the complete path including the semicolon separator and params component if the URL string contains them.")
    open var parameterString: String? {
        return CFURLCopyParameterString(_cfObject, nil)?._swiftObject
    }
    
    open var query: String? {
        return CFURLCopyQueryString(_cfObject, nil)?._swiftObject
    }
    
    // The same as path if baseURL is nil
    open var relativePath: String? {
        guard var url = CFURLCopyFileSystemPath(_cfObject, kCFURLPOSIXPathStyle)?._swiftObject else {
            return nil
        }
#if os(Windows)
        // Per RFC 8089:E.2, if we have an absolute Windows/DOS path we can
        // begin the URL with a drive letter rather than a `/`
        let scalars = Array(url.unicodeScalars)
        if isFileURL, url.isAbsolutePath,
           scalars.count >= 3, scalars[0] == "/", scalars[2] == ":" {
            url.removeFirst()
        }
#endif
        return url
    }
    
    /* Determines if a given URL string's path represents a directory (i.e. the path component in the URL string ends with a '/' character). This does not check the resource the URL refers to.
    */
    open var hasDirectoryPath: Bool {
        return CFURLHasDirectoryPath(_cfObject)
    }
    
    /* Returns the URL's path in file system representation. File system representation is a null-terminated C string with canonical UTF-8 encoding.
    */
    open func getFileSystemRepresentation(_ buffer: UnsafeMutablePointer<Int8>, maxLength maxBufferLength: Int) -> Bool {
        return buffer.withMemoryRebound(to: UInt8.self, capacity: maxBufferLength) {
            CFURLGetFileSystemRepresentation(_cfObject, true, $0, maxBufferLength)
        }
    }

#if os(Windows)
    internal func _getWideFileSystemRepresentation(_ buffer: UnsafeMutablePointer<UInt16>, maxLength: Int) -> Bool {
      _CFURLGetWideFileSystemRepresentation(_cfObject, true, buffer, maxLength)
    }
#endif

    /* Returns the URL's path in file system representation. File system representation is a null-terminated C string with canonical UTF-8 encoding. The returned C string will be automatically freed just as a returned object would be released; your code should copy the representation or use getFileSystemRepresentation:maxLength: if it needs to store the representation outside of the autorelease context in which the representation is created.
    */
    
    // Memory leak. See https://github.com/apple/swift-corelibs-foundation/blob/master/Docs/Issues.md
    open var fileSystemRepresentation: UnsafePointer<Int8> {
#if os(Windows)
        if let resolved = CFURLCopyAbsoluteURL(_cfObject),
                let representation = CFURLCopyFileSystemPath(resolved, kCFURLWindowsPathStyle)?._swiftObject {
            let buffer = representation.withCString {
                let len = strlen($0)
                let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: len + 1)
                buffer.initialize(from: $0, count: len + 1)
                return buffer
            }
            return UnsafePointer(buffer)
        }
#else
        let bufSize = Int(PATH_MAX + 1)

        let _fsrBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufSize)
        _fsrBuffer.initialize(repeating: 0, count: bufSize)

        if getFileSystemRepresentation(_fsrBuffer, maxLength: bufSize) {
            return UnsafePointer(_fsrBuffer)
        }
#endif

        // FIXME: This used to return nil, but the corresponding Darwin
        // implementation is marked as non-nullable.
        fatalError("URL cannot be expressed in the filesystem representation;" +
                   "use getFileSystemRepresentation to handle this case")
    }

#if os(Windows)
    internal var _wideFileSystemRepresentation: UnsafePointer<UInt16> {
      let capacity: Int = Int(MAX_PATH) + 1
      let buffer: UnsafeMutablePointer<UInt16> =
          UnsafeMutablePointer<UInt16>.allocate(capacity: capacity)
      buffer.initialize(repeating: 0, count: capacity)

      if _getWideFileSystemRepresentation(buffer, maxLength: capacity) {
        return UnsafePointer(buffer)
      }

      fatalError("URL cannot be expressed in the filesystem representation; use getFileSystemRepresentation to handle this case")
    }
#endif

    // Whether the scheme is file:; if myURL.isFileURL is true, then myURL.path is suitable for input into FileManager or NSPathUtilities.
    open var isFileURL: Bool {
        return _CFURLIsFileURL(_cfObject)
    }
    
    /* A string constant for the "file" URL scheme. If you are using this to compare to a URL's scheme to see if it is a file URL, you should instead use the NSURL fileURL property -- the fileURL property is much faster. */
    open var standardized: URL? {
        guard path != nil else {
            return nil
        }

        guard let components = NSURLComponents(string: relativeString), let componentPath = components.path else {
            return nil
        }

        if componentPath.contains("..") || componentPath.contains(".") {
            components.path = _pathByRemovingDots(pathComponents!)
        }

        if let filePath = components.path, isFileURL {
            return URL(fileURLWithPath: filePath, isDirectory: hasDirectoryPath, relativeTo: baseURL)
        }

        return components.url(relativeTo: baseURL)
    }
    
    /* Returns whether the URL's resource exists and is reachable. This method synchronously checks if the resource's backing store is reachable. Checking reachability is appropriate when making decisions that do not require other immediate operations on the resource, e.g. periodic maintenance of UI state that depends on the existence of a specific document. When performing operations such as opening a file or copying resource properties, it is more efficient to simply try the operation and handle failures. If this method returns NO, the optional error is populated. This method is currently applicable only to URLs for file system resources. For other URL types, NO is returned. Symbol is present in iOS 4, but performs no operation.
    */
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation as a suitable alternative
    /// - Note: Since this API is under consideration it may be either removed or revised in the near future
    // TODO: should be `checkResourceIsReachableAndReturnError` with autoreleased error parameter.
    // Currently Autoreleased pointers is not supported on Linux.
    open func checkResourceIsReachable() throws -> Bool {
        guard isFileURL,
            let path = path else {
                throw NSError(domain: NSCocoaErrorDomain,
                              code: CocoaError.Code.fileReadUnsupportedScheme.rawValue)
        }
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw NSError(domain: NSCocoaErrorDomain,
                          code: CocoaError.Code.fileReadNoSuchFile.rawValue,
                          userInfo: [
                            "NSURL" : self,
                            "NSFilePath" : path])
        }
        
        return true
    }

    /* Returns a file path URL that refers to the same resource as a specified URL. File path URLs use a file system style path. An error will occur if the url parameter is not a file URL. A file reference URL's resource must exist and be reachable to be converted to a file path URL. Symbol is present in iOS 4, but performs no operation.
    */
    open var filePathURL: URL? {
        guard isFileURL else {
            return nil
        }

        return URL(string: absoluteString)
    }
    
    internal override var _cfTypeID: CFTypeID {
        return CFURLGetTypeID()
    }

    open func removeAllCachedResourceValues() {
        _resourceStorage?.removeAllCachedResourceValues()
    }
    open func removeCachedResourceValue(forKey key: URLResourceKey) {
        _resourceStorage?.removeCachedResourceValue(forKey: key)
    }
    open  func getResourceValue(_ value: inout AnyObject?, forKey key: URLResourceKey) throws {
        guard let storage = _resourceStorage else { value = nil; return }
        try storage.getResourceValue(&value, forKey: key, url: self)
    }
    open func resourceValues(forKeys keys: [URLResourceKey]) throws -> [URLResourceKey : Any] {
        guard let storage = _resourceStorage else { return [:] }
        return try storage.resourceValues(forKeys: keys, url: self)
    }
    open func setResourceValue(_ value: Any?, forKey key: URLResourceKey) throws {
        guard let storage = _resourceStorage else { return }
        try storage.setResourceValue(value, forKey: key, url: self)
    }
    open func setResourceValues(_ keyedValues: [URLResourceKey : Any]) throws {
        guard let storage = _resourceStorage else { return }
        try storage.setResourceValues(keyedValues, url: self)
    }
    open func setTemporaryResourceValue(_ value: Any?, forKey key: URLResourceKey) {
        guard let storage = _resourceStorage else { return }
        storage.setTemporaryResourceValue(value, forKey: key)
    }
}

internal class URLResourceValuesStorage: NSObject {
    let valuesCacheLock = NSLock()
    var valuesCache: [URLResourceKey: Any] = [:]
    
    func removeAllCachedResourceValues() {
        valuesCacheLock.lock()
        defer { valuesCacheLock.unlock() }
        
        valuesCache = [:]
    }
    
    func removeCachedResourceValue(forKey key: URLResourceKey) {
        valuesCacheLock.lock()
        defer { valuesCacheLock.unlock() }
        
        valuesCache.removeValue(forKey: key)
    }
    
    func setTemporaryResourceValue(_ value: Any?, forKey key: URLResourceKey) {
        valuesCacheLock.lock()
        defer { valuesCacheLock.unlock() }
        
        if let value = value {
            valuesCache[key] = value
        } else {
            valuesCache.removeValue(forKey: key)
        }
    }
    
    func getResourceValue(_ value: inout AnyObject?,
                          forKey key: URLResourceKey, url: NSURL) throws {
        let cached = valuesCacheLock.synchronized {
            return valuesCache[key]
        }
        
        if let cached = cached {
            value = __SwiftValue.store(cached)
            return
        }
        
        let fetchedValues = try read([key], for: url)
        if let fetched = fetchedValues[key] {
            valuesCacheLock.synchronized {
                valuesCache[key] = fetched
            }
            value = __SwiftValue.store(fetched)
        } else {
            value = nil
        }
    }
    
    func resourceValues(forKeys keys: [URLResourceKey], url: NSURL) throws -> [URLResourceKey : Any] {
        
        var result: [URLResourceKey : Any] = [:]
        
        var keysToFetch: [URLResourceKey] = []
        valuesCacheLock.synchronized {
            for key in keys {
                if let value = valuesCache[key] {
                    result[key] = value
                } else {
                    keysToFetch.append(key)
                }
            }
        }
        
        if keysToFetch.count > 0 {
            let found = try read(keysToFetch, for: url).compactMapValues { $0 }
            
            valuesCacheLock.synchronized {
                valuesCache.merge(found, uniquingKeysWith: { $1 })
            }
            
            result.merge(found, uniquingKeysWith: { $1 })
        }
        
        return result
    }
    
    func setResourceValue(_ value: Any?, forKey key: URLResourceKey, url: NSURL) throws {
        try write([key: value], to: url)
        
        valuesCacheLock.lock()
        defer { valuesCacheLock.unlock() }
        
        valuesCache[key] = value
    }
    
    func setResourceValues(_ keyedValues: [URLResourceKey : Any], url: NSURL) throws {
        try write(keyedValues, to: url)
        
        valuesCacheLock.lock()
        defer { valuesCacheLock.unlock() }
        
        valuesCache.merge(keyedValues, uniquingKeysWith: { $1 })
    }
    
    internal override init() {
        super.init()
    }
    
    internal init(copying storage: URLResourceValuesStorage) {
        storage.valuesCacheLock.lock()
        defer { storage.valuesCacheLock.unlock() }
        
        valuesCache = storage.valuesCache
        super.init()
    }
}

extension NSCharacterSet {
    
    // Predefined character sets for the six URL components and subcomponents which allow percent encoding. These character sets are passed to -stringByAddingPercentEncodingWithAllowedCharacters:.
    
    // Returns a character set containing the characters allowed in an URL's user subcomponent.
    public class var urlUserAllowed: CharacterSet {
        return _CFURLComponentsGetURLUserAllowedCharacterSet()._swiftObject
    }
    
    // Returns a character set containing the characters allowed in an URL's password subcomponent.
    public class var urlPasswordAllowed: CharacterSet {
        return _CFURLComponentsGetURLPasswordAllowedCharacterSet()._swiftObject
    }
    
    // Returns a character set containing the characters allowed in an URL's host subcomponent.
    public class var urlHostAllowed: CharacterSet {
        return _CFURLComponentsGetURLHostAllowedCharacterSet()._swiftObject
    }
    
    // Returns a character set containing the characters allowed in an URL's path component. ';' is a legal path character, but it is recommended that it be percent-encoded for best compatibility with NSURL (-stringByAddingPercentEncodingWithAllowedCharacters: will percent-encode any ';' characters if you pass the URLPathAllowedCharacterSet).
    public class var urlPathAllowed: CharacterSet {
        return _CFURLComponentsGetURLPathAllowedCharacterSet()._swiftObject
    }
    
    // Returns a character set containing the characters allowed in an URL's query component.
    public class var urlQueryAllowed: CharacterSet {
        return _CFURLComponentsGetURLQueryAllowedCharacterSet()._swiftObject
    }
    
    // Returns a character set containing the characters allowed in an URL's fragment component.
    public class var urlFragmentAllowed: CharacterSet {
        return _CFURLComponentsGetURLFragmentAllowedCharacterSet()._swiftObject
    }
}

extension NSString {
    
    // Returns a new string made from the receiver by replacing all characters not in the allowedCharacters set with percent encoded characters. UTF-8 encoding is used to determine the correct percent encoded characters. Entire URL strings cannot be percent-encoded. This method is intended to percent-encode an URL component or subcomponent string, NOT the entire URL string. Any characters in allowedCharacters outside of the 7-bit ASCII range are ignored.
    public func addingPercentEncoding(withAllowedCharacters allowedCharacters: CharacterSet) -> String? {
        return _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, self._cfObject, allowedCharacters._cfObject)._swiftObject
    }
    
    // Returns a new string made from the receiver by replacing all percent encoded sequences with the matching UTF-8 characters.
    public var removingPercentEncoding: String? {
        return _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, self._cfObject)?._swiftObject
    }
}

extension NSURL {
    
    /* The following methods work on the path portion of a URL in the same manner that the NSPathUtilities methods on NSString do.
    */
    public class func fileURL(withPathComponents components: [String]) -> URL? {
        let path = NSString.path(withComponents: components)
        if components.last == "/" {
            return URL(fileURLWithPath: path, isDirectory: true)
        } else {
            return URL(fileURLWithPath: path)
        }
    }
    
    internal func _pathByFixingSlashes(compress : Bool = true, stripTrailing: Bool = true) -> String? {
        guard let p = path else {
            return nil
        }

        if p == "/" {
            return p
        }

        var result = p
        if compress {
            let startPos = result.startIndex
            var endPos = result.endIndex
            var curPos = startPos

            while curPos < endPos {
                if result[curPos] == "/" {
                    var afterLastSlashPos = curPos
                    while afterLastSlashPos < endPos && result[afterLastSlashPos] == "/" {
                        afterLastSlashPos = result.index(after: afterLastSlashPos)
                    }
                    if afterLastSlashPos != result.index(after: curPos) {
                        result.replaceSubrange(curPos ..< afterLastSlashPos, with: ["/"])
                        endPos = result.endIndex
                    }
                    curPos = afterLastSlashPos
                } else {
                    curPos = result.index(after: curPos)
                }
            }
        }
        if stripTrailing && result.hasSuffix("/") {
            result.remove(at: result.index(before: result.endIndex))
        }
        return result
    }

    public var pathComponents: [String]? {
        return _pathComponents(path)
    }
    
    public var lastPathComponent: String? {
        guard let fixedSelf = _pathByFixingSlashes() else {
            return nil
        }
        if fixedSelf.length <= 1 {
            return fixedSelf
        }
        
        return String(fixedSelf.suffix(from: fixedSelf._startOfLastPathComponent))
    }
    
    public var pathExtension: String? {
        guard let fixedSelf = _pathByFixingSlashes() else {
            return nil
        }
        if fixedSelf.length <= 1 {
            return ""
        }
        
        if let extensionPos = fixedSelf._startOfPathExtension {
            return String(fixedSelf.suffix(from: extensionPos))
        } else {
            return ""
        }
    }
    
    public func appendingPathComponent(_ pathComponent: String) -> URL? {
        var result : URL? = appendingPathComponent(pathComponent, isDirectory: false)

        // File URLs can't be handled on WASI without file system access
#if !os(WASI)
        // Since we are appending to a URL, path seperators should
        // always be '/', even if we're on Windows
        if !pathComponent.hasSuffix("/") && isFileURL {
            if let urlWithoutDirectory = result {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: urlWithoutDirectory.path, isDirectory: &isDir) && isDir.boolValue {
                    result = self.appendingPathComponent(pathComponent, isDirectory: true)
                }
            }
    
        }
#endif
        return result
    }
    
    public func appendingPathComponent(_ pathComponent: String, isDirectory: Bool) -> URL? {
        return CFURLCreateCopyAppendingPathComponent(kCFAllocatorSystemDefault, _cfObject, pathComponent._cfObject, isDirectory)?._swiftObject
    }
    
    public var deletingLastPathComponent: URL? {
        return CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorSystemDefault, _cfObject)?._swiftObject
    }
    
    public func appendingPathExtension(_ pathExtension: String) -> URL? {
        return CFURLCreateCopyAppendingPathExtension(kCFAllocatorSystemDefault, _cfObject, pathExtension._cfObject)?._swiftObject
    }
    
    public var deletingPathExtension: URL? {
        return CFURLCreateCopyDeletingPathExtension(kCFAllocatorSystemDefault, _cfObject)?._swiftObject
    }
    
    /* The following methods work only on `file:` scheme URLs; for non-`file:` scheme URLs, these methods return the URL unchanged.
    */
    public var standardizingPath: URL? {
        // Documentation says it should expand initial tilde, but it does't do this on OS X.
        // In remaining cases it works just like URLByResolvingSymlinksInPath.
        return _resolveSymlinksInPath(excludeSystemDirs: true, preserveDirectoryFlag: true)
    }
    
    public var resolvingSymlinksInPath: URL? {
        return _resolveSymlinksInPath(excludeSystemDirs: true)
    }
    
    internal func _resolveSymlinksInPath(excludeSystemDirs: Bool, preserveDirectoryFlag: Bool = false) -> URL? {
        guard isFileURL else {
            return URL(string: absoluteString)
        }

        guard let selfPath = path else {
            return URL(string: absoluteString)
        }

        let absolutePath: String
        if selfPath.isAbsolutePath {
            absolutePath = selfPath
        } else {
            let workingDir = FileManager.default.currentDirectoryPath
            absolutePath = workingDir._bridgeToObjectiveC().appendingPathComponent(selfPath)
        }

#if os(Windows)
        let hFile: HANDLE = absolutePath.withCString(encodedAs: UTF16.self) {
          CreateFileW($0, GENERIC_READ,
                      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                      nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, nil)
        }
        guard hFile == INVALID_HANDLE_VALUE else {
          defer { CloseHandle(hFile) }

          let dwLength = GetFinalPathNameByHandleW(hFile, nil, 0, 0)
          return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) {
            let dwLength =
                GetFinalPathNameByHandleW(hFile, $0.baseAddress, DWORD($0.count), 0)
            assert(dwLength < $0.count)

            var resolved = String(decodingCString: $0.baseAddress!, as: UTF16.self)
            if preserveDirectoryFlag {
              var isExistingDirectory: ObjCBool = false
              let _ = FileManager.default.fileExists(atPath: resolved, isDirectory: &isExistingDirectory)
              if isExistingDirectory.boolValue && !resolved.hasSuffix("/") {
                resolved += "/"
              }
            }
            return URL(fileURLWithPath: resolved)
          }
        }
#endif

        var components = URL(fileURLWithPath: absolutePath).pathComponents
        guard !components.isEmpty else {
            return URL(string: absoluteString)
        }

        var resolvedPath = components.removeFirst()
        for component in components {
            switch component {

            case "", ".":
                break

            case "..":
                resolvedPath = resolvedPath._bridgeToObjectiveC().deletingLastPathComponent

            default:
                resolvedPath = resolvedPath._bridgeToObjectiveC().appendingPathComponent(component)
                if let destination = FileManager.default._tryToResolveTrailingSymlinkInPath(resolvedPath) {
                    resolvedPath = destination
                }
            }
        }

        // It might be a responsibility of NSURL(fileURLWithPath:). Check it.
        var isExistingDirectory: ObjCBool = false

        let _ = FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isExistingDirectory)

        if excludeSystemDirs {
            resolvedPath = resolvedPath._tryToRemovePathPrefix("/private") ?? resolvedPath
        }

        if isExistingDirectory.boolValue && !resolvedPath.hasSuffix("/") {
            resolvedPath += "/"
        }

        if preserveDirectoryFlag {
            return URL(fileURLWithPath: resolvedPath, isDirectory: self.hasDirectoryPath)
        } else {
            return URL(fileURLWithPath: resolvedPath)
        }
    }

    fileprivate func _pathByRemovingDots(_ comps: [String]) -> String {
        var components = comps
        
        if(components.last == "/") {
            components.removeLast()
        }

        guard !components.isEmpty else {
            return self.path!
        }

        let isAbsolutePath = components.first == "/"
        var result : String = components.removeFirst()

        for component in components {
            switch component {
                case ".":
                    break
                case ".." where isAbsolutePath:
                    result = result._bridgeToObjectiveC().deletingLastPathComponent
                default:
                    result = result._bridgeToObjectiveC().appendingPathComponent(component)
            }
        }

        if(self.path!.hasSuffix("/")) {
            result += "/"
        }

        return result
    }
}

extension NSURL: _SwiftBridgeable {
    typealias SwiftType = URL
    internal var _swiftObject: SwiftType { return self as URL }
}

extension CFURL : _NSBridgeable, _SwiftBridgeable {
    typealias NSType = NSURL
    typealias SwiftType = URL
    internal var _nsObject: NSType { return unsafeBitCast(self, to: NSType.self) }
    internal var _swiftObject: SwiftType { return _nsObject._swiftObject }
}

extension URL : _NSBridgeable {
    typealias NSType = NSURL
    typealias CFType = CFURL
    internal var _nsObject: NSType { return self as NSURL }
    internal var _cfObject: CFType { return _nsObject._cfObject }
}

extension NSURL : _StructTypeBridgeable {
    public typealias _StructType = URL
    
    public func _bridgeToSwift() -> _StructType {
        return _StructType._unconditionallyBridgeFromObjectiveC(self)
    }
}

// -----

internal func _CFSwiftURLCopyResourcePropertyForKey(_ url: CFTypeRef, _ key: CFString, _ valuePointer: UnsafeMutablePointer<Unmanaged<CFTypeRef>?>?, _ errorPointer: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> _DarwinCompatibleBoolean {
    do {
        let key = URLResourceKey(rawValue: key._swiftObject)
        let values = try unsafeDowncast(url, to: NSURL.self).resourceValues(forKeys: [ key ])
        let value = values[key]
        
        if let value = value {
            let result = __SwiftValue.store(value)
            valuePointer?.pointee = .passRetained(unsafeBitCast(result, to: CFTypeRef.self))
        } else {
            valuePointer?.pointee = nil
        }
        
        return true
    } catch {
        if let errorPointer = errorPointer {
            let nsError = NSError(domain: NSCocoaErrorDomain, code: CocoaError.featureUnsupported.rawValue)
            let cfError = Unmanaged.passRetained(nsError._cfObject)
            errorPointer.pointee = cfError
        }
        return false
    }
}

internal func _CFSwiftURLCopyResourcePropertiesForKeys(_ url: CFTypeRef, _ keys: CFArray, _ errorPointer: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFDictionary>? {
    do {
        var swiftKeys: [URLResourceKey] = []
        for nsKey in keys._swiftObject {
            if let stringKey = nsKey as? String {
                swiftKeys.append(URLResourceKey(rawValue: stringKey))
            }
        }
        
        let result = try unsafeDowncast(url, to: NSURL.self).resourceValues(forKeys: swiftKeys)
        
        let finalDictionary = NSMutableDictionary()
        for entry in result {
            finalDictionary[entry.key.rawValue._nsObject] = entry.value
        }
        
        return .passRetained(finalDictionary._cfObject)
    } catch {
        if let errorPointer = errorPointer {
            let nsError = NSError(domain: NSCocoaErrorDomain, code: CocoaError.featureUnsupported.rawValue)
            let cfError = Unmanaged.passRetained(nsError._cfObject)
            errorPointer.pointee = cfError
        }
        return nil
    }
}

internal func _CFSwiftURLSetResourcePropertyForKey(_ url: CFTypeRef, _ key: CFString, _ value: CFTypeRef?, _ errorPointer: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> _DarwinCompatibleBoolean {
    do {
        let key = URLResourceKey(rawValue: key._swiftObject)
        try unsafeDowncast(url, to: NSURL.self).setResourceValue(__SwiftValue.fetch(value), forKey: key)
        
        return true
    } catch {
        if let errorPointer = errorPointer {
            let nsError = NSError(domain: NSCocoaErrorDomain, code: CocoaError.featureUnsupported.rawValue)
            let cfError = Unmanaged.passRetained(nsError._cfObject)
            errorPointer.pointee = cfError
        }
        
        return false
    }
}

internal func _CFSwiftURLSetResourcePropertiesForKeys(_ url: CFTypeRef, _ properties: CFDictionary, _ errorPointer: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> _DarwinCompatibleBoolean {
    do {
        var swiftValues: [URLResourceKey: Any] = [:]
        let swiftProperties = properties._swiftObject
        for entry in swiftProperties {
            if let stringKey = entry.key as? String {
                swiftValues[URLResourceKey(rawValue: stringKey)] = entry.value
            }
        }
        
        try unsafeDowncast(url, to: NSURL.self).setResourceValues(swiftValues)
        return true
    } catch {
        if let errorPointer = errorPointer {
            let nsError = NSError(domain: NSCocoaErrorDomain, code: CocoaError.featureUnsupported.rawValue)
            let cfError = Unmanaged.passRetained(nsError._cfObject)
            errorPointer.pointee = cfError
        }
        return false
    }
}

internal func _CFSwiftURLClearResourcePropertyCacheForKey(_ url: CFTypeRef, _ key: CFString) {
    let swiftKey = URLResourceKey(rawValue: key._swiftObject)
    unsafeDowncast(url, to: NSURL.self).removeCachedResourceValue(forKey: swiftKey)
}

internal func _CFSwiftURLClearResourcePropertyCache(_ url: CFTypeRef) {
    unsafeDowncast(url, to: NSURL.self).removeAllCachedResourceValues()
}

internal func _CFSwiftSetTemporaryResourceValueForKey(_ url: CFTypeRef, _ key: CFString, _ value: CFTypeRef) {
    unsafeDowncast(url, to: NSURL.self).setTemporaryResourceValue(__SwiftValue.fetch(value), forKey: URLResourceKey(rawValue: key._swiftObject))
}

internal func _CFSwiftURLResourceIsReachable(_ url: CFTypeRef, _ errorPointer: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> _DarwinCompatibleBoolean {
    do {
        let reachable = try unsafeDowncast(url, to: NSURL.self).checkResourceIsReachable()
        return reachable ? true : false
    } catch {
        if let errorPointer = errorPointer {
            let nsError = NSError(domain: NSCocoaErrorDomain, code: CocoaError.featureUnsupported.rawValue)
            let cfError = Unmanaged.passRetained(nsError._cfObject)
            errorPointer.pointee = cfError
        }
        return false
    }
}

// MARK: Fetching URL resource values

internal class _URLFileResourceIdentifier: NSObject {
    let path: String
    let inode: Int
    let volumeIdentifier: Int
    
    init(path: String, inode: Int, volumeIdentifier: Int) {
        self.path = path
        self.inode = inode
        self.volumeIdentifier = volumeIdentifier
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? _URLFileResourceIdentifier else {
            return false
        }
        
        return path == other.path || (inode == other.inode && volumeIdentifier == other.volumeIdentifier)
    }
    
    override var hash: Int {
        return path._nsObject.hashValue ^ inode ^ volumeIdentifier
    }
}

fileprivate extension URLResourceValuesStorage {
    func read(_ keys: [URLResourceKey], for url: NSURL) throws -> [URLResourceKey: Any?] {
        var result: [URLResourceKey: Any?] = [:]
        
        let fm = FileManager.default
        let path = url.path ?? ""
        
        // Memoized access to attributes:
        
        var fileAttributesStorage: [FileAttributeKey: Any]? = nil
        func attributes() throws -> [FileAttributeKey: Any] {
            if let storage = fileAttributesStorage {
                return storage
            } else {
                let storage = try fm._attributesOfItemIncludingPrivate(atPath: path)
                fileAttributesStorage = storage
                return storage
            }
        }
        func attribute(_ fileAttributeKey: FileAttributeKey) throws -> Any? {
            let attributeValues = try attributes()
            return attributeValues[fileAttributeKey]
        }
        
        // Memoized access to lstat:
        
        var urlStatStorage: stat?
        func urlStat() throws -> stat {
            if let storage = urlStatStorage {
                return storage
            } else {
                let storage = try fm._lstatFile(atPath: path)
                urlStatStorage = storage
                return storage
            }
        }
        
        // Memoized access to volume URLs:
        
        var volumeURLsStorage: [URL]?
        var volumeURLs: [URL] {
            if let storage = volumeURLsStorage {
                return storage
            } else {
                let storage = fm.mountedVolumeURLs(includingResourceValuesForKeys: nil) ?? []
                volumeURLsStorage = storage
                return storage
            }
        }
        
        var volumeAttributesStorage: [FileAttributeKey: Any]?
        var blockSizeStorage: UInt64?
        func volumeAttributes() throws -> [FileAttributeKey: Any] {
            if let storage = volumeAttributesStorage {
                return storage
            } else {
                let (storage, block) = try fm._attributesOfFileSystemIncludingBlockSize(forPath: path)
                volumeAttributesStorage = storage
                blockSizeStorage = block
                return storage
            }
        }
        func blockSize() throws -> UInt64? {
            _ = try volumeAttributes()
            return blockSizeStorage
        }
        func volumeAttribute(_ fileAttributeKey: FileAttributeKey) throws -> Any? {
            let attributeValues = try volumeAttributes()
            return attributeValues[fileAttributeKey]
        }
        
        var volumeURLStorage: (searched: Bool, url: URL?)?
        func volumeURL() throws -> URL? {
            if let url = volumeURLStorage {
                return url.url
            }
            
            var foundURL: URL?
            
            for volumeURL in volumeURLs {
                var relationship: FileManager.URLRelationship = .other
                try fm.getRelationship(&relationship, ofDirectoryAt: volumeURL, toItemAt: url._swiftObject)
                if relationship == .same || relationship == .contains {
                    foundURL = volumeURL
                    break
                }
            }
            
            volumeURLStorage = (searched: true, url: foundURL)
            return foundURL
        }
        
        for key in keys {
            switch key {
            case .nameKey:
                result[key] = url.lastPathComponent
            case .localizedNameKey:
                result[key] = fm.displayName(atPath: path)
            case .isRegularFileKey:
                result[key] = try attribute(.type) as? FileAttributeType == FileAttributeType.typeRegular
            case .isDirectoryKey:
                result[key] = try attribute(.type) as? FileAttributeType == FileAttributeType.typeDirectory
            case .isSymbolicLinkKey:
                result[key] = try attribute(.type) as? FileAttributeType == FileAttributeType.typeSymbolicLink
            case .isVolumeKey:
                result[key] = volumeURLs.contains(url._swiftObject)
            case .isPackageKey:
                result[key] = try attribute(.type) as? FileAttributeType == FileAttributeType.typeDirectory && url.pathExtension != nil && url.pathExtension != ""
            case .isApplicationKey:
                #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                result[key] = try attribute(.type) as? FileAttributeType == FileAttributeType.typeDirectory && url.pathExtension == "app"
                #else
                result[key] = false
                #endif
            case .applicationIsScriptableKey:
                // Not supported.
                break
            case .isSystemImmutableKey:
                result[key] = try attribute(._systemImmutable) as? Bool == true
            case .isUserImmutableKey:
                result[key] = try attribute(.immutable) as? Bool == true
            case .isHiddenKey:
                result[key] = try attribute(._hidden) as? Bool == true
            case .hasHiddenExtensionKey:
                result[key] = false // Most OSes do not have a way to record this.
            case .creationDateKey:
                result[key] = try attribute(.creationDate)
            case .contentAccessDateKey:
                result[key] = try attribute(._accessDate)
            case .contentModificationDateKey:
                result[key] = try attribute(.modificationDate)
            case .attributeModificationDateKey:
                // We do not support this in a cross-platform manner.
                break
            case .linkCountKey:
                result[key] = Int(try urlStat().st_nlink)
            case .parentDirectoryURLKey:
                result[key] = url.deletingLastPathComponent
            case .volumeURLKey:
                result[key] = try volumeURL()
                
            case .fileResourceIdentifierKey:
                result[key] = _URLFileResourceIdentifier(path: path, inode: Int(try urlStat().st_ino), volumeIdentifier: Int(try urlStat().st_dev))
                
            case .volumeIdentifierKey:
                result[key] = try volumeAttribute(.systemNumber)
                
            case .preferredIOBlockSizeKey:
                result[key] = try blockSize()
                
            case .isReadableKey:
                result[key] = fm.isReadableFile(atPath: path)
            case .isWritableKey:
                result[key] = fm.isWritableFile(atPath: path)
            case .isExecutableKey:
                result[key] = fm.isExecutableFile(atPath: path)
            case .pathKey:
                result[key] = url.path
            case .canonicalPathKey:
                result[key] = try fm._canonicalizedPath(toFileAtPath: path)
            case .fileResourceTypeKey:
                result[key] = try attribute(.type)
            case .totalFileSizeKey: fallthrough // FIXME: This should add the size of any metadata.
            case .fileSizeKey:
                result[key] = try attribute(.size)
            case .totalFileAllocatedSizeKey: fallthrough // FIXME: This should add the size of any metadata.
            case .fileAllocatedSizeKey:
#if !os(Windows)
                let stat = try urlStat()
                result[key] = Int(stat.st_blocks) * Int(stat.st_blksize)
#endif
            case .isAliasFileKey:
                // swift-corelibs-foundation does not support aliases and bookmarks.
                break
            case .volumeLocalizedFormatDescriptionKey:
                // FIXME: This should have different names for different kinds of volumes, and be localized.
                result[key] = "Volume"
            case .volumeTotalCapacityKey:
                result[key] = try volumeAttribute(.systemSize)
            case .volumeAvailableCapacityKey:
                result[key] = try volumeAttribute(.systemFreeSize)
            case .volumeResourceCountKey:
                result[key] = try volumeAttribute(.systemFileNumber)

            // FIXME: swift-corelibs-foundation does not currently support querying this kind of filesystem information. We return reasonable assumptions for now, with the understanding that by noting support we are encouraging the application to try performing corresponding I/O operations (and handle those errors, which they already must) instead. Where those keys would inform I/O decisions that are not single operations, we assume conservatively.
            case .volumeSupportsPersistentIDsKey:
                result[key] = false
            case .volumeSupportsSymbolicLinksKey:
                result[key] = true
            case .volumeSupportsHardLinksKey:
                result[key] = true
            case .volumeSupportsJournalingKey:
                result[key] = false
            case .volumeIsJournalingKey:
                result[key] = false
            case .volumeSupportsSparseFilesKey:
                result[key] = false
            case .volumeSupportsZeroRunsKey:
                result[key] = false
            case .volumeSupportsRootDirectoryDatesKey:
                result[key] = true
            case .volumeSupportsVolumeSizesKey:
                result[key] = true
            case .volumeSupportsRenamingKey:
                result[key] = true
            case .volumeSupportsAdvisoryFileLockingKey:
                result[key] = false
            case .volumeSupportsExtendedSecurityKey:
                result[key] = false
            case .volumeIsBrowsableKey:
                result[key] = true
            case .volumeIsReadOnlyKey:
                result[key] = false
            case .volumeCreationDateKey:
                result[key] = try volumeAttribute(.creationDate)
            case .volumeURLForRemountingKey:
                result[key] = nil
            case .volumeMaximumFileSizeKey: fallthrough
            case .volumeIsEjectableKey: fallthrough
            case .volumeIsRemovableKey: fallthrough
            case .volumeIsInternalKey: fallthrough
            case .volumeIsAutomountedKey: fallthrough
            case .volumeIsLocalKey: fallthrough
            case .volumeSupportsCaseSensitiveNamesKey: fallthrough
            case .volumeUUIDStringKey: fallthrough
            case .volumeIsEncryptedKey: fallthrough
            case .volumeSupportsCompressionKey: fallthrough
            case .volumeSupportsFileCloningKey: fallthrough
            case .volumeSupportsSwapRenamingKey: fallthrough
            case .volumeSupportsExclusiveRenamingKey: fallthrough
            case .volumeSupportsCasePreservedNamesKey:
                // Whatever we assume here, we may make problems for the implementation that relies on them; we just don't answer for now.
                break
                
            case .volumeNameKey:
                if let url = try volumeURL() {
                    result[key] = url.lastPathComponent
                }
            case .volumeLocalizedNameKey:
                if let url = try volumeURL() {
                    result[key] = fm.displayName(atPath: url.path)
                }
                
            case .volumeIsRootFileSystemKey:
                #if !os(Windows)
                if let url = try volumeURL() {
                    result[key] = url.path == "/"
                }
                #endif
                
            case .isUbiquitousItemKey: fallthrough
            case .ubiquitousItemHasUnresolvedConflictsKey: fallthrough
            case .ubiquitousItemIsDownloadingKey: fallthrough
            case .ubiquitousItemIsUploadedKey: fallthrough
            case .ubiquitousItemIsUploadingKey: fallthrough
            case .ubiquitousItemDownloadingStatusKey: fallthrough
            case .ubiquitousItemDownloadingErrorKey: fallthrough
            case .ubiquitousItemUploadingErrorKey: fallthrough
            case .ubiquitousItemDownloadRequestedKey: fallthrough
            case .ubiquitousItemContainerDisplayNameKey: fallthrough
            case .fileSecurityKey: fallthrough
            case .isExcludedFromBackupKey: fallthrough
            case .tagNamesKey: fallthrough
            case .typeIdentifierKey: fallthrough
            case .localizedTypeDescriptionKey: fallthrough
            case .labelNumberKey: fallthrough
            case .labelColorKey: fallthrough
            case .localizedLabelKey: fallthrough
            case .effectiveIconKey: fallthrough
            case .isMountTriggerKey: fallthrough
            case .generationIdentifierKey: fallthrough
            case .documentIdentifierKey: fallthrough
            case .addedToDirectoryDateKey: fallthrough
            case .quarantinePropertiesKey: fallthrough
            case .thumbnailDictionaryKey: fallthrough
            case .thumbnailKey: fallthrough
            case .customIconKey:
                // Not supported outside of Apple OSes.
                break
                
            default:
                break
            }
        }
        
        return result
    }
    
    func write(_ keysAndValues: [URLResourceKey: Any?], to url: NSURL) throws {
        // Keys we could support but don't yet (FIXME):
        // .labelNumberKey, // Darwin only:
        // .fileSecurityKey,
        // .isExcludedFromBackupKey,
        // .tagNamesKey,
        // .quarantinePropertiesKey,
        // .addedToDirectoryDateKey, // Most OSes do not have a separate stat()-able added-to-directory date.
        // .volumeNameKey, // The way to set this is very system-dependent.
        
        var finalError: Error?
        var unsuccessfulKeys = Set(keysAndValues.keys)
        
        let fm = FileManager.default
        let path = url.path ?? ""
        
        let swiftURL = url._swiftObject
        
        var attributesToSet: [FileAttributeKey: Any] = [:]
        var keysThatSucceedBySettingAttributes: Set<URLResourceKey> = []
        
        for key in keysAndValues.keys {
            let value = keysAndValues[key]
            do {
                var succeeded = true
                
                func prepareToSetFileAttribute(_ attributeKey: FileAttributeKey, value: Any?) throws {
                    if let value = value {
                        attributesToSet[attributeKey] = value
                        keysThatSucceedBySettingAttributes.insert(key)
                    } else {
                        throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnknown.rawValue)
                    }
                    
                    succeeded = false
                }

                switch key {
                    
                case .isUserImmutableKey:
                    try prepareToSetFileAttribute(.immutable, value: value as? Bool)

                case .isSystemImmutableKey:
                    try prepareToSetFileAttribute(._systemImmutable, value: value as? Bool)

                case .hasHiddenExtensionKey:
                    try prepareToSetFileAttribute(.extensionHidden, value: value as? Bool)
                    
                case .creationDateKey:
                    try prepareToSetFileAttribute(.creationDate, value: value as? Date)
                    
                case .contentAccessDateKey:
                    try prepareToSetFileAttribute(._accessDate, value: value as? Date)
                    
                case .contentModificationDateKey:
                    try prepareToSetFileAttribute(.modificationDate, value: value as? Date)
                    
                case .isHiddenKey:
                    try prepareToSetFileAttribute(._hidden, value: value as? Bool)
                    
                default:
                    /* https://developer.apple.com/documentation/foundation/nsurl/1408208-setresourcevalues:
                     Attempts to set a read-only resource property or to set a resource property that is not supported by the resource are ignored and are not considered errors.
                     
                     Properties swift-corelibs-foundation doesn't support are treated as if they are supported by no resource. */
                    break
                }
                
                if succeeded {
                    unsuccessfulKeys.remove(key)
                }
            } catch {
                finalError = error
                break
            }
            
            // _setAttributes(…) needs to figure out the correct order to apply these attributes in, so set them all together at the end.
            if !attributesToSet.isEmpty {
                try fm._setAttributesIncludingPrivate(attributesToSet, ofItemAtPath: path)
                unsuccessfulKeys.formSymmetricDifference(keysThatSucceedBySettingAttributes)
            }
            
            // The name must be set last, since otherwise the URL may be invalid.
            if keysAndValues.keys.contains(.nameKey) {
                if let value = keysAndValues[.nameKey] as? String {
                    let destination = swiftURL.deletingLastPathComponent().appendingPathComponent(value)
                    try fm.moveItem(at: swiftURL, to: destination)
                    unsuccessfulKeys.remove(.nameKey)
                } else {
                    throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteInvalidFileName.rawValue)
                }
            }
        }
        
        if let finalError = finalError {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnknown.rawValue, userInfo: [
                URLResourceKey.keysOfUnsetValuesKey.rawValue: Array(unsuccessfulKeys),
                NSUnderlyingErrorKey: finalError,
            ])
        }
    }
}

// -----

internal extension Date {
    #if !os(Windows)
    init(timespec: timespec) {
        self.init(timeIntervalSince1970: TimeInterval(timespec.tv_sec), nanoseconds: Double(timespec.tv_nsec))
    }
    #endif
    
    init(timeIntervalSince1970: TimeInterval, nanoseconds: Double = 0) {
        self.init(timeIntervalSinceReferenceDate: (timeIntervalSince1970 - kCFAbsoluteTimeIntervalSince1970) + (1.0e-9 * nanoseconds))
    }
}

extension stat {
    var lastModificationDate: Date {
        #if canImport(Darwin)
        return Date(timespec: st_mtimespec)
        #elseif os(Windows)
        return Date(timeIntervalSince1970: TimeInterval(st_mtime))
        #else
        return Date(timespec: st_mtim)
        #endif
    }
    
    var lastAccessDate: Date {
        #if canImport(Darwin)
        return Date(timespec: st_atimespec)
        #elseif os(Windows)
        return Date(timeIntervalSince1970: TimeInterval(st_atime))
        #else
        return Date(timespec: st_atim)
        #endif
    }
    
    var creationDate: Date {
        #if canImport(Darwin)
        return Date(timespec: st_birthtimespec)
        #elseif os(Windows)
        return Date(timeIntervalSince1970: TimeInterval(st_ctime))
        #else
        return Date(timespec: st_ctim)
        #endif
    }
}
