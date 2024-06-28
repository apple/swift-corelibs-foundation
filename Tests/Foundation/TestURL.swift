// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if canImport(Android)
import Android
#endif

let kURLTestParsingTestsKey = "ParsingTests"

let kURLTestTitleKey = "In-Title"
let kURLTestUrlKey = "In-Url"
let kURLTestBaseKey = "In-Base"
let kURLTestURLCreatorKey = "In-URLCreator"
let kURLTestPathComponentKey = "In-PathComponent"
let kURLTestPathExtensionKey = "In-PathExtension"

let kURLTestCFResultsKey = "Out-CFResults"
let kURLTestNSResultsKey = "Out-NSResults"

let kNSURLWithStringCreator = "NSURLWithString"
let kCFURLCreateWithStringCreator = "CFURLCreateWithString"
let kCFURLCreateWithBytesCreator = "CFURLCreateWithBytes"
let kCFURLCreateAbsoluteURLWithBytesCreator = "CFURLCreateAbsoluteURLWithBytes"

let kNullURLString = "<null url>"
let kNullString = "<null>"

/// Reads the test data plist file and returns the list of objects
private func getTestData() -> [Any]? {
    let testFilePath = testBundle().url(forResource: "NSURLTestData", withExtension: "plist")
    let data = try! Data(contentsOf: testFilePath!)
    guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else {
        XCTFail("Unable to deserialize property list data")
        return nil
    }
    guard let testRoot = plist as? [String : Any] else {
        XCTFail("Unable to deserialize property list data")
        return nil
    }
    guard let parsingTests = testRoot[kURLTestParsingTestsKey] as? [Any] else {
        XCTFail("Unable to create the parsingTests dictionary")
        return nil
    }
    return parsingTests
}

class TestURL : XCTestCase {
#if os(Windows)
    func test_WindowsPathSeparator() {
      // ensure that the mixed slashes are handled properly
      // e.g. NOT file:///S:/b/u1%2/
      let u1 = URL(fileURLWithPath: "S:\\b\\u1/")
      XCTAssertEqual(u1.absoluteString, "file:///S:/b/u1/")

      // ensure that trailing slashes are compressed
      // e.g. NOT file:///S:/b/u2%2F%2F%2F%/
      let u2 = URL(fileURLWithPath: "S:\\b\\u2/////")
      XCTAssertEqual(u2.absoluteString, "file:///S:/b/u2/")

      // ensure that the trailing slashes are compressed even when mixed
      // e.g. NOT file:///S:/b/u3%2F%/%2F%2/
      let u3 = URL(fileURLWithPath: "S:\\b\\u3//\\//")
      XCTAssertEqual(u3.absoluteString, "file:///S:/b/u3/")
      XCTAssertEqual(u3.path, "S:/b/u3")

      // ensure that the regular conversion works
      let u4 = URL(fileURLWithPath: "S:\\b\\u4")
      XCTAssertEqual(u4.absoluteString, "file:///S:/b/u4")

      // ensure that the trailing slash is added
      let u5 = URL(fileURLWithPath: "S:\\b\\u5", isDirectory: true)
      XCTAssertEqual(u5.absoluteString, "file:///S:/b/u5/")

      // ensure that the trailing slash is preserved
      let u6 = URL(fileURLWithPath: "S:\\b\\u6\\")
      XCTAssertEqual(u6.absoluteString, "file:///S:/b/u6/")

      // ensure that we do not index beyond the start of the string
      // NOTE: explicitly mark `S:\b` as a directory as this test expects the
      // directory to exist to determine that it is a directory.
      let u7 = URL(fileURLWithPath: "eh",
                   relativeTo: URL(fileURLWithPath: "S:\\b", isDirectory: true))
      XCTAssertEqual(u7.absoluteString, "file:///S:/b/eh")

      let u8 = URL(fileURLWithPath: "eh",
                   relativeTo: URL(fileURLWithPath: "S:\\b", isDirectory: false))
      XCTAssertEqual(u8.absoluteString, "file:///S:/eh")

      // ensure that / is handled properly
      let u9 = URL(fileURLWithPath: "/")
      XCTAssertEqual(u9.absoluteString, "file:///")
    }

    func test_WindowsPathSeparator2() {
      let u1 = URL(fileURLWithPath: "S:\\b\\u1\\", isDirectory: false)
      XCTAssertEqual(u1.absoluteString, "file:///S:/b/u1")

      let u2 = URL(fileURLWithPath: "/", isDirectory: false)
      XCTAssertEqual(u2.absoluteString, "file:///")

      let u3 = URL(fileURLWithPath: "\\", isDirectory: false)
      XCTAssertEqual(u3.absoluteString, "file:///")

      let u4 = URL(fileURLWithPath: "S:\\b\\u3//\\//")
      XCTAssertEqual(u4.absoluteString, "file:///S:/b/u3/")

      // ensure leading slash doesn't break everything
      let u5 = URL(fileURLWithPath: "\\abs\\path")
      XCTAssertEqual(u5.absoluteString, "file:///abs/path")
      XCTAssertEqual(u5.path, "/abs/path")

      let u6 = u5.appendingPathComponent("test")
      XCTAssertEqual(u6.absoluteString, "file:///abs/path/test")
      XCTAssertEqual(u6.path, "/abs/path/test")

      let u7 = u6.deletingLastPathComponent()
      XCTAssertEqual(u7.absoluteString, "file:///abs/path/")
      XCTAssertEqual(u7.path, "/abs/path")
    }
#endif

    func test_fileURLWithPath_relativeTo() {
        let homeDirectory = NSHomeDirectory()
        let homeURL = URL(fileURLWithPath: homeDirectory, isDirectory: true)
        XCTAssertEqual(homeDirectory, homeURL.path)

        #if os(macOS)
        let baseURL = URL(fileURLWithPath: homeDirectory, isDirectory: true)
        let relativePath = "Documents"
        #elseif os(Android)
        let baseURL = URL(fileURLWithPath: "/data", isDirectory: true)
        let relativePath = "local"
        #elseif os(Linux) || os(OpenBSD)
        let baseURL = URL(fileURLWithPath: "/usr", isDirectory: true)
        let relativePath = "include"
        #elseif os(Windows)
        let baseURL = URL(fileURLWithPath: homeDirectory, isDirectory: true)
        let relativePath = "Documents"
        #endif
        // we're telling fileURLWithPath:isDirectory:relativeTo: Documents is a directory
        let url1 = URL(fileURLWithFileSystemRepresentation: relativePath, isDirectory: true, relativeTo: baseURL)
        // we're letting fileURLWithPath:relativeTo: determine Documents is a directory with I/O
        let url2 = URL(fileURLWithPath: relativePath, relativeTo: baseURL)
        XCTAssertEqual(url1, url2, "\(url1) was not equal to \(url2)")
        // we're telling fileURLWithPath:relativeTo: Documents is a directory with a trailing slash
        let url3 = URL(fileURLWithPath: relativePath + "/", relativeTo: baseURL)
        XCTAssertEqual(url1, url3, "\(url1) was not equal to \(url3)")
    }

    func test_relativeFilePath() {
        let url1 = URL(fileURLWithPath: "/this/is/absolute", relativeTo: nil)
        XCTAssertNil(url1.baseURL, "Absolute URLs should have no base URL")
        XCTAssertEqual(url1.path, url1.relativePath, "URLs without base path should have equal path and relativePath")

        let url2 = URL(fileURLWithPath: "this/is/relative", relativeTo: nil)
        XCTAssertNotNil(url2.baseURL, "Relative URLs should have base URL assigned")
        XCTAssertNotEqual(url2.path, url2.relativePath, "URLs without base path should have different path and relativePath")

        #if os(Windows)
        let url3 = URL(fileURLWithPath: "C:\\this\\is\\absolute", relativeTo: nil)
        XCTAssertNil(url3.baseURL, "Absolute URLs should have no base URL")
        XCTAssertEqual(url3.path, url3.relativePath, "URLs without base path should have equal path and relativePath")
        #endif
    }

    /// Returns a URL from the given url string and base
    private func URLWithString(_ urlString : String, baseString : String?) -> URL? {
        if let baseString = baseString {
            let baseURL = URL(string: baseString)
            return URL(string: urlString, relativeTo: baseURL)
        } else {
            return URL(string: urlString)
        }
    }

    internal func generateResults(_ url: URL, pathComponent: String?, pathExtension : String?) -> [String : Any] {
        var result = [String : Any]()
        if let pathComponent = pathComponent {
            let newFileURL = url.appendingPathComponent(pathComponent, isDirectory: false)
            result["appendingPathComponent-File"] = newFileURL.relativeString
            result["appendingPathComponent-File-BaseURL"] = newFileURL.baseURL?.relativeString ?? kNullString

            let newDirURL = url.appendingPathComponent(pathComponent, isDirectory: true)
            result["appendingPathComponent-Directory"] = newDirURL.relativeString
            result["appendingPathComponent-Directory-BaseURL"] = newDirURL.baseURL?.relativeString ?? kNullString
        } else if let pathExtension = pathExtension {
            let newURL = url.appendingPathExtension(pathExtension)
            result["appendingPathExtension"] = newURL.relativeString
            result["appendingPathExtension-BaseURL"] = newURL.baseURL?.relativeString ?? kNullString
        } else {
            result["relativeString"] = url.relativeString
            result["baseURLString"] = url.baseURL?.relativeString ?? kNullString
            result["absoluteString"] = url.absoluteString
            result["absoluteURLString"] = url.absoluteURL.relativeString
            result["scheme"] = url.scheme ?? kNullString
            result["host"] = url.host(percentEncoded: false) ?? kNullString

            result["port"] = url.port ?? kNullString
            result["user"] = url.user(percentEncoded: false) ?? kNullString
            result["password"] = url.password ?? kNullString
            result["path"] = url.path
            result["query"] = url.query ?? kNullString
            result["fragment"] = url.fragment ?? kNullString
            result["relativePath"] = url.relativePath
            result["isFileURL"] = url.isFileURL ? "YES" : "NO"
            result["standardizedURL"] = url.standardized.relativeString

            result["pathComponents"] = url.pathComponents
            result["lastPathComponent"] = url.lastPathComponent
            result["pathExtension"] = url.pathExtension
            result["deletingLastPathComponent"] = url.deletingLastPathComponent().relativeString
            result["deletingLastPathExtension"] = url.deletingPathExtension().relativeString
        }
        return result
    }

    internal func compareResults(_ url : URL, expected : [String : Any], got : [String : Any]) -> (Bool, [String]) {
        var differences = [String]()
        for (key, expectation) in expected {
            // Skip non-string expected results
            if ["port", "standardizedURL", "pathComponents"].contains(key) {
                continue
            }
            var obj: Any? = expectation
            if obj as? String == kNullString {
                obj = nil
            }
            if let expectedValue = obj as? String {
                if let testedValue = got[key] as? String {
                    if expectedValue != testedValue {
                        differences.append(" \(key)  Expected = '\(expectedValue)',  Got = '\(testedValue)'")
                    }
                } else {
                    differences.append(" \(key)  Expected = '\(expectedValue)',  Got = '\(String(describing: got[key]))'")
                }
            } else if let expectedValue = obj as? [String] {
                if let testedValue = got[key] as? [String] {
                    if expectedValue != testedValue {
                        differences.append(" \(key)  Expected = '\(expectedValue)',  Got = '\(testedValue)'")
                    }
                } else {
                    differences.append(" \(key)  Expected = '\(expectedValue)',  Got = '\(String(describing: got[key]))'")
                }
            } else if let expectedValue = obj as? Int {
                if let testedValue = got[key] as? Int {
                    if expectedValue != testedValue {
                        differences.append(" \(key)  Expected = '\(expectedValue)',  Got = '\(testedValue)'")
                    }
                } else {
                    differences.append(" \(key)  Expected = '\(expectedValue)',  Got = '\(String(describing: got[key]))'")
                }
            } else if obj == nil {
                if got[key] != nil && got[key] as? String != kNullString {
                    differences.append(" \(key)  Expected = '\(String(describing: obj))',  Got = '\(String(describing: got[key]))'")
                }
            }

        }
        for (key, obj) in got {
            if expected[key] == nil {
                differences.append(" \(key)  Expected = 'nil',  Got = '\(obj)'")
            }
        }
        if differences.count > 0 {
            differences.sort()
            differences.insert(" url:  '\(url)' ", at: 0)
            return (false, differences)
        } else {
            return (true, [])
        }
    }

    // TODO: Disabled until it is updated to the new parser in swift-foundation
    #if false
    func test_URLStrings() {
        for obj in getTestData()! {
            let testDict = obj as! [String: Any]
            let title = testDict[kURLTestTitleKey] as! String
            let inURL = testDict[kURLTestUrlKey]! as! String
            let inBase = testDict[kURLTestBaseKey] as! String?
            let inPathComponent = testDict[kURLTestPathComponentKey] as! String?
            let inPathExtension = testDict[kURLTestPathExtensionKey] as! String?
            let expectedNSResult = testDict[kURLTestNSResultsKey]!
            var url : URL? = nil

            switch (testDict[kURLTestURLCreatorKey]! as! String) {
            case kNSURLWithStringCreator:
                url = URLWithString(inURL, baseString: inBase)
            case kCFURLCreateWithStringCreator, kCFURLCreateWithBytesCreator, kCFURLCreateAbsoluteURLWithBytesCreator:
                // TODO: Not supported right now
                continue
            default:
                XCTFail()
            }

#if os(Windows)
            // On Windows, pipes are valid charcters which can be used
            // to replace a ':'. See RFC 8089 Section E.2.2 for
            // details.
            //
            // Skip the test which expects pipes to be invalid
            let skippedPipeTest = "NSURLWithString-parse-absolute-escape-006-pipe-invalid"
#else
            // On other platforms, pipes are not valid
            //
            // Skip the test which expects pipes to be valid
            let skippedPipeTest = "NSURLWithString-parse-absolute-escape-006-pipe-valid"
#endif
            let skippedTests = [
                "NSURLWithString-parse-ambiguous-url-001", // TODO: Fix Test
                skippedPipeTest,
            ]
            if skippedTests.contains(title) { continue }

            if let url = url {
                let results = generateResults(url, pathComponent: inPathComponent, pathExtension: inPathExtension)
                if let expected = expectedNSResult as? [String: Any] {
                    let (isEqual, differences) = compareResults(url, expected: expected, got: results)
                    XCTAssertTrue(isEqual, "\(title): \(differences.joined(separator: "\n"))")
                } else {
                    XCTFail("\(url) should not be a valid url")
                }
            } else {
                XCTAssertEqual(expectedNSResult as? String, kNullURLString)
            }
        }
    }
    #endif

    static let gBaseTemporaryDirectoryPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("org.swift.foundation.TestFoundation.TestURL.\(ProcessInfo.processInfo.processIdentifier)")
    static var gBaseCurrentWorkingDirectoryPath : String {
        return FileManager.default.currentDirectoryPath
    }
    static var gSavedPath = ""
    static var gRelativeOffsetFromBaseCurrentWorkingDirectory: UInt = 0
    static let gFileExistsName = "TestCFURL_file_exists\(ProcessInfo.processInfo.globallyUniqueString)"
    static let gFileDoesNotExistName = "TestCFURL_file_does_not_exist"
    static let gDirectoryExistsName = "TestCFURL_directory_exists\(ProcessInfo.processInfo.globallyUniqueString)"
    static let gDirectoryDoesNotExistName = "TestCFURL_directory_does_not_exist"
    static let gFileExistsPath = gBaseTemporaryDirectoryPath + gFileExistsName
    static let gFileDoesNotExistPath = gBaseTemporaryDirectoryPath + gFileDoesNotExistName
    static let gDirectoryExistsPath = gBaseTemporaryDirectoryPath + gDirectoryExistsName
    static let gDirectoryDoesNotExistPath = gBaseTemporaryDirectoryPath + gDirectoryDoesNotExistName

    override class func tearDown() {
        let path = TestURL.gBaseTemporaryDirectoryPath
        if (try? FileManager.default.attributesOfItem(atPath: path)) != nil {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                NSLog("Could not remove test directory at path \(path): \(error)")
            }
        }

        super.tearDown()
    }

    static func setup_test_paths() -> Bool {
        _ = FileManager.default.createFile(atPath: gFileExistsPath, contents: nil)

        do {
          try FileManager.default.removeItem(atPath: gFileDoesNotExistPath)
        } catch {
          // The error code is a CocoaError
          if (error as? NSError)?.code != CocoaError.fileNoSuchFile.rawValue {
            return false
          }
        }

        do {
          try FileManager.default.createDirectory(atPath: gDirectoryExistsPath, withIntermediateDirectories: false)
        } catch {
            // The error code is a CocoaError
            if (error as? NSError)?.code != CocoaError.fileWriteFileExists.rawValue {
                return false
            }
        }

        do {
          try FileManager.default.removeItem(atPath: gDirectoryDoesNotExistPath)
        } catch {
            // The error code is a CocoaError
            if (error as? NSError)?.code != CocoaError.fileNoSuchFile.rawValue {
                return false
            }
        }

        TestURL.gSavedPath = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(NSTemporaryDirectory())

        let cwd = FileManager.default.currentDirectoryPath
        let cwdURL = URL(fileURLWithPath: cwd, isDirectory: true)
        // 1 for path separator
        cwdURL.withUnsafeFileSystemRepresentation {
            gRelativeOffsetFromBaseCurrentWorkingDirectory = UInt(strlen($0!) + 1)
        }

        return true
    }

    func test_fileURLWithPath() {
        if !TestURL.setup_test_paths() {
            let error = strerror(errno)!
            XCTFail("Failed to set up test paths: \(String(cString: error))")
        }
        defer { FileManager.default.changeCurrentDirectoryPath(TestURL.gSavedPath) }

        // test with file that exists
        var path = TestURL.gFileExistsPath
        var url = NSURL(fileURLWithPath: path)
        XCTAssertFalse(url.hasDirectoryPath, "did not expect URL with directory path: \(url)")
        XCTAssertEqual(path, url.path, "path from file path URL is wrong")

        // test with file that doesn't exist
        path = TestURL.gFileDoesNotExistPath
        url = NSURL(fileURLWithPath: path)
        XCTAssertFalse(url.hasDirectoryPath, "did not expect URL with directory path: \(url)")
        XCTAssertEqual(path, url.path, "path from file path URL is wrong")

        // test with directory that exists
        path = TestURL.gDirectoryExistsPath
        url = NSURL(fileURLWithPath: path)
        XCTAssertTrue(url.hasDirectoryPath, "expected URL with directory path: \(url)")
        XCTAssertEqual(path, url.path, "path from file path URL is wrong")

        // test with directory that doesn't exist
        path = TestURL.gDirectoryDoesNotExistPath
        url = NSURL(fileURLWithPath: path)
        XCTAssertFalse(url.hasDirectoryPath, "did not expect URL with directory path: \(url)")
        XCTAssertEqual(path, url.path, "path from file path URL is wrong")

        // test with name relative to current working directory
        path = TestURL.gFileDoesNotExistName
        url = NSURL(fileURLWithPath: path)
        XCTAssertFalse(url.hasDirectoryPath, "did not expect URL with directory path: \(url)")
        let fileSystemRep = url.fileSystemRepresentation
        let actualLength = strlen(fileSystemRep)
        // 1 for path separator
        let expectedLength = UInt(strlen(TestURL.gFileDoesNotExistName)) + TestURL.gRelativeOffsetFromBaseCurrentWorkingDirectory
        XCTAssertEqual(UInt(actualLength), expectedLength, "fileSystemRepresentation was too short")
#if os(Windows)
        // On Windows, the URL path should have `/` separators and the
        // fileSystemRepresentation should have `\` separators.
        XCTAssertTrue(strncmp(String(TestURL.gBaseCurrentWorkingDirectoryPath.map { $0 == "/" ? "\\" : $0 }),
                              fileSystemRep,
                              Int(strlen(TestURL.gBaseCurrentWorkingDirectoryPath))) == 0,
                      "fileSystemRepresentation of base path is wrong")
#else
        XCTAssertTrue(strncmp(TestURL.gBaseCurrentWorkingDirectoryPath, fileSystemRep, Int(strlen(TestURL.gBaseCurrentWorkingDirectoryPath))) == 0, "fileSystemRepresentation of base path is wrong")
#endif
        let lengthOfRelativePath = Int(strlen(TestURL.gFileDoesNotExistName))
        let relativePath = fileSystemRep.advanced(by: Int(TestURL.gRelativeOffsetFromBaseCurrentWorkingDirectory))
        XCTAssertTrue(strncmp(TestURL.gFileDoesNotExistName, relativePath, lengthOfRelativePath) == 0, "fileSystemRepresentation of file path is wrong")

        // SR-12366
        let url1 = URL(fileURLWithPath: "/path/to/b/folder", isDirectory: true).standardizedFileURL.absoluteString
        let url2 = URL(fileURLWithPath: "/path/to/b/folder", isDirectory: true).absoluteString
        XCTAssertEqual(url1, url2)
    }

    func test_fileURLWithPath_isDirectory() {
        if !TestURL.setup_test_paths() {
            let error = strerror(errno)!
            XCTFail("Failed to set up test paths: \(String(cString: error))")
        }
        defer { FileManager.default.changeCurrentDirectoryPath(TestURL.gSavedPath) }

        // test with file that exists
        var path = TestURL.gFileExistsPath
        var url = NSURL(fileURLWithPath: path, isDirectory: true)
        XCTAssertTrue(url.hasDirectoryPath, "expected URL with directory path: \(url)")
        url = NSURL(fileURLWithPath: path, isDirectory: false)
        XCTAssertFalse(url.hasDirectoryPath, "did not expect URL with directory path: \(url)")
        XCTAssertEqual(path, url.path, "path from file path URL is wrong")

        // test with file that doesn't exist
        path = TestURL.gFileDoesNotExistPath
        url = NSURL(fileURLWithPath: path, isDirectory: true)
        XCTAssertTrue(url.hasDirectoryPath, "expected URL with directory path: \(url)")
        url = NSURL(fileURLWithPath: path, isDirectory: false)
        XCTAssertFalse(url.hasDirectoryPath, "did not expect URL with directory path: \(url)")
        XCTAssertEqual(path, url.path, "path from file path URL is wrong")

        // test with directory that exists
        path = TestURL.gDirectoryExistsPath
        url = NSURL(fileURLWithPath: path, isDirectory: false)
        XCTAssertFalse(url.hasDirectoryPath, "did not expect URL with directory path: \(url)")
        url = NSURL(fileURLWithPath: path, isDirectory: true)
        XCTAssertTrue(url.hasDirectoryPath, "expected URL with directory path: \(url)")
        XCTAssertEqual(path, url.path, "path from file path URL is wrong")

        // test with directory that doesn't exist
        path = TestURL.gDirectoryDoesNotExistPath
        url = NSURL(fileURLWithPath: path, isDirectory: false)
        XCTAssertFalse(url.hasDirectoryPath, "did not expect URL with directory path: \(url)")
        url = NSURL(fileURLWithPath: path, isDirectory: true)
        XCTAssertTrue(url.hasDirectoryPath, "expected URL with directory path: \(url)")
        XCTAssertEqual(path, url.path, "path from file path URL is wrong")

        // test with name relative to current working directory
        path = TestURL.gFileDoesNotExistName
        url = NSURL(fileURLWithPath: path, isDirectory: false)
        XCTAssertFalse(url.hasDirectoryPath, "did not expect URL with directory path: \(url)")
        url = NSURL(fileURLWithPath: path, isDirectory: true)
        XCTAssertTrue(url.hasDirectoryPath, "expected URL with directory path: \(url)")
        let fileSystemRep = url.fileSystemRepresentation
        let actualLength = UInt(strlen(fileSystemRep))
        // 1 for path separator
        let expectedLength = UInt(strlen(TestURL.gFileDoesNotExistName)) + TestURL.gRelativeOffsetFromBaseCurrentWorkingDirectory
        XCTAssertEqual(actualLength, expectedLength, "fileSystemRepresentation was too short")
#if os(Windows)
        // On Windows, the URL path should have `/` separators and the
        // fileSystemRepresentation should have `\` separators.
        XCTAssertTrue(strncmp(String(TestURL.gBaseCurrentWorkingDirectoryPath.map { $0 == "/" ? "\\" : $0 }),
                              fileSystemRep,
                              Int(strlen(TestURL.gBaseCurrentWorkingDirectoryPath))) == 0,
                      "fileSystemRepresentation of base path is wrong")
#else
        XCTAssertTrue(strncmp(TestURL.gBaseCurrentWorkingDirectoryPath, fileSystemRep, Int(strlen(TestURL.gBaseCurrentWorkingDirectoryPath))) == 0, "fileSystemRepresentation of base path is wrong")
#endif
        let lengthOfRelativePath = Int(strlen(TestURL.gFileDoesNotExistName))
        let relativePath = fileSystemRep.advanced(by: Int(TestURL.gRelativeOffsetFromBaseCurrentWorkingDirectory))
        XCTAssertTrue(strncmp(TestURL.gFileDoesNotExistName, relativePath, lengthOfRelativePath) == 0, "fileSystemRepresentation of file path is wrong")
    }

    func test_URLByResolvingSymlinksInPathShouldRemoveDuplicatedPathSeparators() {
        let url = URL(fileURLWithPath: "//foo///bar////baz/")
        let result = url.resolvingSymlinksInPath()
        XCTAssertEqual(result, URL(fileURLWithPath: "/foo/bar/baz/"))
    }

    func test_URLByResolvingSymlinksInPathShouldRemoveSingleDotsBetweenSeparators() {
        let url = URL(fileURLWithPath: "/./foo/./.bar/./baz/./")
        let result = url.resolvingSymlinksInPath()
        XCTAssertEqual(result, URL(fileURLWithPath: "/foo/.bar/baz/"))
    }

    func test_URLByResolvingSymlinksInPathShouldCompressDoubleDotsBetweenSeparators() {
        let url = URL(fileURLWithPath: "/foo/../..bar/../baz/")
        let result = url.resolvingSymlinksInPath()
        XCTAssertEqual(result, URL(fileURLWithPath: "/baz/"))
    }

    func test_URLByResolvingSymlinksInPathShouldUseTheCurrentDirectory() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: writableTestDirectoryURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: writableTestDirectoryURL) }

        let previousCurrentDirectory = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(writableTestDirectoryURL.path)
        defer { fileManager.changeCurrentDirectoryPath(previousCurrentDirectory) }

        // In Darwin, because temporary directory is inside /private,
        // writableTestDirectoryURL will be something like /var/folders/...,
        // but /var points to /private/var, which is only removed if the
        // destination exists, so we create the destination to avoid having to
        // compare against /private in Darwin.
        try fileManager.createDirectory(at: writableTestDirectoryURL.appendingPathComponent("foo/bar"), withIntermediateDirectories: true)
        try "".write(to: writableTestDirectoryURL.appendingPathComponent("foo/bar/baz"), atomically: true, encoding: .utf8)

        let url = URL(fileURLWithPath: "foo/bar/baz")
        let result = url.resolvingSymlinksInPath()
        XCTAssertEqual(result, URL(fileURLWithPath: writableTestDirectoryURL.path + "/foo/bar/baz").resolvingSymlinksInPath())
    }

    func test_resolvingSymlinksInPathShouldAppendTrailingSlashWhenExistingDirectory() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: writableTestDirectoryURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: writableTestDirectoryURL) }

        var path = writableTestDirectoryURL.path
        if path.hasSuffix("/") {
            path.remove(at: path.index(path.endIndex, offsetBy: -1))
        }
        let url = URL(fileURLWithPath: path)
        let result = url.resolvingSymlinksInPath()
        XCTAssertEqual(result, URL(fileURLWithPath: path + "/").resolvingSymlinksInPath())
    }

    func test_resolvingSymlinksInPathShouldResolveSymlinks() throws {
        // NOTE: this test only works on file systems that support symlinks.
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: writableTestDirectoryURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: writableTestDirectoryURL) }

        let symbolicLink = writableTestDirectoryURL.appendingPathComponent("origin")
        let destination = writableTestDirectoryURL.appendingPathComponent("destination")
        try "".write(to: destination, atomically: true, encoding: .utf8)
        try fileManager.createSymbolicLink(at: symbolicLink, withDestinationURL: destination)

        let result = symbolicLink.resolvingSymlinksInPath()
        XCTAssertEqual(result, URL(fileURLWithPath: writableTestDirectoryURL.path + "/destination").resolvingSymlinksInPath())
    }

    func test_resolvingSymlinksInPathShouldRemovePrivatePrefix() throws {
        #if !canImport(Darwin)
        throw XCTSkip("This test is only supported on Darwin")
        #else
        // NOTE: this test only works on Darwin, since the code that removes
        // /private relies on /private/tmp existing.
        let url = URL(fileURLWithPath: "/private/tmp")
        let result = url.resolvingSymlinksInPath()
        XCTAssertEqual(result, URL(fileURLWithPath: "/tmp"))
        #endif
    }

    func test_resolvingSymlinksInPathShouldNotRemovePrivatePrefixIfOnlyComponent() throws {
        #if !canImport(Darwin)
        throw XCTSkip("This test is only supported on Darwin")
        #else
        // NOTE: this test only works on Darwin, since only there /tmp is
        // symlinked to /private/tmp.
        let url = URL(fileURLWithPath: "/tmp/..")
        let result = url.resolvingSymlinksInPath()
        XCTAssertEqual(result, URL(fileURLWithPath: "/private"))
        #endif
    }

    func test_resolvingSymlinksInPathShouldNotChangeNonFileURLs() throws {
        let url = try XCTUnwrap(URL(string: "myscheme://server/foo/bar/baz"))
        let result = url.resolvingSymlinksInPath().absoluteString
        XCTAssertEqual(result, "myscheme://server/foo/bar/baz")
    }

    func test_resolvingSymlinksInPathShouldNotChangePathlessURLs() throws {
        let url = try XCTUnwrap(URL(string: "file://"))
        let result = url.resolvingSymlinksInPath().absoluteString
        XCTAssertEqual(result, "file://")
    }

    func test_reachable() {
        #if os(Android)
        var url = URL(fileURLWithPath: "/data")
        #elseif os(Windows)
        var url = URL(fileURLWithPath: NSHomeDirectory())
        #else
        var url = URL(fileURLWithPath: "/usr")
        #endif
        XCTAssertEqual(true, try? url.checkResourceIsReachable())

        url = URL(string: "https://www.swift.org")!
        do {
            _ = try url.checkResourceIsReachable()
            XCTFail()
        } catch let error as NSError {
            XCTAssertEqual(NSCocoaErrorDomain, error.domain)
            XCTAssertEqual(CocoaError.Code.fileReadUnsupportedScheme.rawValue, error.code)
        } catch {
            XCTFail()
        }

        url = URL(fileURLWithPath: "/some_random_path")
        do {
            _ = try url.checkResourceIsReachable()
            XCTFail()
        } catch let error as NSError {
            XCTAssertEqual(NSCocoaErrorDomain, error.domain)
            XCTAssertEqual(CocoaError.Code.fileReadNoSuchFile.rawValue, error.code)
        } catch {
            XCTFail()
        }

        #if os(Android)
        var nsURL = NSURL(fileURLWithPath: "/data")
        #elseif os(Windows)
        var nsURL = NSURL(fileURLWithPath: NSHomeDirectory())
        #else
        var nsURL = NSURL(fileURLWithPath: "/usr")
        #endif
        XCTAssertEqual(true, try? nsURL.checkResourceIsReachable())

        nsURL = NSURL(string: "https://www.swift.org")!
        do {
            _ = try nsURL.checkResourceIsReachable()
            XCTFail()
        } catch let error as NSError {
            XCTAssertEqual(NSCocoaErrorDomain, error.domain)
            XCTAssertEqual(CocoaError.Code.fileReadUnsupportedScheme.rawValue, error.code)
        } catch {
            XCTFail()
        }

        nsURL = NSURL(fileURLWithPath: "/some_random_path")
        do {
            _ = try nsURL.checkResourceIsReachable()
            XCTFail()
        } catch let error as NSError {
            XCTAssertEqual(NSCocoaErrorDomain, error.domain)
            XCTAssertEqual(CocoaError.Code.fileReadNoSuchFile.rawValue, error.code)
        } catch {
            XCTFail()
        }
    }

    func test_copy() {
        let url = NSURL(string: "https://www.swift.org")
        let urlCopy = url!.copy() as! NSURL
        XCTAssertTrue(url!.isEqual(urlCopy))

        let queryItem = NSURLQueryItem(name: "id", value: "23")
        let queryItemCopy = queryItem.copy() as! NSURLQueryItem
        XCTAssertTrue(queryItem.isEqual(queryItemCopy))
    }

    func test_itemNSCoding() {
        let queryItemA = NSURLQueryItem(name: "id", value: "23")
        let queryItemB = NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: queryItemA)) as! NSURLQueryItem
        XCTAssertEqual(queryItemA, queryItemB, "Archived then unarchived query item must be equal.")
    }

    func test_dataRepresentation() {
        let url = NSURL(fileURLWithPath: "/tmp/foo")
        let url2 = NSURL(dataRepresentation: url.dataRepresentation,
            relativeTo: nil)
        XCTAssertEqual(url, url2)
    }

   func test_description() {
        let url = URL(string: "http://amazon.in")!
        XCTAssertEqual(url.description, "http://amazon.in")
        var urlComponents = URLComponents()
        urlComponents.port = 8080
        urlComponents.host = "amazon.in"
        urlComponents.password = "abcd"
        let relativeURL = urlComponents.url(relativeTo: url)
        XCTAssertEqual(relativeURL?.description, "//:abcd@amazon.in:8080 -- http://amazon.in")
    }

    // MARK: Resource values.

    func test_URLResourceValues() throws {
        do {
            try FileManager.default.createDirectory(at: writableTestDirectoryURL, withIntermediateDirectories: true)
            var a = writableTestDirectoryURL.appendingPathComponent("a")
            try Data().write(to: a)

            // Not all OSes support fractions of a second; remove the fractional part.
            let (roughlyAYearFromNowInterval, _) = modf(Date(timeIntervalSinceNow: 1 * 365 * 24 * 60 * 60).timeIntervalSinceReferenceDate)
            let roughlyAYearFromNow = Date(timeIntervalSinceReferenceDate: roughlyAYearFromNowInterval)

            var values = URLResourceValues()
            values.contentModificationDate = roughlyAYearFromNow

            try a.setResourceValues(values)

            let keys: Set<URLResourceKey> = [
                .contentModificationDateKey,
            ]

            func assertRelevantValuesAreEqual(in newValues: URLResourceValues) {
                XCTAssertEqual(values.contentModificationDate, newValues.contentModificationDate)
            }

            do {
                let newValues = try a.resourceValues(forKeys: keys)
                assertRelevantValuesAreEqual(in: newValues)
            }

            do {
                a.removeAllCachedResourceValues()
                let newValues = try a.resourceValues(forKeys: keys)
                assertRelevantValuesAreEqual(in: newValues)
            }

            do {
                let separateA = writableTestDirectoryURL.appendingPathComponent("a")
                let newValues = try separateA.resourceValues(forKeys: keys)
                assertRelevantValuesAreEqual(in: newValues)
            }
        } catch {
            if let error = error as? NSError {
                print("error: \(error.description) - \(error.userInfo)")
            } else {
                print("error: \(error)")
            }
            throw error
        }
    }

    // MARK: -

    var writableTestDirectoryURL: URL!

    override func setUp() {
        super.setUp()

        let pid = ProcessInfo.processInfo.processIdentifier
        writableTestDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("org.swift.TestFoundation.TestURL.resourceValues.\(pid)")
    }

    override func tearDown() {
        if let directoryURL = writableTestDirectoryURL,
            (try? FileManager.default.attributesOfItem(atPath: directoryURL.path)) != nil {
            do {
                try FileManager.default.removeItem(at: directoryURL)
            } catch {
                NSLog("Could not remove test directory at URL \(directoryURL): \(error)")
            }
        }

        super.tearDown()
    }
}
