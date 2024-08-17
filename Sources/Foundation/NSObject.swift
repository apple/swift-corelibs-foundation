// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

// @_exported import of Dispatch here makes it available to all
// classes in Foundation and all sources that import Foundation.
// This brings it into line with Darwin usage for compatibility.
#if !os(WASI)
@_exported import Dispatch
#endif

@_implementationOnly import CoreFoundation

/// The `NSObjectProtocol` groups methods that are fundamental to all Foundation objects.
///
/// If an object conforms to this protocol, it can be considered a first-class object.
/// 
/// The Cocoa root class, NSObject, adopts this protocol, so all objects inheriting
/// from NSObject have the features described by this protocol.
public protocol NSObjectProtocol: AnyObject {
    
    /// Returns a Boolean value that indicates whether the instance
    /// and a given `object` are equal.
    ///
    /// This method defines what it means for instances to be equal. For example, a container
    /// object might define two containers as equal if their corresponding objects all respond
    /// true to an `isEqual(_:)` request. See the `NSData`, `NSDictionary`, `NSArray`,
    /// and `NSString` class specifications for examples of the use of this method.
    ///
    /// If two objects are equal, they must have the same hash value.
    /// This last point is particularly important if you define `isEqual(_:)` in a subclass
    /// and intend to put instances of that subclass into a collection.
    /// Make sure you also define hash in your subclass.
    ///
    /// - Parameter object: The object to be compared to the instance.
    ///                     May be `nil`, in which case this method returns `false`.
    /// - Returns:          `true` if the instance and `object` are equal, otherwise `false`.
    func isEqual(_ object: Any?) -> Bool
    
    /// Returns an integer that can be used as a table address in a hash table structure.
    /// 
    /// If two objects are equal (as determined by the `isEqual(_:)` method),
    /// they must have the same hash value. This last point is particularly important
    /// if you define `hash` in a subclass and intend to put instances of that subclass
    /// into a collection.
    ///
    /// If a mutable object is added to a collection that uses hash values to determine
    /// the object’s position in the collection, the value returned by the `hash` property
    /// of the object must not change while the object is in the collection. Therefore, either
    /// the `hash` property must not rely on any of the object’s internal state information
    /// or you must make sure the object’s internal state information does not change while
    /// the object is in the collection. Thus, for example, a mutable dictionary can be put
    /// in a hash table but you must not change it while it is in there.
    /// (Note that it can be difficult to know whether or not a given object is in a collection.)
    var hash: Int { get }
    
    /// Returns the instance itself.
    ///
    /// - Returns: The instance itself.
    func `self`() -> Self
    
    /// Returns a Boolean value that indicates whether the instance does not descend from NSObject.
    ///
    /// - Returns: `false` if the instance really descends from `NSObject`, otherwise `true`.
    func isProxy() -> Bool

    /// Returns a string that describes the contents of the instance.
    var description: String { get }
    
    /// Returns a string that describes the contents of the instance for presentation
    /// in the debugger.
    var debugDescription: String { get }
}

extension NSObjectProtocol {
    
    public var debugDescription: String {
        return description
    }
}

@available(*, unavailable)
extension NSZone : @unchecked Sendable { }

public struct NSZone : ExpressibleByNilLiteral {
    
    public init() {
        
    }
    
    public init(nilLiteral: ()) {
        
    }
}

/// The `NSCopying` protocol declares a method for providing functional copies of an object.
/// The exact meaning of “copy” can vary from class to class, but a copy must be a functionally
/// independent object with values identical to the original at the time the copy was made.
///
/// NSCopying declares one method, `copy(with:)`, but copying is commonly invoked with the
/// convenience method `copy`. The copy method is defined for all objects inheriting from NSObject
/// and simply invokes `copy(with:)` with the `nil` zone.
///
/// If a subclass inherits `NSCopying` from its superclass and declares additional instance variables,
/// the subclass has to override `copy(with:)` to properly handle its own instance variables,
/// invoking the superclass’s implementation first.
public protocol NSCopying {
    
    /// Returns a new instance that’s a copy of the current one.
    ///
    /// - Parameter zone:   This parameter is ignored. Memory zones are no longer used.
    /// - Returns:          A new instance that’s a copy of the current one.
    func copy(with zone: NSZone?) -> Any
}

extension NSCopying {
    
    /// Returns a new instance that’s a copy of the current one.
    ///
    /// - Returns: A new instance that’s a copy of the current one.
    public func copy() -> Any {
        return copy(with: nil)
    }
}

/// The `NSMutableCopying` protocol declares a method for providing mutable
/// copies of an object. Only classes that define an “immutable vs. mutable” distinction
/// should adopt this protocol. Classes that don’t define such a distinction should
/// adopt `NSCopying` instead.
public protocol NSMutableCopying {
    
    /// Returns a new instance that’s a mutable copy of the current one.
    ///
    /// - Parameter zone:   This parameter is ignored. Memory zones are no longer used.
    /// - Returns:          A new instance that’s a mutable copy of the current one.
    func mutableCopy(with zone: NSZone?) -> Any
}

extension NSMutableCopying {
    
    /// Returns a new instance that’s a mutable copy of the current one.
    ///
    /// - Returns: A new instance that’s a mutable copy of the current one.
    public func mutableCopy() -> Any {
        return mutableCopy(with: nil)
    }
}

/// The root class of most Foundation class hierarchies.
//@_nonSendable - TODO: Mark with attribute to indicate this pure abstract class defers Sendable annotation to its subclasses.
open class NSObject : NSObjectProtocol, Equatable, Hashable {
    // Important: add no ivars here. It will subvert the careful layout of subclasses that bridge into CF.
    
    /// Implemented by subclasses to initialize a new object immediately after memory
    /// for it has been allocated.
    public init() {}
    
    /// Returns the object returned by `copy(with:)`.
    ///
    /// This is a convenience method for classes that adopt the `NSCopying` protocol.
    /// `NSObject` does not itself support the `NSCopying` protocol.
    /// Subclasses must support the protocol and implement the `copy(with:)` method.
    /// A subclass version of the `copy(with:)` method should invoke `super`'s method first,
    /// to incorporate its implementation, unless the subclass descends directly from `NSObject`.
    ///
    /// - Returns: The object returned by the `NSCopying` protocol method `copy(with:)`.
    open func copy() -> Any {
        if let copyable = self as? NSCopying {
            return copyable.copy(with: nil)
        }
        return self
    }
    
    /// Returns the object returned by `mutableCopy(with:)` where the zone is `nil.`
    ///
    /// This is a convenience method for classes that adopt the `NSMutableCopying` protocol.
    ///
    /// - Returns: The object returned by the `NSMutableCopying` protocol method
    ///            `mutableCopy(with:)`, where the zone is `nil`.
    open func mutableCopy() -> Any {
        if let copyable = self as? NSMutableCopying {
            return copyable.mutableCopy(with: nil)
        }
        return self
    }
    
    /// Returns a Boolean value that indicates whether the instance is equal to another given object.
    ///
    /// The default implementation for this method provided by `NSObject` returns `true` if
    /// the objects being compared refer to the same instance.
    ///
    /// - Parameter object: The object with which to compare the instance.
    /// - Returns:          `true` if the instance is equal to `object`, otherwise `false`.
    open func isEqual(_ object: Any?) -> Bool {
        guard let obj = object as? NSObject else { return false }
        return obj === self
    }
    
    /// Returns an integer that can be used as a table address in a hash table structure.
    ///
    /// If two objects are equal (as determined by the `isEqual(_:)` method),
    /// they must have the same hash value. This last point is particularly important
    /// if you define `hash` in a subclass and intend to put instances of that subclass
    /// into a collection.
    ///
    /// If a mutable object is added to a collection that uses hash values to determine
    /// the object’s position in the collection, the value returned by the `hash` property
    /// of the object must not change while the object is in the collection. Therefore, either
    /// the `hash` property must not rely on any of the object’s internal state information
    /// or you must make sure the object’s internal state information does not change while
    /// the object is in the collection. Thus, for example, a mutable dictionary can be put
    /// in a hash table but you must not change it while it is in there.
    /// (Note that it can be difficult to know whether or not a given object is in a collection.)
    open var hash: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    /// Returns the instance itself.
    ///
    /// - Returns: The instance itself.
    open func `self`() -> Self {
        return self
    }
    
    /// Returns a Boolean value that indicates whether the instance does not descend from NSObject.
    ///
    /// - Returns: `false` if the instance really descends from `NSObject`, otherwise `true`.
    open func isProxy() -> Bool {
        return false
    }
    
    /// Returns a string that describes the contents of the instance.
    open var description: String {
        return "<\(type(of: self)): \(Unmanaged.passUnretained(self).toOpaque())>"
    }
    
    /// Returns a string that describes the contents of the instance for presentation
    /// in the debugger.
    open var debugDescription: String {
        return description
    }
    
    internal var _cfTypeID: CFTypeID {
        return 0
    }
    
    // TODO: move these back into extensions once extension methods can be overridden
    
    /// Overridden by subclasses to substitute a class other than its own during coding.
    ///
    /// This property is needed for `NSCoder`.
    /// `NSObject`’s implementation returns the instance's class.
    /// The private subclasses of a class cluster substitute the name of their public
    /// superclass when being archived.
    open var classForCoder: AnyClass {
        return type(of: self)
    }
 
    /// Overridden by subclasses to substitute another object for itself during encoding.
    ///
    /// An object might encode itself into an archive, but encode a proxy for itself if
    /// it’s being encoded for distribution. This method is invoked by `NSCoder`.
    /// `NSObject`’s implementation returns `self`.
    ///
    /// - Parameter aCoder: The coder encoding the instance.
    /// - Returns:          The object encode instead of the instance (if different).
    open func replacementObject(for aCoder: NSCoder) -> Any? {
        return self
    }

    // TODO: Could perhaps be an extension of NSCoding instead.
    // The reason it is an extension of NSObject is the lack of default
    // implementations on protocols in Objective-C.
    
    /// Subclasses to substitute a new class for instances during keyed archiving.
    ///
    /// The object will be encoded as if it were a member of the class. This property is
    /// overridden by the encoder class and instance name to class encoding tables.
    /// If this property is `nil`, the result of this property is ignored.
    open var classForKeyedArchiver: AnyClass? {
        return self.classForCoder
    }
    
    /// Overridden by subclasses to substitute another object for itself during keyed archiving.
    ///
    /// This method is called only if no replacement mapping for the object has been set up
    /// in the encoder (for example, due to a previous call of `replacementObject(for:)` to that object).
    ///
    /// - Parameter archiver:   A keyed archiver creating an archive.
    /// - Returns:              The object encode instead of the instance (if different).
    open func replacementObject(for archiver: NSKeyedArchiver) -> Any? {
        return self.replacementObject(for: archiver as NSCoder)
    }
    
    /// Overridden to return the names of classes that can be used to decode
    /// objects if their class is unavailable.
    ///
    /// `NSKeyedArchiver` calls this method and stores the result inside the archive.
    /// If the actual class of an object doesn’t exist at the time of unarchiving,
    /// `NSKeyedUnarchiver` goes through the stored list of classes and uses the first one
    /// that does exists as a substitute class for decoding the object.
    /// The default implementation of this method returns empty array.
    ///
    /// You can use this method if you introduce a new class into your application to provide
    /// some backwards compatibility in case the archive will be read on a system that does not
    /// have that class. Sometimes there may be another class which may work nearly as well as
    /// a substitute for the new class, and the archive keys and archived state for the new class
    /// can be carefully chosen (or compatibility written out) so that the object can be unarchived
    /// as the substitute class if necessary.
    ///
    /// - Returns: An array of strings that specify the names of classes in preferred order for unarchiving.
    open class func classFallbacksForKeyedArchiver() -> [String] {
        return []
    }

    /// Overridden by subclasses to substitute a new class during keyed unarchiving.
    ///
    /// During keyed unarchiving, instances of the class will be decoded as members
    /// of the returned class. This method overrides the results of the decoder’s class
    /// and instance name to class encoding tables.
    ///
    /// - Returns: The class to substitute for the current class during keyed unarchiving.
    open class func classForKeyedUnarchiver() -> AnyClass {
        return self
    }

    /// The hash value.
    ///
    /// `NSObject` implements this by returning `self.hash`.
    ///
    /// `NSObject.hashValue` is not overridable; subclasses can customize hashing
    /// by overriding the `hash` property.
    ///
    /// **Axiom:** `x == y` implies `x.hashValue == y.hashValue`
    ///
    /// - Note: the hash value is not guaranteed to be stable across
    ///   different invocations of the same program.  Do not persist the
    ///   hash value across program runs.
    public final var hashValue: Int {
        return hash
    }

    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// NSObject implements this by feeding `self.hash` to the hasher.
    ///
    /// `NSObject.hash(into:)` is not overridable; subclasses can customize
    /// hashing by overriding the `hash` property.
    public final func hash(into hasher: inout Hasher) {
        hasher.combine(self.hash)
    }

    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func ==(lhs: NSObject, rhs: NSObject) -> Bool {
        return lhs.isEqual(rhs)
    }
    
    // Please note:
    // the following methods are not overridable in swift-corelibs-foundation.
    
    private class var nsObjectSuperclass: NSObject.Type? {
        // Pretend that {Swift,}Foundation.NSObject is the top of the class hierarchy.
        // On Darwin, avoids dipping into the class hierarchy that exists above this class,
        // which is ultimately rooted in the ObjC NSObject class.
        guard !(self == NSObject.self) else { return nil }
        return _getSuperclass(self) as? NSObject.Type
    }
    
    public class var superclass: AnyClass? {
        return nsObjectSuperclass
    }
    
    /// Returns a Boolean value that indicates whether the receiving
    /// class is a subclass of, or identical to, a given class.
    public class func isSubclass(of aClass: AnyClass) -> Bool {
        var checkedClass: NSObject.Type? = self
        while let thisClass = checkedClass {
            if thisClass === aClass {
                return true
            }
            checkedClass = thisClass.nsObjectSuperclass
        }
        
        return false
    }
    
    public func isMember(of aClass: AnyClass) -> Bool {
        return type(of: self) === aClass
    }
    
    public func isKind(of aClass: AnyClass) -> Bool {
        return type(of: self).isSubclass(of: aClass)
    }
}

extension NSObject : CustomDebugStringConvertible {
}

extension NSObject : CustomStringConvertible {
}
