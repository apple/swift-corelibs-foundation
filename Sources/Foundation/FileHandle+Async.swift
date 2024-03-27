//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
final actor IOActor {
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func read(from fd: Int32, into buffer: UnsafeMutableRawBufferPointer) async throws -> Int {
        while true {
#if canImport(Darwin)
            let read = Darwin.read
#elseif canImport(Glibc)
            let read = Glibc.read
#elseif canImport(CRT)
            let read = CRT._read
#endif
            let amount = read(fd, buffer.baseAddress, buffer.count)
            if amount >= 0 {
                return amount
            }
            let posixErrno = errno
            if errno != EINTR {
                // TODO: get the path of the fd to provide a more informative error
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(posixErrno), userInfo: [:])
            }
        }
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func read(from handle: FileHandle, into buffer: UnsafeMutableRawBufferPointer) async throws -> Int {
        // this is not incredibly effecient but it is the best we have
        guard let data = try handle.read(upToCount: buffer.count) else {
            return 0
        }
        data.copyBytes(to: buffer)
        return data.count
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func createFileHandle(reading url: URL) async throws -> FileHandle {
        return try FileHandle(forReadingFrom: url)
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    static let `default` = IOActor()
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
@frozen @usableFromInline
internal struct _AsyncBytesBuffer {
    
    struct Header {
        internal var readFunction: ((inout _AsyncBytesBuffer) async throws -> Int)? = nil
        internal var finished = false
    }
    
    class Storage : ManagedBuffer<Header, UInt8> {
        var finished: Bool {
            get { return header.finished }
            set { header.finished = newValue }
        }
    }
    
    var readFunction: (inout _AsyncBytesBuffer) async throws -> Int {
        get { return (storage as! Storage).header.readFunction! }
        set { (storage as! Storage).header.readFunction = newValue }
    }
    
    // The managed buffer is guaranteed to keep the bytes alive as long as it is alive.
    // This must be escaped to avoid the extra indirection step that
    // withUnsafeMutablePointerToElement incurs in the hot path
    // DO NOT COPY THIS APPROACH WITHOUT CONSULTING THE COMPILER TEAM
    // The reasons it's delicately safe here are:
    // • We never use the pointer to access a property (would violate exclusivity)
    // • We never access the interior of a value type (doesn't have a stable address)
    //     - This is especially delicate in the case of Data, where we have to force it out of its inline representation
    //       which can't be reliably done using public API
    // • We keep the reference we're accessing the interior of alive manually
    var baseAddress: UnsafeMutableRawPointer {
        (storage as! Storage).withUnsafeMutablePointerToElements { UnsafeMutableRawPointer($0) }
    }
    
    var capacity: Int {
        (storage as! Storage).capacity
    }
    
    var storage: AnyObject? = nil
    @usableFromInline internal var nextPointer: UnsafeMutableRawPointer
    @usableFromInline internal var endPointer: UnsafeMutableRawPointer
    
    @usableFromInline init(capacity: Int) {
        let s = Storage.create(minimumCapacity: capacity) { _ in
            return Header(readFunction: nil, finished: false)
        }
        storage = s
        nextPointer = s.withUnsafeMutablePointerToElements { UnsafeMutableRawPointer($0) }
        endPointer = nextPointer
    }
    
    @inline(never) @usableFromInline
    internal mutating func reloadBufferAndNext() async throws -> UInt8? {
        let storage = self.storage as! Storage
        if storage.finished {
            return nil
        }
        try Task.checkCancellation()
        nextPointer = storage.withUnsafeMutablePointerToElements { UnsafeMutableRawPointer($0) }
        do {
            let readSize = try await readFunction(&self)
            if readSize == 0 {
                storage.finished = true
            }
        } catch {
            storage.finished = true
            throw error
        }
        return try await next()
    }
    
    @inlinable @inline(__always)
    internal mutating func next() async throws -> UInt8? {
        if _fastPath(nextPointer != endPointer) {
            let byte = nextPointer.load(fromByteOffset: 0, as: UInt8.self)
            nextPointer = nextPointer + 1
            return byte
        }
        return try await reloadBufferAndNext()
    }
}

extension FileHandle {
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct AsyncBytes: AsyncSequence {
        public typealias Element = UInt8
        public typealias AsyncIterator = FileHandle.AsyncBytes.Iterator
        var handle: FileHandle
        
        internal init(file: FileHandle) {
            handle = file
        }
        
        public func makeAsyncIterator() -> Iterator {
            return Iterator(file: handle)
        }
        
        @frozen
        public struct Iterator: AsyncIteratorProtocol {
            
            @inline(__always) static var bufferSize: Int {
                16384
            }
            
            public typealias Element = UInt8
            @usableFromInline var buffer: _AsyncBytesBuffer
            
            internal var byteBuffer: _AsyncBytesBuffer {
                return buffer
            }
            
            internal init(file: FileHandle) {
                buffer = _AsyncBytesBuffer(capacity: Iterator.bufferSize)
                let fileDescriptor = file.fileDescriptor
                buffer.readFunction = { (buf) in
                    buf.nextPointer = buf.baseAddress
                    let capacity = buf.capacity
                    let bufPtr = UnsafeMutableRawBufferPointer(start: buf.nextPointer, count: capacity)
                    let readSize: Int
                    if fileDescriptor >= 0 {
                        readSize = try await IOActor.default.read(from: fileDescriptor, into: bufPtr)
                    } else {
                        readSize = try await IOActor.default.read(from: file, into: bufPtr)
                    }
                    buf.endPointer = buf.nextPointer + readSize
                    return readSize
                }
            }
            
            @inlinable @inline(__always)
            public mutating func next() async throws -> UInt8? {
                return try await buffer.next()
            }
        }
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public var bytes: AsyncBytes {
        return AsyncBytes(file: self)
    }
}
