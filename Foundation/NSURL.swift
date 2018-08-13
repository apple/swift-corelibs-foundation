// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


import CoreFoundation

#if os(macOS) || os(iOS)
import Darwin
#elseif os(Linux) || CYGWIN
import Glibc
#endif

#if os(macOS) || os(iOS)
internal let kCFURLPOSIXPathStyle = CFURLPathStyle.cfurlposixPathStyle
internal let kCFURLWindowsPathStyle = CFURLPathStyle.cfurlWindowsPathStyle
#endif

private func _standardizedPath(_ path: String) -> String {
    if !path.absolutePath {
        return path._nsObject.standardizingPath
    }
    return path
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

public struct URLResourceKey : RawRepresentable, Equatable, Hashable {
    public private(set) var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }

    public static func ==(lhs: URLResourceKey, rhs: URLResourceKey) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

extension URLResourceKey {
    public static let keysOfUnsetValuesKey = URLResourceKey(rawValue: "NSURLKeysOfUnsetValuesKey")
    public static let nameKey = URLResourceKey(rawValue: "NSURLNameKey")
    public static let localizedNameKey = URLResourceKey(rawValue: "NSURLLocalizedNameKey")
    public static let isRegularFileKey = URLResourceKey(rawValue: "NSURLIsRegularFileKey")
    public static let isDirectoryKey = URLResourceKey(rawValue: "NSURLIsDirectoryKey")
    public static let isSymbolicLinkKey = URLResourceKey(rawValue: "NSURLIsSymbolicLinkKey")
    public static let isVolumeKey = URLResourceKey(rawValue: "NSURLIsVolumeKey")
    public static let isPackageKey = URLResourceKey(rawValue: "NSURLIsPackageKey")
    public static let isApplicationKey = URLResourceKey(rawValue: "NSURLIsApplicationKey")
    public static let applicationIsScriptableKey = URLResourceKey(rawValue: "NSURLApplicationIsScriptableKey")
    public static let isSystemImmutableKey = URLResourceKey(rawValue: "NSURLIsSystemImmutableKey")
    public static let isUserImmutableKey = URLResourceKey(rawValue: "NSURLIsUserImmutableKey")
    public static let isHiddenKey = URLResourceKey(rawValue: "NSURLIsHiddenKey")
    public static let hasHiddenExtensionKey = URLResourceKey(rawValue: "NSURLHasHiddenExtensionKey")
    public static let creationDateKey = URLResourceKey(rawValue: "NSURLCreationDateKey")
    public static let contentAccessDateKey = URLResourceKey(rawValue: "NSURLContentAccessDateKey")
    public static let contentModificationDateKey = URLResourceKey(rawValue: "NSURLContentModificationDateKey")
    public static let attributeModificationDateKey = URLResourceKey(rawValue: "NSURLAttributeModificationDateKey")
    public static let linkCountKey = URLResourceKey(rawValue: "NSURLLinkCountKey")
    public static let parentDirectoryURLKey = URLResourceKey(rawValue: "NSURLParentDirectoryURLKey")
    public static let volumeURLKey = URLResourceKey(rawValue: "NSURLVolumeURLKey")
    public static let typeIdentifierKey = URLResourceKey(rawValue: "NSURLTypeIdentifierKey")
    public static let localizedTypeDescriptionKey = URLResourceKey(rawValue: "NSURLLocalizedTypeDescriptionKey")
    public static let labelNumberKey = URLResourceKey(rawValue: "NSURLLabelNumberKey")
    public static let labelColorKey = URLResourceKey(rawValue: "NSURLLabelColorKey")
    public static let localizedLabelKey = URLResourceKey(rawValue: "NSURLLocalizedLabelKey")
    public static let effectiveIconKey = URLResourceKey(rawValue: "NSURLEffectiveIconKey")
    public static let customIconKey = URLResourceKey(rawValue: "NSURLCustomIconKey")
    public static let fileResourceIdentifierKey = URLResourceKey(rawValue: "NSURLFileResourceIdentifierKey")
    public static let volumeIdentifierKey = URLResourceKey(rawValue: "NSURLVolumeIdentifierKey")
    public static let preferredIOBlockSizeKey = URLResourceKey(rawValue: "NSURLPreferredIOBlockSizeKey")
    public static let isReadableKey = URLResourceKey(rawValue: "NSURLIsReadableKey")
    public static let isWritableKey = URLResourceKey(rawValue: "NSURLIsWritableKey")
    public static let isExecutableKey = URLResourceKey(rawValue: "NSURLIsExecutableKey")
    public static let fileSecurityKey = URLResourceKey(rawValue: "NSURLFileSecurityKey")
    public static let isExcludedFromBackupKey = URLResourceKey(rawValue: "NSURLIsExcludedFromBackupKey")
    public static let tagNamesKey = URLResourceKey(rawValue: "NSURLTagNamesKey")
    public static let pathKey = URLResourceKey(rawValue: "NSURLPathKey")
    public static let canonicalPathKey = URLResourceKey(rawValue: "NSURLCanonicalPathKey")
    public static let isMountTriggerKey = URLResourceKey(rawValue: "NSURLIsMountTriggerKey")
    public static let generationIdentifierKey = URLResourceKey(rawValue: "NSURLGenerationIdentifierKey")
    public static let documentIdentifierKey = URLResourceKey(rawValue: "NSURLDocumentIdentifierKey")
    public static let addedToDirectoryDateKey = URLResourceKey(rawValue: "NSURLAddedToDirectoryDateKey")
    public static let quarantinePropertiesKey = URLResourceKey(rawValue: "NSURLQuarantinePropertiesKey")
    public static let fileResourceTypeKey = URLResourceKey(rawValue: "NSURLFileResourceTypeKey")
    public static let thumbnailDictionaryKey = URLResourceKey(rawValue: "NSURLThumbnailDictionaryKey")
    public static let thumbnailKey = URLResourceKey(rawValue: "NSURLThumbnailKey")
    public static let fileSizeKey = URLResourceKey(rawValue: "NSURLFileSizeKey")
    public static let fileAllocatedSizeKey = URLResourceKey(rawValue: "NSURLFileAllocatedSizeKey")
    public static let totalFileSizeKey = URLResourceKey(rawValue: "NSURLTotalFileSizeKey")
    public static let totalFileAllocatedSizeKey = URLResourceKey(rawValue: "NSURLTotalFileAllocatedSizeKey")
    public static let isAliasFileKey = URLResourceKey(rawValue: "NSURLIsAliasFileKey")
    public static let volumeLocalizedFormatDescriptionKey = URLResourceKey(rawValue: "NSURLVolumeLocalizedFormatDescriptionKey")
    public static let volumeTotalCapacityKey = URLResourceKey(rawValue: "NSURLVolumeTotalCapacityKey")
    public static let volumeAvailableCapacityKey = URLResourceKey(rawValue: "NSURLVolumeAvailableCapacityKey")
    public static let volumeResourceCountKey = URLResourceKey(rawValue: "NSURLVolumeResourceCountKey")
    public static let volumeSupportsPersistentIDsKey = URLResourceKey(rawValue: "NSURLVolumeSupportsPersistentIDsKey")
    public static let volumeSupportsSymbolicLinksKey = URLResourceKey(rawValue: "NSURLVolumeSupportsSymbolicLinksKey")
    public static let volumeSupportsHardLinksKey = URLResourceKey(rawValue: "NSURLVolumeSupportsHardLinksKey")
    public static let volumeSupportsJournalingKey = URLResourceKey(rawValue: "NSURLVolumeSupportsJournalingKey")
    public static let volumeIsJournalingKey = URLResourceKey(rawValue: "NSURLVolumeIsJournalingKey")
    public static let volumeSupportsSparseFilesKey = URLResourceKey(rawValue: "NSURLVolumeSupportsSparseFilesKey")
    public static let volumeSupportsZeroRunsKey = URLResourceKey(rawValue: "NSURLVolumeSupportsZeroRunsKey")
    public static let volumeSupportsCaseSensitiveNamesKey = URLResourceKey(rawValue: "NSURLVolumeSupportsCaseSensitiveNamesKey")
    public static let volumeSupportsCasePreservedNamesKey = URLResourceKey(rawValue: "NSURLVolumeSupportsCasePreservedNamesKey")
    public static let volumeSupportsRootDirectoryDatesKey = URLResourceKey(rawValue: "NSURLVolumeSupportsRootDirectoryDatesKey")
    public static let volumeSupportsVolumeSizesKey = URLResourceKey(rawValue: "NSURLVolumeSupportsVolumeSizesKey")
    public static let volumeSupportsRenamingKey = URLResourceKey(rawValue: "NSURLVolumeSupportsRenamingKey")
    public static let volumeSupportsAdvisoryFileLockingKey = URLResourceKey(rawValue: "NSURLVolumeSupportsAdvisoryFileLockingKey")
    public static let volumeSupportsExtendedSecurityKey = URLResourceKey(rawValue: "NSURLVolumeSupportsExtendedSecurityKey")
    public static let volumeIsBrowsableKey = URLResourceKey(rawValue: "NSURLVolumeIsBrowsableKey")
    public static let volumeMaximumFileSizeKey = URLResourceKey(rawValue: "NSURLVolumeMaximumFileSizeKey")
    public static let volumeIsEjectableKey = URLResourceKey(rawValue: "NSURLVolumeIsEjectableKey")
    public static let volumeIsRemovableKey = URLResourceKey(rawValue: "NSURLVolumeIsRemovableKey")
    public static let volumeIsInternalKey = URLResourceKey(rawValue: "NSURLVolumeIsInternalKey")
    public static let volumeIsAutomountedKey = URLResourceKey(rawValue: "NSURLVolumeIsAutomountedKey")
    public static let volumeIsLocalKey = URLResourceKey(rawValue: "NSURLVolumeIsLocalKey")
    public static let volumeIsReadOnlyKey = URLResourceKey(rawValue: "NSURLVolumeIsReadOnlyKey")
    public static let volumeCreationDateKey = URLResourceKey(rawValue: "NSURLVolumeCreationDateKey")
    public static let volumeURLForRemountingKey = URLResourceKey(rawValue: "NSURLVolumeURLForRemountingKey")
    public static let volumeUUIDStringKey = URLResourceKey(rawValue: "NSURLVolumeUUIDStringKey")
    public static let volumeNameKey = URLResourceKey(rawValue: "NSURLVolumeNameKey")
    public static let volumeLocalizedNameKey = URLResourceKey(rawValue: "NSURLVolumeLocalizedNameKey")
    public static let volumeIsEncryptedKey = URLResourceKey(rawValue: "NSURLVolumeIsEncryptedKey")
    public static let volumeIsRootFileSystemKey = URLResourceKey(rawValue: "NSURLVolumeIsRootFileSystemKey")
    public static let volumeSupportsCompressionKey = URLResourceKey(rawValue: "NSURLVolumeSupportsCompressionKey")
    public static let volumeSupportsFileCloningKey = URLResourceKey(rawValue: "NSURLVolumeSupportsFileCloningKey")
    public static let volumeSupportsSwapRenamingKey = URLResourceKey(rawValue: "NSURLVolumeSupportsSwapRenamingKey")
    public static let volumeSupportsExclusiveRenamingKey = URLResourceKey(rawValue: "NSURLVolumeSupportsExclusiveRenamingKey")
    public static let isUbiquitousItemKey = URLResourceKey(rawValue: "NSURLIsUbiquitousItemKey")
    public static let ubiquitousItemHasUnresolvedConflictsKey = URLResourceKey(rawValue: "NSURLUbiquitousItemHasUnresolvedConflictsKey")
    public static let ubiquitousItemIsDownloadingKey = URLResourceKey(rawValue: "NSURLUbiquitousItemIsDownloadingKey")
    public static let ubiquitousItemIsUploadedKey = URLResourceKey(rawValue: "NSURLUbiquitousItemIsUploadedKey")
    public static let ubiquitousItemIsUploadingKey = URLResourceKey(rawValue: "NSURLUbiquitousItemIsUploadingKey")
    public static let ubiquitousItemDownloadingStatusKey = URLResourceKey(rawValue: "NSURLUbiquitousItemDownloadingStatusKey")
    public static let ubiquitousItemDownloadingErrorKey = URLResourceKey(rawValue: "NSURLUbiquitousItemDownloadingErrorKey")
    public static let ubiquitousItemUploadingErrorKey = URLResourceKey(rawValue: "NSURLUbiquitousItemUploadingErrorKey")
    public static let ubiquitousItemDownloadRequestedKey = URLResourceKey(rawValue: "NSURLUbiquitousItemDownloadRequestedKey")
    public static let ubiquitousItemContainerDisplayNameKey = URLResourceKey(rawValue: "NSURLUbiquitousItemContainerDisplayNameKey")
}


public struct URLFileResourceType : RawRepresentable, Equatable, Hashable {
    public private(set) var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var hashValue: Int {
        return rawValue.hashValue
    }

    public static func ==(lhs: URLFileResourceType, rhs: URLFileResourceType) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

extension URLFileResourceType {
    public static let namedPipe = URLFileResourceType(rawValue: "NSURLFileResourceTypeNamedPipe")
    public static let characterSpecial = URLFileResourceType(rawValue: "NSURLFileResourceTypeCharacterSpecial")
    public static let directory = URLFileResourceType(rawValue: "NSURLFileResourceTypeDirectory")
    public static let blockSpecial = URLFileResourceType(rawValue: "NSURLFileResourceTypeBlockSpecial")
    public static let regular = URLFileResourceType(rawValue: "NSURLFileResourceTypeRegular")
    public static let symbolicLink = URLFileResourceType(rawValue: "NSURLFileResourceTypeSymbolicLink")
    public static let socket = URLFileResourceType(rawValue: "NSURLFileResourceTypeSocket")
    public static let unknown = URLFileResourceType(rawValue: "NSURLFileResourceTypeUnknown")
}

open class NSURL : NSObject, NSSecureCoding, NSCopying {
    typealias CFType = CFURL
    internal var _base = _CFInfo(typeID: CFURLGetTypeID())
    internal var _flags : UInt32 = 0
    internal var _encoding : CFStringEncoding = 0
    internal var _string : UnsafeMutablePointer<CFString>? = nil
    internal var _baseURL : UnsafeMutablePointer<CFURL>? = nil
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
    
    
    internal var _cfObject : CFType {
        if type(of: self) === NSURL.self {
            return unsafeBitCast(self, to: CFType.self)
        } else {
            return CFURLCreateWithString(kCFAllocatorSystemDefault, relativeString._cfObject, self.baseURL?._cfObject)
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
        return self
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
            
            _CFURLInitWithFileSystemPathRelativeToBase(_cfObject, thePath._cfObject, kCFURLPOSIXPathStyle, isDir, baseURL?._cfObject)
        } else if let baseURL = baseURL {
            _CFURLInitWithFileSystemPathRelativeToBase(_cfObject, baseURL.path._cfObject, kCFURLPOSIXPathStyle, baseURL.hasDirectoryPath, nil)
        }
    }
    
    public convenience init(fileURLWithPath path: String, relativeTo baseURL: URL?) {

        let thePath = _standardizedPath(path)
        
        var isDir: ObjCBool = false
        if thePath.hasSuffix("/") {
            isDir = true
        } else {
            let absolutePath: String
            if let absPath = baseURL?.appendingPathComponent(path).path {
                absolutePath = absPath
            } else {
                absolutePath = path
            }
            
            let _ = FileManager.default.fileExists(atPath: absolutePath, isDirectory: &isDir)
        }

        self.init(fileURLWithPath: thePath, isDirectory: isDir.boolValue, relativeTo: baseURL)
    }

    public convenience init(fileURLWithPath path: String, isDirectory isDir: Bool) {
        self.init(fileURLWithPath: path, isDirectory: isDir, relativeTo: nil)
    }

    public init(fileURLWithPath path: String) {
        let thePath: String
        let pathString = NSString(string: path)
        if !pathString.isAbsolutePath {
            thePath = pathString.standardizingPath
        } else {
            thePath = path
        }

        var isDir: ObjCBool = false
        if thePath.hasSuffix("/") {
            isDir = true
        } else {
            if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                isDir = false
            }
        }
        super.init()
        _CFURLInitWithFileSystemPathRelativeToBase(_cfObject, thePath._cfObject, kCFURLPOSIXPathStyle, isDir.boolValue, nil)
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
        data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> Void in
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
        data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> Void in
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
#if os(Linux) || os(Android) || CYGWIN
        let passwordRange = CFURLGetByteRangeForComponent(absoluteURL, kCFURLComponentPassword, nil)
#else
        let passwordRange = CFURLGetByteRangeForComponent(absoluteURL, .password, nil)
#endif
        guard passwordRange.location != kCFNotFound else {
            return nil
        }
        
        // For historical reasons, the password string should _not_ have its percent escapes removed.
        let bufSize = CFURLGetBytes(absoluteURL, nil, 0)
        var buf = [UInt8](repeating: 0, count: bufSize)
        guard CFURLGetBytes(absoluteURL, &buf, bufSize) >= 0 else {
            return nil
        }
        
        let passwordBuf = buf[passwordRange.location ..< passwordRange.location+passwordRange.length]
        return passwordBuf.withUnsafeBufferPointer { ptr in
            NSString(bytes: ptr.baseAddress!, length: passwordBuf.count, encoding: String.Encoding.utf8.rawValue)?._swiftObject
        }
    }
    
    open var path: String? {
        let absURL = CFURLCopyAbsoluteURL(_cfObject)
        return CFURLCopyFileSystemPath(absURL, kCFURLPOSIXPathStyle)?._swiftObject
    }
    
    open var fragment: String? {
        return CFURLCopyFragment(_cfObject, nil)?._swiftObject
    }
    
    open var parameterString: String? {
        return CFURLCopyParameterString(_cfObject, nil)?._swiftObject
    }
    
    open var query: String? {
        return CFURLCopyQueryString(_cfObject, nil)?._swiftObject
    }
    
    // The same as path if baseURL is nil
    open var relativePath: String? {
        return CFURLCopyFileSystemPath(_cfObject, kCFURLPOSIXPathStyle)?._swiftObject
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
    
    /* Returns the URL's path in file system representation. File system representation is a null-terminated C string with canonical UTF-8 encoding. The returned C string will be automatically freed just as a returned object would be released; your code should copy the representation or use getFileSystemRepresentation:maxLength: if it needs to store the representation outside of the autorelease context in which the representation is created.
    */
    
    // Memory leak. See https://github.com/apple/swift-corelibs-foundation/blob/master/Docs/Issues.md
    open var fileSystemRepresentation: UnsafePointer<Int8> {
        
        let bufSize = Int(PATH_MAX + 1)
        
        let _fsrBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufSize)
        _fsrBuffer.initialize(repeating: 0, count: bufSize)

        if getFileSystemRepresentation(_fsrBuffer, maxLength: bufSize) {
            return UnsafePointer(_fsrBuffer)
        }

        // FIXME: This used to return nil, but the corresponding Darwin
        // implementation is marked as non-nullable.
        fatalError("URL cannot be expressed in the filesystem representation;" +
                   "use getFileSystemRepresentation to handle this case")
    }
    
    // Whether the scheme is file:; if myURL.isFileURL is true, then myURL.path is suitable for input into FileManager or NSPathUtilities.
    open var isFileURL: Bool {
        return _CFURLIsFileURL(_cfObject)
    }
    
    /* A string constant for the "file" URL scheme. If you are using this to compare to a URL's scheme to see if it is a file URL, you should instead use the NSURL fileURL property -- the fileURL property is much faster. */
    open var standardized: URL? {
        guard (path != nil) else {
            return nil
        }

        let URLComponents = NSURLComponents(string: relativeString)
        guard ((URLComponents != nil) && (URLComponents!.path != nil)) else {
            return nil
        }
        guard (URLComponents!.path!.contains("..") || URLComponents!.path!.contains(".")) else{
            return URLComponents!.url(relativeTo: baseURL)
        }

        URLComponents!.path! = _pathByRemovingDots(pathComponents!)
        return URLComponents!.url(relativeTo: baseURL)
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
    
    override open var _cfTypeID: CFTypeID {
        return CFURLGetTypeID()
    }

    open func removeAllCachedResourceValues() { NSUnimplemented() }
    open func removeCachedResourceValue(forKey key: URLResourceKey) { NSUnimplemented() }
    open func resourceValues(forKeys keys: [URLResourceKey]) throws -> [URLResourceKey : Any] { NSUnimplemented() }
    open func setResourceValue(_ value: Any?, forKey key: URLResourceKey) throws { NSUnimplemented() }
    open func setResourceValues(_ keyedValues: [URLResourceKey : Any]) throws { NSUnimplemented() }
    open func setTemporaryResourceValue(_ value: Any?, forKey key: URLResourceKey) { NSUnimplemented() }
}

extension NSCharacterSet {
    
    // Predefined character sets for the six URL components and subcomponents which allow percent encoding. These character sets are passed to -stringByAddingPercentEncodingWithAllowedCharacters:.
    
    // Returns a character set containing the characters allowed in an URL's user subcomponent.
    open class var urlUserAllowed: CharacterSet {
        return _CFURLComponentsGetURLUserAllowedCharacterSet()._swiftObject
    }
    
    // Returns a character set containing the characters allowed in an URL's password subcomponent.
    open class var urlPasswordAllowed: CharacterSet {
        return _CFURLComponentsGetURLPasswordAllowedCharacterSet()._swiftObject
    }
    
    // Returns a character set containing the characters allowed in an URL's host subcomponent.
    open class var urlHostAllowed: CharacterSet {
        return _CFURLComponentsGetURLHostAllowedCharacterSet()._swiftObject
    }
    
    // Returns a character set containing the characters allowed in an URL's path component. ';' is a legal path character, but it is recommended that it be percent-encoded for best compatibility with NSURL (-stringByAddingPercentEncodingWithAllowedCharacters: will percent-encode any ';' characters if you pass the URLPathAllowedCharacterSet).
    open class var urlPathAllowed: CharacterSet {
        return _CFURLComponentsGetURLPathAllowedCharacterSet()._swiftObject
    }
    
    // Returns a character set containing the characters allowed in an URL's query component.
    open class var urlQueryAllowed: CharacterSet {
        return _CFURLComponentsGetURLQueryAllowedCharacterSet()._swiftObject
    }
    
    // Returns a character set containing the characters allowed in an URL's fragment component.
    open class var urlFragmentAllowed: CharacterSet {
        return _CFURLComponentsGetURLFragmentAllowedCharacterSet()._swiftObject
    }
}

extension NSString {
    
    // Returns a new string made from the receiver by replacing all characters not in the allowedCharacters set with percent encoded characters. UTF-8 encoding is used to determine the correct percent encoded characters. Entire URL strings cannot be percent-encoded. This method is intended to percent-encode an URL component or subcomponent string, NOT the entire URL string. Any characters in allowedCharacters outside of the 7-bit ASCII range are ignored.
    open func addingPercentEncoding(withAllowedCharacters allowedCharacters: CharacterSet) -> String? {
        return _CFStringCreateByAddingPercentEncodingWithAllowedCharacters(kCFAllocatorSystemDefault, self._cfObject, allowedCharacters._cfObject)._swiftObject
    }
    
    // Returns a new string made from the receiver by replacing all percent encoded sequences with the matching UTF-8 characters.
    open var removingPercentEncoding: String? {
        return _CFStringCreateByRemovingPercentEncoding(kCFAllocatorSystemDefault, self._cfObject)?._swiftObject
    }
}

extension NSURL {
    
    /* The following methods work on the path portion of a URL in the same manner that the NSPathUtilities methods on NSString do.
    */
    open class func fileURL(withPathComponents components: [String]) -> URL? {
        let path = NSString.pathWithComponents(components)
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

    open var pathComponents: [String]? {
        return _pathComponents(path)
    }
    
    open var lastPathComponent: String? {
        guard let fixedSelf = _pathByFixingSlashes() else {
            return nil
        }
        if fixedSelf.length <= 1 {
            return fixedSelf
        }
        
        return String(fixedSelf.suffix(from: fixedSelf._startOfLastPathComponent))
    }
    
    open var pathExtension: String? {
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
    
    open func appendingPathComponent(_ pathComponent: String) -> URL? {
        var result : URL? = appendingPathComponent(pathComponent, isDirectory: false)
        if !pathComponent.hasSuffix("/") && isFileURL {
            if let urlWithoutDirectory = result {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: urlWithoutDirectory.path, isDirectory: &isDir) && isDir.boolValue {
                    result = self.appendingPathComponent(pathComponent, isDirectory: true)
                }
            }
    
        }
        return result
    }
    
    open func appendingPathComponent(_ pathComponent: String, isDirectory: Bool) -> URL? {
        return CFURLCreateCopyAppendingPathComponent(kCFAllocatorSystemDefault, _cfObject, pathComponent._cfObject, isDirectory)?._swiftObject
    }
    
    open var deletingLastPathComponent: URL? {
        return CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorSystemDefault, _cfObject)?._swiftObject
    }
    
    open func appendingPathExtension(_ pathExtension: String) -> URL? {
        return CFURLCreateCopyAppendingPathExtension(kCFAllocatorSystemDefault, _cfObject, pathExtension._cfObject)?._swiftObject
    }
    
    open var deletingPathExtension: URL? {
        return CFURLCreateCopyDeletingPathExtension(kCFAllocatorSystemDefault, _cfObject)?._swiftObject
    }
    
    /* The following methods work only on `file:` scheme URLs; for non-`file:` scheme URLs, these methods return the URL unchanged.
    */
    open var standardizingPath: URL? {
        // Documentation says it should expand initial tilde, but it does't do this on OS X.
        // In remaining cases it works just like URLByResolvingSymlinksInPath.
        return resolvingSymlinksInPath
    }
    
    open var resolvingSymlinksInPath: URL? {
        return _resolveSymlinksInPath(excludeSystemDirs: true)
    }
    
    internal func _resolveSymlinksInPath(excludeSystemDirs: Bool) -> URL? {
        guard isFileURL else {
            return URL(string: absoluteString)
        }

        guard let selfPath = path else {
            return URL(string: absoluteString)
        }

        let absolutePath: String
        if selfPath.hasPrefix("/") {
            absolutePath = selfPath
        } else {
            let workingDir = FileManager.default.currentDirectoryPath
            absolutePath = workingDir._bridgeToObjectiveC().appendingPathComponent(selfPath)
        }

        
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
        
        return URL(fileURLWithPath: resolvedPath)
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

// NSURLQueryItem encapsulates a single query name-value pair. The name and value strings of a query name-value pair are not percent encoded. For use with the NSURLComponents queryItems property.
open class NSURLQueryItem : NSObject, NSSecureCoding, NSCopying {
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
    
    open private(set) var name: String
    open private(set) var value: String?
}

open class NSURLComponents: NSObject, NSCopying {
    private let _components : CFURLComponentsRef!
    
     deinit {
        if let component = _components {
            __CFURLComponentsDeallocate(component)
        }
    }

    open override func copy() -> Any {
        return copy(with: nil)
    }

    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? NSURLComponents else { return false }
        return self === other
            || (scheme == other.scheme
                && user == other.user
                && password == other.password
                && host == other.host
                && port == other.port
                && path == other.path
                && query == other.query
                && fragment == other.fragment)
    }

    open func copy(with zone: NSZone? = nil) -> Any {
        let copy = NSURLComponents()
        copy.scheme = self.scheme
        copy.user = self.user
        copy.password = self.password
        copy.host = self.host
        copy.port = self.port
        copy.path = self.path
        copy.query = self.query
        copy.fragment = self.fragment
        return copy
    }
    
    // Initialize a NSURLComponents with the components of a URL. If resolvingAgainstBaseURL is YES and url is a relative URL, the components of [url absoluteURL] are used. If the url string from the NSURL is malformed, nil is returned.
    public init?(url: URL, resolvingAgainstBaseURL resolve: Bool) {
        _components = _CFURLComponentsCreateWithURL(kCFAllocatorSystemDefault, url._cfObject, resolve)
        super.init()
        if _components == nil {
            return nil
        }
    }
    
    // Initialize a NSURLComponents with a URL string. If the URLString is malformed, nil is returned.
    public init?(string URLString: String) {
        _components = _CFURLComponentsCreateWithString(kCFAllocatorSystemDefault, URLString._cfObject)
        super.init()
        if _components == nil {
            return nil
        }
    }
    
    public override init() {
        _components = _CFURLComponentsCreate(kCFAllocatorSystemDefault)
    }
    
    // Returns a URL created from the NSURLComponents. If the NSURLComponents has an authority component (user, password, host or port) and a path component, then the path must either begin with "/" or be an empty string. If the NSURLComponents does not have an authority component (user, password, host or port) and has a path component, the path component must not start with "//". If those requirements are not met, nil is returned.
    open var url: URL? {
        guard let result = _CFURLComponentsCopyURL(_components) else { return nil }
        return unsafeBitCast(result, to: URL.self)
    }
    
    // Returns a URL created from the NSURLComponents relative to a base URL. If the NSURLComponents has an authority component (user, password, host or port) and a path component, then the path must either begin with "/" or be an empty string. If the NSURLComponents does not have an authority component (user, password, host or port) and has a path component, the path component must not start with "//". If those requirements are not met, nil is returned.
    open func url(relativeTo baseURL: URL?) -> URL? {
        if let componentString = string {
            return URL(string: componentString, relativeTo: baseURL)
        }
        return nil
    }
    
    // Returns a URL string created from the NSURLComponents. If the NSURLComponents has an authority component (user, password, host or port) and a path component, then the path must either begin with "/" or be an empty string. If the NSURLComponents does not have an authority component (user, password, host or port) and has a path component, the path component must not start with "//". If those requirements are not met, nil is returned.
    open var string: String?  {
        return _CFURLComponentsCopyString(_components)?._swiftObject
    }
    
    // Warning: IETF STD 66 (rfc3986) says the use of the format "user:password" in the userinfo subcomponent of a URI is deprecated because passing authentication information in clear text has proven to be a security risk. However, there are cases where this practice is still needed, and so the user and password components and methods are provided.
    
    // Getting these properties removes any percent encoding these components may have (if the component allows percent encoding). Setting these properties assumes the subcomponent or component string is not percent encoded and will add percent encoding (if the component allows percent encoding).
    // Attempting to set the scheme with an invalid scheme string will cause an exception.
    open var scheme: String? {
        get {
            return _CFURLComponentsCopyScheme(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetScheme(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var user: String? {
        get {
            return _CFURLComponentsCopyUser(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetUser(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var password: String? {
        get {
            return _CFURLComponentsCopyPassword(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetPassword(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var host: String? {
        get {
            return _CFURLComponentsCopyHost(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetHost(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    // Attempting to set a negative port number will cause an exception.
    open var port: NSNumber? {
        get {
            if let result = _CFURLComponentsCopyPort(_components) {
                return unsafeBitCast(result, to: NSNumber.self)
            } else {
                return nil
            }
        }
        set(new) {
            if !_CFURLComponentsSetPort(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var path: String? {
        get {
            return _CFURLComponentsCopyPath(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetPath(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var query: String? {
        get {
            return _CFURLComponentsCopyQuery(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetQuery(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var fragment: String? {
        get {
            return _CFURLComponentsCopyFragment(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetFragment(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    
    // Getting these properties retains any percent encoding these components may have. Setting these properties assumes the component string is already correctly percent encoded. Attempting to set an incorrectly percent encoded string will cause an exception. Although ';' is a legal path character, it is recommended that it be percent-encoded for best compatibility with NSURL (-stringByAddingPercentEncodingWithAllowedCharacters: will percent-encode any ';' characters if you pass the urlPathAllowed).
    open var percentEncodedUser: String? {
        get {
            return _CFURLComponentsCopyPercentEncodedUser(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetPercentEncodedUser(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var percentEncodedPassword: String? {
        get {
            return _CFURLComponentsCopyPercentEncodedPassword(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetPercentEncodedPassword(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var percentEncodedHost: String? {
        get {
            return _CFURLComponentsCopyPercentEncodedHost(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetPercentEncodedHost(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var percentEncodedPath: String? {
        get {
            return _CFURLComponentsCopyPercentEncodedPath(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetPercentEncodedPath(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var percentEncodedQuery: String? {
        get {
            return _CFURLComponentsCopyPercentEncodedQuery(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetPercentEncodedQuery(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    open var percentEncodedFragment: String? {
        get {
            return _CFURLComponentsCopyPercentEncodedFragment(_components)?._swiftObject
        }
        set(new) {
            if !_CFURLComponentsSetPercentEncodedFragment(_components, new?._cfObject) {
                fatalError()
            }
        }
    }
    
    
    /* These properties return the character range of a component in the URL string returned by -[NSURLComponents string]. If the component does not exist in the NSURLComponents object, {NSNotFound, 0} is returned. Note: Zero length components are legal. For example, the URL string "scheme://:@/?#" has a zero length user, password, host, query and fragment; the URL strings "scheme:" and "" both have a zero length path.
    */
    open var rangeOfScheme: NSRange {
        return NSRange(_CFURLComponentsGetRangeOfScheme(_components))
    }
    
    open var rangeOfUser: NSRange {
        return NSRange(_CFURLComponentsGetRangeOfUser(_components))
    }
    
    open var rangeOfPassword: NSRange {
        return NSRange(_CFURLComponentsGetRangeOfPassword(_components))
    }
    
    open var rangeOfHost: NSRange {
        return NSRange(_CFURLComponentsGetRangeOfHost(_components))
    }
    
    open var rangeOfPort: NSRange {
        return NSRange(_CFURLComponentsGetRangeOfPort(_components))
    }
    
    open var rangeOfPath: NSRange {
        return NSRange(_CFURLComponentsGetRangeOfPath(_components))
    }
    
    open var rangeOfQuery: NSRange {
        return NSRange(_CFURLComponentsGetRangeOfQuery(_components))
    }
    
    open var rangeOfFragment: NSRange {
        return NSRange(_CFURLComponentsGetRangeOfFragment(_components))
    }
    
    // The getter method that underlies the queryItems property parses the query string based on these delimiters and returns an NSArray containing any number of NSURLQueryItem objects, each of which represents a single key-value pair, in the order in which they appear in the original query string.  Note that a name may appear more than once in a single query string, so the name values are not guaranteed to be unique. If the NSURLComponents object has an empty query component, queryItems returns an empty NSArray. If the NSURLComponents object has no query component, queryItems returns nil.
    // The setter method that underlies the queryItems property combines an NSArray containing any number of NSURLQueryItem objects, each of which represents a single key-value pair, into a query string and sets the NSURLComponents' query property. Passing an empty NSArray to setQueryItems sets the query component of the NSURLComponents object to an empty string. Passing nil to setQueryItems removes the query component of the NSURLComponents object.
    // Note: If a name-value pair in a query is empty (i.e. the query string starts with '&', ends with '&', or has "&&" within it), you get a NSURLQueryItem with a zero-length name and and a nil value. If a query's name-value pair has nothing before the equals sign, you get a zero-length name. If a query's name-value pair has nothing after the equals sign, you get a zero-length value. If a query's name-value pair has no equals sign, the query name-value pair string is the name and you get a nil value.
    open var queryItems: [URLQueryItem]? {
        get {
            // This CFURL implementation returns a CFArray of CFDictionary; each CFDictionary has an entry for name and optionally an entry for value
            guard let queryArray = _CFURLComponentsCopyQueryItems(_components) else {
                return nil
            }

            let count = CFArrayGetCount(queryArray)
            return (0..<count).map { idx in
                let oneEntry = unsafeBitCast(CFArrayGetValueAtIndex(queryArray, idx), to: NSDictionary.self)
                let swiftEntry = oneEntry._swiftObject
                let entryName = swiftEntry["name"] as! String
                let entryValue = swiftEntry["value"] as? String
                return URLQueryItem(name: entryName, value: entryValue)
            }
        }
        set(new) {
            guard let new = new else {
                self.percentEncodedQuery = nil
                return
            }

            // The CFURL implementation requires two CFArrays, one for names and one for values
            var names = [CFTypeRef]()
            var values = [CFTypeRef]()
            for entry in new {
                names.append(entry.name._cfObject)
                if let v = entry.value {
                    values.append(v._cfObject)
                } else {
                    values.append(kCFNull)
                }
            }
            _CFURLComponentsSetQueryItems(_components, names._cfObject, values._cfObject)
        }
    }
}

extension NSURL: _CFBridgeable, _SwiftBridgeable {
    typealias SwiftType = URL
    internal var _swiftObject: SwiftType { return URL(reference: self) }
}

extension CFURL : _NSBridgeable, _SwiftBridgeable {
    typealias NSType = NSURL
    typealias SwiftType = URL
    internal var _nsObject: NSType { return unsafeBitCast(self, to: NSType.self) }
    internal var _swiftObject: SwiftType { return _nsObject._swiftObject }
}

extension URL : _NSBridgeable, _CFBridgeable {
    typealias NSType = NSURL
    typealias CFType = CFURL
    internal var _nsObject: NSType { return self.reference }
    internal var _cfObject: CFType { return _nsObject._cfObject }
}

extension NSURL : _StructTypeBridgeable {
    public typealias _StructType = URL
    
    public func _bridgeToSwift() -> _StructType {
        return _StructType._unconditionallyBridgeFromObjectiveC(self)
    }
}

extension NSURLComponents : _StructTypeBridgeable {
    public typealias _StructType = URLComponents
    
    public func _bridgeToSwift() -> _StructType {
        return _StructType._unconditionallyBridgeFromObjectiveC(self)
    }
}

extension NSURLQueryItem : _StructTypeBridgeable {
    public typealias _StructType = URLQueryItem
    
    public func _bridgeToSwift() -> _StructType {
        return _StructType._unconditionallyBridgeFromObjectiveC(self)
    }
}


extension NSURL : _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as URL)
    }
}

extension NSURLComponents : _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as URLComponents)
    }
}

extension NSURLQueryItem : _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as URLQueryItem)
    }
}
