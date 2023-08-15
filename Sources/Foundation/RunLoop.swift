// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if os(Linux) || os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(OpenBSD)
import CoreFoundation
#else
@_implementationOnly import CoreFoundation
#endif

internal let kCFRunLoopEntry = CFRunLoopActivity.entry.rawValue
internal let kCFRunLoopBeforeTimers = CFRunLoopActivity.beforeTimers.rawValue
internal let kCFRunLoopBeforeSources = CFRunLoopActivity.beforeSources.rawValue
internal let kCFRunLoopBeforeWaiting = CFRunLoopActivity.beforeWaiting.rawValue
internal let kCFRunLoopAfterWaiting = CFRunLoopActivity.afterWaiting.rawValue
internal let kCFRunLoopExit = CFRunLoopActivity.exit.rawValue
internal let kCFRunLoopAllActivities = CFRunLoopActivity.allActivities.rawValue

extension RunLoop {
    public struct Mode : RawRepresentable, Equatable, Hashable {
        public private(set) var rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

extension RunLoop.Mode {
    public static let `default`: RunLoop.Mode = RunLoop.Mode("kCFRunLoopDefaultMode")
    public static let common: RunLoop.Mode = RunLoop.Mode("kCFRunLoopCommonModes")
    
    // Use this instead of .rawValue._cfObject; this will allow CFRunLoop to use pointer equality internally.
    fileprivate var _cfStringUniquingKnown: CFString {
        if self == .default {
            return kCFRunLoopDefaultMode
        } else if self == .common {
            return kCFRunLoopCommonModes
        } else {
            return rawValue._cfObject
        }
    }
}

internal func _NSRunLoopNew(_ cf: CFRunLoop) -> Unmanaged<AnyObject> {
    let rl = Unmanaged<RunLoop>.passRetained(RunLoop(cfObject: cf))
    return unsafeBitCast(rl, to: Unmanaged<AnyObject>.self) // this retain is balanced on the other side of the CF fence
}

open class RunLoop: NSObject {
    internal var _cfRunLoopStorage : AnyObject!
    internal final var _cfRunLoop: CFRunLoop! {
        get { unsafeBitCast(_cfRunLoopStorage, to: CFRunLoop?.self) }
        set { _cfRunLoopStorage = newValue }
    }

    internal static var _mainRunLoop: RunLoop = {
        let cfObject: CFRunLoop! = CFRunLoopGetMain()
#if os(Windows)
        // Enable the main runloop on Windows to process the Windows UI events.
        // Windows, similar to AppKit and UIKit, expects to process the UI
        // events on the main thread.
        _CFRunLoopSetWindowsMessageQueueMask(cfObject, QS_ALLINPUT, kCFRunLoopDefaultMode)
#endif
        return RunLoop(cfObject: cfObject)
    }()

    internal init(cfObject : CFRunLoop) {
        _cfRunLoopStorage = cfObject
    }

    open class var current: RunLoop {
        return _CFRunLoopGet2(CFRunLoopGetCurrent()) as! RunLoop
    }

    open class var main: RunLoop {
        return _CFRunLoopGet2(_mainRunLoop._cfRunLoop) as! RunLoop
    }

    open var currentMode: RunLoop.Mode? {
        if let mode = CFRunLoopCopyCurrentMode(_cfRunLoop) {
            return RunLoop.Mode(mode._swiftObject)
        } else {
            return nil
        }
    }
    
    // On platforms where it's available, getCFRunLoop() can be overridden and we use it below.
    // Make sure we honor the override -- var currentCFRunLoop will do so on platforms where overrides are available.

    #if os(Linux) || os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(OpenBSD)
    internal var currentCFRunLoop: CFRunLoop { getCFRunLoop() }

    @available(*, deprecated, message: "Directly accessing the run loop may cause your code to not become portable in the future.")
    open func getCFRunLoop() -> CFRunLoop {
        return _cfRunLoop
    }
    #else
    internal final var currentCFRunLoop: CFRunLoop { _cfRunLoop }

    @available(*, unavailable, message: "Core Foundation is not available on your platform.")
    open func getCFRunLoop() -> Never {
        fatalError()
    }
    #endif

    open func add(_ timer: Timer, forMode mode: RunLoop.Mode) {
        CFRunLoopAddTimer(_cfRunLoop, timer._cfObject, mode._cfStringUniquingKnown)
    }

    private let monitoredPortsWithModesLock = NSLock() // guards:
    private var monitoredPortsWithModes: [Port: Set<RunLoop.Mode>] = [:]
    private var monitoredPortObservers:  [Port: NSObjectProtocol]  = [:]
    
    open func add(_ aPort: Port, forMode mode: RunLoop.Mode) {
        var shouldSchedule = false
        monitoredPortsWithModesLock.synchronized {
            if monitoredPortsWithModes[aPort]?.contains(mode) != true {
                monitoredPortsWithModes[aPort, default: []].insert(mode)
                
                let shouldStartMonitoring = monitoredPortObservers[aPort] == nil
                if shouldStartMonitoring {
                    monitoredPortObservers[aPort] = NotificationCenter.default.addObserver(forName: Port.didBecomeInvalidNotification, object: aPort, queue: nil, using: { [weak self] (notification) in
                        self?.portDidInvalidate(aPort)
                    })
                }
                
                shouldSchedule = true
            }
        }
        
        if shouldSchedule {
            aPort.schedule(in: self, forMode: mode)
        }
    }
    
    private func portDidInvalidate(_ aPort: Port) {
        monitoredPortsWithModesLock.synchronized {
            if let observer = monitoredPortObservers.removeValue(forKey: aPort) {
                NotificationCenter.default.removeObserver(observer)
            }
            monitoredPortsWithModes.removeValue(forKey: aPort)
        }
    }

    open func remove(_ aPort: Port, forMode mode: RunLoop.Mode) {
        var shouldRemove = false
        monitoredPortsWithModesLock.synchronized {
            guard let modes = monitoredPortsWithModes[aPort], modes.contains(mode) else {
                return
            }
            
            shouldRemove = true
            
            if modes.count == 1 {
                if let observer = monitoredPortObservers.removeValue(forKey: aPort) {
                    NotificationCenter.default.removeObserver(observer)
                }
                monitoredPortsWithModes.removeValue(forKey: aPort)
            } else {
                monitoredPortsWithModes[aPort]?.remove(mode)
            }
        }
        
        if shouldRemove {
            aPort.remove(from: self, forMode: mode)
        }
    }

    open func limitDate(forMode mode: RunLoop.Mode) -> Date? {
        if _cfRunLoop !== CFRunLoopGetCurrent() {
            return nil
        }
        let modeArg = mode.rawValue._cfObject
        
        CFRunLoopRunInMode(modeArg, -10.0, true) /* poll run loop to fire ready timers and performers, as used to be done here */
        if _CFRunLoopFinished(_cfRunLoop, modeArg) {
            return nil
        }
        
        let nextTimerFireAbsoluteTime = CFRunLoopGetNextTimerFireDate(CFRunLoopGetCurrent(), modeArg)

        if (nextTimerFireAbsoluteTime == 0) {
            return Date.distantFuture
        }

        return Date(timeIntervalSinceReferenceDate: nextTimerFireAbsoluteTime)
    }

    open func acceptInput(forMode mode: String, before limitDate: Date) {
        if _cfRunLoop !== CFRunLoopGetCurrent() {
            return
        }
        CFRunLoopRunInMode(mode._cfObject, limitDate.timeIntervalSinceReferenceDate - CFAbsoluteTimeGetCurrent(), true)
    }

}

extension RunLoop {

    public func run() {
        while run(mode: .default, before: Date.distantFuture) { }
    }

    public func run(until limitDate: Date) {
        while run(mode: .default, before: limitDate) && limitDate.timeIntervalSinceReferenceDate > CFAbsoluteTimeGetCurrent() { }
    }

    public func run(mode: RunLoop.Mode, before limitDate: Date) -> Bool {
        if _cfRunLoop !== CFRunLoopGetCurrent() {
            return false
        }
        let modeArg = mode._cfStringUniquingKnown
        if _CFRunLoopFinished(_cfRunLoop, modeArg) {
            return false
        }
        
        let limitTime = limitDate.timeIntervalSinceReferenceDate
        let ti = limitTime - CFAbsoluteTimeGetCurrent()
        CFRunLoopRunInMode(modeArg, ti, true)
        return true
    }

    public func perform(inModes modes: [RunLoop.Mode], block: @escaping () -> Void) {
        CFRunLoopPerformBlock(currentCFRunLoop, (modes.map { $0._cfStringUniquingKnown })._cfObject, block)
    }
    
    public func perform(_ block: @escaping () -> Void) {
        perform(inModes: [.default], block: block)
    }
}

// These exist as SPI for XCTest for now. Do not rely on their contracts or continued existence.

extension RunLoop {
    @available(*, deprecated, message: "For XCTest use only.")
    public func _stop() {
        CFRunLoopStop(currentCFRunLoop)
    }
    
    @available(*, deprecated, message: "For XCTest use only.")
    public func _observe(_ activities: _Activities, in mode: RunLoop.Mode = .default, repeats: Bool = true, order: Int = 0, handler: @escaping (_Activity) -> Void) -> _Observer {
        let observer = _Observer(activities: activities, repeats: repeats, order: order, handler: handler)
        CFRunLoopAddObserver(self.currentCFRunLoop, observer.cfObserver, mode._cfStringUniquingKnown)
        return observer
    }
    
    @available(*, deprecated, message: "For XCTest use only.")
    public func _observe(_ activity: _Activity, in mode: RunLoop.Mode = .default, repeats: Bool = true, order: Int = 0, handler: @escaping (_Activity) -> Void) -> _Observer {
        return _observe(_Activities(activity), in: mode, repeats: repeats, order: order, handler: handler)
    }
    
    @available(*, deprecated, message: "For XCTest use only.")
    public func _add(_ source: _Source, forMode mode: RunLoop.Mode) {
        CFRunLoopAddSource(_cfRunLoop, source.cfSource, mode._cfStringUniquingKnown)
    }
    
    @available(*, deprecated, message: "For XCTest use only.")
    public func _remove(_ source: _Source, for mode: RunLoop.Mode) {
        CFRunLoopRemoveSource(_cfRunLoop, source.cfSource, mode._cfStringUniquingKnown)
    }
}

extension RunLoop {
    @available(*, deprecated, message: "For XCTest use only.")
    public enum _Activity: UInt {
        // These must match CFRunLoopActivity.
        case entry = 0
        case beforeTimers = 1
        case beforeSources = 2
        case beforeWaiting = 32
        case afterWaiting = 64
        case exit = 128
    }
    
    @available(*, deprecated, message: "For XCTest use only.")
    public struct _Activities: OptionSet {
        public var rawValue: UInt
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        public init(_ activity: _Activity) {
            self.rawValue = activity.rawValue
        }
        
        public static let entry = _Activities(rawValue: _Activity.entry.rawValue)
        public static let beforeTimers = _Activities(rawValue: _Activity.beforeTimers.rawValue)
        public static let beforeSources = _Activities(rawValue: _Activity.beforeSources.rawValue)
        public static let beforeWaiting = _Activities(rawValue: _Activity.beforeWaiting.rawValue)
        public static let afterWaiting = _Activities(rawValue: _Activity.afterWaiting.rawValue)
        public static let exit = _Activities(rawValue: _Activity.exit.rawValue)
        public static let allActivities = _Activities(rawValue: 0x0FFFFFFF)
    }
    
    @available(*, deprecated, message: "For XCTest use only.")
    public class _Observer {
        fileprivate let _cfObserverStorage: AnyObject
        fileprivate var cfObserver: CFRunLoopObserver { unsafeBitCast(_cfObserverStorage, to: CFRunLoopObserver.self) }
        
        fileprivate init(activities: _Activities, repeats: Bool, order: Int, handler: @escaping (_Activity) -> Void) {
            self._cfObserverStorage = CFRunLoopObserverCreateWithHandler(kCFAllocatorSystemDefault, CFOptionFlags(activities.rawValue), repeats, CFIndex(order), { (cfObserver, cfActivity) in
                guard let activity = _Activity(rawValue: UInt(cfActivity.rawValue)) else { return }
                handler(activity)
            })
        }
        
        public func invalidate() {
            CFRunLoopObserverInvalidate(cfObserver)
        }
        
        public var order: Int {
            Int(CFRunLoopObserverGetOrder(cfObserver))
        }
        
        public var isValid: Bool {
            CFRunLoopObserverIsValid(cfObserver)
        }
        
        deinit {
            invalidate()
        }
    }
    
    @available(*, deprecated, message: "For XCTest use only.")
    open class _Source: NSObject {
        fileprivate var _cfSourceStorage: AnyObject!
        
        public init(order: Int = 0) {
            super.init()
            
            var context = CFRunLoopSourceContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: { (info) -> Unmanaged<CFString>? in
                    let me = Unmanaged<_Source>.fromOpaque(info!).takeUnretainedValue()
                    return .passRetained(String(describing: me)._cfObject)
                },
                equal: { (infoA, infoB) in
                    let a = Unmanaged<_Source>.fromOpaque(infoA!).takeUnretainedValue()
                    let b = Unmanaged<_Source>.fromOpaque(infoB!).takeUnretainedValue()
                    return a == b ? true : false
                },
                hash: { (info) -> CFHashCode in
                    let me = Unmanaged<_Source>.fromOpaque(info!).takeUnretainedValue()
                    return CFHashCode(bitPattern: me.hashValue)
                },
                schedule: { (info, cfRunLoop, cfRunLoopMode) in
                    let me = Unmanaged<_Source>.fromOpaque(info!).takeUnretainedValue()
                    var mode: RunLoop.Mode = .default
                    if let cfRunLoopMode = cfRunLoopMode {
                        mode = RunLoop.Mode(rawValue: cfRunLoopMode._swiftObject)
                    }
                    
                    me.didSchedule(in: mode)
                },
                cancel: { (info, cfRunLoop, cfRunLoopMode) in
                    let me = Unmanaged<_Source>.fromOpaque(info!).takeUnretainedValue()
                    var mode: RunLoop.Mode = .default
                    if let cfRunLoopMode = cfRunLoopMode {
                        mode = RunLoop.Mode(rawValue: cfRunLoopMode._swiftObject)
                    }
                    
                    me.didCancel(in: mode)
                },
                perform: { (info) in
                    let me = Unmanaged<_Source>.fromOpaque(info!).takeUnretainedValue()
                    me.perform()
                })
            
            self._cfSourceStorage = CFRunLoopSourceCreate(kCFAllocatorSystemDefault, CFIndex(order), &context)
        }
        
        open func didSchedule(in mode: RunLoop.Mode) {
            // Override me.
        }
        
        open func didCancel(in mode: RunLoop.Mode) {
            // Override me.
        }
        
        open func perform() {
            // Override me.
        }
        
        open func invalidate() {
            CFRunLoopSourceInvalidate(cfSource)
        }
        
        open var order: Int {
            Int(CFRunLoopSourceGetOrder(cfSource))
        }

        open var isValid: Bool {
            CFRunLoopSourceIsValid(cfSource)
        }
        
        open func signal() {
            CFRunLoopSourceSignal(cfSource)
        }
        
        deinit {
            invalidate()
        }
    }
}

extension RunLoop._Source {
    fileprivate var cfSource: CFRunLoopSource {
      unsafeBitCast(_cfSourceStorage, to: CFRunLoopSource.self)
    }
}
