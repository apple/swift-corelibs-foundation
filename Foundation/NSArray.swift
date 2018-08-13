// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

import CoreFoundation

open class NSArray : NSObject, NSCopying, NSMutableCopying, NSSecureCoding, NSCoding {
    private let _cfinfo = _CFInfo(typeID: CFArrayGetTypeID())
    internal var _storage = [AnyObject]()
    
    open var count: Int {
        guard type(of: self) === NSArray.self || type(of: self) === NSMutableArray.self else {
            NSRequiresConcreteImplementation()
        }
        return _storage.count
    }
    
    open func object(at index: Int) -> Any {
        guard type(of: self) === NSArray.self || type(of: self) === NSMutableArray.self else {
           NSRequiresConcreteImplementation()
        }
        return _SwiftValue.fetch(nonOptional: _storage[index])
    }
    
    public override init() {
        _storage.reserveCapacity(0)
    }

    public required init(objects: UnsafePointer<AnyObject>?, count: Int) {
        precondition(count >= 0)
        precondition(count == 0 || objects != nil)

        _storage.reserveCapacity(count)
        for idx in 0..<count {
            _storage.append(objects![idx])
        }
    }

    public convenience init(objects: UnsafePointer<AnyObject>, count: Int) {
        self.init()
        _storage.reserveCapacity(count)
        for idx in 0..<count {
            _storage.append(objects[idx])
        }
    }

    public convenience init(objects elements: AnyObject...) {
        self.init(objects: elements, count: elements.count)
    }

    public required convenience init(arrayLiteral elements: Any...) {
        self.init(array: elements)
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
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        if let keyedArchiver = aCoder as? NSKeyedArchiver {
            keyedArchiver._encodeArrayOfObjects(self, forKey:"NS.objects")
        } else {
            for object in self {
                if let codable = object as? NSCoding {
                    codable.encode(with: aCoder)
                }
            }
        }
    }
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        if type(of: self) === NSArray.self {
            // return self for immutable type
            return self
        } else if type(of: self) === NSMutableArray.self {
            let array = NSArray()
            array._storage = self._storage
            return array
        }
        return NSArray(array: self.allObjects)
    }
    
    open override func mutableCopy() -> Any {
        return mutableCopy(with: nil)
    }
    
    open func mutableCopy(with zone: NSZone? = nil) -> Any {
        if type(of: self) === NSArray.self || type(of: self) === NSMutableArray.self {
            // always create and return an NSMutableArray
            let mutableArray = NSMutableArray()
            mutableArray._storage = self._storage
            return mutableArray
        }
        return NSMutableArray(array: self.allObjects)
    }

    public convenience init(object anObject: Any) {
        self.init(array: [anObject])
    }
    
    public convenience init(array: [Any]) {
        self.init(array: array, copyItems: false)
    }
    
    public convenience init(array: [Any], copyItems: Bool) {
        
        let optionalArray : [AnyObject] =
            copyItems ?
                array.map { return _SwiftValue.store($0).copy() as! NSObject } :
                array.map { return _SwiftValue.store($0) }
        
        // This would have been nice, but "initializer delegation cannot be nested in another expression"
//        optionalArray.withUnsafeBufferPointer { ptr in
//            self.init(objects: ptr.baseAddress, count: array.count)
//        }
        let cnt = array.count
        let buffer = UnsafeMutablePointer<AnyObject>.allocate(capacity: cnt)
        buffer.initialize(from: optionalArray, count: cnt)
        self.init(objects: buffer, count: cnt)
        buffer.deinitialize(count: cnt)
        buffer.deallocate()
    }

    open override func isEqual(_ value: Any?) -> Bool {
        switch value {
        case let other as [Any]:
            return self.isEqual(to: other)
        case let other as NSArray:
            return self.isEqual(to: other.allObjects)
        default:
            return false
        }
    }

    open override var hash: Int {
        return self.count
    }

    internal var allObjects: [Any] {
        if type(of: self) === NSArray.self || type(of: self) === NSMutableArray.self {
            return _storage.map { _SwiftValue.fetch(nonOptional: $0) }
        } else {
            return (0..<count).map { idx in
                return self[idx]
            }
        }
    }
    
    open func adding(_ anObject: Any) -> [Any] {
        return allObjects + [anObject]
    }
    
    open func addingObjects(from otherArray: [Any]) -> [Any] {
        return allObjects + otherArray
    }

    open func componentsJoined(by separator: String) -> String {
        // make certain to call NSObject's description rather than asking the string interpolator for the swift description
        return allObjects.map { "\($0)" }.joined(separator: separator)
    }

    open func contains(_ anObject: Any) -> Bool {
        guard let other = anObject as? AnyHashable else {
            return false
        }

        for idx in 0..<count {
            if let obj = self[idx] as? AnyHashable {
                if obj == other {
                    return true
                }
            }
        }
        return false
    }

    override open var description: String {
        return description(withLocale: nil)
    }

    open func description(withLocale locale: Locale?) -> String {
        return description(withLocale: locale, indent: 0)
    }

    open func description(withLocale locale: Locale?, indent level: Int) -> String {
        var descriptions = [String]()
        let cnt = count
        for idx in 0..<cnt {
            let obj = self[idx]
            if let string = obj as? String {
                descriptions.append(string)
            } else if let array = obj as? [Any] {
                descriptions.append(NSArray(array: array).description(withLocale: locale, indent: level + 1))
            } else if let dict = obj as? [AnyHashable : Any] {
                descriptions.append(dict._bridgeToObjectiveC().description(withLocale: locale, indent: level + 1))
            } else {
                descriptions.append("\(obj)")
            }
        }
        var indent = ""
        for _ in 0..<level {
            indent += "    "
        }
        var result = indent + "(\n"
        for idx in 0..<cnt {
            result += indent + "    " + descriptions[idx]
            if idx + 1 < cnt {
                result += ",\n"
            } else {
                result += "\n"
            }
        }
        result += indent + ")"
        return result
    }
    
    open func firstObjectCommon(with otherArray: [Any]) -> Any? {
        let set = otherArray.map { _SwiftValue.store($0) }

        for idx in 0..<count {
            let item = _SwiftValue.store(self[idx])
            if set.contains(item) {
                return _SwiftValue.fetch(nonOptional: item)
            }
        }
        return nil
    }

    internal func getObjects(_ objects: inout [Any], range: NSRange) {
        objects.reserveCapacity(objects.count + range.length)

        if type(of: self) === NSArray.self || type(of: self) === NSMutableArray.self {
            objects += _storage[Range(range)!].map { _SwiftValue.fetch(nonOptional: $0) }
            return
        }
        
        objects += Range(range)!.map { self[$0] }
    }
    
    open func index(of anObject: Any) -> Int {
        guard let val = anObject as? AnyHashable else {
            return NSNotFound
        }
        for idx in 0..<count {
            if let obj = object(at: idx) as? AnyHashable {
                if val == obj {
                    return idx
                }
            }
        }
        return NSNotFound
    }
    
    open func index(of anObject: Any, in range: NSRange) -> Int {
        guard let val = anObject as? AnyHashable else {
            return NSNotFound
        }
        for idx in 0..<range.length {
            if let obj = object(at: idx + range.location) as? AnyHashable {
                if val == obj {
                    return idx
                }
            }
        }
        return NSNotFound
    }
    
    open func indexOfObjectIdentical(to anObject: Any) -> Int {
        guard let val = anObject as? NSObject else {
            return NSNotFound
        }
        for idx in 0..<count {
            if let obj = object(at: idx) as? NSObject {
                if val === obj {
                    return idx
                }
            }
        }
        return NSNotFound
    }
    
    open func indexOfObjectIdentical(to anObject: Any, in range: NSRange) -> Int {
        guard let val = anObject as? NSObject else {
            return NSNotFound
        }
        for idx in 0..<range.length {
            if let obj = object(at: idx + range.location) as? NSObject {
                if val === obj {
                    return idx
                }
            }
        }
        return NSNotFound
    }
    
    open func isEqual(to otherArray: [Any]) -> Bool {
        if count != otherArray.count {
            return false
        }
        
        for idx in 0..<count {
            if let val1 = object(at: idx) as? AnyHashable,
               let val2 = otherArray[idx] as? AnyHashable {
                if val1 != val2 {
                    return false
                }
            } else {
              let val1 = object(at: idx)
              let val2 = otherArray[idx]
                if !_SwiftValue.store(val1).isEqual(_SwiftValue.store(val2)) {
                    return false
                }
            }
        }
        
        return true
    }

    open var firstObject: Any? {
        if count > 0 {
            return object(at: 0)
        } else {
            return nil
        }
    }
    
    open var lastObject: Any? {
        if count > 0 {
            return object(at: count - 1)
        } else {
            return nil
        }
    }
    
    public struct Iterator : IteratorProtocol {
        // TODO: Detect mutations
        // TODO: Use IndexingGenerator instead?
        let array : NSArray
        let sentinel : Int
        let reverse : Bool
        var idx : Int
        public mutating func next() -> Any? {
            guard idx != sentinel else {
                return nil
            }
            let result = array.object(at: reverse ? idx - 1 : idx)
            idx += reverse ? -1 : 1
            return result
        }
        init(_ array : NSArray, reverse : Bool = false) {
            self.array = array
            self.sentinel = reverse ? 0 : array.count
            self.idx = reverse ? array.count : 0
            self.reverse = reverse
        }
    }
    open func objectEnumerator() -> NSEnumerator {
        return NSGeneratorEnumerator(Iterator(self))
    }
    
    open func reverseObjectEnumerator() -> NSEnumerator {
        return NSGeneratorEnumerator(Iterator(self, reverse: true))
    }
    
    open var sortedArrayHint: Data {
        let size = MemoryLayout<Int32>.size * count
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        buffer.withMemoryRebound(to: Int32.self, capacity: count) { (ptr) in
            for idx in 0..<count {
                let item = object(at: idx) as! NSObject
                let hash = item.hash
                ptr.advanced(by: idx).pointee = Int32(hash).littleEndian
            }
        }
        return Data(bytesNoCopy: buffer, count: size, deallocator: .custom({ (_, _) in
            buffer.deallocate()
        }))
    }
    
    open func sortedArray(_ comparator: (Any, Any, UnsafeMutableRawPointer?) -> Int, context: UnsafeMutableRawPointer?) -> [Any] {
        return sortedArray(options: []) { lhs, rhs in
            return ComparisonResult(rawValue: comparator(lhs, rhs, context))!
        }
    }
    
    open func sortedArray(_ comparator: (Any, Any, UnsafeMutableRawPointer?) -> Int, context: UnsafeMutableRawPointer?, hint: Data?) -> [Any] {
        return sortedArray(options: []) { lhs, rhs in
            return ComparisonResult(rawValue: comparator(lhs, rhs, context))!
        }
    }

    open func subarray(with range: NSRange) -> [Any] {
        if range.length == 0 {
            return []
        }
        var objects = [Any]()
        getObjects(&objects, range: range)
        return objects
    }

    open func write(to url: URL) throws {
        let pListData = try PropertyListSerialization.data(fromPropertyList: self, format: .xml, options: 0)
        try pListData.write(to: url, options: .atomic)
    }

    @available(*, deprecated)
    open func write(toFile path: String, atomically useAuxiliaryFile: Bool) -> Bool {
        return write(to: URL(fileURLWithPath: path), atomically: useAuxiliaryFile)
    }

    // the atomically flag is ignored if url of a type that cannot be written atomically.
    @available(*, deprecated)
    open func write(to url: URL, atomically: Bool) -> Bool {
        do {
            let pListData = try PropertyListSerialization.data(fromPropertyList: self, format: .xml, options: 0)
            try pListData.write(to: url, options: atomically ? .atomic : [])
            return true
        } catch {
            return false
        }
    }

    open func objects(at indexes: IndexSet) -> [Any] {
        var objs = [Any]()
        indexes.rangeView.forEach {
            objs.append(contentsOf: self.subarray(with: NSRange(location: $0.lowerBound, length: $0.upperBound - $0.lowerBound)))
        }
        
        return objs
    }

    open subscript (idx: Int) -> Any {
        guard idx < count && idx >= 0 else {
            fatalError("\(self): Index out of bounds")
        }
        
        return object(at: idx)
    }

    open func enumerateObjects(_ block: (Any, Int, UnsafeMutablePointer<ObjCBool>) -> Swift.Void) {
        self.enumerateObjects(options: [], using: block)
    }

    open func enumerateObjects(options opts: NSEnumerationOptions = [], using block: (Any, Int, UnsafeMutablePointer<ObjCBool>) -> Swift.Void) {
        self.enumerateObjects(at: IndexSet(integersIn: 0..<count), options: opts, using: block)
    }

    open func enumerateObjects(at s: IndexSet, options opts: NSEnumerationOptions = [], using block: (Any, Int, UnsafeMutablePointer<ObjCBool>) -> Swift.Void) {
        s._bridgeToObjectiveC().enumerate(options: opts) { (idx, stop) in
            block(self.object(at: idx), idx, stop)
        }
    }

    open func indexOfObject(passingTest predicate: (Any, Int, UnsafeMutablePointer<ObjCBool>) -> Bool) -> Int {
        return indexOfObject(options: [], passingTest: predicate)
    }

    open func indexOfObject(options opts: NSEnumerationOptions = [], passingTest predicate: (Any, Int, UnsafeMutablePointer<ObjCBool>) -> Bool) -> Int {
        return indexOfObject(at: IndexSet(integersIn: 0..<count), options: opts, passingTest: predicate)
    }

    open func indexOfObject(at s: IndexSet, options opts: NSEnumerationOptions = [], passingTest predicate: (Any, Int, UnsafeMutablePointer<ObjCBool>) -> Bool) -> Int {
        var result = NSNotFound
        enumerateObjects(at: s, options: opts) { (obj, idx, stop) -> Void in
            if predicate(obj, idx, stop) {
                result = idx
                stop.pointee = true
            }
        }
        return result
    }

    open func indexesOfObjects(passingTest predicate: (Any, Int, UnsafeMutablePointer<ObjCBool>) -> Bool) -> IndexSet {
        return indexesOfObjects(options: [], passingTest: predicate)
    }

    open func indexesOfObjects(options opts: NSEnumerationOptions = [], passingTest predicate: (Any, Int, UnsafeMutablePointer<ObjCBool>) -> Bool) -> IndexSet {
        return indexesOfObjects(at: IndexSet(integersIn: 0..<count), options: opts, passingTest: predicate)
    }

    open func indexesOfObjects(at s: IndexSet, options opts: NSEnumerationOptions = [], passingTest predicate: (Any, Int, UnsafeMutablePointer<ObjCBool>) -> Bool) -> IndexSet {
        var result = IndexSet()
        enumerateObjects(at: s, options: opts) { (obj, idx, stop) in
            if predicate(obj, idx, stop) {
                result.insert(idx)
            }
        }
        return result
    }

    internal func sortedArray(from range: NSRange, options: NSSortOptions, usingComparator cmptr: (Any, Any) -> ComparisonResult) -> [Any] {
        // The sort options are not available. We use the Array's sorting algorithm. It is not stable neither concurrent.
        guard options.isEmpty else {
            NSUnimplemented()
        }

        let count = self.count
        if range.length == 0 || count == 0 {
            return []
        }

        let swiftRange = Range(range)!
        return allObjects[swiftRange].sorted { lhs, rhs in
            return cmptr(lhs, rhs) == .orderedAscending
        }
    }
    
    open func sortedArray(comparator cmptr: (Any, Any) -> ComparisonResult) -> [Any] {
        return sortedArray(from: NSRange(location: 0, length: count), options: [], usingComparator: cmptr)
    }

    open func sortedArray(options opts: NSSortOptions = [], usingComparator cmptr: (Any, Any) -> ComparisonResult) -> [Any] {
        return sortedArray(from: NSRange(location: 0, length: count), options: opts, usingComparator: cmptr)
    }

    open func index(of obj: Any, inSortedRange r: NSRange, options opts: NSBinarySearchingOptions = [], usingComparator cmp: (Any, Any) -> ComparisonResult) -> Int {
        let lastIndex = r.location + r.length - 1
        
        // argument validation
        guard lastIndex < count else {
            let bounds = count == 0 ? "for empty array" : "[0 .. \(count - 1)]"
            NSInvalidArgument("range \(r) extends beyond bounds \(bounds)")
        }
        
        if opts.contains(.firstEqual) && opts.contains(.lastEqual) {
            NSInvalidArgument("both NSBinarySearching.firstEqual and NSBinarySearching.lastEqual options cannot be specified")
        }
        
        let searchForInsertionIndex = opts.contains(.insertionIndex)
        
        // fringe cases
        if r.length == 0 {
            return  searchForInsertionIndex ? r.location : NSNotFound
        }
        
        let leastObj = object(at: r.location)
        if cmp(obj, leastObj) == .orderedAscending {
            return searchForInsertionIndex ? r.location : NSNotFound
        }
        
        let greatestObj = object(at: lastIndex)
        if cmp(obj, greatestObj) == .orderedDescending {
            return searchForInsertionIndex ? lastIndex + 1 : NSNotFound
        }
        
        // common processing
        let firstEqual = opts.contains(.firstEqual)
        let lastEqual = opts.contains(.lastEqual)
        let anyEqual = !(firstEqual || lastEqual)
        
        var result = NSNotFound
        var indexOfLeastGreaterThanObj = NSNotFound
        var start = r.location
        var end = lastIndex
        
        loop: while start <= end {
            let middle = start + (end - start) / 2
            let item = object(at: middle)
            
            switch cmp(item, obj) {
                
            case .orderedSame where anyEqual:
                result = middle
                break loop
                
            case .orderedSame where lastEqual:
                result = middle
                fallthrough
                
            case .orderedAscending:
                start = middle + 1
                
            case .orderedSame where firstEqual:
                result = middle
                fallthrough
                
            case .orderedDescending:
                indexOfLeastGreaterThanObj = middle
                end = middle - 1
                
            default:
                fatalError("Implementation error.")
            }
        }
        
        if !searchForInsertionIndex {
            return result
        }
        
        if result == NSNotFound {
            return indexOfLeastGreaterThanObj
        }
        
        return lastEqual ? result + 1 : result
    }

    public convenience init(contentsOf url: URL, error: ()) throws {
        let plistDoc = try Data(contentsOf: url)
        guard let plistArray = try PropertyListSerialization.propertyList(from: plistDoc, options: [], format: nil) as? Array<Any>
            else {
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: [NSURLErrorKey : url])
        }
        self.init(array: plistArray)
    }

    @available(*, deprecated)
    public convenience init?(contentsOfFile path: String) {
        do {
            try self.init(contentsOf: URL(fileURLWithPath: path), error: ())
        } catch {
            return nil
        }
    }

    @available(*, deprecated)
    public convenience init?(contentsOf url: URL) {
        do {
            try self.init(contentsOf: url, error: ())
        } catch {
            return nil
        }
    }

    open func pathsMatchingExtensions(_ filterTypes: [String]) -> [String] {
        guard !filterTypes.isEmpty else {
            return []
        }

        let extensions: [String] = filterTypes.map {
            var ext = "."
            ext.append($0)
            return ext
        }

        return self.filter {
            // The force unwrap will abort if the element is not a String but this behaviour matches Darwin, which throws an exception.
            let filename = $0 as! String
            for ext in extensions {
                if filename.hasSuffix(ext) && filename.count > ext.count {
                    return true
                }
            }
            return false
        } as! [String]
    }

    override open var _cfTypeID: CFTypeID {
        return CFArrayGetTypeID()
    }
}

extension NSArray : _CFBridgeable, _SwiftBridgeable {
    internal var _cfObject: CFArray { return unsafeBitCast(self, to: CFArray.self) }
    internal var _swiftObject: [AnyObject] { return Array._unconditionallyBridgeFromObjectiveC(self) }
}

extension NSMutableArray {
    internal var _cfMutableObject: CFMutableArray { return unsafeBitCast(self, to: CFMutableArray.self) }
}

extension CFArray : _NSBridgeable, _SwiftBridgeable {
    internal var _nsObject: NSArray { return unsafeBitCast(self, to: NSArray.self) }
    internal var _swiftObject: Array<Any> { return _nsObject._swiftObject }
}

extension CFArray {
    /// Bridge something returned from CF to an Array<T>. Useful when we already know that a CFArray contains objects that are toll-free bridged with Swift objects, e.g. CFArray<CFURLRef>.
    /// - Note: This bridging operation is unfortunately still O(n), but it only traverses the NSArray once, creating the Swift array and casting at the same time.
    func _unsafeTypedBridge<T : _CFBridgeable>() -> Array<T> {
        var result = Array<T>()
        let count = CFArrayGetCount(self)
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(unsafeBitCast(CFArrayGetValueAtIndex(self, i), to: T.self))
        }
        return result
    }
}

extension Array : _NSBridgeable, _CFBridgeable {
    internal var _nsObject: NSArray { return _bridgeToObjectiveC() }
    internal var _cfObject: CFArray { return _nsObject._cfObject }
}

public struct NSBinarySearchingOptions : OptionSet {
    public let rawValue : UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    
    public static let firstEqual = NSBinarySearchingOptions(rawValue: 1 << 8)
    public static let lastEqual = NSBinarySearchingOptions(rawValue: 1 << 9)
    public static let insertionIndex = NSBinarySearchingOptions(rawValue: 1 << 10)
}

open class NSMutableArray : NSArray {
    
    open func add(_ anObject: Any) {
        insert(anObject, at: count)
    }
    
    open func insert(_ anObject: Any, at index: Int) {
        guard type(of: self) === NSMutableArray.self else {
            NSRequiresConcreteImplementation()
        }
        _storage.insert(_SwiftValue.store(anObject), at: index)
    }

    open func insert(_ objects: [Any], at indexes: IndexSet) {
        precondition(objects.count == indexes.count)
        
        if type(of: self) === NSMutableArray.self {
            _storage.reserveCapacity(count + indexes.count)
        }
        
        var objectIdx = 0
        for insertionIndex in indexes {
            self.insert(objects[objectIdx], at: insertionIndex)
            objectIdx += 1
        }
    }

    open func removeLastObject() {
        if count > 0 {
            removeObject(at: count - 1)
        }
    }
    
    open func removeObject(at index: Int) {
        guard type(of: self) === NSMutableArray.self else {
            NSRequiresConcreteImplementation()
        }
        _storage.remove(at: index)
    }
    
    open func replaceObject(at index: Int, with anObject: Any) {
        guard type(of: self) === NSMutableArray.self else {
            NSRequiresConcreteImplementation()
        }
        let min = index
        let max = index + 1
        _storage.replaceSubrange(min..<max, with: [_SwiftValue.store(anObject) as AnyObject])
    }
    
    public override init() {
        super.init()
    }
    
    public init(capacity numItems: Int) {
        super.init(objects: nil, count: 0)

        if type(of: self) === NSMutableArray.self {
            _storage.reserveCapacity(numItems)
        }
    }
    
    public required init(objects: UnsafePointer<AnyObject>?, count: Int) {
        precondition(count >= 0)
        precondition(count == 0 || objects != nil)

        super.init()
        _storage.reserveCapacity(count)
        for idx in 0..<count {
            _storage.append(objects![idx])
        }
    }
    
    open override subscript (idx: Int) -> Any {
        get {
            return object(at: idx)
        }
        set(newObject) {
            self.replaceObject(at: idx, with: newObject)
        }
    }
    
    open func addObjects(from otherArray: [Any]) {
        if type(of: self) === NSMutableArray.self {
            _storage += otherArray.map { _SwiftValue.store($0) as AnyObject }
        } else {
            for obj in otherArray {
                add(obj)
            }
        }
    }
    
    open func exchangeObject(at idx1: Int, withObjectAt idx2: Int) {
        if type(of: self) === NSMutableArray.self {
            swap(&_storage[idx1], &_storage[idx2])
        } else {
            NSUnimplemented()
        }
    }
    
    open func removeAllObjects() {
        if type(of: self) === NSMutableArray.self {
            _storage.removeAll()
        } else {
            while count > 0 {
                removeObject(at: 0)
            }
        }
    }
    
    open func remove(_ anObject: Any, in range: NSRange) {
        let idx = index(of: anObject, in: range)
        if idx != NSNotFound {
            removeObject(at: idx)
        }
    }
    
    open func remove(_ anObject: Any) {
        let idx = index(of: anObject)
        if idx != NSNotFound {
            removeObject(at: idx)
        }
    }
    
    open func removeObject(identicalTo anObject: Any, in range: NSRange) {
        let idx = indexOfObjectIdentical(to: anObject, in: range)
        if idx != NSNotFound {
            removeObject(at: idx)
        }
    }
    
    open func removeObject(identicalTo anObject: Any) {
        let idx = indexOfObjectIdentical(to: anObject)
        if idx != NSNotFound {
            removeObject(at: idx)
        }
    }
    
    open func removeObjects(in otherArray: [Any]) {
        let set = Set(otherArray.map { $0 as! AnyHashable } )
        for idx in (0..<count).reversed() {
            if let value = object(at: idx) as? AnyHashable {
                if set.contains(value) {
                    removeObject(at: idx)
                }
            }
        }
    }
    
    open func removeObjects(in range: NSRange) {
        if type(of: self) === NSMutableArray.self {
            _storage.removeSubrange(Range(range)!)
        } else {
            for idx in Range(range)!.reversed() {
                removeObject(at: idx)
            }
        }
    }
    open func replaceObjects(in range: NSRange, withObjectsFrom otherArray: [Any], range otherRange: NSRange) {
        var list = [Any]()
        otherArray._bridgeToObjectiveC().getObjects(&list, range:otherRange)
        replaceObjects(in: range, withObjectsFrom: list)
    }
    
    open func replaceObjects(in range: NSRange, withObjectsFrom otherArray: [Any]) {
        if type(of: self) === NSMutableArray.self {
            _storage.reserveCapacity(count - range.length + otherArray.count)
            for idx in 0..<range.length {
                _storage[idx + range.location] = _SwiftValue.store(otherArray[idx])
            }
            for idx in range.length..<otherArray.count {
                _storage.insert(_SwiftValue.store(otherArray[idx]), at: idx + range.location)
            }
        } else {
            NSUnimplemented()
        }
    }
    
    open func setArray(_ otherArray: [Any]) {
        if type(of: self) === NSMutableArray.self {
            _storage = otherArray.map { _SwiftValue.store($0) }
        } else {
            replaceObjects(in: NSRange(location: 0, length: count), withObjectsFrom: otherArray)
        }
    }
    
    open func removeObjects(at indexes: IndexSet) {
        for range in indexes.rangeView.reversed() {
            self.removeObjects(in: NSRange(location: range.lowerBound, length: range.upperBound - range.lowerBound))
        }
    }
    
    open func replaceObjects(at indexes: IndexSet, with objects: [Any]) {
        var objectIndex = 0
        for countedRange in indexes.rangeView {
            let range = NSRange(location: countedRange.lowerBound, length: countedRange.upperBound - countedRange.lowerBound)
            let subObjects = objects[objectIndex..<objectIndex + range.length]
            self.replaceObjects(in: range, withObjectsFrom: Array(subObjects))
            objectIndex += range.length
        }
    }

    open func sort(_ compare: (Any, Any, UnsafeMutableRawPointer?) -> Int, context: UnsafeMutableRawPointer?) {
        self.setArray(self.sortedArray(compare, context: context))
    }

    open func sort(comparator: Comparator) {
        self.sort(options: [], usingComparator: comparator)
    }

    open func sort(options opts: NSSortOptions = [], usingComparator cmptr: Comparator) {
        self.setArray(self.sortedArray(options: opts, usingComparator: cmptr))
    }
}

extension NSArray : _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? {
        // FIXME: I want to return AnyHashable(self as! [AnyHashable])
        // here, but a direct conversion to AnyHashable can fail with nested
        // collections.
        var a: [AnyHashable] = []
        a.reserveCapacity(self.count)
        for member in self {
            a.append(member as AnyObject as! AnyHashable)
        }
        return AnyHashable(a)
    }
}

extension NSArray : Sequence {
    final public func makeIterator() -> Iterator {
        return Iterator(self)
    }
}

extension NSArray : ExpressibleByArrayLiteral {
    
    /// Create an instance initialized with `elements`.
//    required public convenience init(arrayLiteral elements: Any...) {
//        
//    }
}

extension NSArray : CustomReflectable {
    public var customMirror: Mirror { NSUnimplemented() }
}

extension NSArray : _StructTypeBridgeable {
    public typealias _StructType = Array<Any>
    
    public func _bridgeToSwift() -> _StructType {
        return _StructType._unconditionallyBridgeFromObjectiveC(self)
    }
}
