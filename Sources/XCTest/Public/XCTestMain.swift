// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//
//  XCTestMain.swift
//  This is the main file for the framework. It provides the entry point function
//  for running tests and some infrastructure for running them.
//

// Note that we are re-exporting Foundation so tests importing XCTest don't need
// to import it themselves. This is consistent with the behavior of Apple XCTest
#if os(macOS)
    #if USE_FOUNDATION_FRAMEWORK
    @_exported import Foundation
    #else
    @_exported import SwiftFoundation
    #endif
#else
    @_exported import Foundation
#endif

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

/// Starts a test run for the specified test cases.
///
/// Example usage:
///
///     class TestFoo: XCTestCase {
///         static var allTests = {
///             return [
///                 ("test_foo", test_foo),
///                 ("test_bar", test_bar),
///             ]
///         }()
///
///         func test_foo() {
///             // Test things...
///         }
///
///         // etc...
///     }
///
///     let exitCode = XCTMain([ testCase(TestFoo.allTests) ])
///
/// Command line arguments can be used to select a particular test case or class
/// to execute. For example:
///
///     ./FooTests FooTestCase/testFoo  # Run a single test case
///     ./FooTests FooTestCase          # Run all the tests in FooTestCase
///
/// - Parameters:
///     - testCases: An array of test cases run, each produced by a call to the
///         `testCase` function.
///     - arguments: Command-line arguments to pass to XCTest. By default, the
///         arguments passed to the process are used.
///     - observers: Zero or more observers that should observe events that
///         occur while testing. If `nil` (the default), events are written to
///         the console.
///
/// - Returns: The exit code to use when the process terminates. `EXIT_SUCCESS`
///     indicates success, while any other value (including `EXIT_FAILURE`)
///     indicates failure.
@_disfavoredOverload
public func XCTMain(
    _ testCases: [XCTestCaseEntry],
    arguments: [String] = CommandLine.arguments,
    observers: [XCTestObservation]? = nil
) -> CInt {
    let observers = observers ?? [PrintObserver()]
    let testBundle = Bundle.main

    let executionMode = ArgumentParser(arguments: arguments).executionMode

    // Apple XCTest behaves differently if tests have been filtered:
    // - The root `XCTestSuite` is named "Selected tests" instead of
    //   "All tests".
    // - An `XCTestSuite` representing the .xctest test bundle is not included.
    let rootTestSuite: XCTestSuite
    let currentTestSuite: XCTestSuite
    if executionMode.selectedTestNames == nil {
        rootTestSuite = XCTestSuite(name: "All tests")
        currentTestSuite = XCTestSuite(name: "\(testBundle.bundleURL.lastPathComponent).xctest")
        rootTestSuite.addTest(currentTestSuite)
    } else {
        rootTestSuite = XCTestSuite(name: "Selected tests")
        currentTestSuite = rootTestSuite
    }

    let filter = TestFiltering(selectedTestNames: executionMode.selectedTestNames)
    TestFiltering.filterTests(testCases, filter: filter.selectedTestFilter)
        .map(XCTestCaseSuite.init)
        .forEach(currentTestSuite.addTest)

    switch executionMode {
    case .list(type: .humanReadable):
        TestListing(testSuite: rootTestSuite).printTestList()
        return EXIT_SUCCESS
    case .list(type: .json):
        TestListing(testSuite: rootTestSuite).printTestJSON()
        return EXIT_SUCCESS
    case let .help(invalidOption):
        if let invalid = invalidOption {
            let errMsg = "Error: Invalid option \"\(invalid)\"\n"
            FileHandle.standardError.write(errMsg.data(using: .utf8) ?? Data())
        }
        let exeName = URL(fileURLWithPath: arguments[0]).lastPathComponent
        let sampleTest = rootTestSuite.list().first ?? "Tests.FooTestCase/testFoo"
        let sampleTests = sampleTest.prefix(while: { $0 != "/" })
        print("""
              Usage: \(exeName) [OPTION]
                     \(exeName) [TESTCASE]
              Run and report results of test cases.

              With no OPTION or TESTCASE, runs all test cases.

              OPTIONS:

              -l, --list-tests             List tests line by line to standard output
                  --dump-tests-json        List tests in JSON to standard output

              TESTCASES:

                 Run a single test

                     > \(exeName) \(sampleTest)

                 Run all the tests in \(sampleTests)

                     > \(exeName) \(sampleTests)
              """)
        return invalidOption == nil ? EXIT_SUCCESS : EXIT_FAILURE
    case .run(selectedTestNames: _):
        // Add a test observer that prints test progress to stdout.
        let observationCenter = XCTestObservationCenter.shared
        for observer in observers {
            observationCenter.addTestObserver(observer)
        }

        observationCenter.testBundleWillStart(testBundle)
        rootTestSuite.run()
        observationCenter.testBundleDidFinish(testBundle)

        return rootTestSuite.testRun!.totalFailureCount == 0 ? EXIT_SUCCESS : EXIT_FAILURE
    }
}

// @available(*, deprecated, message: "Call the overload of XCTMain() that returns an exit code instead.")
public func XCTMain(_ testCases: [XCTestCaseEntry]) -> Never {
    exit(XCTMain(testCases, arguments: CommandLine.arguments, observers: nil) as CInt)
}

// @available(*, deprecated, message: "Call the overload of XCTMain() that returns an exit code instead.")
public func XCTMain(_ testCases: [XCTestCaseEntry], arguments: [String]) -> Never {
    exit(XCTMain(testCases, arguments: arguments, observers: nil) as CInt)
}

// @available(*, deprecated, message: "Call the overload of XCTMain() that returns an exit code instead.")
public func XCTMain(
    _ testCases: [XCTestCaseEntry],
    arguments: [String],
    observers: [XCTestObservation]
) -> Never {
    exit(XCTMain(testCases, arguments: arguments, observers: observers) as CInt)
}
