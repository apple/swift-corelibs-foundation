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
fileprivate let UF_IMMUTABLE: Int32 = 1
fileprivate let SF_IMMUTABLE: Int32 = 1
fileprivate let UF_APPEND: Int32 = 1
fileprivate let UF_HIDDEN: Int32 = 1
#endif

@_implementationOnly import CoreFoundation
#if os(Windows)
import CRT
import WinSDK
#endif

#if os(WASI)
import WASILibc
#endif

#if os(Windows)
internal typealias NativeFSRCharType = WCHAR
internal let NativeFSREncoding = String.Encoding.utf16LittleEndian.rawValue
#else
internal typealias NativeFSRCharType = CChar
internal let NativeFSREncoding = String.Encoding.utf8.rawValue
#endif

open class FileManager : NSObject {
    
    /* Returns the default singleton instance.
    */
    private static let _default = FileManager()
    open class var `default`: FileManager {
        get {
            return _default
        }
    }
    
    /// Returns an array of URLs that identify the mounted volumes available on the device.
    open func mountedVolumeURLs(includingResourceValuesForKeys propertyKeys: [URLResourceKey]?, options: VolumeEnumerationOptions = []) -> [URL]? {
        return _mountedVolumeURLs(includingResourceValuesForKeys: propertyKeys, options: options)
    }

    
    /* Returns an NSArray of NSURLs identifying the the directory entries. 
    
        If the directory contains no entries, this method will return the empty array. When an array is specified for the 'keys' parameter, the specified property values will be pre-fetched and cached with each enumerated URL.
     
        This method always does a shallow enumeration of the specified directory (i.e. it always acts as if NSDirectoryEnumerationSkipsSubdirectoryDescendants has been specified). If you need to perform a deep enumeration, use -[NSFileManager enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:].
     
        If you wish to only receive the URLs and no other attributes, then pass '0' for 'options' and an empty NSArray ('[NSArray array]') for 'keys'. If you wish to have the property caches of the vended URLs pre-populated with a default set of attributes, then pass '0' for 'options' and 'nil' for 'keys'.
     */
    open func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: DirectoryEnumerationOptions = []) throws -> [URL] {
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
    
    internal enum _SearchPathDomain {
        case system
        case local
        case network
        case user
        
        static let correspondingValues: [UInt: _SearchPathDomain] = [
            SearchPathDomainMask.systemDomainMask.rawValue: .system,
            SearchPathDomainMask.localDomainMask.rawValue: .local,
            SearchPathDomainMask.networkDomainMask.rawValue: .network,
            SearchPathDomainMask.userDomainMask.rawValue: .user,
        ]
        
        static let searchOrder: [SearchPathDomainMask] = [
            .systemDomainMask,
            .localDomainMask,
            .networkDomainMask,
            .userDomainMask,
        ]
        
        init?(_ domainMask: SearchPathDomainMask) {
            if let value = _SearchPathDomain.correspondingValues[domainMask.rawValue] {
                self = value
            } else {
                return nil
            }
        }
        
        static func allInSearchOrder(from domainMask: SearchPathDomainMask) -> [_SearchPathDomain] {
            var domains: [_SearchPathDomain] = []

            for bit in _SearchPathDomain.searchOrder {
                if domainMask.contains(bit) {
                    domains.append(_SearchPathDomain.correspondingValues[bit.rawValue]!)
                }
            }
            
            return domains
        }
    }

    /* -URLsForDirectory:inDomains: is analogous to NSSearchPathForDirectoriesInDomains(), but returns an array of NSURL instances for use with URL-taking APIs. This API is suitable when you need to search for a file or files which may live in one of a variety of locations in the domains specified.
     */
    open func urls(for directory: SearchPathDirectory, in domainMask: SearchPathDomainMask) -> [URL] {
        return _urls(for: directory, in: domainMask)
    }

    internal lazy var xdgHomeDirectory: String = {
        let key = "HOME="
        if let contents = try? String(contentsOfFile: "/etc/default/useradd", encoding: .utf8) {
            for line in contents.components(separatedBy: "\n") {
                if line.hasPrefix(key) {
                    let index = line.index(line.startIndex, offsetBy: key.count)
                    let str = String(line[index...]) as NSString
                    let homeDir = str.trimmingCharacters(in: CharacterSet.whitespaces)
                    if homeDir.count > 0 {
                        return homeDir
                    }
                }
            }
        }
        return "/home"
    }()

    private enum URLForDirectoryError: Error {
        case directoryUnknown
    }

    /* -URLForDirectory:inDomain:appropriateForURL:create:error: is a URL-based replacement for FSFindFolder(). It allows for the specification and (optional) creation of a specific directory for a particular purpose (e.g. the replacement of a particular item on disk, or a particular Library directory.
     
        You may pass only one of the values from the NSSearchPathDomainMask enumeration, and you may not pass NSAllDomainsMask.
     */
    open func url(for directory: SearchPathDirectory, in domain: SearchPathDomainMask, appropriateFor reference: URL?, create
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
            
            switch _SearchPathDomain(domain) {
            case .some(.user):
                attributes[.posixPermissions] = 0o700
                
            case .some(.system):
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
                        if let error = error as? NSError, error.domain == NSCocoaErrorDomain, error.code == CocoaError.fileWriteFileExists.rawValue {
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
    open func getRelationship(_ outRelationship: UnsafeMutablePointer<URLRelationship>, ofDirectoryAt directoryURL: URL, toItemAt otherURL: URL) throws {
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
    open func getRelationship(_ outRelationship: UnsafeMutablePointer<URLRelationship>, of directory: SearchPathDirectory, in domainMask: SearchPathDomainMask, toItemAt url: URL) throws {
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
    
    /* createDirectoryAtURL:withIntermediateDirectories:attributes:error: creates a directory at the specified URL. If you pass 'NO' for withIntermediateDirectories, the directory must not exist at the time this call is made. Passing 'YES' for withIntermediateDirectories will create any necessary intermediate directories. This method returns YES if all directories specified in 'url' were created and attributes were set. Directories are created with attributes specified by the dictionary passed to 'attributes'. If no dictionary is supplied, directories are created according to the umask of the process. This method returns NO if a failure occurs at any stage of the operation. If an error parameter was provided, a presentable NSError will be returned by reference.
     */
    open func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = [:]) throws {
        guard url.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnsupportedScheme.rawValue, userInfo: [NSURLErrorKey : url])
        }
        try self.createDirectory(atPath: url.path, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }
    
    /* createSymbolicLinkAtURL:withDestinationURL:error: returns YES if the symbolic link that point at 'destURL' was able to be created at the location specified by 'url'. 'destURL' is always resolved against its base URL, if it has one. If 'destURL' has no base URL and it's 'relativePath' is indeed a relative path, then a relative symlink will be created. If this method returns NO, the link was unable to be created and an NSError will be returned by reference in the 'error' parameter. This method does not traverse a terminal symlink.
     */
    open func createSymbolicLink(at url: URL, withDestinationURL destURL: URL) throws {
        guard url.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnsupportedScheme.rawValue, userInfo: [NSURLErrorKey : url])
        }
        guard destURL.scheme == nil || destURL.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnsupportedScheme.rawValue, userInfo: [NSURLErrorKey : destURL])
        }
        try self.createSymbolicLink(atPath: url.path, withDestinationPath: destURL.path)
    }
    
    /* Instances of FileManager may now have delegates. Each instance has one delegate, and the delegate is not retained. In versions of Mac OS X prior to 10.5, the behavior of calling [[NSFileManager alloc] init] was undefined. In Mac OS X 10.5 "Leopard" and later, calling [[NSFileManager alloc] init] returns a new instance of an FileManager.
     */
    open weak var delegate: FileManagerDelegate?
    
    /* setAttributes:ofItemAtPath:error: returns YES when the attributes specified in the 'attributes' dictionary are set successfully on the item specified by 'path'. If this method returns NO, a presentable NSError will be provided by-reference in the 'error' parameter. If no error is required, you may pass 'nil' for the error.
     
        This method replaces changeFileAttributes:atPath:.
     */
    open func setAttributes(_ attributes: [FileAttributeKey : Any], ofItemAtPath path: String) throws {
        try _setAttributes(attributes, ofItemAtPath: path)
    }
    
    internal func _setAttributes(_ attributeValues: [FileAttributeKey : Any], ofItemAtPath path: String, includingPrivateAttributes: Bool = false) throws {
        var attributes = Set(attributeValues.keys)
        if !includingPrivateAttributes {
            attributes.formIntersection(FileAttributeKey.allPublicKeys)
        }
        
        try _fileSystemRepresentation(withPath: path) { fsRep in
            var flagsToSet: UInt32 = 0
            var flagsToUnset: UInt32 = 0
            
            var newModificationDate: Date?
            var newAccessDate: Date?
            
            for attribute in attributes {
                
                func prepareToSetOrUnsetFlag(_ flag: Int32) {
                    guard let shouldSet = attributeValues[attribute] as? Bool else {
                        fatalError("Can't set \(attribute) to \(attributeValues[attribute] as Any?)")
                    }
                    
                    if shouldSet {
                        flagsToSet |= UInt32(flag)
                    } else {
                        flagsToUnset |= UInt32(flag)
                    }
                }
                
                switch attribute {
                case .posixPermissions:
#if os(WASI)
                    // WASI does not have permission concept
                    throw _NSErrorWithErrno(ENOTSUP, reading: false, path: path)
#else
                    guard let number = attributeValues[attribute] as? NSNumber else {
                        fatalError("Can't set file permissions to \(attributeValues[attribute] as Any?)")
                    }
                    #if os(macOS) || os(iOS)
                        let modeT = number.uint16Value
                    #elseif os(Linux) || os(Android) || os(Windows) || os(OpenBSD)
                        let modeT = number.uint32Value
                    #endif
#if os(Windows)
                    let result = _wchmod(fsRep, mode_t(modeT))
#else
                    let result = chmod(fsRep, mode_t(modeT))
#endif
                    guard result == 0 else {
                        throw _NSErrorWithErrno(errno, reading: false, path: path)
                    }
#endif // os(WASI)
                
                case .modificationDate: fallthrough
                case ._accessDate:
                    guard let providedDate = attributeValues[attribute] as? Date else {
                        fatalError("Can't set \(attribute) to \(attributeValues[attribute] as Any?)")
                    }

                    if attribute == .modificationDate {
                        newModificationDate = providedDate
                    } else if attribute == ._accessDate {
                        newAccessDate = providedDate
                    }

                case .immutable: fallthrough
                case ._userImmutable:
                    prepareToSetOrUnsetFlag(UF_IMMUTABLE)
                    
                case ._systemImmutable:
                    prepareToSetOrUnsetFlag(SF_IMMUTABLE)
                    
                case .appendOnly:
                    prepareToSetOrUnsetFlag(UF_APPEND)
                    
                case ._hidden:
#if os(Windows)
                    let attrs = try windowsFileAttributes(atPath: path).dwFileAttributes
                    guard let isHidden = attributeValues[attribute] as? Bool else {
                      fatalError("Can't set \(attribute) to \(attributeValues[attribute] as Any?)")
                    }

                    let hiddenAttrs = isHidden
                        ? attrs | FILE_ATTRIBUTE_HIDDEN
                        : attrs & ~FILE_ATTRIBUTE_HIDDEN
                    guard SetFileAttributesW(fsRep, hiddenAttrs) else {
                      throw _NSErrorWithWindowsError(GetLastError(), reading: false, paths: [path])
                    }
#else
                    prepareToSetOrUnsetFlag(UF_HIDDEN)
#endif
                    
                // FIXME: On Darwin, these can be set with setattrlist(); and of course chown/chgrp on other OSes.
                case .ownerAccountID: fallthrough
                case .ownerAccountName: fallthrough
                case .groupOwnerAccountID: fallthrough
                case .groupOwnerAccountName: fallthrough
                case .creationDate: fallthrough
                case .extensionHidden:
                    // Setting these attributes is unsupported (for now) in swift-corelibs-foundation
                    throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnknown.rawValue)
                    
                default:
                    break
                }
            }

            if flagsToSet != 0 || flagsToUnset != 0 {
                #if !canImport(Darwin) && !os(FreeBSD)
                    // Setting these attributes is unsupported on these platforms.
                    throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnknown.rawValue)
                #else
                    let stat = try _lstatFile(atPath: path, withFileSystemRepresentation: fsRep)
                    var flags = stat.st_flags
                    flags |= flagsToSet
                    flags &= ~flagsToUnset
                
                    guard chflags(fsRep, flags) == 0 else {
                        throw _NSErrorWithErrno(errno, reading: false, path: path)
                    }
                #endif
            }

            if newModificationDate != nil || newAccessDate != nil {
              // Set dates as the very last step, to avoid other operations overwriting these values:
              try _updateTimes(atPath: path, withFileSystemRepresentation: fsRep, accessTime: newAccessDate, modificationTime: newModificationDate)
            }
        }
    }
    
    /* createDirectoryAtPath:withIntermediateDirectories:attributes:error: creates a directory at the specified path. If you pass 'NO' for createIntermediates, the directory must not exist at the time this call is made. Passing 'YES' for 'createIntermediates' will create any necessary intermediate directories. This method returns YES if all directories specified in 'path' were created and attributes were set. Directories are created with attributes specified by the dictionary passed to 'attributes'. If no dictionary is supplied, directories are created according to the umask of the process. This method returns NO if a failure occurs at any stage of the operation. If an error parameter was provided, a presentable NSError will be returned by reference.
     
        This method replaces createDirectoryAtPath:attributes:
     */
    open func createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = [:]) throws {
        return try _createDirectory(atPath: path, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }

    /**
     Performs a shallow search of the specified directory and returns the paths of any contained items.
     
     This method performs a shallow search of the directory and therefore does not traverse symbolic links or return the contents of any subdirectories. This method also does not return URLs for the current directory (“.”), parent directory (“..”) but it does return other hidden files (files that begin with a period character).
     
     The order of the files in the returned array is undefined.
     
     - Parameter path: The path to the directory whose contents you want to enumerate.
     
     - Throws: `NSError` if the directory does not exist, this error is thrown with the associated error code.
     
     - Returns: An array of String each of which identifies a file, directory, or symbolic link contained in `path`. The order of the files returned is undefined.
     */
    open func contentsOfDirectory(atPath path: String) throws -> [String] {
        var contents: [String] = []

        try _contentsOfDir(atPath: path, { (entryName, entryType) throws in
            contents.append(entryName)
        })
        return contents
    }

    /**
    Performs a deep enumeration of the specified directory and returns the paths of all of the contained subdirectories.
    
    This method recurses the specified directory and its subdirectories. The method skips the “.” and “..” directories at each level of the recursion.
    
    Because this method recurses the directory’s contents, you might not want to use it in performance-critical code. Instead, consider using the enumeratorAtURL:includingPropertiesForKeys:options:errorHandler: or enumeratorAtPath: method to enumerate the directory contents yourself. Doing so gives you more control over the retrieval of items and more opportunities to abort the enumeration or perform other tasks at the same time.
    
    - Parameter path: The path of the directory to list.
    
    - Throws: `NSError` if the directory does not exist, this error is thrown with the associated error code.
    
    - Returns: An array of NSString objects, each of which contains the path of an item in the directory specified by path. If path is a symbolic link, this method traverses the link. This method returns nil if it cannot retrieve the device of the linked-to file.
    */
    open func subpathsOfDirectory(atPath path: String) throws -> [String] {
        return try _subpathsOfDirectory(atPath: path)
    }

    /* attributesOfItemAtPath:error: returns an NSDictionary of key/value pairs containing the attributes of the item (file, directory, symlink, etc.) at the path in question. If this method returns 'nil', an NSError will be returned by reference in the 'error' parameter. This method does not traverse a terminal symlink.

        This method replaces fileAttributesAtPath:traverseLink:.
     */
    open func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        return try _attributesOfItem(atPath: path)
    }
    
    internal func _attributesOfItem(atPath path: String, includingPrivateAttributes: Bool = false) throws -> [FileAttributeKey: Any] {
        var result: [FileAttributeKey:Any] = [:]

#if os(Linux)
        let (s, creationDate) = try _statxFile(atPath: path)
        result[.creationDate] = creationDate
#elseif os(Windows)
        let (s, ino) = try _statxFile(atPath: path)
        result[.creationDate] = s.creationDate
#else
        let s = try _lstatFile(atPath: path)
        result[.creationDate] = s.creationDate
#endif

        result[.size] = NSNumber(value: UInt64(s.st_size))

        result[.modificationDate] = s.lastModificationDate
        if includingPrivateAttributes {
            result[._accessDate] = s.lastAccessDate
        }

        result[.posixPermissions] = NSNumber(value: _filePermissionsMask(mode: UInt32(s.st_mode)))
        result[.referenceCount] = NSNumber(value: UInt64(s.st_nlink))
        result[.systemNumber] = NSNumber(value: UInt64(s.st_dev))
#if os(Windows)
        result[.systemFileNumber] = NSNumber(value: UInt64(ino))
#else
        result[.systemFileNumber] = NSNumber(value: UInt64(s.st_ino))
#endif

#if os(Windows)
        result[.deviceIdentifier] = NSNumber(value: UInt64(s.st_rdev))
        let attributes = try windowsFileAttributes(atPath: path)
        let type = FileAttributeType(attributes: attributes, atPath: path)
#elseif os(WASI)
        let type = FileAttributeType(statMode: mode_t(s.st_mode))
#else
        if let pwd = getpwuid(s.st_uid), let pw_name = pwd.pointee.pw_name {
            let name = String(cString: pw_name)
            result[.ownerAccountName] = name
        }

        if let grd = getgrgid(s.st_gid), let gr_name = grd.pointee.gr_name {
            let name = String(cString: gr_name)
            result[.groupOwnerAccountName] = name
        }

        let type = FileAttributeType(statMode: mode_t(s.st_mode))
#endif
        result[.type] = type

        if type == .typeBlockSpecial || type == .typeCharacterSpecial {
            result[.deviceIdentifier] = NSNumber(value: UInt64(s.st_rdev))
        }

#if canImport(Darwin)
        if (s.st_flags & UInt32(UF_IMMUTABLE | SF_IMMUTABLE)) != 0 {
            result[.immutable] = NSNumber(value: true)
        }
        
        if includingPrivateAttributes {
            result[._userImmutable] = (s.st_flags & UInt32(UF_IMMUTABLE)) != 0
            result[._systemImmutable] = (s.st_flags & UInt32(SF_IMMUTABLE)) != 0
            result[._hidden] = (s.st_flags & UInt32(UF_HIDDEN)) != 0
        }
        
        if (s.st_flags & UInt32(UF_APPEND | SF_APPEND)) != 0 {
            result[.appendOnly] = NSNumber(value: true)
        }
#endif

#if os(Windows)
        let attrs = attributes.dwFileAttributes
        result[._hidden] = attrs & FILE_ATTRIBUTE_HIDDEN != 0
#endif
        result[.ownerAccountID] = NSNumber(value: UInt64(s.st_uid))
        result[.groupOwnerAccountID] = NSNumber(value: UInt64(s.st_gid))

        return result
    }

    /* attributesOfFileSystemForPath:error: returns an NSDictionary of key/value pairs containing the attributes of the filesystem containing the provided path. If this method returns 'nil', an NSError will be returned by reference in the 'error' parameter. This method does not traverse a terminal symlink.
     
        This method replaces fileSystemAttributesAtPath:.
     */
    open func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey : Any] {
        return try _attributesOfFileSystem(forPath: path)
    }

    /* createSymbolicLinkAtPath:withDestination:error: returns YES if the symbolic link that point at 'destPath' was able to be created at the location specified by 'path'. If this method returns NO, the link was unable to be created and an NSError will be returned by reference in the 'error' parameter. This method does not traverse a terminal symlink.

        This method replaces createSymbolicLinkAtPath:pathContent:
     */
    open func createSymbolicLink(atPath path: String, withDestinationPath destPath: String) throws {
        return try _createSymbolicLink(atPath: path, withDestinationPath: destPath)
    }

    /* destinationOfSymbolicLinkAtPath:error: returns a String containing the path of the item pointed at by the symlink specified by 'path'. If this method returns 'nil', an NSError will be thrown.

        This method replaces pathContentOfSymbolicLinkAtPath:
     */
    open func destinationOfSymbolicLink(atPath path: String) throws -> String {
        return try _destinationOfSymbolicLink(atPath: path)
    }
    
    internal func recursiveDestinationOfSymbolicLink(atPath path: String) throws -> String {
        return try _recursiveDestinationOfSymbolicLink(atPath: path)
    }

    internal func extraErrorInfo(srcPath: String?, dstPath: String?, userVariant: String?) -> [String : Any] {
        var result = [String : Any]()
        result["NSSourceFilePathErrorKey"] = srcPath
        result["NSDestinationFilePath"] = dstPath
        result["NSUserStringVariant"] = userVariant.map(NSArray.init(object:))
        return result
    }

    internal func shouldProceedAfterError(_ error: Error, copyingItemAtPath path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return false }
        if isURL {
            return delegate.fileManager(self, shouldProceedAfterError: error, copyingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldProceedAfterError: error, copyingItemAtPath: path, toPath: toPath)
        }
    }
    
    internal func shouldCopyItemAtPath(_ path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return true }
        if isURL {
            return delegate.fileManager(self, shouldCopyItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldCopyItemAtPath: path, toPath: toPath)
        }
    }
    
    fileprivate func _copyItem(atPath srcPath: String, toPath dstPath: String, isURL: Bool) throws {
        try _copyOrLinkDirectoryHelper(atPath: srcPath, toPath: dstPath) { (srcPath, dstPath, fileType) in
            guard shouldCopyItemAtPath(srcPath, toPath: dstPath, isURL: isURL) else {
                return
            }
            
            do {
                switch fileType {
                case .typeRegular:
                    try _copyRegularFile(atPath: srcPath, toPath: dstPath)
                case .typeSymbolicLink:
                    try _copySymlink(atPath: srcPath, toPath: dstPath)
                default:
                    break
                }
            } catch {
                if !shouldProceedAfterError(error, copyingItemAtPath: srcPath, toPath: dstPath, isURL: isURL) {
                    throw error
                }
            }
        }
    }
    
    internal func shouldProceedAfterError(_ error: Error, movingItemAtPath path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return false }
        if isURL {
            return delegate.fileManager(self, shouldProceedAfterError: error, movingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldProceedAfterError: error, movingItemAtPath: path, toPath: toPath)
        }
    }
    
    internal func shouldMoveItemAtPath(_ path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return true }
        if isURL {
            return delegate.fileManager(self, shouldMoveItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldMoveItemAtPath: path, toPath: toPath)
        }
    }
    
    internal func shouldProceedAfterError(_ error: Error, linkingItemAtPath path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return false }
        if isURL {
            return delegate.fileManager(self, shouldProceedAfterError: error, linkingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldProceedAfterError: error, linkingItemAtPath: path, toPath: toPath)
        }
    }
    
    internal func shouldLinkItemAtPath(_ path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return true }
        if isURL {
            return delegate.fileManager(self, shouldLinkItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldLinkItemAtPath: path, toPath: toPath)
        }
    }
    
    internal func shouldProceedAfterError(_ error: Error, removingItemAtPath path: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return false }
        if isURL {
            return delegate.fileManager(self, shouldProceedAfterError: error, removingItemAt: URL(fileURLWithPath: path))
        } else {
            return delegate.fileManager(self, shouldProceedAfterError: error, removingItemAtPath: path)
        }
    }
    
    internal func shouldRemoveItemAtPath(_ path: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return true }
        if isURL {
            return delegate.fileManager(self, shouldRemoveItemAt: URL(fileURLWithPath: path))
        } else {
            return delegate.fileManager(self, shouldRemoveItemAtPath: path)
        }
    }

    open func copyItem(atPath srcPath: String, toPath dstPath: String) throws {
        try _copyItem(atPath: srcPath, toPath: dstPath, isURL: false)
    }
    
    open func moveItem(atPath srcPath: String, toPath dstPath: String) throws {
        try _moveItem(atPath: srcPath, toPath: dstPath, isURL: false)
    }
    
    open func linkItem(atPath srcPath: String, toPath dstPath: String) throws {
        try _linkItem(atPath: srcPath, toPath: dstPath, isURL: false)
    }
    
    open func removeItem(atPath path: String) throws {
        try _removeItem(atPath: path, isURL: false)
    }
    
    open func copyItem(at srcURL: URL, to dstURL: URL) throws {
        guard srcURL.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnsupportedScheme.rawValue, userInfo: [NSURLErrorKey : srcURL])
        }
        guard dstURL.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnsupportedScheme.rawValue, userInfo: [NSURLErrorKey : dstURL])
        }
        try _copyItem(atPath: srcURL.path, toPath: dstURL.path, isURL: true)
    }
    
    open func moveItem(at srcURL: URL, to dstURL: URL) throws {
        guard srcURL.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnsupportedScheme.rawValue, userInfo: [NSURLErrorKey : srcURL])
        }
        guard dstURL.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnsupportedScheme.rawValue, userInfo: [NSURLErrorKey : dstURL])
        }
        try _moveItem(atPath: srcURL.path, toPath: dstURL.path, isURL: true)
    }
    
    open func linkItem(at srcURL: URL, to dstURL: URL) throws {
        guard srcURL.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnsupportedScheme.rawValue, userInfo: [NSURLErrorKey : srcURL])
        }
        guard dstURL.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnsupportedScheme.rawValue, userInfo: [NSURLErrorKey : dstURL])
        }
        try _linkItem(atPath: srcURL.path, toPath: dstURL.path, isURL: true)
    }

    open func removeItem(at url: URL) throws {
        guard url.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnsupportedScheme.rawValue, userInfo: [NSURLErrorKey : url])
        }
        try _removeItem(atPath: url.path, isURL: true)
    }

    /* Process working directory management. Despite the fact that these are instance methods on FileManager, these methods report and change (respectively) the working directory for the entire process. Developers are cautioned that doing so is fraught with peril.
     */
    open var currentDirectoryPath: String {
        return _currentDirectoryPath()
    }

    @discardableResult
    open func changeCurrentDirectoryPath(_ path: String) -> Bool {
        return _changeCurrentDirectoryPath(path)
    }

    /* The following methods are of limited utility. Attempting to predicate behavior based on the current state of the filesystem or a particular file on the filesystem is encouraging odd behavior in the face of filesystem race conditions. It's far better to attempt an operation (like loading a file or creating a directory) and handle the error gracefully than it is to try to figure out ahead of time whether the operation will succeed.
     */
    open func fileExists(atPath path: String) -> Bool {
        return _fileExists(atPath: path, isDirectory: nil)
    }

    open func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        return _fileExists(atPath: path, isDirectory: isDirectory)
    }

    open func isReadableFile(atPath path: String) -> Bool {
        return _isReadableFile(atPath: path)
    }

    open func isWritableFile(atPath path: String) -> Bool {
        return _isWritableFile(atPath: path)
    }

    open func isExecutableFile(atPath path: String) -> Bool {
        return _isExecutableFile(atPath: path)
    }

    /**
     - parameters:
        - path: The path to the file we are trying to determine is deletable.

      - returns: `true` if the file is deletable, `false` otherwise.
     */
    open func isDeletableFile(atPath path: String) -> Bool {
        return _isDeletableFile(atPath: path)
    }

    internal func _compareDirectories(atPath path1: String, andPath path2: String) -> Bool {
        guard let enumerator1 = enumerator(atPath: path1) else {
            return false
        }

        guard let enumerator2 = enumerator(atPath: path2) else {
            return false
        }
        enumerator1.skipDescendants()
        enumerator2.skipDescendants()

        var path1entries = Set<String>()
        while let item = enumerator1.nextObject() as? String {
            path1entries.insert(item)
        }

        while let item = enumerator2.nextObject() as? String {
            if path1entries.remove(item) == nil {
                return false
            }
            if contentsEqual(atPath: NSString(string: path1).appendingPathComponent(item), andPath: NSString(string: path2).appendingPathComponent(item)) == false {
                return false
            }
        }
        return path1entries.isEmpty
    }

    internal func _filePermissionsMask(mode : UInt32) -> Int {
#if os(Windows)
        return Int(mode & ~UInt32(ucrt.S_IFMT))
#elseif canImport(Darwin)
        return Int(mode & ~UInt32(S_IFMT))
#else
        return Int(mode & ~S_IFMT)
#endif
    }

    internal func _permissionsOfItem(atPath path: String) throws -> Int {
        let fileInfo = try _lstatFile(atPath: path)
        return _filePermissionsMask(mode: UInt32(fileInfo.st_mode))
    }

#if os(Linux)
    // statx() is only supported by Linux kernels >= 4.11.0
    internal lazy var supportsStatx: Bool = {
        let requiredVersion = OperatingSystemVersion(majorVersion: 4, minorVersion: 11, patchVersion: 0)
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(requiredVersion)
    }()

    // renameat2() is only supported by Linux kernels >= 3.15
    internal lazy var kernelSupportsRenameat2: Bool = {
        let requiredVersion = OperatingSystemVersion(majorVersion: 3, minorVersion: 15, patchVersion: 0)
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(requiredVersion)
    }()
#endif

    internal func _compareFiles(withFileSystemRepresentation file1Rep: UnsafePointer<NativeFSRCharType>, andFileSystemRepresentation file2Rep: UnsafePointer<NativeFSRCharType>, size: Int64, bufSize: Int) -> Bool {
        guard let file1 = FileHandle(fileSystemRepresentation: file1Rep, flags: O_RDONLY, createMode: 0) else { return false }
        guard let file2 = FileHandle(fileSystemRepresentation: file2Rep, flags: O_RDONLY, createMode: 0) else { return false }

        let buffer1 = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        let buffer2 = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer {
            buffer1.deallocate()
            buffer2.deallocate()
        }
        var bytesLeft = size
        while bytesLeft > 0 {
            let bytesToRead = Int(min(Int64(bufSize), bytesLeft))

            guard let file1BytesRead = try? file1._readBytes(into: buffer1, length: bytesToRead), file1BytesRead == bytesToRead else {
                return false
            }
            guard let file2BytesRead = try? file2._readBytes(into: buffer2, length: bytesToRead), file2BytesRead == bytesToRead else {
                return false
            }
            guard memcmp(buffer1, buffer2, bytesToRead) == 0 else {
                return false
            }
            bytesLeft -= Int64(bytesToRead)
        }
        return true
    }

    /* -contentsEqualAtPath:andPath: does not take into account data stored in the resource fork or filesystem extended attributes.
     */
    open func contentsEqual(atPath path1: String, andPath path2: String) -> Bool {
        return _contentsEqual(atPath: path1, andPath: path2)
    }
    
    // For testing only: this facility pins the language used by displayName to the passed-in language.
    private var _overriddenDisplayNameLanguages: [String]? = nil
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
    open func displayName(atPath path: String) -> String {
        
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
    open func componentsToDisplay(forPath path: String) -> [String]? {
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
    open func enumerator(atPath path: String) -> DirectoryEnumerator? {
        return NSPathDirectoryEnumerator(path: path)
    }
    
    /* enumeratorAtURL:includingPropertiesForKeys:options:errorHandler: returns an NSDirectoryEnumerator rooted at the provided directory URL. The NSDirectoryEnumerator returns NSURLs from the -nextObject method. The optional 'includingPropertiesForKeys' parameter indicates which resource properties should be pre-fetched and cached with each enumerated URL. The optional 'errorHandler' block argument is invoked when an error occurs. Parameters to the block are the URL on which an error occurred and the error. When the error handler returns YES, enumeration continues if possible. Enumeration stops immediately when the error handler returns NO.
    
        If you wish to only receive the URLs and no other attributes, then pass '0' for 'options' and an empty NSArray ('[NSArray array]') for 'keys'. If you wish to have the property caches of the vended URLs pre-populated with a default set of attributes, then pass '0' for 'options' and 'nil' for 'keys'.
     */
    // Note: Because the error handler is an optional block, the compiler treats it as @escaping by default. If that behavior changes, the @escaping will need to be added back.
    open func enumerator(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: DirectoryEnumerationOptions = [], errorHandler handler: (/* @escaping */ (URL, Error) -> Bool)? = nil) -> DirectoryEnumerator? {
        return NSURLDirectoryEnumerator(url: url, options: mask, errorHandler: handler)
    }
    
    /* subpathsAtPath: returns an NSArray of all contents and subpaths recursively from the provided path. This may be very expensive to compute for deep filesystem hierarchies, and should probably be avoided.
     */
    open func subpaths(atPath path: String) -> [String]? {
        return try? subpathsOfDirectory(atPath: path)
    }
    
    /* These methods are provided here for compatibility. The corresponding methods on NSData which return NSErrors should be regarded as the primary method of creating a file from an NSData or retrieving the contents of a file as an NSData.
     */
    open func contents(atPath path: String) -> Data? {
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    @discardableResult
    open func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]? = nil) -> Bool {
        do {
            try (data ?? Data()).write(to: URL(fileURLWithPath: path), options: .atomic)
            if let attr = attr {
                try self.setAttributes(attr, ofItemAtPath: path)
            }
            return true
        } catch {
            return false
        }
    }
    
    /* fileSystemRepresentationWithPath: returns an array of characters suitable for passing to lower-level POSIX style APIs. The string is provided in the representation most appropriate for the filesystem in question.
     */
    open func fileSystemRepresentation(withPath path: String) -> UnsafePointer<Int8> {
        precondition(path != "", "Empty path argument")
#if os(Windows)
        // On Windows, the internal _fileSystemRepresentation returns UTF16
        // encoded data, so we need to re-encode the result as UTF-8 before
        // returning.
        return try! _fileSystemRepresentation(withPath: path) {
            String(decodingCString: $0, as: UTF16.self).withCString() {
                let size = strnlen($0, Int(MAX_PATH))
                let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: size + 1)
                buffer.initialize(from: $0, count: size + 1)
                return UnsafePointer(buffer)
            }
        }
#else
        return try! __fileSystemRepresentation(withPath: path)
#endif
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

    /* stringWithFileSystemRepresentation:length: returns an NSString created from an array of bytes that are in the filesystem representation.
     */
    open func string(withFileSystemRepresentation str: UnsafePointer<Int8>, length len: Int) -> String {
        return NSString(bytes: str, length: len, encoding: String.Encoding.utf8.rawValue)!._swiftObject
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
    open func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: ItemReplacementOptions = []) throws -> URL? {
        NSUnimplemented()
    }

    @available(Windows, deprecated, message: "Not yet implemented")
    public func replaceItemAt(_ originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String? = nil, options: ItemReplacementOptions = []) throws -> URL? {
        NSUnimplemented()
    }

    #else
    open func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: ItemReplacementOptions = []) throws -> URL? {
        return try _replaceItem(at: originalItemURL, withItemAt: newItemURL, backupItemName: backupItemName, options: options)
    }

    public func replaceItemAt(_ originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String? = nil, options: ItemReplacementOptions = []) throws -> URL? {
        return try _replaceItem(at: originalItemURL, withItemAt: newItemURL, backupItemName: backupItemName, options: options)
    }
    #endif
    
    @available(*, unavailable, message: "Returning an object through an autoreleased pointer is not supported in swift-corelibs-foundation. Use replaceItem(at:withItemAt:backupItemName:options:) instead.", renamed: "replaceItem(at:withItemAt:backupItemName:options:)")
    open func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: FileManager.ItemReplacementOptions = [], resultingItemURL resultingURL: UnsafeMutablePointer<NSURL?>?) throws {
        NSUnsupported()
    }

    internal func _tryToResolveTrailingSymlinkInPath(_ path: String) -> String? {
        // FileManager.recursiveDestinationOfSymbolicLink(atPath:) will fail if the path is not a symbolic link
        guard let destination = try? self.recursiveDestinationOfSymbolicLink(atPath: path) else {
            return nil
        }

        return _appendSymlinkDestination(destination, toPath: path)
    }

    open var homeDirectoryForCurrentUser: URL {
        CFCopyHomeDirectoryURLForUser(nil)!.takeRetainedValue()._swiftObject
    }
    
    open var temporaryDirectory: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
    }
    
    open func homeDirectory(forUser userName: String) -> URL? {
        guard !userName.isEmpty else { return nil }
        // Prefer to take the `CFCopyHomeDirectoryURLForUser` path for the
        // current user.
        return CFCopyHomeDirectoryURLForUser(userName == NSUserName()
                                                ? nil
                                                : userName._cfObject)?
                    .takeRetainedValue()
                    ._swiftObject
    }
}

extension FileManager {
    public struct VolumeEnumerationOptions : OptionSet {
        public let rawValue : UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        /* The mounted volume enumeration will skip hidden volumes.
         */
        public static let skipHiddenVolumes = VolumeEnumerationOptions(rawValue: 1 << 1)

        /* The mounted volume enumeration will produce file reference URLs rather than path-based URLs.
         */
        public static let produceFileReferenceURLs = VolumeEnumerationOptions(rawValue: 1 << 2)
    }
    
    public struct DirectoryEnumerationOptions : OptionSet {
        public let rawValue : UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        /* NSDirectoryEnumerationSkipsSubdirectoryDescendants causes the NSDirectoryEnumerator to perform a shallow enumeration and not descend into directories it encounters.
         */
        public static let skipsSubdirectoryDescendants = DirectoryEnumerationOptions(rawValue: 1 << 0)

        /* NSDirectoryEnumerationSkipsPackageDescendants will cause the NSDirectoryEnumerator to not descend into packages.
         */
        public static let skipsPackageDescendants = DirectoryEnumerationOptions(rawValue: 1 << 1)

        /* NSDirectoryEnumerationSkipsHiddenFiles causes the NSDirectoryEnumerator to not enumerate hidden files.
         */
        public static let skipsHiddenFiles = DirectoryEnumerationOptions(rawValue: 1 << 2)
    }

    public struct ItemReplacementOptions : OptionSet {
        public let rawValue : UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        /* Causes -replaceItemAtURL:withItemAtURL:backupItemName:options:resultingItemURL:error: to use metadata from the new item only and not to attempt to preserve metadata from the original item.
         */
        public static let usingNewMetadataOnly = ItemReplacementOptions(rawValue: 1 << 0)

        /* Causes -replaceItemAtURL:withItemAtURL:backupItemName:options:resultingItemURL:error: to leave the backup item in place after a successful replacement. The default behavior is to remove the item.
         */
        public static let withoutDeletingBackupItem = ItemReplacementOptions(rawValue: 1 << 1)
    }

    public enum URLRelationship : Int {
        case contains
        case same
        case other
    }
}

public struct FileAttributeKey : RawRepresentable, Equatable, Hashable {
    public let rawValue: String
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let type = FileAttributeKey(rawValue: "NSFileType")
    public static let size = FileAttributeKey(rawValue: "NSFileSize")
    public static let modificationDate = FileAttributeKey(rawValue: "NSFileModificationDate")
    public static let referenceCount = FileAttributeKey(rawValue: "NSFileReferenceCount")
    public static let deviceIdentifier = FileAttributeKey(rawValue: "NSFileDeviceIdentifier")
    public static let ownerAccountName = FileAttributeKey(rawValue: "NSFileOwnerAccountName")
    public static let groupOwnerAccountName = FileAttributeKey(rawValue: "NSFileGroupOwnerAccountName")
    public static let posixPermissions = FileAttributeKey(rawValue: "NSFilePosixPermissions")
    public static let systemNumber = FileAttributeKey(rawValue: "NSFileSystemNumber")
    public static let systemFileNumber = FileAttributeKey(rawValue: "NSFileSystemFileNumber")
    public static let extensionHidden = FileAttributeKey(rawValue: "NSFileExtensionHidden")
    public static let hfsCreatorCode = FileAttributeKey(rawValue: "NSFileHFSCreatorCode")
    public static let hfsTypeCode = FileAttributeKey(rawValue: "NSFileHFSTypeCode")
    public static let immutable = FileAttributeKey(rawValue: "NSFileImmutable")
    public static let appendOnly = FileAttributeKey(rawValue: "NSFileAppendOnly")
    public static let creationDate = FileAttributeKey(rawValue: "NSFileCreationDate")
    public static let ownerAccountID = FileAttributeKey(rawValue: "NSFileOwnerAccountID")
    public static let groupOwnerAccountID = FileAttributeKey(rawValue: "NSFileGroupOwnerAccountID")
    public static let busy = FileAttributeKey(rawValue: "NSFileBusy")
    public static let systemSize = FileAttributeKey(rawValue: "NSFileSystemSize")
    public static let systemFreeSize = FileAttributeKey(rawValue: "NSFileSystemFreeSize")
    public static let systemNodes = FileAttributeKey(rawValue: "NSFileSystemNodes")
    public static let systemFreeNodes = FileAttributeKey(rawValue: "NSFileSystemFreeNodes")
    
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
    internal static let _userImmutable = FileAttributeKey(rawValue: "org.swift.Foundation.FileAttributeKey._userImmutable")
    internal static let _hidden = FileAttributeKey(rawValue: "org.swift.Foundation.FileAttributeKey._hidden")
    internal static let _accessDate = FileAttributeKey(rawValue: "org.swift.Foundation.FileAttributeKey._accessDate")
}

public struct FileAttributeType : RawRepresentable, Equatable, Hashable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

#if os(Windows)
    internal init(attributes: WIN32_FILE_ATTRIBUTE_DATA, atPath path: String) {
        if attributes.dwFileAttributes & FILE_ATTRIBUTE_DEVICE == FILE_ATTRIBUTE_DEVICE {
            self = .typeCharacterSpecial
        } else if attributes.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT {
            // A reparse point may or may not actually be a symbolic link, we need to read the reparse tag
            let handle: HANDLE = (try? FileManager.default._fileSystemRepresentation(withPath: path) {
              CreateFileW($0, 0, FILE_SHARE_READ | FILE_SHARE_WRITE, nil,
                          OPEN_EXISTING,
                          FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS,
                          nil)
            }) ?? INVALID_HANDLE_VALUE
            if handle == INVALID_HANDLE_VALUE {
                self = .typeUnknown
                return
            }
            defer { CloseHandle(handle) }
            var tagInfo = FILE_ATTRIBUTE_TAG_INFO()
            if !GetFileInformationByHandleEx(handle, FileAttributeTagInfo, &tagInfo,
                                             DWORD(MemoryLayout<FILE_ATTRIBUTE_TAG_INFO>.size)) {
                self = .typeUnknown
                return
            }
            self = tagInfo.ReparseTag == IO_REPARSE_TAG_SYMLINK ? .typeSymbolicLink : .typeRegular
        } else if attributes.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY {
            // Note: Since Windows marks directory symlinks as both
            // directories and reparse points, having this after the
            // reparse point check implicitly encodes Windows
            // directory symlinks as not directories, which matches
            // POSIX behavior.
            self = .typeDirectory
        } else {
            self = .typeRegular
        }
    }
#else
    internal init(statMode: mode_t) {
        switch statMode & S_IFMT {
        case S_IFCHR: self = .typeCharacterSpecial
        case S_IFDIR: self = .typeDirectory
        case S_IFBLK: self = .typeBlockSpecial
        case S_IFREG: self = .typeRegular
        case S_IFLNK: self = .typeSymbolicLink
        case S_IFSOCK: self = .typeSocket
        default: self = .typeUnknown
        }
    }
#endif

    public static let typeDirectory = FileAttributeType(rawValue: "NSFileTypeDirectory")
    public static let typeRegular = FileAttributeType(rawValue: "NSFileTypeRegular")
    public static let typeSymbolicLink = FileAttributeType(rawValue: "NSFileTypeSymbolicLink")
    public static let typeSocket = FileAttributeType(rawValue: "NSFileTypeSocket")
    public static let typeCharacterSpecial = FileAttributeType(rawValue: "NSFileTypeCharacterSpecial")
    public static let typeBlockSpecial = FileAttributeType(rawValue: "NSFileTypeBlockSpecial")
    public static let typeUnknown = FileAttributeType(rawValue: "NSFileTypeUnknown")
}

public protocol FileManagerDelegate : NSObjectProtocol {
    
    /* fileManager:shouldCopyItemAtPath:toPath: gives the delegate an opportunity to filter the resulting copy. Returning YES from this method will allow the copy to happen. Returning NO from this method causes the item in question to be skipped. If the item skipped was a directory, no children of that directory will be copied, nor will the delegate be notified of those children.
     */
    func fileManager(_ fileManager: FileManager, shouldCopyItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: FileManager, shouldCopyItemAt srcURL: URL, to dstURL: URL) -> Bool
    
    /* fileManager:shouldProceedAfterError:copyingItemAtPath:toPath: gives the delegate an opportunity to recover from or continue copying after an error. If an error occurs, the error object will contain an NSError indicating the problem. The source path and destination paths are also provided. If this method returns YES, the FileManager instance will continue as if the error had not occurred. If this method returns NO, the FileManager instance will stop copying, return NO from copyItemAtPath:toPath:error: and the error will be provided there.
     */
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, copyingItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, copyingItemAt srcURL: URL, to dstURL: URL) -> Bool
    
    /* fileManager:shouldMoveItemAtPath:toPath: gives the delegate an opportunity to not move the item at the specified path. If the source path and the destination path are not on the same device, a copy is performed to the destination path and the original is removed. If the copy does not succeed, an error is returned and the incomplete copy is removed, leaving the original in place.
    
     */
    func fileManager(_ fileManager: FileManager, shouldMoveItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: FileManager, shouldMoveItemAt srcURL: URL, to dstURL: URL) -> Bool
    
    /* fileManager:shouldProceedAfterError:movingItemAtPath:toPath: functions much like fileManager:shouldProceedAfterError:copyingItemAtPath:toPath: above. The delegate has the opportunity to remedy the error condition and allow the move to continue.
     */
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, movingItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, movingItemAt srcURL: URL, to dstURL: URL) -> Bool
    
    /* fileManager:shouldLinkItemAtPath:toPath: acts as the other "should" methods, but this applies to the file manager creating hard links to the files in question.
     */
    func fileManager(_ fileManager: FileManager, shouldLinkItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: FileManager, shouldLinkItemAt srcURL: URL, to dstURL: URL) -> Bool
    
    /* fileManager:shouldProceedAfterError:linkingItemAtPath:toPath: allows the delegate an opportunity to remedy the error which occurred in linking srcPath to dstPath. If the delegate returns YES from this method, the linking will continue. If the delegate returns NO from this method, the linking operation will stop and the error will be returned via linkItemAtPath:toPath:error:.
     */
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, linkingItemAtPath srcPath: String, toPath dstPath: String) -> Bool
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, linkingItemAt srcURL: URL, to dstURL: URL) -> Bool
    
    /* fileManager:shouldRemoveItemAtPath: allows the delegate the opportunity to not remove the item at path. If the delegate returns YES from this method, the FileManager instance will attempt to remove the item. If the delegate returns NO from this method, the remove skips the item. If the item is a directory, no children of that item will be visited.
     */
    func fileManager(_ fileManager: FileManager, shouldRemoveItemAtPath path: String) -> Bool
    func fileManager(_ fileManager: FileManager, shouldRemoveItemAt URL: URL) -> Bool
    
    /* fileManager:shouldProceedAfterError:removingItemAtPath: allows the delegate an opportunity to remedy the error which occurred in removing the item at the path provided. If the delegate returns YES from this method, the removal operation will continue. If the delegate returns NO from this method, the removal operation will stop and the error will be returned via linkItemAtPath:toPath:error:.
     */
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, removingItemAtPath path: String) -> Bool
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, removingItemAt URL: URL) -> Bool
}

extension FileManagerDelegate {
    func fileManager(_ fileManager: FileManager, shouldCopyItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return true }
    func fileManager(_ fileManager: FileManager, shouldCopyItemAt srcURL: URL, to dstURL: URL) -> Bool { return true }

    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, copyingItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return false }
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, copyingItemAt srcURL: URL, to dstURL: URL) -> Bool { return false }

    func fileManager(_ fileManager: FileManager, shouldMoveItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return true }
    func fileManager(_ fileManager: FileManager, shouldMoveItemAt srcURL: URL, to dstURL: URL) -> Bool { return true }

    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, movingItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return false }
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, movingItemAt srcURL: URL, to dstURL: URL) -> Bool { return false }

    func fileManager(_ fileManager: FileManager, shouldLinkItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return true }
    func fileManager(_ fileManager: FileManager, shouldLinkItemAt srcURL: URL, to dstURL: URL) -> Bool { return true }

    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, linkingItemAtPath srcPath: String, toPath dstPath: String) -> Bool { return false }
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, linkingItemAt srcURL: URL, to dstURL: URL) -> Bool { return false }

    func fileManager(_ fileManager: FileManager, shouldRemoveItemAtPath path: String) -> Bool { return true }
    func fileManager(_ fileManager: FileManager, shouldRemoveItemAt URL: URL) -> Bool { return true }

    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, removingItemAtPath path: String) -> Bool { return false }
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, removingItemAt URL: URL) -> Bool { return false }
}

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
