// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

// Protocol implementation of data: URL scheme

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import SwiftFoundation
#else
import Foundation
#endif


// Iterate through a SubString validating that the input is ASCII and converting any %xx
// percent endcoded hex sequences to a UInt8 byte.
private struct _PercentDecoder: IteratorProtocol {

    enum Element {
        case asciiCharacter(Character)
        case decodedByte(UInt8)
        case invalid                    // Not ASCII or hex encoded
    }

    private let subString: Substring
    private var currentIndex: String.Index
    var remainingString: Substring { subString[currentIndex...] }


    init(subString: Substring) {
        self.subString = subString
        currentIndex = subString.startIndex
    }

    mutating private func nextChar() -> Character? {
        guard currentIndex < subString.endIndex else { return nil }
        let ch = subString[currentIndex]
        currentIndex = subString.index(after: currentIndex)
        return ch
    }

    mutating func next() -> _PercentDecoder.Element? {
        guard let ch = nextChar() else { return nil }

        guard let asciiValue = ch.asciiValue else { return .invalid }

        guard asciiValue == UInt8(ascii: "%") else {
            return .asciiCharacter(ch)
        }

        // Decode the %xx value
        guard let hiNibble = nextChar(), hiNibble.isASCII,
            let hiNibbleValue = hiNibble.hexDigitValue else {
                return .invalid
        }

        guard let loNibble = nextChar(), loNibble.isASCII,
            let loNibbleValue = loNibble.hexDigitValue else {
                return .invalid
        }
        let byte = UInt8(hiNibbleValue) << 4 | UInt8(loNibbleValue)
        return .decodedByte(byte)
    }
}


internal class _DataURLProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme == "data"
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        return task.currentRequest?.url?.scheme == "data"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let urlClient = self.client else { fatalError("No URLProtocol client set") }

        if let (response, decodedData) = decodeURI() {
            urlClient.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            urlClient.urlProtocol(self, didLoad: decodedData)
            urlClient.urlProtocolDidFinishLoading(self)
        } else {
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
            if let task = self.task, let session = task.actualSession, let delegate = task.delegate {
                delegate.urlSession(session, task: task, didCompleteWithError: error)
            }
        }
    }


    private func decodeURI() -> (URLResponse, Data)? {
        guard let url = self.request.url else {
            return nil
        }
        let dataBody = url.absoluteString
        guard dataBody.hasPrefix("data:") else {
            return nil
        }

        let startIdx = dataBody.index(dataBody.startIndex, offsetBy: 5)
        var iterator = _PercentDecoder(subString: dataBody[startIdx...])

        var mimeType: String?
        var charSet: String?
        var base64 = false

        // Simple validation that the mime type has only one '/' and its not at the start or end.
        func validate(mimeType: String) -> Bool {
            if mimeType.hasPrefix("/") { return false }
            var count = 0
            var lastChar: Character!

            for ch in mimeType {
                if ch == "/" { count += 1 }
                if count > 1 { return false }
                lastChar = ch
            }
            guard count == 1 else { return false }
            return lastChar != "/"
        }

        // Determine optional mime type, optional charset and whether ;base64 flag is just before a comma.
        func decodeHeader() -> Bool {
            let defaultMimeType = "text/plain"

            var part = ""
            var foundCharsetKey = false

             while let element = iterator.next() {
                switch element {
                    case .asciiCharacter(let ch) where ch == Character(","):
                        // ";base64 must be the last part just before the ',' that separates the header from the data
                        if foundCharsetKey {
                            charSet = part
                        } else {
                            base64 = (part == ";base64")
                        }
                        if mimeType == nil || !validate(mimeType: mimeType!) {
                            mimeType = defaultMimeType
                        }
                        return true


                    case .asciiCharacter(let ch) where ch == Character(";"):
                        // First item is the mimeType if there is a '/' in the string
                        if mimeType == nil {
                            if part.contains("/") {
                                mimeType = part
                            } else {
                                mimeType = defaultMimeType // default value
                            }
                        }
                        if foundCharsetKey {
                            charSet = part
                            foundCharsetKey = false
                        }
                        part = ";"

                    case .asciiCharacter(let ch) where ch == Character("="):
                        if mimeType == nil {
                            mimeType = defaultMimeType
                        } else if part == ";charset" && charSet == nil {
                            foundCharsetKey = true
                            part = ""
                        }

                    case .asciiCharacter(let ch):
                        part += String(ch)

                    case .decodedByte(_), .invalid:
                        // Dont allow percent encoded bytes in the header.
                        return false
                }
            }
            // No comma found.
            return false
        }

        // Convert any percent encoding to bytes then pass the whole String to be Base64 decoded.
        // Let the Base64 decoder take care of input validation.
        func decodeBase64Body() -> Data? {
            var base64encoded = ""
            base64encoded.reserveCapacity(iterator.remainingString.count)

            while let element = iterator.next() {
                switch element {
                    case .asciiCharacter(let ch):
                        base64encoded += String(ch)

                    case .decodedByte(let value) where UnicodeScalar(value).isASCII:
                        base64encoded += String(Character(UnicodeScalar(value)))

                    default: return nil
                }
            }
            return Data(base64Encoded: base64encoded)
        }

        // Convert any percent encoding to bytes and append to a `Data` instance. The bytes may
        // be valid in the specified charset in the header and not necessarily UTF-8.
        func decodeStringBody() -> Data? {
            var data = Data()
            data.reserveCapacity(iterator.remainingString.count)

            while let ch = iterator.next() {
                switch ch {
                    case .asciiCharacter(let ch): data.append(ch.asciiValue!)
                    case .decodedByte(let value): data.append(value)
                    default: return nil
                }
            }
            return data
        }

        guard decodeHeader() else { return nil }
        guard let decodedData = base64 ? decodeBase64Body() : decodeStringBody() else {
            return nil
        }

        let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: decodedData.count, textEncodingName: charSet)
        return (response, decodedData)
    }

    // Nothing to do here.
    override func stopLoading() {
    }
}
