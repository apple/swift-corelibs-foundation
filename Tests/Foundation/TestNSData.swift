// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016, 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

import XCTest
@testable import Foundation

#if canImport(Android)
import Android
#endif

class TestNSData: XCTestCase {
    
    class AllOnesImmutableData : NSData {
        private var _length : Int
        var _pointer : UnsafeMutableBufferPointer<UInt8>? {
            willSet {
                if let p = _pointer { free(p.baseAddress) }
            }
        }
        
        init(length: Int) {
            _length = length
            super.init()
        }
        
        required init?(coder aDecoder: NSCoder) {
            // Not tested
            fatalError()
        }
        
        deinit {
            if let p = _pointer {
                free(p.baseAddress)
            }
        }
        
        override var length : Int {
            get {
                return _length
            }
        }
        
        override var bytes : UnsafeRawPointer {
            if let d = _pointer {
                return UnsafeRawPointer(d.baseAddress!)
            } else {
                // Need to allocate the buffer now.
                // It doesn't matter if the buffer is uniquely referenced or not here.
                let buffer = malloc(length)
                memset(buffer!, 1, length)
                let bytePtr = buffer!.bindMemory(to: UInt8.self, capacity: length)
                let result = UnsafeMutableBufferPointer(start: bytePtr, count: length)
                _pointer = result
                return UnsafeRawPointer(result.baseAddress!)
            }
        }
        
        override func getBytes(_ buffer: UnsafeMutableRawPointer, length: Int) {
            if let d = _pointer {
                // Get the real data from the buffer
                memmove(buffer, d.baseAddress!, length)
            } else {
                // A more efficient implementation of getBytes in the case where no one has asked for our backing bytes
                memset(buffer, 1, length)
            }
        }
    }
    
    
    class AllOnesData : NSMutableData {
        
        private var _length : Int
        var _pointer : UnsafeMutableBufferPointer<UInt8>? {
            willSet {
                if let p = _pointer { free(p.baseAddress) }
            }
        }
        
        override init(length: Int) {
            _length = length
            super.init()
        }
        
        required init?(coder aDecoder: NSCoder) {
            // Not tested
            fatalError()
        }
        
        deinit {
            if let p = _pointer {
                free(p.baseAddress)
            }
        }
        
        override var length : Int {
            get {
                return _length
            }
            set {
                if let ptr = _pointer {
                    // Copy the data to our new length buffer
                    let newBuffer = malloc(newValue)!
                    if newValue <= _length {
                        memmove(newBuffer, ptr.baseAddress!, newValue)
                    } else if newValue > _length {
                        memmove(newBuffer, ptr.baseAddress!, _length)
                        memset(newBuffer + _length, 1, newValue - _length)
                    }
                    let bytePtr = newBuffer.bindMemory(to: UInt8.self, capacity: newValue)
                    _pointer = UnsafeMutableBufferPointer(start: bytePtr, count: newValue)
                }
                _length = newValue
            }
        }
        
        override var bytes : UnsafeRawPointer {
            if let d = _pointer {
                return UnsafeRawPointer(d.baseAddress!)
            } else {
                // Need to allocate the buffer now.
                // It doesn't matter if the buffer is uniquely referenced or not here.
                let buffer = malloc(length)
                memset(buffer!, 1, length)
                let bytePtr = buffer!.bindMemory(to: UInt8.self, capacity: length)
                let result = UnsafeMutableBufferPointer(start: bytePtr, count: length)
                _pointer = result
                return UnsafeRawPointer(result.baseAddress!)
            }
        }
        
        override var mutableBytes: UnsafeMutableRawPointer {
            let newBufferLength = _length
            let newBuffer = malloc(newBufferLength)
            if let ptr = _pointer {
                // Copy the existing data to the new box, then return its pointer
                memmove(newBuffer!, ptr.baseAddress!, newBufferLength)
            } else {
                // Set new data to 1s
                memset(newBuffer!, 1, newBufferLength)
            }
            let bytePtr = newBuffer!.bindMemory(to: UInt8.self, capacity: newBufferLength)
            let result = UnsafeMutableBufferPointer(start: bytePtr, count: newBufferLength)
            _pointer = result
            _length = newBufferLength
            return UnsafeMutableRawPointer(result.baseAddress!)
        }
        
        override func getBytes(_ buffer: UnsafeMutableRawPointer, length: Int) {
            if let d = _pointer {
                // Get the real data from the buffer
                memmove(buffer, d.baseAddress!, length)
            } else {
                // A more efficient implementation of getBytes in the case where no one has asked for our backing bytes
                memset(buffer, 1, length)
            }
        }
    }
    
    var heldData: Data?
    
    // this holds a reference while applying the function which forces the internal ref type to become non-uniquely referenced
    func holdReference(_ data: Data, apply: () -> Void) {
        heldData = data
        apply()
        heldData = nil
    }
    
    // MARK: -
    
    // String of course has its own way to get data, but this way tests our own data struct
    func dataFrom(_ string : String) -> Data {
        // Create a Data out of those bytes
        return string.utf8CString.withUnsafeBufferPointer { (ptr) in
            ptr.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: ptr.count) {
                // Subtract 1 so we don't get the null terminator byte. This matches NSString behavior.
                return Data(bytes: $0, count: ptr.count - 1)
            }
        }
    }
    
    func test_writeToURLOptions() {
        let saveData = try! Data(contentsOf: Bundle.module.url(forResource: "Test", withExtension: "plist")!)
        let savePath = URL(fileURLWithPath: NSTemporaryDirectory() + "Test1.plist")
        do {
            try saveData.write(to: savePath, options: .atomic)
            let fileManager = FileManager.default
            XCTAssertTrue(fileManager.fileExists(atPath: savePath.path))
            try! fileManager.removeItem(atPath: savePath.path)
        } catch {
            XCTFail()
        }
    }

#if !os(Windows)
    // NOTE: `umask(3)` is process global. Therefore, the behavior is unknown if `withUmask(_:_:)` is used simultaneously.
    private func withUmask(_ mode: mode_t, _ block: () -> Void) {
        let original = umask(mode)
        block()
        umask(original)
    }
#endif

    func test_writeToURLPermissions() {
#if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT && !os(Windows)
        withUmask(0) {
            do {
                let data = Data()
                let url = URL(fileURLWithPath: NSTemporaryDirectory() + "meow")
                try data.write(to: url)
                let fileManager = FileManager.default
                let permission = try fileManager.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
#if canImport(Darwin)
                let expected = Int(S_IRUSR) | Int(S_IWUSR) | Int(S_IRGRP) | Int(S_IWGRP) | Int(S_IROTH) | Int(S_IWOTH)
#elseif canImport(Android)
                let expected = Int(Android.S_IRUSR) | Int(Android.S_IWUSR) | Int(Android.S_IRGRP) | Int(Android.S_IWGRP) | Int(Android.S_IROTH) | Int(Android.S_IWOTH)
#else
                let expected = Int(Glibc.S_IRUSR) | Int(Glibc.S_IWUSR) | Int(Glibc.S_IRGRP) | Int(Glibc.S_IWGRP) | Int(Glibc.S_IROTH) | Int(Glibc.S_IWOTH)
#endif
                XCTAssertEqual(permission, expected)
                try! fileManager.removeItem(atPath: url.path)
            } catch {
                XCTFail()
            }
        }
#endif
    }

    func test_writeToURLPermissionsWithAtomic() {
#if NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT && !os(Windows)
        withUmask(0) {
            do {
                let data = Data()
                let url = URL(fileURLWithPath: NSTemporaryDirectory() + "meow")
                try data.write(to: url, options: .atomic)
                let fileManager = FileManager.default
                let permission = try fileManager.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
#if canImport(Darwin)
                let expected = Int(S_IRUSR) | Int(S_IWUSR) | Int(S_IRGRP) | Int(S_IWGRP) | Int(S_IROTH) | Int(S_IWOTH)
#elseif canImport(Android)
                let expected = Int(Android.S_IRUSR) | Int(Android.S_IWUSR) | Int(Android.S_IRGRP) | Int(Android.S_IWGRP) | Int(Android.S_IROTH) | Int(Android.S_IWOTH)
#else
                let expected = Int(Glibc.S_IRUSR) | Int(Glibc.S_IWUSR) | Int(Glibc.S_IRGRP) | Int(Glibc.S_IWGRP) | Int(Glibc.S_IROTH) | Int(Glibc.S_IWOTH)
#endif
                XCTAssertEqual(permission, expected)
                try! fileManager.removeItem(atPath: url.path)
            } catch {
                XCTFail()
            }
        }
#endif
    }

    func test_writeToURLSpecialFile() {
#if os(Windows)
        let url = URL(fileURLWithPath: "CON")
#else
        let url = URL(fileURLWithPath: "/dev/stdout")
#endif
        XCTAssertNoThrow(try Data("Output to STDOUT\n".utf8).write(to: url))
    }

    func test_emptyDescription() {
        let expected = "<>"
        
        let bytes: [UInt8] = []
        let data = NSData(bytes: bytes, length: bytes.count)
        
        XCTAssertEqual(expected, data.description)
    }
    
    func test_description() {
        let expected =  "<ff4c3e00 55>"
        
        let bytes: [UInt8] = [0xff, 0x4c, 0x3e, 0x00, 0x55]
        let data = NSData(bytes: bytes, length: bytes.count)
        
        XCTAssertEqual(data.description, expected)
    }
    
    func test_longDescription() {
        // taken directly from Foundation
        let expected = "<ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8ff6e 4482d8ff 6e4482d8 ff6e4482 d8ff6e44 82d8>"
        
        let bytes: [UInt8] = [0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, 0xff, 0x6e, 0x44, 0x82, 0xd8, ]
        let data = NSData(bytes: bytes, length: bytes.count)
        
        XCTAssertEqual(expected, data.description)
    }
    
    func test_debugDescription() {
        let expected =  "<ff4c3e00 55>"
        
        let bytes: [UInt8] = [0xff, 0x4c, 0x3e, 0x00, 0x55]
        let data = NSData(bytes: bytes, length: bytes.count)
        
        XCTAssertEqual(data.debugDescription, expected)
    }
    
    func test_limitDebugDescription() {
        let expected = "<ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff>"
        let bytes = [UInt8](repeating: 0xff, count: 1024)
        let data = NSData(bytes: bytes, length: bytes.count)
        XCTAssertEqual(data.debugDescription, expected)
    }
    
    func test_longDebugDescription() {
        let expected = "<ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ... ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff>"
        let bytes = [UInt8](repeating: 0xff, count: 100_000)
        let data = NSData(bytes: bytes, length: bytes.count)
        XCTAssertEqual(data.debugDescription, expected)
    }

    func test_edgeDebugDescription() {
        let expected = "<ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ... ffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ff>"
        let bytes = [UInt8](repeating: 0xff, count: 1025)
        let data = NSData(bytes: bytes, length: bytes.count)
        XCTAssertEqual(data.debugDescription, expected)
    }

    func test_edgeNoCopyDescription() {
        let expected = "<ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ... ffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ff>"
        var bytes = [UInt8](repeating: 0xff, count: 1025)

        bytes.withUnsafeMutableBufferPointer {
            let baseAddress = $0.baseAddress!
            let count = $0.count
            let data = NSData(bytesNoCopy: UnsafeMutableRawPointer(baseAddress), length: count, freeWhenDone: false)
            XCTAssertEqual(data.debugDescription, expected)
            XCTAssertEqual(data.bytes, UnsafeRawPointer(baseAddress))
        }
    }

    func test_initializeWithBase64EncodedDataGetsDecodedData() {
        let plainText = "ARMA virumque cano, Troiae qui primus ab oris\nItaliam, fato profugus, Laviniaque venit"
        let encodedText = "QVJNQSB2aXJ1bXF1ZSBjYW5vLCBUcm9pYWUgcXVpIHByaW11cyBhYiBvcmlzCkl0YWxpYW0sIGZhdG8gcHJvZnVndXMsIExhdmluaWFxdWUgdmVuaXQ="
        guard let encodedData = encodedText.data(using: .utf8) else {
            XCTFail("Could not get UTF-8 data")
            return
        }
        guard let decodedData = Data(base64Encoded: encodedData, options: []) else {
            XCTFail("Could not Base-64 decode data")
            return
        }
        guard let decodedText = String(data: decodedData, encoding: .utf8) else {
            XCTFail("Could not convert decoded data to a UTF-8 String")
            return
        }

        XCTAssertEqual(decodedText, plainText)
        XCTAssertTrue(decodedData == plainText.data(using: .utf8)!)
    }
    
    func test_initializeWithBase64EncodedDataWithNonBase64CharacterIsNil() {
        let encodedText = "QVJNQSB2aXJ1bXF1ZSBjYW5vLCBUcm9pYWUgcXVpIHBya$W11cyBhYiBvcmlzCkl0YWxpYW0sIGZhdG8gcHJvZnVndXMsIExhdmluaWFxdWUgdmVuaXQ="
        guard let encodedData = encodedText.data(using: .utf8) else {
            XCTFail("Could not get UTF-8 data")
            return
        }
        let decodedData = NSData(base64Encoded: encodedData, options: [])
        XCTAssertNil(decodedData)
    }
    
    func test_initializeWithBase64EncodedDataWithNonBase64CharacterWithOptionToAllowItSkipsCharacter() {
        let plainText = "ARMA virumque cano, Troiae qui primus ab oris\nItaliam, fato profugus, Laviniaque venit"
        let encodedText = "QVJNQSB2aXJ1bXF1ZSBjYW5vLCBUcm9pYWUgcXVpIHBya$W11cyBhYiBvcmlzCkl0YWxpYW0sIGZhdG8gcHJvZnVndXMsIExhdmluaWFxdWUgdmVuaXQ="
        guard let encodedData = encodedText.data(using: .utf8) else {
            XCTFail("Could not get UTF-8 data")
            return
        }
        guard let decodedData = Data(base64Encoded: encodedData, options: [.ignoreUnknownCharacters]) else {
            XCTFail("Could not Base-64 decode data")
            return
        }
        guard let decodedText = String(data: decodedData, encoding: .utf8) else {
            XCTFail("Could not convert decoded data to a UTF-8 String")
            return
        }
        
        XCTAssertEqual(decodedText, plainText)
        XCTAssertTrue(decodedData == plainText.data(using: .utf8)!)
    }
    
    func test_initializeWithBase64EncodedStringGetsDecodedData() {
        let plainText = "ARMA virumque cano, Troiae qui primus ab oris\nItaliam, fato profugus, Laviniaque venit"
        let encodedText = "QVJNQSB2aXJ1bXF1ZSBjYW5vLCBUcm9pYWUgcXVpIHByaW11cyBhYiBvcmlzCkl0YWxpYW0sIGZhdG8gcHJvZnVndXMsIExhdmluaWFxdWUgdmVuaXQ="
        guard let decodedData = Data(base64Encoded: encodedText, options: []) else {
            XCTFail("Could not Base-64 decode data")
            return
        }
        guard let decodedText = String(data: decodedData, encoding: .utf8) else {
            XCTFail("Could not convert decoded data to a UTF-8 String")
            return
        }
        
        XCTAssertEqual(decodedText, plainText)
    }
    
    func test_base64EncodedDataGetsEncodedText() {
        let plainText = "Constitit, et lacrimans, `Quis iam locus’ inquit `Achate,\nquae regio in terris nostri non plena laboris?`"
        let encodedText = "Q29uc3RpdGl0LCBldCBsYWNyaW1hbnMsIGBRdWlzIGlhbSBsb2N1c+KAmSBpbnF1aXQgYEFjaGF0ZSwKcXVhZSByZWdpbyBpbiB0ZXJyaXMgbm9zdHJpIG5vbiBwbGVuYSBsYWJvcmlzP2A="
        guard let data = plainText.data(using: .utf8) else {
            XCTFail("Could not encode UTF-8 string")
            return
        }
        let encodedData = data.base64EncodedData()
        guard let encodedTextResult = String(data: encodedData, encoding: .ascii) else {
            XCTFail("Could not convert encoded data to an ASCII String")
            return
        }
        XCTAssertEqual(encodedTextResult, encodedText)
    }
    
    func test_base64EncodedDataWithOptionToInsertLineFeedsContainsLineFeed() {
        let plainText = "Constitit, et lacrimans, `Quis iam locus’ inquit `Achate,\nquae regio in terris nostri non plena laboris?`"
        let encodedText = "Q29uc3RpdGl0LCBldCBsYWNyaW1hbnMsIGBRdWlzIGlhbSBsb2N1c+KAmSBpbnF1\naXQgYEFjaGF0ZSwKcXVhZSByZWdpbyBpbiB0ZXJyaXMgbm9zdHJpIG5vbiBwbGVu\nYSBsYWJvcmlzP2A="
        guard let data = plainText.data(using: .utf8) else {
            XCTFail("Could not encode UTF-8 string")
            return
        }
        let encodedData = data.base64EncodedData(options: [.lineLength64Characters, .endLineWithLineFeed])
        guard let encodedTextResult = String(data: encodedData, encoding: .ascii) else {
            XCTFail("Could not convert encoded data to an ASCII String")
            return
        }
        XCTAssertEqual(encodedTextResult, encodedText)
    }
    
    func test_base64EncodedDataWithOptionToInsertCarriageReturnContainsCarriageReturn() {
        let plainText = "Constitit, et lacrimans, `Quis iam locus’ inquit `Achate,\nquae regio in terris nostri non plena laboris?`"
        let encodedText = "Q29uc3RpdGl0LCBldCBsYWNyaW1hbnMsIGBRdWlzIGlhbSBsb2N1c+KAmSBpbnF1aXQgYEFjaGF0\rZSwKcXVhZSByZWdpbyBpbiB0ZXJyaXMgbm9zdHJpIG5vbiBwbGVuYSBsYWJvcmlzP2A="
        guard let data = plainText.data(using: .utf8) else {
            XCTFail("Could not encode UTF-8 string")
            return
        }
        let encodedData = data.base64EncodedData(options: [.lineLength76Characters, .endLineWithCarriageReturn])
        guard let encodedTextResult = String(data: encodedData, encoding: .ascii) else {
            XCTFail("Could not convert encoded data to an ASCII String")
            return
        }
        XCTAssertEqual(encodedTextResult, encodedText)
    }
    
    func test_base64EncodedDataWithOptionToInsertCarriageReturnAndLineFeedContainsBoth() {
        let plainText = "Revocate animos, maestumque timorem mittite: forsan et haec olim meminisse iuvabit."
        let encodedText = "UmV2b2NhdGUgYW5pbW9zLCBtYWVzdHVtcXVlIHRpbW9yZW0gbWl0dGl0ZTogZm9yc2FuIGV0IGhh\r\nZWMgb2xpbSBtZW1pbmlzc2UgaXV2YWJpdC4="
        guard let data = plainText.data(using: .utf8) else {
            XCTFail("Could not encode UTF-8 string")
            return
        }
        let encodedData = data.base64EncodedData(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])
        guard let encodedTextResult = String(data: encodedData, encoding: .ascii) else {
            XCTFail("Could not convert encoded data to an ASCII String")
            return
        }
        XCTAssertEqual(encodedTextResult, encodedText)
    }
    
    func test_base64EncodeDoesNotAddLineSeparatorsWhenStringFitsInLine() {
        
        XCTAssertEqual(
            Data(repeating: 0, count: 48).base64EncodedString(options: .lineLength64Characters),
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            "each 3 byte is converted into 4 characterss. 48 / 3 * 4 <= 64, therefore result should not have line separator."
        )
        
        XCTAssertEqual(
            Data(repeating: 0, count: 57).base64EncodedString(options: .lineLength76Characters),
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            "each 3 byte is converted into 4 characterss. 57 / 3 * 4 <= 76, therefore result should not have line separator."
        )
    }
    
    func test_base64EncodeAddsLineSeparatorsWhenStringDoesNotFitInLine() {
        
        XCTAssertEqual(
            Data(repeating: 0, count: 49).base64EncodedString(options: .lineLength64Characters),
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAA==",
            "each 3 byte is converted into 4 characterss. 49 / 3 * 4 > 64, therefore result should have lines with separator."
        )
        
        XCTAssertEqual(
            Data(repeating: 0, count: 58).base64EncodedString(options: .lineLength76Characters),
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAA==",
            "each 3 byte is converted into 4 characterss. 58 / 3 * 4 > 76, therefore result should have lines with separator."
        )
    }
    
    func test_base64EncodedStringGetsEncodedText() {
        let plainText = "Revocate animos, maestumque timorem mittite: forsan et haec olim meminisse iuvabit."
        let encodedText = "UmV2b2NhdGUgYW5pbW9zLCBtYWVzdHVtcXVlIHRpbW9yZW0gbWl0dGl0ZTogZm9yc2FuIGV0IGhhZWMgb2xpbSBtZW1pbmlzc2UgaXV2YWJpdC4="
        guard let data = plainText.data(using: .utf8) else {
            XCTFail("Could not encode UTF-8 string")
            return
        }
        let encodedTextResult = data.base64EncodedString()
        XCTAssertEqual(encodedTextResult, encodedText)

    }

    func test_base64EncodeEmptyData() {
        XCTAssertEqual(Data().base64EncodedString(), "")
        XCTAssertEqual(NSData().base64EncodedString(), "")
        XCTAssertEqual(Data().base64EncodedData(), Data())
        XCTAssertEqual(NSData().base64EncodedData(), Data())
    }

    func test_base64DecodeWithPadding1() {
        let encodedPadding1 = "AoR="
        let dataPadding1Bytes : [UInt8] = [0x02,0x84]
        let dataPadding1 = NSData(bytes: dataPadding1Bytes, length: dataPadding1Bytes.count)
        
        
        guard let decodedPadding1 = Data(base64Encoded:encodedPadding1, options: []) else {
            XCTFail("Could not Base-64 decode data")
            return
        }
        XCTAssert(dataPadding1.isEqual(to: decodedPadding1))
    }

    func test_base64DecodeWithPadding2() {
        let encodedPadding2 = "Ao=="
        let dataPadding2Bytes : [UInt8] = [0x02]
        let dataPadding2 = NSData(bytes: dataPadding2Bytes, length: dataPadding2Bytes.count)
        
        
        guard let decodedPadding2 = Data(base64Encoded:encodedPadding2, options: []) else {
            XCTFail("Could not Base-64 decode data")
            return
        }
        XCTAssert(dataPadding2.isEqual(to: decodedPadding2))
    }

    func test_rangeOfData() {
        let baseData : [UInt8] = [0x00,0x01,0x02,0x03,0x04]
        let base = NSData(bytes: baseData, length: baseData.count)
        let baseFullRange = NSRange(location : 0,length : baseData.count)
        let noPrefixRange = NSRange(location : 2,length : baseData.count-2)
        let noSuffixRange = NSRange(location : 0,length : baseData.count-2)
        let notFoundRange = NSRange(location: NSNotFound, length: 0)
        
        
        let prefixData : [UInt8] = [0x00,0x01]
        let prefix = Data(bytes: prefixData, count: prefixData.count)
        let prefixRange = NSRange(location: 0, length: prefixData.count)
        
        XCTAssert(NSEqualRanges(base.range(of: prefix, options: [], in: baseFullRange),prefixRange))
        XCTAssert(NSEqualRanges(base.range(of: prefix, options: [.anchored], in: baseFullRange),prefixRange))
        XCTAssert(NSEqualRanges(base.range(of: prefix, options: [.backwards], in: baseFullRange),prefixRange))
        XCTAssert(NSEqualRanges(base.range(of: prefix, options: [.backwards,.anchored], in: baseFullRange),notFoundRange))
        
        XCTAssert(NSEqualRanges(base.range(of: prefix, options: [], in: noPrefixRange),notFoundRange))
        XCTAssert(NSEqualRanges(base.range(of: prefix, options: [.backwards], in: noPrefixRange),notFoundRange))
        XCTAssert(NSEqualRanges(base.range(of: prefix, options: [], in: noSuffixRange),prefixRange))
        XCTAssert(NSEqualRanges(base.range(of: prefix, options: [.backwards], in: noSuffixRange),prefixRange))
        
        
        let suffixData : [UInt8] = [0x03,0x04]
        let suffix = Data(bytes: suffixData, count: suffixData.count)
        let suffixRange = NSRange(location: 3, length: suffixData.count)
        
        XCTAssert(NSEqualRanges(base.range(of: suffix, options: [], in: baseFullRange),suffixRange))
        XCTAssert(NSEqualRanges(base.range(of: suffix, options: [.anchored], in: baseFullRange),notFoundRange))
        XCTAssert(NSEqualRanges(base.range(of: suffix, options: [.backwards], in: baseFullRange),suffixRange))
        XCTAssert(NSEqualRanges(base.range(of: suffix, options: [.backwards,.anchored], in: baseFullRange),suffixRange))
        
        XCTAssert(NSEqualRanges(base.range(of: suffix, options: [], in: noPrefixRange),suffixRange))
        XCTAssert(NSEqualRanges(base.range(of: suffix, options: [.backwards], in: noPrefixRange),suffixRange))
        XCTAssert(NSEqualRanges(base.range(of: suffix, options: [], in: noSuffixRange),notFoundRange))
        XCTAssert(NSEqualRanges(base.range(of: suffix, options: [.backwards], in: noSuffixRange),notFoundRange))
        
        
        let sliceData : [UInt8] = [0x02,0x03]
        let slice = Data(bytes: sliceData, count: sliceData.count)
        let sliceRange = NSRange(location: 2, length: sliceData.count)
        
        XCTAssert(NSEqualRanges(base.range(of: slice, options: [], in: baseFullRange),sliceRange))
        XCTAssert(NSEqualRanges(base.range(of: slice, options: [.anchored], in: baseFullRange),notFoundRange))
        XCTAssert(NSEqualRanges(base.range(of: slice, options: [.backwards], in: baseFullRange),sliceRange))
        XCTAssert(NSEqualRanges(base.range(of: slice, options: [.backwards,.anchored], in: baseFullRange),notFoundRange))
        
        let empty = Data()
        XCTAssert(NSEqualRanges(base.range(of: empty, options: [], in: baseFullRange),notFoundRange))
        XCTAssert(NSEqualRanges(base.range(of: empty, options: [.anchored], in: baseFullRange),notFoundRange))
        XCTAssert(NSEqualRanges(base.range(of: empty, options: [.backwards], in: baseFullRange),notFoundRange))
        XCTAssert(NSEqualRanges(base.range(of: empty, options: [.backwards,.anchored], in: baseFullRange),notFoundRange))
        
    }

    func test_sr10689_rangeOfDataProtocol() {
        // https://bugs.swift.org/browse/SR-10689
        
        let base = Data([0x00, 0x01, 0x02, 0x03, 0x00, 0x01, 0x02, 0x03,
                         0x00, 0x01, 0x02, 0x03, 0x00, 0x01, 0x02, 0x03])
        let subdata = base[10..<13] // [0x02, 0x03, 0x00]
        let oneByte = base[14..<15] // [0x02]
        
        do { // firstRange(of:in:)
            func assertFirstRange(_ data: Data, _ fragment: Data, range: ClosedRange<Int>? = nil, expectedStartIndex: Int?,
                                  message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line)
            {
                if let index = expectedStartIndex {
                    let expectedRange: Range<Int> = index..<(index + fragment.count)
                    if let someRange = range {
                        XCTAssertEqual(data.firstRange(of: fragment, in: someRange), expectedRange, message(), file: file, line: line)
                    } else {
                        XCTAssertEqual(data.firstRange(of: fragment), expectedRange, message(), file: file, line: line)
                    }
                } else {
                    if let someRange = range {
                        XCTAssertNil(data.firstRange(of: fragment, in: someRange), message(), file: file, line: line)
                    } else {
                        XCTAssertNil(data.firstRange(of: fragment), message(), file: file, line: line)
                    }
                }
            }
            
            assertFirstRange(base, base, expectedStartIndex: base.startIndex)
            assertFirstRange(base, subdata, expectedStartIndex: 2)
            assertFirstRange(base, oneByte, expectedStartIndex: 2)
            
            assertFirstRange(subdata, base, expectedStartIndex: nil)
            assertFirstRange(subdata, subdata, expectedStartIndex: subdata.startIndex)
            assertFirstRange(subdata, oneByte, expectedStartIndex: subdata.startIndex)
            
            assertFirstRange(oneByte, base, expectedStartIndex: nil)
            assertFirstRange(oneByte, subdata, expectedStartIndex: nil)
            assertFirstRange(oneByte, oneByte, expectedStartIndex: oneByte.startIndex)
            
            assertFirstRange(base, subdata, range: 1...14, expectedStartIndex: 2)
            assertFirstRange(base, subdata, range: 6...8, expectedStartIndex: 6)
            assertFirstRange(base, subdata, range: 8...10, expectedStartIndex: nil)
            
            assertFirstRange(base, oneByte, range: 1...14, expectedStartIndex: 2)
            assertFirstRange(base, oneByte, range: 6...6, expectedStartIndex: 6)
            assertFirstRange(base, oneByte, range: 8...9, expectedStartIndex: nil)
        }
        
        do { // lastRange(of:in:)
            func assertLastRange(_ data: Data, _ fragment: Data, range: ClosedRange<Int>? = nil, expectedStartIndex: Int?,
                                 message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line)
            {
                if let index = expectedStartIndex {
                    let expectedRange: Range<Int> = index..<(index + fragment.count)
                    if let someRange = range {
                        XCTAssertEqual(data.lastRange(of: fragment, in: someRange), expectedRange, message(), file: file, line: line)
                    } else {
                        XCTAssertEqual(data.lastRange(of: fragment), expectedRange, message(), file: file, line: line)
                    }
                } else {
                    if let someRange = range {
                        XCTAssertNil(data.lastRange(of: fragment, in: someRange), message(), file: file, line: line)
                    } else {
                        XCTAssertNil(data.lastRange(of: fragment), message(), file: file, line: line)
                    }
                }
            }
            
            assertLastRange(base, base, expectedStartIndex: base.startIndex)
            assertLastRange(base, subdata, expectedStartIndex: 10)
            assertLastRange(base, oneByte, expectedStartIndex: 14)
            
            assertLastRange(subdata, base, expectedStartIndex: nil)
            assertLastRange(subdata, subdata, expectedStartIndex: subdata.startIndex)
            assertLastRange(subdata, oneByte, expectedStartIndex: subdata.startIndex)
            
            assertLastRange(oneByte, base, expectedStartIndex: nil)
            assertLastRange(oneByte, subdata, expectedStartIndex: nil)
            assertLastRange(oneByte, oneByte, expectedStartIndex: oneByte.startIndex)
            
            assertLastRange(base, subdata, range: 1...14, expectedStartIndex: 10)
            assertLastRange(base, subdata, range: 6...8, expectedStartIndex: 6)
            assertLastRange(base, subdata, range: 8...10, expectedStartIndex: nil)
            
            assertLastRange(base, oneByte, range: 1...14, expectedStartIndex: 14)
            assertLastRange(base, oneByte, range: 6...6, expectedStartIndex: 6)
            assertLastRange(base, oneByte, range: 8...9, expectedStartIndex: nil)
        }
    }

    // Check all of the NSMutableData constructors are available.
    func test_initNSMutableData() {
        let mData = NSMutableData()
        XCTAssertEqual(mData.length, 0)
    }

    func test_initNSMutableDataWithLength() {
        let mData = NSMutableData(length: 30)
        XCTAssertNotNil(mData)
        XCTAssertEqual(mData!.length, 30)
    }

    func test_initNSMutableDataWithCapacity() {
        let mData = NSMutableData(capacity: 30)
        XCTAssertNotNil(mData)
        XCTAssertEqual(mData!.length, 0)
    }

    func test_initNSMutableDataFromData() {
        let data = Data([1, 2, 3])
        let mData = NSMutableData(data: data)
        XCTAssertEqual(mData.length, 3)
        XCTAssertEqual(NSData(data: data), mData)
    }

    func test_initNSMutableDataFromBytes() {
        let data = Data([1, 2, 3, 4, 5, 6])
        var testBytes: [UInt8] = [1, 2, 3, 4, 5, 6]

        let md1 = NSMutableData(bytes: &testBytes, length: testBytes.count)
        XCTAssertEqual(md1, NSData(data: data))

        let md2 = NSMutableData(bytes: nil, length: 0)
        XCTAssertEqual(md2.length, 0)

        let testBuffer = malloc(testBytes.count)!
        let md3 = NSMutableData(bytesNoCopy: testBuffer, length: testBytes.count)
        md3.replaceBytes(in: NSRange(location: 0, length: testBytes.count), withBytes: &testBytes)
        XCTAssertEqual(md3, NSData(data: data))

        let md4 = NSMutableData(bytesNoCopy: &testBytes, length: testBytes.count, deallocator: nil)
        XCTAssertEqual(md4.length, testBytes.count)

        let md5 = NSMutableData(bytesNoCopy: &testBytes, length: testBytes.count, freeWhenDone: false)
        XCTAssertEqual(md5, NSData(data: data))
    }

    func test_initNSMutableDataContentsOf() {
        let testDir = Bundle.module.resourcePath
        let filename = testDir!.appending("/NSStringTestData.txt")
        let url = URL(fileURLWithPath: filename)

        func testText(_ mData: NSMutableData?) {
            guard let mData = mData else {
                XCTFail("Contents of file are Nil")
                return
            }
            if let txt = String(data: Data(referencing: mData), encoding: .ascii) {
                XCTAssertEqual(txt, "swift-corelibs-foundation")
            } else {
                XCTFail("Cant convert to string")
            }
        }

        let contents1 = NSMutableData(contentsOfFile: filename)
        XCTAssertNotNil(contents1)
        testText(contents1)

        let contents2 = try? NSMutableData(contentsOfFile: filename, options: [])
        XCTAssertNotNil(contents2)
        testText(contents2)

        let contents3 = NSMutableData(contentsOf: url)
        XCTAssertNotNil(contents3)
        testText(contents3)

        let contents4 = try? NSMutableData(contentsOf: url, options: [])
        XCTAssertNotNil(contents4)
        testText(contents4)

        // Test failure to read
        let badFilename = "does not exist"
        let badUrl = URL(fileURLWithPath: badFilename)

        XCTAssertNil(NSMutableData(contentsOfFile: badFilename))
        XCTAssertNil(try? NSMutableData(contentsOfFile: badFilename, options: []))
        XCTAssertNil(NSMutableData(contentsOf: badUrl))
        XCTAssertNil(try? NSMutableData(contentsOf: badUrl, options:  []))
    }

    func test_initNSMutableDataBase64() {
        let srcData = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
        let base64Data = srcData.base64EncodedData()
        let base64String = srcData.base64EncodedString()
        XCTAssertEqual(base64String, "AQIDBAUGBwgJAA==")

        let mData1 = NSMutableData(base64Encoded: base64Data)
        XCTAssertNotNil(mData1)
        XCTAssertEqual(mData1!, NSData(data: srcData))

        let mData2 = NSMutableData(base64Encoded: base64String)
        XCTAssertNotNil(mData2)
        XCTAssertEqual(mData2!, NSData(data: srcData))

        // Test bad input
        XCTAssertNil(NSMutableData(base64Encoded: Data([1,2,3]), options: []))
        XCTAssertNil(NSMutableData(base64Encoded: "x", options: []))
    }

    func test_replaceBytes() {
        var data = Data([0, 0, 0, 0, 0])
        let newData = Data([1, 2, 3, 4, 5])

        // test replaceSubrange(_, with:)
        XCTAssertFalse(data == newData)
        data.replaceSubrange(data.startIndex..<data.endIndex, with: newData)
        XCTAssertTrue(data == newData)

        // subscript(index:) uses replaceBytes so use it to test edge conditions
        data[0] = 0
        data[4] = 0
        XCTAssertTrue(data == Data([0, 2, 3, 4, 0]))

        // test NSMutableData.replaceBytes(in:withBytes:length:) directly
        func makeData(_ data: [UInt8]) -> NSData {
            return NSData(bytes: data, length: data.count)
        }

        guard let mData = NSMutableData(length: 5) else {
            XCTFail("Cant create NSMutableData")
            return
        }

        let replacement = makeData([8, 9, 10])
        withExtendedLifetime(replacement) {
            mData.replaceBytes(in: NSRange(location: 1, length: 3), withBytes: replacement.bytes,
            length: 3)
        }
        let expected = makeData([0, 8, 9, 10, 0])
        XCTAssertEqual(mData, expected)
    }

    func test_replaceBytesWithNil() {
        func makeData(_ data: [UInt8]) -> NSMutableData {
            return NSMutableData(bytes: data, length: data.count)
        }

        let mData = makeData([1, 2, 3, 4, 5])
        mData.replaceBytes(in: NSRange(location: 1, length: 3), withBytes: nil, length: 0)
        let expected = makeData([1, 5])
        XCTAssertEqual(mData, expected)
    }

    func test_initDataWithCapacity() {
        let data = Data(capacity: 123)
        XCTAssertEqual(data.count, 0)
    }

    func test_initDataWithCount() {
        let dataSize = 1024
        let data = Data(count: dataSize)
        XCTAssertEqual(data.count, dataSize)
        if let index = (data.firstIndex { $0 != 0 }) {
            XCTFail("Byte at index: \(index) is not zero: \(data[index])")
            return
        }
    }

    func test_emptyStringToData() {
        let data = "".data(using: .utf8)!
        XCTAssertEqual(0, data.count, "data from empty string is empty")
    }
}

// Tests from Swift SDK Overlay
extension TestNSData {
    func testBasicConstruction() throws {
        
        // Make sure that we were able to create some data
        let hello = dataFrom("hello")
        let helloLength = hello.count
        XCTAssertEqual(hello[0], 0x68, "Unexpected first byte")
        
        let world = dataFrom(" world")
        var helloWorld = hello
        world.withUnsafeBytes {
            helloWorld.append($0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: world.count)
        }
        
        XCTAssertEqual(hello[0], 0x68, "First byte should not have changed")
        XCTAssertEqual(hello.count, helloLength, "Length of first data should not have changed")
        XCTAssertEqual(helloWorld.count, hello.count + world.count, "The total length should include both buffers")
    }
    
    func testInitializationWithArray() {
        let data = Data([1, 2, 3])
        XCTAssertEqual(3, data.count)
        
        let data2 = Data([1, 2, 3].filter { $0 >= 2 })
        XCTAssertEqual(2, data2.count)
        
        let data3 = Data([1, 2, 3, 4, 5][1..<3])
        XCTAssertEqual(2, data3.count)
    }
    
    func testMutableData() {
        let hello = dataFrom("hello")
        let helloLength = hello.count
        XCTAssertEqual(hello[0], 0x68, "Unexpected first byte")
        
        // Double the length
        var mutatingHello = hello
        mutatingHello.count *= 2
        
        XCTAssertEqual(hello.count, helloLength, "The length of the initial data should not have changed")
        XCTAssertEqual(mutatingHello.count, helloLength * 2, "The length should have changed")
        
        // Get the underlying data for hello2
        mutatingHello.withUnsafeMutableBytes { (bytes : UnsafeMutableRawBufferPointer) in
            XCTAssertEqual(bytes[0], 0x68, "First byte should be 0x68")
            
            // Mutate it
            bytes[0] = 0x67
            XCTAssertEqual(bytes[0], 0x67, "First byte should be 0x67")
        }
        XCTAssertEqual(mutatingHello[0], 0x67, "First byte accessed via other method should still be 0x67")

        // Verify that the first data is still correct
        XCTAssertEqual(hello[0], 0x68, "The first byte should still be 0x68")
    }
    

    
    func testBridgingDefault() {
        let hello = dataFrom("hello")
        // Convert from struct Data to NSData
        if let s = NSString(data: hello, encoding: String.Encoding.utf8.rawValue) {
            XCTAssertTrue(s.isEqual(to: "hello"), "The strings should be equal")
        }
        
        // Convert from NSData to struct Data
        let goodbye = dataFrom("goodbye")
        if let resultingData = NSString(string: "goodbye").data(using: String.Encoding.utf8.rawValue) {
            XCTAssertEqual(resultingData[0], goodbye[0], "First byte should be equal")
        }
    }
    
    func testBridgingMutable() {
        // Create a mutable data
        var helloWorld = dataFrom("hello")
        helloWorld.append(dataFrom("world"))
        
        // Convert from struct Data to NSData
        if let s = NSString(data: helloWorld, encoding: String.Encoding.utf8.rawValue) {
            XCTAssertTrue(s.isEqual(to: "helloworld"), "The strings should be equal")
        }
        
    }
    
  
    func testEquality() {
        let d1 = dataFrom("hello")
        let d2 = dataFrom("hello")
        
        // Use == explicitly here to make sure we're calling the right methods
        XCTAssertTrue(d1 == d2, "Data should be equal")
    }
    
    func testDataInSet() {
        let d1 = dataFrom("Hello")
        let d2 = dataFrom("Hello")
        let d3 = dataFrom("World")
        
        var s = Set<Data>()
        s.insert(d1)
        s.insert(d2)
        s.insert(d3)
        
        XCTAssertEqual(s.count, 2, "Expected only two entries in the Set")
    }
    
    func testFirstRangeEmptyData() {
        let d = Data([1, 2, 3])
        XCTAssertNil(d.firstRange(of: Data()))
    }
    
    func testLastRangeEmptyData() {
        let d = Data([1, 2, 3])
        XCTAssertNil(d.lastRange(of: Data()))
    }
    
    func testReplaceSubrange() {
        var hello = dataFrom("Hello")
        let world = dataFrom("World")
        
        hello[0] = world[0]
        XCTAssertEqual(hello[0], world[0])
        
        var goodbyeWorld = dataFrom("Hello World")
        let goodbye = dataFrom("Goodbye")
        let expected = dataFrom("Goodbye World")
        
        goodbyeWorld.replaceSubrange(0..<5, with: goodbye)
        XCTAssertEqual(goodbyeWorld, expected)
    }
    
    func testReplaceSubrange2() {
        let hello = dataFrom("Hello")
        let world = dataFrom(" World")
        let goodbye = dataFrom("Goodbye")
        let expected = dataFrom("Goodbye World")
        
        var mutateMe = hello
        mutateMe.append(world)
        
        if let found = mutateMe.range(of: hello) {
            mutateMe.replaceSubrange(found, with: goodbye)
        }
        XCTAssertEqual(mutateMe, expected)
    }
    
    func testReplaceSubrange3() {
        // The expected result
        let expectedBytes : [UInt8] = [1, 2, 9, 10, 11, 12, 13]
        let expected = expectedBytes.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }
        
        // The data we'll mutate
        let someBytes : [UInt8] = [1, 2, 3, 4, 5]
        var a = someBytes.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }
        
        // The bytes we'll insert
        let b : [UInt8] = [9, 10, 11, 12, 13]
        b.withUnsafeBufferPointer {
            a.replaceSubrange(2..<5, with: $0)
        }
        XCTAssertEqual(expected, a)
    }
    
    func testReplaceSubrange4() {
        let expectedBytes : [UInt8] = [1, 2, 9, 10, 11, 12, 13]
        let expected = Data(expectedBytes)
        
        // The data we'll mutate
        let someBytes : [UInt8] = [1, 2, 3, 4, 5]
        var a = Data(someBytes)
        
        // The bytes we'll insert
        let b : [UInt8] = [9, 10, 11, 12, 13]
        a.replaceSubrange(2..<5, with: b)
        XCTAssertEqual(expected, a)
    }
    
    func testReplaceSubrange5() {
        var d = Data([1, 2, 3])
        d.replaceSubrange(0..<0, with: [4])
        XCTAssertEqual(Data([4, 1, 2, 3]), d)
        
        d.replaceSubrange(0..<4, with: [9])
        XCTAssertEqual(Data([9]), d)
        
        d.replaceSubrange(0..<d.count, with: [])
        XCTAssertEqual(Data(), d)
        
        d.replaceSubrange(0..<0, with: [1, 2, 3, 4])
        XCTAssertEqual(Data([1, 2, 3, 4]), d)
        
        d.replaceSubrange(1..<3, with: [9, 8])
        XCTAssertEqual(Data([1, 9, 8, 4]), d)
        
        d.replaceSubrange(d.count..<d.count, with: [5])
        XCTAssertEqual(Data([1, 9, 8, 4, 5]), d)
    }
    
    func testRange() {
        let helloWorld = dataFrom("Hello World")
        let goodbye = dataFrom("Goodbye")
        let hello = dataFrom("Hello")
        
        do {
            let found = helloWorld.range(of: goodbye)
            XCTAssertTrue(found == nil || found!.isEmpty)
        }
        
        do {
            let found = helloWorld.range(of: goodbye, options: .anchored)
            XCTAssertTrue(found == nil || found!.isEmpty)
        }
        
        do {
            let found = helloWorld.range(of: hello, in: 7..<helloWorld.count)
            XCTAssertTrue(found == nil || found!.isEmpty)
        }
    }
    
    func testInsertData() {
        let hello = dataFrom("Hello")
        let world = dataFrom(" World")
        let expected = dataFrom("Hello World")
        var helloWorld = dataFrom("")
        
        helloWorld.replaceSubrange(0..<0, with: world)
        helloWorld.replaceSubrange(0..<0, with: hello)
        
        XCTAssertEqual(helloWorld, expected)
    }
    
    func testLoops() {
        let hello = dataFrom("Hello")
        var count = 0
        for _ in hello {
            count += 1
        }
        XCTAssertEqual(count, 5)
    }
    
    func testGenericAlgorithms() {
        let hello = dataFrom("Hello World")
        
        let isCapital = { (byte : UInt8) in byte >= 65 && byte <= 90 }
        
        let allCaps = hello.filter(isCapital)
        XCTAssertEqual(allCaps.count, 2)
        
        let capCount = hello.reduce(0) { isCapital($1) ? $0 + 1 : $0 }
        XCTAssertEqual(capCount, 2)
        
        let allLower = hello.map { isCapital($0) ? $0 + 31 : $0 }
        XCTAssertEqual(allLower.count, hello.count)
    }
    
    func testCustomDeallocator() {
        var deallocatorCalled = false
        
        // Scope the data to a block to control lifecycle
        do {
            let buffer = malloc(16)!
            let bytePtr = buffer.bindMemory(to: UInt8.self, capacity: 16)
            var data = Data(bytesNoCopy: bytePtr, count: 16, deallocator: .custom({ (ptr, size) in
                deallocatorCalled = true
                free(UnsafeMutableRawPointer(ptr))
            }))
            // Use the data
            data[0] = 1
        }
        
        XCTAssertTrue(deallocatorCalled, "Custom deallocator was never called")
    }
    
    func testCopyBytes() {
        let c = 10
        let underlyingBuffer = malloc(c * MemoryLayout<UInt16>.stride)!
        let u16Ptr = underlyingBuffer.bindMemory(to: UInt16.self, capacity: c)
        let buffer = UnsafeMutableBufferPointer<UInt16>(start: u16Ptr, count: c)
        
        buffer[0] = 0
        buffer[1] = 0
        
        var data = Data(capacity: c * MemoryLayout<UInt16>.stride)
        data.resetBytes(in: 0..<c * MemoryLayout<UInt16>.stride)
        data[0] = 0xFF
        data[1] = 0xFF
        let copiedCount = data.copyBytes(to: buffer)
        XCTAssertEqual(copiedCount, c * MemoryLayout<UInt16>.stride)
        
        XCTAssertEqual(buffer[0], 0xFFFF)
        free(underlyingBuffer)
    }
    
    func testCopyBytes_undersized() {
        let a : [UInt8] = [1, 2, 3, 4, 5]
        let data = a.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }
        let expectedSize = MemoryLayout<UInt8>.stride * a.count
        XCTAssertEqual(expectedSize, data.count)
        
        let size = expectedSize - 1
        let underlyingBuffer = malloc(size)!
        let buffer = UnsafeMutableBufferPointer(start: underlyingBuffer.bindMemory(to: UInt8.self, capacity: size), count: size)
        
        // We should only copy in enough bytes that can fit in the buffer
        let copiedCount = data.copyBytes(to: buffer)
        XCTAssertEqual(expectedSize - 1, copiedCount)
        
        var index = 0
        for v in a[0..<expectedSize-1] {
            XCTAssertEqual(v, buffer[index])
            index += 1
        }
        
        free(underlyingBuffer)
    }
    
    func testCopyBytes_oversized() {
        let a : [Int32] = [1, 0, 1, 0, 1]
        let data = a.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }
        let expectedSize = MemoryLayout<Int32>.stride * a.count
        XCTAssertEqual(expectedSize, data.count)

        let size = expectedSize + 1
        let underlyingBuffer = malloc(size)!
        let buffer = UnsafeMutableBufferPointer(start: underlyingBuffer.bindMemory(to: UInt8.self, capacity: size), count: size)
        
        let copiedCount = data.copyBytes(to: buffer)
        XCTAssertEqual(expectedSize, copiedCount)
        
        free(underlyingBuffer)
    }
    
    func testCopyBytes_ranges() {
        
        do {
            // Equal sized buffer, data
            let a : [UInt8] = [1, 2, 3, 4, 5]
            let data = a.withUnsafeBufferPointer {
                return Data(buffer: $0)
            }

            let size = data.count
            let underlyingBuffer = malloc(size)!
            let buffer = UnsafeMutableBufferPointer(start: underlyingBuffer.bindMemory(to: UInt8.self, capacity: size), count: size)
            
            var copiedCount : Int
            
            copiedCount = data.copyBytes(to: buffer, from: 0..<0)
            XCTAssertEqual(0, copiedCount)
            
            copiedCount = data.copyBytes(to: buffer, from: 1..<1)
            XCTAssertEqual(0, copiedCount)
            
            copiedCount = data.copyBytes(to: buffer, from: 0..<3)
            XCTAssertEqual((0..<3).count, copiedCount)
            
            var index = 0
            for v in a[0..<3] {
                XCTAssertEqual(v, buffer[index])
                index += 1
            }
            free(underlyingBuffer)
        }
        
        do {
            // Larger buffer than data
            let a : [UInt8] = [1, 2, 3, 4]
            let data = a.withUnsafeBufferPointer {
                return Data(buffer: $0)
            }

            let size = 10
            let underlyingBuffer = malloc(size)!
            let buffer = UnsafeMutableBufferPointer(start: underlyingBuffer.bindMemory(to: UInt8.self, capacity: size), count: size)

            var copiedCount : Int
            
            copiedCount = data.copyBytes(to: buffer, from: 0..<3)
            XCTAssertEqual((0..<3).count, copiedCount)
            
            var index = 0
            for v in a[0..<3] {
                XCTAssertEqual(v, buffer[index])
                index += 1
            }
            free(underlyingBuffer)
        }
        
        do {
            // Larger data than buffer
            let a : [UInt8] = [1, 2, 3, 4, 5, 6]
            let data = a.withUnsafeBufferPointer {
                return Data(buffer: $0)
            }

            let size = 4
            let underlyingBuffer = malloc(size)!
            let buffer = UnsafeMutableBufferPointer(start: underlyingBuffer.bindMemory(to: UInt8.self, capacity: size), count: size)
            
            var copiedCount : Int
            
            copiedCount = data.copyBytes(to: buffer, from: 0..<data.index(before: data.endIndex))
            XCTAssertEqual(4, copiedCount)
            
            var index = 0
            for v in a[0..<4] {
                XCTAssertEqual(v, buffer[index])
                index += 1
            }
            free(underlyingBuffer)
            
        }
    }
    
    func test_base64Data_small() {
        let data = "Hello World".data(using: .utf8)!
        let base64 = data.base64EncodedString()
        XCTAssertEqual("SGVsbG8gV29ybGQ=", base64, "trivial base64 encoding should work")
    }
    
    func test_base64DataDecode_small() {
        let dataEncoded = "SGVsbG8sIG5ldyBXb3JsZA==".data(using: .utf8)!
        let dataDecoded = NSData(base64Encoded: dataEncoded)!
        let string = Data(referencing: dataDecoded).withUnsafeBytes { buffer in
            return String(bytes: buffer, encoding: .utf8)
        }
        XCTAssertEqual("Hello, new World", string, "trivial base64 decoding should work")
    }

    func test_dataHash() {
        XCTAssertEqual(NSData().hash, 0)
        XCTAssertEqual(NSMutableData().hash, 0)

        let data = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        let d1 = NSData(data: data)
        let md1 = NSMutableData(data: data)
        XCTAssertEqual(d1.hash, 72772266)
        XCTAssertEqual(md1.hash, 72772266)
   }
    
    func test_base64Data_medium() {
        let data = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut at tincidunt arcu. Suspendisse nec sodales erat, sit amet imperdiet ipsum. Etiam sed ornare felis. Nunc mauris turpis, bibendum non lectus quis, malesuada placerat turpis. Nam adipiscing non massa et semper. Nulla convallis semper bibendum. Aliquam dictum nulla cursus mi ultricies, at tincidunt mi sagittis. Nulla faucibus at dui quis sodales. Morbi rutrum, dui id ultrices venenatis, arcu urna egestas felis, vel suscipit mauris arcu quis risus. Nunc venenatis ligula at orci tristique, et mattis purus pulvinar. Etiam ultricies est odio. Nunc eleifend malesuada justo, nec euismod sem ultrices quis. Etiam nec nibh sit amet lorem faucibus dapibus quis nec leo. Praesent sit amet mauris vel lacus hendrerit porta mollis consectetur mi. Donec eget tortor dui. Morbi imperdiet, arcu sit amet elementum interdum, quam nisl tempor quam, vitae feugiat augue purus sed lacus. In ac urna adipiscing purus venenatis volutpat vel et metus. Nullam nec auctor quam. Phasellus porttitor felis ac nibh gravida suscipit tempus at ante. Nunc pellentesque iaculis sapien a mattis. Aenean eleifend dolor non nunc laoreet, non dictum massa aliquam. Aenean quis turpis augue. Praesent augue lectus, mollis nec elementum eu, dignissim at velit. Ut congue neque id ullamcorper pellentesque. Maecenas euismod in elit eu vehicula. Nullam tristique dui nulla, nec convallis metus suscipit eget. Cras semper augue nec cursus blandit. Nulla rhoncus et odio quis blandit. Praesent lobortis dignissim velit ut pulvinar. Duis interdum quam adipiscing dolor semper semper. Nunc bibendum convallis dui, eget mollis magna hendrerit et. Morbi facilisis, augue eu fringilla convallis, mauris est cursus dolor, eu posuere odio nunc quis orci. Ut eu justo sem. Phasellus ut erat rhoncus, faucibus arcu vitae, vulputate erat. Aliquam nec magna viverra, interdum est vitae, rhoncus sapien. Duis tincidunt tempor ipsum ut dapibus. Nullam commodo varius metus, sed sollicitudin eros. Etiam nec odio et dui tempor blandit posuere.".data(using: .utf8)!
        let base64 = data.base64EncodedString()
        XCTAssertEqual("TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZWxpdC4gVXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBzb2RhbGVzIGVyYXQsIHNpdCBhbWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2VkIG9ybmFyZSBmZWxpcy4gTnVuYyBtYXVyaXMgdHVycGlzLCBiaWJlbmR1bSBub24gbGVjdHVzIHF1aXMsIG1hbGVzdWFkYSBwbGFjZXJhdCB0dXJwaXMuIE5hbSBhZGlwaXNjaW5nIG5vbiBtYXNzYSBldCBzZW1wZXIuIE51bGxhIGNvbnZhbGxpcyBzZW1wZXIgYmliZW5kdW0uIEFsaXF1YW0gZGljdHVtIG51bGxhIGN1cnN1cyBtaSB1bHRyaWNpZXMsIGF0IHRpbmNpZHVudCBtaSBzYWdpdHRpcy4gTnVsbGEgZmF1Y2lidXMgYXQgZHVpIHF1aXMgc29kYWxlcy4gTW9yYmkgcnV0cnVtLCBkdWkgaWQgdWx0cmljZXMgdmVuZW5hdGlzLCBhcmN1IHVybmEgZWdlc3RhcyBmZWxpcywgdmVsIHN1c2NpcGl0IG1hdXJpcyBhcmN1IHF1aXMgcmlzdXMuIE51bmMgdmVuZW5hdGlzIGxpZ3VsYSBhdCBvcmNpIHRyaXN0aXF1ZSwgZXQgbWF0dGlzIHB1cnVzIHB1bHZpbmFyLiBFdGlhbSB1bHRyaWNpZXMgZXN0IG9kaW8uIE51bmMgZWxlaWZlbmQgbWFsZXN1YWRhIGp1c3RvLCBuZWMgZXVpc21vZCBzZW0gdWx0cmljZXMgcXVpcy4gRXRpYW0gbmVjIG5pYmggc2l0IGFtZXQgbG9yZW0gZmF1Y2lidXMgZGFwaWJ1cyBxdWlzIG5lYyBsZW8uIFByYWVzZW50IHNpdCBhbWV0IG1hdXJpcyB2ZWwgbGFjdXMgaGVuZHJlcml0IHBvcnRhIG1vbGxpcyBjb25zZWN0ZXR1ciBtaS4gRG9uZWMgZWdldCB0b3J0b3IgZHVpLiBNb3JiaSBpbXBlcmRpZXQsIGFyY3Ugc2l0IGFtZXQgZWxlbWVudHVtIGludGVyZHVtLCBxdWFtIG5pc2wgdGVtcG9yIHF1YW0sIHZpdGFlIGZldWdpYXQgYXVndWUgcHVydXMgc2VkIGxhY3VzLiBJbiBhYyB1cm5hIGFkaXBpc2NpbmcgcHVydXMgdmVuZW5hdGlzIHZvbHV0cGF0IHZlbCBldCBtZXR1cy4gTnVsbGFtIG5lYyBhdWN0b3IgcXVhbS4gUGhhc2VsbHVzIHBvcnR0aXRvciBmZWxpcyBhYyBuaWJoIGdyYXZpZGEgc3VzY2lwaXQgdGVtcHVzIGF0IGFudGUuIE51bmMgcGVsbGVudGVzcXVlIGlhY3VsaXMgc2FwaWVuIGEgbWF0dGlzLiBBZW5lYW4gZWxlaWZlbmQgZG9sb3Igbm9uIG51bmMgbGFvcmVldCwgbm9uIGRpY3R1bSBtYXNzYSBhbGlxdWFtLiBBZW5lYW4gcXVpcyB0dXJwaXMgYXVndWUuIFByYWVzZW50IGF1Z3VlIGxlY3R1cywgbW9sbGlzIG5lYyBlbGVtZW50dW0gZXUsIGRpZ25pc3NpbSBhdCB2ZWxpdC4gVXQgY29uZ3VlIG5lcXVlIGlkIHVsbGFtY29ycGVyIHBlbGxlbnRlc3F1ZS4gTWFlY2VuYXMgZXVpc21vZCBpbiBlbGl0IGV1IHZlaGljdWxhLiBOdWxsYW0gdHJpc3RpcXVlIGR1aSBudWxsYSwgbmVjIGNvbnZhbGxpcyBtZXR1cyBzdXNjaXBpdCBlZ2V0LiBDcmFzIHNlbXBlciBhdWd1ZSBuZWMgY3Vyc3VzIGJsYW5kaXQuIE51bGxhIHJob25jdXMgZXQgb2RpbyBxdWlzIGJsYW5kaXQuIFByYWVzZW50IGxvYm9ydGlzIGRpZ25pc3NpbSB2ZWxpdCB1dCBwdWx2aW5hci4gRHVpcyBpbnRlcmR1bSBxdWFtIGFkaXBpc2NpbmcgZG9sb3Igc2VtcGVyIHNlbXBlci4gTnVuYyBiaWJlbmR1bSBjb252YWxsaXMgZHVpLCBlZ2V0IG1vbGxpcyBtYWduYSBoZW5kcmVyaXQgZXQuIE1vcmJpIGZhY2lsaXNpcywgYXVndWUgZXUgZnJpbmdpbGxhIGNvbnZhbGxpcywgbWF1cmlzIGVzdCBjdXJzdXMgZG9sb3IsIGV1IHBvc3VlcmUgb2RpbyBudW5jIHF1aXMgb3JjaS4gVXQgZXUganVzdG8gc2VtLiBQaGFzZWxsdXMgdXQgZXJhdCByaG9uY3VzLCBmYXVjaWJ1cyBhcmN1IHZpdGFlLCB2dWxwdXRhdGUgZXJhdC4gQWxpcXVhbSBuZWMgbWFnbmEgdml2ZXJyYSwgaW50ZXJkdW0gZXN0IHZpdGFlLCByaG9uY3VzIHNhcGllbi4gRHVpcyB0aW5jaWR1bnQgdGVtcG9yIGlwc3VtIHV0IGRhcGlidXMuIE51bGxhbSBjb21tb2RvIHZhcml1cyBtZXR1cywgc2VkIHNvbGxpY2l0dWRpbiBlcm9zLiBFdGlhbSBuZWMgb2RpbyBldCBkdWkgdGVtcG9yIGJsYW5kaXQgcG9zdWVyZS4=", base64, "medium base64 encoding should work")
    }

    func test_base64DataDecode_medium() {
        let dataEncoded = "TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZWxpdC4gVXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBzb2RhbGVzIGVyYXQsIHNpdCBhbWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2VkIG9ybmFyZSBmZWxpcy4gTnVuYyBtYXVyaXMgdHVycGlzLCBiaWJlbmR1bSBub24gbGVjdHVzIHF1aXMsIG1hbGVzdWFkYSBwbGFjZXJhdCB0dXJwaXMuIE5hbSBhZGlwaXNjaW5nIG5vbiBtYXNzYSBldCBzZW1wZXIuIE51bGxhIGNvbnZhbGxpcyBzZW1wZXIgYmliZW5kdW0uIEFsaXF1YW0gZGljdHVtIG51bGxhIGN1cnN1cyBtaSB1bHRyaWNpZXMsIGF0IHRpbmNpZHVudCBtaSBzYWdpdHRpcy4gTnVsbGEgZmF1Y2lidXMgYXQgZHVpIHF1aXMgc29kYWxlcy4gTW9yYmkgcnV0cnVtLCBkdWkgaWQgdWx0cmljZXMgdmVuZW5hdGlzLCBhcmN1IHVybmEgZWdlc3RhcyBmZWxpcywgdmVsIHN1c2NpcGl0IG1hdXJpcyBhcmN1IHF1aXMgcmlzdXMuIE51bmMgdmVuZW5hdGlzIGxpZ3VsYSBhdCBvcmNpIHRyaXN0aXF1ZSwgZXQgbWF0dGlzIHB1cnVzIHB1bHZpbmFyLiBFdGlhbSB1bHRyaWNpZXMgZXN0IG9kaW8uIE51bmMgZWxlaWZlbmQgbWFsZXN1YWRhIGp1c3RvLCBuZWMgZXVpc21vZCBzZW0gdWx0cmljZXMgcXVpcy4gRXRpYW0gbmVjIG5pYmggc2l0IGFtZXQgbG9yZW0gZmF1Y2lidXMgZGFwaWJ1cyBxdWlzIG5lYyBsZW8uIFByYWVzZW50IHNpdCBhbWV0IG1hdXJpcyB2ZWwgbGFjdXMgaGVuZHJlcml0IHBvcnRhIG1vbGxpcyBjb25zZWN0ZXR1ciBtaS4gRG9uZWMgZWdldCB0b3J0b3IgZHVpLiBNb3JiaSBpbXBlcmRpZXQsIGFyY3Ugc2l0IGFtZXQgZWxlbWVudHVtIGludGVyZHVtLCBxdWFtIG5pc2wgdGVtcG9yIHF1YW0sIHZpdGFlIGZldWdpYXQgYXVndWUgcHVydXMgc2VkIGxhY3VzLiBJbiBhYyB1cm5hIGFkaXBpc2NpbmcgcHVydXMgdmVuZW5hdGlzIHZvbHV0cGF0IHZlbCBldCBtZXR1cy4gTnVsbGFtIG5lYyBhdWN0b3IgcXVhbS4gUGhhc2VsbHVzIHBvcnR0aXRvciBmZWxpcyBhYyBuaWJoIGdyYXZpZGEgc3VzY2lwaXQgdGVtcHVzIGF0IGFudGUuIE51bmMgcGVsbGVudGVzcXVlIGlhY3VsaXMgc2FwaWVuIGEgbWF0dGlzLiBBZW5lYW4gZWxlaWZlbmQgZG9sb3Igbm9uIG51bmMgbGFvcmVldCwgbm9uIGRpY3R1bSBtYXNzYSBhbGlxdWFtLiBBZW5lYW4gcXVpcyB0dXJwaXMgYXVndWUuIFByYWVzZW50IGF1Z3VlIGxlY3R1cywgbW9sbGlzIG5lYyBlbGVtZW50dW0gZXUsIGRpZ25pc3NpbSBhdCB2ZWxpdC4gVXQgY29uZ3VlIG5lcXVlIGlkIHVsbGFtY29ycGVyIHBlbGxlbnRlc3F1ZS4gTWFlY2VuYXMgZXVpc21vZCBpbiBlbGl0IGV1IHZlaGljdWxhLiBOdWxsYW0gdHJpc3RpcXVlIGR1aSBudWxsYSwgbmVjIGNvbnZhbGxpcyBtZXR1cyBzdXNjaXBpdCBlZ2V0LiBDcmFzIHNlbXBlciBhdWd1ZSBuZWMgY3Vyc3VzIGJsYW5kaXQuIE51bGxhIHJob25jdXMgZXQgb2RpbyBxdWlzIGJsYW5kaXQuIFByYWVzZW50IGxvYm9ydGlzIGRpZ25pc3NpbSB2ZWxpdCB1dCBwdWx2aW5hci4gRHVpcyBpbnRlcmR1bSBxdWFtIGFkaXBpc2NpbmcgZG9sb3Igc2VtcGVyIHNlbXBlci4gTnVuYyBiaWJlbmR1bSBjb252YWxsaXMgZHVpLCBlZ2V0IG1vbGxpcyBtYWduYSBoZW5kcmVyaXQgZXQuIE1vcmJpIGZhY2lsaXNpcywgYXVndWUgZXUgZnJpbmdpbGxhIGNvbnZhbGxpcywgbWF1cmlzIGVzdCBjdXJzdXMgZG9sb3IsIGV1IHBvc3VlcmUgb2RpbyBudW5jIHF1aXMgb3JjaS4gVXQgZXUganVzdG8gc2VtLiBQaGFzZWxsdXMgdXQgZXJhdCByaG9uY3VzLCBmYXVjaWJ1cyBhcmN1IHZpdGFlLCB2dWxwdXRhdGUgZXJhdC4gQWxpcXVhbSBuZWMgbWFnbmEgdml2ZXJyYSwgaW50ZXJkdW0gZXN0IHZpdGFlLCByaG9uY3VzIHNhcGllbi4gRHVpcyB0aW5jaWR1bnQgdGVtcG9yIGlwc3VtIHV0IGRhcGlidXMuIE51bGxhbSBjb21tb2RvIHZhcml1cyBtZXR1cywgc2VkIHNvbGxpY2l0dWRpbiBlcm9zLiBFdGlhbSBuZWMgb2RpbyBldCBkdWkgdGVtcG9yIGJsYW5kaXQgcG9zdWVyZS4=".data(using: .utf8)!
        let dataDecoded = NSData(base64Encoded: dataEncoded)!
        let string = Data(referencing: dataDecoded).withUnsafeBytes { buffer in
            return String(bytes: buffer, encoding: .utf8)
        }
        XCTAssertEqual("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut at tincidunt arcu. Suspendisse nec sodales erat, sit amet imperdiet ipsum. Etiam sed ornare felis. Nunc mauris turpis, bibendum non lectus quis, malesuada placerat turpis. Nam adipiscing non massa et semper. Nulla convallis semper bibendum. Aliquam dictum nulla cursus mi ultricies, at tincidunt mi sagittis. Nulla faucibus at dui quis sodales. Morbi rutrum, dui id ultrices venenatis, arcu urna egestas felis, vel suscipit mauris arcu quis risus. Nunc venenatis ligula at orci tristique, et mattis purus pulvinar. Etiam ultricies est odio. Nunc eleifend malesuada justo, nec euismod sem ultrices quis. Etiam nec nibh sit amet lorem faucibus dapibus quis nec leo. Praesent sit amet mauris vel lacus hendrerit porta mollis consectetur mi. Donec eget tortor dui. Morbi imperdiet, arcu sit amet elementum interdum, quam nisl tempor quam, vitae feugiat augue purus sed lacus. In ac urna adipiscing purus venenatis volutpat vel et metus. Nullam nec auctor quam. Phasellus porttitor felis ac nibh gravida suscipit tempus at ante. Nunc pellentesque iaculis sapien a mattis. Aenean eleifend dolor non nunc laoreet, non dictum massa aliquam. Aenean quis turpis augue. Praesent augue lectus, mollis nec elementum eu, dignissim at velit. Ut congue neque id ullamcorper pellentesque. Maecenas euismod in elit eu vehicula. Nullam tristique dui nulla, nec convallis metus suscipit eget. Cras semper augue nec cursus blandit. Nulla rhoncus et odio quis blandit. Praesent lobortis dignissim velit ut pulvinar. Duis interdum quam adipiscing dolor semper semper. Nunc bibendum convallis dui, eget mollis magna hendrerit et. Morbi facilisis, augue eu fringilla convallis, mauris est cursus dolor, eu posuere odio nunc quis orci. Ut eu justo sem. Phasellus ut erat rhoncus, faucibus arcu vitae, vulputate erat. Aliquam nec magna viverra, interdum est vitae, rhoncus sapien. Duis tincidunt tempor ipsum ut dapibus. Nullam commodo varius metus, sed sollicitudin eros. Etiam nec odio et dui tempor blandit posuere.", string, "medium base64 decoding should work")
    }

    func test_openingNonExistentFile() {
        var didCatchError = false

        do {
            let _ = try NSData(contentsOfFile: "does not exist", options: [])
        } catch {
            didCatchError = true
        }

        XCTAssertTrue(didCatchError)
    }

    func test_contentsOfFile() {
        let testDir = Bundle.module.resourcePath
        let filename = testDir!.appending("/NSStringTestData.txt")

        let contents = NSData(contentsOfFile: filename)
        XCTAssertNotNil(contents)
        if let contents = contents {
            withExtendedLifetime(contents) {
                let ptr =  UnsafeMutableRawPointer(mutating: contents.bytes)
                let str = String(bytesNoCopy: ptr, length: contents.length,
                             encoding: .ascii, freeWhenDone: false)
                XCTAssertEqual(str, "swift-corelibs-foundation")
            }
        }
    }

    func test_contentsOfZeroFile() {
#if os(Linux)
        guard FileManager.default.fileExists(atPath: "/proc/self") else {
            return
        }
        let contents = NSData(contentsOfFile: "/proc/self/cmdline")
        XCTAssertNotNil(contents)
        if let contents = contents {
            withExtendedLifetime(contents) {
                XCTAssertTrue(contents.length > 0)
                let ptr = UnsafeMutableRawPointer(mutating: contents.bytes)
                var zeroIdx = contents.range(of: Data([0]), in: NSMakeRange(0, contents.length)).location
                if zeroIdx == NSNotFound { zeroIdx = contents.length }
                if let str = String(bytesNoCopy: ptr, length: zeroIdx, encoding: .ascii, freeWhenDone: false) {
                    XCTAssertTrue(str.hasSuffix(".xctest"))
                } else {
                    XCTFail("Cant create String")
                }
            }
        }

        do {
            let maps = try String(contentsOfFile: "/proc/self/maps", encoding: .utf8)
            XCTAssertTrue(maps.count > 0)
        } catch {
            XCTFail("Cannot read /proc/self/maps: \(String(describing: error))")
        }
#endif
    }

    func test_wrongSizedFile() throws {
#if os(Linux)
        guard FileManager.default.fileExists(atPath: "/sys/kernel/profiling") else {
            throw XCTSkip("/sys/kernel/profiling doesn't exist")
        }
        // Some files in /sys report a non-zero st_size often bigger than the contents
        guard let data = NSData.init(contentsOfFile: "/sys/kernel/profiling") else {
            XCTFail("Cant read /sys/kernel/profiling")
            return
        }
        XCTAssert(data.length > 0)
#endif
    }

#if ENABLE_DATA_NETWORKING_TESTS
    func test_contentsOfURL() throws {
        do {
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/country.txt"
            let url = try XCTUnwrap(URL(string: urlString))
            let contents = NSData(contentsOf: url)
            XCTAssertNotNil(contents)
            if let contents = contents {
                XCTAssertTrue(contents.length > 0)
            }
        }

        do {
            let urlString = "http://127.0.0.1:\(TestURLSession.serverPort)/NotFound"
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertNil(NSData(contentsOf: url))
            do {
                _ = try NSData(contentsOf: url, options: [])
                XCTFail("NSData(contentsOf:options: did not throw")
            } catch let error as NSError {
                if let nserror = error as? NSError {
                    XCTAssertEqual(NSCocoaErrorDomain, nserror.domain)
                    XCTAssertEqual(CocoaError.fileReadUnknown.rawValue, nserror.code)
                } else {
                    XCTFail("Not an NSError")
                }
            }

            do {
                _ = try Data(contentsOf: url)
                XCTFail("Data(contentsOf:options: did not throw")
            } catch let error as NSError {
                if let nserror = error as? NSError {
                    XCTAssertEqual(NSCocoaErrorDomain, nserror.domain)
                    XCTAssertEqual(CocoaError.fileReadUnknown.rawValue, nserror.code)
                } else {
                    XCTFail("Not an NSError")
                }
            }
        }
    }
#endif

    func test_basicReadWrite() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("testfile")
        let count = 1 << 24
        let randomMemory = malloc(count)!
        let ptr = randomMemory.bindMemory(to: UInt8.self, capacity: count)
        let data = Data(bytesNoCopy: ptr, count: count, deallocator: .free)
        do {
            try data.write(to: url)
            let readData = try Data(contentsOf: url)
            XCTAssertEqual(data, readData)
        } catch {
            XCTFail("Should not have thrown")
        }
        
        try? FileManager.default.removeItem(at: url)
    }
    
    func test_writeFailure() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("testfile")
        
        let data = Data()
        do {
            try data.write(to: url)
        } catch let error as NSError {
            print(error)
            XCTAssertTrue(false, "Should not have thrown")
        } catch {
            XCTFail("unexpected error")
        }
        
        do {
            try data.write(to: url, options: [.withoutOverwriting])
            XCTAssertTrue(false, "Should have thrown")
        } catch {
            XCTAssertEqual((error as NSError).code, CocoaError.fileWriteFileExists.rawValue)
        }
        
        try? FileManager.default.removeItem(at: url)

        // Make sure clearing the error condition allows the write to succeed
        do {
            try data.write(to: url, options: [.withoutOverwriting])
        } catch {
            XCTAssertTrue(false, "Should not have thrown")
        }
        
        try? FileManager.default.removeItem(at: url)
    }
    
    func test_genericBuffers() {
        let a : [Int32] = [1, 0, 1, 0, 1]
        var data = a.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }
        
        var expectedSize = MemoryLayout<Int32>.stride * a.count
        XCTAssertEqual(expectedSize, data.count)
        
        [false, true].withUnsafeBufferPointer {
            data.append($0)
        }
        
        expectedSize += MemoryLayout<Bool>.stride * 2
        XCTAssertEqual(expectedSize, data.count)
        
        let size = expectedSize
        let underlyingBuffer = malloc(size)!
        let buffer = UnsafeMutableBufferPointer(start: underlyingBuffer.bindMemory(to: UInt8.self, capacity: size), count: size)
        let copiedCount = data.copyBytes(to: buffer)
        XCTAssertEqual(copiedCount, expectedSize)
        
        free(underlyingBuffer)
    }
    
    // intentionally structured so sizeof() != strideof()
    struct MyStruct {
        var time: UInt64
        let x: UInt32
        let y: UInt32
        let z: UInt32
        init() {
            time = 0
            x = 1
            y = 2
            z = 3
        }
    }
    
    func test_bufferSizeCalculation() {
        // Make sure that Data is correctly using strideof instead of sizeof.
        // n.b. if sizeof(MyStruct) == strideof(MyStruct), this test is not as useful as it could be
        
        // init
        let stuff = [MyStruct(), MyStruct(), MyStruct()]
        var data = stuff.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }
        
        XCTAssertEqual(data.count, MemoryLayout<MyStruct>.stride * 3)
        
        
        // append
        stuff.withUnsafeBufferPointer {
            data.append($0)
        }
        
        XCTAssertEqual(data.count, MemoryLayout<MyStruct>.stride * 6)
        
        // copyBytes
        do {
            // equal size
            let underlyingBuffer = malloc(6 * MemoryLayout<MyStruct>.stride)!
            defer { free(underlyingBuffer) }
            
            let ptr = underlyingBuffer.bindMemory(to: MyStruct.self, capacity: 6)
            let buffer = UnsafeMutableBufferPointer<MyStruct>(start: ptr, count: 6)
            
            let byteCount = data.copyBytes(to: buffer)
            XCTAssertEqual(6 * MemoryLayout<MyStruct>.stride, byteCount)
        }
        
        do {
            // undersized
            let underlyingBuffer = malloc(3 * MemoryLayout<MyStruct>.stride)!
            defer { free(underlyingBuffer) }
            
            let ptr = underlyingBuffer.bindMemory(to: MyStruct.self, capacity: 3)
            let buffer = UnsafeMutableBufferPointer<MyStruct>(start: ptr, count: 3)
            
            let byteCount = data.copyBytes(to: buffer)
            XCTAssertEqual(3 * MemoryLayout<MyStruct>.stride, byteCount)
        }
        
        do {
            // oversized
            let underlyingBuffer = malloc(12 * MemoryLayout<MyStruct>.stride)!
            defer { free(underlyingBuffer) }
            
            let ptr = underlyingBuffer.bindMemory(to: MyStruct.self, capacity: 6)
            let buffer = UnsafeMutableBufferPointer<MyStruct>(start: ptr, count: 6)
            
            let byteCount = data.copyBytes(to: buffer)
            XCTAssertEqual(6 * MemoryLayout<MyStruct>.stride, byteCount)
        }
    }

    func test_repeatingValueInitialization() {
        var d = Data(repeating: 0x01, count: 3)
        let elements = repeatElement(UInt8(0x02), count: 3) // ensure we fall into the sequence case
        d.append(contentsOf: elements)

        XCTAssertEqual(d[0], 0x01)
        XCTAssertEqual(d[1], 0x01)
        XCTAssertEqual(d[2], 0x01)

        XCTAssertEqual(d[3], 0x02)
        XCTAssertEqual(d[4], 0x02)
        XCTAssertEqual(d[5], 0x02)
    }
    
    func test_sliceAppending() {
        // https://bugs.swift.org/browse/SR-4473
        var fooData = Data()
        let barData = Data([0, 1, 2, 3, 4, 5])
        let slice = barData.suffix(from: 3)
        fooData.append(slice)
        XCTAssertEqual(fooData[0], 0x03)
        XCTAssertEqual(fooData[1], 0x04)
        XCTAssertEqual(fooData[2], 0x05)
    }
    
    func test_replaceSubrange() {
        // https://bugs.swift.org/browse/SR-4462
        let data = Data([0x01, 0x02])
        var dataII = Data(base64Encoded: data.base64EncodedString())!
        dataII.replaceSubrange(0..<1, with: Data())
        XCTAssertEqual(dataII[0], 0x02)
    }
    
    func test_sliceWithUnsafeBytes() {
        let base = Data([0, 1, 2, 3, 4, 5])
        let slice = base[2..<4]
        let segment = slice.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> [UInt8] in
            return [buffer[0], buffer[1]]
        }
        XCTAssertEqual(segment, [UInt8(2), UInt8(3)])
    }
    
    func test_sliceIteration() {
        let base = Data([0, 1, 2, 3, 4, 5])
        let slice = base[2..<4]
        var found = [UInt8]()
        for byte in slice {
            found.append(byte)
        }
        XCTAssertEqual(found[0], 2)
        XCTAssertEqual(found[1], 3)
    }

        func test_validateMutation_withUnsafeMutableBytes() {
            var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[5] = 0xFF
        }
            XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 0xFF, 6, 7, 8, 9]))
    }
    
    func test_validateMutation_appendBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.append("hello", count: 5)
        XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0x5)
    }
    
    func test_validateMutation_appendData() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let other = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.append(other)
        XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
    }
    
    func test_validateMutation_appendBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
    }
    
    func test_validateMutation_appendSequence() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let seq = repeatElement(UInt8(1), count: 10)
        data.append(contentsOf: seq)
        XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 1)
    }
    
    func test_validateMutation_appendContentsOf() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        data.append(contentsOf: bytes)
        XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
    }
    
    func test_validateMutation_resetBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 0, 0, 0, 8, 9]))
    }
    
    func test_validateMutation_replaceSubrange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
    }
    
    func test_validateMutation_replaceSubrangeRange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
    }
    
    func test_validateMutation_replaceSubrangeWithBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer {
            data.replaceSubrange(range, with: $0)
        }
        XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
    }
    
    func test_validateMutation_replaceSubrangeWithCollection() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let bytes: [UInt8] = [0xFF, 0xFF]
        data.replaceSubrange(range, with: bytes)
        XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
    }
    
    func test_validateMutation_replaceSubrangeWithBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBytes {
            data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
        }
        XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
    }
    
    func test_validateMutation_slice_withUnsafeMutableBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            buffer[1] = 0xFF
        }
        XCTAssertEqual(data, Data([4, 0xFF, 6, 7, 8]))
    }
    
    func test_validateMutation_slice_appendBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_appendData() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let other = Data([0xFF, 0xFF])
        data.append(other)
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_appendBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_appendSequence() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let seq = repeatElement(UInt8(0xFF), count: 2)
        data.append(contentsOf: seq)
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_appendContentsOf() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        data.append(contentsOf: bytes)
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_resetBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data, Data([4, 0, 0, 0, 8]))
    }
    
    func test_validateMutation_slice_replaceSubrange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }
    
    func test_validateMutation_slice_replaceSubrangeRange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }
    
    func test_validateMutation_slice_replaceSubrangeWithBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer {
            data.replaceSubrange(range, with: $0)
        }
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }
    
    func test_validateMutation_slice_replaceSubrangeWithCollection() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        data.replaceSubrange(range, with: bytes)
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }
    
    func test_validateMutation_slice_replaceSubrangeWithBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBytes {
            data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
        }
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }
    
    func test_validateMutation_cow_withUnsafeMutableBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                ptr[5] = 0xFF
            }
            XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 0xFF, 6, 7, 8, 9]))
        }
    }
    
    func test_validateMutation_cow_appendBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            data.append("hello", count: 5)
            XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 0x9)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x68)
        }
    }
    
    func test_validateMutation_cow_appendData() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let other = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
            data.append(other)
            XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
        }
    }
    
    func test_validateMutation_cow_appendBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            bytes.withUnsafeBufferPointer { data.append($0) }
            XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
        }
    }
    
    func test_validateMutation_cow_appendSequence() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let seq = repeatElement(UInt8(1), count: 10)
            data.append(contentsOf: seq)
            XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 1)
        }
    }
    
    func test_validateMutation_cow_appendContentsOf() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            data.append(contentsOf: bytes)
            XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
        }
    }
    
    func test_validateMutation_cow_resetBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 0, 0, 0, 8, 9]))
        }
    }
    
    func test_validateMutation_cow_replaceSubrange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
        }
    }
    
    func test_validateMutation_cow_replaceSubrangeRange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
        }
    }
    
    func test_validateMutation_cow_replaceSubrangeWithBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer {
                data.replaceSubrange(range, with: $0)
            }
            XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
        }
    }
    
    func test_validateMutation_cow_replaceSubrangeWithCollection() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let bytes: [UInt8] = [0xFF, 0xFF]
            data.replaceSubrange(range, with: bytes)
            XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
        }
    }
    
    func test_validateMutation_cow_replaceSubrangeWithBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBytes {
                data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
            }
            XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
        }
    }
    
    func test_validateMutation_slice_cow_withUnsafeMutableBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                ptr[1] = 0xFF
            }
            XCTAssertEqual(data, Data([4, 0xFF, 6, 7, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_appendBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            data.append("hello", count: 5)
            XCTAssertEqual(data[data.startIndex.advanced(by: 4)], 0x8)
            XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0x68)
        }
    }
    
    func test_validateMutation_slice_cow_appendData() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let other = Data([0xFF, 0xFF])
            data.append(other)
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_appendBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.append($0) }
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_appendSequence() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let seq = repeatElement(UInt8(0xFF), count: 2)
            data.append(contentsOf: seq)
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_appendContentsOf() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            data.append(contentsOf: bytes)
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_resetBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data, Data([4, 0, 0, 0, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_replaceSubrange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_replaceSubrangeRange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_replaceSubrangeWithBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer {
                data.replaceSubrange(range, with: $0)
            }
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_replaceSubrangeWithCollection() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            data.replaceSubrange(range, with: bytes)
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_replaceSubrangeWithBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBytes {
                data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
            }
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_immutableBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[5] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0xFF)
    }
    
    func test_validateMutation_immutableBacking_appendBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append("hello", count: 5)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x64)
        XCTAssertEqual(data[data.startIndex.advanced(by: 11)], 0x68)
    }
    
    func test_validateMutation_immutableBacking_appendData() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        let other = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.append(other)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x64)
        XCTAssertEqual(data[data.startIndex.advanced(by: 11)], 0)
    }
    
    func test_validateMutation_immutableBacking_appendBuffer() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x64)
        XCTAssertEqual(data[data.startIndex.advanced(by: 11)], 0)
    }
    
    func test_validateMutation_immutableBacking_appendSequence() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        let seq = repeatElement(UInt8(1), count: 10)
        data.append(contentsOf: seq)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x64)
        XCTAssertEqual(data[data.startIndex.advanced(by: 11)], 1)
    }
    
    func test_validateMutation_immutableBacking_appendContentsOf() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        data.append(contentsOf: bytes)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x64)
        XCTAssertEqual(data[data.startIndex.advanced(by: 11)], 0)
    }
    
    func test_validateMutation_immutableBacking_resetBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x00, 0x00, 0x00, 0x72, 0x6c, 0x64]))
    }
    
    func test_validateMutation_immutableBacking_replaceSubrange() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xFF, 0xFF, 0x6c, 0x64]))
    }
    
    func test_validateMutation_immutableBacking_replaceSubrangeRange() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xFF, 0xFF, 0x6c, 0x64]))
    }
    
    func test_validateMutation_immutableBacking_replaceSubrangeWithBuffer() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer {
            data.replaceSubrange(range, with: $0)
        }
        XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xFF, 0xFF, 0x6c, 0x64]))
    }
    
    func test_validateMutation_immutableBacking_replaceSubrangeWithCollection() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let bytes: [UInt8] = [0xFF, 0xFF]
        data.replaceSubrange(range, with: bytes)
        XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xFF, 0xFF, 0x6c, 0x64]))
    }
    
    func test_validateMutation_immutableBacking_replaceSubrangeWithBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let bytes: [UInt8] = [0xFF, 0xFF]
        data.replaceSubrange(range, with: bytes)
        XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xFF, 0xFF, 0x6c, 0x64]))
    }
    
    func test_validateMutation_slice_immutableBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))[4..<9]
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[1] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
    }
    
    func test_validateMutation_slice_immutableBacking_appendBytes() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_immutableBacking_appendData() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        data.append(Data([0xFF, 0xFF]))
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_immutableBacking_appendBuffer() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_immutableBacking_appendSequence() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        data.append(contentsOf: repeatElement(UInt8(0xFF), count: 2))
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_immutableBacking_appendContentsOf() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        data.append(contentsOf: [0xFF, 0xFF])
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_immutableBacking_resetBytes() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data, Data([4, 0, 0, 0, 8]))
    }
    
    func test_validateMutation_slice_immutableBacking_replaceSubrange() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: Data([0xFF, 0xFF]))
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }
    
    func test_validateMutation_slice_immutableBacking_replaceSubrangeRange() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: Data([0xFF, 0xFF]))
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }
    
    func test_validateMutation_slice_immutableBacking_replaceSubrangeWithBuffer() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        let replacement: [UInt8] = [0xFF, 0xFF]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        replacement.withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<UInt8>) in
            data.replaceSubrange(range, with: buffer)
        }
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }
    
    func test_validateMutation_slice_immutableBacking_replaceSubrangeWithCollection() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let replacement: [UInt8] = [0xFF, 0xFF]
        data.replaceSubrange(range, with:replacement)
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }
    
    func test_validateMutation_slice_immutableBacking_replaceSubrangeWithBytes() {
        let base: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = base.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        let replacement: [UInt8] = [0xFF, 0xFF]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        replacement.withUnsafeBytes {
            data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
        }
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }
    
    func test_validateMutation_cow_immutableBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                ptr[5] = 0xFF
            }
            XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0xFF)
        }
    }
    
    func test_validateMutation_cow_immutableBacking_appendBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            data.append("hello", count: 5)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x64)
            XCTAssertEqual(data[data.startIndex.advanced(by: 11)], 0x68)
        }
    }
    
    func test_validateMutation_cow_immutableBacking_appendData() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            let other = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
            data.append(other)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x64)
            XCTAssertEqual(data[data.startIndex.advanced(by: 11)], 0)
        }
    }
    
    func test_validateMutation_cow_immutableBacking_appendBuffer() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            bytes.withUnsafeBufferPointer { data.append($0) }
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x64)
            XCTAssertEqual(data[data.startIndex.advanced(by: 11)], 0)
        }
    }
    
    func test_validateMutation_cow_immutableBacking_appendSequence() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            let seq = repeatElement(UInt8(1), count: 10)
            data.append(contentsOf: seq)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x64)
            XCTAssertEqual(data[data.startIndex.advanced(by: 11)], 1)
        }
    }
    
    func test_validateMutation_cow_immutableBacking_appendContentsOf() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            let bytes: [UInt8] = [1, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            data.append(contentsOf: bytes)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x64)
            XCTAssertEqual(data[data.startIndex.advanced(by: 11)], 1)
        }
    }
    
    func test_validateMutation_cow_immutableBacking_resetBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x00, 0x00, 0x00, 0x72, 0x6c, 0x64]))
        }
    }
    
    func test_validateMutation_cow_immutableBacking_replaceSubrange() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xff, 0xff, 0x6c, 0x64]))
        }
    }
    
    func test_validateMutation_cow_immutableBacking_replaceSubrangeRange() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xff, 0xff, 0x6c, 0x64]))
        }
    }
    
    func test_validateMutation_cow_immutableBacking_replaceSubrangeWithBuffer() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            let replacement: [UInt8] = [0xFF, 0xFF]
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            replacement.withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<UInt8>) in
                data.replaceSubrange(range, with: buffer)
            }
            XCTAssertEqual(data, Data([0x68, 0xff, 0xff, 0x64]))
        }
    }
    
    func test_validateMutation_cow_immutableBacking_replaceSubrangeWithCollection() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            let replacement: [UInt8] = [0xFF, 0xFF]
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([0x68, 0xff, 0xff, 0x64]))
        }
    }
    
    func test_validateMutation_cow_immutableBacking_replaceSubrangeWithBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        holdReference(data) {
            let replacement: [UInt8] = [0xFF, 0xFF]
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            replacement.withUnsafeBytes {
                data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
            }
            XCTAssertEqual(data, Data([0x68, 0xff, 0xff, 0x64]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))[4..<9]
        holdReference(data) {
            data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                ptr[1] = 0xFF
            }
            XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_appendBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_appendData() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        holdReference(data) {
            data.append(Data([0xFF, 0xFF]))
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_appendBuffer() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer{ data.append($0) }
            XCTAssertEqual(data, Data([0x6f, 0x20, 0x77, 0x6f, 0x72, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_appendSequence() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        holdReference(data) {
            let bytes = repeatElement(UInt8(0xFF), count: 2)
            data.append(contentsOf: bytes)
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_appendContentsOf() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            data.append(contentsOf: bytes)
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_resetBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data, Data([4, 0, 0, 0, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_replaceSubrange() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data([0xFF, 0xFF]))
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_replaceSubrangeRange() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data([0xFF, 0xFF]))
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_replaceSubrangeWithBuffer() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0) }
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_replaceSubrangeWithCollection() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            data.replaceSubrange(range, with: bytes)
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_immutableBacking_replaceSubrangeWithBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))[4..<9]
        }
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBytes { data.replaceSubrange(range, with: $0.baseAddress!, count: 2) }
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_mutableBacking_withUnsafeMutableBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[5] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0xFF)
    }
    
    func test_validateMutation_mutableBacking_appendBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_mutableBacking_appendData() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        data.append(Data([0xFF, 0xFF]))
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_mutableBacking_appendBuffer() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_mutableBacking_appendSequence() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        data.append(contentsOf: repeatElement(UInt8(0xFF), count: 2))
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_mutableBacking_appendContentsOf() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        data.append(contentsOf: [0xFF, 0xFF])
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_mutableBacking_resetBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 0, 0, 0, 8, 9]))
    }
    
    func test_validateMutation_mutableBacking_replaceSubrange() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([0, 0xFF, 0xFF, 9]))
    }
    
    func test_validateMutation_mutableBacking_replaceSubrangeRange() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([0, 0xFF, 0xFF, 9]))
    }
    
    func test_validateMutation_mutableBacking_replaceSubrangeWithBuffer() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer {
            data.replaceSubrange(range, with: $0)
        }
        XCTAssertEqual(data, Data([0, 0xFF, 0xFF, 9]))
    }
    
    func test_validateMutation_mutableBacking_replaceSubrangeWithCollection() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: [0xFF, 0xFF])
        XCTAssertEqual(data, Data([0, 0xFF, 0xFF, 9]))
    }
    
    func test_validateMutation_mutableBacking_replaceSubrangeWithBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var data = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        data.append(contentsOf: [7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBytes {
            data.replaceSubrange(range, with: $0.baseAddress!, count: $0.count)
        }
        XCTAssertEqual(data, Data([0, 0xFF, 0xFF, 9]))
    }
    
    func test_validateMutation_slice_mutableBacking_withUnsafeMutableBytes() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<9]
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[1] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
    }
    
    func test_validateMutation_slice_mutableBacking_appendBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_mutableBacking_appendData() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        data.append(Data([0xFF, 0xFF]))
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_mutableBacking_appendBuffer() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<9]
        let bytes: [UInt8] = [1, 2, 3]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data, Data([0x6f, 0x20, 0x77, 0x6f, 0x72, 0x1, 0x2, 0x3]))
    }
    
    func test_validateMutation_slice_mutableBacking_appendSequence() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<9]
        let seq = repeatElement(UInt8(1), count: 3)
        data.append(contentsOf: seq)
        XCTAssertEqual(data, Data([0x6f, 0x20, 0x77, 0x6f, 0x72, 0x1, 0x1, 0x1]))
    }
    
    func test_validateMutation_slice_mutableBacking_appendContentsOf() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<9]
        let bytes: [UInt8] = [1, 2, 3]
        data.append(contentsOf: bytes)
        XCTAssertEqual(data, Data([0x6f, 0x20, 0x77, 0x6f, 0x72, 0x1, 0x2, 0x3]))
    }
    
    func test_validateMutation_slice_mutableBacking_resetBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data, Data([4, 0, 0, 0, 8]))
    }
    
    func test_validateMutation_slice_mutableBacking_replaceSubrange() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: Data([0xFF, 0xFF]))
        XCTAssertEqual(data, Data([0x6f, 0xFF, 0xFF, 0x72]))
    }
    
    func test_validateMutation_slice_mutableBacking_replaceSubrangeRange() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: Data([0xFF, 0xFF]))
        XCTAssertEqual(data, Data([0x6f, 0xFF, 0xFF, 0x72]))
    }
    
    func test_validateMutation_slice_mutableBacking_replaceSubrangeWithBuffer() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<9]
        let replacement: [UInt8] = [0xFF, 0xFF]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        replacement.withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<UInt8>) in
            data.replaceSubrange(range, with: buffer)
        }
        XCTAssertEqual(data, Data([0x6f, 0xFF, 0xFF, 0x72]))
    }
    
    func test_validateMutation_slice_mutableBacking_replaceSubrangeWithCollection() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let replacement: [UInt8] = [0xFF, 0xFF]
        data.replaceSubrange(range, with:replacement)
        XCTAssertEqual(data, Data([0x6f, 0xFF, 0xFF, 0x72]))
    }
    
    func test_validateMutation_slice_mutableBacking_replaceSubrangeWithBytes() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<9]
        let replacement: [UInt8] = [0xFF, 0xFF]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        replacement.withUnsafeBytes {
            data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
        }
        XCTAssertEqual(data, Data([0x6f, 0xFF, 0xFF, 0x72]))
    }
    
    func test_validateMutation_cow_mutableBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                ptr[5] = 0xFF
            }
            XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0xFF)
        }
    }
    
    func test_validateMutation_cow_mutableBacking_appendBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            data.append("hello", count: 5)
            XCTAssertEqual(data[data.startIndex.advanced(by: 16)], 6)
            XCTAssertEqual(data[data.startIndex.advanced(by: 17)], 0x68)
        }
    }
    
    func test_validateMutation_cow_mutableBacking_appendData() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            data.append("hello", count: 5)
            XCTAssertEqual(data[data.startIndex.advanced(by: 16)], 6)
            XCTAssertEqual(data[data.startIndex.advanced(by: 17)], 0x68)
        }
    }
    
    func test_validateMutation_cow_mutableBacking_appendBuffer() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            let other = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
            data.append(other)
            XCTAssertEqual(data[data.startIndex.advanced(by: 16)], 6)
            XCTAssertEqual(data[data.startIndex.advanced(by: 17)], 0)
        }
    }
    
    func test_validateMutation_cow_mutableBacking_appendSequence() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            let seq = repeatElement(UInt8(1), count: 10)
            data.append(contentsOf: seq)
            XCTAssertEqual(data[data.startIndex.advanced(by: 16)], 6)
            XCTAssertEqual(data[data.startIndex.advanced(by: 17)], 1)
        }
    }
    
    func test_validateMutation_cow_mutableBacking_appendContentsOf() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            let bytes: [UInt8] = [1, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            data.append(contentsOf: bytes)
            XCTAssertEqual(data[data.startIndex.advanced(by: 16)], 6)
            XCTAssertEqual(data[data.startIndex.advanced(by: 17)], 1)
        }
    }
    
    func test_validateMutation_cow_mutableBacking_resetBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x00, 0x00, 0x00, 0x72, 0x6c, 0x64, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
        }
    }
    
    func test_validateMutation_cow_mutableBacking_replaceSubrange() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xff, 0xff, 0x6c, 0x64, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
        }
    }
    
    func test_validateMutation_cow_mutableBacking_replaceSubrangeRange() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xff, 0xff, 0x6c, 0x64, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
        }
    }
    
    func test_validateMutation_cow_mutableBacking_replaceSubrangeWithBuffer() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let replacement: [UInt8] = [0xFF, 0xFF]
            replacement.withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<UInt8>) in
                data.replaceSubrange(range, with: buffer)
            }
            XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xff, 0xff, 0x6c, 0x64, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
        }
    }
    
    func test_validateMutation_cow_mutableBacking_replaceSubrangeWithCollection() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            let replacement: [UInt8] = [0xFF, 0xFF]
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xff, 0xff, 0x6c, 0x64, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
        }
    }
    
    func test_validateMutation_cow_mutableBacking_replaceSubrangeWithBytes() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))
        data.append(contentsOf: [1, 2, 3, 4, 5, 6])
        holdReference(data) {
            let replacement: [UInt8] = [0xFF, 0xFF]
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            replacement.withUnsafeBytes {
                data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
            }
            XCTAssertEqual(data, Data([0x68, 0x65, 0x6c, 0x6c, 0xff, 0xff, 0x6c, 0x64, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_withUnsafeMutableBytes() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<9]
        holdReference(data) {
            data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                ptr[1] = 0xFF
            }
            XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_appendBytes() {
        let bytes: [UInt8] = [0, 1, 2]
        var base = bytes.withUnsafeBytes { (ptr) in
            return Data(referencing: NSData(bytes: ptr.baseAddress!, length: ptr.count))
        }
        base.append(contentsOf: [3, 4, 5])
        var data = base[1..<4]
        holdReference(data) {
            let bytesToAppend: [UInt8] = [6, 7, 8]
            bytesToAppend.withUnsafeBytes { (ptr) in
                data.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), count: ptr.count)
            }
            XCTAssertEqual(data, Data([1, 2, 3, 6, 7, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_appendData() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        holdReference(data) {
            data.append(Data([0xFF, 0xFF]))
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_appendBuffer() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer{ data.append($0) }
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_appendSequence() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        holdReference(data) {
            let bytes = repeatElement(UInt8(0xFF), count: 2)
            data.append(contentsOf: bytes)
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_appendContentsOf() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            data.append(contentsOf: bytes)
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_resetBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data, Data([4, 0, 0, 0, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_replaceSubrange() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data([0xFF, 0xFF]))
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_replaceSubrangeRange() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data([0xFF, 0xFF]))
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_replaceSubrangeWithBuffer() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0) }
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_replaceSubrangeWithCollection() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            data.replaceSubrange(range, with: bytes)
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_slice_cow_mutableBacking_replaceSubrangeWithBytes() {
        let baseBytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        var base = baseBytes.withUnsafeBufferPointer {
            return Data(referencing: NSData(bytes: $0.baseAddress!, length: $0.count))
        }
        base.append(contentsOf: [7, 8, 9])
        var data = base[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBytes { data.replaceSubrange(range, with: $0.baseAddress!, count: 2) }
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }
    
    func test_validateMutation_customBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[5] = 0xFF
        }
        XCTAssertEqual(data, Data([1, 1, 1, 1, 1, 0xFF, 1, 1, 1, 1]))
    }
    
#if false // this requires factory patterns
    func test_validateMutation_customBacking_appendBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_customBacking_appendData() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        data.append(Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_customBacking_appendBuffer() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { (buffer) in
            data.append(buffer)
        }
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0xFF, 0xFF]))
        
    }
    
    func test_validateMutation_customBacking_appendSequence() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        data.append(contentsOf: repeatElement(UInt8(0xFF), count: 2))
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_customBacking_appendContentsOf() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        data.append(contentsOf: [0xFF, 0xFF])
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_customBacking_resetBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0, 0, 0, 1, 1]))
    }
    
    func test_validateMutation_customBacking_replaceSubrange() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        let range: Range<Int> = 1..<4
        data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1, 1, 1, 1, 1, 1]))
    }
    
    func test_validateMutation_customBacking_replaceSubrangeRange() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        let range: Range<Int> = 1..<4
        data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1, 1, 1, 1, 1, 1]))
    }
    
    func test_validateMutation_customBacking_replaceSubrangeWithBuffer() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        let bytes: [UInt8] = [0xFF, 0xFF]
        let range: Range<Int> = 1..<4
        bytes.withUnsafeBufferPointer { (buffer) in
            data.replaceSubrange(range, with: buffer)
        }
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1, 1, 1, 1, 1, 1]))
    }
    
    func test_validateMutation_customBacking_replaceSubrangeWithCollection() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        let range: Range<Int> = 1..<4
        data.replaceSubrange(range, with: [0xFF, 0xFF])
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1, 1, 1, 1, 1, 1]))
    }
    
    func test_validateMutation_customBacking_replaceSubrangeWithBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        let bytes: [UInt8] = [0xFF, 0xFF]
        let range: Range<Int> = 1..<5
        bytes.withUnsafeBufferPointer { (buffer) in
            data.replaceSubrange(range, with: buffer.baseAddress!, count: buffer.count)
        }
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1, 1, 1, 1, 1]))
    }
    
    func test_validateMutation_slice_customBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[1] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
    }
    
    func test_validateMutation_slice_customBacking_appendBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBytes { ptr in
            data.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), count: ptr.count)
        }
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_customBacking_appendData() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        data.append(Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_customBacking_appendBuffer() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { (buffer) in
            data.append(buffer)
        }
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_customBacking_appendSequence() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        let seq = repeatElement(UInt8(0xFF), count: 2)
        data.append(contentsOf: seq)
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_customBacking_appendContentsOf() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        data.append(contentsOf: [0xFF, 0xFF])
        XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_customBacking_resetBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 1]))
    }
    
    func test_validateMutation_slice_customBacking_replaceSubrange() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
    }
    
    func test_validateMutation_slice_customBacking_replaceSubrangeRange() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
    }
    
    func test_validateMutation_slice_customBacking_replaceSubrangeWithBuffer() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { (buffer) in
            data.replaceSubrange(range, with: buffer)
        }
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
    }
    
    func test_validateMutation_slice_customBacking_replaceSubrangeWithCollection() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: [0xFF, 0xFF])
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
    }
    
    func test_validateMutation_slice_customBacking_replaceSubrangeWithBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBytes { buffer in
            data.replaceSubrange(range, with: buffer.baseAddress!, count: 2)
        }
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
    }
    
    func test_validateMutation_cow_customBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                ptr[5] = 0xFF
            }
            XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0xFF)
        }
    }
    
    func test_validateMutation_cow_customBacking_appendBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { (buffer) in
                data.append(buffer.baseAddress!, count: buffer.count)
            }
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_cow_customBacking_appendData() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            data.append(Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_cow_customBacking_appendBuffer() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.append($0) }
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_cow_customBacking_appendSequence() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            data.append(contentsOf: repeatElement(UInt8(0xFF), count: 2))
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_cow_customBacking_appendContentsOf() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            data.append(contentsOf: [0xFF, 0xFF])
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_cow_customBacking_resetBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0, 0, 0, 1, 1]))
        }
    }
    
    func test_validateMutation_cow_customBacking_replaceSubrange() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
        }
    }
    
    func test_validateMutation_cow_customBacking_replaceSubrangeRange() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
        }
    }
    
    func test_validateMutation_cow_customBacking_replaceSubrangeWithBuffer() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0) }
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
        }
    }
    
    func test_validateMutation_cow_customBacking_replaceSubrangeWithCollection() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: [0xFF, 0xFF])
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
        }
    }
    
    func test_validateMutation_cow_customBacking_replaceSubrangeWithBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            bytes.withUnsafeBytes {
                data.replaceSubrange(range, with: $0.baseAddress!, count: $0.count)
            }
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                ptr[1] = 0xFF
            }
            XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_appendBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { (buffer) in
                data.append(buffer.baseAddress!, count: buffer.count)
            }
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_appendData() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            data.append(Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_appendBuffer() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.append($0) }
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_appendSequence() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            data.append(contentsOf: repeatElement(UInt8(0xFF), count: 2))
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_appendContentsOf() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            data.append(contentsOf: [0xFF, 0xFF])
            XCTAssertEqual(data, Data(bytes: [1, 1, 1, 1, 1, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_resetBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 1]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_replaceSubrange() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_replaceSubrangeRange() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_replaceSubrangeWithBuffer() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0) }
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_replaceSubrangeWithCollection() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: [0xFF, 0xFF])
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
        }
    }
    
    func test_validateMutation_slice_cow_customBacking_replaceSubrangeWithBytes() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<9]
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBytes {
                data.replaceSubrange(range, with: $0.baseAddress!, count: $0.count)
            }
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 1]))
        }
    }
    
    func test_validateMutation_customMutableBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[5] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0xFF)
    }
    
    func test_validateMutation_customMutableBacking_appendBytes() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_customMutableBacking_appendData() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        data.append(Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_customMutableBacking_appendBuffer() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_customMutableBacking_appendSequence() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        data.append(contentsOf: repeatElement(UInt8(0xFF), count: 2))
        XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_customMutableBacking_appendContentsOf() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        data.append(contentsOf: [0xFF, 0xFF])
        XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_customMutableBacking_resetBytes() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data.count, 10)
        XCTAssertEqual(data[data.startIndex.advanced(by: 0)], 1)
        XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0)
        XCTAssertEqual(data[data.startIndex.advanced(by: 6)], 0)
        XCTAssertEqual(data[data.startIndex.advanced(by: 7)], 0)
    }
    
    func test_validateMutation_customMutableBacking_replaceSubrange() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 0]))
    }
    
    func test_validateMutation_customMutableBacking_replaceSubrangeRange() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 0]))
    }
    
    func test_validateMutation_customMutableBacking_replaceSubrangeWithBuffer() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0) }
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 0]))
    }
    
    func test_validateMutation_customMutableBacking_replaceSubrangeWithCollection() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: [0xFF, 0xFF])
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 0]))
    }
    
    func test_validateMutation_customMutableBacking_replaceSubrangeWithBytes() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0.baseAddress!, count: $0.count) }
        XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 0]))
    }
    
    func test_validateMutation_slice_customMutableBacking_withUnsafeMutableBytes() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[1] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
    }
    
    func test_validateMutation_slice_customMutableBacking_appendBytes() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(data, Data(bytes: [0, 0, 0, 0, 0, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_customMutableBacking_appendData() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        data.append(Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [0, 0, 0, 0, 0, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_customMutableBacking_appendBuffer() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data, Data(bytes: [0, 0, 0, 0, 0, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_customMutableBacking_appendSequence() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data, Data(bytes: [0, 0, 0, 0, 0, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_customMutableBacking_appendContentsOf() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        data.append(contentsOf: [0xFF, 0xFF])
        XCTAssertEqual(data, Data(bytes: [0, 0, 0, 0, 0, 0xFF, 0xFF]))
    }
    
    func test_validateMutation_slice_customMutableBacking_resetBytes() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        data.resetBytes(in: 5..<8)
        
        XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0)
        XCTAssertEqual(data[data.startIndex.advanced(by: 2)], 0)
        XCTAssertEqual(data[data.startIndex.advanced(by: 3)], 0)
    }
    
    func test_validateMutation_slice_customMutableBacking_replaceSubrange() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [0, 0xFF, 0xFF, 0]))
    }
    
    func test_validateMutation_slice_customMutableBacking_replaceSubrangeRange() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
        XCTAssertEqual(data, Data(bytes: [0, 0xFF, 0xFF, 0]))
    }
    
    func test_validateMutation_slice_customMutableBacking_replaceSubrangeWithBuffer() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0) }
        XCTAssertEqual(data, Data(bytes: [0, 0xFF, 0xFF, 0]))
    }
    
    func test_validateMutation_slice_customMutableBacking_replaceSubrangeWithCollection() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        data.replaceSubrange(range, with: [0xFF, 0xFF])
        XCTAssertEqual(data, Data(bytes: [0, 0xFF, 0xFF, 0]))
    }
    
    func test_validateMutation_slice_customMutableBacking_replaceSubrangeWithBytes() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0.baseAddress!, count: $0.count) }
        XCTAssertEqual(data, Data(bytes: [0, 0xFF, 0xFF, 0]))
    }
    
    func test_validateMutation_cow_customMutableBacking_withUnsafeMutableBytes() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                ptr[5].pointee = 0xFF
            }
            XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0xFF)
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_appendBytes() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
            XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_appendData() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            data.append(Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_appendBuffer() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.append($0) }
            XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_appendSequence() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            data.append(contentsOf: repeatElement(UInt8(0xFF), count: 2))
            XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_appendContentsOf() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            data.append(contentsOf: [0xFF, 0xFF])
            XCTAssertEqual(data, Data(bytes: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_resetBytes() {
        var data = Data(referencing: AllOnesData(length: 10))
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data.count, 10)
            XCTAssertEqual(data[data.startIndex.advanced(by: 0)], 1)
            XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0)
            XCTAssertEqual(data[data.startIndex.advanced(by: 6)], 0)
            XCTAssertEqual(data[data.startIndex.advanced(by: 7)], 0)
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_replaceSubrange() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 0])) 
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_replaceSubrangeRange() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 0])) 
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_replaceSubrangeWithBuffer() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0) }
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 0])) 
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_replaceSubrangeWithCollection() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: [0xFF, 0xFF])
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 0])) 
        }
    }
    
    func test_validateMutation_cow_customMutableBacking_replaceSubrangeWithBytes() {
        var data = Data(referencing: AllOnesData(length: 1))
        data.count = 10
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0.baseAddress!, count: $0.count) }
            XCTAssertEqual(data, Data(bytes: [1, 0xFF, 0xFF, 0])) 
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_withUnsafeMutableBytes() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
                ptr[1] = 0xFF
            }
            XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_appendBytes() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
            XCTAssertEqual(data, Data(bytes: [0, 0, 0, 0, 0, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_appendData() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            data.append(Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [0, 0, 0, 0, 0, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_appendBuffer() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.append($0) }
            XCTAssertEqual(data, Data(bytes: [0, 0, 0, 0, 0, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_appendSequence() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            data.append(contentsOf: repeatElement(UInt8(0xFF), count: 2))
            XCTAssertEqual(data, Data(bytes: [0, 0, 0, 0, 0, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_appendContentsOf() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            data.append(contentsOf: [0xFF, 0xFF])
            XCTAssertEqual(data, Data(bytes: [0, 0, 0, 0, 0, 0xFF, 0xFF]))
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_resetBytes() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0)
            XCTAssertEqual(data[data.startIndex.advanced(by: 2)], 0)
            XCTAssertEqual(data[data.startIndex.advanced(by: 3)], 0)
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_replaceSubrange() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [0, 0xFF, 0xFF, 0]))
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_replaceSubrangeRange() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: Data(bytes: [0xFF, 0xFF]))
            XCTAssertEqual(data, Data(bytes: [0, 0xFF, 0xFF, 0]))
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_replaceSubrangeWithBuffer() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0) }
            XCTAssertEqual(data, Data(bytes: [0, 0xFF, 0xFF, 0]))
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_replaceSubrangeWithCollection() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            data.replaceSubrange(range, with: [0xFF, 0xFF])
            XCTAssertEqual(data, Data(bytes: [0, 0xFF, 0xFF, 0]))
        }
    }
    
    func test_validateMutation_slice_cow_customMutableBacking_replaceSubrangeWithBytes() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<9]
        holdReference(data) {
            let range: Range<Int> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.replaceSubrange(range, with: $0.baseAddress!, count: $0.count) }
            XCTAssertEqual(data, Data(bytes: [0, 0xFF, 0xFF, 0]))
        }
    }
#endif
    
    func test_sliceHash() {
        let base1 = Data([0, 0xFF, 0xFF, 0])
        let base2 = Data([0, 0xFF, 0xFF, 0])
        let base3 = Data([0xFF, 0xFF, 0xFF, 0])
        let sliceEmulation = Data([0xFF, 0xFF])
        XCTAssertEqual(base1.hashValue, base2.hashValue)
        let slice1 = base1[base1.startIndex.advanced(by: 1)..<base1.endIndex.advanced(by: -1)]
        let slice2 = base2[base2.startIndex.advanced(by: 1)..<base2.endIndex.advanced(by: -1)]
        let slice3 = base3[base3.startIndex.advanced(by: 1)..<base3.endIndex.advanced(by: -1)]
        XCTAssertEqual(slice1.hashValue, sliceEmulation.hashValue)
        XCTAssertEqual(slice1.hashValue, slice2.hashValue)
        XCTAssertEqual(slice2.hashValue, slice3.hashValue)
    }

    func test_slice_resize_growth() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        data.resetBytes(in: data.endIndex.advanced(by: -1)..<data.endIndex.advanced(by: 1))
        XCTAssertEqual(data, Data([4, 5, 6, 7, 0, 0]))
    }
    
    /*
    func test_sliceEnumeration() {
        var base = DispatchData.empty
        let bytes: [UInt8] = [0, 1, 2, 3, 4]
        base.append(bytes.withUnsafeBytes { DispatchData(bytes: $0) })
        base.append(bytes.withUnsafeBytes { DispatchData(bytes: $0) })
        base.append(bytes.withUnsafeBytes { DispatchData(bytes: $0) })
        let data = ((base as AnyObject) as! Data)[3..<11]
        var regionRanges: [Range<Int>] = []
        var regionData: [Data] = []
        data.enumerateBytes { (buffer, index, _) in
            regionData.append(Data(bytes: buffer.baseAddress!, count: buffer.count))
            regionRanges.append(index..<index + buffer.count)
        }
        XCTAssertEqual(regionRanges.count, 3)
        XCTAssertEqual(Range<Data.Index>(3..<5), regionRanges[0])
        XCTAssertEqual(Range<Data.Index>(5..<10), regionRanges[1])
        XCTAssertEqual(Range<Data.Index>(10..<11), regionRanges[2])
        XCTAssertEqual(Data(bytes: [3, 4]), regionData[0]) //fails
        XCTAssertEqual(Data(bytes: [0, 1, 2, 3, 4]), regionData[1]) //passes
        XCTAssertEqual(Data(bytes: [0]), regionData[2]) //fails
    }
 */
    
    func test_sliceInsertion() {
        // https://bugs.swift.org/browse/SR-5810
        let baseData = Data([0, 1, 2, 3, 4, 5])
        var sliceData = baseData[2..<4]
        let sliceDataEndIndexBeforeInsertion = sliceData.endIndex
        let elementToInsert: UInt8 = 0x07
        sliceData.insert(elementToInsert, at: sliceData.startIndex)
        XCTAssertEqual(sliceData.first, elementToInsert)
        XCTAssertEqual(sliceData.startIndex, 2)
        XCTAssertEqual(sliceDataEndIndexBeforeInsertion, 4)
        XCTAssertEqual(sliceData.endIndex, sliceDataEndIndexBeforeInsertion + 1)
    }
    
    func test_sliceDeletion() {
        // https://bugs.swift.org/browse/SR-5810
        let baseData = Data([0, 1, 2, 3, 4, 5, 6, 7])
        let sliceData = baseData[2..<6]
        var mutableSliceData = sliceData
        let numberOfElementsToDelete = 2
        let subrangeToDelete = mutableSliceData.startIndex..<mutableSliceData.startIndex.advanced(by: numberOfElementsToDelete)
        mutableSliceData.removeSubrange(subrangeToDelete)
        XCTAssertEqual(sliceData[sliceData.startIndex + numberOfElementsToDelete], mutableSliceData.first)
        XCTAssertEqual(mutableSliceData.startIndex, 2)
        XCTAssertEqual(mutableSliceData.endIndex, sliceData.endIndex - numberOfElementsToDelete)
    }
    
    func test_validateMutation_slice_withUnsafeMutableBytes_lengthLessThanLowerBound() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<6]
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[1] = 0xFF
        }
        XCTAssertEqual(data, Data([4, 0xFF]))
    }
    
    func test_validateMutation_slice_immutableBacking_withUnsafeMutableBytes_lengthLessThanLowerBound() {
        var data = Data(referencing: NSData(bytes: "hello world", length: 11))[4..<6]
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[1] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
    }

    func test_validateMutation_slice_mutableBacking_withUnsafeMutableBytes_lengthLessThanLowerBound() {
        var base = Data(referencing: NSData(bytes: "hello world", length: 11))
        base.append(contentsOf: [1, 2, 3, 4, 5, 6])
        var data = base[4..<6]
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[1] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
    }

    func test_validateMutation_slice_customBacking_withUnsafeMutableBytes_lengthLessThanLowerBound() {
        var data = Data(referencing: AllOnesImmutableData(length: 10))[4..<6]
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[1] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
    }

    func test_validateMutation_slice_customMutableBacking_withUnsafeMutableBytes_lengthLessThanLowerBound() {
        var base = Data(referencing: AllOnesData(length: 1))
        base.count = 10
        var data = base[4..<6]
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            ptr[1] = 0xFF
        }
        XCTAssertEqual(data[data.startIndex.advanced(by: 1)], 0xFF)
    }

    func testCustomData() {
        let length = 5
        let allOnesData = Data(referencing: AllOnesData(length: length))
        XCTAssertEqual(1, allOnesData[0], "First byte of all 1s data should be 1")

        // Double the length
        var allOnesCopyToMutate = allOnesData
        allOnesCopyToMutate.count = allOnesData.count * 2

        XCTAssertEqual(allOnesData.count, length, "The length of the initial data should not have changed")
        XCTAssertEqual(allOnesCopyToMutate.count, length * 2, "The length should have changed")

        // Force the second data to create its storage
        allOnesCopyToMutate.withUnsafeMutableBytes { (bytes : UnsafeMutableRawBufferPointer) in
            XCTAssertEqual(bytes[0], 1, "First byte should be 1")

            // Mutate the second data
            bytes[0] = 0
            XCTAssertEqual(bytes[0], 0, "First byte should be 0")

        }
        XCTAssertEqual(allOnesCopyToMutate[0], 0, "First byte accessed via other method should still be 0")

        // Verify that the first data is still 1
        XCTAssertEqual(allOnesData[0], 1, "The first byte should still be 1")
    }
 
    func testBridgingCustom() {
        // Let's use an AllOnesData with some Objective-C code
        let allOnes = AllOnesData(length: 64)

        // Type-erased
        let data = Data(referencing: allOnes)

        // Create a home for our test data
        let dirPath = FileManager.default.temporaryDirectory.appendingPathComponent("TestFoundation_Playground_" + UUID().uuidString)
        try! FileManager.default.createDirectory(atPath: dirPath.path, withIntermediateDirectories: true, attributes: nil)
        let filePath = dirPath.appendingPathComponent("temp_file")
        guard FileManager.default.createFile(atPath: filePath.path, contents: nil, attributes: nil) else { XCTAssertTrue(false, "Unable to create temporary file"); return}
        guard let fh = FileHandle(forWritingAtPath: filePath.path) else { XCTAssertTrue(false, "Unable to open temporary file"); return }
        defer {
          fh.closeFile()
          try! FileManager.default.removeItem(atPath: dirPath.path)
        }

        // Now use this data with some Objective-C code that takes NSData arguments
        fh.write(data)

        // Get the data back
        do {
            let url = URL(fileURLWithPath: filePath.path)
            let readData = try Data.init(contentsOf: url)
            XCTAssertEqual(data.count, readData.count, "The length of the data is not the same")
        } catch {
            XCTAssertTrue(false, "Unable to read back data")
            return
        }
    }

    func test_discontiguousEnumerateBytes() {
        let dataToEncode = "Hello World".data(using: .utf8)!

        let subdata1 = dataToEncode.withUnsafeBytes { bytes in
            return DispatchData(bytes: bytes)
        }
        let subdata2 = dataToEncode.withUnsafeBytes { bytes in
            return DispatchData(bytes: bytes)
        }
        var data = subdata1
        data.append(subdata2)

        var numChunks = 0
        var offsets = [Int]()
        data.enumerateBytes() { buffer, offset, stop in
            numChunks += 1
            offsets.append(offset)
        }

        XCTAssertEqual(2, numChunks, "composing two dispatch_data should enumerate as structural data as 2 chunks")
        XCTAssertEqual(0, offsets[0], "composing two dispatch_data should enumerate as structural data with the first offset as the location of the region")
        XCTAssertEqual(dataToEncode.count, offsets[1], "composing two dispatch_data should enumerate as structural data with the first offset as the location of the region")
    }

    func test_doubleDeallocation() {
        var data = "12345679".data(using: .utf8)!
        let len = data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) -> Int in
            let slice = Data(bytesNoCopy: bytes.baseAddress!, count: 1, deallocator: .none)
            return slice.count
        }
        XCTAssertEqual(len, 1)
    }

    func test_rangeZoo() {
        let r1: Range = 0..<1
        let r2: Range = 0..<1
        let r3 = ClosedRange(0..<1)
        let r4 = ClosedRange(0..<1)

        let data = Data([8, 1, 2, 3, 4])
        let slice1: Data = data[r1]
        let slice2: Data = data[r2]
        let slice3: Data = data[r3]
        let slice4: Data = data[r4]
        XCTAssertEqual(slice1[0], 8)
        XCTAssertEqual(slice2[0], 8)
        XCTAssertEqual(slice3[0], 8)
        XCTAssertEqual(slice4[0], 8)
    }

    func test_sliceIndexing() {
        let d = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        let slice = d[5..<10]
        XCTAssertEqual(slice[5], d[5])
    }

    func test_sliceEquality() {
        let d = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        let slice = d[5..<7]
        let expected = Data([5, 6])
        XCTAssertEqual(expected, slice)
    }

    func test_sliceEquality2() {
        let d = Data([5, 6, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        let slice1 = d[0..<2]
        let slice2 = d[5..<7]
        XCTAssertEqual(slice1, slice2)
    }

    func test_splittingHttp() {
        func split(_ data: Data, on delimiter: String) -> [Data] {
            let dataDelimiter = delimiter.data(using: .utf8)!
            var found = [Data]()
            let start = data.startIndex
            let end = data.endIndex.advanced(by: -dataDelimiter.count)
            guard end >= start else { return [data] }
            var index = start
            var previousIndex = index
            while index < end {
                let slice = data[index..<index.advanced(by: dataDelimiter.count)]

                if slice == dataDelimiter {
                    found.append(data[previousIndex..<index])
                    previousIndex = index + dataDelimiter.count
                }

                index = index.advanced(by: 1)
            }
            if index < data.endIndex { found.append(data[index..<index]) }
            return found
        }
        let data = "GET /index.html HTTP/1.1\r\nHost: www.example.com\r\n\r\n".data(using: .utf8)!
        let fields = split(data, on: "\r\n")
        let splitFields = fields.map { String(data:$0, encoding: .utf8)! }
        XCTAssertEqual([
            "GET /index.html HTTP/1.1",
            "Host: www.example.com",
            ""
            ], splitFields)
    }

    func test_map() {
        let d1 = Data([81, 0, 0, 0, 14])
        let d2 = d1[1...4]
        XCTAssertEqual(4, d2.count)
        let expected: [UInt8] = [0, 0, 0, 14]
        let actual = d2.map { $0 }
        XCTAssertEqual(expected, actual)
    }

    func test_dropFirst() {
        let data = Data([0, 1, 2, 3, 4, 5])
        let sliced = data.dropFirst()
        XCTAssertEqual(data.count - 1, sliced.count)
        XCTAssertEqual(UInt8(1), sliced[1])
        XCTAssertEqual(UInt8(2), sliced[2])
        XCTAssertEqual(UInt8(3), sliced[3])
        XCTAssertEqual(UInt8(4), sliced[4])
        XCTAssertEqual(UInt8(5), sliced[5])
    }

    func test_dropFirst2() {
        let data = Data([0, 1, 2, 3, 4, 5])
        let sliced = data.dropFirst(2)
        XCTAssertEqual(data.count - 2, sliced.count)
        XCTAssertEqual(UInt8(2), sliced[2])
        XCTAssertEqual(UInt8(3), sliced[3])
        XCTAssertEqual(UInt8(4), sliced[4])
        XCTAssertEqual(UInt8(5), sliced[5])
    }

    func test_copyBytes1() {
        var array: [UInt8] = [0, 1, 2, 3]
        let data = Data(array)

        array.withUnsafeMutableBufferPointer {
            data[1..<3].copyBytes(to: $0.baseAddress!, from: 1..<3)
        }
        XCTAssertEqual([UInt8(1), UInt8(2), UInt8(2), UInt8(3)], array)
    }

    func test_copyBytes2() {
        let array: [UInt8] = [0, 1, 2, 3]
        let data = Data(array)

        let expectedSlice = array[1..<3]

        let start = data.index(after: data.startIndex)
        let end = data.index(before: data.endIndex)
        let slice = data[start..<end]
        XCTAssertEqual(expectedSlice[expectedSlice.startIndex], slice[slice.startIndex])
    }

    func test_sliceOfSliceViaRangeExpression() {
        let data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])

        let slice = data[2..<7]

        let sliceOfSlice1 = slice[..<(slice.startIndex + 2)] // this triggers the range expression
        let sliceOfSlice2 = slice[(slice.startIndex + 2)...] // also triggers range expression
        XCTAssertEqual(Data([2, 3]), sliceOfSlice1)
        XCTAssertEqual(Data([4, 5, 6]), sliceOfSlice2)
    }

    func test_appendingSlices() {
        let d1 = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let slice = d1[1..<2]
        var d2 = Data()
        d2.append(slice)
        XCTAssertEqual(Data([1]), slice)
    }
    
    // This test uses `repeatElement` to produce a sequence -- the produced sequence reports its actual count as its `.underestimatedCount`.
    func test_appendingNonContiguousSequence_exactCount() {
        var d = Data()
        
        // d should go from .empty representation to .inline.
        // Appending a small enough sequence to fit in .inline should actually be copied.
        d.append(contentsOf: 0x00...0x01)
        expectEqual(Data([0x00, 0x01]), d)
        
        // Appending another small sequence should similarly still work.
        d.append(contentsOf: 0x02...0x02)
        expectEqual(Data([0x00, 0x01, 0x02]), d)
        
        // If we append a sequence of elements larger than a single InlineData, the internal append here should buffer.
        // We want to make sure that buffering in this way does not accidentally drop trailing elements on the floor.
        d.append(contentsOf: 0x03...0x2F)
        expectEqual(Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                          0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
                          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
                          0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
                          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
                          0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F]), d)
    }
    
    // This test is like test_appendingNonContiguousSequence_exactCount but uses a sequence which reports 0 for its `.underestimatedCount`.
    // This attempts to hit the worst-case scenario of `Data.append<S>(_:)` -- a discontiguous sequence of unknown length.
    func test_appendingNonContiguousSequence_underestimatedCount() {
        var d = Data()
        
        // d should go from .empty representation to .inline.
        // Appending a small enough sequence to fit in .inline should actually be copied.
        d.append(contentsOf: (0x00...0x01).makeIterator()) // `.makeIterator()` produces a sequence whose `.underestimatedCount` is 0.
        expectEqual(Data([0x00, 0x01]), d)
        
        // Appending another small sequence should similarly still work.
        d.append(contentsOf: (0x02...0x02).makeIterator()) // `.makeIterator()` produces a sequence whose `.underestimatedCount` is 0.
        expectEqual(Data([0x00, 0x01, 0x02]), d)
        
        // If we append a sequence of elements larger than a single InlineData, the internal append here should buffer.
        // We want to make sure that buffering in this way does not accidentally drop trailing elements on the floor.
        d.append(contentsOf: (0x03...0x2F).makeIterator()) // `.makeIterator()` produces a sequence whose `.underestimatedCount` is 0.
        expectEqual(Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                          0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
                          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
                          0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
                          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
                          0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F]), d)
    }

    func test_sequenceInitializers() {
        let seq = repeatElement(UInt8(0x02), count: 3) // ensure we fall into the sequence case

        let dataFromSeq = Data(seq)
        XCTAssertEqual(3, dataFromSeq.count)
        XCTAssertEqual(UInt8(0x02), dataFromSeq[0])
        XCTAssertEqual(UInt8(0x02), dataFromSeq[1])
        XCTAssertEqual(UInt8(0x02), dataFromSeq[2])

        let array: [UInt8] = [0, 1, 2, 3, 4, 5, 6]

        let dataFromArray = Data(array)
        XCTAssertEqual(array.count, dataFromArray.count)
        XCTAssertEqual(array[0], dataFromArray[0])
        XCTAssertEqual(array[1], dataFromArray[1])
        XCTAssertEqual(array[2], dataFromArray[2])
        XCTAssertEqual(array[3], dataFromArray[3])

        let slice = array[1..<4]

        let dataFromSlice = Data(slice)
        XCTAssertEqual(slice.count, dataFromSlice.count)
        XCTAssertEqual(slice.first, dataFromSlice.first)
        XCTAssertEqual(slice.last, dataFromSlice.last)

        let data = Data([1, 2, 3, 4, 5, 6, 7, 8, 9])

        let dataFromData = Data(data)
        XCTAssertEqual(data, dataFromData)

        let sliceOfData = data[1..<3]

        let dataFromSliceOfData = Data(sliceOfData)
        XCTAssertEqual(sliceOfData, dataFromSliceOfData)
    }

    func test_reversedDataInit() {
        let data = Data([1, 2, 3, 4, 5, 6, 7, 8, 9])
        let reversedData = Data(data.reversed())
        let expected = Data([9, 8, 7, 6, 5, 4, 3, 2, 1])
        XCTAssertEqual(expected, reversedData)
    }

    func test_replaceSubrangeReferencingMutable() {
        let mdataObj = NSMutableData(bytes: [0x01, 0x02, 0x03, 0x04], length: 4)
        var data = Data(referencing: mdataObj)
        let expected = data.count
        data.replaceSubrange(4 ..< 4, with: Data([]))
        XCTAssertEqual(expected, data.count)
        data.replaceSubrange(4 ..< 4, with: Data([]))
        XCTAssertEqual(expected, data.count)
    }

    func test_replaceSubrangeReferencingImmutable() {
        let dataObj = NSData(bytes: [0x01, 0x02, 0x03, 0x04], length: 4)
        var data = Data(referencing: dataObj)
        let expected = data.count
        data.replaceSubrange(4 ..< 4, with: Data([]))
        XCTAssertEqual(expected, data.count)
        data.replaceSubrange(4 ..< 4, with: Data([]))
        XCTAssertEqual(expected, data.count)
    }

    func test_rangeOfSlice() {
        let data = "FooBar".data(using: .utf8)!
        let slice = data[3...] // Bar
        let range = slice.range(of: "a".data(using: .utf8)!)
        XCTAssertEqual(range, 4..<5)
    }

    func test_nskeyedarchiving() {
        let bytes: [UInt8] = [0xd, 0xe, 0xa, 0xd, 0xb, 0xe, 0xe, 0xf]
        let data = NSData(bytes: bytes, length: bytes.count)

        let archiver = NSKeyedArchiver()
        data.encode(with: archiver)
        let encodedData = archiver.encodedData

        let unarchiver = NSKeyedUnarchiver(forReadingWith: encodedData)
        let decodedData = NSData(coder: unarchiver)
        XCTAssertEqual(data, decodedData)
    }

    func test_nsdataSequence() {
        if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
            let bytes: [UInt8] = Array(0x00...0xFF)
            let data = bytes.withUnsafeBytes { NSData(bytes: $0.baseAddress, length: $0.count) }

            for byte in bytes {
                expectEqual(data[Int(byte)], byte)
            }
        }
    }

    func test_dispatchSequence() {
        if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
            let bytes1: [UInt8] = Array(0x00..<0xF0)
            let bytes2: [UInt8] = Array(0xF0..<0xFF)
            var data = DispatchData.empty
            bytes1.withUnsafeBytes {
                data.append($0)
            }
            bytes2.withUnsafeBytes {
                data.append($0)
            }

            for byte in bytes1 {
                expectEqual(data[Int(byte)], byte)
            }
            for byte in bytes2 {
                expectEqual(data[Int(byte)], byte)
            }
        }
    }

    func test_Data_increaseCount() {
         guard #available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *) else { return }
         let initials: [Range<UInt8>] = [
             0..<0,
             0..<2,
             0..<4,
             0..<8,
             0..<16,
             0..<32,
             0..<64
         ]
         let diffs = [0, 1, 2, 4, 8, 16, 32]
         for initial in initials {
             for diff in diffs {
                 var data = Data(initial)
                 data.count += diff
                 XCTAssertEqual(
                     Data(Array(initial) + Array(repeating: 0, count: diff)),
                     data)
             }
         }
     }

     func test_Data_decreaseCount() {
         guard #available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *) else { return }
         let initials: [Range<UInt8>] = [
             0..<0,
             0..<2,
             0..<4,
             0..<8,
             0..<16,
             0..<32,
             0..<64
         ]
         let diffs = [0, 1, 2, 4, 8, 16, 32]
         for initial in initials {
             for diff in diffs {
                 guard initial.count >= diff else { continue }
                 var data = Data(initial)
                 data.count -= diff
                 XCTAssertEqual(
                     Data(initial.dropLast(diff)),
                     data)
             }
         }
     }
}

