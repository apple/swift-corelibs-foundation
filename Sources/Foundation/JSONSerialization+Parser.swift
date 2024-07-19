//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//


internal struct JSONParser {
    var reader: DocumentReader
    var depth: Int = 0

    init(bytes: [UInt8]) {
        self.reader = DocumentReader(array: bytes)
    }

    mutating func parse() throws -> JSONValue {
        try reader.consumeWhitespace()
        let value = try self.parseValue()
        #if DEBUG
        defer {
            guard self.depth == 0 else {
                preconditionFailure("Expected to end parsing with a depth of 0")
            }
        }
        #endif

        // ensure only white space is remaining
        var whitespace = 0
        while let next = reader.peek(offset: whitespace) {
            switch next {
            case ._space, ._tab, ._return, ._newline:
                whitespace += 1
                continue
            default:
                throw JSONError.unexpectedCharacter(ascii: next, characterIndex: reader.readerIndex + whitespace)
            }
        }

        return value
    }

    // MARK: Generic Value Parsing

    mutating func parseValue() throws -> JSONValue {
        var whitespace = 0
        while let byte = reader.peek(offset: whitespace) {
            switch byte {
            case UInt8(ascii: "\""):
                reader.moveReaderIndex(forwardBy: whitespace)
                return .string(try reader.readString())
            case ._openbrace:
                reader.moveReaderIndex(forwardBy: whitespace)
                let object = try parseObject()
                return .object(object)
            case ._openbracket:
                reader.moveReaderIndex(forwardBy: whitespace)
                let array = try parseArray()
                return .array(array)
            case UInt8(ascii: "f"), UInt8(ascii: "t"):
                reader.moveReaderIndex(forwardBy: whitespace)
                let bool = try reader.readBool()
                return .bool(bool)
            case UInt8(ascii: "n"):
                reader.moveReaderIndex(forwardBy: whitespace)
                try reader.readNull()
                return .null
            case UInt8(ascii: "-"), UInt8(ascii: "0") ... UInt8(ascii: "9"):
                reader.moveReaderIndex(forwardBy: whitespace)
                let number = try self.reader.readNumber()
                return .number(number)
            case ._space, ._return, ._newline, ._tab:
                whitespace += 1
                continue
            default:
                throw JSONError.unexpectedCharacter(ascii: byte, characterIndex: self.reader.readerIndex)
            }
        }

        throw JSONError.unexpectedEndOfFile
    }


    // MARK: - Parse Array -

    mutating func parseArray() throws -> [JSONValue] {
        precondition(self.reader.read() == ._openbracket)
        guard self.depth < 512 else {
            throw JSONError.tooManyNestedArraysOrDictionaries(characterIndex: self.reader.readerIndex - 1)
        }
        self.depth += 1
        defer { depth -= 1 }

        // parse first value or end immediatly
        switch try reader.consumeWhitespace() {
        case ._space, ._return, ._newline, ._tab:
            preconditionFailure("Expected that all white space is consumed")
        case ._closebracket:
            // if the first char after whitespace is a closing bracket, we found an empty array
            self.reader.moveReaderIndex(forwardBy: 1)
            return []
        default:
            break
        }

        var array = [JSONValue]()
        array.reserveCapacity(10)

        // parse values
        while true {
            let value = try parseValue()
            array.append(value)

            // consume the whitespace after the value before the comma
            let ascii = try reader.consumeWhitespace()
            switch ascii {
            case ._space, ._return, ._newline, ._tab:
                preconditionFailure("Expected that all white space is consumed")
            case ._closebracket:
                reader.moveReaderIndex(forwardBy: 1)
                return array
            case ._comma:
                // consume the comma
                reader.moveReaderIndex(forwardBy: 1)
                // consume the whitespace before the next value
                if try reader.consumeWhitespace() == ._closebracket {
                    // the foundation json implementation does support trailing commas
                    reader.moveReaderIndex(forwardBy: 1)
                    return array
                }
                continue
            default:
                throw JSONError.unexpectedCharacter(ascii: ascii, characterIndex: reader.readerIndex)
            }
        }
    }

    // MARK: - Object parsing -

    mutating func parseObject() throws -> [String: JSONValue] {
        precondition(self.reader.read() == ._openbrace)
        guard self.depth < 512 else {
            throw JSONError.tooManyNestedArraysOrDictionaries(characterIndex: self.reader.readerIndex - 1)
        }
        self.depth += 1
        defer { depth -= 1 }

        // parse first value or end immediatly
        switch try reader.consumeWhitespace() {
        case ._space, ._return, ._newline, ._tab:
            preconditionFailure("Expected that all white space is consumed")
        case ._closebrace:
            // if the first char after whitespace is a closing bracket, we found an empty array
            self.reader.moveReaderIndex(forwardBy: 1)
            return [:]
        default:
            break
        }

        var object = [String: JSONValue]()
        object.reserveCapacity(20)

        while true {
            let key = try reader.readString()
            let colon = try reader.consumeWhitespace()
            guard colon == ._colon else {
                throw JSONError.unexpectedCharacter(ascii: colon, characterIndex: reader.readerIndex)
            }
            reader.moveReaderIndex(forwardBy: 1)
            try reader.consumeWhitespace()
            object[key] = try self.parseValue()

            let commaOrBrace = try reader.consumeWhitespace()
            switch commaOrBrace {
            case ._closebrace:
                reader.moveReaderIndex(forwardBy: 1)
                return object
            case ._comma:
                reader.moveReaderIndex(forwardBy: 1)
                if try reader.consumeWhitespace() == ._closebrace {
                    // the foundation json implementation does support trailing commas
                    reader.moveReaderIndex(forwardBy: 1)
                    return object
                }
                continue
            default:
                throw JSONError.unexpectedCharacter(ascii: commaOrBrace, characterIndex: reader.readerIndex)
            }
        }
    }
}

extension JSONParser {

    struct DocumentReader {
        let array: [UInt8]

        private(set) var readerIndex: Int = 0

        private var readableBytes: Int {
            self.array.endIndex - self.readerIndex
        }

        var isEOF: Bool {
            self.readerIndex >= self.array.endIndex
        }


        init(array: [UInt8]) {
            self.array = array
        }

        subscript<R: RangeExpression<Int>>(bounds: R) -> ArraySlice<UInt8> {
            self.array[bounds]
        }

        mutating func read() -> UInt8? {
            guard self.readerIndex < self.array.endIndex else {
                self.readerIndex = self.array.endIndex
                return nil
            }

            defer { self.readerIndex += 1 }

            return self.array[self.readerIndex]
        }

        func peek(offset: Int = 0) -> UInt8? {
            guard self.readerIndex + offset < self.array.endIndex else {
                return nil
            }

            return self.array[self.readerIndex + offset]
        }

        mutating func moveReaderIndex(forwardBy offset: Int) {
            self.readerIndex += offset
        }

        @discardableResult
        mutating func consumeWhitespace() throws -> UInt8 {
            var whitespace = 0
            while let ascii = self.peek(offset: whitespace) {
                switch ascii {
                case ._space, ._return, ._newline, ._tab:
                    whitespace += 1
                    continue
                default:
                    self.moveReaderIndex(forwardBy: whitespace)
                    return ascii
                }
            }

            throw JSONError.unexpectedEndOfFile
        }

        mutating func readString() throws -> String {
            try self.readUTF8StringTillNextUnescapedQuote()
        }

        mutating func readNumber() throws -> String {
            try self.parseNumber()
        }

        mutating func readBool() throws -> Bool {
            switch self.read() {
            case UInt8(ascii: "t"):
                for target in [UInt8]._true.dropFirst(1) {
                    guard let byte = self.read() else {
                        throw JSONError.unexpectedEndOfFile
                    }
                    guard byte == target else {
                        throw JSONError.unexpectedCharacter(ascii: byte, characterIndex: self.readerIndex - 1)
                    }
                }

                return true
            case UInt8(ascii: "f"):
                for target in [UInt8]._false.dropFirst(1) {
                    guard let byte = self.read() else {
                        throw JSONError.unexpectedEndOfFile
                    }
                    guard byte == target else {
                        throw JSONError.unexpectedCharacter(ascii: byte, characterIndex: self.readerIndex - 1)
                    }
                }

                return false
            default:
                preconditionFailure("Expected to have `t` or `f` as first character")
            }
        }

        mutating func readNull() throws {
            for target in [UInt8]._null {
                guard let byte = self.read() else {
                    throw JSONError.unexpectedEndOfFile
                }
                guard byte == target else {
                    throw JSONError.unexpectedCharacter(ascii: byte, characterIndex: self.readerIndex - 1)
                }
            }
        }

        // MARK: - Private Methods -

        // MARK: String

        enum EscapedSequenceError: Swift.Error {
            case expectedLowSurrogateUTF8SequenceAfterHighSurrogate(index: Int)
            case unexpectedEscapedCharacter(ascii: UInt8, index: Int)
            case couldNotCreateUnicodeScalarFromUInt32(index: Int, unicodeScalarValue: UInt32)
        }

        private mutating func readUTF8StringTillNextUnescapedQuote() throws -> String {
            guard self.read() == ._quote else {
                throw JSONError.unexpectedCharacter(ascii: self.peek(offset: -1)!, characterIndex: self.readerIndex - 1)
            }
            var stringStartIndex = self.readerIndex
            var copy = 0
            var output: String?

            while let byte = peek(offset: copy) {
                switch byte {
                case UInt8(ascii: "\""):
                    self.moveReaderIndex(forwardBy: copy + 1)
                    guard var result = output else {
                        // if we don't have an output string we create a new string
                        return try makeString(at: stringStartIndex ..< stringStartIndex + copy)
                    }
                    // if we have an output string we append
                    result += try makeString(at: stringStartIndex ..< stringStartIndex + copy)
                    return result

                case 0 ... 31:
                    // All Unicode characters may be placed within the
                    // quotation marks, except for the characters that must be escaped:
                    // quotation mark, reverse solidus, and the control characters (U+0000
                    // through U+001F).
                    var string = output ?? ""
                    let errorIndex = self.readerIndex + copy
                    string += try makeString(at: stringStartIndex ... errorIndex)
                    throw JSONError.unescapedControlCharacterInString(ascii: byte, in: string, index: errorIndex)

                case UInt8(ascii: "\\"):
                    self.moveReaderIndex(forwardBy: copy)
                    if output != nil {
                        output! += try makeString(at: stringStartIndex ..< stringStartIndex + copy)
                    } else {
                        output = try makeString(at: stringStartIndex ..< stringStartIndex + copy)
                    }

                    let escapedStartIndex = self.readerIndex

                    do {
                        let escaped = try parseEscapeSequence()
                        output! += escaped
                        stringStartIndex = self.readerIndex
                        copy = 0
                    } catch EscapedSequenceError.unexpectedEscapedCharacter(let ascii, let failureIndex) {
                        output! += try makeString(at: escapedStartIndex ..< self.readerIndex)
                        throw JSONError.unexpectedEscapedCharacter(ascii: ascii, in: output!, index: failureIndex)
                    } catch EscapedSequenceError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(let failureIndex) {
                        output! += try makeString(at: escapedStartIndex ..< self.readerIndex)
                        throw JSONError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: output!, index: failureIndex)
                    } catch EscapedSequenceError.couldNotCreateUnicodeScalarFromUInt32(let failureIndex, let unicodeScalarValue) {
                        output! += try makeString(at: escapedStartIndex ..< self.readerIndex)
                        throw JSONError.couldNotCreateUnicodeScalarFromUInt32(
                            in: output!, index: failureIndex, unicodeScalarValue: unicodeScalarValue
                        )
                    }

                default:
                    copy += 1
                    continue
                }
            }

            throw JSONError.unexpectedEndOfFile
        }

        private func makeString<R: RangeExpression<Int>>(at range: R) throws -> String {
            let raw = array[range]
            guard let str = String(bytes: raw, encoding: .utf8) else {
                throw JSONError.invalidUTF8Sequence(Data(raw), characterIndex: range.relative(to: array).lowerBound)
            }
            return str
        }

        private mutating func parseEscapeSequence() throws -> String {
            precondition(self.read() == ._backslash, "Expected to have an backslash first")
            guard let ascii = self.read() else {
                throw JSONError.unexpectedEndOfFile
            }

            switch ascii {
            case 0x22: return "\""
            case 0x5C: return "\\"
            case 0x2F: return "/"
            case 0x62: return "\u{08}" // \b
            case 0x66: return "\u{0C}" // \f
            case 0x6E: return "\u{0A}" // \n
            case 0x72: return "\u{0D}" // \r
            case 0x74: return "\u{09}" // \t
            case 0x75:
                let character = try parseUnicodeSequence()
                return String(character)
            default:
                throw EscapedSequenceError.unexpectedEscapedCharacter(ascii: ascii, index: self.readerIndex - 1)
            }
        }

        private mutating func parseUnicodeSequence() throws -> Unicode.Scalar {
            // we build this for utf8 only for now.
            let bitPattern = try parseUnicodeHexSequence()

            // check if high surrogate
            let isFirstByteHighSurrogate = bitPattern & 0xFC00 // nil everything except first six bits
            if isFirstByteHighSurrogate == 0xD800 {
                // if we have a high surrogate we expect a low surrogate next
                let highSurrogateBitPattern = bitPattern
                guard let (escapeChar) = self.read(),
                      let (uChar) = self.read()
                else {
                    throw JSONError.unexpectedEndOfFile
                }

                guard escapeChar == UInt8(ascii: #"\"#), uChar == UInt8(ascii: "u") else {
                    throw EscapedSequenceError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(index: self.readerIndex - 1)
                }

                let lowSurrogateBitBattern = try parseUnicodeHexSequence()
                let isSecondByteLowSurrogate = lowSurrogateBitBattern & 0xFC00 // nil everything except first six bits
                guard isSecondByteLowSurrogate == 0xDC00 else {
                    // we are in an escaped sequence. for this reason an output string must have
                    // been initialized
                    throw EscapedSequenceError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(index: self.readerIndex - 1)
                }

                let highValue = UInt32(highSurrogateBitPattern - 0xD800) * 0x400
                let lowValue = UInt32(lowSurrogateBitBattern - 0xDC00)
                let unicodeValue = highValue + lowValue + 0x10000
                guard let unicode = Unicode.Scalar(unicodeValue) else {
                    throw EscapedSequenceError.couldNotCreateUnicodeScalarFromUInt32(
                        index: self.readerIndex, unicodeScalarValue: unicodeValue
                    )
                }
                return unicode
            }

            guard let unicode = Unicode.Scalar(bitPattern) else {
                throw EscapedSequenceError.couldNotCreateUnicodeScalarFromUInt32(
                    index: self.readerIndex, unicodeScalarValue: UInt32(bitPattern)
                )
            }
            return unicode
        }

        private mutating func parseUnicodeHexSequence() throws -> UInt16 {
            // As stated in RFC-8259 an escaped unicode character is 4 HEXDIGITs long
            // https://tools.ietf.org/html/rfc8259#section-7
            let startIndex = self.readerIndex
            guard let firstHex = self.read(),
                  let secondHex = self.read(),
                  let thirdHex = self.read(),
                  let forthHex = self.read()
            else {
                throw JSONError.unexpectedEndOfFile
            }

            guard let first = DocumentReader.hexAsciiTo4Bits(firstHex),
                  let second = DocumentReader.hexAsciiTo4Bits(secondHex),
                  let third = DocumentReader.hexAsciiTo4Bits(thirdHex),
                  let forth = DocumentReader.hexAsciiTo4Bits(forthHex)
            else {
                let hexString = String(decoding: [firstHex, secondHex, thirdHex, forthHex], as: Unicode.UTF8.self)
                throw JSONError.invalidHexDigitSequence(hexString, index: startIndex)
            }
            let firstByte = UInt16(first) << 4 | UInt16(second)
            let secondByte = UInt16(third) << 4 | UInt16(forth)

            let bitPattern = UInt16(firstByte) << 8 | UInt16(secondByte)

            return bitPattern
        }

        private static func hexAsciiTo4Bits(_ ascii: UInt8) -> UInt8? {
            switch ascii {
            case 48 ... 57:
                return ascii - 48
            case 65 ... 70:
                // uppercase letters
                return ascii - 55
            case 97 ... 102:
                // lowercase letters
                return ascii - 87
            default:
                return nil
            }
        }

        // MARK: Numbers

        private enum ControlCharacter {
            case operand
            case decimalPoint
            case exp
            case expOperator
        }

        private mutating func parseNumber() throws -> String {
            var pastControlChar: ControlCharacter = .operand
            var numbersSinceControlChar: UInt = 0
            var hasLeadingZero = false

            // parse first character

            guard let ascii = self.peek() else {
                preconditionFailure("Why was this function called, if there is no 0...9 or -")
            }
            switch ascii {
            case UInt8(ascii: "0"):
                numbersSinceControlChar = 1
                pastControlChar = .operand
                hasLeadingZero = true
            case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                numbersSinceControlChar = 1
                pastControlChar = .operand
            case UInt8(ascii: "-"):
                numbersSinceControlChar = 0
                pastControlChar = .operand
            default:
                preconditionFailure("Why was this function called, if there is no 0...9 or -")
            }

            var numberchars = 1

            // parse everything else
            while let byte = self.peek(offset: numberchars) {
                switch byte {
                case UInt8(ascii: "0"):
                    if hasLeadingZero {
                        throw JSONError.numberWithLeadingZero(index: readerIndex + numberchars)
                    }
                    if numbersSinceControlChar == 0, pastControlChar == .operand {
                        // the number started with a minus. this is the leading zero.
                        hasLeadingZero = true
                    }
                    numberchars += 1
                    numbersSinceControlChar += 1
                case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                    if hasLeadingZero {
                        throw JSONError.numberWithLeadingZero(index: readerIndex + numberchars)
                    }
                    numberchars += 1
                    numbersSinceControlChar += 1
                case UInt8(ascii: "."):
                    guard numbersSinceControlChar > 0, pastControlChar == .operand else {
                        throw JSONError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                    }

                    numberchars += 1
                    hasLeadingZero = false
                    pastControlChar = .decimalPoint
                    numbersSinceControlChar = 0

                case UInt8(ascii: "e"), UInt8(ascii: "E"):
                    guard numbersSinceControlChar > 0,
                          pastControlChar == .operand || pastControlChar == .decimalPoint
                    else {
                        throw JSONError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                    }

                    numberchars += 1
                    hasLeadingZero = false
                    pastControlChar = .exp
                    numbersSinceControlChar = 0
                case UInt8(ascii: "+"), UInt8(ascii: "-"):
                    guard numbersSinceControlChar == 0, pastControlChar == .exp else {
                        throw JSONError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                    }

                    numberchars += 1
                    pastControlChar = .expOperator
                    numbersSinceControlChar = 0
                case ._space, ._return, ._newline, ._tab, ._comma, ._closebracket, ._closebrace:
                    guard numbersSinceControlChar > 0 else {
                        throw JSONError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                    }
                    let numberStartIndex = self.readerIndex
                    self.moveReaderIndex(forwardBy: numberchars)

                    return String(decoding: self[numberStartIndex ..< self.readerIndex], as: Unicode.UTF8.self)
                default:
                    throw JSONError.unexpectedCharacter(ascii: byte, characterIndex: readerIndex + numberchars)
                }
            }

            guard numbersSinceControlChar > 0 else {
                throw JSONError.unexpectedEndOfFile
            }

            defer { self.readerIndex = self.array.endIndex }
            return String(decoding: self.array.suffix(from: readerIndex), as: Unicode.UTF8.self)
        }
    }
}

extension UInt8 {

    internal static let _space = UInt8(ascii: " ")
    internal static let _return = UInt8(ascii: "\r")
    internal static let _newline = UInt8(ascii: "\n")
    internal static let _tab = UInt8(ascii: "\t")

    internal static let _colon = UInt8(ascii: ":")
    internal static let _comma = UInt8(ascii: ",")

    internal static let _openbrace = UInt8(ascii: "{")
    internal static let _closebrace = UInt8(ascii: "}")

    internal static let _openbracket = UInt8(ascii: "[")
    internal static let _closebracket = UInt8(ascii: "]")

    internal static let _quote = UInt8(ascii: "\"")
    internal static let _backslash = UInt8(ascii: "\\")

}

extension Array where Element == UInt8 {

    internal static let _true = [UInt8(ascii: "t"), UInt8(ascii: "r"), UInt8(ascii: "u"), UInt8(ascii: "e")]
    internal static let _false = [UInt8(ascii: "f"), UInt8(ascii: "a"), UInt8(ascii: "l"), UInt8(ascii: "s"), UInt8(ascii: "e")]
    internal static let _null = [UInt8(ascii: "n"), UInt8(ascii: "u"), UInt8(ascii: "l"), UInt8(ascii: "l")]

}

enum JSONError: Swift.Error, Equatable {
    case cannotConvertInputDataToUTF8
    case unexpectedCharacter(ascii: UInt8, characterIndex: Int)
    case unexpectedEndOfFile
    case tooManyNestedArraysOrDictionaries(characterIndex: Int)
    case invalidHexDigitSequence(String, index: Int)
    case unexpectedEscapedCharacter(ascii: UInt8, in: String, index: Int)
    case unescapedControlCharacterInString(ascii: UInt8, in: String, index: Int)
    case expectedLowSurrogateUTF8SequenceAfterHighSurrogate(in: String, index: Int)
    case couldNotCreateUnicodeScalarFromUInt32(in: String, index: Int, unicodeScalarValue: UInt32)
    case numberWithLeadingZero(index: Int)
    case numberIsNotRepresentableInSwift(parsed: String)
    case singleFragmentFoundButNotAllowed
    case invalidUTF8Sequence(Data, characterIndex: Int)
}
