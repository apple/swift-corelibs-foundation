// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation

// In swift-corelibs-foundation, key-value coding is not available. Since encoding and decoding a NSSortDescriptor requires interpreting key paths, NSSortDescriptor does not conform to NSCoding or NSSecureCoding in swift-corelibs-foundation only.
open class NSSortDescriptor: NSObject, NSCopying {
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }

    @available(*, unavailable, message: "Key-value coding is not available in swift-corelibs-foundation. Use Swift key paths instead with init(keyPath:ascending:) or init(keyPath:ascending:comparator:)", renamed: "init(keyPath:ascending:)")
    public init(key: String?, ascending: Bool) { NSUnsupported() }
    
    @available(*, unavailable, message: "Key-value coding is not available in swift-corelibs-foundation. Use Swift key paths instead with init(keyPath:ascending:) or init(keyPath:ascending:comparator:)", renamed: "init(keyPath:ascending:)")
    public init(key: String?, ascending: Bool, comparator cmptr: Comparator) { NSUnsupported() }
    
    
    @available(*, unavailable, message: "Key-value coding is not available in swift-corelibs-foundation. Use .keyPath instead.", renamed: "keyPath")
    open var key: String? { NSUnsupported() }
    
    @available(*, unavailable, message: "Sort descriptors cannot be decoded from archives in swift-corelibs-foundation.")
    open func allowEvaluation() {}
    
    // MARK: Available parts.
    
    public init<Root, Value: Comparable>(keyPath: KeyPath<Root, Value>, ascending: Bool) {
        self.keyPath = keyPath
        self.ascending = ascending
        self.lens = { ($0 as! Root)[keyPath: keyPath] }
        self.comparator = { (a, b) -> ComparisonResult in
            let valueA = a as! Value
            let valueB = b as! Value
            
            if valueA < valueB {
                return .orderedAscending
            } else if valueB < valueA {
                return .orderedDescending
            } else {
                return .orderedSame
            }
        }
        self.reversedSortDescriptorProducer = { return NSSortDescriptor(keyPath: keyPath, ascending: !ascending) }
    }

    public init<Root, Value>(keyPath: KeyPath<Root, Value>, ascending: Bool, comparator cmptr: @escaping Comparator) {
        self.keyPath = keyPath
        self.ascending = ascending
        self.lens = { ($0 as! Root)[keyPath: keyPath] }
        self.comparator = cmptr
        self.reversedSortDescriptorProducer = { return NSSortDescriptor(keyPath: keyPath, ascending: !ascending, comparator: cmptr) }
    }

    private static func optionalComparator<Value>(for _: Value.Type,
                                                  wrappedComparison: @escaping (Value, Value) -> ComparisonResult) -> Comparator {
        return { a, b -> ComparisonResult in
            let valueA = a as! Optional<Value>
            let valueB = b as! Optional<Value>

            switch (valueA, valueB) {
            case (.none, .none): return .orderedSame
            case (.none, .some(_)): return .orderedAscending
            case (.some(_), .none): return .orderedDescending
            case (.some(let unwrappedValueA), .some(let unwrappedValueB)):
                return wrappedComparison(unwrappedValueA, unwrappedValueB)
            }
        }
    }

    // These overloads are necessary for supporting `SortDescriptor` which relies on `NSSortDescriptor` handling optionals (like on Darwin).
    internal init<Root, Value: Comparable>(keyPath: KeyPath<Root, Value?>, ascending: Bool) {
        self.keyPath = keyPath
        self.ascending = ascending
        self.lens = { ($0 as! Root)[keyPath: keyPath] as Any }
        self.comparator = NSSortDescriptor.optionalComparator(for: Value.self, wrappedComparison: { valueA, valueB -> ComparisonResult in
            if valueA < valueB {
                return .orderedAscending
            } else if valueB < valueA {
                return .orderedDescending
            } else {
                return .orderedSame
            }
        })
        self.reversedSortDescriptorProducer = { return NSSortDescriptor(keyPath: keyPath, ascending: !ascending) }
    }

    internal init<Root, Value>(keyPath: KeyPath<Root, Value>,
                               ascending: Bool,
                               typedComparator: @escaping (Value, Value) -> ComparisonResult) {
        self.keyPath = keyPath
        self.ascending = ascending
        self.lens = { ($0 as! Root)[keyPath: keyPath] as Any }
        self.comparator = { a, b -> ComparisonResult in
            let valueA = a as! Value
            let valueB = b as! Value
            return typedComparator(valueA, valueB)
        }
        self.reversedSortDescriptorProducer = {
            return NSSortDescriptor(keyPath: keyPath, ascending: !ascending, typedComparator: typedComparator)
        }
    }

    internal init<Root, Value>(keyPath: KeyPath<Root, Value?>,
                               ascending: Bool,
                               typedComparator: @escaping (Value, Value) -> ComparisonResult) {
        self.keyPath = keyPath
        self.ascending = ascending
        self.lens = { ($0 as! Root)[keyPath: keyPath] as Any }
        self.comparator = NSSortDescriptor.optionalComparator(for: Value.self, wrappedComparison: typedComparator)
        self.reversedSortDescriptorProducer = {
            return NSSortDescriptor(keyPath: keyPath, ascending: !ascending, typedComparator: typedComparator)
        }
    }

    internal init(_sortDescriptor: NSSortDescriptor, ascending: Bool) {
        self.lens = _sortDescriptor.lens
        self.reversedSortDescriptorProducer = _sortDescriptor.reversedSortDescriptorProducer
        self.ascending = ascending
        self.keyPath = _sortDescriptor.keyPath
        self.comparator = _sortDescriptor.comparator
    }
    
    private let lens: (Any) -> Any
    private let reversedSortDescriptorProducer: () -> NSSortDescriptor
    
    open private(set) var ascending: Bool
    open private(set) var keyPath: AnyKeyPath
    open private(set) var comparator: Comparator
    
    // primitive - override this method if you want to perform comparisons differently (not key based for example)
    open func compare(_ object1: Any, to object2: Any) -> ComparisonResult {
        let lhs = lens(object1)
        let rhs = lens(object2)
        let result = comparator(lhs, rhs)
        
        let actualResult: ComparisonResult
        
        if ascending {
            actualResult = result
        } else {
            switch result {
            case .orderedAscending: actualResult = .orderedDescending
            case .orderedDescending: actualResult = .orderedAscending
            case .orderedSame: actualResult = .orderedSame
            }
        }
        
        return actualResult
    }
    open var reversedSortDescriptor: Any {
        return reversedSortDescriptorProducer()
    }
}

extension NSNumber: Comparable {
    public static func < (lhs: NSNumber, rhs: NSNumber) -> Bool {
        return lhs.compare(rhs) == .orderedAscending
    }
}

extension NSString: Comparable {
    public static func < (lhs: NSString, rhs: NSString) -> Bool {
        return lhs.compare(rhs._swiftObject) == .orderedAscending
    }
}

extension NSDateInterval: Comparable {
    public static func < (lhs: NSDateInterval, rhs: NSDateInterval) -> Bool {
        return lhs.compare(rhs._swiftObject) == .orderedAscending
    }
}

extension NSDate: Comparable {
    public static func < (lhs: NSDate, rhs: NSDate) -> Bool {
        return lhs.compare(rhs._swiftObject) == .orderedAscending
    }
}

extension NSIndexPath: Comparable {
    public static func < (lhs: NSIndexPath, rhs: NSIndexPath) -> Bool {
        return lhs.compare(rhs._swiftObject) == .orderedAscending
    }
}
