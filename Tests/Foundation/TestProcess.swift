// This source file is part of the Swift.org open source project
//
// Copyright (c) 2015 - 2016, 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

import Synchronization
#if canImport(Android)
import Android
#endif

class TestProcess : XCTestCase {
    
    func test_exit0() throws {
        let process = Process()
        let executableURL = xdgTestHelperURL()
        if #available(macOS 10.13, *) {
            process.executableURL = executableURL
        } else {
            // Fallback on earlier versions
            process.launchPath = executableURL.path
        }
        XCTAssertEqual(executableURL.path, process.executableURL?.path)
        process.arguments = ["--exit", "0"]
        try process.run()
        process.waitUntilExit()
        
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(process.terminationReason, .exit)
    }
    
    func test_exit1() throws {
        let process = Process()
        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--exit", "1"]

        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 1)
        XCTAssertEqual(process.terminationReason, .exit)
    }
    
    func test_exit100() throws {
        let process = Process()
        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--exit", "100"]
        
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 100)
        XCTAssertEqual(process.terminationReason, .exit)
    }
    
    func test_sleep2() throws {
        let process = Process()
        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--sleep", "2"]
        
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(process.terminationReason, .exit)
    }

    func test_terminationReason_uncaughtSignal() throws {
        let process = Process()
        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--signal-self", SIGTERM.description]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, SIGTERM)
        XCTAssertEqual(process.terminationReason, .uncaughtSignal)
    }

    func test_pipe_stdin() throws {
        let process = Process()

        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--cat"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        let inputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let msg = try XCTUnwrap("Hello, 🐶.\n".data(using: .utf8))
        do {
            try inputPipe.fileHandleForWriting.write(contentsOf: msg)
        } catch {
            XCTFail("Cant write to pipe: \(error)")
            return
        }

        // Close the input pipe to send EOF to cat.
        inputPipe.fileHandleForWriting.closeFile()

        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let data = outputPipe.fileHandleForReading.availableData
        guard let string = String(data: data, encoding: .utf8) else {
            XCTFail("Could not read stdout")
            return
        }
        XCTAssertEqual(string, "Hello, 🐶.\n")
    }

    func test_pipe_stdout() throws {
        let process = Process()

        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--getcwd"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = nil

        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let data = pipe.fileHandleForReading.availableData
        guard let string = String(data: data, encoding: .ascii) else {
            XCTFail("Could not read stdout")
            return
        }

        XCTAssertEqual(string.trimmingCharacters(in: CharacterSet(["\n", "\r"])), FileManager.default.currentDirectoryPath)
    }

    func test_pipe_stderr() throws {
        let process = Process()

        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--cat", "invalid_file_name"]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 1)

        let data = errorPipe.fileHandleForReading.availableData
        guard let string = String(data: data, encoding: .ascii) else {
            XCTFail("Could not read stdout")
            return
        }
        // Ignore messages from malloc debug etc on macOs
        let errMsg = string.trimmingCharacters(in: CharacterSet(["\n"])).components(separatedBy: "\n").last
        XCTAssertEqual(errMsg, "cat: invalid_file_name: No such file or directory")
    }

    func test_pipe_stdout_and_stderr_same_pipe() throws {
        let process = Process()

        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--cat", "invalid_file_name"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // Clear the environment to stop the malloc debug flags used in Xcode debug being
        // set in the subprocess.
        process.environment = [:]
#if os(Android)
        // In Android, we have to provide at least an LD_LIBRARY_PATH, or
        // xdgTestHelper will not be able to find the Swift libraries.
        if let ldLibraryPath = ProcessInfo.processInfo.environment["LD_LIBRARY_PATH"] {
            process.environment?["LD_LIBRARY_PATH"] = ldLibraryPath
        }
#endif
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 1)

        let data = pipe.fileHandleForReading.availableData
        guard let string = String(data: data, encoding: .ascii) else {
            XCTFail("Could not read stdout")
            return
        }

        // Ignore messages from malloc debug etc on macOS
        let errMsg = string.trimmingCharacters(in: CharacterSet(["\n"])).components(separatedBy: "\n").last
        XCTAssertEqual(errMsg, "cat: invalid_file_name: No such file or directory")
    }

    func test_file_stdout() throws {
        let process = Process()

        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--getcwd"]

        let url: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: false)
        _ = FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { _ = try? FileManager.default.removeItem(at: url) }

        let handle: FileHandle = FileHandle(forUpdatingAtPath: url.path)!

        process.standardOutput = handle

        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        handle.seek(toFileOffset: 0)
        let data = handle.readDataToEndOfFile()
        guard let string = String(data: data, encoding: .ascii) else {
            XCTFail("Could not read stdout")
            return
        }
        XCTAssertEqual(string.trimmingCharacters(in: CharacterSet(["\r", "\n"])), FileManager.default.currentDirectoryPath)
    }
    
    func test_passthrough_environment() {
        do {
            let (output, _) = try runTask([xdgTestHelperURL().path, "--env"], environment: nil)
            let env = try parseEnv(output)
#if os(Windows)
            // On Windows, Path is always passed to the sub process
            XCTAssertGreaterThan(env.count, 1)
#else
            XCTAssertGreaterThan(env.count, 0)
#endif
        } catch {
            XCTFail("Test failed: \(error)")
        }
    }

    func test_no_environment() {
        do {
            let (output, _) = try runTask([xdgTestHelperURL().path, "--env"], environment: [:])
            let env = try parseEnv(output)
#if os(Windows)
            // On Windows, Path is always passed to the sub process
            XCTAssertEqual(env.count, 1)
#else
            XCTAssertEqual(env.count, 0)
#endif
        } catch {
            XCTFail("Test failed: \(error)")
        }
    }

    func test_custom_environment() {
        do {
            let input = ["HELLO": "WORLD", "HOME": "CUPERTINO"]
            let (output, _) = try runTask([xdgTestHelperURL().path, "--env"], environment: input)
            var env = try parseEnv(output)
#if os(Windows)
            // On Windows, Path is always passed to the sub process, remove it
            // before comparing.
            env.removeValue(forKey: "Path")
#endif
            XCTAssertEqual(env, input)
        } catch {
            XCTFail("Test failed: \(error)")
        }
    }

    func test_current_working_directory() throws {
        let tmpDir = { () -> String in
            // NSTemporaryDirectory might return a final slash, but
            // FileManager.currentDirectoryPath seems to avoid it.
            var dir = NSTemporaryDirectory()
            if (dir.hasSuffix("/") && dir != "/") || dir.hasSuffix("\\") {
               dir.removeLast()
            }
            return dir.standardizePath()
        }()

        let fm = FileManager.default
        let previousWorkingDirectory = fm.currentDirectoryPath
        XCTAssertNotEqual(previousWorkingDirectory.standardizePath(), tmpDir)

        // Test that getcwd() returns the currentDirectoryPath
        do {
            let (pwd, _) = try runTask([xdgTestHelperURL().path, "--getcwd"], currentDirectoryPath: tmpDir)
            // Check the sub-process used the correct directory
            XCTAssertEqual(pwd.trimmingCharacters(in: .newlines).standardizePath(), tmpDir)
        } catch {
            XCTFail("Test failed: \(error)")
        }

        // Test that $PWD by default is set to currentDirectoryPath
        do {
            let (pwd, _) = try runTask([xdgTestHelperURL().path, "--echo-PWD"], currentDirectoryPath: tmpDir)
            // Check the sub-process used the correct directory
            let cwd = FileManager.default.currentDirectoryPath.standardizePath()
            XCTAssertNotEqual(cwd, tmpDir)
            XCTAssertNotEqual(pwd.trimmingCharacters(in: .newlines).standardizePath(), tmpDir)
        } catch {
            XCTFail("Test failed: \(error)")
        }

        // Test that $PWD can be over-ridden
        do {
            var env = ProcessInfo.processInfo.environment
            env["PWD"] = "/bin"
            let (pwd, _) = try runTask([xdgTestHelperURL().path, "--echo-PWD"], environment: env, currentDirectoryPath: tmpDir)
            // Check the sub-process used the correct directory
            XCTAssertEqual(pwd.trimmingCharacters(in: .newlines), "/bin")
        } catch {
            XCTFail("Test failed: \(error)")
        }

        // Test that $PWD can be set to empty
        do {
            var env = ProcessInfo.processInfo.environment
            env["PWD"] = ""
            let (pwd, _) = try runTask([xdgTestHelperURL().path, "--echo-PWD"], environment: env, currentDirectoryPath: tmpDir)
            // Check the sub-process used the correct directory
            XCTAssertEqual(pwd.trimmingCharacters(in: .newlines), "")
        } catch {
            XCTFail("Test failed: \(error)")
        }

        XCTAssertEqual(previousWorkingDirectory, fm.currentDirectoryPath)
    }

    func test_run() {
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath

        do {
            let process = try Process.run(xdgTestHelperURL(), arguments: ["--exit", "123"], terminationHandler: nil)
            process.waitUntilExit()
            XCTAssertEqual(process.terminationReason, .exit)
            XCTAssertEqual(process.terminationStatus, 123)
        } catch {
            XCTFail("Cant execute \(xdgTestHelperURL().path): \(error)")
        }
        XCTAssertEqual(fm.currentDirectoryPath, cwd)

        do {
            // Check running the process twice throws an error.
            let process = Process()
            process.executableURL = xdgTestHelperURL()
            process.arguments = ["--exit", "0"]
            XCTAssertNoThrow(try process.run())
            process.waitUntilExit()
            XCTAssertThrowsError(try process.run()) {
                let nserror = ($0 as NSError)
                XCTAssertEqual(nserror.domain, NSCocoaErrorDomain)
                let code = CocoaError(_nsError: nserror).code
                XCTAssertEqual(code, .executableLoad)
            }
        }

        do {
            let process = Process()
            process.executableURL = xdgTestHelperURL()
            process.arguments = ["--exit", "0"]
            process.currentDirectoryURL = URL(fileURLWithPath: "/.../_no_such_directory", isDirectory: true)
            XCTAssertThrowsError(try process.run())
        }
        XCTAssertEqual(fm.currentDirectoryPath, cwd)

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/..", isDirectory: false)
            process.arguments = []
            process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            XCTAssertThrowsError(try process.run())
        }
        XCTAssertEqual(fm.currentDirectoryPath, cwd)
        _ = fm.changeCurrentDirectoryPath(cwd)
    }

    func test_preStartEndState() {
        let process = Process()
        XCTAssertNil(process.executableURL)
        XCTAssertNotNil(process.currentDirectoryURL)
        XCTAssertNil(process.arguments)
        XCTAssertNil(process.environment)
        XCTAssertFalse(process.isRunning)
        XCTAssertEqual(process.processIdentifier, 0)
        XCTAssertEqual(process.qualityOfService, .default)

        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--cat"]
        _ = try? process.run()
        XCTAssertTrue(process.isRunning)
        XCTAssertTrue(process.processIdentifier > 0)
        process.terminate()
        process.waitUntilExit()
        XCTAssertFalse(process.isRunning)
        XCTAssertTrue(process.processIdentifier > 0)
        XCTAssertEqual(process.terminationReason, .uncaughtSignal)
        XCTAssertEqual(process.terminationStatus, SIGTERM)
    }

    func test_interrupt() throws {
        #if os(Windows)
        throw XCTSkip("Windows does not have signals")
        #else
        let helper = _SignalHelperRunner()
        do {
            try helper.start()
        }  catch {
            XCTFail("Cant run xdgTestHelper: \(error)")
            return
        }
        if !helper.waitForReady() {
            XCTFail("Didnt receive Ready from sub-process")
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let timeout = DispatchTime(uptimeNanoseconds: now + 2_000_000_000)

        var count = 3
        while count > 0 {
            helper.process.interrupt()
            guard helper.semaphore.wait(timeout: timeout) == .success else {
                helper.process.terminate()
                XCTFail("Timedout waiting for signal")
                return
            }

            if helper.sigIntCount == 3 {
                break
            }
            count -= 1
        }
        helper.process.terminate()
        XCTAssertEqual(helper.sigIntCount, 3)
        helper.process.waitUntilExit()
        let terminationReason = helper.process.terminationReason
        XCTAssertEqual(terminationReason, Process.TerminationReason.exit)
        let status = helper.process.terminationStatus
        XCTAssertEqual(status, 99)
        #endif
    }

    func test_terminate() {
        guard let process = try? Process.run(xdgTestHelperURL(), arguments: ["--cat"]) else {
            XCTFail("Cant run 'cat'")
            return
        }

        process.terminate()
        process.waitUntilExit()
        let terminationReason = process.terminationReason
        XCTAssertEqual(terminationReason, Process.TerminationReason.uncaughtSignal)
        XCTAssertEqual(process.terminationStatus, SIGTERM)
    }


    func test_suspend_resume() throws {
        #if os(Windows)
        throw XCTSkip("Windows does not have signals")
        #else
        nonisolated(unsafe) let helper = _SignalHelperRunner()
        do {
            try helper.start()
        }  catch {
            XCTFail("Cant run xdgTestHelper: \(error)")
            return
        }
        if !helper.waitForReady() {
            XCTFail("Didnt receive Ready from sub-process")
            return
        }
        let now = DispatchTime.now().uptimeNanoseconds
        let timeout = DispatchTime(uptimeNanoseconds: now + 2_000_000_000)

        func waitForSemaphore() -> Bool {
            guard helper.semaphore.wait(timeout: timeout) == .success else {
                helper.process.terminate()
                XCTFail("Timedout waiting for signal")
                return false
            }
            return true
        }

        XCTAssertTrue(helper.process.isRunning)
        XCTAssertTrue(helper.process.suspend())
        XCTAssertTrue(helper.process.isRunning)
        XCTAssertTrue(helper.process.resume())
        if waitForSemaphore() == false { return }
        XCTAssertEqual(helper.sigContCount, 1)

        XCTAssertTrue(helper.process.resume())
        XCTAssertTrue(helper.process.suspend())
        XCTAssertTrue(helper.process.resume())
        XCTAssertEqual(helper.sigContCount, 1)

        XCTAssertTrue(helper.process.suspend())
        XCTAssertTrue(helper.process.suspend())
        XCTAssertTrue(helper.process.resume())
        if waitForSemaphore() == false { return }

        _ = helper.process.suspend()
        _ = helper.process.resume()
        if waitForSemaphore() == false { return }
        XCTAssertEqual(helper.sigContCount, 3)

        helper.process.terminate()
        helper.process.waitUntilExit()
        XCTAssertFalse(helper.process.isRunning)
        XCTAssertFalse(helper.process.suspend())
        XCTAssertTrue(helper.process.resume())
        XCTAssertTrue(helper.process.resume())
        #endif
    }


    func test_redirect_stdin_using_null() {
        let task = Process()
        task.executableURL = xdgTestHelperURL()
        task.arguments = ["--cat"]
        task.standardInput = FileHandle.nullDevice
        XCTAssertNoThrow(try task.run())
        task.waitUntilExit()
    }


    func test_redirect_stdout_using_null() {
        let task = Process()
        task.executableURL = xdgTestHelperURL()
        task.arguments = ["--env"]
        task.standardOutput = FileHandle.nullDevice
        XCTAssertNoThrow(try task.run())
        task.waitUntilExit()
    }

    func test_redirect_stdin_stdout_using_null() {
        let task = Process()
        task.executableURL = xdgTestHelperURL()
        task.arguments = ["--cat"]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        XCTAssertNoThrow(try task.run())
        task.waitUntilExit()
    }


    func test_redirect_stderr_using_null() throws {
        let task = Process()
        task.executableURL = xdgTestHelperURL()
        task.arguments = ["--env"]
        task.standardError = FileHandle.nullDevice
        XCTAssertNoThrow(try task.run())
        task.waitUntilExit()
    }


    func test_redirect_all_using_null() throws {
        let task = Process()
        task.executableURL = xdgTestHelperURL()
        task.arguments = ["--cat"]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        XCTAssertNoThrow(try task.run())
        task.waitUntilExit()
    }

    func test_redirect_all_using_nil() throws {
        let task = Process()
        task.executableURL = xdgTestHelperURL()
        task.arguments = ["--cat"]
        task.standardInput = nil
        task.standardOutput = nil
        task.standardError = nil
        XCTAssertNoThrow(try task.run())
        task.waitUntilExit()
    }


    func test_plutil() throws {
        let task = Process()

        guard let url = testBundle(executable: true).url(forAuxiliaryExecutable: "plutil") else {
            throw Error.ExternalBinaryNotFound("plutil")
        }

        task.executableURL = url
        task.arguments = []
        let stdoutPipe = Pipe()
        let stdoutData = Mutex(Data())
        task.standardOutput = stdoutPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { fh in
            stdoutData.withLock {
                $0.append(fh.availableData)
            }
        }
        try task.run()
        task.waitUntilExit()
        stdoutPipe.fileHandleForReading.readabilityHandler = nil

        try stdoutData.withLock {
            if let d = try stdoutPipe.fileHandleForReading.readToEnd() {
                $0.append(d)
            }
            XCTAssertEqual(String(data: $0, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), "No files specified.")
        }
    }

    @available(*, deprecated) // test of deprecated API, suppress deprecation warning
    func test_currentDirectory() throws {

        let process = Process()
        XCTAssertNil(process.executableURL)
        XCTAssertNotNil(process.currentDirectoryURL)

        // Test currentDirectoryURL cannot be set to nil even though it is a URL?
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        process.currentDirectoryURL = nil
        XCTAssertNotNil(process.currentDirectoryURL)
        XCTAssertEqual(process.currentDirectoryURL, cwd)

        let aFileURL = URL(fileURLWithPath: "/a_file", isDirectory: false)
        XCTAssertFalse(aFileURL.hasDirectoryPath)
        XCTAssertEqual(aFileURL.path, "/a_file")
        process.currentDirectoryURL = aFileURL
        XCTAssertNotEqual(process.currentDirectoryURL, aFileURL)
        XCTAssertEqual(process.currentDirectoryPath, "/a_file")
        XCTAssertTrue(try XCTUnwrap(process.currentDirectoryURL).hasDirectoryPath)
        XCTAssertEqual(try XCTUnwrap(process.currentDirectoryURL).absoluteString, "file:///a_file/")

        let aDirURL = URL(fileURLWithPath: "/a_dir", isDirectory: true)
        XCTAssertTrue(aDirURL.hasDirectoryPath)
        XCTAssertEqual(aDirURL.path, "/a_dir")
        process.currentDirectoryURL = aDirURL
        XCTAssertEqual(process.currentDirectoryURL, aDirURL)
        XCTAssertEqual(process.currentDirectoryPath, "/a_dir")
        XCTAssertTrue(try XCTUnwrap(process.currentDirectoryURL).hasDirectoryPath)
        XCTAssertEqual(try XCTUnwrap(process.currentDirectoryURL).absoluteString, "file:///a_dir/")

        process.currentDirectoryPath = ""
        XCTAssertEqual(process.currentDirectoryPath, "")
        XCTAssertNil(process.currentDirectoryURL)
        process.currentDirectoryURL = nil
        XCTAssertEqual(process.currentDirectoryPath, cwd.path)


        process.executableURL = URL(fileURLWithPath: "/some_file_that_doesnt_exist", isDirectory: false)
        XCTAssertThrowsError(try process.run()) {
            let code = CocoaError.Code(rawValue: ($0 as NSError).code)
            XCTAssertEqual(code, .fileReadNoSuchFile)
        }

        do {
            let (stdout, _) = try runTask([xdgTestHelperURL().path, "--getcwd"], currentDirectoryPath: "/")
            var directory = stdout.trimmingCharacters(in: CharacterSet(["\n", "\r"]))
#if os(Windows)
            let zero: String.Index = directory.startIndex
            let one: String.Index = directory.index(zero, offsetBy: 1)
            XCTAssertTrue(directory[zero].isLetter)
            XCTAssertEqual(directory[one], ":")
            directory = "/" + String(directory.dropFirst(2))
#endif
            XCTAssertEqual(URL(fileURLWithPath: directory).absoluteURL,
                           URL(fileURLWithPath: "/").absoluteURL)
        }

        do {
            // NOTE: Windows does have an environment variable called `PWD`.
            // The closed thing is %CD% which is a property of the shell rather
            // than the environment.  Simply ignore this test on Windows.
#if !os(Windows)
            XCTAssertNotEqual("/", FileManager.default.currentDirectoryPath)
            XCTAssertNotEqual(FileManager.default.currentDirectoryPath, "/")
            let (stdout, _) = try runTask([xdgTestHelperURL().path, "--echo-PWD"], currentDirectoryPath: "/")
            let directory = stdout.trimmingCharacters(in: CharacterSet(["\n", "\r"]))
            XCTAssertEqual(directory, ProcessInfo.processInfo.environment["PWD"])
            XCTAssertNotEqual(directory, "/")
#endif
        }

        do {
            let process = Process()
            process.executableURL = xdgTestHelperURL()
            process.arguments = [ "--getcwd" ]
            process.currentDirectoryPath = ""

            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw Error.TerminationStatus(process.terminationStatus)
            }

            var stdoutData = Data()
            if let d = try stdoutPipe.fileHandleForReading.readToEnd() {
                stdoutData.append(d)
            }

            guard let stdout = String(data: stdoutData, encoding: .utf8) else {
                throw Error.UnicodeDecodingError(stdoutData)
            }
            let directory = stdout.trimmingCharacters(in: CharacterSet(["\n", "\r"]))
            XCTAssertEqual(directory, FileManager.default.currentDirectoryPath)
        } catch {
            XCTFail(String(describing: error))
        }

        XCTAssertThrowsError(try runTask([xdgTestHelperURL().path, "--getcwd"], currentDirectoryPath: "/some_directory_that_doesnt_exsit")) { error in
            let code = CocoaError.Code(rawValue: (error as NSError).code)
            XCTAssertEqual(code, .fileReadNoSuchFile)
        }
    }

    #if !os(Windows)
    func test_fileDescriptorsAreNotInherited() throws {
        let task = Process()
        let someExtraFDs = [dup(1), dup(1), dup(1), dup(1), dup(1), dup(1), dup(1)]
        task.executableURL = xdgTestHelperURL()
        task.arguments = ["--print-open-file-descriptors"]
        task.standardInput = FileHandle.nullDevice
        let stdoutPipe = Pipe()
        task.standardOutput = stdoutPipe.fileHandleForWriting
        task.standardError = FileHandle.nullDevice
        XCTAssertNoThrow(try task.run())

        try stdoutPipe.fileHandleForWriting.close()
        let stdoutData = try stdoutPipe.fileHandleForReading.readToEnd()
        task.waitUntilExit()
        let stdoutString = String(decoding: stdoutData ?? Data(), as: Unicode.UTF8.self)
        #if os(macOS)
        XCTAssertEqual("0\n1\n2\n", stdoutString)
        #else
        // on Linux we may also have a /dev/urandom open as well as some socket that Process uses for something.

        // we should definitely have stdin (0), stdout (1), and stderr (2) open
        XCTAssert(stdoutString.utf8.starts(with: "0\n1\n2\n".utf8))

        // in total we should have 6 or fewer lines:
        // 1. stdin
        // 2. stdout
        // 3. stderr
        // 4. /dev/urandom (optional)
        // 5. communication socket (optional)
        // 6. trailing new line
        XCTAssertLessThanOrEqual(stdoutString.components(separatedBy: "\n").count, 6, "\(stdoutString)")
        #endif
        for fd in someExtraFDs {
            close(fd)
        }
    }
    #endif

    func test_pipeCloseBeforeLaunch() {
        let process = Process()
        let stdInput = Pipe()
        let stdOutput = Pipe()

        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--cat"]
        process.standardInput = stdInput
        process.standardOutput = stdOutput

        let string = "Hello, World"
        let stdInputPipe = stdInput.fileHandleForWriting
        XCTAssertNoThrow(try stdInputPipe.write(XCTUnwrap(string.data(using: .utf8))))
        stdInputPipe.closeFile()

        XCTAssertNoThrow(try process.run())
        process.waitUntilExit()

        let stdOutputPipe = stdOutput.fileHandleForReading
        do {
            let readData = try XCTUnwrap(stdOutputPipe.readToEnd())
            let readString = String(data: readData, encoding: .utf8)
            XCTAssertEqual(string, readString)
        } catch {
            XCTFail("\(error)")
        }
    }

    func test_multiProcesses() {
        let source = Process()
        source.executableURL = xdgTestHelperURL()
        source.arguments = [ "--getcwd" ]

        let cat1 = Process()
        cat1.executableURL = xdgTestHelperURL()
        cat1.arguments = [ "--cat" ]

        let cat2 = Process()
        cat2.executableURL = xdgTestHelperURL()
        cat2.arguments = [ "--cat" ]

        let pipe1 = Pipe()
        source.standardOutput = pipe1
        cat1.standardInput = pipe1

        let pipe2 = Pipe()
        cat1.standardOutput = pipe2
        cat2.standardInput = pipe2

        let pipe3 = Pipe()
        cat2.standardOutput = pipe3

        XCTAssertNoThrow(try source.run())
        XCTAssertNoThrow(try cat1.run())
        XCTAssertNoThrow(try cat2.run())
        cat2.waitUntilExit()
        cat1.waitUntilExit()
        source.waitUntilExit()

        do {
            let data = try XCTUnwrap(pipe3.fileHandleForReading.readToEnd())
            let pwd = String.init(decoding: data, as: UTF8.self).trimmingCharacters(in: CharacterSet(["\n", "\r"]))
            XCTAssertEqual(pwd, FileManager.default.currentDirectoryPath)
        } catch {
            XCTFail("\(error)")
        }
    }

#if !os(Windows)
    func test_processGroup() throws {
        // The process group of the child process should be different to the parent's.
        let process = Process()

        process.executableURL = xdgTestHelperURL()
        process.arguments = ["--pgrp"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = nil

        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let data = pipe.fileHandleForReading.availableData
        guard let string = String(data: data, encoding: .ascii) else {
            XCTFail("Could not read stdout")
            return
        }

        let parts = string.trimmingCharacters(in: .newlines).components(separatedBy: ": ")
        guard parts.count == 2, parts[0] == "pgrp", let childPgrp = Int(parts[1]) else {
            XCTFail("Could not pgrp fron stdout")
            return
        }
        let parentPgrp = Int(getpgrp())
        XCTAssertNotEqual(parentPgrp, childPgrp, "Child process group \(parentPgrp) should not equal parent process group \(childPgrp)")
    }
#endif
}

private enum Error: Swift.Error {
    case TerminationStatus(Int32)
    case UnicodeDecodingError(Data)
    case InvalidEnvironmentVariable(String)
    case ExternalBinaryNotFound(String)
}

// Run xdgTestHelper, wait for 'Ready' from the sub-process, then signal a semaphore.
// Read lines from a pipe and store in a queue.
class _SignalHelperRunner {
    let process = Process()
    let semaphore = DispatchSemaphore(value: 0)

    private let outputPipe = Pipe()
    private let sQueue = DispatchQueue(label: "signal queue")

    private var gotReady = false
    private var bytesIn = Data()
    private var _sigIntCount = 0
    private var _sigContCount = 0
    var sigIntCount: Int { return sQueue.sync { return _sigIntCount } }
    var sigContCount: Int { return sQueue.sync { return _sigContCount } }


    init() {
        process.executableURL = xdgTestHelperURL()
        process.environment = ProcessInfo.processInfo.environment
        process.arguments = ["--signal-test"]
        process.standardOutput = outputPipe.fileHandleForWriting

        nonisolated(unsafe) let nonisolatedSelf = self
        outputPipe.fileHandleForReading.readabilityHandler = { fh in
            let newLine = UInt8(ascii: "\n")
            
            nonisolatedSelf.bytesIn.append(fh.availableData)
            if nonisolatedSelf.bytesIn.isEmpty {
                return
            }
            // Split the incoming data into lines.
            while let index = nonisolatedSelf.bytesIn.firstIndex(of: newLine) {
                if index >= nonisolatedSelf.bytesIn.startIndex {
                    // don't include the newline when converting to string
                    let line = String(data: nonisolatedSelf.bytesIn[nonisolatedSelf.bytesIn.startIndex..<index], encoding: String.Encoding.utf8) ?? ""
                    nonisolatedSelf.bytesIn.removeSubrange(nonisolatedSelf.bytesIn.startIndex...index)
                    
                    if nonisolatedSelf.gotReady == false && line == "Ready" {
                        nonisolatedSelf.semaphore.signal()
                        nonisolatedSelf.gotReady = true;
                    }
                    else if nonisolatedSelf.gotReady == true {
                        if line == "Signal: SIGINT" {
                            nonisolatedSelf.sQueue.sync { nonisolatedSelf._sigIntCount += 1 }
                            nonisolatedSelf.semaphore.signal()
                        }
                        else if line == "Signal: SIGCONT" {
                            nonisolatedSelf.sQueue.sync { nonisolatedSelf._sigContCount += 1 }
                            nonisolatedSelf.semaphore.signal()
                        }
                    }
                }
            }
        }
    }

    deinit {
        process.terminate()
        process.waitUntilExit()
    }

    func start() throws {
        try process.run()
    }

    func waitForReady() -> Bool {
        let now = DispatchTime.now().uptimeNanoseconds
        let timeout = DispatchTime(uptimeNanoseconds: now + 2_000_000_000)
        guard semaphore.wait(timeout: timeout) == .success else {
            process.terminate()
            return false
        }
        return true
    }
}

@discardableResult
internal func runTask(_ arguments: [String], environment: [String: String]? = nil, currentDirectoryPath: String? = nil) throws -> (String, String) {
    let process = Process()

    var arguments = arguments
    let firstArg = arguments.removeFirst()
    process.executableURL = URL(fileURLWithPath: firstArg)
    process.arguments = arguments
    // Darwin Foundation doesnt allow .environment to be set to nil although the documentation
    // says it is an optional. https://developer.apple.com/documentation/foundation/process/1409412-environment
    if var e = environment {
#if os(Android)
        // In Android, we have to provide at least an LD_LIBRARY_PATH, or
        // xdgTestHelper will not be able to find the Swift libraries.
        if e["LD_LIBRARY_PATH"] == nil {
            if let ldLibraryPath = ProcessInfo.processInfo.environment["LD_LIBRARY_PATH"] {
                e["LD_LIBRARY_PATH"] = ldLibraryPath
            }
        }
#endif
        process.environment = e
    }

    if let dirPath = currentDirectoryPath {
        process.currentDirectoryURL = URL(fileURLWithPath: dirPath, isDirectory: true)
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    struct Output {
        var stdoutData = Data()
        var stderrData = Data()
    }
    let dataLock = Mutex(Output())
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    stdoutPipe.fileHandleForReading.readabilityHandler = { fh in
        dataLock.withLock {
            $0.stdoutData.append(fh.availableData)
        }
    }

    stderrPipe.fileHandleForReading.readabilityHandler = { fh in
        dataLock.withLock {
            $0.stderrData.append(fh.availableData)
        }
    }

    try process.run()
    process.waitUntilExit()
    stdoutPipe.fileHandleForReading.readabilityHandler = nil
    stderrPipe.fileHandleForReading.readabilityHandler = nil

    guard process.terminationStatus == 0 else {
        throw Error.TerminationStatus(process.terminationStatus)
    }

    return try dataLock.withLock {
        // Drain any data remaining in the pipes
        if let d = try stdoutPipe.fileHandleForReading.readToEnd() {
            $0.stdoutData.append(d)
        }

        if let d = try stderrPipe.fileHandleForReading.readToEnd() {
            $0.stderrData.append(d)
        }

        guard let stdout = String(data: $0.stdoutData, encoding: .utf8) else {
            throw Error.UnicodeDecodingError($0.stdoutData)
        }

        guard let stderr = String(data: $0.stderrData, encoding: .utf8) else {
            throw Error.UnicodeDecodingError($0.stderrData)
        }

        return (stdout, stderr)
    }
}

private func parseEnv(_ env: String) throws -> [String: String] {
    var result = [String: String]()
    for line in env.components(separatedBy: .newlines) where line != "" {
        guard let range = line.range(of: "=") else {
            throw Error.InvalidEnvironmentVariable(line)
        }
        let key = String(line[..<range.lowerBound])
#if os(Android)
        // NOTE: this works because the results of parseEnv are never checked
        // against the parent environment, where this key will be set. If that
        // ever happen, the checks should be changed.
        if key == "LD_LIBRARY_PATH" {
            continue
        }
#endif
        result[key] = String(line[range.upperBound...])
    }
    return result
}
