// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
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


class TestNSProcessInfo : XCTestCase {
    
    var allTests : [(String, () -> ())] {
        return [
            ("test_processName", test_processName ),
        ]
    }
    
    func test_processName() {
        // Assert that the original process name is "TestFoundation". This test
        // will fail if the test target ever gets renamed, so maybe it should
        // just test that the initial name is not empty or something?
        let processInfo = NSProcessInfo.processInfo()
        let targetName = "TestFoundation"
        let originalProcessName = processInfo.processName
        XCTAssertEqual(originalProcessName, targetName, "\"\(originalProcessName)\" not equal to \"TestFoundation\"")
        
        // Try assigning a new process name.
        let newProcessName = "TestProcessName"
        processInfo.processName = newProcessName
        XCTAssertEqual(processInfo.processName, newProcessName, "\"\(processInfo.processName)\" not equal to \"\(newProcessName)\"")
        
        // Assign back to the original process name.
        processInfo.processName = originalProcessName
        XCTAssertEqual(processInfo.processName, originalProcessName, "\"\(processInfo.processName)\" not equal to \"\(originalProcessName)\"")
    }
}
