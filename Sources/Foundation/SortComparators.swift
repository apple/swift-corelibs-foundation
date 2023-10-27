//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// The orderings that sorts can be performed with.
@frozen public enum SortOrder: Hashable, Codable, Sendable {
    /// The ordering where if compare(a, b) == .orderedAscending,
    /// a is placed before b.
    case forward

    /// The ordering where if compare(a, b) == .orderedAscending,
    /// a is placed after b.
    case reverse

    public init(from decoder: Decoder) throws {
        self = try decoder.singleValueContainer().decode(Bool.self) ? .forward : .reverse
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .forward: try container.encode(true)
        case .reverse: try container.encode(false)
        }
    }
}

public protocol SortComparator<Compared>: Hashable {
    /// The type that the `SortComparator` provides a comparison for.
    associatedtype Compared

    /// If the `SortComparator`s resulting order is forward or reverse.
    var order: SortOrder { get set }

    /// The relative ordering of lhs, and rhs.
    ///
    /// The result of comparisons should be flipped if the current `order`
    /// is `reverse`.
    ///
    /// If `compare(lhs, rhs)` is `.orderedAscending`, then `compare(rhs, lhs)`
    /// must be `.orderedDescending`. If `compare(lhs, rhs)` is
    /// `.orderedDescending`, then `compare(rhs, lhs)` must be
    /// `.orderedAscending`.
    ///
    /// - Parameters:
    ///     - lhs: A value to compare.
    ///     - rhs: A value to compare.
    func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult
}

extension Never: SortComparator {
    public typealias Compared = Never

    public var order: SortOrder {
        get { fatalError("unreachable") }
        set { fatalError("unreachable") }
    }

    public func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {}
}

extension Sequence {
    /// If `lhs` is ordered before `rhs` in the ordering described by the given
    /// sequence of `SortComparator`s
    ///
    /// The first element of the sequence of comparators specifies the primary
    /// comparator to be used in sorting the sequence's elements. Any subsequent
    /// comparators are used to further refine the order of elements with equal
    /// values.
    public func compare<Comparator>(_ lhs: Comparator.Compared, _ rhs: Comparator.Compared) -> ComparisonResult
    where Comparator: SortComparator, Comparator == Element
    {
        lazy
            .map({ $0.compare(lhs, rhs) })
            .first(where: { $0 != .orderedSame })
        ?? .orderedSame
    }
}

extension Sequence {
    /// Returns the elements of the sequence, sorted using the given comparator
    /// to compare elements.
    ///
    /// - Parameters:
    ///   - comparator: the comparator to use in ordering elements
    /// - Returns: an array of the elements sorted using `comparator`.
    public func sorted<Comparator>(using comparator: Comparator) -> Array<Element>
    where Comparator: SortComparator, Element == Comparator.Compared
    {
        sorted(by: { comparator.compare($0, $1) == .orderedAscending })
    }

    /// Returns the elements of the sequence, sorted using the given array of
    /// `SortComparator`s to compare elements.
    ///
    /// - Parameters:
    ///   - comparators: an array of comparators used to compare elements. The
    ///   first comparator specifies the primary comparator to be used in
    ///   sorting the sequence's elements. Any subsequent comparators are used
    ///   to further refine the order of elements with equal values.
    /// - Returns: an array of the elements sorted using `comparators`.
    public func sorted<S, Comparator>(using comparators: S) -> Array<Element>
    where S: Sequence, Comparator: SortComparator, Comparator == S.Element, Element == Comparator.Compared
    {
        sorted(by: { comparators.compare($0, $1) == .orderedAscending })
    }
}

extension MutableCollection where Self: RandomAccessCollection {
    /// Sorts the collection using the given comparator to compare elements.
    /// - Parameters:
    ///     - comparator: the sort comparator used to compare elements.
    public mutating func sort<Comparator>(using comparator: Comparator)
    where Comparator: SortComparator, Element == Comparator.Compared {
        sort(by: { comparator.compare($0, $1) == .orderedAscending })
    }

    /// Sorts the collection using the given array of `SortComparator`s to
    /// compare elements.
    ///
    /// - Parameters:
    ///   - comparators: an array of comparators used to compare elements. The
    ///   first comparator specifies the primary comparator to be used in
    ///   sorting the sequence's elements. Any subsequent comparators are used
    ///   to further refine the order of elements with equal values.
    public mutating func sort<S, Comparator>(using comparators: S)
    where S: Sequence, Comparator: SortComparator, Comparator == S.Element, Element == Comparator.Compared
    {
        sort(by: { comparators.compare($0, $1) == .orderedAscending })
    }
}

/// Compares `Comparable` types using their comparable implementation.
public struct ComparableComparator<Compared>: SortComparator, Sendable where Compared: Comparable {
    public var order: SortOrder

    public func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
        guard lhs != rhs else { return .orderedSame }
        switch order {
        case .forward: return lhs < rhs ? .orderedAscending : .orderedDescending
        case .reverse: return lhs > rhs ? .orderedAscending : .orderedDescending
        }
    }
}

struct OptionalComparator<Base: SortComparator>: SortComparator {
    typealias Compared = Optional<Base.Compared>

    var base: Base

    var order: SortOrder {
        get { base.order }
        set { base.order = newValue }
    }

    func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
        switch (lhs, rhs) {
        case (.none, .none): return .orderedSame
        case (.none, .some(_)):
            return order == .forward ? .orderedAscending : .orderedDescending
        case (.some(_), .none):
            return order == .forward ? .orderedDescending : .orderedAscending
        case (.some(let lhsUnwrapped), .some(let rhsUnwrapped)):
            return base.compare(lhsUnwrapped, rhsUnwrapped)
        }
    }
}

extension OptionalComparator: Sendable where Base: Sendable {}

extension OptionalComparator: Encodable where Base: Encodable {
    func encode(to encoder: Encoder) throws {
        try base.encode(to: encoder)
    }
}

extension OptionalComparator: Decodable where Base: Decodable {
    init(from decoder: Decoder) throws {
        base = try .init(from: decoder)
    }
}

extension String {
    /// Compares `String`s using one of a fixed set of standard comparison
    /// algorithms.
    public struct StandardComparator: SortComparator, Codable/*, Sendable*/ {
        private enum CodingKeys: String, CodingKey {
            case options, isLocalized, order
        }

        public typealias Compared = String

        /// Compares `String`s as compared by the Finder.
        ///
        /// Uses a localized, numeric comparison in the current locale.
        ///
        /// The default `SortComparator` used in `String` comparisons.
        public static let localizedStandard = String.StandardComparator(
            options: .init(rawValue: 833), // raw value taken from Foundation
            isLocalized: true,
            order: .forward
        )

        /// Compares `String`s using a localized comparison in the current
        /// locale.
        public static let localized = String.StandardComparator(
            options: [],
            isLocalized: true,
            order: .forward
        )

        /// Compares `String`s lexically.
        public static let lexical = String.StandardComparator(
            options: [],
            isLocalized: false,
            order: .forward
        )

        fileprivate let options: String.CompareOptions
        fileprivate let isLocalized: Bool

        public var order: SortOrder

        private init(options: String.CompareOptions, isLocalized: Bool, order: SortOrder) {
            self.options = options
            self.isLocalized = isLocalized
            self.order = order
        }

        /// Create a `StandardComparator` from the given `StandardComparator`
        /// with the given new `order`.
        ///
        /// - Parameters:
        ///     - base: The standard comparator to modify the order of.
        ///     - order: The initial order of the new `StandardComparator`.
        public init(_ comparator: StandardComparator, order: SortOrder) {
            self.init(options: comparator.options, isLocalized: comparator.isLocalized, order: order)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            options = try .init(rawValue: container.decode(String.CompareOptions.RawValue.self, forKey: .options))
            isLocalized = try container.decode(Bool.self, forKey: .isLocalized)
            order = try container.decode(SortOrder.self, forKey: .order)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(options.rawValue, forKey: .options)
            try container.encode(isLocalized, forKey: .isLocalized)
            try container.encode(order, forKey: .order)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(options.rawValue)
            hasher.combine(isLocalized)
            hasher.combine(order)
        }

        public func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
            let result = lhs.compare(rhs, options: options, locale: isLocalized ? .current : nil)
            guard order == .reverse else { return result }
            switch result {
            case .orderedSame: return .orderedSame
            case .orderedAscending: return .orderedDescending
            case .orderedDescending: return .orderedAscending
            }
        }
    }

    /// A `String` comparison performed using the given comparison options
    /// and locale.
    public struct Comparator: SortComparator, Codable/*, Sendable*/ {
        private enum CodingKeys: String, CodingKey {
            case options, locale, order
        }

        public typealias Compared = String

        /// The options to use for comparison.
        public let options: String.CompareOptions

        /// The locale to use for comparison if the comparator is localized,
        /// otherwise nil.
        public let locale: Locale?

        public var order: SortOrder

        /// Creates a `String.Comparator` with the given `CompareOptions` and
        /// `Locale`.
        ///
        /// - Parameters:
        ///     - options: The options to use for comparison.
        ///     - locale: The locale to use for comparison. If `nil`, the
        ///       comparison is unlocalized.
        ///     - order: The initial order to use for ordered comparison.
        public init(options: String.CompareOptions,
                    locale: Locale? = .current,
                    order: SortOrder = .forward) {
            self.options = options
            self.locale = locale
            self.order = order
        }

        /// Creates a `String.Comparator` that represents the same comparison
        /// as the given `String.StandardComparator`.
        ///
        /// - Parameters:
        ///    - standardComparison: The `String.StandardComparator` to convert.
        public init(_ standardComparison: StandardComparator) {
            self.init(options: standardComparison.options,
                      // locale seems to be ignored by Darwin Foundation
//                      locale: standardComparison.isLocalized ? .current : nil,
                      order: standardComparison.order)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            options = try .init(rawValue: container.decode(String.CompareOptions.RawValue.self, forKey: .options))
            locale = try container.decodeIfPresent(Locale.self, forKey: .locale)
            order = try container.decode(SortOrder.self, forKey: .order)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(options.rawValue, forKey: .options)
            try container.encodeIfPresent(locale, forKey: .locale)
            try container.encode(order, forKey: .order)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(options.rawValue)
            hasher.combine(locale)
            hasher.combine(order)
        }

        public func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
            let result = lhs.compare(rhs, options: options, locale: locale)
            guard order == .reverse else { return result }
            switch result {
            case .orderedSame: return .orderedSame
            case .orderedAscending: return .orderedDescending
            case .orderedDescending: return .orderedAscending
            }
        }
    }
}

extension SortComparator where Self == String.Comparator {
    /// Compares `String`s as compared by the Finder.
    ///
    /// Uses a localized, numeric comparison in the current locale.
    ///
    /// The default `String.Comparator` used in `String` comparisons.
    public static var localizedStandard: String.Comparator {
        String.Comparator(.localizedStandard)
    }

    /// Compares `String`s using a localized comparison in the current
    /// locale.
    public static var localized: String.Comparator {
        String.Comparator(.localized)
    }
}

fileprivate struct AnySortCompartor: SortComparator {
    private var _base: Any
    private var hashableBase: AnyHashable

    private let _compare: (Any, Any, Any) -> ComparisonResult
    private let getOrder: (Any) -> SortOrder
    private let setOrder: (inout Any, SortOrder) -> AnyHashable

    var order: SortOrder {
        get { getOrder(_base) }
        set { hashableBase = setOrder(&_base, newValue) }
    }

    init<Base: SortComparator>(erasing base: Base) {
        _base = base
        hashableBase = .init(base)
        _compare = { ($0 as! Base).compare($1 as! Base.Compared, $2 as! Base.Compared) }
        getOrder = { ($0 as! Base).order }
        setOrder = {
            var base = $0 as! Base
            base.order = $1
            $0 = base
            return .init(base)
        }
    }

    func compare(_ lhs: Any, _ rhs: Any) -> ComparisonResult {
        _compare(_base, lhs, rhs)
    }

    func hash(into hasher: inout Hasher) {
        hashableBase.hash(into: &hasher)
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.hashableBase == rhs.hashableBase
    }
}

/// Compares elements using a `KeyPath`, and a `SortComparator` which compares
/// elements of the `KeyPath`s `Value` type.
public struct KeyPathComparator<Compared>: SortComparator {
    /// The key path to the property to be used for comparisons.
    public let keyPath: PartialKeyPath<Compared>

    private var comparator: AnySortCompartor
    private let extractField: (Compared) -> Any

    public var order: SortOrder {
        get { comparator.order }
        set { comparator.order = newValue }
    }

    /// Creates a `KeyPathComparator` that orders values based on a property
    /// that conforms to the `Comparable` protocol.
    ///
    /// The underlying field comparison uses `ComparableComparator<Value>()`
    /// unless the keyPath points to a `String` in which case the default string
    /// comparator, `String.StandardComparator.localizedStandard`, will be used.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init<Value>(_ keyPath: KeyPath<Compared, Value>, order: SortOrder = .forward) where Value: Comparable {
        self.keyPath = keyPath
        if Value.self == String.self {
            self.comparator = .init(erasing: String.StandardComparator(.localizedStandard, order: order))
        } else {
            self.comparator = .init(erasing: ComparableComparator<Value>(order: order))
        }
        self.extractField = { $0[keyPath: keyPath] }
    }

    /// Creates a `KeyPathComparator` that orders values based on an optional
    /// property whose wrapped value conforms to the `Comparable` protocol.
    ///
    /// The resulting `KeyPathComparator` orders `nil` values first when in
    /// `forward` order.
    ///
    /// The underlying field comparison uses `ComparableComparator<Value>()`
    /// unless the keyPath points to a `String` in which case the default string
    /// comparator, `String.StandardComparator.localizedStandard`, will be used.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init<Value>(_ keyPath: KeyPath<Compared, Value?>, order: SortOrder = .forward) where Value: Comparable {
        self.keyPath = keyPath
        if Value.self == String.self {
            self.comparator = .init(erasing: OptionalComparator(base: String.StandardComparator(.localizedStandard, order: order)))
        } else {
            self.comparator = .init(erasing: OptionalComparator(base: ComparableComparator<Value>(order: order)))
        }
        self.extractField = { $0[keyPath: keyPath] as Any }
    }

    /// Creates a `KeyPathComparator` with the given `keyPath` and
    /// `SortComparator`.
    ///
    /// `comparator.order` is used for the initial `order` of the created
    /// `KeyPathComparator`.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the value used for the comparison.
    ///   - comparator: The `SortComparator` used to order values.
    public init<Value, Comparator>(_ keyPath: KeyPath<Compared, Value>, comparator: Comparator)
    where Value == Comparator.Compared, Comparator: SortComparator
    {
        self.keyPath = keyPath
        self.comparator = .init(erasing: comparator)
        self.extractField = { $0[keyPath: keyPath] }
    }

    /// Creates a `KeyPathComparator` with the given `keyPath` to an optional
    /// value and `SortComparator`.
    ///
    /// The resulting `KeyPathComparator` orders `nil` values first when in
    /// `forward` order.
    ///
    /// `comparator.order` is used for the initial `order` of the created
    /// `KeyPathComparator`.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the value used for the comparison.
    ///   - comparator: The `SortComparator` used to order values.
    public init<Value, Comparator>(_ keyPath: KeyPath<Compared, Value?>, comparator: Comparator)
    where Value == Comparator.Compared, Comparator: SortComparator
    {
        self.keyPath = keyPath
        self.comparator = .init(erasing: OptionalComparator(base: comparator))
        self.extractField = { $0[keyPath: keyPath] as Any }
    }

    /// Creates a `KeyPathComparator` with the given `keyPath`,
    /// `SortComparator`, and initial order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the value used for the comparison.
    ///   - comparator: The `SortComparator` used to order values.
    ///   - order: The initial order to use for comparison.
    public init<Value, Comparator>(_ keyPath: KeyPath<Compared, Value>, comparator: Comparator, order: SortOrder)
    where Value == Comparator.Compared, Comparator: SortComparator
    {
        var newComparator = comparator
        newComparator.order = order
        self.keyPath = keyPath
        self.comparator = .init(erasing: newComparator)
        self.extractField = { $0[keyPath: keyPath] }
    }

    /// Creates a `KeyPathComparator` with the given `keyPath`,
    /// `SortComparator`, and initial order.
    ///
    ///  The resulting `KeyPathComparator` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the value used for the comparison.
    ///   - comparator: The `SortComparator` used to order values.
    ///   - order: The initial order to use for comparison.
    public init<Value, Comparator>(_ keyPath: KeyPath<Compared, Value?>, comparator: Comparator, order: SortOrder)
    where Value == Comparator.Compared, Comparator: SortComparator
    {
        var newComparator = comparator
        newComparator.order = order
        self.keyPath = keyPath
        self.comparator = .init(erasing: OptionalComparator(base: newComparator))
        self.extractField = { $0[keyPath: keyPath] as Any }
    }

    public func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
        comparator.compare(extractField(lhs), extractField(rhs))
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
        hasher.combine(comparator)
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.keyPath == rhs.keyPath && lhs.comparator == rhs.comparator
    }
}

// In swift-corelibs-foundation, key-value coding is not available. Since encoding and decoding a SortDescriptor requires interpreting key paths, SortDescriptor does not conform to Encodable and Decodable in swift-corelibs-foundation only.
public struct SortDescriptor<Compared>: SortComparator/*, Sendable*/ {
    fileprivate let nsSortDescriptor: NSSortDescriptor

    public var order: SortOrder

    /// Creates a `SortDescriptor` that orders values based on a `Bool`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Bool>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true, typedComparator: { boolA, boolB in
            if boolA && !boolB {
                return .orderedAscending
            } else if !boolA && boolB {
                return .orderedDescending
            } else {
                return .orderedSame
            }
        })
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Bool?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Bool?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true, typedComparator: { boolA, boolB in
            if boolA && !boolB {
                return .orderedAscending
            } else if !boolA && boolB {
                return .orderedDescending
            } else {
                return .orderedSame
            }
        })
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Double`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Double>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Double?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Double?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Float`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Float>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Float?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Float?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int8`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int8>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int8?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int8?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int16`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int16>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int16?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int16?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int32`
    /// property
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int32>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int32?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int32?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int64`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int64>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int64?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int64?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt8`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt8>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt8?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt8?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt16`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt16>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt16?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt16?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt32`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt32>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt32?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt32?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt64`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt64>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt64?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt64?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Date`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Date>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `Date?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Date?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UUID`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UUID>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath.appending(path: \.uuidString), ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values based on a `UUID?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UUID?>, order: SortOrder = .forward)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath.appending(path: \.?.uuidString), ascending: true)
        self.order = order
    }

    /// Creates a `SortDescriptor` that orders values using the given
    /// standard string comparator.
    ///
    /// `comparator.order` is used for the initial `order` of the
    /// created `SortDescriptor`.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    public init(_ keyPath: KeyPath<Compared, String>, comparator: String.StandardComparator = .localizedStandard)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true, typedComparator: { stringA, stringB in
            comparator.compare(stringA, stringB)
        })
        self.order = comparator.order
    }

    /// Creates a `SortDescriptor` that orders optional values using the given
    /// standard string comparator.
    ///
    /// `comparator.order` is used for the initial `order` of the
    /// created `SortDescriptor`.
    ///
    ///  The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    public init(_ keyPath: KeyPath<Compared, String?>, comparator: String.StandardComparator = .localizedStandard)
    where Compared: NSObject
    {
        self.nsSortDescriptor = .init(keyPath: keyPath, ascending: true, typedComparator: { stringA, stringB in
            comparator.compare(stringA, stringB)
        })
        self.order = comparator.order
    }

    /// Creates a `SortDescriptor` that orders values using the given
    /// standard string comparator with the given initial order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, String>, comparator: String.StandardComparator = .localizedStandard, order: SortOrder)
    where Compared: NSObject
    {
        self.init(keyPath, comparator: .init(comparator, order: order))
    }

    /// Creates a `SortDescriptor` that orders optional values using the given
    /// standard string comparator with the given initial order.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, String?>, comparator: String.StandardComparator = .localizedStandard, order: SortOrder)
    where Compared: NSObject
    {
        self.init(keyPath, comparator: .init(comparator, order: order))
    }

    /// Creates a `SortDescriptor` describing the same sort as the
    /// `NSSortDescriptor` over the given `Compared` type.
    ///
    /// Returns `nil` if there is no `SortDescriptor` equivalent to the given
    /// `NSSortDescriptor`, or if the `NSSortDescriptor`s selector is not one of
    /// the standard string comparison algorithms, or `compare(_:)`.
    ///
    /// The comparison for the created `SortDescriptor` uses the
    /// `NSSortDescriptor`s associated selector directly, so in cases where
    /// using the `NSSortDescriptor`s comparison would crash, the
    /// `SortDescriptor`s comparison will as well.
    ///
    /// - Parameters:
    ///     - descriptor: The `NSSortDescriptor` to convert.
    ///     - comparedType: The type the resulting `SortDescriptor` compares.
    public init?(_ descriptor: NSSortDescriptor, comparing comparedType: Compared.Type)
    where Compared: NSObject
    {
        nsSortDescriptor = .init(_sortDescriptor: descriptor, ascending: true)
        order = descriptor.ascending ? .forward : .reverse
    }

    public func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
        let result = nsSortDescriptor.compare(lhs, to: rhs)
        guard order == .reverse else { return result }
        switch result {
        case .orderedSame: return .orderedSame
        case .orderedAscending: return .orderedDescending
        case .orderedDescending: return .orderedAscending
        }
    }
}

extension NSSortDescriptor {
    /// Creates an `NSSortDescriptor` representing the same sort as the given
    /// `SortDescriptor`.
    ///
    /// - Parameters:
    ///     - sortDescriptor: The `SortDescriptor` to convert.
    public convenience init<T>(_ sortDescriptor: SortDescriptor<T>) {
        self.init(_sortDescriptor: sortDescriptor.nsSortDescriptor,
                  ascending: sortDescriptor.order == .forward)
    }
}
