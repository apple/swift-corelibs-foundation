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
public struct AsyncUnicodeScalarSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    public typealias Element = UnicodeScalar
    
    var base: Base
    
    @frozen
    public struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline var _base: Base.AsyncIterator
        @usableFromInline var _leftover: UInt8? = nil
        
        internal init(underlyingIterator: Base.AsyncIterator) {
            _base = underlyingIterator
        }
        
        @inlinable @inline(__always)
        func _expectedContinuationCountForByte(_ byte: UInt8) -> Int? {
            if byte & 0b11100000 == 0b11000000 {
                return 1
            }
            if byte & 0b11110000 == 0b11100000 {
                return 2
            }
            if byte & 0b11111000 == 0b11110000 {
                return 3
            }
            if byte & 0b10000000 == 0b00000000 {
                return 0
            }
            if byte & 0b11000000 == 0b10000000 {
                //is a continuation itself
                return nil
            }
            //is an invalid value
            return nil
        }
        
        @inlinable //not @inline(__always) since this path is less perf critical
        mutating func _nextComplexScalar(_ first: UInt8) async rethrows
        -> UnicodeScalar? {
            guard let expectedContinuationCount = _expectedContinuationCountForByte(first) else {
                //We only reach here for invalid UTF8, so just return a replacement character directly
                return "\u{FFFD}"
            }
            var bytes: (UInt8, UInt8, UInt8, UInt8) = (first, 0, 0, 0)
            var numContinuations = 0
            while numContinuations < expectedContinuationCount, let next = try await _base.next() {
                guard UTF8.isContinuation(next) else {
                    //We read one more byte than we needed due to an invalid missing continuation byte. Store it in `leftover` for next time
                    _leftover = next
                    break
                }
                
                numContinuations += 1
                withUnsafeMutableBytes(of: &bytes) {
                    $0[numContinuations] = next
                }
            }
            return withUnsafeBytes(of: &bytes) {
                return String(decoding: $0, as: UTF8.self).unicodeScalars.first
            }
        }
        
        @inlinable @inline(__always)
        public mutating func next() async rethrows -> UnicodeScalar? {
            if let leftover = _leftover {
                self._leftover = nil
                return try await _nextComplexScalar(leftover)
            }
            if let byte = try await _base.next() {
                if UTF8.isASCII(byte) {
                    _onFastPath()
                    return UnicodeScalar(byte)
                }
                return try await _nextComplexScalar(byte)
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
     A non-blocking sequence of `UnicodeScalars` created by decoding the elements of `self` as UTF8.
     */
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    var unicodeScalars: AsyncUnicodeScalarSequence<Self> {
        AsyncUnicodeScalarSequence(underlyingSequence: self)
    }
}
