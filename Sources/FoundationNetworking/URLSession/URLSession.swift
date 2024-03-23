// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

/*
 
 URLSession is a replacement API for URLConnection.  It provides
 options that affect the policy of, and various aspects of the
 mechanism by which NSURLRequest objects are retrieved from the
 network.
 
 An URLSession may be bound to a delegate object.  The delegate is
 invoked for certain events during the lifetime of a session, such as
 server authentication or determining whether a resource to be loaded
 should be converted into a download.
 
 URLSession instances are threadsafe.
 
 The default URLSession uses a system provided delegate and is
 appropriate to use in place of existing code that uses
 +[NSURLConnection sendAsynchronousRequest:queue:completionHandler:]
 
 An URLSession creates URLSessionTask objects which represent the
 action of a resource being loaded.  These are analogous to
 NSURLConnection objects but provide for more control and a unified
 delegate model.
 
 URLSessionTask objects are always created in a suspended state and
 must be sent the -resume message before they will execute.
 
 Subclasses of URLSessionTask are used to syntactically
 differentiate between data and file downloads.
 
 An URLSessionDataTask receives the resource as a series of calls to
 the URLSession:dataTask:didReceiveData: delegate method.  This is type of
 task most commonly associated with retrieving objects for immediate parsing
 by the consumer.
 
 An URLSessionUploadTask differs from an URLSessionDataTask
 in how its instance is constructed.  Upload tasks are explicitly created
 by referencing a file or data object to upload, or by utilizing the
 -URLSession:task:needNewBodyStream: delegate message to supply an upload
 body.
 
 An URLSessionDownloadTask will directly write the response data to
 a temporary file.  When completed, the delegate is sent
 URLSession:downloadTask:didFinishDownloadingToURL: and given an opportunity
 to move this file to a permanent location in its sandboxed container, or to
 otherwise read the file. If canceled, an URLSessionDownloadTask can
 produce a data blob that can be used to resume a download at a later
 time.
 
 Beginning with iOS 9 and Mac OS X 10.11, URLSessionStream is
 available as a task type.  This allows for direct TCP/IP connection
 to a given host and port with optional secure handshaking and
 navigation of proxies.  Data tasks may also be upgraded to a
 URLSessionStream task via the HTTP Upgrade: header and appropriate
 use of the pipelining option of URLSessionConfiguration.  See RFC
 2817 and RFC 6455 for information about the Upgrade: header, and
 comments below on turning data tasks into stream tasks.
 */

/* DataTask objects receive the payload through zero or more delegate messages */
/* UploadTask objects receive periodic progress updates but do not return a body */
/* DownloadTask objects represent an active download to disk.  They can provide resume data when canceled. */
/* StreamTask objects may be used to create NSInput and OutputStreams, or used directly in reading and writing. */

/*
 
 URLSession is not available for i386 targets before Mac OS X 10.10.
 
 */


// -----------------------------------------------------------------------------
/// # URLSession API implementation overview
///
/// ## Design Overview
///
/// This implementation uses libcurl for the HTTP layer implementation. At a
/// high level, the `URLSession` keeps a *multi handle*, and each
/// `URLSessionTask` has an *easy handle*. This way these two APIs somewhat
/// have a 1-to-1 mapping.
///
/// The `URLSessionTask` class is in charge of configuring its *easy handle*
/// and adding it to the owning session’s *multi handle*. Adding / removing
/// the handle effectively resumes / suspends the transfer.
///
/// The `URLSessionTask` class has subclasses, but this design puts all the
/// logic into the parent `URLSessionTask`.
///
/// Both the `URLSession` and `URLSessionTask` extensively use helper
/// types to ease testability, separate responsibilities, and improve
/// readability. These types are nested inside the `URLSession` and
/// `URLSessionTask` to limit their scope. Some of these even have sub-types.
///
/// The session class uses the `URLSession.TaskRegistry` to keep track of its
/// tasks.
///
/// The task class uses an `InternalState` type together with `TransferState` to
/// keep track of its state and each transfer’s state -- note that a single task
/// may do multiple transfers, e.g. as the result of a redirect.
///
/// ## Error Handling
///
/// Most libcurl functions either return a `CURLcode` or `CURLMcode` which
/// are represented in Swift as `CFURLSessionEasyCode` and
/// `CFURLSessionMultiCode` respectively. We turn these functions into throwing
/// functions by appending `.asError()` onto their calls. This turns the error
/// code into `Void` but throws the error if it's not `.OK` / zero.
///
/// This is combined with `try!` is almost all places, because such an error
/// indicates a programming error. Hence the pattern used in this code is
///
/// ```
/// try! someFunction().asError()
/// ```
///
/// where `someFunction()` is a function that returns a `CFURLSessionEasyCode`.
///
/// ## Threading
///
/// The URLSession has a libdispatch ‘work queue’, and all internal work is
/// done on that queue, such that the code doesn't have to deal with thread
/// safety beyond that. All work inside a `URLSessionTask` will run on this
/// work queue, and so will code manipulating the session's *multi handle*.
///
/// Delegate callbacks are, however, done on the passed in
/// `delegateQueue`. And any calls into this API need to switch onto the ‘work
/// queue’ as needed.
///
/// - SeeAlso: https://curl.haxx.se/libcurl/c/threadsafe.html
/// - SeeAlso: URLSession+libcurl.swift
///
/// ## HTTP and RFC 2616
///
/// Most of HTTP is defined in [RFC 2616](https://tools.ietf.org/html/rfc2616).
/// While libcurl handles many of these details, some are handled by this
/// URLSession implementation.
///
/// ## To Do
///
/// - TODO: Is is not clear if using API that takes a URLRequest will override
/// all settings of the URLSessionConfiguration or just those that have not
/// explicitly been set.
/// E.g. creating an URLRequest will cause it to have the default timeoutInterval
/// of 60 seconds, but should this be used in stead of the configuration's
/// timeoutIntervalForRequest even if the request's timeoutInterval has not
/// been set explicitly?
///
/// - TODO: We could re-use EasyHandles once they're complete. That'd be a
/// performance optimization. Not sure how much that'd help. The URLSession
/// would have to keep a pool of unused handles.
///
/// - TODO: Could make `workQueue` concurrent and use a multiple reader / single
/// writer approach if it turns out that there's contention.
// -----------------------------------------------------------------------------


#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import SwiftFoundation
#else
import Foundation
#endif
@_implementationOnly import CoreFoundation

extension URLSession {
    public enum DelayedRequestDisposition {
        case cancel
        case continueLoading
        case useNewRequest
    }
}

fileprivate let globalVarSyncQ = DispatchQueue(label: "org.swift.Foundation.URLSession.GlobalVarSyncQ")
fileprivate var sessionCounter = Int32(0)
fileprivate func nextSessionIdentifier() -> Int32 {
    return globalVarSyncQ.sync {
        sessionCounter += 1
        return sessionCounter
    }
}
public let NSURLSessionTransferSizeUnknown: Int64 = -1

open class URLSession : NSObject {
    internal let _configuration: _Configuration
    fileprivate let multiHandle: _MultiHandle
    fileprivate var nextTaskIdentifier = 1
    internal let workQueue: DispatchQueue 
    internal let taskRegistry = URLSession._TaskRegistry()
    fileprivate let identifier: Int32
    fileprivate var invalidated = false
    fileprivate static let registerProtocols: () = {
        // TODO: We register all the native protocols here.
        _ = URLProtocol.registerClass(_HTTPURLProtocol.self)
        _ = URLProtocol.registerClass(_FTPURLProtocol.self)
        _ = URLProtocol.registerClass(_DataURLProtocol.self)
        _ = URLProtocol.registerClass(_WebSocketURLProtocol.self)
    }()
    
    /*
     * The shared session uses the currently set global URLCache,
     * HTTPCookieStorage and URLCredential.Storage objects.
     */
    open class var shared: URLSession {
        return _shared
    }

    fileprivate static let _shared: URLSession = {
        var configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.protocolClasses = URLProtocol.getProtocols()
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }()

    /*
     * Customization of URLSession occurs during creation of a new session.
     * If you only need to use the convenience routines with custom
     * configuration options it is not necessary to specify a delegate.
     * If you do specify a delegate, the delegate will be retained until after
     * the delegate has been sent the URLSession:didBecomeInvalidWithError: message.
     */
    public /*not inherited*/ init(configuration: URLSessionConfiguration) {
        initializeLibcurl()
        identifier = nextSessionIdentifier()
        self.workQueue = DispatchQueue(label: "URLSession<\(identifier)>")
        self.delegateQueue = OperationQueue()
        self.delegateQueue.maxConcurrentOperationCount = 1
        self.delegate = nil
        //TODO: Make sure this one can't be written to?
        // Could create a subclass of URLSessionConfiguration that wraps the
        // URLSession._Configuration and with fatalError() in all setters.
        self.configuration = configuration.copy() as! URLSessionConfiguration
        let c = URLSession._Configuration(URLSessionConfiguration: configuration)
        self._configuration = c
        self.multiHandle = _MultiHandle(configuration: c, workQueue: workQueue)
        // registering all the protocol classes with URLProtocol
        let _ = URLSession.registerProtocols
    }

    /*
     * A delegate queue should be serial to ensure correct ordering of callbacks.
     * However, if user supplies a concurrent delegateQueue it is not converted to serial.
     */
    public /*not inherited*/ init(configuration: URLSessionConfiguration, delegate: URLSessionDelegate?, delegateQueue queue: OperationQueue?) {
        initializeLibcurl()
        identifier = nextSessionIdentifier()
        self.workQueue = DispatchQueue(label: "URLSession<\(identifier)>")
        if let _queue = queue {
           self.delegateQueue = _queue
        } else {
           self.delegateQueue = OperationQueue()
           self.delegateQueue.maxConcurrentOperationCount = 1
        }
        self.delegate = delegate
        //TODO: Make sure this one can't be written to?
        // Could create a subclass of URLSessionConfiguration that wraps the
        // URLSession._Configuration and with fatalError() in all setters.
        self.configuration = configuration.copy() as! URLSessionConfiguration
        let c = URLSession._Configuration(URLSessionConfiguration: configuration)
        self._configuration = c
        self.multiHandle = _MultiHandle(configuration: c, workQueue: workQueue)
        // registering all the protocol classes with URLProtocol
        let _ = URLSession.registerProtocols
    }
    
    open private(set) var delegateQueue: OperationQueue
    open private(set) var delegate: URLSessionDelegate?
    open private(set) var configuration: URLSessionConfiguration
    
    /*
     * The sessionDescription property is available for the developer to
     * provide a descriptive label for the session.
     */
    open var sessionDescription: String?
    
    /* -finishTasksAndInvalidate returns immediately and existing tasks will be allowed
     * to run to completion.  New tasks may not be created.  The session
     * will continue to make delegate callbacks until URLSession:didBecomeInvalidWithError:
     * has been issued.
     *
     * -finishTasksAndInvalidate and -invalidateAndCancel do not
     * have any effect on the shared session singleton.
     *
     * When invalidating a background session, it is not safe to create another background
     * session with the same identifier until URLSession:didBecomeInvalidWithError: has
     * been issued.
     */
    open func finishTasksAndInvalidate() {
       //we need to return immediately
       workQueue.async {
           //don't allow creation of new tasks from this point onwards
           self.invalidated = true

           let invalidateSessionCallback = { [weak self] in
               //invoke the delegate method and break the delegate link
               guard let strongSelf = self, let sessionDelegate = strongSelf.delegate else { return }
               strongSelf.delegateQueue.addOperation {
                   sessionDelegate.urlSession(strongSelf, didBecomeInvalidWithError: nil)
                   strongSelf.delegate = nil
               }
           }

           //wait for running tasks to finish
           if !self.taskRegistry.isEmpty {
               self.taskRegistry.notify(on: invalidateSessionCallback)
           } else {
               invalidateSessionCallback()
           }
       }
    }
    
    /* -invalidateAndCancel acts as -finishTasksAndInvalidate, but issues
     * -cancel to all outstanding tasks for this session.  Note task
     * cancellation is subject to the state of the task, and some tasks may
     * have already have completed at the time they are sent -cancel.
     */
    open func invalidateAndCancel() {
        /*
         As per documentation,
         Calling this method on the session returned by the sharedSession method has no effect.
         */
        guard self !== URLSession.shared else { return }
        
        workQueue.sync {
            self.invalidated = true
        }
        
        for task in taskRegistry.allTasks {
            task.cancel()
        }
        
        // Don't allow creation of new tasks from this point onwards
        workQueue.async {
            guard let sessionDelegate = self.delegate else { return }
            
            self.delegateQueue.addOperation {
                sessionDelegate.urlSession(self, didBecomeInvalidWithError: nil)
                self.delegate = nil
            }
        }
    }
    
    /* empty all cookies, cache and credential stores, removes disk files, issues -flushWithCompletionHandler:. Invokes completionHandler() on the delegate queue. */
    open func reset(completionHandler: @escaping () -> Void) {
        let configuration = self.configuration
        
        DispatchQueue.global(qos: .background).async {
            configuration.urlCache?.removeAllCachedResponses()
            if let storage = configuration.urlCredentialStorage {
                for credentialEntry in storage.allCredentials {
                    for credential in credentialEntry.value {
                        storage.remove(credential.value, for: credentialEntry.key)
                    }
                }
            }
            
            self.flush(completionHandler: completionHandler)
        }
    }
    
     /* flush storage to disk and clear transient network caches.  Invokes completionHandler() on the delegate queue. */
    open func flush(completionHandler: @escaping () -> Void) {
        // We create new CURL handles every request.
        delegateQueue.addOperation {
            completionHandler()
        }
    }

    @available(*, unavailable, renamed: "getTasksWithCompletionHandler(_:)")
    open func getTasksWithCompletionHandler(completionHandler: @escaping ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask]) -> Void) {
        getTasksWithCompletionHandler(completionHandler)
    }

    /* invokes completionHandler with outstanding data, upload and download tasks. */
    open func getTasksWithCompletionHandler(_ completionHandler: @escaping ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask]) -> Void)  {
        workQueue.async {
            self.delegateQueue.addOperation {
                var dataTasks = [URLSessionDataTask]()
                var uploadTasks = [URLSessionUploadTask]()
                var downloadTasks = [URLSessionDownloadTask]()

                for task in self.taskRegistry.allTasks {
                    guard task.state == .running || task.isSuspendedAfterResume else { continue }

                    if let uploadTask = task as? URLSessionUploadTask {
                        uploadTasks.append(uploadTask)
                    } else if let dataTask = task as? URLSessionDataTask {
                        dataTasks.append(dataTask)
                    } else if let downloadTask = task as? URLSessionDownloadTask {
                        downloadTasks.append(downloadTask)
                    } else {
                        // Above three are the only required tasks to be returned from this API, so we can ignore any other types of tasks.
                    }
                }
                completionHandler(dataTasks, uploadTasks, downloadTasks)
            }
        }
    }
    
    /* invokes completionHandler with all outstanding tasks. */
    open func getAllTasks(completionHandler: @escaping ([URLSessionTask]) -> Void)  {
        workQueue.async {
            self.delegateQueue.addOperation {
                completionHandler(self.taskRegistry.allTasks.filter { $0.state == .running || $0.isSuspendedAfterResume })
            }
        }
    }
    
    /*
     * URLSessionTask objects are always created in a suspended state and
     * must be sent the -resume message before they will execute.
     */
    
    /* Creates a data task with the given request.  The request may have a body stream. */
    open func dataTask(with request: URLRequest) -> URLSessionDataTask {
        return dataTask(with: _Request(request), behaviour: .callDelegate)
    }
    
    /* Creates a data task to retrieve the contents of the given URL. */
    open func dataTask(with url: URL) -> URLSessionDataTask {
        return dataTask(with: _Request(url), behaviour: .callDelegate)
    }

    /*
     * data task convenience methods.  These methods create tasks that
     * bypass the normal delegate calls for response and data delivery,
     * and provide a simple cancelable asynchronous interface to receiving
     * data.  Errors will be returned in the NSURLErrorDomain,
     * see <Foundation/NSURLError.h>.  The delegate, if any, will still be
     * called for authentication challenges.
     */
    open func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        return dataTask(with: _Request(request), behaviour: .dataCompletionHandler(completionHandler))
    }

    open func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        return dataTask(with: _Request(url), behaviour: .dataCompletionHandler(completionHandler))
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    open func data(from url: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        var task: URLSessionTask? = nil

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let completionHandler: URLSession._TaskRegistry.DataTaskCompletion = { data, response, error in
                    if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        fatalError()
                    }
                }
                task = dataTask(with: _Request(url), behaviour: .dataCompletionHandlerWithTaskDelegate(completionHandler, delegate))

                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                task?.resume()
            }
        } onCancel: { [weak task] in
            task?.cancel()
        }
    }
    
    /* Creates an upload task with the given request.  The body of the request will be created from the file referenced by fileURL */
    open func uploadTask(with request: URLRequest, fromFile fileURL: URL) -> URLSessionUploadTask {
        let r = URLSession._Request(request)
        return uploadTask(with: r, body: .file(fileURL), behaviour: .callDelegate)
    }
    
    /* Creates an upload task with the given request.  The body of the request is provided from the bodyData. */
    open func uploadTask(with request: URLRequest, from bodyData: Data) -> URLSessionUploadTask {
        let r = URLSession._Request(request)
        return uploadTask(with: r, body: .data(createDispatchData(bodyData)), behaviour: .callDelegate)
    }
    
    /* Creates an upload task with the given request.  The previously set body stream of the request (if any) is ignored and the URLSession:task:needNewBodyStream: delegate will be called when the body payload is required. */
    open func uploadTask(withStreamedRequest request: URLRequest) -> URLSessionUploadTask {
        let r = URLSession._Request(request)
        return uploadTask(with: r, body: nil, behaviour: .callDelegate)
    }

    /*
     * upload convenience method.
     */
    open func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
        let r = URLSession._Request(request)
        return uploadTask(with: r, body: .file(fileURL), behaviour: .dataCompletionHandler(completionHandler))
    }

    open func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
        return uploadTask(with: _Request(request), body: .data(createDispatchData(bodyData!)), behaviour: .dataCompletionHandler(completionHandler))
    }
    
    /* Creates a download task with the given request. */
    open func downloadTask(with request: URLRequest) -> URLSessionDownloadTask {
        let r = URLSession._Request(request)
        return downloadTask(with: r, behavior: .callDelegate)
    }
    
    /* Creates a download task to download the contents of the given URL. */
    open func downloadTask(with url: URL) -> URLSessionDownloadTask {
        return downloadTask(with: _Request(url), behavior: .callDelegate)
    }
    
    /* Creates a download task with the resume data.  If the download cannot be successfully resumed, URLSession:task:didCompleteWithError: will be called. */
    open func downloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask {
        return invalidDownloadTask(behavior: .callDelegate)
    }

    /*
     * download task convenience methods.  When a download successfully
     * completes, the URL will point to a file that must be read or
     * copied during the invocation of the completion routine.  The file
     * will be removed automatically.
     */
    open func downloadTask(with request: URLRequest, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        return downloadTask(with: _Request(request), behavior: .downloadCompletionHandler(completionHandler))
    }

    open func downloadTask(with url: URL, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
       return downloadTask(with: _Request(url), behavior: .downloadCompletionHandler(completionHandler))
    }

    open func downloadTask(withResumeData resumeData: Data, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        return invalidDownloadTask(behavior: .downloadCompletionHandler(completionHandler))
    }
    
    /* Creates a bidirectional stream task to a given host and port.
     */
    @available(*, unavailable, message: "URLSessionStreamTask is not available in swift-corelibs-foundation")
    open func streamTask(withHostName hostname: String, port: Int) -> URLSessionStreamTask { NSUnsupported() }
    
    open func webSocketTask(with url: URL) -> URLSessionWebSocketTask {
        return webSocketTask(with: _Request(url), behavior: .callDelegate)
    }
    
    open func webSocketTask(with url: URL, protocols: [String]) -> URLSessionWebSocketTask {
        var request = URLRequest(url: url)
        request.setValue(protocols.joined(separator: ", "), forHTTPHeaderField: "Sec-WebSocket-Protocol")
        return webSocketTask(with: request)
    }

    open func webSocketTask(with request: URLRequest) -> URLSessionWebSocketTask {
        return webSocketTask(with: _Request(request), behavior: .callDelegate)
    }
}


// Helpers
fileprivate extension URLSession {
    enum _Request {
        case request(URLRequest)
        case url(URL)
    }
    func createConfiguredRequest(from request: URLSession._Request) -> URLRequest {
        let r = request.createMutableURLRequest()
        return _configuration.configure(request: r)
    }
}
extension URLSession._Request {
    init(_ url: URL) {
        self = .url(url)
    }
    init(_ request: URLRequest) {
        self = .request(request)
    }
}
extension URLSession._Request {
    func createMutableURLRequest() -> URLRequest {
        switch self {
        case .url(let url): return URLRequest(url: url)
        case .request(let r): return r
        }
    }
}

fileprivate extension URLSession {
    func createNextTaskIdentifier() -> Int {
        return workQueue.sync {
            let i = nextTaskIdentifier
            nextTaskIdentifier += 1
            return i
        }
    }
}

fileprivate extension URLSession {
    /// Create a data task.
    ///
    /// All public methods funnel into this one.
    func dataTask(with request: _Request, behaviour: _TaskRegistry._Behaviour) -> URLSessionDataTask {
        guard !self.invalidated else { fatalError("Session invalidated") }
        let r = createConfiguredRequest(from: request)
        let i = createNextTaskIdentifier()
        let task = URLSessionDataTask(session: self, request: r, taskIdentifier: i)
        workQueue.async {
            self.taskRegistry.add(task, behaviour: behaviour)
        }
        return task
    }
    
    /// Create an upload task.
    ///
    /// All public methods funnel into this one.
    func uploadTask(with request: _Request, body: URLSessionTask._Body?, behaviour: _TaskRegistry._Behaviour) -> URLSessionUploadTask {
        guard !self.invalidated else { fatalError("Session invalidated") }
        let r = createConfiguredRequest(from: request)
        let i = createNextTaskIdentifier()
        let task = URLSessionUploadTask(session: self, request: r, taskIdentifier: i, body: body)
        workQueue.async {
            self.taskRegistry.add(task, behaviour: behaviour)
        }
        return task
    }
    
    /// Create a download task
    func downloadTask(with request: _Request, behavior: _TaskRegistry._Behaviour) -> URLSessionDownloadTask {
        guard !self.invalidated else { fatalError("Session invalidated") }
        let r = createConfiguredRequest(from: request)
        let i = createNextTaskIdentifier()
        let task = URLSessionDownloadTask(session: self, request: r, taskIdentifier: i)
        workQueue.async {
            self.taskRegistry.add(task, behaviour: behavior)
        }
        return task
    }
  
    /// Create a web socket task
    func webSocketTask(with request: _Request, behavior: _TaskRegistry._Behaviour) -> URLSessionWebSocketTask {
        guard !self.invalidated else { fatalError("Session invalidated") }
        let r = createConfiguredRequest(from: request)
        let i = createNextTaskIdentifier()
        let task = URLSessionWebSocketTask(session: self, request: r, taskIdentifier: i, body: URLSessionTask._Body.none)
        workQueue.async {
            self.taskRegistry.add(task, behaviour: behavior)
        }
        return task
    }

    /// Create a download task that is marked invalid.
    func invalidDownloadTask(behavior: _TaskRegistry._Behaviour) -> URLSessionDownloadTask {
        /* We do not support resume data in swift-corelibs-foundation, so whatever we are passed, we should just behave as Darwin does in the presence of invalid data. */
        
        guard !self.invalidated else { fatalError("Session invalidated") }
        let task = URLSessionDownloadTask()
        task.createdFromInvalidResumeData = true
        task.taskIdentifier = createNextTaskIdentifier()
        task.session = self
        workQueue.async {
            self.taskRegistry.add(task, behaviour: behavior)
        }
        return task
    }
}

internal extension URLSession {
    /// The kind of callback / delegate behaviour of a task.
    ///
    /// This is similar to the `URLSession.TaskRegistry.Behaviour`, but it
    /// also encodes the kind of delegate that the session has.
    enum _TaskBehaviour {
        /// The session has no delegate, or just a plain `URLSessionDelegate`.
        case noDelegate
        /// The session has a delegate of type `URLSessionTaskDelegate`
        case taskDelegate(URLSessionTaskDelegate)
        /// Default action for all events, except for completion.
        /// - SeeAlso: URLSession.TaskRegistry.Behaviour.dataCompletionHandler
        case dataCompletionHandler(URLSession._TaskRegistry.DataTaskCompletion)
        /// Default action for all asynchronous events.
        /// - SeeAlso: URLsession.TaskRegistry.Behaviour.dataCompletionHandlerWithTaskDelegate
        case dataCompletionHandlerWithTaskDelegate(URLSession._TaskRegistry.DataTaskCompletion, URLSessionTaskDelegate)
        /// Default action for all events, except for completion.
        /// - SeeAlso: URLSession.TaskRegistry.Behaviour.downloadCompletionHandler
        case downloadCompletionHandler(URLSession._TaskRegistry.DownloadTaskCompletion)
    }

    func behaviour(for task: URLSessionTask) -> _TaskBehaviour {
        switch taskRegistry.behaviour(for: task) {
        case .dataCompletionHandler(let c): return .dataCompletionHandler(c)
        case .dataCompletionHandlerWithTaskDelegate(let c, let d):
            guard let d else {
                return .dataCompletionHandler(c)
            }
            return .dataCompletionHandlerWithTaskDelegate(c, d)
        case .downloadCompletionHandler(let c): return .downloadCompletionHandler(c)
        case .callDelegate:
            guard let d = delegate as? URLSessionTaskDelegate else {
                return .noDelegate
            }
            return .taskDelegate(d)
        }
    }
}


internal protocol URLSessionProtocol: AnyObject {
    func add(handle: _EasyHandle)
    func remove(handle: _EasyHandle)
    func behaviour(for: URLSessionTask) -> URLSession._TaskBehaviour
    var configuration: URLSessionConfiguration { get }
    var delegate: URLSessionDelegate? { get }
}
extension URLSession: URLSessionProtocol {
    func add(handle: _EasyHandle) {
        multiHandle.add(handle)
    }
    func remove(handle: _EasyHandle) {
        multiHandle.remove(handle)
    }
}
/// This class is only used to allow `URLSessionTask.init()` to work.
///
/// - SeeAlso: URLSessionTask.init()
final internal class _MissingURLSession: URLSessionProtocol {
    var delegate: URLSessionDelegate? {
        fatalError()
    }
    var configuration: URLSessionConfiguration {
        fatalError()
    }
    func add(handle: _EasyHandle) {
        fatalError()
    }
    func remove(handle: _EasyHandle) {
        fatalError()
    }
    func behaviour(for: URLSessionTask) -> URLSession._TaskBehaviour {
        fatalError()
    }
}
