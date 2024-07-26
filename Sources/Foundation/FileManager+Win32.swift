// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation

#if os(Windows)
import let WinSDK.INVALID_FILE_ATTRIBUTES
import WinSDK

extension URL {
    fileprivate var NTPath: String {
        // Use a NT style, device path to avoid the 261-character path
        // limitation on Windows APIs.  The addition of the prefix will bypass
        // the Win32 layer for the path handling and thus must be fully resolved
        // and normalised before being passed in.  This allows us access to the
        // complete path limit as imposed by the NT kernel rather than the 260
        // character limit as imposed by Win32.
        #"\\?\\#(CFURLCopyFileSystemPath(CFURLCopyAbsoluteURL(_cfObject), kCFURLWindowsPathStyle)!._swiftObject)"#
    }

    internal func withUnsafeNTPath<Result>(_ body: (UnsafePointer<WCHAR>) throws -> Result) rethrows -> Result {
        try self.NTPath.withCString(encodedAs: UTF16.self, body)
    }
}


internal func withNTPathRepresentation<Result>(of path: String, _ body: (UnsafePointer<WCHAR>) throws -> Result) throws -> Result {
    guard !path.isEmpty else {
        throw CocoaError.error(.fileReadInvalidFileName, userInfo: [NSFilePathErrorKey:path])
    }

    // 1. Normalize the path first.

    var path = path

    // Strip the leading `/` on a RFC8089 path (`/[drive-letter]:/...` ).  A
    // leading slash indicates a rooted path on the drive for teh current
    // working directory.
    var iter = path.makeIterator()
    if iter.next() == "/", iter.next()?.isLetter ?? false, iter.next() == ":" {
        path.removeFirst()
    }

    // Win32 APIs can support `/` for the arc separator. However,
    // symlinks created with `/` do not resolve properly, so normalize
    // the path.
    path = path.replacing("/", with: "\\")

    // Droop trailing slashes unless it follows a drive specification.  The
    // trailing arc separator after a drive specifier iindicates the root as
    // opposed to a drive relative path.
    while path.count > 1, path[path.index(before: path.endIndex)] == "\\",
            !(path.count == 3 &&
                path[path.index(path.endIndex, offsetBy: -2)] == ":" &&
                path[path.index(path.endIndex, offsetBy: -3)].isLetter) {
        path.removeLast()
    }

    // 2. Perform the operation on the normalized path.

    return try path.withCString(encodedAs: UTF16.self) { pwszPath in
        guard !path.hasPrefix(#"\\"#) else { return try body(pwszPath) }

        let dwLength = GetFullPathNameW(pwszPath, 0, nil, nil)
        let path = withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) {
            _ = GetFullPathNameW(pwszPath, DWORD($0.count), $0.baseAddress, nil)
            return String(decodingCString: $0.baseAddress!, as: UTF16.self)
        }
        guard !path.hasPrefix(#"\\"#) else {
            return try path.withCString(encodedAs: UTF16.self, body)
        }
        return try #"\\?\\#(path)"#.withCString(encodedAs: UTF16.self, body)
    }
}

private func walk(directory path: URL, _ body: (String, DWORD) throws -> Void) rethrows {
    try "\(path.NTPath)\\*".withCString(encodedAs: UTF16.self) {
        var ffd: WIN32_FIND_DATAW = .init()

        let hFind: HANDLE = FindFirstFileW($0, &ffd)
        if hFind == INVALID_HANDLE_VALUE {
            throw _NSErrorWithWindowsError(GetLastError(), reading: true, paths: [path.path])
        }

        defer { FindClose(hFind) }

        repeat {
            let entry: String = withUnsafeBytes(of: ffd.cFileName) {
                $0.withMemoryRebound(to: WCHAR.self) {
                    String(decodingCString: $0.baseAddress!, as: UTF16.self)
                }
            }

            try body(entry, ffd.dwFileAttributes)
        } while FindNextFileW(hFind, &ffd)
    }
}

extension FileManager {
    internal func _mountedVolumeURLs(includingResourceValuesForKeys propertyKeys: [URLResourceKey]?, options: VolumeEnumerationOptions = []) -> [URL]? {
        var urls: [URL] = []

        var wszVolumeName: [WCHAR] = Array<WCHAR>(repeating: 0, count: Int(MAX_PATH))

        let hVolumes: HANDLE = FindFirstVolumeW(&wszVolumeName, DWORD(wszVolumeName.count))
        guard hVolumes != INVALID_HANDLE_VALUE else { return nil }
        defer { FindVolumeClose(hVolumes) }

        repeat {
            var dwCChReturnLength: DWORD = 0
            GetVolumePathNamesForVolumeNameW(&wszVolumeName, nil, 0, &dwCChReturnLength)

            var wszPathNames: [WCHAR] = Array<WCHAR>(repeating: 0, count: Int(dwCChReturnLength + 1))
            if !GetVolumePathNamesForVolumeNameW(&wszVolumeName, &wszPathNames, DWORD(wszPathNames.count), &dwCChReturnLength) {
                // TODO(compnerd) handle error
                continue
            }

            // GetVolumePathNamesForVolumeNameW writes an array of
            // null terminated wchar strings followed by an additional
            // null terminator.
            // e.g. [ "C", ":", "\\", "\0", "D", ":", "\\", "\0", "\0"]
            var remaining = wszPathNames[...]
            while !remaining.isEmpty {
                let path = remaining.withUnsafeBufferPointer {
                    String(decodingCString: $0.baseAddress!, as: UTF16.self)
                }

                if !path.isEmpty {
                    urls.append(URL(fileURLWithPath: path, isDirectory: true))
                }
                remaining = remaining.dropFirst(path.count + 1)
            }
        } while FindNextVolumeW(hVolumes, &wszVolumeName, DWORD(wszVolumeName.count))

        return urls
    }

    internal func windowsFileAttributes(atPath path: String) throws -> WIN32_FILE_ATTRIBUTE_DATA {
        return try withNTPathRepresentation(of: path) {
            var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
            if !GetFileAttributesExW($0, GetFileExInfoStandard, &faAttributes) {
              throw _NSErrorWithWindowsError(GetLastError(), reading: true, paths: [path])
            }
            return faAttributes
        }
    }

    internal func _attributesOfFileSystemIncludingBlockSize(forPath path: String) throws -> (attributes: [FileAttributeKey : Any], blockSize: UInt64?) {
        return (attributes: try attributesOfFileSystem(forPath: path), blockSize: nil)
    }
    
    private func _realpath(_ path: String) -> String {
        return (try? destinationOfSymbolicLink(atPath: path)) ?? path
    }
    
    internal func _recursiveDestinationOfSymbolicLink(atPath path: String) throws -> String {
        // Throw error if path is not a symbolic link:
        var previousIterationDestination = try destinationOfSymbolicLink(atPath: path)
        
        // Same recursion limit as in Darwin:
        let symbolicLinkRecursionLimit = 32
        for _ in 0..<symbolicLinkRecursionLimit {
            let iterationDestination = _realpath(previousIterationDestination)
            if previousIterationDestination == iterationDestination {
                return iterationDestination
            }
            previousIterationDestination = iterationDestination
        }
        
        // As in Darwin Foundation, after the recursion limit we return the initial path without resolution.
        return path
    }

    internal func _canonicalizedPath(toFileAtPath path: String) throws -> String {
        let hFile: HANDLE = try FileManager.default._fileSystemRepresentation(withPath: path) {
          // BACKUP_SEMANTICS are (confusingly) required in order to receive a
          // handle to a directory
          CreateFileW($0, 0,
                      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                      nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, nil)
        }
        if hFile == INVALID_HANDLE_VALUE {
          return try FileManager.default._fileSystemRepresentation(withPath: path) {
            var dwLength = GetFullPathNameW($0, 0, nil, nil)

            var szPath = Array<WCHAR>(repeating: 0, count: Int(dwLength + 1))
            dwLength = GetFullPathNameW($0, DWORD(szPath.count), &szPath, nil)
            guard dwLength > 0 && dwLength <= szPath.count else {
              throw _NSErrorWithWindowsError(GetLastError(), reading: true, paths: [path])
            }

            return String(decodingCString: szPath, as: UTF16.self)
          }
        }
        defer { CloseHandle(hFile) }

        let dwLength: DWORD = GetFinalPathNameByHandleW(hFile, nil, 0, DWORD(FILE_NAME_NORMALIZED))
        var szPath: [WCHAR] = Array<WCHAR>(repeating: 0, count: Int(dwLength + 1))

        GetFinalPathNameByHandleW(hFile, &szPath, dwLength, DWORD(FILE_NAME_NORMALIZED))
        return String(decodingCString: &szPath, as: UTF16.self)
    }

    internal func _lstatFile(atPath path: String, withFileSystemRepresentation fsRep: UnsafePointer<NativeFSRCharType>? = nil) throws -> stat {
        let (stbuf, _) = try _statxFile(atPath: path, withFileSystemRepresentation: fsRep)
        return stbuf
    }

    // FIXME(compnerd) the UInt64 should be UInt128 to uniquely identify the file across volumes
    internal func _statxFile(atPath path: String, withFileSystemRepresentation fsRep: UnsafePointer<NativeFSRCharType>? = nil) throws -> (stat, UInt64) {
        let _fsRep: UnsafePointer<NativeFSRCharType>
        if fsRep == nil {
            _fsRep = try __fileSystemRepresentation(withPath: path)
        } else {
            _fsRep = fsRep!
        }

        defer {
            if fsRep == nil { _fsRep.deallocate() }
        }

        var statInfo = stat()
        let handle =
            CreateFileW(_fsRep, 0, FILE_SHARE_READ, nil, OPEN_EXISTING,
                        FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS,
                        nil)
        if handle == INVALID_HANDLE_VALUE {
            throw _NSErrorWithWindowsError(GetLastError(), reading: false, paths: [path])
        }
        defer { CloseHandle(handle) }

        var info: BY_HANDLE_FILE_INFORMATION = BY_HANDLE_FILE_INFORMATION()
        GetFileInformationByHandle(handle, &info)

        // Group id is always 0 on Windows
        statInfo.st_gid = 0
        statInfo.st_atime = info.ftLastAccessTime.time_t
        statInfo.st_ctime = info.ftCreationTime.time_t
        statInfo.st_dev = _dev_t(info.dwVolumeSerialNumber)
        // The inode, and therefore st_ino, has no meaning in the FAT, HPFS, or
        // NTFS file systems. -- docs.microsoft.com
        statInfo.st_ino = 0
        statInfo.st_rdev = _dev_t(info.dwVolumeSerialNumber)

        let isReparsePoint = info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT != 0
        let isDir = info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY != 0
        let fileMode = isDir ? _S_IFDIR : _S_IFREG
        // On a symlink to a directory, Windows sets both the REPARSE_POINT and
        // DIRECTORY attributes. Since Windows doesn't provide S_IFLNK and we
        // want unix style "symlinks to directories are not directories
        // themselves, we say symlinks are regular files
        statInfo.st_mode = UInt16(isReparsePoint ? _S_IFREG : fileMode)
        let isReadOnly = info.dwFileAttributes & FILE_ATTRIBUTE_READONLY != 0
        statInfo.st_mode |= UInt16(isReadOnly ? _S_IREAD : (_S_IREAD | _S_IWRITE))
        statInfo.st_mode |= UInt16(_S_IEXEC)

        statInfo.st_mtime = info.ftLastWriteTime.time_t
        statInfo.st_nlink = Int16(info.nNumberOfLinks)
        guard info.nFileSizeHigh == 0 else {
            throw _NSErrorWithErrno(EOVERFLOW, reading: true, path: path)
        }
        statInfo.st_size = _off_t(info.nFileSizeLow)
        // Uid is always 0 on Windows systems
        statInfo.st_uid = 0

        return (statInfo, UInt64(info.nFileIndexHigh << 32) | UInt64(info.nFileIndexLow))
    }

    internal func _appendSymlinkDestination(_ dest: String, toPath: String) -> String {
        if dest.isAbsolutePath { return dest }
        let temp = toPath._bridgeToObjectiveC().deletingLastPathComponent
        return temp._bridgeToObjectiveC().appendingPathComponent(dest)
    }

    internal func _updateTimes(atPath path: String,
                               withFileSystemRepresentation fsr: UnsafePointer<NativeFSRCharType>,
                               creationTime: Date? = nil,
                               accessTime: Date? = nil,
                               modificationTime: Date? = nil) throws {
      let stat = try _lstatFile(atPath: path, withFileSystemRepresentation: fsr)

      var ctime: FILETIME =
          FILETIME(from: time_t((creationTime ?? stat.creationDate).timeIntervalSince1970))
      var atime: FILETIME =
          FILETIME(from: time_t((accessTime ?? stat.lastAccessDate).timeIntervalSince1970))
      var mtime: FILETIME =
          FILETIME(from: time_t((modificationTime ?? stat.lastModificationDate).timeIntervalSince1970))

      let hFile: HANDLE =
        CreateFileW(fsr, GENERIC_WRITE, FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0,
                    nil)
      if hFile == INVALID_HANDLE_VALUE {
          throw _NSErrorWithWindowsError(GetLastError(), reading: true, paths: [path])
      }
      defer { CloseHandle(hFile) }

      if !SetFileTime(hFile, &ctime, &atime, &mtime) {
          throw _NSErrorWithWindowsError(GetLastError(), reading: false, paths: [path])
      }

    }

    internal class NSURLDirectoryEnumerator : DirectoryEnumerator {
        var _options : FileManager.DirectoryEnumerationOptions
        var _errorHandler : ((URL, Error) -> Bool)?
        var _stack: [URL]
        var _lastReturned: URL?
        var _root: URL

        init(url: URL, options: FileManager.DirectoryEnumerationOptions, errorHandler: (/* @escaping */ (URL, Error) -> Bool)?) {
            _options = options
            _errorHandler = errorHandler
            _stack = []
            _root = url
        }

        override func nextObject() -> Any? {
            func firstValidItem() -> URL? {
                while let url = _stack.popLast() {
                    if !FileManager.default.fileExists(atPath: url.path) {
                        guard let handler = _errorHandler else { return nil }
                        if !handler(url, _NSErrorWithWindowsError(GetLastError(), reading: true, paths: [url.path])) {
                            return nil
                        }
                    }
                    _lastReturned = url
                    return _lastReturned
                }
                return nil
            }

            if _lastReturned == nil {
                guard let attrs = try? FileManager.default.windowsFileAttributes(atPath: _root.path) else {
                    guard let handler = _errorHandler else { return nil }
                    if !handler(_root, _NSErrorWithWindowsError(GetLastError(), reading: true, paths: [_root.path])) {
                        return nil
                    }
                    return firstValidItem()
                }

                let isDirectory = attrs.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY && attrs.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT != FILE_ATTRIBUTE_REPARSE_POINT
                _lastReturned = URL(fileURLWithPath: _root.path, isDirectory: isDirectory)
            }

            guard let _lastReturned else { return firstValidItem() }

            if _lastReturned.hasDirectoryPath && (level == 0 || !_options.contains(.skipsSubdirectoryDescendants)) {
                walk(directory: _lastReturned) { entry, attributes in
                    if entry == "." || entry == ".." { return }
                    if _options.contains(.skipsHiddenFiles) && attributes & FILE_ATTRIBUTE_HIDDEN == FILE_ATTRIBUTE_HIDDEN {
                        return
                    }
                    let isDirectory = attributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY && attributes & FILE_ATTRIBUTE_REPARSE_POINT != FILE_ATTRIBUTE_REPARSE_POINT
                    _stack.append(_lastReturned.appendingPathComponent(entry, isDirectory: isDirectory))
                }
            }

            return firstValidItem()
        }

        override var level: Int {
            guard let _lastReturned else { return 0 }
            return _lastReturned.pathComponents.count - _root.pathComponents.count
        }

        override func skipDescendants() {
            _options.insert(.skipsSubdirectoryDescendants)
        }

        override var directoryAttributes : [FileAttributeKey : Any]? {
            return nil
        }

        override var fileAttributes: [FileAttributeKey : Any]? {
            return nil
        }
    }
}

extension FileManager.NSPathDirectoryEnumerator {
    internal func _nextObject() -> Any? {
        guard let url = innerEnumerator.nextObject() as? URL else { return nil }

        let path: String? = baseURL.withUnsafeNTPath { pwszBasePath in
            let dwBaseAttrs = GetFileAttributesW(pwszBasePath)
            if dwBaseAttrs == INVALID_FILE_ATTRIBUTES { return nil }

            return try? url.withUnsafeNTPath { pwszPath in
                let dwAttrs = GetFileAttributesW(pwszPath)
                if dwAttrs == INVALID_FILE_ATTRIBUTES { return nil }

                return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(MAX_PATH)) {
                    guard PathRelativePathToW($0.baseAddress, pwszBasePath, dwBaseAttrs, pwszPath, dwAttrs) else { return nil }
                    // Drop the leading ".\" from the path
                    return String(decodingCString: $0.baseAddress!.advanced(by: 2), as: UTF16.self)
                }
            }
        }

        _currentItemPath = path ?? _currentItemPath
        return path
    }

}

#endif
