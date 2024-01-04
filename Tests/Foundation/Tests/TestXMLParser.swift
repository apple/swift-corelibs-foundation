// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

enum XMLParserDelegateEvent {
    case startDocument
    case endDocument
    case foundNotationDeclaration(String, String?, String?)
    case foundUnparsedEntityDeclaration(String, String?, String?, String?)
    case foundAttributeDeclaration(String, String?, String?, String?)
    case foundElementDeclaration(String, String)
    case foundInternalEntityDeclaration(String, String?)
    case foundExternalEntityDeclaration(String, String?, String?)
    case didStartElement(String, String?, String?, [String : String])
    case didEndElement(String, String?, String?)
    case didStartMappingPrefix(String, String)
    case didEndMappingPrefix(String)
    case foundCharacters(String)
    case foundIgnorableWhitespace(String)
    case foundProcessingInstruction(String, String?)
    case foundComment(String)
    case foundCDATA(Data)
    case resolveExternalEntity(String, String?)
    case parseErrorOccurred(Error)
    case validationErrorOccurred(Error)
}

extension XMLParserDelegateEvent: Equatable {

    public static func ==(lhs: XMLParserDelegateEvent, rhs: XMLParserDelegateEvent) -> Bool {
        switch (lhs, rhs) {
        case (.startDocument, .startDocument):
            return true
        case (.endDocument, .endDocument):
            return true
        case let (.foundNotationDeclaration(lhsName, lhsPublicID, lhsSystemID),
                  .foundNotationDeclaration(rhsName, rhsPublicID, rhsSystemID)):
            return lhsName == rhsName && lhsPublicID == rhsPublicID && lhsSystemID == rhsSystemID
        case let (.foundUnparsedEntityDeclaration(lhsName, lhsPublicID, lhsSystemID, lhsNotationName),
                  .foundUnparsedEntityDeclaration(rhsName, rhsPublicID, rhsSystemID, rhsNotationName)):
            return lhsName == rhsName && lhsPublicID == rhsPublicID && lhsSystemID == rhsSystemID && lhsNotationName == rhsNotationName
        case let (.foundAttributeDeclaration(lhsAttributeName, lhsElementName, lhsType, lhsDefaultValue),
                  .foundAttributeDeclaration(rhsAttributeName, rhsElementName, rhsType, rhsDefaultValue)):
            return lhsAttributeName == rhsAttributeName && lhsElementName == rhsElementName && lhsType == rhsType && lhsDefaultValue == rhsDefaultValue
        case let (.foundElementDeclaration(lhsElementName, lhsModel),
                  .foundElementDeclaration(rhsElementName, rhsModel)):
            return lhsElementName == rhsElementName && lhsModel == rhsModel
        case let (.foundInternalEntityDeclaration(lhsName, lhsValue),
                  .foundInternalEntityDeclaration(rhsName, rhsValue)):
            return lhsName == rhsName && lhsValue == rhsValue
        case let (.foundExternalEntityDeclaration(lhsName, lhsPublicID, lhsSystemID),
                  .foundExternalEntityDeclaration(rhsName, rhsPublicID, rhsSystemID)):
            return lhsName == rhsName && lhsPublicID == rhsPublicID && lhsSystemID == rhsSystemID
        case let (.didStartElement(lhsElement, lhsNamespace, lhsQname, lhsAttr),
                  .didStartElement(rhsElement, rhsNamespace, rhsQname, rhsAttr)):
            return lhsElement == rhsElement && lhsNamespace == rhsNamespace && lhsQname == rhsQname && lhsAttr == rhsAttr
        case let (.didEndElement(lhsElement, lhsNamespace, lhsQname),
                  .didEndElement(rhsElement, rhsNamespace, rhsQname)):
            return lhsElement == rhsElement && lhsNamespace == rhsNamespace && lhsQname == rhsQname
        case let (.didStartMappingPrefix(lhsPrefix, lhsNamespaceURI),
                  .didStartMappingPrefix(rhsPrefix, rhsNamespaceURI)):
            return lhsPrefix == rhsPrefix && lhsNamespaceURI == rhsNamespaceURI
        case let (.didEndMappingPrefix(lhsPrefix),
                  .didEndMappingPrefix(rhsPrefix)):
            return lhsPrefix == rhsPrefix
        case let (.foundCharacters(lhsChar), .foundCharacters(rhsChar)):
            return lhsChar == rhsChar
        case let (.foundIgnorableWhitespace(lhsWhitespaceString),
                  .foundIgnorableWhitespace(rhsWhitespaceString)):
            return lhsWhitespaceString == rhsWhitespaceString
        case let (.foundProcessingInstruction(lhsTarget, lhsData),
                  .foundProcessingInstruction(rhsTarget, rhsData)):
            return lhsTarget == rhsTarget && lhsData == rhsData
        case let (.foundComment(lhsComment),
                  .foundComment(rhsComment)):
            return lhsComment == rhsComment
        case let (.foundCDATA(lhsData),
                  .foundCDATA(rhsData)):
            return lhsData == rhsData
        case let (.resolveExternalEntity(lhsName, lhsSystemID),
                  .resolveExternalEntity(rhsName, rhsSystemID)):
            return lhsName == rhsName && lhsSystemID == rhsSystemID
        case let (.parseErrorOccurred(lhsError),
                  .parseErrorOccurred(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case let (.validationErrorOccurred(lhsError),
                  .validationErrorOccurred(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }

}

class XMLParserDelegateEventStream: NSObject, XMLParserDelegate {
    var events: [XMLParserDelegateEvent] = []

    func parserDidStartDocument(_ parser: XMLParser) {
        events.append(.startDocument)
    }
    func parserDidEndDocument(_ parser: XMLParser) {
        events.append(.endDocument)
    }
    func parser(_ parser: XMLParser, foundNotationDeclarationWithName name: String, publicID: String?, systemID: String?) {
        events.append(.foundNotationDeclaration(name, publicID, systemID))
    }
    func parser(_ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?, systemID: String?, notationName: String?) {
        events.append(.foundUnparsedEntityDeclaration(name, publicID, systemID, notationName))
    }
    func parser(_ parser: XMLParser, foundAttributeDeclarationWithName attributeName: String, forElement elementName: String, type: String?, defaultValue: String?) {
        events.append(.foundAttributeDeclaration(attributeName, elementName, type, defaultValue))
    }
    func parser(_ parser: XMLParser, foundElementDeclarationWithName elementName: String, model: String) {
        events.append(.foundElementDeclaration(elementName, model))
    }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        events.append(.foundInternalEntityDeclaration(name, value))
    }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
        events.append(.foundExternalEntityDeclaration(name, publicID, systemID))
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        events.append(.didStartElement(elementName, namespaceURI, qName, attributeDict))
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        events.append(.didEndElement(elementName, namespaceURI, qName))
    }
    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) {
        events.append(.didStartMappingPrefix(prefix, namespaceURI))
    }
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) {
        events.append(.didEndMappingPrefix(prefix))
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if let previousEvent = events.last, case let .foundCharacters(previousString) = previousEvent {
            events.removeLast()
            events.append(.foundCharacters(previousString + string))
        } else {
            events.append(.foundCharacters(string))
        }
    }
    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
        if let previousEvent = events.last, case let .foundIgnorableWhitespace(previousString) = previousEvent {
            events.removeLast()
            events.append(.foundIgnorableWhitespace(previousString + whitespaceString))
        } else {
            events.append(.foundIgnorableWhitespace(whitespaceString))
        }
    }
    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
        events.append(.foundProcessingInstruction(target, data))
    }
    func parser(_ parser: XMLParser, foundComment comment: String) {
        events.append(.foundComment(comment))
    }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        events.append(.foundCDATA(CDATABlock))
    }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
        events.append(.resolveExternalEntity(name, systemID))
        return Data("[resolveExternalEntityName \(name)]".utf8)
    }
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        events.append(.parseErrorOccurred(parseError))
    }
    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        events.append(.validationErrorOccurred(validationError))
    }
}

class TestXMLParser : XCTestCase {

    static var allTests: [(String, (TestXMLParser) -> () throws -> Void)] {
        return [
            ("test_withData", test_withData),
            ("test_withDataEncodings", test_withDataEncodings),
            ("test_withDataOptions", test_withDataOptions),
            ("test_sr9758_abortParsing", test_sr9758_abortParsing),
            ("test_sr10157_swappedElementNames", test_sr10157_swappedElementNames),
            ("test_sr13546_stackedParsers", test_sr13546_stackedParsers),
            ("test_entities", test_entities),
        ]
    }

    // Helper method to embed the correct encoding in the XML header
    static func xmlUnderTest(encoding: String.Encoding? = nil) -> String {
        let xmlUnderTest = "<test attribute='value'><foo>bar</foo></test>"
        guard var encoding = encoding?.description else {
            return xmlUnderTest
        }
        if let open = encoding.range(of: "(") {
            let range: Range<String.Index> = open.upperBound..<encoding.endIndex
            encoding = String(encoding[range])
        }
        if let close = encoding.range(of: ")") {
            encoding = String(encoding[..<close.lowerBound])
        }
        return "<?xml version='1.0' encoding='\(encoding.uppercased())' standalone='no'?>\n\(xmlUnderTest)\n"
    }

    static func xmlUnderTestExpectedEvents(namespaces: Bool = false) -> [XMLParserDelegateEvent] {
        let uri: String? = namespaces ? "" : nil
        return [
            .startDocument,
            .didStartElement("test", uri, namespaces ? "test" : nil, ["attribute": "value"]),
            .didStartElement("foo", uri, namespaces ? "foo" : nil, [:]),
            .foundCharacters("bar"),
            .didEndElement("foo", uri, namespaces ? "foo" : nil),
            .didEndElement("test", uri, namespaces ? "test" : nil),
            .endDocument,
        ]
    }

    func test_withData() {
        let xml = Array(TestXMLParser.xmlUnderTest().utf8CString)
        let data = xml.withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<CChar>) -> Data in
            return buffer.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: buffer.count * MemoryLayout<CChar>.stride) {
                // Must not include final \0
                return Data(bytes: $0, count: buffer.count-1)
            }
        }
        let parser = XMLParser(data: data)
        let stream = XMLParserDelegateEventStream()
        parser.delegate = stream
        let res = parser.parse()
        XCTAssertEqual(stream.events, TestXMLParser.xmlUnderTestExpectedEvents())
        XCTAssertTrue(res)
    }

    func test_withDataEncodings() {
        // If th <?xml header isn't present, any non-UTF8 encodings fail. This appears to be libxml2 behavior.
        // These don't work, it may just be an issue with the `encoding=xxx`.
        //   - .nextstep, .utf32LittleEndian
        var encodings: [String.Encoding] = [.utf16LittleEndian, .utf16BigEndian,  .ascii]
#if !os(Windows)
        // libxml requires iconv support for UTF32
        encodings.append(.utf32BigEndian)
#endif
        for encoding in encodings {
            let xml = TestXMLParser.xmlUnderTest(encoding: encoding)
            let parser = XMLParser(data: xml.data(using: encoding)!)
            let stream = XMLParserDelegateEventStream()
            parser.delegate = stream
            let res = parser.parse()
            XCTAssertEqual(stream.events, TestXMLParser.xmlUnderTestExpectedEvents())
            XCTAssertTrue(res)
        }
    }

    func test_withDataOptions() {
        let xml = TestXMLParser.xmlUnderTest()
        let parser = XMLParser(data: xml.data(using: .utf8)!)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = true
        let stream = XMLParserDelegateEventStream()
        parser.delegate = stream
        let res = parser.parse()
        XCTAssertEqual(stream.events, TestXMLParser.xmlUnderTestExpectedEvents(namespaces: true)  )
        XCTAssertTrue(res)
    }

    func test_sr9758_abortParsing() {
        class Delegate: NSObject, XMLParserDelegate {
            func parserDidStartDocument(_ parser: XMLParser) { parser.abortParsing() }
        }
        let xml = TestXMLParser.xmlUnderTest(encoding: .utf8)
        let parser = XMLParser(data: xml.data(using: .utf8)!)
        let delegate = Delegate()
        defer {
            // XMLParser holds a weak reference to delegate. Keep it alive.
            _fixLifetime(delegate)
        }
        parser.delegate = delegate
        XCTAssertFalse(parser.parse())
        XCTAssertNotNil(parser.parserError)
    }

    func test_sr10157_swappedElementNames() {
        class ElementNameChecker: NSObject, XMLParserDelegate {
            let name: String
            init(_ name: String) { self.name = name }
            func parser(_ parser: XMLParser,
                        didStartElement elementName: String,
                        namespaceURI: String?,
                        qualifiedName qName: String?,
                        attributes attributeDict: [String: String] = [:])
            {
                if parser.shouldProcessNamespaces {
                    XCTAssertEqual(self.name, qName)
                } else {
                    XCTAssertEqual(self.name, elementName)
                }
            }
            func parser(_ parser: XMLParser,
                        didEndElement elementName: String,
                        namespaceURI: String?,
                        qualifiedName qName: String?)
            {
                if parser.shouldProcessNamespaces {
                    XCTAssertEqual(self.name, qName)
                } else {
                    XCTAssertEqual(self.name, elementName)
                }
            }
            func check() {
                let elementString = "<\(self.name) />"
                var parser = XMLParser(data: elementString.data(using: .utf8)!)
                parser.delegate = self
                XCTAssertTrue(parser.parse())
                
                // Confirm that the parts of QName is also not swapped.
                parser = XMLParser(data: elementString.data(using: .utf8)!)
                parser.delegate = self
                parser.shouldProcessNamespaces = true
                XCTAssertTrue(parser.parse())
            }
        }
        
        ElementNameChecker("noPrefix").check()
        ElementNameChecker("myPrefix:myLocalName").check()
    }
    
    func test_sr13546_stackedParsers() {
        let xml = """
                  <?xml version="1.0" encoding="ISO-8859-1"?>
                  <!DOCTYPE root [
                  
                  <!ELEMENT root (foo*) >
                  
                  <!ELEMENT foo ANY >
                  
                  ]>
                  <root xmlns:swift="https://swift.org/ns/test/sr13546">
                  <foo/>
                  </root>
                  """
        let xmlData = xml.data(using: .utf8)
        XCTAssertNotNil(xmlData, "Expect XML string to convert to UTF-8")

        let expectedEvents: [XMLParserDelegateEvent] = [
            .startDocument,
            .foundElementDeclaration("root", "ELEMENT"),
            .foundElementDeclaration("foo", "ANY"),
            .didStartMappingPrefix("swift", "https://swift.org/ns/test/sr13546"),
            .didStartElement("root", "", "root", [:]),
            .foundCharacters("\n"),
            .didStartElement("foo", "", "foo", [:]),
            .didEndElement("foo", "", "foo"),
            .foundCharacters("\n"),
            .didEndElement("root", "", "root"),
            .didEndMappingPrefix("swift"),
            .endDocument
        ]

        let parser = XMLParser(data: xmlData!)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = true
        parser.externalEntityResolvingPolicy = .always

        class StackedParserXMLParserDelegateEventStream : XMLParserDelegateEventStream {
            var xmlData: Data! = nil
            var innerResult: Bool = false
            var innerStream: XMLParserDelegateEventStream! = nil

            override func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {

                let parser = XMLParser(data: self.xmlData)
                parser.shouldProcessNamespaces = true
                parser.shouldReportNamespacePrefixes = true
                parser.shouldResolveExternalEntities = true
                parser.externalEntityResolvingPolicy = .always

                self.innerStream = XMLParserDelegateEventStream()
                parser.delegate = self.innerStream
                self.innerResult = parser.parse()

                super.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

            }
        }

        let stream = StackedParserXMLParserDelegateEventStream()
        stream.xmlData = xmlData
        parser.delegate = stream

        let res = parser.parse()
        XCTAssertTrue(res)
        XCTAssertEqual(stream.events, expectedEvents)

        XCTAssertTrue(stream.innerResult)
        XCTAssertEqual(stream.innerStream.events, expectedEvents)
    }

    func test_entities() {
        let tempDirectory = FileManager.default.temporaryDirectory
        let externalEntityPath = tempDirectory.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        XCTAssertNoThrow(try Data("""
                                  <?xml version="1.0" encoding="ISO-8859-1"?>
                                  <tagExt attrExt="attrExtValue">textExt</tagExt>
                                  """.utf8).write(to: externalEntityPath), "creating temp file failed")
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: externalEntityPath), "Cleanup failed") }

        let unparsedExternalPath = tempDirectory.appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        XCTAssertNoThrow(try Data("unparsedExternal".utf8).write(to: unparsedExternalPath), "creating temp file failed")
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: unparsedExternalPath), "Cleanup failed") }


        let xml = """
                  <?xml version="1.0" encoding="ISO-8859-1"?>
                  <!DOCTYPE root [
                  
                  <!NOTATION notation PUBLIC "A notation">
                  
                  <!ENTITY internalEntity "Internal">
                  <!ENTITY externalEntity SYSTEM "\(externalEntityPath)">
                  <!ENTITY unparsedExternal SYSTEM "\(unparsedExternalPath)" NDATA notation>
                  
                  <!ELEMENT root (foo*) >
                  
                  <!ELEMENT foo ANY >
                  
                  <!ATTLIST foo bar ENTITY #REQUIRED>
                  
                  ]>
                  <root>
                  <foo bar="&internalEntity;">internal entity: &internalEntity;</foo>
                  <foo bar="externalEntity">external entity: &externalEntity;</foo>
                  <foo bar="unparsedExternal">unparsed external entity: unparsedExternal</foo>
                  </root>
                  """
        let expectedEvents: [XMLParserDelegateEvent] = [
            .startDocument,
            .foundNotationDeclaration("notation", "A notation", nil),
            .foundInternalEntityDeclaration("internalEntity", "Internal"),
            .foundExternalEntityDeclaration("externalEntity", nil, externalEntityPath.absoluteString),
            .foundUnparsedEntityDeclaration("unparsedExternal", nil, unparsedExternalPath.absoluteString, "notation"),
            .foundElementDeclaration("root", "ELEMENT"),
            .foundElementDeclaration("foo", "ANY"),
            .foundAttributeDeclaration("bar", "foo", "ENTITY", nil),
            .didStartElement("root", "", "root", [:]),
            .foundCharacters("\n"),
            .didStartElement("foo", "", "foo", ["bar": "Internal"]),
            .foundCharacters("internal entity: Internal"),
            .didEndElement("foo", "", "foo"),
            .foundCharacters("\n"),
            .didStartElement("foo", "", "foo", ["bar": "externalEntity"]),
            .foundCharacters("external entity: "),
            .foundIgnorableWhitespace("\n"),
            .didStartElement("tagExt", "", "tagExt", ["attrExt": "attrExtValue"]),
            .foundCharacters("textExt"),
            .didEndElement("tagExt", "", "tagExt"),
            .didEndElement("foo", "", "foo"),
            .foundCharacters("\n"),
            .didStartElement("foo", "", "foo", ["bar": "unparsedExternal"]),
            .foundCharacters("unparsed external entity: unparsedExternal"),
            .didEndElement("foo", "", "foo"),
            .foundCharacters("\n"),
            .didEndElement("root", "", "root"),
            .endDocument
        ]

        let xmlData = xml.data(using: .utf8)
        XCTAssertNotNil(xmlData, "Expect XML string to convert to UTF-8")

        let parser = XMLParser(data: xmlData!)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = true
        parser.externalEntityResolvingPolicy = .always

        let stream = XMLParserDelegateEventStream()
        parser.delegate = stream

        let res = parser.parse()
        XCTAssertTrue(res)

        XCTAssertEqual(stream.events, expectedEvents)
    }
}
