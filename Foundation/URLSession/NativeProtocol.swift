// Foundation/NSURLSession/_NativeProtocol.swift - NSURLSession & libcurl
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

import CoreFoundation
import Dispatch

internal let enableLibcurlDebugOutput: Bool = {
    return  (ProcessInfo.processInfo.environment["URLSessionDebugLibcurl"] != nil)
}()
internal let enableDebugOutput: Bool = {
    return (ProcessInfo.processInfo.environment["URLSessionDebug"] != nil)
}()

class _NativeProtocol: URLProtocol, _EasyHandleDelegate {
    internal var easyHandle: _EasyHandle!
    internal var totalDownloaded = 0
    internal lazy var tempFileURL: URL = {
        let fileName = NSTemporaryDirectory() + NSUUID().uuidString + ".tmp"
        _ = FileManager.default.createFile(atPath: fileName, contents: nil)
        return URL(fileURLWithPath: fileName)
    }()

    public required init(task: URLSessionTask, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        self.internalState = _InternalState.initial
        super.init(request: task.originalRequest!, cachedResponse: cachedResponse, client: client)
        self.task = task
        self.easyHandle = _EasyHandle(delegate: self)
    }

    public required init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        self.internalState = _InternalState.initial
        super.init(request: request, cachedResponse: cachedResponse, client: client)
        self.easyHandle = _EasyHandle(delegate: self)
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
        guard case .transferInProgress(var ts) = internalState else { fatalError("Received body data, but no transfer in progress.") }
        if let response = validateHeaderComplete(transferSate:ts) {
            ts.response = response
        }
        notifyDelegate(aboutReceivedData: data)
        internalState = .transferInProgress(ts.byAppending(bodyData: data))
        return .proceed
    }

    func validateHeaderComplete(transferSate: _TransferState) -> URLResponse? {
        guard transferSate.isHeaderComplete else { fatalError("Received body data, but the header is not complete, yet.") }
        return nil
    }

    fileprivate func notifyDelegate(aboutReceivedData data: Data) {
        guard let t = self.task else { fatalError("Cannot notify") }
        if case .taskDelegate(let delegate) = t.session.behaviour(for: self.task!),
            let dataDelegate = delegate as? URLSessionDataDelegate,
            let task = self.task as? URLSessionDataTask {
            // Forward to the delegate:
            guard let s = self.task?.session as? URLSession else { fatalError() }
            s.delegateQueue.addOperation {
                dataDelegate.urlSession(s, dataTask: task, didReceive: data)
            }
        } else if case .taskDelegate(let delegate) = t.session.behaviour(for: self.task!),
            let downloadDelegate = delegate as? URLSessionDownloadDelegate,
            let task = self.task as? URLSessionDownloadTask {
            guard let s = self.task?.session as? URLSession else { fatalError() }
            let fileHandle = try! FileHandle(forWritingTo: self.tempFileURL)
            _ = fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            task.countOfBytesReceived  += Int64(data.count)
 
            s.delegateQueue.addOperation {
                downloadDelegate.urlSession(s, downloadTask: task, didWriteData: Int64(data.count), totalBytesWritten: task.countOfBytesReceived,
                                            totalBytesExpectedToWrite: task.countOfBytesExpectedToReceive)
            }
            if task.countOfBytesExpectedToReceive == task.countOfBytesReceived {
                fileHandle.closeFile()
                self.properties[.temporaryFileURL] = self.tempFileURL
            }
        }
    }

    fileprivate func notifyDelegate(aboutUploadedData count: Int64) {
        guard let task = self.task as? URLSessionUploadTask,
            let session = self.task?.session as? URLSession,
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
        guard case .transferInProgress(let ts) = internalState else { fatalError("Requested to fill write buffer, but transfer isn't in progress.") }
        guard let source = ts.requestBodySource else { fatalError("Requested to fill write buffer, but transfer state has no body source.") }
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

    func transferCompleted(withErrorCode errorCode: Int?) {
        // At this point the transfer is complete and we can decide what to do.
        // If everything went well, we will simply forward the resulting data
        // to the delegate. But in case of redirects etc. we might send another
        // request.
        guard case .transferInProgress(let ts) = internalState else { fatalError("Transfer completed, but it wasn't in progress.") }
        guard let request = task?.currentRequest else { fatalError("Transfer completed, but there's no current request.") }
        guard errorCode == nil else {
            internalState = .transferFailed
            failWith(errorCode: errorCode!, request: request)
            return
        }

        if let response = task?.response {
            var transferState = ts
            transferState.response = response
        }

        guard let response = ts.response else { fatalError("Transfer completed, but there's no response.") }
        internalState = .transferCompleted(response: response, bodyDataDrain: ts.bodyDataDrain)
        let action = completionAction(forCompletedRequest: request, response: response)

        switch action {
        case .completeTask:
            completeTask()
        case .failWithError(let errorCode):
            internalState = .transferFailed
            failWith(errorCode: errorCode, request: request)
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
        //We don't want a timeout to be triggered after this. The timeout timer needs to be cancelled.
        easyHandle.timeoutTimer = nil
        //because we deregister the task with the session on internalState being set to taskCompleted
        //we need to do the latter after the delegate/handler was notified/invoked
        if case .inMemory(let bodyData) = bodyDataDrain {
            var data = Data()
            if let body = bodyData {
                data = Data(bytes: body.bytes, count: body.length)
            }
            self.client?.urlProtocol(self, didLoad: data)
            self.internalState = .taskCompleted
        }

        if case .toFile(let url, let fileHandle?) = bodyDataDrain {
            self.properties[.temporaryFileURL] = url
            fileHandle.closeFile()
        }
        self.client?.urlProtocolDidFinishLoading(self)
        self.internalState = .taskCompleted
    }

    func completionAction(forCompletedRequest request: URLRequest, response: URLResponse) -> _CompletionAction {
        return .completeTask
    }

    func seekInputStream(to position: UInt64) throws {
         NSUnimplemented()
    }

    func updateProgressMeter(with propgress: _EasyHandle._Progress) {
    }

    fileprivate func createTransferBodyDataDrain() -> _DataDrain {
        guard let task = task else { fatalError() }
        let s = task.session as! URLSession
        switch s.behaviour(for: task) {
        case .noDelegate:
            return .ignore
        case .taskDelegate:
            // Data will be forwarded to the delegate as we receive it, we don't
            // need to do anything about it.
            return .ignore
        case .dataCompletionHandler:
            // Data needs to be concatenated in-memory such that we can pass it
            // to the completion handler upon completion.
            return .inMemory(nil)
        case .downloadCompletionHandler:
            // Data needs to be written to a file (i.e. a download task).
            let fileHandle = try! FileHandle(forWritingTo: self.tempFileURL)
            return .toFile(self.tempFileURL, fileHandle)
        }
    }

    func createTransferState(url: URL, workQueue: DispatchQueue) -> _TransferState {
        let drain = createTransferBodyDataDrain()
        guard let t = task else { fatalError("Cannot create transfer state") }
        switch t.body {
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
        case .stream:
            NSUnimplemented()
        }
    }

    /// Start a new transfer
    func startNewTransfer(with request: URLRequest) {
        guard let t = task else { fatalError() }
        t.currentRequest = request
        guard let url = request.url else { fatalError("No URL in request.") }

        self.internalState = .transferReady(createTransferState(url: url, workQueue: t.workQueue))
        configureEasyHandle(for: request)
        if (t.suspendCount) < 1 {
            resume()
        }
    }

    func resume() {
        if case .initial = self.internalState {
            guard let r = task?.originalRequest else { fatalError("Task has no original request.") }
            startNewTransfer(with: r)
        }

        if case .transferReady(let transferState) = self.internalState {
            self.internalState = .transferInProgress(transferState)
        }
    }

    func suspend() {
        if case .transferInProgress(let transferState) =  self.internalState {
            self.internalState = .transferReady(transferState)
        }
    }

    func configureEasyHandle(for: URLRequest) {
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
    
    func failWith(errorCode: Int, request: URLRequest) {
        //TODO: Error handling
        let userInfo: [String : Any]? = request.url.map {
            [
                NSURLErrorFailingURLErrorKey: $0,
                NSURLErrorFailingURLStringErrorKey: $0.absoluteString,
                ]
        }
        let error = URLError(_nsError: NSError(domain: NSURLErrorDomain, code: errorCode, userInfo: userInfo))
        completeTask(withError: error)
        self.client?.urlProtocol(self, didFailWithError: error)
    }

    /// Give the delegate a chance to tell us how to proceed once we have a
    /// response / complete header.
    ///
    /// This will pause the transfer.
    func askDelegateHowToProceedAfterCompleteResponse(_ response: URLResponse, delegate: URLSessionDataDelegate) {
        // Ask the delegate how to proceed.
        
        // This will pause the easy handle. We need to wait for the
        // delegate before processing any more data.
        guard case .transferInProgress(let ts) = self.internalState else { fatalError("Transfer not in progress.") }
        self.internalState = .waitingForResponseCompletionHandler(ts)
        
        let dt = task as! URLSessionDataTask
        
        // We need this ugly cast in order to be able to support `URLSessionTask.init()`
        guard let s = task?.session as? URLSession else { fatalError() }
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
        guard case .waitingForResponseCompletionHandler(let ts) = self.internalState else { fatalError("Received response disposition, but we're not waiting for it.") }
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
            NSUnimplemented()
        }
    }
}

extension _NativeProtocol {
    /// State related to an ongoing transfer.
    ///
    /// This contains headers received so far, body data received so far, etc.
    ///
    /// There's a strict 1-to-1 relationship between an `EasyHandle` and a
    /// `TransferState`.
    ///
    /// - TODO: Might move the `EasyHandle` into this `struct` ?
    /// - SeeAlso: `URLSessionTask.EasyHandle`
    internal struct _TransferState {
        /// The URL that's being requested
        let url: URL
        /// Raw headers received.
        let parsedResponseHeader: _ParsedResponseHeader
        /// Once the headers is complete, this will contain the response
        var response: URLResponse?
        /// The body data to be sent in the request
        let requestBodySource: _BodySource?
        /// Body data received
        let bodyDataDrain: _NativeProtocol._DataDrain
        /// Describes what to do with received body data for this transfer:
    }
}

extension _NativeProtocol {
    
    enum _InternalState {
        /// Task has been created, but nothing has been done, yet
        case initial
        /// The easy handle has been fully configured. But it is not added to
        /// the multi handle.
        case transferReady(_TransferState)
        /// The easy handle is currently added to the multi handle
        case transferInProgress(_TransferState)
        /// The transfer completed.
        ///
        /// The easy handle has been removed from the multi handle. This does
        /// not (necessarily mean the task completed. A task that gets
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
    
    enum _DataDrain {
        /// Concatenate in-memory
        case inMemory(NSMutableData?)
        /// Write to file
        case toFile(URL, FileHandle?)
        /// Do nothing. Might be forwarded to delegate
        case ignore
    }
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

extension _NativeProtocol._TransferState {
    /// Transfer state that can receive body data, but will not send body data.
    init(url: URL, bodyDataDrain: _NativeProtocol._DataDrain) {
        self.url = url
        self.bodyDataDrain = bodyDataDrain
        self.response = nil
        self.parsedResponseHeader = _NativeProtocol._ParsedResponseHeader()
        self.requestBodySource = nil
    }
    
    /// Transfer state that sends body data and can receive body data.
    init(url: URL, bodyDataDrain: _NativeProtocol._DataDrain, bodySource: _BodySource) {
        self.url = url
        self.parsedResponseHeader = _NativeProtocol._ParsedResponseHeader()
        self.response = nil
        self.requestBodySource = bodySource
        self.bodyDataDrain = bodyDataDrain
    }
    
}

struct _Delimiters {
    /// *Carriage Return* symbol
    static let CR: UInt8 = 0x0d
    /// *Line Feed* symbol
    static let LF: UInt8 = 0x0a
    /// *Space* symbol
    static let Space = UnicodeScalar(0x20)
    static let HorizontalTab = UnicodeScalar(0x09)
    static let Colon = UnicodeScalar(0x3a)
    /// *Separators* according to RFC 2616
    static let Separators = NSCharacterSet(charactersIn: "()<>@,;:\\\"/[]?={} \t")
}

extension _NativeProtocol {
    /// An HTTP header being parsed.
    ///
    /// It can either be complete (i.e. the final CR LF CR LF has been
    /// received), or partial.
    internal enum _ParsedResponseHeader {
        case partial(_ResponseHeaderLines)
        case complete(_ResponseHeaderLines)
        init() {
            self = .partial(_ResponseHeaderLines())
        }
    }
    /// A type safe wrapper around multiple lines of headers.
    ///
    /// This can be converted into an `NSHTTPURLResponse`.
    internal struct _ResponseHeaderLines {
        let lines: [String]
        init() {
            self.lines = []
        }
        init(headerLines: [String]) {
            self.lines = headerLines
        }
    }
    
}

extension _NativeProtocol._ResponseHeaderLines {
    
    func createURLResponse(for URL: URL, contentLength: Int64) -> URLResponse? {
        return URLResponse(url: URL, mimeType: nil, expectedContentLength: Int(contentLength),textEncodingName: nil)
    }
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

extension _NativeProtocol._ParsedResponseHeader {
    
    /// Parse a header line passed by libcurl.
    ///
    /// These contain the <CRLF> ending and the final line contains nothing but
    /// that ending.
    /// - Returns: Returning nil indicates failure. Otherwise returns a new
    ///     `ParsedResponseHeader` with the given line added.
    func byAppending(headerLine data: Data, headerCompleted: (String) -> Bool) -> _NativeProtocol._ParsedResponseHeader? {
        // The buffer must end in CRLF
        guard
            2 <= data.count &&
                data[data.endIndex - 2] == _Delimiters.CR &&
                data[data.endIndex - 1] == _Delimiters.LF
            else { return nil }
        let lineBuffer = data.subdata(in: Range(data.startIndex..<data.endIndex-2))
        guard let line = String(data: lineBuffer, encoding: String.Encoding.utf8) else { return nil}
        return byAppending(headerLine: line, headerCompleted: headerCompleted)
    }
    
    private func byAppending(headerLine line: String, headerCompleted: (String) -> Bool) -> _NativeProtocol._ParsedResponseHeader {
        if headerCompleted(line) {
            switch self {
            case .partial(let header): return .complete(header)
            case .complete: return .partial(_NativeProtocol._ResponseHeaderLines())
            }
        } else {
            let header = partialResponseHeader
            return .partial(header.byAppending(headerLine: line))
        }
    }
    
    private var partialResponseHeader: _NativeProtocol._ResponseHeaderLines {
        switch self {
        case .partial(let header): return header
        case .complete: return _NativeProtocol._ResponseHeaderLines()
        }
    }
}

extension _NativeProtocol._ResponseHeaderLines {
    /// Returns a copy of the lines with the new line appended to it.
    func byAppending(headerLine line: String) -> _NativeProtocol._ResponseHeaderLines {
        var l = self.lines
        l.append(line)
        return _NativeProtocol._ResponseHeaderLines(headerLines: l)
    }
}

extension _NativeProtocol._TransferState {
    var isHeaderComplete: Bool {
        return response != nil
    }
    func byAppending(bodyData buffer: Data) -> _NativeProtocol._TransferState {
        switch bodyDataDrain {
        case .inMemory(let bodyData):
            let data: NSMutableData = bodyData ?? NSMutableData()
            data.append(buffer)
            let drain = _NativeProtocol._DataDrain.inMemory(data)
            return _NativeProtocol._TransferState(url: url, parsedResponseHeader: parsedResponseHeader, response: response, requestBodySource: requestBodySource, bodyDataDrain: drain)
        case .toFile(_, let fileHandle):
            //TODO: Create / open the file for writing
            // Append to the file
            _ = fileHandle!.seekToEndOfFile()
            fileHandle!.write(buffer)
            return self
        case .ignore:
            return self
        }
    }
    /// Sets the given body source on the transfer state.
    ///
    /// This can be used to either set the initial body source, or to reset it
    /// e.g. when restarting a transfer.
    func bySetting(bodySource newSource: _BodySource) -> _NativeProtocol._TransferState {
        return _NativeProtocol._TransferState(url: url, parsedResponseHeader: parsedResponseHeader, response: response, requestBodySource: newSource, bodyDataDrain: bodyDataDrain)
    }
}

extension _FTPURLProtocol._TransferState {
   
    enum FTPHeaderCode: String {
        case transferCompleted = "226"
        case openDataConnection = "150"
        case fileStatus = "213"
        case syntaxError = "5" // 500 series FTP Syntax errors
        case errorOccurred = "4" // 400 Series FTP transfer errors
    }
 
    /// Appends a header line
    ///
    /// Will set the complete response once the header is complete, i.e. the
    /// return value's `isHeaderComplete` will then by `true`.
    ///
    /// - Throws: When a parsing error occurs
    func byAppendingFTP(headerLine data: Data, expectedContentLength: Int64) throws -> _NativeProtocol._TransferState {
        let line = String(data: data, encoding: String.Encoding.utf8)
        if (line?.starts(with: FTPHeaderCode.transferCompleted.rawValue))! {
            return self
        }
        
        func  isCompleteHeader(_ headerLine: String) ->Bool {
            return  headerLine.starts(with: FTPHeaderCode.openDataConnection.rawValue)
        }
        guard let h = parsedResponseHeader.byAppending(headerLine: data,headerCompleted: isCompleteHeader) else {
            throw _NativeProtocol._Error.parseSingleLineError
        }

        if case .complete(let lines) = h {
            let response = lines.createURLResponse(for: url, contentLength: expectedContentLength)
            guard response != nil else {
                throw _NativeProtocol._Error.parseCompleteHeaderError
            }
            return _NativeProtocol._TransferState(url: url, parsedResponseHeader: _NativeProtocol._ParsedResponseHeader(), response: response, requestBodySource: requestBodySource, bodyDataDrain: bodyDataDrain)
        } else {
            return _NativeProtocol._TransferState(url: url, parsedResponseHeader: _NativeProtocol._ParsedResponseHeader(), response: nil, requestBodySource: requestBodySource, bodyDataDrain: bodyDataDrain)
        }
    }
}

extension _HTTPURLProtocol._TransferState {
    /// Appends a header line
    ///
    /// Will set the complete response once the header is complete, i.e. the
    /// return value's `isHeaderComplete` will then by `true`.
    ///
    /// - Throws: When a parsing error occurs
    func byAppendingHTTP(headerLine data: Data) throws -> _NativeProtocol._TransferState {
        func  isCompleteHeader(_ headerLine: String) -> Bool {
            return  headerLine.isEmpty
        }
        guard let h = parsedResponseHeader.byAppending(headerLine: data, headerCompleted: isCompleteHeader) else {
            throw _NativeProtocol._Error.parseSingleLineError
        }
        if case .complete(let lines) = h {
            // Header is complete
            let response = lines.createHTTPURLResponse(for: url)
            guard response != nil else {
                throw _NativeProtocol._Error.parseCompleteHeaderError
            }
            return _NativeProtocol._TransferState(url: url, parsedResponseHeader: _NativeProtocol._ParsedResponseHeader(), response: response, requestBodySource: requestBodySource, bodyDataDrain: bodyDataDrain)
        } else {
            return _NativeProtocol._TransferState(url: url, parsedResponseHeader: h, response: nil, requestBodySource: requestBodySource, bodyDataDrain: bodyDataDrain)
        }
    }
}


