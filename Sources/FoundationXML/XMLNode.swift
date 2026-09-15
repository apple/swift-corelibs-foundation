// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

//import libxml2
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import SwiftFoundation
import _CFXMLInterface
#else
import Foundation
@_implementationOnly import _CFXMLInterface
#endif

// initWithKind options
//  NSXMLNodeOptionsNone
//  NSXMLNodePreserveAll
//  NSXMLNodePreserveNamespaceOrder
//  NSXMLNodePreserveAttributeOrder
//  NSXMLNodePreserveEntities
//  NSXMLNodePreservePrefixes
//  NSXMLNodeIsCDATA
//  NSXMLNodeExpandEmptyElement
//  NSXMLNodeCompactEmptyElement
//  NSXMLNodeUseSingleQuotes
//  NSXMLNodeUseDoubleQuotes

// Output options
//  NSXMLNodePrettyPrint

@available(*, unavailable)
extension XMLNode : @unchecked Sendable { }

/*!
 @class NSXMLNode
 @abstract The basic unit of an XML document.
 */
open class XMLNode: NSObject, NSCopying {
    
    public enum Kind : UInt, Sendable {
        case invalid
        case document
        case element
        case attribute
        case namespace
        case processingInstruction
        case comment
        case text
        case DTDKind
        case entityDeclaration
        case attributeDeclaration
        case elementDeclaration
        case notationDeclaration
    }
    
    public struct Options : OptionSet, Sendable {
        public let rawValue : UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        
        public static let nodeIsCDATA = Options(rawValue: 1 << 0)
        public static let nodeExpandEmptyElement = Options(rawValue: 1 << 1)
        public static let nodeCompactEmptyElement = Options(rawValue: 1 << 2)
        public static let nodeUseSingleQuotes = Options(rawValue: 1 << 3)
        public static let nodeUseDoubleQuotes = Options(rawValue: 1 << 4)
        public static let nodeNeverEscapeContents = Options(rawValue: 1 << 5)
        
        public static let documentTidyHTML = Options(rawValue: 1 << 9)
        public static let documentTidyXML = Options(rawValue: 1 << 10)
        public static let documentValidate = Options(rawValue: 1 << 13)
        
        public static let nodeLoadExternalEntitiesAlways = Options(rawValue: 1 << 14)
        public static let nodeLoadExternalEntitiesSameOriginOnly = Options(rawValue: 1 << 15)
        public static let nodeLoadExternalEntitiesNever = Options(rawValue: 1 << 19)
        
        public static let documentXInclude = Options(rawValue: 1 << 16)
        public static let nodePrettyPrint = Options(rawValue: 1 << 17)
        public static let documentIncludeContentTypeDeclaration = Options(rawValue: 1 << 18)
        
        public static let nodePreserveNamespaceOrder = Options(rawValue: 1 << 20)
        public static let nodePreserveAttributeOrder = Options(rawValue: 1 << 21)
        public static let nodePreserveEntities = Options(rawValue: 1 << 22)
        public static let nodePreservePrefixes = Options(rawValue: 1 << 23)
        public static let nodePreserveCDATA = Options(rawValue: 1 << 24)
        public static let nodePreserveWhitespace = Options(rawValue: 1 << 25)
        public static let nodePreserveDTD = Options(rawValue: 1 << 26)
        public static let nodePreserveCharacterReferences = Options(rawValue: 1 << 27)
        public static let nodePromoteSignificantWhitespace = Options(rawValue: 1 << 28)
        public static let nodePreserveEmptyElements = Options([.nodeExpandEmptyElement, .nodeCompactEmptyElement])
        public static let nodePreserveQuotes = Options([.nodeUseSingleQuotes, .nodeUseDoubleQuotes])
        public static let nodePreserveAll = Options(rawValue: 0xFFF00000).union([.nodePreserveNamespaceOrder, .nodePreserveAttributeOrder, .nodePreserveEntities, .nodePreservePrefixes, .nodePreserveCDATA, .nodePreserveEmptyElements, .nodePreserveQuotes, .nodePreserveWhitespace, .nodePreserveDTD, .nodePreserveCharacterReferences])
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    internal let _xmlNode: _CFXMLNodePtr!
    internal var _xmlDocument: XMLDocument?
    
    open func copy(with zone: NSZone? = nil) -> Any {
        let newNode = _CFXMLCopyNode(_xmlNode, true)
        return XMLNode._objectNodeForNode(newNode)
    }
    
    @available(*, deprecated, message: "On Darwin, this initializer creates nodes that are valid objects but crash your process if used. The same behavior is replicated in swift-corelibs-foundation, but you should not use this initializer on either platform; use one of the class methods or initializers instead to create a specific kind of code.")
    public convenience override init() {
        // Match the Darwin behavior.
        self.init(kind: .invalid)
    }
    
    /*!
     @method initWithKind:
     @abstract Invokes @link initWithKind:options: @/link with options set to NSXMLNodeOptionsNone
     */
    public convenience init(kind: XMLNode.Kind) {
        self.init(kind: kind, options: [])
    }
    
    /*!
     @method initWithKind:options:
     @abstract Inits a node with fidelity options as description NSXMLNodeOptions.h
     */
    public init(kind: XMLNode.Kind, options: XMLNode.Options = []) {
        setupXMLParsing()

        switch kind {
        case .document:
            let docPtr = _CFXMLNewDoc("1.0")
            _CFXMLDocSetStandalone(docPtr, false) // same default as on Darwin
            _xmlNode = _CFXMLNodePtr(docPtr)
            
        case .element:
            _xmlNode = _CFXMLNewNode(nil, "")
            
        case .attribute:
            _xmlNode = _CFXMLNodePtr(_CFXMLNewProperty(nil, "", nil, ""))
            
        case .DTDKind:
            _xmlNode = _CFXMLNewDTD(nil, "", "", "")
            
        case .namespace:
            _xmlNode = _CFXMLNewNamespace("", "")
            
        default:
            _xmlNode = nil
        }
        
        super.init()

        if let node = _xmlNode {
            withOpaqueUnretainedReference {
                _CFXMLNodeSetPrivateData(node, $0)
            }
        }
    }
    
    /*!
     @method document:
     @abstract Returns an empty document.
     */
    open class func document() -> Any {
        return XMLDocument(rootElement: nil)
    }
    
    /*!
     @method documentWithRootElement:
     @abstract Returns a document
     @param element The document's root node.
     */
    open class func document(withRootElement element: XMLElement) -> Any {
        return XMLDocument(rootElement: element)
    }
    
    /*!
     @method elementWithName:
     @abstract Returns an element <tt>&lt;name>&lt;/name></tt>.
     */
    open class func element(withName name: String) -> Any {
        return XMLElement(name: name)
    }
    
    /*!
     @method elementWithName:URI:
     @abstract Returns an element whose full QName is specified.
     */
    open class func element(withName name: String, uri: String) -> Any {
        return XMLElement(name: name, uri: uri)
    }
    
    /*!
     @method elementWithName:stringValue:
     @abstract Returns an element with a single text node child <tt>&lt;name>string&lt;/name></tt>.
     */
    open class func element(withName name: String, stringValue string: String) -> Any {
        return XMLElement(name: name, stringValue: string)
    }
    
    /*!
     @method elementWithName:children:attributes:
     @abstract Returns an element children and attributes <tt>&lt;name attr1="foo" attr2="bar">&lt;-- child1 -->child2&lt;/name></tt>.
     */
    open class func element(withName name: String, children: [XMLNode]?, attributes: [XMLNode]?) -> Any {
        let element = XMLElement(name: name)
        element.setChildren(children)
        element.attributes = attributes
        
        return element
    }
    
    /*!
     @method attributeWithName:stringValue:
     @abstract Returns an attribute <tt>name="stringValue"</tt>.
     */
    open class func attribute(withName name: String, stringValue: String) -> Any {
        let attribute = _CFXMLNewProperty(nil, name, nil, stringValue)
        
        return XMLNode(ptr: attribute)
    }
    
    /*!
     @method attributeWithLocalName:URI:stringValue:
     @abstract Returns an attribute whose full QName is specified.
     */
    open class func attribute(withName name: String, uri: String, stringValue: String) -> Any {
        let attribute = _CFXMLNewProperty(nil, name, uri, stringValue)
        
        return XMLNode(ptr: attribute)
    }
    
    /*!
     @method namespaceWithName:stringValue:
     @abstract Returns a namespace <tt>xmlns:name="stringValue"</tt>.
     */
    open class func namespace(withName name: String, stringValue: String) -> Any {
        let node = _CFXMLNewNamespace(name, stringValue)
        return XMLNode(ptr: node)
    }
    
    /*!
     @method processingInstructionWithName:stringValue:
     @abstract Returns a processing instruction <tt>&lt;?name stringValue></tt>.
     */
    public class func processingInstruction(withName name: String, stringValue: String) -> Any {
        let node = _CFXMLNewProcessingInstruction(name, stringValue)
        return XMLNode(ptr: node)
    }
    
    /*!
     @method commentWithStringValue:
     @abstract Returns a comment <tt>&lt;--stringValue--></tt>.
     */
    open class func comment(withStringValue stringValue: String) -> Any {
        let node = _CFXMLNewComment(stringValue)
        return XMLNode(ptr: node)
    }
    
    /*!
     @method textWithStringValue:
     @abstract Returns a text node.
     */
    open class func text(withStringValue stringValue: String) -> Any {
        let node = _CFXMLNewTextNode(stringValue)
        return XMLNode(ptr: node)
    }
    
    /*!
     @method DTDNodeWithXMLString:
     @abstract Returns an element, attribute, entity, or notation DTD node based on the full XML string.
     */
    open class func dtdNode(withXMLString string: String) -> Any? {
        setupXMLParsing()
        guard let node = _CFXMLParseDTDNode(string) else { return nil }
        
        return XMLDTDNode(ptr: node)
    }
    
    /*!
     @method kind
     @abstract Returns an element, attribute, entity, or notation DTD node based on the full XML string.
     */
    open var kind: XMLNode.Kind  {
        switch _CFXMLNodeGetType(_xmlNode) {
        case _kCFXMLTypeElement:
            return .element
            
        case _kCFXMLTypeAttribute:
            return .attribute
            
        case _kCFXMLTypeDocument:
            return .document
            
        case _kCFXMLTypeDTD:
            return .DTDKind
            
        case _kCFXMLDTDNodeTypeElement:
            return .elementDeclaration
            
        case _kCFXMLDTDNodeTypeEntity:
            return .entityDeclaration
            
        case _kCFXMLDTDNodeTypeNotation:
            return .notationDeclaration
            
        case _kCFXMLDTDNodeTypeAttribute:
            return .attributeDeclaration
            
        case _kCFXMLTypeNamespace:
            return .namespace
            
        case _kCFXMLTypeProcessingInstruction:
            return .processingInstruction
            
        case _kCFXMLTypeComment:
            return .comment
            
        case _kCFXMLTypeCDataSection: fallthrough
        case _kCFXMLTypeText:
            return .text
            
        default:
            return .invalid
        }
    }
    
    internal var isCData: Bool {
        return _CFXMLNodeGetType(_xmlNode) == _kCFXMLTypeCDataSection
    }
    
    /*!
     @method name
     @abstract Sets the nodes name. Applicable for element, attribute, namespace, processing-instruction, document type declaration, element declaration, attribute declaration, entity declaration, and notation declaration.
     */
    open var name: String? {
        get {
            switch kind {
            case .comment, .text:
                // As with Darwin, name is always nil when the node is comment or text.
                return nil
            case .namespace:
                return _CFXMLNamespaceCopyPrefix(_xmlNode).map({ unsafeBitCast($0, to: NSString.self) as String }) ?? ""
            default:
                return _CFXMLNodeCopyName(_xmlNode).map({ unsafeBitCast($0, to: NSString.self) as String })
            }
        }
        set {
            switch kind {
            case .document:
                // As with Darwin, ignore the name when the node is document.
                break
            case .notationDeclaration, .entityDeclaration, .attributeDeclaration, .elementDeclaration:
                // Use _CFXMLNodeForceSetName because
                // _CFXMLNodeSetName ignores the new name for DTD declaration nodes.
                _CFXMLNodeForceSetName(_xmlNode, newValue)
            case .namespace:
                _CFXMLNamespaceSetPrefix(_xmlNode, newValue, Int64(newValue?.utf8.count ?? 0))
            case .DTDKind:
                _CFXMLNodeForceSetName(_xmlNode, newValue)
            default:
                if let newName = newValue {
                    _CFXMLNodeSetName(_xmlNode, newName)
                } else {
                    _CFXMLNodeSetName(_xmlNode, "")
                }
            }
        }
    }
    
    private var _objectValue: Any? = nil
    
    /*!
     @method objectValue
     @abstract Sets the content of the node. Setting the objectValue removes all existing children including processing instructions and comments. Setting the object value on an element creates a single text node child.
     */
    open var objectValue: Any? {
        get {
            if let value = _objectValue {
                return value
            } else {
                return stringValue
            }
        }
        set {
            _objectValue = newValue
            if let describableValue = newValue as? CustomStringConvertible {
                stringValue = "\(describableValue.description)"
            } else if let value = newValue {
                stringValue = "\(value)"
            } else {
                stringValue = nil
            }
        }
    }
    
    /*!
     @method stringValue:
     @abstract Sets the content of the node. Setting the stringValue removes all existing children including processing instructions and comments. Setting the string value on an element creates a single text node child. The getter returns the string value of the node, which may be either its content or child text nodes, depending on the type of node. Elements are recursed and text nodes concatenated in document order with no intervening spaces.
     */
    open var stringValue: String? {
        get {
            switch kind {
            case .entityDeclaration:
                let returned = _CFXMLCopyEntityContent(_CFXMLEntityPtr(_xmlNode))
                return returned == nil ? nil : unsafeBitCast(returned!, to: NSString.self) as String
                
            case .namespace:
                let returned = _CFXMLNamespaceCopyValue(_xmlNode)
                return returned == nil ? nil : unsafeBitCast(returned!, to: NSString.self) as String
                
            case .element:
                // As with Darwin, children's string values are just concatenated without spaces.
                return children?.compactMap({ $0.stringValue }).joined() ?? ""
                
            default:
                let returned = _CFXMLNodeCopyContent(_xmlNode)
                return returned == nil ? nil : unsafeBitCast(returned!, to: NSString.self) as String
            }
        }
        set {
            switch kind {
            case .namespace:
                if let newValue = newValue {
                    precondition(URL(string: newValue) != nil, "namespace stringValue must be a valid href")
                }
                _CFXMLNamespaceSetValue(_xmlNode, newValue, Int64(newValue?.utf8.count ?? 0))
                
            case .comment, .text:
                _CFXMLNodeSetContent(_xmlNode, newValue)

            case .elementDeclaration:
                // Element declaration content is a validation string (e.g. "(#PCDATA | array)*"),
                // not XML text — entity-encoding it would corrupt it, and _CFXMLEncodeEntities
                // returns nil when there is no owning document, which would wipe the value.
                _CFXMLNodeSetContent(_xmlNode, newValue)

            default:
                _removeAllChildNodesExceptAttributes() // in case anyone is holding a reference to any of these children we're about to destroy
                if let string = newValue {
                    let returned = _CFXMLEncodeEntities(_CFXMLNodeGetDocument(_xmlNode), string)
                    let newContent = returned == nil ? "" : unsafeBitCast(returned!, to: NSString.self) as String
                    _CFXMLNodeSetContent(_xmlNode, newContent)
                } else {
                    _CFXMLNodeSetContent(_xmlNode, nil)
                }
            }
        }
    }
    
    private func _removeAllChildNodesExceptAttributes() {
        for node in _childNodes {
            if node.kind != .attribute {
                _CFXMLUnlinkNode(node._xmlNode)
                _childNodes.remove(node)
            }
        }
    }
    
    internal func _removeAllChildren() {
        var nextChild = _CFXMLNodeGetFirstChild(_xmlNode)
        while let child = nextChild {
            nextChild = _CFXMLNodeGetNextSibling(child)
            _CFXMLUnlinkNode(child)
        }
        _childNodes.removeAll(keepingCapacity: true)
    }
    
    /*!
     @method setStringValue:resolvingEntities:
     @abstract Sets the content as with @link setStringValue: @/link, but when "resolve" is true, character references, predefined entities and user entities available in the document's dtd are resolved. Entities not available in the dtd remain in their entity form.
     */
    open func setStringValue(_ string: String, resolvingEntities resolve: Bool) {
        guard resolve else {
            stringValue = string
            return
        }
        
        _removeAllChildNodesExceptAttributes()
        
        var entities: [(Range<Int>, String)] = []
        var entityChars: [Character] = []
        var inEntity = false
        var startIndex = 0
        for (index, char) in string.enumerated() {
            if char == "&" {
                inEntity = true
                startIndex = index
                continue
            }
            if char == ";" && inEntity {
                inEntity = false
                let min = startIndex
                let max = index + 1
                entities.append((min..<max, String(entityChars)))
                startIndex = 0
                entityChars.removeAll()
            }
            if inEntity {
                entityChars.append(char)
            }
        }
        
        var result: [Character] = Array(string)
        let doc = _CFXMLNodeGetDocument(_xmlNode)!
        for (range, entity) in entities {
            var entityPtr = _CFXMLGetDocEntity(doc, entity)
            if entityPtr == nil {
                entityPtr = _CFXMLGetDTDEntity(doc, entity)
            }
            if entityPtr == nil {
                entityPtr = _CFXMLGetParameterEntity(doc, entity)
            }
            if let validEntity = entityPtr {
                let returned = _CFXMLCopyEntityContent(validEntity)
                let replacement = returned == nil ? "" : unsafeBitCast(returned!, to: NSString.self) as String
                result.replaceSubrange(range, with: replacement)
            } else {
                result.replaceSubrange(range, with: []) // This appears to be how Darwin Foundation does it
            }
        }
        stringValue = String(result)
    }
    
    /*!
     @method index
     @abstract A node's index amongst its siblings.
     */
    open var index: Int {
        if let siblings = self.parent?.children,
            let index = siblings.firstIndex(of: self) {
            return index
        }
        
        return 0
    }
    
    /*!
     @method level
     @abstract The depth of the node within the tree. Documents and standalone nodes are level 0.
     */
    open var level: Int {
        var result = 0
        var nextParent = _CFXMLNodeGetParent(_xmlNode)
        while let parent = nextParent {
            result += 1
            nextParent = _CFXMLNodeGetParent(parent)
        }
        
        return result
    }
    
    /*!
     @method rootDocument
     @abstract The encompassing document or nil.
     */
    open var rootDocument: XMLDocument? {
        guard let doc = _CFXMLNodeGetDocument(_xmlNode) else { return nil }
        
        return XMLNode._objectNodeForNode(_CFXMLNodePtr(doc)) as? XMLDocument
    }
    
    /*!
     @method parent
     @abstract The parent of this node. Documents and standalone Nodes have a nil parent; there is not a 1-to-1 relationship between parent and children, eg a namespace cannot be a child but has a parent element.
     */
    /*@NSCopying*/ open var parent: XMLNode? {
        guard let parentPtr = _CFXMLNodeGetParent(_xmlNode) else { return nil }
        
        return XMLNode._objectNodeForNode(parentPtr)
    }
    
    /*!
     @method childCount
     @abstract The amount of children, relevant for documents, elements, and document type declarations.
     */
    open var childCount: Int {
        return self.children?.count ?? 0
    }
    
    /*!
     @method children
     @abstract An immutable array of child nodes. Relevant for documents, elements, and document type declarations.
     */
    open var children: [XMLNode]? {
        switch kind {
        case .document:
            fallthrough
        case .element:
            fallthrough
        case .DTDKind:
            return Array<XMLNode>(self as XMLNode)
            
        default:
            return nil
        }
    }
    
    /*!
     @method childAtIndex:
     @abstract Returns the child node at a particular index.
     */
    open func child(at index: Int) -> XMLNode? {
        precondition(index >= 0)
        precondition(index < childCount)
        
        return self[self.index(startIndex, offsetBy: index)]
    }
    
    /*!
     @method previousSibling:
     @abstract Returns the previous sibling, or nil if there isn't one.
     */
    /*@NSCopying*/ open var previousSibling: XMLNode? {
        guard let prev = _CFXMLNodeGetPrevSibling(_xmlNode) else { return nil }
        
        return XMLNode._objectNodeForNode(prev)
    }
    
    /*!
     @method nextSibling:
     @abstract Returns the next sibling, or nil if there isn't one.
     */
    /*@NSCopying*/ open var nextSibling: XMLNode? {
        guard let next = _CFXMLNodeGetNextSibling(_xmlNode) else { return nil }
        
        return XMLNode._objectNodeForNode(next)
    }
    
    /*!
     @method previousNode:
     @abstract Returns the previous node in document order. This can be used to walk the tree backwards.
     */
    /*@NSCopying*/ open var previous: XMLNode? {
        if let previousSibling = self.previousSibling {
            if let lastChild = _CFXMLNodeGetLastChild(previousSibling._xmlNode) {
                return XMLNode._objectNodeForNode(lastChild)
            } else {
                return previousSibling
            }
        } else if let parent = self.parent {
            return parent
        } else {
            return nil
        }
    }
    
    /*!
     @method nextNode:
     @abstract Returns the next node in document order. This can be used to walk the tree forwards.
     */
    /*@NSCopying*/ open var next: XMLNode? {
        if let children = _CFXMLNodeGetFirstChild(_xmlNode) {
            return XMLNode._objectNodeForNode(children)
        } else if let next = nextSibling {
            return next
        } else if let parent = self.parent {
            return parent.nextSibling
        } else {
            return nil
        }
    }
    
    /*!
     @method detach:
     @abstract Detaches this node from its parent.
     */
    open func detach() {
        guard let parentPtr = _CFXMLNodeGetParent(_xmlNode) else { return }
        _CFXMLUnlinkNode(_xmlNode)
        
        guard let parentNodePtr = _CFXMLNodeGetPrivateData(parentPtr) else { return }
        
        let parent = unsafeBitCast(parentNodePtr, to: XMLNode.self)
        parent._childNodes.remove(self)
    }
    
    /*!
     @method XPath
     @abstract Returns the XPath to this node, for example foo/bar[2]/baz.
     */
    open var xPath: String? {
        guard _CFXMLNodeGetDocument(_xmlNode) != nil else { return nil }
        
        let returned = _CFXMLCopyPathForNode(_xmlNode)
        return returned == nil ? nil : unsafeBitCast(returned!, to: NSString.self) as String
    }
    
    /*!
     @method localName
     @abstract Returns the local name bar if this attribute or element's name is foo:bar
     */
    open var localName: String? {
        let returned = _CFXMLNodeCopyLocalName(_xmlNode)
        return returned == nil ? nil : unsafeBitCast(returned!, to: NSString.self) as String
    }
    
    /*!
     @method prefix
     @abstract Returns the prefix foo if this attribute or element's name if foo:bar
     */
    open var prefix: String? {
        switch kind {
        case .namespace:
            return _CFXMLNamespaceCopyPrefix(_xmlNode).map({ unsafeBitCast($0, to: NSString.self) as String }) ?? ""
        default:
            let returned = _CFXMLNodeCopyPrefix(_xmlNode)
            return returned == nil ? nil : unsafeBitCast(returned!, to: NSString.self) as String
        }
    }
    
    /*!
     @method URI
     @abstract Set the URI of this element, attribute, or document. For documents it is the URI of document origin. Getter returns the URI of this element, attribute, or document. For documents it is the URI of document origin and is automatically set when using initWithContentsOfURL.
     */
    open var uri: String? {
        get {
            let returned = _CFXMLNodeCopyURI(_xmlNode)
            return returned == nil ? nil : unsafeBitCast(returned!, to: NSString.self) as String
        }
        set {
            if let URI = newValue {
                _CFXMLNodeSetURI(_xmlNode, URI)
            } else {
                _CFXMLNodeSetURI(_xmlNode, nil)
            }
        }
    }
    
    /*!
     @method localNameForName:
     @abstract Returns the local name bar in foo:bar.
     */
    open class func localName(forName name: String) -> String {
        if let localName = _CFXMLSplitQualifiedName(name) {
            return String(cString: localName)
        } else {
            return name
        }
    }
    
    /*!
     @method localNameForName:
     @abstract Returns the prefix foo in the name foo:bar.
     */
    open class func prefix(forName name: String) -> String? {
        var size: size_t = 0
        if _CFXMLGetLengthOfPrefixInQualifiedName(name, &size) {
            return name.withCString {
                $0.withMemoryRebound(to: UInt8.self, capacity: size) {
                    return String(decoding: UnsafeBufferPointer(start: $0, count: size), as: UTF8.self)
                }
            }
        } else {
            return nil
        }
    }
    
    /*!
     @method predefinedNamespaceForPrefix:
     @abstract Returns the namespace belonging to one of the predefined namespaces xml, xs, or xsi
     */
    private static func defaultNamespace(prefix: String, value: String) -> XMLNode {
        let node = XMLNode(kind: .namespace)
        node.name = prefix
        node.objectValue = value
        return node
    }
    private static nonisolated(unsafe) let _defaultNamespaces: [XMLNode] = [
        XMLNode.defaultNamespace(prefix: "xml", value: "http://www.w3.org/XML/1998/namespace"),
        XMLNode.defaultNamespace(prefix: "xml", value: "http://www.w3.org/2001/XMLSchema"),
        XMLNode.defaultNamespace(prefix: "xml", value: "http://www.w3.org/2001/XMLSchema-instance"),
    ]
    
    internal static nonisolated(unsafe) let _defaultNamespacesByPrefix: [String: XMLNode] =
        Dictionary(XMLNode._defaultNamespaces.map { ($0.name!, $0) }, uniquingKeysWith: { old, _ in old })

    internal static nonisolated(unsafe) let _defaultNamespacesByURI: [String: XMLNode] =
        Dictionary(XMLNode._defaultNamespaces.map { ($0.stringValue!, $0) }, uniquingKeysWith: { old, _ in old })

    open class func predefinedNamespace(forPrefix name: String) -> XMLNode? {
        return XMLNode._defaultNamespacesByPrefix[name]
    }
    
    /*!
     @method description
     @abstract Used for debugging. May give more information than XMLString.
     */
    open override var description: String {
        return xmlString
    }
    
    /*!
     @method XMLString
     @abstract The representation of this node as it would appear in an XML document.
     */
    open var xmlString: String {
        return xmlString(options: [])
    }
    
    /*!
     @method XMLStringWithOptions:
     @abstract The representation of this node as it would appear in an XML document, with various output options available.
     */
    open func xmlString(options: Options) -> String {
        return unsafeBitCast(_CFXMLCopyStringWithOptions(_xmlNode, UInt32(options.rawValue)), to: NSString.self) as String
    }
    
    /*!
     @method canonicalXMLStringPreservingComments:
     @abstract W3 canonical form (http://www.w3.org/TR/xml-c14n). The input option NSXMLNodePreserveWhitespace should be set for true canonical form.
     */
    open func canonicalXMLStringPreservingComments(_ comments: Bool) -> String {
        var result = ""
        switch kind {
        case .text:
            let scanner = Scanner(string: self.stringValue ?? "")
            let toReplace = CharacterSet(charactersIn: "&<>\r")
            while let string = scanner.scanUpToCharacters(from: toReplace) {
                result += string
                if scanner.scanString("&") != nil {
                    result += "&amp;"
                } else if scanner.scanString("<") != nil {
                    result += "&lt;"
                } else if scanner.scanString(">") != nil {
                    result += "&gt;"
                } else if scanner.scanString("\r") != nil {
                    result += "&#xD;"
                } else {
                    fatalError("We scanned up to one of the characters to replace, but couldn't find it when we went to consume it.")
                }
            }
            result += scanner.string[scanner.currentIndex...]
            
            
        case .comment:
            if comments {
                result = "<!--\(stringValue ?? "")-->"
            }
            
        default: break
        }
        
        return result
    }
    
    /*!
     @method nodesForXPath:error:
     @abstract Returns the nodes resulting from applying an XPath to this node using the node as the context item ("."). normalizeAdjacentTextNodesPreservingCDATA:NO should be called if there are adjacent text nodes since they are not allowed under the XPath/XQuery Data Model.
     @returns An array whose elements are a kind of NSXMLNode.
     */
    open func nodes(forXPath xpath: String) throws -> [XMLNode] {
        guard let nodes = _CFXMLNodesForXPath(_xmlNode, xpath) else {
            return []
        }
        
        var result: [XMLNode] = []
        
        let CFArrayGetCount = unsafeBitCast(CF.CFArrayGetCount, to: (@convention(c) (CFArray) -> CFIndex).self)
        let CFArrayGetValueAtIndex = unsafeBitCast(CF.CFArrayGetValueAtIndex, to: (@convention(c) (CFArray, CFIndex) -> UnsafeRawPointer?).self)

        for i in 0..<CFArrayGetCount(nodes) {
            let nodePtr = CFArrayGetValueAtIndex(nodes, i)!
            result.append(XMLNode._objectNodeForNode(_CFXMLNodePtr(mutating: nodePtr)))
        }
        
        return result
    }
    
    /*!
     @method objectsForXQuery:constants:error:
     @abstract Returns the objects resulting from applying an XQuery to this node using the node as the context item ("."). Constants are a name-value dictionary for constants declared "external" in the query. normalizeAdjacentTextNodesPreservingCDATA:NO should be called if there are adjacent text nodes since they are not allowed under the XPath/XQuery Data Model.
     @returns An array whose elements are kinds of NSArray, NSData, NSDate, NSNumber, NSString, NSURL, or NSXMLNode.
     */
    @available(*, unavailable, message: "XQuery is not available in swift-corelibs-foundation")
    open func objects(forXQuery xquery: String, constants: [String : Any]?) throws -> [Any] {
        NSUnsupported()
    }
    
    @available(*, unavailable, message: "XQuery is not available in swift-corelibs-foundation")
    open func objects(forXQuery xquery: String) throws -> [Any] {
        NSUnsupported()
    }
    
    internal var _childNodes: Set<XMLNode> = []
    
    deinit {
        guard _xmlNode != nil else { return }
        
        for node in _childNodes {
            node.detach()
        }
        
        _xmlDocument = nil
        
        switch kind {
        case .document:
            _CFXMLFreeDocument(_CFXMLDocPtr(_xmlNode))
            
        case .DTDKind:
            _CFXMLFreeDTD(_CFXMLDTDPtr(_xmlNode))
            
        case .attribute:
            _CFXMLFreeProperty(_xmlNode)
            
        default:
            _CFXMLFreeNode(_xmlNode)
        }
    }
    
    internal init(ptr: _CFXMLNodePtr) {
        setupXMLParsing()
        precondition(_CFXMLNodeGetPrivateData(ptr) == nil, "Only one XMLNode per xmlNodePtr allowed")
        
        _xmlNode = ptr
        super.init()
        
        if let parent = _CFXMLNodeGetParent(_xmlNode) {
            let parentNode = XMLNode._objectNodeForNode(parent)
            parentNode._childNodes.insert(self)
        }
        
        
        _CFXMLNodeSetPrivateData(_xmlNode, Unmanaged.passRetained(self).toOpaque())
        
        if let documentPtr = _CFXMLNodeGetDocument(_xmlNode) {
            if documentPtr != ptr {
                _xmlDocument = XMLDocument._objectNodeForNode(documentPtr)
            }
        }
    }
    
    internal class func _objectNodeForNode(_ node: _CFXMLNodePtr) -> XMLNode {
        switch _CFXMLNodeGetType(node) {
        case _kCFXMLTypeElement:
            return XMLElement._objectNodeForNode(node)
            
        case _kCFXMLTypeDocument:
            return XMLDocument._objectNodeForNode(node)
            
        case _kCFXMLTypeDTD:
            return XMLDTD._objectNodeForNode(node)
            
        case _kCFXMLDTDNodeTypeEntity:
            fallthrough
        case _kCFXMLDTDNodeTypeElement:
            fallthrough
        case _kCFXMLDTDNodeTypeNotation:
            fallthrough
        case _kCFXMLDTDNodeTypeAttribute:
            return XMLDTDNode._objectNodeForNode(node)
            
        default:
            if let _private = _CFXMLNodeGetPrivateData(node) {
                return unsafeBitCast(_private, to: XMLNode.self)
            }
            
            return XMLNode(ptr: node)
        }
    }
    
    // libxml2 believes any node can have children, though XMLNode disagrees.
    // Nevertheless, this belongs here so that XMLElement and XMLDocument can share
    // the same implementation.
    internal func _insertChild(_ child: XMLNode, atIndex index: Int) {
        precondition(index >= 0)
        precondition(index <= childCount)
        precondition(child.parent == nil)
        
        _childNodes.insert(child)
        
        if index == 0 {
            let first = _CFXMLNodeGetFirstChild(_xmlNode)!
            _CFXMLNodeAddPrevSibling(first, child._xmlNode)
        } else {
            let currChild = self.child(at: index - 1)!._xmlNode
            _CFXMLNodeAddNextSibling(currChild!, child._xmlNode)
        }
    }
    
    // see above
    internal func _insertChildren(_ children: [XMLNode], atIndex index: Int) {
        for (childIndex, node) in children.enumerated() {
            _insertChild(node, atIndex: index + childIndex)
        }
    }
    
    /*!
     @method removeChildAtIndex:atIndex:
     @abstract Removes a child at a particular index.
     */
    // See above!
    internal func _removeChildAtIndex(_ index: Int) {
        guard let child = child(at: index) else {
            fatalError("index out of bounds")
        }
        
        _childNodes.remove(child)
        _CFXMLUnlinkNode(child._xmlNode)
    }
    
    // see above
    internal func _setChildren(_ children: [XMLNode]?) {
        _removeAllChildren()
        guard let children = children else {
            return
        }
        
        for child in children {
            _addChild(child)
        }
    }
    
    /*!
     @method addChild:
     @abstract Adds a child to the end of the existing children.
     */
    // see above
    internal func _addChild(_ child: XMLNode) {
        precondition(child.parent == nil)
        
        _CFXMLNodeAddChild(_xmlNode, child._xmlNode)
        _childNodes.insert(child)
    }
    
    /*!
     @method replaceChildAtIndex:withNode:
     @abstract Replaces a child at a particular index with another child.
     */
    // see above
    internal func _replaceChildAtIndex(_ index: Int, withNode node: XMLNode) {
        let child = self.child(at: index)!
        _childNodes.remove(child)
        _CFXMLNodeReplaceNode(child._xmlNode, node._xmlNode)
        _childNodes.insert(node)
    }
}

internal protocol _NSXMLNodeCollectionType: Collection { }

@available(*, unavailable)
extension XMLNode.Index : Sendable { }

extension XMLNode: _NSXMLNodeCollectionType {
    
    public struct Index: Comparable {
        fileprivate let node: _CFXMLNodePtr?
        fileprivate let offset: Int?
    }
    
    public subscript(index: Index) -> XMLNode {
        return XMLNode._objectNodeForNode(index.node!)
    }
    
    public var startIndex: Index {
        let node = _CFXMLNodeGetFirstChild(_xmlNode)
        return Index(node: node, offset: node.map { _ in 0 })
    }
    
    public var endIndex: Index {
        return Index(node: nil, offset: nil)
    }
    
    public func index(after i: Index) -> Index {
        precondition(i.node != nil, "can't increment endIndex")
        let nextNode = _CFXMLNodeGetNextSibling(i.node!)
        return Index(node: nextNode, offset: nextNode.map { _ in i.offset! + 1 } )
    }
}

extension XMLNode.Index {
    public static func ==(lhs: XMLNode.Index, rhs: XMLNode.Index) -> Bool {
        return lhs.offset == rhs.offset
    }
    
    public static func <(lhs: XMLNode.Index, rhs: XMLNode.Index) -> Bool {
        switch (lhs.offset, rhs.offset) {
        case (nil, nil):
            return false
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        case (let lhsOffset?, let rhsOffset?):
            return lhsOffset < rhsOffset
        }
    }
}
