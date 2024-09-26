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

/// An `URLResponse` object represents a URL load response in a
/// manner independent of protocol and URL scheme.
///
/// `URLResponse` encapsulates the metadata associated
/// with a URL load. Note that URLResponse objects do not contain
/// the actual bytes representing the content of a URL. See
/// `URLSession` for more information about receiving the content
/// data for a URL load.
open class URLResponse : NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {

    static public var supportsSecureCoding: Bool {
        return true
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        
        guard let nsurl = aDecoder.decodeObject(of: NSURL.self, forKey: "NS.url") else { return nil }
        self.url = nsurl as URL
        
        if let mimetype = aDecoder.decodeObject(of: NSString.self, forKey: "NS.mimeType") {
            self.mimeType = mimetype as String
        }
        
        self.expectedContentLength = aDecoder.decodeInt64(forKey: "NS.expectedContentLength")
        
        if let encodedEncodingName = aDecoder.decodeObject(of: NSString.self, forKey: "NS.textEncodingName") {
            self.textEncodingName = encodedEncodingName as String
        }
        
        // re-sanitizing with lastPathComponent because of supportsSecureCoding
        if let encodedFilename = aDecoder.decodeObject(of: NSString.self, forKey: "NS.suggestedFilename")?.lastPathComponent, !encodedFilename.isEmpty {
            self.suggestedFilename = encodedFilename
        } else {
            self.suggestedFilename = "Unknown"
        }
    }
    
    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        
        aCoder.encode(self.url?._bridgeToObjectiveC(), forKey: "NS.url")
        aCoder.encode(self.mimeType?._bridgeToObjectiveC(), forKey: "NS.mimeType")
        aCoder.encode(self.expectedContentLength, forKey: "NS.expectedContentLength")
        aCoder.encode(self.textEncodingName?._bridgeToObjectiveC(), forKey: "NS.textEncodingName")
        aCoder.encode(self.suggestedFilename?._bridgeToObjectiveC(), forKey: "NS.suggestedFilename")
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
    
    /// Initialize an URLResponse with the provided values.
    ///
    /// This is the designated initializer for URLResponse.
    /// - Parameter URL: the URL
    /// - Parameter mimeType: the MIME content type of the response
    /// - Parameter expectedContentLength: the expected content length of the associated data
    /// - Parameter textEncodingName the name of the text encoding for the associated data, if applicable, else nil
    /// - Returns: The initialized URLResponse.
    public init(url: URL, mimeType: String?, expectedContentLength length: Int, textEncodingName name: String?) {
        self.url = url
        self.mimeType = mimeType
        self.expectedContentLength = Int64(length)
        self.textEncodingName = name
        let c = url.lastPathComponent
        self.suggestedFilename = c.isEmpty ? "Unknown" : c
    }
    
    /// The URL of the receiver.
    /*@NSCopying*/ open private(set) var url: URL?

    
    /// The MIME type of the receiver.
    ///
    /// The MIME type is based on the information provided
    /// from an origin source. However, that value may be changed or
    /// corrected by a protocol implementation if it can be determined
    /// that the origin server or source reported the information
    /// incorrectly or imprecisely. An attempt to guess the MIME type may
    /// be made if the origin source did not report any such information.
    open fileprivate(set) var mimeType: String?
    
    /// The expected content length of the receiver.
    ///
    /// Some protocol implementations report a content length
    /// as part of delivering load metadata, but not all protocols
    /// guarantee the amount of data that will be delivered in actuality.
    /// Hence, this method returns an expected amount. Clients should use
    /// this value as an advisory, and should be prepared to deal with
    /// either more or less data.
    ///
    /// The expected content length of the receiver, or `-1` if
    /// there is no expectation that can be arrived at regarding expected
    /// content length.
    open fileprivate(set) var expectedContentLength: Int64
    
    /// The name of the text encoding of the receiver.
    ///
    /// This name will be the actual string reported by the
    /// origin source during the course of performing a protocol-specific
    /// URL load. Clients can inspect this string and convert it to an
    /// NSStringEncoding or CFStringEncoding using the methods and
    /// functions made available in the appropriate framework.
    open fileprivate(set) var textEncodingName: String?
    
    /// A suggested filename if the resource were saved to disk.
    ///
    /// The method first checks if the server has specified a filename
    /// using the content disposition header. If no valid filename is
    /// specified using that mechanism, this method checks the last path
    /// component of the URL. If no valid filename can be obtained using
    /// the last path component, this method uses the URL's host as the
    /// filename. If the URL's host can't be converted to a valid
    /// filename, the filename "unknown" is used. In mose cases, this
    /// method appends the proper file extension based on the MIME type.
    ///
    /// This method always returns a valid filename.
    open fileprivate(set) var suggestedFilename: String?

    open override func isEqual(_ value: Any?) -> Bool {
        switch value {
        case let other as URLResponse:
            return self.isEqual(to: other)
        default:
            return false
        }
    }

    private func isEqual(to other: URLResponse) -> Bool {
        if self === other {
            return true
        }

        return self.url == other.url &&
                self.expectedContentLength == other.expectedContentLength &&
                self.mimeType == other.mimeType &&
                self.textEncodingName == other.textEncodingName
    }

    open override var hash: Int {
        var hasher = Hasher()
        hasher.combine(url)
        hasher.combine(expectedContentLength)
        hasher.combine(mimeType)
        hasher.combine(textEncodingName)
        return hasher.finalize()
    }
}

/// A Response to an HTTP URL load.
///
/// An HTTPURLResponse object represents a response to an
/// HTTP URL load. It is a specialization of URLResponse which
/// provides conveniences for accessing information specific to HTTP
/// protocol responses.
open class HTTPURLResponse : URLResponse, @unchecked Sendable {
    
    private static func sanitize(headerFields: [String: String]?) -> [String: String] {
        // Canonicalize the header fields by capitalizing the field names, but not X- Headers
        // This matches the behaviour of Darwin.
        guard let headerFields = headerFields else { return [:] }
        var canonicalizedFields: [String: String] = [:]
        
        for (key, value) in headerFields  {
            if key.isEmpty { continue }
            if key.hasPrefix("x-") || key.hasPrefix("X-") {
                canonicalizedFields[key] = value
            } else if key.caseInsensitiveCompare("WWW-Authenticate") == .orderedSame {
                canonicalizedFields["WWW-Authenticate"] = value
            } else {
                canonicalizedFields[key.capitalized] = value
            }
        }
        return canonicalizedFields
    }
    
    /// Initializer for HTTPURLResponse objects.
    ///
    /// - Parameter url: the URL from which the response was generated.
    /// - Parameter statusCode: an HTTP status code.
    /// - Parameter httpVersion: The version of the HTTP response as represented by the server.  This is typically represented as "HTTP/1.1".
    /// - Parameter headerFields: A dictionary representing the header keys and values of the server response.
    /// - Returns: the instance of the object, or `nil` if an error occurred during initialization.
    public init?(url: URL, statusCode: Int, httpVersion: String?, headerFields: [String : String]?) {
        self.statusCode = statusCode
        
        self._allHeaderFields = HTTPURLResponse.sanitize(headerFields: headerFields)
        
        super.init(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        expectedContentLength = getExpectedContentLength(fromHeaderFields: _allHeaderFields) ?? -1
        suggestedFilename = getSuggestedFilename(fromHeaderFields: _allHeaderFields) ?? "Unknown"
        if let type = ContentTypeComponents(headerFields: _allHeaderFields) {
            mimeType = type.mimeType.lowercased()
            textEncodingName = type.textEncoding?.lowercased()
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        
        self.statusCode = aDecoder.decodeInteger(forKey: "NS.statusCode")
        
        // re-sanitizing dictionary because of supportsSecureCoding
        self._allHeaderFields = HTTPURLResponse.sanitize(headerFields: aDecoder.decodeObject(of: NSDictionary.self, forKey: "NS.allHeaderFields") as? [String: String])
        
        super.init(coder: aDecoder)
        
        // re-sanitizing from _allHeaderFields because of supportsSecureCoding
        expectedContentLength = getExpectedContentLength(fromHeaderFields: _allHeaderFields) ?? -1
        suggestedFilename = getSuggestedFilename(fromHeaderFields: _allHeaderFields) ?? "Unknown"
        if let type = ContentTypeComponents(headerFields: _allHeaderFields) {
            mimeType = type.mimeType.lowercased()
            textEncodingName = type.textEncoding?.lowercased()
        }
    }
    
    open override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder) //Will fail if .allowsKeyedCoding == false
        
        aCoder.encode(self.statusCode, forKey: "NS.statusCode")
        aCoder.encode(self.allHeaderFields as NSDictionary, forKey: "NS.allHeaderFields")
        
    }
    
    /// The HTTP status code of the receiver.
    public let statusCode: Int
    
    /// Returns a dictionary containing all the HTTP header fields
    /// of the receiver.
    ///
    /// By examining this header dictionary, clients can see
    /// the "raw" header information which was reported to the protocol
    /// implementation by the HTTP server. This may be of use to
    /// sophisticated or special-purpose HTTP clients.
    ///
    /// - Returns: A dictionary containing all the HTTP header fields of the
    /// receiver.
    ///
    /// - Important: This is an *experimental* change from the
    /// `[NSObject: AnyObject]` type that Darwin Foundation uses.
    private let _allHeaderFields: [String: String]
    public var allHeaderFields: [AnyHashable : Any] {
        _allHeaderFields as [AnyHashable : Any]
    }

    public func value(forHTTPHeaderField field: String) -> String? {
        return valueForCaseInsensitiveKey(field, fields: _allHeaderFields)
    }

    /// Convenience method which returns a localized string
    /// corresponding to the status code for this response.
    /// - Parameter forStatusCode: the status code to use to produce a localized string.
    open class func localizedString(forStatusCode statusCode: Int) -> String {
        switch statusCode {
        case 100: return "Continue"
        case 101: return "Switching Protocols"
        case 102: return "Processing"
        case 100...199: return "Informational"
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 203: return "Non-Authoritative Information"
        case 204: return "No Content"
        case 205: return "Reset Content"
        case 206: return "Partial Content"
        case 207: return "Multi-Status"
        case 208: return "Already Reported"
        case 226: return "IM Used"
        case 200...299: return "Success"
        case 300: return "Multiple Choices"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 303: return "See Other"
        case 304: return "Not Modified"
        case 305: return "Use Proxy"
        case 307: return "Temporary Redirect"
        case 308: return "Permanent Redirect"
        case 300...399: return "Redirection"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 402: return "Payment Required"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 406: return "Not Acceptable"
        case 407: return "Proxy Authentication Required"
        case 408: return "Request Timeout"
        case 409: return "Conflict"
        case 410: return "Gone"
        case 411: return "Length Required"
        case 412: return "Precondition Failed"
        case 413: return "Payload Too Large"
        case 414: return "URI Too Long"
        case 415: return "Unsupported Media Type"
        case 416: return "Range Not Satisfiable"
        case 417: return "Expectation Failed"
        case 421: return "Misdirected Request"
        case 422: return "Unprocessable Entity"
        case 423: return "Locked"
        case 424: return "Failed Dependency"
        case 426: return "Upgrade Required"
        case 428: return "Precondition Required"
        case 429: return "Too Many Requests"
        case 431: return "Request Header Fields Too Large"
        case 451: return "Unavailable For Legal Reasons"
        case 400...499: return "Client Error"
        case 500: return "Internal Server Error"
        case 501: return "Not Implemented"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
        case 505: return "HTTP Version Not Supported"
        case 506: return "Variant Also Negotiates"
        case 507: return "Insufficient Storage"
        case 508: return "Loop Detected"
        case 510: return "Not Extended"
        case 511: return "Network Authentication Required"
        case 500...599: return "Server Error"
        default: return "Server Error"
        }
    }

    /// A string that represents the contents of the HTTPURLResponse Object.
    /// This property is intended to produce readable output.
    override open var description: String {
        var result = "<\(type(of: self)) \(Unmanaged.passUnretained(self).toOpaque())> { URL: \(url!.absoluteString) }{ status: \(statusCode), headers {\n"
        for key in _allHeaderFields.keys.sorted() {
            guard let value = _allHeaderFields[key] else { continue }
            if((key.lowercased() == "content-disposition" && suggestedFilename != "Unknown") || key.lowercased() == "content-type") {
                result += "   \"\(key)\" = \"\(value)\";\n"
            } else {
                result += "   \"\(key)\" = \(value);\n"
            }
        }
        result += "} }"
        return result
    }
}

/// Parses the expected content length from the headers.
///
/// Note that the message content length is different from the message
/// transfer length.
/// The transfer length can only be derived when the Transfer-Encoding is identity (default).
/// For compressed content (Content-Encoding other than identity), there is not way to derive the
/// content length from the transfer length.
private func getExpectedContentLength(fromHeaderFields headerFields: [String : String]?) -> Int64? {
    guard
        let f = headerFields,
        let contentLengthS = valueForCaseInsensitiveKey("content-length", fields: f),
        let contentLength = Int64(contentLengthS)
        else { return nil }
    return contentLength
}
/// Parses the suggested filename from the `Content-Disposition` header.
///
/// - SeeAlso: [RFC 2183](https://tools.ietf.org/html/rfc2183)
private func getSuggestedFilename(fromHeaderFields headerFields: [String : String]?) -> String? {
    // Typical use looks like this:
    //     Content-Disposition: attachment; filename="fname.ext"
    guard
        let f = headerFields,
        let contentDisposition = valueForCaseInsensitiveKey("content-disposition", fields: f),
        let field = contentDisposition.httpHeaderParts
        else { return nil }
    for part in field.parameters where part.attribute == "filename" {
        if let path = part.value {
            return (path as NSString).pathComponents.map{ $0 == "/" ? "" : $0}.joined(separator: "_")
        } else {
            return nil
        }
    }
    return nil
}
/// Parts corresponding to the `Content-Type` header field in a HTTP message.
private struct ContentTypeComponents : Sendable {
    /// For `text/html; charset=ISO-8859-4` this would be `text/html`
    let mimeType: String
    /// For `text/html; charset=ISO-8859-4` this would be `ISO-8859-4`. Will be
    /// `nil` when no `charset` is specified.
    let textEncoding: String?
}
extension ContentTypeComponents {
    /// Parses the `Content-Type` header field
    ///
    /// `Content-Type: text/html; charset=ISO-8859-4` would result in `("text/html", "ISO-8859-4")`, while
    /// `Content-Type: text/html` would result in `("text/html", nil)`.
    init?(headerFields: [String : String]?) {
        guard
            let f = headerFields,
            let contentType = valueForCaseInsensitiveKey("content-type", fields: f),
            let field = contentType.httpHeaderParts
            else { return nil }
        for parameter in field.parameters where parameter.attribute == "charset" {
            self.mimeType = field.value
            self.textEncoding = parameter.value
            return
        }
        self.mimeType = field.value
        self.textEncoding = nil
    }
}

/// A type with parameters
///
/// RFC 2616 specifies a few types that can have parameters, e.g. `Content-Type`.
/// These are specified like so
/// ```
/// field          = value *( ";" parameter )
/// value          = token
/// ```
/// where parameters are attribute/value as specified by
/// ```
/// parameter               = attribute "=" value
/// attribute               = token
/// value                   = token | quoted-string
/// ```
private struct ValueWithParameters : Sendable {
    let value: String
    let parameters: [Parameter]
    struct Parameter : Sendable {
        let attribute: String
        let value: String?
    }
}

private extension String {
    /// Split the string at each ";", remove any quoting.
    /// 
    /// The trouble is if there's a
    /// ";" inside something that's quoted. And we can escape the separator and
    /// the quotes with a "\".
    var httpHeaderParts: ValueWithParameters? {
        var type: String?
        var parameters: [ValueWithParameters.Parameter] = []
        let ws = CharacterSet.whitespaces
        func append(_ string: String) {
            if type == nil {
                type = string
            } else {
                if let r = string.range(of: "=") {
                    let name = String(string[string.startIndex..<r.lowerBound]).trimmingCharacters(in: ws)
                    let value = String(string[r.upperBound..<string.endIndex]).trimmingCharacters(in: ws)
                    parameters.append(ValueWithParameters.Parameter(attribute: name, value: value))
                } else {
                    let name = string.trimmingCharacters(in: ws)
                    parameters.append(ValueWithParameters.Parameter(attribute: name, value: nil))
                }
            }
        }
        
        let escape = UnicodeScalar(0x5c)!    //  \
        let quote = UnicodeScalar(0x22)!     //  "
        let separator = UnicodeScalar(0x3b)! //  ;
        enum State : Sendable {
            case nonQuoted(String)
            case nonQuotedEscaped(String)
            case quoted(String)
            case quotedEscaped(String)
        }
        var state = State.nonQuoted("")
        for next in unicodeScalars {
            switch (state, next) {
            case (.nonQuoted(let s), separator):
                append(s)
                state = .nonQuoted("")
            case (.nonQuoted(let s), escape):
                state = .nonQuotedEscaped(s + String(next))
            case (.nonQuoted(let s), quote):
                state = .quoted(s)
            case (.nonQuoted(let s), _):
                state = .nonQuoted(s + String(next))
                
            case (.nonQuotedEscaped(let s), _):
                state = .nonQuoted(s + String(next))
                
            case (.quoted(let s), quote):
                state = .nonQuoted(s)
            case (.quoted(let s), escape):
                state = .quotedEscaped(s + String(next))
            case (.quoted(let s), _):
                state = .quoted(s + String(next))
            
            case (.quotedEscaped(let s), _):
                state = .quoted(s + String(next))
            }
        }
        switch state {
            case .nonQuoted(let s): append(s)
            case .nonQuotedEscaped(let s): append(s)
            case .quoted(let s): append(s)
            case .quotedEscaped(let s): append(s)
        }
        guard let t = type else { return nil }
        return ValueWithParameters(value: t, parameters: parameters)
    }
}
private func valueForCaseInsensitiveKey(_ key: String, fields: [String: String]) -> String? {
    let kk = key.lowercased()
    for (k, v) in fields {
        if k.lowercased() == kk {
            return v
        }
    }
    return nil
}
