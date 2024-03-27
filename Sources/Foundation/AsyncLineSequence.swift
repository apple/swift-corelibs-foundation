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

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct AsyncLineSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    public typealias Element = String
    
    var base: Base
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = String
        
        var byteSource: Base.AsyncIterator
        var buffer: Array<UInt8> = []
        var leftover: UInt8? = nil
        
        internal init(underlyingIterator: Base.AsyncIterator) {
            byteSource = underlyingIterator
        }
        
        // We'd like to reserve flexibility to improve the implementation of
        // next() in the future, so aren't marking it @inlinable. Manually
        // specializing for the common source types helps us get back some of
        // the performance we're leaving on the table.
        @_specialize(where Base == URL.AsyncBytes)
        @_specialize(where Base == FileHandle.AsyncBytes)
        //@_specialize(where Base == URLSession.AsyncBytes)
        public mutating func next() async rethrows -> String? {
            /*
             0D 0A: CR-LF
             0A | 0B | 0C | 0D: LF, VT, FF, CR
             E2 80 A8:  U+2028 (LINE SEPARATOR)
             E2 80 A9:  U+2029 (PARAGRAPH SEPARATOR)
             */
            let _CR: UInt8 = 0x0D
            let _LF: UInt8 = 0x0A
            let _NEL_PREFIX: UInt8 = 0xC2
            let _NEL_SUFFIX: UInt8 = 0x85
            let _SEPARATOR_PREFIX: UInt8 = 0xE2
            let _SEPARATOR_CONTINUATION: UInt8 = 0x80
            let _SEPARATOR_SUFFIX_LINE: UInt8 = 0xA8
            let _SEPARATOR_SUFFIX_PARAGRAPH: UInt8 = 0xA9
          
            func yield() -> String? {
                defer {
                    buffer.removeAll(keepingCapacity: true)
                }
                if buffer.isEmpty {
                    return nil
                }
                return String(decoding: buffer, as: UTF8.self)
            }
            
            func nextByte() async throws -> UInt8? {
                defer { leftover = nil }
                if let leftover = leftover {
                    return leftover
                }
                return try await byteSource.next()
            }
            
            while let first = try await nextByte() {
                switch first {
                case _CR:
                    let result = yield()
                    // Swallow up any subsequent LF
                    guard let next = try await byteSource.next() else {
                        return result //if we ran out of bytes, the last byte was a CR
                    }
                    if next != _LF {
                        leftover = next
                    }
                    if let result = result {
                        return result
                    }
                    continue
                case _LF..<_CR:
                    guard let result = yield() else {
                        continue
                    }
                    return result
                case _NEL_PREFIX: // this may be used to compose other UTF8 characters
                    guard let next = try await byteSource.next() else {
                        // technically invalid UTF8 but it should be repaired to "\u{FFFD}"
                        buffer.append(first)
                        return yield()
                    }
                    if next != _NEL_SUFFIX {
                        buffer.append(first)
                        buffer.append(next)
                    } else {
                      guard let result = yield() else {
                          continue
                      }
                      return result
                    }
                case _SEPARATOR_PREFIX:
                    // Try to read: 80 [A8 | A9].
                    // If we can't, then we put the byte in the buffer for error correction
                    guard let next = try await byteSource.next() else {
                        buffer.append(first)
                        return yield()
                    }
                    guard next == _SEPARATOR_CONTINUATION else {
                        buffer.append(first)
                        buffer.append(next)
                        continue
                    }
                    guard let fin = try await byteSource.next() else {
                        buffer.append(first)
                        buffer.append(next)
                        return yield()
                        
                    }
                    guard fin == _SEPARATOR_SUFFIX_LINE || fin == _SEPARATOR_SUFFIX_PARAGRAPH else {
                        buffer.append(first)
                        buffer.append(next)
                        buffer.append(fin)
                        continue
                    }
                    if let result = yield() {
                        return result
                    }
                    continue
                default:
                    buffer.append(first)
                }
            }
            // Don't emit an empty newline when there is no more content (e.g. end of file)
            if !buffer.isEmpty {
                return yield()
            }
            return nil
        }
        
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(underlyingIterator: base.makeAsyncIterator())
    }
    
    internal init(underlyingSequence: Base) {
        base = underlyingSequence
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension AsyncSequence where Self.Element == UInt8 {
    /**
     A non-blocking sequence of newline-separated `Strings` created by decoding the elements of `self` as UTF8.
     */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    var lines: AsyncLineSequence<Self> {
        AsyncLineSequence(underlyingSequence: self)
    }
}
