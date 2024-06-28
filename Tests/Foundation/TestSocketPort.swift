// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
#if os(Windows)
import WinSDK
#elseif canImport(Android)
import Android
#endif

class TestPortDelegateWithBlock: NSObject, PortDelegate {
    let block: (PortMessage) -> Void
    
    init(block: @escaping (PortMessage) -> Void) {
        self.block = block
    }
    
    func handle(_ message: PortMessage) {
        block(message)
    }
}

class TestSocketPort : XCTestCase {

    func tcpOrUdpPort(of socketPort: SocketPort) -> Int? {
        let data = socketPort.address
        
        #if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)
        let familyOffset = 1
        #else
        let familyOffset = 0
        #endif
        
        if data[data.startIndex + familyOffset] == AF_INET {
            return data.withUnsafeBytes { (buffer) in
                var sin = sockaddr_in()
                withUnsafeMutableBytes(of: &sin) {
                    $0.copyMemory(from: buffer)
                }
                
                return Int(sin.sin_port.bigEndian)
            }
        } else if data[data.startIndex + familyOffset] == AF_INET6 {
            return data.withUnsafeBytes { (buffer) in
                var sin = sockaddr_in6()
                withUnsafeMutableBytes(of: &sin) {
                    $0.copyMemory(from: buffer)
                }
                
                return Int(sin.sin6_port.bigEndian)
            }
        } else {
            return nil
        }
    }
    
    func testRemoteSocketPortsAreUniqued() {
        let a = SocketPort(remoteWithTCPPort: 10000, host: "localhost")
        let b = SocketPort(remoteWithTCPPort: 10000, host: "localhost")
        XCTAssertEqual(a, b)
    }
    
    func testInitPicksATCPPort() throws {
        let local = try XCTUnwrap(SocketPort(tcpPort: 0))
        defer { local.invalidate() }
        
        let port = try XCTUnwrap(tcpOrUdpPort(of: local))
        XCTAssertNotEqual(port, 0)
        XCTAssert(port >= 1024)
    }
    
    func testSendingOneMessageRemoteToLocal() throws {
        let local = try XCTUnwrap(SocketPort(tcpPort: 0))
        defer { local.invalidate() }
                        
        let tcpPort = try UInt16(XCTUnwrap(tcpOrUdpPort(of: local)))
        
        let remote = try XCTUnwrap(SocketPort(remoteWithTCPPort: tcpPort, host: "localhost"))
        defer { remote.invalidate() }
        
        let data = Data("I cannot weave".utf8)

        let received = expectation(description: "Message received")
        let delegate = TestPortDelegateWithBlock { message in
            XCTAssertEqual(message.components as? [AnyHashable], [data as NSData])
            received.fulfill()
        }
        
        withExtendedLifetime(delegate) {
            local.setDelegate(delegate)
            local.schedule(in: .main, forMode: .default)
            remote.schedule(in: .main, forMode: .default)
            
            defer {
                local.setDelegate(nil)
                local.remove(from: .main, forMode: .default)
                remote.remove(from: .main, forMode: .default)
            }
            
            let sent = remote.send(before: Date(timeIntervalSinceNow: 5), components: NSMutableArray(array: [data]), from: nil, reserved: 0)
            XCTAssertTrue(sent)
            
            waitForExpectations(timeout: 5.5)
        }
    }
    
    func testSendingMultipleMessagesRemoteToLocal() throws {
        var localPorts = [SocketPort]()
        var remotePorts = [SocketPort]()
        var delegates = [TestPortDelegateWithBlock]()

        let data = Data("I cannot weave".utf8)

        for _ in 0..<128 {
            let local = try XCTUnwrap(SocketPort(tcpPort: 0))
            let tcpPort = try UInt16(XCTUnwrap(tcpOrUdpPort(of: local)))
            let remote = try XCTUnwrap(SocketPort(remoteWithTCPPort: tcpPort, host: "localhost"))
            
            let received = expectation(description: "Message received")

            let localDelegate = TestPortDelegateWithBlock { message in
                XCTAssertEqual(message.components as? [AnyHashable], [data as NSData])
                received.fulfill()
            }

            localPorts.append(local)
            remotePorts.append(remote)
            delegates.append(localDelegate)

            local.setDelegate(localDelegate)
            local.schedule(in: .main, forMode: .default)
            remote.schedule(in: .main, forMode: .default)
        }

        withExtendedLifetime(delegates) {
            for remote in remotePorts {
                let sent = remote.send(before: Date(timeIntervalSinceNow: 5), components: NSMutableArray(array: [data]), from: nil, reserved: 0)
                XCTAssertTrue(sent)
            }
            waitForExpectations(timeout: 5.0)
        }

        for port in localPorts + remotePorts {
            port.setDelegate(nil)
            port.remove(from: .main, forMode: .default)
            port.invalidate()
        }
    }
}
