// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import SwiftFoundation
#else
import Foundation
#endif

internal extension NSLock {
    func performLocked<T>(_ block: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try block()
    }
}

/*!
    @enum URLCache.StoragePolicy
    
    @discussion The URLCache.StoragePolicy enum defines constants that
    can be used to specify the type of storage that is allowable for an
    NSCachedURLResponse object that is to be stored in an URLCache.
    
    @constant URLCache.StoragePolicy.allowed Specifies that storage in an
    URLCache is allowed without restriction.

    @constant URLCache.StoragePolicy.allowedInMemoryOnly Specifies that
    storage in an URLCache is allowed; however storage should be
    done in memory only, no disk storage should be done.

    @constant URLCache.StoragePolicy.notAllowed Specifies that storage in an
    URLCache is not allowed in any fashion, either in memory or on
    disk.
*/
extension URLCache {
    public enum StoragePolicy : UInt {
        
        case allowed
        case allowedInMemoryOnly
        case notAllowed
    }
}

class StoredCachedURLResponse: NSObject, NSSecureCoding {
    class var supportsSecureCoding: Bool { return true }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(cachedURLResponse.response, forKey: "response")
        aCoder.encode(cachedURLResponse.data._bridgeToObjectiveC(), forKey: "data")
        aCoder.encode(Int(bitPattern: cachedURLResponse.storagePolicy.rawValue), forKey: "storagePolicy")
        aCoder.encode(cachedURLResponse.userInfo as NSDictionary?, forKey: "userInfo")
        aCoder.encode(cachedURLResponse.date as NSDate, forKey: "date")
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let response = aDecoder.decodeObject(of: URLResponse.self, forKey: "response"),
              let data = aDecoder.decodeObject(of: NSData.self, forKey: "data"),
            let storagePolicy = URLCache.StoragePolicy(rawValue: UInt(bitPattern: aDecoder.decodeInteger(forKey: "storagePolicy"))),
              let date = aDecoder.decodeObject(of: NSDate.self, forKey: "date") else {
                return nil
        }
        
        let userInfo = aDecoder.decodeObject(of: NSDictionary.self, forKey: "userInfo") as? [AnyHashable: Any]
        
        cachedURLResponse = CachedURLResponse(response: response, data: Data(data), userInfo: userInfo, storagePolicy: storagePolicy)
        cachedURLResponse.date = date as Date
    }
    
    let cachedURLResponse: CachedURLResponse
    
    init(cachedURLResponse: CachedURLResponse) {
        self.cachedURLResponse = cachedURLResponse
    }
}

/*!
    @class CachedURLResponse
    CachedURLResponse is a class whose objects functions as a wrapper for
    objects that are stored in the framework's caching system. 
    It is used to maintain characteristics and attributes of a cached 
    object. 
*/
open class CachedURLResponse : NSObject, NSCopying {
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }

    /*!
        @method initWithResponse:data
        @abstract Initializes an CachedURLResponse with the given
        response and data.
        @discussion A default URLCache.StoragePolicy is used for
        CachedURLResponse objects initialized with this method:
        URLCache.StoragePolicy.allowed.
        @param response a URLResponse object.
        @param data an Data object representing the URL content
        corresponding to the given response.
        @result an initialized CachedURLResponse.
    */
    public init(response: URLResponse, data: Data) {
        self.response = response.copy() as! URLResponse
        self.data = data
        self.userInfo = nil
        self.storagePolicy = .allowed
    }
    
    /*! 
        @method initWithResponse:data:userInfo:storagePolicy:
        @abstract Initializes an NSCachedURLResponse with the given
        response, data, user-info dictionary, and storage policy.
        @param response a URLResponse object.
        @param data an NSData object representing the URL content
        corresponding to the given response.
        @param userInfo a dictionary user-specified information to be
        stored with the NSCachedURLResponse.
        @param storagePolicy an URLCache.StoragePolicy constant.
        @result an initialized CachedURLResponse.
    */
    public init(response: URLResponse, data: Data, userInfo: [AnyHashable : Any]? = nil, storagePolicy: URLCache.StoragePolicy) {
        self.response = response.copy() as! URLResponse
        self.data = data
        self.userInfo = userInfo
        self.storagePolicy = storagePolicy
    }
    
    /*! 
        @method response
        @abstract Returns the response wrapped by this instance. 
        @result The response wrapped by this instance. 
    */
    /*@NSCopying*/ open private(set) var response: URLResponse
    
    /*! 
        @method data
        @abstract Returns the data of the receiver. 
        @result The data of the receiver. 
    */
    /*@NSCopying*/ open private(set) var data: Data
    
    /*! 
        @method userInfo
        @abstract Returns the userInfo dictionary of the receiver. 
        @result The userInfo dictionary of the receiver. 
    */
    open private(set) var userInfo: [AnyHashable : Any]?
    
    /*! 
        @method storagePolicy
        @abstract Returns the URLCache.StoragePolicy constant of the receiver.
        @result The URLCache.StoragePolicy constant of the receiver.
    */
    open private(set) var storagePolicy: URLCache.StoragePolicy

    open override func isEqual(_ value: Any?) -> Bool {
        switch value {
        case let other as CachedURLResponse:
            return self.isEqual(to: other)
        default:
            return false
        }
    }

    private func isEqual(to other: CachedURLResponse) -> Bool {
        if self === other {
            return true
        }

        // We cannot compare userInfo because of the values are Any, which
        // doesn't conform to Equatable.
        return self.response == other.response &&
                self.data == other.data &&
                self.storagePolicy == other.storagePolicy
    }
    
    internal fileprivate(set) var date: Date = Date()

    open override var hash: Int {
        var hasher = Hasher()
        hasher.combine(response)
        hasher.combine(data)
        hasher.combine(storagePolicy)
        return hasher.finalize()
    }
}

open class URLCache : NSObject {
    
    private static let sharedLock = NSLock()
    private static var _shared: URLCache?
    
    /*! 
        @method sharedURLCache
        @abstract Returns the shared URLCache instance.
        @discussion Unless set explicitly, this method returns an URLCache
        instance created with the following default values:
        <ul>
        <li>Memory capacity: 4 megabytes (4 * 1024 * 1024 bytes)
        <li>Disk capacity: 20 megabytes (20 * 1024 * 1024 bytes)
        <li>Disk path: <nobr>(user home directory)/Library/Caches/(application bundle id)</nobr> 
        </ul>
        <p>Users who do not have special caching requirements or
        constraints should find the default shared cache instance
        acceptable. If this default shared cache instance is not
        acceptable, the property can be set with a different URLCache
        instance to be returned from this method.
        @result the shared URLCache instance.
    */
    open class var shared: URLCache {
        get {
            return sharedLock.performLocked {
                if let shared = _shared {
                    return shared
                }
                
                let shared = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024, diskPath: nil)
                _shared = shared
                return shared
            }
        }
        set {
            sharedLock.performLocked {
                _shared = newValue
            }
        }
    }
    
    private let cacheDirectory: URL?
    
    private struct CacheEntry: Hashable {
        var identifier: String
        var cachedURLResponse: CachedURLResponse
        var date: Date
        var cost: Int
        
        init(identifier: String, cachedURLResponse: CachedURLResponse, serializedVersion: Data? = nil) {
            self.identifier = identifier
            self.cachedURLResponse = cachedURLResponse
            self.date = Date()
            // Estimate cost if we haven't already had to serialize this.
            self.cost = serializedVersion?.count ?? (cachedURLResponse.data.count + 500 * (cachedURLResponse.userInfo?.count ?? 0))
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
        }
        
        static func ==(_ lhs: CacheEntry, _ rhs: CacheEntry) -> Bool {
            return lhs.identifier == rhs.identifier
        }
    }
    
    private let inMemoryCacheLock = NSLock()
    private var inMemoryCacheOrder: [String] = []
    private var inMemoryCacheContents: [String: CacheEntry] = [:]
    
    func evictFromMemoryCacheAssumingLockHeld(maximumSize: Int) {
        var totalSize = inMemoryCacheContents.values.reduce(0) { $0 + $1.cost }
        
        var countEvicted = 0
        for identifier in inMemoryCacheOrder {
            if totalSize > maximumSize {
                countEvicted += 1
                let entry = inMemoryCacheContents.removeValue(forKey: identifier)!
                totalSize -= entry.cost
            } else {
                break
            }
        }
        
        inMemoryCacheOrder.removeSubrange(0 ..< countEvicted)
    }
    
    func evictFromDiskCache(maximumSize: Int) {
        let entries = diskEntries(includingPropertiesForKeys: [.fileSizeKey]).sorted {
            $0.date < $1.date
        }
        
        let sizes = entries.map { (entry) in
            (try? entry.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }

        var totalSize = sizes.reduce(0, +)
        
        for (index, entry) in entries.enumerated() {
            if totalSize > maximumSize {
                try? FileManager.default.removeItem(at: entry.url)
                totalSize -= sizes[index]
            }
        }
    }
    
    /*! 
        @method initWithMemoryCapacity:diskCapacity:diskPath:
        @abstract Initializes an URLCache with the given capacity and
        path.
        @discussion The returned URLCache is backed by disk, so
        developers can be more liberal with space when choosing the
        capacity for this kind of cache. A disk cache measured in the tens
        of megabytes should be acceptable in most cases.
        @param capacity the capacity, measured in bytes, for the cache.
        @param path the path on disk where the cache data is stored.
        @result an initialized URLCache, with the given capacity, backed
        by disk.
    */
    public init(memoryCapacity: Int, diskCapacity: Int, diskPath path: String?) {
        self.memoryCapacity = memoryCapacity
        self.diskCapacity = diskCapacity
        
        let url: URL?
        
        if let path = path {
            url = URL(fileURLWithPath: path)
        } else {
            do {
                let caches = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let directoryName = (Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName)
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "\\", with: "_")
                    .replacingOccurrences(of: ":", with: "_")

                // We append a Swift Foundation identifier to avoid clobbering a Darwin cache that may exist at the same path;
                // the two on-disk cache formats aren't compatible.
                url = caches
                    .appendingPathComponent("org.swift.foundation.URLCache", isDirectory: true)
                    .appendingPathComponent(directoryName, isDirectory: true)
            } catch {
                url = nil
            }
        }
        
        if let url = url {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                cacheDirectory = url
            } catch {
                cacheDirectory = nil
            }
        } else {
            cacheDirectory = nil
        }
    }
    
    /*!
        @method initWithMemoryCapacity:diskCapacity:directoryURL:
        @abstract Initializes an NSURLCache with the given capacity and directory.
        @param memoryCapacity the capacity, measured in bytes, for the cache in memory. Or 0 to disable memory cache.
        @param diskCapacity the capacity, measured in bytes, for the cache on disk. Or 0 to disable disk cache.
        @param directoryURL the path to a directory on disk where the cache data is stored. Or nil for default directory.
        @result an initialized NSURLCache, with the given capacity, optionally backed by disk.
    */
    public convenience init(memoryCapacity: Int, diskCapacity: Int, directory: URL? = nil) {
        self.init(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: directory?.path)
    }

    private func identifier(for request: URLRequest) -> String? {
        guard let url = request.url else { return nil }
        
        if let host = url.host {
            var data = Data()
            data.append(Data(host.lowercased(with: NSLocale.system).utf8))
            data.append(0)
            let port = url.port ?? -1
            data.append(Data("\(port)".utf8))
            data.append(0)
            data.append(Data(url.path.utf8))
            data.append(0)
        
            return data.base64EncodedString()
        } else {
            return nil
        }
    }
    
    private struct DiskEntry {
        static let pathExtension = "storedcachedurlresponse"
        
        var url: URL
        var date: Date
        var identifier: String
        
        init?(_ url: URL) {
            if url.pathExtension.caseInsensitiveCompare(DiskEntry.pathExtension) != .orderedSame {
                return nil
            }
            
            let parts = url.deletingPathExtension().lastPathComponent.components(separatedBy: ".")
            guard parts.count == 2 else { return nil }
            let (timeString, identifier) = (parts[0], parts[1])
            
            guard let time = Int64(timeString) else { return nil }
            
            self.date = Date(timeIntervalSinceReferenceDate: TimeInterval(time))
            self.identifier = identifier
            self.url = url
        }
    }
    
    private func enumerateDiskEntries(includingPropertiesForKeys keys: [URLResourceKey] = [], using block: (DiskEntry, inout Bool) -> Void) {
        guard let directory = cacheDirectory else { return }
        for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? [] {
            if let entry = DiskEntry(url) {
                var stop = false
                block(entry, &stop)
                if stop {
                    return
                }
            }
        }
    }
    
    private func diskEntries(includingPropertiesForKeys keys: [URLResourceKey] = []) -> [DiskEntry] {
        var entries: [DiskEntry] = []
        enumerateDiskEntries(includingPropertiesForKeys: keys) { (entry, stop) in
            entries.append(entry)
        }
        return entries
    }
    
    private func diskContentLocators(for request: URLRequest, forCreationAt date: Date? = nil) -> (identifier: String, url: URL)? {
        guard let directory = cacheDirectory else { return nil }
        guard let identifier = self.identifier(for: request) else { return nil }
        
        if let date = date {
            // Create a new URL, which may or may not exist on disk.
            let interval = Int64(date.timeIntervalSinceReferenceDate)
            return (identifier, directory.appendingPathComponent("\(interval).\(identifier).\(DiskEntry.pathExtension)"))
        } else {
            var foundURL: URL?
            
            enumerateDiskEntries { (entry, stop) in
                if entry.identifier == identifier {
                    foundURL = entry.url
                    stop = true
                }
            }
            
            if let foundURL = foundURL {
                return (identifier, foundURL)
            }
        }
        
        return nil
    }
    
    private func diskContents(for request: URLRequest) throws -> StoredCachedURLResponse? {
        guard let url = diskContentLocators(for: request)?.url else { return nil }
        
        let data = try Data(contentsOf: url)
        return try NSKeyedUnarchiver.unarchivedObject(ofClasses: [StoredCachedURLResponse.self], from: data) as? StoredCachedURLResponse
    }
    
    /*! 
        @method cachedResponseForRequest:
        @abstract Returns the NSCachedURLResponse stored in the cache with
        the given request.
        @discussion The method returns nil if there is no
        NSCachedURLResponse stored using the given request.
        @param request the NSURLRequest to use as a key for the lookup.
        @result The NSCachedURLResponse stored in the cache with the given
        request, or nil if there is no NSCachedURLResponse stored with the
        given request.
    */
    open func cachedResponse(for request: URLRequest) -> CachedURLResponse? {
        let result = inMemoryCacheLock.performLocked { () -> CachedURLResponse? in
            if let identifier = identifier(for: request),
                let entry = inMemoryCacheContents[identifier] {
                return entry.cachedURLResponse
            } else {
                return nil
            }
        }
        
        if let result = result {
            return result
        }
        
        guard let contents = try? diskContents(for: request) else { return nil }
        return contents.cachedURLResponse
    }
    
    /*! 
        @method storeCachedResponse:forRequest:
        @abstract Stores the given NSCachedURLResponse in the cache using
        the given request.
        @param cachedResponse The cached response to store.
        @param request the NSURLRequest to use as a key for the storage.
    */
    open func storeCachedResponse(_ cachedResponse: CachedURLResponse, for request: URLRequest) {
        let inMemory = cachedResponse.storagePolicy == .allowed || cachedResponse.storagePolicy == .allowedInMemoryOnly
        let onDisk = cachedResponse.storagePolicy == .allowed
        guard inMemory || onDisk else { return }
        
        guard let identifier = identifier(for: request) else { return }
        
        // Only create a serialized version if we are writing to disk:
        let object = StoredCachedURLResponse(cachedURLResponse: cachedResponse)
        let serialized = (onDisk && diskCapacity > 0) ? try? NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true) : nil
        
        let entry = CacheEntry(identifier: identifier, cachedURLResponse: cachedResponse, serializedVersion: serialized)

        if inMemory && entry.cost < memoryCapacity {
            inMemoryCacheLock.performLocked {
                evictFromMemoryCacheAssumingLockHeld(maximumSize: memoryCapacity - entry.cost)
                inMemoryCacheOrder.append(identifier)
                inMemoryCacheContents[identifier] = entry
            }
        }
        
        if onDisk, let serialized = serialized, entry.cost < diskCapacity {
            do {
                evictFromDiskCache(maximumSize: diskCapacity - entry.cost)
                
                let locators = diskContentLocators(for: request, forCreationAt: Date())
                if let newURL = locators?.url {
                    try serialized.write(to: newURL, options: .atomic)
                }
                
                if let identifier = locators?.identifier {
                    // Multiple threads and/or processes may be writing the same key at the same time. If writing the contents race for the exact same timestamp, we can't do much about that. (One of the two will exist, due to the .atomic; the other will error out.) But if the timestamps differ, we may end up with duplicate keys on disk.
                    // If so, best-effort clear all entries except the one with the highest date.
                    
                    // Refetch a snapshot of the directory contents from disk; do not trust prior state:
                    let entriesToRemove = diskEntries().filter {
                        $0.identifier == identifier
                    }.sorted {
                        $1.date < $0.date
                    }.dropFirst() // Keep the one with the latest date.
                    
                    for entry in entriesToRemove {
                        // Do not interrupt cleanup if one fails.
                        try? FileManager.default.removeItem(at: entry.url)
                    }
                }
                
            } catch { /* Best effort -- do not store on error. */ }
        }
    }
    
    /*! 
        @method removeCachedResponseForRequest:
        @abstract Removes the NSCachedURLResponse from the cache that is
        stored using the given request. 
        @discussion No action is taken if there is no NSCachedURLResponse
        stored with the given request.
        @param request the NSURLRequest to use as a key for the lookup.
    */
    open func removeCachedResponse(for request: URLRequest) {
        guard let identifier = identifier(for: request) else { return }
        
        inMemoryCacheLock.performLocked {
            if inMemoryCacheContents[identifier] != nil {
                inMemoryCacheOrder.removeAll(where: { $0 == identifier })
                inMemoryCacheContents.removeValue(forKey: identifier)
            }
        }
        
        if let oldURL = diskContentLocators(for: request)?.url {
            try? FileManager.default.removeItem(at: oldURL)
        }
    }
    
    /*! 
        @method removeAllCachedResponses
        @abstract Clears the given cache, removing all NSCachedURLResponse
        objects that it stores.
    */
    open func removeAllCachedResponses() {
        inMemoryCacheLock.performLocked {
            inMemoryCacheContents = [:]
            inMemoryCacheOrder = []
        }
        
        evictFromDiskCache(maximumSize: 0)
    }
    
    /*!
     @method removeCachedResponsesSince:
     @abstract Clears the given cache of any cached responses since the provided date.
     */
    open func removeCachedResponses(since date: Date) {
        inMemoryCacheLock.performLocked { // Memory cache:
            var identifiersToRemove: Set<String> = []
            for entry in inMemoryCacheContents {
                if entry.value.date > date {
                    identifiersToRemove.insert(entry.key)
                }
            }
            
            for toRemove in identifiersToRemove {
                inMemoryCacheContents.removeValue(forKey: toRemove)
            }
            inMemoryCacheOrder.removeAll { identifiersToRemove.contains($0) }
        }
        
        do { // Disk cache:
            let entriesToRemove = diskEntries().filter {
                $0.date > date
            }
            
            for entry in entriesToRemove {
                try? FileManager.default.removeItem(at: entry.url)
            }
        }
    }
    
    /*! 
        @method memoryCapacity
        @abstract In-memory capacity of the receiver. 
        @discussion At the time this call is made, the in-memory cache will truncate its contents to the size given, if necessary.
        @result The in-memory capacity, measured in bytes, for the receiver. 
    */
    open var memoryCapacity: Int {
        didSet {
            inMemoryCacheLock.performLocked {
                evictFromMemoryCacheAssumingLockHeld(maximumSize: memoryCapacity)
            }
        }
    }
    
    /*! 
        @method diskCapacity
        @abstract The on-disk capacity of the receiver. 
        @discussion At the time this call is made, the on-disk cache will truncate its contents to the size given, if necessary.
        @param diskCapacity the new on-disk capacity, measured in bytes, for the receiver.
    */
    open var diskCapacity: Int {
        didSet { evictFromDiskCache(maximumSize: diskCapacity) }
    }
    
    /*! 
        @method currentMemoryUsage
        @abstract Returns the current amount of space consumed by the
        in-memory cache of the receiver.
        @discussion This size, measured in bytes, indicates the current
        usage of the in-memory cache. 
        @result the current usage of the in-memory cache of the receiver.
    */
    open var currentMemoryUsage: Int {
        return inMemoryCacheLock.performLocked {
            return inMemoryCacheContents.values.reduce(0) { (result, entry) in
                return result + entry.cost
            }
        }
    }
    
    /*! 
        @method currentDiskUsage
        @abstract Returns the current amount of space consumed by the
        on-disk cache of the receiver.
        @discussion This size, measured in bytes, indicates the current
        usage of the on-disk cache. 
        @result the current usage of the on-disk cache of the receiver.
    */
    open var currentDiskUsage: Int {
        var total = 0
        enumerateDiskEntries(includingPropertiesForKeys: [.fileSizeKey]) { (entry, stop) in
            if let size = (try? entry.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += size
            }
        }
        
        return total
    }

    open func storeCachedResponse(_ cachedResponse: CachedURLResponse, for dataTask: URLSessionDataTask) {
        guard let request = dataTask.currentRequest else { return }
        storeCachedResponse(cachedResponse, for: request)
    }
    
    open func getCachedResponse(for dataTask: URLSessionDataTask, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        guard let request = dataTask.currentRequest else {
            completionHandler(nil)
            return
        }
        DispatchQueue.global(qos: .background).async {
            completionHandler(self.cachedResponse(for: request))
        }
    }
    
    open func removeCachedResponse(for dataTask: URLSessionDataTask) {
        guard let request = dataTask.currentRequest else { return }
        removeCachedResponse(for: request)
    }
}
