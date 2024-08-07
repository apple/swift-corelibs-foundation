// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation
internal import Synchronization

// MARK: Port and related types

public typealias SocketNativeHandle = Int32

extension Port {
    public static let didBecomeInvalidNotification  = NSNotification.Name(rawValue: "NSPortDidBecomeInvalidNotification")
}

//@_nonSendable - TODO: Mark with attribute to indicate this pure abstract class defers Sendable annotation to its subclasses.
open class Port : NSObject, NSCopying {
    /// On Darwin, you can invoke `Port()` directly to produce a `MessagePort`. Since `MessagePort` is not available in swift-corelibs-foundation, you should not invoke this initializer directly. Subclasses of `Port` can delegate to this initializer safely.
    public override init() {
        if type(of: self) == Port.self {
            NSRequiresConcreteImplementation()
        }
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
    
    open func invalidate() {
        NSRequiresConcreteImplementation()
    }

    open var isValid: Bool {
        NSRequiresConcreteImplementation()
    }
    
    open func setDelegate(_ anObject: PortDelegate?) {
        NSRequiresConcreteImplementation()
    }
    open func delegate() -> PortDelegate? {
        NSRequiresConcreteImplementation()
    }

    // These two methods should be implemented by subclasses
    // to setup monitoring of the port when added to a run loop,
    // and stop monitoring if needed when removed;
    // These methods should not be called directly!
    open func schedule(in runLoop: RunLoop, forMode mode: RunLoop.Mode) {
        NSRequiresConcreteImplementation()
    }

    open func remove(from runLoop: RunLoop, forMode mode: RunLoop.Mode) {
        NSRequiresConcreteImplementation()
    }
    
    open var reservedSpaceLength: Int {
        return 0
    }
    
    open func send(before limitDate: Date, components: NSMutableArray?, from receivePort: Port?, reserved headerSpaceReserved: Int) -> Bool {
        NSRequiresConcreteImplementation()
    }

    open func send(before limitDate: Date, msgid msgID: Int, components: NSMutableArray?, from receivePort: Port?, reserved headerSpaceReserved: Int) -> Bool {
        return send(before: limitDate, components: components, from: receivePort, reserved: headerSpaceReserved)
    }
}

@available(*, unavailable, message: "MessagePort is not available in swift-corelibs-foundation.")
open class MessagePort: Port {}

@available(*, unavailable, message: "NSMachPort is not available in swift-corelibs-foundation.")
open class NSMachPort: Port {}

@available(*, unavailable)
extension MessagePort : @unchecked Sendable { }

@available(*, unavailable)
extension NSMachPort : @unchecked Sendable { }

extension PortDelegate {
    func handle(_ message: PortMessage) { }
}

public protocol PortDelegate: AnyObject {
    func handle(_ message: PortMessage)
}

#if os(WASI)

@available(*, unavailable, message: "SocketPort is not available on this platform.")
open class SocketPort: Port {}

@available(*, unavailable)
extension SocketPort : @unchecked Sendable { }

#else

#if canImport(Darwin)
import Darwin
fileprivate let FOUNDATION_SOCK_STREAM = SOCK_STREAM
fileprivate let FOUNDATION_IPPROTO_TCP = IPPROTO_TCP
#endif

#if canImport(Glibc) && !os(OpenBSD)
import Glibc
fileprivate let FOUNDATION_SOCK_STREAM = Int32(SOCK_STREAM.rawValue)
fileprivate let FOUNDATION_IPPROTO_TCP = Int32(IPPROTO_TCP)
#endif

#if canImport(Glibc) && os(OpenBSD)
import Glibc
fileprivate let FOUNDATION_SOCK_STREAM = Int32(SOCK_STREAM)
fileprivate let FOUNDATION_IPPROTO_TCP = Int32(IPPROTO_TCP)
fileprivate let INADDR_ANY: in_addr_t = 0
fileprivate let INADDR_LOOPBACK = 0x7f000001
#endif

#if canImport(Android)
import Android
fileprivate let FOUNDATION_SOCK_STREAM = Int32(Android.SOCK_STREAM)
fileprivate let FOUNDATION_IPPROTO_TCP = Int32(Android.IPPROTO_TCP)
fileprivate let INADDR_ANY: in_addr_t = 0
#endif


#if canImport(WinSDK)
import WinSDK
/*
 // https://docs.microsoft.com/en-us/windows/win32/api/winsock/ns-winsock-sockaddr_in
 typedef struct sockaddr_in {
   short          sin_family;
   u_short        sin_port;
   struct in_addr sin_addr;
   char           sin_zero[8];
 } SOCKADDR_IN, *PSOCKADDR_IN, *LPSOCKADDR_IN;
 */
fileprivate typealias sa_family_t = ADDRESS_FAMILY
fileprivate typealias in_port_t = USHORT
fileprivate typealias in_addr_t = UInt32
fileprivate let FOUNDATION_SOCK_STREAM = SOCK_STREAM
fileprivate let FOUNDATION_IPPROTO_TCP = Int32(WinSDK.IPPROTO_TCP.rawValue)
#endif

// MARK: Darwin representation of socket addresses

/*
 ===== YOU ARE ABOUT TO ENTER THE SADNESS ZONE =====
 
 SocketPort transmits ports by sending _Darwin_ sockaddr values serialized over the wire. (Yeah.)
 This means that whatever the platform, we need to be able to send Darwin sockaddrs and figure them out on the other side of the wire.
 
 Now, the vast majority of the intreresting ports that may be sent is AF_INET and AF_INET6 — other sockets aren't uncommon, but they are generally local to their host (eg. AF_UNIX). So, we make the following tactical choice:
 
 - swift-corelibs-foundation clients across all platforms can interoperate between themselves and with Darwin as long as all the ports that are sent through SocketPort are AF_INET or AF_INET6;
 - otherwise, it is the implementor and deployer's responsibility to make sure all the clients are on the same platform. For sockets that do not leave the machine, like AF_UNIX, this is trivial.
 
 This allows us to special-case sockaddr_in and sockaddr_in6; when we transmit them, we will transmit them in a way that's binary-compatible with Darwin's version of those structure, and then we translate them into whatever version your platform uses, with the one exception that we assume that in_addr is always representable as 4 contiguous bytes, and similarly in6_addr as 16 contiguous bytes.
 
 Addresses are internally represented as LocalAddress enum cases; we use DarwinAddress as a type to denote a block of bytes that we type as being a sockaddr produced by Darwin or a Darwin-mimicking source; and the extensions on sockaddr_in and sockaddr_in6 paper over some platform differences and provide translations back and forth into DarwinAddresses for their specific types.
 
 Note that all address parameters and properties that are public are the data representation of a sockaddr generated starting from the current platform's sockaddrs, not a DarwinAddress. No code that's a client of SocketPort should be able to see the Darwin version of the data we generate internally.
 */

fileprivate let darwinAfInet: UInt8 = 2
fileprivate let darwinAfInet6: UInt8 = 30
fileprivate let darwinSockaddrInSize: UInt8 = 16
fileprivate let darwinSockaddrIn6Size: UInt8 = 28

fileprivate typealias DarwinIn6Addr =
    (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
     UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) // 16 contiguous bytes
fileprivate let darwinIn6AddrSize = 16

fileprivate extension sockaddr_in {
    // Not all platforms have a sin_len field. This is like init(), but also sets that field if it exists.
    init(settingLength: ()) {
        self.init()
        
        #if canImport(Darwin) || os(FreeBSD)
        self.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
    }
    
    init?(_ address: DarwinAddress) {
        let data = address.data
        guard data.count == darwinSockaddrInSize,
              data[offset: 0] == darwinSockaddrInSize,
              data[offset: 1] == darwinAfInet else { return nil }
        
        var port: UInt16 = 0
        var inAddr: UInt32 = 0
        
        data.withUnsafeBytes { (buffer) -> Void in
            withUnsafeMutableBytes(of: &port) {
                $0.copyMemory(from: UnsafeRawBufferPointer(rebasing: buffer[2..<4]))
            }
            withUnsafeMutableBytes(of: &inAddr) {
                $0.copyMemory(from: UnsafeRawBufferPointer(rebasing: buffer[4..<8]))
            }
        }
        
        self.init(settingLength: ())
        self.sin_family = sa_family_t(AF_INET)
        self.sin_port = in_port_t(port)
        withUnsafeMutableBytes(of: &self.sin_addr) { (buffer) in
            withUnsafeBytes(of: inAddr) { buffer.copyMemory(from: $0) }
        }
    }
    
    var darwinAddress: DarwinAddress {
        var data = Data()
        withUnsafeBytes(of: darwinSockaddrInSize) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: darwinAfInet) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(sin_port)) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: sin_addr) { data.append(contentsOf: $0) }
        
        let padding: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8) =
            (0, 0, 0, 0, 0, 0, 0, 0)
        withUnsafeBytes(of: padding) { data.append(contentsOf: $0) }
        
        return DarwinAddress(data)
    }
}

fileprivate extension sockaddr_in6 {
    init(settingLength: ()) {
        self.init()
        
        #if canImport(Darwin) || os(FreeBSD)
        self.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        #endif
    }
    
    init?(_ address: DarwinAddress) {
        let data = address.data
        guard data.count == darwinSockaddrIn6Size,
            data[offset: 0] == darwinSockaddrIn6Size,
            data[offset: 1] == darwinAfInet6 else { return nil }
        
        var port: UInt16 = 0
        var flowInfo: UInt32 = 0
        var in6Addr: DarwinIn6Addr =
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        var scopeId: UInt32 = 0
        
        data.withUnsafeBytes { (buffer) -> Void in
            withUnsafeMutableBytes(of: &port) {
                $0.copyMemory(from: UnsafeRawBufferPointer(rebasing: buffer[2..<4]))
            }
            withUnsafeMutableBytes(of: &flowInfo) {
                $0.copyMemory(from: UnsafeRawBufferPointer(rebasing: buffer[4..<8]))
            }
            withUnsafeMutableBytes(of: &in6Addr) {
                $0.copyMemory(from: UnsafeRawBufferPointer(rebasing: buffer[8..<24]))
            }
            withUnsafeMutableBytes(of: &scopeId) {
                $0.copyMemory(from: UnsafeRawBufferPointer(rebasing: buffer[24..<28]))
            }
        }
        
        self.init(settingLength: ())
        self.sin6_family = sa_family_t(AF_INET6)
        self.sin6_port = in_port_t(port)
#if os(Windows)
        self.sin6_flowinfo = ULONG(flowInfo)
#else
        self.sin6_flowinfo = flowInfo
#endif
        withUnsafeMutableBytes(of: &self.sin6_addr) { (buffer) in
            withUnsafeBytes(of: in6Addr) { buffer.copyMemory(from: $0) }
        }
        #if !os(Windows)
        self.sin6_scope_id = scopeId
        #endif
    }
    
    var darwinAddress: DarwinAddress {
        var data = Data()
        withUnsafeBytes(of: darwinSockaddrIn6Size) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: darwinAfInet6) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(sin6_port)) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(sin6_flowinfo)) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: sin6_addr) { data.append(contentsOf: $0) }
        
        #if os(Windows)
        withUnsafeBytes(of: UInt32(0)) { data.append(contentsOf: $0) }
        #else
        withUnsafeBytes(of: UInt32(sin6_scope_id)) { data.append(contentsOf: $0) }
        #endif
        
        return DarwinAddress(data)
    }
}

enum LocalAddress: Hashable {
    case ipv4(sockaddr_in)
    case ipv6(sockaddr_in6)
    case other(Data)
    
    init(_ data: Data) {
        if data.count == MemoryLayout<sockaddr_in>.size {
            let sinAddr = data.withUnsafeBytes { $0.baseAddress!.load(as: sockaddr_in.self) }
            if sinAddr.sin_family == sa_family_t(AF_INET) {
                self = .ipv4(sinAddr)
                return
            }
        }
        
        if data.count == MemoryLayout<sockaddr_in6>.size {
            let sinAddr = data.withUnsafeBytes { $0.baseAddress!.load(as: sockaddr_in6.self) }
            if sinAddr.sin6_family == sa_family_t(AF_INET6) {
                self = .ipv6(sinAddr)
                return
            }
        }
        
        self = .other(data)
    }
    
    init(_ darwinAddress: DarwinAddress) {
        let data = Data(darwinAddress.data)
        if data[offset: 1] == UInt8(AF_INET), let sinAddr = sockaddr_in(darwinAddress) {
            self = .ipv4(sinAddr); return
        }
        
        if data[offset: 1] == UInt8(AF_INET6), let sinAddr = sockaddr_in6(darwinAddress) {
            self = .ipv6(sinAddr); return
        }
        
        self = .other(darwinAddress.data)
    }
    
    var data: Data {
        switch self {
        case .ipv4(let sinAddr):
            return withUnsafeBytes(of: sinAddr) { Data($0) }
        case .ipv6(let sinAddr):
            return withUnsafeBytes(of: sinAddr) { Data($0) }
        case .other(let data):
            return data
        }
    }
    
    func hash(into hasher: inout Hasher) {
        data.hash(into: &hasher)
    }
    
    static func ==(_ lhs: LocalAddress, _ rhs: LocalAddress) -> Bool {
        return lhs.data == rhs.data
    }
}

struct DarwinAddress: Hashable {
    var data: Data
    
    init(_ data: Data) {
        self.data = data
    }
    
    init(_ localAddress: LocalAddress) {
        switch localAddress {
        case .ipv4(let sinAddr):
            self = sinAddr.darwinAddress
            
        case .ipv6(let sinAddr):
            self = sinAddr.darwinAddress
            
        case .other(let data):
            self.data = data
        }
    }
}

// MARK: SocketPort

// A subclass of Port which can be used for remote
// message sending on all platforms.

fileprivate func __NSFireSocketAccept(_ socket: CFSocket?, _ type: CFSocketCallBackType, _ address: CFData?, _ data: UnsafeRawPointer?, _ info: UnsafeMutableRawPointer?) {
    guard let nonoptionalInfo = info else {
        return
    }
    
    let me = Unmanaged<SocketPort>.fromOpaque(nonoptionalInfo).takeUnretainedValue()
    me.socketDidAccept(socket, type, address, data)
}

fileprivate func __NSFireSocketData(_ socket: CFSocket?, _ type: CFSocketCallBackType, _ address: CFData?, _ data: UnsafeRawPointer?, _ info: UnsafeMutableRawPointer?) {
    guard let nonoptionalInfo = info else {
        return
    }
    
    let me = Unmanaged<SocketPort>.fromOpaque(nonoptionalInfo).takeUnretainedValue()
    me.socketDidReceiveData(socket, type, address, data)
}

fileprivate func __NSFireSocketDatagram(_ socket: CFSocket?, _ type: CFSocketCallBackType, _ address: CFData?, _ data: UnsafeRawPointer?, _ info: UnsafeMutableRawPointer?) {
    guard let nonoptionalInfo = info else {
        return
    }
    
    let me = Unmanaged<SocketPort>.fromOpaque(nonoptionalInfo).takeUnretainedValue()
    me.socketDidReceiveDatagram(socket, type, address, data)
}

@available(*, unavailable)
extension SocketPort : @unchecked Sendable { }

extension CFSocket : @unchecked Sendable { }

open class SocketPort : Port {
    struct SocketKind: Hashable {
        var protocolFamily: Int32
        var socketType: Int32
        var `protocol`: Int32
    }
    
    struct Signature: Hashable {
        var address: LocalAddress
        
        var protocolFamily: Int32
        var socketType: Int32
        var `protocol`: Int32
        
        var socketKind: SocketKind {
            get {
                return SocketKind(protocolFamily: protocolFamily, socketType: socketType, protocol: `protocol`)
            }
            set {
                self.protocolFamily = newValue.protocolFamily
                self.socketType = newValue.socketType
                self.protocol = newValue.protocol
            }
        }
        
        var darwinCompatibleDataRepresentation: Data? {
            var data = Data()
            let address = DarwinAddress(self.address).data
            
            guard let protocolFamilyByte = UInt8(exactly: protocolFamily),
                  let socketTypeByte = UInt8(exactly: socketType),
                  let protocolByte = UInt8(exactly: `protocol`),
                  let addressCountByte = UInt8(exactly: address.count) else {
                    return nil
            }
            
            // TODO: Fixup namelen in Unix socket name.
            
            data.append(protocolFamilyByte)
            data.append(socketTypeByte)
            data.append(protocolByte)
            data.append(addressCountByte)
            data.append(contentsOf: address)
            
            return data
        }
        
        init(address: LocalAddress, protocolFamily: Int32, socketType: Int32, protocol: Int32) {
            self.address = address
            self.protocolFamily = protocolFamily
            self.socketType = socketType
            self.protocol = `protocol`
        }
        
        init?(darwinCompatibleDataRepresentation data: Data) {
            guard data.count > 3 else { return nil }
            let addressCountByte = data[offset: 3]
            guard data.count == addressCountByte + 4 else { return nil }
            
            self.protocolFamily = Int32(data[offset: 0])
            self.socketType = Int32(data[offset: 1])
            self.protocol = Int32(data[offset: 2])
            // data[3] is addressCountByte, handled above.
            self.address = LocalAddress(DarwinAddress(data[offset: 4...]))
        }
    }
    
    class Core : @unchecked Sendable {
        fileprivate let isUniqued: Bool
        fileprivate var signature: Signature!
        
        fileprivate let lock = NSLock()
        fileprivate var connectors: [Signature: CFSocket] = [:]
        fileprivate var loops: [ObjectIdentifier: (runLoop: CFRunLoop, modes: Set<RunLoop.Mode>)] = [:]
        fileprivate var receiver: CFSocket?
        fileprivate var data: [ObjectIdentifier: Data] = [:]
        
        init(isUniqued: Bool) { self.isUniqued = isUniqued }
    }
    
    private var core: Core!
    
    public convenience override init() {
        self.init(tcpPort: 0)!
    }
    
    public convenience init?(tcpPort port: UInt16) {
        var address = sockaddr_in(settingLength: ())
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        withUnsafeMutableBytes(of: &address.sin_addr) { (buffer) in
            withUnsafeBytes(of: in_addr_t(INADDR_ANY).bigEndian) { buffer.copyMemory(from: $0) }
        }
        
        let data = withUnsafeBytes(of: address) { Data($0) }
        
        self.init(protocolFamily: PF_INET, socketType: FOUNDATION_SOCK_STREAM, protocol: FOUNDATION_IPPROTO_TCP, address: data)
    }
    
    private final func createNonuniquedCore(from socket: CFSocket, protocolFamily family: Int32, socketType type: Int32, protocol: Int32) {
        self.core = Core(isUniqued: false)
        let address = CFSocketCopyAddress(socket)._swiftObject
        core.signature = Signature(address: LocalAddress(address), protocolFamily: family, socketType: type, protocol: `protocol`)
        core.receiver = socket
    }
    
    public init?(protocolFamily family: Int32, socketType type: Int32, protocol: Int32, address: Data) {
        super.init()
        
        var context = CFSocketContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        var s: CFSocket
        if type == FOUNDATION_SOCK_STREAM {
            s = CFSocketCreate(nil, family, type, `protocol`, CFOptionFlags(kCFSocketAcceptCallBack), __NSFireSocketAccept, &context)
        } else {
            s = CFSocketCreate(nil, family, type, `protocol`, CFOptionFlags(kCFSocketDataCallBack), __NSFireSocketDatagram, &context)
        }
        
        if CFSocketSetAddress(s, address._cfObject) != CFSocketError(0) {
            return nil
        }
        
        createNonuniquedCore(from: s, protocolFamily: family, socketType: type, protocol: `protocol`)
    }
    
    public init?(protocolFamily family: Int32, socketType type: Int32, protocol: Int32, socket sock: SocketNativeHandle) {
        super.init()
        
        var context = CFSocketContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        var s: CFSocket
        if type == FOUNDATION_SOCK_STREAM {
            s = CFSocketCreateWithNative(nil, CFSocketNativeHandle(sock), CFOptionFlags(kCFSocketAcceptCallBack), __NSFireSocketAccept, &context)
        } else {
            s = CFSocketCreateWithNative(nil, CFSocketNativeHandle(sock), CFOptionFlags(kCFSocketDataCallBack), __NSFireSocketDatagram, &context)
        }
        
        createNonuniquedCore(from: s, protocolFamily: family, socketType: type, protocol: `protocol`)
    }
    
    public convenience init?(remoteWithTCPPort port: UInt16, host hostName: String?) {
        let host = Host(name: hostName?.isEmpty == true ? nil : hostName)
        var addresses: [String] = hostName == nil ? [] : [hostName!]
        addresses.append(contentsOf: host.addresses)
        
        // Prefer IPv4 addresses, as Darwin does:
        for address in addresses {
            var inAddr = in_addr()
            if inet_pton(AF_INET, address, &inAddr) == 1 {
                var sinAddr = sockaddr_in(settingLength: ())
                sinAddr.sin_family = sa_family_t(AF_INET)
                sinAddr.sin_port = port.bigEndian
                sinAddr.sin_addr = inAddr
                
                let data = withUnsafeBytes(of: sinAddr) { Data($0) }
                self.init(remoteWithProtocolFamily: PF_INET, socketType: FOUNDATION_SOCK_STREAM, protocol: FOUNDATION_IPPROTO_TCP, address: data)
                return
            }
        }
        for address in addresses {
            var in6Addr = in6_addr()
            if inet_pton(AF_INET6, address, &in6Addr) == 1 {
                var sinAddr = sockaddr_in6(settingLength: ())
                sinAddr.sin6_family = sa_family_t(AF_INET6)
                sinAddr.sin6_port = port.bigEndian
                sinAddr.sin6_addr = in6Addr
                
                let data = withUnsafeBytes(of: sinAddr) { Data($0) }
                self.init(remoteWithProtocolFamily: PF_INET, socketType: FOUNDATION_SOCK_STREAM, protocol: FOUNDATION_IPPROTO_TCP, address: data)
                return
            }
        }
        
        if hostName != nil {
            return nil
        }
        
        // Lookup on local host.
        var sinAddr = sockaddr_in(settingLength: ())
        sinAddr.sin_family = sa_family_t(AF_INET)
        sinAddr.sin_port = port.bigEndian
        withUnsafeMutableBytes(of: &sinAddr.sin_addr) { (buffer) in
            withUnsafeBytes(of: in_addr_t(INADDR_LOOPBACK).bigEndian) { buffer.copyMemory(from: $0) }
        }
        let data = withUnsafeBytes(of: sinAddr) { Data($0) }
        self.init(remoteWithProtocolFamily: PF_INET, socketType: FOUNDATION_SOCK_STREAM, protocol: FOUNDATION_IPPROTO_TCP, address: data)
    }
    
    private static let remoteSocketCores = Mutex<[Signature: Core]>([:])
    
    static private func retainedCore(for signature: Signature) -> Core {
        return SocketPort.remoteSocketCores.withLock {
            if let core = $0[signature] {
                return core
            } else {
                let core = Core(isUniqued: true)
                core.signature = signature
                
                $0[signature] = core
                
                return core
            }
        }
    }
    
    public init(remoteWithProtocolFamily family: Int32, socketType type: Int32, protocol: Int32, address: Data) {
        let signature = Signature(address: LocalAddress(address), protocolFamily: family, socketType: type, protocol: `protocol`)
        self.core = SocketPort.retainedCore(for: signature)
    }
    
    private init(remoteWithSignature signature: Signature) {
        self.core = SocketPort.retainedCore(for: signature)
    }
    
    deinit {
        // On Darwin, .invalidate() is invoked on the _last_ release, immediately before deinit; we cannot do that here.
        invalidate()
    }
    
    open override func invalidate() {
        guard var core = core else { return }
        self.core = nil
        
        var signatureToRemove: Signature?
        
        if core.isUniqued {
            if isKnownUniquelyReferenced(&core) {
                signatureToRemove = core.signature // No need to lock here — this is the only reference to the core.
            } else {
                return // Do not clean up the contents of this core yet.
            }
        }
        
        if let receiver = core.receiver, CFSocketIsValid(receiver) {
            for connector in core.connectors.values {
                CFSocketInvalidate(connector)
            }
        
            CFSocketInvalidate(receiver)
            
            // Invalidation notifications are only sent for local (receiver != nil) ports.
            NotificationCenter.default.post(name: Port.didBecomeInvalidNotification, object: self)
        }
        
        if let signatureToRemove = signatureToRemove {
            SocketPort.remoteSocketCores.withLock {
                _ = $0.removeValue(forKey: signatureToRemove)
            }
        }
    }
    
    open override var isValid: Bool {
        return core != nil
    }
    
    weak var _delegate: PortDelegate?
    open override func setDelegate(_ anObject: PortDelegate?) {
        _delegate = anObject
    }
    open override func delegate() -> PortDelegate? {
        return _delegate
    }

    open var protocolFamily: Int32 {
        return core.signature.protocolFamily
    }
    
    open var socketType: Int32 {
        return core.signature.socketType
    }
    
    open var `protocol`: Int32 {
        return core.signature.protocol
    }
    
    open var address: Data {
        return core.signature.address.data
    }
    
    open var socket: SocketNativeHandle {
        return SocketNativeHandle(CFSocketGetNative(core.receiver))
    }
    
    open override func schedule(in runLoop: RunLoop, forMode mode: RunLoop.Mode) {
        let loop = runLoop.currentCFRunLoop
        let loopKey = ObjectIdentifier(loop)
        
        core.lock.synchronized {
            guard let receiver = core.receiver, CFSocketIsValid(receiver) else { return }
            
            var modes = core.loops[loopKey]?.modes ?? []
            
            guard !modes.contains(mode) else { return }
            modes.insert(mode)
            
            core.loops[loopKey] = (loop, modes)
            
            if let source = CFSocketCreateRunLoopSource(nil, receiver, 600) {
                CFRunLoopAddSource(loop, source, mode.rawValue._cfObject)
            }
            
            for socket in core.connectors.values {
                if let source = CFSocketCreateRunLoopSource(nil, socket, 600) {
                    CFRunLoopAddSource(loop, source, mode.rawValue._cfObject)
                }
            }
        }
    }
    
    open override func remove(from runLoop: RunLoop, forMode mode: RunLoop.Mode) {
        let loop = runLoop.currentCFRunLoop
        let loopKey = ObjectIdentifier(loop)
        
        core.lock.synchronized {
            guard let receiver = core.receiver, CFSocketIsValid(receiver) else { return }
            
            let modes = core.loops[loopKey]?.modes ?? []
            guard modes.contains(mode) else { return }
            
            if modes.count == 1 {
                core.loops.removeValue(forKey: loopKey)
            } else {
                core.loops[loopKey]?.modes.remove(mode)
            }
            
            if let source = CFSocketCreateRunLoopSource(nil, receiver, 600) {
                CFRunLoopRemoveSource(loop, source, mode.rawValue._cfObject)
            }
            
            for socket in core.connectors.values {
                if let source = CFSocketCreateRunLoopSource(nil, socket, 600) {
                    CFRunLoopRemoveSource(loop, source, mode.rawValue._cfObject)
                }
            }
        }
    }
    
    // On Darwin/ObjC Foundation, invoking initRemote… will return an existing SocketPort from a factory initializer if a port with that signature already exists.
    // We cannot do that in Swift; we return instead different objects that share a 'core' (their state), so that invoking methods on either will affect the other. To keep maintain a better illusion, unlike Darwin, we redefine equality so that s1 == s2 for objects that have the same core, even though s1 !== s2 (this we cannot fix).
    // This allows e.g. collections where SocketPorts are keys or entries to continue working the same way they do on Darwin when remote socket ports are encountered.
    
    open override var hash: Int {
        var hasher = Hasher()
        ObjectIdentifier(core).hash(into: &hasher)
        return hasher.finalize()
    }
    
    open override func isEqual(_ object: Any?) -> Bool {
        guard let socketPort = object as? SocketPort else { return false }
        return core === socketPort.core
    }
    
    // Sending and receiving:
    
    fileprivate final func socketDidAccept(_ socket: CFSocket?, _ type: CFSocketCallBackType, _ address: CFData?, _ data: UnsafeRawPointer?) {
        guard let handle = data?.assumingMemoryBound(to: SocketNativeHandle.self),
            let address = address else {
                return
        }
        
        var context = CFSocketContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        guard let child = CFSocketCreateWithNative(nil, CFSocketNativeHandle(handle.pointee), CFOptionFlags(kCFSocketDataCallBack), __NSFireSocketData, &context) else {
            return
        }
        
        var signature = core.signature!
        signature.address = LocalAddress(address._swiftObject)
        core.lock.synchronized {
            core.connectors[signature] = child
            addToLoopsAssumingLockHeld(child)
        }
    }
    
    private final func addToLoopsAssumingLockHeld(_ socket: CFSocket) {
        guard let source = CFSocketCreateRunLoopSource(nil, socket, 600) else {
            return
        }
        
        for loop in core.loops.values {
            for mode in loop.modes {
                CFRunLoopAddSource(loop.runLoop, source, mode.rawValue._cfObject)
            }
        }
    }
    
    private static let magicNumber: UInt32 = 0xD0CF50C0
    
    private enum ComponentType: UInt32 {
        case data = 1
        case port = 2
    }
    
    fileprivate final func socketDidReceiveData(_ socket: CFSocket?, _ type: CFSocketCallBackType, _ address: CFData?, _ dataPointer: UnsafeRawPointer?) {
        guard let socket = socket,
              let dataPointer = dataPointer else { return }
        let socketKey = ObjectIdentifier(socket)
        
        let peerAddress = CFSocketCopyPeerAddress(socket)._swiftObject

        let lock = core.lock
        lock.lock() // We may briefly release the lock during the loop below, and it's unlocked at the end ⬇
        
        let data = Unmanaged<CFData>.fromOpaque(dataPointer).takeUnretainedValue()._swiftObject
        
        if data.count == 0 {
            core.data.removeValue(forKey: socketKey)
            let keysToRemove = core.connectors.keys.filter { core.connectors[$0] === socket }
            for key in keysToRemove {
                core.connectors.removeValue(forKey: key)
            }
        } else {
            var storedData: Data
            if let currentData = core.data[socketKey] {
                storedData = currentData
                storedData.append(contentsOf: data)
            } else {
                storedData = data
            }
            
            var keepGoing = true
            while keepGoing && storedData.count > 8 {
                let preamble = storedData.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }.bigEndian
                let messageLength = storedData.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }.bigEndian
                
                if preamble == SocketPort.magicNumber && messageLength > 8 {
                    if storedData.count >= messageLength {
                        let messageEndIndex = storedData.index(storedData.startIndex, offsetBy: Int(messageLength))
                        
                        let toStore = storedData[offset: messageEndIndex...]
                        if toStore.isEmpty {
                            core.data.removeValue(forKey: socketKey)
                        } else {
                            core.data[socketKey] = toStore
                        }
                        storedData.removeSubrange(messageEndIndex...)
                        
                        lock.unlock() // Briefly release the lock ⬆
                        handleMessage(storedData, from: peerAddress, socket: socket)
                        lock.lock() // Retake for the remainder ⬇
                        
                        if let newStoredData = core.data[socketKey] {
                            storedData = newStoredData
                        } else {
                            keepGoing = false
                        }
                    } else {
                        keepGoing = false
                    }
                } else {
                    // Got message without proper header; delete it.
                    core.data.removeValue(forKey: socketKey)
                    keepGoing = false
                }
            }
        }
        
        lock.unlock() // Release lock from above ⬆
    }
    
    fileprivate final func socketDidReceiveDatagram(_ socket: CFSocket?, _ type: CFSocketCallBackType, _ address: CFData?, _ data: UnsafeRawPointer?) {
        guard let address = address?._swiftObject,
              let data = data else {
            return
        }
        
        let actualData = Unmanaged<CFData>.fromOpaque(data).takeUnretainedValue()._swiftObject
        self.handleMessage(actualData, from: address, socket: nil)
    }
    
    private enum Structure {
        static let offsetOfMagicNumber = 0 // a UInt32
        static let offsetOfMessageLength = 4 // a UInt32
        static let offsetOfMsgId = 8 // a UInt32
        
        static let offsetOfSignature = 12
        static let sizeOfSignatureHeader = 4
        static let offsetOfSignatureAddressLength = 15
    }
    
    private final func handleMessage(_ message: Data, from address: Data, socket: CFSocket?) {
        guard message.count > 24, let delegate = delegate() else { return }
        let portMessage = message.withUnsafeBytes { (messageBuffer) -> PortMessage? in
            guard SocketPort.magicNumber == messageBuffer.load(fromByteOffset: Structure.offsetOfMagicNumber, as: UInt32.self).bigEndian,
                  message.count == messageBuffer.load(fromByteOffset: Structure.offsetOfMessageLength, as: UInt32.self).bigEndian else {
                  return nil
            }
            
            let msgId = messageBuffer.load(fromByteOffset: Structure.offsetOfMsgId, as: UInt32.self).bigEndian
            let signatureLength = Int(messageBuffer[Structure.offsetOfSignatureAddressLength]) + Structure.sizeOfSignatureHeader // corresponds to the sin_len/sin6_len field inside the signature.
            var signatureBytes = Data(UnsafeRawBufferPointer(rebasing: messageBuffer[12 ..< min(12 + signatureLength, message.count - 20)]))
            
            if signatureBytes.count >= 12 && signatureBytes[offset: 5] == AF_INET && address.count >= 8 {
                if address[offset: 1] == AF_INET {
                    signatureBytes.withUnsafeMutableBytes { (mutableSignatureBuffer) in
                        address.withUnsafeBytes { (address) in
                            mutableSignatureBuffer.baseAddress?.advanced(by: 8).copyMemory(from: address.baseAddress!.advanced(by: 4), byteCount: 4)
                        }
                    }
                }
            } else if signatureBytes.count >= 32 && signatureBytes[offset: 5] == AF_INET6 && address.count >= 28 {
                if address[offset: 1] == AF_INET6 {
                    signatureBytes.withUnsafeMutableBytes { (mutableSignatureBuffer) in
                        address.withUnsafeBytes { (address) in
                            mutableSignatureBuffer.baseAddress?.advanced(by: 8).copyMemory(from: address.baseAddress!.advanced(by: 4), byteCount: 24)
                        }
                    }
                }
            }
            
            guard let signature = Signature(darwinCompatibleDataRepresentation: signatureBytes) else {
                return nil
            }
            
            if let socket = socket {
                core.lock.synchronized {
                    if let existing = core.connectors[signature], CFSocketIsValid(existing) {
                        core.connectors[signature] = socket
                    }
                }
            }
            
            let sender = SocketPort(remoteWithSignature: signature)
            var index = messageBuffer.startIndex + signatureBytes.count + 20
            var components: [AnyObject] = []
            while index < messageBuffer.endIndex {
                var word1: UInt32 = 0
                var word2: UInt32 = 0
                
                // The amount of data prior to this point may mean that these reads are unaligned; copy instead.
                withUnsafeMutableBytes(of: &word1) { (destination) -> Void in
                    messageBuffer.copyBytes(to: destination, from: Int(index - 8) ..< Int(index - 4))
                }
                withUnsafeMutableBytes(of: &word2) { (destination) -> Void in
                    messageBuffer.copyBytes(to: destination, from: Int(index - 4) ..< Int(index))
                }
                
                let componentType = word1.bigEndian
                let componentLength = word2.bigEndian
                
                let componentEndIndex = min(index + Int(componentLength), messageBuffer.endIndex)
                let componentData = Data(messageBuffer[index ..< componentEndIndex])

                if let type = ComponentType(rawValue: componentType) {
                    switch type {
                    case .data:
                        components.append(componentData._nsObject)
                        
                    case .port:
                        if let signature = Signature(darwinCompatibleDataRepresentation: componentData) {
                            components.append(SocketPort(remoteWithSignature: signature))
                        }
                    }
                }
                
                guard messageBuffer.formIndex(&index, offsetBy: componentData.count + 8, limitedBy: messageBuffer.endIndex) else {
                    break
                }
            }
            
            let message = PortMessage(sendPort: sender, receivePort: self, components: components)
            message.msgid = msgId
            return message
        }
        
        if let portMessage = portMessage {
            delegate.handle(portMessage)
        }
    }
    
    open override func send(before limitDate: Date, components: NSMutableArray?, from receivePort: Port?, reserved headerSpaceReserved: Int) -> Bool {
        send(before: limitDate, msgid: 0, components: components, from: receivePort, reserved: headerSpaceReserved)
    }
    
    open override func send(before limitDate: Date, msgid msgID: Int, components: NSMutableArray?, from receivePort: Port?, reserved headerSpaceReserved: Int) -> Bool {
        guard let sender = sendingSocket(for: self, before: limitDate.timeIntervalSinceReferenceDate),
              let signature = core.signature.darwinCompatibleDataRepresentation else {
            return false
        }
        
        let magicNumber: UInt32 = SocketPort.magicNumber.bigEndian
        var outLength: UInt32 = 0
        let messageNumber = UInt32(msgID).bigEndian
        
        var data = Data()
        withUnsafeBytes(of: magicNumber) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: outLength) { data.append(contentsOf: $0) } // Reserve space for it.
        withUnsafeBytes(of: messageNumber) { data.append(contentsOf: $0) }
        data.append(contentsOf: signature)
                
        for component in components?.allObjects ?? [] {
            var componentData: Data
            var componentType: ComponentType
            
            switch component {
            case let component as Data:
                componentData = component
                componentType = .data
                
            case let component as NSData:
                componentData = component._swiftObject
                componentType = .data
                
            case let component as SocketPort:
                guard let signature = component.core.signature.darwinCompatibleDataRepresentation else {
                    return false
                }
                componentData = signature
                componentType = .port
                
            default:
                return false
            }
            
            var componentLength = UInt32(componentData.count).bigEndian
            var componentTypeRawValue = UInt32(componentType.rawValue).bigEndian
            
            withUnsafeBytes(of: &componentTypeRawValue) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &componentLength) { data.append(contentsOf: $0) }
            data.append(contentsOf: componentData)
        }
        
        outLength = UInt32(data.count).bigEndian
        withUnsafeBytes(of: outLength) { (lengthBytes) -> Void in
            data.withUnsafeMutableBytes { (bytes)  -> Void in
                bytes.baseAddress!.advanced(by: 4).copyMemory(from: lengthBytes.baseAddress!, byteCount: lengthBytes.count)
            }
        }
        
        let result = CFSocketSendData(sender, self.address._cfObject, data._cfObject, limitDate.timeIntervalSinceNow)
        
        switch result {
        case kCFSocketSuccess:
            return true
        case kCFSocketError: fallthrough
        case kCFSocketTimeout:
            return false
            
        default:
            fatalError("Unknown result of sending through a socket: \(result)")
        }
    }
    
    private static let maximumTimeout: TimeInterval = 86400
    
    private static let sendingSockets = Mutex<[SocketKind: CFSocket]>([:])
    
    private final func sendingSocket(for port: SocketPort, before time: TimeInterval) -> CFSocket? {
        let signature = port.core.signature!
        let socketKind = signature.socketKind

        // Uses a pointer value for comparison only
        nonisolated(unsafe) var context = CFSocketContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        nonisolated(unsafe) let nonisolatedSelf = self
        return core.lock.synchronized {
            if let connector = nonisolatedSelf.core.connectors[signature], CFSocketIsValid(connector) {
                return connector
            } else {
                if signature.socketType == FOUNDATION_SOCK_STREAM {
                    if let connector = CFSocketCreate(nil, socketKind.protocolFamily, socketKind.socketType, socketKind.protocol, CFOptionFlags(kCFSocketDataCallBack), __NSFireSocketData, &context), CFSocketIsValid(connector) {
                        var timeout = time - Date.timeIntervalSinceReferenceDate
                        if timeout < 0 || timeout >= SocketPort.maximumTimeout {
                            timeout = 0
                        }
                        
                        if CFSocketIsValid(connector) && CFSocketConnectToAddress(connector, address._cfObject, timeout) == CFSocketError(0) {
                            nonisolatedSelf.core.connectors[signature] = connector
                            self.addToLoopsAssumingLockHeld(connector)
                            return connector
                        } else {
                            CFSocketInvalidate(connector)
                        }
                    }
                } else {
                    return SocketPort.sendingSockets.withLock {
                        var result: CFSocket?
                        
                        if signature.socketKind == nonisolatedSelf.core.signature.socketKind,
                           let receiver = nonisolatedSelf.core.receiver, CFSocketIsValid(receiver) {
                            result = receiver
                        } else if let socket = $0[socketKind], CFSocketIsValid(socket) {
                            result = socket
                        }
                        
                        if result == nil,
                           let sender = CFSocketCreate(nil, socketKind.protocolFamily, socketKind.socketType, socketKind.protocol, CFOptionFlags(kCFSocketNoCallBack), nil, &context), CFSocketIsValid(sender) {
                            
                            $0[socketKind] = sender
                            result = sender
                        }
                        
                        return result
                    }
                }
            }
            
            return nil
        }
    }
}

fileprivate extension Data {
    subscript(offset value: Int) -> Data.Element {
        return self[self.index(self.startIndex, offsetBy: value)]
    }
    
    subscript(offset range: Range<Int>) -> Data.SubSequence {
        return self[self.index(self.startIndex, offsetBy: range.lowerBound) ..< self.index(self.startIndex, offsetBy: range.upperBound)]
    }
    
    subscript(offset range: ClosedRange<Int>) -> Data.SubSequence {
        return self[self.index(self.startIndex, offsetBy: range.lowerBound) ... self.index(self.startIndex, offsetBy: range.upperBound)]
    }
    
    subscript(offset range: PartialRangeFrom<Int>) -> Data.SubSequence {
        return self[self.index(self.startIndex, offsetBy: range.lowerBound)...]
    }
    
    subscript(offset range: PartialRangeUpTo<Int>) -> Data.SubSequence {
        return self[...self.index(self.startIndex, offsetBy: range.upperBound)]
    }
}

#endif
