//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
#if !os(Windows)

#if os(Android) && (arch(i386) || arch(arm)) // struct stat.st_mode is UInt32
internal func &(left: UInt32, right: mode_t) -> mode_t {
    return mode_t(left) & right
}
#endif

#if os(WASI)
import WASILibc
// wasi-libc defines the following constants in a way that Clang Importer can't
// understand, so we need to grab them manually through ForSwiftFoundationOnly.h
internal var DT_DIR: UInt8 { _getConst_DT_DIR() }
internal var O_CREAT: Int32 { _getConst_O_CREAT() }
internal var O_DIRECTORY: Int32 { _getConst_O_DIRECTORY() }
internal var O_EXCL: Int32 { _getConst_O_EXCL() }
internal var O_TRUNC: Int32 { _getConst_O_TRUNC() }
internal var O_WRONLY: Int32 { _getConst_O_WRONLY() }
#endif

@_implementationOnly import CoreFoundation

extension FileManager {
    internal func _mountedVolumeURLs(includingResourceValuesForKeys propertyKeys: [URLResourceKey]?, options: VolumeEnumerationOptions = []) -> [URL]? {
        var urls: [URL] = []

#if os(Linux) || os(Android)
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

        if #available(macOS 10.13, *) {
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
#elseif os(OpenBSD)
        func mountPoints(_ statBufs: UnsafePointer<statfs>, _ fsCount: Int) -> [URL] {
            var urls: [URL] = []

            for fsIndex in 0..<fsCount {
                var fs = statBufs.advanced(by: fsIndex).pointee

                let mountPoint = withUnsafePointer(to: &fs.f_mntonname.0) { (ptr: UnsafePointer<Int8>) -> String in
                    return string(withFileSystemRepresentation: ptr, length: strlen(ptr))
                }
                urls.append(URL(fileURLWithPath: mountPoint, isDirectory: true))
            }
            return urls
        }

            var fsCount = getfsstat(nil, 0, MNT_WAIT)
            guard fsCount > 0 else {
                return nil
            }
            let statBuf = UnsafeMutablePointer<statfs>.allocate(capacity: Int(fsCount))
            defer { statBuf.deallocate() }
            fsCount = getfsstat(statBuf, Int(fsCount) * MemoryLayout<statfs>.stride, MNT_WAIT)
            guard fsCount > 0 else {
                return nil
            }
            urls = mountPoints(statBuf, Int(fsCount))
#elseif os(WASI)
        // Skip the first three file descriptors, which are reserved for stdin, stdout, and stderr.
        var fd: __wasi_fd_t = 3
        let __WASI_PREOPENTYPE_DIR: UInt8 = 0
        while true {
            var prestat = __wasi_prestat_t()
            guard __wasi_fd_prestat_get(fd, &prestat) == 0 else {
                break
            }

            if prestat.tag == __WASI_PREOPENTYPE_DIR {
                var buf = [UInt8](repeating: 0, count: Int(prestat.u.dir.pr_name_len))
                guard __wasi_fd_prestat_dir_name(fd, &buf, prestat.u.dir.pr_name_len) == 0 else {
                    break
                }
                let path = buf.withUnsafeBufferPointer { buf in
                  guard let baseAddress = buf.baseAddress else {
                    return ""
                  }
                  let base = UnsafeRawPointer(baseAddress).assumingMemoryBound(to: Int8.self)
                  return string(withFileSystemRepresentation: base, length: buf.count)
                }
                urls.append(URL(fileURLWithPath: path, isDirectory: true))
            }
            fd += 1
        }
#else
#error("Requires a platform-specific implementation")
#endif
        return urls
    }

    internal func darwinPathURLs(for domain: _SearchPathDomain, system: String?, local: String?, network: String?, userHomeSubpath: String?) -> [URL] {
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

    internal func darwinPathURLs(for domain: _SearchPathDomain, all: String, useLocalDirectoryForSystem: Bool = false) -> [URL] {
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

    internal func _urls(for directory: SearchPathDirectory, in domainMask: SearchPathDomainMask) -> [URL] {
        let domains = _SearchPathDomain.allInSearchOrder(from: domainMask)

        var urls: [URL] = []

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

        return urls
    }

    internal func xdgURLs(for directory: SearchPathDirectory, in domain: _SearchPathDomain) -> [URL] {
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

    internal func darwinURLs(for directory: SearchPathDirectory, in domain: _SearchPathDomain) -> [URL] {
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

    internal func _createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = [:]) throws {
        try _fileSystemRepresentation(withPath: path, { pathFsRep in
            if createIntermediates {
                var isDir: ObjCBool = false
                if !fileExists(atPath: path, isDirectory: &isDir) {
                    let parent = path._nsObject.deletingLastPathComponent
                    if !parent.isEmpty && !fileExists(atPath: parent, isDirectory: &isDir) {
                        try createDirectory(atPath: parent, withIntermediateDirectories: true, attributes: attributes)
                    }
                    if mkdir(pathFsRep, S_IRWXU | S_IRWXG | S_IRWXO) != 0 {
                        let posixError = errno
                        if posixError == EEXIST && fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue {
                            // Continue; if there is an existing file and it is a directory, that is still a success.
                            // There can be an existing file if another thread or process concurrently creates the
                            // same file.
                        } else {
                            throw _NSErrorWithErrno(posixError, reading: false, path: path)
                        }
                    }
                    if let attr = attributes {
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
    }

    internal func _contentsOfDir(atPath path: String, _ closure: (String, Int32) throws -> () ) throws {
        try _fileSystemRepresentation(withPath: path) { fsRep in
            guard let dir = opendir(fsRep) else {
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadNoSuchFile.rawValue,
                              userInfo: [NSFilePathErrorKey: path, "NSUserStringVariant": NSArray(object: "Folder")])
            }
            defer { closedir(dir) }

            // readdir returns NULL on EOF and error so set errno to 0 to check for errors
            errno = 0
            while let entry = readdir(dir) {
                let length = Int(_direntNameLength(entry))
                let namePtr = UnsafeRawPointer(_direntName(entry)).assumingMemoryBound(to: CChar.self)
                let entryName = string(withFileSystemRepresentation: namePtr, length: length)
                if entryName != "." && entryName != ".." {
                    let entryType = Int32(entry.pointee.d_type)
                    try closure(entryName, entryType)
                }
                errno = 0
            }
            guard errno == 0 else {
                throw _NSErrorWithErrno(errno, reading: true, path: path)
            }
        }
    }

    internal func _subpathsOfDirectory(atPath path: String) throws -> [String] {
        var contents: [String] = []

        try _contentsOfDir(atPath: path, { (entryName, entryType) throws in
            contents.append(entryName)
            if entryType == DT_DIR {
                let subPath: String = path + "/" + entryName
                let entries = try subpathsOfDirectory(atPath: subPath)
                contents.append(contentsOf: entries.map({file in "\(entryName)/\(file)"}))
            }
        })
        return contents
    }

    internal func _attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey : Any] {
        return try _attributesOfFileSystemIncludingBlockSize(forPath: path).attributes
    }
    
    internal func _attributesOfFileSystemIncludingBlockSize(forPath path: String) throws -> (attributes: [FileAttributeKey : Any], blockSize: UInt64?) {
    #if os(WASI)
        // WASI doesn't have statvfs
        throw _NSErrorWithErrno(ENOTSUP, reading: true, path: path)
    #else
        var result: [FileAttributeKey:Any] = [:]
        var finalBlockSize: UInt64?
        
        try _fileSystemRepresentation(withPath: path) { fsRep in
            // statvfs(2) doesn't support 64bit inode on Darwin (apfs), fallback to statfs(2)
    #if canImport(Darwin)
            var s = statfs()
            guard statfs(fsRep, &s) == 0 else {
                throw _NSErrorWithErrno(errno, reading: true, path: path)
            }
    #else
            var s = statvfs()
            guard statvfs(fsRep, &s) == 0 else {
                throw _NSErrorWithErrno(errno, reading: true, path: path)
            }
    #endif

    #if canImport(Darwin)
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
            
            finalBlockSize = blockSize
        }
        return (attributes: result, blockSize: finalBlockSize)
    #endif // os(WASI)
    }

    internal func _createSymbolicLink(atPath path: String, withDestinationPath destPath: String) throws {
        try _fileSystemRepresentation(withPath: path, andPath: destPath, {
            guard symlink($1, $0) == 0 else {
                throw _NSErrorWithErrno(errno, reading: false, path: path)
            }
       })
    }

    /* destinationOfSymbolicLinkAtPath:error: returns a String containing the path of the item pointed at by the symlink specified by 'path'. If this method returns 'nil', an NSError will be thrown.

        This method replaces pathContentOfSymbolicLinkAtPath:
     */
    internal func _destinationOfSymbolicLink(atPath path: String) throws -> String {
        let bufferSize = Int(PATH_MAX + 1)
        let buffer = try [Int8](unsafeUninitializedCapacity: bufferSize) { buffer, initializedCount in
            let len = try _fileSystemRepresentation(withPath: path) { (path) -> Int in
                return readlink(path, buffer.baseAddress!, bufferSize)
            }
            guard len >= 0 else {
                throw _NSErrorWithErrno(errno, reading: true, path: path)
            }
            initializedCount = len
        }
        return self.string(withFileSystemRepresentation: buffer, length: buffer.count)
    }
        
    internal func _recursiveDestinationOfSymbolicLink(atPath path: String) throws -> String {
        #if os(WASI)
        // TODO: Remove this guard when realpath implementation will be released
        // See https://github.com/WebAssembly/wasi-libc/pull/473
        throw _NSErrorWithErrno(ENOTSUP, reading: true, path: path)
        #else
        // Throw error if path is not a symbolic link:
        let path = try _destinationOfSymbolicLink(atPath: path)
        
        let bufSize = Int(PATH_MAX + 1)
        var buf = [Int8](repeating: 0, count: bufSize)
        let _resolvedPath = try _fileSystemRepresentation(withPath: path) {
            realpath($0, &buf)
        }
        guard let resolvedPath = _resolvedPath else {
            throw _NSErrorWithErrno(errno, reading: true, path: path)
        }

        return String(cString: resolvedPath)
        #endif
    }

    /* Returns a String with a canonicalized path for the element at the specified path. */
    internal func _canonicalizedPath(toFileAtPath path: String) throws -> String {
        #if os(WASI)
        // TODO: Remove this guard when realpath implementation will be released
        // See https://github.com/WebAssembly/wasi-libc/pull/473
        throw _NSErrorWithErrno(ENOTSUP, reading: true, path: path)
        #else
        let bufSize = Int(PATH_MAX + 1)
        var buf = [Int8](repeating: 0, count: bufSize)
        let done = try _fileSystemRepresentation(withPath: path) {
            realpath($0, &buf) != nil
        }
        if !done {
            throw _NSErrorWithErrno(errno, reading: true, path: path)
        }
        
        return self.string(withFileSystemRepresentation: buf, length: strlen(buf))
        #endif
    }

    internal func _readFrom(fd: Int32, toBuffer buffer: UnsafeMutablePointer<UInt8>, length bytesToRead: Int, filename: String) throws -> Int {
        var bytesRead = 0

        repeat {
            bytesRead = numericCast(read(fd, buffer, numericCast(bytesToRead)))
        } while bytesRead < 0 && errno == EINTR
        guard bytesRead >= 0 else {
            throw _NSErrorWithErrno(errno, reading: true, path: filename)
        }
        return bytesRead
    }

    internal func _writeTo(fd: Int32, fromBuffer buffer : UnsafeMutablePointer<UInt8>, length bytesToWrite: Int, filename: String) throws {
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

    internal func _copyRegularFile(atPath srcPath: String, toPath dstPath: String, variant: String = "Copy") throws {
        let srcRep = try __fileSystemRepresentation(withPath: srcPath)
        defer { srcRep.deallocate() }
        let dstRep = try __fileSystemRepresentation(withPath: dstPath)
        defer { dstRep.deallocate() }

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

        let dstfd = open(dstRep, O_WRONLY | O_CREAT | O_EXCL | O_TRUNC, 0o666)
        guard dstfd >= 0 else {
            throw _NSErrorWithErrno(errno, reading: false, path: dstPath,
                                    extraUserInfo: extraErrorInfo(srcPath: srcPath, dstPath: dstPath, userVariant: variant))
        }
        defer { close(dstfd) }

        #if !os(WASI) // WASI doesn't have ownership concept
        // Set the file permissions using fchmod() instead of when open()ing to avoid umask() issues
        let permissions = fileInfo.st_mode & ~S_IFMT
        guard fchmod(dstfd, permissions) == 0 else {
            throw _NSErrorWithErrno(errno, reading: false, path: dstPath,
                extraUserInfo: extraErrorInfo(srcPath: srcPath, dstPath: dstPath, userVariant: variant))
        }
        #endif

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
    }

    internal func _copySymlink(atPath srcPath: String, toPath dstPath: String, variant: String = "Copy") throws {
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
    }

    internal func _copyOrLinkDirectoryHelper(atPath srcPath: String, toPath dstPath: String, variant: String = "Copy", _ body: (String, String, FileAttributeType) throws -> ()) throws {
        let stat = try _lstatFile(atPath: srcPath)

        let fileType = FileAttributeType(statMode: mode_t(stat.st_mode))
        if fileType == .typeDirectory {
            try createDirectory(atPath: dstPath, withIntermediateDirectories: false, attributes: nil)

            guard let enumerator = enumerator(atPath: srcPath) else {
                throw _NSErrorWithErrno(ENOENT, reading: true, path: srcPath)
            }

            while let item = enumerator.nextObject() as? String {
                let src = srcPath + "/" + item
                let dst = dstPath + "/" + item
                if let stat = try? _lstatFile(atPath: src) {
                    let fileType = FileAttributeType(statMode: mode_t(stat.st_mode))
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
    }

    internal func _moveItem(atPath srcPath: String, toPath dstPath: String, isURL: Bool) throws {
        guard shouldMoveItemAtPath(srcPath, toPath: dstPath, isURL: isURL) else {
            return
        }

        guard !self.fileExists(atPath: dstPath) else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteFileExists.rawValue, userInfo: [NSFilePathErrorKey : NSString(dstPath)])
        }

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
    }

    internal func _linkItem(atPath srcPath: String, toPath dstPath: String, isURL: Bool) throws {
        try _copyOrLinkDirectoryHelper(atPath: srcPath, toPath: dstPath) { (srcPath, dstPath, fileType) in
            guard shouldLinkItemAtPath(srcPath, toPath: dstPath, isURL: isURL) else {
                return
            }

            do {
                switch fileType {
                case .typeRegular:
                    try _fileSystemRepresentation(withPath: srcPath, andPath: dstPath, {
                        if link($0, $1) == -1 {
                            throw _NSErrorWithErrno(errno, reading: false, path: srcPath)
                        }
                    })
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

    internal func _removeItem(atPath path: String, isURL: Bool, alreadyConfirmed: Bool = false) throws {
        guard alreadyConfirmed || shouldRemoveItemAtPath(path, isURL: isURL) else {
            return
        }
        try _fileSystemRepresentation(withPath: path, { fsRep in
            if rmdir(fsRep) == 0 {
                return
            } else if errno == ENOTEMPTY {
                #if os(WASI)
                // wasi-libc, which is based on musl, does not provide fts(3)
                throw _NSErrorWithErrno(ENOTSUP, reading: false, path: path)
                #else
                let ps = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: 2)
                ps.initialize(to: UnsafeMutablePointer(mutating: fsRep))
                ps.advanced(by: 1).initialize(to: nil)
                let stream = ps.withMemoryRebound(to: UnsafeMutablePointer<CChar>.self, capacity: 2) {
                    fts_open($0, FTS_PHYSICAL | FTS_XDEV | FTS_NOCHDIR | FTS_NOSTAT, nil)
                }
                ps.deinitialize(count: 2)
                ps.deallocate()

                if let stream {
                    defer {
                        fts_close(stream)
                    }

                    while let current = fts_read(stream)?.pointee, let fts_path = current.fts_path {
                        let itemPath = string(withFileSystemRepresentation: fts_path, length: Int(current.fts_pathlen))
                        guard alreadyConfirmed || shouldRemoveItemAtPath(itemPath, isURL: isURL) else {
                            continue
                        }

                        do {
                            switch Int32(current.fts_info) {
                            case FTS_DEFAULT, FTS_F, FTS_NSOK, FTS_SL, FTS_SLNONE:
                                if unlink(fts_path) == -1 {
                                    throw _NSErrorWithErrno(errno, reading: false, path: itemPath)
                                }
                            case FTS_DP:
                                if rmdir(fts_path) == -1 {
                                    throw _NSErrorWithErrno(errno, reading: false, path: itemPath)
                                }
                            case FTS_DNR, FTS_ERR, FTS_NS:
                                throw _NSErrorWithErrno(current.fts_errno, reading: false, path: itemPath)
                            default:
                                break
                            }
                        } catch {
                            if !shouldProceedAfterError(error, removingItemAtPath: itemPath, isURL: isURL) {
                                throw error
                            }
                        }
                    }
                } else {
                    let _ = _NSErrorWithErrno(ENOTEMPTY, reading: false, path: path)
                }
                #endif
            } else if errno != ENOTDIR {
                throw _NSErrorWithErrno(errno, reading: false, path: path)
            } else if unlink(fsRep) != 0 {
                throw _NSErrorWithErrno(errno, reading: false, path: path)
            }
        })

    }

    internal func _currentDirectoryPath() -> String {
        let length = Int(PATH_MAX) + 1
        var buf = [Int8](repeating: 0, count: length)
        getcwd(&buf, length)
        return string(withFileSystemRepresentation: buf, length: Int(strlen(buf)))
    }

    @discardableResult
    internal func _changeCurrentDirectoryPath(_ path: String) -> Bool {
        do {
            return try _fileSystemRepresentation(withPath: path, { chdir($0) == 0 })
        }
        catch {
            return false
        }
    }

    internal func _fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        do {
            return try _fileSystemRepresentation(withPath: path, { fsRep in
                var s = try _lstatFile(atPath: path, withFileSystemRepresentation: fsRep)
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
        } catch {
            return false
        }
    }

    internal func _isReadableFile(atPath path: String) -> Bool {
        do {
            return try _fileSystemRepresentation(withPath: path, {
                access($0, R_OK) == 0
            })
        } catch {
            return false
        }
    }

    internal func _isWritableFile(atPath path: String) -> Bool {
        do {
            return try _fileSystemRepresentation(withPath: path, {
                access($0, W_OK) == 0
            })
        } catch {
            return false
        }
    }

    internal func _isExecutableFile(atPath path: String) -> Bool {
        do {
            return try _fileSystemRepresentation(withPath: path, {
                access($0, X_OK) == 0
            })
        } catch {
            return false
        }
    }

    /**
     - parameters:
        - path: The path to the file we are trying to determine is deletable.

      - returns: `true` if the file is deletable, `false` otherwise.
     */
    internal func _isDeletableFile(atPath path: String) -> Bool {
        guard path != "" else { return true }   // This matches Darwin even though its probably the wrong response

        // Get the parent directory of supplied path
        let parent = path._nsObject.deletingLastPathComponent

        do {
            return try _fileSystemRepresentation(withPath: parent, andPath: path, { parentFsRep, fsRep  in
                // Check the parent directory is writeable, else return false.
                guard access(parentFsRep, W_OK) == 0 else {
                    return false
                }

                #if !os(WASI) // WASI doesn't have ownership concept
                // Stat the parent directory, if that fails, return false.
                let parentS = try _lstatFile(atPath: path, withFileSystemRepresentation: parentFsRep)

                // Check if the parent is 'sticky' if it exists.
                if (parentS.st_mode & S_ISVTX) == S_ISVTX {
                    let s = try _lstatFile(atPath: path, withFileSystemRepresentation: fsRep)

                    // If the current user owns the file, return true.
                    return s.st_uid == getuid()
                }
                #endif

                // Return true as the best guess.
                return true
            })
        } catch {
            return false
        }
    }

    private func _compareSymlinks(withFileSystemRepresentation file1Rep: UnsafePointer<Int8>, andFileSystemRepresentation file2Rep: UnsafePointer<Int8>, size fileSize: Int64) -> Bool {
        let bufSize = Int(fileSize)
        let buffer1 = UnsafeMutablePointer<CChar>.allocate(capacity: bufSize)
        defer { buffer1.deallocate() }
        let buffer2 = UnsafeMutablePointer<CChar>.allocate(capacity: bufSize)
        defer { buffer2.deallocate() }

        let size1 = readlink(file1Rep, buffer1, bufSize)
        guard size1 >= 0 else { return false }

        let size2 = readlink(file2Rep, buffer2, bufSize)
        guard size2 >= 0 else { return false }

        #if !os(Android)
            // In Android the reported size doesn't match the contents.
            // Other platforms seems to follow that rule.
            guard fileSize == size1 else { return false }
        #endif

        guard size1 == size2  else { return false }
        return memcmp(buffer1, buffer2, size1) == 0
    }

    internal func _lstatFile(atPath path: String, withFileSystemRepresentation fsRep: UnsafePointer<Int8>? = nil) throws -> stat {
        let _fsRep: UnsafePointer<Int8>
        if fsRep == nil {
            _fsRep = try __fileSystemRepresentation(withPath: path)
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

#if os(Linux)
    // This is only used on Linux and the only extra information it returns in addition
    // to a normal stat() call is the file creation date (stx_btime). It is only
    // used by attributesOfItem(atPath:) which is why the return is a simple stat()
    // structure and optional creation date.

    internal func _statxFile(atPath path: String) throws -> (stat, Date?) {
        // Fallback if statx() is unavailable or fails
        func _statxFallback(atPath path: String, withFileSystemRepresentation fsRep: UnsafePointer<Int8>?) throws -> (stat, Date?) {
            let statInfo = try _lstatFile(atPath: path, withFileSystemRepresentation: fsRep)
            return (statInfo, nil)
        }

        return try _fileSystemRepresentation(withPath: path) { fsRep in
            if supportsStatx {
                var statInfo = stat()
                var btime = timespec()
                let statxErrno = _stat_with_btime(fsRep, &statInfo, &btime)
                guard statxErrno == 0 else {
                    switch statxErrno {
                    case EPERM, ENOSYS:
                        // statx() may be blocked by a security mechanism (eg libseccomp or Docker) even if the kernel verison is new enough. EPERM or ENONSYS may be reported.
                        // Dont try to use it in future and fallthough to a normal lstat() call.
                        supportsStatx = false
                        return try _statxFallback(atPath: path, withFileSystemRepresentation: fsRep)

                    default:
                        throw _NSErrorWithErrno(statxErrno, reading: true, path: path)
                    }
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
                return try _statxFallback(atPath: path, withFileSystemRepresentation: fsRep)
            }
        }
    }
#endif

    /* -contentsEqualAtPath:andPath: does not take into account data stored in the resource fork or filesystem extended attributes.
     */
    internal func _contentsEqual(atPath path1: String, andPath path2: String) -> Bool {
        do {
            let fsRep1 = try __fileSystemRepresentation(withPath: path1)
            defer { fsRep1.deallocate() }

            let file1 = try _lstatFile(atPath: path1, withFileSystemRepresentation: fsRep1)
            let file1Type = file1.st_mode & S_IFMT

            // Don't use access() for symlinks as only the contents should be checked even
            // if the symlink doesnt point to an actual file, but access() will always try
            // to resolve the link and fail if the destination is not found
            if path1 == path2 && file1Type != S_IFLNK {
                return access(fsRep1, R_OK) == 0
            }

            let fsRep2 = try __fileSystemRepresentation(withPath: path2)
            defer { fsRep2.deallocate() }
            let file2 = try _lstatFile(atPath: path2, withFileSystemRepresentation: fsRep2)
            let file2Type = file2.st_mode & S_IFMT

            // Are paths the same type: file, directory, symbolic link etc.
            guard file1Type == file2Type else {
                return false
            }

            if file1Type == S_IFCHR || file1Type == S_IFBLK {
                // For character devices, just check the major/minor pair is the same.
                return _dev_major(dev_t(file1.st_rdev)) == _dev_major(dev_t(file2.st_rdev))
                    && _dev_minor(dev_t(file1.st_rdev)) == _dev_minor(dev_t(file2.st_rdev))
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

            // Don't know how to compare other file types.
            return false
        } catch {
            return false
        }
}

    internal func _appendSymlinkDestination(_ dest: String, toPath: String) -> String {
        let isAbsolutePath: Bool = dest.hasPrefix("/")

        if isAbsolutePath {
            return dest
        }
        let temp = toPath._bridgeToObjectiveC().deletingLastPathComponent
        return temp._bridgeToObjectiveC().appendingPathComponent(dest)
    }

    #if os(WASI)
    // For platforms that don't support FTS, we just throw an error for now.
    // TODO: Provide readdir(2) based implementation here or FTS in wasi-libc?
    internal class NSURLDirectoryEnumerator : DirectoryEnumerator {
        var _url : URL
        var _errorHandler : ((URL, Error) -> Bool)?

        init(url: URL, options: FileManager.DirectoryEnumerationOptions, errorHandler: ((URL, Error) -> Bool)?) {
            _url = url
            _errorHandler = errorHandler
        }

        override func nextObject() -> Any? {
            if let handler = _errorHandler {
                _ = handler(_url, _NSErrorWithErrno(ENOTSUP, reading: true, url: _url))
            }
            return nil
        }
    }
    #else
    internal class NSURLDirectoryEnumerator : DirectoryEnumerator {
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

            let fm = FileManager.default
            do {
                guard fm.fileExists(atPath: _url.path) else { throw _NSErrorWithErrno(ENOENT, reading: true, url: url) }
                _stream = try FileManager.default._fileSystemRepresentation(withPath: _url.path) { fsRep in
                    let ps = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: 2)
                    defer { ps.deallocate() }
                    ps.initialize(to: UnsafeMutablePointer(mutating: fsRep))
                    ps.advanced(by: 1).initialize(to: nil)
                    return ps.withMemoryRebound(to: UnsafeMutablePointer<CChar>.self, capacity: 2) {
                        fts_open($0, FTS_PHYSICAL | FTS_XDEV | FTS_NOCHDIR | FTS_NOSTAT, nil)
                    }
                }
                if _stream == nil {
                    throw _NSErrorWithErrno(errno, reading: true, url: url)
                }
            } catch {
                _rootError = error
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
                    let filename = FileManager.default.string(withFileSystemRepresentation: current.pointee.fts_path!, length: Int(current.pointee.fts_pathlen))

                    switch Int32(current.pointee.fts_info) {
                        case FTS_D:
                            let (showFile, skipDescendants) = match(filename: filename, to: _options, isDir: true)
                            if skipDescendants {
                                fts_set(stream, _current!, FTS_SKIP)
                            }
                            if showFile {
                                 return URL(fileURLWithPath: filename, isDirectory: true)
                            }

                        case FTS_DEFAULT, FTS_F, FTS_NSOK, FTS_SL, FTS_SLNONE:
                            let (showFile, _) = match(filename: filename, to: _options, isDir: false)
                            if showFile {
                                return URL(fileURLWithPath: filename, isDirectory: false)
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

        override var directoryAttributes : [FileAttributeKey : Any]? {
            return nil
        }

        override var fileAttributes: [FileAttributeKey : Any]? {
            return nil
        }
    }
    #endif

    internal func _updateTimes(atPath path: String, withFileSystemRepresentation fsr: UnsafePointer<Int8>, creationTime: Date? = nil, accessTime: Date? = nil, modificationTime: Date? = nil) throws {
        let stat = try _lstatFile(atPath: path, withFileSystemRepresentation: fsr)

        let accessDate = accessTime ?? stat.lastAccessDate
        let modificationDate = modificationTime ?? stat.lastModificationDate

        let array = [
            timeval(_timeIntervalSince1970: accessDate.timeIntervalSince1970), 
            timeval(_timeIntervalSince1970: modificationDate.timeIntervalSince1970),
        ]
        try array.withUnsafeBufferPointer {
            guard utimes(fsr, $0.baseAddress) == 0 else {
                throw _NSErrorWithErrno(errno, reading: false, path: path)
            }
        }
    }

    internal func _replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: ItemReplacementOptions = [], allowPlatformSpecificSyscalls: Bool = true) throws -> URL? {

        // 1. Make a backup, if asked to.
        var backupItemURL: URL?
        if let backupItemName = backupItemName {
            let url = originalItemURL.deletingLastPathComponent().appendingPathComponent(backupItemName)
            try copyItem(at: originalItemURL, to: url)
            backupItemURL = url
        }
        
        // 2. Make sure we have a copy of the original attributes if we're being asked to preserve them (the default)
        let originalAttributes = try attributesOfItem(atPath: originalItemURL.path)
        let newAttributes = try attributesOfItem(atPath: newItemURL.path)
        
        func applyPostprocessingRequiredByOptions() throws {
            if !options.contains(.usingNewMetadataOnly) {
                var attributesToReapply: [FileAttributeKey: Any] = [:]
                attributesToReapply[.creationDate] = originalAttributes[.creationDate]
                attributesToReapply[.posixPermissions] = originalAttributes[.posixPermissions]
                try setAttributes(attributesToReapply, ofItemAtPath: originalItemURL.path)
            }
            
            // As the very last step, if not explicitly asked to keep the backup, remove it.
            if let backupItemURL = backupItemURL, !options.contains(.withoutDeletingBackupItem) {
                try removeItem(at: backupItemURL)
            }
        }
        
        if allowPlatformSpecificSyscalls {
            // First, a little OS-specific detour.
            // Blindly try these operations first, and fall back to the non-OS-specific code below if they all fail.
            #if canImport(Darwin)
            do {
                let finalErrno = originalItemURL.withUnsafeFileSystemRepresentation { (originalFS) -> Int32? in
                    return newItemURL.withUnsafeFileSystemRepresentation { (newItemFS) -> Int32? in
                        // Note that Darwin allows swapping a file with a directory this way.
                        if renameatx_np(AT_FDCWD, originalFS, AT_FDCWD, newItemFS, UInt32(RENAME_SWAP)) == 0 {
                            return nil
                        } else {
                            return errno
                        }
                    }
                }
                
                if let finalErrno = finalErrno, finalErrno != ENOTSUP {
                    throw _NSErrorWithErrno(finalErrno, reading: false, url: originalItemURL)
                } else if finalErrno == nil {
                    try applyPostprocessingRequiredByOptions()
                    return originalItemURL
                }
            }
            #endif
            
            #if canImport(Glibc)
            do {
                let finalErrno = originalItemURL.withUnsafeFileSystemRepresentation { (originalFS) -> Int32? in
                    return newItemURL.withUnsafeFileSystemRepresentation { (newItemFS) -> Int32? in
                        if let originalFS = originalFS,
                           let newItemFS = newItemFS {

                                #if os(Linux)
                                if _CFHasRenameat2 && kernelSupportsRenameat2 {
                                    if _CF_renameat2(AT_FDCWD, originalFS, AT_FDCWD, newItemFS, _CF_renameat2_RENAME_EXCHANGE) == 0 {
                                        return nil
                                    } else {
                                        return errno
                                    }
                                }
                                #endif
                                if renameat(AT_FDCWD, originalFS, AT_FDCWD, newItemFS) == 0 {
                                    return nil
                                } else {
                                    return errno
                                }
                        } else {
                            return Int32(EINVAL)
                        }
                    }
                }
                
                // ENOTDIR is raised if the objects are directories; EINVAL may indicate that the filesystem does not support the operation.
                if let finalErrno = finalErrno, finalErrno != ENOTDIR && finalErrno != EINVAL {
                    throw _NSErrorWithErrno(finalErrno, reading: false, url: originalItemURL)
                } else if finalErrno == nil {
                    try applyPostprocessingRequiredByOptions()
                    return originalItemURL
                }
            }
            #endif
        }
        
        // 3. Replace!
        // Are they both regular files?
        let originalType = originalAttributes[.type] as? FileAttributeType
        let newType = newAttributes[.type] as? FileAttributeType
        if originalType == newType, originalType == .typeRegular {
            let finalErrno = originalItemURL.withUnsafeFileSystemRepresentation { (originalFS) -> Int32? in
                return newItemURL.withUnsafeFileSystemRepresentation { (newItemFS) -> Int32? in
                    // This is an atomic operation in many OSes, but is not guaranteed to be atomic by the standard.
                    if rename(newItemFS!, originalFS!) == 0 {
                        return nil
                    } else {
                        return errno
                    }
                }
            }
            if let theErrno = finalErrno {
                throw _NSErrorWithErrno(theErrno, reading: false, url: originalItemURL)
            }
        } else {
            // Only perform a replacement of different object kinds nonatomically.
            let uniqueName = UUID().uuidString
            let tombstoneURL = newItemURL.deletingLastPathComponent().appendingPathComponent(uniqueName)
            try moveItem(at: originalItemURL, to: tombstoneURL)
            try moveItem(at: newItemURL, to: originalItemURL)
            try removeItem(at: tombstoneURL)
        }
        
        // 4. Reapply attributes if asked to preserve, and delete the backup if not asked otherwise.
        try applyPostprocessingRequiredByOptions()
        
        return originalItemURL
    }
}

extension FileManager.NSPathDirectoryEnumerator {
    internal func _nextObject() -> Any? {
        let o = innerEnumerator.nextObject()
        guard let url = o as? URL else {
            return nil
        }

        let path = url.path.replacingOccurrences(of: baseURL.path+"/", with: "")
        _currentItemPath = path
        return _currentItemPath
    }
}


#endif
