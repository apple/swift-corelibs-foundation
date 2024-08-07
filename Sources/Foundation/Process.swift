// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016, 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if canImport(Dispatch)
@_implementationOnly import CoreFoundation
#if os(Windows)
import WinSDK
import let WinSDK.HANDLE_FLAG_INHERIT
import let WinSDK.STARTF_USESTDHANDLES
import struct WinSDK.HANDLE
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#endif

internal import Synchronization

extension Process {
    public enum TerminationReason : Int, Sendable {
        case exit
        case uncaughtSignal
    }
}

private func WIFEXITED(_ status: Int32) -> Bool {
    return _WSTATUS(status) == 0
}

private func _WSTATUS(_ status: Int32) -> Int32 {
    return status & 0x7f
}

private func WIFSIGNALED(_ status: Int32) -> Bool {
    return (_WSTATUS(status) != 0) && (_WSTATUS(status) != 0x7f)
}

private func WEXITSTATUS(_ status: Int32) -> Int32 {
    return (status >> 8) & 0xff
}

private func WTERMSIG(_ status: Int32) -> Int32 {
    return status & 0x7f
}

// Protected by 'Once' below in `setup`
private nonisolated(unsafe) var managerThreadRunLoop : RunLoop? = nil

// Protected by managerThreadRunLoopIsRunningCondition
private nonisolated(unsafe) var managerThreadRunLoopIsRunning = false
private let managerThreadRunLoopIsRunningCondition = NSCondition()

internal let kCFSocketNoCallBack: CFOptionFlags = 0 // .noCallBack cannot be used because empty option flags are imported as unavailable.
internal let kCFSocketAcceptCallBack = CFSocketCallBackType.acceptCallBack.rawValue
internal let kCFSocketDataCallBack = CFSocketCallBackType.dataCallBack.rawValue

internal let kCFSocketSuccess = CFSocketError.success
internal let kCFSocketError = CFSocketError.error
internal let kCFSocketTimeout = CFSocketError.timeout

extension CFSocketError {
    init?(_ value: CFIndex) {
        self.init(rawValue: value)
    }
}

#if !canImport(Darwin) && !os(Windows)
private func findMaximumOpenFromProcSelfFD() -> CInt? {
    guard let dirPtr = opendir("/proc/self/fd") else {
        return nil
    }
    defer {
        closedir(dirPtr)
    }
    var highestFDSoFar = CInt(0)

    while let dirEntPtr = readdir(dirPtr) {
        var entryName = dirEntPtr.pointee.d_name
        let thisFD = withUnsafeBytes(of: &entryName) { entryNamePtr -> CInt? in
            CInt(String(decoding: entryNamePtr.prefix(while: { $0 != 0 }), as: Unicode.UTF8.self))
        }
        highestFDSoFar = max(thisFD ?? -1, highestFDSoFar)
    }

    return highestFDSoFar
}

func findMaximumOpenFD() -> CInt {
    if let maxFD = findMaximumOpenFromProcSelfFD() {
        // the precise method worked, let's return this fd.
        return maxFD
    }

    // We don't have /proc, let's go with the best estimate.
#if os(Linux)
    return getdtablesize()
#else
    return 4096
#endif
}
#endif


private func emptyRunLoopCallback(_ context : UnsafeMutableRawPointer?) -> Void {}


// Retain method for run loop source
private func runLoopSourceRetain(_ pointer : UnsafeRawPointer?) -> UnsafeRawPointer? {
    let ref = Unmanaged<AnyObject>.fromOpaque(pointer!).takeUnretainedValue()
    let retained = Unmanaged<AnyObject>.passRetained(ref)
    return unsafeBitCast(retained, to: UnsafeRawPointer.self)
}

// Release method for run loop source
private func runLoopSourceRelease(_ pointer : UnsafeRawPointer?) -> Void {
    Unmanaged<AnyObject>.fromOpaque(pointer!).release()
}

// Equal method for run loop source

private func runloopIsEqual(_ a : UnsafeRawPointer?, _ b : UnsafeRawPointer?) -> _DarwinCompatibleBoolean {
    
    let unmanagedrunLoopA = Unmanaged<AnyObject>.fromOpaque(a!)
    guard let runLoopA = unmanagedrunLoopA.takeUnretainedValue() as? RunLoop else {
        return false
    }
    
    let unmanagedRunLoopB = Unmanaged<AnyObject>.fromOpaque(a!)
    guard let runLoopB = unmanagedRunLoopB.takeUnretainedValue() as? RunLoop else {
        return false
    }
    
    guard runLoopA == runLoopB else {
        return false
    }
    
    return true
}


// Equal method for process in run loop source
private func processIsEqual(_ a : UnsafeRawPointer?, _ b : UnsafeRawPointer?) -> _DarwinCompatibleBoolean {
    
    let unmanagedProcessA = Unmanaged<AnyObject>.fromOpaque(a!)
    guard let processA = unmanagedProcessA.takeUnretainedValue() as? Process else {
        return false
    }
    
    let unmanagedProcessB = Unmanaged<AnyObject>.fromOpaque(a!)
    guard let processB = unmanagedProcessB.takeUnretainedValue() as? Process else {
        return false
    }
    
    guard processA == processB else {
        return false
    }
    
    return true
}

#if os(Windows)

private func quoteWindowsCommandLine(_ commandLine: [String]) -> String {
    func quoteWindowsCommandArg(arg: String) -> String {
        // Windows escaping, adapted from Daniel Colascione's "Everyone quotes
        // command line arguments the wrong way" - Microsoft Developer Blog
        if !arg.contains(where: {" \t\n\"".contains($0)}) {
            return arg
        }

        // To escape the command line, we surround the argument with quotes. However
        // the complication comes due to how the Windows command line parser treats
        // backslashes (\) and quotes (")
        //
        // - \ is normally treated as a literal backslash
        //     - e.g. foo\bar\baz => foo\bar\baz
        // - However, the sequence \" is treated as a literal "
        //     - e.g. foo\"bar => foo"bar
        //
        // But then what if we are given a path that ends with a \? Surrounding
        // foo\bar\ with " would be "foo\bar\" which would be an unterminated string

        // since it ends on a literal quote. To allow this case the parser treats:
        //
        // - \\" as \ followed by the " metachar
        // - \\\" as \ followed by a literal "
        // - In general:
        //     - 2n \ followed by " => n \ followed by the " metachar
        //     - 2n+1 \ followed by " => n \ followed by a literal "
        var quoted = "\""
        var unquoted = arg.unicodeScalars

        while !unquoted.isEmpty {
            guard let firstNonBackslash = unquoted.firstIndex(where: { $0 != "\\" }) else {
                // String ends with a backslash e.g. foo\bar\, escape all the backslashes
                // then add the metachar " below
                let backslashCount = unquoted.count
                quoted.append(String(repeating: "\\", count: backslashCount * 2))
                break
            }
            let backslashCount = unquoted.distance(from: unquoted.startIndex, to: firstNonBackslash)
            if (unquoted[firstNonBackslash] == "\"") {
                // This is  a string of \ followed by a " e.g. foo\"bar. Escape the
                // backslashes and the quote
                quoted.append(String(repeating: "\\", count: backslashCount * 2 + 1))
                quoted.append(String(unquoted[firstNonBackslash]))
            } else {
                // These are just literal backslashes
                quoted.append(String(repeating: "\\", count: backslashCount))
                quoted.append(String(unquoted[firstNonBackslash]))
            }
            // Drop the backslashes and the following character
            unquoted.removeFirst(backslashCount + 1)
        }
        quoted.append("\"")
        return quoted
    }
    return commandLine.map(quoteWindowsCommandArg).joined(separator: " ")
}
#endif

open class Process: NSObject, @unchecked Sendable {
    static let once = Mutex(false)
    
    private static func setup() {
        once.withLock {
            if !$0 {
                let thread = Thread {
                    managerThreadRunLoop = RunLoop.current
                    var emptySourceContext = CFRunLoopSourceContext()
                    emptySourceContext.version = 0
                    emptySourceContext.retain = runLoopSourceRetain
                    emptySourceContext.release = runLoopSourceRelease
                    emptySourceContext.equal = runloopIsEqual
                    emptySourceContext.perform = emptyRunLoopCallback
                    managerThreadRunLoop!.withUnretainedReference {
                        (refPtr: UnsafeMutablePointer<UInt8>) in
                        emptySourceContext.info = UnsafeMutableRawPointer(refPtr)
                    }
                    
                    CFRunLoopAddSource(managerThreadRunLoop?._cfRunLoop, CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &emptySourceContext), kCFRunLoopDefaultMode)
                    
                    managerThreadRunLoopIsRunningCondition.lock()
                    
                    CFRunLoopPerformBlock(managerThreadRunLoop?._cfRunLoop, kCFRunLoopDefaultMode) {
                        managerThreadRunLoopIsRunning = true
                        managerThreadRunLoopIsRunningCondition.broadcast()
                        managerThreadRunLoopIsRunningCondition.unlock()
                    }
                    
                    managerThreadRunLoop?.run()
                    fatalError("Process manager run loop exited unexpectedly; it should run forever once initialized")
                }
                thread.start()
                managerThreadRunLoopIsRunningCondition.lock()
                while managerThreadRunLoopIsRunning == false {
                    managerThreadRunLoopIsRunningCondition.wait()
                }
                managerThreadRunLoopIsRunningCondition.unlock()
                $0 = true
            }
        }
    }

    // Create an Process which can be run at a later time
    // An Process can only be run once. Subsequent attempts to
    // run an Process will raise.
    // Upon process death a notification will be sent
    //   { Name = ProcessDidTerminateNotification; object = process; }
    //
    
    public override init() {

    }

    // These properties can only be set before a launch.
    private var _executable: URL?
    open var executableURL: URL? {
        get { _executable }
        set {
            guard let url = newValue, url.isFileURL else {
                fatalError("must provide a launch path")
            }
            _executable = url
        }
    }

    private var _currentDirectoryPath = FileManager.default.currentDirectoryPath
    open var currentDirectoryURL: URL? {
        get { _currentDirectoryPath == "" ? nil : URL(fileURLWithPath: _currentDirectoryPath, isDirectory: true) }
        set {
            // Setting currentDirectoryURL to nil resets to the current directory
            if let url = newValue {
                guard url.isFileURL else { fatalError("non-file URL argument") }
                _currentDirectoryPath = url.path
            } else {
                _currentDirectoryPath = FileManager.default.currentDirectoryPath
            }
        }
    }

    open var arguments: [String]?
    open var environment: [String : String]? // if not set, use current

    @available(*, deprecated, renamed: "executableURL")
    open var launchPath: String? {
        get { return executableURL?.path }
        set { executableURL = (newValue != nil) ? URL(fileURLWithPath: newValue!) : nil }
    }

    @available(*, deprecated, renamed: "currentDirectoryURL")
    open var currentDirectoryPath: String {
        get { _currentDirectoryPath }
        set { _currentDirectoryPath = newValue }
    }

    // Standard I/O channels; could be either a FileHandle or a Pipe

    open var standardInput: Any? = FileHandle._stdinFileHandle {
        willSet {
            precondition(newValue is Pipe || newValue is FileHandle || newValue == nil,
                         "standardInput must be either Pipe or FileHandle")
        }
    }

    open var standardOutput: Any? = FileHandle._stdoutFileHandle {
        willSet {
            precondition(newValue is Pipe || newValue is FileHandle || newValue == nil,
                         "standardOutput must be either Pipe or FileHandle")
        }
    }
    
    open var standardError: Any? = FileHandle._stderrFileHandle {
        willSet {
            precondition(newValue is Pipe || newValue is FileHandle || newValue == nil,
                         "standardError must be either Pipe or FileHandle")
        }
    }
    
    private class NonexportedCFRunLoopSourceContextStorage {
        internal var value: CFRunLoopSourceContext?
    }

    private class NonexportedCFRunLoopSourceStorage {
        internal var value: CFRunLoopSource?
    }

    private var _runLoopSourceContextStorage = NonexportedCFRunLoopSourceContextStorage()
    private final var runLoopSourceContext: CFRunLoopSourceContext? {
        get { _runLoopSourceContextStorage.value }
        set { _runLoopSourceContextStorage.value = newValue }
    }
    
    private var _runLoopSourceStorage = NonexportedCFRunLoopSourceStorage()
    private final var runLoopSource: CFRunLoopSource? {
        get { _runLoopSourceStorage.value }
        set { _runLoopSourceStorage.value = newValue }
    }
    
    fileprivate weak var runLoop : RunLoop? = nil
    
    private var processLaunchedCondition = NSCondition()
    
    // Actions
    
    @available(*, deprecated, renamed: "run")
    open func launch() {
        do {
            try run()
        } catch let nserror as NSError {
            if let path = nserror.userInfo[NSFilePathErrorKey] as? String, path == currentDirectoryPath {
                // Foundation throws an NSException when changing the working directory fails,
                // and unfortunately launch() is not marked `throws`, so we get away with a
                // fatalError.
                switch CocoaError.Code(rawValue: nserror.code) {
                case .fileReadNoSuchFile:
                    fatalError("Process: The specified working directory does not exist.")
                case .fileReadNoPermission:
                    fatalError("Process: The specified working directory cannot be accessed.")
                default:
                    fatalError("Process: The specified working directory cannot be set.")
                }
            } else {
                fatalError(String(describing: nserror))
            }
        } catch {
            fatalError(String(describing: error))
        }
    }

    #if os(Windows)
    private func _socketpair() -> (first: SOCKET, second: SOCKET) {
      let listener: SOCKET = socket(AF_INET, SOCK_STREAM, 0)
      if listener == INVALID_SOCKET {
        return (first: INVALID_SOCKET, second: INVALID_SOCKET)
      }
      defer { closesocket(listener) }

      var result: Int32 = SOCKET_ERROR

      var address: sockaddr_in =
          sockaddr_in(sin_family: ADDRESS_FAMILY(AF_INET), sin_port: USHORT(0),
                      sin_addr: IN_ADDR(S_un: in_addr.__Unnamed_union_S_un(S_un_b: in_addr.__Unnamed_union_S_un.__Unnamed_struct_S_un_b(s_b1: 127, s_b2: 0, s_b3: 0, s_b4: 1))),
                      sin_zero: (CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0)))
      withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          result = bind(listener, $0, Int32(MemoryLayout<sockaddr_in>.size))
        }
      }

      if result == SOCKET_ERROR {
        return (first: INVALID_SOCKET, second: INVALID_SOCKET)
      }

      if listen(listener, 1) == SOCKET_ERROR {
        return (first: INVALID_SOCKET, second: INVALID_SOCKET)
      }

      withUnsafeMutablePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          var value: Int32 = Int32(MemoryLayout<sockaddr_in>.size)
          result = getsockname(listener, $0, &value)
        }
      }
      if result == SOCKET_ERROR {
        return (first: INVALID_SOCKET, second: INVALID_SOCKET)
      }

      let first: SOCKET = socket(AF_INET, SOCK_STREAM, 0)
      if first == INVALID_SOCKET {
        return (first: INVALID_SOCKET, second: INVALID_SOCKET)
      }

      withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          result = connect(first, $0, Int32(MemoryLayout<sockaddr_in>.size))
        }
      }

      if result == SOCKET_ERROR {
        closesocket(first)
        return (first: INVALID_SOCKET, second: INVALID_SOCKET)
      }

      var value: u_long = 1
      if ioctlsocket(first, CLong(FIONBIO), &value) == SOCKET_ERROR {
        closesocket(first)
        return (first: INVALID_SOCKET, second: INVALID_SOCKET)
      }

      var option: CInt = 1
      if setsockopt(first, IPPROTO_TCP.rawValue, TCP_NODELAY, &option,
                    CInt(MemoryLayout.size(ofValue: option))) == SOCKET_ERROR {
        closesocket(first)
        return (first: INVALID_SOCKET, second: INVALID_SOCKET)
      }

      let second: SOCKET = accept(listener, nil, nil)
      if second == INVALID_SOCKET {
        closesocket(first)
        return (first: INVALID_SOCKET, second: INVALID_SOCKET)
      }

      return (first: first, second: second)
    }
    #endif

    open func run() throws {

        func _throwIfPosixError(_ posixErrno: Int32) throws {
            if posixErrno != 0 {
                // When this is called, self.executableURL is already known to be non-nil
                let userInfo: [String: Any] = [ NSURLErrorKey: self.executableURL! ]
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(posixErrno), userInfo: userInfo)
            }
        }

        self.processLaunchedCondition.lock()
        defer {
            self.processLaunchedCondition.broadcast()
            self.processLaunchedCondition.unlock()
        }

        // Dispatch the manager thread if it isn't already running
        Process.setup()

        // Check that the process isnt run more than once
        guard hasStarted == false && hasFinished == false else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSExecutableLoadError)
        }

        // Ensure that the launch path is set
        guard let launchPath = self.executableURL?.path else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        }

#if os(Windows)
        var command: [String] = [try FileManager.default._fileSystemRepresentation(withPath: launchPath) { String(decodingCString: $0, as: UTF16.self) }]
        if let arguments = self.arguments {
          command.append(contentsOf: arguments)
        }

        var siStartupInfo: STARTUPINFOW = STARTUPINFOW()
        siStartupInfo.cb = DWORD(MemoryLayout<STARTUPINFOW>.size)
        siStartupInfo.dwFlags = DWORD(STARTF_USESTDHANDLES)

        var _devNull: FileHandle?
        func devNullFd() throws -> HANDLE {
            _devNull = try _devNull ?? FileHandle(forUpdating: URL(fileURLWithPath: "NUL", isDirectory: false))
            return _devNull!._handle
        }

        var modifiedPipes: [(handle: HANDLE, prevValue: DWORD)] = []
        defer { modifiedPipes.forEach { SetHandleInformation($0.handle, DWORD(HANDLE_FLAG_INHERIT), $0.prevValue) } }

        func deferReset(handle: HANDLE) throws {
            var handleInfo: DWORD = 0
            guard GetHandleInformation(handle, &handleInfo) else {
                throw _NSErrorWithWindowsError(GetLastError(), reading: false)
            }
            modifiedPipes.append((handle: handle, prevValue: handleInfo & DWORD(HANDLE_FLAG_INHERIT)))
        }

        switch standardInput {
        case let pipe as Pipe:
            siStartupInfo.hStdInput = pipe.fileHandleForReading._handle
            try deferReset(handle: pipe.fileHandleForWriting._handle)
            SetHandleInformation(pipe.fileHandleForWriting._handle, DWORD(HANDLE_FLAG_INHERIT), 0)

        // nil or NullDevice maps to NUL
        case let handle as FileHandle where handle === FileHandle._nulldeviceFileHandle: fallthrough
        case .none:
            siStartupInfo.hStdInput = try devNullFd()

        case let handle as FileHandle:
            siStartupInfo.hStdInput = handle._handle
            try deferReset(handle: handle._handle)
            SetHandleInformation(handle._handle, DWORD(HANDLE_FLAG_INHERIT), 1)
        default: break
        }

        switch standardOutput {
        case let pipe as Pipe:
            siStartupInfo.hStdOutput = pipe.fileHandleForWriting._handle
            try deferReset(handle: pipe.fileHandleForReading._handle)
            SetHandleInformation(pipe.fileHandleForReading._handle, DWORD(HANDLE_FLAG_INHERIT), 0)

        // nil or NullDevice maps to NUL
        case let handle as FileHandle where handle === FileHandle._nulldeviceFileHandle: fallthrough
        case .none:
            siStartupInfo.hStdOutput = try devNullFd()

        case let handle as FileHandle:
            siStartupInfo.hStdOutput = handle._handle
            try deferReset(handle: handle._handle)
            SetHandleInformation(handle._handle, DWORD(HANDLE_FLAG_INHERIT), 1)
        default: break
        }

        switch standardError {
        case let pipe as Pipe:
            siStartupInfo.hStdError = pipe.fileHandleForWriting._handle
            try deferReset(handle: pipe.fileHandleForReading._handle)
            SetHandleInformation(pipe.fileHandleForReading._handle, DWORD(HANDLE_FLAG_INHERIT), 0)

        // nil or NullDevice maps to NUL
        case let handle as FileHandle where handle === FileHandle._nulldeviceFileHandle: fallthrough
        case .none:
            siStartupInfo.hStdError = try devNullFd()

        case let handle as FileHandle:
            siStartupInfo.hStdError = handle._handle
            try deferReset(handle: handle._handle)
            SetHandleInformation(handle._handle, DWORD(HANDLE_FLAG_INHERIT), 1)
        default: break
        }

        var piProcessInfo: PROCESS_INFORMATION = PROCESS_INFORMATION()

        var environment: [String:String] = [:]
        if let env = self.environment {
            environment = env
        } else {
            environment = ProcessInfo.processInfo.environment
        }

        // On Windows, the PATH is required in order to locate dlls needed by
        // the process so we should also pass that to the child
        if environment["Path"] == nil, let path = ProcessInfo.processInfo.environment["Path"] {
            environment["Path"] = path
        }

        // NOTE(compnerd) the environment string must be terminated by a double
        // null-terminator.  Otherwise, CreateProcess will fail with
        // INVALID_PARMETER.
        let szEnvironment: String = environment.map { $0.key + "=" + $0.value }.joined(separator: "\0") + "\0\0"

        let sockets: (first: SOCKET, second: SOCKET) = _socketpair()

        var context: CFSocketContext = CFSocketContext()
        context.version = 0
        context.retain = runLoopSourceRetain
        context.release = runLoopSourceRelease
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let socket: CFSocket = CFSocketCreateWithNative(nil, CFSocketNativeHandle(sockets.first), CFOptionFlags(kCFSocketDataCallBack), { (socket, type, address, data, info) in
            let process: Process = NSObject.unretainedReference(info!)
            process.processLaunchedCondition.lock()
            while process.isRunning == false {
                process.processLaunchedCondition.wait()
            }
            process.processLaunchedCondition.unlock()

            WaitForSingleObject(process.processHandle, WinSDK.INFINITE)

            // On Windows, the top nibble of an NTSTATUS indicates severity, with
            // the top two bits both being set (0b11) indicating an error. In
            // addition, in a well formed NTSTATUS, the 4th bit must be 0.
            // The third bit indicates if the error is a Microsoft defined error
            // and may or may not be set.
            //
            // If we receive such an error, we'll indicate that the process
            // exited abnormally (confusingly indicating "signalled" so we match
            // POSIX behaviour for abnormal exits).
            //
            // However, we don't want user programs which normally exit -1, -2,
            // etc to count as exited abnormally, so we specifically check for a
            // top nibble of 0b11_0 so that e.g. 0xFFFFFFFF, won't trigger an
            // abnormal exit.
            //
            // Additionally, on Windows, an uncaught signal terminates the
            // program with the magic exit code 3, regardless of the signal (I'd
            // personally love to know the reason for this). So we also consider
            // 3 to be an abnormal exit.
            var dwExitCode: DWORD = 0
            GetExitCodeProcess(process.processHandle, &dwExitCode)
            if (dwExitCode & 0xF0000000) == 0x80000000      // HRESULT
            || (dwExitCode & 0xF0000000) == 0xC0000000      // NTSTATUS
            || (dwExitCode & 0xF0000000) == 0xE0000000      // NTSTATUS (Customer)
            || dwExitCode == 3 {
                process._terminationStatus = Int32(dwExitCode & 0x3FFFFFFF)
                process._terminationReason = .uncaughtSignal
            } else {
                process._terminationStatus = Int32(bitPattern: UInt32(dwExitCode))
                process._terminationReason = .exit
            }

            // Signal waitUntilExit() and optionally invoke termination handler.
            process.terminateRunLoop()

            CFSocketInvalidate(socket)
        }, &context)
        CFSocketSetSocketFlags(socket, CFOptionFlags(kCFSocketCloseOnInvalidate))

        let source: CFRunLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0)
        CFRunLoopAddSource(managerThreadRunLoop?._cfRunLoop, source, kCFRunLoopDefaultMode)

        let workingDirectory = currentDirectoryURL?.path ?? FileManager.default.currentDirectoryPath
        try quoteWindowsCommandLine(command).withCString(encodedAs: UTF16.self) { wszCommandLine in
          try FileManager.default._fileSystemRepresentation(withPath: workingDirectory) { wszCurrentDirectory in
            try szEnvironment.withCString(encodedAs: UTF16.self) { wszEnvironment in
              if !CreateProcessW(nil, UnsafeMutablePointer<WCHAR>(mutating: wszCommandLine),
                                 nil, nil, true,
                                 DWORD(CREATE_UNICODE_ENVIRONMENT), UnsafeMutableRawPointer(mutating: wszEnvironment),
                                 wszCurrentDirectory,
                                 &siStartupInfo, &piProcessInfo) {
                let error = GetLastError()
                // If the current directory doesn't exist, Windows
                // throws an ERROR_DIRECTORY. Since POSIX gives an
                // ENOENT, we intercept the error to match the POSIX
                // behaviour
                if error == ERROR_DIRECTORY {
                    throw _NSErrorWithWindowsError(DWORD(ERROR_FILE_NOT_FOUND), reading: true)
                }
                throw _NSErrorWithWindowsError(GetLastError(), reading: true)
              }
            }
          }
        }

        self.processHandle = piProcessInfo.hProcess
        if !CloseHandle(piProcessInfo.hThread) {
          throw _NSErrorWithWindowsError(GetLastError(), reading: false)
        }

        if let pipe = standardInput as? Pipe {
          pipe.fileHandleForReading.closeFile()
        }
        if let pipe = standardOutput as? Pipe {
          pipe.fileHandleForWriting.closeFile()
        }
        if let pipe = standardError as? Pipe {
          pipe.fileHandleForWriting.closeFile()
        }

        self.runLoop = RunLoop.current
        self.runLoopSourceContext =
            CFRunLoopSourceContext(version: 0,
                                   info: Unmanaged.passUnretained(self).toOpaque(),
                                   retain: { runLoopSourceRetain($0) },
                                   release: { runLoopSourceRelease($0) },
                                   copyDescription: nil,
                                   equal: { processIsEqual($0, $1) },
                                   hash: nil,
                                   schedule: nil,
                                   cancel: nil,
                                   perform: { emptyRunLoopCallback($0) })
        self.runLoopSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &self.runLoopSourceContext!)

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode)

        isRunning = true

        closesocket(sockets.second)
#else
        // Initial checks that the launchPath points to an executable file. posix_spawn()
        // can return success even if executing the program fails, eg fork() works but execve()
        // fails, so try and check as much as possible beforehand.
        try FileManager.default._fileSystemRepresentation(withPath: launchPath, { fsRep in
            var statInfo = stat()
            guard stat(fsRep, &statInfo) == 0 else {
                throw _NSErrorWithErrno(errno, reading: true, path: launchPath)
            }

            let isRegularFile: Bool = statInfo.st_mode & S_IFMT == S_IFREG
            guard isRegularFile == true else {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
            }

            guard access(fsRep, X_OK) == 0 else {
                throw _NSErrorWithErrno(errno, reading: true, path: launchPath)
            }
        })
        // Convert the arguments array into a posix_spawn-friendly format
        
        var args = [launchPath]
        if let arguments = self.arguments {
            args.append(contentsOf: arguments)
        }
        
        let argv : UnsafeMutablePointer<UnsafeMutablePointer<Int8>?> = args.withUnsafeBufferPointer {
            let array : UnsafeBufferPointer<String> = $0
            let buffer = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: array.count + 1)
            buffer.initialize(from: array.map { $0.withCString(strdup) }, count: array.count)
            buffer[array.count] = nil
            return buffer
        }
        
        defer {
            for arg in argv ..< argv + args.count {
                free(UnsafeMutableRawPointer(arg.pointee))
            }
            argv.deallocate()
        }

        var env: [String: String]
        if let e = environment {
            env = e
        } else {
            env = ProcessInfo.processInfo.environment
        }

        let nenv = env.count
        let envp = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: 1 + nenv)
        envp.initialize(from: env.map { strdup("\($0)=\($1)") }, count: nenv)
        envp[env.count] = nil

        defer {
            for pair in envp ..< envp + env.count {
                free(UnsafeMutableRawPointer(pair.pointee))
            }
            envp.deallocate()
        }

        var taskSocketPair : [Int32] = [0, 0]
#if os(macOS) || os(iOS) || os(Android) || os(OpenBSD) || canImport(Musl)
        socketpair(AF_UNIX, SOCK_STREAM, 0, &taskSocketPair)
#else
        socketpair(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0, &taskSocketPair)
#endif
        var context = CFSocketContext()
        context.version = 0
        context.retain = runLoopSourceRetain
        context.release = runLoopSourceRelease
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let socket = CFSocketCreateWithNative( nil, taskSocketPair[0], CFOptionFlags(kCFSocketDataCallBack), {
            (socket, type, address, data, info )  in
            
            let process: Process = NSObject.unretainedReference(info!)
            
            process.processLaunchedCondition.lock()
            while process.isRunning == false {
                process.processLaunchedCondition.wait()
            }
            
            process.processLaunchedCondition.unlock()
            
            var exitCode : Int32 = 0
#if CYGWIN
            let exitCodePtrWrapper = withUnsafeMutablePointer(to: &exitCode) {
                exitCodePtr in
                __wait_status_ptr_t(__int_ptr: exitCodePtr)
            }
#endif
            var waitResult : Int32 = 0

            repeat {
#if CYGWIN
                waitResult = waitpid( process.processIdentifier, exitCodePtrWrapper, 0)
#else
                waitResult = waitpid( process.processIdentifier, &exitCode, 0)
#endif
            } while ( (waitResult == -1) && (errno == EINTR) )

            if WIFSIGNALED(exitCode) {
                process._terminationStatus = WTERMSIG(exitCode)
                process._terminationReason = .uncaughtSignal
            } else {
                assert(WIFEXITED(exitCode))
                process._terminationStatus = WEXITSTATUS(exitCode)
                process._terminationReason = .exit
            }
            
            // Signal waitUntilExit() and optionally invoke termination handler.
            process.terminateRunLoop()
            
            CFSocketInvalidate( socket )
            
        }, &context )
        
        CFSocketSetSocketFlags( socket, CFOptionFlags(kCFSocketCloseOnInvalidate))
        
        let source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0)
        CFRunLoopAddSource(managerThreadRunLoop?._cfRunLoop, source, kCFRunLoopDefaultMode)

        let fileActions = _CFPosixSpawnFileActionsAlloc()
        defer {
            _CFPosixSpawnFileActionsDestroy(fileActions)
            _CFPosixSpawnFileActionsDealloc(fileActions)
        }
        try _throwIfPosixError(_CFPosixSpawnFileActionsInit(fileActions))

        // File descriptors to duplicate in the child process. This allows
        // output redirection to NSPipe or NSFileHandle.
        var adddup2 = [Int32: Int32]()

        // File descriptors to close in the child process. A set so that
        // shared pipes only get closed once. Would result in EBADF on OSX
        // otherwise.
        var addclose = Set<Int32>()

        var _devNull: FileHandle?
        func devNullFd() throws -> Int32 {
            _devNull = try _devNull ?? FileHandle(forUpdating: URL(fileURLWithPath: "/dev/null", isDirectory: false))
            return _devNull!.fileDescriptor
        }

        switch standardInput {
        case let pipe as Pipe:
            adddup2[STDIN_FILENO] = pipe.fileHandleForReading.fileDescriptor
            addclose.insert(pipe.fileHandleForWriting.fileDescriptor)

        // nil or NullDevice map to /dev/null
        case let handle as FileHandle where handle === FileHandle._nulldeviceFileHandle: fallthrough
        case .none:
            adddup2[STDIN_FILENO] = try devNullFd()

        // No need to dup stdin to stdin
        case let handle as FileHandle where handle === FileHandle._stdinFileHandle: break

        case let handle as FileHandle:
            adddup2[STDIN_FILENO] = handle.fileDescriptor

        default: break
        }

        switch standardOutput {
        case let pipe as Pipe:
            adddup2[STDOUT_FILENO] = pipe.fileHandleForWriting.fileDescriptor
            addclose.insert(pipe.fileHandleForReading.fileDescriptor)

        // nil or NullDevice map to /dev/null
        case let handle as FileHandle where handle === FileHandle._nulldeviceFileHandle: fallthrough
        case .none:
            adddup2[STDOUT_FILENO] = try devNullFd()

        // No need to dup stdout to stdout
        case let handle as FileHandle where handle === FileHandle._stdoutFileHandle: break

        case let handle as FileHandle:
            adddup2[STDOUT_FILENO] = handle.fileDescriptor

        default: break
        }

        switch standardError {
        case let pipe as Pipe:
            adddup2[STDERR_FILENO] = pipe.fileHandleForWriting.fileDescriptor
            addclose.insert(pipe.fileHandleForReading.fileDescriptor)

        // nil or NullDevice map to /dev/null
        case let handle as FileHandle where handle === FileHandle._nulldeviceFileHandle: fallthrough
        case .none:
            adddup2[STDERR_FILENO] = try devNullFd()

        // No need to dup stderr to stderr
        case let handle as FileHandle where handle === FileHandle._stderrFileHandle: break

        case let handle as FileHandle:
            adddup2[STDERR_FILENO] = handle.fileDescriptor

        default: break
        }

        for (new, old) in adddup2 {
            try _throwIfPosixError(_CFPosixSpawnFileActionsAddDup2(fileActions, old, new))
        }
        for fd in addclose.filter({ $0 >= 0 }) {
            try _throwIfPosixError(_CFPosixSpawnFileActionsAddClose(fileActions, fd))
        }

#if canImport(Darwin) || os(Android) || os(OpenBSD)
        var spawnAttrs: posix_spawnattr_t? = nil
#else
        var spawnAttrs: posix_spawnattr_t = posix_spawnattr_t()
#endif
#if os(Android)
        guard var spawnAttrs else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                    NSURLErrorKey:self.executableURL!
            ])
        }
#endif
        try _throwIfPosixError(posix_spawnattr_init(&spawnAttrs))
        try _throwIfPosixError(posix_spawnattr_setflags(&spawnAttrs, .init(POSIX_SPAWN_SETPGROUP)))
#if canImport(Darwin)
        try _throwIfPosixError(posix_spawnattr_setflags(&spawnAttrs, .init(POSIX_SPAWN_CLOEXEC_DEFAULT)))
#else
        // POSIX_SPAWN_CLOEXEC_DEFAULT is an Apple extension so emulate it.
        for fd in 3 ... findMaximumOpenFD() {
            guard adddup2[fd] == nil &&
                  !addclose.contains(fd) &&
                  fd != taskSocketPair[1] else {
                    continue // Do not double-close descriptors, or close those pertaining to Pipes or FileHandles we want inherited.
            }
            try _throwIfPosixError(_CFPosixSpawnFileActionsAddClose(fileActions, fd))
        }
#endif

        let fileManager = FileManager()
        let previousDirectoryPath = fileManager.currentDirectoryPath
        if let dir = currentDirectoryURL?.path, !fileManager.changeCurrentDirectoryPath(dir) {
            throw _NSErrorWithErrno(errno, reading: true, url: currentDirectoryURL)
        }

        defer {
            // Reset the previous working directory path.
            _ = fileManager.changeCurrentDirectoryPath(previousDirectoryPath)
        }

        // Launch
        var pid = pid_t()
        
        try FileManager.default._fileSystemRepresentation(withPath: launchPath, { fsRep in
            guard _CFPosixSpawn(&pid, fsRep, fileActions, &spawnAttrs, argv, envp) == 0 else {
                throw _NSErrorWithErrno(errno, reading: true, path: launchPath)
            }
        })
        posix_spawnattr_destroy(&spawnAttrs)

        // Close the write end of the input and output pipes.
        if let pipe = standardInput as? Pipe {
            pipe.fileHandleForReading.closeFile()
        }
        if let pipe = standardOutput as? Pipe {
            pipe.fileHandleForWriting.closeFile()
        }
        if let pipe = standardError as? Pipe {
            pipe.fileHandleForWriting.closeFile()
        }

        close(taskSocketPair[1])

        self.runLoop = RunLoop.current
        self.runLoopSourceContext = CFRunLoopSourceContext(version: 0,
                                                           info: Unmanaged.passUnretained(self).toOpaque(),
                                                           retain: { return runLoopSourceRetain($0) },
                                                           release: { runLoopSourceRelease($0) },
                                                           copyDescription: nil,
                                                           equal: { return processIsEqual($0, $1) },
                                                           hash: nil,
                                                           schedule: nil,
                                                           cancel: nil,
                                                           perform: { emptyRunLoopCallback($0) })
        self.runLoopSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &runLoopSourceContext!)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode)
        
        isRunning = true
        
        self.processIdentifier = pid
#endif
    }
    
    open func interrupt() {
        precondition(hasStarted, "task not launched")
#if os(Windows)
        TerminateProcess(processHandle, UINT(SIGINT))
#else
        kill(processIdentifier, SIGINT)
#endif
    }

    open func terminate() {
        precondition(hasStarted, "task not launched")
#if os(Windows)
        TerminateProcess(processHandle, UINT(0xC0000000 | DWORD(SIGTERM)))
#else
        kill(processIdentifier, SIGTERM)
#endif
    }

    // Every suspend() has to be balanced with a resume() so keep a count of both.
    private var suspendCount = 0

    open func suspend() -> Bool {
#if os(Windows)
      let pNTSuspendProcess: Optional<(HANDLE) -> LONG> =
          unsafeBitCast(GetProcAddress(GetModuleHandleA("ntdll.dll"),
                                       "NtSuspendProcess"),
                        to: Optional<(HANDLE) -> LONG>.self)
      if let pNTSuspendProcess = pNTSuspendProcess {
        if pNTSuspendProcess(processHandle) < 0 {
          return false
        }
        suspendCount += 1
        return true
      }
      return false
#else
        if kill(processIdentifier, SIGSTOP) == 0 {
            suspendCount += 1
            return true
        } else {
            return false
        }
#endif
    }

    open func resume() -> Bool {
        var success: Bool = true
#if os(Windows)
        if suspendCount == 1 {
          let pNTResumeProcess: Optional<(HANDLE) -> NTSTATUS> =
              unsafeBitCast(GetProcAddress(GetModuleHandleA("ntdll.dll"),
                                           "NtResumeProcess"),
                            to: Optional<(HANDLE) -> NTSTATUS>.self)
          if let pNTResumeProcess = pNTResumeProcess {
            if pNTResumeProcess(processHandle) < 0 {
              success = false
            }
          }
        }
#else
        if suspendCount == 1 {
            success = kill(processIdentifier, SIGCONT) == 0
        }
#endif
        if success {
            suspendCount -= 1
        }
        return success
    }
    
    // status
#if os(Windows)
    open private(set) var processHandle: HANDLE = INVALID_HANDLE_VALUE
    open var processIdentifier: Int32 {
      guard processHandle != INVALID_HANDLE_VALUE else {
          return 0
      }
      return Int32(GetProcessId(processHandle))
    }
    open private(set) var isRunning: Bool = false

    private var hasStarted: Bool {
      return processHandle != INVALID_HANDLE_VALUE
    }
    private var hasFinished: Bool {
      return hasStarted && !isRunning
    }
#else
    open private(set) var processIdentifier: Int32 = 0
    open private(set) var isRunning: Bool = false
    private var hasStarted: Bool { return processIdentifier > 0 }
    private var hasFinished: Bool { return !isRunning && processIdentifier > 0 }
#endif

    private var _terminationStatus: Int32 = 0
    public var terminationStatus: Int32 {
        precondition(hasStarted, "task not launched")
        precondition(hasFinished, "task still running")
        return _terminationStatus
    }

    private var _terminationReason: TerminationReason = .exit
    public var terminationReason: TerminationReason {
        precondition(hasStarted, "task not launched")
        precondition(hasFinished, "task still running")
        return _terminationReason
    }

    /*
    A block to be invoked when the process underlying the Process terminates.  Setting the block to nil is valid, and stops the previous block from being invoked, as long as it hasn't started in any way.  The Process is passed as the argument to the block so the block does not have to capture, and thus retain, it.  The block is copied when set.  Only one termination handler block can be set at any time.  The execution context in which the block is invoked is undefined.  If the Process has already finished, the block is executed immediately/soon (not necessarily on the current thread).  If a terminationHandler is set on an Process, the ProcessDidTerminateNotification notification is not posted for that process.  Also note that -waitUntilExit won't wait until the terminationHandler has been fully executed.  You cannot use this property in a concrete subclass of Process which hasn't been updated to include an implementation of the storage and use of it.  
    */
    open var terminationHandler: (@Sendable (Process) -> Void)?
    open var qualityOfService: QualityOfService = .default  // read-only after the process is launched


    open class func run(_ url: URL, arguments: [String], terminationHandler: (@Sendable (Process) -> Void)? = nil) throws -> Process {
        let process = Process()
        process.executableURL = url
        process.arguments = arguments
        process.terminationHandler = terminationHandler
        try process.run()
        return process
    }

    @available(*, deprecated, renamed: "run(_:arguments:terminationHandler:)")
    // convenience; create and launch
    open class func launchedProcess(launchPath path: String, arguments: [String]) -> Process {
        let process = Process()
        process.launchPath = path
        process.arguments = arguments
        process.launch()
    
        return process
    }

    // poll the runLoop in defaultMode until process completes
    open func waitUntilExit() {
        let runInterval = 0.05
        let currentRunLoop = RunLoop.current

        let runRunLoop : () -> Void = (currentRunLoop == self.runLoop)
                ? { _ = currentRunLoop.run(mode: .default, before: Date(timeIntervalSinceNow: runInterval)) }
                : { currentRunLoop.run(until: Date(timeIntervalSinceNow: runInterval)) }
        // update .runLoop to allow early wakeup triggered by terminateRunLoop.
        self.runLoop = currentRunLoop

        while self.isRunning {
            runRunLoop()
        } 

        self.runLoop = nil
        self.runLoopSource = nil
    }

    private func terminateRunLoop() {
        // Ensure that the run loop source is invalidated before we mark the process
        // as no longer running.  This serves as a semaphore to
        // `waitUntilExit` to decrement the `runLoopSource` retain count,
        // potentially releasing it.
        CFRunLoopSourceInvalidate(self.runLoopSource)
        let runloopToWakeup = self.runLoop
        self.isRunning = false

        // Wake up the run loop, *AFTER* clearing .isRunning to avoid an extra time out period.
        if let cfRunLoop = runloopToWakeup?._cfRunLoop {
            CFRunLoopWakeUp(cfRunLoop)
        }

        if let handler = self.terminationHandler {
            let thread: Thread = Thread { handler(self) }
            thread.start()
        }
    }
}

extension Process {
    
    public static let didTerminateNotification = NSNotification.Name(rawValue: "NSTaskDidTerminateNotification")
}

#endif
