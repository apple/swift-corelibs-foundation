//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
#if !os(Windows)

#if canImport(Android)
import Android
#endif

#if os(Android) && (arch(i386) || arch(arm)) // struct stat.st_mode is UInt32
internal func &(left: UInt32, right: mode_t) -> mode_t {
    return mode_t(left) & right
}
#endif

@_implementationOnly import CoreFoundation

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
        
    internal func _recursiveDestinationOfSymbolicLink(atPath path: String) throws -> String {
        #if os(WASI)
        // TODO: Remove this guard when realpath implementation will be released
        // See https://github.com/WebAssembly/wasi-libc/pull/473
        throw _NSErrorWithErrno(ENOTSUP, reading: true, path: path)
        #else
        // Throw error if path is not a symbolic link:
        let path = try destinationOfSymbolicLink(atPath: path)
        
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
                    return ps.withMemoryRebound(to: UnsafeMutablePointer<CChar>.self, capacity: 2) { rebound_ps in
#if canImport(Android)
                        let arg = rebound_ps
#else
                        let arg = ps
#endif
                        return fts_open(arg, FTS_PHYSICAL | FTS_XDEV | FTS_NOCHDIR | FTS_NOSTAT, nil)
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
