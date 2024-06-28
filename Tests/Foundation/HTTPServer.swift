// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


// This is a very rudimentary HTTP server written plainly for testing URLSession.
// It listens for connections and then processes each client connection in a Dispatch
// queue using async().

import Dispatch

#if canImport(CRT)
    import CRT
    import WinSDK
#elseif canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Android)
    import Android
#endif

#if !os(Windows)
typealias SOCKET = Int32
#endif

#if os(OpenBSD)
let INADDR_LOOPBACK = 0x7f000001
#endif

private let serverDebug = (ProcessInfo.processInfo.environment["SCLF_HTTP_SERVER_DEBUG"] == "YES")

private func debugLog(_ msg: String) {
    if serverDebug {
        NSLog(msg)
    }
}

public let globalDispatchQueue = DispatchQueue.global()
public let dispatchQueueMake: (String) -> DispatchQueue = { DispatchQueue.init(label: $0) }
public let dispatchGroupMake: () -> DispatchGroup = DispatchGroup.init

struct _HTTPUtils {
    static let CRLF = "\r\n"
    static let VERSION = "HTTP/1.1"
    static let SPACE = " "
    static let CRLF2 = CRLF + CRLF
    static let EMPTY = ""
}

extension UInt16 {
    public init(networkByteOrder input: UInt16) {
        self.init(bigEndian: input)
    }
}

// _TCPSocket wraps one socket that is used either to listen()/accept() new connections, or for the client connection itself.
class _TCPSocket: CustomStringConvertible {
#if !os(Windows)
    #if os(Linux) || os(Android) || os(FreeBSD)
    private let sendFlags = CInt(MSG_NOSIGNAL)
#else
    private let sendFlags = CInt(0)
    #endif
#endif

    var description: String {
        return "_TCPSocket @ 0x" + String(unsafeBitCast(self, to: UInt.self), radix: 16)
    }

    let listening: Bool
    private var _socket: SOCKET!
    private var socketAddress = UnsafeMutablePointer<sockaddr_in>.allocate(capacity: 1)
    public private(set) var port: UInt16

    private func isNotNegative(r: CInt) -> Bool {
        return r != -1
    }

    private func isZero(r: CInt) -> Bool {
        return r == 0
    }

    private func attempt<T>(_ name: String, file: String = #file, line: UInt = #line, valid: (T) -> Bool,  _ b: @autoclosure () -> T) throws -> T {
        let r = b()
        guard valid(r) else {
            throw ServerError(operation: name, errno: errno, file: file, line: line)
        }
        return r
    }


    init(socket: SOCKET) {
        _socket = socket
        self.port = 0
        listening = false
    }

    init(port: UInt16?, backlog: Int32) throws {
        listening = true
        self.port = 0

#if os(Windows)
        _socket = try attempt("WSASocketW", valid: { $0 != INVALID_SOCKET }, WSASocketW(AF_INET, SOCK_STREAM, IPPROTO_TCP.rawValue, nil, 0, DWORD(WSA_FLAG_OVERLAPPED)))

        var value: Int8 = 1
        _ = try attempt("setsockopt", valid: { $0 == 0 }, setsockopt(_socket, SOL_SOCKET, SO_REUSEADDR, &value, Int32(MemoryLayout.size(ofValue: value))))
#else
#if os(Linux) && !os(Android)
        let SOCKSTREAM = Int32(SOCK_STREAM.rawValue)
#else
        let SOCKSTREAM = SOCK_STREAM
#endif
        _socket = try attempt("socket", valid: { $0 >= 0 }, socket(AF_INET, SOCKSTREAM, Int32(IPPROTO_TCP)))
        var on: CInt = 1
        _ = try attempt("setsockopt", valid: { $0 == 0 }, setsockopt(_socket, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<CInt>.size)))
#endif

        let sa = createSockaddr(port)
        socketAddress.initialize(to: sa)
        try socketAddress.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size, { 
            let addr = UnsafePointer<sockaddr>($0)
            _ = try attempt("bind", valid: isZero, bind(_socket, addr, socklen_t(MemoryLayout<sockaddr>.size)))
            _ = try attempt("listen", valid: isZero, listen(_socket, backlog))
        })

        var actualSA = sockaddr_in()
        withUnsafeMutablePointer(to: &actualSA) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { (ptr: UnsafeMutablePointer<sockaddr>) in
                var len = socklen_t(MemoryLayout<sockaddr>.size)
                getsockname(_socket, ptr, &len)
            }
        }

        self.port = UInt16(networkByteOrder: actualSA.sin_port)
    }

    private func createSockaddr(_ port: UInt16?) -> sockaddr_in {
        // Listen on the loopback address so that OSX doesnt pop up a dialog
        // asking to accept incoming connections if the firewall is enabled.
        let addr = UInt32(INADDR_LOOPBACK).bigEndian
        let netPort = UInt16(bigEndian: port ?? 0)
        #if os(Android)
            return sockaddr_in(sin_family: sa_family_t(AF_INET), sin_port: netPort, sin_addr: in_addr(s_addr: addr), __pad: (0,0,0,0,0,0,0,0))
        #elseif os(Linux)
            return sockaddr_in(sin_family: sa_family_t(AF_INET), sin_port: netPort, sin_addr: in_addr(s_addr: addr), sin_zero: (0,0,0,0,0,0,0,0))
        #elseif os(Windows)
            return sockaddr_in(sin_family: ADDRESS_FAMILY(AF_INET), sin_port: USHORT(netPort), sin_addr: IN_ADDR(S_un: in_addr.__Unnamed_union_S_un(S_addr: addr)), sin_zero: (CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0)))
        #else
            return sockaddr_in(sin_len: 0, sin_family: sa_family_t(AF_INET), sin_port: netPort, sin_addr: in_addr(s_addr: addr), sin_zero: (0,0,0,0,0,0,0,0))
        #endif
    }

    func acceptConnection() throws -> _TCPSocket {
        guard listening else { fatalError("Trying to listen on a client connection socket") }
        let connection: SOCKET = try socketAddress.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size, {
            let addr = UnsafeMutablePointer<sockaddr>($0)
            var sockLen = socklen_t(MemoryLayout<sockaddr>.size) 
#if os(Windows)
            let connectionSocket = try attempt("WSAAccept", valid: { $0 != INVALID_SOCKET }, WSAAccept(_socket, addr, &sockLen, nil, 0))
#else
            let connectionSocket = try attempt("accept", valid: { $0 >= 0 }, accept(_socket, addr, &sockLen))
#endif
#if canImport(Darwin)
            // Disable SIGPIPEs when writing to closed sockets
            var on: CInt = 1
            guard setsockopt(connectionSocket, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<CInt>.size)) == 0 else {
                close(connectionSocket)
                throw ServerError.init(operation: "setsockopt", errno: errno, file: #file, line: #line)
            }
#endif
            debugLog("\(self) acceptConnection: accepted: \(connectionSocket)")
            return connectionSocket
        })
        return _TCPSocket(socket: connection)
    }
 
    func readData() throws -> Data? {
        guard let connectionSocket = _socket else {
            throw InternalServerError.socketAlreadyClosed
        }

        var buffer = [CChar](repeating: 0, count: 4096)
#if os(Windows)
        var dwNumberOfBytesRecieved: DWORD = 0;
        try buffer.withUnsafeMutableBufferPointer {
            var wsaBuffer: WSABUF = WSABUF(len: ULONG($0.count), buf: $0.baseAddress)
            var flags: DWORD = 0
            _ = try attempt("WSARecv", valid: { $0 != SOCKET_ERROR }, WSARecv(connectionSocket, &wsaBuffer, 1, &dwNumberOfBytesRecieved, &flags, nil, nil))
        }
        let length = Int(dwNumberOfBytesRecieved)
#else
        let length = try attempt("read", valid: { $0 >= 0 }, read(connectionSocket, &buffer, buffer.count))
#endif
        guard length > 0 else { return nil }
        return Data(bytes: buffer, count: length)
    }

    func writeRawData(_ data: Data) throws {
        guard let connectionSocket = _socket else {
            throw InternalServerError.socketAlreadyClosed
        }
#if os(Windows)
        _ = try data.withUnsafeBytes {
            var dwNumberOfBytesSent: DWORD = 0
            var wsaBuffer: WSABUF = WSABUF(len: ULONG(data.count), buf: UnsafeMutablePointer<CHAR>(mutating: $0.bindMemory(to: CHAR.self).baseAddress))
            _ = try attempt("WSASend", valid: { $0 != SOCKET_ERROR }, WSASend(connectionSocket, &wsaBuffer, 1, &dwNumberOfBytesSent, 0, nil, nil))
        }
#else
        _ = try data.withUnsafeBytes { ptr in
            try attempt("send", valid: { $0 == data.count }, CInt(send(connectionSocket, ptr.baseAddress!, data.count, sendFlags)))
        }
#endif
        debugLog("wrote \(data.count) bytes")
    }

    func writeData(header: String, bodyData: Data) throws {
        var totalData = Data(header.utf8)
        totalData.append(bodyData)
        try writeRawData(totalData)
    }

    func closeSocket() throws {
        guard _socket != nil else { return }
#if os(Windows)
        if listening { shutdown(_socket, SD_BOTH) }
        closesocket(_socket)
#else
        if listening { shutdown(_socket, CInt(SHUT_RDWR)) }
        close(_socket)
#endif
        _socket = nil
    }

    deinit {
        debugLog("\(self) closing socket")
        try? closeSocket()
    }
}


class _HTTPServer: CustomStringConvertible {

    var description: String {
        return "_HTTPServer @ 0x" + String(unsafeBitCast(self, to: UInt.self), radix: 16)
    }

    // Provide Data() blocks from the socket either separated by a given separator or of a requested block size.
    struct _SocketDataReader {
        private let tcpSocket: _TCPSocket
        private var buffer = Data()

        init(socket: _TCPSocket) {
            tcpSocket = socket
        }

        mutating func readBlockSeparated(by separatorData: Data) throws -> Data {
            var range = buffer.range(of: separatorData)
            while range == nil {
                guard let data = try tcpSocket.readData() else { break }
                debugLog("read \(data.count) bytes")
                buffer.append(data)
                range = buffer.range(of: separatorData)
            }
            guard let r = range else { throw InternalServerError.requestTooShort }

            let result = buffer.prefix(upTo: r.lowerBound)
            buffer = buffer.suffix(from: r.upperBound)
            return result
        }

        mutating func readBytes(count: Int) throws -> Data {
            while buffer.count < count {
                guard let data = try tcpSocket.readData() else { break }
                debugLog("read \(data.count) bytes")
                buffer.append(data)
            }
            guard buffer.count >= count else {
                throw InternalServerError.requestTooShort
            }
            let endIndex = buffer.startIndex + count
            let result = buffer[buffer.startIndex..<endIndex]
            buffer = buffer[endIndex...]
            return result
        }
    }

    deinit {
        debugLog("_HTTPServer \(self) stopping")
    }

    let tcpSocket: _TCPSocket
    var port: UInt16 { tcpSocket.port }

    init(port: UInt16?, backlog: Int32 = SOMAXCONN) throws {
        tcpSocket = try _TCPSocket(port: port, backlog: backlog)
    }

    init(socket: _TCPSocket) {
        tcpSocket = socket
    }

    public class func create(port: UInt16?) throws -> _HTTPServer {
        return try _HTTPServer(port: port)
    }

    public func listen() throws -> _HTTPServer {
        let connection = try tcpSocket.acceptConnection()
        debugLog("\(self) accepted: \(connection)")
        return _HTTPServer(socket: connection)
    }

    public func stop() throws {
        try tcpSocket.closeSocket()
    }
    
    public func request() throws -> _HTTPRequest {

        var reader = _SocketDataReader(socket: tcpSocket)
        let headerData = try reader.readBlockSeparated(by: _HTTPUtils.CRLF2.data(using: .utf8)!)

        guard let headerString = String(bytes: headerData, encoding: .utf8) else {
            throw InternalServerError.requestTooShort
        }
        var request = try _HTTPRequest(header: headerString)

        if let contentLength = request.getHeader(for: "Content-Length"), let length = Int(contentLength), length > 0 {
            let messageData = try reader.readBytes(count: length)
            request.messageData = messageData
            request.messageBody = String(bytes: messageData, encoding: .utf8)
            return request
        }
        else if(request.getHeader(for: "Transfer-Encoding") ?? "").lowercased() == "chunked" {
            // According to RFC7230 https://tools.ietf.org/html/rfc7230#section-3
            // We receive messageBody after the headers, so we need read from socket minimum 2 times
            //
            // HTTP-message structure
            //
            // start-line
            // *( header-field CRLF )
            // CRLF
            // [ message-body ]
            // We receives '{numofbytes}\r\n{data}\r\n'

            // There maybe some part of the body in the initial data

            let bodySeparator = _HTTPUtils.CRLF.data(using: .utf8)!
            var messageData = Data()
            var finished = false

            while !finished {
                let chunkSizeData = try reader.readBlockSeparated(by: bodySeparator)
                // Should now have <num bytes>\r\n
                guard let number = String(bytes: chunkSizeData, encoding: .utf8), let chunkSize = Int(number, radix: 16) else {
                     throw InternalServerError.requestTooShort
                }
                if chunkSize == 0 {
                    finished = true
                    break
                }

                let chunkData = try reader.readBytes(count: chunkSize)
                messageData.append(chunkData)

                // Next 2 bytes should be \r\n to indicate the end of the chunk
                let endOfChunk = try reader.readBytes(count: bodySeparator.count)
                guard endOfChunk == bodySeparator else {
                    throw InternalServerError.requestTooShort
                }
            }
            request.messageData = messageData
            request.messageBody = String(bytes: messageData, encoding: .utf8)
        }

        return request
    }

    public func respond(with response: _HTTPResponse) throws {
        try tcpSocket.writeData(header: response.header, bodyData: response.bodyData)
    }

    func respondWithBrokenResponses(uri: String) throws {
        let responseData: Data
        switch uri {
            case "/LandOfTheLostCities/Pompeii":
                /* this is an example of what you get if you connect to an HTTP2
                 server using HTTP/1.1. Curl interprets that as a HTTP/0.9
                 simple-response and therefore sends this back as a response
                 body. Go figure! */
                responseData = Data([
                    0x00, 0x00, 0x18, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                    0x01, 0x00, 0x00, 0x10, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00,
                    0x01, 0x00, 0x05, 0x00, 0x00, 0x40, 0x00, 0x00, 0x06, 0x00,
                    0x00, 0x1f, 0x40, 0x00, 0x00, 0x86, 0x07, 0x00, 0x00, 0x00,
                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
                    0x48, 0x54, 0x54, 0x50, 0x2f, 0x32, 0x20, 0x63, 0x6c, 0x69,
                    0x65, 0x6e, 0x74, 0x20, 0x70, 0x72, 0x65, 0x66, 0x61, 0x63,
                    0x65, 0x20, 0x73, 0x74, 0x72, 0x69, 0x6e, 0x67, 0x20, 0x6d,
                    0x69, 0x73, 0x73, 0x69, 0x6e, 0x67, 0x20, 0x6f, 0x72, 0x20,
                    0x63, 0x6f, 0x72, 0x72, 0x75, 0x70, 0x74, 0x2e, 0x20, 0x48,
                    0x65, 0x78, 0x20, 0x64, 0x75, 0x6d, 0x70, 0x20, 0x66, 0x6f,
                    0x72, 0x20, 0x72, 0x65, 0x63, 0x65, 0x69, 0x76, 0x65, 0x64,
                    0x20, 0x62, 0x79, 0x74, 0x65, 0x73, 0x3a, 0x20, 0x34, 0x37,
                    0x34, 0x35, 0x35, 0x34, 0x32, 0x30, 0x32, 0x66, 0x33, 0x33,
                    0x32, 0x66, 0x36, 0x34, 0x36, 0x35, 0x37, 0x36, 0x36, 0x39,
                    0x36, 0x33, 0x36, 0x35, 0x32, 0x66, 0x33, 0x31, 0x33, 0x32,
                    0x33, 0x33, 0x33, 0x34, 0x33, 0x35, 0x33, 0x36, 0x33, 0x37,
                    0x33, 0x38, 0x33, 0x39, 0x33, 0x30])
            case "/LandOfTheLostCities/Sodom":
                /* a technically valid HTTP/0.9 simple-response */
                responseData = ("technically, this is a valid HTTP/0.9 " +
                    "simple-response. I know it's odd but CURL supports it " +
                    "still...\r\nFind out more in those URLs:\r\n " +
                    " - https://www.w3.org/Protocols/HTTP/1.0/spec.html#Message-Types\r\n" +
                    " - https://github.com/curl/curl/issues/467\r\n").data(using: .utf8)!
            case "/LandOfTheLostCities/Gomorrah":
                /* just broken, hope that's not officially HTTP/0.9 :p */
                responseData = "HTTP/1.1\r\n\r\n\r\n".data(using: .utf8)!
            case "/LandOfTheLostCities/Myndus":
                responseData = ("HTTP/1.1 200 OK\r\n" +
                               "\r\n" +
                               "this is a body that isn't legal as it's " +
                               "neither chunked encoding nor any Content-Length\r\n").data(using: .utf8)!
            case "/LandOfTheLostCities/Kameiros":
                responseData = ("HTTP/1.1 999 Wrong Code\r\n" +
                               "illegal: status code (too large)\r\n" +
                               "\r\n").data(using: .utf8)!
            case "/LandOfTheLostCities/Dinavar":
                responseData = ("HTTP/1.1 20 Too Few Digits\r\n" +
                               "illegal: status code (too few digits)\r\n" +
                               "\r\n").data(using: .utf8)!
            case "/LandOfTheLostCities/Kuhikugu":
                responseData = ("HTTP/1.1 2000 Too Many Digits\r\n" +
                               "illegal: status code (too many digits)\r\n" +
                               "\r\n").data(using: .utf8)!
            default:
                responseData = ("HTTP/1.1 500 Internal Server Error\r\n" +
                               "case-missing-in: TestFoundation/HTTPServer.swift\r\n" +
                               "\r\n").data(using: .utf8)!
        }
        try tcpSocket.writeRawData(responseData)
    }

    func respondWithAuthResponse(request: _HTTPRequest) throws {
        let responseData: Data
        if let auth = request.getHeader(for: "authorization"),
            auth == "Basic dXNlcjpwYXNzd2Q=" {
                responseData = ("HTTP/1.1 200 OK \r\n" +
                "Content-Length: 37\r\n" +
                "Content-Type: application/json\r\n" +
                "Access-Control-Allow-Origin: *\r\n" +
                "Access-Control-Allow-Credentials: true\r\n" +
                "Via: 1.1 vegur\r\n" +
                "Cache-Control: proxy-revalidate\r\n" +
                "Connection: keep-Alive\r\n" +
                "\r\n" +
                "{\"authenticated\":true,\"user\":\"user\"}\n").data(using: .utf8)!
        } else {
            responseData = ("HTTP/1.1 401 UNAUTHORIZED \r\n" +
                        "Content-Length: 0\r\n" +
                        "WWW-Authenticate: Basic realm=\"Fake Relam\"\r\n" +
                        "Access-Control-Allow-Origin: *\r\n" +
                        "Access-Control-Allow-Credentials: true\r\n" +
                        "Via: 1.1 vegur\r\n" +
                        "Cache-Control: proxy-revalidate\r\n" +
                        "Connection: keep-Alive\r\n" +
                        "\r\n").data(using: .utf8)!
        }
        try tcpSocket.writeRawData(responseData)
    }

    func respondWithUnauthorizedHeader() throws{
        let responseData = ("HTTP/1.1 401 UNAUTHORIZED \r\n" +
                "Content-Length: 0\r\n" +
                "Connection: keep-Alive\r\n" +
                "\r\n").data(using: .utf8)!
        try tcpSocket.writeRawData(responseData)
    }
}

struct _HTTPRequest: CustomStringConvertible {
    enum Method : String {
        case HEAD
        case GET
        case POST
        case PUT
        case DELETE
    }

    enum Error: Swift.Error {
        case invalidURI
        case invalidMethod
        case headerEndNotFound
    }

    let method: Method
    let uri: String
    private(set) var headers: [String] = []
    private(set) var parameters: [String: String] = [:]
    var messageBody: String?
    var messageData: Data?
    var description: String {
        return "\(method.rawValue) \(uri)"
    }


    public init(header: String) throws {
        self.headers = header.components(separatedBy: _HTTPUtils.CRLF)
        guard headers.count > 0 else {
            throw Error.invalidURI
        }
        let uriParts = headers[0].components(separatedBy: " ")
        guard uriParts.count > 2, let methodName = Method(rawValue: uriParts[0]) else {
            throw Error.invalidMethod
        }
        method = methodName
        let params = uriParts[1].split(separator: "?", maxSplits: 1, omittingEmptySubsequences: true)
        if params.count > 1 {
            for arg in params[1].split(separator: "&", omittingEmptySubsequences: true) {
                let keyValue = arg.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard !keyValue.isEmpty else { continue }
                guard let key = keyValue[0].removingPercentEncoding else {
                    throw Error.invalidURI
                }
                guard let value = (keyValue.count > 1) ? keyValue[1].removingPercentEncoding : "" else {
                    throw Error.invalidURI
                }
                self.parameters[key] = value
            }
        }

        self.uri = String(params[0])
    }

    public func getCommaSeparatedHeaders() -> String {
        var allHeaders = ""
        for header in headers {
            allHeaders += header + ","
        }
        return allHeaders
    }

    public func getHeader(for key: String) -> String? {
        let lookup = key.lowercased()
        for header in headers {
            let parts = header.components(separatedBy: ":")
            if parts[0].lowercased() == lookup {
                return parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " "))
            }
        }
        return nil
    }

    public func headersAsJSON() throws -> Data {
        var headerDict: [String: String] = [:]
        for header in headers {
            if header.hasPrefix(method.rawValue) {
                headerDict["uri"] = header
                continue
            }
            let parts = header.components(separatedBy: ":")
            if parts.count > 1 {
                headerDict[parts[0]] = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " "))
            }
        }

        // Include the body as a Base64 Encoded entry
        if let bodyData = messageData ?? messageBody?.data(using: .utf8) {
            headerDict["x-base64-body"] = bodyData.base64EncodedString()
        }
        return try JSONSerialization.data(withJSONObject: headerDict, options: .sortedKeys)
    }
}

struct _HTTPResponse {
    enum Response: Int {
        case SWITCHING_PROTOCOLS = 101
        case OK = 200
        case FOUND = 302
        case BAD_REQUEST = 400
        case NOT_FOUND = 404
        case METHOD_NOT_ALLOWED = 405
        case SERVER_ERROR = 500
    }


    private let responseCode: Int
    private var headers: [String]
    public let bodyData: Data

    public init(responseCode: Int, headers: [String] = [], bodyData: Data) {
        self.responseCode = responseCode
        self.headers = headers
        self.bodyData = bodyData

        for header in headers {
            if header.lowercased().hasPrefix("content-length") {
                return
            }
        }
        self.headers.append("Content-Length: \(bodyData.count)")
    }

    public init(response: Response, headers: [String] = [], bodyData: Data = Data()) {
        self.init(responseCode: response.rawValue, headers: headers, bodyData: bodyData)
    }

    public init(response: Response, headers: String = _HTTPUtils.EMPTY, bodyData: Data) {
        let headers = headers.split(separator: "\r\n").map { String($0) }
        self.init(responseCode: response.rawValue, headers: headers, bodyData: bodyData)
    }

    public init(response: Response, headers: String = _HTTPUtils.EMPTY, body: String) throws {
        guard let data = body.data(using: .utf8) else {
            throw InternalServerError.badBody
        }
        self.init(response: response, headers: headers, bodyData: data)
    }

    public init(responseCode: Int, headers: [String] = [], body: String) throws {
        guard let data = body.data(using: .utf8) else {
            throw InternalServerError.badBody
        }
        self.init(responseCode: responseCode, headers: headers, bodyData: data)
    }

    public var header: String {
        let responseCodeName = HTTPURLResponse.localizedString(forStatusCode: responseCode)
        let statusLine = _HTTPUtils.VERSION + _HTTPUtils.SPACE + "\(responseCode)" + _HTTPUtils.SPACE + "\(responseCodeName)"
        let header = headers.joined(separator: "\r\n")
        return statusLine + (header != _HTTPUtils.EMPTY ? _HTTPUtils.CRLF + header : _HTTPUtils.EMPTY) + _HTTPUtils.CRLF2
    }

    mutating func addHeader(_ header: String) {
        headers.append(header)
    }
}

public class TestURLSessionServer: CustomStringConvertible {

    public var description: String {
        return "TestURLSessionServer @ 0x" + String(unsafeBitCast(self, to: UInt.self), radix: 16)
    }

    let capitals: [String:String] = ["Nepal": "Kathmandu",
                                     "Peru": "Lima",
                                     "Italy": "Rome",
                                     "USA": "Washington, D.C.",
                                     "UnitedStates": "USA",
                                     "UnitedKingdom": "UK",
                                     "UK": "London",
                                     "country.txt": "A country is a region that is identified as a distinct national entity in political geography"]
    let httpServer: _HTTPServer

    internal init(httpServer: _HTTPServer) {
        self.httpServer = httpServer
        debugLog("\(self) - server \(httpServer)")
    }

    public func readAndRespond() throws {
        let req = try httpServer.request()
        debugLog("request: \(req)")
        if let value = req.getHeader(for: "x-pause") {
            if let wait = Double(value), wait > 0 {
                Thread.sleep(forTimeInterval: wait)
            }
        }

        if req.uri.hasPrefix("/LandOfTheLostCities/") {
            /* these are all misbehaving servers */
            try httpServer.respondWithBrokenResponses(uri: req.uri)
        } else if req.uri == "/NSString-ISO-8859-1-data.txt" {
            // Serve this directly as binary data to avoid any String encoding conversions.
            if let url = testBundle().url(forResource: "NSString-ISO-8859-1-data", withExtension: "txt"),
                let content = try? Data(contentsOf: url) {
                var responseData = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=ISO-8859-1\r\nContent-Length: \(content.count)\r\n\r\n".data(using: .utf8)!
                responseData.append(content)
                try httpServer.tcpSocket.writeRawData(responseData)
            } else {
                try httpServer.respond(with: _HTTPResponse(response: .NOT_FOUND, body: "Not Found"))
            }
        } else if req.uri.hasPrefix("/auth") {
            try httpServer.respondWithAuthResponse(request: req)
        } else if req.uri.hasPrefix("/unauthorized") {
            try httpServer.respondWithUnauthorizedHeader()
        } else if req.uri.hasPrefix("/web-socket") {
            try handleWebSocketRequest(req)
        } else {
            let response = try getResponse(request: req)
            try httpServer.respond(with: response)
            debugLog("response: \(response)")
        }
    }

    func getResponse(request: _HTTPRequest) throws -> _HTTPResponse {

        func headersAsJSONResponse() throws -> _HTTPResponse {
            return try _HTTPResponse(response: .OK, headers: ["Content-Type: application/json"], bodyData: request.headersAsJSON())
        }

        let uri = request.uri
        if uri == "/jsonBody" {
            return try headersAsJSONResponse()
        }

        if uri == "/head" {
            guard request.method == .HEAD else { return try _HTTPResponse(response: .METHOD_NOT_ALLOWED, body: "Method not allowed") }
            return try headersAsJSONResponse()
        }

        if uri == "/get" {
            guard request.method == .GET else { return try _HTTPResponse(response: .METHOD_NOT_ALLOWED, body: "Method not allowed") }
            return try headersAsJSONResponse()
        }

        if uri == "/put" {
            guard request.method == .PUT else { return try _HTTPResponse(response: .METHOD_NOT_ALLOWED, body: "Method not allowed") }
            return try headersAsJSONResponse()
        }

        if uri == "/post" {
            guard request.method == .POST else { return try _HTTPResponse(response: .METHOD_NOT_ALLOWED, body: "Method not allowed") }
            return try headersAsJSONResponse()
        }

        if uri == "/delete" {
            guard request.method == .DELETE else { return try _HTTPResponse(response: .METHOD_NOT_ALLOWED, body: "Method not allowed") }
            return try headersAsJSONResponse()
        }

        if uri.hasPrefix("/redirect/") {
            let components = uri.components(separatedBy: "/")
            if components.count >= 3, let count = Int(components[2]) {
                let newLocation = (count <= 1) ? "/jsonBody" : "/redirect/\(count - 1)"
                return try _HTTPResponse(response: .FOUND, headers: "Location: \(newLocation)", body: "Redirecting to \(newLocation)")
            }
        }

        if uri == "/upload" {
            if let contentLength = request.getHeader(for: "content-length") {
                let text = "Upload completed!, Content-Length: \(contentLength)"
                return try _HTTPResponse(response: .OK, body: text)
            }
            if let te = request.getHeader(for: "transfer-encoding"), te == "chunked" {
                return try _HTTPResponse(response: .OK, body: "Received Chunked request")
            } else {
                return try _HTTPResponse(response: .BAD_REQUEST, body: "Missing Content-Length")
            }
        }

        if uri == "/country.txt" {
            let text = capitals[String(uri.dropFirst())]!
            return try _HTTPResponse(response: .OK, body: text)
        }

        if uri == "/requestHeaders" {
            let text = request.getCommaSeparatedHeaders()
            return try _HTTPResponse(response: .OK, body: text)
        }

        if uri == "/emptyPost" {
            if request.getHeader(for: "Content-Type") == nil {
                return try _HTTPResponse(response: .OK, body: "")
            }
            return try _HTTPResponse(response: .NOT_FOUND, body: "")
        }

        if uri == "/requestCookies" {
            return try _HTTPResponse(response: .OK, headers: "Set-Cookie: fr=anjd&232; Max-Age=7776000; path=/\r\nSet-Cookie: nm=sddf&232; Max-Age=7776000; path=/; domain=.swift.org; secure; httponly\r\n", body: "")
        }

        if uri == "/echoHeaders" {
            let text = request.getCommaSeparatedHeaders()
            return try _HTTPResponse(response: .OK, headers: "Content-Length: \(text.data(using: .utf8)!.count)", body: text)
        }
        
        if uri == "/redirectToEchoHeaders" {
            return try _HTTPResponse(response: .FOUND, headers: "location: /echoHeaders\r\nSet-Cookie: redirect=true; Max-Age=7776000; path=/", body: "")
        }

        if uri == "/UnitedStates" {
            let value = capitals[String(uri.dropFirst())]!
            let text = request.getCommaSeparatedHeaders()
            let host = request.headers[1].components(separatedBy: " ")[1]
            let ip = host.components(separatedBy: ":")[0]
            let port = host.components(separatedBy: ":")[1]
            let newPort = Int(port)! + 1
            let newHost = ip + ":" + String(newPort)
            let httpResponse = try _HTTPResponse(response: .FOUND, headers: "Location: http://\(newHost + "/" + value)", body: text)
            return httpResponse 
        }

        if uri == "/DTDs/PropertyList-1.0.dtd" {
            let dtd = """
    <!ENTITY % plistObject "(array | data | date | dict | real | integer | string | true | false )" >
    <!ELEMENT plist %plistObject;>
    <!ATTLIST plist version CDATA "1.0" >

    <!-- Collections -->
    <!ELEMENT array (%plistObject;)*>
    <!ELEMENT dict (key, %plistObject;)*>
    <!ELEMENT key (#PCDATA)>

    <!--- Primitive types -->
    <!ELEMENT string (#PCDATA)>
    <!ELEMENT data (#PCDATA)> <!-- Contents interpreted as Base-64 encoded -->
    <!ELEMENT date (#PCDATA)> <!-- Contents should conform to a subset of ISO 8601 (in particular, YYYY '-' MM '-' DD 'T' HH ':' MM ':' SS 'Z'.  Smaller units may be omitted with a loss of precision) -->

    <!-- Numerical primitives -->
    <!ELEMENT true EMPTY>  <!-- Boolean constant true -->
    <!ELEMENT false EMPTY> <!-- Boolean constant false -->
    <!ELEMENT real (#PCDATA)> <!-- Contents should represent a floating point number matching ("+" | "-")? d+ ("."d*)? ("E" ("+" | "-") d+)? where d is a digit 0-9.  -->
    <!ELEMENT integer (#PCDATA)> <!-- Contents should represent a (possibly signed) integer number in base 10 -->
"""
            return try _HTTPResponse(response: .OK, body: dtd)
        }

        if uri == "/UnitedKingdom" {
            let value = capitals[String(uri.dropFirst())]!
            let text = request.getCommaSeparatedHeaders()
            //Response header with only path to the location to redirect.
            let httpResponse = try _HTTPResponse(response: .FOUND, headers: "Location: \(value)", body: text)
            return httpResponse
        }
        
        if uri == "/echo" {
            return try _HTTPResponse(response: .OK, body: request.messageBody ?? "")
        }
        
        if uri == "/redirect-with-default-port" {
            let text = request.getCommaSeparatedHeaders()
            let host = request.headers[1].components(separatedBy: " ")[1]
            let ip = host.components(separatedBy: ":")[0]
            let httpResponse = try _HTTPResponse(response: .FOUND, headers: "Location: http://\(ip)/redirected-with-default-port", body: text)
            return httpResponse

        }

        if uri == "/gzipped-response" {
            // This is "Hello World!" gzipped.
            let helloWorld = Data([0x1f, 0x8b, 0x08, 0x00, 0x6d, 0xca, 0xb2, 0x5c,
                                   0x00, 0x03, 0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x57,
                                   0x08, 0xcf, 0x2f, 0xca, 0x49, 0x51, 0x04, 0x00,
                                   0xa3, 0x1c, 0x29, 0x1c, 0x0c, 0x00, 0x00, 0x00])
            return _HTTPResponse(response: .OK,
                                 headers: ["Content-Length: \(helloWorld.count)",
                                           "Content-Encoding: gzip"].joined(separator: _HTTPUtils.CRLF),
                                 bodyData: helloWorld)
        }
        
        if uri == "/echo-query" {
            let body = request.parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            return try _HTTPResponse(response: .OK, body: body)
        }

        // Look for /xxx where xxx is a 3digit HTTP code
        if uri.hasPrefix("/") && uri.count == 4, let code = Int(String(uri.dropFirst())), code > 0 && code < 1000 {
            return try statusCodeResponse(forRequest: request, statusCode: code)
        }

        guard let capital = capitals[String(uri.dropFirst())] else {
            return _HTTPResponse(response: .NOT_FOUND)
        }
        return try _HTTPResponse(response: .OK, body: capital)
    }

    private func unmaskedPayload(from masked: Data) throws -> Data {
        if masked.count < 6 {
            throw InternalServerError.badBody
        }
        if masked.count == 6 {
            return Data()
        }
        var maskingKey: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &maskingKey) { buffer in
            masked.subdata(in: 2..<6).copyBytes(to: buffer)
        }
        var paddedMasked = masked
        var padCount = 0
        while paddedMasked.count % 4 != 2 {
            paddedMasked.append(0x00)
            padCount += 1
        }
        let maskedPayload = paddedMasked.suffix(from: 6)
        let unmaskedPayload = maskedPayload.enumerated().map { i, byte in
            let maskByte: UInt8
            switch i % 4 {
            case 3: maskByte = UInt8(maskingKey >> 24)
            case 2: maskByte = UInt8((maskingKey >> 16) & 0xFF)
            case 1: maskByte = UInt8((maskingKey >> 8) & 0xFF)
            case 0: maskByte = UInt8(maskingKey & 0xFF)
            default: fatalError()
            }
            return maskByte ^ byte
        }
        return Data(unmaskedPayload.dropLast(padCount))
    }

    func handleWebSocketRequest(_ request: _HTTPRequest) throws {
        guard request.method == .GET,
              "websocket" == request.getHeader(for: "upgrade"),
              let connectionHeader = request.getHeader(for: "connection"),
              connectionHeader.lowercased().contains("upgrade") else {
            try httpServer.respond(with: _HTTPResponse(response: .NOT_FOUND))
            return
        }
        
        var responseHeaders = ["Upgrade: websocket",
                               "Connection: Upgrade"]
        
        let expectFullRequestResponseTests: Bool
        let sendClosePacket: Bool
        let completeUpgrade: Bool
        
        let uri = request.uri
        switch uri {
        case "/web-socket":
            expectFullRequestResponseTests = true
            completeUpgrade = true
            sendClosePacket = true
        case "/web-socket/semi-abrupt-close":
            expectFullRequestResponseTests = false
            completeUpgrade = true
            sendClosePacket = false
        case "/web-socket/abrupt-close":
            expectFullRequestResponseTests = false
            completeUpgrade = false
            sendClosePacket = false
        default:
            guard uri.count > "/web-socket/".count else {
                NSLog("Expected Sec-WebSocket-Protocol")
                throw InternalServerError.badHeaders
            }
            let expectedProtocol = String(uri.suffix(from: uri.index(uri.startIndex, offsetBy: "/web-socket/".count)))
            guard let receivedProtocolStr = request.getHeader(for: "Sec-WebSocket-Protocol"),
                  expectedProtocol == receivedProtocolStr.components(separatedBy: ", ")[0] else {
                NSLog("Expected Sec-WebSocket-Protocol")
                throw InternalServerError.badHeaders
            }
            responseHeaders.append("Sec-WebSocket-Protocol: \(expectedProtocol)")
            expectFullRequestResponseTests = false
            completeUpgrade = true
            sendClosePacket = true
        }
            
        guard completeUpgrade else { return }

        var upgradeResponse = _HTTPResponse(response: .SWITCHING_PROTOCOLS, headers: responseHeaders)
        // Lacking an available SHA1 implementation, we'll only include this response for a well-known key
        if "dGhlIHNhbXBsZSBub25jZQ==" == request.getHeader(for: "sec-websocket-key") {
            upgradeResponse.addHeader("Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
        }
        
        try httpServer.respond(with: upgradeResponse)
        
        do {
            let closeCode = 1000
            let closeReason = "BuhBye".data(using: .utf8)!
            let closePayload = Data([UInt8(closeCode >> 8),
                                     UInt8(closeCode & 0xFF)]) + closeReason

            let pingPayload = "Hi".data(using: .utf8)!

            if expectFullRequestResponseTests {
                let stringPayload = "Hello".data(using: .utf8)!
                let dataPayload = Data([0x20, 0x22, 0x10, 0x03])
                
                // Receive a string message
                guard let stringFrame = try httpServer.tcpSocket.readData(),
                      stringFrame.count == (2 + 4 + stringPayload.count),
                      Data(stringFrame.prefix(2)) == Data([0x81, (0x80 | UInt8(stringPayload.count))]),
                      try unmaskedPayload(from: stringFrame) == stringPayload else {
                    NSLog("Invalid string frame")
                    throw InternalServerError.badBody
                }
                
                // Send a string message
                let sendStringFrame = Data([0x81, UInt8(stringPayload.count)]) + stringPayload
                try httpServer.tcpSocket.writeRawData(sendStringFrame)
                
                // Receive a data message
                guard let dataFrame = try httpServer.tcpSocket.readData(),
                      dataFrame.count == (2 + 4 + dataPayload.count),
                      Data(dataFrame.prefix(2)) == Data([0x82, (0x80 | UInt8(dataPayload.count))]),
                      try unmaskedPayload(from: dataFrame) == dataPayload else {
                    NSLog("Invalid data frame")
                    throw InternalServerError.badBody
                }
                
                // Send a data message
                let sendDataFrame = Data([0x82, UInt8(dataPayload.count)]) + dataPayload
                try httpServer.tcpSocket.writeRawData(sendDataFrame)
                
                // Receive a ping
                guard let pingFrame = try httpServer.tcpSocket.readData(),
                      pingFrame.count == (2 + 4 + 0),
                      Data(pingFrame.prefix(2)) == Data([0x89, 0x80]),
                      try unmaskedPayload(from: pingFrame) == Data() else {
                    NSLog("Invalid ping frame")
                    throw InternalServerError.badBody
                }
                // ... and pong it
                try httpServer.tcpSocket.writeRawData(Data([0x8a, 0x00]))
            }
            
            // Send a ping
            let sendPingFrame = Data([0x89, UInt8(pingPayload.count)]) + pingPayload
            try httpServer.tcpSocket.writeRawData(sendPingFrame)
            // ... and receive its pong
            guard let pongFrame = try httpServer.tcpSocket.readData(),
                  pongFrame.count == (2 + 4 + pingPayload.count),
                  Data(pongFrame.prefix(2)) == Data([0x8a, (0x80 | UInt8(pingPayload.count))]),
                  try unmaskedPayload(from: pongFrame) == pingPayload else {
                NSLog("Invalid pong frame")
                throw InternalServerError.badBody
            }
            
            if sendClosePacket {
                if expectFullRequestResponseTests {
                    // Send a close
                    let sendCloseFrame = Data([0x88, UInt8(closePayload.count)]) + closePayload
                    try httpServer.tcpSocket.writeRawData(sendCloseFrame)
                }

                // Receive a close message
                guard let closeFrame = try httpServer.tcpSocket.readData(),
                      closeFrame.count == (2 + 4 + closePayload.count),
                      Data(closeFrame.prefix(2)) == Data([0x88, (0x80 | UInt8(closePayload.count))]),
                      try unmaskedPayload(from: closeFrame) == closePayload else {
                    NSLog("Invalid close payload")
                    throw InternalServerError.badBody
                }
            }

        } catch {
            let badBodyCloseFrame = Data([0x88, 0x08, 0x03, 0xEA, 0x42, 0x75, 0x68, 0x42, 0x79, 0x65])
            try httpServer.tcpSocket.writeRawData(badBodyCloseFrame)
            throw error
        }
    }
    
    private func statusCodeResponse(forRequest request: _HTTPRequest, statusCode: Int) throws -> _HTTPResponse {
        guard let bodyData = try? request.headersAsJSON() else {
            return try _HTTPResponse(response: .SERVER_ERROR, body: "Cant convert headers to JSON object")
        }

        var response: _HTTPResponse
        switch statusCode {
            case 300...303, 305...308:
                let location = request.parameters["location"] ?? "/" + request.method.rawValue.lowercased()
                let body = "Redirecting to \(request.method) \(location)"
                let headers = ["Content-Type: test/plain", "Location: \(location)"]
                response = try _HTTPResponse(responseCode: statusCode, headers: headers, body: body)

            case 401:
                let headers = ["Content-Type: application/json", "Content-Length: \(bodyData.count)"]
                response = _HTTPResponse(responseCode: statusCode, headers: headers, bodyData: bodyData)
                response.addHeader("WWW-Authenticate: Basic realm=\"Fake Relam\"")

            default:
                let headers = ["Content-Type: application/json", "Content-Length: \(bodyData.count)"]
                response = _HTTPResponse(responseCode: statusCode, headers: headers, bodyData: bodyData)
                break
        }

        return response
    }
}

struct ServerError : Error {
    let operation: String
    let errno: CInt
    let file: String
    let line: UInt
    var _code: Int { return Int(errno) }
    var _domain: String { return NSPOSIXErrorDomain }
}


extension ServerError : CustomStringConvertible {
    var description: String {
        let s = String(validatingUTF8: strerror(errno)) ?? ""
        return "\(operation) failed: \(s) (\(_code))"
    }
}

enum InternalServerError : Error {
    case socketAlreadyClosed
    case requestTooShort
    case badBody
    case badHeaders
}

extension LoopbackServerTest {
    struct Options {
        var serverBacklog: Int32
        var isAsynchronous: Bool
        
        static let `default` = Options(serverBacklog: SOMAXCONN, isAsynchronous: true)
    }
}

class LoopbackServerTest : XCTestCase {
    private static let staticSyncQ = DispatchQueue(label: "org.swift.TestFoundation.HTTPServer.StaticSyncQ")

    private static var _serverPort: Int = -1
    private static var _serverActive = false
    private static var testServer: _HTTPServer? = nil
    private static var _options: Options = .default
    
    static var options: Options {
        get {
            return staticSyncQ.sync { _options }
        }
        set {
            staticSyncQ.sync { _options = newValue }
        }
    }
    
    static var serverPort: Int {
        get {
            return staticSyncQ.sync { _serverPort }
        }
        set {
            staticSyncQ.sync { _serverPort = newValue }
        }
    }

    static var serverActive: Bool {
        get { return staticSyncQ.sync { _serverActive } }
        set { staticSyncQ.sync { _serverActive = newValue }}
    }

    override class func setUp() {
        super.setUp()
        Self.startServer()
    }

    override class func tearDown() {
        Self.stopServer()
        super.tearDown()
    }
    
    static func startServer() {
        var _serverPort = 0
        let dispatchGroup = DispatchGroup()

        func runServer() throws {
            testServer = try _HTTPServer(port: nil, backlog: options.serverBacklog)
            _serverPort = Int(testServer!.port)
            serverActive = true
            dispatchGroup.leave()

            while serverActive {
                do {
                    let httpServer = try testServer!.listen()
                    
                    func handleRequest() {
                        let subServer = TestURLSessionServer(httpServer: httpServer)
                        do {
                            try subServer.readAndRespond()
                        } catch {
                            NSLog("readAndRespond: \(error)")
                        }
                    }
                    
                    if options.isAsynchronous {
                        globalDispatchQueue.async(execute: handleRequest)
                    } else {
                        handleRequest()
                    }
                } catch {
                    if (serverActive) { // Ignore errors thrown on shutdown
                        NSLog("httpServer: \(error)")
                    }
                }
            }
            serverPort = -2
        }

        dispatchGroup.enter()

        globalDispatchQueue.async {
            do {
                try runServer()
            } catch {
                NSLog("runServer: \(error)")
            }
        }

        let timeout = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 2_000_000_000)

        guard dispatchGroup.wait(timeout: timeout) == .success, _serverPort > 0 else {
            fatalError("Timedout waiting for server to be ready")
        }
        serverPort = _serverPort
        debugLog("Listening on \(serverPort)")
    }
    
    static func stopServer() {
        serverActive = false
        try? testServer?.stop()
    }
}
