// Foundation/URLSession/URLSessionTask.swift - URLSession API
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
/// URLSession API code.
/// - SeeAlso: URLSession.swift
///
// -----------------------------------------------------------------------------

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import SwiftFoundation
#else
import Foundation
#endif
@_implementationOnly import CoreFoundation

private class Bag<Element> {
    var values: [Element] = []
}

/// A cancelable object that refers to the lifetime
/// of processing a given request.
open class URLSessionTask : NSObject, NSCopying, @unchecked Sendable {
    
    // These properties aren't heeded in swift-corelibs-foundation, but we may heed them in the future. They exist for source compatibility.
    open var countOfBytesClientExpectsToReceive: Int64 = NSURLSessionTransferSizeUnknown {
        didSet { updateProgress() }
    }
    open var countOfBytesClientExpectsToSend: Int64 = NSURLSessionTransferSizeUnknown {
        didSet { updateProgress() }
    }
    
    #if NS_CURL_MISSING_XFERINFOFUNCTION
    @available(*, deprecated, message: "This platform doesn't fully support reporting the progress of a URLSessionTask. The progress instance returned will be functional, but may not have continuous updates as bytes are sent or received.")
    open private(set) var progress = Progress(totalUnitCount: -1)
    #else
    open private(set) var progress = Progress(totalUnitCount: -1)
    #endif
    
    func updateProgress() {
        self.workQueue.async {
            let progress = self.progress
            
            switch self.state {
            case .canceling: fallthrough
            case .completed:
                let total = progress.totalUnitCount
                let finalTotal = total < 0 ? 1 : total
                progress.totalUnitCount = finalTotal
                progress.completedUnitCount = finalTotal
                
            default:
                let toBeSent: Int64?
                if let bodyLength = try? self.knownBody?.getBodyLength() {
                    toBeSent = Int64(clamping: bodyLength)
                } else if self.countOfBytesExpectedToSend > 0 {
                    toBeSent = Int64(clamping: self.countOfBytesExpectedToSend)
                } else if self.countOfBytesClientExpectsToSend != NSURLSessionTransferSizeUnknown && self.countOfBytesClientExpectsToSend > 0 {
                    toBeSent = Int64(clamping: self.countOfBytesClientExpectsToSend)
                } else {
                    toBeSent = nil
                }
                
                let sent = self.countOfBytesSent
                
                let toBeReceived: Int64?
                if self.countOfBytesExpectedToReceive > 0 {
                    toBeReceived = Int64(clamping: self.countOfBytesClientExpectsToReceive)
                } else if self.countOfBytesClientExpectsToReceive != NSURLSessionTransferSizeUnknown && self.countOfBytesClientExpectsToReceive > 0 {
                    toBeReceived = Int64(clamping: self.countOfBytesClientExpectsToReceive)
                } else {
                    toBeReceived = nil
                }
                
                let received = self.countOfBytesReceived
                
                progress.completedUnitCount = sent.addingReportingOverflow(received).partialValue
                
                if let toBeSent = toBeSent, let toBeReceived = toBeReceived {
                    progress.totalUnitCount = toBeSent.addingReportingOverflow(toBeReceived).partialValue
                } else {
                    progress.totalUnitCount = -1
                }
                
            }
        }
    }
    
    // We're not going to heed this one. If someone is setting it in Linux code, they may be relying on behavior that isn't there; warn.
    @available(*, deprecated, message: "swift-corelibs-foundation does not support background URLSession instances, and this property is documented to have no effect when set on tasks created from non-background URLSession instances. Modifying this property has no effect in swift-corelibs-foundation and shouldn't be relied upon; resume tasks at the appropriate time instead.")
    open var earliestBeginDate: Date? = nil
    
    /// How many times the task has been suspended, 0 indicating a running task.
    internal var suspendCount = 1
    
    internal var actualSession: URLSession? { return session as? URLSession }
    internal var session: URLSessionProtocol! //change to nil when task completes

    fileprivate enum ProtocolState {
        case toBeCreated
        case awaitingCacheReply(Bag<(URLProtocol?) -> Void>)
        case existing(URLProtocol)
        case invalidated
    }
    
    fileprivate let _protocolLock = NSLock() // protects:
    fileprivate var _protocolStorage: ProtocolState = .toBeCreated
    internal    var _lastCredentialUsedFromStorageDuringAuthentication: (protectionSpace: URLProtectionSpace, credential: URLCredential)?
    
    private var _protocolClass: URLProtocol.Type? {
        guard let request = currentRequest else { fatalError("A protocol class was requested, but we do not have a current request") }
        let protocolClasses = session.configuration.protocolClasses ?? []
        if let urlProtocolClass = URLProtocol.getProtocolClass(protocols: protocolClasses, request: request) {
            guard let urlProtocol = urlProtocolClass as? URLProtocol.Type else { fatalError("A protocol class specified in the URLSessionConfiguration's .protocolClasses array was not a URLProtocol subclass: \(urlProtocolClass)") }
            return urlProtocol
        } else {
            let protocolClasses = URLProtocol.getProtocols() ?? []
            if let urlProtocolClass = URLProtocol.getProtocolClass(protocols: protocolClasses, request: request) {
                guard let urlProtocol = urlProtocolClass as? URLProtocol.Type else { fatalError("A protocol class registered with URLProtocol.register… was not a URLProtocol subclass: \(urlProtocolClass)") }
                return urlProtocol
            }
        }
        return nil
    }
    
    func _getProtocol(_ callback: @escaping (URLProtocol?) -> Void) {
        _protocolLock.lock() // Must be balanced below, before we call out ⬇
        
        switch _protocolStorage {
        case .toBeCreated:
            guard let protocolClass = self._protocolClass else {
                _protocolLock.unlock() // Balances above ⬆
                callback(nil)
                break
            }
            if let cache = session.configuration.urlCache, let me = self as? URLSessionDataTask {
                let bag: Bag<(URLProtocol?) -> Void> = Bag()
                bag.values.append(callback)
                
                _protocolStorage = .awaitingCacheReply(bag)
                _protocolLock.unlock() // Balances above ⬆
                
                cache.getCachedResponse(for: me) { (response) in
                    let urlProtocol = protocolClass.init(task: self, cachedResponse: response, client: nil)
                    self._satisfyProtocolRequest(with: urlProtocol)
                }
            } else {
                let urlProtocol = protocolClass.init(task: self, cachedResponse: nil, client: nil)
                _protocolStorage = .existing(urlProtocol)
                _protocolLock.unlock() // Balances above ⬆
                
                callback(urlProtocol)
            }
            
        case .awaitingCacheReply(let bag):
            bag.values.append(callback)
            _protocolLock.unlock() // Balances above ⬆
        
        case .existing(let urlProtocol):
            _protocolLock.unlock() // Balances above ⬆
            
            callback(urlProtocol)
        
        case .invalidated:
            _protocolLock.unlock() // Balances above ⬆
            
            callback(nil)
        }
    }
    
    func _satisfyProtocolRequest(with urlProtocol: URLProtocol) {
        _protocolLock.lock() // Must be balanced below, before we call out ⬇
        switch _protocolStorage {
        case .toBeCreated:
            _protocolStorage = .existing(urlProtocol)
            _protocolLock.unlock() // Balances above ⬆
            
        case .awaitingCacheReply(let bag):
            _protocolStorage = .existing(urlProtocol)
            _protocolLock.unlock() // Balances above ⬆
            
            for callback in bag.values {
                callback(urlProtocol)
            }
            
        case .existing(_): fallthrough
        case .invalidated:
            _protocolLock.unlock() // Balances above ⬆
        }
    }
    
    func _invalidateProtocol() {
        _protocolLock.performLocked {
            _protocolStorage = .invalidated
        }
    }
    
    
    internal var knownBody: _Body?
    func getBody(completion: @escaping (_Body) -> Void) {
        if let body = knownBody {
            completion(body)
            return
        }
        
        if let session = actualSession, let delegate = session.delegate as? URLSessionTaskDelegate {
            delegate.urlSession(session, task: self) { (stream) in
                if let stream = stream {
                    completion(.stream(stream))
                } else {
                    completion(.none)
                }
            }
        } else {
            completion(.none)
        }
    }
    
    private let syncQ = DispatchQueue(label: "org.swift.URLSessionTask.SyncQ")
    private var hasTriggeredResume: Bool = false
    internal var isSuspendedAfterResume: Bool {
        return self.syncQ.sync { return self.hasTriggeredResume } && self.state == .suspended
    }
    
    /// All operations must run on this queue.
    internal let workQueue: DispatchQueue 
    
    public override init() {
        // Darwin Foundation oddly allows calling this initializer, even though
        // such a task is quite broken -- it doesn't have a session. And calling
        // e.g. `taskIdentifier` will crash.
        //
        // We set up the bare minimum for init to work, but don't care too much
        // about things crashing later.
        session = _MissingURLSession()
        taskIdentifier = 0
        originalRequest = nil
        knownBody = URLSessionTask._Body.none
        workQueue = DispatchQueue(label: "URLSessionTask.notused.0")
        super.init()
    }
    /// Create a data task. If there is a httpBody in the URLRequest, use that as a parameter
    internal convenience init(session: URLSession, request: URLRequest, taskIdentifier: Int) {
        if let bodyData = request.httpBody, !bodyData.isEmpty {
            self.init(session: session, request: request, taskIdentifier: taskIdentifier, body: _Body.data(createDispatchData(bodyData)))
        } else if let bodyStream = request.httpBodyStream {
            self.init(session: session, request: request, taskIdentifier: taskIdentifier, body: _Body.stream(bodyStream))
        } else {
            self.init(session: session, request: request, taskIdentifier: taskIdentifier, body: _Body.none)
        }
    }

    internal init(session: URLSession, request: URLRequest, taskIdentifier: Int, body: _Body?) {
        self.session = session
        /* make sure we're actually having a serial queue as it's used for synchronization */
        self.workQueue = DispatchQueue.init(label: "org.swift.URLSessionTask.WorkQueue", target: session.workQueue)
        self.taskIdentifier = taskIdentifier
        self.originalRequest = request
        self.knownBody = body
        super.init()
        self.currentRequest = request
        self.progress.cancellationHandler = { [weak self] in
            self?.cancel()
        }
    }
    deinit {
        //TODO: Do we remove the EasyHandle from the session here? This might run on the wrong thread / queue.
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone?) -> Any {
        return self
    }
    
    /// An identifier for this task, assigned by and unique to the owning session
    open internal(set) var taskIdentifier: Int
    
    /// May be nil if this is a stream task
    
    /*@NSCopying*/ open private(set) var originalRequest: URLRequest?

    /// If there's an authentication failure, we'd need to create a new request with the credentials supplied by the user
    var authRequest: URLRequest? = nil

    /// Authentication failure count
    fileprivate var previousFailureCount = 0
    
    /// May differ from originalRequest due to http server redirection
    /*@NSCopying*/ open internal(set) var currentRequest: URLRequest? {
        get {
            return self.syncQ.sync { return self._currentRequest }
        }
        set {
            self.syncQ.sync { self._currentRequest = newValue }
        }
    }
    fileprivate var _currentRequest: URLRequest? = nil
    /*@NSCopying*/ open internal(set) var response: URLResponse? {
        get {
            return self.syncQ.sync { return self._response }
        }
        set {
            self.syncQ.sync { self._response = newValue }
        }
    }
    fileprivate var _response: URLResponse? = nil
    
    /* Byte count properties may be zero if no body is expected,
     * or URLSessionTransferSizeUnknown if it is not possible
     * to know how many bytes will be transferred.
     */
    
    /// Number of body bytes already received
    open internal(set) var countOfBytesReceived: Int64 {
        get {
            return self.syncQ.sync { return self._countOfBytesReceived }
        }
        set {
            self.syncQ.sync { self._countOfBytesReceived = newValue }
            updateProgress()
        }
    }
    fileprivate var _countOfBytesReceived: Int64 = 0
    
    /// Number of body bytes already sent */
    open internal(set) var countOfBytesSent: Int64 {
        get {
            return self.syncQ.sync { return self._countOfBytesSent }
        }
        set {
            self.syncQ.sync { self._countOfBytesSent = newValue }
            updateProgress()
        }
    }
    
    fileprivate var _countOfBytesSent: Int64 = 0
    
    /// Number of body bytes we expect to send, derived from the Content-Length of the HTTP request */
    open internal(set) var countOfBytesExpectedToSend: Int64 = 0 {
        didSet { updateProgress() }
    }
    
    /// Number of bytes we expect to receive, usually derived from the Content-Length header of an HTTP response. */
    open internal(set) var countOfBytesExpectedToReceive: Int64 = 0 {
        didSet { updateProgress() }
    }
    
    /// The taskDescription property is available for the developer to
    /// provide a descriptive label for the task.
    open var taskDescription: String?
    
    /* -cancel returns immediately, but marks a task as being canceled.
     * The task will signal -URLSession:task:didCompleteWithError: with an
     * error value of { NSURLErrorDomain, NSURLErrorCancelled }.  In some
     * cases, the task may signal other work before it acknowledges the
     * cancellation.  -cancel may be sent to a task that has been suspended.
     */
    open func cancel() {
        workQueue.sync {
            let canceled = self.syncQ.sync { () -> Bool in
                guard self._state == .running || self._state == .suspended else { return true }
                self._state = .canceling
                return false
            }
            guard !canceled else { return }
            self._getProtocol { (urlProtocol) in
                self.workQueue.async {
                    var info = [NSLocalizedDescriptionKey: "\(URLError.Code.cancelled)" as Any]
                    if let url = self.originalRequest?.url {
                        info[NSURLErrorFailingURLErrorKey] = url
                        info[NSURLErrorFailingURLStringErrorKey] = url.absoluteString
                    }
                    let urlError = URLError(_nsError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: info))
                    self.error = urlError
                    if let urlProtocol = urlProtocol {
                        urlProtocol.stopLoading()
                        urlProtocol.client?.urlProtocol(urlProtocol, didFailWithError: urlError)
                    }
                }
            }
        }
    }
    
    /*
     * The current state of the task within the session.
     */
    open fileprivate(set) var state: URLSessionTask.State {
        get {
            return self.syncQ.sync { self._state }
        }
        set {
            self.syncQ.sync { self._state = newValue }
        }
    }
    fileprivate var _state: URLSessionTask.State = .suspended
    
    /*
     * The error, if any, delivered via -URLSession:task:didCompleteWithError:
     * This property will be nil in the event that no error occurred.
     */
    /*@NSCopying*/ open internal(set) var error: Error?
    
    /// Suspend the task.
    ///
    /// Suspending a task will prevent the URLSession from continuing to
    /// load data.  There may still be delegate calls made on behalf of
    /// this task (for instance, to report data received while suspending)
    /// but no further transmissions will be made on behalf of the task
    /// until -resume is sent.  The timeout timer associated with the task
    /// will be disabled while a task is suspended. -suspend and -resume are
    /// nestable.
    open func suspend() {
        // suspend / resume is implemented simply by adding / removing the task's
        // easy handle fromt he session's multi-handle.
        //
        // This might result in slightly different behaviour than the Darwin Foundation
        // implementation, but it'll be difficult to get complete parity anyhow.
        // Too many things depend on timeout on the wire etc.
        //
        // TODO: It may be worth looking into starting over a task that gets
        // resumed. The Darwin Foundation documentation states that that's what
        // it does for anything but download tasks.
        
        // We perform the increment and call to `updateTaskState()`
        // synchronous, to make sure the `state` is updated when this method
        // returns, but the actual suspend will be done asynchronous to avoid
        // dead-locks.
        workQueue.sync {
            guard self.state != .canceling && self.state != .completed else { return }
            self.suspendCount += 1
            guard self.suspendCount < Int.max else { fatalError("Task suspended too many times \(Int.max).") }
            self.updateTaskState()
            
            if self.suspendCount == 1 {
                self._getProtocol { (urlProtocol) in
                    self.workQueue.async {
                        urlProtocol?.stopLoading()
                    }
                }
            }
        }
    }
    /// Resume the task.
    ///
    /// - SeeAlso: `suspend()`
    open func resume() {
        workQueue.sync {
            guard self.state != .canceling && self.state != .completed else { return }
            if self.suspendCount > 0 { self.suspendCount -= 1 }
            self.updateTaskState()
            if self.suspendCount == 0 {
                self.hasTriggeredResume = true
                self._getProtocol { (urlProtocol) in
                    self.workQueue.async {
                        if let _protocol = urlProtocol {
                            _protocol.startLoading()
                        }
                        else if self.error == nil {
                            var userInfo: [String: Any] = [NSLocalizedDescriptionKey: "unsupported URL"]
                            if let url = self.originalRequest?.url {
                                userInfo[NSURLErrorFailingURLErrorKey] = url
                                userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString
                            }
                            let urlError = URLError(_nsError: NSError(domain: NSURLErrorDomain,
                                                                      code: NSURLErrorUnsupportedURL,
                                                                      userInfo: userInfo))
                            self.error = urlError
                            _ProtocolClient().urlProtocol(task: self, didFailWithError: urlError)
                        }
                    }
                }
            }
        }
    }
    
    /// The priority of the task.
    ///
    /// Sets a scaling factor for the priority of the task. The scaling factor is a
    /// value between 0.0 and 1.0 (inclusive), where 0.0 is considered the lowest
    /// priority and 1.0 is considered the highest.
    ///
    /// The priority is a hint and not a hard requirement of task performance. The
    /// priority of a task may be changed using this API at any time, but not all
    /// protocols support this; in these cases, the last priority that took effect
    /// will be used.
    ///
    /// If no priority is specified, the task will operate with the default priority
    /// as defined by the constant URLSessionTask.defaultPriority. Two additional
    /// priority levels are provided: URLSessionTask.lowPriority and
    /// URLSessionTask.highPriority, but use is not restricted to these.
    open var priority: Float {
        get {
            return self.workQueue.sync { return self._priority }
        }
        set {
            self.workQueue.sync { self._priority = newValue }
        }
    }
    fileprivate var _priority: Float = URLSessionTask.defaultPriority
}

extension URLSessionTask {
    public enum State : Int {
        /// The task is currently being serviced by the session
        case running
        case suspended
        /// The task has been told to cancel.  The session will receive a URLSession:task:didCompleteWithError: message.
        case canceling
        /// The task has completed and the session will receive no more delegate notifications
        case completed
    }
}

extension URLSessionTask : ProgressReporting {}

extension URLSessionTask {
    /// Updates the (public) state based on private / internal state.
    ///
    /// - Note: This must be called on the `workQueue`.
    internal func updateTaskState() {
        func calculateState() -> URLSessionTask.State {
            if suspendCount == 0 {
                return .running
            } else {
                return .suspended
            }
        }
        state = calculateState()
    }
}

internal extension URLSessionTask {
    enum _Body {
        case none
        case data(DispatchData)
        /// Body data is read from the given file URL
        case file(URL)
        case stream(InputStream)
    }
}
internal extension URLSessionTask._Body {
    enum _Error : Error {
        case fileForBodyDataNotFound
    }
    /// - Returns: The body length, or `nil` for no body (e.g. `GET` request).
    func getBodyLength() throws -> UInt64? {
        switch self {
        case .none:
            return 0
        case .data(let d):
            return UInt64(d.count)
        /// Body data is read from the given file URL
        case .file(let fileURL):
            guard let s = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber else {
                throw _Error.fileForBodyDataNotFound
            }
            return s.uint64Value
        case .stream:
            return nil
        }
    }
}


fileprivate func errorCode(fileSystemError error: Error) -> Int {
    func fromCocoaErrorCode(_ code: Int) -> Int {
        switch code {
        case CocoaError.fileReadNoSuchFile.rawValue:
            return NSURLErrorFileDoesNotExist
        case CocoaError.fileReadNoPermission.rawValue:
            return NSURLErrorNoPermissionsToReadFile
        default:
            return NSURLErrorUnknown
        }
    }
    switch error {
    case let e as NSError where e.domain == NSCocoaErrorDomain:
        return fromCocoaErrorCode(e.code)
    default:
        return NSURLErrorUnknown
    }
}

extension URLSessionTask {
    /// The default URL session task priority, used implicitly for any task you
    /// have not prioritized. The floating point value of this constant is 0.5.
    public static let defaultPriority: Float = 0.5
    
    /// A low URL session task priority, with a floating point value above the
    /// minimum of 0 and below the default value.
    public static let lowPriority: Float = 0.25
    
    /// A high URL session task priority, with a floating point value above the
    /// default value and below the maximum of 1.0.
    public static let highPriority: Float = 0.75
}

/*
 * An URLSessionDataTask does not provide any additional
 * functionality over an URLSessionTask and its presence is merely
 * to provide lexical differentiation from download and upload tasks.
 */
open class URLSessionDataTask : URLSessionTask {
}

/*
 * An URLSessionUploadTask does not currently provide any additional
 * functionality over an URLSessionDataTask.  All delegate messages
 * that may be sent referencing an URLSessionDataTask equally apply
 * to URLSessionUploadTasks.
 */
open class URLSessionUploadTask : URLSessionDataTask {
}

/*
 * URLSessionDownloadTask is a task that represents a download to
 * local storage.
 */
open class URLSessionDownloadTask : URLSessionTask {
    
    var createdFromInvalidResumeData = false
    
    // If a task is created from invalid resume data, prevent attempting creation of the protocol object.
    override func _getProtocol(_ callback: @escaping (URLProtocol?) -> Void) {
        if createdFromInvalidResumeData {
            callback(nil)
        } else {
            super._getProtocol(callback)
        }
    }
    
    internal var fileLength = -1.0
    
    /* Cancel the download (and calls the superclass -cancel).  If
     * conditions will allow for resuming the download in the future, the
     * callback will be called with an opaque data blob, which may be used
     * with -downloadTaskWithResumeData: to attempt to resume the download.
     * If resume data cannot be created, the completion handler will be
     * called with nil resumeData.
     */
    open func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void) {
        super.cancel()
        
        /*
         * In Objective-C, this method relies on an Apple-maintained XPC process
         * to manage the bookmarking of partially downloaded data. Therefore, the
         * original behavior cannot be directly ported, here.
         *
         * Instead, we just call the completionHandler directly.
         */
        completionHandler(nil)
    }
}

/*
 * A URLSessionWebSocketTask is a task that allows clients to connect to servers supporting
 * WebSocket. The task will perform the HTTP handshake to upgrade the connection
 * and once the WebSocket handshake is successful, the client can read and write
 * messages that will be framed using the WebSocket protocol by the framework.
 */
open class URLSessionWebSocketTask : URLSessionTask {
    public enum CloseCode : Int, @unchecked Sendable {
        case invalid = 0
        case normalClosure = 1000
        case goingAway = 1001
        case protocolError = 1002
        case unsupportedData = 1003
        case noStatusReceived = 1005
        case abnormalClosure = 1006
        case invalidFramePayloadData = 1007
        case policyViolation = 1008
        case messageTooBig = 1009
        case mandatoryExtensionMissing = 1010
        case internalServerError = 1011
        case tlsHandshakeFailure = 1015
    }
    
    public enum Message {
        case data(Data)
        case string(String)
    }
    
    internal var handshakeCompleted = false {
        didSet {
            doPendingWork()
        }
    }
    
    private var taskError: Error? = nil {
        didSet {
            doPendingWork()
        }
    }

    open override var error: Error? {
        didSet {
            doPendingWork()
        }
    }

    private var sendBuffer = [(Message, (Error?) -> Void)]()
    private var receiveBuffer = [Message]()
    private var receiveCompletionHandlers = [(Result<Message, Error>) -> Void]()
    private var pongCompletionHandlers = [(Error?) -> Void]()
    private var closeMessage: (CloseCode, Data)? = nil
    
    internal var protocolPicked: String? = nil
    
    func appendReceivedMessage(_ message: Message) {
        workQueue.async {
            self.receiveBuffer.append(message)
            self.doPendingWork()
        }
    }
    
    func noteReceivedPong() {
        workQueue.async {
            guard !self.pongCompletionHandlers.isEmpty else {
                self.close(code: .protocolError, reason: nil)
                return
            }
            let completionHandler = self.pongCompletionHandlers.removeFirst()
            completionHandler(nil)
        }
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    open func sendPing() async throws {
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    open func sendPing(pongReceiveHandler: @escaping (Error?) -> Void) {
        self.workQueue.async {
            self._getProtocol { urlProtocol in
                self.workQueue.async {
                    if let webSocketProtocol = urlProtocol as? _WebSocketURLProtocol {
                        do {
                            try webSocketProtocol.sendWebSocketData(Data(), flags: [.ping])
                            self.pongCompletionHandlers.append(pongReceiveHandler)
                        } catch {
                            pongReceiveHandler(error)
                        }
                    } else {
                        let disconnectedError = URLError(_nsError: NSError(domain: NSURLErrorDomain,
                                                                           code: NSURLErrorNetworkConnectionLost))
                        pongReceiveHandler(disconnectedError)
                    }
                }
            }
        }
    }
    
    override open func cancel() {
        cancel(with: .invalid, reason: nil)
    }
    
    open func cancel(with closeCode: CloseCode, reason: Data?) {
        close(code: closeCode, reason: reason)
    }
    
    open var maximumMessageSize: Int = 1 * 1024 * 1024
    
    open private(set) var closeCode: CloseCode = .invalid
    
    open private(set) var closeReason: Data? = nil
    
    internal func close(code: CloseCode, reason: Data?) {
        workQueue.async {
            // If we've already errored out in some way, no need to re-close.
            if self.taskError != nil { return }
            
            self.closeCode = code
            self.closeReason = reason
            self.taskError = URLError(_nsError: NSError(domain: NSURLErrorDomain,
                                                        code: NSURLErrorNetworkConnectionLost))
            self.closeMessage = (code, reason ?? Data())
            self.doPendingWork()
        }
    }
    
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func send(_ message: Message) async throws -> Void {
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            send(message) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    private func send(_ message: Message, completionHandler: @escaping (Error?) -> Void) {
        self.workQueue.async {
            self.sendBuffer.append((message, completionHandler))
            self.doPendingWork()
        }
    }
    
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func receive() async throws -> Message {
        try await withCheckedThrowingContinuation { continuation in
            receive() { result in
                continuation.resume(with: result)
            }
        }
    }

    private func receive(completionHandler: @escaping (Result<Message, Error>) -> Void) {
        self.workQueue.async {
            self.receiveCompletionHandlers.append(completionHandler)
            self.doPendingWork()
        }
    }
    
    private func doPendingWork() {
        self.workQueue.async {
            let session = self.session as! URLSession
            if let taskError = self.taskError ?? self.error {
                for (_, handler) in self.sendBuffer {
                    session.delegateQueue.addOperation {
                        handler(taskError)
                    }
                }
                self.sendBuffer.removeAll()
                for handler in self.receiveCompletionHandlers {
                    session.delegateQueue.addOperation {
                        handler(.failure(taskError))
                    }
                }
                self.receiveCompletionHandlers.removeAll()
                self._getProtocol { urlProtocol in
                    self.workQueue.async {
                        if self.handshakeCompleted && self.state != .completed {
                            if let webSocketProtocol = urlProtocol as? _WebSocketURLProtocol {
                                if let closeMessage = self.closeMessage {
                                    self.closeMessage = nil
                                    var closeData = Data([UInt8(closeMessage.0.rawValue >> 8), UInt8(closeMessage.0.rawValue & 0xFF)])
                                    closeData.append(contentsOf: closeMessage.1)
                                    try? webSocketProtocol.sendWebSocketData(closeData, flags: [.close])
                                }
                            }
                        }
                    }
                }
            } else {
                self._getProtocol { urlProtocol in
                    self.workQueue.async {
                        if self.handshakeCompleted {
                            if let webSocketProtocol = urlProtocol as? _WebSocketURLProtocol {
                                while !self.sendBuffer.isEmpty {
                                    let (message, completionHandler) = self.sendBuffer.removeFirst()
                                    do {
                                        switch message {
                                        case .data(let data):
                                            try webSocketProtocol.sendWebSocketData(data, flags: [.binary])
                                        case .string(let str):
                                            try webSocketProtocol.sendWebSocketData(str.data(using: .utf8)!, flags: [.text])
                                        }
                                        completionHandler(nil)
                                    } catch {
                                        completionHandler(error)
                                    }
                                }
                                if let closeMessage = self.closeMessage {
                                    self.closeMessage = nil
                                    var closeData = Data([UInt8(closeMessage.0.rawValue >> 8), UInt8(closeMessage.0.rawValue & 0xFF)])
                                    closeData.append(contentsOf: closeMessage.1)
                                    try? webSocketProtocol.sendWebSocketData(closeData, flags: [.close])
                                }
                            }
                        }
                        while !self.receiveBuffer.isEmpty && !self.receiveCompletionHandlers.isEmpty {
                            let message = self.receiveBuffer.removeFirst()
                            let handler = self.receiveCompletionHandlers.removeFirst()
                            handler(.success(message))
                        }
                    }
                }
            }
        }
    }
    
    override open func resume() {
        guard _EasyHandle.supportsWebSockets else {
            workQueue.async {
                var userInfo: [String: Any] = [NSLocalizedDescriptionKey: "WebSockets not supported by libcurl"]
                if let url = self.originalRequest?.url {
                    userInfo[NSURLErrorFailingURLErrorKey] = url
                    userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString
                }
                let urlError = URLError(_nsError: NSError(domain: NSURLErrorDomain,
                                                          code: NSURLErrorUnsupportedURL,
                                                          userInfo: userInfo))
                self.error = urlError
                _ProtocolClient().urlProtocol(task: self, didFailWithError: urlError)
            }
            return
        }
        super.resume()
    }
    
    internal static var supportsWebSockets: Bool {
        _EasyHandle.supportsWebSockets
    }
}

public protocol URLSessionWebSocketDelegate : URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?)
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

extension URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {}
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {}
}

/*
 * An URLSessionStreamTask provides an interface to perform reads
 * and writes to a TCP/IP stream created via URLSession.  This task
 * may be explicitly created from an URLSession, or created as a
 * result of the appropriate disposition response to a
 * -URLSession:dataTask:didReceiveResponse: delegate message.
 *
 * URLSessionStreamTask can be used to perform asynchronous reads
 * and writes.  Reads and writes are enquened and executed serially,
 * with the completion handler being invoked on the sessions delegate
 * queuee.  If an error occurs, or the task is canceled, all
 * outstanding read and write calls will have their completion
 * handlers invoked with an appropriate error.
 *
 * It is also possible to create InputStream and OutputStream
 * instances from an URLSessionTask by sending
 * -captureStreams to the task.  All outstanding read and writess are
 * completed before the streams are created.  Once the streams are
 * delivered to the session delegate, the task is considered complete
 * and will receive no more messages.  These streams are
 * disassociated from the underlying session.
 */

@available(*, deprecated, message: "URLSessionStreamTask is not available in swift-corelibs-foundation")
open class URLSessionStreamTask : URLSessionTask {
    
    /* Read minBytes, or at most maxBytes bytes and invoke the completion
     * handler on the sessions delegate queue with the data or an error.
     * If an error occurs, any outstanding reads will also fail, and new
     * read requests will error out immediately.
     */
    @available(*, unavailable, message: "URLSessionStreamTask is not available in swift-corelibs-foundation")
    open func readData(ofMinLength minBytes: Int, maxLength maxBytes: Int, timeout: TimeInterval, completionHandler: @escaping (Data?, Bool, Error?) -> Void) { NSUnsupported() }
    
    /* Write the data completely to the underlying socket.  If all the
     * bytes have not been written by the timeout, a timeout error will
     * occur.  Note that invocation of the completion handler does not
     * guarantee that the remote side has received all the bytes, only
     * that they have been written to the kernel. */
    @available(*, unavailable, message: "URLSessionStreamTask is not available in swift-corelibs-foundation")
    open func write(_ data: Data, timeout: TimeInterval, completionHandler: @escaping (Error?) -> Void) { NSUnsupported() }
    
    /* -captureStreams completes any already enqueued reads
     * and writes, and then invokes the
     * URLSession:streamTask:didBecomeInputStream:outputStream: delegate
     * message. When that message is received, the task object is
     * considered completed and will not receive any more delegate
     * messages. */
    @available(*, unavailable, message: "URLSessionStreamTask is not available in swift-corelibs-foundation")
    open func captureStreams() { NSUnsupported() }
    
    /* Enqueue a request to close the write end of the underlying socket.
     * All outstanding IO will complete before the write side of the
     * socket is closed.  The server, however, may continue to write bytes
     * back to the client, so best practice is to continue reading from
     * the server until you receive EOF.
     */
    @available(*, unavailable, message: "URLSessionStreamTask is not available in swift-corelibs-foundation")
    open func closeWrite() { NSUnsupported() }
    
    /* Enqueue a request to close the read side of the underlying socket.
     * All outstanding IO will complete before the read side is closed.
     * You may continue writing to the server.
     */
    @available(*, unavailable, message: "URLSessionStreamTask is not available in swift-corelibs-foundation")
    open func closeRead() { NSUnsupported() }
    
    /*
     * Begin encrypted handshake.  The handshake begins after all pending
     * IO has completed.  TLS authentication callbacks are sent to the
     * session's -URLSession:task:didReceiveChallenge:completionHandler:
     */
    @available(*, unavailable, message: "URLSessionStreamTask is not available in swift-corelibs-foundation")
    open func startSecureConnection() { NSUnsupported() }
    
    /*
     * Cleanly close a secure connection after all pending secure IO has
     * completed.
     */
    @available(*, unavailable, message: "URLSessionStreamTask is not available in swift-corelibs-foundation")
    open func stopSecureConnection() { NSUnsupported() }
}

/* Key in the userInfo dictionary of an NSError received during a failed download. */
public let URLSessionDownloadTaskResumeData: String = "NSURLSessionDownloadTaskResumeData"

extension _ProtocolClient : URLProtocolClient {

    func urlProtocol(_ protocol: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) {
        guard let task = `protocol`.task else { fatalError("Received response, but there's no task.") }
        task.response = response
        let session = task.session as! URLSession
        
        // Only cache data tasks:
        self.cachePolicy = policy
        
        if session.configuration.urlCache != nil {
            switch policy {
            case .allowed: fallthrough
            case .allowedInMemoryOnly:
                cacheableData = []
                cacheableResponse = response
                
            case .notAllowed:
                break
            }
        }
        
        switch session.behaviour(for: task) {
        case .taskDelegate(let delegate):
            if let dataDelegate = delegate as? URLSessionDataDelegate,
               let dataTask = task as? URLSessionDataTask {
                session.delegateQueue.addOperation {
                    dataDelegate.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: { _ in
                        URLSession.printDebug("warning: Ignoring disposition from completion handler.")
                    })
                }
            } else if let webSocketDelegate = delegate as? URLSessionWebSocketDelegate,
                      let webSocketTask = task as? URLSessionWebSocketTask {
                session.delegateQueue.addOperation {
                    webSocketDelegate.urlSession(session, webSocketTask: webSocketTask, didOpenWithProtocol: webSocketTask.protocolPicked)
                }
            }
        case .noDelegate, .dataCompletionHandler, .dataCompletionHandlerWithTaskDelegate, .downloadCompletionHandler:
            break
        }
    }

    func urlProtocolDidFinishLoading(_ urlProtocol: URLProtocol) {
        guard let task = urlProtocol.task else { fatalError() }
        guard let session = task.session as? URLSession else { fatalError() }
        let urlResponse = task.response
        if let response = urlResponse as? HTTPURLResponse, response.statusCode == 401 {
            if let protectionSpace = URLProtectionSpace.create(with: response) {

                func proceed(proposing credential: URLCredential?) {
                    let proposedCredential: URLCredential?
                    let last = task._protocolLock.performLocked { task._lastCredentialUsedFromStorageDuringAuthentication }
                    
                    if last?.credential != credential {
                        proposedCredential = credential
                    } else {
                        proposedCredential = nil
                    }
                    
                    let authenticationChallenge = URLAuthenticationChallenge(protectionSpace: protectionSpace, proposedCredential: proposedCredential,
                                                                             previousFailureCount: task.previousFailureCount, failureResponse: response, error: nil,
                                                                             sender: URLSessionAuthenticationChallengeSender())
                    task.previousFailureCount += 1
                    self.urlProtocol(urlProtocol, didReceive: authenticationChallenge)
                }
                
                if let storage = session.configuration.urlCredentialStorage {
                    storage.getCredentials(for: protectionSpace, task: task) { (credentials) in
                        if let credentials = credentials,
                            let firstKeyLexicographically = credentials.keys.sorted().first {
                            proceed(proposing: credentials[firstKeyLexicographically])
                        } else {
                            storage.getDefaultCredential(for: protectionSpace, task: task) { (credential) in
                                proceed(proposing: credential)
                            }
                        }
                    }
                } else {
                    proceed(proposing: nil)
                }
                
                return
            }
        }
        
        if let storage = session.configuration.urlCredentialStorage,
           let last = task._protocolLock.performLocked({ task._lastCredentialUsedFromStorageDuringAuthentication }) {
            storage.set(last.credential, for: last.protectionSpace, task: task)
        }
        
        if let cache = session.configuration.urlCache,
           let data = cacheableData,
           let response = cacheableResponse,
           let task = task as? URLSessionDataTask {
            
            let cacheable = CachedURLResponse(response: response, data: Data(data.joined()), storagePolicy: cachePolicy)
            let protocolAllows = (urlProtocol as? _NativeProtocol)?.canCache(cacheable) ?? false
            if protocolAllows {
                if let delegate = task.session.delegate as? URLSessionDataDelegate {
                    delegate.urlSession(task.session as! URLSession, dataTask: task, willCacheResponse: cacheable) { (actualCacheable) in
                        if let actualCacheable = actualCacheable {
                            cache.storeCachedResponse(actualCacheable, for: task)
                        }
                    }
                } else {
                    cache.storeCachedResponse(cacheable, for: task)
                }
            }
        }
        
        switch session.behaviour(for: task) {
        case .taskDelegate(let delegate):
            if let downloadDelegate = delegate as? URLSessionDownloadDelegate, let downloadTask = task as? URLSessionDownloadTask {
                session.delegateQueue.addOperation {
                    downloadDelegate.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: urlProtocol.properties[URLProtocol._PropertyKey.temporaryFileURL] as! URL)
                }
            } else if let webSocketDelegate = delegate as? URLSessionWebSocketDelegate,
                      let webSocketTask = task as? URLSessionWebSocketTask {
                session.delegateQueue.addOperation {
                    webSocketDelegate.urlSession(session, webSocketTask: webSocketTask, didCloseWith: webSocketTask.closeCode, reason: webSocketTask.closeReason)
                }
            }
            session.delegateQueue.addOperation {
                guard task.state != .completed else { return }
                delegate.urlSession(session, task: task, didCompleteWithError: nil)
                task.state = .completed
                session.workQueue.async {
                    session.taskRegistry.remove(task)
                }
            }
        case .noDelegate:
            guard task.state != .completed else { break }
            task.state = .completed
            session.workQueue.async {
                session.taskRegistry.remove(task)
            }
        case .dataCompletionHandler(let completion),
             .dataCompletionHandlerWithTaskDelegate(let completion, _):
            session.delegateQueue.addOperation {
                guard task.state != .completed else { return }
                completion(urlProtocol.properties[URLProtocol._PropertyKey.responseData] as? Data ?? Data(), task.response, nil)
                task.state = .completed
                session.workQueue.async {
                    session.taskRegistry.remove(task)
                }
            }
        case .downloadCompletionHandler(let completion):
            session.delegateQueue.addOperation {
                guard task.state != .completed else { return }
                completion(urlProtocol.properties[URLProtocol._PropertyKey.temporaryFileURL] as? URL, task.response, nil)
                task.state = .completed
                session.workQueue.async {
                    session.taskRegistry.remove(task)
                }
            }
        }
        task._invalidateProtocol()
    }

    func urlProtocol(_ protocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {
        guard let task = `protocol`.task else { fatalError() }
        // Fail with a cancellation error, for now.
        urlProtocol(task: task, didFailWithError: NSError(domain: NSCocoaErrorDomain, code: CocoaError.userCancelled.rawValue))
    }

    func urlProtocol(_ protocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {
        guard let task = `protocol`.task else { fatalError("Received response, but there's no task.") }
        guard let session = task.session as? URLSession else { fatalError("Task not associated with URLSession.") }
        
        func proceed(using credential: URLCredential?) {
            let protectionSpace = challenge.protectionSpace
            let authScheme = protectionSpace.authenticationMethod

            task.suspend()
            
            guard let handler = URLSessionTask.authHandler(for: authScheme) else {
                fatalError("\(authScheme) is not supported")
            }
            handler(task, .useCredential, credential)

            task._protocolLock.performLocked {
                if let credential = credential {
                    task._lastCredentialUsedFromStorageDuringAuthentication = (protectionSpace: protectionSpace, credential: credential)
                } else {
                    task._lastCredentialUsedFromStorageDuringAuthentication = nil
                }
                task._protocolStorage = .existing(_HTTPURLProtocol(task: task, cachedResponse: nil, client: nil))
            }
            
            task.resume()
        }
        
        func attemptProceedingWithDefaultCredential() {
            if let credential = challenge.proposedCredential {
                let last = task._protocolLock.performLocked { task._lastCredentialUsedFromStorageDuringAuthentication }
                
                if last?.credential != credential {
                    proceed(using: credential)
                } else {
                    task.cancel()
                }
            }
        }
        
        if let delegate = session.delegate as? URLSessionTaskDelegate {
            session.delegateQueue.addOperation {
                delegate.urlSession(session, task: task, didReceive: challenge) { disposition, credential in
                    
                    switch disposition {
                    case .useCredential:
                        proceed(using: credential!)
                        
                    case .performDefaultHandling:
                        attemptProceedingWithDefaultCredential()
                        
                    case .rejectProtectionSpace:
                        // swift-corelibs-foundation currently supports only a single protection space per request.
                        fallthrough
                    case .cancelAuthenticationChallenge:
                        task.cancel()
                    }
                    
                }
            }
        } else {
            attemptProceedingWithDefaultCredential()
        }
    }

    func urlProtocol(_ protocol: URLProtocol, didLoad data: Data) {
        `protocol`.properties[.responseData] = data
        guard let task = `protocol`.task else { fatalError() }
        guard let session = task.session as? URLSession else { fatalError() }
        
        switch cachePolicy {
        case .allowed: fallthrough
        case .allowedInMemoryOnly:
            cacheableData?.append(data)

        case .notAllowed:
            break
        }
        
        switch session.behaviour(for: task) {
        case .taskDelegate(let delegate):
            let dataDelegate = delegate as? URLSessionDataDelegate
            let dataTask = task as? URLSessionDataTask
            session.delegateQueue.addOperation {
                dataDelegate?.urlSession(session, dataTask: dataTask!, didReceive: data)
            }
        default: return
        }
    }

    func urlProtocol(_ protocol: URLProtocol, didFailWithError error: Error) {
        guard let task = `protocol`.task else { fatalError() }
        urlProtocol(task: task, didFailWithError: error)
    }

    func urlProtocol(task: URLSessionTask, didFailWithError error: Error) {
        guard let session = task.session as? URLSession else { fatalError() }
        switch session.behaviour(for: task) {
        case .taskDelegate(let delegate):
            session.delegateQueue.addOperation {
                guard task.state != .completed else { return }
                delegate.urlSession(session, task: task, didCompleteWithError: error as Error)
                task.state = .completed
                session.workQueue.async {
                    session.taskRegistry.remove(task)
                }
            }
        case .noDelegate:
            guard task.state != .completed else { break }
            task.state = .completed
            session.workQueue.async {
                session.taskRegistry.remove(task)
            }
        case .dataCompletionHandler(let completion),
             .dataCompletionHandlerWithTaskDelegate(let completion, _):
            session.delegateQueue.addOperation {
                guard task.state != .completed else { return }
                completion(nil, nil, error)
                task.state = .completed
                session.workQueue.async {
                    session.taskRegistry.remove(task)
                }
            }
        case .downloadCompletionHandler(let completion):
            session.delegateQueue.addOperation {
                guard task.state != .completed else { return }
                completion(nil, nil, error)
                task.state = .completed
                session.workQueue.async {
                    session.taskRegistry.remove(task)
                }
            }
        }
        task._invalidateProtocol()
    }

    func urlProtocol(_ protocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) {}

    func urlProtocol(_ protocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) {
        fatalError("The URLSession swift-corelibs-foundation implementation doesn't currently handle redirects directly.")
    }
}
extension URLSessionTask {
    typealias _AuthHandler = ((URLSessionTask, URLSession.AuthChallengeDisposition, URLCredential?) -> ())

    static func authHandler(for authScheme: String) -> _AuthHandler? {
        let handlers: [String : _AuthHandler] = [
            NSURLAuthenticationMethodHTTPBasic : basicAuth,
            NSURLAuthenticationMethodHTTPDigest: digestAuth
        ]
        return handlers[authScheme]
    }

    //Authentication handlers
    static func basicAuth(_ task: URLSessionTask, _ disposition: URLSession.AuthChallengeDisposition, _ credential: URLCredential?) {
        //TODO: Handle disposition. For now, we default to .useCredential
        let user = credential?.user ?? ""
        let password = credential?.password ?? ""
        let encodedString = "\(user):\(password)".data(using: .utf8)?.base64EncodedString()
        task.authRequest = task.originalRequest
        task.authRequest?.setValue("Basic \(encodedString!)", forHTTPHeaderField: "Authorization")
    }

    static func digestAuth(_ task: URLSessionTask, _ disposition: URLSession.AuthChallengeDisposition, _ credential: URLCredential?) {
        fatalError("The URLSession swift-corelibs-foundation implementation doesn't currently handle digest authentication.")
    }
}

extension URLProtocol {
    enum _PropertyKey: String {
        case responseData
        case temporaryFileURL
    }
}
