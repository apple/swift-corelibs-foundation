// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if !os(Windows)
//This is a very rudimentary FTP server written plainly for testing URLSession FTP Implementation.
import Dispatch

#if canImport(Glibc)
    import Glibc
#elseif canImport(Darwin)
    import Darwin
#elseif canImport(Android)
    import Android
#endif

final class ServerSemaphore : Sendable {
    let dispatchSemaphore = DispatchSemaphore(value: 0)

    func wait(timeout: DispatchTime) -> DispatchTimeoutResult {
        return dispatchSemaphore.wait(timeout: timeout)
    }

    func signal() {
        dispatchSemaphore.signal()
    }
}

class _FTPSocket {

    private var listenSocket: Int32!
    private var socketAddress = UnsafeMutablePointer<sockaddr_in>.allocate(capacity: 1)
    private var socketAddress1 = UnsafeMutablePointer<sockaddr_in>.allocate(capacity: 1)
    private var connectionSocket: Int32!
    var dataSocket: Int32! // data socket for communication
    var dataSocketPort: UInt16! // data socket port, should be sent as part of header
    private func isNotMinusOne(r: CInt) -> Bool {
        return r != -1
    }

    private func isZero(r: CInt) -> Bool {
        return r == 0
    }

    private func attempt(_ name: String, file: String = #file, line: UInt = #line, valid: (CInt) -> Bool,  _ b: @autoclosure () -> CInt) throws -> CInt {
        let r = b()
        guard valid(r) else { throw ServerError(operation: name, errno: r, file: file, line: line) }
        return r
    }

    init(port: UInt16) throws {
        #if os(Linux)
            let SOCKSTREAM = Int32(SOCK_STREAM.rawValue)
        #else
            let SOCKSTREAM = SOCK_STREAM
        #endif
        listenSocket = try attempt("socket", valid: isNotMinusOne, socket(AF_INET, SOCKSTREAM, Int32(IPPROTO_TCP)))
        var on: Int = 1
        _ = try attempt("setsockopt", valid: isZero, setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int>.size)))
        let sa = createSockaddr(port)
        socketAddress.initialize(to: sa)
        try socketAddress.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size, {
            let addr = UnsafePointer<sockaddr>($0)
            _ = try attempt("bind", valid: isZero, bind(listenSocket, addr, socklen_t(MemoryLayout<sockaddr>.size)))
        })

        dataSocket = try attempt("socket", valid: isNotMinusOne,
                                 socket(AF_INET, SOCKSTREAM, Int32(IPPROTO_TCP)))
        var on1: Int = 1
        _ = try attempt("setsockopt", valid: isZero,
                        setsockopt(dataSocket, SOL_SOCKET, SO_REUSEADDR, &on1, socklen_t(MemoryLayout<Int>.size)))
        let sa1 = createSockaddr(port+1)
        socketAddress1.initialize(to: sa1)
        try socketAddress1.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size, {
            nonisolated(unsafe) let addr = UnsafeMutablePointer<sockaddr>($0)
            _ = try attempt("bind", valid: isZero, bind(dataSocket, addr, socklen_t(MemoryLayout<sockaddr>.size)))
            _ = try attempt("listen", valid: isZero, listen(dataSocket, SOMAXCONN))
            // Open the data port asynchronously. Port should be opened before ESPV header communication.
            nonisolated(unsafe) let nonisolatedSelf = self
            DispatchQueue(label: "delay").async {
                do {
                    var sockLen = socklen_t(MemoryLayout<sockaddr>.size)
                    nonisolatedSelf.dataSocket = try nonisolatedSelf.attempt("accept", valid: nonisolatedSelf.isNotMinusOne, accept(nonisolatedSelf.dataSocket, addr, &sockLen))
                    nonisolatedSelf.dataSocketPort = sa1.sin_port
                } catch {
		     NSLog("Could not open data port.")
                }
            }
        })
    }

    private func createSockaddr(_ port: UInt16) -> sockaddr_in {
        // Listen on the loopback address so that OSX doesnt pop up a dialog
        // asking to accept incoming connections if the firewall is enabled.
        let addr = UInt32(INADDR_LOOPBACK).bigEndian
        let netPort = port.bigEndian
        #if os(Linux)
            return sockaddr_in(sin_family: sa_family_t(AF_INET), sin_port: netPort, sin_addr: in_addr(s_addr: addr), sin_zero: (0,0,0,0,0,0,0,0))
        #elseif os(Android)
            return sockaddr_in(sin_family: sa_family_t(AF_INET), sin_port: netPort, sin_addr: in_addr(s_addr: addr), __pad: (0,0,0,0,0,0,0,0))
        #else
            return sockaddr_in(sin_len: 0, sin_family: sa_family_t(AF_INET), sin_port: netPort, sin_addr: in_addr(s_addr: addr), sin_zero: (0,0,0,0,0,0,0,0))
        #endif
    }
 
    func acceptConnection(notify: ServerSemaphore) throws {
        _ = try attempt("listen", valid: isZero, listen(listenSocket, SOMAXCONN))
        try socketAddress.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size, {
            let addr = UnsafeMutablePointer<sockaddr>($0)
            var sockLen = socklen_t(MemoryLayout<sockaddr>.size)
            notify.signal()
            connectionSocket = try attempt("accept", valid: isNotMinusOne, accept(listenSocket, addr, &sockLen))
        })
    }
    
    func readData() throws -> String {
        var buffer = [UInt8](repeating: 0, count: 4096)
        _ = try attempt("read", valid: isNotMinusOne, CInt(read(connectionSocket, &buffer, 4096)))
        return String(cString: &buffer)
    }
    
    func readDataOnDataSocket() throws -> String {
        var buffer = [UInt8](repeating: 0, count: 4096)
        _ = try attempt("read", valid: isNotMinusOne, CInt(read(dataSocket, &buffer, 4096)))
        return String(cString: &buffer)
    }

    func writeRawData(_ data: Data) throws {
        _ = try data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            let ptr = rawBuffer.baseAddress
            _ = try attempt("write", valid: isNotMinusOne, CInt(write(connectionSocket, ptr, data.count)))
        }
    }

    func writeRawData(socket data: Data) throws -> Int32 {
        var bytesWritten: Int32 = 0
        _ = try data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            let ptr = rawBuffer.baseAddress
            bytesWritten = try attempt("write", valid: isNotMinusOne, CInt(write(dataSocket, ptr, data.count)))
        }
        return bytesWritten
    }

    func shutdown() {
        close(connectionSocket)
        close(listenSocket)
        close(dataSocket)
    }
}

class _FTPServer {
    
    let socket: _FTPSocket
    let commandPort: UInt16

    init(port: UInt16) throws {
        commandPort = port
        socket = try _FTPSocket(port: port)
    }

    class func create(port: UInt16) throws -> _FTPServer {
        return try _FTPServer(port: port)
    }

    func listen(notify: ServerSemaphore) throws {
        try socket.acceptConnection(notify: notify)
    }

    func stop() {
        socket.shutdown()
    }

    // parse header information and respond accordingly
    func parseHeaderData() throws {
        let saveData = """
                       FTP implementation to test FTP
                       upload, download and data tasks. Instead of sending a file,
                       we are sending the hardcoded data.We are going to test FTP
                       data, download and upload tasks with delegates & completion handlers.
                       Creating the data here as we need to pass the count
                       as part of the header.\r\n
                       """.data(using: String.Encoding.utf8)

        let dataCount = saveData?.count
        let read =  try socket.readData()
        if read.contains("anonymous") {
            try respondWithRawData(with: "331 Please specify the password.\r\n")
        } else if read.contains("PASS") {
            try respondWithRawData(with: "230 Login successful.\r\n")
        } else if read.contains("PWD") {
            try respondWithRawData(with: "257 \"/\"\r\n")
        } else if read.contains("EPSV") {
            try respondWithRawData(with: "229 Entering Extended Passive Mode (|||\(commandPort+1)|).\r\n")
        } else if read.contains("TYPE I") {
            try respondWithRawData(with: "200 Switching to Binary mode.\r\n")
        } else if read.contains("SIZE") {
            try respondWithRawData(with: "213 \(dataCount!)\r\n")
        } else if read.contains("RETR") {
            try respondWithRawData(with: "150 Opening BINARY mode data, connection for test.txt (\(dataCount!) bytes).\r\n")
            // Send data here through data port
            do {
                let dataWritten = try respondWithData(with: saveData!)
                if dataWritten != -1 {
                    // Send the end header on command port
                    try respondWithRawData(with: "226 Transfer complete.\r\n")
                }
            } catch {
                NSLog("Transfer failed.")
            }
        } else if read.contains("STOR") {
            // Request is for upload. As we are only dealing with data, just read the data and ignore
            try respondWithRawData(with: "150 Ok to send data.\r\n")
            // Read data from the data socket and respond with completion header after the transfer
            do {
                _ = try readDataOnDataSocket()
                try respondWithRawData(with: "226 Transfer complete.\r\n")
            } catch {
                NSLog("Transfer failed.")
            }
        }
    }

    func respondWithRawData(with string: String) throws {
        try self.socket.writeRawData(string.data(using: String.Encoding.utf8)!)
    }

    func respondWithData(with data: Data) throws -> Int32 {
        return try self.socket.writeRawData(socket: data)
    }
    func readDataOnDataSocket() throws -> String {
        return try self.socket.readDataOnDataSocket()
    }
}

class TestFTPURLSessionServer {
    let ftpServer: _FTPServer

    init (port: UInt16) throws {
        ftpServer = try _FTPServer.create(port: port)
    }
    func start(started: ServerSemaphore) throws {
        started.signal()
        try ftpServer.listen(notify: started)
    }
    func parseHeaderAndRespond()  throws {
        try ftpServer.parseHeaderData()
    }

    func writeStartHeaderData()  throws {
        try ftpServer.respondWithRawData(with: "220 (vsFTPd 2.3.5)\r\n")
    }

    func stop() {
        ftpServer.stop()
    }
}

class LoopbackFTPServerTest: XCTestCase {
    nonisolated(unsafe) static var serverPort: Int = -1

    override class func setUp() {
        super.setUp()
        @Sendable func runServer(with condition: ServerSemaphore,
                       startDelay: TimeInterval? = nil,
                       sendDelay: TimeInterval? = nil, bodyChunks: Int? = nil) throws {
            let start = 21961 // 21961
            for port in start...(start+100) { //we must find at least one port to bind
                do {
                    serverPort = port
                    let test = try TestFTPURLSessionServer(port: UInt16(port))
                    try test.start(started: condition)
                    try test.writeStartHeaderData() // Welcome message to start the transfer
                    for _ in 1...7 {
                        try test.parseHeaderAndRespond()
                    }
                    test.stop()
                } catch let err as ServerError {
                    if err.operation == "bind" { continue }
                    throw err
                }
            }
        }

        let serverReady = ServerSemaphore()
        globalDispatchQueue.async {
            do {
                try runServer(with: serverReady)
            } catch {
                XCTAssertTrue(true)
                return
            }
        }
        let timeout = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + 2_000_000_000)

        _ = serverReady.wait(timeout: timeout)
    }
}
#endif
