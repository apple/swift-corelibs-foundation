// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

open class NSNotification: NSObject, NSCopying, NSCoding {
    public struct Name : RawRepresentable, Equatable, Hashable {
        public private(set) var rawValue: String
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        public var hashValue: Int {
            return self.rawValue.hashValue
        }
        
        public static func ==(lhs: Name, rhs: Name) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }
    }

    private(set) open var name: Name
    
    private(set) open var object: Any?
    
    private(set) open var userInfo: [AnyHashable : Any]?
    
    public convenience override init() {
        /* do not invoke; not a valid initializer for this class */
        fatalError()
    }
    
    public init(name: Name, object: Any?, userInfo: [AnyHashable : Any]? = nil) {
        self.name = name
        self.object = object
        self.userInfo = userInfo
    }
    
    public convenience required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        guard let name = aDecoder.decodeObject(of: NSString.self, forKey:"NS.name") else {
            return nil
        }
        let object = aDecoder.decodeObject(forKey: "NS.object")
        //            let userInfo = aDecoder.decodeObject(of: NSDictionary.self, forKey: "NS.userinfo")
        self.init(name: Name(rawValue: String._unconditionallyBridgeFromObjectiveC(name)), object: object as! NSObject, userInfo: nil)
    }
    
    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        aCoder.encode(self.name.rawValue._bridgeToObjectiveC(), forKey:"NS.name")
        aCoder.encode(self.object, forKey:"NS.object")
        aCoder.encode(self.userInfo?._bridgeToObjectiveC(), forKey:"NS.userinfo")
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
    
    open override var description: String {
        var str = "\(type(of: self)) \(Unmanaged.passUnretained(self).toOpaque()) {"
        
        str += "name = \(self.name.rawValue)"
        if let object = self.object {
            str += "; object = \(object)"
        }
        if let userInfo = self.userInfo {
            str += "; userInfo = \(userInfo)"
        }
        str += "}"
        
        return str
    }
}

private class NSNotificationReceiver : NSObject {
    fileprivate weak var object: NSObject?
    fileprivate var name: Notification.Name?
    fileprivate var block: ((Notification) -> Void)?
    fileprivate var sender: AnyObject?
    fileprivate var queue: OperationQueue?
}

extension Sequence where Iterator.Element : NSNotificationReceiver {

    /// Returns collection of `NSNotificationReceiver`.
    ///
    /// Will return:
    ///  - elements that property `object` is not equal to `observerToFilter`
    ///  - elements that property `name` is not equal to parameter `name` if specified.
    ///  - elements that property `sender` is not equal to parameter `object` if specified.
    ///
    fileprivate func filterOutObserver(_ observerToFilter: AnyObject, name:Notification.Name? = nil, object: Any? = nil) -> [Iterator.Element] {
        return self.filter { observer in

            let differentObserver = observer.object !== observerToFilter
            let nameSpecified = name != nil
            let differentName = observer.name != name
            let objectSpecified = object != nil
            let differentSender = observer.sender !== _SwiftValue.store(object)

            return differentObserver || (nameSpecified  && differentName) || (objectSpecified && differentSender)
        }
    }

    /// Returns collection of `NSNotificationReceiver`.
    ///
    /// Will return:
    ///  - elements that property `sender` is `nil` or equals specified parameter `sender`.
    ///  - elements that property `name` is `nil` or equals specified parameter `name`.
    ///
    fileprivate func observersMatchingName(_ name:Notification.Name? = nil, sender: Any? = nil) -> [Iterator.Element] {
        return self.filter { observer in

            let emptyName = observer.name == nil
            let sameName = observer.name == name
            let emptySender = observer.sender == nil
            let sameSender = observer.sender === _SwiftValue.store(sender)

            return (emptySender || sameSender) && (emptyName || sameName)
        }
    }
}

private let _defaultCenter: NotificationCenter = NotificationCenter()

open class NotificationCenter: NSObject {
    
    private var _observers: [NSNotificationReceiver]
    private let _observersLock = NSLock()
    
    public required override init() {
        _observers = [NSNotificationReceiver]()
    }
    
    open class var `default`: NotificationCenter {
        return _defaultCenter
    }
    
    open func post(_ notification: Notification) {

        let sendTo = _observersLock.synchronized({
            return _observers.observersMatchingName(notification.name, sender: notification.object)
        })

        for observer in sendTo {
            guard let block = observer.block else {
                continue
            }
            
            if let queue = observer.queue, queue != OperationQueue.current {
                queue.addOperation { block(notification) }
                queue.waitUntilAllOperationsAreFinished()
            } else {
                block(notification)
            }
        }
    }

    open func post(name aName: NSNotification.Name, object anObject: Any?, userInfo aUserInfo: [AnyHashable : Any]? = nil) {
        let notification = Notification(name: aName, object: anObject, userInfo: aUserInfo)
        post(notification)
    }

    open func removeObserver(_ observer: Any) {
        removeObserver(observer, name: nil, object: nil)
    }

    open func removeObserver(_ observer: Any, name aName: NSNotification.Name?, object: Any?) {
        guard let observer = observer as? NSObject else {
            return
        }

        _observersLock.synchronized({
            self._observers = _observers.filterOutObserver(observer, name: aName, object: object)
        })
    }

    @available(*, unavailable, renamed: "addObserver(forName:object:queue:using:)")
    open func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, usingBlock block: @escaping (Notification) -> Void) -> NSObjectProtocol {
        return addObserver(forName: name, object: obj, queue: queue, using: block)
    }

    open func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
        let object = NSObject()
        
        let newObserver = NSNotificationReceiver()
        newObserver.object = object
        newObserver.name = name
        newObserver.block = block
        newObserver.sender = _SwiftValue.store(obj)
        newObserver.queue = queue

        _observersLock.synchronized({
            _observers.append(newObserver)
        })
        
        return object
    }

}

extension NSNotification : _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as Notification)
    }
}
