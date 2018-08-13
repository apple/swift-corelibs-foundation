// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


import CoreFoundation

open class NSSet : NSObject, NSCopying, NSMutableCopying, NSSecureCoding, NSCoding {
    private let _cfinfo = _CFInfo(typeID: CFSetGetTypeID())
    internal var _storage: Set<NSObject>
    
    open var count: Int {
        guard type(of: self) === NSSet.self || type(of: self) === NSMutableSet.self || type(of: self) === NSCountedSet.self else {
            NSRequiresConcreteImplementation()
        }
        return _storage.count
    }
    
    open func member(_ object: Any) -> Any? {
        guard type(of: self) === NSSet.self || type(of: self) === NSMutableSet.self || type(of: self) === NSCountedSet.self else {
            NSRequiresConcreteImplementation()
        }
        let value = _SwiftValue.store(object)
        guard let idx = _storage.index(of: value) else { return nil }
        return _storage[idx]
    }
    
    open func objectEnumerator() -> NSEnumerator {
        guard type(of: self) === NSSet.self || type(of: self) === NSMutableSet.self || type(of: self) === NSCountedSet.self else {
            NSRequiresConcreteImplementation()
        }
        return NSGeneratorEnumerator(_storage.map { _SwiftValue.fetch(nonOptional: $0) }.makeIterator())
    }

    public convenience override init() {
        self.init(objects: [], count: 0)
    }
    
    public init(objects: UnsafePointer<AnyObject>!, count cnt: Int) {
        _storage = Set(minimumCapacity: cnt)
        super.init()
        let buffer = UnsafeBufferPointer(start: objects, count: cnt)
        for obj in buffer {
            _storage.insert(_SwiftValue.store(obj))
        }
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        if type(of: aDecoder) == NSKeyedUnarchiver.self || aDecoder.containsValue(forKey: "NS.objects") {
            let objects = aDecoder._decodeArrayOfObjectsForKey("NS.objects")
            self.init(array: objects as! [NSObject])
        } else {
            var objects = [AnyObject]()
            var count = 0
            while let object = aDecoder.decodeObject(forKey: "NS.object.\(count)") {
                objects.append(object as! NSObject)
                count += 1
            }
            self.init(array: objects)
        }
    }
    
    open func encode(with aCoder: NSCoder) {
        // The encoding of a NSSet is identical to the encoding of an NSArray of its contents
        self.allObjects._nsObject.encode(with: aCoder)
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        if type(of: self) === NSSet.self {
            // return self for immutable type
            return self
        } else if type(of: self) === NSMutableSet.self {
            let set = NSSet()
            set._storage = self._storage
            return set
        }
        return NSSet(array: self.allObjects)
    }
    
    open override func mutableCopy() -> Any {
        return mutableCopy(with: nil)
    }

    open func mutableCopy(with zone: NSZone? = nil) -> Any {
        if type(of: self) === NSSet.self || type(of: self) === NSMutableSet.self {
            // always create and return an NSMutableSet
            let mutableSet = NSMutableSet()
            mutableSet._storage = self._storage
            return mutableSet
        }
        return NSMutableSet(array: self.allObjects)
    }

    public static var supportsSecureCoding: Bool {
        return true
    }
    
    open func description(withLocale locale: Locale?) -> String { 
      // NSUnimplemented() 
      return description
    }
    
    override open var _cfTypeID: CFTypeID {
        return CFSetGetTypeID()
    }

    open override func isEqual(_ value: Any?) -> Bool {
        switch value {
        case let other as Set<AnyHashable>:
            return isEqual(to: other)
        case let other as NSSet:
            return isEqual(to: Set._unconditionallyBridgeFromObjectiveC(other))
        default:
            return false
        }
    }

    open override var hash: Int {
        return self.count
    }

    public convenience init(array: [Any]) {
        let buffer = UnsafeMutablePointer<AnyObject>.allocate(capacity: array.count)
        for (idx, element) in array.enumerated() {
            buffer.advanced(by: idx).initialize(to: _SwiftValue.store(element))
        }
        self.init(objects: buffer, count: array.count)
        buffer.deinitialize(count: array.count)
        buffer.deallocate()
    }

    public convenience init(set: Set<AnyHashable>) {
        self.init(set: set, copyItems: false)
    }

    public convenience init(set: Set<AnyHashable>, copyItems flag: Bool) {
        if flag {
            self.init(array: set.map {
                if let item = $0 as? NSObject {
                    return item.copy()
                } else {
                    return $0
                }
            })
        } else {
            self.init(array: Array(set))
        }
    }
}

extension NSSet {
    
    public convenience init(object: Any) {
        self.init(array: [object])
    }
}

extension NSSet {
    
    open var allObjects: [Any] {
        if type(of: self) === NSSet.self || type(of: self) === NSMutableSet.self {
            return _storage.map { _SwiftValue.fetch(nonOptional: $0) }
        } else {
            let enumerator = objectEnumerator()
            var items = [Any]()
            while let val = enumerator.nextObject() {
                items.append(val)
            }
            return items
        }
    }
    
    open func anyObject() -> Any? {
        return objectEnumerator().nextObject()
    }
    
    open func contains(_ anObject: Any) -> Bool {
        return member(anObject) != nil
    }
    
    open func intersects(_ otherSet: Set<AnyHashable>) -> Bool {
        if count < otherSet.count {
            for item in self {
                if otherSet.contains(item as! AnyHashable) {
                    return true
                }
            }
            return false
        } else {
            return otherSet.contains { obj in contains(obj) }
        }
    }
    
    open func isEqual(to otherSet: Set<AnyHashable>) -> Bool {
        return count == otherSet.count && isSubset(of: otherSet)
    }
    
    open func isSubset(of otherSet: Set<AnyHashable>) -> Bool {
        // `true` if we don't contain any object that `otherSet` doesn't contain.
        for item in self {
            if !otherSet.contains(item as! AnyHashable) {
                return false
            }
        }
        return true
    }

    open func adding(_ anObject: Any) -> Set<AnyHashable> {
        return self.addingObjects(from: [anObject])
    }
    
    open func addingObjects(from other: Set<AnyHashable>) -> Set<AnyHashable> {
        var result = Set<AnyHashable>(minimumCapacity: Swift.max(count, other.count))
        if type(of: self) === NSSet.self || type(of: self) === NSMutableSet.self {
            result.formUnion(_storage.map { _SwiftValue.fetch(nonOptional: $0) as! AnyHashable })
        } else {
            for case let obj as NSObject in self {
                _ = result.insert(obj)
            }
        }
        return result.union(other)
    }
    
    open func addingObjects(from other: [Any]) -> Set<AnyHashable> {
        var result = Set<AnyHashable>(minimumCapacity: count)
        if type(of: self) === NSSet.self || type(of: self) === NSMutableSet.self {
            result.formUnion(_storage.map { _SwiftValue.fetch(nonOptional: $0) as! AnyHashable })
        } else {
            for case let obj as AnyHashable in self {
                result.insert(obj)
            }
        }
        for case let obj as AnyHashable in other {
            result.insert(obj)
        }
        return result
    }

    open func enumerateObjects(_ block: (Any, UnsafeMutablePointer<ObjCBool>) -> Swift.Void) {
        enumerateObjects(options: [], using: block)
    }
    
    open func enumerateObjects(options opts: NSEnumerationOptions = [], using block: (Any, UnsafeMutablePointer<ObjCBool>) -> Swift.Void) {
        var stop : ObjCBool = false
        for obj in self {
            withUnsafeMutablePointer(to: &stop) { stop in
                block(obj, stop)
            }
            if stop.boolValue {
                break
            }
        }
    }

    open func objects(passingTest predicate: (Any, UnsafeMutablePointer<ObjCBool>) -> Bool) -> Set<AnyHashable> {
        return objects(options: [], passingTest: predicate)
    }
    
    open func objects(options opts: NSEnumerationOptions = [], passingTest predicate: (Any, UnsafeMutablePointer<ObjCBool>) -> Bool) -> Set<AnyHashable> {
        var result = Set<AnyHashable>()
        enumerateObjects(options: opts) { obj, stopp in
            if predicate(obj, stopp) {
                result.insert(obj as! AnyHashable)
            }
        }
        return result
    }
}

extension NSSet : _CFBridgeable, _SwiftBridgeable {
    internal var _cfObject: CFSet { return unsafeBitCast(self, to: CFSet.self) }
    internal var _swiftObject: Set<NSObject> { return Set._unconditionallyBridgeFromObjectiveC(self) }
}

extension CFSet : _NSBridgeable, _SwiftBridgeable {
    internal var _nsObject: NSSet { return unsafeBitCast(self, to: NSSet.self) }
    internal var _swiftObject: Set<NSObject> { return _nsObject._swiftObject }
}

extension NSMutableSet {
    internal var _cfMutableObject: CFMutableSet { return unsafeBitCast(self, to: CFMutableSet.self) }
}

extension Set : _NSBridgeable, _CFBridgeable {
    internal var _nsObject: NSSet { return _bridgeToObjectiveC() }
    internal var _cfObject: CFSet { return _nsObject._cfObject }
}

extension NSSet : _HasCustomAnyHashableRepresentation {
  public func _toCustomAnyHashable() -> AnyHashable? {
    return AnyHashable(self as! Set<AnyHashable>)
  }
}

extension NSSet : Sequence {
    public typealias Iterator = NSEnumerator.Iterator
    public func makeIterator() -> Iterator {
        return self.objectEnumerator().makeIterator()
    }
}

extension NSSet : CustomReflectable {
    public var customMirror: Mirror { NSUnimplemented() }
}

open class NSMutableSet : NSSet {
    
    open func add(_ object: Any) {
        guard type(of: self) === NSMutableSet.self else {
            NSRequiresConcreteImplementation()
        }
        _storage.insert(_SwiftValue.store(object))
    }
    
    open func remove(_ object: Any) {
        guard type(of: self) === NSMutableSet.self else {
            NSRequiresConcreteImplementation()
        }

        _storage.remove(_SwiftValue.store(object))
    }
    
    override public init(objects: UnsafePointer<AnyObject>!, count cnt: Int) {
        super.init(objects: objects, count: cnt)
    }

    public convenience init() {
        self.init(capacity: 0)
    }
    
    public required init(capacity numItems: Int) {
        super.init(objects: [], count: 0)
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        NSUnimplemented()
    }
    
    open func addObjects(from array: [Any]) {
        if type(of: self) === NSMutableSet.self {
            for case let obj in array {
                _storage.insert(_SwiftValue.store(obj))
            }
        } else {
            array.forEach(add)
        }
    }
    
    open func intersect(_ otherSet: Set<AnyHashable>) {
        if type(of: self) === NSMutableSet.self {
            _storage.formIntersection(otherSet.map { _SwiftValue.store($0) })
        } else {
            for obj in self {
                if !otherSet.contains(obj as! AnyHashable) {
                    remove(obj)
                }
            }
        }
    }
    
    open func minus(_ otherSet: Set<AnyHashable>) {
        if type(of: self) === NSMutableSet.self {
            _storage.subtract(otherSet.map { _SwiftValue.store($0) })
        } else {
            otherSet.forEach(remove)
        }
    }
    
    open func removeAllObjects() {
        if type(of: self) === NSMutableSet.self {
            _storage.removeAll()
        } else {
            forEach(remove)
        }
    }
    
    open func union(_ otherSet: Set<AnyHashable>) {
        if type(of: self) === NSMutableSet.self {
            _storage.formUnion(otherSet.map { _SwiftValue.store($0) })
        } else {
            otherSet.forEach(add)
        }
    }
    
    open func setSet(_ otherSet: Set<AnyHashable>) {
        if type(of: self) === NSMutableSet.self {
            _storage = Set(otherSet.map { _SwiftValue.store($0) })
        } else {
            removeAllObjects()
            union(otherSet)
        }
    }

}

/****************	Counted Set	****************/
open class NSCountedSet : NSMutableSet {
    internal var _table: Dictionary<NSObject, Int>

    public required init(capacity numItems: Int) {
        _table = Dictionary<NSObject, Int>()
        super.init(capacity: numItems)
    }

    public  convenience init() {
        self.init(capacity: 0)
    }

    public convenience init(array: [Any]) {
        self.init(capacity: array.count)
        for object in array {
            let value = _SwiftValue.store(object)
            if let count = _table[value] {
                _table[value] = count + 1
            } else {
                _table[value] = 1
                _storage.insert(value)
            }
        }
    }

    public convenience init(set: Set<AnyHashable>) {
        self.init(array: Array(set))
    }

    public required convenience init?(coder: NSCoder) { NSUnimplemented() }

    open override func copy(with zone: NSZone? = nil) -> Any {
        if type(of: self) === NSCountedSet.self {
            let countedSet = NSCountedSet()
            countedSet._storage = self._storage
            countedSet._table = self._table
            return countedSet
        }
        return NSCountedSet(array: self.allObjects)
    }

    open override func mutableCopy(with zone: NSZone? = nil) -> Any {
        if type(of: self) === NSCountedSet.self {
            let countedSet = NSCountedSet()
            countedSet._storage = self._storage
            countedSet._table = self._table
            return countedSet
        }
        return NSCountedSet(array: self.allObjects)
    }

    open func count(for object: Any) -> Int {
        guard type(of: self) === NSCountedSet.self else {
            NSRequiresConcreteImplementation()
        }
        let value = _SwiftValue.store(object)
        guard let count = _table[value] else {
            return 0
        }
        return count
    }

    open override func add(_ object: Any) {
        guard type(of: self) === NSCountedSet.self else {
            NSRequiresConcreteImplementation()
        }
        let value = _SwiftValue.store(object)
        if let count = _table[value] {
            _table[value] = count + 1
        } else {
            _table[value] = 1
            _storage.insert(value)
        }
    }

    open override func remove(_ object: Any) {
        guard type(of: self) === NSCountedSet.self else {
            NSRequiresConcreteImplementation()
        }
        let value = _SwiftValue.store(object)
        guard let count = _table[value] else {
            return
        }

        if count > 1 {
            _table[value] = count - 1
        } else {
            _table[value] = nil
            _storage.remove(value)
        }
    }

    open override func removeAllObjects() {
        if type(of: self) === NSCountedSet.self {
            _storage.removeAll()
            _table.removeAll()
        } else {
            forEach(remove)
        }
    }
}

extension NSSet : _StructTypeBridgeable {
    public typealias _StructType = Set<AnyHashable>
    
    public func _bridgeToSwift() -> _StructType {
        return _StructType._unconditionallyBridgeFromObjectiveC(self)
    }
}
