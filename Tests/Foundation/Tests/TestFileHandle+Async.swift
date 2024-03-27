// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test
// REQUIRES: objc_interop

#if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT
    #if canImport(SwiftFoundation) && !DEPLOYMENT_RUNTIME_OBJC
        @testable import SwiftFoundation
    #else
        @testable import Foundation
    #endif
#endif

extension AsyncSequence {
    @inlinable @inline(__always)
    func measure(_ N: Int) async rethrows -> Double {
        var count = 0
        let pi = ProcessInfo.processInfo
        let start = pi.systemUptime
        for try await _ in self {
            count += 1
            if count >= N {
                let end = pi.systemUptime
                return Double(count) / (end - start)
            }
        }
        return .nan
    }
}

extension Sequence {
  public var async: AsyncLazySequence<Self> {
    AsyncLazySequence(self)
  }
}

public struct AsyncLazySequence<Base: Sequence>: AsyncSequence {
  public typealias Element = Base.Element
  
  public struct Iterator: AsyncIteratorProtocol {
    var iterator: Base.Iterator?
    
    public mutating func next() async -> Base.Element? {
      if Task.isCancelled {
        iterator = nil
        return nil
      }
      
      return iterator?.next()
    }
  }
  
  let base: Base
  
  init(_ base: Base) {
    self.base = base
  }
  
  public func makeAsyncIterator() -> Iterator {
    Iterator(iterator: base.makeIterator())
  }
}

extension AsyncSequence {
  @inlinable
  public func collect() async rethrows -> [Element] {
    var collected = [Element]()
    for try await item in self {
      collected.append(item)
    }
    return collected
  }
}

// Tests for AsyncSequence bytestream adaptors are here until that can move to the stdlib

class TestFileHandleAsync : XCTestCase {

    func _create_test_file_and_run(with data: String, work: (URL) async throws -> Void) async rethrows {
        let fm = FileManager.default
        
        // Temporary directory
        let dirPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(NSUUID().uuidString)
        try! fm.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
        do {
            let filePath = "\(dirPath)/test.txt"
            try! data.write(toFile: filePath, atomically: true, encoding: .utf8)
            try await work(URL(fileURLWithPath: filePath))
            try! FileManager.default.removeItem(atPath: dirPath)
        } catch {
            
        }
    }

    func _test_lines(with data: String, expectedResults: [String]? = nil) async throws {
        var collected = [String]()
        let expected = (expectedResults ?? data.split(whereSeparator: { $0.isNewline }).map(String.init))
        try await _create_test_file_and_run(with: data) {
            for try await line in $0.lines {
                collected.append(line)
            }
        }
        XCTAssertEqual(collected, expected)
    }
    
    func _test_characters(with data: String) async throws {
        try await _create_test_file_and_run(with: data) {
            let expected = data.map(String.init)
            var result = [String]()
            for try await char in try FileHandle(forReadingFrom: $0).bytes.characters {
                result.append(String(char))
            }
            XCTAssertEqual(expected, result)
        }
    }
    
    
    func _test_scalars(with data: String) async throws {
        try await _create_test_file_and_run(with: data) {
            let expected = Array(data.unicodeScalars)
            var result = [UnicodeScalar]()
            for try await scalar in try FileHandle(forReadingFrom: $0).bytes.unicodeScalars {
                result.append(scalar)
            }
            XCTAssertEqual(expected, result)
        }
    }
    
    func _test_utf8_bytes(with data: String) async throws {
        var allEqual = true
        try await _create_test_file_and_run(with: data) {
            var expectedIter = data.utf8.makeIterator()
            for try await byte in $0.resourceBytes {
                allEqual = allEqual && byte == expectedIter.next()
            }
        }
        XCTAssertTrue(allEqual)
    }
    
    func _test_piped_data_scalars(_ data: Data) async throws {
        let p = Pipe()
        let resultString = String(decoding: data, as: UTF8.self)
        Task {
            p.fileHandleForWriting.write(data)
            try p.fileHandleForWriting.close()
        }
        var collected = [UnicodeScalar]()
        for try await scalar in p.fileHandleForReading.bytes.unicodeScalars {
            collected.append(scalar)
        }
        XCTAssertEqual(Array(resultString.unicodeScalars), collected)
    }
    
    func test_lines() async throws {
        /*Cases:
         * ASCII
         * empty string
         * multibyte
         * - "\n" (U+000A): LINE FEED (LF)
         * - U+000B: LINE TABULATION (VT)
         * - U+000C: FORM FEED (FF)
         * - "\r" (U+000D): CARRIAGE RETURN (CR)
         * - "\r\n" (U+000D U+000A): CR-LF
         * - U+0085: NEXT LINE (NEL)
         * - U+2028: LINE SEPARATOR
         * - U+2029: PARAGRAPH SEPARATOR
         */
        let data = "ASCII\n\nMültibyte\ra\r\nb\u{0085}c\u{2028}d\u{2029}e\r\r\nf"
        try await _test_lines(with: data)
    }
    
    func _disabled_test_perf() async throws {
        let result = try await URL(fileURLWithPath: "/dev/zero").resourceBytes.measure(1_000_000_000)
        print("With URL wrapper: \(result / 1_000_000) MB/sec")
        let result2 = try await FileHandle(forReadingFrom: URL(fileURLWithPath: "/dev/zero")).bytes.measure(1_000_000_000)
        print("Without URL wrapper: \(result2 / 1_000_000) MB/sec")
//        let result = try await FileHandle(forReadingFrom: URL(fileURLWithPath: "/dev/zero")).bytes.reduce(into: 0, { partialResult, next in
//            partialResult = next
//        })
//        exit(Int32(result))
    }
    
    //For large files we need to read multiple chunks, and lines may end up straddling chunks, this makes sure we handle that correctly
    func test_large_file_lines() async throws {
        var data = ""
        do {
            data = try String(contentsOfFile: "/usr/share/dict/web2", encoding: .utf8)
        } catch {
            //unsupported test on this platform
            return
        }
#if DEBUG
        let count = 1
#else
        let count = 10
#endif
        let combinedString = Array(repeating: data, count: count /*A few more would be nice, but it's too slow in debug builds */).joined()
        let partialResults = data.split(whereSeparator: { $0.isNewline }).map(String.init)
        let results = Array(Array(repeating: partialResults, count: count).joined())
        
        try await _test_lines(
            with: combinedString,
            expectedResults: results
        )
    }
    
    func test_empty_file_lines() async throws {
        try await _test_lines(with: "")
    }
    
    func test_all_newlines() async throws {
        try await _test_lines(with: "\n\n\r\r\nb\u{0085}\u{2028}\u{2029}\r\r\n\u{0085}c")
    }
    
    func test_partial_NEL() async throws {
        try await _test_lines(with: "a\u{0085}c")
    }
    
    func test_trailing_partial_NEL() async throws {
        try await _test_lines(with: "c\u{0085}")
    }
    
    func test_crcrlf() async throws {
        try await _test_lines(with: "\r\r\n")
    }
    
    func test_trailing_lf() async throws {
        try await _test_lines(with: "abc\n")
    }
    
    func test_trailing_cr() async throws {
        try await _test_lines(with: "abc\r")
    }
    
    func test_characters() async throws {
        let data = Array(repeating: "aü😃🏳️‍🌈👩‍👧bcdef👨‍👨‍👧‍👦" /* get a mix of byte counts */, count: 1).joined()
        try await _test_characters(with: data)
    }
    
    func test_empty_file_characters() async throws {
        try await _test_characters(with: "")
    }
    
    func test_scalars() async throws {
        let data = Array(repeating: "aü😃🏳️‍🌈👩‍👧bcdef👨‍👨‍👧‍👦" /* get a mix of byte counts */, count: 1000).joined()
        try await _test_scalars(with: data)
    }
    
    func test_empty_file_scalars() async throws {
        try await _test_scalars(with: "")
    }
    
    func test_extra_trailing_continuation_bytes_scalars() async throws {
        try await _test_piped_data_scalars(Data([0xC3, 0xA9, 0xA9]))
    }
    
    func test_extra_continuation_bytes_scalars() async throws {
        try await _test_piped_data_scalars(Data([0xC3, 0xA9, 0xA9, 0xC3]))
    }
    
    func test_multibyte_after_continuation() async throws {
        let bytes = Array("😃👨‍👨‍👧‍👦".utf8)
        try await _test_piped_data_scalars(Data(bytes))
    }
    
    func test_truncated_multibyte_after_continuation() async throws {
        let bytes = Array("😃👨‍👨‍👧‍👦".utf8.dropLast())
        try await _test_piped_data_scalars(Data(bytes))
    }
        
    func test_utf8_bytes() async throws {
        let data = Array(repeating: "aü😃🏳️‍🌈👩‍👧bcdef👨‍👨‍👧‍👦" /* get a mix of byte counts */, count: 1000).joined()
        try await _test_utf8_bytes(with: data)
    }
    
    func test_empty_file_utf8_bytes() async throws {
        try await _test_utf8_bytes(with: "")
    }
    
    func test_nullDevice() async throws {
        for try await _ in FileHandle.nullDevice.bytes {
            XCTFail("null device reported a byte")
        }
    }
    
    func test_standardOutput_read() async {
        do {
            for try await _ in FileHandle.standardOutput.bytes {
                XCTFail("output file handle reported a byte")
            }
            XCTFail("output file handle finished")
        } catch {
            // pass
        }
    }
    
    func test_invalidFileHandle() async throws {
        do {
            for try await _ in FileHandle(fileDescriptor: -1).bytes {
                XCTFail("invalid file handle reported a byte")
            }
            XCTFail("invalid file handle finished")
        } catch {
            // pass
        }
    }
    
    func test_pipe() async throws {
        let p = Pipe()
        
        Task {
            for _ in 0..<10000 {
                p.fileHandleForWriting.write("hello\(repeatElement(" ", count: Int.random(in: 1..<100)).joined(separator: ""))\n".data(using: .utf8)!)
            }
            try p.fileHandleForWriting.close()
        }
        var collected = [String]()
        for try await line in p.fileHandleForReading.bytes.lines {
            collected.append(line)
        }
        XCTAssertEqual(10000, collected.count)
    }
    
    func test_pipe_unexpected_close() async throws {
        let p = Pipe()
        
        Task {
            p.fileHandleForWriting.write("hello\(repeatElement(" ", count: Int.random(in: 1..<100)).joined(separator: ""))\n".data(using: .utf8)!)
        }
    
        do {
            for try await _ in p.fileHandleForReading.bytes.lines {
                try p.fileHandleForReading.close()
            }
            XCTFail("expected failure due to early close")
        } catch {
            let err = error as NSError
            XCTAssertNotNil(err)
            XCTAssertNil(err.userInfo[NSFilePathErrorKey])
        }
    }
    
    func test_device() async throws {
        let byte = try await FileHandle(forReadingFrom: URL(fileURLWithPath: "/dev/random")).bytes.first { $0 != 0 }
        XCTAssertTrue(byte != 0)
    }
    
    func test_nel_prefix_but_no_suffix() async throws {
        // ¢ shares the same prefix bit mask as NEL
        try await _test_lines(with: String(data: Data([0x48, 0xC2, 0xA2, 0x65, 0xC2, 0xA2, 0x6C, 0xC2, 0xA2, 0x6C, 0xC2, 0xA2, 0x6F]), encoding: .utf8)!)
    }
    
    func test_nel_prefix_and_suffix() async throws {
        // ¢ shares the same prefix bit mask as NEL
        try await _test_lines(with: String(data: Data([0x48, 0xC2, 0x85, 0x65, 0xC2, 0x85, 0x6C, 0xC2, 0x85, 0x6C, 0xC2, 0x85, 0x6F]), encoding: .utf8)!)
    }
    
    
    func test_nel_prefix_end() async {
        let lines = await [UInt8(0x48), UInt8(0xC2)].async.lines.collect()
        XCTAssertEqual(lines, ["H\u{FFFD}"])
    }
    
    func test_seperator_prefix_but_no_suffix() async throws {
        // € shares the same prefix bit mask as _SEPERATOR_PREFIX
        try await _test_lines(with: String(data: Data([0x61, 0xE2, 0x82, 0xAC, 0x62, 0xE2, 0x82, 0xAC, 0x63, 0xE2, 0x82, 0xAC]), encoding: .utf8)!)
    }
    
    func test_seperator_prefix_end() async {
        let lines = await [UInt8(0x48), UInt8(0xE2)].async.lines.collect()
        XCTAssertEqual(lines, ["H\u{FFFD}"])
    }
    
    func test_seperator_prefix_and_continuation_end() async {
        let lines = await [UInt8(0x48), UInt8(0xE2), UInt8(0x80)].async.lines.collect()
        XCTAssertEqual(lines, ["H\u{FFFD}"])
    }
    
    func test_seperator_prefix_and_continuation_without_fin() async {
        let lines = await [UInt8(0x48), UInt8(0xE2), UInt8(0x80), UInt8(0x48)].async.lines.collect()
        XCTAssertEqual(lines, ["H\u{FFFD}H"])
    }
    
    static var allTests : [(String, (TestFileHandleAsync) -> () async throws -> ())] {
        var tests: [(String, (TestFileHandleAsync) -> () async throws -> ())] = [
            ("testLines", test_lines),
            ("testLargeFileLines", test_large_file_lines),
            ("testEmptyFileLines", test_empty_file_lines),
            ("testAllNewlines", test_all_newlines),
            ("testPartialNEL", test_partial_NEL),
            ("testTrailingPartialNEL", test_trailing_partial_NEL),
            ("testTrailingCR", test_trailing_cr),
            ("testTrailingLF", test_trailing_lf),
            ("testCRCRLF", test_crcrlf),
            ("testCharacters", test_characters),
            ("testScalars", test_scalars),
            ("testUTF8Bytes", test_utf8_bytes),
            ("testExtraTrailingContinuationBytesScalars", test_extra_trailing_continuation_bytes_scalars),
            ("testExtraContinuationBytesScalars", test_extra_continuation_bytes_scalars),
            ("testMultiByteAfterContinuation", test_multibyte_after_continuation),
            ("testEmptyFileCharacters", test_empty_file_characters),
            ("testEmptyFileScalars", test_empty_file_scalars),
            ("testEmptyFileUTF8Bytes", test_empty_file_utf8_bytes),
            ("testNullDevice", test_nullDevice),
            ("testPipe", test_pipe),
            ("testPipeUnexpectedClose", test_pipe_unexpected_close),
            ("testDevice", test_device),
            ("testNELPrefixButNoSuffix", test_nel_prefix_but_no_suffix),
            ("testNELPrefixEnd", test_nel_prefix_end),
            ("testNELPrefixAndSuffix", test_nel_prefix_and_suffix),
            ("testSeparatorPrefixAndContinuationEnd", test_seperator_prefix_and_continuation_end),
            ("testSeparatorPrefixButNoSuffix", test_seperator_prefix_but_no_suffix),
            ("testSeparatorPrefixAndContinuationEnd", test_seperator_prefix_and_continuation_end),
            ("testSeparatorPrefixAndContinuationWithoutFin", test_seperator_prefix_and_continuation_without_fin)
        ]
        
        return tests
    }
}
