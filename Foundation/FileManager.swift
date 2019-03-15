// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if os(Android) // struct stat.st_mode is UInt32
internal func &(left: UInt32, right: mode_t) -> mode_t {
    return mode_t(left) & right
}
#endif
#if os(Windows)
fileprivate let rmdir = _NS_rmdir
fileprivate let unlink = _NS_unlink
#endif

import CoreFoundation

#if os(Windows)
internal func joinPath(prefix: String, suffix: String) -> String {
    var pszPath: PWSTR?
    _ = prefix.withCString(encodedAs: UTF16.self) { prefix in
        _ = suffix.withCString(encodedAs: UTF16.self) { suffix in
            PathAllocCombine(prefix, suffix, ULONG(PATHCCH_ALLOW_LONG_PATHS.rawValue), &pszPath)
        }
    }

    let path: String = String(decodingCString: pszPath!, as: UTF16.self)
    LocalFree(pszPath)
    return path
}
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
        var urls: [URL] = []

#if os(Linux)
        guard let procMounts = try? String(contentsOfFile: "/proc/mounts", encoding: .utf8) else {
            return nil
        }
        urls = []
        for line in procMounts.components(separatedBy: "\n") {
            let mountPoint = line.components(separatedBy: " ")
            if mountPoint.count > 2 {
                urls.append(URL(fileURLWithPath: mountPoint[1], isDirectory: true))
            }
        }
#elseif os(Windows)
      var wszVolumeName: UnsafeMutableBufferPointer<WCHAR> = UnsafeMutableBufferPointer<WCHAR>.allocate(capacity: Int(MAX_PATH))
      defer { wszVolumeName.deallocate() }

      var hVolumes: HANDLE = FindFirstVolumeW(wszVolumeName.baseAddress, DWORD(wszVolumeName.count))
      guard hVolumes != INVALID_HANDLE_VALUE else { return nil }
      defer { FindVolumeClose(hVolumes) }

      repeat {
        var dwCChReturnLength: DWORD = 0
        GetVolumePathNamesForVolumeNameW(wszVolumeName.baseAddress, nil, 0, &dwCChReturnLength)

        var wszPathNames: UnsafeMutableBufferPointer<WCHAR> = UnsafeMutableBufferPointer<WCHAR>.allocate(capacity: Int(dwCChReturnLength + 1))
        defer { wszPathNames.deallocate() }

        if GetVolumePathNamesForVolumeNameW(wszVolumeName.baseAddress, wszPathNames.baseAddress, DWORD(wszPathNames.count), &dwCChReturnLength) == FALSE {
          // TODO(compnerd) handle error
          continue
        }

        var pPath: DWORD = 0
        repeat {
          let path: String = String(decodingCString: wszPathNames.baseAddress! + Int(pPath), as: UTF16.self)
          if path.length == 0 {
            break
          }
          urls.append(URL(fileURLWithPath: path, isDirectory: true))
          pPath += DWORD(path.length + 1)
        } while pPath < dwCChReturnLength
      } while FindNextVolumeW(hVolumes, wszVolumeName.baseAddress, DWORD(wszVolumeName.count)) != FALSE
#elseif canImport(Darwin)

        func mountPoints(_ statBufs: UnsafePointer<statfs>, _ fsCount: Int) -> [URL] {
            var urls: [URL] = []

            for fsIndex in 0..<fsCount {
                var fs = statBufs.advanced(by: fsIndex).pointee

                if options.contains(.skipHiddenVolumes) && fs.f_flags & UInt32(MNT_DONTBROWSE) != 0 {
                    continue
                }

                let mountPoint = withUnsafePointer(to: &fs.f_mntonname.0) { (ptr: UnsafePointer<Int8>) -> String in
                    return string(withFileSystemRepresentation: ptr, length: strlen(ptr))
                }
                urls.append(URL(fileURLWithPath: mountPoint, isDirectory: true))
            }
            return urls
        }

        if #available(OSX 10.13, *) {
            var statBufPtr: UnsafeMutablePointer<statfs>?
            let fsCount = getmntinfo_r_np(&statBufPtr, MNT_WAIT)
            guard let statBuf = statBufPtr, fsCount > 0 else {
                return nil
            }
            urls = mountPoints(statBuf, Int(fsCount))
            free(statBufPtr)
        } else {
            var fsCount = getfsstat(nil, 0, MNT_WAIT)
            guard fsCount > 0 else {
                return nil
            }
            let statBuf = UnsafeMutablePointer<statfs>.allocate(capacity: Int(fsCount))
            defer { statBuf.deallocate() }
            fsCount = getfsstat(statBuf, fsCount * Int32(MemoryLayout<statfs>.stride), MNT_WAIT)
            guard fsCount > 0 else {
                return nil
            }
            urls = mountPoints(statBuf, Int(fsCount))
        }
#else
#error("Requires a platform-specific implementation")
#endif
        return urls
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
    
    private enum _SearchPathDomain {
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
    
    private func darwinPathURLs(for domain: _SearchPathDomain, system: String?, local: String?, network: String?, userHomeSubpath: String?) -> [URL] {
        switch domain {
        case .system:
            guard let path = system else { return [] }
            return [ URL(fileURLWithPath: path, isDirectory: true) ]
        case .local:
            guard let path = local else { return [] }
            return [ URL(fileURLWithPath: path, isDirectory: true) ]
        case .network:
            guard let path = network else { return [] }
            return [ URL(fileURLWithPath: path, isDirectory: true) ]
        case .user:
            guard let path = userHomeSubpath else { return [] }
            return [ URL(fileURLWithPath: path, isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
        }
    }
    
    private func darwinPathURLs(for domain: _SearchPathDomain, all: String, useLocalDirectoryForSystem: Bool = false) -> [URL] {
        switch domain {
        case .system:
            return [ URL(fileURLWithPath: useLocalDirectoryForSystem ? "/\(all)" : "/System/\(all)", isDirectory: true) ]
        case .local:
            return [ URL(fileURLWithPath: "/\(all)", isDirectory: true) ]
        case .network:
            return [ URL(fileURLWithPath: "/Network/\(all)", isDirectory: true) ]
        case .user:
            return [ URL(fileURLWithPath: all, isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
        }
    }

    /* -URLsForDirectory:inDomains: is analogous to NSSearchPathForDirectoriesInDomains(), but returns an array of NSURL instances for use with URL-taking APIs. This API is suitable when you need to search for a file or files which may live in one of a variety of locations in the domains specified.
     */
    open func urls(for directory: SearchPathDirectory, in domainMask: SearchPathDomainMask) -> [URL] {
        let domains = _SearchPathDomain.allInSearchOrder(from: domainMask)

        var urls: [URL] = []

#if os(Windows)
        for domain in domains {
          urls.append(contentsOf: windowsURLs(for: directory, in: domain))
        }
#else
        // We are going to return appropriate paths on Darwin, but [] on platforms that do not have comparable locations.
        // For example, on FHS/XDG systems, applications are not installed in a single path.

        let useDarwinPaths: Bool
        if let envVar = ProcessInfo.processInfo.environment["_NSFileManagerUseXDGPathsForDirectoryDomains"] {
            useDarwinPaths = !NSString(string: envVar).boolValue
        } else {
            #if canImport(Darwin)
                useDarwinPaths = true
            #else
                useDarwinPaths = false
            #endif
        }

        for domain in domains {
            if useDarwinPaths {
                urls.append(contentsOf: darwinURLs(for: directory, in: domain))
            } else {
                urls.append(contentsOf: xdgURLs(for: directory, in: domain))
            }
        }
#endif

        return urls
    }

#if os(Windows)
    private class func url(for id: KNOWNFOLDERID) -> URL {
      var pszPath: PWSTR?
      let hResult: HRESULT = withUnsafePointer(to: id) { id in
        SHGetKnownFolderPath(id, DWORD(KF_FLAG_DEFAULT.rawValue), nil, &pszPath)
      }
      precondition(hResult >= 0, "SHGetKnownFolderpath failed \(GetLastError())")
      let url: URL = URL(fileURLWithPath: String(decodingCString: pszPath!, as: UTF16.self), isDirectory: true)
      CoTaskMemFree(pszPath)
      return url
    }

    private func windowsURLs(for directory: SearchPathDirectory, in domain: _SearchPathDomain) -> [URL] {
      switch directory {
      case .autosavedInformationDirectory:
        // FIXME(compnerd) where should this go?
        return []

      case .desktopDirectory:
        guard domain == .user else { return [] }
        return [FileManager.url(for: FOLDERID_Desktop)]

      case .documentDirectory:
        guard domain == .user else { return [] }
        return [FileManager.url(for: FOLDERID_Documents)]

      case .cachesDirectory:
        guard domain == .user else { return [] }
        return [URL(fileURLWithPath: NSTemporaryDirectory())]

      case .applicationSupportDirectory:
        switch domain {
        case .local:
          return [FileManager.url(for: FOLDERID_ProgramData)]
        case .user:
          return [FileManager.url(for: FOLDERID_LocalAppData)]
        default:
          return []
        }

      case .downloadsDirectory:
        guard domain == .user else { return [] }
        return [FileManager.url(for: FOLDERID_Downloads)]

      case .userDirectory:
        guard domain == .user else { return [] }
        return [FileManager.url(for: FOLDERID_UserProfiles)]

      case .moviesDirectory:
        guard domain == .user else { return [] }
        return [FileManager.url(for: FOLDERID_Videos)]

      case .musicDirectory:
        guard domain == .user else { return [] }
        return [FileManager.url(for: FOLDERID_Music)]

      case .picturesDirectory:
        guard domain == .user else { return [] }
        return [FileManager.url(for: FOLDERID_PicturesLibrary)]

      case .sharedPublicDirectory:
        guard domain == .user else { return [] }
        return [FileManager.url(for: FOLDERID_Public)]

      case .trashDirectory:
        guard domain == .user else { return [] }
        return [FileManager.url(for: FOLDERID_RecycleBinFolder)]

       // None of these are supported outside of Darwin:
      case .applicationDirectory,
           .demoApplicationDirectory,
           .developerApplicationDirectory,
           .adminApplicationDirectory,
           .libraryDirectory,
           .developerDirectory,
           .documentationDirectory,
           .coreServiceDirectory,
           .inputMethodsDirectory,
           .preferencePanesDirectory,
           .applicationScriptsDirectory,
           .allApplicationsDirectory,
           .allLibrariesDirectory,
           .printerDescriptionDirectory,
           .itemReplacementDirectory:
          return []
      }
    }
#endif

    private lazy var xdgHomeDirectory: String = {
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

    private func xdgURLs(for directory: SearchPathDirectory, in domain: _SearchPathDomain) -> [URL] {
        // FHS/XDG-compliant OSes:
        switch directory {
        case .autosavedInformationDirectory:
            let runtimePath = __SwiftValue.fetch(nonOptional: _CFXDGCreateDataHomePath()) as! String
            return [ URL(fileURLWithPath: "Autosave Information", isDirectory: true, relativeTo: URL(fileURLWithPath: runtimePath, isDirectory: true)) ]
            
        case .desktopDirectory:
            guard domain == .user else { return [] }
            return [ _XDGUserDirectory.desktop.url ]
            
        case .documentDirectory:
            guard domain == .user else { return [] }
            return [ _XDGUserDirectory.documents.url ]
            
        case .cachesDirectory:
            guard domain == .user else { return [] }
            let path = __SwiftValue.fetch(nonOptional: _CFXDGCreateCacheDirectoryPath()) as! String
            return [ URL(fileURLWithPath: path, isDirectory: true) ]
            
        case .applicationSupportDirectory:
            guard domain == .user else { return [] }
            let path = __SwiftValue.fetch(nonOptional: _CFXDGCreateDataHomePath()) as! String
            return [ URL(fileURLWithPath: path, isDirectory: true) ]
            
        case .downloadsDirectory:
            guard domain == .user else { return [] }
            return [ _XDGUserDirectory.download.url ]
            
        case .userDirectory:
            guard domain == .local else { return [] }
            return [ URL(fileURLWithPath: xdgHomeDirectory, isDirectory: true) ]
            
        case .moviesDirectory:
            return [ _XDGUserDirectory.videos.url ]
            
        case .musicDirectory:
            guard domain == .user else { return [] }
            return [ _XDGUserDirectory.music.url ]
            
        case .picturesDirectory:
            guard domain == .user else { return [] }
            return [ _XDGUserDirectory.pictures.url ]
            
        case .sharedPublicDirectory:
            guard domain == .user else { return [] }
            return [ _XDGUserDirectory.publicShare.url ]
            
        case .trashDirectory:
            let userTrashURL = URL(fileURLWithPath: ".Trash", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
            if domain == .user || domain == .local {
                return [ userTrashURL ]
            } else {
                return []
            }
            
        // None of these are supported outside of Darwin:
        case .applicationDirectory:
            fallthrough
        case .demoApplicationDirectory:
            fallthrough
        case .developerApplicationDirectory:
            fallthrough
        case .adminApplicationDirectory:
            fallthrough
        case .libraryDirectory:
            fallthrough
        case .developerDirectory:
            fallthrough
        case .documentationDirectory:
            fallthrough
        case .coreServiceDirectory:
            fallthrough
        case .inputMethodsDirectory:
            fallthrough
        case .preferencePanesDirectory:
            fallthrough
        case .applicationScriptsDirectory:
            fallthrough
        case .allApplicationsDirectory:
            fallthrough
        case .allLibrariesDirectory:
            fallthrough
        case .printerDescriptionDirectory:
            fallthrough
        case .itemReplacementDirectory:
            return []
        }
    }
    
    private func darwinURLs(for directory: SearchPathDirectory, in domain: _SearchPathDomain) -> [URL] {
        switch directory {
        case .applicationDirectory:
            return darwinPathURLs(for: domain, all: "Applications", useLocalDirectoryForSystem: true)
            
        case .demoApplicationDirectory:
            return darwinPathURLs(for: domain, all: "Demos", useLocalDirectoryForSystem: true)
            
        case .developerApplicationDirectory:
            return darwinPathURLs(for: domain, all: "Developer/Applications", useLocalDirectoryForSystem: true)
            
        case .adminApplicationDirectory:
            return darwinPathURLs(for: domain, all: "Applications/Utilities", useLocalDirectoryForSystem: true)
            
        case .libraryDirectory:
            return darwinPathURLs(for: domain, all: "Library")
            
        case .developerDirectory:
            return darwinPathURLs(for: domain, all: "Developer", useLocalDirectoryForSystem: true)
            
        case .documentationDirectory:
            return darwinPathURLs(for: domain, all: "Library/Documentation")
            
        case .coreServiceDirectory:
            return darwinPathURLs(for: domain, system: "/System/Library/CoreServices", local: nil, network: nil, userHomeSubpath: nil)
            
        case .autosavedInformationDirectory:
            return darwinPathURLs(for: domain, system: nil, local: nil, network: nil, userHomeSubpath: "Library/Autosave Information")
            
        case .inputMethodsDirectory:
            return darwinPathURLs(for: domain, all: "Library/Input Methods")
            
        case .preferencePanesDirectory:
            return darwinPathURLs(for: domain, system: "/System/Library/PreferencePanes", local: "/Library/PreferencePanes", network: nil, userHomeSubpath: "Library/PreferencePanes")
            
        case .applicationScriptsDirectory:
            // Only the ObjC Foundation can know where this is.
            return []
            
        case .allApplicationsDirectory:
            var directories: [URL] = []
            directories.append(contentsOf: darwinPathURLs(for: domain, all: "Applications", useLocalDirectoryForSystem: true))
            directories.append(contentsOf: darwinPathURLs(for: domain, all: "Demos", useLocalDirectoryForSystem: true))
            directories.append(contentsOf: darwinPathURLs(for: domain, all: "Developer/Applications", useLocalDirectoryForSystem: true))
            directories.append(contentsOf: darwinPathURLs(for: domain, all: "Applications/Utilities", useLocalDirectoryForSystem: true))
            return directories
            
        case .allLibrariesDirectory:
            var directories: [URL] = []
            directories.append(contentsOf: darwinPathURLs(for: domain, all: "Library"))
            directories.append(contentsOf: darwinPathURLs(for: domain, all: "Developer"))
            return directories
            
        case .printerDescriptionDirectory:
            guard domain == .system else { return [] }
            return [ URL(fileURLWithPath: "/System/Library/Printers/PPD", isDirectory: true) ]
            
        case .desktopDirectory:
            guard domain == .user else { return [] }
            return [ URL(fileURLWithPath: "Desktop", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
            
        case .documentDirectory:
            guard domain == .user else { return [] }
            return [ URL(fileURLWithPath: "Documents", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
            
        case .cachesDirectory:
            guard domain == .user else { return [] }
            return [ URL(fileURLWithPath: "Library/Caches", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
            
        case .applicationSupportDirectory:
            guard domain == .user else { return [] }
            return [ URL(fileURLWithPath: "Library/Application Support", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
            
        case .downloadsDirectory:
            guard domain == .user else { return [] }
            return [ URL(fileURLWithPath: "Downloads", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
            
        case .userDirectory:
            return darwinPathURLs(for: domain, system: nil, local: "/Users", network: "/Network/Users", userHomeSubpath: nil)
            
        case .moviesDirectory:
            guard domain == .user else { return [] }
            return [ URL(fileURLWithPath: "Movies", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
            
        case .musicDirectory:
            guard domain == .user else { return [] }
            return [ URL(fileURLWithPath: "Music", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
            
        case .picturesDirectory:
            guard domain == .user else { return [] }
            return [ URL(fileURLWithPath: "Pictures", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
            
        case .sharedPublicDirectory:
            guard domain == .user else { return [] }
            return [ URL(fileURLWithPath: "Public", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) ]
            
        case .trashDirectory:
            let userTrashURL = URL(fileURLWithPath: ".Trash", isDirectory: true, relativeTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
            if domain == .user || domain == .local {
                return [ userTrashURL ]
            } else {
                return []
            }
            
        case .itemReplacementDirectory:
            // This directory is only returned by url(for:in:appropriateFor:create:)
            return []
        }
    }
        
    private enum URLForDirectoryError: Error {
        case directoryUnknown
    }
    
    /* -URLForDirectory:inDomain:appropriateForURL:create:error: is a URL-based replacement for FSFindFolder(). It allows for the specification and (optional) creation of a specific directory for a particular purpose (e.g. the replacement of a particular item on disk, or a particular Library directory.
     
        You may pass only one of the values from the NSSearchPathDomainMask enumeration, and you may not pass NSAllDomainsMask.
     */
    open func url(for directory: SearchPathDirectory, in domain: SearchPathDomainMask, appropriateFor url: URL?, create shouldCreate: Bool) throws -> URL {
        let urls = self.urls(for: directory, in: domain)
        guard let url = urls.first else {
            // On Apple OSes, this case returns nil without filling in the error parameter; Swift then synthesizes an error rather than trap.
            // We simulate that behavior by throwing a private error.
            throw URLForDirectoryError.directoryUnknown
        }
        
        if shouldCreate {
            var attributes: [FileAttributeKey : Any] = [:]
            
            switch _SearchPathDomain(domain) {
            case .some(.user):
                attributes[.posixPermissions] = 0700
                
            case .some(.system):
                attributes[.posixPermissions] = 0755
                attributes[.ownerAccountID] = 0 // root
                #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
                    attributes[.ownerAccountID] = 80 // on Darwin, the admin group's fixed ID.
                #endif
                
            default:
                break
            }
            
            try createDirectory(at: url, withIntermediateDirectories: true, attributes: attributes)
        }
        
        return url
    }
    
    /* Sets 'outRelationship' to NSURLRelationshipContains if the directory at 'directoryURL' directly or indirectly contains the item at 'otherURL', meaning 'directoryURL' is found while enumerating parent URLs starting from 'otherURL'. Sets 'outRelationship' to NSURLRelationshipSame if 'directoryURL' and 'otherURL' locate the same item, meaning they have the same NSURLFileResourceIdentifierKey value. If 'directoryURL' is not a directory, or does not contain 'otherURL' and they do not locate the same file, then sets 'outRelationship' to NSURLRelationshipOther. If an error occurs, returns NO and sets 'error'.
     */
    open func getRelationship(_ outRelationship: UnsafeMutablePointer<URLRelationship>, ofDirectoryAt directoryURL: URL, toItemAt otherURL: URL) throws {
        NSUnimplemented()
    }
    
    /* Similar to -[NSFileManager getRelationship:ofDirectoryAtURL:toItemAtURL:error:], except that the directory is instead defined by an NSSearchPathDirectory and NSSearchPathDomainMask. Pass 0 for domainMask to instruct the method to automatically choose the domain appropriate for 'url'. For example, to discover if a file is contained by a Trash directory, call [fileManager getRelationship:&result ofDirectory:NSTrashDirectory inDomain:0 toItemAtURL:url error:&error].
     */
    open func getRelationship(_ outRelationship: UnsafeMutablePointer<URLRelationship>, of directory: SearchPathDirectory, in domainMask: SearchPathDomainMask, toItemAt url: URL) throws {
        NSUnimplemented()
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
        for attribute in attributes.keys {
            if attribute == .posixPermissions {
                guard let number = attributes[attribute] as? NSNumber else {
                    fatalError("Can't set file permissions to \(attributes[attribute] as Any?)")
                }
                #if os(macOS) || os(iOS)
                    let modeT = number.uint16Value
                #elseif os(Linux) || os(Android) || os(Windows)
                    let modeT = number.uint32Value
                #endif
                try _fileSystemRepresentation(withPath: path, {
                    guard chmod($0, mode_t(modeT)) == 0 else {
                        throw _NSErrorWithErrno(errno, reading: false, path: path)
                    }
                })
            } else {
                fatalError("Attribute type not implemented: \(attribute)")
            }
        }
    }
    
    /* createDirectoryAtPath:withIntermediateDirectories:attributes:error: creates a directory at the specified path. If you pass 'NO' for createIntermediates, the directory must not exist at the time this call is made. Passing 'YES' for 'createIntermediates' will create any necessary intermediate directories. This method returns YES if all directories specified in 'path' were created and attributes were set. Directories are created with attributes specified by the dictionary passed to 'attributes'. If no dictionary is supplied, directories are created according to the umask of the process. This method returns NO if a failure occurs at any stage of the operation. If an error parameter was provided, a presentable NSError will be returned by reference.
     
        This method replaces createDirectoryAtPath:attributes:
     */
    open func createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = [:]) throws {
#if os(Windows)
        if createIntermediates {
          var isDir: ObjCBool = false
          if fileExists(atPath: path, isDirectory: &isDir) {
            guard isDir.boolValue else { throw _NSErrorWithErrno(EEXIST, reading: false, path: path) }
            return
          }

          let parent = path._nsObject.deletingLastPathComponent
          if !parent.isEmpty && !fileExists(atPath: parent, isDirectory: &isDir) {
            try createDirectory(atPath: parent, withIntermediateDirectories: true, attributes: attributes)
          }
        }

        var saAttributes: SECURITY_ATTRIBUTES =
            SECURITY_ATTRIBUTES(nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size),
                                lpSecurityDescriptor: nil,
                                bInheritHandle: FALSE)
        let psaAttributes: UnsafeMutablePointer<SECURITY_ATTRIBUTES> =
            UnsafeMutablePointer<SECURITY_ATTRIBUTES>(&saAttributes)


        try path.withCString(encodedAs: UTF16.self) {
          if CreateDirectoryW($0, psaAttributes) != FALSE {
            // FIXME(compnerd) pass along path
            throw _NSErrorWithWindowsError(GetLastError(), reading: false)
          }
        }
        if let attr = attributes {
          try self.setAttributes(attr, ofItemAtPath: path)
        }
#else
        try _fileSystemRepresentation(withPath: path, { pathFsRep in
            if createIntermediates {
                var isDir: ObjCBool = false
                if !fileExists(atPath: path, isDirectory: &isDir) {
                    let parent = path._nsObject.deletingLastPathComponent
                    if !parent.isEmpty && !fileExists(atPath: parent, isDirectory: &isDir) {
                        try createDirectory(atPath: parent, withIntermediateDirectories: true, attributes: attributes)
                    }
                    if mkdir(pathFsRep, S_IRWXU | S_IRWXG | S_IRWXO) != 0 {
                        throw _NSErrorWithErrno(errno, reading: false, path: path)
                    } else if let attr = attributes {
                        try self.setAttributes(attr, ofItemAtPath: path)
                    }
                } else if isDir.boolValue {
                    return
                } else {
                    throw _NSErrorWithErrno(EEXIST, reading: false, path: path)
                }
            } else {
                if mkdir(pathFsRep, S_IRWXU | S_IRWXG | S_IRWXO) != 0 {
                    throw _NSErrorWithErrno(errno, reading: false, path: path)
                } else if let attr = attributes {
                    try self.setAttributes(attr, ofItemAtPath: path)
                }
            }
        })
#endif
    }

    private func _contentsOfDir(atPath path: String, _ closure: (String, Int32) throws -> () ) throws {
#if os(Windows)
        try path.withCString(encodedAs: UTF16.self) {
          var ffd: WIN32_FIND_DATAW = WIN32_FIND_DATAW()

          let hDirectory: HANDLE = FindFirstFileW($0, &ffd)
          if hDirectory == INVALID_HANDLE_VALUE {
            throw _NSErrorWithWindowsError(GetLastError(), reading: true)
          }
          defer { FindClose(hDirectory) }

          repeat {
            let path: String = withUnsafePointer(to: &ffd.cFileName) {
              $0.withMemoryRebound(to: UInt16.self, capacity: MemoryLayout.size(ofValue: $0) / MemoryLayout<WCHAR>.size) {
                String(decodingCString: $0, as: UTF16.self)
              }
            }

            try closure(path, Int32(ffd.dwFileAttributes))
          } while FindNextFileW(hDirectory, &ffd) != FALSE
        }
#else
        let fsRep = fileSystemRepresentation(withPath: path)
        defer { fsRep.deallocate() }

        guard let dir = opendir(fsRep) else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadNoSuchFile.rawValue,
                          userInfo: [NSFilePathErrorKey: path, "NSUserStringVariant": NSArray(object: "Folder")])
        }
        defer { closedir(dir) }

        var entry = dirent()
        var result: UnsafeMutablePointer<dirent>? = nil

        while readdir_r(dir, &entry, &result) == 0 {
            guard result != nil else {
                return
            }
            let length = Int(_direntNameLength(&entry))
            let entryName = withUnsafePointer(to: &entry.d_name) { (ptr) -> String in
                let namePtr = UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                return string(withFileSystemRepresentation: namePtr, length: length)
            }
            if entryName != "." && entryName != ".." {
                let entryType = Int32(entry.d_type)
                try closure(entryName, entryType)
            }
        }
#endif
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
        var contents: [String] = []

        try _contentsOfDir(atPath: path, { (entryName, entryType) throws in
            contents.append(entryName)
#if os(Windows)
            if entryType & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY {
              let subPath: String = joinPath(prefix: path, suffix: entryName)
              let entries = try subpathsOfDirectory(atPath: subPath)
              contents.append(contentsOf: entries.map { joinPath(prefix: entryName, suffix: $0) })
            }
#else
            if entryType == DT_DIR {
                let subPath: String = path + "/" + entryName
                let entries = try subpathsOfDirectory(atPath: subPath)
                contents.append(contentsOf: entries.map({file in "\(entryName)/\(file)"}))
            }
#endif
        })
        return contents
    }


#if os(Windows)
    private func windowsFileAttributes(atPath path: String) throws -> WIN32_FILE_ATTRIBUTE_DATA {
      var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = WIN32_FILE_ATTRIBUTE_DATA()
      return try path.withCString(encodedAs: UTF16.self) {
        if GetFileAttributesExW($0, GetFileExInfoStandard, &faAttributes) == FALSE {
          throw _NSErrorWithWindowsError(GetLastError(), reading: true)
        }
        return faAttributes
      }
    }
#endif

    /* attributesOfItemAtPath:error: returns an NSDictionary of key/value pairs containing the attributes of the item (file, directory, symlink, etc.) at the path in question. If this method returns 'nil', an NSError will be returned by reference in the 'error' parameter. This method does not traverse a terminal symlink.

        This method replaces fileAttributesAtPath:traverseLink:.
     */
    open func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        var result: [FileAttributeKey:Any] = [:]

#if os(Windows)
        let faAttributes: WIN32_FILE_ATTRIBUTE_DATA = try windowsFileAttributes(atPath: path)

        result[.size] = NSNumber(value: (faAttributes.nFileSizeHigh << 32) | faAttributes.nFileSizeLow)
        result[.modificationDate] = Date(timeIntervalSinceReferenceDate: TimeInterval(faAttributes.ftLastWriteTime))
        // FIXME(compnerd) what about .posixPermissions, .referenceCount, .systemNumber, .systemFileNumber, .ownerAccountName, .groupOwnerAccountName, .type, .immuatable, .appendOnly, .ownerAccountID, .groupOwnerAccountID
#else
   
#if os(Linux)
        let (s, creationDate) = try _statxFile(atPath: path)
        result[.creationDate] = creationDate
#else
        let s = try _lstatFile(atPath: path)
#endif

        result[.size] = NSNumber(value: UInt64(s.st_size))

#if os(macOS) || os(iOS)
        let ti = (TimeInterval(s.st_mtimespec.tv_sec) - kCFAbsoluteTimeIntervalSince1970) + (1.0e-9 * TimeInterval(s.st_mtimespec.tv_nsec))
#elseif os(Android)
        let ti = (TimeInterval(s.st_mtime) - kCFAbsoluteTimeIntervalSince1970) + (1.0e-9 * TimeInterval(s.st_mtime_nsec))
#else
        let ti = (TimeInterval(s.st_mtim.tv_sec) - kCFAbsoluteTimeIntervalSince1970) + (1.0e-9 * TimeInterval(s.st_mtim.tv_nsec))
#endif
        result[.modificationDate] = Date(timeIntervalSinceReferenceDate: ti)
        
        result[.posixPermissions] = NSNumber(value: UInt64(s.st_mode & ~S_IFMT))
        result[.referenceCount] = NSNumber(value: UInt64(s.st_nlink))
        result[.systemNumber] = NSNumber(value: UInt64(s.st_dev))
        result[.systemFileNumber] = NSNumber(value: UInt64(s.st_ino))
        
        if let pwd = getpwuid(s.st_uid), pwd.pointee.pw_name != nil {
            let name = String(cString: pwd.pointee.pw_name)
            result[.ownerAccountName] = name
        }
        
        if let grd = getgrgid(s.st_gid), grd.pointee.gr_name != nil {
            let name = String(cString: grd.pointee.gr_name)
            result[.groupOwnerAccountName] = name
        }

        let type = FileAttributeType(statMode: s.st_mode)
        result[.type] = type
        
        if type == .typeBlockSpecial || type == .typeCharacterSpecial {
            result[.deviceIdentifier] = NSNumber(value: UInt64(s.st_rdev))
        }

#if os(macOS) || os(iOS)
        if (s.st_flags & UInt32(UF_IMMUTABLE | SF_IMMUTABLE)) != 0 {
            result[.immutable] = NSNumber(value: true)
        }
        if (s.st_flags & UInt32(UF_APPEND | SF_APPEND)) != 0 {
            result[.appendOnly] = NSNumber(value: true)
        }
#endif
        result[.ownerAccountID] = NSNumber(value: UInt64(s.st_uid))
        result[.groupOwnerAccountID] = NSNumber(value: UInt64(s.st_gid))
#endif

        return result
    }
    
    /* attributesOfFileSystemForPath:error: returns an NSDictionary of key/value pairs containing the attributes of the filesystem containing the provided path. If this method returns 'nil', an NSError will be returned by reference in the 'error' parameter. This method does not traverse a terminal symlink.
     
        This method replaces fileSystemAttributesAtPath:.
     */
 #if os(Android)
    @available(*, unavailable, message: "Unsuppported on this platform")
    open func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey : Any] {
        NSUnsupported()
    }
 #else
    open func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey : Any] {
      var result: [FileAttributeKey:Any] = [:]

#if os(Windows)
      try path.withCString(encodedAs: UTF16.self) {
        let dwLength: DWORD = GetFullPathNameW($0, 0, nil, nil)
        let szVolumePath: UnsafeMutableBufferPointer<WCHAR> = UnsafeMutableBufferPointer<WCHAR>.allocate(capacity: Int(dwLength + 1))
        defer { szVolumePath.deallocate() }

        guard GetVolumePathNameW($0, szVolumePath.baseAddress, dwLength) != FALSE else {
          throw _NSErrorWithWindowsError(GetLastError(), reading: true)
        }

        var liTotal: ULARGE_INTEGER = ULARGE_INTEGER()
        var liFree: ULARGE_INTEGER = ULARGE_INTEGER()

        guard GetDiskFreeSpaceExW(szVolumePath.baseAddress, nil, &liTotal, &liFree) != FALSE else {
          throw _NSErrorWithWindowsError(GetLastError(), reading: true)
        }

        result[.systemSize] = NSNumber(value: liTotal.QuadPart)
        result[.systemFreeSize] = NSNumber(value: liFree.QuadPart)
        // FIXME(compnerd): what about .systemNodes, .systemFreeNodes?
      }
#else
        // statvfs(2) doesn't support 64bit inode on Darwin (apfs), fallback to statfs(2)
        #if os(macOS) || os(iOS)
            var s = statfs()
            guard statfs(path, &s) == 0 else {
                throw _NSErrorWithErrno(errno, reading: true, path: path)
            }
        #else
            var s = statvfs()
            guard statvfs(path, &s) == 0 else {
                throw _NSErrorWithErrno(errno, reading: true, path: path)
            }
        #endif

        #if os(macOS) || os(iOS)
            let blockSize = UInt64(s.f_bsize)
            result[.systemNumber] = NSNumber(value: UInt64(s.f_fsid.val.0))
        #else
            let blockSize = UInt64(s.f_frsize)
            result[.systemNumber] = NSNumber(value: UInt64(s.f_fsid))
        #endif
        result[.systemSize] = NSNumber(value: blockSize * UInt64(s.f_blocks))
        result[.systemFreeSize] = NSNumber(value: blockSize * UInt64(s.f_bavail))
        result[.systemNodes] = NSNumber(value: UInt64(s.f_files))
        result[.systemFreeNodes] = NSNumber(value: UInt64(s.f_ffree))
#endif

        return result
    }
#endif
    
    /* createSymbolicLinkAtPath:withDestination:error: returns YES if the symbolic link that point at 'destPath' was able to be created at the location specified by 'path'. If this method returns NO, the link was unable to be created and an NSError will be returned by reference in the 'error' parameter. This method does not traverse a terminal symlink.
     
        This method replaces createSymbolicLinkAtPath:pathContent:
     */
    open func createSymbolicLink(atPath path: String, withDestinationPath destPath: String) throws {
#if os(Windows)
      let faAttributes: WIN32_FILE_ATTRIBUTE_DATA = try windowsFileAttributes(atPath: path)
      var dwFlags: DWORD = DWORD(SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE)
      if faAttributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) == DWORD(FILE_ATTRIBUTE_DIRECTORY) {
        dwFlags |= DWORD(SYMBOLIC_LINK_FLAG_DIRECTORY)
      }

      try path.withCString(encodedAs: UTF16.self) { name in
        try destPath.withCString(encodedAs: UTF16.self) { dest in
          guard CreateSymbolicLinkW(name, dest, dwFlags) != FALSE else {
            throw _NSErrorWithWindowsError(GetLastError(), reading: false)
          }
        }
      }
#else
        try _fileSystemRepresentation(withPath: path, andPath: destPath, {
            guard symlink($1, $0) == 0 else {
                throw _NSErrorWithErrno(errno, reading: false, path: path)
            }
        })
#endif
    }
    
    /* destinationOfSymbolicLinkAtPath:error: returns a String containing the path of the item pointed at by the symlink specified by 'path'. If this method returns 'nil', an NSError will be thrown.
     
        This method replaces pathContentOfSymbolicLinkAtPath:
     */
    open func destinationOfSymbolicLink(atPath path: String) throws -> String {
#if os(Windows)
        var hFile: HANDLE = INVALID_HANDLE_VALUE
        path.withCString(encodedAs: UTF16.self) { link in
          hFile = CreateFileW(link, GENERIC_READ, DWORD(FILE_SHARE_WRITE), nil, DWORD(OPEN_EXISTING), DWORD(FILE_FLAG_BACKUP_SEMANTICS), nil)
        }
        if hFile == INVALID_HANDLE_VALUE {
          throw _NSErrorWithWindowsError(GetLastError(), reading: true)
        }

        let dwLength: DWORD = GetFinalPathNameByHandleW(hFile, nil, 0, DWORD(FILE_NAME_NORMALIZED))
        let szPath: UnsafeMutableBufferPointer<WCHAR> = UnsafeMutableBufferPointer<WCHAR>.allocate(capacity: Int(dwLength + 1))
        defer { szPath.deallocate() }

        GetFinalPathNameByHandleW(hFile, szPath.baseAddress, dwLength, DWORD(FILE_NAME_NORMALIZED))
        return String(decodingCString: szPath.baseAddress!, as: UTF16.self)
#else
        let bufSize = Int(PATH_MAX + 1)
        var buf = [Int8](repeating: 0, count: bufSize)
        let len = _fileSystemRepresentation(withPath: path) {
            readlink($0, &buf, bufSize)
        }
        if len < 0 {
            throw _NSErrorWithErrno(errno, reading: true, path: path)
        }
        
        return self.string(withFileSystemRepresentation: buf, length: Int(len))
#endif
    }

#if !os(Windows)
    private func _readFrom(fd: Int32, toBuffer buffer: UnsafeMutablePointer<UInt8>, length bytesToRead: Int, filename: String) throws -> Int {
        var bytesRead = 0

        repeat {
            bytesRead = numericCast(read(fd, buffer, numericCast(bytesToRead)))
        } while bytesRead < 0 && errno == EINTR
        guard bytesRead >= 0 else {
            throw _NSErrorWithErrno(errno, reading: true, path: filename)
        }
        return bytesRead
    }

    private func _writeTo(fd: Int32, fromBuffer buffer : UnsafeMutablePointer<UInt8>, length bytesToWrite: Int, filename: String) throws {
        var bytesWritten = 0
        while bytesWritten < bytesToWrite {
            var written = 0
            let bytesLeftToWrite = bytesToWrite - bytesWritten
            repeat {
                written =
                    numericCast(write(fd, buffer.advanced(by: bytesWritten),
                                      numericCast(bytesLeftToWrite)))
            } while written < 0 && errno == EINTR
            guard written >= 0 else {
                throw _NSErrorWithErrno(errno, reading: false, path: filename)
            }
            bytesWritten += written
        }
    }
#endif

    private func extraErrorInfo(srcPath: String?, dstPath: String?, userVariant: String?) -> [String : Any] {
        var result = [String : Any]()
        result["NSSourceFilePathErrorKey"] = srcPath
        result["NSDestinationFilePath"] = dstPath
        result["NSUserStringVariant"] = userVariant.map(NSArray.init(object:))
        return result
    }

    private func _copyRegularFile(atPath srcPath: String, toPath dstPath: String, variant: String = "Copy") throws {
#if os(Windows)
        try srcPath.withCString(encodedAs: UTF16.self) { src in
          try dstPath.withCString(encodedAs: UTF16.self) { dst in
            if CopyFileW(src, dst, FALSE) == FALSE {
              throw _NSErrorWithWindowsError(GetLastError(), reading: false)
            }
          }
        }
#else
        let srcRep = fileSystemRepresentation(withPath: srcPath)
        let dstRep = fileSystemRepresentation(withPath: dstPath)
        defer {
            srcRep.deallocate()
            dstRep.deallocate()
        }

        var fileInfo = stat()
        guard stat(srcRep, &fileInfo) >= 0 else {
            throw _NSErrorWithErrno(errno, reading: true, path: srcPath,
                                    extraUserInfo: extraErrorInfo(srcPath: srcPath, dstPath: dstPath, userVariant: variant))
        }

        let srcfd = open(srcRep, O_RDONLY)
        guard srcfd >= 0 else {
            throw _NSErrorWithErrno(errno, reading: true, path: srcPath,
                                    extraUserInfo: extraErrorInfo(srcPath: srcPath, dstPath: dstPath, userVariant: variant))
        }
        defer { close(srcfd) }

        let dstfd = open(dstRep, O_WRONLY | O_CREAT | O_TRUNC, 0o666)
        guard dstfd >= 0 else {
            throw _NSErrorWithErrno(errno, reading: false, path: dstPath,
                                    extraUserInfo: extraErrorInfo(srcPath: srcPath, dstPath: dstPath, userVariant: variant))
        }
        defer { close(dstfd) }

        // Set the file permissions using fchmod() instead of when open()ing to avoid umask() issues
        let permissions = fileInfo.st_mode & ~S_IFMT
        guard fchmod(dstfd, permissions) == 0 else {
            throw _NSErrorWithErrno(errno, reading: false, path: dstPath,
                extraUserInfo: extraErrorInfo(srcPath: srcPath, dstPath: dstPath, userVariant: variant))
        }

        if fileInfo.st_size == 0 {
            // no copying required
            return
        }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(fileInfo.st_blksize))
        defer { buffer.deallocate() }

        // Casted to Int64 because fileInfo.st_size is 64 bits long even on 32 bit platforms
        var bytesRemaining = Int64(fileInfo.st_size)
        while bytesRemaining > 0 {
            let bytesToRead = min(bytesRemaining, Int64(fileInfo.st_blksize))
            let bytesRead = try _readFrom(fd: srcfd, toBuffer: buffer, length: Int(bytesToRead), filename: srcPath)
            if bytesRead == 0 {
                // Early EOF
                return
            }
            try _writeTo(fd: dstfd, fromBuffer: buffer, length: bytesRead, filename: dstPath)
            bytesRemaining -= Int64(bytesRead)
        }
#endif
    }

    private func _copySymlink(atPath srcPath: String, toPath dstPath: String, variant: String = "Copy") throws {
#if os(Windows)
        let faAttributes: WIN32_FILE_ATTRIBUTE_DATA = try windowsFileAttributes(atPath: srcPath)
        guard faAttributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) == DWORD(FILE_ATTRIBUTE_REPARSE_POINT) else {
          throw _NSErrorWithErrno(EINVAL, reading: true, path: srcPath, extraUserInfo: extraErrorInfo(srcPath: srcPath, dstPath: dstPath, userVariant: variant))
        }

        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: srcPath)

        var dwFlags: DWORD = DWORD(SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE)
        if try windowsFileAttributes(atPath: destination).dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) == DWORD(FILE_ATTRIBUTE_DIRECTORY) {
          dwFlags |= DWORD(SYMBOLIC_LINK_FLAG_DIRECTORY)
        }

        try FileManager.default.createSymbolicLink(atPath: dstPath, withDestinationPath: destination)
#else
        let bufSize = Int(PATH_MAX) + 1
        var buf = [Int8](repeating: 0, count: bufSize)

        try _fileSystemRepresentation(withPath: srcPath) { srcFsRep in
            let len = readlink(srcFsRep, &buf, bufSize)
            if len < 0 {
                throw _NSErrorWithErrno(errno, reading: true, path: srcPath,
                                        extraUserInfo: extraErrorInfo(srcPath: srcPath, dstPath: dstPath, userVariant: variant))
            }
            try _fileSystemRepresentation(withPath: dstPath) { dstFsRep in
                if symlink(buf, dstFsRep) == -1 {
                    throw _NSErrorWithErrno(errno, reading: false, path: dstPath,
                                            extraUserInfo: extraErrorInfo(srcPath: srcPath, dstPath: dstPath, userVariant: variant))
                }
            }
        }
#endif
    }
    
    private func _copyOrLinkDirectoryHelper(atPath srcPath: String, toPath dstPath: String, variant: String = "Copy", _ body: (String, String, FileAttributeType) throws -> ()) throws {
    #if os(Windows)
        var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = WIN32_FILE_ATTRIBUTE_DATA()
        do { faAttributes = try windowsFileAttributes(atPath: srcPath) } catch { return }

        var fileType = FileAttributeType(attributes: faAttributes)
        if fileType == .typeDirectory {
          try createDirectory(atPath: dstPath, withIntermediateDirectories: false, attributes: nil)
          guard let enumerator = enumerator(atPath: srcPath) else {
            throw _NSErrorWithErrno(ENOENT, reading: true, path: srcPath)
          }

          while let item = enumerator.nextObject() as? String {
            let src = joinPath(prefix: srcPath, suffix: item)
            let dst = joinPath(prefix: dstPath, suffix: item)

            do { faAttributes = try windowsFileAttributes(atPath: src) } catch { return }
            fileType = FileAttributeType(attributes: faAttributes)
            if fileType == .typeDirectory {
              try createDirectory(atPath: dst, withIntermediateDirectories: false, attributes: nil)
            } else {
              try body(src, dst, fileType)
            }
          }
        } else {
          try body(srcPath, dstPath, fileType)
        }
    #else
        guard let stat = try? _lstatFile(atPath: srcPath) else {
                return
        }

        let fileType = FileAttributeType(statMode: stat.st_mode)
        if fileType == .typeDirectory {
            try createDirectory(atPath: dstPath, withIntermediateDirectories: false, attributes: nil)

            guard let enumerator = enumerator(atPath: srcPath) else {
                throw _NSErrorWithErrno(ENOENT, reading: true, path: srcPath)
            }

            while let item = enumerator.nextObject() as? String {
                let src = srcPath + "/" + item
                let dst = dstPath + "/" + item
                if let stat = try? _lstatFile(atPath: src) {
                    let fileType = FileAttributeType(statMode: stat.st_mode)
                    if fileType == .typeDirectory {
                        try createDirectory(atPath: dst, withIntermediateDirectories: false, attributes: nil)
                    } else {
                        try body(src, dst, fileType)
                    }
                }
            }
        } else {
            try body(srcPath, dstPath, fileType)
        }
    #endif
    }
    
    private func shouldProceedAfterError(_ error: Error, copyingItemAtPath path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return false }
        if isURL {
            return delegate.fileManager(self, shouldProceedAfterError: error, copyingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldProceedAfterError: error, copyingItemAtPath: path, toPath: toPath)
        }
    }
    
    private func shouldCopyItemAtPath(_ path: String, toPath: String, isURL: Bool) -> Bool {
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
    
    private func shouldProceedAfterError(_ error: Error, movingItemAtPath path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return false }
        if isURL {
            return delegate.fileManager(self, shouldProceedAfterError: error, movingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldProceedAfterError: error, movingItemAtPath: path, toPath: toPath)
        }
    }
    
    private func shouldMoveItemAtPath(_ path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return true }
        if isURL {
            return delegate.fileManager(self, shouldMoveItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldMoveItemAtPath: path, toPath: toPath)
        }
    }
    
    private func _moveItem(atPath srcPath: String, toPath dstPath: String, isURL: Bool) throws {
        guard shouldMoveItemAtPath(srcPath, toPath: dstPath, isURL: isURL) else {
            return
        }
        
        guard !self.fileExists(atPath: dstPath) else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteFileExists.rawValue, userInfo: [NSFilePathErrorKey : NSString(dstPath)])
        }

#if os(Windows)
        try srcPath.withCString(encodedAs: UTF16.self) { src in
          try dstPath.withCString(encodedAs: UTF16.self) { dst in
            if MoveFileExW(src, dst, DWORD(MOVEFILE_COPY_ALLOWED | MOVEFILE_WRITE_THROUGH)) == FALSE {
              throw _NSErrorWithWindowsError(GetLastError(), reading: false)
            }
          }
        }
#else
        try _fileSystemRepresentation(withPath: srcPath, andPath: dstPath, {
            if rename($0, $1) != 0 {
                if errno == EXDEV {
                    try _copyOrLinkDirectoryHelper(atPath: srcPath, toPath: dstPath, variant: "Move") { (srcPath, dstPath, fileType) in
                        do {
                            switch fileType {
                            case .typeRegular:
                                try _copyRegularFile(atPath: srcPath, toPath: dstPath, variant: "Move")
                            case .typeSymbolicLink:
                                try _copySymlink(atPath: srcPath, toPath: dstPath, variant: "Move")
                            default:
                                break
                            }
                        } catch {
                            if !shouldProceedAfterError(error, movingItemAtPath: srcPath, toPath: dstPath, isURL: isURL) {
                                throw error
                            }
                        }
                    }
                    
                    // Remove source directory/file after successful moving
                    try _removeItem(atPath: srcPath, isURL: isURL, alreadyConfirmed: true)
                } else {
                    throw _NSErrorWithErrno(errno, reading: false, path: srcPath,
                                            extraUserInfo: extraErrorInfo(srcPath: srcPath, dstPath: dstPath, userVariant: "Move"))
                }
            }
        })
#endif
    }
    
    private func shouldProceedAfterError(_ error: Error, linkingItemAtPath path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return false }
        if isURL {
            return delegate.fileManager(self, shouldProceedAfterError: error, linkingItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldProceedAfterError: error, linkingItemAtPath: path, toPath: toPath)
        }
    }
    
    private func shouldLinkItemAtPath(_ path: String, toPath: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return true }
        if isURL {
            return delegate.fileManager(self, shouldLinkItemAt: URL(fileURLWithPath: path), to: URL(fileURLWithPath: toPath))
        } else {
            return delegate.fileManager(self, shouldLinkItemAtPath: path, toPath: toPath)
        }
    }
    
    private func _linkItem(atPath srcPath: String, toPath dstPath: String, isURL: Bool) throws {
        try _copyOrLinkDirectoryHelper(atPath: srcPath, toPath: dstPath) { (srcPath, dstPath, fileType) in
            guard shouldLinkItemAtPath(srcPath, toPath: dstPath, isURL: isURL) else {
                return
            }
            
            do {
                switch fileType {
                case .typeRegular:
#if os(Windows)
                    try srcPath.withCString(encodedAs: UTF16.self) { src in
                      try dstPath.withCString(encodedAs: UTF16.self) { dst in
                        if CreateHardLinkW(src, dst, nil) == FALSE {
                          throw _NSErrorWithWindowsError(GetLastError(), reading: false)
                        }
                      }
                    }
#else
                    try _fileSystemRepresentation(withPath: srcPath, andPath: dstPath, {
                        if link($0, $1) == -1 {
                            throw _NSErrorWithErrno(errno, reading: false, path: srcPath)
                        }
                    })
#endif
                case .typeSymbolicLink:
                    try _copySymlink(atPath: srcPath, toPath: dstPath)
                default:
                    break
                }
            } catch {
                if !shouldProceedAfterError(error, linkingItemAtPath: srcPath, toPath: dstPath, isURL: isURL) {
                    throw error
                }
            }
        }
    }
    
    private func shouldProceedAfterError(_ error: Error, removingItemAtPath path: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return false }
        if isURL {
            return delegate.fileManager(self, shouldProceedAfterError: error, removingItemAt: URL(fileURLWithPath: path))
        } else {
            return delegate.fileManager(self, shouldProceedAfterError: error, removingItemAtPath: path)
        }
    }
    
    private func shouldRemoveItemAtPath(_ path: String, isURL: Bool) -> Bool {
        guard let delegate = self.delegate else { return true }
        if isURL {
            return delegate.fileManager(self, shouldRemoveItemAt: URL(fileURLWithPath: path))
        } else {
            return delegate.fileManager(self, shouldRemoveItemAtPath: path)
        }
    }

    private func _removeItem(atPath path: String, isURL: Bool, alreadyConfirmed: Bool = false) throws {
        guard alreadyConfirmed || shouldRemoveItemAtPath(path, isURL: isURL) else {
            return
        }

        var isDir: ObjCBool = false
        let _ = fileExists(atPath: path, isDirectory: &isDir)
        if isDir.boolValue {
            let stream =  NSURLDirectoryEnumerator(
              url: URL(fileURLWithPath: path),
              options: [],
              errorHandler: {(url, err) in
                self.shouldProceedAfterError(err,
                                             removingItemAtPath: url.absoluteString,
                                             isURL: true)
              })
            while let itemPath = stream.nextObject() as? String {
              do {
                guard alreadyConfirmed || shouldRemoveItemAtPath(itemPath, isURL: true) else {
                  continue
                }
                let _ = fileExists(atPath: itemPath, isDirectory: &isDir)
                if isDir.boolValue {
                  if rmdir(itemPath) == -1 {
                    throw _NSErrorWithErrno(errno, reading: false, path: itemPath)
                  }
                } else {
                  if unlink(itemPath) == -1 {
                    throw _NSErrorWithErrno(errno, reading: false, path: itemPath)
                  }
                }
              } catch {
                if !shouldProceedAfterError(error, removingItemAtPath: itemPath, isURL: true) {
                  throw error
                }
              }
            }
        } else if _fileSystemRepresentation(withPath: path, { unlink($0) != 0 }) {
            throw _NSErrorWithErrno(errno, reading: false, path: path)
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
#if os(Windows)
        let dwLength: DWORD = GetCurrentDirectoryW(0, nil)
        var szDirectory: UnsafeMutableBufferPointer<WCHAR> = UnsafeMutableBufferPointer.allocate(capacity: Int(dwLength + 1))
        defer { szDirectory.deallocate() }

        GetCurrentDirectoryW(dwLength, szDirectory.baseAddress)
        return String(decodingCString: szDirectory.baseAddress!, as: UTF16.self)
#else
        let length = Int(PATH_MAX) + 1
        var buf = [Int8](repeating: 0, count: length)
        getcwd(&buf, length)
        return string(withFileSystemRepresentation: buf, length: Int(strlen(buf)))
#endif
    }
    
    @discardableResult
    open func changeCurrentDirectoryPath(_ path: String) -> Bool {
#if os(Windows)
        return path.withCString(encodedAs: UTF16.self) { SetCurrentDirectoryW($0) != FALSE }
#else
        return _fileSystemRepresentation(withPath: path, { chdir($0) == 0 })
#endif
    }
    
    /* The following methods are of limited utility. Attempting to predicate behavior based on the current state of the filesystem or a particular file on the filesystem is encouraging odd behavior in the face of filesystem race conditions. It's far better to attempt an operation (like loading a file or creating a directory) and handle the error gracefully than it is to try to figure out ahead of time whether the operation will succeed.
     */
    open func fileExists(atPath path: String) -> Bool {
        return self.fileExists(atPath: path, isDirectory: nil)
    }
    
    open func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
#if os(Windows)
        var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = WIN32_FILE_ATTRIBUTE_DATA()
        do { faAttributes = try windowsFileAttributes(atPath: path) } catch { return false }
        if faAttributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) == DWORD(FILE_ATTRIBUTE_REPARSE_POINT) {
          do { try faAttributes = windowsFileAttributes(atPath: destinationOfSymbolicLink(atPath: path)) } catch { return false }
        }
        if let isDirectory = isDirectory {
          isDirectory.pointee = ObjCBool(faAttributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) == DWORD(FILE_ATTRIBUTE_DIRECTORY))
        }
        return true
#else
        return _fileSystemRepresentation(withPath: path, { fsRep in
            guard var s = try? _lstatFile(atPath: path, withFileSystemRepresentation: fsRep) else {
                return false
            }

            if (s.st_mode & S_IFMT) == S_IFLNK {
                // don't chase the link for this magic case -- we might be /Net/foo
                // which is a symlink to /private/Net/foo which is not yet mounted...
                if isDirectory == nil && (s.st_mode & S_ISVTX) == S_ISVTX {
                    return true
                }
                // chase the link; too bad if it is a slink to /Net/foo
                guard stat(fsRep, &s) >= 0 else {
                    return false
                }
            }

            if let isDirectory = isDirectory {
                isDirectory.pointee = ObjCBool((s.st_mode & S_IFMT) == S_IFDIR)
            }

            return true
        })
#endif
    }
    
    open func isReadableFile(atPath path: String) -> Bool {
#if os(Windows)
        do { let _ = try windowsFileAttributes(atPath: path) } catch { return false }
        return true
#else
        return _fileSystemRepresentation(withPath: path, {
            access($0, R_OK) == 0
        })
#endif
    }
    
    open func isWritableFile(atPath path: String) -> Bool {
#if os(Windows)
        guard let faAttributes: WIN32_FILE_ATTRIBUTE_DATA = try? windowsFileAttributes(atPath: path) else { return false }
        return faAttributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_READONLY) != DWORD(FILE_ATTRIBUTE_READONLY)
#else
        return _fileSystemRepresentation(withPath: path, {
            access($0, W_OK) == 0
        })
#endif
    }
    
    open func isExecutableFile(atPath path: String) -> Bool {
#if os(Windows)
        // FIXME(compnerd) is there some test that we can perform here?
        return true
#else
        return _fileSystemRepresentation(withPath: path, {
            access($0, X_OK) == 0
        })
#endif
    }

    /**
     - parameters:
        - path: The path to the file we are trying to determine is deletable.

      - returns: `true` if the file is deletable, `false` otherwise.
     */
    open func isDeletableFile(atPath path: String) -> Bool {
        // Get the parent directory of supplied path
        let parent = path._nsObject.deletingLastPathComponent

#if os(Windows)
        var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = WIN32_FILE_ATTRIBUTE_DATA()
        do { faAttributes = try windowsFileAttributes(atPath: parent) } catch { return false }
        if faAttributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_READONLY) == DWORD(FILE_ATTRIBUTE_READONLY) {
          return false
        }

        do { faAttributes = try windowsFileAttributes(atPath: path) } catch { return false }
        if faAttributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_READONLY) == DWORD(FILE_ATTRIBUTE_READONLY) {
          return false
        }

        return true
#else
        return _fileSystemRepresentation(withPath: parent, andPath: path, { parentFsRep, fsRep  in
            // Check the parent directory is writeable, else return false.
            guard access(parentFsRep, W_OK) == 0 else {
                return false
            }

            // Stat the parent directory, if that fails, return false.
            guard let parentS = try? _lstatFile(atPath: path, withFileSystemRepresentation: parentFsRep) else {
                return false
            }

            // Check if the parent is 'sticky' if it exists.
            if (parentS.st_mode & S_ISVTX) == S_ISVTX {
                guard let s = try? _lstatFile(atPath: path, withFileSystemRepresentation: fsRep) else {
                    return false
                }

                // If the current user owns the file, return true.
                return s.st_uid == getuid()
            }

            // Return true as the best guess.
            return true
        })
#endif
    }

    private func _compareFiles(withFileSystemRepresentation file1Rep: UnsafePointer<Int8>, andFileSystemRepresentation file2Rep: UnsafePointer<Int8>, size: Int64, bufSize: Int) -> Bool {
#if os(Windows)
        NSUnimplemented()
#else
        let fd1 = open(file1Rep, O_RDONLY)
        guard fd1 >= 0 else {
            return false
        }
        defer { close(fd1) }

        let fd2 = open(file2Rep, O_RDONLY)
        guard fd2 >= 0 else {
            return false
        }
        defer { close(fd2) }

        let buffer1 = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        let buffer2 = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer {
            buffer1.deallocate()
            buffer2.deallocate()
        }

        var bytesLeft = size
        while bytesLeft > 0 {
            let bytesToRead = Int(min(Int64(bufSize), bytesLeft))
            guard read(fd1, buffer1, bytesToRead) == bytesToRead else {
                return false
            }
            guard read(fd2, buffer2, bytesToRead) == bytesToRead else {
                return false
            }
            guard memcmp(buffer1, buffer2, bytesToRead) == 0 else {
                return false
            }
            bytesLeft -= Int64(bytesToRead)
        }
        return true
#endif
    }

#if !os(Windows)
    private func _compareSymlinks(withFileSystemRepresentation file1Rep: UnsafePointer<Int8>, andFileSystemRepresentation file2Rep: UnsafePointer<Int8>, size: Int64) -> Bool {
        let bufSize = Int(size)
        let buffer1 = UnsafeMutablePointer<CChar>.allocate(capacity: bufSize)
        let buffer2 = UnsafeMutablePointer<CChar>.allocate(capacity: bufSize)

        let size1 = readlink(file1Rep, buffer1, bufSize)
        let size2 = readlink(file2Rep, buffer2, bufSize)

        let compare: Bool
        if size1 < 0 || size2 < 0 || size1 != size || size1 != size2 {
            compare = false
        } else {
            compare = memcmp(buffer1, buffer2, size1) == 0
        }

        buffer1.deallocate()
        buffer2.deallocate()
        return compare
    }
#endif

    private func _compareDirectories(atPath path1: String, andPath path2: String) -> Bool {
        guard let enumerator1 = enumerator(atPath: path1) else {
            return false
        }

        guard let enumerator2 = enumerator(atPath: path2) else {
            return false
        }

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

#if !os(Windows)
    private func _lstatFile(atPath path: String, withFileSystemRepresentation fsRep: UnsafePointer<Int8>? = nil) throws -> stat {
        let _fsRep: UnsafePointer<Int8>
        if fsRep == nil {
            _fsRep = fileSystemRepresentation(withPath: path)
        } else {
            _fsRep = fsRep!
        }

        defer {
            if fsRep == nil { _fsRep.deallocate() }
        }

        var statInfo = stat()
        guard lstat(_fsRep, &statInfo) == 0 else {
            throw _NSErrorWithErrno(errno, reading: true, path: path)
        }
        return statInfo
    }
#endif

    @available(Windows, deprecated, message: "Not Yet Implemented")
    internal func _permissionsOfItem(atPath path: String) throws -> Int {
#if os(Windows)
        NSUnimplemented()
#else
        let fileInfo = try _lstatFile(atPath: path)
        return Int(fileInfo.st_mode & ~S_IFMT)
#endif
    }


#if os(Linux)
    // statx() is only supported by Linux kernels >= 4.11.0
    private lazy var supportsStatx: Bool = {
        let requiredVersion = OperatingSystemVersion(majorVersion: 4, minorVersion: 11, patchVersion: 0)
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(requiredVersion)
    }()

    // This is only used on Linux and the only extra information it returns in addition
    // to a normal stat() call is the file creation date (stx_btime). It is only
    // used by attributesOfItem(atPath:) which is why the return is a simple stat()
    // structure and optional creation date.

    private func _statxFile(atPath path: String) throws -> (stat, Date?) {
        let fsRep = fileSystemRepresentation(withPath: path)
        defer { fsRep.deallocate() }

        if supportsStatx {
            var statInfo = stat()
            var btime = timespec()
            guard _stat_with_btime(fsRep, &statInfo, &btime) == 0 else {
                throw _NSErrorWithErrno(errno, reading: true, path: path)
            }

            let sec = btime.tv_sec
            let nsec = btime.tv_nsec
            let creationDate: Date?
            if sec == 0 && nsec == 0 {
                creationDate = nil
            } else {
                let ti = (TimeInterval(sec) - kCFAbsoluteTimeIntervalSince1970) + (1.0e-9 * TimeInterval(nsec))
                creationDate = Date(timeIntervalSinceReferenceDate: ti)
            }
            return (statInfo, creationDate)
        } else {
            // fallback if statx() is unavailable or fails
            let statInfo = try _lstatFile(atPath: path, withFileSystemRepresentation: fsRep)
            return (statInfo, nil)
        }
    }
#endif

    /* -contentsEqualAtPath:andPath: does not take into account data stored in the resource fork or filesystem extended attributes.
     */
    @available(Windows, deprecated, message: "Not Yet Implemented")
    open func contentsEqual(atPath path1: String, andPath path2: String) -> Bool {
#if os(Windows)
        NSUnimplemented()
#else
        let fsRep1 = fileSystemRepresentation(withPath: path1)
        defer { fsRep1.deallocate() }

        guard let file1 = try? _lstatFile(atPath: path1, withFileSystemRepresentation: fsRep1) else {
            return false
        }
        let file1Type = file1.st_mode & S_IFMT

        // Dont use access() for symlinks as only the contents should be checked even
        // if the symlink doesnt point to an actual file, but access() will always try
        // to resolve the link and fail if the destination is not found
        if path1 == path2 && file1Type != S_IFLNK {
            return access(fsRep1, R_OK) == 0
        }

        let fsRep2 = fileSystemRepresentation(withPath: path2)
        defer { fsRep2.deallocate() }
        guard let file2 = try? _lstatFile(atPath: path2, withFileSystemRepresentation: fsRep2) else {
            return false
        }
        let file2Type = file2.st_mode & S_IFMT

        // Are paths the same type: file, directory, symbolic link etc.
        guard file1Type == file2Type else {
            return false
        }

        if file1Type == S_IFCHR || file1Type == S_IFBLK {
            // For character devices, just check the major/minor pair is the same.
            return _dev_major(file1.st_rdev) == _dev_major(file2.st_rdev)
                && _dev_minor(file1.st_rdev) == _dev_minor(file2.st_rdev)
        }

        // If both paths point to the same device/inode or they are both zero length
        // then they are considered equal so just check readability.
        if (file1.st_dev == file2.st_dev && file1.st_ino == file2.st_ino)
            || (file1.st_size == 0 && file2.st_size == 0) {
            return access(fsRep1, R_OK) == 0 && access(fsRep2, R_OK) == 0
        }

        if file1Type == S_IFREG {
            // Regular files and symlinks should at least have the same filesize if contents are equal.
            guard file1.st_size == file2.st_size else {
                return false
            }
            return _compareFiles(withFileSystemRepresentation: path1, andFileSystemRepresentation: path2, size: Int64(file1.st_size), bufSize: Int(file1.st_blksize))
        }
        else if file1Type == S_IFLNK {
            return _compareSymlinks(withFileSystemRepresentation: fsRep1, andFileSystemRepresentation: fsRep2, size: Int64(file1.st_size))
        }
        else if file1Type == S_IFDIR {
            return _compareDirectories(atPath: path1, andPath: path2)
        }

        // Dont know how to compare other file types.
        return false
#endif
    }
    
    /* displayNameAtPath: returns an NSString suitable for presentation to the user. For directories which have localization information, this will return the appropriate localized string. This string is not suitable for passing to anything that must interact with the filesystem.
     */
    open func displayName(atPath path: String) -> String {
        NSUnimplemented()
    }
    
    /* componentsToDisplayForPath: returns an NSArray of display names for the path provided. Localization will occur as in displayNameAtPath: above. This array cannot and should not be reassembled into an usable filesystem path for any kind of access.
     */
    open func componentsToDisplay(forPath path: String) -> [String]? {
        NSUnimplemented()
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
        let len = CFStringGetMaximumSizeOfFileSystemRepresentation(path._cfObject)
        if len == kCFNotFound {
            fatalError("string could not be converted")
        }
        let buf = UnsafeMutablePointer<Int8>.allocate(capacity: len)
        buf.initialize(repeating: 0, count: len)
        if !path._nsObject.getFileSystemRepresentation(buf, maxLength: len) {
            buf.deinitialize(count: len)
            buf.deallocate()
            fatalError("string could not be converted")
        }
        return UnsafePointer(buf)
    }

    internal func _fileSystemRepresentation<ResultType>(withPath path: String, _ body: (UnsafePointer<Int8>) throws -> ResultType) rethrows -> ResultType {
        let fsRep = fileSystemRepresentation(withPath: path)
        defer { fsRep.deallocate() }
        return try body(fsRep)
    }

    internal func _fileSystemRepresentation<ResultType>(withPath path1: String, andPath path2: String, _ body: (UnsafePointer<Int8>, UnsafePointer<Int8>) throws -> ResultType) rethrows -> ResultType {

        let fsRep1 = fileSystemRepresentation(withPath: path1)
        let fsRep2 = fileSystemRepresentation(withPath: path2)
        defer {
            fsRep1.deallocate()
            fsRep2.deallocate()
        }
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
    open func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: ItemReplacementOptions = []) throws {
        NSUnimplemented()
    }
    
    internal func _tryToResolveTrailingSymlinkInPath(_ path: String) -> String? {
        // destinationOfSymbolicLink(atPath:) will fail if the path is not a symbolic link
        guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: path) else {
            return nil
        }
        
        return _appendSymlinkDestination(destination, toPath: path)
    }
    
    internal func _appendSymlinkDestination(_ dest: String, toPath: String) -> String {
    #if os(Windows)
      var isAbsolutePath: Bool = false
      dest.withCString(encodedAs: UTF16.self) {
        isAbsolutePath = PathIsRelativeW($0) == FALSE
      }
    #else
      let isAbsolutePath: Bool = dest.hasPrefix("/")
    #endif

        if isAbsolutePath {
            return dest
        }
        let temp = toPath._bridgeToObjectiveC().deletingLastPathComponent
        return temp._bridgeToObjectiveC().appendingPathComponent(dest)
    }
}

extension FileManager {
    public func replaceItemAt(_ originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String? = nil, options: ItemReplacementOptions = []) throws -> NSURL? {
        NSUnimplemented()
    }
}

extension FileManager {
    open var homeDirectoryForCurrentUser: URL {
        return homeDirectory(forUser: NSUserName())!
    }
    
    open var temporaryDirectory: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
    }
    
    open func homeDirectory(forUser userName: String) -> URL? {
        guard !userName.isEmpty else { return nil }
        guard let url = CFCopyHomeDirectoryURLForUser(userName._cfObject) else { return nil }
        return  url.takeRetainedValue()._swiftObject
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
    
    public var hashValue: Int {
        return self.rawValue.hashValue
    }
    
    public static func ==(_ lhs: FileAttributeKey, _ rhs: FileAttributeKey) -> Bool {
        return lhs.rawValue == rhs.rawValue
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
}

public struct FileAttributeType : RawRepresentable, Equatable, Hashable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var hashValue: Int {
        return self.rawValue.hashValue
    }

    public static func ==(_ lhs: FileAttributeType, _ rhs: FileAttributeType) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

#if os(Windows)
    fileprivate init(attributes: WIN32_FILE_ATTRIBUTE_DATA) {
      if attributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) == DWORD(FILE_ATTRIBUTE_DIRECTORY) {
        self = .typeDirectory
      } else if attributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_DEVICE) == DWORD(FILE_ATTRIBUTE_DEVICE) {
        self = .typeCharacterSpecial
      } else if attributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_REPARSE_POINT) == DWORD(FILE_ATTRIBUTE_REPARSE_POINT) {
        // FIXME(compnerd) this is a lie!  It may be a junction or a hard link
        self = .typeSymbolicLink
      } else if attributes.dwFileAttributes & DWORD(FILE_ATTRIBUTE_NORMAL) == DWORD(FILE_ATTRIBUTE_NORMAL) {
        self = .typeRegular
      } else {
        self = .typeUnknown
      }
    }
#else
    fileprivate init(statMode: mode_t) {
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
        private var _currentItemPath: String?

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
            let url = URL(fileURLWithPath: path)
            self.baseURL = url
            guard let ie = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [], errorHandler: nil) else {
                return nil
            }
            self.innerEnumerator = ie
        }
        
        override func nextObject() -> Any? {
            let o = innerEnumerator.nextObject()
            guard let url = o as? URL else {
                return nil
            }

#if os(Windows)
            var relativePath = UnsafeMutableBufferPointer<WCHAR>.allocate(capacity: Int(MAX_PATH))
            defer { relativePath.deallocate() }
            func withURLCString<Result>(url: URL, _ f: (UnsafePointer<WCHAR>) -> Result?) -> Result? {
                return url.withUnsafeFileSystemRepresentation { fsr in
                    (fsr.flatMap { String(utf8String: $0) })?.withCString(encodedAs: UTF16.self) { f($0) }
                }
            }
            let result = withURLCString(url: baseURL) { pszFrom -> BOOL? in
                withURLCString(url: url) { pszTo in
                    let fromAttrs = GetFileAttributesW(pszFrom)
                    let toAttrs = GetFileAttributesW(pszTo)
                    guard fromAttrs != INVALID_FILE_ATTRIBUTES, toAttrs != INVALID_FILE_ATTRIBUTES else {
                        return FALSE
                    }
                    return PathRelativePathToW(relativePath.baseAddress, pszFrom, fromAttrs, pszTo, toAttrs)
                }
            }

            guard result == TRUE, let (path, _) = String.decodeCString(relativePath.baseAddress, as: UTF16.self) else {
                return nil
            }
#else
            let path = url.path.replacingOccurrences(of: baseURL.path+"/", with: "")
#endif
            _currentItemPath = path
            return _currentItemPath
        }
    }

    internal class NSURLDirectoryEnumerator : DirectoryEnumerator {
#if os(Windows)
        var _options : FileManager.DirectoryEnumerationOptions
        var _errorHandler : ((URL, Error) -> Bool)?
        var _stack: [URL]
        var _current: URL?
        var _rootDepth : Int

        init(url: URL, options: FileManager.DirectoryEnumerationOptions, errorHandler: (/* @escaping */ (URL, Error) -> Bool)?) {
            _options = options
            _errorHandler = errorHandler
            _stack = [url]
            _rootDepth = url.pathComponents.count
        }

        override func nextObject() -> Any? {
            func contentsOfDir(directory: URL) -> [URL]? {
                var ffd: WIN32_FIND_DATAW = WIN32_FIND_DATAW()
                guard let dirFSR = directory.withUnsafeFileSystemRepresentation({ $0.flatMap { fsr in String(utf8String: fsr) } })
                else { return nil }
                let dirPath = joinPath(prefix: dirFSR, suffix: "*")
                let h: HANDLE = dirPath.withCString(encodedAs: UTF16.self) {
                  FindFirstFileW($0, &ffd)
                }
                guard h != INVALID_HANDLE_VALUE else { return nil }
                defer { FindClose(h) }

                var files: [URL] = []
                repeat {
                    let fileArr = Array<WCHAR>(
                      UnsafeBufferPointer(start: &ffd.cFileName.0,
                                          count: MemoryLayout.size(ofValue: ffd.cFileName)))
                    let file = String(decodingCString: fileArr, as: UTF16.self)
                    if file != "."
                        && file != ".."
                        && (!_options.contains(.skipsHiddenFiles)
                            || (ffd.dwFileAttributes & DWORD(FILE_ATTRIBUTE_HIDDEN) == 0)) {
                        files.append(URL(fileURLWithPath: joinPath(prefix: dirFSR, suffix: file)))
                      }
                } while(FindNextFileW(h, &ffd) != 0)
                return files
            }
            while let url = _stack.popLast() {
                if url.hasDirectoryPath && !_options.contains(.skipsSubdirectoryDescendants) {
                    guard let dirContents = contentsOfDir(directory: url)?.reversed() else {
                        if let handler = _errorHandler {
                           let dirFSR = url.withUnsafeFileSystemRepresentation { $0.flatMap { fsr in String(utf8String: fsr) } }
                           let keepGoing = handler(URL(fileURLWithPath: dirFSR ?? ""),
                               _NSErrorWithWindowsError(GetLastError(), reading: true))
                           if !keepGoing { return nil }
                        }
                        continue
                    }
                    _stack.append(contentsOf: dirContents)
                }
                _current = url
                return url
            }
            return nil
        }

        override var level: Int {
            return _rootDepth - (_current?.pathComponents.count ?? _rootDepth)
        }

        override func skipDescendants() {
            _options.insert(.skipsSubdirectoryDescendants)
        }
#else
        var _url : URL
        var _options : FileManager.DirectoryEnumerationOptions
        var _errorHandler : ((URL, Error) -> Bool)?
        var _stream : UnsafeMutablePointer<FTS>? = nil
        var _current : UnsafeMutablePointer<FTSENT>? = nil
        var _rootError : Error? = nil
        var _gotRoot : Bool = false


        // See @escaping comments above.
        init(url: URL, options: FileManager.DirectoryEnumerationOptions, errorHandler: (/* @escaping */ (URL, Error) -> Bool)?) {
            _url = url
            _options = options
            _errorHandler = errorHandler

            if FileManager.default.fileExists(atPath: _url.path) {
                let fsRep = FileManager.default.fileSystemRepresentation(withPath: _url.path)
                let ps = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: 2)
                ps.initialize(to: UnsafeMutablePointer(mutating: fsRep))
                ps.advanced(by: 1).initialize(to: nil)
                _stream = fts_open(ps, FTS_PHYSICAL | FTS_XDEV | FTS_NOCHDIR, nil)
                ps.deinitialize(count: 2)
                ps.deallocate()
                fsRep.deallocate()
            } else {
                _rootError = _NSErrorWithErrno(ENOENT, reading: true, url: url)
            }
        }

        deinit {
            if let stream = _stream {
                fts_close(stream)
            }
        }


        override func nextObject() -> Any? {
            func match(filename: String, to options: DirectoryEnumerationOptions, isDir: Bool) -> (Bool, Bool) {
                var showFile = true
                var skipDescendants = false

                if isDir {
                    if options.contains(.skipsSubdirectoryDescendants) {
                        skipDescendants = true
                    }
                    // Ignore .skipsPackageDescendants
                }
                if options.contains(.skipsHiddenFiles) && (filename[filename._startOfLastPathComponent] == ".") {
                    showFile = false
                    skipDescendants = true
                }

                return (showFile, skipDescendants)
            }


            if let stream = _stream {

                if !_gotRoot  {
                    _gotRoot = true

                    // Skip the root.
                    _current = fts_read(stream)
                }

                _current = fts_read(stream)
                while let current = _current {
                    let filename = FileManager.default.string(withFileSystemRepresentation: current.pointee.fts_path, length: Int(current.pointee.fts_pathlen))

                    switch Int32(current.pointee.fts_info) {
                        case FTS_D:
                            let (showFile, skipDescendants) = match(filename: filename, to: _options, isDir: true)
                            if skipDescendants {
                                fts_set(_stream, _current, FTS_SKIP)
                            }
                            if showFile {
                                 return URL(fileURLWithPath: filename)
                            }

                        case FTS_DEFAULT, FTS_F, FTS_NSOK, FTS_SL, FTS_SLNONE:
                            let (showFile, _) = match(filename: filename, to: _options, isDir: false)
                            if showFile {
                                return URL(fileURLWithPath: filename)
                            }
                        case FTS_DNR, FTS_ERR, FTS_NS:
                            let keepGoing: Bool
                            if let handler = _errorHandler {
                                keepGoing = handler(URL(fileURLWithPath: filename), _NSErrorWithErrno(current.pointee.fts_errno, reading: true))
                            } else {
                                keepGoing = true
                            }
                            if !keepGoing {
                                fts_close(stream)
                                _stream = nil
                                return nil
                            }
                        default:
                            break
                    }
                    _current = fts_read(stream)
                }
                // TODO: Error handling if fts_read fails.

            } else if let error = _rootError {
                // Was there an error opening the stream?
                if let handler = _errorHandler {
                    let _ = handler(_url, error)
                }
            }
            return nil
        }
        override var level: Int {
            return Int(_current?.pointee.fts_level ?? 0)
        }

        override func skipDescendants() {
            if let stream = _stream, let current = _current {
                fts_set(stream, current, FTS_SKIP)
            }
        }
#endif
        override var directoryAttributes : [FileAttributeKey : Any]? {
            return nil
        }
        override var fileAttributes: [FileAttributeKey : Any]? {
            return nil
        }
    }
}
