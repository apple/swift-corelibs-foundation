//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
// -----------------------------------------------------------------------------
///
/// libcurl *multi handle* wrapper.
/// These are libcurl helpers for the URLSession API code.
/// - SeeAlso: https://curl.haxx.se/libcurl/c/
/// - SeeAlso: URLSession.swift
///
// -----------------------------------------------------------------------------

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import SwiftFoundation
#else
import Foundation
#endif

@_implementationOnly import CoreFoundation
@_implementationOnly import CFURLSessionInterface
import Dispatch



extension URLSession {
    /// Minimal wrapper around [curl multi interface](https://curl.haxx.se/libcurl/c/libcurl-multi.html).
    ///
    /// The the *multi handle* manages the sockets for easy handles
    /// (`_EasyHandle`), and this implementation uses
    /// libdispatch to listen for sockets being read / write ready.
    ///
    /// Using `DispatchSource` allows this implementation to be
    /// non-blocking and all code to run on the same thread /
    /// `DispatchQueue` -- thus keeping is simple.
    ///
    /// - SeeAlso: _EasyHandle
    internal final class _MultiHandle {
        let rawHandle = CFURLSessionMultiHandleInit()
        let queue: DispatchQueue
        let group = DispatchGroup()
        fileprivate var easyHandles: [_EasyHandle] = []
        fileprivate var socketReferences: [CFURLSession_socket_t: _SocketReference] = [:]
        fileprivate var timeoutSource: _TimeoutSource? = nil
        private var reentrantInUpdateTimeoutTimer = false
        
        init(configuration: URLSession._Configuration, workQueue: DispatchQueue) {
            queue = DispatchQueue(label: "MultiHandle.isolation", target: workQueue)
            setupCallbacks()
            configure(with: configuration)
        }
        deinit {
            // C.f.: <https://curl.haxx.se/libcurl/c/curl_multi_cleanup.html>
            easyHandles.forEach {
                try! CFURLSessionMultiHandleRemoveHandle(rawHandle, $0.rawHandle).asError()
            }
            try! CFURLSessionMultiHandleDeinit(rawHandle).asError()
        }
    }
}

extension URLSession._MultiHandle {
    func configure(with configuration: URLSession._Configuration) {
        #if !NS_CURL_MISSING_MAX_HOST_CONNECTIONS
        try! CFURLSession_multi_setopt_l(rawHandle, CFURLSessionMultiOptionMAX_HOST_CONNECTIONS, numericCast(configuration.httpMaximumConnectionsPerHost)).asError()
        #endif
        
        try! CFURLSession_multi_setopt_l(rawHandle, CFURLSessionMultiOptionPIPELINING, configuration.httpShouldUsePipelining ? 3 : 2).asError()
        //TODO: We may want to set
        //    CFURLSessionMultiOptionMAXCONNECTS
        //    CFURLSessionMultiOptionMAX_TOTAL_CONNECTIONS
    }
}

fileprivate extension URLSession._MultiHandle {
    static func from(callbackUserData userdata: UnsafeMutableRawPointer?) -> URLSession._MultiHandle? {
        guard let userdata = userdata else { return nil }
        return Unmanaged<URLSession._MultiHandle>.fromOpaque(userdata).takeUnretainedValue()
    }
}

fileprivate extension URLSession._MultiHandle {
    /// Forward the libcurl callbacks into Swift methods
    func setupCallbacks() {
        // Socket
        try! CFURLSession_multi_setopt_ptr(rawHandle, CFURLSessionMultiOptionSOCKETDATA, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())).asError()
        try! CFURLSession_multi_setopt_sf(rawHandle, CFURLSessionMultiOptionSOCKETFUNCTION) { (easyHandle: CFURLSessionEasyHandle, socket: CFURLSession_socket_t, what: Int32, userdata: UnsafeMutableRawPointer?, socketptr: UnsafeMutableRawPointer?) -> Int32 in
            guard let handle = URLSession._MultiHandle.from(callbackUserData: userdata) else { fatalError() }
            return handle.register(socket: socket, for: easyHandle, what: what, socketSourcePtr: socketptr)
            }.asError()
        // Timeout:
        try! CFURLSession_multi_setopt_ptr(rawHandle, CFURLSessionMultiOptionTIMERDATA, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())).asError()
#if os(Windows) && (arch(arm64) || arch(x86_64))
        typealias CFURLSessionMultiOption = Int32
#else
        typealias CFURLSessionMultiOption = Int
#endif
        try! CFURLSession_multi_setopt_tf(rawHandle, CFURLSessionMultiOptionTIMERFUNCTION) { (_, timeout: CFURLSessionMultiOption, userdata: UnsafeMutableRawPointer?) -> Int32 in
            guard let handle = URLSession._MultiHandle.from(callbackUserData: userdata) else { fatalError() }
            handle.updateTimeoutTimer(to: numericCast(timeout))
            return 0
            }.asError()
    }
    /// <https://curl.haxx.se/libcurl/c/CURLMOPT_SOCKETFUNCTION.html> and
    /// <https://curl.haxx.se/libcurl/c/curl_multi_socket_action.html>
    func register(socket: CFURLSession_socket_t, for easyHandle: CFURLSessionEasyHandle, what: Int32, socketSourcePtr: UnsafeMutableRawPointer?) -> Int32 {
        // We get this callback whenever we need to register or unregister a
        // given socket with libdispatch.
        // The `action` / `what` defines if we should register or unregister
        // that we're interested in read and/or write readiness. We will do so
        // through libdispatch (DispatchSource) and store the source(s) inside
        // a `SocketSources` which we in turn store inside libcurl's multi handle
        // by means of curl_multi_assign() -- we retain the object fist.
        let action = _SocketRegisterAction(rawValue: CFURLSessionPoll(value: what))
        var socketSources = _SocketSources.from(socketSourcePtr: socketSourcePtr)
        if socketSources == nil && action.needsSource {
            let s = _SocketSources()
            let p = Unmanaged.passRetained(s).toOpaque()
            CFURLSessionMultiHandleAssign(rawHandle, socket, UnsafeMutableRawPointer(p))
            socketSources = s
        } else if socketSources != nil && action == .unregister {
            // We need to release the stored pointer:
            if let opaque = socketSourcePtr {
                Unmanaged<_SocketSources>.fromOpaque(opaque).release()
            }
            socketSources?.tearDown(handle: self, socket: socket, queue: queue)
            socketSources = nil
        }
        if let ss = socketSources {
            let handler = DispatchWorkItem { [weak self] in
                self?.performAction(for: socket)
            }
            ss.createSources(with: action, handle: self, socket: socket, queue: queue, handler: handler)
        }
        return 0
    }

    /// What read / write ready event to register / unregister.
    ///
    /// This re-maps `CFURLSessionPoll` / `CURL_POLL`.
    enum _SocketRegisterAction {
        case none
        case registerRead
        case registerWrite
        case registerReadAndWrite
        case unregister
    }
}

extension Collection where Element == _EasyHandle {
  internal func firstIndex(of element: Element) -> Index? {
    var i = self.startIndex
    while i != self.endIndex {
      if self[i] == element { return i }
      self.formIndex(after: &i)
    }
    return nil
  }
}

private extension URLSession._MultiHandle {
    class _SocketReference {
        let socket: CFURLSession_socket_t
        var shouldClose: Bool
        var workItem: DispatchWorkItem?
        
        init(socket: CFURLSession_socket_t) {
            self.socket = socket
            shouldClose = false
        }
        
        deinit {
            if shouldClose {
                #if os(Windows)
                closesocket(socket)
                #else
                close(socket)
                #endif
            }
        }
    }

    /// Creates and stores socket reference. Reentrancy is not supported.
    /// Trying to begin operation for same socket twice would mean something
    /// went horribly wrong, or our assumptions about CURL register/unregister
    /// action flow are nor correct.
    func beginOperation(for socket: CFURLSession_socket_t) -> _SocketReference {
        let reference = _SocketReference(socket: socket)
        precondition(socketReferences.updateValue(reference, forKey: socket) == nil, "Reentrancy is not supported for socket operations")
        return reference
    }

    /// Removes socket reference from the shared store. If there is work item scheduled,
    /// executes it on the current thread.
    func endOperation(for socketReference: _SocketReference) {
        precondition(socketReferences.removeValue(forKey: socketReference.socket) != nil, "No operation associated with the socket")
        if let workItem = socketReference.workItem, !workItem.isCancelled {
            // CURL never asks for socket close without unregistering first, and
            // we should cancel pending work when unregister action is requested.
            precondition(!socketReference.shouldClose, "Socket close was scheduled, but there is some pending work left")
            workItem.perform()
        }
    }

    /// Marks this reference to close socket on deinit. This allows us
    /// to extend socket lifecycle by keeping the reference alive.
    func scheduleClose(for socket: CFURLSession_socket_t) {
        let reference = socketReferences[socket] ?? _SocketReference(socket: socket)
        reference.shouldClose = true
    }

    /// Schedules work to be performed when an operation ends for the socket,
    /// or performs it immediately if there is no operation in progress.
    /// 
    /// We're using this to postpone Dispatch Source creation when
    /// previous Dispatch Source is not cancelled yet.
    func schedule(_ workItem: DispatchWorkItem, for socket: CFURLSession_socket_t) {
        guard let socketReference = socketReferences[socket] else { 
            workItem.perform()
            return
        }
        // CURL never asks for register without pairing it with unregister later,
        // and we're cancelling pending work item on unregister.
        // But it is safe to just drop existing work item anyway,
        // and replace it with the new one.
        socketReference.workItem = workItem
    }

    /// Cancels pending work for socket operation. Does nothing if
    /// there is no operation in progress or no pending work item.
    /// 
    /// CURL may become not interested in Dispatch Sources
    /// we have planned to create. In this case we should just cancel
    /// scheduled work. 
    func cancelWorkItem(for socket: CFURLSession_socket_t) {
        guard let socketReference = socketReferences[socket] else { 
            return
        }
        socketReference.workItem?.cancel()
        socketReference.workItem = nil
    }

}

internal extension URLSession._MultiHandle {
    /// Add an easy handle -- start its transfer.
    func add(_ handle: _EasyHandle) {
        // Set CLOSESOCKETFUNCTION. Note that while the option belongs to easy_handle,
        // the connection cache is managed by CURL multi_handle, and sockets can actually
        // outlive easy_handle (even after curl_easy_cleanup call). That's why
        // socket management lives in _MultiHandle.
        try! CFURLSession_easy_setopt_ptr(handle.rawHandle, CFURLSessionOptionCLOSESOCKETDATA, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())).asError()
        try! CFURLSession_easy_setopt_scl(handle.rawHandle, CFURLSessionOptionCLOSESOCKETFUNCTION) {  (clientp: UnsafeMutableRawPointer?, item: CFURLSession_socket_t) in
            guard let handle = URLSession._MultiHandle.from(callbackUserData: clientp) else { fatalError() }
            handle.scheduleClose(for: item)
            return 0
        }.asError()
        
        // If this is the first handle being added, we need to `kick` the
        // underlying multi handle by calling `timeoutTimerFired` as
        // described in
        // <https://curl.haxx.se/libcurl/c/curl_multi_socket_action.html>.
        // That will initiate the registration for timeout timer and socket
        // readiness.
        let needsTimeout = self.easyHandles.isEmpty
        self.easyHandles.append(handle)
        try! CFURLSessionMultiHandleAddHandle(self.rawHandle, handle.rawHandle).asError()
        if needsTimeout {
            self.timeoutTimerFired()
        }
    }
    /// Remove an easy handle -- stop its transfer.
    func remove(_ handle: _EasyHandle) {
        guard let idx = self.easyHandles.firstIndex(of: handle) else {
            fatalError("Handle not in list.")
        }
        self.easyHandles.remove(at: idx)
        try! CFURLSessionMultiHandleRemoveHandle(self.rawHandle, handle.rawHandle).asError()
    }
}

fileprivate extension URLSession._MultiHandle {
    /// This gets called when we should ask curl to perform action on a socket.
    func performAction(for socket: CFURLSession_socket_t) {
        try! readAndWriteAvailableData(on: socket)
    }
    /// This gets called when our timeout timer fires.
    ///
    /// libcurl relies on us calling curl_multi_socket_action() every now and then.
    func timeoutTimerFired() {
        try! readAndWriteAvailableData(on: CFURLSessionSocketTimeout)
    }
    /// reads/writes available data given an action
    func readAndWriteAvailableData(on socket: CFURLSession_socket_t) throws {
        var runningHandlesCount = Int32(0)
        try CFURLSessionMultiHandleAction(rawHandle, socket, 0, &runningHandlesCount).asError()
        //TODO: Do we remove the timeout timer here if / when runningHandles == 0 ?
        readMessages()
    }
    
    /// Check the status of all individual transfers.
    ///
    /// libcurl refers to this as “read multi stack informationals”.
    /// Check for transfers that completed.
    func readMessages() {
        // We pop the messages one by one in a loop:
        repeat {
            // count will contain the messages left in the queue
            var count = Int32(0)
            let info = CFURLSessionMultiHandleInfoRead(rawHandle, &count)
            guard let handle = info.easyHandle else { break }
            let code = info.resultCode
            completedTransfer(forEasyHandle: handle, easyCode: code)
        } while true
    }
    /// Transfer completed.
    func completedTransfer(forEasyHandle handle: CFURLSessionEasyHandle, easyCode: CFURLSessionEasyCode) {
        // Look up the matching wrapper:
        guard let idx = easyHandles.firstIndex(where: { $0.rawHandle == handle }) else {
            fatalError("Transfer completed for easy handle, but it is not in the list of added handles.")
        }
        let easyHandle = easyHandles[idx]
        // Find the NSURLError code
        var error: NSError?
        if let errorCode = easyHandle.urlErrorCode(for: easyCode) {
            var errorDescription: String = ""
            if easyHandle.errorBuffer[0] == 0 {
              let description = CFURLSessionEasyCodeDescription(easyCode)!
              errorDescription = NSString(bytes: UnsafeMutableRawPointer(mutating: description), length: strlen(description), encoding: String.Encoding.utf8.rawValue)! as String
            } else {
              errorDescription = String(cString: easyHandle.errorBuffer)
            }

            error = NSError(domain: NSURLErrorDomain, code: errorCode, userInfo: [
                NSLocalizedDescriptionKey: errorDescription
            ])
        }
        completedTransfer(forEasyHandle: easyHandle, error: error)
    }
    /// Transfer completed.
    func completedTransfer(forEasyHandle handle: _EasyHandle, error: NSError?) {
        handle.completedTransfer(withError: error)
    }
}

fileprivate extension _EasyHandle {
    /// An error code within the `NSURLErrorDomain` based on the error of the
    /// easy handle.
    /// - Note: The error value is set only on failure. You can't use it to
    ///   determine *if* something failed or not, only *why* it failed.
    func urlErrorCode(for easyCode: CFURLSessionEasyCode) -> Int? {
        switch (easyCode, CInt(connectFailureErrno)) {
        case (CFURLSessionEasyCodeOK, _):
            return nil
        case (_, ECONNREFUSED):
            return NSURLErrorCannotConnectToHost
        case (CFURLSessionEasyCodeUNSUPPORTED_PROTOCOL, _):
            return NSURLErrorUnsupportedURL
        case (CFURLSessionEasyCodeURL_MALFORMAT, _):
            return NSURLErrorBadURL
        case (CFURLSessionEasyCodeCOULDNT_RESOLVE_HOST, _):
            // Oddly, this appears to happen for malformed URLs, too.
            return NSURLErrorCannotFindHost
        case (CFURLSessionEasyCodeRECV_ERROR, ECONNRESET):
            return NSURLErrorNetworkConnectionLost
        case (CFURLSessionEasyCodeSEND_ERROR, ECONNRESET):
            return NSURLErrorNetworkConnectionLost
        case (CFURLSessionEasyCodeGOT_NOTHING, _):
            return NSURLErrorBadServerResponse
        case (CFURLSessionEasyCodeABORTED_BY_CALLBACK, _):
            return NSURLErrorUnknown // Or NSURLErrorCancelled if we're in such a state
        case (CFURLSessionEasyCodeCOULDNT_CONNECT, ETIMEDOUT):
            return NSURLErrorTimedOut
        case (CFURLSessionEasyCodeOPERATION_TIMEDOUT, _):
            return NSURLErrorTimedOut
        default:
            //TODO: Need to map to one of the NSURLError... constants
            return NSURLErrorUnknown
        }
    }
}

internal func ==(lhs: CFURLSessionPoll, rhs: CFURLSessionPoll) -> Bool {
    return lhs.value == rhs.value
}
internal func ~=(lhs: CFURLSessionPoll, rhs: CFURLSessionPoll) -> Bool {
    return lhs == rhs
}

fileprivate extension URLSession._MultiHandle._SocketRegisterAction {
    init(rawValue: CFURLSessionPoll) {
        switch rawValue {
        case CFURLSessionPollNone:
            self = .none
        case CFURLSessionPollIn:
            self = .registerRead
        case CFURLSessionPollOut:
            self = .registerWrite
        case CFURLSessionPollInOut:
            self = .registerReadAndWrite
        case CFURLSessionPollRemove:
            self = .unregister
        default:
            fatalError("Invalid CFURLSessionPoll value.")
        }
    }
}

fileprivate extension URLSession._MultiHandle._SocketRegisterAction {
    /// Should a libdispatch source be registered for **read** readiness?
    var needsReadSource: Bool {
        switch self {
        case .none: return false
        case .registerRead: return true
        case .registerWrite: return false
        case .registerReadAndWrite: return true
        case .unregister: return false
        }
    }
    /// Should a libdispatch source be registered for **write** readiness?
    var needsWriteSource: Bool {
        switch self {
        case .none: return false
        case .registerRead: return false
        case .registerWrite: return true
        case .registerReadAndWrite: return true
        case .unregister: return false
        }
    }
    /// Should either a **read** or a **write** readiness libdispatch source be
    /// registered?
    var needsSource: Bool {
        return needsReadSource || needsWriteSource
    }
}

/// A helper class that wraps a libdispatch timer.
///
/// Used to implement the timeout of `URLSession.MultiHandle` and `URLSession.EasyHandle`
class _TimeoutSource {
    let rawSource: DispatchSource 
    let milliseconds: Int
    let queue: DispatchQueue        //needed to restart the timer for EasyHandles
    let handler: DispatchWorkItem   //needed to restart the timer for EasyHandles
    init(queue: DispatchQueue, milliseconds: Int, handler: DispatchWorkItem) {
        self.queue = queue
        self.handler = handler
        self.milliseconds = milliseconds
        self.rawSource = DispatchSource.makeTimerSource(queue: queue) as! DispatchSource
        
        let delay = UInt64(max(1, milliseconds - 1)) 
        let start = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(delay))
        
        rawSource.schedule(deadline: start, repeating: .never, leeway: (milliseconds == 1) ? .microseconds(Int(1)) : .milliseconds(Int(1)))
        rawSource.setEventHandler(handler: handler)
        rawSource.resume() 
    }
    deinit {
        rawSource.cancel()
    }
}

fileprivate extension URLSession._MultiHandle {

    /// <https://curl.haxx.se/libcurl/c/CURLMOPT_TIMERFUNCTION.html>
    func updateTimeoutTimer(to value: Int) {
        updateTimeoutTimer(to: _Timeout(timeout: value))
    }
    
    func updateTimeoutTimer(to timeout: _Timeout) {
        // Set up a timeout timer based on the given value:
        switch timeout {
        case .none:
            timeoutSource = nil
        case .immediate:
            timeoutSource = nil
            queue.async { self.timeoutTimerFired() }
        case .milliseconds(let milliseconds):
            //TODO: Could simply change the existing timer by using DispatchSourceTimer again.
            let block = DispatchWorkItem { [weak self] in
                self?.timeoutTimerFired()
            }
            // Note: Previous timer instance would cancel internal Dispatch timer in deinit
            timeoutSource = _TimeoutSource(queue: queue, milliseconds: milliseconds, handler: block)
        }
    }
    enum _Timeout {
        case milliseconds(Int)
        case none
        case immediate
    }
}

fileprivate extension URLSession._MultiHandle._Timeout {
    init(timeout: Int) {
        switch timeout {
        case -1:
            self = .none
        case 0:
            self = .immediate
        default:
            self = .milliseconds(timeout)
        }
    }
}


/// Read and write libdispatch sources for a specific socket.
///
/// A simple helper that combines two sources -- both being optional.
///
/// This info is stored into the socket using `curl_multi_assign()`.
///
/// - SeeAlso: URLSession.MultiHandle.SocketRegisterAction
fileprivate class _SocketSources {
    var readSource: DispatchSource?
    var writeSource: DispatchSource?

    func createReadSource(socket: CFURLSession_socket_t, queue: DispatchQueue, handler: DispatchWorkItem) {
        guard readSource == nil else { return }
#if os(Windows)
        let s = DispatchSource.makeReadSource(handle: HANDLE(bitPattern: Int(socket))!, queue: queue)
#else
        let s = DispatchSource.makeReadSource(fileDescriptor: socket, queue: queue)
#endif
        s.setEventHandler(handler: handler)
        readSource = s as? DispatchSource
        s.resume()
    }

    func createWriteSource(socket: CFURLSession_socket_t, queue: DispatchQueue, handler: DispatchWorkItem) {
        guard writeSource == nil else { return }
#if os(Windows)
        let s = DispatchSource.makeWriteSource(handle: HANDLE(bitPattern: Int(socket))!, queue: queue)
#else
        let s = DispatchSource.makeWriteSource(fileDescriptor: socket, queue: queue)
#endif
        s.setEventHandler(handler: handler)
        writeSource = s as? DispatchSource
        s.resume()
    }

    func tearDown(handle: URLSession._MultiHandle, socket: CFURLSession_socket_t, queue: DispatchQueue) {
        handle.cancelWorkItem(for: socket) // There could be pending register action which needs to be cancelled
        
        guard readSource != nil || writeSource != nil else {
            // This means that we have posponed (and already abandoned)
            // sources creation.
            return
        }
        
        // Socket is guaranteed to not to be closed as long as we keeping
        // the reference.
        let socketReference = handle.beginOperation(for: socket)
        let cancelHandlerGroup = DispatchGroup()
        [readSource, writeSource].compactMap({ $0 }).forEach { source in
            cancelHandlerGroup.enter()
            source.setCancelHandler {   
                cancelHandlerGroup.leave()
            }
            source.cancel()
        }
        cancelHandlerGroup.notify(queue: queue) {
            handle.endOperation(for: socketReference)
        }
        
        readSource = nil
        writeSource = nil
    }
}
extension _SocketSources {
    /// Create a read and/or write source as specified by the action.
    func createSources(with action: URLSession._MultiHandle._SocketRegisterAction, handle: URLSession._MultiHandle, socket: CFURLSession_socket_t, queue: DispatchQueue, handler: DispatchWorkItem) {
        // CURL casually requests to unregister and register handlers for same 
        // socket in a row. There is (pretty low) chance of overlapping tear-down operation
        // with "register" request. Bad things could happen if we create 
        // a new Dispatch Source while other is being cancelled for the same socket.
        // We're using `_MultiHandle.schedule(_:for:)` here to postpone sources creation until
        // pending operation is finished (if there is none, submitted work item is performed
        // immediately).
        // Also, CURL may request unregister even before we perform any postponed work,
        // so we have to cancel such work in such case. See 
        let createSources = DispatchWorkItem {
            if action.needsReadSource {
                self.createReadSource(socket: socket, queue: queue, handler: handler)
            }
            if action.needsWriteSource {
                self.createWriteSource(socket: socket, queue: queue, handler: handler)
            }
        }
        if action.needsReadSource || action.needsWriteSource {
            handle.schedule(createSources, for: socket)
        }
    }
}
extension _SocketSources {
    /// Unwraps the `SocketSources`
    ///
    /// A `SocketSources` is stored into the multi handle's socket using
    /// `curl_multi_assign()`. This helper unwraps it from the returned
    /// `UnsafeMutablePointer<Void>`.
    static func from(socketSourcePtr ptr: UnsafeMutableRawPointer?) -> _SocketSources? {
        guard let ptr = ptr else { return nil }
        return Unmanaged<_SocketSources>.fromOpaque(ptr).takeUnretainedValue()
    }
}


internal func ==(lhs: CFURLSessionMultiCode, rhs: CFURLSessionMultiCode) -> Bool {
    return lhs.value == rhs.value
}
internal func ~=(lhs: CFURLSessionMultiCode, rhs: CFURLSessionMultiCode) -> Bool {
    return lhs == rhs
}

extension CFURLSessionMultiCode {
    internal func asError() throws {
        if self == CFURLSessionMultiCodeOK { return }
        throw NSError(domain: "libcurl.multi", code: Int(self.value))
    }
}
