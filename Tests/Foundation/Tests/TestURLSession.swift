// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
    #if canImport(SwiftFoundationNetworking) && !DEPLOYMENT_RUNTIME_OBJC
        @testable import SwiftFoundationNetworking
    #else
        @testable import FoundationNetworking
    #endif
#endif

class TestURLSession: LoopbackServerTest {

    let httpMethods = ["HEAD", "GET", "PUT", "POST", "DELETE"]

    func test_dataTaskWithURL() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Nepal"
        let url = URL(string: urlString)!
        let d = DataTask(with: expectation(description: "GET \(urlString): with a delegate"))
        d.run(with: url)
        waitForExpectations(timeout: 12)
        if !d.error {
            XCTAssertEqual(d.capital, "Kathmandu", "test_dataTaskWithURLRequest returned an unexpected result")
        }
    }

    func test_dataTaskWithURLCompletionHandler() {
        //shared session
        dataTaskWithURLCompletionHandler(with: URLSession.shared)

        //new session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        dataTaskWithURLCompletionHandler(with: session)
    }

    func dataTaskWithURLCompletionHandler(with session: URLSession) {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/USA"
        let url = URL(string: urlString)!
        let expect = expectation(description: "GET \(urlString): with a completion handler")
        var expectedResult = "unknown"
        let task = session.dataTask(with: url) { data, response, error in
            defer { expect.fulfill() }
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            guard let httpResponse = response as? HTTPURLResponse, let data = data else { return }
            XCTAssertEqual(200, httpResponse.statusCode, "HTTP response code is not 200")
            expectedResult = String(data: data, encoding: .utf8) ?? ""
            XCTAssertEqual("Washington, D.C.", expectedResult, "Did not receive expected value")
        }
        task.resume()
        waitForExpectations(timeout: 12)
    }
    
    func test_dataTaskWithURLRequest() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Peru"
        let urlRequest = URLRequest(url: URL(string: urlString)!)
        let d = DataTask(with: expectation(description: "GET \(urlString): with a delegate"))
        d.run(with: urlRequest)
        waitForExpectations(timeout: 12)
        if !d.error {
            XCTAssertEqual(d.capital, "Lima", "test_dataTaskWithURLRequest returned an unexpected result")
        }
    }
    
    func test_dataTaskWithURLRequestCompletionHandler() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Italy"
        let urlRequest = URLRequest(url: URL(string: urlString)!)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "GET \(urlString): with a completion handler")
        var expectedResult = "unknown"
        let task = session.dataTask(with: urlRequest) { data, response, error in
            defer { expect.fulfill() }
            XCTAssertNotNil(data)
            XCTAssertNotNil(response)
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            guard let httpResponse = response as? HTTPURLResponse, let data = data else { return }
            XCTAssertEqual(200, httpResponse.statusCode, "HTTP response code is not 200")
            expectedResult = String(data: data, encoding: .utf8) ?? ""
            XCTAssertEqual("Rome", expectedResult, "Did not receive expected value")
        }
        task.resume()
        waitForExpectations(timeout: 12)
    }
    
    func test_dataTaskWithHttpInputStream() throws {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/jsonBody"
        let url = try XCTUnwrap(URL(string: urlString))

        let dataString = """
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras congue laoreet facilisis. Sed porta tristique orci. Fusce ut nisl dignissim, tempor tortor id, molestie neque. Nam non tincidunt mi. Integer ac diam quis leo aliquam congue et non magna. In porta mauris suscipit erat pulvinar, sed fringilla quam ornare. Nulla vulputate et ligula vitae sollicitudin. Nulla vel vehicula risus. Quisque eu urna ullamcorper, tincidunt ante vitae, aliquet sem. Suspendisse nec turpis placerat, porttitor ex vel, tristique orci. Maecenas pretium, augue non elementum imperdiet, diam ex vestibulum tortor, non ultrices ante enim iaculis ex.

            Suspendisse ante eros, scelerisque ut molestie vitae, lacinia nec metus. Sed in feugiat sem. Nullam sed congue nulla, id vehicula mauris. Aliquam ultrices ultricies pellentesque. Etiam blandit ultrices quam in egestas. Donec a vulputate est, ut ultricies dui. In non maximus velit.

            Vivamus vehicula faucibus odio vel maximus. Vivamus elementum, quam at accumsan rhoncus, ex ligula maximus sem, sed pretium urna enim ut urna. Donec semper porta augue at faucibus. Quisque vel congue purus. Morbi vitae elit pellentesque, finibus lectus quis, laoreet nulla. Praesent in fermentum felis. Aenean vestibulum dictum lorem quis egestas. Sed dictum elementum est laoreet volutpat.
        """
        let data = try XCTUnwrap(dataString.data(using: .utf8))

        // For all HTTP methods, send data as an input stream with both a Content-Type header and without to check that the
        // header is added correctly for only POST messages with a body.
        // GET will also fail to send a body.
        for method in httpMethods {
            for contentType in ["text/plain; charset=utf-8", nil] {   // nil Content-Type lets URLSession set it
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = method
                urlRequest.httpBodyStream = InputStream(data: data)
                urlRequest.setValue("en-us", forHTTPHeaderField: "Accept-Language")
                urlRequest.setValue("chunked", forHTTPHeaderField: "Transfer-Encoding")
                if let ct = contentType  {
                    urlRequest.setValue(ct, forHTTPHeaderField: "Content-Type")
                }

                let delegate = SessionDelegate(with: expectation(description: "\(method) \(urlString): with HTTP Body as InputStream"))
                delegate.run(with: urlRequest, timeoutInterval: 3)
                waitForExpectations(timeout: 4)

                let httpResponse = delegate.response as? HTTPURLResponse
                let contentLength = Int(httpResponse?.value(forHTTPHeaderField: "Content-Length") ?? "")
                // Only POST sets a default Content-Type if it is nil
                let postedContentType = contentType ?? ((method == "POST") ? "application/x-www-form-urlencoded" : nil)

                let callBacks: [String]
                switch method {
                    case "HEAD":
                        XCTAssertNil(delegate.error)
                        XCTAssertNotNil(delegate.response)
                        XCTAssertEqual(httpResponse?.statusCode, 200)
                        XCTAssertNil(delegate.receivedData)
                        callBacks = ["urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)",
                                     "urlSession(_:dataTask:didReceive:completionHandler:)",
                                     "urlSession(_:task:didCompleteWithError:)"]

                    case "GET":
                        // GET requests must not have a body, which causes an error
                        XCTAssertNotNil(delegate.error)
                        let error = delegate.error as? URLError
                        XCTAssertEqual(error?.code.rawValue, NSURLErrorDataLengthExceedsMaximum)
                        XCTAssertEqual(error?.localizedDescription, "resource exceeds maximum size")
                        let userInfo = error?.userInfo
                        XCTAssertNotNil(userInfo)
                        let errorURL = userInfo?[NSURLErrorFailingURLErrorKey] as? URL
                        XCTAssertEqual(errorURL, url)

                        XCTAssertNil(delegate.response)
                        XCTAssertNil(delegate.receivedData)
                        callBacks = ["urlSession(_:task:didCompleteWithError:)"]

                    default:
                        XCTAssertNil(delegate.error)
                        XCTAssertNotNil(delegate.response)
                        XCTAssertEqual(httpResponse?.statusCode, 200)

                        XCTAssertNotNil(delegate.receivedData)
                        XCTAssertEqual(delegate.receivedData?.count, contentLength)
                        if let receivedData = delegate.receivedData, let jsonBody = try? JSONSerialization.jsonObject(with: receivedData, options: []) as? [String: String] {
                            XCTAssertEqual(jsonBody["Content-Type"], postedContentType)
                            if let postedBody = jsonBody["x-base64-body"], let decodedBody = Data(base64Encoded: postedBody) {
                                XCTAssertEqual(decodedBody, data)
                            } else {
                                XCTFail("Could not decode Base64 body for \(method)")
                            }
                        } else {
                            XCTFail("No JSON body for \(method)")
                        }
                        callBacks = ["urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)",
                                     "urlSession(_:dataTask:didReceive:completionHandler:)",
                                     "urlSession(_:dataTask:didReceive:)",
                                     "urlSession(_:task:didCompleteWithError:)"]
                }
                XCTAssertEqual(delegate.callbacks.count, callBacks.count)
                XCTAssertEqual(delegate.callbacks, callBacks)
            }
        }
    }
    
    func test_dataTaskWithHTTPBodyRedirect() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/303?location=Peru"
        let url = URL(string: urlString)!
        let parameters = "foo=bar"
        var postRequest = URLRequest(url: url)
        postRequest.httpBody = parameters.data(using: .utf8)
        postRequest.httpMethod = "POST"
        
        let d = HTTPRedirectionDataTask(with: expectation(description: "POST \(urlString): with HTTP redirection"))
        d.run(with: postRequest)

        waitForExpectations(timeout: 12)
        
        XCTAssertEqual("Lima", String(data: d.receivedData, encoding: .utf8), "\(#function) did not redirect properly.")
    }

    func test_gzippedDataTask() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/gzipped-response"
        let url = URL(string: urlString)!
        let d = DataTask(with: expectation(description: "GET \(urlString): gzipped response"))
        d.run(with: url)
        waitForExpectations(timeout: 12)
        if !d.error {
            XCTAssertEqual(d.capital, "Hello World!")
        }
    }

    func test_downloadTaskWithURL() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/country.txt"
        let url = URL(string: urlString)!
        let d = DownloadTask(testCase: self, description: "Download GET \(urlString): with a delegate")
        d.run(with: url)
        waitForExpectations(timeout: 12)
    }
    
    func test_downloadTaskWithURLRequest() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/country.txt"
        let urlRequest = URLRequest(url: URL(string: urlString)!)
        let d = DownloadTask(testCase: self, description: "Download GET \(urlString): with a delegate")
        d.run(with: urlRequest)
        waitForExpectations(timeout: 12)
    }
    
    func test_downloadTaskWithRequestAndHandler() {
        //shared session
        downloadTaskWithRequestAndHandler(with: URLSession.shared)

        //newly created session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        downloadTaskWithRequestAndHandler(with: session)
    }

    func downloadTaskWithRequestAndHandler(with session: URLSession) {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/country.txt"
        let expect = expectation(description: "Download GET \(urlString): with a completion handler")
        let req = URLRequest(url: URL(string: urlString)!)
        let task = session.downloadTask(with: req) { (_, _, error) -> Void in
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            expect.fulfill()
        }
        task.resume()
        waitForExpectations(timeout: 12)
    }
    
    func test_downloadTaskWithURLAndHandler() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/country.txt"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "Download GET \(urlString): with a completion handler")
        let req = URLRequest(url: URL(string: urlString)!)
        let task = session.downloadTask(with: req) { (_, _, error) -> Void in
            if let e = error as? URLError {
                XCTAssertEqual(e.code, .timedOut, "Unexpected error code")
            }
            expect.fulfill()
        }
        task.resume()
        waitForExpectations(timeout: 12)
    }

    func test_gzippedDownloadTask() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/gzipped-response"
        let url = URL(string: urlString)!
        let d = DownloadTask(testCase: self, description: "GET \(urlString): gzipped response")
        d.run(with: url)
        waitForExpectations(timeout: 12)
        if d.totalBytesWritten != "Hello World!".utf8.count {
            XCTFail("Expected the gzipped-response to be the length of Hello World!")
        }
    }

    func test_finishTasksAndInvalidate() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Nepal"
        let invalidateExpectation = expectation(description: "Session invalidation")
        let delegate = SessionDelegate(invalidateExpectation: invalidateExpectation)
        let url = URL(string: urlString)!
        let session = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: delegate, delegateQueue: nil)
        let completionExpectation = expectation(description: "GET \(urlString): task completion before session invalidation")
        let task = session.dataTask(with: url) { (_, _, _) in
            completionExpectation.fulfill()
        }
        task.resume()
        session.finishTasksAndInvalidate()
        waitForExpectations(timeout: 12)
    }
    
    func test_taskError() {
        let urlString = "http://127.0.0.1:-1/Nepal"
        let url = URL(string: urlString)!
        let session = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: nil,
                                 delegateQueue: nil)
        let completionExpectation = expectation(description: "GET \(urlString): Bad URL error")
        let task = session.dataTask(with: url) { (_, _, result) in
            let error = result as? URLError
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.code, .badURL)
            completionExpectation.fulfill()
        }
        //should result in Bad URL error
        task.resume()
        
        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error)
            
            XCTAssertNotNil(task.error)
            XCTAssertEqual((task.error as? URLError)?.code, .badURL)
        }
    }
    
    func test_taskCopy() {
        let url = URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/Nepal")!
        let session = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: nil,
                                 delegateQueue: nil)
        let task = session.dataTask(with: url)
        
        XCTAssert(task.isEqual(task.copy()))
    }

    // This test is buggy because the server could respond before the task is cancelled.
    func test_cancelTask() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Peru"
        var urlRequest = URLRequest(url: URL(string: urlString)!)
        urlRequest.setValue("2.0", forHTTPHeaderField: "X-Pause")
        let d = DataTask(with: expectation(description: "GET \(urlString): task cancelation"))
        d.cancelExpectation = expectation(description: "GET \(urlString): task canceled")
        d.run(with: urlRequest)
        d.cancel()
        waitForExpectations(timeout: 12)
    }

    func test_unhandledURLProtocol() {
        let urlString = "foobar://127.0.0.1:\(TestURLSession.serverPort)/Nepal"
        let url = URL(string: urlString)!
        let session = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: nil,
                                 delegateQueue: nil)
        let completionExpectation = expectation(description: "GET \(urlString): Unsupported URL error")
        let task = session.dataTask(with: url) { (data, response, _error) in
            XCTAssertNil(data)
            XCTAssertNil(response)
            let error = _error as? URLError
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.code, .unsupportedURL)
            completionExpectation.fulfill()
        }
        task.resume()

        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error)
            XCTAssertEqual((task.error as? URLError)?.code, .unsupportedURL)
        }
    }

    func test_requestToNilURL() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Nepal"
        let url = URL(string: urlString)!
        let session = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: nil,
                                 delegateQueue: nil)
        let completionExpectation = expectation(description: "DataTask with nil URL: Unsupported URL error")
        var request = URLRequest(url: url)
        request.url = nil
        let task = session.dataTask(with: request) { (data, response, _error) in
            XCTAssertNil(data)
            XCTAssertNil(response)
            let error = _error as? URLError
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.code, .unsupportedURL)
            completionExpectation.fulfill()
        }
        task.resume()

        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error)
            XCTAssertEqual((task.error as? URLError)?.code, .unsupportedURL)
        }
    }

    func test_suspendResumeTask() throws {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/get"
        let url = try XCTUnwrap(URL(string: urlString))

        let expect = expectation(description: "GET \(urlString)")
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
             guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("response (\(response.debugDescription)) invalid")
                return
            }
            if httpResponse.statusCode == 200 {
                expect.fulfill()
            }
        }

        // The task starts suspended (1) so this requires 1 extra resume to perform the task
        task.suspend()                          // 2
        XCTAssertEqual(task.state, .suspended)
        task.suspend()                          // 3
        XCTAssertEqual(task.state, .suspended)

        task.resume()                           // 2
        XCTAssertEqual(task.state, .suspended)  // Darwin reports this as .running even though the task hasnt actually resumed
        task.resume()                           // 1
        XCTAssertEqual(task.state, .suspended)  // Darwin reports this as .running even though the task hasnt actually resumed

        task.resume()                           // 0 - Task can run
        XCTAssertEqual(task.state, .running)

        task.resume()                           // -1
        XCTAssertEqual(task.state, .running)
        task.resume()                           // -2
        XCTAssertEqual(task.state, .running)

        waitForExpectations(timeout: 3)
    }

    
    func test_verifyRequestHeaders() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/requestHeaders"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "POST \(urlString): get request headers")
        var req = URLRequest(url: URL(string: urlString)!)
        let headers = ["header1": "value1"]
        req.httpMethod = "POST"
        req.allHTTPHeaderFields = headers
        let task = session.dataTask(with: req) { (data, _, error) -> Void in
            defer { expect.fulfill() }
            XCTAssertNotNil(data)
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            guard let data = data else { return }
            let headers = String(data: data, encoding: .utf8) ?? ""
            XCTAssertNotNil(headers.range(of: "header1: value1"))
        }
        task.resume()
        req.allHTTPHeaderFields = nil
        waitForExpectations(timeout: 30)
    }
    
    // Verify httpAdditionalHeaders from session configuration are added to the request
    // and whether it is overriden by Request.allHTTPHeaderFields.
    
    func test_verifyHttpAdditionalHeaders() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.httpAdditionalHeaders = ["header2": "svalue2", "header3": "svalue3", "header4": "svalue4"]
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/requestHeaders"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "POST \(urlString) with additional headers")
        var req = URLRequest(url: URL(string: urlString)!)
        let headers = ["header1": "rvalue1", "header2": "rvalue2", "Header4": "rvalue4"]
        req.httpMethod = "POST"
        req.allHTTPHeaderFields = headers
        let task = session.dataTask(with: req) { (data, _, error) -> Void in
            defer { expect.fulfill() }
            XCTAssertNotNil(data)
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            guard let data = data else { return }
            let headers = String(data: data, encoding: .utf8) ?? ""
            XCTAssertNotNil(headers.range(of: "header1: rvalue1"))
            XCTAssertNotNil(headers.range(of: "header2: rvalue2"))
            XCTAssertNotNil(headers.range(of: "header3: svalue3"))
            XCTAssertNotNil(headers.range(of: "Header4: rvalue4"))
            XCTAssertNil(headers.range(of: "header4: svalue"))
        }
        task.resume()
        
        waitForExpectations(timeout: 30)
    }
    
    func test_taskTimeout() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Peru"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "GET \(urlString): no timeout")
        let req = URLRequest(url: URL(string: urlString)!)
        let task = session.dataTask(with: req) { (data, _, error) -> Void in
            defer { expect.fulfill() }
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
        }
        task.resume()
        
        waitForExpectations(timeout: 30)
    }
    
    func test_httpTimeout() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Peru"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "GET \(urlString): will timeout")
        var req = URLRequest(url: URL(string: urlString)!)
        req.setValue("3", forHTTPHeaderField: "x-pause")
        req.timeoutInterval = 1
        let task = session.dataTask(with: req) { (data, _, error) -> Void in
            defer { expect.fulfill() }
            XCTAssertEqual((error as? URLError)?.code, .timedOut, "Task should fail with URLError.timedOut error")
        }
        task.resume()
        waitForExpectations(timeout: 30)
    }

    func test_connectTimeout() {
        // Reconfigure http server for this specific scenario:
        // a slow request keeps web server busy, while other
        // request times out on connection attempt.
        Self.stopServer()
        Self.options = Options(serverBacklog: 1, isAsynchronous: false)
        Self.startServer()
        
        let config = URLSessionConfiguration.default
        let slowUrlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Peru"
        let fastUrlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Italy"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let slowReqExpect = expectation(description: "GET \(slowUrlString): will complete")
        let fastReqExpect = expectation(description: "GET \(fastUrlString): will timeout")
        
        var slowReq = URLRequest(url: URL(string: slowUrlString)!)
        slowReq.setValue("3", forHTTPHeaderField: "x-pause")
        
        var fastReq = URLRequest(url: URL(string: fastUrlString)!)
        fastReq.timeoutInterval = 1
        
        let slowTask = session.dataTask(with: slowReq) { (data, _, error) -> Void in
            slowReqExpect.fulfill()
        }
        let fastTask = session.dataTask(with: fastReq) { (data, _, error) -> Void in
            defer { fastReqExpect.fulfill() }
            XCTAssertEqual((error as? URLError)?.code, .timedOut, "Task should fail with URLError.timedOut error")
        }
        slowTask.resume()
        Thread.sleep(forTimeInterval: 0.1) // Give slow task some time to start
        fastTask.resume()
        
        waitForExpectations(timeout: 30)

        // Reconfigure http server back to default settings
        Self.stopServer()
        Self.options = .default
        Self.startServer()
    }
    
    func test_repeatedRequestsStress() throws {
        // TODO: try disabling curl connection cache to force socket close early. Or create several url sessions (they have cleanup in deinit)
        
        let config = URLSessionConfiguration.default
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Peru"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let req = URLRequest(url: URL(string: urlString)!)
        
        var requestsLeft = 3000
        let expect = expectation(description: "\(requestsLeft) x GET \(urlString)")
        
        func doRequests(completion: @escaping () -> Void) {
            // We only care about completion of one of the tasks,
            // so we could move to next cycle.
            // Some overlapping would happen and that's what we
            // want actually to provoke issue with socket reuse
            // on Windows.
            let task = session.dataTask(with: req) { (_, _, _) -> Void in
            }
            task.resume()
            let task2 = session.dataTask(with: req) { (_, _, _) -> Void in
            }
            task2.resume()
            let task3 = session.dataTask(with: req) { (_, _, _) -> Void in
                completion()
            }
            task3.resume()
        }

        func checkCountAndRunNext() {
            guard requestsLeft > 0 else {
                expect.fulfill()
                return
            }
            requestsLeft -= 1
            doRequests(completion: checkCountAndRunNext)
        }
        
        checkCountAndRunNext()

        waitForExpectations(timeout: 30)
    }

    func test_httpRedirectionWithCode300() throws {
        let statusCode = 300
        for method in httpMethods {
            let testMethod = "\(method) request with statusCode \(statusCode)"
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/\(statusCode)?location=jsonBody"
            let url = try XCTUnwrap(URL(string: urlString), "Cant create URL for \(testMethod)")
            var request = URLRequest(url: url)
            request.httpMethod = method
            let d = HTTPRedirectionDataTask(with: expectation(description: "\(method) \(urlString): with HTTP redirection"))
            d.run(with: request)

            waitForExpectations(timeout: 12)
            XCTAssertNil(d.error)

            XCTAssertNil(d.redirectionResponse)
            XCTAssertNotNil(d.response)
            let httpresponse = d.response as? HTTPURLResponse
            XCTAssertEqual(httpresponse?.statusCode, statusCode, "HTTP final response code is invalid for \(testMethod)")

            let callbackMsg = "Bad callback for \(testMethod)"
            switch method {
                case "HEAD":
                    XCTAssertEqual(d.callbackCount, 2, "Callback count for \(testMethod)")
                    XCTAssertEqual(d.callback(0), "urlSession(_:dataTask:didReceive:completionHandler:)", callbackMsg)
                    XCTAssertEqual(d.callback(1), "urlSession(_:task:didCompleteWithError:)", callbackMsg)
                    XCTAssertEqual(d.receivedData.count, 0) // No body for HEAD requests

                default:
                    XCTAssertEqual(d.callbackCount, 3, "Callback count for \(testMethod)")
                    XCTAssertEqual(d.callback(0), "urlSession(_:dataTask:didReceive:completionHandler:)", callbackMsg)
                    XCTAssertEqual(d.callback(1), "urlSession(_:dataTask:didReceive:)", callbackMsg)
                    XCTAssertEqual(d.callback(2), "urlSession(_:task:didCompleteWithError:)", callbackMsg)

                    if let body = String(data: d.receivedData, encoding: .utf8) {
                        XCTAssertEqual(body, "Redirecting to \(method) jsonBody", "URI mismatch for \(testMethod)")
                    } else {
                        XCTFail("No JSON body for \(testMethod)")
                    }
            }
        }
    }

    func test_httpRedirectionWithCode301_302() throws {
        for statusCode in 301...302 {
            for method in httpMethods {
                let testMethod = "\(method) request with statusCode \(statusCode)"
                let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/\(statusCode)?location=jsonBody"
                let url = try XCTUnwrap(URL(string: urlString), "Cant create URL for \(testMethod)")
                var request = URLRequest(url: url)
                request.httpMethod = method
                let d = HTTPRedirectionDataTask(with: expectation(description: "\(method) \(urlString): with HTTP redirection"))
                d.run(with: request)

                waitForExpectations(timeout: 12)
                XCTAssertNil(d.error)

                XCTAssertNotNil(d.response)
                let httpresponse = d.response as? HTTPURLResponse
                XCTAssertEqual(httpresponse?.statusCode, 200, "HTTP final response code is invalid for \(testMethod)")
                XCTAssertEqual(d.redirectionResponse?.statusCode, statusCode, "HTTP redirection response code is invalid for \(testMethod)")

                let callbackMsg = "Bad callback for \(testMethod)"
                switch method {
                    case "HEAD":
                        XCTAssertEqual(d.callbackCount, 3, "Callback count for \(testMethod)")
                        XCTAssertEqual(d.callback(0), "urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)", callbackMsg)
                        XCTAssertEqual(d.callback(1), "urlSession(_:dataTask:didReceive:completionHandler:)", callbackMsg)
                        XCTAssertEqual(d.callback(2), "urlSession(_:task:didCompleteWithError:)", callbackMsg)
                        XCTAssertEqual(d.receivedData.count, 0) // No body for HEAD requests


                    default:
                        XCTAssertEqual(d.callbackCount, 4, "Callback count for \(testMethod)")
                        XCTAssertEqual(d.callback(0), "urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)", callbackMsg)
                        XCTAssertEqual(d.callback(1), "urlSession(_:dataTask:didReceive:completionHandler:)", callbackMsg)
                        XCTAssertEqual(d.callback(2), "urlSession(_:dataTask:didReceive:)", callbackMsg)
                        XCTAssertEqual(d.callback(3), "urlSession(_:task:didCompleteWithError:)", callbackMsg)

                        if let jsonBody = try? JSONSerialization.jsonObject(with: d.receivedData, options: []) as? [String: String] {
                            let uri = (method == "POST" ? "GET" : method) + " /jsonBody HTTP/1.1"
                            XCTAssertEqual(jsonBody["uri"], uri, "URI mismatch for \(testMethod)")
                        } else {
                            XCTFail("No JSON body for \(testMethod)")
                    }
                }
            }
        }
    }

    func test_httpRedirectionWithCode303() throws {
        let statusCode = 303
        for method in httpMethods {
            let testMethod = "\(method) request with statusCode \(statusCode)"
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/\(statusCode)?location=jsonBody"
            let url = try XCTUnwrap(URL(string: urlString), "Cant create URL for \(testMethod)")
            var request = URLRequest(url: url)
            request.httpMethod = method
            let d = HTTPRedirectionDataTask(with: expectation(description: "\(method) \(urlString): with HTTP redirection"))
            d.run(with: request)

            waitForExpectations(timeout: 12)
            XCTAssertNil(d.error)

            XCTAssertNotNil(d.response)
            let httpresponse = d.response as? HTTPURLResponse
            XCTAssertEqual(httpresponse?.statusCode, 200, "HTTP final response code is invalid for \(testMethod)")
            XCTAssertEqual(d.redirectionResponse?.statusCode, statusCode, "HTTP redirection response code is invalid for \(testMethod)")

            let callbackMsg = "Bad callback for \(testMethod)"
            XCTAssertEqual(d.callbackCount, 4, "Callback count for \(testMethod)")
            XCTAssertEqual(d.callback(0), "urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)", callbackMsg)
            XCTAssertEqual(d.callback(1), "urlSession(_:dataTask:didReceive:completionHandler:)", callbackMsg)
            XCTAssertEqual(d.callback(2), "urlSession(_:dataTask:didReceive:)", callbackMsg)
            XCTAssertEqual(d.callback(3), "urlSession(_:task:didCompleteWithError:)", callbackMsg)
            if let jsonBody = try? JSONSerialization.jsonObject(with: d.receivedData, options: []) as? [String: String] {
                let uri = "GET /jsonBody HTTP/1.1"
                XCTAssertEqual(jsonBody["uri"], uri, "URI mismatch for \(testMethod)")
            } else {
                XCTFail("No jsonBody for \(testMethod)")
            }
        }
    }

    func test_httpRedirectionWithCode304() throws {
        let statusCode = 304
        for method in httpMethods {
            let testMethod = "\(method) request with statusCode \(statusCode)"
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/\(statusCode)?location=jsonBody"
            let url = try XCTUnwrap(URL(string: urlString), "Cant create URL for \(testMethod)")
            var request = URLRequest(url: url)
            request.httpMethod = method
            let d = HTTPRedirectionDataTask(with: expectation(description: "\(method) \(urlString): with HTTP redirection"))
            d.run(with: request)

            waitForExpectations(timeout: 12)
            XCTAssertNil(d.error)

            XCTAssertNotNil(d.response)
            let httpresponse = d.response as? HTTPURLResponse
            XCTAssertEqual(httpresponse?.statusCode, statusCode, "HTTP final response code is invalid for \(testMethod)")
            XCTAssertNil(d.redirectionResponse)

            let callbackMsg = "Bad callback for \(testMethod)"
            XCTAssertEqual(d.callbackCount, 2, "Callback count for \(testMethod)")
            XCTAssertEqual(d.callback(0), "urlSession(_:dataTask:didReceive:completionHandler:)", callbackMsg)
            XCTAssertEqual(d.callback(1), "urlSession(_:task:didCompleteWithError:)", callbackMsg)

            XCTAssertEqual(d.receivedData.count, 0)
            let jsonBody = try? JSONSerialization.jsonObject(with: d.receivedData, options: []) as? [String: String]
            XCTAssertNil(jsonBody)
        }
    }

    func test_httpRedirectionWithCode305_308() throws {
        for statusCode in 305...308 {
            for method in httpMethods {
                let testMethod = "\(method) request with statusCode \(statusCode)"
                let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/\(statusCode)?location=jsonBody"
                let url = try XCTUnwrap(URL(string: urlString), "Cant create URL for \(testMethod)")
                var request = URLRequest(url: url)
                request.httpMethod = method
                let d = HTTPRedirectionDataTask(with: expectation(description: "\(method) \(urlString): with HTTP redirection"))
                d.run(with: request)

                waitForExpectations(timeout: 12)
                XCTAssertNil(d.error)

                XCTAssertNotNil(d.response)
                let httpresponse = d.response as? HTTPURLResponse
                XCTAssertEqual(httpresponse?.statusCode, 200, "HTTP final response code is invalid for \(testMethod)")
                XCTAssertEqual(d.redirectionResponse?.statusCode, statusCode, "HTTP redirection response code is invalid for \(testMethod)")

                let callbackMsg = "Bad callback for \(testMethod)"
                switch method {
                    case "HEAD":
                        XCTAssertEqual(d.callbackCount, 3, "Callback count for \(testMethod)")
                        XCTAssertEqual(d.callback(0), "urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)", callbackMsg)
                        XCTAssertEqual(d.callback(1), "urlSession(_:dataTask:didReceive:completionHandler:)", callbackMsg)
                        XCTAssertEqual(d.callback(2), "urlSession(_:task:didCompleteWithError:)", callbackMsg)
                        XCTAssertEqual(d.receivedData.count, 0) // No body for HEAD requests

                    default:
                        XCTAssertEqual(d.callbackCount, 4, "Callback count for \(testMethod)")
                        XCTAssertEqual(d.callback(0), "urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)", callbackMsg)
                        XCTAssertEqual(d.callback(1), "urlSession(_:dataTask:didReceive:completionHandler:)", callbackMsg)
                        XCTAssertEqual(d.callback(2), "urlSession(_:dataTask:didReceive:)", callbackMsg)
                        XCTAssertEqual(d.callback(3), "urlSession(_:task:didCompleteWithError:)", callbackMsg)
                        if let jsonBody = try? JSONSerialization.jsonObject(with: d.receivedData, options: []) as? [String: String] {
                            let uri = "\(method) /jsonBody HTTP/1.1"
                            XCTAssertEqual(jsonBody["uri"], uri, "URI mismatch for \(testMethod)")
                        } else {
                            XCTFail("No JSON body for \(testMethod)")
                    }
                }
            }
        }
    }

    func test_httpRedirectDontFollowUsingNil() throws {
        let statusCode = 302
        for method in httpMethods {
            let testMethod = "\(method) request with statusCode \(statusCode)"
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/\(statusCode)?location=jsonBody"
            let url = try XCTUnwrap(URL(string: urlString), "Cant create URL for \(testMethod)")
            var request = URLRequest(url: url)
            request.httpMethod = method
            let delegate = SessionDelegate(with: expectation(description: "\(method) \(urlString): with HTTP redirection"))
            delegate.redirectionHandler = { (response: HTTPURLResponse, request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) in
                // Dont follow the request by calling the completion handler with nil
                completionHandler(nil)
            }
            delegate.run(with: request, timeoutInterval: 2)

            waitForExpectations(timeout: 3)
            XCTAssertNil(delegate.error)

            XCTAssertNotNil(delegate.response)
            let httpResponse = delegate.response as? HTTPURLResponse
            XCTAssertEqual(httpResponse?.statusCode, 302, "HTTP final response code is invalid for \(testMethod)")
            XCTAssertEqual(delegate.redirectionResponse?.statusCode, statusCode, "HTTP redirection response code is invalid for \(testMethod)")

            let callbackMsg = "Bad callback for \(testMethod)"
            switch method {
                case "HEAD":
                    let callbacks = [
                        "urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)",
                        "urlSession(_:dataTask:didReceive:completionHandler:)",
                        "urlSession(_:task:didCompleteWithError:)"
                    ]
                    XCTAssertEqual(delegate.callbacks.count, 3, "Callback count for \(testMethod)")
                    XCTAssertEqual(delegate.callbacks, callbacks, callbackMsg)
                    XCTAssertNil(delegate.receivedData) // No body for HEAD requests

                default:
                    let callbacks = [
                        "urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)",
                        "urlSession(_:dataTask:didReceive:completionHandler:)",
                        "urlSession(_:dataTask:didReceive:)",
                        "urlSession(_:task:didCompleteWithError:)",
                    ]
                    XCTAssertEqual(delegate.callbacks.count, 4, "Callback count for \(testMethod)")
                    XCTAssertEqual(delegate.callbacks, callbacks, callbackMsg)

                    let contentLength = Int(httpResponse?.value(forHTTPHeaderField: "Content-Length") ?? "")
                    let body = "Redirecting to \(method) jsonBody"
                    XCTAssertEqual(contentLength, body.count)
                    XCTAssertEqual(delegate.receivedData?.count, body.count)

                    if let data = delegate.receivedData, let string = String(data: data, encoding: .utf8) {
                        XCTAssertEqual(string, body)
                    } else {
                        XCTFail("No string body for \(testMethod)")
                }
            }
        }
    }

    func test_httpRedirectDontFollowIgnoringHandler() throws {
        let statusCode = 302
        for method in httpMethods {
            let testMethod = "\(method) request with statusCode \(statusCode)"
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/\(statusCode)?location=jsonBody"
            let url = try XCTUnwrap(URL(string: urlString), "Cant create URL for \(testMethod)")
            var request = URLRequest(url: url)
            request.httpMethod = method
            let expect = expectation(description: "\(method) \(urlString): with HTTP redirection")
            expect.isInverted = true
            let delegate = SessionDelegate(with: expect)
            delegate.redirectionHandler = { (response: HTTPURLResponse, request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) in
                // Dont follow the request by not calling the completion handler at all
            }
            delegate.run(with: request, timeoutInterval: 1)

            waitForExpectations(timeout: 2)
            XCTAssertNil(delegate.error)
            XCTAssertNil(delegate.receivedData)
            XCTAssertNil(delegate.response)
            XCTAssertEqual(delegate.redirectionResponse?.statusCode, statusCode, "HTTP redirection response code is invalid for \(testMethod)")

            let callbackMsg = "Bad callback for \(testMethod)"
            XCTAssertEqual(delegate.callbacks.count, 1, "Callback count for \(testMethod)")
            XCTAssertEqual(delegate.callbacks, ["urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)"], callbackMsg)
        }
    }

    func test_httpRedirectionWithCompleteRelativePath() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/UnitedStates"
        let url = URL(string: urlString)!
        let d = HTTPRedirectionDataTask(with: expectation(description: "GET \(urlString): with HTTP redirection"))
        d.run(with: url)
        waitForExpectations(timeout: 12)
    }

    func test_httpRedirectionWithInCompleteRelativePath() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/UnitedKingdom"
        let url = URL(string: urlString)!
        let d = HTTPRedirectionDataTask(with: expectation(description: "GET \(urlString): with HTTP redirection"))
        d.run(with: url)
        waitForExpectations(timeout: 12)
    }

    func test_httpRedirectionWithDefaultPort() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/redirect-with-default-port"
        let url = URL(string: urlString)!
        let d = HTTPRedirectionDataTask(with: expectation(description: "GET \(urlString): with HTTP redirection"))
        d.run(with: url)
        waitForExpectations(timeout: 12)
    }
    
    func test_httpRedirectionWithEncodedQuery() {
        let location = "echo-query%3Fparam%3Dfoo" // "echo-query?param=foo" url encoded
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/303?location=\(location)"
        let url = URL(string: urlString)!
        let d = HTTPRedirectionDataTask(with: expectation(description: "GET \(urlString): with HTTP redirection"))
        d.run(with: url)
        waitForExpectations(timeout: 12)
        
        if let body = String(data: d.receivedData, encoding: .utf8) {
            XCTAssertEqual(body, "param=foo")
        } else {
            XCTFail("No string body")
        }
    }

     // temporarily disabled (https://bugs.swift.org/browse/SR-5751)
    func test_httpRedirectionTimeout() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/UnitedStates"
        var req = URLRequest(url: URL(string: urlString)!)
        req.timeoutInterval = 3
        let config = URLSessionConfiguration.default
        let expect = expectation(description: "GET \(urlString): timeout with redirection ")
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let task = session.dataTask(with: req) { data, response, error in
            defer { expect.fulfill() }
            if let e = error as? URLError {
                XCTAssertEqual(e.code, .cannotConnectToHost, "Unexpected error code")
                return
            } else {
                XCTFail("test unexpectedly succeeded (response=\(response.debugDescription))")
            }
        }
        task.resume()
        waitForExpectations(timeout: 12)
    }

    func test_httpRedirectionChainInheritsTimeoutInterval() throws {
        let redirectCount = 4
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/redirect/\(redirectCount)"
        let url = try XCTUnwrap(URL(string: urlString))
        let timeoutInterval = 3.0

        for method in httpMethods {
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.timeoutInterval = timeoutInterval
            let delegate = SessionDelegate(with: expectation(description: "\(method) \(urlString): with HTTP redirection"))
            var timeoutIntervals: [Double] = []
            delegate.redirectionHandler = { (response: HTTPURLResponse, request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) in
                timeoutIntervals.append(request.timeoutInterval)
                completionHandler(request)
            }
            delegate.run(with: request, timeoutInterval: timeoutInterval)
            waitForExpectations(timeout: timeoutInterval + 1)
            XCTAssertEqual(timeoutIntervals.count, redirectCount, "Redirect chain count for \(method)")

            // Check the redirect request timeouts are the same as the original request timeout
            XCTAssertFalse(timeoutIntervals.contains { $0 != timeoutInterval }, "Timeout Intervals for \(method)")
            let httpResponse = delegate.response as? HTTPURLResponse
            XCTAssertEqual(httpResponse?.statusCode, 200, ".statusCode for \(method)")
        }
    }

    func test_httpRedirectionExceededMaxRedirects() throws {
        let expectedMaxRedirects = 20
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/redirect/99"
        let url = try XCTUnwrap(URL(string: urlString))
        let exceededCountUrlString = "http://127.0.0.1:\(TestURLSession.serverPort)/redirect/\(99 - expectedMaxRedirects)"
        let exceededCountUrl = try XCTUnwrap(URL(string: exceededCountUrlString))

        for method in httpMethods {
            var request = URLRequest(url: url)
            request.httpMethod = method
            let delegate = SessionDelegate(with: expectation(description: "\(method) \(urlString): with HTTP redirection"))

            var redirectRequests: [(HTTPURLResponse, URLRequest)] = []
            delegate.redirectionHandler = { (response: HTTPURLResponse, request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) in
                redirectRequests.append((response, request))
                completionHandler(request)
            }
            delegate.run(with: request, timeoutInterval: 5)
            waitForExpectations(timeout: 20)

            XCTAssertNil(delegate.response)
            XCTAssertNil(delegate.receivedData)

            XCTAssertNotNil(delegate.error)
            let error = delegate.error as? URLError
            XCTAssertEqual(error?.code.rawValue, NSURLErrorHTTPTooManyRedirects)
            XCTAssertEqual(error?.localizedDescription, "too many HTTP redirects")
            let userInfo = error?.userInfo
            XCTAssertNotNil(userInfo)
            let errorURL = userInfo?[NSURLErrorFailingURLErrorKey] as? URL
            XCTAssertEqual(errorURL, exceededCountUrl)

            // Check the last Redirection response/request received.
            XCTAssertEqual(redirectRequests.count, expectedMaxRedirects)
            let lastResponse = redirectRequests.last?.0
            let lastRequest = redirectRequests.last?.1

            XCTAssertEqual(lastResponse?.statusCode, 302)
            XCTAssertEqual(lastRequest?.url, exceededCountUrl)
        }
    }

    func test_willPerformRedirect() throws {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/redirect/1"
        let url = try XCTUnwrap(URL(string: urlString))
        let redirectURL = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/jsonBody"))
        let delegate = SessionDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let expect = expectation(description: "GET \(urlString)")

        let task = session.dataTask(with: url) { (data, response, error) in
            defer { expect.fulfill() }
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            XCTAssertNotNil(response)
            XCTAssertEqual(delegate.redirectionRequest?.url, redirectURL)

            let callBacks = [
                "urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)",
            ]
            XCTAssertEqual(delegate.callbacks.count, callBacks.count)
            XCTAssertEqual(delegate.callbacks, callBacks)
        }

        task.resume()
        waitForExpectations(timeout: 5)
    }

    func test_httpNotFound() throws {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/404"
        let url = try XCTUnwrap(URL(string: urlString))

        let delegate = SessionDelegate(with: expectation(description: "GET \(urlString): with a delegate"))
        delegate.run(with: url)

        waitForExpectations(timeout: 4)
        XCTAssertNil(delegate.error)
        XCTAssertNotNil(delegate.response)
        let httpResponse = delegate.response as? HTTPURLResponse
        XCTAssertEqual(httpResponse?.statusCode, 404)

        XCTAssertEqual(delegate.callbacks.count, 3)
        let callbacks = ["urlSession(_:dataTask:didReceive:completionHandler:)",
                         "urlSession(_:dataTask:didReceive:)",
                         "urlSession(_:task:didCompleteWithError:)"
        ]
        XCTAssertEqual(delegate.callbacks, callbacks)

        XCTAssertNotNil(delegate.receivedData)
        if let data = delegate.receivedData, let jsonBody = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
            XCTAssertEqual(jsonBody["uri"], "GET /404 HTTP/1.1")
        } else {
            XCTFail("Could not decode body as JSON")
        }
    }

    func test_http0_9SimpleResponses() {
        for brokenCity in ["Pompeii", "Sodom"] {
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/LandOfTheLostCities/\(brokenCity)"
            let url = URL(string: urlString)!

            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 8
            let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
            let expect = expectation(description: "GET \(urlString): simple HTTP/0.9 response")
            let task = session.dataTask(with: url) { data, response, error in
                XCTAssertNotNil(data)
                XCTAssertNotNil(response)
                XCTAssertNil(error)

                defer { expect.fulfill() }

                guard let httpResponse = response as? HTTPURLResponse else {
                    XCTFail("response (\(response.debugDescription)) invalid")
                    return
                }
                XCTAssertEqual(200, httpResponse.statusCode, "HTTP response code is not 200")
            }
            task.resume()
            waitForExpectations(timeout: 12)
        }
    }

    func test_outOfRangeButCorrectlyFormattedHTTPCode() {
        let brokenCity = "Kameiros"
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/LandOfTheLostCities/\(brokenCity)"
        let url = URL(string: urlString)!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "GET \(urlString): out of range HTTP code")
        let task = session.dataTask(with: url) { data, response, error in
            XCTAssertNotNil(data)
            XCTAssertNotNil(response)
            XCTAssertNil(error)

            defer { expect.fulfill() }

            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("response (\(response.debugDescription)) invalid")
                return
            }
            XCTAssertEqual(999, httpResponse.statusCode, "HTTP response code is not 999")
        }
        task.resume()
        waitForExpectations(timeout: 12)
    }

    func test_missingContentLengthButStillABody() {
        let brokenCity = "Myndus"
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/LandOfTheLostCities/\(brokenCity)"
        let url = URL(string: urlString)!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "GET \(urlString): missing content length")
        let task = session.dataTask(with: url) { data, response, error in
            XCTAssertNotNil(data)
            XCTAssertNotNil(response)
            XCTAssertNil(error)

            defer { expect.fulfill() }

            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("response (\(response.debugDescription)) invalid")
                return
            }
            XCTAssertEqual(200, httpResponse.statusCode, "HTTP response code is not 200")
        }
        task.resume()
        waitForExpectations(timeout: 12)
    }


    func test_illegalHTTPServerResponses() {
        for brokenCity in ["Gomorrah", "Dinavar", "Kuhikugu"] {
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/LandOfTheLostCities/\(brokenCity)"
            let url = URL(string: urlString)!

            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 8
            let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
            let expect = expectation(description: "GET \(urlString): illegal response")
            let task = session.dataTask(with: url) { data, response, error in
                XCTAssertNil(data)
                XCTAssertNil(response)
                XCTAssertNotNil(error)

                expect.fulfill()
            }
            task.resume()
            waitForExpectations(timeout: 12)
        }
    }

    func test_dataTaskWithSharedDelegate() {
        let sharedDelegate = SharedDelegate()
        let urlString0 = "http://127.0.0.1:\(TestURLSession.serverPort)/Nepal"
        let session = URLSession(configuration: .default, delegate: sharedDelegate, delegateQueue: nil)

        let dataRequest = URLRequest(url: URL(string: urlString0)!)
        let dataTask = session.dataTask(with: dataRequest)

        sharedDelegate.dataCompletionExpectation = expectation(description: "GET \(urlString0)")
        dataTask.resume()
        waitForExpectations(timeout: 20)
    }

    func test_simpleUploadWithDelegate() {
        let delegate = HTTPUploadDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/upload"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "PUT"

        delegate.uploadCompletedExpectation = expectation(description: "PUT \(urlString): Upload data")

        let fileData = Data(count: 16 * 1024)
        let task = session.uploadTask(with: request, from: fileData)
        task.resume()
        waitForExpectations(timeout: 20)
        XCTAssertEqual(delegate.totalBytesSent, Int64(fileData.count))

    }

    func test_requestWithEmptyBody() throws {
        for method in httpMethods {
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/" + method.lowercased()
            let url = try XCTUnwrap(URL(string: urlString))

            for body in [nil, Data()] as [Data?] {
                for contentType in ["text/plain; charset=utf-8", nil] {   // nil Content-Type lets URLSession set it
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = method
                    urlRequest.httpBody = body
                    if let ct = contentType  {
                        urlRequest.setValue(ct, forHTTPHeaderField: "Content-Type")
                    }

                    let delegate = SessionDelegate(with: expectation(description: "\(method) \(urlString): with empty HTTP Body"))
                    delegate.run(with: urlRequest, timeoutInterval: 3)
                    waitForExpectations(timeout: 4)

                    let httpResponse = delegate.response as? HTTPURLResponse
                    let contentLength = Int(httpResponse?.value(forHTTPHeaderField: "Content-Length") ?? "")

                    switch method {
                        case "HEAD":
                            XCTAssertNil(delegate.error, "Expected no errors for \(method) request")
                            XCTAssertNotNil(delegate.response, "Expected a response for \(method) request")
                            XCTAssertEqual(httpResponse?.statusCode, 200, "Status code for \(method) request")
                            XCTAssertEqual(delegate.callbacks.count, 2, "Callback count for \(method) request")
                            let callbacks = ["urlSession(_:dataTask:didReceive:completionHandler:)",
                                             "urlSession(_:task:didCompleteWithError:)"
                            ]
                            XCTAssertEqual(delegate.callbacks, callbacks, "Delegate Callbacks for \(method) request")
                            XCTAssertNil(delegate.receivedData, "Expected no Data for \(method) request")

                        default:
                            XCTAssertNil(delegate.error, "Expected no errors for \(method) request")
                            XCTAssertNotNil(delegate.response, "Expected a response for \(method) request")
                            XCTAssertEqual(httpResponse?.statusCode, 200, "Status code for \(method) request")
                            XCTAssertEqual(delegate.callbacks.count, 3, "Callback count for \(method) request")
                            let callBacks = ["urlSession(_:dataTask:didReceive:completionHandler:)",
                                             "urlSession(_:dataTask:didReceive:)",
                                             "urlSession(_:task:didCompleteWithError:)"
                            ]
                            XCTAssertEqual(delegate.callbacks, callBacks, "Delegate Callbacks for \(method) request")
                            XCTAssertNotNil(delegate.receivedData, "Expected Data for \(method) request")
                            XCTAssertEqual(delegate.receivedData?.count, contentLength, "Content-Length for \(method) request")
                            if let receivedData = delegate.receivedData, let jsonBody = try? JSONSerialization.jsonObject(with: receivedData, options: []) as? [String: String] {
                                XCTAssertEqual(jsonBody["Content-Type"], contentType, "Content-Type for \(method) request")
                            } else {
                                XCTFail("No JSON body for \(method)")
                        }
                    }
                }
            }
        }
    }

    func test_requestWithNonEmptyBody() throws {
        let bodyData = try XCTUnwrap("This is a request body".data(using: .utf8))
        for method in httpMethods {
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/" + method.lowercased()
            let url = try XCTUnwrap(URL(string: urlString))

            for contentType in ["text/plain; charset=utf-8", nil] {   // nil Content-Type lets URLSession set it
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = method
                urlRequest.httpBody = bodyData
                if let ct = contentType  {
                    urlRequest.setValue(ct, forHTTPHeaderField: "Content-Type")
                }

                let delegate = SessionDelegate(with: expectation(description: "\(method) \(urlString): with empty HTTP Body"))
                delegate.run(with: urlRequest, timeoutInterval: 3)
                waitForExpectations(timeout: 4)

                let httpResponse = delegate.response as? HTTPURLResponse
                let contentLength = Int(httpResponse?.value(forHTTPHeaderField: "Content-Length") ?? "")
                // Only POST sets a default Content-Type if it is nil
                let postedContentType = contentType ?? ((method == "POST") ? "application/x-www-form-urlencoded" : nil)

                let callBacks: [String]
                switch method {
                    case "HEAD":
                        XCTAssertNil(delegate.error)
                        XCTAssertNotNil(delegate.response)
                        XCTAssertEqual(httpResponse?.statusCode, 200)
                        XCTAssertNil(delegate.receivedData)
                        callBacks = ["urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)",
                                     "urlSession(_:dataTask:didReceive:completionHandler:)",
                                     "urlSession(_:task:didCompleteWithError:)"]

                    case "GET":
                        // GET requests must not have a body, which causes an error
                        XCTAssertNotNil(delegate.error)
                        let error = delegate.error as? URLError
                        XCTAssertEqual(error?.code.rawValue, NSURLErrorDataLengthExceedsMaximum)
                        XCTAssertEqual(error?.localizedDescription, "resource exceeds maximum size")
                        let userInfo = error?.userInfo
                        XCTAssertNotNil(userInfo)
                        let errorURL = userInfo?[NSURLErrorFailingURLErrorKey] as? URL
                        XCTAssertEqual(errorURL, url)

                        XCTAssertNil(delegate.response)
                        XCTAssertNil(delegate.receivedData)
                        callBacks = ["urlSession(_:task:didCompleteWithError:)"]

                    default:
                        XCTAssertNil(delegate.error)
                        XCTAssertNotNil(delegate.response)
                        XCTAssertEqual(httpResponse?.statusCode, 200)
                        XCTAssertNotNil(delegate.receivedData)
                        XCTAssertEqual(delegate.receivedData?.count, contentLength)
                        if let receivedData = delegate.receivedData, let jsonBody = try? JSONSerialization.jsonObject(with: receivedData, options: []) as? [String: String] {
                            XCTAssertEqual(jsonBody["Content-Type"], postedContentType)
                            let uri = "\(method) /" + method.lowercased() + " HTTP/1.1"
                            XCTAssertEqual(jsonBody["uri"], uri)
                            XCTAssertEqual(jsonBody["Content-Length"], "\(bodyData.count)", "Bad Content-Length for \(method) request")
                            if let postedBody = jsonBody["x-base64-body"], let decodedBody = Data(base64Encoded: postedBody) {
                                XCTAssertEqual(decodedBody, bodyData)
                            } else {
                                XCTFail("Could not decode Base64 body for \(method)")
                            }
                        } else {
                            XCTFail("No JSON body for \(method)")
                        }
                        callBacks = ["urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)",
                                     "urlSession(_:dataTask:didReceive:completionHandler:)",
                                     "urlSession(_:dataTask:didReceive:)",
                                     "urlSession(_:task:didCompleteWithError:)"]
                }
                XCTAssertEqual(delegate.callbacks.count, callBacks.count)
                XCTAssertEqual(delegate.callbacks, callBacks)
            }
        }
    }


    func test_concurrentRequests() throws {
        let tasks = 10
        let syncQ = dispatchQueueMake("test_dataTaskWithURL.syncQ")
        var dataTasks: [DataTask] = []
        dataTasks.reserveCapacity(tasks)

        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/Nepal"
        let url = try XCTUnwrap(URL(string: urlString))

        let g = dispatchGroupMake()
        for f in 0..<tasks {
            g.enter()
            let expectation = self.expectation(description: "GET \(urlString) [\(f)]: with a delegate")
            globalDispatchQueue.async {
                let d = DataTask(with: expectation)
                d.run(with: url)
                syncQ.sync {
                    dataTasks.append(d)
                }
                g.leave()
            }
        }
        waitForExpectations(timeout: 12)
        XCTAssertEqual(g.wait(timeout: .now() + .milliseconds(1)), .success)
        XCTAssertEqual(dataTasks.count, tasks)
        for task in dataTasks {
            XCTAssertFalse(task.error)
            XCTAssertEqual(task.capital, "Kathmandu", "test_dataTaskWithURLRequest returned an unexpected result")
        }
    }

    func emptyCookieStorage(storage: HTTPCookieStorage?) {
        if let storage = storage, let cookies = storage.cookies {
            for cookie in cookies {
                storage.deleteCookie(cookie)
            }
        }
    }

    func test_disableCookiesStorage() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.httpCookieAcceptPolicy = HTTPCookie.AcceptPolicy.never
        emptyCookieStorage(storage: config.httpCookieStorage)
        XCTAssertEqual(config.httpCookieStorage?.cookies?.count, 0)
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/requestCookies"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "POST \(urlString)")
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "POST"
        let task = session.dataTask(with: req) { (data, response, error) -> Void in
            defer { expect.fulfill() }
            XCTAssertNotNil(data)
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            guard let httpResponse = try? XCTUnwrap(response as? HTTPURLResponse) else {
                XCTFail("response should be a non-nil HTTPURLResponse")
                return
            }
            XCTAssertNotNil(httpResponse.allHeaderFields["Set-Cookie"])
        }
        task.resume()
        waitForExpectations(timeout: 30)
        let cookies = HTTPCookieStorage.shared.cookies
        XCTAssertEqual(cookies?.count, 0)
    }

    func test_cookiesStorage() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        emptyCookieStorage(storage: config.httpCookieStorage)
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/requestCookies"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "POST \(urlString)")
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "POST"
        let task = session.dataTask(with: req) { (data, response, error) -> Void in
            defer { expect.fulfill() }
            XCTAssertNotNil(data)
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            guard let httpResponse = try? XCTUnwrap(response as? HTTPURLResponse) else {
                XCTFail("response should be a non-nil HTTPURLResponse")
                return
            }
            XCTAssertNotNil(httpResponse.allHeaderFields["Set-Cookie"])
        }
        task.resume()
        waitForExpectations(timeout: 30)
        let cookies = HTTPCookieStorage.shared.cookies
        XCTAssertEqual(cookies?.count, 1)
    }

    func test_redirectionWithSetCookies() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        emptyCookieStorage(storage: config.httpCookieStorage)
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/redirectToEchoHeaders"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "POST \(urlString)")
        let req = URLRequest(url: URL(string: urlString)!)
        let task = session.dataTask(with: req) { (data, _, error) -> Void in
            defer { expect.fulfill() }
            // Because /redirectToEchoHeaders is a redirection, this is the
            // final result of the redirection, not the redirection itself.
            guard let data = try? XCTUnwrap(data) else {
                XCTFail("data should not be nil")
                return
            }
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            let headers = String(data: data, encoding: String.Encoding.utf8) ?? ""
            XCTAssertNotNil(headers.range(of: "Cookie: redirect=true"))
        }
        task.resume()
        waitForExpectations(timeout: 30)
    }

    func test_previouslySetCookiesAreSentInLaterRequests() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        emptyCookieStorage(storage: config.httpCookieStorage)
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)

        let urlString1 = "http://127.0.0.1:\(TestURLSession.serverPort)/requestCookies"
        let expect1 = expectation(description: "POST \(urlString1)")
        var req1 = URLRequest(url: URL(string: urlString1)!)
        req1.httpMethod = "POST"

        let urlString2 = "http://127.0.0.1:\(TestURLSession.serverPort)/echoHeaders"
        let expect2 = expectation(description: "POST \(urlString2)")
        var req2 = URLRequest(url: URL(string: urlString2)!)
        req2.httpMethod = "POST"

        let task1 = session.dataTask(with: req1) { (data, response, error) -> Void in
            defer { expect1.fulfill() }
            XCTAssertNotNil(data)
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            guard let httpResponse = try? XCTUnwrap(response as? HTTPURLResponse) else {
                XCTFail("response should be a non-nil HTTPURLResponse")
                return
            }
            XCTAssertNotNil(httpResponse.allHeaderFields["Set-Cookie"])

            let task2 = session.dataTask(with: req2) { (data, _, error) -> Void in
                defer { expect2.fulfill() }
                guard let data = try? XCTUnwrap(data) else {
                    XCTFail("data should not be nil")
                    return
                }
                XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
                let headers = String(data: data, encoding: String.Encoding.utf8) ?? ""
                XCTAssertNotNil(headers.range(of: "Cookie: fr=anjd&232"))
            }
            task2.resume()
        }
        task1.resume()

        waitForExpectations(timeout: 30)
    }

    func test_cookieStorageForEphemeralConfiguration() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        emptyCookieStorage(storage: config.httpCookieStorage)

        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/requestCookies"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "POST \(urlString)")
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "POST"
        let task = session.dataTask(with: req) { (data, _, error) -> Void in
            defer { expect.fulfill() }
            XCTAssertNotNil(data)
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
        }
        task.resume()
        waitForExpectations(timeout: 30)
        let cookies = config.httpCookieStorage?.cookies
        XCTAssertEqual(cookies?.count, 1)

        let config2 = URLSessionConfiguration.ephemeral
        let cookies2 = config2.httpCookieStorage?.cookies
        XCTAssertEqual(cookies2?.count, 0)
    }

    func test_setCookieHeadersCanBeIgnored() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.httpShouldSetCookies = false
        emptyCookieStorage(storage: config.httpCookieStorage)
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)

        let urlString1 = "http://127.0.0.1:\(TestURLSession.serverPort)/requestCookies"
        let expect1 = expectation(description: "POST \(urlString1)")
        var req1 = URLRequest(url: URL(string: urlString1)!)
        req1.httpMethod = "POST"

        let urlString2 = "http://127.0.0.1:\(TestURLSession.serverPort)/echoHeaders"
        let expect2 = expectation(description: "POST \(urlString2)")
        var req2 = URLRequest(url: URL(string: urlString2)!)
        req2.httpMethod = "POST"

        let task1 = session.dataTask(with: req1) { (data, response, error) -> Void in
            defer { expect1.fulfill() }
            XCTAssertNotNil(data)
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            guard let httpResponse = try? XCTUnwrap(response as? HTTPURLResponse) else {
                XCTFail("response should be a non-nil HTTPURLResponse")
                return
            }
            XCTAssertNotNil(httpResponse.allHeaderFields["Set-Cookie"])

            let task2 = session.dataTask(with: req2) { (data, _, error) -> Void in
                defer { expect2.fulfill() }
                guard let data = try? XCTUnwrap(data) else {
                    XCTFail("data should not be nil")
                    return
                }
                XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
                let headers = String(data: data, encoding: String.Encoding.utf8) ?? ""
                XCTAssertNil(headers.range(of: "Cookie: fr=anjd&232"))
            }
            task2.resume()
        }
        task1.resume()

        waitForExpectations(timeout: 30)
    }

    // Validate that the properties are correctly set
    func test_initURLSessionConfiguration() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 604800
        config.networkServiceType = .default
        config.allowsCellularAccess = false
        config.isDiscretionary = true
        config.httpShouldUsePipelining = true
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        config.httpMaximumConnectionsPerHost = 2
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.shouldUseExtendedBackgroundIdleMode = true

        XCTAssertEqual(config.requestCachePolicy, NSURLRequest.CachePolicy.useProtocolCachePolicy)
        XCTAssertEqual(config.timeoutIntervalForRequest, 30)
        XCTAssertEqual(config.timeoutIntervalForResource, 604800)
        XCTAssertEqual(config.networkServiceType, NSURLRequest.NetworkServiceType.default)
        XCTAssertEqual(config.allowsCellularAccess, false)
        XCTAssertEqual(config.isDiscretionary, true)
        XCTAssertEqual(config.httpShouldUsePipelining, true)
        XCTAssertEqual(config.httpShouldSetCookies, true)
        XCTAssertEqual(config.httpCookieAcceptPolicy, HTTPCookie.AcceptPolicy.always)
        XCTAssertEqual(config.httpMaximumConnectionsPerHost, 2)
        XCTAssertEqual(config.httpCookieStorage, HTTPCookieStorage.shared)
        XCTAssertEqual(config.urlCredentialStorage, nil)
        XCTAssertEqual(config.urlCache, nil)
        XCTAssertEqual(config.shouldUseExtendedBackgroundIdleMode, true)
   }

   func test_basicAuthRequest() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/auth/basic"
        let url = URL(string: urlString)!
        let d = DataTask(with: expectation(description: "GET \(urlString): with a delegate"))
        d.run(with: url)
        waitForExpectations(timeout: 60)
    }

    /* Test for SR-8970 to verify that content-type header is not added to post with empty body */
    func test_postWithEmptyBody() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/emptyPost"
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let expect = expectation(description: "POST \(urlString): post with empty body")
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "POST"
        let task = session.dataTask(with: req) { (_, response, error) -> Void in
            defer { expect.fulfill() }
            XCTAssertNil(error as? URLError, "error = \(error as! URLError)")
            guard let httpresponse = response as? HTTPURLResponse else { fatalError() }
            XCTAssertEqual(200, httpresponse.statusCode, "HTTP response code is not 200")
        }
        task.resume()
        waitForExpectations(timeout: 30)
    }

    func test_basicAuthWithUnauthorizedHeader() {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/unauthorized"
        let url = URL(string: urlString)!
        let expect = expectation(description: "GET \(urlString): with a completion handler")
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: url) { _, response, error in
            defer { expect.fulfill() }
            XCTAssertNotNil(response)
            XCTAssertNil(error)
        }
        task.resume()
        waitForExpectations(timeout: 12, handler: nil)
    }

    func test_checkErrorTypeAfterInvalidateAndCancel() throws {
        let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/country.txt"
        let url = try XCTUnwrap(URL(string: urlString))
        var urlRequest = URLRequest(url: url)
        urlRequest.addValue("5", forHTTPHeaderField: "X-Pause")
        let expect = expectation(description: "Check error code of tasks after invalidateAndCancel")
        let delegate = SessionDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: urlRequest) { (_, _, error) in
            XCTAssertNotNil(error as? URLError)
            if let urlError = error as? URLError {
                XCTAssertEqual(urlError._nsError.code, NSURLErrorCancelled)
                XCTAssertEqual(urlError.userInfo[NSURLErrorFailingURLErrorKey] as? URL, URL(string: urlString))
                XCTAssertEqual(urlError.userInfo[NSURLErrorFailingURLStringErrorKey] as? String, urlString)
                XCTAssertEqual(urlError.localizedDescription, "cancelled")
            }

            expect.fulfill()
        }
        task.resume()
        session.invalidateAndCancel()
        waitForExpectations(timeout: 5)
    }

    func test_taskCountAfterInvalidateAndCancel() throws {
        let expect = expectation(description: "Check task count after invalidateAndCancel")

        let session = URLSession(configuration: .default)
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/country.txt")))
        request.addValue("5", forHTTPHeaderField: "X-Pause")
        let task1 = session.dataTask(with: request)
        request.url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/requestHeaders"))
        let task2 = session.dataTask(with: request)
        request.url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/emptyPost"))
        let task3 = session.dataTask(with: request)

        task1.resume()
        task2.resume()
        session.invalidateAndCancel()

        session.getAllTasks { tasksBeforeResume in
            XCTAssertEqual(tasksBeforeResume.count, 0)

            // Resume a task after invalidating a session shouldn't change the task's status
            task3.resume()

            session.getAllTasks { tasksAfterResume in
                XCTAssertEqual(tasksAfterResume.count, 0)
                expect.fulfill()
            }
        }
        waitForExpectations(timeout: 5)
    }

    func test_sessionDelegateAfterInvalidateAndCancel() {
        let delegate = SessionDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        session.invalidateAndCancel()
        Thread.sleep(forTimeInterval: 2)
        XCTAssertNil(session.delegate)
    }

    func test_getAllTasks() throws {
        let expect = expectation(description: "Tasks URLSession.getAllTasks")

        let session = URLSession(configuration: .default)
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/country.txt")))
        request.addValue("5", forHTTPHeaderField: "X-Pause")
        let dataTask1 = session.dataTask(with: request)
        request.url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/requestHeaders"))
        let dataTask2 = session.dataTask(with: request)
        request.url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/emptyPost"))
        let dataTask3 = session.dataTask(with: request)

        session.getAllTasks { (tasksBeforeResume) in
            XCTAssertEqual(tasksBeforeResume.count, 0)

            dataTask1.cancel()

            dataTask2.resume()
            dataTask2.suspend()
            // dataTask3 is suspended even before it was resumed, so the next call to `getAllTasks` should not include this tasks
            dataTask3.suspend()
            session.getAllTasks { (tasksAfterCancel) in
                // tasksAfterCancel should only contain dataTask2
                XCTAssertEqual(tasksAfterCancel.count, 1)

                // A task will in be in suspended state when it was created.
                // Given that, dataTask3 was suspended once again earlier above, so it should receive `resume()` twice in order to be executed
                // Calling `getAllTasks` next time should not include dataTask3
                dataTask3.resume()

                session.getAllTasks { (tasksAfterFirstResume) in
                    // tasksAfterFirstResume should only contain dataTask2
                    XCTAssertEqual(tasksAfterFirstResume.count, 1)

                    // Now dataTask3 received `resume()` twice, this time `getAllTasks` should include
                    dataTask3.resume()
                    session.getAllTasks { (tasksAfterSecondResume) in
                        // tasksAfterSecondResume should contain dataTask2 and dataTask2 this time
                        XCTAssertEqual(tasksAfterSecondResume.count, 2)
                        expect.fulfill()
                    }
                }
            }
        }

        waitForExpectations(timeout: 20)
    }

    func test_getTasksWithCompletion() throws {
        let expect = expectation(description: "Test URLSession.getTasksWithCompletion")

        let session = URLSession(configuration: .default)
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/country.txt")))
        request.addValue("5", forHTTPHeaderField: "X-Pause")
        let dataTask1 = session.dataTask(with: request)
        request.url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/requestHeaders"))
        let dataTask2 = session.dataTask(with: request)
        request.url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/emptyPost"))
        let dataTask3 = session.dataTask(with: request)

        request.url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/upload"))
        let uploadTask1 = session.uploadTask(with: request, from: Data())
        request.url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/echo"))
        let uploadTask2 = session.uploadTask(with: request, from: Data())

        request.url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/DTDs/PropertyList-1.0.dtd"))
        let downloadTask1 = session.downloadTask(with: request)

        session.getTasksWithCompletionHandler { (dataTasksBeforeCancel, uploadTasksBeforeCancel, downloadTasksBeforeCancel) in
            XCTAssertEqual(dataTasksBeforeCancel.count, 0)
            XCTAssertEqual(uploadTasksBeforeCancel.count, 0)
            XCTAssertEqual(downloadTasksBeforeCancel.count, 0)

            dataTask1.cancel()
            dataTask2.resume()
            // dataTask3 is resumed and suspended, so this task should be a part of `getTasksWithCompletionHandler` response
            dataTask3.resume()
            dataTask3.suspend()

            // uploadTask1 suspended even before it was resumed, so this task shouldn't be a part of `getTasksWithCompletionHandler` response
            uploadTask1.suspend()
            uploadTask2.resume()

            downloadTask1.cancel()

            session.getTasksWithCompletionHandler{ (dataTasksAfterCancel, uploadTasksAfterCancel, downloadTasksAfterCancel) in
                XCTAssertEqual(dataTasksAfterCancel.count, 2)
                XCTAssertEqual(uploadTasksAfterCancel.count, 1)
                XCTAssertEqual(downloadTasksAfterCancel.count, 0)
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: 20)
    }

    func test_noDoubleCallbackWhenCancellingAndProtocolFailsFast() throws {
        let urlString = "failfast://bogus"
        var callbackCount = 0
        let callback1 = expectation(description: "Callback call #1")
        let callback2 = expectation(description: "Callback call #2")
        callback2.isInverted = true
        let delegate = SessionDelegate()
        let url = try XCTUnwrap(URL(string: urlString))
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [FailFastProtocol.self]
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: url) { (_, _, error) in
            callbackCount += 1
            XCTAssertNotNil(error)
            if let urlError = error as? URLError {
                XCTAssertEqual(urlError._nsError.code, NSURLErrorCancelled)
            }

            if callbackCount == 1 {
                callback1.fulfill()
            } else {
                callback2.fulfill()
            }
        }
        task.resume()
        session.invalidateAndCancel()
        waitForExpectations(timeout: 1)
    }

    func test_cancelledTasksCannotBeResumed() throws {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/Nepal"))
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        let task = session.dataTask(with: url)

        task.cancel() // should set .cancelling and eventually .completed
        task.resume() // should not change the task to .running

        let e = expectation(description: "getAllTasks callback called")
        session.getAllTasks { tasks in
            XCTAssertEqual(tasks.count, 0)
            e.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
    func test_invalidResumeDataForDownloadTask() {
        let done = expectation(description: "Invalid resume data for download task (with completion block)")
        URLSession.shared.downloadTask(withResumeData: Data()) { (url, response, error) in
            XCTAssertNil(url)
            XCTAssertNil(response)
            XCTAssert(error is URLError)
            XCTAssertEqual((error as? URLError)?.errorCode, URLError.unsupportedURL.rawValue)
            
            done.fulfill()
        }.resume()
        waitForExpectations(timeout: 20)
        
        let d = DownloadTask(testCase: self, description: "Invalid resume data for download task")
        d.run { (session) -> DownloadTask.Configuration in
            return DownloadTask.Configuration(task: session.downloadTask(withResumeData: Data()),
                                              errorExpectation:
                { (error) in
                    XCTAssert(error is URLError)
                    XCTAssertEqual((error as? URLError)?.errorCode, URLError.unsupportedURL.rawValue)
            })
        }
        waitForExpectations(timeout: 20)
    }
    
    func test_simpleUploadWithDelegateProvidingInputStream() throws {

        let fileData = Data(count: 16 * 1024)
        for method in httpMethods {
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/" + method.lowercased()
            let url = try XCTUnwrap(URL(string: urlString))
            var request = URLRequest(url: url)
            request.httpMethod = method

            let delegate = SessionDelegate(with: expectation(description: "\(method) \(urlString): Upload data"))
            delegate.newBodyStreamHandler = { (completionHandler: @escaping (InputStream?) -> Void) in
                completionHandler(InputStream(data: fileData))
            }
            delegate.runUploadTask(with: request, timeoutInterval: 4)
            waitForExpectations(timeout: 5)

            let httpResponse = delegate.response as? HTTPURLResponse
            let callBacks: [String]

            switch method {
                case "HEAD":
                    XCTAssertNil(delegate.error)
                    XCTAssertNotNil(delegate.response)
                    XCTAssertEqual(httpResponse?.statusCode, 200)
                    XCTAssertNil(delegate.receivedData)
                    XCTAssertEqual(delegate.totalBytesSent, Int64(fileData.count))
                    callBacks = ["urlSession(_:task:needNewBodyStream:)",
                                 "urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)",
                                 "urlSession(_:dataTask:didReceive:completionHandler:)",
                                 "urlSession(_:task:didCompleteWithError:)"]

                case "GET":
                    // GET requests must not have a body, which causes an error
                    XCTAssertNotNil(delegate.error)
                    let error = delegate.error as? URLError
                    XCTAssertEqual(error?.code.rawValue, NSURLErrorDataLengthExceedsMaximum)
                    XCTAssertEqual(error?.localizedDescription, "resource exceeds maximum size")
                    let userInfo = error?.userInfo
                    XCTAssertNotNil(userInfo)
                    let errorURL = userInfo?[NSURLErrorFailingURLErrorKey] as? URL
                    XCTAssertEqual(errorURL, url)
                    XCTAssertNil(delegate.response)
                    XCTAssertNil(delegate.receivedData)
                    XCTAssertEqual(delegate.totalBytesSent, 0)
                    callBacks = ["urlSession(_:task:needNewBodyStream:)",
                                 "urlSession(_:task:didCompleteWithError:)"]

                default:
                    XCTAssertNil(delegate.error)
                    XCTAssertNotNil(delegate.response)
                    XCTAssertEqual(httpResponse?.statusCode, 200)
                    XCTAssertEqual(delegate.totalBytesSent, Int64(fileData.count))
                    XCTAssertNotNil(delegate.receivedData)
                    let contentLength = Int(httpResponse?.value(forHTTPHeaderField: "Content-Length") ?? "")

                    XCTAssertEqual(delegate.receivedData?.count, contentLength)
                    if let receivedData = delegate.receivedData, let jsonBody = try? JSONSerialization.jsonObject(with: receivedData, options: []) as? [String: String] {
                        if let postedContentType = (method == "POST") ? "application/x-www-form-urlencoded" : nil {
                            XCTAssertEqual(jsonBody["Content-Type"], postedContentType)
                        } else {
                            XCTAssertNil(jsonBody.index(forKey: "Content-Type"))
                        }
                        if let postedBody = jsonBody["x-base64-body"], let decodedBody = Data(base64Encoded: postedBody) {
                            XCTAssertEqual(decodedBody, fileData)
                        } else {
                            XCTFail("Could not decode Base64 body for \(method)")
                        }
                    } else {
                        XCTFail("No JSON body for \(method)")
                    }
                    callBacks = ["urlSession(_:task:needNewBodyStream:)",
                                 "urlSession(_:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)",
                                 "urlSession(_:dataTask:didReceive:completionHandler:)",
                                 "urlSession(_:dataTask:didReceive:)",
                                 "urlSession(_:task:didCompleteWithError:)"]
            }
            XCTAssertEqual(delegate.callbacks.count, callBacks.count, "Callback count for \(method)")
            XCTAssertEqual(delegate.callbacks, callBacks, "Callbacks for \(method)")
        }
    }
    
#if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
    func test_webSocket() async throws {
        guard #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) else { return }
        guard URLSessionWebSocketTask.supportsWebSockets else {
            print("libcurl lacks WebSockets support, skipping \(#function)")
            return
        }
        
        let urlString = "ws://127.0.0.1:\(TestURLSession.serverPort)/web-socket"
        let url = try XCTUnwrap(URL(string: urlString))
        let request = URLRequest(url: url)
        
        let delegate = SessionDelegate(with: expectation(description: "\(urlString): Connect"))
        let task = delegate.runWebSocketTask(with: request, timeoutInterval: 4)
        
        // We interleave sending and receiving, as the test HTTPServer implementation is barebones, and can't handle receiving more than one frame at a time.  So, this back-and-forth acts as a gating mechanism
        try await task.send(.string("Hello"))
        
        let stringMessage = try await task.receive()
        switch stringMessage {
        case .string(let str):
            XCTAssert(str == "Hello")
        default:
            XCTFail("Unexpected String Message")
        }
        
        try await task.send(.data(Data([0x20, 0x22, 0x10, 0x03])))
        
        let dataMessage = try await task.receive()
        switch dataMessage {
        case .data(let data):
            XCTAssert(data == Data([0x20, 0x22, 0x10, 0x03]))
        default:
            XCTFail("Unexpected Data Message")
        }
        
        try await task.sendPing()
        
        wait(for: [delegate.expectation], timeout: 50)
        
        do {
            _ = try await task.receive()
            XCTFail("Expected to throw when receiving on closed task")
        } catch {
            let urlError = try XCTUnwrap(error as? URLError)
            XCTAssertEqual(urlError._nsError.code, NSURLErrorNetworkConnectionLost)
        }
        
        let callbacks = [ "urlSession(_:webSocketTask:didOpenWithProtocol:)",
                          "urlSession(_:webSocketTask:didCloseWith:reason:)",
                          "urlSession(_:task:didCompleteWithError:)" ]
        XCTAssertEqual(delegate.callbacks.count, callbacks.count)
        XCTAssertEqual(delegate.callbacks, callbacks, "Callbacks for \(#function)")
    }
    
    func test_webSocketSpecificProtocol() async throws {
        guard #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) else { return }
        guard URLSessionWebSocketTask.supportsWebSockets else {
            print("libcurl lacks WebSockets support, skipping \(#function)")
            return
        }

        let urlString = "ws://127.0.0.1:\(TestURLSession.serverPort)/web-socket/chatbot"
        let url = try XCTUnwrap(URL(string: urlString))
        let request = URLRequest(url: url)
        
        let delegate = SessionDelegate(with: expectation(description: "\(urlString): Connect"))
        let task = delegate.runWebSocketTask(with: request, timeoutInterval: 4, protocols: ["chatbot", "IRC", "BulletinBoard"])
        
        DispatchQueue.global(qos: .default).asyncAfter(wallDeadline: .now() + 1) {
            task.cancel(with: .normalClosure, reason: "BuhBye".data(using: .utf8))
        }
        
        wait(for: [delegate.expectation], timeout: 50)
        
        let callbacks = [ "urlSession(_:webSocketTask:didOpenWithProtocol:)",
                          "urlSession(_:webSocketTask:didCloseWith:reason:)",
                          "urlSession(_:task:didCompleteWithError:)" ]
        XCTAssertEqual(delegate.callbacks.count, callbacks.count)
        XCTAssertEqual(delegate.callbacks, callbacks, "Callbacks for \(#function)")
        
        XCTAssertEqual(task.closeCode, .normalClosure)
        XCTAssertEqual(task.closeReason, "BuhBye".data(using: .utf8))
    }
    
    func test_webSocketAbruptClose() async throws {
        guard #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) else { return }
        guard URLSessionWebSocketTask.supportsWebSockets else {
            print("libcurl lacks WebSockets support, skipping \(#function)")
            return
        }

        let urlString = "ws://127.0.0.1:\(TestURLSession.serverPort)/web-socket/abrupt-close"
        let url = try XCTUnwrap(URL(string: urlString))
        let request = URLRequest(url: url)
        
        let delegate = SessionDelegate(with: expectation(description: "\(urlString): Connect"))
        let task = delegate.runWebSocketTask(with: request, timeoutInterval: 4)
        
        do {
            _ = try await task.receive()
            XCTFail("Expected to throw when server closes connection")
        } catch {
            let urlError = try XCTUnwrap(error as? URLError)
            XCTAssertEqual(urlError._nsError.code, NSURLErrorBadServerResponse)
        }

        wait(for: [delegate.expectation], timeout: 50)

        do {
            _ = try await task.receive()
            XCTFail("Expected to throw when receiving on closed connection")
        } catch {
            let urlError = try XCTUnwrap(error as? URLError)
            XCTAssertEqual(urlError._nsError.code, NSURLErrorBadServerResponse)
        }

        let callbacks = [ "urlSession(_:task:didCompleteWithError:)" ]
        XCTAssertEqual(delegate.callbacks.count, callbacks.count)
        XCTAssertEqual(delegate.callbacks, callbacks, "Callbacks for \(#function)")
        
        XCTAssertEqual(task.closeCode, .invalid)
        XCTAssertEqual(task.closeReason, nil)
    }

    func test_webSocketSemiAbruptClose() async throws {
        guard #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) else { return }
        guard URLSessionWebSocketTask.supportsWebSockets else {
            print("libcurl lacks WebSockets support, skipping \(#function)")
            return
        }

        let urlString = "ws://127.0.0.1:\(TestURLSession.serverPort)/web-socket/semi-abrupt-close"
        let url = try XCTUnwrap(URL(string: urlString))
        let request = URLRequest(url: url)
        
        let delegate = SessionDelegate(with: expectation(description: "\(urlString): Connect"))
        let task = delegate.runWebSocketTask(with: request, timeoutInterval: 4)
        
        do {
            _ = try await task.receive()
            XCTFail("Expected to throw when server closes connection")
        } catch {
            let urlError = try XCTUnwrap(error as? URLError)
            XCTAssertEqual(urlError._nsError.code, NSURLErrorNetworkConnectionLost)
        }

        wait(for: [delegate.expectation], timeout: 50)

        do {
            _ = try await task.receive()
            XCTFail("Expected to throw when receiving on closed connection")
        } catch {
            let urlError = try XCTUnwrap(error as? URLError)
            XCTAssertEqual(urlError._nsError.code, NSURLErrorNetworkConnectionLost)
        }

        let callbacks = [ "urlSession(_:webSocketTask:didOpenWithProtocol:)",
                          "urlSession(_:webSocketTask:didCloseWith:reason:)",
                          "urlSession(_:task:didCompleteWithError:)" ]
        XCTAssertEqual(delegate.callbacks.count, callbacks.count)
        XCTAssertEqual(delegate.callbacks, callbacks, "Callbacks for \(#function)")
        
        XCTAssertEqual(task.closeCode, .normalClosure)
        XCTAssertEqual(task.closeReason, nil)
    }
#endif
  
    static var allTests: [(String, (TestURLSession) -> () throws -> Void)] {
        var retVal = [
            ("test_dataTaskWithURL", test_dataTaskWithURL),
            ("test_dataTaskWithURLRequest", test_dataTaskWithURLRequest),
            ("test_dataTaskWithURLCompletionHandler", test_dataTaskWithURLCompletionHandler),
            ("test_dataTaskWithURLRequestCompletionHandler", test_dataTaskWithURLRequestCompletionHandler),
            /* ⚠️ */ ("test_dataTaskWithHttpInputStream", testExpectedToFail(test_dataTaskWithHttpInputStream, "Flaky test")),
            ("test_dataTaskWithHTTPBodyRedirect", test_dataTaskWithHTTPBodyRedirect),
            ("test_gzippedDataTask", test_gzippedDataTask),
            ("test_downloadTaskWithURL", test_downloadTaskWithURL),
            ("test_downloadTaskWithURLRequest", test_downloadTaskWithURLRequest),
            ("test_downloadTaskWithRequestAndHandler", test_downloadTaskWithRequestAndHandler),
            ("test_downloadTaskWithURLAndHandler", test_downloadTaskWithURLAndHandler),
            ("test_gzippedDownloadTask", test_gzippedDownloadTask),
            ("test_finishTaskAndInvalidate", test_finishTasksAndInvalidate),
            ("test_taskError", test_taskError),
            ("test_taskCopy", test_taskCopy),
            ("test_cancelTask", test_cancelTask),
            ("test_unhandledURLProtocol", test_unhandledURLProtocol),
            ("test_requestToNilURL", test_requestToNilURL),
            /* ⚠️ */ ("test_suspendResumeTask", testExpectedToFail(test_suspendResumeTask, "Occasionally breaks")),
            ("test_taskTimeout", test_taskTimeout),
            ("test_verifyRequestHeaders", test_verifyRequestHeaders),
            ("test_verifyHttpAdditionalHeaders", test_verifyHttpAdditionalHeaders),
            ("test_httpRedirectionWithCode300", test_httpRedirectionWithCode300),
            ("test_httpRedirectionWithCode301_302", test_httpRedirectionWithCode301_302),
            ("test_httpRedirectionWithCode303", test_httpRedirectionWithCode303),
            ("test_httpRedirectionWithCode304", test_httpRedirectionWithCode304),
            ("test_httpRedirectionWithCode305_308", test_httpRedirectionWithCode305_308),
            ("test_httpRedirectDontFollowUsingNil", test_httpRedirectDontFollowUsingNil),
            ("test_httpRedirectDontFollowIgnoringHandler", test_httpRedirectDontFollowIgnoringHandler),
            ("test_httpRedirectionWithCompleteRelativePath", test_httpRedirectionWithCompleteRelativePath),
            ("test_httpRedirectionWithInCompleteRelativePath", test_httpRedirectionWithInCompleteRelativePath),
            ("test_httpRedirectionWithDefaultPort", test_httpRedirectionWithDefaultPort),
            ("test_httpRedirectionWithEncodedQuery", test_httpRedirectionWithEncodedQuery),
            ("test_httpRedirectionTimeout", test_httpRedirectionTimeout),
            /* ⚠️ */ ("test_httpRedirectionChainInheritsTimeoutInterval", testExpectedToFail(test_httpRedirectionChainInheritsTimeoutInterval, "Flaky on Linux CI: https://bugs.swift.org/browse/SR-14433")),
            /* ⚠️ */ ("test_httpRedirectionExceededMaxRedirects", testExpectedToFail(test_httpRedirectionExceededMaxRedirects, "Flaky on Linux CI: https://bugs.swift.org/browse/SR-14433")),
            ("test_willPerformRedirect", test_willPerformRedirect),
            ("test_httpNotFound", test_httpNotFound),
            /* ⚠️ */ ("test_http0_9SimpleResponses", testExpectedToFail(test_http0_9SimpleResponses, "Breaks on Ubunut20.04")),
            ("test_outOfRangeButCorrectlyFormattedHTTPCode", test_outOfRangeButCorrectlyFormattedHTTPCode),
            ("test_missingContentLengthButStillABody", test_missingContentLengthButStillABody),
            ("test_illegalHTTPServerResponses", test_illegalHTTPServerResponses),
            ("test_dataTaskWithSharedDelegate", test_dataTaskWithSharedDelegate),
            ("test_simpleUploadWithDelegate", test_simpleUploadWithDelegate),
            ("test_requestWithEmptyBody", test_requestWithEmptyBody),
            /* ⚠️ */ ("test_requestWithNonEmptyBody", testExpectedToFail(test_requestWithNonEmptyBody, "Started failing for no readily available reason.")),
            /* ⚠️ */ ("test_concurrentRequests", testExpectedToFail(test_concurrentRequests, "Intermittent SEGFAULT: rdar://84519512")),
            ("test_disableCookiesStorage", test_disableCookiesStorage),
            ("test_cookiesStorage", test_cookiesStorage),
            ("test_cookieStorageForEphemeralConfiguration", test_cookieStorageForEphemeralConfiguration),
            ("test_previouslySetCookiesAreSentInLaterRequests", test_previouslySetCookiesAreSentInLaterRequests),
            ("test_setCookieHeadersCanBeIgnored", test_setCookieHeadersCanBeIgnored),
            ("test_initURLSessionConfiguration", test_initURLSessionConfiguration),
            ("test_basicAuthRequest", test_basicAuthRequest),
            ("test_redirectionWithSetCookies", test_redirectionWithSetCookies),
            ("test_postWithEmptyBody", test_postWithEmptyBody),
            ("test_basicAuthWithUnauthorizedHeader", test_basicAuthWithUnauthorizedHeader),
            ("test_checkErrorTypeAfterInvalidateAndCancel", test_checkErrorTypeAfterInvalidateAndCancel),
            ("test_taskCountAfterInvalidateAndCancel", test_taskCountAfterInvalidateAndCancel),
            ("test_sessionDelegateAfterInvalidateAndCancel", test_sessionDelegateAfterInvalidateAndCancel),
            /* ⚠️ */ ("test_getAllTasks", testExpectedToFail(test_getAllTasks, "This test causes later ones to crash")),
            /* ⚠️ */ ("test_getTasksWithCompletion", testExpectedToFail(test_getTasksWithCompletion, "Flaky tests")),
            /* ⚠️ */ ("test_invalidResumeDataForDownloadTask",
            /* ⚠️ */   testExpectedToFail(test_invalidResumeDataForDownloadTask, "This test crashes nondeterministically: https://bugs.swift.org/browse/SR-11353")),
            /* ⚠️ */ ("test_simpleUploadWithDelegateProvidingInputStream",
            /* ⚠️ */   testExpectedToFail(test_simpleUploadWithDelegateProvidingInputStream, "This test times out frequently: https://bugs.swift.org/browse/SR-11343")),
            /* ⚠️ */ ("test_noDoubleCallbackWhenCancellingAndProtocolFailsFast",
            /* ⚠️ */      testExpectedToFail(test_noDoubleCallbackWhenCancellingAndProtocolFailsFast, "This test crashes nondeterministically: https://bugs.swift.org/browse/SR-11310")),
            /* ⚠️ */ ("test_cancelledTasksCannotBeResumed", testExpectedToFail(test_cancelledTasksCannotBeResumed, "Breaks on Ubuntu 18.04")),
        ]
        #if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
        if #available(macOS 12.0, *) {
            retVal.append(contentsOf: [
                ("test_webSocket", asyncTest(test_webSocket)),
                ("test_webSocketSpecificProtocol", asyncTest(test_webSocketSpecificProtocol)),
                ("test_webSocketAbruptClose", asyncTest(test_webSocketAbruptClose)),
                ("test_webSocketSemiAbruptClose", asyncTest(test_webSocketSemiAbruptClose)),
            ])
        }
        #endif
        #if os(Windows)
            retVal.append(contentsOf: [
                ("test_httpTimeout", test_httpTimeout),
                ("test_connectTimeout", test_connectTimeout),
                ("test_repeatedRequestsStress", testExpectedToFail(test_repeatedRequestsStress, "Crashes with high probability")),
            ])
        #else
        retVal.append(contentsOf: [
            ("test_httpTimeout", test_httpTimeout),
            ("test_connectTimeout", test_connectTimeout),
        ])
        #endif
        return retVal
    }
    
}

class SharedDelegate: NSObject {
    var dataCompletionExpectation: XCTestExpectation!
}

extension SharedDelegate: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        dataCompletionExpectation.fulfill()
    }
}

extension SharedDelegate: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    }
}


class SessionDelegate: NSObject, URLSessionDelegate, URLSessionWebSocketDelegate {
    var expectation: XCTestExpectation! = nil
    var session: URLSession! = nil
    var task: URLSessionTask! = nil
    var cancelExpectation: XCTestExpectation? = nil
    var invalidateExpectation: XCTestExpectation? = nil

    // Callbacks
    typealias ChallengeHandler = (URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?)
    var challengeHandler: ChallengeHandler? = nil

    typealias RedirectionHandler = (HTTPURLResponse, URLRequest, @escaping (URLRequest?) -> Void) -> Void
    var redirectionHandler: RedirectionHandler? = nil

    typealias NewBodyStreamHandler = (@escaping (InputStream?) -> Void) -> Void
    var newBodyStreamHandler: NewBodyStreamHandler? = nil


    private(set) var receivedData: Data?
    private(set) var error: Error?
    private(set) var response: URLResponse?
    private(set) var redirectionRequest: URLRequest?
    private(set) var redirectionResponse: HTTPURLResponse?
    private(set) var totalBytesSent: Int64 = 0
    private(set) var callbacks: [String] = []
    private(set) var authenticationChallenges: [URLAuthenticationChallenge] = []


    init(with expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    override init() {
        invalidateExpectation = nil
        super.init()
    }

    init(invalidateExpectation: XCTestExpectation) {
        self.invalidateExpectation = invalidateExpectation
    }

    func run(with url: URL, timeoutInterval: Double = 3) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: url)
        task.resume()
    }

    func run(with request: URLRequest, timeoutInterval: Double = 3) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: request)
        task.resume()
    }

    func runUploadTask(with request: URLRequest, timeoutInterval: Double = 3) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session.uploadTask(withStreamedRequest: request)
        task.resume()
    }
    
    func runWebSocketTask(with request: URLRequest, timeoutInterval: Double = 3, protocols: [String] = []) -> URLSessionWebSocketTask {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let webSocketTask: URLSessionWebSocketTask
        if protocols.isEmpty {
            webSocketTask = session.webSocketTask(with: request)
        } else {
            webSocketTask = session.webSocketTask(with: request.url!, protocols: protocols)
        }
        task = webSocketTask
        task.resume()
        return webSocketTask
    }
        
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        callbacks.append(#function)
        self.error = error
        invalidateExpectation?.fulfill()
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        callbacks.append(#function)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        callbacks.append(#function)
    }
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        callbacks.append(#function)
    }
}

extension SessionDelegate: URLSessionTaskDelegate {

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        callbacks.append(#function)
        self.error = error
        expectation.fulfill()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if callbacks.last != #function {
            callbacks.append(#function)
        }
        self.totalBytesSent = totalBytesSent
    }

    // New Body Stream
    public func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        callbacks.append(#function)

        if let handler = newBodyStreamHandler {
            handler(completionHandler)
        }
    }

    // HTTP Authentication Challenge
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        callbacks.append(#function)
        authenticationChallenges.append(challenge)

        if let handler = challengeHandler {
            let (disposition, credentials) = handler(challenge)
            completionHandler(disposition, credentials)
        }
    }

    // HTTP Redirect
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        callbacks.append(#function)
        redirectionRequest = request
        redirectionResponse = response

        if let handler = redirectionHandler {
            handler(response, request, completionHandler)
        } else {
            completionHandler(request)
        }
    }
}

extension SessionDelegate: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if callbacks.last != #function {
            callbacks.append(#function)
        }
        if receivedData == nil {
            receivedData = data
        } else {
            receivedData!.append(data)
        }
    }


    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        callbacks.append(#function)

        self.response = response
        completionHandler(.allow)
    }
}


class DataTask : NSObject {
    let syncQ = dispatchQueueMake("org.swift.TestFoundation.TestURLSession.DataTask.syncQ")
    let dataTaskExpectation: XCTestExpectation!
    let protocols: [AnyClass]?

    /* all the following var _XYZ need to be synchronized on syncQ.
       We can't just assert that we're on main thread here as we're modified in the URLSessionDataDelegate extension
       for DataTask
     */
    var _capital = "unknown"
    var capital: String {
        get {
            return self.syncQ.sync { self._capital }
        }
        set {
            self.syncQ.sync { self._capital = newValue }
        }
    }
    var _session: URLSession! = nil
    var session: URLSession! {
        get {
            return self.syncQ.sync { self._session }
        }
        set {
            self.syncQ.sync { self._session = newValue }
        }
    }
    var _task: URLSessionDataTask! = nil
    var task: URLSessionDataTask! {
        get {
            return self.syncQ.sync { self._task }
        }
        set {
            self.syncQ.sync { self._task = newValue }
        }
    }
    var _cancelExpectation: XCTestExpectation?
    var cancelExpectation: XCTestExpectation? {
        get {
            return self.syncQ.sync { self._cancelExpectation }
        }
        set {
            self.syncQ.sync { self._cancelExpectation = newValue }
        }
    }
    var _responseReceivedExpectation: XCTestExpectation?
    var responseReceivedExpectation: XCTestExpectation? {
        get {
            return self.syncQ.sync { self._responseReceivedExpectation }
        }
        set {
            self.syncQ.sync { self._responseReceivedExpectation = newValue }
        }
    }
    
    private var _error = false
    public var error: Bool {
        get {
            return self.syncQ.sync { self._error }
        }
        set {
            self.syncQ.sync { self._error = newValue }
        }
    }
    
    init(with expectation: XCTestExpectation, protocolClasses: [AnyClass]? = nil) {
        dataTaskExpectation = expectation
        protocols = protocolClasses
    }
    
    func run(with request: URLRequest) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        if let customProtocols = protocols {
            config.protocolClasses = customProtocols
        }
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: request)
        task.resume()
    }
    
    func run(with url: URL) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        if let customProtocols = protocols {
            config.protocolClasses = customProtocols
        }
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: url)
        task.resume()
    }
    
    func cancel() {
        task.cancel()
    }
}

extension DataTask : URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        capital = String(data: data, encoding: .utf8)!
    }

    public func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let expectation = responseReceivedExpectation {
            expectation.fulfill()
        }
        completionHandler(.allow)
    }
}

extension DataTask : URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        dataTaskExpectation.fulfill()
        guard (error as? URLError) != nil else { return }
        if let cancellation = cancelExpectation {
            cancellation.fulfill()
        }
        self.error = true
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge:
        URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition,
        URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(user: "user", password: "passwd", persistence: .none))
    }
}

class DownloadTask : NSObject {
    var totalBytesWritten: Int64 = 0
    var didDownloadExpectation: XCTestExpectation?
    let didCompleteExpectation: XCTestExpectation
    var session: URLSession! = nil
    var task: URLSessionDownloadTask! = nil
    var errorExpectation: ((Error) -> Void)?
    weak var testCase: XCTestCase?
    var expectationsDescription: String
    
    init(testCase: XCTestCase, description: String) {
        self.expectationsDescription = description
        self.testCase = testCase
        self.didCompleteExpectation = testCase.expectation(description: "Did complete \(description)")
    }
    
    private func makeDownloadExpectation() {
        guard didDownloadExpectation == nil else { return }
        self.didDownloadExpectation = testCase!.expectation(description: "Did finish download: \(description)")
        self.testCase = nil // No need for it any more here.
    }
    
    func run(with url: URL) {
        makeDownloadExpectation()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session.downloadTask(with: url)
        task.resume()
    }
    
    func run(with urlRequest: URLRequest) {
        makeDownloadExpectation()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session.downloadTask(with: urlRequest)
        task.resume()
    }
    
    struct Configuration {
        var task: URLSessionDownloadTask
        var errorExpectation: ((Error) -> Void)?
    }
    
    func run(configuration: (URLSession) -> Configuration) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let taskConfiguration = configuration(session)
        
        task = taskConfiguration.task
        errorExpectation = taskConfiguration.errorExpectation
        if errorExpectation == nil {
            makeDownloadExpectation()
        }
        task.resume()
    }
}

extension DownloadTask : URLSessionDownloadDelegate {
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) -> Void {
        self.totalBytesWritten = totalBytesWritten
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        defer { didDownloadExpectation?.fulfill() }
        
        guard self.errorExpectation == nil else {
            XCTFail("Expected an error, but got …didFinishDownloadingTo… from download task \(downloadTask) (at \(location))")
            return
        }
        
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: location.path)
            XCTAssertEqual((attr[.size]! as? NSNumber)!.int64Value, totalBytesWritten, "Size of downloaded file not equal to total bytes downloaded")
        } catch {
            XCTFail("Unable to calculate size of the downloaded file")
        }
    }
}

extension DownloadTask : URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { didCompleteExpectation.fulfill() }
        
        if let errorExpectation = self.errorExpectation {
            if let error = error {
                errorExpectation(error)
            } else {
                XCTFail("Expected an error, but got a completion without error from download task \(task)")
            }
        } else {
            guard let e = error as? URLError else { return }
            XCTAssertEqual(e.code, .timedOut, "Unexpected error code")
        }
    }
}

class FailFastProtocol: URLProtocol {
    enum Error: Swift.Error {
    case fastError
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme == "failfast"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        guard let request = task.currentRequest else { return false }
        return canInit(with: request)
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: Error.fastError)
    }

    override func stopLoading() {
        // Intentionally blank
    }
}

class HTTPRedirectionDataTask: NSObject {
    let dataTaskExpectation: XCTestExpectation!
    var session: URLSession! = nil
    var task: URLSessionDataTask! = nil
    var cancelExpectation: XCTestExpectation?
    private(set) var receivedData = Data()
    private(set) var error: Error?
    private(set) var response: URLResponse?
    private(set) var redirectionResponse: HTTPURLResponse?
    private var callbacks: [String] = []

    init(with expectation: XCTestExpectation) {
        dataTaskExpectation = expectation
    }
    
    func run(with request: URLRequest) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: request)
        task.resume()
    }
    
    func run(with url: URL) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session.dataTask(with: url)
        task.resume()
    }
    
    func cancel() {
        task.cancel()
    }

    var callbackCount: Int { callbacks.count }

    func callback(_ idx: Int) -> String? {
        guard idx < callbacks.count else { return nil }
        return callbacks[idx]
    }
}

extension HTTPRedirectionDataTask: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if callbacks.last != #function {
            callbacks.append(#function)
        }
        receivedData.append(data)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        callbacks.append(#function)

        self.response = response
        completionHandler(.allow)
    }
}

extension HTTPRedirectionDataTask: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        callbacks.append(#function)
        dataTaskExpectation.fulfill()

        if let cancellation = cancelExpectation {
            cancellation.fulfill()
        }
        self.error = error
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        callbacks.append(#function)
        redirectionResponse = response

        if let url = response.url, url.path.hasSuffix("/redirect-with-default-port") {
            XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1/redirected-with-default-port")
            // Don't follow the redirect as the test server is not running on port 80
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
}

class HTTPUploadDelegate: NSObject {
    private(set) var callbacks: [String] = []

    var uploadCompletedExpectation: XCTestExpectation!
    var totalBytesSent: Int64 = 0
}

extension HTTPUploadDelegate: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        callbacks.append(#function)
        uploadCompletedExpectation.fulfill()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if callbacks.last != #function {
            callbacks.append(#function)
        }
        self.totalBytesSent = totalBytesSent
    }
}

extension HTTPUploadDelegate: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        callbacks.append(#function)
    }
}
