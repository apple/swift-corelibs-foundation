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

#if os(Windows)
import WinSDK
#elseif canImport(Android)
import Android
#endif

public struct HTTPCookiePropertyKey : RawRepresentable, Equatable, Hashable, Sendable {
    public private(set) var rawValue: String
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension HTTPCookiePropertyKey {
    /// Key for cookie name
    public static let name = HTTPCookiePropertyKey(rawValue: "Name")

    /// Key for cookie value
    public static let value = HTTPCookiePropertyKey(rawValue: "Value")

    /// Key for cookie origin URL
    public static let originURL = HTTPCookiePropertyKey(rawValue: "OriginURL")

    /// Key for cookie version
    public static let version = HTTPCookiePropertyKey(rawValue: "Version")

    /// Key for cookie domain
    public static let domain = HTTPCookiePropertyKey(rawValue: "Domain")

    /// Key for cookie path
    public static let path = HTTPCookiePropertyKey(rawValue: "Path")

    /// Key for cookie secure flag
    public static let secure = HTTPCookiePropertyKey(rawValue: "Secure")

    /// Key for cookie expiration date
    public static let expires = HTTPCookiePropertyKey(rawValue: "Expires")

    /// Key for cookie comment text
    public static let comment = HTTPCookiePropertyKey(rawValue: "Comment")

    /// Key for cookie comment URL
    public static let commentURL = HTTPCookiePropertyKey(rawValue: "CommentURL")

    /// Key for cookie discard (session-only) flag
    public static let discard = HTTPCookiePropertyKey(rawValue: "Discard")

    /// Key for cookie maximum age (an alternate way of specifying the expiration)
    public static let maximumAge = HTTPCookiePropertyKey(rawValue: "Max-Age")

    /// Key for cookie ports
    public static let port = HTTPCookiePropertyKey(rawValue: "Port")

    // For Cocoa compatibility
    internal static let created = HTTPCookiePropertyKey(rawValue: "Created")
}

internal extension HTTPCookiePropertyKey {
    static let httpOnly = HTTPCookiePropertyKey(rawValue: "HttpOnly")

    static private let _setCookieAttributes: [String: HTTPCookiePropertyKey] = {
        // Only some attributes are valid in the Set-Cookie header.
        let validProperties: [HTTPCookiePropertyKey] = [
            .expires, .maximumAge, .domain, .path, .secure, .comment,
            .commentURL, .discard, .port, .version, .httpOnly
        ]
        let canonicalNames = validProperties.map { $0.rawValue.lowercased() }
        return Dictionary(uniqueKeysWithValues: zip(canonicalNames, validProperties))
    }()

    init?(attributeName: String) {
        let canonical = attributeName.lowercased()
        switch HTTPCookiePropertyKey._setCookieAttributes[canonical] {
        case let property?: self = property
        case nil: return nil
        }
    }
}

/// `HTTPCookie` represents an http cookie.
///
/// An `HTTPCookie` instance represents a single http cookie. It is
/// an immutable object initialized from a dictionary that contains
/// the various cookie attributes. It has accessors to get the various
/// attributes of a cookie.
open class HTTPCookie : NSObject, @unchecked Sendable {

    let _comment: String?
    let _commentURL: URL?
    let _domain: String
    let _expiresDate: Date?
    let _HTTPOnly: Bool
    let _secure: Bool
    let _sessionOnly: Bool
    let _name: String
    let _path: String
    let _portList: [NSNumber]?
    let _value: String
    let _version: Int
    let _properties: [HTTPCookiePropertyKey : Any]

    // See: https://tools.ietf.org/html/rfc2616#section-3.3.1

    // Sun, 06 Nov 1994 08:49:37 GMT  ; RFC 822, updated by RFC 1123
    static let _formatter1: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss O"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter
    }()

    // Sun Nov  6 08:49:37 1994       ; ANSI C's asctime() format
    static let _formatter2: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter
    }()

    // Sun, 06-Nov-1994 08:49:37 GMT  ; Tomcat servers sometimes return cookies in this format
    static let _formatter3: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd-MMM-yyyy HH:mm:ss O"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter
    }()

    static let _allFormatters: [DateFormatter]
        = [_formatter1, _formatter2, _formatter3]

    /// Initialize a HTTPCookie object with a dictionary of parameters
    ///
    /// - Parameter properties: The dictionary of properties to be used to
    /// initialize this cookie.
    ///
    /// Supported dictionary keys and value types for the
    /// given dictionary are as follows.
    ///
    /// All properties can handle an NSString value, but some can also
    /// handle other types.
    ///
    /// <table border=1 cellspacing=2 cellpadding=4>
    /// <tr>
    ///     <th>Property key constant</th>
    ///     <th>Type of value</th>
    ///     <th>Required</th>
    ///     <th>Description</th>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.comment</td>
    ///     <td>NSString</td>
    ///     <td>NO</td>
    ///     <td>Comment for the cookie. Only valid for version 1 cookies and
    ///     later. Default is nil.</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.commentURL</td>
    ///     <td>NSURL or NSString</td>
    ///     <td>NO</td>
    ///     <td>Comment URL for the cookie. Only valid for version 1 cookies
    ///     and later. Default is nil.</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.domain</td>
    ///     <td>NSString</td>
    ///     <td>Special, a value for either .originURL or
    ///     HTTPCookiePropertyKey.domain must be specified.</td>
    ///     <td>Domain for the cookie. Inferred from the value for
    ///     HTTPCookiePropertyKey.originURL if not provided.</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.discard</td>
    ///     <td>NSString</td>
    ///     <td>NO</td>
    ///     <td>A string stating whether the cookie should be discarded at
    ///     the end of the session. String value must be either "TRUE" or
    ///     "FALSE". Default is "FALSE", unless this is cookie is version
    ///     1 or greater and a value for HTTPCookiePropertyKey.maximumAge is not
    ///     specified, in which case it is assumed "TRUE".</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.expires</td>
    ///     <td>NSDate or NSString</td>
    ///     <td>NO</td>
    ///     <td>Expiration date for the cookie. Used only for version 0
    ///     cookies. Ignored for version 1 or greater.</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.maximumAge</td>
    ///     <td>NSString</td>
    ///     <td>NO</td>
    ///     <td>A string containing an integer value stating how long in
    ///     seconds the cookie should be kept, at most. Only valid for
    ///     version 1 cookies and later. Default is "0".</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.name</td>
    ///     <td>NSString</td>
    ///     <td>YES</td>
    ///     <td>Name of the cookie</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.originURL</td>
    ///     <td>NSURL or NSString</td>
    ///     <td>Special, a value for either HTTPCookiePropertyKey.originURL or
    ///     HTTPCookiePropertyKey.domain must be specified.</td>
    ///     <td>URL that set this cookie. Used as default for other fields
    ///     as noted.</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.path</td>
    ///     <td>NSString</td>
    ///     <td>YES</td>
    ///     <td>Path for the cookie</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.port</td>
    ///     <td>NSString</td>
    ///     <td>NO</td>
    ///     <td>comma-separated integer values specifying the ports for the
    ///     cookie. Only valid for version 1 cookies and later. Default is
    ///     empty string ("").</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.secure</td>
    ///     <td>NSString</td>
    ///     <td>NO</td>
    ///     <td>A string stating whether the cookie should be transmitted
    ///     only over secure channels. String value must be either "TRUE"
    ///     or "FALSE". Default is "FALSE".</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.value</td>
    ///     <td>NSString</td>
    ///     <td>YES</td>
    ///     <td>Value of the cookie</td>
    /// </tr>
    /// <tr>
    ///     <td>HTTPCookiePropertyKey.version</td>
    ///     <td>NSString</td>
    ///     <td>NO</td>
    ///     <td>Specifies the version of the cookie. Must be either "0" or
    ///     "1". Default is "0".</td>
    /// </tr>
    /// </table>
    ///
    /// All other keys are ignored.
    ///
    /// - Returns: An initialized `HTTPCookie`, or nil if the set of
    /// dictionary keys is invalid, for example because a required key is
    /// missing, or a recognized key maps to an illegal value.
    ///
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation as a suitable alternative
    /// - Note: Since this API is under consideration it may be either removed or revised in the near future
    public init?(properties: [HTTPCookiePropertyKey : Any]) {
        func stringValue(_ strVal: Any?) -> String? {
            if let subStr = strVal as? Substring {
                return String(subStr)
            }
            return strVal as? String
        }
        guard
            let path = stringValue(properties[.path]),
            let name = stringValue(properties[.name]),
            let value = stringValue(properties[.value])
        else {
            return nil
        }

        let canonicalDomain: String
        if let domain = properties[.domain] as? String {
            canonicalDomain = domain
        } else if
            let originURL = properties[.originURL] as? URL,
            let host = originURL.host
        {
            canonicalDomain = host
        } else {
            return nil
        }

        _path = path
        _name = name
        _value = value
        _domain = canonicalDomain.lowercased()

        if let
            secureString = properties[.secure] as? String, !secureString.isEmpty
        {
            _secure = true
        } else {
            _secure = false
        }

        let version: Int
        if let
            versionString = properties[.version] as? String, versionString == "1"
        {
            version = 1
        } else {
            version = 0
        }
        _version = version

        if let portString = properties[.port] as? String {
            let portList = portString.split(separator: ",")
                .compactMap { Int(String($0)) }
                .map { NSNumber(value: $0) }
            if version == 1 {
                _portList = portList
            } else {
                // Version 0 only stores a single port number
                _portList = portList.count > 0 ? [portList[0]] : nil
            }
        } else {
            _portList = nil
        }

        var expDate: Date? = nil
        // Maximum-Age is preferred over expires-Date but only version 1 cookies use Maximum-Age
        if let maximumAge = properties[.maximumAge] as? String,
            let secondsFromNow = Int(maximumAge) {
            if version == 1 {
                expDate = Date(timeIntervalSinceNow: Double(secondsFromNow))
            }
        } else {
            let expiresProperty = properties[.expires]
            if let date = expiresProperty as? Date {
                expDate = date
            } else if let dateString = expiresProperty as? String {
                let results = HTTPCookie._allFormatters.compactMap { $0.date(from: dateString) }
                expDate = results.first
            }
        }
        _expiresDate = expDate

        if let discardString = properties[.discard] as? String {
            _sessionOnly = discardString == "TRUE"
        } else {
            _sessionOnly = properties[.maximumAge] == nil && version >= 1
        }

        _comment = properties[.comment] as? String
        if let commentURL = properties[.commentURL] as? URL {
            _commentURL = commentURL
        } else if let commentURL = properties[.commentURL] as? String {
            _commentURL = URL(string: commentURL)
        } else {
            _commentURL = nil
        }

        if let httpOnlyString = properties[.httpOnly] as? String {
            _HTTPOnly = httpOnlyString == "TRUE"
        } else {
            _HTTPOnly = false
        }

        var props : [HTTPCookiePropertyKey : Any] = [
            .created : Date().timeIntervalSinceReferenceDate, // Cocoa Compatibility
            .discard : _sessionOnly,
            .domain : _domain,
            .name : _name,
            .path : _path,
            .secure : _secure,
            .value : _value,
            .version : _version
        ]
        if let comment = properties[.comment] {
            props[.comment] = comment
        }
        if let commentURL = properties[.commentURL] {
            props[.commentURL] = commentURL
        }
        if let expires = properties[.expires] {
            props[.expires] = expires
        }
        if let maximumAge = properties[.maximumAge] {
            props[.maximumAge] = maximumAge
        }
        if let originURL = properties[.originURL] {
            props[.originURL] = originURL
        }
        if let _portList = _portList {
            props[.port] = _portList
        }
        _properties = props
    }

    /// Return a dictionary of header fields that can be used to add the
    /// specified cookies to the request.
    ///
    /// - Parameter cookies: The cookies to turn into request headers.
    /// - Returns: A dictionary where the keys are header field names, and the values
    /// are the corresponding header field values.
    open class func requestHeaderFields(with cookies: [HTTPCookie]) -> [String : String] {
        var cookieString = cookies.reduce("") { (sum, next) -> String in
            return sum + "\(next._name)=\(next._value); "
        }
        //Remove the final trailing semicolon and whitespace
        if ( cookieString.length > 0 ) {
            cookieString.removeLast()
            cookieString.removeLast()
        }
        if cookieString == "" {
            return [:]
        } else {
            return ["Cookie": cookieString]
        }
    }

    /// Return an array of cookies parsed from the specified response header fields and URL.
    ///
    /// This method will ignore irrelevant header fields so
    /// you can pass a dictionary containing data other than cookie data.
    /// - Parameter headerFields: The response header fields to check for cookies.
    /// - Parameter URL: The URL that the cookies came from - relevant to how the cookies are interpreted.
    /// - Returns: An array of HTTPCookie objects
    open class func cookies(withResponseHeaderFields headerFields: [String : String], for URL: URL) -> [HTTPCookie] {

        // HTTP Cookie parsing based on RFC 6265: https://tools.ietf.org/html/rfc6265
        // Though RFC6265 suggests that multiple cookies cannot be folded into a single Set-Cookie field, this is
        // pretty common. It also suggests that commas and semicolons among other characters, cannot be a part of
        // names and values. This implementation takes care of multiple cookies in the same field, however it doesn't   
        // support commas and semicolons in names and values(except for dates)

        guard let cookies: String = headerFields["Set-Cookie"]  else { return [] }

        var httpCookies: [HTTPCookie] = []

        // Let's do old school parsing, which should allow us to handle the
        // embedded commas correctly.
        var idx: String.Index = cookies.startIndex
        let end: String.Index = cookies.endIndex
        while idx < end {
            // Skip leading spaces.
            while idx < end && cookies[idx].isSpace {
                idx = cookies.index(after: idx)
            }
            let cookieStartIdx: String.Index = idx
            var cookieEndIdx: String.Index = idx

            while idx < end {
                // Scan to the next comma, but check that the comma is not a
                // legal comma in a value, by looking ahead for the token,
                // which indicates the comma was separating cookies.
                let cookiesRest = cookies[idx..<end]
                if let commaIdx = cookiesRest.firstIndex(of: ",") {
                    // We are looking for WSP* TOKEN_CHAR+ WSP* '='
                    var lookaheadIdx = cookies.index(after: commaIdx)
                    // Skip whitespace
                    while lookaheadIdx < end && cookies[lookaheadIdx].isSpace {
                        lookaheadIdx = cookies.index(after: lookaheadIdx)
                    }
                    // Skip over the token characters
                    var tokenLength = 0
                    while lookaheadIdx < end && cookies[lookaheadIdx].isTokenCharacter {
                        lookaheadIdx = cookies.index(after: lookaheadIdx)
                        tokenLength += 1
                    }
                    // Skip whitespace
                    while lookaheadIdx < end && cookies[lookaheadIdx].isSpace {
                        lookaheadIdx = cookies.index(after: lookaheadIdx)
                    }
                    // Check there was a token, and there's an equals.
                    if lookaheadIdx < end && cookies[lookaheadIdx] == "=" && tokenLength > 0 {
                        // We found a token after the comma, this is a cookie
                        // separator, and not an embedded comma.
                        idx = cookies.index(after: commaIdx)
                        cookieEndIdx = commaIdx
                        break
                    }
                    // Otherwise, keep scanning from the comma.
                    idx = cookies.index(after: commaIdx)
                    cookieEndIdx = idx
                } else {
                    // No more commas, skip to the end.
                    idx = end
                    cookieEndIdx = end
                    break
                }
            }

            if cookieEndIdx <= cookieStartIdx {
                continue
            }

            if let aCookie = createHttpCookie(url: URL, cookie: String(cookies[cookieStartIdx..<cookieEndIdx])) {
                httpCookies.append(aCookie)
            }
        }

        return httpCookies
    }

    //Bake a cookie
    private class func createHttpCookie(url: URL, cookie: String) -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey : Any] = [:]
        let scanner = Scanner(string: cookie)

        guard let nameValuePair = scanner.scanUpToString(";") else {
            // if the scanner does not read anything, there's no cookie
            return nil
        }

        guard case (let name?, let value?) = splitNameValue(nameValuePair) else {
            return nil
        }

        properties[.name] = name
        properties[.value] = value
        properties[.originURL] = url

        while scanner.scanString(";") != nil {
            if let attribute = scanner.scanUpToString(";") {
                switch splitNameValue(attribute) {
                case (nil, _):
                    // ignore empty attribute names
                    break
                case (let name?, nil):
                    switch HTTPCookiePropertyKey(attributeName: name) {
                    case .secure?:
                        properties[.secure] = "TRUE"
                    case .discard?:
                        properties[.discard] = "TRUE"
                    case .httpOnly?:
                        properties[.httpOnly] = "TRUE"
                    default:
                        // ignore unknown attributes
                        break
                    }
                case (let name?, let value?):
                    switch HTTPCookiePropertyKey(attributeName: name) {
                    case .comment?:
                        properties[.comment] = value
                    case .commentURL?:
                        properties[.commentURL] = value
                    case .domain?:
                        properties[.domain] = value
                    case .maximumAge?:
                        properties[.maximumAge] = value
                    case .path?:
                        properties[.path] = value
                    case .port?:
                        properties[.port] = value
                    case .version?:
                        properties[.version] = value
                    case .expires?:
                        properties[.expires] = value
                    default:
                        // ignore unknown attributes
                        break
                    }
                }
            }
        }

        if let domain = properties[.domain] as? String {
            // The provided domain string has to be prepended with a dot,
            // because the domain field indicates that it can be sent
            // subdomains of the domain (but only if it is not an IP address).
            if (!domain.hasPrefix(".") && !isIPv4Address(domain)) {
                properties[.domain] = ".\(domain)"
            }
        } else {
            // If domain wasn't provided, extract it from the URL. No dots in
            // this case, only exact matching.
            properties[.domain] = url.host
        }
        // Always lowercase the domain.
        if let domain = properties[.domain] as? String {
            properties[.domain] = domain.lowercased()
        }

        // the default Path is "/"
        if let path = properties[.path] as? String, path.first == "/" {
            // do nothing
        } else {
            properties[.path] = "/"
        }

        return HTTPCookie(properties: properties)
    }

    private class func splitNameValue(_ pair: String) -> (name: String?, value: String?) {
        let scanner = Scanner(string: pair)

        guard let name = scanner.scanUpToString("=")?.trim(),
              !name.isEmpty else {
            // if the scanner does not read anything, or the trimmed name is
            // empty, there's no name=value
            return (nil, nil)
        }

        guard scanner.scanString("=") != nil else {
            // if the scanner does not find =, there's no value
            return (name, nil)
        }

        let location = scanner.scanLocation
        let value = String(pair[pair.index(pair.startIndex, offsetBy: location)..<pair.endIndex]).trim()

        return (name, value)
    }

    private class func isIPv4Address(_ string: String) -> Bool {
        var x = in_addr()
        return inet_pton(AF_INET, string, &x) == 1
    }

    /// Returns a dictionary representation of the receiver.
    ///
    /// This method returns a dictionary representation of the
    /// `HTTPCookie` which can be saved and passed to
    /// `init(properties:)` later to reconstitute an equivalent cookie.
    ///
    /// See the `HTTPCookie` `init(properties:)` method for
    /// more information on the constraints imposed on the dictionary, and
    /// for descriptions of the supported keys and values.
    ///
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation as a suitable alternative
    /// - Note: Since this API is under consideration it may be either removed or revised in the near future
    open var properties: [HTTPCookiePropertyKey : Any]? {
        return _properties
    }

    /// The version of the receiver.
    ///
    /// Version 0 maps to "old-style" Netscape cookies.
    /// Version 1 maps to RFC2965 cookies. There may be future versions.
    open var version: Int {
        return _version
    }

    /// The name of the receiver.
    open var name: String {
        return _name
    }

    /// The value of the receiver.
    open var value: String {
        return _value
    }

    /// Returns The expires date of the receiver.
    ///
    /// The expires date is the date when the cookie should be
    /// deleted. The result will be nil if there is no specific expires
    /// date. This will be the case only for *session-only* cookies.
    /*@NSCopying*/ open var expiresDate: Date? {
        return _expiresDate
    }

    /// Whether the receiver is session-only.
    ///
    /// `true` if this receiver should be discarded at the end of the
    /// session (regardless of expiration date), `false` if receiver need not
    /// be discarded at the end of the session.
    open var isSessionOnly: Bool {
        return _sessionOnly
    }

    /// The domain of the receiver.
    ///
    /// This value specifies URL domain to which the cookie
    /// should be sent. A domain with a leading dot means the cookie
    /// should be sent to subdomains as well, assuming certain other
    /// restrictions are valid. See RFC 2965 for more detail.
    open var domain: String {
        return _domain
    }
    
    /// The path of the receiver.
    ///
    /// This value specifies the URL path under the cookie's
    /// domain for which this cookie should be sent. The cookie will also
    /// be sent for children of that path, so `"/"` is the most general.
    open var path: String {
        return _path
    }
   
    /// Whether the receiver should be sent only over secure channels
    ///
    /// Cookies may be marked secure by a server (or by a javascript).
    /// Cookies marked as such must only be sent via an encrypted connection to
    /// trusted servers (i.e. via SSL or TLS), and should not be delivered to any
    /// javascript applications to prevent cross-site scripting vulnerabilities. 
    open var isSecure: Bool {
        return _secure
    }

    /// Whether the receiver should only be sent to HTTP servers per RFC 2965
    ///
    /// Cookies may be marked as HTTPOnly by a server (or by a javascript).
    /// Cookies marked as such must only be sent via HTTP Headers in HTTP Requests
    /// for URL's that match both the path and domain of the respective Cookies.
    /// Specifically these cookies should not be delivered to any javascript
    /// applications to prevent cross-site scripting vulnerabilities.
    open var isHTTPOnly: Bool {
        return _HTTPOnly
    }

    /// The comment of the receiver.
    ///
    /// This value specifies a string which is suitable for
    /// presentation to the user explaining the contents and purpose of this
    /// cookie. It may be nil.
    open var comment: String? {
        return _comment
    }

    /// The comment URL of the receiver.
    ///
    /// This value specifies a URL which is suitable for
    /// presentation to the user as a link for further information about
    /// this cookie. It may be nil.
    /*@NSCopying*/ open var commentURL: URL? {
        return _commentURL
    }

    /// The list ports to which the receiver should be sent.
    ///
    /// This value specifies an NSArray of NSNumbers
    /// (containing integers) which specify the only ports to which this
    /// cookie should be sent.
    ///
    /// The array may be nil, in which case this cookie can be sent to any
    /// port.
    open var portList: [NSNumber]? {
        return _portList
    }

    open override var description: String {
        var str = "<\(type(of: self)) "
        str += "version:\(self._version) name:\"\(self._name)\" value:\"\(self._value)\" expiresDate:"
        if let expires = self._expiresDate {
            str += "\(expires)"
        } else {
            str += "nil"
        }
        str += " sessionOnly:\(self._sessionOnly) domain:\"\(self._domain)\" path:\"\(self._path)\" isSecure:\(self._secure) comment:"
        if let comments = self._comment {
            str += "\(comments)"
        } else {
            str += "nil"
        }
        str += " ports:{ "
        if let ports = self._portList {
            str += "\(NSArray(array: (ports)).componentsJoined(by: ","))"
        } else {
            str += "0"
        }
        str += " }>"
        return str
    }
}

//utils for cookie parsing
fileprivate extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

fileprivate extension Character {
    var isSpace: Bool {
        return self == " " || self == "\t" || self == "\n" || self == "\r"
    }

    var isTokenCharacter: Bool {
        guard let asciiValue = self.asciiValue else {
            return false
        }

        // CTL, 0-31 and DEL (127)
        if asciiValue <= 31 || asciiValue >= 127 {
            return false
        }

        let nonTokenCharacters = "()<>@,;:\\\"/[]?={} \t"
        return !nonTokenCharacters.contains(self)
    }
}
