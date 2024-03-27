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
public struct AsyncCharacterSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    public typealias Element = Character
    
    var underlying: AsyncUnicodeScalarSequence<Base>
    
    @frozen
    public struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline var remaining: AsyncUnicodeScalarSequence<Base>.AsyncIterator
        @usableFromInline var accumulator = ""
        
        @inlinable @inline(__always)
        public mutating func next() async rethrows -> Character? {
            while let scalar = try await remaining.next() {
                accumulator.unicodeScalars.append(scalar)
                if accumulator.count > 1 {
                    return accumulator.removeFirst()
                }
            }
            return accumulator.count > 0 ? accumulator.removeFirst() : nil
        }
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(remaining: underlying.makeAsyncIterator())
    }
    
    internal init(underlyingSequence: Base) {
        underlying = AsyncUnicodeScalarSequence(underlyingSequence: underlyingSequence)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension AsyncSequence where Self.Element == UInt8 {
    /**
     A non-blocking sequence of `Characters` created by decoding the elements of `self` as UTF8.
     */
    var characters: AsyncCharacterSequence<Self> {
        AsyncCharacterSequence(underlyingSequence: self)
    }
}
