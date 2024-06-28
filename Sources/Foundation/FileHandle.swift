// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016, 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation
#if canImport(Dispatch)
import Dispatch
#endif

// FileHandle has a .read(upToCount:) method. Just invoking read() will cause an ambiguity warning. Use _read instead.
// Same with close()/.close().
#if canImport(Darwin)
import Darwin
fileprivate let _read = Darwin.read(_:_:_:)
fileprivate let _write = Darwin.write(_:_:_:)
fileprivate let _close = Darwin.close(_:)
#elseif canImport(Glibc)
import Glibc
fileprivate let _read = Glibc.read(_:_:_:)
fileprivate let _write = Glibc.write(_:_:_:)
fileprivate let _close = Glibc.close(_:)
#elseif canImport(Musl)
import Musl
fileprivate let _read = Musl.read(_:_:_:)
fileprivate let _write = Musl.write(_:_:_:)
fileprivate let _close = Musl.close(_:)
#elseif canImport(WASILibc)
import WASILibc
fileprivate let _read = WASILibc.read(_:_:_:)
fileprivate let _write = WASILibc.write(_:_:_:)
fileprivate let _close = WASILibc.close(_:)
#elseif canImport(Android)
import Android
fileprivate let _read = Android.read(_:_:_:)
fileprivate let _write = Android.write(_:_:_:)
fileprivate let _close = Android.close(_:)
#endif

#if canImport(WinSDK)
import let WinSDK.INVALID_HANDLE_VALUE
import struct WinSDK.HANDLE
#endif

extension NSError {
    internal var errnoIfAvailable: Int? {
        if domain == NSPOSIXErrorDomain {
            return code
        }
        
        if let underlying = userInfo[NSUnderlyingErrorKey] as? NSError {
            return underlying.errnoIfAvailable
        }
        
        return nil
    }
}

/* On Darwin, FileHandle conforms to NSSecureCoding for use with NSXPCConnection and related facilities only. On swift-corelibs-foundation, it does not conform to that protocol since those facilities are unavailable. */
 
open class FileHandle : NSObject {
#if os(Windows)
    public private(set) var _handle: HANDLE

    @available(Windows, unavailable, message: "Cannot perform non-owning handle to fd conversion")
    open var fileDescriptor: Int32 {
        NSUnsupported()
    }

    private func _checkFileHandle() {
        precondition(self._handle != INVALID_HANDLE_VALUE, "Invalid file handle")
    }

    internal var _isPlatformHandleValid: Bool {
        return self._handle != INVALID_HANDLE_VALUE
    }
#else
    private var _fd: Int32

    open var fileDescriptor: Int32 {
        return _fd
    }

    private func _checkFileHandle() {
        precondition(_fd >= 0, "Bad file descriptor")
    }

    internal var _isPlatformHandleValid: Bool {
        return fileDescriptor >= 0
    }
#endif

    private var _closeOnDealloc: Bool

#if canImport(Dispatch)
    private var currentBackgroundActivityOwner: AnyObject? // Guarded by privateAsyncVariablesLock
    
    private var readabilitySource: DispatchSourceProtocol? // Guarded by privateAsyncVariablesLock
    private var writabilitySource: DispatchSourceProtocol? // Guarded by privateAsyncVariablesLock
    
    private var privateAsyncVariablesLock = NSLock()
    
    // matches Darwin.
    private var _queue: DispatchQueue? // Guarded by privateAsyncVariablesLock
    private var queue: DispatchQueue {
        privateAsyncVariablesLock.lock()
        defer { privateAsyncVariablesLock.unlock() }
        
        if let queue = _queue {
            return queue
        } else {
            let storage = DispatchQueue(label: "com.apple.NSFileHandle.fd_monitoring")
            _queue = storage
            return storage
        }
    }
    private var queueIfExists: DispatchQueue? {
        privateAsyncVariablesLock.lock()
        defer { privateAsyncVariablesLock.unlock() }
        
        return _queue
    }
    
    private func monitor(forReading reading: Bool, resumed: Bool = true, handler: @escaping (FileHandle, DispatchSourceProtocol) -> Void) -> DispatchSourceProtocol {
        _checkFileHandle()
        
        // Duplicate the file descriptor.
        // Closing the file descriptor while Dispatch is monitoring it leads to undefined behavior; guard against that.
        #if os(Windows)
        var dupHandle: HANDLE?
        if !DuplicateHandle(GetCurrentProcess(), self._handle, GetCurrentProcess(), &dupHandle,
                        /*dwDesiredAccess:*/0, /*bInheritHandle:*/true, DWORD(DUPLICATE_SAME_ACCESS)) {
            fatalError("DuplicateHandleFailed: \(GetLastError())")
        }

        let fd = _open_osfhandle(intptr_t(bitPattern: dupHandle), 0)
        #else
        let fd = dup(fileDescriptor)
        #endif
        let source: DispatchSourceProtocol
        if reading {
            source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        } else {
            source = DispatchSource.makeWriteSource(fileDescriptor: fd, queue: queue)
        }
        
        let sourceObject = source as AnyObject
        source.setEventHandler { [weak self, weak sourceObject] in
            if let me = self, let source = sourceObject as? DispatchSourceProtocol {
                handler(me, source)
            }
        }
        source.setCancelHandler {
            _ = _close(fd)
        }
        
        if resumed {
            source.resume()
        }
        
        return source
    }

    private var _readabilityHandler: ((FileHandle) -> Void)? = nil // Guarded by privateAsyncVariablesLock
    open var readabilityHandler: ((FileHandle) -> Void)? {
        get {
            privateAsyncVariablesLock.lock()
            let handler = _readabilityHandler
            privateAsyncVariablesLock.unlock()
            return handler
        }
        set {
            privateAsyncVariablesLock.lock()
            _readabilityHandler = newValue
            if let oldSource = readabilitySource {
                oldSource.cancel()
                readabilitySource = nil
            }
            privateAsyncVariablesLock.unlock()
            
            if let handler = newValue {
                // The handler can be called as part of the creation of the monitoring source, which can then call into FileHandle code again. Make sure we do not hold the lock when this is invoked.
                let source = monitor(forReading: true, handler: { (fh, _) in handler(fh) })
                
                privateAsyncVariablesLock.lock()
                readabilitySource = source
                privateAsyncVariablesLock.unlock()
            }
        }
    }
    
    private var _writeabilityHandler: ((FileHandle) -> Void)? = nil // Guarded by privateAsyncVariablesLock
    open var writeabilityHandler: ((FileHandle) -> Void)? {
        get {
            privateAsyncVariablesLock.lock()
            let handler = _writeabilityHandler
            privateAsyncVariablesLock.unlock()
            return handler
        }
        set {
            privateAsyncVariablesLock.lock()
            _writeabilityHandler = newValue
            if let oldSource = writabilitySource {
                oldSource.cancel()
                writabilitySource = nil
            }
            privateAsyncVariablesLock.unlock()
            
            if let handler = newValue {
                // The handler can be called as part of the creation of the monitoring source, which can then call into FileHandle code again. Make sure we do not hold the lock when this is invoked.
                let source = monitor(forReading: false, handler: { (fh, _) in handler(fh) })
                
                privateAsyncVariablesLock.lock()
                writabilitySource = source
                privateAsyncVariablesLock.unlock()
            }
        }
    }
#endif // canImport(Dispatch)

    open var availableData: Data {
        _checkFileHandle()
        do {
            let readResult = try _readDataOfLength(Int.max, untilEOF: false)
            return readResult.toData()
        } catch {
            fatalError("\(error)")
        }
    }
    
    internal func _readDataOfLength(_ length: Int, untilEOF: Bool, options: NSData.ReadingOptions = []) throws -> NSData.NSDataReadResult {
        guard _isPlatformHandleValid else { throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadUnknown.rawValue) }
        
#if os(Windows)
        if length == 0 && !untilEOF {
          // Nothing requested, return empty response
          return NSData.NSDataReadResult(bytes: nil, length: 0, deallocator: nil)
        }

        if GetFileType(self._handle) == FILE_TYPE_DISK {
          var fiFileInfo: BY_HANDLE_FILE_INFORMATION = BY_HANDLE_FILE_INFORMATION()
          if !GetFileInformationByHandle(self._handle, &fiFileInfo) {
              throw _NSErrorWithWindowsError(GetLastError(), reading: true)
          }

          if options.contains(.alwaysMapped) {
            let hMapping: HANDLE =
                CreateFileMappingA(self._handle, nil, DWORD(PAGE_READONLY), 0, 0, nil)
            if hMapping == HANDLE(bitPattern: 0) {
              fatalError("CreateFileMappingA failed")
            }

            let szFileSize: UInt64 = (UInt64(fiFileInfo.nFileSizeHigh) << 32) | UInt64(fiFileInfo.nFileSizeLow << 0)
            let szMapSize: UInt64 = Swift.min(UInt64(length), szFileSize)
            let pData: UnsafeMutableRawPointer =
                MapViewOfFile(hMapping, DWORD(FILE_MAP_READ), 0, 0, SIZE_T(szMapSize))

            return NSData.NSDataReadResult(bytes: pData, length: Int(szMapSize)) { buffer, length in
              if !UnmapViewOfFile(buffer) {
                fatalError("UnmapViewOfFile failed")
              }
              if !CloseHandle(hMapping) {
                fatalError("CloseHandle failed")
              }
            }
          }
        }

        let blockSize: Int = 8 * 1024
        var allocated: Int = blockSize
        var buffer: UnsafeMutableRawPointer = malloc(allocated)!
        var total: Int = 0

        while total < length {
          let remaining = length - total
          let BytesToRead: DWORD = DWORD(min(blockSize, remaining))

          if (allocated - total) < BytesToRead {
            allocated *= 2
            buffer = _CFReallocf(buffer, allocated)
          }

          var BytesRead: DWORD = 0
          if !ReadFile(self._handle, buffer.advanced(by: total), BytesToRead, &BytesRead, nil) {
            let err = GetLastError()
            if err == ERROR_BROKEN_PIPE {
                break
            }
            free(buffer)
            throw _NSErrorWithWindowsError(err, reading: true)
          }
          total += Int(BytesRead)
          if BytesRead == 0 || !untilEOF {
            break
          }
        }

        if total == 0 {
          free(buffer)
          return NSData.NSDataReadResult(bytes: nil, length: 0, deallocator: nil)
        }

        buffer = _CFReallocf(buffer, total)
        let data = buffer.bindMemory(to: UInt8.self, capacity: total)
        return NSData.NSDataReadResult(bytes: data, length: total) { buffer, length in
          free(buffer)
        }
#else
        if length == 0 && !untilEOF {
            // Nothing requested, return empty response
            return NSData.NSDataReadResult(bytes: nil, length: 0, deallocator: nil)
        }

        var statbuf = stat()
        if fstat(_fd, &statbuf) < 0 {
            throw _NSErrorWithErrno(errno, reading: true)
        }

        let readBlockSize: Int
        if statbuf.st_mode & S_IFMT == S_IFREG {
            // TODO: Should files over a certain size always be mmap()'d?
            if options.contains(.alwaysMapped) {
                // Filesizes are often 64bit even on 32bit systems
                let mapSize = min(length, Int(clamping: statbuf.st_size))
                let data = mmap(nil, mapSize, PROT_READ, MAP_PRIVATE, _fd, 0)
                // Swift does not currently expose MAP_FAILURE
                if data != UnsafeMutableRawPointer(bitPattern: -1) {
                    return NSData.NSDataReadResult(bytes: data, length: mapSize) { buffer, length in
                        munmap(buffer, length)
                    }
                }
            }

            if statbuf.st_blksize > 0 {
                readBlockSize = Int(clamping: statbuf.st_blksize)
            } else {
                readBlockSize = 1024 * 8
            }
        } else {
            /* We get here on sockets, character special files, FIFOs ... */
            readBlockSize = 1024 * 8
        }
        var currentAllocationSize = readBlockSize
        var dynamicBuffer = malloc(currentAllocationSize)!
        var total = 0

        while total < length {
            let remaining = length - total
            let amountToRead = min(readBlockSize, remaining)
            // Make sure there is always at least amountToRead bytes available in the buffer.
            if (currentAllocationSize - total) < amountToRead {
                currentAllocationSize *= 2
                dynamicBuffer = _CFReallocf(dynamicBuffer, currentAllocationSize)
            }
            let amtRead = _read(_fd, dynamicBuffer.advanced(by: total), amountToRead)
            if amtRead < 0 {
                free(dynamicBuffer)
                throw _NSErrorWithErrno(errno, reading: true)
            }
            total += amtRead
            if amtRead == 0 || !untilEOF { // If there is nothing more to read or we shouldn't keep reading then exit
                break
            }
        }

        if total == 0 {
            free(dynamicBuffer)
            return NSData.NSDataReadResult(bytes: nil, length: 0, deallocator: nil)
        }
        dynamicBuffer = _CFReallocf(dynamicBuffer, total)
        let bytePtr = dynamicBuffer.bindMemory(to: UInt8.self, capacity: total)
        return NSData.NSDataReadResult(bytes: bytePtr, length: total) { buffer, length in
            free(buffer)
        }
#endif
    }
    
    internal func _readBytes(into buffer: UnsafeMutablePointer<UInt8>, length: Int) throws -> Int {
#if os(Windows)
        var BytesRead: DWORD = 0
        let BytesToRead: DWORD = DWORD(length)
        if !ReadFile(self._handle, buffer, BytesToRead, &BytesRead, nil) {
            throw _NSErrorWithWindowsError(GetLastError(), reading: true)
        }
        return Int(BytesRead)
#else
        let amtRead = _read(_fd, buffer, length)
        if amtRead < 0 {
            throw _NSErrorWithErrno(errno, reading: true)
        }
        return amtRead
#endif
    }

    internal func _writeBytes(buf: UnsafeRawPointer, length: Int) throws {
#if os(Windows)
        var bytesRemaining = length
        while bytesRemaining > 0 {
            var bytesWritten: DWORD = 0
            if !WriteFile(self._handle, buf.advanced(by: length - bytesRemaining), DWORD(bytesRemaining), &bytesWritten, nil) {
                throw _NSErrorWithWindowsError(GetLastError(), reading: false)
            }
            if bytesWritten == 0 {
                throw _NSErrorWithWindowsError(GetLastError(), reading: false)
            }
            bytesRemaining -= Int(bytesWritten)
        }
#else
        var bytesRemaining = length
        while bytesRemaining > 0 {
            var bytesWritten = 0
            repeat {
                bytesWritten = _write(_fd, buf.advanced(by: length - bytesRemaining), bytesRemaining)
            } while (bytesWritten < 0 && errno == EINTR)
            if bytesWritten <= 0 {
                throw _NSErrorWithErrno(errno, reading: false, path: nil)
            }
            bytesRemaining -= bytesWritten
        }
#endif
    }

#if os(Windows)
    internal init(handle: HANDLE, closeOnDealloc closeopt: Bool) {
      self._handle = handle
      _closeOnDealloc = closeopt
    }

    public init(fileDescriptor fd: Int32, closeOnDealloc closeopt: Bool) {
      if (closeopt) {
        var handle: HANDLE?
        if !DuplicateHandle(GetCurrentProcess(), HANDLE(bitPattern: _get_osfhandle(fd))!, GetCurrentProcess(), &handle, 0, false, DWORD(DUPLICATE_SAME_ACCESS)) {
          fatalError("DuplicateHandle() failed: \(GetLastError())")
        }
        _close(fd)
        self._handle = handle!
        _closeOnDealloc = true
      } else {
        self._handle = HANDLE(bitPattern: _get_osfhandle(fd))!
        _closeOnDealloc = false
      }
    }

    public convenience init(fileDescriptor fd: Int32) {
      self.init(handle: HANDLE(bitPattern: _get_osfhandle(fd))!,
                closeOnDealloc: false)
    }

    internal convenience init?(path: String, flags: Int32, createMode: Int) {
        guard let fd: CInt = try? withNTPathRepresentation(of: path, {
            _CFOpenFileWithMode($0, flags, mode_t(createMode))
        }), fd > 0 else { return nil }

        self.init(fileDescriptor: fd, closeOnDealloc: true)
        if self._handle == INVALID_HANDLE_VALUE { return nil }
    }
#else
    public init(fileDescriptor fd: Int32, closeOnDealloc closeopt: Bool) {
        _fd = fd
        _closeOnDealloc = closeopt
    }

    public convenience init(fileDescriptor fd: Int32) {
        self.init(fileDescriptor: fd, closeOnDealloc: false)
    }

    internal init?(path: String, flags: Int32, createMode: Int) {
        _fd = _CFOpenFileWithMode(path, flags, mode_t(createMode))
        _closeOnDealloc = true
        super.init()
        if _fd < 0 {
            return nil
        }
    }
#endif

    internal convenience init?(fileSystemRepresentation: UnsafePointer<NativeFSRCharType>, flags: Int32, createMode: Int) {
        let fd = _CFOpenFileWithMode(fileSystemRepresentation, flags, mode_t(createMode))
        guard fd > 0 else { return nil }
        self.init(fileDescriptor: fd, closeOnDealloc: true)
    }

    deinit {
        // .close() tries to wait after operations in flight on the handle queue, if one exists, and then close. It does so by sending .sync { … } work to it.
        // if we try to do that here, we may end up in a situation where:
        // - the last reference is held by the handle queue;
        // - the last operation holding onto the handle finishes, and the block is released;
        // - the handle is released;
        // - the handle's deinit is invoked;
        // - deinit tries to .sync { … } to serialize the work on the handle queue, _which we're already on_
        // - deadlock! DispatchQueue's deadlock detection triggers and crashes us.
        // since all operations on the handle queue retain the handle during use, if the handle is being deinited, then there are no more operations on the queue, so this is serial with respect to them anyway. Just close the handle immediately.
        try? _immediatelyClose(closeFd: _closeOnDealloc)
    }

    // MARK: -
    // MARK: New API.
    
    @available(swift 5.0)
    public func readToEnd() throws -> Data? {
        guard self != FileHandle._nulldeviceFileHandle else { return nil }
        
        return try read(upToCount: Int.max)
    }
    
    @available(swift 5.0)
    public func read(upToCount count: Int) throws -> Data? {
        guard self != FileHandle._nulldeviceFileHandle else { return nil }
        
        let result = try _readDataOfLength(count, untilEOF: true)
        return result.length == 0 ? nil : result.toData()
    }
    
    @available(swift 5.0)
    public func write<T: DataProtocol>(contentsOf data: T) throws {
        guard self != FileHandle._nulldeviceFileHandle else { return }
        
        guard _isPlatformHandleValid else { throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnknown.rawValue) }
        
        for region in data.regions {
            try region.withUnsafeBytes { (bytes) in
                if let baseAddress = bytes.baseAddress, bytes.count > 0 {
                    try _writeBytes(buf: UnsafeRawPointer(baseAddress), length: bytes.count)
                }
            }
        }
    }
    
    @available(swift 5.0)
    public func offset() throws -> UInt64 {
        guard self != FileHandle._nulldeviceFileHandle else { return 0 }
        
        guard _isPlatformHandleValid else { throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadUnknown.rawValue) }

        #if os(Windows)
        var liPointer: LARGE_INTEGER = LARGE_INTEGER(QuadPart: 0)
        guard SetFilePointerEx(self._handle, LARGE_INTEGER(QuadPart: 0), &liPointer, DWORD(FILE_CURRENT)) else {
            throw _NSErrorWithWindowsError(GetLastError(), reading: true)
        }
        return UInt64(liPointer.QuadPart)
        #else
        let offset = lseek(_fd, 0, SEEK_CUR)
        guard offset >= 0 else { throw _NSErrorWithErrno(errno, reading: true) }
        return UInt64(offset)
        #endif
    }
    
    @available(swift 5.0)
    @discardableResult
    public func seekToEnd() throws -> UInt64 {
        guard self != FileHandle._nulldeviceFileHandle else { return 0 }
        
        guard _isPlatformHandleValid else { throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadUnknown.rawValue) }

        #if os(Windows)
        var liPointer: LARGE_INTEGER = LARGE_INTEGER(QuadPart: 0)
        guard SetFilePointerEx(self._handle, LARGE_INTEGER(QuadPart: 0), &liPointer, DWORD(FILE_END)) else {
            throw _NSErrorWithWindowsError(GetLastError(), reading: true)
        }
        return UInt64(liPointer.QuadPart)
        #else
        let offset = lseek(_fd, 0, SEEK_END)
        guard offset >= 0 else { throw _NSErrorWithErrno(errno, reading: true) }
        return UInt64(offset)
        #endif
    }
    
    @available(swift 5.0)
    public func seek(toOffset offset: UInt64) throws {
        guard self != FileHandle._nulldeviceFileHandle else { return }
        
        guard _isPlatformHandleValid else { throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadUnknown.rawValue) }

        #if os(Windows)
        guard SetFilePointerEx(self._handle, LARGE_INTEGER(QuadPart: LONGLONG(offset)), nil, DWORD(FILE_BEGIN)) else {
            throw _NSErrorWithWindowsError(GetLastError(), reading: true)
        }
        #else
        guard lseek(_fd, off_t(offset), SEEK_SET) >= 0 else { throw _NSErrorWithErrno(errno, reading: true) }
        #endif
    }
    
    @available(swift 5.0)
    public func truncate(atOffset offset: UInt64) throws {
        guard self != FileHandle._nulldeviceFileHandle else { return }
        
        guard _isPlatformHandleValid else { throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnknown.rawValue) }

        #if os(Windows)
        guard SetFilePointerEx(self._handle, LARGE_INTEGER(QuadPart: LONGLONG(offset)), nil, DWORD(FILE_BEGIN)) else {
            throw _NSErrorWithWindowsError(GetLastError(), reading: false)
        }
        guard SetEndOfFile(self._handle) else {
            throw _NSErrorWithWindowsError(GetLastError(), reading: false)
        }
        #else
        guard lseek(_fd, off_t(offset), SEEK_SET) >= 0 else { throw _NSErrorWithErrno(errno, reading: false) }
        guard ftruncate(_fd, off_t(offset)) >= 0 else { throw _NSErrorWithErrno(errno, reading: false) }
        #endif
    }
    
    @available(swift 5.0)
    public func synchronize() throws {
        guard self != FileHandle._nulldeviceFileHandle else { return }
        
        #if os(Windows)
        guard FlushFileBuffers(self._handle) else {
            let dwError: DWORD = GetLastError()
            // If the handle is a handle to the console output,
            // `FlushFileBuffers` will fail and return `ERROR_INVALID_HANDLE` as
            // console output is not buffered.
            if dwError == ERROR_INVALID_HANDLE &&
                    GetFileType(self._handle) == FILE_TYPE_CHAR {
                // Simlar to the Linux, macOS, BSD cases below, ignore the error
                // on the special file type.
                return
            }
            throw _NSErrorWithWindowsError(dwError, reading: false)
        }
        #else
        // Linux, macOS, OpenBSD return -1 and errno == EINVAL if trying to sync a special file,
        // eg a fifo, character device etc which can be ignored.
        // Additionally, Linux may return EROFS if tying to sync on a readonly filesystem, which also can be ignored.
        // macOS can also return ENOTSUP for pipes but dont ignore it, so that the behaviour matches Darwin's Foundation.
        if fsync(_fd) < 0 {
            if errno == EINVAL || errno == EROFS { return }
            throw _NSErrorWithErrno(errno, reading: false)
        }
        #endif
    }
    
    private func performOnQueueIfExists(_ block: () throws -> Void) throws {
#if canImport(Dispatch)
        if let queue = queueIfExists {
            var theError: Swift.Error?
            queue.sync {
                do { try block() } catch { theError = error }
            }
            if let error = theError {
                throw error
            }
        } else {
            try block()
        }
#else
        try block()
#endif
    }
    
    @available(swift 5.0)
    public func close() throws {
        try performOnQueueIfExists {
            try _immediatelyClose()
        }
    }

    // Shutdown any read/write sources and handlers, and optionally close the file descriptor.
    private func _immediatelyClose(closeFd: Bool = true) throws {
        guard self != FileHandle._nulldeviceFileHandle else { return }
        guard _isPlatformHandleValid else { return }
        
        #if canImport(Dispatch)
        privateAsyncVariablesLock.lock()
        writabilitySource?.cancel()
        readabilitySource?.cancel()
        _readabilityHandler = nil
        _writeabilityHandler = nil
        writabilitySource = nil
        readabilitySource = nil
        privateAsyncVariablesLock.unlock()
        #endif

#if os(Windows)
            // SR-13822 - Not Closing the file descriptor on Windows causes a Stack Overflow
            guard CloseHandle(self._handle) else {
                throw _NSErrorWithWindowsError(GetLastError(), reading: true)
            }
            self._handle = INVALID_HANDLE_VALUE
#else
            if closeFd {
                guard _close(_fd) >= 0 else {
                    throw _NSErrorWithErrno(errno, reading: true)
                }
                _fd = -1
            }
#endif
    }
    
    // MARK: -
    // MARK: To-be-deprecated API.
    
    // This matches the effect of API_TO_BE_DEPRECATED in ObjC headers:
    @available(swift, deprecated: 100000, renamed: "readToEnd()")
    open func readDataToEndOfFile() -> Data {
        return try! readToEnd() ?? Data()
    }
    
    @available(swift, deprecated: 100000, renamed: "read(upToCount:)")
    open func readData(ofLength length: Int) -> Data {
        return try! read(upToCount: length) ?? Data()
    }
    
    @available(swift, deprecated: 100000, renamed: "write(contentsOf:)")
    open func write(_ data: Data) {
        try! write(contentsOf: data)
    }
    
    @available(swift, deprecated: 100000, renamed: "offset()")
    open var offsetInFile: UInt64 {
        return try! offset()
    }
    
    @available(swift, deprecated: 100000, renamed: "seekToEnd()")
    @discardableResult
    open func seekToEndOfFile() -> UInt64 {
        return try! seekToEnd()
    }
    
    @available(swift, deprecated: 100000, renamed: "seek(toOffset:)")
    open func seek(toFileOffset offset: UInt64) {
        try! seek(toOffset: offset)
    }
    
    @available(swift, deprecated: 100000, renamed: "truncate(atOffset:)")
    open func truncateFile(atOffset offset: UInt64) {
        try! truncate(atOffset: offset)
    }
    
    @available(swift, deprecated: 100000, renamed: "synchronize()")
    open func synchronizeFile() {
        try! synchronize()
    }
    
    @available(swift, deprecated: 100000, renamed: "close()")
    open func closeFile() {
        try! self.close()
    }
}

extension FileHandle {
    
    internal static var _stdinFileHandle: FileHandle = {
        return FileHandle(fileDescriptor: STDIN_FILENO, closeOnDealloc: false)
    }()

    open class var standardInput: FileHandle {
        return _stdinFileHandle
    }
    
    internal static var _stdoutFileHandle: FileHandle = {
        return FileHandle(fileDescriptor: STDOUT_FILENO, closeOnDealloc: false)
    }()

    open class var standardOutput: FileHandle {
        return _stdoutFileHandle
    }
    
    internal static var _stderrFileHandle: FileHandle = {
        return FileHandle(fileDescriptor: STDERR_FILENO, closeOnDealloc: false)
    }()
    
    open class var standardError: FileHandle {
        return _stderrFileHandle
    }

    internal static var _nulldeviceFileHandle: FileHandle = {
        class NullDevice: FileHandle {
            override var availableData: Data {
                return Data()
            }

            override func readDataToEndOfFile() -> Data {
                return Data()
            }

            override func readData(ofLength length: Int) -> Data {
                return Data()
            }

            override func write(_ data: Data) {}

            override var offsetInFile: UInt64 {
                return 0
            }

            override func seekToEndOfFile() -> UInt64 {
                return 0
            }

            override func seek(toFileOffset offset: UInt64) {}

            override func truncateFile(atOffset offset: UInt64) {}

            override func synchronizeFile() {}

            override func closeFile() {}

            deinit {}
        }

#if os(Windows)
        return NullDevice(handle: INVALID_HANDLE_VALUE, closeOnDealloc: false)
#else
        return NullDevice(fileDescriptor: -1, closeOnDealloc: false)
#endif
    }()

    open class var nullDevice: FileHandle {
        return _nulldeviceFileHandle
    }

    public convenience init?(forReadingAtPath path: String) {
        self.init(path: path, flags: O_RDONLY, createMode: 0)
    }
    
    public convenience init?(forWritingAtPath path: String) {
        self.init(path: path, flags: O_WRONLY, createMode: 0)
    }
    
    public convenience init?(forUpdatingAtPath path: String) {
        self.init(path: path, flags: O_RDWR, createMode: 0)
    }
    
    internal static func _openFileDescriptorForURL(_ url : URL, flags: Int32, reading: Bool) throws -> Int32 {
        let fd = url.withUnsafeFileSystemRepresentation( { (fsRep) -> Int32 in
            guard let fsRep = fsRep else { return -1 }
            return _CFOpenFile(fsRep, flags)
        })
        if fd < 0 {
            throw _NSErrorWithErrno(errno, reading: reading, url: url)
        }
        return fd
    }
    
    public convenience init(forReadingFrom url: URL) throws {
        let fd = try FileHandle._openFileDescriptorForURL(url, flags: O_RDONLY, reading: true)
        self.init(fileDescriptor: fd, closeOnDealloc: true)
    }
    
    public convenience init(forWritingTo url: URL) throws {
        let fd = try FileHandle._openFileDescriptorForURL(url, flags: O_WRONLY, reading: false)
        self.init(fileDescriptor: fd, closeOnDealloc: true)
    }

    public convenience init(forUpdating url: URL) throws {
        let fd = try FileHandle._openFileDescriptorForURL(url, flags: O_RDWR, reading: false)
        self.init(fileDescriptor: fd, closeOnDealloc: true)
    }
}

extension NSExceptionName {
    public static let fileHandleOperationException = NSExceptionName(rawValue: "NSFileHandleOperationException")
}

extension Notification.Name {
    public static let NSFileHandleReadToEndOfFileCompletion = Notification.Name(rawValue: "NSFileHandleReadToEndOfFileCompletionNotification")
    public static let NSFileHandleConnectionAccepted = Notification.Name(rawValue: "NSFileHandleConnectionAcceptedNotification")
    public static let NSFileHandleDataAvailable = Notification.Name(rawValue: "NSFileHandleDataAvailableNotification")
}

extension FileHandle {
    public static let readCompletionNotification = Notification.Name(rawValue: "NSFileHandleReadCompletionNotification")
}

public let NSFileHandleNotificationDataItem: String = "NSFileHandleNotificationDataItem"
public let NSFileHandleNotificationFileHandleItem: String = "NSFileHandleNotificationFileHandleItem"

extension FileHandle {
    open func readInBackgroundAndNotify() {
        readInBackgroundAndNotify(forModes: [.default])
    }

    open func readInBackgroundAndNotify(forModes modes: [RunLoop.Mode]?) {
#if !canImport(Dispatch)
        NSUnsupported()
#else
        _checkFileHandle()
        
        privateAsyncVariablesLock.lock()
        guard currentBackgroundActivityOwner == nil else { fatalError("No two activities can occur at the same time") }
        let token = NSObject()
        currentBackgroundActivityOwner = token
        privateAsyncVariablesLock.unlock()

        let operation = { (_ data: DispatchData, _ error: Int32) in
            self.privateAsyncVariablesLock.lock()
            if self.currentBackgroundActivityOwner === token {
                self.currentBackgroundActivityOwner = nil
            }
            self.privateAsyncVariablesLock.unlock()

            var userInfo: [String: Any] = [:]
            if error == 0 {
                userInfo[NSFileHandleNotificationDataItem] = Data(data)
            } else {
                userInfo[NSFileHandleNotificationDataItem] = Data()
#if os(Windows)
                // On Windows, reading from a directory results in an
                // ERROR_ACCESS_DENIED. If we get ERROR_ACCESS_DENIED
                // and the handle we attempt to read from is a
                // directory, replace it with
                // ERROR_DIRECTORY_NOT_SUPPORTED to match POSIX's EISDIR
                var translatedError = error
                if error == ERROR_ACCESS_DENIED {
                    var fileInfo = BY_HANDLE_FILE_INFORMATION()
                    GetFileInformationByHandle(self._handle, &fileInfo)
                    if fileInfo.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY {
                        translatedError = Int32(ERROR_DIRECTORY_NOT_SUPPORTED)
                    }
                }
                userInfo["NSFileHandleError"] = Int(translatedError)
#else
                userInfo["NSFileHandleError"] = Int(error)
#endif
            }

            DispatchQueue.main.async {
                NotificationQueue.default.enqueue(Notification(name: FileHandle.readCompletionNotification, object: self, userInfo: userInfo), postingStyle: .asap, coalesceMask: .none, forModes: modes)
            }
        }

#if os(Windows)
        DispatchIO.read(fromHandle: self._handle, maxLength: 1024 * 1024, runningHandlerOn: queue) { (data, error) in
          operation(data, error)
        }
#else
        DispatchIO.read(fromFileDescriptor: fileDescriptor, maxLength: 1024 * 1024, runningHandlerOn: queue) { (data, error) in
          operation(data, error)
        }
#endif
#endif // canImport(Dispatch)
    }
    
    open func readToEndOfFileInBackgroundAndNotify() {
        readToEndOfFileInBackgroundAndNotify(forModes: [.default])
    }
    
    open func readToEndOfFileInBackgroundAndNotify(forModes modes: [RunLoop.Mode]?) {
#if !canImport(Dispatch) || !canImport(Dispatch)
        NSUnsupported()
#else
        privateAsyncVariablesLock.lock()
        guard currentBackgroundActivityOwner == nil else { fatalError("No two activities can occur at the same time") }
        
        let token = NSObject()
        currentBackgroundActivityOwner = token
        privateAsyncVariablesLock.unlock()

        queue.async {
            let data: Data?
            let error: Int?
            
            do {
                data = try self.readToEnd()
                error = nil
            } catch let thrown {
                data = nil
                if let thrown = thrown as? NSError {
                    error = thrown.errnoIfAvailable
                } else {
                    error = nil
                }
            }
            
            DispatchQueue.main.async {
                self.privateAsyncVariablesLock.lock()
                if token === self.currentBackgroundActivityOwner {
                    self.currentBackgroundActivityOwner = nil
                }
                self.privateAsyncVariablesLock.unlock()
                
                var userInfo: [String: Any] = [:]
                if let data = data {
                    userInfo[NSFileHandleNotificationDataItem] = data
                }
                if let error = error {
                    userInfo["NSFileHandleError"] = error
                }
                
                NotificationQueue.default.enqueue(Notification(name: .NSFileHandleReadToEndOfFileCompletion, object: self, userInfo: userInfo), postingStyle: .asap, coalesceMask: .none, forModes: modes)
            }
        }
#endif
    }
    
    @available(Windows, unavailable, message: "A SOCKET cannot be treated as a fd")
    open func acceptConnectionInBackgroundAndNotify() {
#if os(Windows) || !canImport(Dispatch)
        NSUnsupported()
#else
        acceptConnectionInBackgroundAndNotify(forModes: [.default])
#endif
    }

    @available(Windows, unavailable, message: "A SOCKET cannot be treated as a fd")
    open func acceptConnectionInBackgroundAndNotify(forModes modes: [RunLoop.Mode]?) {
#if os(Windows) || !canImport(Dispatch)
        NSUnsupported()
#else
        let owner = monitor(forReading: true, resumed: false) { (handle, source) in
            var notification = Notification(name: .NSFileHandleConnectionAccepted, object: handle, userInfo: [:])
            let userInfo: [AnyHashable : Any]
            
            let acceptedFD = accept(handle.fileDescriptor, nil, nil)
            if acceptedFD >= 0 {
                userInfo = [NSFileHandleNotificationFileHandleItem: FileHandle(fileDescriptor: acceptedFD)]
            } else {
                userInfo = ["NSFileHandleError": NSNumber(value: errno)]
            }
            notification.userInfo = userInfo
            
            DispatchQueue.main.async {
                handle.privateAsyncVariablesLock.lock()
                handle.currentBackgroundActivityOwner = nil
                handle.privateAsyncVariablesLock.unlock()
                
                NotificationQueue.default.enqueue(Notification(name: .NSFileHandleConnectionAccepted, object: handle, userInfo: [:]), postingStyle: .asap, coalesceMask: .none, forModes: modes)
            }
        }
        
        privateAsyncVariablesLock.lock()
        guard currentBackgroundActivityOwner == nil else { fatalError("No two activities can occur at the same time") }
        currentBackgroundActivityOwner = owner as AnyObject
        privateAsyncVariablesLock.unlock()
        
        owner.resume()
#endif
    }

    open func waitForDataInBackgroundAndNotify() {
        waitForDataInBackgroundAndNotify(forModes: [.default])
    }
    
    open func waitForDataInBackgroundAndNotify(forModes modes: [RunLoop.Mode]?) {
#if !canImport(Dispatch)
        NSUnsupported()
#else
        let owner = monitor(forReading: true, resumed: false) { (handle, source) in
            source.cancel()
            DispatchQueue.main.async {
                handle.privateAsyncVariablesLock.lock()
                handle.currentBackgroundActivityOwner = nil
                handle.privateAsyncVariablesLock.unlock()
                
                NotificationQueue.default.enqueue(Notification(name: .NSFileHandleDataAvailable, object: handle, userInfo: [:]), postingStyle: .asap, coalesceMask: .none, forModes: modes)
            }
        }
        
        privateAsyncVariablesLock.lock()
        guard currentBackgroundActivityOwner == nil else { fatalError("No two activities can occur at the same time") }
        currentBackgroundActivityOwner = owner as AnyObject
        privateAsyncVariablesLock.unlock()
        
        owner.resume()
#endif
    }
}

open class Pipe: NSObject {
    public let fileHandleForReading: FileHandle
    public let fileHandleForWriting: FileHandle

    public override init() {
#if os(Windows)
        var saAttr: SECURITY_ATTRIBUTES = SECURITY_ATTRIBUTES(nLength: DWORD(MemoryLayout<SECURITY_ATTRIBUTES>.size), lpSecurityDescriptor: nil, bInheritHandle: true)

        var hReadPipe: HANDLE?
        var hWritePipe: HANDLE?

        if !CreatePipe(&hReadPipe, &hWritePipe, &saAttr, 0) {
          fatalError("CreatePipe failed")
        }
        self.fileHandleForReading = FileHandle(handle: hReadPipe!,
                                               closeOnDealloc: true)
        self.fileHandleForWriting = FileHandle(handle: hWritePipe!,
                                               closeOnDealloc: true)
#elseif os(WASI)
        NSUnsupported()
#else
        /// the `pipe` system call creates two `fd` in a malloc'ed area
        let fds = UnsafeMutablePointer<Int32>.allocate(capacity: 2)
        defer {
            fds.deallocate()
        }
        /// If the operating system prevents us from creating file handles, stop
        let ret = pipe(fds)
        switch (ret, errno) {
        case (0, _):
            self.fileHandleForReading = FileHandle(fileDescriptor: fds.pointee, closeOnDealloc: true)
            self.fileHandleForWriting = FileHandle(fileDescriptor: fds.successor().pointee, closeOnDealloc: true)

        case (-1, EMFILE), (-1, ENFILE):
            // Unfortunately this initializer does not throw and isn't failable so this is only
            // way of handling this situation.
            self.fileHandleForReading = FileHandle(fileDescriptor: -1, closeOnDealloc: false)
            self.fileHandleForWriting = FileHandle(fileDescriptor: -1, closeOnDealloc: false)

        default:
            fatalError("Error calling pipe(): \(errno)")
        }
#endif
        super.init()
    }
}
