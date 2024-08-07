// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation
#if os(Windows)
import WinSDK
#endif

#if canImport(Android)
    import Android
    // Android Bionic differs a little with respect to the Linux Glibc.

    // IFF_LOOPBACK is part of the enumeration net_device_flags, which needs to
    // convert to UInt32.
    private extension UInt32 {
        init(_ value: net_device_flags) {
            self.init(value.rawValue)
        }
    }

    // getnameinfo uses size_t for its 4th and 6th arguments.
    private func getnameinfo(_ addr: UnsafePointer<sockaddr>, _ addrlen: socklen_t, _ host: UnsafeMutablePointer<Int8>?, _ hostlen: socklen_t, _ serv: UnsafeMutablePointer<Int8>?, _ servlen: socklen_t, _ flags: Int32) -> Int32 {
        return Android.getnameinfo(addr, addrlen, host, Int(hostlen), serv, Int(servlen), flags)
    }

    // getifaddrs and freeifaddrs are not available in Android 6.0 or earlier, so call these functions dynamically.
    // This only happens during the initial lookup of the addresses and then the results are cached and _resolved is marked true.
    // If this API changes so these functions are called more frequently, it might be beneficial to cache the function pointers.

    private typealias GetIfAddrsFunc = @convention(c) (UnsafeMutablePointer<UnsafeMutablePointer<ifaddrs>?>) -> Int32
    private func getifaddrs(_ ifap: UnsafeMutablePointer<UnsafeMutablePointer<ifaddrs>?>) -> Int32 {
        var result: Int32 = -1
        if let handle = dlopen("libc.so", RTLD_NOLOAD) {
            if let entry = dlsym(handle, "getifaddrs") {
                result = unsafeBitCast(entry, to: GetIfAddrsFunc.self)(ifap)
            }
            dlclose(handle)
        }
        return result
    }

    private typealias FreeIfAddrsFunc = @convention(c) (UnsafeMutablePointer<ifaddrs>?) -> Void
    private func freeifaddrs(_ ifa: UnsafeMutablePointer<ifaddrs>?) {
        if let handle = dlopen("libc.so", RTLD_NOLOAD) {
            if let entry = dlsym(handle, "freeifaddrs") {
                unsafeBitCast(entry, to: FreeIfAddrsFunc.self)(ifa)
            }
            dlclose(handle)
        }
    }
#endif

@available(*, unavailable)
extension Host : @unchecked Sendable { }

open class Host: NSObject {
    enum ResolveType {
        case name
        case address
        case current
    }
    internal var _info: String?
    internal var _type: ResolveType
    internal var _resolved = false
    internal var _names = [String]()
    internal var _addresses = [String]()
    
    static internal let _cachedCurrentHostName = currentHostName()
    
    internal init(_ info: String?, _ type: ResolveType) {
        _info = info
        _type = type
    }
    
    static internal func currentHostName() -> String {
#if os(Windows)
        var dwLength: DWORD = 0
        GetComputerNameExA(ComputerNameDnsHostname, nil, &dwLength)
        guard dwLength > 0 else { return "localhost" }

        guard let hostname: UnsafeMutablePointer<Int8> =
                UnsafeMutableBufferPointer<Int8>
                    .allocate(capacity: Int(dwLength + 1))
                    .baseAddress else {
            return "localhost"
        }
        defer { hostname.deallocate() }
        guard GetComputerNameExA(ComputerNameDnsHostname, hostname, &dwLength) else {
            return "localhost"
        }
        return String(cString: hostname)
#elseif os(WASI) // WASI does not have uname
        return "localhost"
#else
        let hname = UnsafeMutablePointer<Int8>.allocate(capacity: Int(NI_MAXHOST))
        defer {
            hname.deallocate()
        }
        let r = gethostname(hname, Int(NI_MAXHOST))
        if r < 0 || hname[0] == 0 {
            return "localhost"
        }
        return String(cString: hname)
#endif
    }
    
    open class func current() -> Host {
        return Host(Self._cachedCurrentHostName, .current)
    }
    
    public convenience init(name: String?) {
        self.init(name, .name)
    }
    
    public convenience init(address: String) {
        self.init(address, .address)
    }
    
    open func isEqual(to aHost: Host) -> Bool {
        if self === aHost { return true }
        return addresses.firstIndex { aHost.addresses.contains($0) } != nil
    }
    
    internal func _resolveCurrent(withInfo info: String) {
#if os(Windows)
        var szAddress: [WCHAR] =
            Array<WCHAR>(repeating: 0, count: Int(NI_MAXHOST))

        var ulSize: ULONG = 0
        var ulResult: ULONG =
            GetAdaptersAddresses(ULONG(AF_UNSPEC), 0, nil, nil, &ulSize)

        let arAdapters: UnsafeMutableRawPointer =
            UnsafeMutableRawPointer.allocate(byteCount: Int(ulSize),
                                             alignment: 1)
        defer { arAdapters.deallocate() }

        ulResult = GetAdaptersAddresses(ULONG(AF_UNSPEC), 0, nil,
                                        arAdapters.assumingMemoryBound(to: IP_ADAPTER_ADDRESSES.self),
                                        &ulSize)
        guard ulResult == ERROR_SUCCESS else { return }

        var pAdapter: UnsafeMutablePointer<IP_ADAPTER_ADDRESSES>? =
            arAdapters.assumingMemoryBound(to: IP_ADAPTER_ADDRESSES.self)
        while pAdapter != nil {
          // print("Adapter: \(String(cString: pAdapter!.pointee.AdapterName))")

          let arAddresses: UnsafeMutablePointer<IP_ADAPTER_UNICAST_ADDRESS> =
              pAdapter!.pointee.FirstUnicastAddress

          var pAddress: UnsafeMutablePointer<IP_ADAPTER_UNICAST_ADDRESS>? =
              arAddresses
          while pAddress != nil {
            switch pAddress!.pointee.Address.lpSockaddr.pointee.sa_family {
            case ADDRESS_FAMILY(AF_INET), ADDRESS_FAMILY(AF_INET6):
              if GetNameInfoW(pAddress!.pointee.Address.lpSockaddr,
                              pAddress!.pointee.Address.iSockaddrLength,
                              &szAddress, DWORD(szAddress.capacity), nil, 0,
                              NI_NUMERICHOST) == 0 {
                // print("\tIP Address: \(String(decodingCString: &szAddress, as: UTF16.self))")
                _addresses.append(String(decodingCString: &szAddress,
                                         as: UTF16.self))
              }
            default: break
            }
            pAddress = pAddress!.pointee.Next
          }

          pAdapter = pAdapter!.pointee.Next
        }
        _names = [info]
        _resolved = true
#elseif os(WASI) // WASI does not have getifaddrs
        _names = [info]
        _resolved = true
#else
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) != 0 {
            return
        }
        var ifa: UnsafeMutablePointer<ifaddrs>? = ifaddr
        let address = UnsafeMutablePointer<Int8>.allocate(capacity: Int(NI_MAXHOST))
        defer {
            freeifaddrs(ifaddr)
            address.deallocate()
        }
        while let ifaValue = ifa?.pointee {
            if let ifa_addr = ifaValue.ifa_addr, ifaValue.ifa_flags & UInt32(IFF_LOOPBACK) == 0 {
                let family = ifa_addr.pointee.sa_family
                if family == sa_family_t(AF_INET) || family == sa_family_t(AF_INET6) {
                    let sa_len: socklen_t = socklen_t((family == sa_family_t(AF_INET6)) ? MemoryLayout<sockaddr_in6>.size : MemoryLayout<sockaddr_in>.size)
#if os(OpenBSD)
                    let hostlen = size_t(NI_MAXHOST)
#else
                    let hostlen = socklen_t(NI_MAXHOST)
#endif
                    if getnameinfo(ifa_addr, sa_len, address, hostlen, nil, 0, NI_NUMERICHOST) == 0 {
                        _addresses.append(String(cString: address))
                    }
                }
            }
            ifa = ifaValue.ifa_next
        }
        _names = [info]
        _resolved = true
#endif
    }
    
    internal func _resolve() {
        guard _resolved == false else { return }
#if os(Windows)
        if let info = _info {
          if _type == .current { return _resolveCurrent(withInfo: info) }

          var hints: ADDRINFOW = ADDRINFOW()
          memset(&hints, 0, MemoryLayout<ADDRINFOW>.size)

          switch (_type) {
          case .name:
            hints.ai_flags = AI_PASSIVE | AI_CANONNAME
          case .address:
            hints.ai_flags = AI_PASSIVE | AI_CANONNAME | AI_NUMERICHOST
          case .current:
            break
          }
          hints.ai_family = AF_UNSPEC
          hints.ai_socktype = SOCK_STREAM
          hints.ai_protocol = IPPROTO_TCP.rawValue

          var aiResult: UnsafeMutablePointer<ADDRINFOW>?
          var bSucceeded: Bool = false
          info.withCString(encodedAs: UTF16.self) {
            if GetAddrInfoW($0, nil, &hints, &aiResult) == 0 {
              bSucceeded = true
            }
          }
          guard bSucceeded == true else { return }
          defer { FreeAddrInfoW(aiResult) }

          var wszHostName: [WCHAR] = Array<WCHAR>(repeating: 0, count: Int(NI_MAXHOST))

          while aiResult != nil {
            let aiInfo: ADDRINFOW = aiResult!.pointee
            var sa_len: socklen_t = 0

            switch aiInfo.ai_family {
            case AF_INET:
              sa_len = socklen_t(MemoryLayout<sockaddr_in>.size)
            case AF_INET6:
              sa_len = socklen_t(MemoryLayout<sockaddr_in6>.size)
            default:
              aiResult = aiInfo.ai_next
              continue
            }

            let lookup = { (content: inout [String], flags: Int32) in
              if GetNameInfoW(aiInfo.ai_addr, sa_len, &wszHostName,
                              DWORD(NI_MAXHOST), nil, 0, flags) == 0 {
                content.append(String(decodingCString: &wszHostName,
                                      as: UTF16.self))
              }
            }

            lookup(&_addresses, NI_NUMERICHOST)
            lookup(&_names, NI_NAMEREQD)
            lookup(&_names, NI_NOFQDN | NI_NAMEREQD)

            aiResult = aiInfo.ai_next
          }

          _resolved = true
        }
#elseif os(WASI) // WASI does not have getaddrinfo
        if let info = _info {
            _names = [info]
            _resolved = true
        }
#else
        if let info = _info {
            var flags: Int32 = 0
            switch (_type) {
            case .name:
                flags = AI_PASSIVE | AI_CANONNAME
            case .address:
                flags = AI_PASSIVE | AI_CANONNAME | AI_NUMERICHOST
            case .current:
                _resolveCurrent(withInfo: info)
                return
            }
            var hints = addrinfo()
            hints.ai_family = PF_UNSPEC
#if os(macOS) || os(iOS) || os(Android) || os(OpenBSD) || canImport(Musl)
            hints.ai_socktype = SOCK_STREAM
#else
            hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
#endif
    
            hints.ai_flags = flags
            
            var res0: UnsafeMutablePointer<addrinfo>? = nil
            let r = getaddrinfo(info, nil, &hints, &res0)
            defer {
                freeaddrinfo(res0)
            }
            if r != 0 {
                return
            }
            var res: UnsafeMutablePointer<addrinfo>? = res0
            let host = UnsafeMutablePointer<Int8>.allocate(capacity: Int(NI_MAXHOST))
            defer {
                host.deallocate()
            }
            while res != nil {
                let info = res!.pointee
                let family = info.ai_family
                if family != AF_INET && family != AF_INET6 {
                    res = info.ai_next
                    continue
                }
                let sa_len: socklen_t = socklen_t((family == AF_INET6) ? MemoryLayout<sockaddr_in6>.size : MemoryLayout<sockaddr_in>.size)
                let lookupInfo = { (content: inout [String], flags: Int32) in
#if os(OpenBSD)
                    let hostlen = size_t(NI_MAXHOST)
#else
                    let hostlen = socklen_t(NI_MAXHOST)
#endif
                    if getnameinfo(info.ai_addr, sa_len, host, hostlen, nil, 0, flags) == 0 {
                        content.append(String(cString: host))
                    }
                }
                lookupInfo(&_addresses, NI_NUMERICHOST)
                lookupInfo(&_names, NI_NAMEREQD)
                lookupInfo(&_names, NI_NOFQDN|NI_NAMEREQD)
                res = info.ai_next
            }
            _resolved = true
        }
#endif   
    }
    
    open var name: String? {
        return names.first
    }
    
    open var names: [String] {
        _resolve()
        return _names
    }
    
    open var address: String? {
        return addresses.first
    }
    
    open var addresses: [String] {
        _resolve()
        return _addresses
    }
    
    open var localizedName: String? {
        return nil
    }
}
