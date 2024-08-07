// This source file is part of the Swift.org open source project
//
// Copyright (c) 2017 - 2018 Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if !DEPLOYMENT_RUNTIME_OBJC && canImport(SwiftFoundation) && canImport(SwiftFoundationNetworking) && canImport(SwiftFoundationXML)
import SwiftFoundation
import SwiftFoundationNetworking
import SwiftFoundationXML
#else
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#endif
#if os(Windows)
import WinSDK
#elseif os(Android)
import Android
#endif

enum HelperCheckStatus : Int32 {
    case ok                 = 0
    case fail               = 1
    case cookieStorageNil   = 20
    case cookieStorePathWrong
}


class XDGCheck {
    static func run() -> Never {
        let storage = HTTPCookieStorage.shared
        let properties: [HTTPCookiePropertyKey: String] = [
            .name: "TestCookie",
            .value: "Test @#$%^$&*99",
            .path: "/",
            .domain: "example.com",
            ]

        guard let simpleCookie = HTTPCookie(properties: properties) else {
            exit(HelperCheckStatus.cookieStorageNil.rawValue)
        }
        guard let rawValue = getenv("XDG_DATA_HOME"), let xdg_data_home = String(utf8String: rawValue) else {
            exit(HelperCheckStatus.fail.rawValue)
        }

        storage.setCookie(simpleCookie)
        let fm = FileManager.default

        let bundleName = Bundle.main.bundlePath.split(separator: "/").last!.prefix(while: { $0 != "." })
        let destPath = xdg_data_home + "/" + bundleName + "/.cookies.shared"
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: destPath, isDirectory: &isDir)
        if (!exists) {
            print("Expected cookie path: ", destPath)
            exit(HelperCheckStatus.cookieStorePathWrong.rawValue)
        }
        exit(HelperCheckStatus.ok.rawValue)
    }
}

#if !os(Windows)
// -----

// Used by TestProcess: test_interrupt(), test_suspend_resume()
func signalTest() {

    var signalSet = sigset_t()
    sigemptyset(&signalSet)
    sigaddset(&signalSet, SIGTERM)
    sigaddset(&signalSet, SIGCONT)
    sigaddset(&signalSet, SIGINT)
    sigaddset(&signalSet, SIGALRM)
    guard sigprocmask(SIG_BLOCK, &signalSet, nil) == 0 else {
        fatalError("Cant block signals")
    }
    // Timeout
    alarm(3)

    // On Linux, print() doesnt currently flush the output over the pipe so use
    // write() for now. On macOS, print() works fine.
    write(1, "Ready\n", 6)

    while true {
        var receivedSignal: Int32 = 0
        let ret = sigwait(&signalSet, &receivedSignal)
        guard ret == 0 else {
            fatalError("sigwait() failed")
        }
        switch receivedSignal {
        case SIGINT:
            write(1, "Signal: SIGINT\n", 15)

        case SIGCONT:
            write(1, "Signal: SIGCONT\n", 16)

        case SIGTERM:
            print("Terminated")
            exit(99)

        case SIGALRM:
            print("Timedout")
            exit(127)

        default:
            let msg = "Unexpected signal: \(receivedSignal)"
            fatalError(msg)
        }
    }
}
#endif

// -----

#if !DEPLOYMENT_RUNTIME_OBJC
struct NSURLForPrintTest {
    enum Method: String {
        case NSSearchPath
        case FileManagerDotURLFor
        case FileManagerDotURLsFor
    }
    
    enum Identifier: String {
        case desktop
        case download
        case publicShare
        case documents
        case music
        case pictures
        case videos
    }
    
    let method: Method
    let identifier: Identifier
    
    func run() {
        let directory: FileManager.SearchPathDirectory
        
        switch identifier {
        case .desktop:
            directory = .desktopDirectory
        case .download:
            directory = .downloadsDirectory
        case .publicShare:
            directory = .sharedPublicDirectory
        case .documents:
            directory = .documentDirectory
        case .music:
            directory = .musicDirectory
        case .pictures:
            directory = .picturesDirectory
        case .videos:
            directory = .moviesDirectory
        }
        
        switch method {
        case .NSSearchPath:
            print(NSSearchPathForDirectoriesInDomains(directory, .userDomainMask, true).first!)
        case .FileManagerDotURLFor:
            print(try! FileManager.default.url(for: directory, in: .userDomainMask, appropriateFor: nil, create: false).path)
        case .FileManagerDotURLsFor:
            print(FileManager.default.urls(for: directory, in: .userDomainMask).first!.path)
        }
    }
}
#endif

// Simple implementation of /bin/cat
func cat(_ args: ArraySlice<String>.Iterator) {
    var exitCode: Int32 = 0

    func catFile(_ name: String) {
        do {
            guard let fh = name == "-" ? FileHandle.standardInput : FileHandle(forReadingAtPath: name) else {
                FileHandle.standardError.write(Data("cat: \(name): No such file or directory\n".utf8))
                exitCode = 1
                return
            }
            while let data = try fh.readToEnd() {
                try FileHandle.standardOutput.write(contentsOf: data)
            }
        }
        catch { print(error) }
    }

    var args = args
    let arg = args.next() ?? "-"
    catFile(arg)
    while let arg = args.next() {
        catFile(arg)
    }
    exit(exitCode)
}

#if !os(Windows)
func printOpenFileDescriptors() {
    let reasonableMaxFD: CInt
    #if os(Linux) || os(macOS)
    reasonableMaxFD = getdtablesize()
    #else
    reasonableMaxFD = 4096
    #endif
    for fd in 0..<reasonableMaxFD {
        if fcntl(fd, F_GETFD) != -1 {
            print(fd)
        }
    }
    exit(0)
}
#endif

// -----

var arguments = ProcessInfo.processInfo.arguments.dropFirst().makeIterator()

guard let arg = arguments.next() else {
    fatalError("The unit test must specify the correct number of flags and arguments.")
}

switch arg {
case "--xdgcheck":
    XDGCheck.run()
    
case "--getcwd":
    print(FileManager.default.currentDirectoryPath)

case "--echo-PWD":
    print(ProcessInfo.processInfo.environment["PWD"] ?? "")

case "--env":
    print(ProcessInfo.processInfo.environment.filter { $0.key != "__CF_USER_TEXT_ENCODING" }.map { "\($0.key)=\($0.value.filter { !$0.isNewline })" }.joined(separator: "\n"))

case "--cat":
    cat(arguments)

case "--exit":
    let code = Int32(arguments.next() ?? "0") ?? 0
    exit(code)

case "--sleep":
    let time = Double(arguments.next() ?? "0") ?? 0
    Thread.sleep(forTimeInterval: time)

case "--signal-self":
    if let signalnum = arguments.next(), let signal = Int32(signalnum) {
#if os(Windows)
        TerminateProcess(GetCurrentProcess(), UINT(0xC0000000 | UINT(signal)))
#else
        kill(ProcessInfo.processInfo.processIdentifier, signal)
#endif
    }
    exit(1)

#if !DEPLOYMENT_RUNTIME_OBJC
case "--nspathfor":
    guard let methodString = arguments.next(),
        let method = NSURLForPrintTest.Method(rawValue: methodString),
        let identifierString = arguments.next(),
        let identifier = NSURLForPrintTest.Identifier(rawValue: identifierString) else {
        fatalError("Usage: --nspathfor <METHOD> <DIRECTORY NAME>")
    }
    
    let test = NSURLForPrintTest(method: method, identifier: identifier)
    test.run()
#endif

#if !os(Windows)
case "--signal-test":
    signalTest()

case "--print-open-file-descriptors":
    printOpenFileDescriptors()

case "--pgrp":
    print("pgrp: \(getpgrp())")

#endif

default:
    fatalError("These arguments are not recognized. Only run this from a unit test.")
}
