// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestXMLDocument : LoopbackServerTest {

    func test_basicCreation() {
        let doc = XMLDocument(rootElement: nil)
        XCTAssert(doc.version == "1.0", "expected 1.0, got \(String(describing: doc.version))")
        doc.version = "1.1"
        XCTAssert(doc.version == "1.1", "expected 1.1, got \(String(describing: doc.version))")
        let node = XMLElement(name: "Hello", uri: "http://www.example.com")

        doc.setRootElement(node)

        let element = doc.rootElement()!
        XCTAssert(element === node)
    }
    
    func test_createElement() throws {
        let element = try XMLElement(xmlString: "<D:propfind xmlns:D=\"DAV:\"><D:prop></D:prop></D:propfind>")
        XCTAssert(element.name! == "D:propfind")
        XCTAssert(element.rootDocument == nil)
        if let namespace = element.namespaces?.first {
            XCTAssertEqual(namespace.prefix, "D")
            XCTAssertEqual(namespace.stringValue, "DAV:")
        } else {
            XCTFail("Namespace was not parsed correctly")
        }
        
        if let child = element.elements(forName: "D:prop").first {
            XCTAssertEqual(child.localName, "prop")
            XCTAssertEqual(child.prefix, "D")
            XCTAssertEqual(child.name, "D:prop")
        } else {
            XCTFail("Child element was not parsed correctly!")
        }
    }

    func test_nextPreviousNode() {
        let doc = XMLDocument(rootElement: nil)
        let node = XMLElement(name: "Hello", uri: "http://www.example.com")

        let fooNode = XMLElement(name: "Foo")
        let barNode = XMLElement(name: "Bar")
        let bazNode = XMLElement(name: "Baz")

        doc.setRootElement(node)
        node.addChild(fooNode)
        fooNode.addChild(bazNode)
        node.addChild(barNode)

        XCTAssert(doc.next === node)
        XCTAssert(doc.next?.next === fooNode)
        XCTAssert(doc.next?.next?.next === bazNode)
        XCTAssert(doc.next?.next?.next?.next === barNode)

        XCTAssert(barNode.previous === bazNode)
        XCTAssert(barNode.previous?.previous === fooNode)
        XCTAssert(barNode.previous?.previous?.previous === node)
        XCTAssert(barNode.previous?.previous?.previous?.previous === doc)
    }

    func test_xpath() throws {
        throw XCTSkip("https://bugs.swift.org/browse/SR-10098")
        #if false
        let doc = XMLDocument(rootElement: nil)
        let foo = XMLElement(name: "foo")
        let bar1 = XMLElement(name: "bar")
        let bar2 = XMLElement(name: "bar")
        let bar3 = XMLElement(name: "bar")
        let baz = XMLElement(name: "baz")

        doc.setRootElement(foo)
        foo.addChild(bar1)
        foo.addChild(bar2)
        foo.addChild(bar3)
        bar2.addChild(baz)
        
        XCTAssertEqual(baz.xPath, "/foo/bar[2]/baz")
        
        let baz2 = XMLElement(name: "/baz")
        bar2.addChild(baz2)

        XCTAssertEqual(baz.xPath, "/foo/bar[2]/baz")
        XCTAssertEqual(try! doc.nodes(forXPath:baz.xPath!).first, baz)

        let nodes = try! doc.nodes(forXPath:"/foo/bar")
        XCTAssertEqual(nodes.count, 3)
        XCTAssertEqual(nodes[0], bar1)
        XCTAssertEqual(nodes[1], bar2)
        XCTAssertEqual(nodes[2], bar3)

        let emptyResults = try! doc.nodes(forXPath: "/items/item/name[@type='alternate']/@value")
        XCTAssertEqual(emptyResults.count, 0)

        let xmlString = """
        <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <D:propfind xmlns:D="DAV:">
                <D:prop>
                    <D:getlastmodified></D:getlastmodified>
                    <D:getcontentlength></D:getcontentlength>
                    <D:creationdate></D:creationdate>
                    <D:resourcetype></D:resourcetype>
                </D:prop>
            </D:propfind>
        """
        
        let namespaceDoc = try XMLDocument(xmlString: xmlString, options: [])
        let propNodes = try namespaceDoc.nodes(forXPath: "//D:prop")
        if let propNode = propNodes.first {
            XCTAssert(propNode.name == "D:prop")
        } else {
            XCTAssert(false, "propNode should have existed, but was nil")            
        }
        #endif
    }

    func test_elementCreation() {
        let element = XMLElement(name: "test", stringValue: "This is my value")
        XCTAssertEqual(element.xmlString, "<test>This is my value</test>")
        XCTAssertEqual(element.children?.count, 1)
    }

    func test_elementChildren() {
        let element = XMLElement(name: "root")
        let foo = XMLElement(name: "foo")
        let bar = XMLElement(name: "bar")
        let bar2 = bar.copy() as! XMLElement

        element.addChild(foo)
        element.addChild(bar)
        element.addChild(bar2)

        XCTAssertEqual(element.elements(forName:"bar"), [bar, bar2])
        XCTAssertFalse(element.elements(forName:"foo").contains(bar))
        XCTAssertFalse(element.elements(forName:"foo").contains(bar2))
        
        let baz = XMLElement(name: "baz")
        element.insertChild(baz, at: 2)
        XCTAssertEqual(element.children?[2], baz)

        foo.detach()
        bar.detach()

        element.insertChildren([foo, bar], at: 1)
        XCTAssertEqual(element.children?[1], foo)
        XCTAssertEqual(element.children?[2], bar)
        XCTAssertEqual(element.children?[0], baz)

        let faz = XMLElement(name: "faz")
        element.replaceChild(at: 2, with: faz)
        XCTAssertEqual(element.children?[2], faz)

        for node in [foo, bar, baz, bar2, faz] {
            node.detach()
        }
        XCTAssert(element.children?.count == 0)

        element.setChildren([foo, bar, baz, bar2, faz])
        XCTAssert(element.children?.count == 5)
    }

    func test_stringValue() {
        let element = XMLElement(name: "root")
        let foo = XMLElement(name: "foo")
        let text = XMLNode.text(withStringValue:"<text>") as! XMLNode
        let comment = XMLNode.comment(withStringValue:"<comment>") as! XMLNode
        foo.addChild(text)
        foo.addChild(comment)
        element.addChild(foo)
        
        XCTAssertEqual(text.stringValue, "<text>")
        XCTAssertEqual(comment.stringValue, "<comment>")
        XCTAssertEqual(foo.stringValue, "<text><comment>") // Same with Darwin
        XCTAssertEqual(element.stringValue, "<text><comment>") // Same with Darwin
        
        // Confirm that SR-10759 is resolved.
        // https://bugs.swift.org/browse/SR-10759
        text.stringValue = "<modified text>"
        comment.stringValue = "<modified comment>"
        XCTAssertEqual(text.stringValue, "<modified text>")
        XCTAssertEqual(comment.stringValue, "<modified comment>")
        
        XCTAssertEqual(element.stringValue, "<modified text><modified comment>")
        XCTAssertEqual(element.xmlString, "<root><foo>&lt;modified text&gt;<!--<modified comment>--></foo></root>")

        element.stringValue = "Hello!<evil/>"
        XCTAssertEqual(element.xmlString, "<root>Hello!&lt;evil/&gt;</root>")
        XCTAssertEqual(element.stringValue, "Hello!<evil/>", element.stringValue ?? "stringValue unexpectedly nil")

        element.stringValue = nil

        //        let doc = XMLDocument(rootElement: element)
        //        xmlCreateIntSubset(xmlDocPtr(doc._xmlNode), "test.dtd", nil, nil)
        //        xmlAddDocEntity(xmlDocPtr(doc._xmlNode), "author", Int32(XML_INTERNAL_GENERAL_ENTITY.rawValue), nil, nil, "Robert Thompson")
        //        let author = XMLElement(name: "author")
        //        doc.rootElement()?.addChild(author)
        //        author.setStringValue("&author;", resolvingEntities: true)
        //        XCTAssertEqual(author.stringValue, "Robert Thompson", author.stringValue ?? "")
    }


    func test_objectValue() {
        let element = XMLElement(name: "root")
        let dict: [String: String] = ["hello": "world"]
        element.objectValue = dict
        
        /// - Todo: verify this behavior
        // id to Any conversion changed descriptions so this now is "<root>[\"hello\": \"world\"]</root>"
        // XCTAssertEqual(element.xmlString, "<root>{\n    hello = world;\n}</root>", element.xmlString)
    }

    func test_attributes() {
        let element = XMLElement(name: "root")
        let attribute = XMLNode.attribute(withName: "color", stringValue: "#ff00ff") as! XMLNode
        element.addAttribute(attribute)
        XCTAssertEqual(element.xmlString, "<root color=\"#ff00ff\"></root>", element.xmlString)
        element.removeAttribute(forName:"color")
        XCTAssertEqual(element.xmlString, "<root></root>", element.xmlString)

        element.addAttribute(attribute)
        let attribute2 = XMLNode.attribute(withName: "color", stringValue: "#00ff00") as! XMLNode
        element.addAttribute(attribute2)
        XCTAssertEqual(element.attribute(forName: "color")?.stringValue, "#00ff00")

        let otherAttribute = XMLNode.attribute(withName: "foo", stringValue: "bar") as! XMLNode
        element.addAttribute(otherAttribute)

        guard let attributes = element.attributes else {
            XCTFail()
            return
        }

        XCTAssertEqual(attributes.count, 2)
        XCTAssertEqual(attributes.first, attribute2)
        XCTAssertEqual(attributes.last, otherAttribute)

        let barAttribute = XMLNode.attribute(withName: "bar", stringValue: "buz") as! XMLNode
        let bazAttribute = XMLNode.attribute(withName: "baz", stringValue: "fiz") as! XMLNode

        element.attributes = [barAttribute, bazAttribute]

        XCTAssertEqual(element.attributes?.count, 2)
        XCTAssertEqual(element.attributes?.first, barAttribute)
        XCTAssertEqual(element.attributes?.last, bazAttribute)

        element.setAttributesWith(["hello": "world", "foobar": "buzbaz"])
        XCTAssertEqual(element.attribute(forName:"hello")?.stringValue, "world", "\(element.attribute(forName:"hello")?.stringValue as Optional)")
        XCTAssertEqual(element.attribute(forName:"foobar")?.stringValue, "buzbaz", "\(element.attributes ?? [])")
    }
    
    func test_attributesWithNamespace() {
        let uriNs1 = "http://example.com/ns1"
        let uriNs2 = "http://example.com/ns2"
        
        let root = XMLNode.element(withName: "root") as! XMLElement

        withExtendedLifetime(root) {
            root.addNamespace(XMLNode.namespace(withName: "ns1", stringValue: uriNs1) as! XMLNode)

            let element = XMLNode.element(withName: "element") as! XMLElement
            element.addNamespace(XMLNode.namespace(withName: "ns2", stringValue: uriNs2) as! XMLNode)
            root.addChild(element)

            // Add attributes without URI
            element.addAttribute(XMLNode.attribute(withName: "name", stringValue: "John") as! XMLNode)
            element.addAttribute(XMLNode.attribute(withName: "ns1:name", stringValue: "Tom") as! XMLNode)

            // Add attributes with URI
            element.addAttribute(XMLNode.attribute(withName: "ns1:age", uri: uriNs1, stringValue: "44") as! XMLNode)
            element.addAttribute(XMLNode.attribute(withName: "ns2:address", uri: uriNs2, stringValue: "Foobar City") as! XMLNode)

            // Retrieve attributes without URI
            XCTAssertEqual(element.attribute(forName: "name")?.stringValue, "John", "name==John")
            XCTAssertEqual(element.attribute(forName: "ns1:name")?.stringValue, "Tom", "ns1:name==Tom")
            XCTAssertEqual(element.attribute(forName: "ns1:age")?.stringValue, "44", "ns1:age==44")
            XCTAssertEqual(element.attribute(forName: "ns2:address")?.stringValue, "Foobar City", "ns2:address==Foobar City")

            // Retrieve attributes with URI
            XCTAssertEqual(element.attribute(forLocalName: "name", uri: nil)?.stringValue, "John", "name==John")
            XCTAssertEqual(element.attribute(forLocalName: "name", uri: uriNs1)?.stringValue, "Tom", "name==Tom")
            XCTAssertEqual(element.attribute(forLocalName: "age", uri: uriNs1)?.stringValue, "44", "age==44")
            XCTAssertNil(element.attribute(forLocalName: "address", uri: uriNs1), "address==nil")
            XCTAssertEqual(element.attribute(forLocalName: "address", uri: uriNs2)?.stringValue, "Foobar City", "address==Foobar City")

            // Overwrite attributes
            element.addAttribute(XMLNode.attribute(withName: "ns1:age", stringValue: "33") as! XMLNode)
            XCTAssertEqual(element.attribute(forName: "ns1:age")?.stringValue, "33", "ns1:age==33")
            element.addAttribute(XMLNode.attribute(withName: "ns1:name", uri: uriNs1, stringValue: "Tommy") as! XMLNode)
            XCTAssertEqual(element.attribute(forLocalName: "name", uri: uriNs1)?.stringValue, "Tommy", "ns1:name==Tommy")

            // Remove attributes
            element.removeAttribute(forName: "name")
            XCTAssertNil(element.attribute(forLocalName: "name", uri: nil), "name removed")
            XCTAssertNotNil(element.attribute(forLocalName: "name", uri: uriNs1), "ns1:name not removed")
            element.removeAttribute(forName: "ns1:name")
            XCTAssertNil(element.attribute(forLocalName: "name", uri: uriNs1), "ns1:name removed")
        }
    }

    func test_comments() {
        let element = XMLElement(name: "root")
        let comment = XMLNode.comment(withStringValue:"Here is a comment") as! XMLNode
        element.addChild(comment)
        XCTAssertEqual(element.xmlString, "<root><!--Here is a comment--></root>")
    }

    func test_processingInstruction() {
        let document = XMLDocument(rootElement: XMLElement(name: "root"))
        let pi = XMLNode.processingInstruction(withName:"xml-stylesheet", stringValue: "type=\"text/css\" href=\"style.css\"") as! XMLNode

        document.addChild(pi)

        XCTAssertEqual(pi.xmlString, "<?xml-stylesheet type=\"text/css\" href=\"style.css\"?>")
    }

    func test_parseXMLString() throws {
        let string = "<?xml version=\"1.0\" encoding=\"utf-8\"?><!DOCTYPE test.dtd [\n        <!ENTITY author \"Robert Thompson\">\n        ]><root><author>&author;</author></root>"

        let doc = try XMLDocument(xmlString: string, options: [.nodeLoadExternalEntitiesNever])
        XCTAssert(doc.childCount == 1)
        XCTAssertEqual(doc.rootElement()?.children?[0].stringValue, "Robert Thompson")

        guard let testDataURL = testBundle().url(forResource: "NSXMLDocumentTestData", withExtension: "xml") else {
            XCTFail("Could not find XML test data")
            return
        }

        let newDoc = try XMLDocument(contentsOf: testDataURL, options: [])
        XCTAssertEqual(newDoc.rootElement()?.name, "root")
        let root = newDoc.rootElement()!
        let children = root.children!
        XCTAssertEqual(children[0].stringValue, "Hello world", children[0].stringValue!)
        XCTAssertEqual(children[1].children?[0].stringValue, "I'm here", (children[1].children?[0].stringValue)!)

        doc.insertChild(XMLElement(name: "body"), at: 1)
        XCTAssertEqual(doc.children?[1].name, "body")
        XCTAssertEqual(doc.children?[2].name, "root", (doc.children?[2].name)!)
    }

    func test_prefixes() {
        let element = XMLElement(name: "xml:root")
        XCTAssertEqual(element.prefix, "xml")
        XCTAssertEqual(element.localName, "root")
    }
    
    func test_addNamespace() {
        let element = XMLElement(name: "foo")
        let xmlnsURI = "http://example.com/fakexmlns"
        let xmlns = XMLNode.namespace(withName: "", stringValue: xmlnsURI) as! XMLNode
        element.addNamespace(xmlns)
        XCTAssert((element.namespaces ?? []).compactMap({ $0.stringValue }).contains(xmlnsURI), "namespaces didn't include the added namespace!")
        XCTAssertEqual(element.uri, xmlnsURI, "uri was \(element.uri ?? "null") instead of \(xmlnsURI)")
        XCTAssertEqual(element.xmlString(options:.nodeCompactEmptyElement), #"<foo xmlns="\#(xmlnsURI)"/>"#, "invalid namespace declaration.")
        
        let otherURI = "http://example.com/fakenamespace"
        let otherNS = XMLNode.namespace(withName: "other", stringValue: otherURI) as! XMLNode
        element.addNamespace(otherNS)
        XCTAssert((element.namespaces ?? []).compactMap({ $0.stringValue }).contains(xmlnsURI), "lost original namespace")
        XCTAssert((element.namespaces ?? []).compactMap({ $0.stringValue }).contains(otherURI), "Lost new namespace")
        
        let otherNS2 = XMLNode.namespace(withName: "other", stringValue: otherURI) as! XMLNode
        element.addNamespace(otherNS2)
        XCTAssertEqual(element.namespaces?.count, 2, "incorrectly added a namespace with duplicate name!")
        
        let xmlString = element.xmlString(options:.nodeCompactEmptyElement)
        XCTAssert(xmlString == #"<foo xmlns="\#(xmlnsURI)" xmlns:other="\#(otherURI)"/>"# || xmlString == #"<foo xmlns:other="\#(otherURI)" xmlns="\#(xmlnsURI)"/>"#, "unexpected namespace declaration: \(xmlString)")
        
        let otherDoc = XMLDocument(rootElement: XMLElement(name: "Bar"))
        otherDoc.rootElement()?.namespaces = [XMLNode.namespace(withName: "R", stringValue: "http://example.com/rnamespace") as! XMLNode, XMLNode.namespace(withName: "F", stringValue: "http://example.com/fakenamespace") as! XMLNode]
        XCTAssert(otherDoc.rootElement()?.namespaces?.count == 2)
        let namespaces: [XMLNode]? = otherDoc.rootElement()?.namespaces
        let names: [String]? = namespaces?.compactMap { $0.name }
        XCTAssertNotNil(names)
        XCTAssert(names![0] == "R" && names![1] == "F")
        otherDoc.rootElement()?.namespaces = nil
        XCTAssert((otherDoc.rootElement()?.namespaces?.count ?? 0) == 0)
    }
    
    func test_removeNamespace() {
        let doc = XMLDocument(rootElement: XMLElement(name: "Foo"))
        let ns = XMLNode.namespace(withName: "F", stringValue: "http://example.com/fakenamespace") as! XMLNode
        let otherNS = XMLNode.namespace(withName: "R", stringValue: "http://example.com/rnamespace") as! XMLNode
        
        doc.rootElement()?.addNamespace(ns)
        doc.rootElement()?.addNamespace(otherNS)
        XCTAssert(doc.rootElement()?.namespaces?.count == 2)
        
        doc.rootElement()?.removeNamespace(forPrefix: "F")
        
        XCTAssert(doc.rootElement()?.namespaces?.count == 1)
        XCTAssert(doc.rootElement()?.namespaces?.first?.name == "R")
    }

    func test_validation_success() throws {
        throw XCTSkip(#"<https://bugs.swift.org/browse/SR-10643> Could not build URI for external subset "http://127.0.0.1:-2/DTDs/PropertyList-1.0.dtd""#)
        #if false
        let validString = "<?xml version=\"1.0\" standalone=\"yes\"?><!DOCTYPE foo [ <!ELEMENT foo (#PCDATA)> ]><foo>Hello world</foo>"
        do {
            let doc = try XMLDocument(xmlString: validString, options: [])
            try doc.validate()
        } catch {
            XCTFail("\(error)")
        }

        let dtdUrl = "http://127.0.0.1:\(TestURLSession.serverPort)/DTDs/PropertyList-1.0.dtd"
        let plistDocString = "<?xml version='1.0' encoding='utf-8'?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"\(dtdUrl)\"> <plist version='1.0'><dict><key>MyKey</key><string>Hello!</string></dict></plist>"
        let plistDoc = try XMLDocument(xmlString: plistDocString, options: [])
        do {
            try plistDoc.validate()
            XCTAssert(plistDoc.rootElement()?.name == "plist")
            let plist = try PropertyListSerialization.propertyList(from: plistDoc.xmlData, options: [], format: nil) as! [String: Any]
            XCTAssert((plist["MyKey"] as? String) == "Hello!")
        } catch let nsError as NSError {
            XCTFail("\(nsError.userInfo)")
        }
        #endif
    }

    func test_validation_failure() throws {
        throw XCTSkip("<https://bugs.swift.org/browse/SR-10643> XCTAssert in last catch block fails")
        #if false
        let xmlString = "<?xml version=\"1.0\" standalone=\"yes\"?><!DOCTYPE foo [ <!ELEMENT img EMPTY> ]><foo><img>not empty</img></foo>"
        do {
            let doc = try XMLDocument(xmlString: xmlString, options: [])
            try doc.validate()
            XCTFail("Should have thrown")
        } catch let nsError as NSError {
            XCTAssert(nsError.code == XMLParser.ErrorCode.internalError.rawValue)
            XCTAssert(nsError.domain == XMLParser.errorDomain)
            XCTAssert((nsError.userInfo[NSLocalizedDescriptionKey] as! String).contains("Element img was declared EMPTY this one has content"))
        }

        let dtdUrl = "http://127.0.0.1:\(TestURLSession.serverPort)/DTDs/PropertyList-1.0.dtd"
        let plistDocString = "<?xml version='1.0' encoding='utf-8'?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"\(dtdUrl)\"> <plist version='1.0'><dict><key>MyKey</key><string>Hello!</string><key>MyBooleanThing</key><true>foobar</true></dict></plist>"
        let plistDoc = try XMLDocument(xmlString: plistDocString, options: [])
        do {
            try plistDoc.validate()
            XCTFail("Should have thrown!")
        } catch let error as NSError {
            XCTAssert((error.userInfo[NSLocalizedDescriptionKey] as! String).contains("Element true was declared EMPTY this one has content"))
        }
        #endif
    }

    func test_dtd() throws {
        let node = XMLNode.dtdNode(withXMLString:"<!ELEMENT foo (#PCDATA)>") as! XMLDTDNode
        XCTAssert(node.name == "foo")
        
        let dtd = try XMLDTD(contentsOf: testBundle().url(forResource: "PropertyList-1.0", withExtension: "dtd")!, options: [])
        //        dtd.systemID = testBundle().URLForResource("PropertyList-1.0", withExtension: "dtd")?.absoluteString
        dtd.name = "plist"
        //        dtd.publicID = "-//Apple//DTD PLIST 1.0//EN"
        let plistNode = dtd.elementDeclaration(forName:"plist")
        XCTAssert(plistNode?.name == "plist")
        let plistObjectNode = dtd.entityDeclaration(forName:"plistObject")
        XCTAssert(plistObjectNode?.name == "plistObject")
        XCTAssert(plistObjectNode?.stringValue == "(array | data | date | dict | real | integer | string | true | false )")
        let plistAttribute = dtd.attributeDeclaration(forName:"version", elementName: "plist")
        XCTAssert(plistAttribute?.name == "version")

        let doc = try XMLDocument(xmlString: "<?xml version='1.0' encoding='utf-8'?><plist version='1.0'><dict><key>hello</key><string>world</string></dict></plist>", options: [])
        doc.dtd = dtd
        do {
            try doc.validate()
        } catch let error as NSError {
            XCTFail("\(error.userInfo)")
        }

        let amp = XMLDTD.predefinedEntityDeclaration(forName:"amp")
        XCTAssert(amp?.name == "amp", amp?.name ?? "")
        XCTAssert(amp?.stringValue == "&", amp?.stringValue ?? "")
        if let entityNode = XMLNode.dtdNode(withXMLString:"<!ENTITY author 'Robert Thompson'>") as? XMLDTDNode {
            XCTAssert(entityNode.name == "author")
            XCTAssert(entityNode.stringValue == "Robert Thompson")
        }

        let elementDecl = XMLDTDNode(kind: .elementDeclaration)
        elementDecl.name = "MyElement"
        elementDecl.stringValue = "(#PCDATA | array)*"
        XCTAssertEqual(elementDecl.stringValue, "(#PCDATA | array)*")
        XCTAssertEqual(elementDecl.name, "MyElement")
    }

    func test_documentWithDTD() throws {
        let doc = try XMLDocument(contentsOf: testBundle().url(forResource: "NSXMLDTDTestData", withExtension: "xml")!, options: [])
        let dtd = doc.dtd
        XCTAssert(dtd?.name == "root")
        
        let notation = dtd?.notationDeclaration(forName:"myNotation")
        notation?.detach()
        XCTAssert(notation?.name == "myNotation")
        XCTAssert(notation?.systemID == "http://www.example.com", notation?.systemID ?? "nil system id!")

        do {
            try doc.validate()
        } catch {
            XCTFail("\(error)")
        }

        let root = dtd?.elementDeclaration(forName:"root")
        root?.stringValue = "(#PCDATA)"
        do {
            try doc.validate()
            XCTFail("should have thrown")
        } catch let error as NSError {
            XCTAssert(error.code == XMLParser.ErrorCode.internalError.rawValue)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func test_dtd_attributes() throws {
        let doc = try XMLDocument(contentsOf: testBundle().url(forResource: "NSXMLDTDTestData", withExtension: "xml")!, options: [])
        let dtd = doc.dtd!
        let attrDecl = dtd.attributeDeclaration(forName: "print", elementName: "foo")!
        XCTAssert(attrDecl.dtdKind == .enumerationAttribute)
    }

    func test_documentWithEncodingSetDoesntCrash() throws {
        weak var weakDoc: XMLDocument? = nil
        func makeSureDocumentIsAllocatedAndFreed() {
                let doc = XMLDocument(rootElement: XMLElement(name: "test"))
                doc.characterEncoding = "UTF-8"
                weakDoc = doc
        }
        makeSureDocumentIsAllocatedAndFreed()
        XCTAssertNil(weakDoc, "document not freed even through it should have")
    }
    
    // Regression test for https://github.com/swiftlang/swift-docc/issues/1666:
    // `XMLElement(xmlString:)` traps (Illegal instruction / SIGILL) on Linux
    // instead of throwing.
    func test_elementFromMalformedXMLWithNoRootElementThrowsRatherThanCrashing() throws {
        XCTAssertThrowsError(try XMLElement(xmlString: "</details>"))
        XCTAssertThrowsError(try XMLElement(xmlString: "body\n</details>"))
    }

    func test_nodeFindingWithNamespaces() throws {
        let xmlString = """
        <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <D:propfind xmlns:D="DAV:">
                <D:prop>
                    <D:getlastmodified></D:getlastmodified>
                    <D:getcontentlength></D:getcontentlength>
                    <D:creationdate></D:creationdate>
                    <D:resourcetype></D:resourcetype>
                </D:prop>
            </D:propfind>
        """
        
        let doc = try XMLDocument(xmlString: xmlString, options: [])
        let namespace = (doc.rootElement()?.namespaces?.first)!
        XCTAssert(namespace.kind == .namespace, "The node was not a namespace but was a \(namespace.kind)")
        XCTAssert(namespace.stringValue == "DAV:", "expected a string value of DAV: got \(namespace.stringValue as Any)")
        XCTAssert(namespace.name == "D", "expected a name of D, got \(namespace.name as Any)")
        
        let newNS = XMLNode.namespace(withName: "R", stringValue: "http://apple.com") as! XMLNode
        XCTAssert(newNS.name == "R", "expected name R, got name \(newNS.name as Any)")
        XCTAssert(newNS.stringValue == "http://apple.com", "expected stringValue http://apple.com, got stringValue \(newNS.stringValue as Any)")
        newNS.stringValue = "FOO:"
        XCTAssert(newNS.stringValue == "FOO:")
        newNS.name = "F"
        XCTAssert(newNS.name == "F")
        
        let root = doc.rootElement()!
        XCTAssertEqual(root.localName, "propfind")
        XCTAssertEqual(root.name, "D:propfind")
        XCTAssertEqual(root.prefix, "D")
        let node = doc.findFirstChild(named: "prop")
        XCTAssert(node != nil, "failed to find existing node")
        XCTAssert(node?.localName == "prop")
        
        XCTAssert(doc.rootElement()?.elements(forLocalName: "prop", uri: "DAV:").first?.name == "D:prop", "failed to get elements, got \(doc.rootElement()?.elements(forLocalName: "prop", uri: "DAV:").first as Any)")
    }

    func test_optionPreserveAll() {
        let xmlString = """
<?xml version="1.0" encoding="UTF-8"?>
<document>
</document>
"""

        let data = xmlString.data(using: .utf8)!
        guard let document = try? XMLDocument(data: data, options: .nodePreserveAll) else {
            XCTFail("XMLDocument with options .nodePreserveAll")
            return
        }
        let expected = xmlString.lowercased() + "\n"
        XCTAssertEqual(expected, String(describing: document))
    }

    func test_rootElementRetainsDocument() {
        let str = """
<?xml version="1.0" encoding="UTF-8"?>
<plans></plans>
"""

        let data = str.data(using: .utf8)!

        func test() throws -> String? {
            let doc = try XMLDocument(data: data, options: []).rootElement()
            return doc?.name
        }

        XCTAssertEqual(try? test(), "plans")
    }

    func test_nodeKinds() {
        XCTAssertEqual(XMLDocument(rootElement: nil).kind, .document)
        XCTAssertEqual(XMLElement(name: "prefix:localName").kind, .element)
        XCTAssertEqual((XMLNode.attribute(withName: "name", stringValue: "value") as? XMLNode)?.kind, .attribute)
        XCTAssertEqual((XMLNode.namespace(withName: "namespace", stringValue: "http://example.com/") as? XMLNode)?.kind, .namespace)
        XCTAssertEqual((XMLNode.processingInstruction(withName: "name", stringValue: "value") as? XMLNode)?.kind, .processingInstruction)
        XCTAssertEqual((XMLNode.comment(withStringValue: "comment") as? XMLNode)?.kind, .comment)
        XCTAssertEqual((XMLNode.text(withStringValue: "text") as? XMLNode)?.kind, .text)
        XCTAssertEqual((try? XMLDTD(data:#"<!ENTITY a "A">"#.data(using: .utf8)!))?.kind, .DTDKind)
        XCTAssertEqual(XMLDTDNode(xmlString: #"<!ENTITY b "B">"#)?.kind, .entityDeclaration)
        XCTAssertEqual(XMLDTDNode(xmlString: "<!ATTLIST A B CDATA #IMPLIED>")?.kind, .attributeDeclaration)
        XCTAssertEqual(XMLDTDNode(xmlString: "<!ELEMENT E EMPTY>")?.kind, .elementDeclaration)
        XCTAssertEqual(XMLDTDNode(xmlString: #"<!NOTATION f SYSTEM "F">"#)?.kind, .notationDeclaration)
    }

    func test_nodeNames() throws {
        let doc = XMLDocument(rootElement: nil)
        XCTAssertNil(doc.name)
        doc.name = "name"
        XCTAssertNil(doc.name) // `name` of XMLDocument is always nil.
        
        let element = try XMLElement(xmlString: #"<element xmlns="http://example.com/defaultNS" />"#)
        XCTAssertEqual(element.name, "element")
        element.name = "otherElement"
        XCTAssertEqual(element.name, "otherElement")
        
        let attribute = try XCTUnwrap(XMLNode.attribute(withName: "name", stringValue: "value") as? XMLNode)
        XCTAssertEqual(attribute.name, "name")
        attribute.name = "otherName"
        XCTAssertEqual(attribute.name, "otherName")
        
        let namespace = try XCTUnwrap(element.namespaces?.first)
        XCTAssertEqual(namespace.name, "")
        namespace.name = "namespacePrefix"
        XCTAssertEqual(namespace.name, "namespacePrefix")
        
        let pi = try XCTUnwrap(XMLNode.processingInstruction(withName: "name", stringValue: "value") as? XMLNode)
        XCTAssertEqual(pi.name, "name")
        pi.name = "otherName"
        XCTAssertEqual(pi.name, "otherName")
        
        let comment = try XCTUnwrap(XMLNode.comment(withStringValue: "comment") as? XMLNode)
        XCTAssertNil(comment.name)
        comment.name = "name"
        XCTAssertNil(comment.name) // always nil
        
        let text = try XCTUnwrap(XMLNode.text(withStringValue: "text") as? XMLNode)
        XCTAssertNil(text.name)
        text.name = "name"
        XCTAssertNil(text.name) // always nil
        
        let dtd = try XMLDTD(data: #"<!ENTITY a "A">"#.data(using: .utf8)!)
        XCTAssertNil(dtd.name)
        dtd.name = "root"
        XCTAssertEqual(dtd.name, "root")
        
        let entityDecl = try XCTUnwrap(XMLDTDNode(xmlString: #"<!ENTITY b "B">"#))
        XCTAssertEqual(entityDecl.name, "b")
        entityDecl.name = "otherEntity"
        XCTAssertEqual(entityDecl.name, "otherEntity")
        
        let attrDecl = try XCTUnwrap(XMLDTDNode(xmlString: "<!ATTLIST A B CDATA #IMPLIED>"))
        XCTAssertEqual(attrDecl.name, "B")
        attrDecl.name = "otherAttr"
        XCTAssertEqual(attrDecl.name, "otherAttr")
        
        let elementDecl = try XCTUnwrap(XMLDTDNode(xmlString: "<!ELEMENT E EMPTY>"))
        XCTAssertEqual(elementDecl.name, "E")
        elementDecl.name = "otherElement"
        XCTAssertEqual(elementDecl.name, "otherElement")
        
        let notationDecl = try XCTUnwrap(XMLDTDNode(xmlString: #"<!NOTATION f SYSTEM "F">"#))
        XCTAssertEqual(notationDecl.name, "f")
        notationDecl.name = "otherNotation"
        XCTAssertEqual(notationDecl.name, "otherNotation")
    }
    
    @available(*, deprecated) // test of deprecated API, suppress deprecation warning
    func test_creatingAnEmptyDocumentAndNode() {
        _ = XMLDocument()
        _ = XMLNode()
    }
    
    func test_creatingAnEmptyDTD() {
        let dtd = XMLDTD()
        XCTAssertEqual(dtd.publicID, "")
        XCTAssertEqual(dtd.systemID, "")
        XCTAssertEqual(dtd.children ?? [], [])
        
        let plistDTDUrl = "https://www.apple.com/DTDs/PropertyList-1.0.dtd"
        dtd.systemID = plistDTDUrl
        XCTAssertEqual(dtd.systemID, plistDTDUrl)
    }
    
    func test_parsingCDataSections() throws {
        let xmlString = """
           <?xml version="1.0" encoding="utf-8" standalone="yes"?>
           <content>some text <![CDATA[Some verbatim content! <br> Yep, it's HTML, what are you going to do]]> some more text</content>
           """
        
        do {
            let doc = try XMLDocument(xmlString: xmlString, options: [])
            
            let root = try XCTUnwrap(doc.rootElement())
            XCTAssertEqual(root.childCount, 3)
            
            root.normalizeAdjacentTextNodesPreservingCDATA(false)
            XCTAssertEqual(root.childCount, 1)
            XCTAssertEqual(root.children?.first?.stringValue, "some text Some verbatim content! <br> Yep, it's HTML, what are you going to do some more text")
        }
        
        do {
            let doc = try XMLDocument(xmlString: xmlString, options: [])
            
            let root = try XCTUnwrap(doc.rootElement())
            XCTAssertEqual(root.childCount, 3)
            
            let prefix = XMLNode.text(withStringValue: "prefix! ") as! XMLNode
            root.insertChild(prefix, at: 0)
            print(root.children!.map { (name: $0.name, kind: $0.kind, stringValue: $0.stringValue ?? "") }.map { String(describing: $0) }.joined(separator: "\n"))
            
            root.normalizeAdjacentTextNodesPreservingCDATA(true)
            XCTAssertEqual(root.childCount, 3)
            let children = try XCTUnwrap(root.children)
            XCTAssertEqual(children[0].stringValue, "prefix! some text ")
            XCTAssertEqual(children[1].stringValue, "Some verbatim content! <br> Yep, it's HTML, what are you going to do")
            XCTAssertEqual(children[2].stringValue, " some more text")
        }
    }
}

fileprivate extension XMLNode {
    func findFirstChild(named name: String) -> XMLNode? {
        guard let children = self.children else {
            return nil
        }
        
        for child in children {
            if let childName = child.localName {
                if childName == name {
                    return child
                }
            }
            
            if let result = child.findFirstChild(named: name) {
                return result
            }
        }
        
        return nil
    }
}


