// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if canImport(Dispatch)
@preconcurrency import Dispatch

internal let _NSOperationIsFinished = "isFinished"
internal let _NSOperationIsFinishedAlternate = "finished"
internal let _NSOperationIsExecuting = "isExecuting"
internal let _NSOperationIsExecutingAlternate = "executing"
internal let _NSOperationIsReady = "isReady"
internal let _NSOperationIsReadyAlternate = "ready"
internal let _NSOperationIsCancelled = "isCancelled"
internal let _NSOperationIsCancelledAlternate = "cancelled"
internal let _NSOperationIsAsynchronous = "isAsynchronous"
internal let _NSOperationQueuePriority = "queuePriority"
internal let _NSOperationThreadPriority = "threadPriority"
internal let _NSOperationCompletionBlock = "completionBlock"
internal let _NSOperationName = "name"
internal let _NSOperationDependencies = "dependencies"
internal let _NSOperationQualityOfService = "qualityOfService"
internal let _NSOperationQueueOperationsKeyPath = "operations"
internal let _NSOperationQueueOperationCountKeyPath = "operationCount"
internal let _NSOperationQueueSuspendedKeyPath = "suspended"

extension QualityOfService {
#if canImport(Darwin)
    internal init(_ qos: qos_class_t) {
        switch qos {
        case QOS_CLASS_DEFAULT: self = .default
        case QOS_CLASS_USER_INTERACTIVE: self = .userInteractive
        case QOS_CLASS_USER_INITIATED: self = .userInitiated
        case QOS_CLASS_UTILITY: self = .utility
        case QOS_CLASS_BACKGROUND: self = .background
        default: fatalError("Unsupported qos")
        }
    }
#endif
    internal var qosClass: DispatchQoS {
        switch self {
        case .userInteractive: return .userInteractive
        case .userInitiated: return .userInitiated
        case .utility: return .utility
        case .background: return .background
        case .default: return .default
        }
    }
}

open class Operation : NSObject, @unchecked Sendable {
    struct PointerHashedUnmanagedBox<T: AnyObject>: Hashable {
        var contents: Unmanaged<T>
        func hash(into hasher: inout Hasher) {
            hasher.combine(contents.toOpaque())
        }
        static func == (_ lhs: PointerHashedUnmanagedBox, _ rhs: PointerHashedUnmanagedBox) -> Bool {
            return lhs.contents.toOpaque() == rhs.contents.toOpaque()
        }
    }
    enum __NSOperationState : UInt8, Sendable {
        case initialized = 0x00
        case enqueuing = 0x48
        case enqueued = 0x50
        case dispatching = 0x88
        case starting = 0xD8
        case executing = 0xE0
        case finishing = 0xF0
        case finished = 0xF4
    }
    
    internal var __previousOperation: Unmanaged<Operation>?
    internal var __nextOperation: Unmanaged<Operation>?
    internal var __nextPriorityOperation: Unmanaged<Operation>?
    internal var __queue: Unmanaged<OperationQueue>?
    internal var __dependencies = [Operation]()
    internal var __downDependencies = Set<PointerHashedUnmanagedBox<Operation>>()
    internal var __unfinishedDependencyCount: Int = 0
    internal var __completion: (@Sendable () -> Void)?
    internal var __name: String?
    internal var __schedule: DispatchWorkItem?
    internal var __state: __NSOperationState = .initialized
    internal var __priorityValue: Operation.QueuePriority.RawValue?
    internal var __cachedIsReady: Bool = true
    internal var __isCancelled: Bool = false
    internal var __propertyQoS: QualityOfService?
    
    var __waitCondition = NSCondition()
    var __lock = NSLock()
    var __atomicLoad = NSLock()
    
    internal var _state: __NSOperationState {
        get {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            return __state
        }
        set(newValue) {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            __state = newValue
        }
    }
    
    internal func _compareAndSwapState(_ old: __NSOperationState, _ new: __NSOperationState) -> Bool {
        __atomicLoad.lock()
        defer { __atomicLoad.unlock() }
        if __state != old { return false }
        __state = new
        return true
    }
    
    internal func _lock() {
        __lock.lock()
    }
    
    internal func _unlock() {
        __lock.unlock()
    }
    
    internal var _queue: OperationQueue? {
        _lock()
        defer { _unlock() }
        return __queue?.takeUnretainedValue()
    }
    
    internal func _adopt(queue: OperationQueue, schedule: DispatchWorkItem) {
        _lock()
        defer { _unlock() }
        __queue = Unmanaged.passRetained(queue)
        __schedule = schedule
    }
    
    internal var _isCancelled: Bool {
        __atomicLoad.lock()
        defer { __atomicLoad.unlock() }
        return __isCancelled
    }
    
    internal var _unfinishedDependencyCount: Int {
        get {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            return __unfinishedDependencyCount
        }
    }
    
    internal func _incrementUnfinishedDependencyCount(by amount: Int = 1) {
        __atomicLoad.lock()
        defer { __atomicLoad.unlock() }
        __unfinishedDependencyCount += amount
    }
    
    internal func _decrementUnfinishedDependencyCount(by amount: Int = 1) {
        __atomicLoad.lock()
        defer { __atomicLoad.unlock() }
        __unfinishedDependencyCount -= amount
    }
    
    internal func _addParent(_ parent: Operation) {
        __downDependencies.insert(PointerHashedUnmanagedBox(contents: .passUnretained(parent)))
    }
    
    internal func _removeParent(_ parent: Operation) {
        __downDependencies.remove(PointerHashedUnmanagedBox(contents: .passUnretained(parent)))
    }
    
    internal var _cachedIsReady: Bool {
        get {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            return __cachedIsReady
        }
        set(newValue) {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            __cachedIsReady = newValue
        }
    }
    
    internal func _fetchCachedIsReady(_ retest: inout Bool) -> Bool {
        let setting = _cachedIsReady
        if !setting {
            _lock()
            retest = __unfinishedDependencyCount == 0
            _unlock()
        }
        return setting
    }
    
    internal func _invalidateQueue() {
        _lock()
        __schedule = nil
        let queue = __queue
        __queue = nil
        _unlock()
        queue?.release()
    }
    
    internal func _removeAllDependencies() {
        _lock()
        let deps = __dependencies
        __dependencies.removeAll()
        _unlock()
        
        for dep in deps {
            dep._lock()
            _lock()
            let upIsFinished = dep._state == .finished
            if !upIsFinished && !_isCancelled {
                _decrementUnfinishedDependencyCount()
            }
            dep._removeParent(self)
            _unlock()
            dep._unlock()
        }
    }
    
    internal static func observeValue(forKeyPath keyPath: String, ofObject op: Operation) {
        enum Transition {
            case toFinished
            case toExecuting
            case toReady
        }
        
        let kind: Transition?
        if keyPath == _NSOperationIsFinished || keyPath == _NSOperationIsFinishedAlternate {
            kind = .toFinished
        } else if keyPath == _NSOperationIsExecuting || keyPath == _NSOperationIsExecutingAlternate {
            kind = .toExecuting
        } else if keyPath == _NSOperationIsReady || keyPath == _NSOperationIsReadyAlternate {
            kind = .toReady
        } else {
            kind = nil
        }
        if let transition = kind {
            switch transition {
            case .toFinished: // we only care about NO -> YES
                if !op.isFinished {
                    return
                }
                
                var ready_deps = [Operation]()
                op._lock()
                let state = op._state
                if op.__queue != nil && state.rawValue < __NSOperationState.starting.rawValue {
                    print("*** \(type(of: op)) \(Unmanaged.passUnretained(op).toOpaque()) went isFinished=YES without being started by the queue it is in")
                }
                if state.rawValue < __NSOperationState.finishing.rawValue {
                    op._state = .finishing
                } else if state == .finished {
                    op._unlock()
                    return
                }
                let down_deps = op.__downDependencies
                op.__downDependencies.removeAll()
                if 0 < down_deps.count {
                    for down in down_deps {
                        let idown = down.contents.takeUnretainedValue()
                        idown._lock()
                        if idown._unfinishedDependencyCount == 1 {
                            ready_deps.append(idown)
                        } else if idown._unfinishedDependencyCount > 1 {
                            idown._decrementUnfinishedDependencyCount()
                        } else {
                            assert(idown._unfinishedDependencyCount  == 0)
                            assert(idown._isCancelled == true)
                        }
                        idown._unlock()
                    }
                }
                
                op._state = .finished
                let oq = op.__queue
                op.__queue = nil
                op._unlock()
                
                if 0 < ready_deps.count {
                    for down in ready_deps {
                        down._lock()
                        if down._unfinishedDependencyCount >= 1 {
                            down._decrementUnfinishedDependencyCount()
                        }
                        down._unlock()
                        Operation.observeValue(forKeyPath: _NSOperationIsReady, ofObject: down)
                    }
                }
                
                op.__waitCondition.lock()
                op.__waitCondition.broadcast()
                op.__waitCondition.unlock()
                if let complete = op.__completion {
                    let held = Unmanaged.passRetained(op)
                    DispatchQueue.global(qos: .default).async {
                        complete()
                        held.release()
                    }
                }
                if let queue = oq {
                    queue.takeUnretainedValue()._operationFinished(op, state)
                    queue.release()
                }
            case .toExecuting:
                let isExecuting = op.isExecuting
                op._lock()
                if op._state.rawValue < __NSOperationState.executing.rawValue && isExecuting {
                    op._state = .executing
                }
                op._unlock()
            case .toReady:
                let r = op.isReady
                op._cachedIsReady = r
                let q = op._queue
                if r {
                    q?._schedule()
                }
            }
        }
    }
    
    public override init() { }
    
    open func start() {
        let state = _state
        if __NSOperationState.finished == state { return }
        if !_compareAndSwapState(__NSOperationState.initialized, __NSOperationState.starting) && !(__NSOperationState.starting == state && __queue != nil) {
            switch state {
            case .executing: fallthrough
            case .finishing:
                fatalError("\(self): receiver is already executing")
            default:
                fatalError("\(self): something is trying to start the receiver simultaneously from more than one thread")
            }
        }
        
        if state.rawValue < __NSOperationState.enqueued.rawValue && !isReady {
            _state = state
            fatalError("\(self): receiver is not yet ready to execute")
        }
        
        let isCanc = _isCancelled
        if !isCanc {
            _state = .executing
            Operation.observeValue(forKeyPath: _NSOperationIsExecuting, ofObject: self)
            
            _queue?._execute(self) ?? main()
        }
        
        if __NSOperationState.executing == _state {
            _state = .finishing
            Operation.observeValue(forKeyPath: _NSOperationIsExecuting, ofObject: self)
            Operation.observeValue(forKeyPath: _NSOperationIsFinished, ofObject: self)
        } else {
            _state = .finishing
            Operation.observeValue(forKeyPath: _NSOperationIsFinished, ofObject: self)
        }
    }
    
    open func main() { }
    
    open var isCancelled: Bool {
        return _isCancelled
    }
    
    open func cancel() {
        if isFinished { return }
        
        __atomicLoad.lock()
        __isCancelled = true
        __atomicLoad.unlock()
        
        if __NSOperationState.executing.rawValue <= _state.rawValue {
            return
        }
        
        _lock()
        __unfinishedDependencyCount = 0
        _unlock()
        Operation.observeValue(forKeyPath: _NSOperationIsReady, ofObject: self)
    }
    
    
    open var isExecuting: Bool {
        return __NSOperationState.executing == _state
    }
    
    open var isFinished: Bool {
        return __NSOperationState.finishing.rawValue <= _state.rawValue
    }
    
    open var isAsynchronous: Bool {
        return false
    }
    
    open var isReady: Bool {
        _lock()
        defer { _unlock() }
        return __unfinishedDependencyCount == 0
    }
    
    internal func _addDependency(_ op: Operation) {
        withExtendedLifetime(self) {
            withExtendedLifetime(op) {
                var up: Operation?
                _lock()
                if __dependencies.first(where: { $0 === op }) == nil {
                    __dependencies.append(op)
                    up = op
                }
                _unlock()
                
                if let upwards = up {
                    upwards._lock()
                    _lock()
                    let upIsFinished = upwards._state == __NSOperationState.finished
                    if !upIsFinished && !_isCancelled {
                        assert(_unfinishedDependencyCount >= 0)
                        _incrementUnfinishedDependencyCount()
                        upwards._addParent(self)
                    }
                    _unlock()
                    upwards._unlock()
                }
                Operation.observeValue(forKeyPath: _NSOperationIsReady, ofObject: self)
            }
        }
    }
    
    open func addDependency(_ op: Operation) {
        _addDependency(op)
    }
    
    open func removeDependency(_ op: Operation) {
        withExtendedLifetime(self) {
            withExtendedLifetime(op) {
                var up_canidate: Operation?
                _lock()
                let idxCanidate = __dependencies.firstIndex { $0 === op }
                if idxCanidate != nil {
                    up_canidate = op
                }
                _unlock()
                
                if let canidate = up_canidate {
                    canidate._lock()
                    _lock()
                    if let idx = __dependencies.firstIndex(where: { $0 === op }) {
                        if canidate._state == .finished && _isCancelled {
                            _decrementUnfinishedDependencyCount()
                        }
                        canidate._removeParent(self)
                        __dependencies.remove(at: idx)
                    }
                    
                    _unlock()
                    canidate._unlock()
                }
                Operation.observeValue(forKeyPath: _NSOperationIsReady, ofObject: self)
            }
        }
    }
    
    open var dependencies: [Operation] {
        get {
            _lock()
            defer { _unlock() }
            return __dependencies.filter { !($0 is _BarrierOperation) }
        }
    }
    
    internal func changePriority(_ newPri: Operation.QueuePriority.RawValue) {
        _lock()
        guard let oq = __queue?.takeUnretainedValue() else {
            __priorityValue = newPri
            _unlock()
            return
        }
        _unlock()
        oq._lock()
        var oldPri = __priorityValue
        if oldPri == nil {
            if let v = (0 == oq.__actualMaxNumOps) ? nil : __propertyQoS {
                switch v {
                case .default: oldPri = Operation.QueuePriority.normal.rawValue
                case .userInteractive: oldPri = Operation.QueuePriority.veryHigh.rawValue
                case .userInitiated: oldPri = Operation.QueuePriority.high.rawValue
                case .utility: oldPri = Operation.QueuePriority.low.rawValue
                case .background: oldPri = Operation.QueuePriority.veryLow.rawValue
                }
            } else {
                oldPri = Operation.QueuePriority.normal.rawValue
            }
        }
        if oldPri == newPri {
            oq._unlock()
            return
        }
        __priorityValue = newPri
        var op = oq._firstPriorityOperation(oldPri)
        var prev: Unmanaged<Operation>?
        while let operation = op?.takeUnretainedValue() {
            let nextOp = operation.__nextPriorityOperation
            if operation === self {
                // Remove from old list
                if let previous = prev?.takeUnretainedValue() {
                    previous.__nextPriorityOperation = nextOp
                } else {
                    oq._setFirstPriorityOperation(oldPri!, nextOp)
                }
                if nextOp == nil {
                    oq._setlastPriorityOperation(oldPri!, prev)
                }
                
                __nextPriorityOperation = nil
                
                // Append to new list
                if let oldLast = oq._lastPriorityOperation(newPri)?.takeUnretainedValue() {
                    oldLast.__nextPriorityOperation = Unmanaged.passUnretained(self)
                } else {
                    oq._setFirstPriorityOperation(newPri, Unmanaged.passUnretained(self))
                }
                oq._setlastPriorityOperation(newPri, Unmanaged.passUnretained(self))
                break
            }
            prev = op
            op = nextOp
        }
        oq._unlock()
    }
    
    open var queuePriority: Operation.QueuePriority {
        get {
            guard let prioValue = __priorityValue else {
                return Operation.QueuePriority.normal
            }
            return Operation.QueuePriority(rawValue: prioValue) ?? .veryHigh
        }
        set(newValue) {
            let newPri: Operation.QueuePriority.RawValue
            if Operation.QueuePriority.veryHigh.rawValue <= newValue.rawValue {
                newPri = Operation.QueuePriority.veryHigh.rawValue
            } else if Operation.QueuePriority.high.rawValue <= newValue.rawValue {
                newPri = Operation.QueuePriority.high.rawValue
            } else if Operation.QueuePriority.normal.rawValue <= newValue.rawValue {
                newPri = Operation.QueuePriority.normal.rawValue
            } else if Operation.QueuePriority.low.rawValue < newValue.rawValue {
                newPri = Operation.QueuePriority.normal.rawValue
            } else if Operation.QueuePriority.veryLow.rawValue < newValue.rawValue {
                newPri = Operation.QueuePriority.low.rawValue
            } else {
                newPri = Operation.QueuePriority.veryLow.rawValue
            }
            if __priorityValue != newPri {
                changePriority(newPri)
            }
        }
    }
    
    
    open var completionBlock: (@Sendable () -> Void)? {
        get {
            _lock()
            defer { _unlock() }
            return __completion
        }
        set(newValue) {
            _lock()
            defer { _unlock() }
            __completion = newValue
        }
    }
    
    @available(*, noasync, message: "Use completionBlock or a dependent Operation instead")
    open func waitUntilFinished() {
        __waitCondition.lock()
        while !isFinished {
            __waitCondition.wait()
        }
        __waitCondition.unlock()
    }
    
    open var qualityOfService: QualityOfService {
        get {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            return __propertyQoS ?? QualityOfService.default
        }
        set(newValue) {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            __propertyQoS = newValue
        }
    }
    
    open var name: String? {
        get {
            return __name
        }
        set(newValue) {
            __name = newValue
        }
    }
}

extension Operation {
    public func willChangeValue(forKey key: String) {
        // do nothing
    }
    
    public func didChangeValue(forKey key: String) {
        Operation.observeValue(forKeyPath: key, ofObject: self)
    }
    
    public func willChangeValue<Value>(for keyPath: KeyPath<Operation, Value>) {
        // do nothing
    }
    
    public func didChangeValue<Value>(for keyPath: KeyPath<Operation, Value>) {
        switch keyPath {
        case \Operation.isFinished: didChangeValue(forKey: _NSOperationIsFinished)
        case \Operation.isReady: didChangeValue(forKey: _NSOperationIsReady)
        case \Operation.isCancelled: didChangeValue(forKey: _NSOperationIsCancelled)
        case \Operation.isExecuting: didChangeValue(forKey: _NSOperationIsExecuting)
        default: break
        }
    }
}

extension Operation {
    public enum QueuePriority : Int, Sendable {
        case veryLow = -8
        case low = -4
        case normal = 0
        case high = 4
        case veryHigh = 8
        
        internal static let barrier = 12
        internal static let priorities = [
            Operation.QueuePriority.barrier,
            Operation.QueuePriority.veryHigh.rawValue,
            Operation.QueuePriority.high.rawValue,
            Operation.QueuePriority.normal.rawValue,
            Operation.QueuePriority.low.rawValue,
            Operation.QueuePriority.veryLow.rawValue
        ]
    }
}

open class BlockOperation : Operation, @unchecked Sendable {
    var _block: (@Sendable () -> Void)?
    var _executionBlocks: [@Sendable () -> Void]?
    
    public override init() {
        
    }
    
    public convenience init(block: @Sendable @escaping () -> Void) {
        self.init()
        _block = block
    }
    
    open func addExecutionBlock(_ block: @Sendable @escaping () -> Void) {
        if isExecuting || isFinished {
            fatalError("blocks cannot be added after the operation has started executing or finished")
        }
        _lock()
        defer { _unlock() }
        if _block == nil {
            _block = block
        } else if _executionBlocks == nil {
            _executionBlocks = [block]
        } else {
            _executionBlocks?.append(block)
        }
    }
    
    open var executionBlocks: [@Sendable () -> Void] {
        get {
            _lock()
            defer { _unlock() }
            var blocks = [@Sendable () -> Void]()
            if let existing = _block {
                blocks.append(existing)
            }
            if let existing = _executionBlocks {
                blocks.append(contentsOf: existing)
            }
            return blocks
        }
    }
    
    open override func main() {
        var blocks = [@Sendable () -> Void]()
        _lock()
        if let existing = _block {
            blocks.append(existing)
        }
        if let existing = _executionBlocks {
            blocks.append(contentsOf: existing)
        }
        _unlock()
        for block in blocks {
            block()
        }
    }
}

internal final class _BarrierOperation : Operation, @unchecked Sendable {
    var _block: (() -> Void)?
    init(_ block: @escaping () -> Void) {
        _block = block
    }
    
    override func main() {
        _lock()
        let block = _block
        _block = nil
        _unlock()
        block?()
        _removeAllDependencies()
    }
}

internal final class _OperationQueueProgress : Progress, @unchecked Sendable {
    var queue: Unmanaged<OperationQueue>?
    let lock = NSLock()
    
    init(_ queue: OperationQueue) {
        self.queue = Unmanaged.passUnretained(queue)
        super.init(parent: nil, userInfo: nil)
    }
    
    func invalidateQueue() {
        lock.lock()
        queue = nil
        lock.unlock()
    }
    
    override var totalUnitCount: Int64 {
        get {
            return super.totalUnitCount
        }
        set(newValue) {
            super.totalUnitCount = newValue
            lock.lock()
            queue?.takeUnretainedValue().__progressReporting = true
            lock.unlock()
        }
    }
}

extension OperationQueue {
    public static let defaultMaxConcurrentOperationCount: Int = -1
}

@available(macOS 10.5, *)
open class OperationQueue : NSObject, ProgressReporting, @unchecked Sendable {
    let __queueLock = NSLock()
    let __atomicLoad = NSLock()
    var __firstOperation: Unmanaged<Operation>?
    var __lastOperation: Unmanaged<Operation>?
    var __firstPriorityOperation: (barrier: Unmanaged<Operation>?, veryHigh: Unmanaged<Operation>?, high: Unmanaged<Operation>?, normal: Unmanaged<Operation>?, low: Unmanaged<Operation>?, veryLow: Unmanaged<Operation>?)
    var __lastPriorityOperation: (barrier: Unmanaged<Operation>?, veryHigh: Unmanaged<Operation>?, high: Unmanaged<Operation>?, normal: Unmanaged<Operation>?, low: Unmanaged<Operation>?, veryLow: Unmanaged<Operation>?)
    var _barriers = [_BarrierOperation]()
    var _progress: _OperationQueueProgress?
    var __operationCount: Int = 0
    var __maxNumOps: Int = OperationQueue.defaultMaxConcurrentOperationCount
    var __actualMaxNumOps: Int32 = .max
    var __numExecOps: Int32 = 0
    var __dispatch_queue: DispatchQueue?
    var __backingQueue: DispatchQueue?
    var __name: String?
    var __suspended: Bool = false
    var __overcommit: Bool = false
    var __propertyQoS: QualityOfService?
    var __mainQ: Bool = false
    var __progressReporting: Bool = false
    
    internal func _lock() {
        __queueLock.lock()
    }
    
    internal func _unlock() {
        __queueLock.unlock()
    }
    
    internal var _suspended: Bool {
        __atomicLoad.lock()
        defer { __atomicLoad.unlock() }
        return __suspended
    }
    
    internal func _incrementExecutingOperations() {
        __atomicLoad.lock()
        defer { __atomicLoad.unlock() }
        __numExecOps += 1
    }
    
    internal func _decrementExecutingOperations() {
        __atomicLoad.lock()
        defer { __atomicLoad.unlock() }
        if __numExecOps > 0 {
           __numExecOps -= 1
        }
    }
    
    internal func _incrementOperationCount(by amount: Int = 1) {
        __atomicLoad.lock()
        defer { __atomicLoad.unlock() }
        __operationCount += amount
    }
    
    internal func _decrementOperationCount(by amount: Int = 1) {
        __atomicLoad.lock()
        defer { __atomicLoad.unlock() }
        __operationCount -= amount
    }
    
    internal func _firstPriorityOperation(_ prio: Operation.QueuePriority.RawValue?) -> Unmanaged<Operation>? {
        guard let priority = prio else { return nil }
        switch priority {
        case Operation.QueuePriority.barrier: return __firstPriorityOperation.barrier
        case Operation.QueuePriority.veryHigh.rawValue: return __firstPriorityOperation.veryHigh
        case Operation.QueuePriority.high.rawValue: return __firstPriorityOperation.high
        case Operation.QueuePriority.normal.rawValue: return __firstPriorityOperation.normal
        case Operation.QueuePriority.low.rawValue: return __firstPriorityOperation.low
        case Operation.QueuePriority.veryLow.rawValue: return __firstPriorityOperation.veryLow
        default: fatalError("unsupported priority")
        }
    }
    
    internal func _setFirstPriorityOperation(_ prio: Operation.QueuePriority.RawValue, _ operation: Unmanaged<Operation>?) {
        switch prio {
        case Operation.QueuePriority.barrier: __firstPriorityOperation.barrier = operation
        case Operation.QueuePriority.veryHigh.rawValue: __firstPriorityOperation.veryHigh = operation
        case Operation.QueuePriority.high.rawValue: __firstPriorityOperation.high = operation
        case Operation.QueuePriority.normal.rawValue: __firstPriorityOperation.normal = operation
        case Operation.QueuePriority.low.rawValue: __firstPriorityOperation.low = operation
        case Operation.QueuePriority.veryLow.rawValue: __firstPriorityOperation.veryLow = operation
        default: fatalError("unsupported priority")
        }
    }
    
    internal func _lastPriorityOperation(_ prio: Operation.QueuePriority.RawValue?) -> Unmanaged<Operation>? {
        guard let priority = prio else { return nil }
        switch priority {
        case Operation.QueuePriority.barrier: return __lastPriorityOperation.barrier
        case Operation.QueuePriority.veryHigh.rawValue: return __lastPriorityOperation.veryHigh
        case Operation.QueuePriority.high.rawValue: return __lastPriorityOperation.high
        case Operation.QueuePriority.normal.rawValue: return __lastPriorityOperation.normal
        case Operation.QueuePriority.low.rawValue: return __lastPriorityOperation.low
        case Operation.QueuePriority.veryLow.rawValue: return __lastPriorityOperation.veryLow
        default: fatalError("unsupported priority")
        }
    }
    
    internal func _setlastPriorityOperation(_ prio: Operation.QueuePriority.RawValue, _ operation: Unmanaged<Operation>?) {
        if let op = operation?.takeUnretainedValue() {
            assert(op.queuePriority.rawValue == prio)
        }
        switch prio {
        case Operation.QueuePriority.barrier: __lastPriorityOperation.barrier = operation
        case Operation.QueuePriority.veryHigh.rawValue: __lastPriorityOperation.veryHigh = operation
        case Operation.QueuePriority.high.rawValue: __lastPriorityOperation.high = operation
        case Operation.QueuePriority.normal.rawValue: __lastPriorityOperation.normal = operation
        case Operation.QueuePriority.low.rawValue: __lastPriorityOperation.low = operation
        case Operation.QueuePriority.veryLow.rawValue: __lastPriorityOperation.veryLow = operation
        default: fatalError("unsupported priority")
        }
    }
    
    internal func _operationFinished(_ op: Operation, _ previousState: Operation.__NSOperationState) {
        // There are only three cases where an operation might have a nil queue
        // A) The operation was never added to a queue and we got here by a normal KVO change
        // B) The operation was somehow already finished
        // C) the operation was attempted to be added to a queue but an exception occurred and was ignored...
        // Option C is NOT supported!
        let isBarrier = op is _BarrierOperation
        _lock()
        let nextOp = op.__nextOperation
        if Operation.__NSOperationState.finished == op._state {
            let prevOp = op.__previousOperation
            if let prev = prevOp {
                prev.takeUnretainedValue().__nextOperation = nextOp
            } else {
                __firstOperation = nextOp
            }
            if let next = nextOp {
                next.takeUnretainedValue().__previousOperation = prevOp
            } else {
                __lastOperation = prevOp
            }
            // only decrement execution count on operations that were executing! (the execution was initially set to __NSOperationStateDispatching so we must compare from that or later)
            // else the number of executing operations might underflow
            if previousState.rawValue >= Operation.__NSOperationState.dispatching.rawValue {
                _decrementExecutingOperations()
            }
            op.__previousOperation = nil
            op.__nextOperation = nil
            op._invalidateQueue()
        }
        if !isBarrier {
            _decrementOperationCount()
        }
        _unlock()
        
        _schedule()
        
        if previousState.rawValue >= Operation.__NSOperationState.enqueuing.rawValue {
            Unmanaged.passUnretained(op).release()
        }
    }
    
    internal var _propertyQoS: QualityOfService? {
        get {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            return __propertyQoS
        }
        set(newValue) {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            __propertyQoS = newValue
        }
    }
    
    internal func _synthesizeBackingQueue() -> DispatchQueue {
        guard let queue = __backingQueue else {
            let queue: DispatchQueue
            if let qos = _propertyQoS {
                if let name = __name {
                    queue = DispatchQueue(label: name, qos: qos.qosClass, attributes: .concurrent)
                } else {
                    queue = DispatchQueue(label: "NSOperationQueue \(Unmanaged.passUnretained(self).toOpaque())", qos: qos.qosClass, attributes: .concurrent)
                }
            } else {
                if let name = __name {
                    queue = DispatchQueue(label: name, attributes: .concurrent)
                } else {
                    queue = DispatchQueue(label: "NSOperationQueue \(Unmanaged.passUnretained(self).toOpaque())", attributes: .concurrent)
                }
            }
            __backingQueue = queue
            return queue
        }
        return queue
    }
    
    static internal nonisolated(unsafe) var _currentQueue = NSThreadSpecific<OperationQueue>()
    
    internal func _schedule(_ op: Operation) {
        op._state = .starting
        // set current tsd
        OperationQueue._currentQueue.set(self)
        op.start()
        OperationQueue._currentQueue.clear()
        // We've just cleared _currentQueue storage.
        // NSThreadSpecific doesn't release stored value on clear.
        // This means `self` will leak if we don't release manually.
        Unmanaged.passUnretained(self).release()
        
        // unset current tsd
        if op.isFinished && op._state.rawValue < Operation.__NSOperationState.finishing.rawValue {
            Operation.observeValue(forKeyPath: _NSOperationIsFinished, ofObject: op)
        }
    }
    
    internal func _schedule() {
        var retestOps = [Operation]()
        _lock()
        var slotsAvail = __actualMaxNumOps - __numExecOps
        for prio in Operation.QueuePriority.priorities {
            if 0 >= slotsAvail || _suspended {
                break
            }
            var op = _firstPriorityOperation(prio)
            var prev: Unmanaged<Operation>?
            while let operation = op?.takeUnretainedValue() {
                if 0 >= slotsAvail || _suspended {
                    break
                }
                let next = operation.__nextPriorityOperation
                var retest = false
                // if the cached state is possibly not valid then the isReady value needs to be re-updated
                if Operation.__NSOperationState.enqueued == operation._state && operation._fetchCachedIsReady(&retest) {
                    if let previous = prev?.takeUnretainedValue() {
                        previous.__nextPriorityOperation = next
                    } else {
                        _setFirstPriorityOperation(prio, next)
                    }
                    if next == nil {
                        _setlastPriorityOperation(prio, prev)
                    }
                    
                    operation.__nextPriorityOperation = nil
                    operation._state = .dispatching
                    _incrementExecutingOperations()
                    slotsAvail -= 1
                    
                    let queue: DispatchQueue
                    if __mainQ {
                        queue = DispatchQueue.main
                    } else {
                        queue = __dispatch_queue ?? _synthesizeBackingQueue()
                    }
                    
                    if let schedule = operation.__schedule {
                        if operation is _BarrierOperation {
                            queue.async(flags: .barrier, execute: {
                                schedule.perform()
                            })
                        } else {
                            queue.async(execute: schedule)
                        }
                    }
                    
                    op = next
                } else {
                    if retest {
                        retestOps.append(operation)
                    }
                    prev = op
                    op = next
                }
            }
        }
        _unlock()
        
        for op in retestOps {
            if op.isReady {
                op._cachedIsReady = true
            }
        }
    }
    
    internal var _isReportingProgress: Bool {
        return __progressReporting
    }
    
    internal func _execute(_ op: Operation) {
        var operationProgress: Progress? = nil
        if !(op is _BarrierOperation) && _isReportingProgress {
            let opProgress = Progress(parent: nil, userInfo: nil)
            opProgress.totalUnitCount = 1
            progress.addChild(opProgress, withPendingUnitCount: 1)
            operationProgress = opProgress
        }
        operationProgress?.becomeCurrent(withPendingUnitCount: 1)
        defer { operationProgress?.resignCurrent() }
        
        op.main()
    }
    
    internal var _maxNumOps: Int {
        get {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            return __maxNumOps
        }
        set(newValue) {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            __maxNumOps = newValue
        }
    }
    
    internal var _isSuspended: Bool {
        get {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            return __suspended
        }
        set(newValue) {
            __atomicLoad.lock()
            defer { __atomicLoad.unlock() }
            __suspended = newValue
        }
    }
    
    internal var _operationCount: Int {
        _lock()
        defer { _unlock() }
        var op = __firstOperation
        var cnt = 0
        while let operation = op?.takeUnretainedValue() {
            if !(operation is _BarrierOperation) {
                cnt += 1
            }
            op = operation.__nextOperation
        }
        return cnt
    }
    
    internal func _operations(includingBarriers: Bool = false) -> [Operation] {
        _lock()
        defer { _unlock() }
        var operations = [Operation]()
        var op = __firstOperation
        while let operation = op?.takeUnretainedValue() {
            if includingBarriers || !(operation is _BarrierOperation) {
                operations.append(operation)
            }
            op = operation.__nextOperation
        }
        return operations
    }
    
    public override init() {
        super.init()
        __name = "NSOperationQueue \(Unmanaged<OperationQueue>.passUnretained(self).toOpaque())"
    }
    
    internal init(asMainQueue: ()) {
        super.init()
        __mainQ = true
        __maxNumOps = 1
        __actualMaxNumOps = 1
        __name = "NSOperationQueue Main Queue"
#if canImport(Darwin)
        __propertyQoS = QualityOfService(qos_class_main())
#else
        __propertyQoS = QualityOfService.userInteractive
#endif
        
    }
    
    open var progress: Progress {
        get {
            _lock()
            defer { _unlock() }
            guard let progress = _progress else {
                let progress = _OperationQueueProgress(self)
                _progress = progress
                return progress
            }
            return progress
        }
    }
    
    internal func _addOperations(_ ops: [Operation], barrier: Bool = false) {
        if ops.isEmpty { return }
        
        var failures = 0
        var successes = 0
        var firstNewOp: Unmanaged<Operation>?
        var lastNewOp: Unmanaged<Operation>?
        for op in ops {
            if op._compareAndSwapState(.initialized, .enqueuing) {
                successes += 1
                if 0 == failures {
                    let retained = Unmanaged.passRetained(op)
                    op._cachedIsReady = op.isReady
                    let schedule: DispatchWorkItem
                    
                    if let qos = op.__propertyQoS?.qosClass {
                        schedule = DispatchWorkItem.init(qos: qos, flags: .enforceQoS, block: {
                            self._schedule(op)
                        })
                    } else {
                        schedule = DispatchWorkItem(flags: .assignCurrentContext, block: {
                            self._schedule(op)
                        })
                    }
                    op._adopt(queue: self, schedule: schedule)
                    op.__previousOperation = lastNewOp
                    op.__nextOperation = nil
                    if let lastNewOperation = lastNewOp?.takeUnretainedValue() {
                        lastNewOperation.__nextOperation = retained
                    } else {
                        firstNewOp = retained
                    }
                    lastNewOp = retained
                } else {
                    _ = op._compareAndSwapState(.enqueuing, .initialized)
                }
            } else {
                failures += 1
            }
        }
        
        if 0 < failures {
            while let firstNewOperation = firstNewOp?.takeUnretainedValue() {
                let nextNewOp = firstNewOperation.__nextOperation
                firstNewOperation._invalidateQueue()
                firstNewOperation.__previousOperation = nil
                firstNewOperation.__nextOperation = nil
                _ = firstNewOperation._compareAndSwapState(.enqueuing, .initialized)
                firstNewOp?.release()
                firstNewOp = nextNewOp
            }
            fatalError("operations finished, executing or already in a queue cannot be enqueued")
        }
        
        // Attach any operations pending attachment to main list
        
        if !barrier {
            _lock()
            _incrementOperationCount()
        }
        
        var pending = firstNewOp
        if let pendingOperation = pending?.takeUnretainedValue() {
            let old_last = __lastOperation
            pendingOperation.__previousOperation = old_last
            if let old = old_last?.takeUnretainedValue() {
                old.__nextOperation = pending
            } else {
                __firstOperation = pending
            }
            __lastOperation = lastNewOp
        }
        while let pendingOperation = pending?.takeUnretainedValue() {
            if !barrier {
                var barrierOp = _firstPriorityOperation(Operation.QueuePriority.barrier)
                while let barrierOperation = barrierOp?.takeUnretainedValue() {
                    pendingOperation._addDependency(barrierOperation)
                    barrierOp = barrierOperation.__nextPriorityOperation
                }
            }
            
            _ = pendingOperation._compareAndSwapState(.enqueuing, .enqueued)
            var pri = pendingOperation.__priorityValue
            if pri == nil {
                let v = __actualMaxNumOps == 1 ? nil : pendingOperation.__propertyQoS
                if let qos = v {
                    switch qos {
                    case .default: pri = Operation.QueuePriority.normal.rawValue
                    case .userInteractive: pri = Operation.QueuePriority.veryHigh.rawValue
                    case .userInitiated: pri = Operation.QueuePriority.high.rawValue
                    case .utility: pri = Operation.QueuePriority.low.rawValue
                    case .background: pri = Operation.QueuePriority.veryLow.rawValue
                    }
                } else {
                    pri = Operation.QueuePriority.normal.rawValue
                }
            }
            pendingOperation.__nextPriorityOperation = nil
            if let old_last = _lastPriorityOperation(pri)?.takeUnretainedValue() {
                old_last.__nextPriorityOperation = pending
            } else {
                _setFirstPriorityOperation(pri!, pending)
            }
            _setlastPriorityOperation(pri!, pending)
            pending = pendingOperation.__nextOperation
        }
        
        if !barrier {
            _unlock()
        }
        
        if !barrier {
            _schedule()
        }
    }
    
    open func addOperation(_ op: Operation) {
        _addOperations([op], barrier: false)
    }
    
    @available(*, noasync, message: "Use addBarrierBlock or a dependent Operation instead")
    open func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool) {
        _addOperations(ops, barrier: false)
        if wait {
            for op in ops {
                op.waitUntilFinished()
            }
        }
    }
    
    open func addOperation(_ block: @Sendable @escaping () -> Void) {
        let op = BlockOperation(block: block)
        if let qos = __propertyQoS {
            op.qualityOfService = qos
        }
        addOperation(op)
    }
    
    open func addBarrierBlock(_ barrier: @Sendable @escaping () -> Void) {
        var queue: DispatchQueue?
        _lock()
        if let op = __firstOperation {
            let barrierOperation = _BarrierOperation(barrier)
            barrierOperation.__priorityValue = Operation.QueuePriority.barrier
            var iterOp: Unmanaged<Operation>? = op
            while let operation = iterOp?.takeUnretainedValue() {
                barrierOperation.addDependency(operation)
                iterOp = operation.__nextOperation
            }
            _addOperations([barrierOperation], barrier: true)
        } else {
            queue = _synthesizeBackingQueue()
        }
        _unlock()
        
        if let q = queue {
            q.async(flags: .barrier, execute: barrier)
        } else {
            _schedule()
        }
    }
    
    open var maxConcurrentOperationCount: Int {
        get {
            return _maxNumOps
        }
        set(newValue) {
            if newValue < 0 && newValue != OperationQueue.defaultMaxConcurrentOperationCount {
                fatalError("count (\(newValue)) cannot be negative")
            }
            if !__mainQ {
                _lock()
                _maxNumOps = newValue
                let acnt = OperationQueue.defaultMaxConcurrentOperationCount == newValue || Int32.max < newValue ? Int32.max : Int32(newValue)
                __actualMaxNumOps = acnt
                _unlock()
                _schedule()
            }
            
        }
    }
    
    open var isSuspended: Bool {
        get {
            return _isSuspended
        }
        set(newValue) {
            if !__mainQ {
                _isSuspended = newValue
                if !newValue {
                    _schedule()
                }
            }
        }
    }
    
    open var name: String? {
        get {
            _lock()
            defer { _unlock() }
            return __name ?? "NSOperationQueue \(Unmanaged.passUnretained(self).toOpaque())"
        }
        set(newValue) {
            if !__mainQ {
                _lock()
                __name = newValue ?? ""
                _unlock()
            }
        }
    }
    
    open var qualityOfService: QualityOfService {
        get {
            return _propertyQoS ?? .default
        }
        set(newValue) {
            if !__mainQ {
                _lock()
                _propertyQoS = newValue
                _unlock()
            }
        }
    }
    
    unowned(unsafe) open var underlyingQueue: DispatchQueue? {
        get {
            if __mainQ {
                return DispatchQueue.main
            } else {
                _lock()
                defer { _unlock() }
                return __dispatch_queue
            }
        }
        set(newValue) {
            if !__mainQ {
                if 0 < _operationCount {
                    fatalError("operation queue must be empty in order to change underlying dispatch queue")
                }
                __dispatch_queue = newValue
            }
        }
    }
    
    open func cancelAllOperations() {
        if !__mainQ {
            for op in _operations(includingBarriers: true) {
                op.cancel()
            }
        }
    }
    
    @available(*, noasync, message: "Use completionBlock or a dependent Operation instead")
    open func waitUntilAllOperationsAreFinished() {
        var ops = _operations(includingBarriers: true)
        while 0 < ops.count {
            for op in ops {
                op.waitUntilFinished()
            }
            ops = _operations(includingBarriers: true)
        }
    }
    
    open class var current: OperationQueue? {
        get {
            if Thread.isMainThread {
                return main
            }
            return OperationQueue._currentQueue.current
        }
    }
    
    open class var main: OperationQueue {
        get {
            struct Once {
                static let mainQ = OperationQueue(asMainQueue: ())
            }
            return Once.mainQ
        }
    }
}

extension OperationQueue {
    // These two functions are inherently a race condition and should be avoided if possible
    
    @available(macOS, introduced: 10.5, deprecated: 100000, message: "access to operations is inherently a race condition, it should not be used. For barrier style behaviors please use addBarrierBlock: instead")
    public var operations: [Operation] {
        get {
            return _operations(includingBarriers: false)
        }
    }
    
    
    @available(macOS, introduced: 10.6, deprecated: 100000)
    public var operationCount: Int {
        get {
            return _operationCount
        }
    }
}
#endif
