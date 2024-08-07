// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if !canImport(Darwin) && !os(FreeBSD)
// The values do not matter as long as they are nonzero.
fileprivate let SF_IMMUTABLE: Int32 = 1
fileprivate let UF_HIDDEN: Int32 = 1
#endif

@_implementationOnly import CoreFoundation
#if os(Windows)
import CRT
import WinSDK
#endif

#if os(WASI)
import WASILibc
#elseif canImport(Android)
import Android
#endif

#if os(Windows)
internal typealias NativeFSRCharType = WCHAR
internal let NativeFSREncoding = String.Encoding.utf16LittleEndian.rawValue
#else
internal typealias NativeFSRCharType = CChar
internal let NativeFSREncoding = String.Encoding.utf8.rawValue
#endif


#if os(Linux)
// statx() is only supported by Linux kernels >= 4.11.0
internal let supportsStatx: Bool = {
    let requiredVersion = OperatingSystemVersion(majorVersion: 4, minorVersion: 11, patchVersion: 0)
    return ProcessInfo.processInfo.isOperatingSystemAtLeast(requiredVersion)
}()

// renameat2() is only supported by Linux kernels >= 3.15
internal let kernelSupportsRenameat2: Bool = {
    let requiredVersion = OperatingSystemVersion(majorVersion: 3, minorVersion: 15, patchVersion: 0)
    return ProcessInfo.processInfo.isOperatingSystemAtLeast(requiredVersion)
}()
#endif

// For testing only: this facility pins the language used by displayName to the passed-in language.
private nonisolated(unsafe) var _overriddenDisplayNameLanguages: [String]? = nil

extension FileManager {
    
    /// Returns an array of URLs that identify the mounted volumes available on the device.
    public func mountedVolumeURLs(includingResourceValuesForKeys propertyKeys: [URLResourceKey]?, options: VolumeEnumerationOptions = []) -> [URL]? {
        return _mountedVolumeURLs(includingResourceValuesForKeys: propertyKeys, options: options)
    }

    
    /* Returns an NSArray of NSURLs identifying the the directory entries. 
    
        If the directory contains no entries, this method will return the empty array. When an array is specified for the 'keys' parameter, the specified property values will be pre-fetched and cached with each enumerated URL.
     
        This method always does a shallow enumeration of the specified directory (i.e. it always acts as if NSDirectoryEnumerationSkipsSubdirectoryDescendants has been specified). If you need to perform a deep enumeration, use -[NSFileManager enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:].
     
        If you wish to only receive the URLs and no other attributes, then pass '0' for 'options' and an empty NSArray ('[NSArray array]') for 'keys'. If you wish to have the property caches of the vended URLs pre-populated with a default set of attributes, then pass '0' for 'options' and 'nil' for 'keys'.
     */
    public func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: DirectoryEnumerationOptions = []) throws -> [URL] {
        var error : Error? = nil
        let e = self.enumerator(at: url, includingPropertiesForKeys: keys, options: mask.union(.skipsSubdirectoryDescendants)) { (url, err) -> Bool in
            error = err
            return false
        }
        var result = [URL]()
        if let e = e {
            for url in e {
                result.append(url as! URL)
            }
            if let error = error {
                throw error
            }
        }
        return result
    }

    private enum URLForDirectoryError: Error {
        case directoryUnknown
    }

    /* -URLForDirectory:inDomain:appropriateForURL:create:error: is a URL-based replacement for FSFindFolder(). It allows for the specification and (optional) creation of a specific directory for a particular purpose (e.g. the replacement of a particular item on disk, or a particular Library directory.
     
        You may pass only one of the values from the NSSearchPathDomainMask enumeration, and you may not pass NSAllDomainsMask.
     */
    public func url(for directory: SearchPathDirectory, in domain: SearchPathDomainMask, appropriateFor reference: URL?, create
        shouldCreate: Bool) throws -> URL {
        var url: URL
        
        if directory == .itemReplacementDirectory {
            // We mimic Darwin here — .itemReplacementDirectory has a number of requirements for use and not meeting them is a programmer error and should panic out.
            precondition(domain == .userDomainMask)
            let referenceURL = reference!
            
            // If the temporary directory and the reference URL are on the same device, use a subdirectory in the temporary directory. Otherwise, use a temporary directory at the same path as the filesystem that contains this file if it's writable. Fall back to the temporary directory if the latter doesn't work.
            let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            let useTemporaryDirectory: Bool
            
            let maybeVolumeIdentifier = try? temporaryDirectory.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier as? AnyHashable
            let maybeReferenceVolumeIdentifier = try? referenceURL.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier as? AnyHashable
            
            if let volumeIdentifier = maybeVolumeIdentifier,
               let referenceVolumeIdentifier = maybeReferenceVolumeIdentifier {
                useTemporaryDirectory = volumeIdentifier == referenceVolumeIdentifier
            } else {
                useTemporaryDirectory = !isWritableFile(atPath: referenceURL.deletingPathExtension().path)
            }
            
            // This is the same name Darwin uses.
            if useTemporaryDirectory {
                url = temporaryDirectory.appendingPathComponent("TemporaryItems")
            } else {
                url = referenceURL.deletingPathExtension()
            }
        } else {
            
            let urls = self.urls(for: directory, in: domain)
            guard let theURL = urls.first else {
                // On Apple OSes, this case returns nil without filling in the error parameter; Swift then synthesizes an error rather than trap.
                // We simulate that behavior by throwing a private error.
                throw URLForDirectoryError.directoryUnknown
            }
            url = theURL
        }
        
        var nameStorage: String?
        
        func itemReplacementDirectoryName(forAttempt attempt: Int) -> String {
            let name: String
            if let someName = nameStorage {
                name = someName
            } else {
                // Sanitize the process name for filesystem use:
                var someName = ProcessInfo.processInfo.processName
                let characterSet = CharacterSet.alphanumerics.inverted
                while let whereIsIt = someName.rangeOfCharacter(from: characterSet, options: [], range: nil) {
                    someName.removeSubrange(whereIsIt)
                }
                name = someName
                nameStorage = someName
            }

            if attempt == 0 {
                return "(A Document Being Saved By \(name))"
            } else {
                return "(A Document Being Saved By \(name) \(attempt + 1)"
            }
        }
        
        // To avoid races, on Darwin, the item replacement directory is _ALWAYS_ created, even if create is false.
        if shouldCreate || directory == .itemReplacementDirectory {
            var attributes: [FileAttributeKey : Any] = [:]
            
            switch domain {
            case .userDomainMask:
                attributes[.posixPermissions] = 0o700
                
            case .systemDomainMask:
                attributes[.posixPermissions] = 0o755
                attributes[.ownerAccountID] = 0 // root
                #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
                    attributes[.ownerAccountID] = 80 // on Darwin, the admin group's fixed ID.
                #endif
                
            default:
                break
            }
            
            if directory == .itemReplacementDirectory {
                
                try createDirectory(at: url, withIntermediateDirectories: true, attributes: attributes)
                var attempt = 0
                
                while true {
                    do {
                        let attemptedURL = url.appendingPathComponent(itemReplacementDirectoryName(forAttempt: attempt))
                        try createDirectory(at: attemptedURL, withIntermediateDirectories: false)
                        url = attemptedURL
                        break
                    } catch {
                        let error = error as NSError
                        if error.domain == NSCocoaErrorDomain, error.code == CocoaError.fileWriteFileExists.rawValue {
                            attempt += 1
                        } else {
                            throw error
                        }
                    }
                }
                
            } else {
                try createDirectory(at: url, withIntermediateDirectories: true, attributes: attributes)
            }
        }
        
        return url
    }
    
    /* Sets 'outRelationship' to NSURLRelationshipContains if the directory at 'directoryURL' directly or indirectly contains the item at 'otherURL', meaning 'directoryURL' is found while enumerating parent URLs starting from 'otherURL'. Sets 'outRelationship' to NSURLRelationshipSame if 'directoryURL' and 'otherURL' locate the same item, meaning they have the same NSURLFileResourceIdentifierKey value. If 'directoryURL' is not a directory, or does not contain 'otherURL' and they do not locate the same file, then sets 'outRelationship' to NSURLRelationshipOther. If an error occurs, returns NO and sets 'error'.
     */
    public func getRelationship(_ outRelationship: UnsafeMutablePointer<URLRelationship>, ofDirectoryAt directoryURL: URL, toItemAt otherURL: URL) throws {
        let from = try _canonicalizedPath(toFileAtPath: directoryURL.path)
        let to = try _canonicalizedPath(toFileAtPath: otherURL.path)
        
        if from == to {
            outRelationship.pointee = .same
        } else if to.hasPrefix(from) && to.count > from.count + 1 /* the contained file's canonicalized path must contain at least one path separator and one filename component */ {
            let character = to[to.index(to.startIndex, offsetBy: from.length)]
            if character == "/" || character == "\\" {
                outRelationship.pointee = .contains
            } else {
                outRelationship.pointee = .other
            }
        } else {
            outRelationship.pointee = .other
        }
    }
    
    /* Similar to -[NSFileManager getRelationship:ofDirectoryAtURL:toItemAtURL:error:], except that the directory is instead defined by an NSSearchPathDirectory and NSSearchPathDomainMask. Pass 0 for domainMask to instruct the method to automatically choose the domain appropriate for 'url'. For example, to discover if a file is contained by a Trash directory, call [fileManager getRelationship:&result ofDirectory:NSTrashDirectory inDomain:0 toItemAtURL:url error:&error].
     */
    public func getRelationship(_ outRelationship: UnsafeMutablePointer<URLRelationship>, of directory: SearchPathDirectory, in domainMask: SearchPathDomainMask, toItemAt url: URL) throws {
        let actualMask: SearchPathDomainMask
        
        if domainMask.isEmpty {
            switch directory {
            case .applicationDirectory: fallthrough
            case .demoApplicationDirectory: fallthrough
            case .developerApplicationDirectory: fallthrough
            case .adminApplicationDirectory: fallthrough
            case .developerDirectory: fallthrough
            case .userDirectory: fallthrough
            case .documentationDirectory:
                actualMask = .localDomainMask
                
            case .libraryDirectory: fallthrough
            case .autosavedInformationDirectory: fallthrough
            case .documentDirectory: fallthrough
            case .desktopDirectory: fallthrough
            case .cachesDirectory: fallthrough
            case .applicationSupportDirectory: fallthrough
            case .downloadsDirectory: fallthrough
            case .inputMethodsDirectory: fallthrough
            case .moviesDirectory: fallthrough
            case .musicDirectory: fallthrough
            case .picturesDirectory: fallthrough
            case .sharedPublicDirectory: fallthrough
            case .preferencePanesDirectory: fallthrough
            case .applicationScriptsDirectory: fallthrough
            case .itemReplacementDirectory: fallthrough
            case .trashDirectory:
                actualMask = .userDomainMask

            case .coreServiceDirectory: fallthrough
            case .printerDescriptionDirectory: fallthrough
            case .allApplicationsDirectory: fallthrough
            case .allLibrariesDirectory:
                actualMask = .systemDomainMask
            }
        } else {
            actualMask = domainMask
        }
        
        try getRelationship(outRelationship, ofDirectoryAt: try self.url(for: directory, in: actualMask, appropriateFor: url, create: false), toItemAt: url)
    }
    
    internal func _setAttributesIncludingPrivate(_ values: [FileAttributeKey : Any], ofItemAtPath path: String) throws {
        // Call through to FoundationEssentials to handle all public attributes
        try self.setAttributes(values, ofItemAtPath: path)
        
        // Handle private attributes
        var flagsToSet: UInt32 = 0
        var flagsToUnset: UInt32 = 0
        
        if let isHidden = values[._hidden] as? Bool {
#if os(Windows)
            let attrs = try windowsFileAttributes(atPath: path).dwFileAttributes
            let hiddenAttrs = isHidden
                ? attrs | FILE_ATTRIBUTE_HIDDEN
                : attrs & ~FILE_ATTRIBUTE_HIDDEN
            try _fileSystemRepresentation(withPath: path) { fsRep in
                guard SetFileAttributesW(fsRep, hiddenAttrs) else {
                    throw _NSErrorWithWindowsError(GetLastError(), reading: false, paths: [path])
                }
            }
#else
            if isHidden {
                flagsToSet |= UInt32(UF_HIDDEN)
            } else {
                flagsToUnset |= UInt32(UF_HIDDEN)
            }
#endif
        }
        
        if let isSystemImmutable = values[._systemImmutable] as? Bool {
            if isSystemImmutable {
                flagsToSet |= UInt32(SF_IMMUTABLE)
            } else {
                flagsToUnset |= UInt32(SF_IMMUTABLE)
            }
        }
        
        if flagsToSet != 0 || flagsToUnset != 0 {
#if !canImport(Darwin) && !os(FreeBSD)
            // Setting these attributes is unsupported on these platforms.
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnknown.rawValue)
#else
            let stat = try _lstatFile(atPath: path, withFileSystemRepresentation: nil)
            var flags = stat.st_flags
            flags |= flagsToSet
            flags &= ~flagsToUnset
            
            guard chflags(fsRep, flags) == 0 else {
                throw _NSErrorWithErrno(errno, reading: false, path: path)
            }
#endif
        }
        
        let accessDate = values[._accessDate] as? Date
        let modificationDate = values[.modificationDate] as? Date
        
        if accessDate != nil || modificationDate != nil {
            // Set dates as the very last step, to avoid other operations overwriting these values
            // Also re-set modification date here in case setting flags above changed it
            try _fileSystemRepresentation(withPath: path) {
                try _updateTimes(atPath: path, withFileSystemRepresentation: $0, accessTime: accessDate, modificationTime: modificationDate)
            }
        }
    }
    
    internal func _attributesOfItemIncludingPrivate(atPath path: String) throws -> [FileAttributeKey: Any] {
        // Call to FoundationEssentials to get all public attributes
        var result = try self.attributesOfItem(atPath: path)
        
#if os(Linux)
        let (s, _) = try _statxFile(atPath: path)
#elseif os(Windows)
        let (s, _) = try _statxFile(atPath: path)
#else
        let s = try _lstatFile(atPath: path)
#endif
        result[._accessDate] = s.lastAccessDate
        
#if canImport(Darwin)
        result[._systemImmutable] = (s.st_flags & UInt32(SF_IMMUTABLE)) != 0
        result[._hidden] = (s.st_flags & UInt32(UF_HIDDEN)) != 0
#elseif os(Windows)
        result[._hidden] = try windowsFileAttributes(atPath: path).dwFileAttributes & FILE_ATTRIBUTE_HIDDEN != 0
#endif
        return result
    }
    
    internal func recursiveDestinationOfSymbolicLink(atPath path: String) throws -> String {
        return try _recursiveDestinationOfSymbolicLink(atPath: path)
    }

    public func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        var isDir: Bool = false
        defer {
            if let isDirectory {
                isDirectory.pointee = ObjCBool(isDir)
            }
        }
        return self.fileExists(atPath: path, isDirectory: &isDir)
    }
    
    internal func _overridingDisplayNameLanguages<T>(with languages: [String], within body: () throws -> T) rethrows -> T {
        let old = _overriddenDisplayNameLanguages
        defer { _overriddenDisplayNameLanguages = old }
        
        _overriddenDisplayNameLanguages = languages
        return try body()
    }
    
    private var _preferredLanguages: [String] {
        return _overriddenDisplayNameLanguages ?? Locale.preferredLanguages
    }

    /* displayNameAtPath: returns an NSString suitable for presentation to the user. For directories which have localization information, this will return the appropriate localized string. This string is not suitable for passing to anything that must interact with the filesystem.
     */
    public func displayName(atPath path: String) -> String {
        
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
        
        // https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemAdvancedPT/LocalizingtheNameofaDirectory/LocalizingtheNameofaDirectory.html
        // This localizes a X.localized directory:
        
        if url.pathExtension == "localized" {
            let dotLocalized = url.appendingPathComponent(".localized")
            var isDirectory: ObjCBool = false
            if fileExists(atPath: dotLocalized.path, isDirectory: &isDirectory),
                isDirectory.boolValue {
                for language in _preferredLanguages {
                    let stringsFile = dotLocalized.appendingPathComponent(language).appendingPathExtension("strings")
                    if let data = try? Data(contentsOf: stringsFile),
                       let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? NSDictionary {
                            
                        let localizedName = (plist[nameWithoutExtension] as? NSString)?._swiftObject
                        return localizedName ?? nameWithoutExtension
                            
                    }
                }
                
                // If we get here and we don't have a good name for this, still hide the extension:
                return nameWithoutExtension
            }
        }
        
        // We do not have the bundle resources to map the names of system directories with .localized files on Darwin, and system directories do not exist on other platforms, so just skip that on swift-corelibs-foundation:
        
        // URL resource values are not yet implemented: https://bugs.swift.org/browse/SR-10365
        // return (try? url.resourceValues(forKeys: [.hasHiddenExtensionKey]))?.hasHiddenExtension == true ? nameWithoutExtension : name
        
        return name
    }
    
    /* componentsToDisplayForPath: returns an NSArray of display names for the path provided. Localization will occur as in displayNameAtPath: above. This array cannot and should not be reassembled into an usable filesystem path for any kind of access.
     */
    public func componentsToDisplay(forPath path: String) -> [String]? {
        var url = URL(fileURLWithPath: path)
        var count = url.pathComponents.count
        
        var result: [String] = []
        while count > 0 {
            result.insert(displayName(atPath: url.path), at: 0)
            url = url.deletingLastPathComponent()
            count -= 1
        }
        
        return result
    }
    
    /* enumeratorAtPath: returns an NSDirectoryEnumerator rooted at the provided path. If the enumerator cannot be created, this returns NULL. Because NSDirectoryEnumerator is a subclass of NSEnumerator, the returned object can be used in the for...in construct.
     */
    public func enumerator(atPath path: String) -> DirectoryEnumerator? {
        return NSPathDirectoryEnumerator(path: path)
    }
    
    /* enumeratorAtURL:includingPropertiesForKeys:options:errorHandler: returns an NSDirectoryEnumerator rooted at the provided directory URL. The NSDirectoryEnumerator returns NSURLs from the -nextObject method. The optional 'includingPropertiesForKeys' parameter indicates which resource properties should be pre-fetched and cached with each enumerated URL. The optional 'errorHandler' block argument is invoked when an error occurs. Parameters to the block are the URL on which an error occurred and the error. When the error handler returns YES, enumeration continues if possible. Enumeration stops immediately when the error handler returns NO.
    
        If you wish to only receive the URLs and no other attributes, then pass '0' for 'options' and an empty NSArray ('[NSArray array]') for 'keys'. If you wish to have the property caches of the vended URLs pre-populated with a default set of attributes, then pass '0' for 'options' and 'nil' for 'keys'.
     */
    // Note: Because the error handler is an optional block, the compiler treats it as @escaping by default. If that behavior changes, the @escaping will need to be added back.
    public func enumerator(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: DirectoryEnumerationOptions = [], errorHandler handler: (/* @escaping */ (URL, Error) -> Bool)? = nil) -> DirectoryEnumerator? {
        return NSURLDirectoryEnumerator(url: url, options: mask, errorHandler: handler)
    }
    
    /* subpathsAtPath: returns an NSArray of all contents and subpaths recursively from the provided path. This may be very expensive to compute for deep filesystem hierarchies, and should probably be avoided.
     */
    public func subpaths(atPath path: String) -> [String]? {
        return try? subpathsOfDirectory(atPath: path)
    }
    
    /* fileSystemRepresentationWithPath: returns an array of characters suitable for passing to lower-level POSIX style APIs. The string is provided in the representation most appropriate for the filesystem in question.
     */
    public func fileSystemRepresentation(withPath path: String) -> UnsafePointer<Int8> {
        precondition(path != "", "Empty path argument")
        return self.withFileSystemRepresentation(for: path) { ptr in
            guard let ptr else {
                let allocation = UnsafeMutablePointer<Int8>.allocate(capacity: 1)
                allocation.pointee = 0
                return UnsafePointer(allocation)
            }
            var endIdx = ptr
            while endIdx.pointee != 0 {
                endIdx = endIdx.advanced(by: 1)
            }
            endIdx = endIdx.advanced(by: 1)
            let size = ptr.distance(to: endIdx)
            let buffer = UnsafeMutableBufferPointer<Int8>.allocate(capacity: size)
            // TODO: This whole function should be obsoleted as it returns a value that the caller must free. This works on Darwin, but is too easy to misuse without the presence of an autoreleasepool on other platforms.
            _ = buffer.initialize(fromContentsOf: UnsafeBufferPointer(start: ptr, count: size))
            return UnsafePointer(buffer.baseAddress!)
        }
    }

    internal func __fileSystemRepresentation(withPath path: String) throws -> UnsafePointer<NativeFSRCharType> {
        let len = CFStringGetMaximumSizeOfFileSystemRepresentation(path._cfObject)
        if len != kCFNotFound {
            let buf = UnsafeMutablePointer<NativeFSRCharType>.allocate(capacity: len)
            buf.initialize(repeating: 0, count: len)
            if path._nsObject._getFileSystemRepresentation(buf, maxLength: len) {
                return UnsafePointer(buf)
            }
            buf.deinitialize(count: len)
            buf.deallocate()
        }
        throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadInvalidFileName.rawValue, userInfo: [NSFilePathErrorKey: path])
    }

    internal func _fileSystemRepresentation<ResultType>(withPath path: String, _ body: (UnsafePointer<NativeFSRCharType>) throws -> ResultType) throws -> ResultType {
        let fsRep = try __fileSystemRepresentation(withPath: path)
        defer { fsRep.deallocate() }
        return try body(fsRep)
    }

    internal func _fileSystemRepresentation<ResultType>(withPath path1: String, andPath path2: String, _ body: (UnsafePointer<NativeFSRCharType>, UnsafePointer<NativeFSRCharType>) throws -> ResultType) throws -> ResultType {
        let fsRep1 = try __fileSystemRepresentation(withPath: path1)
        defer { fsRep1.deallocate() }
        let fsRep2 = try __fileSystemRepresentation(withPath: path2)
        defer { fsRep2.deallocate() }

        return try body(fsRep1, fsRep2)
    }

    /* -replaceItemAtURL:withItemAtURL:backupItemName:options:resultingItemURL:error: is for developers who wish to perform a safe-save without using the full NSDocument machinery that is available in the AppKit.
     
        The `originalItemURL` is the item being replaced.
        `newItemURL` is the item which will replace the original item. This item should be placed in a temporary directory as provided by the OS, or in a uniquely named directory placed in the same directory as the original item if the temporary directory is not available.
        If `backupItemName` is provided, that name will be used to create a backup of the original item. The backup is placed in the same directory as the original item. If an error occurs during the creation of the backup item, the operation will fail. If there is already an item with the same name as the backup item, that item will be removed. The backup item will be removed in the event of success unless the `NSFileManagerItemReplacementWithoutDeletingBackupItem` option is provided in `options`.
        For `options`, pass `0` to get the default behavior, which uses only the metadata from the new item while adjusting some properties using values from the original item. Pass `NSFileManagerItemReplacementUsingNewMetadataOnly` in order to use all possible metadata from the new item.
     */
    
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation as a suitable alternative
    /// - Note: Since this API is under consideration it may be either removed or revised in the near future
    #if os(Windows)
    @available(Windows, deprecated, message: "Not yet implemented")
    public func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: ItemReplacementOptions = []) throws -> URL? {
        NSUnimplemented()
    }

    @available(Windows, deprecated, message: "Not yet implemented")
    public func replaceItemAt(_ originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String? = nil, options: ItemReplacementOptions = []) throws -> URL? {
        NSUnimplemented()
    }

    #else
    public func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: ItemReplacementOptions = []) throws -> URL? {
        return try _replaceItem(at: originalItemURL, withItemAt: newItemURL, backupItemName: backupItemName, options: options)
    }

    public func replaceItemAt(_ originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String? = nil, options: ItemReplacementOptions = []) throws -> URL? {
        return try _replaceItem(at: originalItemURL, withItemAt: newItemURL, backupItemName: backupItemName, options: options)
    }
    #endif
    
    @available(*, unavailable, message: "Returning an object through an autoreleased pointer is not supported in swift-corelibs-foundation. Use replaceItem(at:withItemAt:backupItemName:options:) instead.", renamed: "replaceItem(at:withItemAt:backupItemName:options:)")
    public func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: FileManager.ItemReplacementOptions = [], resultingItemURL resultingURL: UnsafeMutablePointer<NSURL?>?) throws {
        NSUnsupported()
    }

    internal func _tryToResolveTrailingSymlinkInPath(_ path: String) -> String? {
        // FileManager.recursiveDestinationOfSymbolicLink(atPath:) will fail if the path is not a symbolic link
        guard let destination = try? self.recursiveDestinationOfSymbolicLink(atPath: path) else {
            return nil
        }

        return _appendSymlinkDestination(destination, toPath: path)
    }
}

extension FileManager {
    public struct VolumeEnumerationOptions : OptionSet, Sendable {
        public let rawValue : UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        /* The mounted volume enumeration will skip hidden volumes.
         */
        public static let skipHiddenVolumes = VolumeEnumerationOptions(rawValue: 1 << 1)

        /* The mounted volume enumeration will produce file reference URLs rather than path-based URLs.
         */
        public static let produceFileReferenceURLs = VolumeEnumerationOptions(rawValue: 1 << 2)
    }
}

extension FileAttributeKey {
    // These are the public keys:
    internal static let allPublicKeys: Set<FileAttributeKey> = [
        .type,
        .size,
        .modificationDate,
        .referenceCount,
        .deviceIdentifier,
        .ownerAccountName,
        .groupOwnerAccountName,
        .posixPermissions,
        .systemNumber,
        .systemFileNumber,
        .extensionHidden,
        .hfsCreatorCode,
        .hfsTypeCode,
        .immutable,
        .appendOnly,
        .creationDate,
        .ownerAccountID,
        .groupOwnerAccountID,
        .busy,
        .systemSize,
        .systemFreeSize,
        .systemNodes,
        .systemFreeNodes,
    ]
    
    // These are internal keys. They're not generated or accepted by public methods, but they're accepted by internal _setAttributes… methods.
    // They are intended for use by NSURL's resource keys.
    
    internal static let _systemImmutable = FileAttributeKey(rawValue: "org.swift.Foundation.FileAttributeKey._systemImmutable")
    internal static let _hidden = FileAttributeKey(rawValue: "org.swift.Foundation.FileAttributeKey._hidden")
    internal static let _accessDate = FileAttributeKey(rawValue: "org.swift.Foundation.FileAttributeKey._accessDate")
}

@available(*, unavailable)
extension FileManager.DirectoryEnumerator : Sendable { }

extension FileManager {
    open class DirectoryEnumerator : NSEnumerator {
        
        /* For NSDirectoryEnumerators created with -enumeratorAtPath:, the -fileAttributes and -directoryAttributes methods return an NSDictionary containing the keys listed below. For NSDirectoryEnumerators created with -enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:, these two methods return nil.
         */
        open var fileAttributes: [FileAttributeKey : Any]? {
            NSRequiresConcreteImplementation()
        }
        open var directoryAttributes: [FileAttributeKey : Any]? {
            NSRequiresConcreteImplementation()
        }
        
        /* This method returns the number of levels deep the current object is in the directory hierarchy being enumerated. The directory passed to -enumeratorAtURL:includingPropertiesForKeys:options:errorHandler: is considered to be level 0.
         */
        open var level: Int {
            NSRequiresConcreteImplementation()
        }
        
        open func skipDescendants() {
            NSRequiresConcreteImplementation()
        }
    }

    internal class NSPathDirectoryEnumerator: DirectoryEnumerator {
        let baseURL: URL
        let innerEnumerator : DirectoryEnumerator
        internal var _currentItemPath: String?

        override var fileAttributes: [FileAttributeKey : Any]? {
            guard let currentItemPath = _currentItemPath else {
                return nil
            }
            return try? FileManager.default.attributesOfItem(atPath: baseURL.appendingPathComponent(currentItemPath).path)
        }

        override var directoryAttributes: [FileAttributeKey : Any]? {
            return try? FileManager.default.attributesOfItem(atPath: baseURL.path)
        }

        override var level: Int {
            return innerEnumerator.level
        }

        override func skipDescendants() {
            innerEnumerator.skipDescendants()
        }

        init?(path: String) {
            guard path != "" else { return nil }
            let url = URL(fileURLWithPath: path)
            self.baseURL = url
            guard let ie = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [], errorHandler: nil) else {
                return nil
            }
            self.innerEnumerator = ie
        }

        override func nextObject() -> Any? {
            return _nextObject()
        }
    }
}
