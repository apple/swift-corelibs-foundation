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

extension URL {
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct AsyncBytes: AsyncSequence {
        public typealias Element = UInt8
        let url: URL
        
        @frozen
        public struct AsyncIterator: AsyncIteratorProtocol {
            @usableFromInline var buffer = _AsyncBytesBuffer(capacity: 0)
            
            @inlinable @inline(__always)
            public mutating func next() async throws -> UInt8? {
                return try await buffer.next()
            }
            
            internal init(_ url: URL) {
                buffer.readFunction = { (buf: inout _AsyncBytesBuffer) -> Int in
                    if url.isFileURL {
                        let fh = try await IOActor.default.createFileHandle(reading: url).bytes.makeAsyncIterator()
                        buf = fh.buffer
                    } else {
                        // TODO: add networking support
                        throw URLError(.unsupportedURL)
                    }
                    return try await buf.readFunction(&buf)
                }
            }
        }
        
        public func makeAsyncIterator() -> AsyncIterator {
            return AsyncIterator(url)
        }
        
        internal init(_ url: URL) {
            self.url = url
        }
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public var resourceBytes: AsyncBytes {
        return AsyncBytes(self)
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public var lines: AsyncLineSequence<AsyncBytes> {
        resourceBytes.lines
    }
}
