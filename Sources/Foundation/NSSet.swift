// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


@_implementationOnly import CoreFoundation

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
        let value = __SwiftValue.store(object)
        guard let idx = _storage.firstIndex(of: value) else { return nil }
        return _storage[idx]
    }
    
    open func objectEnumerator() -> NSEnumerator {
        guard type(of: self) === NSSet.self || type(of: self) === NSMutableSet.self || type(of: self) === NSCountedSet.self else {
            NSRequiresConcreteImplementation()
        }
        return NSGeneratorEnumerator(_storage.map { __SwiftValue.fetch(nonOptional: $0) }.makeIterator())
    }

    public convenience override init() {
        self.init(objects: [], count: 0)
    }
    
    public init(objects: UnsafePointer<AnyObject>!, count cnt: Int) {
        _storage = Set(minimumCapacity: cnt)
        super.init()
        let buffer = UnsafeBufferPointer(start: objects, count: cnt)
        for obj in buffer {
            _storage.insert(__SwiftValue.store(obj))
        }
    }

    public convenience init(array: [Any]) {
        let buffer = UnsafeMutablePointer<AnyObject>.allocate(capacity: array.count)
        for (idx, element) in array.enumerated() {
            buffer.advanced(by: idx).initialize(to: __SwiftValue.store(element))
        }
        self.init(objects: buffer, count: array.count)
        buffer.deinitialize(count: array.count)
        buffer.deallocate()
    }

    public convenience init(set: Set<AnyHashable>) {
        self.init(set: set, copyItems: false)
    }

    public convenience init(set anSet: NSSet) {
        self.init(array: anSet.allObjects)
    }

    public convenience init(set: Set<AnyHashable>, copyItems flag: Bool) {
        if flag {
            self.init(array: set.map{ ($0 as NSObject).copy() })
        } else {
            self.init(array: Array(set))
        }
    }

    public convenience init(object: Any) {
        self.init(array: [object])
    }

    public convenience init(objects elements: Any...) {
        self.init(array: elements)
    }

    internal class func _objects(from aDecoder: NSCoder, allowDecodingNonindexedArrayKey: Bool = true) -> [NSObject] {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        if (allowDecodingNonindexedArrayKey && type(of: aDecoder) == NSKeyedUnarchiver.self) || aDecoder.containsValue(forKey: "NS.objects") {
            let objects = aDecoder._decodeArrayOfObjectsForKey("NS.objects")
            return objects as! [NSObject]
        } else {
            var objects: [NSObject] = []
            var count = 0
            var key: String { return "NS.object.\(count)" }
            while aDecoder.containsValue(forKey: key) {
                let object = aDecoder.decodeObject(forKey: key)
                objects.append(object as! NSObject)
                count += 1
            }
            return objects
        }
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        self.init(array: NSSet._objects(from: aDecoder))
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
    
    override open var description: String {
        return description(withLocale: nil)
    }
    
    open func description(withLocale locale: Locale?) -> String {
        return description(withLocale: locale, indent: 0)
    }
    
    private func description(withLocale locale: Locale?, indent level: Int) -> String {
        var descriptions = [String]()
        
        for obj in self._storage {
            if let string = obj as? String {
                descriptions.append(string)
            } else if let array = obj as? [Any] {
                descriptions.append(NSArray(array: array).description(withLocale: locale, indent: level + 1))
            } else if let dict = obj as? [AnyHashable : Any] {
                descriptions.append(dict._bridgeToObjectiveC().description(withLocale: locale, indent: level + 1))
            } else if let set = obj as? Set<AnyHashable> {
                descriptions.append(set._bridgeToObjectiveC().description(withLocale: locale, indent: level + 1))
            } else {
                descriptions.append("\(obj)")
            }
        }
        var indent = ""
        for _ in 0..<level {
            indent += "    "
        }
        var result = indent + "{(\n"
        for idx in 0..<self.count {
            result += indent + "    " + descriptions[idx]
            if idx + 1 < self.count {
                result += ",\n"
            } else {
                result += "\n"
            }
        }
        result += indent + ")}"
        return result
    }
    
    internal override var _cfTypeID: CFTypeID {
        return CFSetGetTypeID()
    }

    open override func isEqual(_ value: Any?) -> Bool {
        switch value {
        case let other as NSSet:
            // Check that this isn't a subclass — if both self and other are subclasses, this would otherwise turn into an infinite loop if other.isEqual(_:) calls super.
            if (type(of: self) == NSSet.self || type(of: self) == NSMutableSet.self) &&
               (type(of: other) != NSSet.self && type(of: other) != NSMutableSet.self) {
                return other.isEqual(self) // This ensures NSCountedSet overriding this method is respected no matter which side of the equality it appears on.
            } else {
                return isEqual(to: Set._unconditionallyBridgeFromObjectiveC(other))
            }
        case let other as Set<AnyHashable>:
            return isEqual(to: other)
        default:
            return false
        }
    }

    open override var hash: Int {
        return self.count
    }

    open var allObjects: [Any] {
        if type(of: self) === NSSet.self || type(of: self) === NSMutableSet.self {
            return _storage.map { __SwiftValue.fetch(nonOptional: $0) }
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
        // If self is larger then self cannot be a subset of otherSet
        if count > otherSet.count {
            return false
        }
        
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
            result.formUnion(_storage.map { __SwiftValue.fetch(nonOptional: $0) as! AnyHashable })
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
            result.formUnion(_storage.map { __SwiftValue.fetch(nonOptional: $0) as! AnyHashable })
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
    
    open func sortedArray(using sortDescriptors: [NSSortDescriptor]) -> [Any] {
        return allObjects._nsObject.sortedArray(using: sortDescriptors)
    }
}

extension NSSet : _SwiftBridgeable {
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

extension Set : _NSBridgeable {
    internal var _nsObject: NSSet { return _bridgeToObjectiveC() }
    internal var _cfObject: CFSet { return _nsObject._cfObject }
}

extension NSSet : Sequence {
    public typealias Iterator = NSEnumerator.Iterator
    public func makeIterator() -> Iterator {
        return self.objectEnumerator().makeIterator()
    }
}

extension NSSet: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(reflecting: self._storage)
    }
}

open class NSMutableSet : NSSet {
    
    open func add(_ object: Any) {
        guard type(of: self) === NSMutableSet.self else {
            NSRequiresConcreteImplementation()
        }
        _storage.insert(__SwiftValue.store(object))
    }
    
    open func remove(_ object: Any) {
        guard type(of: self) === NSMutableSet.self else {
            NSRequiresConcreteImplementation()
        }

        _storage.remove(__SwiftValue.store(object))
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
        self.init(array: NSSet._objects(from: aDecoder))
    }
    
    open func addObjects(from array: [Any]) {
        if type(of: self) === NSMutableSet.self {
            for case let obj in array {
                _storage.insert(__SwiftValue.store(obj))
            }
        } else {
            array.forEach(add)
        }
    }
    
    open func intersect(_ otherSet: Set<AnyHashable>) {
        if type(of: self) === NSMutableSet.self {
            _storage.formIntersection(otherSet.map { __SwiftValue.store($0) })
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
            _storage.subtract(otherSet.map { __SwiftValue.store($0) })
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
            _storage.formUnion(otherSet.map { __SwiftValue.store($0) })
        } else {
            otherSet.forEach(add)
        }
    }
    
    open func setSet(_ otherSet: Set<AnyHashable>) {
        if type(of: self) === NSMutableSet.self {
            _storage = Set(otherSet.map { __SwiftValue.store($0) })
        } else {
            removeAllObjects()
            union(otherSet)
        }
    }

}

/****************	Counted Set	****************/
open class NSCountedSet : NSMutableSet {
    // Note: in 5.0 and earlier, _table contained the object's exact count.
    // In 5.1 and earlier, it contains the count minus one. This allows us to have a quick 'is this set just like a regular NSSet' flag (if this table is empty, then all objects in it exist at most once in it.)
    internal var _table: [NSObject: Int] = [:]

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
            add(__SwiftValue.store(object))
        }
    }

    public convenience init(set: Set<AnyHashable>) {
        self.init(array: Array(set))
    }

    private enum NSCodingKeys {
        static let maximumAllowedCount = UInt.max >> 4
        static let countKey = "NS.count"
        static func objectKey(atIndex index: Int64) -> String { return "NS.object\(index)" }
        static func objectCountKey(atIndex index: Int64) -> String { return "NS.count\(index)" }
    }
    
    public required convenience init?(coder: NSCoder) {
        func fail(_ message: String) {
            coder.failWithError(NSError(domain: NSCocoaErrorDomain, code: NSCoderReadCorruptError, userInfo: [NSLocalizedDescriptionKey: message]))
        }
        
        guard coder.allowsKeyedCoding else {
            fail("NSCountedSet requires keyed coding to be archived.")
            return nil
        }
        
        let count = coder.decodeInt64(forKey: NSCodingKeys.countKey)
        guard count >= 0, UInt(count) <= NSCodingKeys.maximumAllowedCount else {
            fail("cannot decode set with \(count) elements in this version")
            return nil
        }
        
        var objects: [(object: Any, count: Int64)] = []
        
        for i in 0 ..< count {
            let objectKey = NSCodingKeys.objectKey(atIndex: i)
            let countKey = NSCodingKeys.objectCountKey(atIndex: i)
            
            guard coder.containsValue(forKey: objectKey) && coder.containsValue(forKey: countKey) else {
                fail("Mismatch in count stored (\(count)) vs. count present (\(i))")
                return nil
            }
            
            guard let object = coder.decodeObject(forKey: objectKey) else {
                fail("Decode failure at index \(i) - item nil")
                return nil
            }
            
            let itemCount = coder.decodeInt64(forKey: countKey)
            guard itemCount > 0 else {
                fail("Decode failure at index \(i) - itemCount zero")
                return nil
            }
            
            guard UInt(itemCount) <= NSCodingKeys.maximumAllowedCount else {
                fail("Cannot store \(itemCount) instances of item \(object) in this version")
                return nil
            }
            
            objects.append((object, itemCount))
        }
        
        self.init()
        for value in objects {
            for _ in 0 ..< value.count {
                add(value.object)
            }
        }
    }
    
    open override func encode(with coder: NSCoder) {
        func fail(_ message: String) {
            coder.failWithError(NSError(domain: NSCocoaErrorDomain, code: NSCoderReadCorruptError, userInfo: [NSLocalizedDescriptionKey: message]))
        }
        
        guard coder.allowsKeyedCoding else {
            fail("NSCountedSet requires keyed coding to be archived.")
            return
        }
        
        coder.encode(Int64(self.count), forKey: NSCodingKeys.countKey)
        var index: Int64 = 0
        for object in self {
            coder.encode(object, forKey: NSCodingKeys.objectKey(atIndex: index))
            coder.encode(Int64(count(for: object)), forKey: NSCodingKeys.objectCountKey(atIndex: index))
            index += 1
        }
    }

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
        let value = __SwiftValue.store(object)
        if let count = _table[value] {
            return count + 1
        } else if _storage.contains(value) {
            return 1
        } else {
            return 0
        }
    }

    open override func add(_ object: Any) {
        guard type(of: self) === NSCountedSet.self else {
            NSRequiresConcreteImplementation()
        }
        let value = __SwiftValue.store(object)
        if _storage.contains(value) {
            _table[value, default: 0] += 1
        } else {
            _storage.insert(value)
        }
    }

    open override func remove(_ object: Any) {
        guard type(of: self) === NSCountedSet.self else {
            NSRequiresConcreteImplementation()
        }
        let value = __SwiftValue.store(object)
        if let count = _table[value] {
            precondition(count > 0)
            _table[value] = count == 1 ? nil : count - 1
        } else if _storage.contains(value) {
            _table.removeValue(forKey: value)
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
    
    open override func isEqual(_ value: Any?) -> Bool {
        if let countedSet = value as? NSCountedSet {
            guard count == countedSet.count else { return false }
            for object in self {
                if !countedSet.contains(object) || count(for: object) != countedSet.count(for: object) {
                    return false
                }
            }
            return true
        }
        
        if _table.isEmpty {
            return super.isEqual(value)
        } else {
            return false
        }
    }
    
    // The hash of a NSSet in s-c-f is its count, which is the same among equal NSCountedSets as well,
    // so just using the superclass's implementation works fine.
}

extension NSSet : _StructTypeBridgeable {
    public typealias _StructType = Set<AnyHashable>
    
    public func _bridgeToSwift() -> _StructType {
        return _StructType._unconditionallyBridgeFromObjectiveC(self)
    }
}
