// This source file is part of the Swift.org open source project
//
// Copyright (c) 2015 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if DEPLOYMENT_RUNTIME_OBJC || os(Linux)
    import Foundation
    import XCTest
#else
    import SwiftFoundation
    import SwiftXCTest
#endif
import CoreFoundation

class TestNSTask : XCTestCase {
    static var allTests: [(String, TestNSTask -> () throws -> Void)] {
        return [
                   ("test_exit0" , test_exit0),
                   ("test_exit1" , test_exit1),
                   ("test_exit100" , test_exit100),
                   ("test_sleep2", test_sleep2),
                   ("test_sleep2_exit1", test_sleep2_exit1),
                   ("test_pipe_stdin", test_pipe_stdin),
                   ("test_pipe_stdout", test_pipe_stdout),
                   ("test_pipe_stderr", test_pipe_stderr),
                   ("test_file_stdout", test_file_stdout),
        ]
    }
    
    func test_exit0() {
        
        let task = NSTask()
        
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "exit 0"]
        
        task.launch()
        task.waitUntilExit()
        XCTAssertEqual(task.terminationStatus, 0)
    }
    
    func test_exit1() {
        
        let task = NSTask()
        
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "exit 1"]

        task.launch()
        task.waitUntilExit()
        XCTAssertEqual(task.terminationStatus, 1)
    }
    
    func test_exit100() {
        
        let task = NSTask()
        
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "exit 100"]
        
        task.launch()
        task.waitUntilExit()
        XCTAssertEqual(task.terminationStatus, 100)
    }
    
    func test_sleep2() {
        
        let task = NSTask()
        
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "sleep 2"]
        
        task.launch()
        task.waitUntilExit()
        XCTAssertEqual(task.terminationStatus, 0)
    }
    
    func test_sleep2_exit1() {
        
        let task = NSTask()
        
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "sleep 2; exit 1"]
        
        task.launch()
        task.waitUntilExit()
        XCTAssertEqual(task.terminationStatus, 1)
    }


    func test_pipe_stdin() {
        let task = NSTask()

        task.launchPath = "/bin/cat"

        let outputPipe = NSPipe()
        task.standardOutput = outputPipe

        let inputPipe = NSPipe()
        task.standardInput = inputPipe

        task.launch()

        inputPipe.fileHandleForWriting.writeData("Hello, 🐶.\n".data(using: NSUTF8StringEncoding)!)

        // Close the input pipe to send EOF to cat.
        inputPipe.fileHandleForWriting.closeFile()

        task.waitUntilExit()
        XCTAssertEqual(task.terminationStatus, 0)

        let data = outputPipe.fileHandleForReading.availableData
        guard let string = String(data: data, encoding: NSUTF8StringEncoding) else {
            XCTFail("Could not read stdout")
            return
        }
        XCTAssertEqual(string, "Hello, 🐶.\n")
    }

    func test_pipe_stdout() {
        let task = NSTask()

        task.launchPath = "/usr/bin/which"
        task.arguments = ["which"]

        let pipe = NSPipe()
        task.standardOutput = pipe

        task.launch()
        task.waitUntilExit()
        XCTAssertEqual(task.terminationStatus, 0)

        let data = pipe.fileHandleForReading.availableData
        guard let string = String(data: data, encoding: NSASCIIStringEncoding) else {
            XCTFail("Could not read stdout")
            return
        }
        XCTAssertEqual(string, "/usr/bin/which\n")
    }

    func test_pipe_stderr() {
        let task = NSTask()

        task.launchPath = "/bin/cat"
        task.arguments = ["invalid_file_name"]

        let errorPipe = NSPipe()
        task.standardError = errorPipe

        task.launch()
        task.waitUntilExit()
        XCTAssertEqual(task.terminationStatus, 1)

        let data = errorPipe.fileHandleForReading.availableData
        guard let string = String(data: data, encoding: NSASCIIStringEncoding) else {
            XCTFail("Could not read stdout")
            return
        }
        XCTAssertEqual(string, "cat: invalid_file_name: No such file or directory\n")
    }

    func test_file_stdout() {
        let task = NSTask()

        task.launchPath = "/usr/bin/which"
        task.arguments = ["which"]

        mkstemp(template: "TestNSTask.XXXXXX") { handle in
            task.standardOutput = handle

            task.launch()
            task.waitUntilExit()
            XCTAssertEqual(task.terminationStatus, 0)

            handle.seekToFileOffset(0)
            let data = handle.readDataToEndOfFile()
            guard let string = String(data: data, encoding: NSASCIIStringEncoding) else {
                XCTFail("Could not read stdout")
                return
            }
            XCTAssertEqual(string, "/usr/bin/which\n")
        }
    }
}

private func mkstemp(template: String, body: @noescape (NSFileHandle) throws -> Void) rethrows {
    let url = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("TestNSTask.XXXXXX")!
    var buffer = [Int8](repeating: 0, count: Int(PATH_MAX))
    url.getFileSystemRepresentation(&buffer, maxLength: buffer.count)
    switch mkstemp(&buffer) {
    case -1: XCTFail("Could not create temporary file")
    case let fd:
        defer { unlink(&buffer) }
        try body(NSFileHandle(fileDescriptor: fd, closeOnDealloc: true))
    }
}