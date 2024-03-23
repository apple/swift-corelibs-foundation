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

@_implementationOnly import CoreFoundation
@_implementationOnly import CFURLSessionInterface
import Dispatch

internal class _HTTPURLProtocol: _NativeProtocol {

    // When processing redirects, the intermediate 3xx response bodies are normally discarded.
    // If the call to urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)
    // results in the completion handler being called with a nil URLRequest, then processing stops
    // and the 3xx response is returned to the client and the data is sent via the delegate notify
    // mechanism. `lastRedirectBody` holds the body of the redirect currently being processed.
    var lastRedirectBody: Data? = nil
    private var redirectCount = 0

    public required init(task: URLSessionTask, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(task: task, cachedResponse: cachedResponse, client: client)
    }

    public required init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard request.url?.scheme == "http" || request.url?.scheme == "https" else { return false }
        return true
    }

    override func didReceive(headerData data: Data, contentLength: Int64) -> _EasyHandle._Action {
        guard case .transferInProgress(let ts) = internalState else {
            fatalError("Received header data, but no transfer in progress.")
        }
        guard let task = task else {
            fatalError("Received header data but no task available.")
        }
        do {
            let newTS = try ts.byAppendingHTTP(headerLine: data)
            internalState = .transferInProgress(newTS)
            let didCompleteHeader = !ts.isHeaderComplete && newTS.isHeaderComplete
            if didCompleteHeader {
                // The header is now complete, but wasn't before.
                let response = newTS.response as! HTTPURLResponse
                if let contentEncoding = response.allHeaderFields["Content-Encoding"] as? String,
                        contentEncoding != "identity" {
                    // compressed responses do not report expected size
                    task.countOfBytesExpectedToReceive = NSURLSessionTransferSizeUnknown
                } else {
                    task.countOfBytesExpectedToReceive = contentLength > 0 ? contentLength : NSURLSessionTransferSizeUnknown
                }
                didReceiveResponse()
            }
            return .proceed
        } catch {
            return .abort
        }
    }
    
    // This implements a RFC 7234 <https://tools.ietf.org/html/rfc7231> cache with the following:
    // - this is a private cache;
    // - we conform to the specification for the Vary header by not caching responses that have a Vary header.
    // - we do not implement a concept of staleness; we are unwilling to serve stale requests from the cache, and we are aggressively going to prune any storage that is used by stored stale data.
    
    struct CacheControlDirectives {
        var maxAge: UInt?
        var sharedMaxAge: UInt?
        var noCache: Bool = false
        var noStore: Bool = false
        
        init(headerValue: String) {
            func isWithArgument<T>(_ part: String, named: String, converter: (String) -> T?) -> T? {
                if part.hasPrefix("\(named)=") {
                    let split = part.components(separatedBy: "=")
                    if split.count == 2 {
                        let argument = split[1]
                        if argument.first == "\"" && argument.last == "\"" {
                            if argument.count >= 2 {
                                return converter(String(argument[argument.index(after: argument.startIndex) ..< argument.index(before: argument.endIndex)]))
                            } else {
                                return nil
                            }
                        } else {
                            return converter(argument)
                        }
                    }
                }
                
                return nil
            }
            
            let parts = headerValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased(with: NSLocale.system) }
            
            for part in parts {
                if part == "no-cache" {
                    noCache = true
                } else if part == "no-store" {
                    noStore = true
                } else if let maxAge = isWithArgument(part, named: "max-age", converter: { UInt($0) }) {
                    self.maxAge = maxAge
                } else if let sharedMaxAge = isWithArgument(part, named: "s-maxage", converter: { UInt($0) }) {
                    self.sharedMaxAge = sharedMaxAge
                }
            }
        }
    }
    
    override func canCache(_ response: CachedURLResponse) -> Bool {
        guard let httpRequest = task?.currentRequest else { return false }
        guard let httpResponse = response.response as? HTTPURLResponse else { return false }
        
        let now = Date()
        
        // Figure out the date we should start counting expiration from.
        let expirationStart: Date
        
        if let dateString = httpResponse.allHeaderFields["Date"] as? String,
           let date = _HTTPURLProtocol.dateFormatter.date(from: dateString) {
            expirationStart = min(date, response.date) // Do not accept a date in the future of the point where we stored it, or of now if we haven't stored it yet. That is: a Date header can only make a response expire _faster_ than if it was issued now, and can't be used to prolong its age.
        } else {
            expirationStart = response.date
        }
        
        // We opt not to cache any requests or responses that contain authorization headers.
        if httpResponse.allHeaderFields["WWW-Authenticate"] != nil ||
           httpResponse.allHeaderFields["Proxy-Authenticate"] != nil ||
           httpRequest.allHTTPHeaderFields?["Authorization"] != nil ||
           httpRequest.allHTTPHeaderFields?["Proxy-Authorization"] != nil {
            return false
        }
        
        // HTTP Methods: https://tools.ietf.org/html/rfc7231#section-4.2.3
        switch httpRequest.httpMethod {
        case "GET":
            break
        case "HEAD":
            if response.data.isEmpty {
                break
            } else {
                return false
            }
        default:
            return false
        }
        
        // Cache-Control: https://tools.ietf.org/html/rfc7234#section-5.2
        var hasCacheControl = false
        var hasMaxAge = false
        if let cacheControl = httpResponse.allHeaderFields["Cache-Control"] as? String {
            let directives = CacheControlDirectives(headerValue: cacheControl)
            
            if directives.noCache || directives.noStore {
                return false
            }
            
            // We should not cache a response that has already expired. (This is also the expiration check for canRespondFromCaching(using:) below.)
            if let maxAge = directives.maxAge {
                hasMaxAge = true
                
                let expiration = expirationStart + TimeInterval(maxAge)
                if now >= expiration {
                    // Do not cache an expired response.
                    return false
                }
            }
            
            // This is not a shared cache, but per <https://tools.ietf.org/html/rfc7234#section-5.3>,
            // if a response has Cache-Control: s-maxage="…" set, we MUST ignore the Expires field below.
            if directives.sharedMaxAge != nil {
                hasMaxAge = true
            }
            
            hasCacheControl = true
        }
        
        // Pragma: https://tools.ietf.org/html/rfc7234#section-5.4
        if !hasCacheControl, let pragma = httpResponse.allHeaderFields["Cache-Control"] as? String {
            let parts = pragma.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased(with: NSLocale.system) }
            if parts.contains("no-cache") {
                return false
            }
        }
        
        // HTTP status codes: https://tools.ietf.org/html/rfc7231#section-6.1
        switch httpResponse.statusCode {
        case 200: fallthrough
        case 203: fallthrough
        case 204: fallthrough
        case 206: fallthrough
        case 300: fallthrough
        case 301: fallthrough
        case 404: fallthrough
        case 405: fallthrough
        case 410: fallthrough
        case 414: fallthrough
        case 501:
            break
            
        default:
            return false
        }
        
        // Vary: https://tools.ietf.org/html/rfc7231#section-7.1.4
        /*   "1.  To inform cache recipients that they MUST NOT use this response
         to satisfy a later request unless the later request has the same
         values for the listed fields as the original request (Section 4.1
         of [RFC7234]).  In other words, Vary expands the cache key
         required to match a new request to the stored cache entry."
         
         If we do not store this response, we will never use it to satisfy a later request, including a later request for which it would be incorrect.
         */
        if httpResponse.allHeaderFields["Vary"] != nil {
            return false
        }
        
        // Expires: <https://tools.ietf.org/html/rfc7234#section-5.3>
        // We should not cache a response that has already expired. (This is also the expiration check for canRespondFromCaching(using:) below.)
        // We MUST ignore this if we have Cache-Control: max-age or s-maxage.
        if !hasMaxAge, let expires = httpResponse.allHeaderFields["Expires"] as? String {
            guard let expiration = _HTTPURLProtocol.dateFormatter.date(from: expires) else {
                // From the spec:
                /* "A cache recipient MUST interpret invalid date formats, especially the
                 value "0", as representing a time in the past (i.e., 'already
                 expired')."
                 */
                return false
            }
            
            if now >= expiration {
                // Do not cache an expired response.
                return false
            }
        }
        
        return true
    }
    
    static let dateFormatter: DateFormatter = {
        let x = DateFormatter()
        x.locale = NSLocale.system
        x.dateFormat = "EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"
        return x
    }()
    
    override func canRespondFromCache(using response: CachedURLResponse) -> Bool {
        // If somehow cached a response that shouldn't have been, we should remove it.
        guard canCache(response) else {
            // Calling super removes it from the cache and returns false, which is the default.
            return super.canRespondFromCache(using: response)
        }
        
        // Expiration checks are done in canCache(…).
        return true
    }

    /// Set options on the easy handle to match the given request.
    ///
    /// This performs a series of `curl_easy_setopt()` calls.
    override func configureEasyHandle(for request: URLRequest, body: _Body) {
        // At this point we will call the equivalent of curl_easy_setopt()
        // to configure everything on the handle. Since we might be re-using
        // a handle, we must be sure to set everything and not rely on default
        // values.

        //TODO: We could add a strong reference from the easy handle back to
        // its URLSessionTask by means of CURLOPT_PRIVATE -- that would ensure
        // that the task is always around while the handle is running.
        // We would have to break that retain cycle once the handle completes
        // its transfer.


        if request.httpMethod == "GET" {
            // GET requests cannot have a body
            guard case .none = body else {
                NSLog("GET method must not have a body")
                let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorDataLengthExceedsMaximum,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "resource exceeds maximum size",
                                        NSURLErrorFailingURLStringErrorKey: request.url?.description ?? ""
                ])
                internalState = .transferFailed
                transferCompleted(withError: error)
                return
            }
        }

        // Behavior Options
        easyHandle.set(verboseModeOn: enableLibcurlDebugOutput)
        easyHandle.set(debugOutputOn: enableLibcurlDebugOutput, task: task!)
        easyHandle.set(passHeadersToDataStream: false)
        easyHandle.set(progressMeterOff: true)
        easyHandle.set(skipAllSignalHandling: true)

        // Error Options:
        easyHandle.set(errorBuffer: nil)
        easyHandle.set(failOnHTTPErrorCode: false)

        // Network Options:
        guard let url = request.url else {
            fatalError("No URL in request.")
        }
        guard url.host != nil else {
            self.internalState = .transferFailed
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL,
                                userInfo: [NSLocalizedDescriptionKey: "HTTP URL must have a host"])
            failWith(error: error, request: request)
            return
        }
        do {
            try easyHandle.set(url: url)
        } catch {
            self.internalState = .transferFailed
            let nsError = error as? NSError ?? NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
            failWith(error: nsError, request: request)
            return
        }
        let session = task?.session as! URLSession
        let _config = session._configuration
        easyHandle.set(sessionConfig: _config)
        easyHandle.setAllowedProtocolsToHTTPAndHTTPS()
        easyHandle.set(preferredReceiveBufferSize: Int.max)
        do {
            switch (body, try body.getBodyLength()) {
            case (.none, _):
                if request.httpMethod == "GET" {
                    set(requestBodyLength: .noBody)
                } else {
                    set(requestBodyLength: .length(0))
                }
            case (_, let length?):
                set(requestBodyLength: .length(length))
                task!.countOfBytesExpectedToSend = Int64(length)
            case (_, nil):
                set(requestBodyLength: .unknown)
            }
        } catch let e {
            // Fail the request here.
            // TODO: We have multiple options:
            //     NSURLErrorNoPermissionsToReadFile
            //     NSURLErrorFileDoesNotExist
            self.internalState = .transferFailed
            let error = NSError(domain: NSURLErrorDomain, code: errorCode(fileSystemError: e),
                                userInfo: [NSLocalizedDescriptionKey: "File system error"])
            failWith(error: error, request: request)
            return
        }
 
        // HTTP Options:
        easyHandle.set(followLocation: false)

        // The httpAdditionalHeaders from session configuration has to be added to the request.
        // The request.allHTTPHeaders can override the httpAdditionalHeaders elements. Add the
        // httpAdditionalHeaders from session configuration first and then append/update the
        // request.allHTTPHeaders so that request.allHTTPHeaders can override httpAdditionalHeaders.

        let httpSession = self.task?.session as! URLSession
        var httpHeaders: [AnyHashable : Any]?

        if let hh = httpSession.configuration.httpAdditionalHeaders {
            httpHeaders = hh
        }

        if let hh = request.allHTTPHeaderFields {
            if httpHeaders == nil {
                httpHeaders = hh
            } else {
                hh.forEach {
                    // When adding a header, remove any current entry with the same header name regardless of case
                    let newKey = $0.lowercased()
                    for key in httpHeaders!.keys {
                        if newKey == (key as! String).lowercased() {
                            httpHeaders?.removeValue(forKey: key)
                            break
                        }
                    }
                    httpHeaders![$0] = $1
                }
            }
        }
        let customHeaders: [String]
        let headersForRequest = curlHeaders(for: httpHeaders)
        var hasStream = (request.httpBodyStream != nil)
        if case _Body.stream(_) = body {
            hasStream = true
        }
        if (request.httpMethod == "POST") && (request.value(forHTTPHeaderField: "Content-Type") == nil)
            && ((request.httpBody?.count ?? 0 > 0) || hasStream) {
            customHeaders = headersForRequest + ["Content-Type:application/x-www-form-urlencoded"]
        } else {
            customHeaders = headersForRequest
        }

        easyHandle.set(customHeaders: customHeaders)

        //TODO: The CURLOPT_PIPEDWAIT option is unavailable on Ubuntu 14.04 (libcurl 7.36)
        //TODO: Introduce something like an #if, if we want to set them here

        //set the request timeout
        //TODO: the timeout value needs to be reset on every data transfer

        var timeoutInterval = Int(httpSession.configuration.timeoutIntervalForRequest) * 1000
        if request.isTimeoutIntervalSet {
            timeoutInterval = Int(request.timeoutInterval) * 1000
        }
        let timeoutHandler = DispatchWorkItem { [weak self] in
            guard let self = self, let task = self.task else {
                fatalError("Timeout on a task that doesn't exist")
            } //this guard must always pass

            // If a timeout occurred while waiting for a redirect completion handler to be called by
            // the delegate then terminate the task but DONT set the error to NSURLErrorTimedOut.
            // This matches Darwin.
            if case .waitingForRedirectCompletionHandler(response: let response,_) = self.internalState {
                task.response = response
                self.easyHandle.timeoutTimer = nil
                self.internalState = .taskCompleted
            } else {
                self.internalState = .transferFailed
                let urlError = URLError(_nsError: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil))
                self.completeTask(withError: urlError)
                self.client?.urlProtocol(self, didFailWithError: urlError)
            }
        }

        guard let task = self.task else { fatalError() }
        easyHandle.timeoutTimer = _TimeoutSource(queue: task.workQueue, milliseconds: timeoutInterval, handler: timeoutHandler)
        easyHandle.set(automaticBodyDecompression: true)
        easyHandle.set(requestMethod: request.httpMethod ?? "GET")
        // Always set the status as it may change if a HEAD is converted to a GET.
        easyHandle.set(noBody: request.httpMethod == "HEAD")
    }

    /// What action to take
    override func completionAction(forCompletedRequest request: URLRequest, response: URLResponse) -> _CompletionAction {
        // Redirect:
        guard let httpURLResponse = response as? HTTPURLResponse else {
            fatalError("Response was not HTTPURLResponse")
        }
        if let request = redirectRequest(for: httpURLResponse, fromRequest: request) {
            return .redirectWithRequest(request)
        }
        return .completeTask
    }

    override func redirectFor(request: URLRequest) {
        guard case .transferCompleted(response: let response, bodyDataDrain: let bodyDataDrain) = self.internalState else {
            fatalError("Trying to redirect, but the transfer is not complete.")
        }

        // Avoid a never ending redirect chain by having a hard limit on the number of redirects.
        // This value mirrors Darwin.
        redirectCount += 1
        if redirectCount > 20 {
            self.internalState = .transferFailed
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorHTTPTooManyRedirects,
                                userInfo: [NSLocalizedDescriptionKey: "too many HTTP redirects"])
            guard let request = task?.currentRequest else {
                fatalError("In a redirect chain but no current task/request")
            }
            failWith(error: error, request: request)
            return
        }

        guard let session = task?.session as? URLSession else { fatalError() }

        if let delegate = session.delegate as? URLSessionTaskDelegate {
            // At this point we need to change the internal state to note
            // that we're waiting for the delegate to call the completion
            // handler. Then we'll call the delegate callback
            // (willPerformHTTPRedirection). The task will then switch out of
            // its internal state once the delegate calls the completion
            // handler.

            //TODO: Should the `public response: URLResponse` property be updated
            // before we call delegate API
            self.internalState = .waitingForRedirectCompletionHandler(response: response, bodyDataDrain: bodyDataDrain)
            // We need this ugly cast in order to be able to support `URLSessionTask.init()`
            session.delegateQueue.addOperation {
                delegate.urlSession(session, task: self.task!, willPerformHTTPRedirection: response as! HTTPURLResponse, newRequest: request) { [weak self] (request: URLRequest?) in
                    guard let self = self else { return }
                    self.task?.workQueue.async {
                        self.didCompleteRedirectCallback(request)
                    }
                }
            }
        } else {
            // Follow the redirect. Need to configure new request with cookies, etc.
            let configuredRequest = session._configuration.configure(request: request)
            task?.knownBody = URLSessionTask._Body.none
            startNewTransfer(with: configuredRequest)
        }
    }

    override func validateHeaderComplete(transferState: _NativeProtocol._TransferState) -> URLResponse? {
        if !transferState.isHeaderComplete {
            return HTTPURLResponse(url: transferState.url, statusCode: 200, httpVersion: "HTTP/0.9", headerFields: [:])
            /* we received body data before CURL tells us that the headers are complete, that happens for HTTP/0.9 simple responses, see
             - https://www.w3.org/Protocols/HTTP/1.0/spec.html#Message-Types
             - https://github.com/curl/curl/issues/467
             */
        }
        return nil
    }
    
    /// Whenever we receive a response (i.e. a complete header) from libcurl,
    /// this method gets called.
    func didReceiveResponse() {
        guard let _ = task as? URLSessionDataTask else { return }
        guard case .transferInProgress(let ts) = self.internalState else { fatalError("Transfer not in progress.") }
        guard let response = ts.response as? HTTPURLResponse else { fatalError("Header complete, but not URL response.") }
        guard let session = task?.session as? URLSession else { fatalError() }
        switch session.behaviour(for: self.task!) {
        case .noDelegate:
            break
        case .taskDelegate:
            //TODO: There's a problem with libcurl / with how we're using it.
            // We're currently unable to pause the transfer / the easy handle:
            // https://curl.haxx.se/mail/lib-2016-03/0222.html
            //
            // For now, we'll notify the delegate, but won't pause the transfer,
            // and we'll disregard the completion handler:
            switch response.statusCode {
            case 301, 302, 303, 305...308:
                break
            default:
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
        case .dataCompletionHandler:
            break
        case .dataCompletionHandlerWithTaskDelegate:
            break
        case .downloadCompletionHandler:
            break
        }
    }

    /// If the response is a redirect, return the new request
    ///
    /// RFC 7231 section 6.4 defines redirection behavior for HTTP/1.1
    ///
    /// - SeeAlso: <https://tools.ietf.org/html/rfc7231#section-6.4>
    func redirectRequest(for response: HTTPURLResponse, fromRequest: URLRequest) -> URLRequest? {
        //TODO: Do we ever want to redirect for HEAD requests?
        
        guard
            let location = response.value(forHeaderField: .location),
            let targetURL = URL(string: location)
            else {
                // Can't redirect when there's no location to redirect to.
                return nil
        }
        
        var request = fromRequest
        
        // Check for a redirect:
        switch response.statusCode {
            case 301...302 where request.httpMethod == "POST", 303:
                // Change "POST" into "GET" but leave other methods unchanged:
                request.httpMethod = "GET"
                request.httpBody = nil

            case 301...302, 305...308:
                // Re-use existing method:
                break

            default:
                return nil
        }

        // If targetURL has only relative path of url, create a new valid url with relative path
        // Otherwise, return request with targetURL ie.url from location field
        guard targetURL.scheme == nil || targetURL.host == nil else {
            request.url = targetURL
            return request
        }

        guard
            let fromUrl = fromRequest.url,
            var components = URLComponents(url: fromUrl, resolvingAgainstBaseURL: false)
            else { return nil }

        // If the new URL contains a host, use the host and port from the new URL.
        // Otherwise, the host and port from the original URL are used.
        if targetURL.host != nil {
            components.host = targetURL.host
            components.port = targetURL.port
        }
        
        // The path must either begin with "/" or be an empty string.
        if targetURL.path.hasPrefix("/") {
            components.path = targetURL.path
        } else {
            components.path = "/" + targetURL.path
        }
        
        // The query and fragment components are set separately to prevent them from being
        // percent encoded again.
        components.percentEncodedQuery = targetURL.query
        components.percentEncodedFragment = targetURL.fragment

        guard let url = components.url else { fatalError("Invalid URL") }
        request.url = url

        return request
    }

    /// These are a list of headers that should be passed to libcurl.
    ///
    /// Headers will be returned as `Accept: text/html` strings for
    /// setting fields, `Accept:` for disabling the libcurl default header, or
    /// `Accept;` for a header with no content. This is the format that libcurl
    /// expects.
    ///
    /// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_HTTPHEADER.html
    func curlHeaders(for httpHeaders: [AnyHashable : Any]?) -> [String] {
        var result: [String] = []
        var names = Set<String>()
	if let hh = httpHeaders as? [String : String] {
            hh.forEach {
                let name = $0.0.lowercased()
                guard !names.contains(name) else { return }
                names.insert(name)

                if $0.1.isEmpty {
                    result.append($0.0 + ";")
                } else {
                    result.append($0.0 + ": " + $0.1)
                }
            }
        }
        curlHeadersToSet.forEach {
            let name = $0.0.lowercased()
            guard !names.contains(name) else { return }
            names.insert(name)
            
            if $0.1.isEmpty {
                result.append($0.0 + ";")
            } else {
                result.append($0.0 + ": " + $0.1)
            }
        }
        curlHeadersToRemove.forEach {
            let name = $0.lowercased()
            guard !names.contains(name) else { return }
            names.insert(name)
            result.append($0 + ":")
        }
        return result
    }
    /// Any header values that should be passed to libcurl
    ///
    /// These will only be set if not already part of the request.
    /// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_HTTPHEADER.html
    var curlHeadersToSet: [(String,String)] {
        var result = [("Connection", "keep-alive"),
                      ("User-Agent", userAgentString),
                      ]
        if let language = NSLocale.current.languageCode {
            result.append(("Accept-Language", language))
        }
        return result
    }
    /// Any header values that should be removed from the ones set by libcurl
    /// - SeeAlso: https://curl.haxx.se/libcurl/c/CURLOPT_HTTPHEADER.html
    var curlHeadersToRemove: [String] {
        if let task = task {
            if task.knownBody == nil {
                return []
            } else if case .some(.none) = task.knownBody {
                return []
            }
        }
        
        return ["Expect"]
    }
}

fileprivate var userAgentString: String = {
    // Darwin uses something like this: "xctest (unknown version) CFNetwork/760.4.2 Darwin/15.4.0 (x86_64)"
    let info = ProcessInfo.processInfo
    let name = info.processName
    let curlVersion = CFURLSessionCurlVersionInfo()
    //TODO: Should probably use sysctl(3) to get these:
    // kern.ostype: Darwin
    // kern.osrelease: 15.4.0
    //TODO: Use Bundle to get the version number?
    return "\(name) (unknown version) curl/\(curlVersion.major).\(curlVersion.minor).\(curlVersion.patch)"
}()

/// State Transfers
extension _HTTPURLProtocol {
    fileprivate func didCompleteRedirectCallback(_ request: URLRequest?) {
        guard case .waitingForRedirectCompletionHandler(response: let response, bodyDataDrain: let bodyDataDrain) = self.internalState else {
            fatalError("Received callback for HTTP redirection, but we're not waiting for it. Was it called multiple times?")
        }
        // If the request is `nil`, we're supposed to treat the current response
        // as the final response, i.e. not do any redirection.
        // Otherwise, we'll start a new transfer with the passed in request.
        if let r = request {
            lastRedirectBody = nil
            task?.knownBody = URLSessionTask._Body.none
            startNewTransfer(with: r)
        } else {
            // If the redirect is not followed, return the redirect itself as the response
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let redirectBody = lastRedirectBody {
                self.client?.urlProtocol(self, didLoad: redirectBody)
            }
            self.internalState = .transferCompleted(response: response, bodyDataDrain: bodyDataDrain)
            completeTask()
        }
    }
}

fileprivate extension HTTPURLResponse {
    /// Type safe HTTP header field name(s)
    enum _Field: String {
        /// `Location`
        /// - SeeAlso: RFC 2616 section 14.30 <https://tools.ietf.org/html/rfc2616#section-14.30>
        case location = "Location"
    }

    func value(forHeaderField field: _Field) -> String? {
        let value = field.rawValue
        if let location = self.allHeaderFields[value] as? String {
            return location
        }
        return nil
    }
}
