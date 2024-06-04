// Foundation/URLSession/NativeProtocol.swift - NSURLSession & libcurl
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
// -----------------------------------------------------------------------------
///
/// This file has the common implementation of Native protocols like HTTP,FTP,Data
/// These are libcurl helpers for the URLSession API code.
/// - SeeAlso: https://curl.haxx.se/libcurl/c/
/// - SeeAlso: NSURLSession.swift
///
// -----------------------------------------------------------------------------

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import SwiftFoundation
#else
import Foundation
#endif

@_implementationOnly import CoreFoundation
import Dispatch

internal let enableLibcurlDebugOutput: Bool = {
    return ProcessInfo.processInfo.environment["URLSessionDebugLibcurl"] != nil
}()
internal let enableDebugOutput: Bool = {
    return ProcessInfo.processInfo.environment["URLSessionDebug"] != nil
}()

internal class _NativeProtocol: URLProtocol, _EasyHandleDelegate {
    internal var easyHandle: _EasyHandle!
    internal lazy var tempFileURL: URL = {
        let fileName = NSTemporaryDirectory() + NSUUID().uuidString + ".tmp"
        _ = FileManager.default.createFile(atPath: fileName, contents: nil)
        return URL(fileURLWithPath: fileName)
    }()

    public required init(task: URLSessionTask, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        self.internalState = .initial
        super.init(request: task.originalRequest!, cachedResponse: cachedResponse, client: client)
        self.task = task
        self.easyHandle = _EasyHandle(delegate: self)
    }

    public required init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        self.internalState = .initial
        super.init(request: request, cachedResponse: cachedResponse, client: client)
        self.easyHandle = _EasyHandle(delegate: self)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        resume()
    }

    override func stopLoading() {
        if task?.state == .suspended {
            suspend()
        } else {
            self.internalState = .transferFailed
            guard let error = self.task?.error else { fatalError() }
            completeTask(withError: error)
        }
    }

    var internalState: _InternalState {
        // We manage adding / removing the easy handle and pausing / unpausing
        // here at a centralized place to make sure the internal state always
        // matches up with the state of the easy handle being added and paused.
        willSet {
            if !internalState.isEasyHandlePaused && newValue.isEasyHandlePaused {
                fatalError("Need to solve pausing receive.")
            }
            if internalState.isEasyHandleAddedToMultiHandle && !newValue.isEasyHandleAddedToMultiHandle {
                task?.session.remove(handle: easyHandle)
            }
        }
        didSet {
            if !oldValue.isEasyHandleAddedToMultiHandle && internalState.isEasyHandleAddedToMultiHandle {
                task?.session.add(handle: easyHandle)
            }
            if oldValue.isEasyHandlePaused && !internalState.isEasyHandlePaused {
                fatalError("Need to solve pausing receive.")
            }
        }
    }

    func didReceive(data: Data) -> _EasyHandle._Action {
        guard case .transferInProgress(var ts) = internalState else {
            fatalError("Received body data, but no transfer in progress.")
        }

        if let response = validateHeaderComplete(transferState:ts) {
            ts.response = response
        }

        // Note this excludes code 300 which should return the response of the redirect and not follow it.
        // For other redirect codes dont notify the delegate of the data received in the redirect response.
        if let httpResponse = ts.response as? HTTPURLResponse, 301...308 ~= httpResponse.statusCode {
            if let _http = self as? _HTTPURLProtocol {
                // Save the response body in case the delegate does not perform a redirect and the 3xx response
                // including its body needs to be returned to the client.
                var redirectBody = _http.lastRedirectBody ?? Data()
                redirectBody.append(data)
                _http.lastRedirectBody = redirectBody
            }
            return .proceed
        }

        notifyDelegate(aboutReceivedData: data)
        internalState = .transferInProgress(ts.byAppending(bodyData: data))
        return .proceed
    }

    func validateHeaderComplete(transferState: _TransferState) -> URLResponse? {
        guard transferState.isHeaderComplete else {
            fatalError("Received body data, but the header is not complete, yet.")
        }
        return nil
    }

    fileprivate func notifyDelegate(aboutReceivedData data: Data) {
        guard let t = self.task else {
            fatalError("Cannot notify")
        }
        if case .taskDelegate(let delegate) = t.session.behaviour(for: self.task!),
            let dataDelegate = delegate as? URLSessionDataDelegate,
            let task = self.task as? URLSessionDataTask {
            // Forward to the delegate:
            guard let s = self.task?.session as? URLSession else {
                fatalError()
            }
            s.delegateQueue.addOperation {
                dataDelegate.urlSession(s, dataTask: task, didReceive: data)
            }
        } else if case .taskDelegate(let delegate) = t.session.behaviour(for: self.task!),
            let downloadDelegate = delegate as? URLSessionDownloadDelegate,
            let task = self.task as? URLSessionDownloadTask {
            guard let s = self.task?.session as? URLSession else {
                fatalError()
            }
            let fileHandle = try! FileHandle(forWritingTo: self.tempFileURL)
            _ = fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            task.countOfBytesReceived  += Int64(data.count)
            s.delegateQueue.addOperation {
                downloadDelegate.urlSession(s, downloadTask: task, didWriteData: Int64(data.count), totalBytesWritten: task.countOfBytesReceived,
                                            totalBytesExpectedToWrite: task.countOfBytesExpectedToReceive)
            }
        }
    }

    fileprivate func notifyDelegate(aboutUploadedData count: Int64) {
        guard let task = self.task, let session = task.session as? URLSession,
            case .taskDelegate(let delegate) = session.behaviour(for: task) else { return }
        task.countOfBytesSent += count
        session.delegateQueue.addOperation {
            delegate.urlSession(session, task: task, didSendBodyData: count,
                                totalBytesSent: task.countOfBytesSent, totalBytesExpectedToSend: task.countOfBytesExpectedToSend)
        }
    }

    func didReceive(headerData data: Data, contentLength: Int64) -> _EasyHandle._Action {
        NSRequiresConcreteImplementation()
    }

    func fill(writeBuffer buffer: UnsafeMutableBufferPointer<Int8>) -> _EasyHandle._WriteBufferResult {
        guard case .transferInProgress(let ts) = internalState else {
            fatalError("Requested to fill write buffer, but transfer isn't in progress.")
        }
        guard let source = ts.requestBodySource else {
            fatalError("Requested to fill write buffer, but transfer state has no body source.")
        }
        switch source.getNextChunk(withLength: buffer.count) {
        case .data(let data):
            copyDispatchData(data, infoBuffer: buffer)
            let count = data.count
            assert(count > 0)
            notifyDelegate(aboutUploadedData: Int64(count))
            return .bytes(count)
        case .done:
            return .bytes(0)
        case .retryLater:
            // At this point we'll try to pause the easy handle. The body source
            // is responsible for un-pausing the handle once data becomes
            // available.
            return .pause
        case .error:
            return .abort
        }
    }

    func transferCompleted(withError error: NSError?) {
        // At this point the transfer is complete and we can decide what to do.
        // If everything went well, we will simply forward the resulting data
        // to the delegate. But in case of redirects etc. we might send another
        // request.
        guard error == nil else {
            internalState = .transferFailed
            failWith(error: error!, request: request)
            return
        }
        guard case .transferInProgress(let ts) = internalState else {
            fatalError("Transfer completed, but it wasn't in progress.")
        }
        guard let request = task?.currentRequest else {
            fatalError("Transfer completed, but there's no current request.")
        }

        if let response = task?.response {
            var transferState = ts
            transferState.response = response
        }

        guard let response = ts.response else {
            fatalError("Transfer completed, but there's no response.")
        }
        internalState = .transferCompleted(response: response, bodyDataDrain: ts.bodyDataDrain)
        let action = completionAction(forCompletedRequest: request, response: response)

        switch action {
        case .completeTask:
            completeTask()
        case .failWithError(let errorCode):
            internalState = .transferFailed
            let error = NSError(domain: NSURLErrorDomain, code: errorCode,
                                userInfo: [NSLocalizedDescriptionKey: "Completion failure"])
            failWith(error: error, request: request)
        case .redirectWithRequest(let newRequest):
            redirectFor(request: newRequest)
        }
    }

    func redirectFor(request: URLRequest) {
        NSRequiresConcreteImplementation()
    }

    func completeTask() {
        guard case .transferCompleted(response: let response, bodyDataDrain: let bodyDataDrain) = self.internalState else {
            fatalError("Trying to complete the task, but its transfer isn't complete.")
        }
        task?.response = response
        // We don't want a timeout to be triggered after this. The timeout timer needs to be cancelled.
        easyHandle.timeoutTimer = nil
        // because we deregister the task with the session on internalState being set to taskCompleted
        // we need to do the latter after the delegate/handler was notified/invoked
        if case .inMemory(let bodyData) = bodyDataDrain {
            var data = Data()
            if let body = bodyData {
                withExtendedLifetime(body) {
                    data = Data(bytes: body.bytes, count: body.length)
                }
            }
            self.client?.urlProtocol(self, didLoad: data)
            self.internalState = .taskCompleted
        } else if case .toFile(let url, let fileHandle?) = bodyDataDrain {
            self.properties[.temporaryFileURL] = url
            fileHandle.closeFile()
        } else if task is URLSessionDownloadTask {
            let fileHandle = try! FileHandle(forWritingTo: self.tempFileURL)
            fileHandle.closeFile()
            self.properties[.temporaryFileURL] = self.tempFileURL
        }
        self.client?.urlProtocolDidFinishLoading(self)
        self.internalState = .taskCompleted
    }

    func completionAction(forCompletedRequest request: URLRequest, response: URLResponse) -> _CompletionAction {
        return .completeTask
    }

    func seekInputStream(to position: UInt64) throws {
        // We will reset the body source and seek forward.
        guard let session = task?.session as? URLSession else { fatalError() }
        
        var currentInputStream: InputStream?
        
        if let delegate = session.delegate as? URLSessionTaskDelegate {
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            
            delegate.urlSession(session, task: task!, needNewBodyStream: { inputStream in
                currentInputStream = inputStream
                dispatchGroup.leave()
            })
            
            _ = dispatchGroup.wait(timeout: .now() + 7)
        }
      
        if let url = self.request.url, let inputStream = currentInputStream {
            switch self.internalState {
            case .transferInProgress(let currentTransferState):
                switch currentTransferState.requestBodySource {
                case is _BodyStreamSource:
                    try _InputStreamSPIForFoundationNetworkingUseOnly(inputStream).seek(to: position)
                    let drain = self.createTransferBodyDataDrain()
                    let source = _BodyStreamSource(inputStream: inputStream)
                    let transferState = _TransferState(url: url, bodyDataDrain: drain, bodySource: source)
                    self.internalState = .transferInProgress(transferState)
                default:
                    fatalError()
                }
            default:
                //TODO: it's possible?
                break
            }
        }
    }

    func updateProgressMeter(with progress: _EasyHandle._Progress) {
        guard let progressReporter = self.task?.progress else { return }
        
        progressReporter.totalUnitCount = progress.totalBytesExpectedToReceive + progress.totalBytesExpectedToSend
        progressReporter.completedUnitCount = progress.totalBytesReceived + progress.totalBytesSent
    }

    /// The data drain.
    ///
    /// This depends on what the delegate / completion handler need.
    fileprivate func createTransferBodyDataDrain() -> _DataDrain {
        guard let task = task else {
            fatalError()
        }
        let s = task.session as! URLSession
        switch s.behaviour(for: task) {
        case .noDelegate:
            return .ignore
        case .taskDelegate:
            // Data will be forwarded to the delegate as we receive it, we don't
            // need to do anything about it.
            return .ignore
        case .dataCompletionHandler,
             .dataCompletionHandlerWithTaskDelegate:
            // Data needs to be concatenated in-memory such that we can pass it
            // to the completion handler upon completion.
            return .inMemory(nil)
        case .downloadCompletionHandler:
            // Data needs to be written to a file (i.e. a download task).
            let fileHandle = try! FileHandle(forWritingTo: self.tempFileURL)
            return .toFile(self.tempFileURL, fileHandle)
        }
    }

    func createTransferState(url: URL, body: _Body, workQueue: DispatchQueue) -> _TransferState {
        let drain = createTransferBodyDataDrain()
        switch body {
        case .none:
            return _TransferState(url: url, bodyDataDrain: drain)
        case .data(let data):
            let source = _BodyDataSource(data: data)
            return _TransferState(url: url, bodyDataDrain: drain,bodySource: source)
        case .file(let fileURL):
            let source = _BodyFileSource(fileURL: fileURL, workQueue: workQueue, dataAvailableHandler: { [weak self] in
                // Unpause the easy handle
                self?.easyHandle.unpauseSend()
            })
            return _TransferState(url: url, bodyDataDrain: drain,bodySource: source)
        case .stream(let inputStream):
            let source = _BodyStreamSource(inputStream: inputStream)
            return _TransferState(url: url, bodyDataDrain: drain, bodySource: source)
        }
    }

    /// Start a new transfer
    func startNewTransfer(with request: URLRequest) {
        let task = self.task!
        task.currentRequest = request
        guard let url = request.url else {
            fatalError("No URL in request.")
        }

        task.getBody { (body) in
            self.internalState = .transferReady(self.createTransferState(url: url, body: body, workQueue: task.workQueue))
            let request = task.authRequest ?? request
            self.configureEasyHandle(for: request, body: body)
            if (task.suspendCount) < 1 {
                self.resume()
            }
        }
    }

    func resume() {
        if case .initial = self.internalState {
            guard let r = task?.originalRequest else {
                fatalError("Task has no original request.")
            }
            
            // Check if the cached response is good to use:
            if let cachedResponse = cachedResponse, canRespondFromCache(using: cachedResponse) {
                self.internalState = .fulfillingFromCache(cachedResponse)
                task?.workQueue.async {
                    self.client?.urlProtocol(self, cachedResponseIsValid: cachedResponse)
                    self.client?.urlProtocol(self, didReceive: cachedResponse.response, cacheStoragePolicy: .notAllowed)
                    if !cachedResponse.data.isEmpty {
                        self.client?.urlProtocol(self, didLoad: cachedResponse.data)
                    }
                    
                    self.client?.urlProtocolDidFinishLoading(self)
                    
                    self.internalState = .taskCompleted
                }
                
            } else {
                startNewTransfer(with: r)
            }
        }

        if case .transferReady(let transferState) = self.internalState {
            self.internalState = .transferInProgress(transferState)
        }
    }
    
    func canCache(_ response: CachedURLResponse) -> Bool {
        return false
    }
    
    /// Allows a native protocol to process a cached response. If `true` is returned, the protocol will replay the cached response instead of starting a new transfer. The default implementation invalidates the response in the cache and returns `false`.
    func canRespondFromCache(using response: CachedURLResponse) -> Bool {
        // By default, native protocols do not cache. Aggressively remove unexpected cached responses.
        if let cache = task?.session.configuration.urlCache, let task = task as? URLSessionDataTask {
            cache.removeCachedResponse(for: task)
        }
        return false
    }

    func suspend() {
        if case .transferInProgress(let transferState) =  self.internalState {
            self.internalState = .transferReady(transferState)
        }
    }

    func configureEasyHandle(for request: URLRequest, body: _Body) {
        NSRequiresConcreteImplementation()
    }
}

extension _NativeProtocol {
    /// Action to be taken after a transfer completes
    enum _CompletionAction {
        case completeTask
        case failWithError(Int)
        case redirectWithRequest(URLRequest)
    }

    func completeTask(withError error: Error) {
        task?.error = error
        guard case .transferFailed = self.internalState else {
            fatalError("Trying to complete the task, but its transfer isn't complete / failed.")
        }
        //We don't want a timeout to be triggered after this. The timeout timer needs to be cancelled.
        easyHandle.timeoutTimer = nil
        self.internalState = .taskCompleted
    }

    func failWith(error: NSError, request: URLRequest) {
        //TODO: Error handling
        let userInfo: [String : Any]? = request.url.map {
            [
                NSUnderlyingErrorKey: error,
                NSURLErrorFailingURLErrorKey: $0,
                NSURLErrorFailingURLStringErrorKey: $0.absoluteString,
                NSLocalizedDescriptionKey: NSLocalizedString(error.localizedDescription, comment: "N/A")
            ]
        }
        let urlError = URLError(_nsError: NSError(domain: NSURLErrorDomain, code: error.code, userInfo: userInfo))
        completeTask(withError: urlError)
        self.client?.urlProtocol(self, didFailWithError: urlError)
    }

    /// Give the delegate a chance to tell us how to proceed once we have a
    /// response / complete header.
    ///
    /// This will pause the transfer.
    func askDelegateHowToProceedAfterCompleteResponse(_ response: URLResponse, delegate: URLSessionDataDelegate) {
        // Ask the delegate how to proceed.
        // This will pause the easy handle. We need to wait for the
        // delegate before processing any more data.
        guard case .transferInProgress(let ts) = self.internalState else {
            fatalError("Transfer not in progress.")
        }
        self.internalState = .waitingForResponseCompletionHandler(ts)

        let dt = task as! URLSessionDataTask

        // We need this ugly cast in order to be able to support `URLSessionTask.init()`
        guard let s = task?.session as? URLSession else {
            fatalError()
        }
        s.delegateQueue.addOperation {
            delegate.urlSession(s, dataTask: dt, didReceive: response, completionHandler: { [weak self] disposition in
                guard let task = self else { return }
                self?.task?.workQueue.async {
                    task.didCompleteResponseCallback(disposition: disposition)
                }
            })
        }
    }

    /// This gets called (indirectly) when the data task delegates lets us know
    /// how we should proceed after receiving a response (i.e. complete header).
    func didCompleteResponseCallback(disposition: URLSession.ResponseDisposition) {
        guard case .waitingForResponseCompletionHandler(let ts) = self.internalState else {
            fatalError("Received response disposition, but we're not waiting for it.")
        }
        switch disposition {
        case .cancel:
            let error = URLError(_nsError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
            self.completeTask(withError: error)
            self.client?.urlProtocol(self, didFailWithError: error)
        case .allow:
            // Continue the transfer. This will unpause the easy handle.
            self.internalState = .transferInProgress(ts)
        case .becomeDownload:
            /* Turn this request into a download */
            NSUnimplemented()
        case .becomeStream:
            /* Turn this task into a stream task */
            NSUnsupported()
        }
    }
}

extension _NativeProtocol {

    enum _InternalState {
        /// Task has been created, but nothing has been done, yet
        case initial
        /// The task is being fulfilled from the cache rather than the network.
        case fulfillingFromCache(CachedURLResponse)
        /// The easy handle has been fully configured. But it is not added to
        /// the multi handle.
        case transferReady(_TransferState)
        /// The easy handle is currently added to the multi handle
        case transferInProgress(_TransferState)
        /// The transfer completed.
        ///
        /// The easy handle has been removed from the multi handle. This does
        /// not necessarily mean the task completed. A task that gets
        /// redirected will do multiple transfers.
        case transferCompleted(response: URLResponse, bodyDataDrain: _NativeProtocol._DataDrain)
        /// The transfer failed.
        ///
        /// Same as `.transferCompleted`, but without response / body data
        case transferFailed
        /// Waiting for the completion handler of the HTTP redirect callback.
        ///
        /// When we tell the delegate that we're about to perform an HTTP
        /// redirect, we need to wait for the delegate to let us know what
        /// action to take.
        case waitingForRedirectCompletionHandler(response: URLResponse, bodyDataDrain: _NativeProtocol._DataDrain)
        /// Waiting for the completion handler of the 'did receive response' callback.
        ///
        /// When we tell the delegate that we received a response (i.e. when
        /// we received a complete header), we need to wait for the delegate to
        /// let us know what action to take. In this state the easy handle is
        /// paused in order to suspend delegate callbacks.
        case waitingForResponseCompletionHandler(_TransferState)
        /// The task is completed
        ///
        /// Contrast this with `.transferCompleted`.
        case taskCompleted
    }
}

extension _NativeProtocol._InternalState {
    var isEasyHandleAddedToMultiHandle: Bool {
        switch self {
        case .initial:                             return false
        case .fulfillingFromCache:                 return false
        case .transferReady:                       return false
        case .transferInProgress:                  return true
        case .transferCompleted:                   return false
        case .transferFailed:                      return false
        case .waitingForRedirectCompletionHandler: return false
        case .waitingForResponseCompletionHandler: return true
        case .taskCompleted:                       return false
        }
    }

    var isEasyHandlePaused: Bool {
        switch self {
        case .initial:                             return false
        case .fulfillingFromCache:                 return false
        case .transferReady:                       return false
        case .transferInProgress:                  return false
        case .transferCompleted:                   return false
        case .transferFailed:                      return false
        case .waitingForRedirectCompletionHandler: return false
        case .waitingForResponseCompletionHandler: return true
        case .taskCompleted:                       return false
        }
    }
}

extension _NativeProtocol {

    enum _Error: Error {
        case parseSingleLineError
        case parseCompleteHeaderError
    }
 
    func errorCode(fileSystemError error: Error) -> Int {
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
}

extension _NativeProtocol._ResponseHeaderLines {
    func createURLResponse(for URL: URL, contentLength: Int64) -> URLResponse? {
        return URLResponse(url: URL, mimeType: nil, expectedContentLength: Int(contentLength), textEncodingName: nil)
    }
}

internal extension _NativeProtocol {
    typealias _Body = URLSessionTask._Body
}

extension _NativeProtocol {
    /// Set request body length.
    ///
    /// An unknown length
    func set(requestBodyLength length: _HTTPURLProtocol._RequestBodyLength) {
        switch length {
        case .noBody:
            easyHandle.set(upload: false)
            easyHandle.set(requestBodyLength: 0)
        case .length(let length):
            easyHandle.set(upload: true)
            easyHandle.set(requestBodyLength: Int64(length))
        case .unknown:
            easyHandle.set(upload: true)
            easyHandle.set(requestBodyLength: -1)
        }
    }

    enum _RequestBodyLength {
        case noBody
        ///
        case length(UInt64)
        /// Will result in a chunked upload
        case unknown
    }
}

extension URLSession {
    static func printDebug(_ text: @autoclosure () -> String) {
        guard enableDebugOutput else { return }
        debugPrint(text())
    }
}
