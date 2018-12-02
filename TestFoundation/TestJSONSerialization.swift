// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestJSONSerialization : XCTestCase {
    
    let supportedEncodings: [String.Encoding] = [
        .utf8,
        .utf16, .utf16BigEndian,
        .utf32LittleEndian, .utf32BigEndian
    ]

    static var allTests: [(String, (TestJSONSerialization) -> () throws -> Void)] {
        return JSONObjectWithDataTests
            + deserializationTests
            + isValidJSONObjectTests
            + serializationTests
    }
    
}

//MARK: - JSONObjectWithData
extension TestJSONSerialization {

    class var JSONObjectWithDataTests: [(String, (TestJSONSerialization) -> () throws -> Void)] {
        return [
            ("test_JSONObjectWithData_emptyObject", test_JSONObjectWithData_emptyObject),
            ("test_JSONObjectWithData_encodingDetection", test_JSONObjectWithData_encodingDetection),
        ]
    }
    
    func test_JSONObjectWithData_emptyObject() {
        var bytes: [UInt8] = [0x7B, 0x7D]
        let subject = bytes.withUnsafeMutableBufferPointer {
            return Data(buffer: $0)
        }
        
        let object = try! JSONSerialization.jsonObject(with: subject, options: []) as? [String:Any]
        XCTAssertEqual(object?.count, 0)
    }
    
    //MARK: - Encoding Detection
    func test_JSONObjectWithData_encodingDetection() {
        let subjects: [(String, [UInt8])] = [
            // BOM Detection
            ("{} UTF-8 w/BOM", [0xEF, 0xBB, 0xBF, 0x7B, 0x7D]),
            ("{} UTF-16BE w/BOM", [0xFE, 0xFF, 0x0, 0x7B, 0x0, 0x7D]),
            ("{} UTF-16LE w/BOM", [0xFF, 0xFE, 0x7B, 0x0, 0x7D, 0x0]),
            ("{} UTF-32BE w/BOM", [0x00, 0x00, 0xFE, 0xFF, 0x0, 0x0, 0x0, 0x7B, 0x0, 0x0, 0x0, 0x7D]),
            ("{} UTF-32LE w/BOM", [0xFF, 0xFE, 0x00, 0x00, 0x7B, 0x0, 0x0, 0x0, 0x7D, 0x0, 0x0, 0x0]),
            
            // RFC4627 Detection
            ("{} UTF-8", [0x7B, 0x7D]),
            ("{} UTF-16BE", [0x0, 0x7B, 0x0, 0x7D]),
            ("{} UTF-16LE", [0x7B, 0x0, 0x7D, 0x0]),
            ("{} UTF-32BE", [0x0, 0x0, 0x0, 0x7B, 0x0, 0x0, 0x0, 0x7D]),
            ("{} UTF-32LE", [0x7B, 0x0, 0x0, 0x0, 0x7D, 0x0, 0x0, 0x0]),
            
            //            // Single Characters
            //            ("'3' UTF-8", [0x33]),
            //            ("'3' UTF-16BE", [0x0, 0x33]),
            //            ("'3' UTF-16LE", [0x33, 0x0]),
        ]
        
        for (description, encoded) in subjects {
            let result = try? JSONSerialization.jsonObject(with: Data(bytes:encoded, count: encoded.count), options: [])
            XCTAssertNotNil(result, description)
        }
    }

}

//MARK: - JSONDeserialization
extension TestJSONSerialization {

    enum ObjectType {
        case data
        case stream
    }
    static var objectType = ObjectType.data

    class var deserializationTests: [(String, (TestJSONSerialization) -> () throws -> Void)] {
        return [
            //Deserialization with Data
            ("test_deserialize_emptyObject_withData", test_deserialize_emptyObject_withData),
            ("test_deserialize_multiStringObject_withData", test_deserialize_multiStringObject_withData),

            ("test_deserialize_emptyArray_withData", test_deserialize_emptyArray_withData),
            ("test_deserialize_multiStringArray_withData", test_deserialize_multiStringArray_withData),
            ("test_deserialize_unicodeString_withData", test_deserialize_unicodeString_withData),
            ("test_deserialize_stringWithSpacesAtStart_withData", test_deserialize_stringWithSpacesAtStart_withData),


            ("test_deserialize_values_withData", test_deserialize_values_withData),
            ("test_deserialize_values_as_reference_types_withData", test_deserialize_values_as_reference_types_withData),
            ("test_deserialize_numbers_withData", test_deserialize_numbers_withData),
            ("test_deserialize_numbers_as_reference_types_withData", test_deserialize_numbers_as_reference_types_withData),

            ("test_deserialize_simpleEscapeSequences_withData", test_deserialize_simpleEscapeSequences_withData),
            ("test_deserialize_unicodeEscapeSequence_withData", test_deserialize_unicodeEscapeSequence_withData),
            ("test_deserialize_unicodeSurrogatePairEscapeSequence_withData", test_deserialize_unicodeSurrogatePairEscapeSequence_withData),
            // Disabled due to uninitialized memory SR-606
            // ("test_deserialize_allowFragments_withData", test_deserialize_allowFragments_withData),

            ("test_deserialize_unterminatedObjectString_withData", test_deserialize_unterminatedObjectString_withData),
            ("test_deserialize_missingObjectKey_withData", test_deserialize_missingObjectKey_withData),
            ("test_deserialize_unexpectedEndOfFile_withData", test_deserialize_unexpectedEndOfFile_withData),
            ("test_deserialize_invalidValueInObject_withData", test_deserialize_invalidValueInObject_withData),
            ("test_deserialize_invalidValueIncorrectSeparatorInObject_withData", test_deserialize_invalidValueIncorrectSeparatorInObject_withData),
            ("test_deserialize_invalidValueInArray_withData", test_deserialize_invalidValueInArray_withData),
            ("test_deserialize_badlyFormedArray_withData", test_deserialize_badlyFormedArray_withData),
            ("test_deserialize_invalidEscapeSequence_withData", test_deserialize_invalidEscapeSequence_withData),
            ("test_deserialize_unicodeMissingLeadingSurrogate_withData", test_deserialize_unicodeMissingLeadingSurrogate_withData),
            ("test_deserialize_unicodeMissingTrailingSurrogate_withData", test_deserialize_unicodeMissingTrailingSurrogate_withData),

            //Deserialization with Stream
            ("test_deserialize_emptyObject_withStream", test_deserialize_emptyObject_withStream),
            ("test_deserialize_multiStringObject_withStream", test_deserialize_multiStringObject_withStream),

            ("test_deserialize_emptyArray_withStream", test_deserialize_emptyArray_withStream),
            ("test_deserialize_multiStringArray_withStream", test_deserialize_multiStringArray_withStream),
            ("test_deserialize_unicodeString_withStream", test_deserialize_unicodeString_withStream),
            ("test_deserialize_stringWithSpacesAtStart_withStream", test_deserialize_stringWithSpacesAtStart_withStream),


            ("test_deserialize_values_withStream", test_deserialize_values_withStream),
            ("test_deserialize_values_as_reference_types_withStream", test_deserialize_values_as_reference_types_withStream),
            ("test_deserialize_numbers_withStream", test_deserialize_numbers_withStream),
            ("test_deserialize_numbers_as_reference_types_withStream", test_deserialize_numbers_as_reference_types_withStream),

            ("test_deserialize_simpleEscapeSequences_withStream", test_deserialize_simpleEscapeSequences_withStream),
            ("test_deserialize_unicodeEscapeSequence_withStream", test_deserialize_unicodeEscapeSequence_withStream),
            ("test_deserialize_unicodeSurrogatePairEscapeSequence_withStream", test_deserialize_unicodeSurrogatePairEscapeSequence_withStream),
            // Disabled due to uninitialized memory SR-606
            // ("test_deserialize_allowFragments_withStream", test_deserialize_allowFragments_withStream),

            ("test_deserialize_unterminatedObjectString_withStream", test_deserialize_unterminatedObjectString_withStream),
            ("test_deserialize_missingObjectKey_withStream", test_deserialize_missingObjectKey_withStream),
            ("test_deserialize_unexpectedEndOfFile_withStream", test_deserialize_unexpectedEndOfFile_withStream),
            ("test_deserialize_invalidValueInObject_withStream", test_deserialize_invalidValueInObject_withStream),
            ("test_deserialize_invalidValueIncorrectSeparatorInObject_withStream", test_deserialize_invalidValueIncorrectSeparatorInObject_withStream),
            ("test_deserialize_invalidValueInArray_withStream", test_deserialize_invalidValueInArray_withStream),
            ("test_deserialize_badlyFormedArray_withStream", test_deserialize_badlyFormedArray_withStream),
            ("test_deserialize_invalidEscapeSequence_withStream", test_deserialize_invalidEscapeSequence_withStream),
            ("test_deserialize_unicodeMissingLeadingSurrogate_withStream", test_deserialize_unicodeMissingLeadingSurrogate_withStream),
            ("test_deserialize_unicodeMissingTrailingSurrogate_withStream", test_deserialize_unicodeMissingTrailingSurrogate_withStream),
            ("test_JSONObjectWithStream_withFile", test_JSONObjectWithStream_withFile),
            ("test_JSONObjectWithStream_withURL", test_JSONObjectWithStream_withURL),
        ]
    }

    func test_deserialize_emptyObject_withData() {
        deserialize_emptyObject(objectType: .data)
    }

    func test_deserialize_multiStringObject_withData() {
        deserialize_multiStringObject(objectType: .data)
    }

    func test_deserialize_emptyArray_withData() {
        deserialize_emptyArray(objectType: .data)
    }

    func test_deserialize_multiStringArray_withData() {
        deserialize_multiStringArray(objectType: .data)
    }


    func test_deserialize_unicodeString_withData() {
        deserialize_unicodeString(objectType: .data)
    }

    func test_deserialize_stringWithSpacesAtStart_withData() {
        deserialize_stringWithSpacesAtStart(objectType: .data)
    }

    func test_deserialize_values_withData() {
        deserialize_values(objectType: .data)
    }

    func test_deserialize_values_as_reference_types_withData() {
        deserialize_values_as_reference_types(objectType: .data)
    }

    func test_deserialize_numbers_withData() {
        deserialize_numbers(objectType: .data)
    }

    func test_deserialize_numbers_as_reference_types_withData() {
        deserialize_numbers_as_reference_types(objectType: .data)
    }

    func test_deserialize_simpleEscapeSequences_withData() {
        deserialize_simpleEscapeSequences(objectType: .data)
    }

    func test_deserialize_unicodeEscapeSequence_withData() {
        deserialize_unicodeEscapeSequence(objectType: .data)
    }

    func test_deserialize_unicodeSurrogatePairEscapeSequence_withData() {
        deserialize_unicodeSurrogatePairEscapeSequence(objectType: .data)
    }

    // Disabled due to uninitialized memory SR-606
    //    func test_deserialize_allowFragments_withData() {
    //        deserialize_allowFragments(objectType: .data)
    //    }

    func test_deserialize_unterminatedObjectString_withData() {
        deserialize_unterminatedObjectString(objectType: .data)
    }

    func test_deserialize_missingObjectKey_withData() {
        deserialize_missingObjectKey(objectType: .data)
    }

    func test_deserialize_unexpectedEndOfFile_withData() {
        deserialize_unexpectedEndOfFile(objectType: .data)
    }

    func test_deserialize_invalidValueInObject_withData() {
        deserialize_invalidValueInObject(objectType: .data)
    }

    func test_deserialize_invalidValueIncorrectSeparatorInObject_withData() {
        deserialize_invalidValueIncorrectSeparatorInObject(objectType: .data)
    }

    func test_deserialize_invalidValueInArray_withData() {
        deserialize_invalidValueInArray(objectType: .data)
    }

    func test_deserialize_badlyFormedArray_withData() {
        deserialize_badlyFormedArray(objectType: .data)
    }

    func test_deserialize_invalidEscapeSequence_withData() {
        deserialize_invalidEscapeSequence(objectType: .data)
    }

    func test_deserialize_unicodeMissingLeadingSurrogate_withData() {
        deserialize_unicodeMissingLeadingSurrogate(objectType: .data)
    }

    func test_deserialize_unicodeMissingTrailingSurrogate_withData() {
        deserialize_unicodeMissingTrailingSurrogate(objectType: .data)
    }

    func test_deserialize_emptyObject_withStream() {
        deserialize_emptyObject(objectType: .stream)
    }

    func test_deserialize_multiStringObject_withStream() {
        deserialize_multiStringObject(objectType: .stream)
    }

    func test_deserialize_emptyArray_withStream() {
        deserialize_emptyArray(objectType: .stream)
    }

    func test_deserialize_multiStringArray_withStream() {
        deserialize_multiStringArray(objectType: .stream)
    }


    func test_deserialize_unicodeString_withStream() {
        deserialize_unicodeString(objectType: .stream)
    }

    func test_deserialize_stringWithSpacesAtStart_withStream() {
        deserialize_stringWithSpacesAtStart(objectType: .stream)
    }

    func test_deserialize_values_withStream() {
        deserialize_values(objectType: .stream)
    }

    func test_deserialize_values_as_reference_types_withStream() {
        deserialize_values_as_reference_types(objectType: .stream)
    }

    func test_deserialize_numbers_withStream() {
        deserialize_numbers(objectType: .stream)
    }

    func test_deserialize_numbers_as_reference_types_withStream() {
        deserialize_numbers_as_reference_types(objectType: .stream)
    }

    func test_deserialize_simpleEscapeSequences_withStream() {
        deserialize_simpleEscapeSequences(objectType: .stream)
    }

    func test_deserialize_unicodeEscapeSequence_withStream() {
        deserialize_unicodeEscapeSequence(objectType: .stream)
    }

    func test_deserialize_unicodeSurrogatePairEscapeSequence_withStream() {
        deserialize_unicodeSurrogatePairEscapeSequence(objectType: .stream)
    }

    // Disabled due to uninitialized memory SR-606
    //    func test_deserialize_allowFragments_withStream() {
    //        deserialize_allowFragments(objectType: .stream)
    //    }

    func test_deserialize_unterminatedObjectString_withStream() {
        deserialize_unterminatedObjectString(objectType: .stream)
    }

    func test_deserialize_missingObjectKey_withStream() {
        deserialize_missingObjectKey(objectType: .stream)
    }

    func test_deserialize_unexpectedEndOfFile_withStream() {
        deserialize_unexpectedEndOfFile(objectType: .stream)
    }

    func test_deserialize_invalidValueInObject_withStream() {
        deserialize_invalidValueInObject(objectType: .stream)
    }

    func test_deserialize_invalidValueIncorrectSeparatorInObject_withStream() {
        deserialize_invalidValueIncorrectSeparatorInObject(objectType: .stream)
    }

    func test_deserialize_invalidValueInArray_withStream() {
        deserialize_invalidValueInArray(objectType: .stream)
    }

    func test_deserialize_badlyFormedArray_withStream() {
        deserialize_badlyFormedArray(objectType: .stream)
    }

    func test_deserialize_invalidEscapeSequence_withStream() {
        deserialize_invalidEscapeSequence(objectType: .stream)
    }

    func test_deserialize_unicodeMissingLeadingSurrogate_withStream() {
        deserialize_unicodeMissingLeadingSurrogate(objectType: .stream)
    }

    func test_deserialize_unicodeMissingTrailingSurrogate_withStream() {
        deserialize_unicodeMissingTrailingSurrogate(objectType: .stream)
    }

    //MARK: - Object Deserialization
    func deserialize_emptyObject(objectType: ObjectType) {
        let subject = "{}"
        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let result = try getjsonObjectResult(data, objectType) as? [String: Any]

            XCTAssertEqual(result?.count, 0)
        } catch {
            XCTFail("Error thrown: \(error)")
        }
    }

    func deserialize_multiStringObject(objectType: ObjectType) {
        let subject = "{ \"hello\": \"world\", \"swift\": \"rocks\" }"
        do {
            for encoding in [String.Encoding.utf8, String.Encoding.utf16BigEndian] {
                guard let data = subject.data(using: encoding) else {
                    XCTFail("Unable to convert string to data")
                    return
                }
                let result = try getjsonObjectResult(data, objectType) as? [String: Any]
                XCTAssertEqual(result?["hello"] as? String, "world")
                XCTAssertEqual(result?["swift"] as? String, "rocks")
            }
        } catch {
            XCTFail("Error thrown: \(error)")
        }
    }

    func deserialize_stringWithSpacesAtStart(objectType: ObjectType) {
        let subject = "{\"title\" : \" hello world!!\" }"
        do {
            guard let data = subject.data(using: .utf8) else  {
                XCTFail("Unable to convert string to data")
                return
            }
            let result = try getjsonObjectResult(data, objectType) as? [String: Any]
            XCTAssertEqual(result?["title"] as? String, " hello world!!")
        } catch{
            XCTFail("Error thrown: \(error)")
        }
    }

    //MARK: - Array Deserialization
    func deserialize_emptyArray(objectType: ObjectType) {
        let subject = "[]"

        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let result = try getjsonObjectResult(data, objectType) as? [Any]
            XCTAssertEqual(result?.count, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func deserialize_multiStringArray(objectType: ObjectType) {
        let subject = "[\"hello\", \"swift⚡️\"]"

        do {
            for encoding in [String.Encoding.utf8, String.Encoding.utf16BigEndian] {
                guard let data = subject.data(using: encoding) else {
                    XCTFail("Unable to convert string to data")
                    return
                }
                let result = try getjsonObjectResult(data, objectType) as? [Any]
                XCTAssertEqual(result?[0] as? String, "hello")
                XCTAssertEqual(result?[1] as? String, "swift⚡️")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func deserialize_unicodeString(objectType: ObjectType) {
        /// Ģ has the same LSB as quotation mark " (U+0022) so test guarding against this case
        let subject = "[\"unicode\", \"Ģ\", \"😢\"]"
        do {
            for encoding in [String.Encoding.utf16LittleEndian, String.Encoding.utf16BigEndian, String.Encoding.utf32LittleEndian, String.Encoding.utf32BigEndian] {
                guard let data = subject.data(using: encoding) else {
                    XCTFail("Unable to convert string to data")
                    return
                }
                let result = try getjsonObjectResult(data, objectType) as? [Any]
                XCTAssertEqual(result?[0] as? String, "unicode")
                XCTAssertEqual(result?[1] as? String, "Ģ")
                XCTAssertEqual(result?[2] as? String, "😢")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    //MARK: - Value parsing
    func deserialize_values(objectType: ObjectType) {
        let subject = "[true, false, \"hello\", null, {}, []]"

        do {
            for encoding in supportedEncodings {
                guard let data = subject.data(using: encoding) else {
                    XCTFail("Unable to convert string to data")
                    return
                }
                let result = try getjsonObjectResult(data, objectType) as? [Any]
                XCTAssertEqual(result?[0] as? Bool, true)
                XCTAssertEqual(result?[1] as? Bool, false)
                XCTAssertEqual(result?[2] as? String, "hello")
                XCTAssertNotNil(result?[3] as? NSNull)
                XCTAssertNotNil(result?[4] as? [String:Any])
                XCTAssertNotNil(result?[5] as? [Any])
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func deserialize_values_as_reference_types(objectType: ObjectType) {
        let subject = "[true, false, \"hello\", null, {}, []]"

        do {
            for encoding in supportedEncodings {
                guard let data = subject.data(using: encoding) else {
                    XCTFail("Unable to convert string to data")
                    return
                }
                let result = try getjsonObjectResult(data, objectType) as? [Any]
                XCTAssertEqual(result?[0] as? NSNumber, true)
                XCTAssertEqual(result?[1] as? NSNumber, false)
                XCTAssertEqual(result?[2] as? String, "hello")
                XCTAssertNotNil(result?[3] as? NSNull)
                XCTAssertNotNil(result?[4] as? [String:Any])
                XCTAssertNotNil(result?[5] as? [Any])
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    //MARK: - Number parsing
    func deserialize_numbers(objectType: ObjectType) {
        let subject = "[1, -1, 1.3, -1.3, 1e3, 1E-3, 10, -12.34e56, 12.34e-56, 12.34e+6, 0.002, 0.0043e+4]"

        do {
            for encoding in supportedEncodings {
                guard let data = subject.data(using: encoding) else {
                    XCTFail("Unable to convert string to data")
                    return
                }
                let result = try getjsonObjectResult(data, objectType) as? [Any]
                XCTAssertEqual(result?[0] as? Int,    1)
                XCTAssertEqual(result?[1] as? Int,    -1)
                XCTAssertEqual(result?[2] as? Double, 1.3)
                XCTAssertEqual(result?[3] as? Double, -1.3)
                XCTAssertEqual(result?[4] as? Int,    1000)
                XCTAssertEqual(result?[5] as? Double, 0.001)
                XCTAssertEqual(result?[6] as? Int,    10)
                XCTAssertEqual(result?[6] as? Double, 10.0)
                XCTAssertEqual(result?[7] as? Double, -12.34e56)
                XCTAssertEqual(result?[8] as? Double, 12.34e-56)
                XCTAssertEqual(result?[9] as? Double, 12.34e6)
                XCTAssertEqual(result?[10] as? Double, 2e-3)
                XCTAssertEqual(result?[11] as? Double, 43)
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func deserialize_numbers_as_reference_types(objectType: ObjectType) {
        let subject = "[1, -1, 1.3, -1.3, 1e3, 1E-3, 10, -12.34e56, 12.34e-56, 12.34e+6, 0.002, 0.0043e+4]"

        do {
            for encoding in supportedEncodings {
                guard let data = subject.data(using: encoding) else {
                    XCTFail("Unable to convert string to data")
                    return
                }
                let result = try getjsonObjectResult(data, objectType) as? [Any]
                XCTAssertEqual(result?[0] as? NSNumber, 1)
                XCTAssertEqual(result?[1] as? NSNumber, -1)
                XCTAssertEqual(result?[2] as? NSNumber, 1.3)
                XCTAssertEqual(result?[3] as? NSNumber, -1.3)
                XCTAssertEqual(result?[4] as? NSNumber, 1000)
                XCTAssertEqual(result?[5] as? NSNumber, 0.001)
                XCTAssertEqual(result?[6] as? NSNumber, 10)
                XCTAssertEqual(result?[6] as? NSNumber, 10.0)
                XCTAssertEqual(result?[7] as? NSNumber, -12.34e56)
                XCTAssertEqual(result?[8] as? NSNumber, 12.34e-56)
                XCTAssertEqual(result?[9] as? NSNumber, 12.34e6)
                XCTAssertEqual(result?[10] as? NSNumber, 2e-3)
                XCTAssertEqual(result?[11] as? NSNumber, 43)

            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    //MARK: - Escape Sequences
    func deserialize_simpleEscapeSequences(objectType: ObjectType) {
        let subject = "[\"\\\"\", \"\\\\\", \"\\/\", \"\\b\", \"\\f\", \"\\n\", \"\\r\", \"\\t\"]"
        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let res = try getjsonObjectResult(data, objectType) as? [Any]
            let result = res?.compactMap { $0 as? String }
            XCTAssertEqual(result?[0], "\"")
            XCTAssertEqual(result?[1], "\\")
            XCTAssertEqual(result?[2], "/")
            XCTAssertEqual(result?[3], "\u{08}")
            XCTAssertEqual(result?[4], "\u{0C}")
            XCTAssertEqual(result?[5], "\u{0A}")
            XCTAssertEqual(result?[6], "\u{0D}")
            XCTAssertEqual(result?[7], "\u{09}")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func deserialize_unicodeEscapeSequence(objectType: ObjectType) {
        let subject = "[\"\\u2728\"]"
        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let result = try getjsonObjectResult(data, objectType) as? [Any]
            // result?[0] as? String returns an Optional<String> and RHS is promoted
            // to Optional<String>
            XCTAssertEqual(result?[0] as? String, "✨")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func deserialize_unicodeSurrogatePairEscapeSequence(objectType: ObjectType) {
        let subject = "[\"\\uD834\\udd1E\"]"
        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let result = try getjsonObjectResult(data, objectType) as? [Any]
            // result?[0] as? String returns an Optional<String> and RHS is promoted
            // to Optional<String>
            XCTAssertEqual(result?[0] as? String, "\u{1D11E}")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func deserialize_allowFragments(objectType: ObjectType) {
        let subject = "3"

        do {
            for encoding in supportedEncodings {
                guard let data = subject.data(using: encoding) else {
                    XCTFail("Unable to convert string to data")
                    return
                }
                let result = try getjsonObjectResult(data, objectType) as? Int
                XCTAssertEqual(result, 3)
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    //MARK: - Parsing Errors
    func deserialize_unterminatedObjectString(objectType: ObjectType) {
        let subject = "{\"}"

        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let _ = try getjsonObjectResult(data, objectType)
            XCTFail("Expected error: UnterminatedString")
        } catch {
            // Passing case; the object as unterminated
        }
    }

    func deserialize_missingObjectKey(objectType: ObjectType) {
        let subject = "{3}"

        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let _ = try getjsonObjectResult(data, objectType)
            XCTFail("Expected error: Missing key for value")
        } catch {
            // Passing case; the key was missing for a value
        }
    }

    func deserialize_unexpectedEndOfFile(objectType: ObjectType) {
        let subject = "{"

        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let _ = try getjsonObjectResult(data, objectType)
            XCTFail("Expected error: Unexpected end of file")
        } catch {
            // Success
        }
    }

    func deserialize_invalidValueInObject(objectType: ObjectType) {
        let subject = "{\"error\":}"

        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let _ = try getjsonObjectResult(data, objectType)
            XCTFail("Expected error: Invalid value")
        } catch {
            // Passing case; the value is invalid
        }
    }

    func deserialize_invalidValueIncorrectSeparatorInObject(objectType: ObjectType) {
        let subject = "{\"missing\";}"

        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let _ = try getjsonObjectResult(data, objectType)
            XCTFail("Expected error: Invalid value")
        } catch {
            // passing case the value is invalid
        }
    }

    func deserialize_invalidValueInArray(objectType: ObjectType) {
        let subject = "[,"

        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let _ = try getjsonObjectResult(data, objectType)
            XCTFail("Expected error: Invalid value")
        } catch {
            // Passing case; the element in the array is missing
        }
    }

    func deserialize_badlyFormedArray(objectType: ObjectType) {
        let subject = "[2b4]"

        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let _ = try getjsonObjectResult(data, objectType)
            XCTFail("Expected error: Badly formed array")
        } catch {
            // Passing case; the array is malformed
        }
    }

    func deserialize_invalidEscapeSequence(objectType: ObjectType) {
        let subject = "[\"\\e\"]"

        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let _ = try getjsonObjectResult(data, objectType)
            XCTFail("Expected error: Invalid escape sequence")
        } catch {
            // Passing case; the escape sequence is invalid
        }
    }

    func deserialize_unicodeMissingLeadingSurrogate(objectType: ObjectType) {
        let subject = "[\"\\uDFF3\"]"
        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let _ = try getjsonObjectResult(data, objectType) as? [String]
            XCTFail("Expected error: Missing Leading Surrogate")
        } catch {
            // Passing case; the unicode character is malformed
        }
    }

    func deserialize_unicodeMissingTrailingSurrogate(objectType: ObjectType) {
        let subject = "[\"\\uD834\"]"
        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            let _ = try getjsonObjectResult(data, objectType) as? [String]
            XCTFail("Expected error: Missing Trailing Surrogate")
        } catch {
            // Passing case; the unicode character is malformed
        }
    }

    func test_JSONObjectWithStream_withFile() {
        let subject = "{}"
        do {
            guard let data = subject.data(using: .utf8) else {
                XCTFail("Unable to convert string to data")
                return
            }
            if let filePath = createTestFile("TestJSON.txt",_contents: data) {
                let fileStream: InputStream = InputStream(fileAtPath: filePath)!
                fileStream.open()
                let resultRead = try JSONSerialization.jsonObject(with: fileStream, options: [])
                let result = resultRead as? [String: Any]
                XCTAssertEqual(result?.count, 0)
                fileStream.close()
                removeTestFile(filePath)
            }
        } catch {
            XCTFail("Error thrown: \(error)")
        }
    }

    func test_JSONObjectWithStream_withURL() {
        let subject = "[true, false, \"hello\", null, {}, []]"
        do {
            for encoding in supportedEncodings {
                guard let data = subject.data(using: encoding) else {
                    XCTFail("Unable to convert string to data")
                    return
                }
                if let filePath = createTestFile("TestJSON.txt",_contents: data) {
                    let url = URL(fileURLWithPath: filePath)
                    let inputStream: InputStream = InputStream(url: url)!
                    inputStream.open()
                    let result = try JSONSerialization.jsonObject(with: inputStream, options: []) as? [Any]
                    inputStream.close()
                    removeTestFile(filePath)
                    XCTAssertEqual(result?[0] as? Bool, true)
                    XCTAssertEqual(result?[1] as? Bool, false)
                    XCTAssertEqual(result?[2] as? String, "hello")
                    XCTAssertNotNil(result?[3] as? NSNull)
                    XCTAssertNotNil(result?[4] as? [String:Any])
                    XCTAssertNotNil(result?[5] as? [Any])
                }
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }


    private func getjsonObjectResult(_ data: Data,
                                     _ objectType: ObjectType,
                                     options opt: JSONSerialization.ReadingOptions = []) throws -> Any {
        var result: Any
        switch objectType {
        case .data:
            //Test with Data
            result = try JSONSerialization.jsonObject(with: data, options: opt)
        case .stream:
            //Test with stream
            let stream: InputStream = InputStream(data: data)
            stream.open()
            result = try JSONSerialization.jsonObject(with: stream, options: opt)
            stream.close()
        }
        return result
    }

}

// MARK: - isValidJSONObjectTests
extension TestJSONSerialization {

    class var isValidJSONObjectTests: [(String, (TestJSONSerialization) -> () throws -> Void)] {
        return [
            ("test_isValidJSONObjectTrue", test_isValidJSONObjectTrue),
            ("test_isValidJSONObjectFalse", test_isValidJSONObjectFalse),
            ("test_validNumericJSONObjects", test_validNumericJSONObjects)
        ]
    }

    func test_isValidJSONObjectTrue() {
        let trueJSON: [Any] = [
            // []
            Array<Any>(),

            // [1, ["string", [[]]]]
            Array<Any>(arrayLiteral:
                NSNumber(value: Int(1)),
                Array<Any>(arrayLiteral:
                    "string",
                    Array<Any>(arrayLiteral:
                        Array<Any>()
                    )
                )
            ),

            // [NSNull(), ["1" : ["string", 1], "2" : NSNull()]]
            Array<Any>(arrayLiteral:
                NSNull(),
                Dictionary<String, Any>(dictionaryLiteral:
                    (
                        "1",
                        Array<Any>(arrayLiteral:
                            "string",
                            NSNumber(value: Int(1))
                        )
                    ),
                    (
                        "2",
                        NSNull()
                    )
                )
            ),

            // ["0" : 0]
            Dictionary<String, Any>(dictionaryLiteral:
                (
                    "0",
                    NSNumber(value: Int(0))
                )
            ),
        ]
        for testCase in trueJSON {
            XCTAssertTrue(JSONSerialization.isValidJSONObject(testCase))
        }
        
        // [Any?.none]
        let optionalAny: Any? = nil
        let anyArray: [Any] = [optionalAny as Any]
        XCTAssertTrue(JSONSerialization.isValidJSONObject(anyArray))
    }

    func test_isValidJSONObjectFalse() {
        var falseJSON = [Any]()
        falseJSON.append(NSNumber(value: Int(0)))
        falseJSON.append(NSNull())
        falseJSON.append("string")
        falseJSON.append(Array<Any>(arrayLiteral:
            NSNumber(value: Int(1)),
            NSNumber(value: Int(2)),
            NSNumber(value: Int(3)),
            Dictionary<NSNumber, Any>(dictionaryLiteral:
                (
                    NSNumber(value: Int(4)),
                    NSNumber(value: Int(5))
                )
            )
        ))
        
        let one = NSNumber(value: Int(1))
        let two = NSNumber(value: Int(2))
        let divo = NSNumber(value: Double(1) / Double(0))
        falseJSON.append([one, two, divo])
        falseJSON.append([NSNull() : NSNumber(value: Int(1))])
        falseJSON.append(Array<Any>(arrayLiteral:
            Array<Any>(arrayLiteral:
                Array<Any>(arrayLiteral:
                    Dictionary<NSNumber, Any>(dictionaryLiteral:
                        (
                            NSNumber(value: Int(1)),
                            NSNumber(value: Int(2))
                        )
                    )
                )
            )
        ))
        
        for testCase in falseJSON {
            XCTAssertFalse(JSONSerialization.isValidJSONObject(testCase))
        }
    }

    func test_validNumericJSONObjects() {
        // All of the numeric types supported by JSONSerialization
        XCTAssertTrue(JSONSerialization.isValidJSONObject([nil, NSNull()]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject([true, false]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject([Int.min, Int8.min, Int16.min, Int32.min, Int64.min]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject([UInt.min, UInt8.min, UInt16.min, UInt32.min, UInt64.min]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject([Float.leastNonzeroMagnitude, Double.leastNonzeroMagnitude]))

        XCTAssertTrue(JSONSerialization.isValidJSONObject([NSNumber(value: true), NSNumber(value: Float.greatestFiniteMagnitude), NSNumber(value: Double.greatestFiniteMagnitude)]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject([NSNumber(value: Int.max), NSNumber(value: Int8.max), NSNumber(value: Int16.max), NSNumber(value: Int32.max), NSNumber(value: Int64.max)]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject([NSNumber(value: UInt.max), NSNumber(value: UInt8.max), NSNumber(value: UInt16.max), NSNumber(value: UInt32.max), NSNumber(value: UInt64.max)]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject([NSDecimalNumber(booleanLiteral: true), NSDecimalNumber(decimal: Decimal.greatestFiniteMagnitude)]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject([NSDecimalNumber(floatLiteral: Double(Float.greatestFiniteMagnitude)), NSDecimalNumber(integerLiteral: Int.min)]))
        XCTAssertTrue(JSONSerialization.isValidJSONObject([Decimal(123), Decimal(Double(Float.leastNonzeroMagnitude))]))

        XCTAssertFalse(JSONSerialization.isValidJSONObject(Float.nan))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(Float.infinity))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(-Float.infinity))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(NSNumber(value: Float.nan)))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(NSNumber(value: Float.infinity)))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(NSNumber(value: -Float.infinity)))

        XCTAssertFalse(JSONSerialization.isValidJSONObject(Double.nan))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(Double.infinity))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(-Double.infinity))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(NSNumber(value: Double.nan)))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(NSNumber(value: Double.infinity)))
        XCTAssertFalse(JSONSerialization.isValidJSONObject(NSNumber(value: -Double.infinity)))

        XCTAssertFalse(JSONSerialization.isValidJSONObject(NSDecimalNumber(decimal: Decimal(floatLiteral: Double.nan))))
    }
}

// MARK: - serializationTests
extension TestJSONSerialization {

    class var serializationTests: [(String, (TestJSONSerialization) -> () throws -> Void)] {
        return [
            ("test_serialize_emptyObject", test_serialize_emptyObject),
            ("test_serialize_null", test_serialize_null),
            ("test_serialize_complexObject", test_serialize_complexObject),
            ("test_nested_array", test_nested_array),
            ("test_nested_dictionary", test_nested_dictionary),
            ("test_serialize_number", test_serialize_number),
            ("test_serialize_IntMax", test_serialize_IntMax),
            ("test_serialize_IntMin", test_serialize_IntMin),
            ("test_serialize_UIntMax", test_serialize_UIntMax),
            ("test_serialize_UIntMin", test_serialize_UIntMin),
            ("test_serialize_8BitSizes", test_serialize_8BitSizes),
            ("test_serialize_16BitSizes", test_serialize_16BitSizes),
            ("test_serialize_32BitSizes", test_serialize_32BitSizes),
            ("test_serialize_64BitSizes", test_serialize_64BitSizes),
            ("test_serialize_Float", test_serialize_Float),
            ("test_serialize_Double", test_serialize_Double),
            ("test_serialize_Decimal", test_serialize_Decimal),
            ("test_serialize_NSDecimalNumber", test_serialize_NSDecimalNumber),
            ("test_serialize_stringEscaping", test_serialize_stringEscaping),
            ("test_jsonReadingOffTheEndOfBuffers", test_jsonReadingOffTheEndOfBuffers),
            ("test_jsonObjectToOutputStreamBuffer", test_jsonObjectToOutputStreamBuffer),
            ("test_jsonObjectToOutputStreamFile", test_jsonObjectToOutputStreamFile),
            ("test_jsonObjectToOutputStreamInsufficientBuffer", test_jsonObjectToOutputStreamInsufficientBuffer),
            ("test_booleanJSONObject", test_booleanJSONObject),
            ("test_serialize_dictionaryWithDecimal", test_serialize_dictionaryWithDecimal),
            ("test_serializeDecimalNumberJSONObject", test_serializeDecimalNumberJSONObject),
            ("test_serializeSortedKeys", test_serializeSortedKeys),
            ("test_serializePrettyPrinted", test_serializePrettyPrinted),
        ]
    }

    func trySerialize(_ obj: Any, options: JSONSerialization.WritingOptions = []) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: obj, options: options)
        guard let string = String(data: data, encoding: .utf8) else {
            XCTFail("Unable to create string")
            return ""
        }
        return string
    }

    func test_serialize_emptyObject() {
        let dict1 = [String: Any]()
        XCTAssertEqual(try trySerialize(dict1), "{}")
            
        let dict2 = [String: NSNumber]()
        XCTAssertEqual(try trySerialize(dict2), "{}")

        let dict3 = [String: String]()
        XCTAssertEqual(try trySerialize(dict3), "{}")

        let array1 = [String]()
        XCTAssertEqual(try trySerialize(array1), "[]")

        let array2 = [NSNumber]()
        XCTAssertEqual(try trySerialize(array2), "[]")
    }
    
    //[SR-2151] https://bugs.swift.org/browse/SR-2151
    //JSONSerialization.data(withJSONObject:options) produces illegal JSON code
    func test_serialize_dictionaryWithDecimal() {
        
        //test serialize values less than 1 with maxFractionDigits = 15
        func excecute_testSetLessThanOne() {
            //expected : input to be serialized
            let params  = [
                           ("0.1",0.1),
                           ("0.2",0.2),
                           ("0.3",0.3),
                           ("0.4",0.4),
                           ("0.5",0.5),
                           ("0.6",0.6),
                           ("0.7",0.7),
                           ("0.8",0.8),
                           ("0.9",0.9),
                           ("0.23456789012345",0.23456789012345),

                           ("-0.1",-0.1),
                           ("-0.2",-0.2),
                           ("-0.3",-0.3),
                           ("-0.4",-0.4),
                           ("-0.5",-0.5),
                           ("-0.6",-0.6),
                           ("-0.7",-0.7),
                           ("-0.8",-0.8),
                           ("-0.9",-0.9),
                           ("-0.23456789012345",-0.23456789012345),
                           ]
            for param in params {
                let testDict = [param.0 : param.1]
                let str = try? trySerialize(testDict)
                XCTAssertEqual(str!, "{\"\(param.0)\":\(param.1)}", "serialized value should  have a decimal places and leading zero")
            }
        }
        //test serialize values grater than 1 with maxFractionDigits = 15
        func excecute_testSetGraterThanOne() {
            let paramsBove1 = [
                ("1.1",1.1),
                ("1.2",1.2),
                ("1.23456789012345",1.23456789012345),
                ("-1.1",-1.1),
                ("-1.2",-1.2),
                ("-1.23456789012345",-1.23456789012345),
                ]
            for param in paramsBove1 {
                let testDict = [param.0 : param.1]
                let str = try? trySerialize(testDict)
                XCTAssertEqual(str!, "{\"\(param.0)\":\(param.1)}", "serialized Double should  have a decimal places and leading value")
            }
        }

        //test serialize values for whole integer where the input is in Double format
        func excecute_testWholeNumbersWithDoubleAsInput() {
            
            let paramsWholeNumbers = [
                ("-1"  ,-1.0),
                ("0"  ,0.0),
                ("1"  ,1.0),
                ]
            for param in paramsWholeNumbers {
                let testDict = [param.0 : param.1]
                let str = try? trySerialize(testDict)
                XCTAssertEqual(str!, "{\"\(param.0)\":\(NSString(string:param.0).intValue)}", "expect that serialized value should not contain trailing zero or decimal as they are whole numbers ")
            }
        }
        
        func excecute_testWholeNumbersWithIntInput() {
            for i  in -10..<10 {
                let iStr = "\(i)"
                let testDict = [iStr : i]
                let str = try? trySerialize(testDict)
                XCTAssertEqual(str!, "{\"\(iStr)\":\(i)}", "expect that serialized value should not contain trailing zero or decimal as they are whole numbers ")
            }
        }
        excecute_testSetLessThanOne()
        excecute_testSetGraterThanOne()
        excecute_testWholeNumbersWithDoubleAsInput()
        excecute_testWholeNumbersWithIntInput()
    }
    
    func test_serialize_null() {
        let arr = [NSNull()]
        XCTAssertEqual(try trySerialize(arr), "[null]")
        
        let dict = ["a":NSNull()]
        XCTAssertEqual(try trySerialize(dict), "{\"a\":null}")
        
        let arr2 = [NSNull(), NSNull(), NSNull()]
        XCTAssertEqual(try trySerialize(arr2), "[null,null,null]")
        
        let dict2 = [["a":NSNull()], ["b":NSNull()], ["c":NSNull()]]
        XCTAssertEqual(try trySerialize(dict2), "[{\"a\":null},{\"b\":null},{\"c\":null}]")
        
        let arr3 = [nil] as [Any?]
        XCTAssertEqual(try trySerialize(arr3), "[null]")
        
        let dict3 = ["a":nil] as [String: Any?]
        XCTAssertEqual(try trySerialize(dict3), "{\"a\":null}")
        
        let arr4 = [nil, nil, nil] as [Any?]
        XCTAssertEqual(try trySerialize(arr4), "[null,null,null]")
        
        let dict4 = [["a": nil] as [String: Any?], ["b": nil] as [String: Any?], ["c": nil] as [String: Any?]]
        XCTAssertEqual(try trySerialize(dict4), "[{\"a\":null},{\"b\":null},{\"c\":null}]")
        
        let arr5 = [Optional<Any>.none]
        XCTAssertEqual(try trySerialize(arr5), "[null]")
        
        let arr6: Array<Optional<Any>> = [Bool?.none, String?.none, Int?.none, [Any?]?.none]
        XCTAssertEqual(try trySerialize(arr6), "[null,null,null,null]")
    }

    func test_serialize_complexObject() {
        let jsonDict = ["a": 4]
        XCTAssertEqual(try trySerialize(jsonDict), "{\"a\":4}")

        let jsonArr = [1, 2, 3, 4]
        XCTAssertEqual(try trySerialize(jsonArr), "[1,2,3,4]")

        let jsonDict2 = ["a": [1,2]]
        XCTAssertEqual(try trySerialize(jsonDict2), "{\"a\":[1,2]}")

        let jsonArr2 = ["a", "b", "c"]
        XCTAssertEqual(try trySerialize(jsonArr2), "[\"a\",\"b\",\"c\"]")
        
        let jsonArr3 = [["a":1],["b":2]]
        XCTAssertEqual(try trySerialize(jsonArr3), "[{\"a\":1},{\"b\":2}]")
        
        let jsonArr4 = [["a":NSNull()],["b":NSNull()]]
        XCTAssertEqual(try trySerialize(jsonArr4), "[{\"a\":null},{\"b\":null}]")
    }
    
    func test_nested_array() {
        var arr: [Any] = ["a"]
        XCTAssertEqual(try trySerialize(arr), "[\"a\"]")
        
        arr = [["b"]]
        XCTAssertEqual(try trySerialize(arr), "[[\"b\"]]")
        
        arr = [[["c"]]]
        XCTAssertEqual(try trySerialize(arr), "[[[\"c\"]]]")
        
        arr = [[[["d"]]]]
        XCTAssertEqual(try trySerialize(arr), "[[[[\"d\"]]]]")
    }
    
    func test_nested_dictionary() {
        var dict: [AnyHashable : Any] = ["a":1]
        XCTAssertEqual(try trySerialize(dict), "{\"a\":1}")
        
        dict = ["a":["b":1]]
        XCTAssertEqual(try trySerialize(dict), "{\"a\":{\"b\":1}}")
        
        dict = ["a":["b":["c":1]]]
        XCTAssertEqual(try trySerialize(dict), "{\"a\":{\"b\":{\"c\":1}}}")
        
        dict = ["a":["b":["c":["d":1]]]]
        XCTAssertEqual(try trySerialize(dict), "{\"a\":{\"b\":{\"c\":{\"d\":1}}}}")
        
        dict = ["a":["b":["c":[1, Optional<Any>.none]]]]
        XCTAssertEqual(try trySerialize(dict), "{\"a\":{\"b\":{\"c\":[1,null]}}}")
    }
    
    func test_serialize_number() {
        var json: [Any] = [1, 1.1, 0, -2]
        XCTAssertEqual(try trySerialize(json), "[1,1.1,0,-2]")
        
        // Cannot generate "true"/"false" currently
        json = [NSNumber(value:false),NSNumber(value:true)]
        XCTAssertEqual(try trySerialize(json), "[false,true]")
    }
    
    func test_serialize_IntMax() {
        let json: [Any] = [Int.max]
        XCTAssertEqual(try trySerialize(json), "[\(Int.max)]")
    }
    
    func test_serialize_IntMin() {
        let json: [Any] = [Int.min]
        XCTAssertEqual(try trySerialize(json), "[\(Int.min)]")
    }
    
    func test_serialize_UIntMax() {
        let json: [Any] = [UInt.max]
        XCTAssertEqual(try trySerialize(json), "[\(UInt.max)]")
    }
    
    func test_serialize_UIntMin() {
        let array: [UInt] = [UInt.min]
        let json = array as [Any]
        XCTAssertEqual(try trySerialize(json), "[\(UInt.min)]")
    }

    func test_serialize_8BitSizes() {
        let json1 = [Int8.min, Int8(-1), Int8(0), Int8(1), Int8.max]
        XCTAssertEqual(try trySerialize(json1), "[-128,-1,0,1,127]")
        let json2 = [UInt8.min, UInt8(0), UInt8(1), UInt8.max]
        XCTAssertEqual(try trySerialize(json2), "[0,0,1,255]")
    }

    func test_serialize_16BitSizes() {
        let json1 = [Int16.min, Int16(-1), Int16(0), Int16(1), Int16.max]
        XCTAssertEqual(try trySerialize(json1), "[-32768,-1,0,1,32767]")
        let json2 = [UInt16.min, UInt16(0), UInt16(1), UInt16.max]
        XCTAssertEqual(try trySerialize(json2), "[0,0,1,65535]")
    }

    func test_serialize_32BitSizes() {
        let json1 = [Int32.min, Int32(-1), Int32(0), Int32(1), Int32.max]
        XCTAssertEqual(try trySerialize(json1), "[-2147483648,-1,0,1,2147483647]")
        let json2 = [UInt32.min, UInt32(0), UInt32(1), UInt32.max]
        XCTAssertEqual(try trySerialize(json2), "[0,0,1,4294967295]")
    }

    func test_serialize_64BitSizes() {
        let json1 = [Int64.min, Int64(-1), Int64(0), Int64(1), Int64.max]
        XCTAssertEqual(try trySerialize(json1), "[-9223372036854775808,-1,0,1,9223372036854775807]")
        let json2 = [UInt64.min, UInt64(0), UInt64(1), UInt64.max]
        XCTAssertEqual(try trySerialize(json2), "[0,0,1,18446744073709551615]")
    }

    func test_serialize_Float() {
        XCTAssertEqual(try trySerialize([-Float.leastNonzeroMagnitude, Float.leastNonzeroMagnitude]), "[-1e-45,1e-45]")
        XCTAssertEqual(try trySerialize([-Float.greatestFiniteMagnitude]), "[-3.4028235e+38]")
        XCTAssertEqual(try trySerialize([Float.greatestFiniteMagnitude]), "[3.4028235e+38]")
        XCTAssertEqual(try trySerialize([Float(-1), Float.leastNonzeroMagnitude, Float(1)]), "[-1,1e-45,1]")
    }

    func test_serialize_Double() {
        XCTAssertEqual(try trySerialize([-Double.leastNonzeroMagnitude, Double.leastNonzeroMagnitude]), "[-5e-324,5e-324]")
        XCTAssertEqual(try trySerialize([-Double.leastNormalMagnitude, Double.leastNormalMagnitude]), "[-2.2250738585072014e-308,2.2250738585072014e-308]")
        XCTAssertEqual(try trySerialize([-Double.greatestFiniteMagnitude]), "[-1.7976931348623157e+308]")
        XCTAssertEqual(try trySerialize([Double.greatestFiniteMagnitude]), "[1.7976931348623157e+308]")
        XCTAssertEqual(try trySerialize([Double(-1.0),  Double(1.0)]), "[-1,1]")

        // Test round-tripping Double values
        let value1 = 7.7087009966199993
        let value2 = 7.7087009966200002
        let dict1 = ["value": value1]
        let dict2 = ["value": value2]
        let jsonData1 = try! JSONSerialization.data(withJSONObject: dict1)
        let jsonData2 = try! JSONSerialization.data(withJSONObject: dict2)
        let jsonString1 = String(decoding: jsonData1, as: UTF8.self)
        let jsonString2 = String(decoding: jsonData2, as: UTF8.self)

        XCTAssertEqual(jsonString1, "{\"value\":7.708700996619999}")
        XCTAssertEqual(jsonString2, "{\"value\":7.70870099662}")
        let decodedDict1 = try! JSONSerialization.jsonObject(with: jsonData1) as! [String : Double]
        let decodedDict2 = try! JSONSerialization.jsonObject(with: jsonData2) as! [String : Double]
        XCTAssertEqual(decodedDict1["value"], value1)
        XCTAssertEqual(decodedDict2["value"], value2)
    }

    func test_serialize_Decimal() {
        XCTAssertEqual(try trySerialize([-Decimal.leastFiniteMagnitude]), "[3402823669209384634633746074317682114550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000]")
        XCTAssertEqual(try trySerialize([Decimal.leastFiniteMagnitude]), "[-3402823669209384634633746074317682114550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000]")
        XCTAssertEqual(try trySerialize([-Decimal.leastNonzeroMagnitude]), "[-0.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001]")
        XCTAssertEqual(try trySerialize([Decimal.leastNonzeroMagnitude]), "[0.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001]")
        XCTAssertEqual(try trySerialize([-Decimal.greatestFiniteMagnitude]), "[-3402823669209384634633746074317682114550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000]")
        XCTAssertEqual(try trySerialize([Decimal.greatestFiniteMagnitude]), "[3402823669209384634633746074317682114550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000]")
        XCTAssertEqual(try trySerialize([Decimal(Int8.min), Decimal(Int8(0)), Decimal(Int8.max)]), "[-128,0,127]")
        XCTAssertEqual(try trySerialize([Decimal(string: "-0.0"), Decimal(string: "0.000"), Decimal(string: "1.0000")]), "[0,0,1]")
    }

    func test_serialize_NSDecimalNumber() {
        let dn0: [Any] = [NSDecimalNumber(floatLiteral: Double(-Float.leastNonzeroMagnitude))]
        let dn1: [Any] = [NSDecimalNumber(floatLiteral: Double(Float.leastNonzeroMagnitude))]
        let dn2: [Any] = [NSDecimalNumber(floatLiteral: Double(-Float.leastNormalMagnitude))]
        let dn3: [Any] = [NSDecimalNumber(floatLiteral: Double(Float.leastNormalMagnitude))]
        let dn4: [Any] = [NSDecimalNumber(floatLiteral: Double(-Float.greatestFiniteMagnitude))]
        let dn5: [Any] = [NSDecimalNumber(floatLiteral: Double(Float.greatestFiniteMagnitude))]

        XCTAssertEqual(try trySerialize(dn0), "[-0.0000000000000000000000000000000000000000000014012984643248173056]")
        XCTAssertEqual(try trySerialize(dn1), "[0.0000000000000000000000000000000000000000000014012984643248173056]")
        XCTAssertEqual(try trySerialize(dn2), "[-0.000000000000000000000000000000000000011754943508222875648]")
        XCTAssertEqual(try trySerialize(dn3), "[0.000000000000000000000000000000000000011754943508222875648]")
        XCTAssertEqual(try trySerialize(dn4), "[-340282346638528921600000000000000000000]")
        XCTAssertEqual(try trySerialize(dn5), "[340282346638528921600000000000000000000]")
        XCTAssertEqual(try trySerialize([NSDecimalNumber(string: "0.0001"), NSDecimalNumber(string: "0.00"), NSDecimalNumber(string: "-0.0")]), "[0.0001,0,0]")
        XCTAssertEqual(try trySerialize([NSDecimalNumber(integerLiteral: Int(Int16.min)), NSDecimalNumber(integerLiteral: 0), NSDecimalNumber(integerLiteral: Int(Int16.max))]), "[-32768,0,32767]")
        XCTAssertEqual(try trySerialize([NSDecimalNumber(booleanLiteral: true), NSDecimalNumber(booleanLiteral: false)]), "[1,0]")
    }

    func test_serialize_stringEscaping() {
        var json = ["foo"]
        XCTAssertEqual(try trySerialize(json), "[\"foo\"]")

        json = ["a\0"]
        XCTAssertEqual(try trySerialize(json), "[\"a\\u0000\"]")
            
        json = ["b\\"]
        XCTAssertEqual(try trySerialize(json), "[\"b\\\\\"]")
        
        json = ["c\t"]
        XCTAssertEqual(try trySerialize(json), "[\"c\\t\"]")
        
        json = ["d\n"]
        XCTAssertEqual(try trySerialize(json), "[\"d\\n\"]")
        
        json = ["e\r"]
        XCTAssertEqual(try trySerialize(json), "[\"e\\r\"]")
        
        json = ["f\""]
        XCTAssertEqual(try trySerialize(json), "[\"f\\\"\"]")
        
        json = ["g\'"]
        XCTAssertEqual(try trySerialize(json), "[\"g\'\"]")
        
        json = ["h\u{7}"]
        XCTAssertEqual(try trySerialize(json), "[\"h\\u0007\"]")
        
        json = ["i\u{1f}"]
        XCTAssertEqual(try trySerialize(json), "[\"i\\u001f\"]")

        json = ["j/"]
        XCTAssertEqual(try trySerialize(json), "[\"j\\/\"]")
    }

    /* These are a programming error and should not be done
       Ideally the interface for JSONSerialization should at compile time prevent this type of thing
       by overloading the interface such that it can only accept dictionaries and arrays.
    func test_serialize_invalid_json() {
        let str = "Invalid JSON"
        do {
            let _ = try trySerialize(str)
            XCTFail("Top-level JSON object cannot be string")
        } catch {
            // should get here
        }
        
        let double = NSNumber(value: Double(1.2))
        do {
            let _ = try trySerialize(double)
            XCTFail("Top-level JSON object cannot be double")
        } catch {
            // should get here
        }
        
        let dict = [NSNumber(value: Double(1.2)):"a"]
        do {
            let _ = try trySerialize(dict)
            XCTFail("Dictionary keys must be strings")
        } catch {
            // should get here
        }
    }
 */
    
    func test_jsonReadingOffTheEndOfBuffers() {
        var data = "12345679".data(using: .utf8)!
        do {
            let res = try data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) -> Any in
                let slice = Data(bytesNoCopy: bytes.baseAddress!, count: 1, deallocator: .none)
                return try JSONSerialization.jsonObject(with: slice, options: .allowFragments)
            }
            if let num = res as? Int {
                XCTAssertEqual(1, num) // the slice truncation should only parse 1 byte!
            } else {
                XCTFail("expected an integer but got a \(res)")
            }
        } catch {
            XCTFail("Unknow json decoding failure")
        }
    }
    
    func test_jsonObjectToOutputStreamBuffer(){
        let dict = ["a":["b":1]]
        do {
            let buffer = Array<UInt8>(repeating: 0, count: 20)
            let outputStream = OutputStream(toBuffer: UnsafeMutablePointer(mutating: buffer), capacity: 20)
            outputStream.open()
            let result = try JSONSerialization.writeJSONObject(dict, toStream: outputStream, options: [])
            outputStream.close()
            if(result > -1) {
                XCTAssertEqual(NSString(bytes: buffer, length: buffer.firstIndex(of: 0) ?? buffer.count, encoding: String.Encoding.utf8.rawValue), "{\"a\":{\"b\":1}}")
            }
        } catch {
            XCTFail("Error thrown: \(error)")
        }
    }
    
    func test_jsonObjectToOutputStreamFile() {
        let dict = ["a":["b":1]]
        do {
            if let filePath = createTestFile("TestFileOut.txt",_contents: Data(capacity: 128)) {
                let outputStream = OutputStream(toFileAtPath: filePath, append: true)
                outputStream?.open()
                let result = try JSONSerialization.writeJSONObject(dict, toStream: outputStream!, options: [])
                outputStream?.close()
                if(result > -1) {
                    let fileStream: InputStream = InputStream(fileAtPath: filePath)!
                    var buffer = [UInt8](repeating: 0, count: 20)
                    fileStream.open()
                    if fileStream.hasBytesAvailable {
                        let resultRead: Int = fileStream.read(&buffer, maxLength: buffer.count)
                        fileStream.close()
                        if(resultRead > -1){
                            XCTAssertEqual(NSString(bytes: buffer, length: buffer.firstIndex(of: 0) ?? buffer.count, encoding: String.Encoding.utf8.rawValue), "{\"a\":{\"b\":1}}")
                        }
                    }
                    removeTestFile(filePath)
                } else {
                    XCTFail("Unable to create temp file")
                }
            }
        } catch {
            XCTFail("Error thrown: \(error)")
        }
    }
    
    func test_jsonObjectToOutputStreamInsufficientBuffer() {
#if !DARWIN_COMPATIBILITY_TESTS  // Hangs
        let dict = ["a":["b":1]]
        let buffer = Array<UInt8>(repeating: 0, count: 10)
        let outputStream = OutputStream(toBuffer: UnsafeMutablePointer(mutating: buffer), capacity: buffer.count)
        outputStream.open()
        do {
            let result = try JSONSerialization.writeJSONObject(dict, toStream: outputStream, options: [])
            outputStream.close()
            if(result > -1) {
                XCTAssertNotEqual(NSString(bytes: buffer, length: buffer.count, encoding: String.Encoding.utf8.rawValue), "{\"a\":{\"b\":1}}")
            }
        } catch {
            XCTFail("Error occurred while writing to stream")
        }
#endif
    }
    
    func test_booleanJSONObject() {
        do {
            let objectLikeBoolArray = try JSONSerialization.data(withJSONObject: [true, NSNumber(value: false), NSNumber(value: true)] as Array<Any>)
            XCTAssertEqual(String(data: objectLikeBoolArray, encoding: .utf8), "[true,false,true]")
            let valueLikeBoolArray = try JSONSerialization.data(withJSONObject: [false, true, false])
            XCTAssertEqual(String(data: valueLikeBoolArray, encoding: .utf8), "[false,true,false]")
        } catch {
            XCTFail("Failed during serialization")
        }
        XCTAssertTrue(JSONSerialization.isValidJSONObject([true]))
    }

    func test_serializeDecimalNumberJSONObject() {
        let decimalArray = "[12.1,10.0,0.0,0.0001,20,\(Int.max)]"
        do {
            let data = decimalArray.data(using: String.Encoding.utf8)
            let result = try JSONSerialization.jsonObject(with: data!, options: []) as? [Any]
            XCTAssertEqual(result?[0] as! Double, 12.1)
            XCTAssertEqual(result?[1] as! Int, 10)
            XCTAssertEqual(result?[2] as! Int, 0)
            XCTAssertEqual(result?[3] as! Double, 0.0001)
            XCTAssertEqual(result?[4] as! Int, 20)
            XCTAssertEqual(result?[5] as! Int, Int.max)
        } catch {
            XCTFail("Failed during serialization")
        }
        do {
            let data = decimalArray.data(using: String.Encoding.utf8)
            let result = try JSONSerialization.jsonObject(with: data!, options: []) as? [Any]
            XCTAssertEqual(result?[0] as! NSNumber, 12.1)
            XCTAssertEqual(result?[1] as! NSNumber, 10)
            XCTAssertEqual(result?[2] as! NSNumber, 0)
            XCTAssertEqual(result?[3] as! NSNumber, 0.0001)
            XCTAssertEqual(result?[4] as! NSNumber, 20)
            XCTAssertEqual(result?[5] as! NSNumber, NSNumber(value: Int.max))
        } catch {
            XCTFail("Failed during serialization")
        }
    } 

    func test_serializeSortedKeys() {
        let dict1 = ["z": 1, "y": 1, "x": 1, "w": 1, "v": 1, "u": 1, "t": 1, "s": 1, "r": 1, "q": 1, ]
        let dict2 = ["aaaa": 1, "aaa": 1, "aa": 1, "a": 1]
        let dict3 = ["c": ["c":1,"b":1,"a":1],"b":["c":1,"b":1,"a":1],"a":["c":1,"b":1,"a":1]]

#if DARWIN_COMPATIBILITY_TESTS
        if #available(macOS 10.13, *) {
            XCTAssertEqual(try trySerialize(dict1, options: .sortedKeys), "{\"q\":1,\"r\":1,\"s\":1,\"t\":1,\"u\":1,\"v\":1,\"w\":1,\"x\":1,\"y\":1,\"z\":1}")
            XCTAssertEqual(try trySerialize(dict2, options: .sortedKeys), "{\"a\":1,\"aa\":1,\"aaa\":1,\"aaaa\":1}")
            XCTAssertEqual(try trySerialize(dict3, options: .sortedKeys), "{\"a\":{\"a\":1,\"b\":1,\"c\":1},\"b\":{\"a\":1,\"b\":1,\"c\":1},\"c\":{\"a\":1,\"b\":1,\"c\":1}}")
        }
#else
        XCTAssertEqual(try trySerialize(dict1, options: .sortedKeys), "{\"q\":1,\"r\":1,\"s\":1,\"t\":1,\"u\":1,\"v\":1,\"w\":1,\"x\":1,\"y\":1,\"z\":1}")
        XCTAssertEqual(try trySerialize(dict2, options: .sortedKeys), "{\"a\":1,\"aa\":1,\"aaa\":1,\"aaaa\":1}")
        XCTAssertEqual(try trySerialize(dict3, options: .sortedKeys), "{\"a\":{\"a\":1,\"b\":1,\"c\":1},\"b\":{\"a\":1,\"b\":1,\"c\":1},\"c\":{\"a\":1,\"b\":1,\"c\":1}}")
#endif
    }

    func test_serializePrettyPrinted() {
        let dictionary = ["key": 4]
        XCTAssertEqual(try trySerialize(dictionary, options: .prettyPrinted), "{\n  \"key\" : 4\n}")
    }

    fileprivate func createTestFile(_ path: String,_contents: Data) -> String? {
        let tempDir = NSTemporaryDirectory() + "TestFoundation_Playground_" + NSUUID().uuidString + "/"
        do {
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: false, attributes: nil)
            if FileManager.default.createFile(atPath: tempDir + "/" + path, contents: _contents,
                                                attributes: nil) {
                return tempDir + path
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    fileprivate func removeTestFile(_ location: String) {
        try? FileManager.default.removeItem(atPath: location)
    }
}
