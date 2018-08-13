// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

import CoreFoundation

#if os(macOS) || os(iOS)
internal let kCFStringEncodingMacRoman =  CFStringBuiltInEncodings.macRoman.rawValue
internal let kCFStringEncodingWindowsLatin1 =  CFStringBuiltInEncodings.windowsLatin1.rawValue
internal let kCFStringEncodingISOLatin1 =  CFStringBuiltInEncodings.isoLatin1.rawValue
internal let kCFStringEncodingNextStepLatin =  CFStringBuiltInEncodings.nextStepLatin.rawValue
internal let kCFStringEncodingASCII =  CFStringBuiltInEncodings.ASCII.rawValue
internal let kCFStringEncodingUnicode =  CFStringBuiltInEncodings.unicode.rawValue
internal let kCFStringEncodingUTF8 =  CFStringBuiltInEncodings.UTF8.rawValue
internal let kCFStringEncodingNonLossyASCII =  CFStringBuiltInEncodings.nonLossyASCII.rawValue
internal let kCFStringEncodingUTF16 = CFStringBuiltInEncodings.UTF16.rawValue
internal let kCFStringEncodingUTF16BE =  CFStringBuiltInEncodings.UTF16BE.rawValue
internal let kCFStringEncodingUTF16LE =  CFStringBuiltInEncodings.UTF16LE.rawValue
internal let kCFStringEncodingUTF32 =  CFStringBuiltInEncodings.UTF32.rawValue
internal let kCFStringEncodingUTF32BE =  CFStringBuiltInEncodings.UTF32BE.rawValue
internal let kCFStringEncodingUTF32LE =  CFStringBuiltInEncodings.UTF32LE.rawValue
#endif


class TestNSString: LoopbackServerTest {
    
    static var allTests: [(String, (TestNSString) -> () throws -> Void)] {
        return [
            ("test_boolValue", test_boolValue ),
            ("test_BridgeConstruction", test_BridgeConstruction ),
            ("test_integerValue", test_integerValue ),
            ("test_intValue", test_intValue ),
            ("test_doubleValue", test_doubleValue),
            ("test_isEqualToStringWithSwiftString", test_isEqualToStringWithSwiftString ),
            ("test_isEqualToObjectWithNSString", test_isEqualToObjectWithNSString ),
            ("test_isNotEqualToObjectWithNSNumber", test_isNotEqualToObjectWithNSNumber ),
            ("test_FromASCIIData", test_FromASCIIData ),
            ("test_FromUTF8Data", test_FromUTF8Data ),
            ("test_FromMalformedUTF8Data", test_FromMalformedUTF8Data ),
            ("test_FromASCIINSData", test_FromASCIINSData ),
            ("test_FromUTF8NSData", test_FromUTF8NSData ),
            ("test_FromMalformedUTF8NSData", test_FromMalformedUTF8NSData ),
            ("test_FromNullTerminatedCStringInASCII", test_FromNullTerminatedCStringInASCII ),
            ("test_FromNullTerminatedCStringInUTF8", test_FromNullTerminatedCStringInUTF8 ),
            ("test_FromMalformedNullTerminatedCStringInUTF8", test_FromMalformedNullTerminatedCStringInUTF8 ),
            ("test_uppercaseString", test_uppercaseString ),
            ("test_lowercaseString", test_lowercaseString ),
            ("test_capitalizedString", test_capitalizedString ),
            ("test_longLongValue", test_longLongValue ),
            ("test_rangeOfCharacterFromSet", test_rangeOfCharacterFromSet ),
            ("test_CFStringCreateMutableCopy", test_CFStringCreateMutableCopy),
            ("test_FromContentsOfURL",test_FromContentsOfURL),
            ("test_FromContentOfFileUsedEncodingIgnored", test_FromContentOfFileUsedEncodingIgnored),
            ("test_FromContentOfFileUsedEncodingUTF8", test_FromContentOfFileUsedEncodingUTF8),
            ("test_FromContentsOfURLUsedEncodingUTF16BE", test_FromContentsOfURLUsedEncodingUTF16BE),
            ("test_FromContentsOfURLUsedEncodingUTF16LE", test_FromContentsOfURLUsedEncodingUTF16LE),
            ("test_FromContentsOfURLUsedEncodingUTF32BE", test_FromContentsOfURLUsedEncodingUTF32BE),
            ("test_FromContentsOfURLUsedEncodingUTF32LE", test_FromContentsOfURLUsedEncodingUTF32LE),
            ("test_FromContentOfFile",test_FromContentOfFile),
            ("test_swiftStringUTF16", test_swiftStringUTF16),
            // This test takes forever on build servers; it has been seen up to 1852.084 seconds
//            ("test_completePathIntoString", test_completePathIntoString),
            ("test_stringByTrimmingCharactersInSet", test_stringByTrimmingCharactersInSet),
            ("test_initializeWithFormat", test_initializeWithFormat),
            ("test_initializeWithFormat2", test_initializeWithFormat2),
            ("test_initializeWithFormat3", test_initializeWithFormat3),
            ("test_appendingPathComponent", test_appendingPathComponent),
            ("test_deletingLastPathComponent", test_deletingLastPathComponent),
            ("test_getCString_simple", test_getCString_simple),
            ("test_getCString_nonASCII_withASCIIAccessor", test_getCString_nonASCII_withASCIIAccessor),
            ("test_NSHomeDirectoryForUser", test_NSHomeDirectoryForUser),
            ("test_resolvingSymlinksInPath", test_resolvingSymlinksInPath),
            ("test_expandingTildeInPath", test_expandingTildeInPath),
            ("test_standardizingPath", test_standardizingPath),
            ("test_addingPercentEncoding", test_addingPercentEncoding),
            ("test_removingPercentEncodingInLatin", test_removingPercentEncodingInLatin),
            ("test_removingPercentEncodingInNonLatin", test_removingPercentEncodingInNonLatin),
            ("test_removingPersentEncodingWithoutEncoding", test_removingPersentEncodingWithoutEncoding),
            ("test_addingPercentEncodingAndBack", test_addingPercentEncodingAndBack),
            ("test_stringByAppendingPathExtension", test_stringByAppendingPathExtension),
            ("test_deletingPathExtension", test_deletingPathExtension),
            ("test_ExternalRepresentation", test_ExternalRepresentation),
            ("test_mutableStringConstructor", test_mutableStringConstructor),
            ("test_emptyStringPrefixAndSuffix",test_emptyStringPrefixAndSuffix),
            ("test_reflection", { _ in test_reflection }),
            ("test_replacingOccurrences", test_replacingOccurrences),
            ("test_getLineStart", test_getLineStart),
            ("test_substringWithRange", test_substringWithRange),
            ("test_createCopy", test_createCopy),
            ("test_AnyHashable", test_AnyHashable),
        ]
    }

    func test_boolValue() {
        let trueStrings: [NSString] = ["t", "true", "TRUE", "tRuE", "yes", "YES", "1", "+000009"]
        for string in trueStrings {
            XCTAssert(string.boolValue)
        }
        let falseStrings: [NSString] = ["false", "FALSE", "fAlSe", "no", "NO", "0", "<true>", "_true", "-00000", "+t", "+", "0t", "++"]
        for string in falseStrings {
            XCTAssertFalse(string.boolValue)
        }
    }
    
    func test_BridgeConstruction() {
        let literalConversion: NSString = "literal"
        XCTAssertEqual(literalConversion.length, 7)
        
        let nonLiteralConversion = NSString(string: "test\(self)")
        XCTAssertTrue(nonLiteralConversion.length > 4)
        
        let nonLiteral2 = NSString(string: String(4))
        let t = nonLiteral2.character(at: 0)
        XCTAssertTrue(t == 52)
        
        let externalString: NSString = NSString(string: String.localizedName(of: String.defaultCStringEncoding))
        XCTAssertTrue(externalString.length >= 4)
        
        let cluster: NSString = "✌🏾"
        XCTAssertEqual(cluster.length, 3)
    }

    func test_integerValue() {
        let string1: NSString = "123"
        XCTAssertEqual(string1.integerValue, 123)

        let string2: NSString = "123a"
        XCTAssertEqual(string2.integerValue, 123)

        let string3: NSString = "-123a"
        XCTAssertEqual(string3.integerValue, -123)

        let string4: NSString = "a123"
        XCTAssertEqual(string4.integerValue, 0)

        let string5: NSString = "+123"
        XCTAssertEqual(string5.integerValue, 123)

        let string6: NSString = "++123"
        XCTAssertEqual(string6.integerValue, 0)

        let string7: NSString = "-123"
        XCTAssertEqual(string7.integerValue, -123)

        let string8: NSString = "--123"
        XCTAssertEqual(string8.integerValue, 0)

        let string9: NSString = "999999999999999999999999999999"
        XCTAssertEqual(string9.integerValue, Int.max)

        let string10: NSString = "-999999999999999999999999999999"
        XCTAssertEqual(string10.integerValue, Int.min)
    }

    func test_intValue() {
        let string1: NSString = "123"
        XCTAssertEqual(string1.intValue, 123)

        let string2: NSString = "123a"
        XCTAssertEqual(string2.intValue, 123)

        let string3: NSString = "-123a"
        XCTAssertEqual(string3.intValue, -123)

        let string4: NSString = "a123"
        XCTAssertEqual(string4.intValue, 0)

        let string5: NSString = "+123"
        XCTAssertEqual(string5.intValue, 123)

        let string6: NSString = "++123"
        XCTAssertEqual(string6.intValue, 0)

        let string7: NSString = "-123"
        XCTAssertEqual(string7.intValue, -123)

        let string8: NSString = "--123"
        XCTAssertEqual(string8.intValue, 0)

        let string9: NSString = "999999999999999999999999999999"
        XCTAssertEqual(string9.intValue, Int32.max)

        let string10: NSString = "-999999999999999999999999999999"
        XCTAssertEqual(string10.intValue, Int32.min)
    }

    func test_doubleValue() {
        XCTAssertEqual(NSString(".2").doubleValue, 0.2)
        XCTAssertEqual(NSString("+.2").doubleValue, 0.2)
        XCTAssertEqual(NSString("-.2").doubleValue, -0.2)
        XCTAssertEqual(NSString("1.23015e+3").doubleValue, 1230.15)
        XCTAssertEqual(NSString("12.3015e+02").doubleValue, 1230.15)
        XCTAssertEqual(NSString("+1.23015e+3").doubleValue, 1230.15)
        XCTAssertEqual(NSString("+12.3015e+02").doubleValue, 1230.15)
        XCTAssertEqual(NSString("-1.23015e+3").doubleValue, -1230.15)
        XCTAssertEqual(NSString("-12.3015e+02").doubleValue, -1230.15)
        XCTAssertEqual(NSString("-12.3015e02").doubleValue, -1230.15)
        XCTAssertEqual(NSString("-31.25e-04").doubleValue, -0.003125)

        XCTAssertEqual(NSString(".e12").doubleValue, 0)
        XCTAssertEqual(NSString("2e3.12").doubleValue, 2000)
        XCTAssertEqual(NSString("1e2.3").doubleValue, 100)
        XCTAssertEqual(NSString("12.e4").doubleValue, 120000)
        XCTAssertEqual(NSString("1.2.3.4").doubleValue, 1.2)
        XCTAssertEqual(NSString("1e2.3").doubleValue, 100)
        XCTAssertEqual(NSString("1E3").doubleValue, 1000)
    }
    
    func test_isEqualToStringWithSwiftString() {
        let string: NSString = "literal"
        let swiftString = "literal"
        XCTAssertTrue(string.isEqual(to: swiftString))
    }
  
    func test_isEqualToObjectWithNSString() {
        let string1: NSString = "literal"
        let string2: NSString = "literal"
        XCTAssertTrue(string1.isEqual(string2))
    }
    
    func test_isNotEqualToObjectWithNSNumber() {
      let string: NSString = "5"
      let number: NSNumber = 5
      XCTAssertFalse(string.isEqual(number))
    }

    internal let mockASCIIStringBytes: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x53, 0x77, 0x69, 0x66, 0x74, 0x21]
    internal let mockASCIIString = "Hello Swift!"
    internal let mockUTF8StringBytes: [UInt8] = [0x49, 0x20, 0xE2, 0x9D, 0xA4, 0xEF, 0xB8, 0x8F, 0x20, 0x53, 0x77, 0x69, 0x66, 0x74]
    internal let mockUTF8String = "I ❤️ Swift"
    internal let mockMalformedUTF8StringBytes: [UInt8] = [0xFF]

    func test_FromASCIIData() {
        let bytes = mockASCIIStringBytes
        let string = NSString(bytes: bytes, length: bytes.count, encoding: String.Encoding.ascii.rawValue)
        XCTAssertNotNil(string)
        XCTAssertTrue(string?.isEqual(to: mockASCIIString) ?? false)
    }

    func test_FromUTF8Data() {
        let bytes = mockUTF8StringBytes
        let string = NSString(bytes: bytes, length: bytes.count, encoding: String.Encoding.utf8.rawValue)
        XCTAssertNotNil(string)
        XCTAssertTrue(string?.isEqual(to: mockUTF8String) ?? false)
    }

    func test_FromMalformedUTF8Data() {
        let bytes = mockMalformedUTF8StringBytes
        let string = NSString(bytes: bytes, length: bytes.count, encoding: String.Encoding.utf8.rawValue)
        XCTAssertNil(string)
    }

    func test_FromASCIINSData() {
        let bytes = mockASCIIStringBytes
        let data = Data(bytes: bytes, count: bytes.count)
        let string = NSString(data: data, encoding: String.Encoding.ascii.rawValue)
        XCTAssertNotNil(string)
        XCTAssertTrue(string?.isEqual(to: mockASCIIString) ?? false)
    }

    func test_FromUTF8NSData() {
        let bytes = mockUTF8StringBytes
        let data = Data(bytes: bytes, count: bytes.count)
        let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        XCTAssertNotNil(string)
        XCTAssertTrue(string?.isEqual(to: mockUTF8String) ?? false)
    }

    func test_FromMalformedUTF8NSData() {
        let bytes = mockMalformedUTF8StringBytes
        let data = Data(bytes: bytes, count: bytes.count)
        let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        XCTAssertNil(string)
    }

    func test_FromNullTerminatedCStringInASCII() {
        let bytes = mockASCIIStringBytes + [0x00]
        let string = NSString(cString: bytes.map { Int8(bitPattern: $0) }, encoding: String.Encoding.ascii.rawValue)
        XCTAssertNotNil(string)
        XCTAssertTrue(string?.isEqual(to: mockASCIIString) ?? false)
    }

    func test_FromNullTerminatedCStringInUTF8() {
        let bytes = mockUTF8StringBytes + [0x00]
        let string = NSString(cString: bytes.map { Int8(bitPattern: $0) }, encoding: String.Encoding.utf8.rawValue)
        XCTAssertNotNil(string)
        XCTAssertTrue(string?.isEqual(to: mockUTF8String) ?? false)
    }

    func test_FromMalformedNullTerminatedCStringInUTF8() {
        let bytes = mockMalformedUTF8StringBytes + [0x00]
        let string = NSString(cString: bytes.map { Int8(bitPattern: $0) }, encoding: String.Encoding.utf8.rawValue)
        XCTAssertNil(string)
    }

    func test_FromContentsOfURL() {
        guard let testFileURL = testBundle().url(forResource: "NSStringTestData", withExtension: "txt") else {
            XCTFail("URL for NSStringTestData.txt is nil")
            return
        }

        do {
            let string = try NSString(contentsOf: testFileURL, encoding: String.Encoding.utf8.rawValue)
            XCTAssertEqual(string, "swift-corelibs-foundation")
        } catch {
            XCTFail("Unable to init NSString from contentsOf:encoding:")
        }
        do {
            let string = try NSString(contentsOf: testFileURL, encoding: String.Encoding.utf16.rawValue)
            XCTAssertNotEqual(string, "swift-corelibs-foundation", "Wrong result when reading UTF-8 file with UTF-16 encoding in contentsOf:encoding")
        } catch {
            XCTFail("Unable to init NSString from contentsOf:encoding:")
        }

        let url = URL(string: "http://127.0.0.1:\(TestURLSession.serverPort)/NSString-ISO-8859-1-data.txt")!
        var enc: UInt = 0
        let contents = try? NSString(contentsOf: url, usedEncoding: &enc)

        XCTAssertNotNil(contents)
        XCTAssertEqual(enc, String.Encoding.isoLatin1.rawValue)
        if let contents = contents {
            XCTAssertEqual(contents, "This file is encoded as ISO-8859-1\nÀÁÂÃÄÅÿ\n±\n")
        }
    }

    func test_FromContentOfFileUsedEncodingIgnored() {
        let testFilePath = testBundle().path(forResource: "NSStringTestData", ofType: "txt")
        XCTAssertNotNil(testFilePath)
        
        do {
            let str = try NSString(contentsOfFile: testFilePath!, usedEncoding: nil)
            XCTAssertEqual(str, "swift-corelibs-foundation")
        } catch {
            XCTFail("Unable to init NSString from contentsOfFile:encoding:")
        }
    }
    
    func test_FromContentOfFileUsedEncodingUTF8() {
        let testFilePath = testBundle().path(forResource: "NSStringTestData", ofType: "txt")
        XCTAssertNotNil(testFilePath)
        
        do {
            var encoding: UInt = 0
            let str = try NSString(contentsOfFile: testFilePath!, usedEncoding: &encoding)
            XCTAssertEqual(str, "swift-corelibs-foundation")
            XCTAssertEqual(encoding, String.Encoding.utf8.rawValue, "Wrong encoding detected from UTF8 file")
        } catch {
            XCTFail("Unable to init NSString from contentsOfFile:encoding:")
        }
    }

    func test_FromContentsOfURLUsedEncodingUTF16BE() {
      guard let testFileURL = testBundle().url(forResource: "NSString-UTF16-BE-data", withExtension: "txt") else {
        XCTFail("URL for NSString-UTF16-BE-data.txt is nil")
        return
      }

      do {
          var encoding: UInt = 0
          let string = try NSString(contentsOf: testFileURL, usedEncoding: &encoding)
          XCTAssertEqual(string, "NSString fromURL usedEncoding test with UTF16 BE file", "Wrong result when reading UTF16BE file")
          XCTAssertEqual(encoding, String.Encoding.utf16BigEndian.rawValue, "Wrong encoding detected from UTF16BE file")
      } catch {
          XCTFail("Unable to init NSString from contentsOf:usedEncoding:")
      }
    }

    func test_FromContentsOfURLUsedEncodingUTF16LE() {
      guard let testFileURL = testBundle().url(forResource: "NSString-UTF16-LE-data", withExtension: "txt") else {
        XCTFail("URL for NSString-UTF16-LE-data.txt is nil")
        return
      }

      do {
          var encoding: UInt = 0
          let string = try NSString(contentsOf: testFileURL, usedEncoding: &encoding)
          XCTAssertEqual(string, "NSString fromURL usedEncoding test with UTF16 LE file", "Wrong result when reading UTF16LE file")
          XCTAssertEqual(encoding, String.Encoding.utf16LittleEndian.rawValue, "Wrong encoding detected from UTF16LE file")
      } catch {
          XCTFail("Unable to init NSString from contentOf:usedEncoding:")
      }
    }

    func test_FromContentsOfURLUsedEncodingUTF32BE() {
      guard let testFileURL = testBundle().url(forResource: "NSString-UTF32-BE-data", withExtension: "txt") else {
        XCTFail("URL for NSString-UTF32-BE-data.txt is nil")
        return
      }

      do {
         var encoding: UInt = 0
         let string = try NSString(contentsOf: testFileURL, usedEncoding: &encoding)
         XCTAssertEqual(string, "NSString fromURL usedEncoding test with UTF32 BE file", "Wrong result when reading UTF32BE file")
         XCTAssertEqual(encoding, String.Encoding.utf32BigEndian.rawValue, "Wrong encoding detected from UTF32BE file")
      } catch {
          XCTFail("Unable to init NSString from contentOf:usedEncoding:")
      }
    }

    func test_FromContentsOfURLUsedEncodingUTF32LE() {
      guard let testFileURL = testBundle().url(forResource: "NSString-UTF32-LE-data", withExtension: "txt") else {
        XCTFail("URL for NSString-UTF32-LE-data.txt is nil")
        return
      }

      do {
         var encoding: UInt = 0
         let string = try NSString(contentsOf: testFileURL, usedEncoding: &encoding)
         XCTAssertEqual(string, "NSString fromURL usedEncoding test with UTF32 LE file", "Wrong result when reading UTF32LE file")
         XCTAssertEqual(encoding, String.Encoding.utf32LittleEndian.rawValue, "Wrong encoding detected from UTF32LE file")
      } catch {
          XCTFail("Unable to init NSString from contentOf:usedEncoding:")
      }
    }

    func test_FromContentOfFile() {
        let testFilePath = testBundle().path(forResource: "NSStringTestData", ofType: "txt")
        XCTAssertNotNil(testFilePath)
        
        do {
            let str = try NSString(contentsOfFile: testFilePath!, encoding: String.Encoding.utf8.rawValue)
            XCTAssertEqual(str, "swift-corelibs-foundation")
        } catch {
            XCTFail("Unable to init NSString from contentsOfFile:encoding:")
        }
    }

    func test_uppercaseString() {
        XCTAssertEqual(NSString(stringLiteral: "abcd").uppercased, "ABCD")
        XCTAssertEqual(NSString(stringLiteral: "ａｂｃｄ").uppercased, "ＡＢＣＤ") // full-width
        XCTAssertEqual(NSString(stringLiteral: "абВГ").uppercased, "АБВГ")
        XCTAssertEqual(NSString(stringLiteral: "たちつてと").uppercased, "たちつてと")

        // Special casing (see swift/validation-tests/stdlib/NSStringAPI.swift)
        XCTAssertEqual(NSString(stringLiteral: "\u{0069}").uppercased(with: Locale(identifier: "en")), "\u{0049}")
        // Currently fails; likely there are locale loading issues that are preventing this from functioning correctly
        // XCTAssertEqual(NSString(stringLiteral: "\u{0069}").uppercased(with: NSLocale(localeIdentifier: "tr")), "\u{0130}")
        XCTAssertEqual(NSString(stringLiteral: "\u{00df}").uppercased, "\u{0053}\u{0053}")
        XCTAssertEqual(NSString(stringLiteral: "\u{fb01}").uppercased, "\u{0046}\u{0049}")
    }

    func test_lowercaseString() {
        XCTAssertEqual(NSString(stringLiteral: "abCD").lowercased, "abcd")
        XCTAssertEqual(NSString(stringLiteral: "ＡＢＣＤ").lowercased, "ａｂｃｄ") // full-width
        XCTAssertEqual(NSString(stringLiteral: "aБВГ").lowercased, "aбвг")
        XCTAssertEqual(NSString(stringLiteral: "たちつてと").lowercased, "たちつてと")

        // Special casing (see swift/validation-tests/stdlib/NSStringAPI.swift)
        XCTAssertEqual(NSString(stringLiteral: "\u{0130}").lowercased(with: Locale(identifier: "en")), "\u{0069}\u{0307}")
        // Currently fails; likely there are locale loading issues that are preventing this from functioning correctly
        // XCTAssertEqual(NSString(stringLiteral: "\u{0130}").lowercased(with: NSLocale(localeIdentifier: "tr")), "\u{0069}")
        XCTAssertEqual(NSString(stringLiteral: "\u{0049}\u{0307}").lowercased(with: Locale(identifier: "en")), "\u{0069}\u{0307}")
        // Currently fails; likely there are locale loading issues that are preventing this from functioning correctly
        // XCTAssertEqual(NSString(stringLiteral: "\u{0049}\u{0307}").lowercaseStringWithLocale(NSLocale(localeIdentifier: "tr")), "\u{0069}")
    }

    func test_capitalizedString() {
        XCTAssertEqual(NSString(stringLiteral: "foo Foo fOO FOO").capitalized, "Foo Foo Foo Foo")
        XCTAssertEqual(NSString(stringLiteral: "жжж").capitalized, "Жжж")
    }

    func test_longLongValue() {
        let string1: NSString = "123"
        XCTAssertEqual(string1.longLongValue, 123)

        let string2: NSString = "123a"
        XCTAssertEqual(string2.longLongValue, 123)

        let string3: NSString = "-123a"
        XCTAssertEqual(string3.longLongValue, -123)

        let string4: NSString = "a123"
        XCTAssertEqual(string4.longLongValue, 0)

        let string5: NSString = "+123"
        XCTAssertEqual(string5.longLongValue, 123)

        let string6: NSString = "++123"
        XCTAssertEqual(string6.longLongValue, 0)

        let string7: NSString = "-123"
        XCTAssertEqual(string7.longLongValue, -123)

        let string8: NSString = "--123"
        XCTAssertEqual(string8.longLongValue, 0)

        let string9: NSString = "999999999999999999999999999999"
        XCTAssertEqual(string9.longLongValue, Int64.max)

        let string10: NSString = "-999999999999999999999999999999"
        XCTAssertEqual(string10.longLongValue, Int64.min)
    }
    
    func test_rangeOfCharacterFromSet() {
        let string: NSString = "0Az"
        let letters = CharacterSet.letters
        let decimalDigits = CharacterSet.decimalDigits
        XCTAssertEqual(string.rangeOfCharacter(from: letters).location, 1)
        XCTAssertEqual(string.rangeOfCharacter(from: decimalDigits).location, 0)
        XCTAssertEqual(string.rangeOfCharacter(from: letters, options: .backwards).location, 2)
        XCTAssertEqual(string.rangeOfCharacter(from: letters, options: [], range: NSRange(location: 2, length: 1)).location, 2)
    }
    
    func test_CFStringCreateMutableCopy() {
        let nsstring: NSString = "абВГ"
        let mCopy = CFStringCreateMutableCopy(kCFAllocatorSystemDefault, 0, unsafeBitCast(nsstring, to: CFString.self))
        let str = unsafeBitCast(mCopy, to: NSString.self)
        XCTAssertEqual(nsstring, str)
    }
    
    // This test verifies that CFStringGetBytes with a UTF16 encoding works on an NSString backed by a Swift string
    func test_swiftStringUTF16() {
        #if os(macOS) || os(iOS)
        let kCFStringEncodingUTF16 = CFStringBuiltInEncodings.UTF16.rawValue
        #endif

        let testString = "hello world"
        let string = NSString(string: testString)
        let cfString = unsafeBitCast(string, to: CFString.self)

        // Get the bytes as UTF16
        let reservedLength = 50
        var buf : [UInt8] = []
        buf.reserveCapacity(reservedLength)
        var usedLen : CFIndex = 0
        let _ = buf.withUnsafeMutableBufferPointer { p in
            CFStringGetBytes(cfString, CFRangeMake(0, CFStringGetLength(cfString)), CFStringEncoding(kCFStringEncodingUTF16), 0, false, p.baseAddress, reservedLength, &usedLen)
        }

        // Make a new string out of it
        let newCFString = CFStringCreateWithBytes(nil, buf, usedLen, CFStringEncoding(kCFStringEncodingUTF16), false)
        let newString = unsafeBitCast(newCFString, to: NSString.self)
        
        XCTAssertTrue(newString.isEqual(to: testString))
    }
    
    func test_completePathIntoString() {
        let fileNames = [
            NSTemporaryDirectory() + "Test_completePathIntoString_01",
            NSTemporaryDirectory() + "test_completePathIntoString_02",
            NSTemporaryDirectory() + "test_completePathIntoString_01.txt",
            NSTemporaryDirectory() + "test_completePathIntoString_01.dat",
            NSTemporaryDirectory() + "test_completePathIntoString_03.DAT"
        ]
        
        guard ensureFiles(fileNames) else {
            XCTAssert(false, "Could not create temp files for testing.")
            return
        }

        let tmpPath = { (path: String) -> String in
            return NSTemporaryDirectory() + "\(path)"
        }

        do {
            let path: String = tmpPath("")
            var outName: String = ""
            var matches: [String] = []
            _ = path.completePath(into: &outName, caseSensitive: false, matchesInto: &matches, filterTypes: nil)
            _ = try FileManager.default.contentsOfDirectory(at: URL(string: path)!, includingPropertiesForKeys: nil, options: [])
            XCTAssert(outName == "/", "If NSString is valid path to directory which has '/' suffix then outName is '/'.")
            // This assert fails on CI; https://bugs.swift.org/browse/SR-389
//            XCTAssert(matches.count == content.count && matches.count == count, "If NSString is valid path to directory then matches contain all content of directory. expected \(content) but got \(matches)")
        } catch {
            XCTAssert(false, "Could not finish test due to error")
        }
        
        do {
            let path: String = "/tmp"
            var outName: String = ""
            var matches: [String] = []
            _ = path.completePath(into: &outName, caseSensitive: false, matchesInto: &matches, filterTypes: nil)
            let urlToTmp = URL(fileURLWithPath: "/private/tmp/").standardized
            _ = try FileManager.default.contentsOfDirectory(at: urlToTmp, includingPropertiesForKeys: nil, options: [])
            XCTAssert(outName == "/tmp/", "If path could be completed to existing directory then outName is a string itself plus '/'.")
            // This assert fails on CI; https://bugs.swift.org/browse/SR-389
            //            XCTAssert(matches.count == content.count && matches.count == count, "If NSString is valid path to directory then matches contain all content of directory. expected \(content) but got \(matches)")
        } catch {
            XCTAssert(false, "Could not finish test due to error")
        }
        
        let fileNames2 = [
            NSTemporaryDirectory() + "ABC/",
            NSTemporaryDirectory() + "ABCD/",
            NSTemporaryDirectory() + "abcde"
        ]
        
        guard ensureFiles(fileNames2) else {
            XCTAssert(false, "Could not create temp files for testing.")
            return
        }
        
        do {
            let path: String = tmpPath("ABC")
            var outName: String = ""
            var matches: [String] = []
            let count = path.completePath(into: &outName, caseSensitive: false, matchesInto: &matches, filterTypes: nil)
            XCTAssert(stringsAreCaseInsensitivelyEqual(outName, path), "If NSString is valid path to directory then outName is string itself.")
            XCTAssert(matches.count == count && count == fileNames2.count, "")
        }
        
        do {
            let path: String = tmpPath("Test_completePathIntoString_01")
            var outName: String = ""
            var matches: [String] = []
            let count = path.completePath(into: &outName, caseSensitive: true, matchesInto: &matches, filterTypes: nil)
            XCTAssert(outName == path, "If NSString is valid path to file and search is case sensitive then outName is string itself.")
            XCTAssert(matches.count == 1 && count == 1 && stringsAreCaseInsensitivelyEqual(matches[0], path), "If NSString is valid path to file and search is case sensitive then matches contain that file path only")
        }
        
		do {
            let path: String = tmpPath("Test_completePathIntoString_01")
            var outName: String = ""
            var matches: [String] = []
            let count = path.completePath(into: &outName, caseSensitive: false, matchesInto: &matches, filterTypes: nil)
            XCTAssert(stringsAreCaseInsensitivelyEqual(outName, path), "If NSString is valid path to file and search is case insensitive then outName is string equal to self.")
            XCTAssert(matches.count == 3 && count == 3, "Matches contain all files with similar name.")
        }

        do {
            let path = tmpPath(NSUUID().uuidString)
            var outName: String = ""
            var matches: [String] = []
            let count = path.completePath(into: &outName, caseSensitive: false, matchesInto: &matches, filterTypes: nil)
            XCTAssert(outName == "", "If no matches found then outName is nil.")
            XCTAssert(matches.isEmpty && count == 0, "If no matches found then return 0 and matches is empty.")
        }

        do {
            let path: String = ""
            var outName: String = ""
            var matches: [String] = []
            let count = path.completePath(into: &outName, caseSensitive: false, matchesInto: &matches, filterTypes: nil)
            XCTAssert(outName == "", "If no matches found then outName is nil.")
            XCTAssert(matches.isEmpty && count == 0, "If no matches found then return 0 and matches is empty.")
        }

        do {
            let path: String = tmpPath("test_c")
            var outName: String = ""
            var matches: [String] = []
            // case insensetive
            let count = path.completePath(into: &outName, caseSensitive: false, matchesInto: &matches, filterTypes: nil)
            XCTAssert(stringsAreCaseInsensitivelyEqual(outName, tmpPath("Test_completePathIntoString_0")), "If there are matches then outName should be longest common prefix of all matches.")
            XCTAssert(matches.count == fileNames.count && count == fileNames.count, "If there are matches then matches array contains them.")
        }
        
        do {
            let path: String = tmpPath("test_c")
            var outName: String = ""
            var matches: [String] = []
            // case sensetive
            let count = path.completePath(into: &outName, caseSensitive: true, matchesInto: &matches, filterTypes: nil)
            XCTAssert(outName == tmpPath("test_completePathIntoString_0"), "If there are matches then outName should be longest common prefix of all matches.")
            XCTAssert(matches.count == 4 && count == 4, "Supports case sensetive search")
        }
        
        do {
            let path: String = tmpPath("test_c")
            var outName: String = ""
            var matches: [String] = []
            // case sensetive
            let count = path.completePath(into: &outName, caseSensitive: true, matchesInto: &matches, filterTypes: ["DAT"])
            XCTAssert(outName == tmpPath("test_completePathIntoString_03.DAT"), "If there are matches then outName should be longest common prefix of all matches.")
            XCTAssert(matches.count == 1 && count == 1, "Supports case sensetive search by extensions")
        }
        
        do {
            let path: String = tmpPath("test_c")
            var outName: String = ""
            var matches: [String] = []
            // type by filter
            let count = path.completePath(into: &outName, caseSensitive: false, matchesInto: &matches, filterTypes: ["txt", "dat"])
            XCTAssert(stringsAreCaseInsensitivelyEqual(outName, tmpPath("test_completePathIntoString_0")), "If there are matches then outName should be longest common prefix of all matches.")
            XCTAssert(matches.count == 3 && count == 3, "Supports filtration by type")
        }
        
        do {
            // will be resolved against current working directory that is directory there results of build process are stored
            let path: String = "TestFoundation"
            var outName: String = ""
            var matches: [String] = []
            let count = path.completePath(into: &outName, caseSensitive: false, matchesInto: &matches, filterTypes: nil)
            // Build directory at least contains executable itself and *.swiftmodule directory
            XCTAssert(matches.count == count && count >= 2, "Supports relative paths.")
            XCTAssert(startWith(path, strings: matches), "For relative paths matches are relative too.")
        }
        
        // Next check has no sense on Linux due to case sensitive file system.
        #if os(macOS)
        guard ensureFiles([NSTemporaryDirectory() + "ABC/temp.txt"]) else {
            XCTAssert(false, "Could not create temp files for testing.")
            return
        }
        
        do {
            let path: String = tmpPath("aBc/t")
            var outName: String = ""
            var matches: [String] = []
            // type by filter
            let count = path.completePath(into: &outName, caseSensitive: true, matchesInto: &matches, filterTypes: ["txt", "dat"])
            XCTAssert(outName == tmpPath("aBc/temp.txt"), "outName starts with receiver.")
            XCTAssert(matches.count >= 1 && count >= 1, "There are matches")
        }
        #endif
    }
    
    private func startWith(_ prefix: String, strings: [String]) -> Bool {
        for item in strings {
            guard item.hasPrefix(prefix) else {
                return false
            }
        }
        
        return true
    }
    
    private func stringsAreCaseInsensitivelyEqual(_ lhs: String, _ rhs: String) -> Bool {
        return lhs.compare(rhs, options: .caseInsensitive) == .orderedSame
    }

    func test_stringByTrimmingCharactersInSet() {
        let characterSet = CharacterSet.whitespaces
        let string: NSString = " abc   "
        XCTAssertEqual(string.trimmingCharacters(in: characterSet), "abc")
        
        let emojiString: NSString = " \u{1F62C}  "
        XCTAssertEqual(emojiString.trimmingCharacters(in: characterSet), "\u{1F62C}")
    }
    
    func test_initializeWithFormat() {
        let argument: [CVarArg] = [42, 42.0]
        withVaList(argument) {
            pointer in
            let string = NSString(format: "Value is %d (%.1f)", arguments: pointer)
            XCTAssertEqual(string, "Value is 42 (42.0)")
        }
    }
    
    func test_initializeWithFormat2() {
        let argument: UInt8 = 75
        let string = NSString(format: "%02X", argument)
        XCTAssertEqual(string, "4B")
    }
    
    func test_initializeWithFormat3() {
        let argument: [CVarArg] = [1000, 42.0]
        
        withVaList(argument) {
            pointer in
            let string = NSString(format: "Default value is %d (%.1f)", locale: nil, arguments: pointer)
            XCTAssertEqual(string, "Default value is 1000 (42.0)")
        }
        
#if false // these two tests expose bugs in icu4c's localization on some linux builds (disable until we can get a uniform fix for this)
        withVaList(argument) {
            pointer in
            let string = NSString(format: "en_GB value is %d (%.1f)", locale: Locale.init(localeIdentifier: "en_GB"), arguments: pointer)
            XCTAssertEqual(string, "en_GB value is 1,000 (42.0)")
        }

        withVaList(argument) {
            pointer in
            let string = NSString(format: "de_DE value is %d (%.1f)", locale: Locale.init(localeIdentifier: "de_DE"), arguments: pointer)
            XCTAssertEqual(string, "de_DE value is 1.000 (42,0)")
        }
#endif
        
        withVaList(argument) {
            pointer in
            let loc: NSDictionary = ["NSDecimalSeparator" as NSString : "&" as NSString]
            let string = NSString(format: "NSDictionary value is %d (%.1f)", locale: loc, arguments: pointer)
            XCTAssertEqual(string, "NSDictionary value is 1000 (42&0)")
        }
    }

    func test_appendingPathComponent() {
        do {
            let path: NSString = "/tmp"
            let result = path.appendingPathComponent("scratch.tiff")
            XCTAssertEqual(result, "/tmp/scratch.tiff")
        }

        do {
            let path: NSString = "/tmp/"
            let result = path.appendingPathComponent("scratch.tiff")
            XCTAssertEqual(result, "/tmp/scratch.tiff")
        }

        do {
            let path: NSString = "/"
            let result = path.appendingPathComponent("scratch.tiff")
            XCTAssertEqual(result, "/scratch.tiff")
        }

        do {
            let path: NSString = ""
            let result = path.appendingPathComponent("scratch.tiff")
            XCTAssertEqual(result, "scratch.tiff")
        }                        
    }
    
    func test_deletingLastPathComponent() {
        do {
            let path: NSString = "/tmp/scratch.tiff"
            let result = path.deletingLastPathComponent
            XCTAssertEqual(result, "/tmp")
        }
        
        do {
            let path: NSString = "/tmp/lock/"
            let result = path.deletingLastPathComponent
            XCTAssertEqual(result, "/tmp")
        }
        
        do {
            let path: NSString = "/tmp/"
            let result = path.deletingLastPathComponent
            XCTAssertEqual(result, "/")
        }
        
        do {
            let path: NSString = "/tmp"
            let result = path.deletingLastPathComponent
            XCTAssertEqual(result, "/")
        }
        
        do {
            let path: NSString = "/"
            let result = path.deletingLastPathComponent
            XCTAssertEqual(result, "/")
        }
        
        do {
            let path: NSString = "scratch.tiff"
            let result = path.deletingLastPathComponent
            XCTAssertEqual(result, "")
        }
        
        do {
            let path: NSString = "foo/bar"
            let result = path.deletingLastPathComponent
            XCTAssertEqual(result, "foo", "Relative path stays relative.")
        }
    }
    
    func test_resolvingSymlinksInPath() {
        do {
            let path: NSString = "foo/bar"
            let result = path.resolvingSymlinksInPath
            XCTAssertEqual(result, "foo/bar", "For relative paths, symbolic links that can’t be resolved are left unresolved in the returned string.")
        }
        
        do {
            let path: NSString = "/tmp/.."
            let result = path.resolvingSymlinksInPath
            
            #if os(macOS)
            let expected = "/private"
            #else
            let expected = "/"
            #endif
            
            XCTAssertEqual(result, expected, "For absolute paths, all symbolic links are guaranteed to be removed.")
        }

        do {
            let path: NSString = "tmp/.."
            let result = path.resolvingSymlinksInPath
            XCTAssertEqual(result, "tmp/..", "Parent links could be resolved for absolute paths only.")
        }
        
        do {
            let path: NSString = "/tmp/"
            let result = path.resolvingSymlinksInPath
            XCTAssertEqual(result, "/tmp", "Result doesn't contain trailing slash.")
        }
        
        do {
            let path: NSString = "http://google.com/search/.."
            let result = path.resolvingSymlinksInPath
            XCTAssertEqual(result, "http:/google.com/search/..", "resolvingSymlinksInPath treats receiver as file path always")
        }
        
        do {
            let path: NSString = "file:///tmp/.."
            let result = path.resolvingSymlinksInPath
            XCTAssertEqual(result, "file:/tmp/..", "resolvingSymlinksInPath treats receiver as file path always")
        }
    }

    func test_getCString_simple() {
        let str: NSString = "foo"
        var chars = [Int8](repeating:0xF, count:4)
        let count = chars.count
        let expected: [Int8] = [102, 111, 111, 0]
        var res: Bool = false
        chars.withUnsafeMutableBufferPointer() {
            let ptr = $0.baseAddress!
            res = str.getCString(ptr, maxLength: count, encoding: String.Encoding.ascii.rawValue)
        }
        XCTAssertTrue(res, "getCString should work on simple strings with ascii string encoding")
        XCTAssertEqual(chars, expected, "getCString on \(str) should have resulted in \(expected) but got \(chars)")
    }
    
    func test_getCString_nonASCII_withASCIIAccessor() {
        let str: NSString = "ƒoo"
        var chars = [Int8](repeating:0xF, count:5)
        let expected: [Int8] = [-58, -110, 111, 111, 0]
        let count = chars.count
        var res: Bool = false
        chars.withUnsafeMutableBufferPointer() {
            let ptr = $0.baseAddress!
            res = str.getCString(ptr, maxLength: count, encoding: String.Encoding.ascii.rawValue)
        }
        XCTAssertFalse(res, "getCString should not work on non ascii strings accessing as ascii string encoding")
        chars.withUnsafeMutableBufferPointer() {
            let ptr = $0.baseAddress!
            res = str.getCString(ptr, maxLength: count, encoding: String.Encoding.utf8.rawValue)
        }
        XCTAssertTrue(res, "getCString should work on UTF8 encoding")
        XCTAssertEqual(chars, expected, "getCString on \(str) should have resulted in \(expected) but got \(chars)")
    }
    
    func test_NSHomeDirectoryForUser() {
        let homeDir = NSHomeDirectoryForUser(nil)
        let userName = NSUserName()
        let homeDir2 = NSHomeDirectoryForUser(userName)
        let homeDir3 = NSHomeDirectory()
        XCTAssert(homeDir != nil && homeDir == homeDir2 && homeDir == homeDir3, "Could get user' home directory")
    }
    
    func test_expandingTildeInPath() {
        do {
            let path: NSString = "~"
            let result = path.expandingTildeInPath
            XCTAssert(result == NSHomeDirectory(), "Could resolve home directory for current user")
            XCTAssertFalse(result.hasSuffix("/"), "Result have no trailing path separator")
        }
        
        do {
            let path: NSString = "~/"
            let result = path.expandingTildeInPath
            XCTAssert(result == NSHomeDirectory(), "Could resolve home directory for current user")
            XCTAssertFalse(result.hasSuffix("/"), "Result have no trailing path separator")
        }
        
        do {
            let path = NSString(string: "~\(NSUserName())")
            let result = path.expandingTildeInPath
            XCTAssert(result == NSHomeDirectory(), "Could resolve home directory for specific user")
            XCTAssertFalse(result.hasSuffix("/"), "Result have no trailing path separator")
        }
        
        do {
            let userName = NSUUID().uuidString
            let path = NSString(string: "~\(userName)/")
            let result = path.expandingTildeInPath
          	// next assert fails in VirtualBox because home directory for unknown user resolved to /var/run/vboxadd
            XCTAssertEqual(result, "~\(userName)", "Return copy of receiver if home directory could not be resolved.")
        }
    }
    
    func test_standardizingPath() {
        
        // tmp is special because it is symlinked to /private/tmp and this /private prefix should be dropped,
        // so tmp is tmp. On Linux tmp is not symlinked so it would be the same.
        do {
            let path: NSString = "/.//tmp/ABC/.."
            let result = path.standardizingPath
            XCTAssertEqual(result, "/tmp", "standardizingPath removes extraneous path components and resolve symlinks.")
        }
        
        do {
            let path: NSString =  "~"
            let result = path.standardizingPath
            let expected = NSHomeDirectory()
            XCTAssertEqual(result, expected, "standardizingPath expanding initial tilde.")
        }
        
        do {
            let path: NSString =  "~/foo/bar/"
            let result = path.standardizingPath
            let expected = NSHomeDirectory() + "/foo/bar"
            XCTAssertEqual(result, expected, "standardizingPath expanding initial tilde.")
        }
        
        // relative file paths depend on file path standardizing that is not yet implemented
        do {
            let path: NSString = "foo/bar"
            let result = path.standardizingPath
            XCTAssertEqual(NSString(string: result), path, "standardizingPath doesn't resolve relative paths")
        }
        
        // tmp is symlinked on macOS only
        #if os(macOS)
        do {
            let path: NSString = "/tmp/.."
            let result = path.standardizingPath
            XCTAssertEqual(result, "/private")
        }
        #endif
        
        do {
            let path: NSString = "/tmp/ABC/.."
            let result = path.standardizingPath
            XCTAssertEqual(result, "/tmp", "parent links could be resolved for absolute paths")
        }
        
        do {
            let path: NSString = "tmp/ABC/.."
            let result = path.standardizingPath
            XCTAssertEqual(NSString(string: result), path, "parent links could not be resolved for relative paths")
        }
    }

    func test_addingPercentEncoding() {
        let s1 = "a b".addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        XCTAssertEqual(s1, "a%20b")
        
        let s2 = "\u{0434}\u{043E}\u{043C}".addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        XCTAssertEqual(s2, "%D0%B4%D0%BE%D0%BC")
    }
    
    func test_removingPercentEncodingInLatin() {
        let s1 = "a%20b".removingPercentEncoding
        XCTAssertEqual(s1, "a b")
        let s2 = "a%1 b".removingPercentEncoding
        XCTAssertNil(s2, "returns nil for a string with an invalid percent encoding")
    }
    
    func test_removingPercentEncodingInNonLatin() {
        let s1 = "\u{043C}\u{043E}\u{0439}%20\u{0434}\u{043E}\u{043C}".removingPercentEncoding
        XCTAssertEqual(s1, "\u{043C}\u{043E}\u{0439} \u{0434}\u{043E}\u{043C}")
        
        let s2 = "%D0%B4%D0%BE%D0%BC".removingPercentEncoding
        XCTAssertEqual(s2, "\u{0434}\u{043E}\u{043C}")
        
        let s3 = "\u{00E0}a%1 b".removingPercentEncoding
        XCTAssertNil(s3, "returns nil for a string with an invalid percent encoding")
    }
    
    func test_removingPersentEncodingWithoutEncoding() {
        let cyrillicString = "\u{0434}\u{043E}\u{043C}"
        let cyrillicEscapedString = cyrillicString.removingPercentEncoding
        XCTAssertEqual(cyrillicString, cyrillicEscapedString)
        
        let chineseString = "\u{623F}\u{5B50}"
        let chineseEscapedString = chineseString.removingPercentEncoding
        XCTAssertEqual(chineseString, chineseEscapedString)
        
        let arabicString = "\u{0645}\u{0646}\u{0632}\u{0644}"
        let arabicEscapedString = arabicString.removingPercentEncoding
        XCTAssertEqual(arabicString, arabicEscapedString)
        
        let randomString = "\u{00E0}\u{00E6}"
        let randomEscapedString = randomString.removingPercentEncoding
        XCTAssertEqual(randomString, randomEscapedString)
        
        let latinString = "home"
        let latinEscapedString = latinString.removingPercentEncoding
        XCTAssertEqual(latinString, latinEscapedString)
    }
    
    func test_addingPercentEncodingAndBack() {
        let latingString = "a b"
        let escapedLatingString = latingString.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        let returnedLatingString = escapedLatingString?.removingPercentEncoding
        XCTAssertEqual(returnedLatingString, latingString)
        
        let cyrillicString = "\u{0434}\u{043E}\u{043C}"
        let escapedCyrillicString = cyrillicString.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        let returnedCyrillicString = escapedCyrillicString?.removingPercentEncoding
        XCTAssertEqual(returnedCyrillicString, cyrillicString)
    }
    
    func test_stringByAppendingPathExtension() {
        let values = [
            NSString(string: "/tmp/scratch.old") : "/tmp/scratch.old.tiff",
            NSString(string: "/tmp/scratch.") : "/tmp/scratch..tiff",
            NSString(string: "/tmp/") : "/tmp.tiff",
            NSString(string: "/scratch") : "/scratch.tiff",
            NSString(string: "/~scratch") : "/~scratch.tiff",
            NSString(string: "scratch") : "scratch.tiff",
        ]
        for (fileName, expectedResult) in values {
            let result = fileName.appendingPathExtension("tiff")
            XCTAssertEqual(result, expectedResult, "expected \(expectedResult) for \(fileName) but got \(result as Optional)")
        }
    }
    
    func test_deletingPathExtension() {
        let values : Dictionary = [
            NSString(string: "/tmp/scratch.tiff") : "/tmp/scratch",
            NSString(string: "/tmp/") : "/tmp",
            NSString(string: "scratch.bundle") : "scratch",
            NSString(string: "scratch..tiff") : "scratch.",
            NSString(string: ".tiff") : ".tiff",
            NSString(string: "/") : "/",
            NSString(string: "..") : "..",
        ]
        for (fileName, expectedResult) in values {
            let result = fileName.deletingPathExtension
            XCTAssertEqual(result, expectedResult, "expected \(expectedResult) for \(fileName) but got \(result)")
        }
    }
    
    func test_ExternalRepresentation() {
        // Ensure NSString can be used to create an external data representation
        
        let UTF8Encoding = CFStringEncoding(kCFStringEncodingUTF8)
        let UTF16Encoding = CFStringEncoding(kCFStringEncodingUTF16)
        let ISOLatin1Encoding = CFStringEncoding(kCFStringEncodingISOLatin1)
        
        do {
            let string = unsafeBitCast(NSString(string: "this is an external string that should be representable by data"), to: CFString.self)
            let UTF8Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, UTF8Encoding, 0)
            let UTF8Length = CFDataGetLength(UTF8Data)
            XCTAssertEqual(UTF8Length, 63, "NSString should successfully produce an external UTF8 representation with a length of 63 but got \(UTF8Length) bytes")
            
            let UTF16Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, UTF16Encoding, 0)
            let UTF16Length = CFDataGetLength(UTF16Data)
            XCTAssertEqual(UTF16Length, 128, "NSString should successfully produce an external UTF16 representation with a length of 128 but got \(UTF16Length) bytes")
            
            let ISOLatin1Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, ISOLatin1Encoding, 0)
            let ISOLatin1Length = CFDataGetLength(ISOLatin1Data)
            XCTAssertEqual(ISOLatin1Length, 63, "NSString should successfully produce an external ISOLatin1 representation with a length of 63 but got \(ISOLatin1Length) bytes")
        }
        
        do {
            let string = unsafeBitCast(NSString(string: "🐢 encoding all the way down. 🐢🐢🐢"), to: CFString.self)
            let UTF8Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, UTF8Encoding, 0)
            let UTF8Length = CFDataGetLength(UTF8Data)
            XCTAssertEqual(UTF8Length, 44, "NSString should successfully produce an external UTF8 representation with a length of 44 but got \(UTF8Length) bytes")
            
            let UTF16Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, UTF16Encoding, 0)
            let UTF16Length = CFDataGetLength(UTF16Data)
            XCTAssertEqual(UTF16Length, 74, "NSString should successfully produce an external UTF16 representation with a length of 74 but got \(UTF16Length) bytes")
            
            let ISOLatin1Data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, string, ISOLatin1Encoding, 0)
            XCTAssertNil(ISOLatin1Data)
        }
    }
    
    func test_mutableStringConstructor() {
        let mutableString = NSMutableString(string: "Test")
        XCTAssertEqual(mutableString, "Test")
    }

    func test_getLineStart() {
        // offset        012345 678901
        let twoLines =  "line1\nline2\n"
        var outStartIndex = twoLines.startIndex
        var outEndIndex = twoLines.startIndex
        var outContentsEndIndex = twoLines.startIndex

        twoLines.getLineStart(&outStartIndex, end: &outEndIndex,
                              contentsEnd: &outContentsEndIndex,
                              for: outEndIndex..<outEndIndex)

        XCTAssertEqual(outStartIndex, twoLines.startIndex)
        XCTAssertEqual(outContentsEndIndex, twoLines.index(twoLines.startIndex, offsetBy: 5))
        XCTAssertEqual(outEndIndex, twoLines.index(twoLines.startIndex, offsetBy: 6))

        twoLines.getLineStart(&outStartIndex, end: &outEndIndex,
                              contentsEnd: &outContentsEndIndex,
                              for: outEndIndex..<outEndIndex)

        XCTAssertEqual(outStartIndex, twoLines.index(twoLines.startIndex, offsetBy: 6))
        XCTAssertEqual(outContentsEndIndex, twoLines.index(twoLines.startIndex, offsetBy: 11))
        XCTAssertEqual(outEndIndex, twoLines.index(twoLines.startIndex, offsetBy: 12))
    }
    
    func test_emptyStringPrefixAndSuffix() {
        let testString = "hello"
        XCTAssertTrue(testString.hasPrefix(""))
        XCTAssertTrue(testString.hasSuffix(""))
    }

    func test_substringWithRange() {
        let trivial = NSString(string: "swift.org")
        XCTAssertEqual(trivial.substring(with: NSRange(location: 0, length: 5)), "swift")

        let surrogatePairSuffix = NSString(string: "Hurray🎉")
        XCTAssertEqual(surrogatePairSuffix.substring(with: NSRange(location: 0, length: 7)), "Hurray�")

        let surrogatePairPrefix = NSString(string: "🐱Cat")
        XCTAssertEqual(surrogatePairPrefix.substring(with: NSRange(location: 1, length: 4)), "�Cat")

        let singleChar = NSString(string: "😹")
        XCTAssertEqual(singleChar.substring(with: NSRange(location: 0, length: 1)), "�")

        let crlf = NSString(string: "\r\n")
        XCTAssertEqual(crlf.substring(with: NSRange(location: 0, length: 1)), "\r")
        XCTAssertEqual(crlf.substring(with: NSRange(location: 1, length: 1)), "\n")
        XCTAssertEqual(crlf.substring(with: NSRange(location: 1, length: 0)), "")

        let bothEnds1 = NSString(string: "😺😺")
        XCTAssertEqual(bothEnds1.substring(with: NSRange(location: 1, length: 2)), "��") 

        let s1 = NSString(string: "😺\r\n")
        XCTAssertEqual(s1.substring(with: NSRange(location: 1, length: 2)), "�\r")

        let s2 = NSString(string: "\r\n😺")
        XCTAssertEqual(s2.substring(with: NSRange(location: 1, length: 2)), "\n�")

        let s3 = NSString(string: "😺cats😺")
        XCTAssertEqual(s3.substring(with: NSRange(location: 1, length: 6)), "�cats�")

        let s4 = NSString(string: "😺cats\r\n")
        XCTAssertEqual(s4.substring(with: NSRange(location: 1, length: 6)), "�cats\r")

        let s5 = NSString(string: "\r\ncats😺")
        XCTAssertEqual(s5.substring(with: NSRange(location: 1, length: 6)), "\ncats�")

        // SR-3363
        let s6 = NSString(string: "Beyonce\u{301} and Tay")
        XCTAssertEqual(s6.substring(with: NSRange(location: 7, length: 9)), "\u{301} and Tay")
    }
    
    func test_createCopy() {
        let string: NSMutableString = "foo"
        let stringCopy = string.copy() as! NSString
        XCTAssertEqual(string, stringCopy)
        string.append("bar")
        XCTAssertNotEqual(string, stringCopy)
        XCTAssertEqual(string, "foobar")
        XCTAssertEqual(stringCopy, "foo")
    }

    func test_AnyHashable() {
        let a1: AnyHashable = "Hello"
        let a2: AnyHashable = NSString(string: "Hello")
        let b1: AnyHashable = "world"
        let b2: AnyHashable = NSString(string: "world")
        XCTAssertEqual(a1, a2)
        XCTAssertEqual(b1, b2)
        XCTAssertNotEqual(a1, b1)
        XCTAssertNotEqual(a1, b2)
        XCTAssertNotEqual(a2, b1)
        XCTAssertNotEqual(a2, b2)

        XCTAssertEqual(a1.hashValue, a2.hashValue)
        XCTAssertEqual(b1.hashValue, b2.hashValue)
    }
}

func test_reflection() {
}

extension TestNSString {
    func test_replacingOccurrences() {
        let testPrefix = "ab"
        let testSuffix = "cd"
        let testEmoji = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"
        let testString = testPrefix + testEmoji + testSuffix

        let testReplacement = "xyz"
        let testReplacementEmoji = "\u{01F468}\u{200D}\u{002764}\u{00FE0F}\u{200D}\u{01F48B}\u{200D}\u{01F468}"

        let noChange = testString.replacingOccurrences(of: testReplacement, with: "")
        XCTAssertEqual(noChange, testString)

        let removePrefix = testString.replacingOccurrences(of: testPrefix, with: "")
        XCTAssertEqual(removePrefix, testEmoji + testSuffix)
        let replacePrefix = testString.replacingOccurrences(of: testPrefix, with: testReplacement)
        XCTAssertEqual(replacePrefix, testReplacement + testEmoji + testSuffix)

        let removeSuffix = testString.replacingOccurrences(of: testSuffix, with: "")
        XCTAssertEqual(removeSuffix, testPrefix + testEmoji)
        let replaceSuffix = testString.replacingOccurrences(of: testSuffix, with: testReplacement)
        XCTAssertEqual(replaceSuffix, testPrefix + testEmoji + testReplacement)

        let removeMultibyte = testString.replacingOccurrences(of: testEmoji, with: "")
        XCTAssertEqual(removeMultibyte, testPrefix + testSuffix)
        let replaceMultibyte = testString.replacingOccurrences(of: testEmoji, with: testReplacement)
        XCTAssertEqual(replaceMultibyte, testPrefix + testReplacement + testSuffix)

        let replaceMultibyteWithMultibyte = testString.replacingOccurrences(of: testEmoji, with: testReplacementEmoji)
        XCTAssertEqual(replaceMultibyteWithMultibyte, testPrefix + testReplacementEmoji + testSuffix)

        let replacePrefixWithMultibyte = testString.replacingOccurrences(of: testPrefix, with: testReplacementEmoji)
        XCTAssertEqual(replacePrefixWithMultibyte, testReplacementEmoji + testEmoji + testSuffix)

        let replaceSuffixWithMultibyte = testString.replacingOccurrences(of: testSuffix, with: testReplacementEmoji)
        XCTAssertEqual(replaceSuffixWithMultibyte, testPrefix + testEmoji + testReplacementEmoji)
    }
}
