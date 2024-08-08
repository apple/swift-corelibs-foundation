// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import SwiftFoundation
import _CFXMLInterface
#else
import Foundation
@_implementationOnly import _CFXMLInterface
#endif

extension XMLParser {
    public enum ExternalEntityResolvingPolicy : UInt, Sendable {
        case never // default
        case noNetwork
        case sameOriginOnly //only applies to NSXMLParser instances initialized with -initWithContentsOfURL:
        case always
    }
}

extension _CFXMLInterface {
    var parser: XMLParser {
        return unsafeBitCast(self, to: XMLParser.self)
    }
}

extension XMLParser {
    internal var interface: _CFXMLInterface {
        return unsafeBitCast(self, to: _CFXMLInterface.self)
    }
}

private func UTF8STRING(_ bytes: UnsafePointer<UInt8>?) -> String? {
    guard let bytes = bytes else {
        return nil
    }
    if let (str, _) = String.decodeCString(bytes, as: UTF8.self,
                                           repairingInvalidCodeUnits: false) {
        return str
    }
    return nil
}

internal func _NSXMLParserCurrentParser() -> _CFXMLInterface? {
    if let parser = XMLParser.currentParser() {
        return parser.interface
    } else {
        return nil
    }
}

internal func _NSXMLParserExternalEntityWithURL(_ interface: _CFXMLInterface, urlStr: UnsafePointer<Int8>, identifier: UnsafePointer<Int8>, context: _CFXMLInterfaceParserContext, originalLoaderFunction: _CFXMLInterfaceExternalEntityLoader) -> _CFXMLInterfaceParserInput? {
    let parser = interface.parser
    let policy = parser.externalEntityResolvingPolicy
    var a: URL?
    if let allowedEntityURLs = parser.allowedExternalEntityURLs {
        if let url = URL(string: String(describing: urlStr)) {
            a = url
            if let scheme = url.scheme {
                if scheme == "file" {
                    a = URL(fileURLWithPath: url.path)
                }
            }
        }
        if let url = a {
            let allowed = allowedEntityURLs.contains(url)
            if allowed || policy != .sameOriginOnly {
                if allowed {
                    return originalLoaderFunction(urlStr, identifier, context)
                }
            }
        }
    }
    
    switch policy {
    case .sameOriginOnly:
        guard let url = parser._url else { break }
        
        if a == nil {
            a = URL(string: String(describing: urlStr))
        }
        
        guard let aUrl = a else { break }
        
        var matches: Bool
        if let aHost = aUrl.host, let host = url.host {
            matches = host == aHost
        } else {
            return nil
        }
        
        if matches {
            if let aPort = aUrl.port, let port = url.port {
                matches = port == aPort
            } else {
                return nil
            }
        }
        
        if matches {
            if let aScheme = aUrl.scheme, let scheme = url.scheme {
                matches = scheme == aScheme
            } else {
                return nil
            }
        }
        
        if !matches {
            return nil
        }
    case .always:
        break
    case .never:
        return nil
    case .noNetwork:
        return _CFXMLInterfaceNoNetExternalEntityLoader(urlStr, identifier, context)
    }
    
    return originalLoaderFunction(urlStr, identifier, context)
}

internal func _NSXMLParserGetContext(_ ctx: _CFXMLInterface) -> _CFXMLInterfaceParserContext {
    return ctx.parser._parserContext!
}

internal func _NSXMLParserInternalSubset(_ ctx: _CFXMLInterface, name: UnsafePointer<UInt8>, ExternalID: UnsafePointer<UInt8>, SystemID: UnsafePointer<UInt8>) -> Void {
    _CFXMLInterfaceSAX2InternalSubset(ctx.parser._parserContext, name, ExternalID, SystemID)
}

internal func _NSXMLParserIsStandalone(_ ctx: _CFXMLInterface) -> Int32 {
    return _CFXMLInterfaceIsStandalone(ctx.parser._parserContext)
}

internal func _NSXMLParserHasInternalSubset(_ ctx: _CFXMLInterface) -> Int32 {
    return _CFXMLInterfaceHasInternalSubset(ctx.parser._parserContext)
}

internal func _NSXMLParserHasExternalSubset(_ ctx: _CFXMLInterface) -> Int32 {
    return _CFXMLInterfaceHasExternalSubset(ctx.parser._parserContext)
}

internal func _NSXMLParserGetEntity(_ ctx: _CFXMLInterface, name: UnsafePointer<UInt8>) -> _CFXMLInterfaceEntity? {
    let parser = ctx.parser
    let context = _NSXMLParserGetContext(ctx)
    var entity = _CFXMLInterfaceGetPredefinedEntity(name)
    if entity == nil {
        entity = _CFXMLInterfaceSAX2GetEntity(context, name)
    }
    if entity == nil {
        if let delegate = parser.delegate {
            let entityName = UTF8STRING(name)!
            // if the systemID was valid, we would already have the correct entity (since we're loading external dtds) so this callback is a bit of a misnomer
            let result = delegate.parser(parser, resolveExternalEntityName: entityName, systemID: nil)
            if _CFXMLInterfaceHasDocument(context) != 0 {
                if let data = result {
                    // unfortunately we can't add the entity to the doc to avoid further lookup since the delegate can change under us
                    data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
                        let bytes = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                        _NSXMLParserCharacters(ctx, ch: bytes, len: Int32(data.count))
                    }
                    
                }
            }
        }
    }
    return entity
}

internal func _NSXMLParserNotationDecl(_ ctx: _CFXMLInterface, name: UnsafePointer<UInt8>, publicId: UnsafePointer<UInt8>, systemId: UnsafePointer<UInt8>) -> Void {
    let parser = ctx.parser
    if let delegate = parser.delegate {
        let notationName = UTF8STRING(name)!
        let publicIDString = UTF8STRING(publicId)
        let systemIDString = UTF8STRING(systemId)
        delegate.parser(parser, foundNotationDeclarationWithName: notationName, publicID: publicIDString, systemID: systemIDString)
    }
}

internal func _NSXMLParserAttributeDecl(_ ctx: _CFXMLInterface, elem: UnsafePointer<UInt8>, fullname: UnsafePointer<UInt8>, type: Int32, def: Int32, defaultValue: UnsafePointer<UInt8>, tree: _CFXMLInterfaceEnumeration) -> Void {
    let parser = ctx.parser
    if let delegate = parser.delegate {
        let elementString = UTF8STRING(elem)!
        let nameString = UTF8STRING(fullname)!
        let typeString = "" // FIXME!
        let defaultValueString = UTF8STRING(defaultValue)
        delegate.parser(parser, foundAttributeDeclarationWithName: nameString, forElement: elementString, type: typeString, defaultValue: defaultValueString)
    }
    // in a regular sax implementation tree is added to an attribute, which takes ownership of it; in our case we need to make sure to release it
    _CFXMLInterfaceFreeEnumeration(tree)
}

internal func _NSXMLParserElementDecl(_ ctx: _CFXMLInterface, name: UnsafePointer<UInt8>, type: Int32, content: _CFXMLInterfaceElementContent) -> Void {
    let parser = ctx.parser
    if let delegate = parser.delegate {
        let nameString = UTF8STRING(name)!
        let modelString = "" // FIXME!
        delegate.parser(parser, foundElementDeclarationWithName: nameString, model: modelString)
    }
}

internal func _NSXMLParserUnparsedEntityDecl(_ ctx: _CFXMLInterface, name: UnsafePointer<UInt8>, publicId: UnsafePointer<UInt8>, systemId: UnsafePointer<UInt8>, notationName: UnsafePointer<UInt8>) -> Void {
    let parser = ctx.parser
    let context = _NSXMLParserGetContext(ctx)
    
    // Add entities to the libxml2 doc so they'll resolve properly
    _CFXMLInterfaceSAX2UnparsedEntityDecl(context, name, publicId, systemId, notationName)
    if let delegate = parser.delegate {
        let declName = UTF8STRING(name)!
        let publicIDString = UTF8STRING(publicId)
        let systemIDString = UTF8STRING(systemId)
        let notationNameString = UTF8STRING(notationName)
        delegate.parser(parser, foundUnparsedEntityDeclarationWithName: declName, publicID: publicIDString, systemID: systemIDString, notationName: notationNameString)
    }
}

internal func _NSXMLParserStartDocument(_ ctx: _CFXMLInterface) -> Void {
    let parser = ctx.parser
    if let delegate = parser.delegate {
        delegate.parserDidStartDocument(parser)
    }
}

internal func _NSXMLParserEndDocument(_ ctx: _CFXMLInterface) -> Void {
    let parser = ctx.parser
    if let delegate = parser.delegate {
        delegate.parserDidEndDocument(parser)
    }
}


internal func _NSXMLParserStartElementNs(_ ctx: _CFXMLInterface, localname: UnsafePointer<UInt8>, prefix: UnsafePointer<UInt8>?, URI: UnsafePointer<UInt8>?, nb_namespaces: Int32, namespaces: UnsafeMutablePointer<UnsafePointer<UInt8>?>, nb_attributes: Int32, nb_defaulted: Int32, attributes: UnsafeMutablePointer<UnsafePointer<UInt8>?>) -> Void {
    let parser = ctx.parser
    let reportNamespaces = parser.shouldReportNamespacePrefixes

    var nsDict = [String:String]()
    var attrDict = [String:String]()
    if nb_attributes + nb_namespaces > 0 {
        for idx in stride(from: 0, to: Int(nb_namespaces) * 2, by: 2) {
            var namespaceNameString: String?
            var asAttrNamespaceNameString: String?
            if let ns = namespaces[idx] {
                namespaceNameString = UTF8STRING(ns)
                asAttrNamespaceNameString = "xmlns:" + namespaceNameString!
            } else {
                namespaceNameString = ""
                asAttrNamespaceNameString = "xmlns"
            }
            let namespaceValueString = namespaces[idx + 1] != nil ? UTF8STRING(namespaces[idx + 1]!) : ""
            if reportNamespaces {
                if let k = namespaceNameString, let v = namespaceValueString {
                    nsDict[k] = v
                }
            }
            if !parser.shouldProcessNamespaces {
                if let k = asAttrNamespaceNameString,
                   let v = namespaceValueString {
                    attrDict[k] = v
                }
            }
        }
    }
    
    if reportNamespaces {
        parser._pushNamespaces(nsDict)
    }
    
    for idx in stride(from: 0, to: Int(nb_attributes) * 5, by: 5) {
        if attributes[idx] == nil {
            continue
        }
        var attributeQName: String
        let attrLocalName = attributes[idx]!
        let attrLocalNameString = UTF8STRING(attrLocalName)!
        let attrPrefix = attributes[idx + 1]
        if let attrPrefixString = UTF8STRING(attrPrefix), !attrPrefixString.isEmpty {
            attributeQName = attrPrefixString + ":" + attrLocalNameString
        } else {
            attributeQName = attrLocalNameString
        }
        // idx+2 = URI, which we throw away
        // idx+3 = value, i+4 = endvalue
        // By using XML_PARSE_NOENT the attribute value string will already have entities resolved
        var attributeValue = ""
        if let value = attributes[idx + 3], let endvalue = attributes[idx + 4] {
            let numBytesWithoutTerminator = endvalue - value
            if numBytesWithoutTerminator > 0 {
                let buffer = UnsafeBufferPointer(start: value,
                                                 count: numBytesWithoutTerminator)
                attributeValue = String(decoding: buffer, as: UTF8.self)
            }
            attrDict[attributeQName] = attributeValue
        }
    }

    var elementName: String = UTF8STRING(localname)!
    var namespaceURI: String? = nil
    var qualifiedName: String? = nil
    if parser.shouldProcessNamespaces {
        namespaceURI = UTF8STRING(URI) ?? ""
        if let prefix = UTF8STRING(prefix) {
            qualifiedName = prefix + ":" + elementName
        } else {
            qualifiedName = elementName
        }
    }
    else if let prefix = UTF8STRING(prefix) {
        elementName = prefix + ":" + elementName
    }

    parser.delegate?.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qualifiedName, attributes: attrDict)
}

internal func _NSXMLParserEndElementNs(_ ctx: _CFXMLInterface , localname: UnsafePointer<UInt8>, prefix: UnsafePointer<UInt8>?, URI: UnsafePointer<UInt8>?) -> Void {
    let parser = ctx.parser

    var elementName: String = UTF8STRING(localname)!
    var namespaceURI: String? = nil
    var qualifiedName: String? = nil
    if parser.shouldProcessNamespaces {
        namespaceURI = UTF8STRING(URI) ?? ""
        if let prefix = UTF8STRING(prefix) {
            qualifiedName = prefix + ":" + elementName
        } else {
            qualifiedName = elementName
        }
    }
    else if let prefix = UTF8STRING(prefix) {
        elementName = prefix + ":" + elementName
    }

    parser.delegate?.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qualifiedName)

    // Pop the last namespaces that were pushed (safe since XML is balanced)
    if parser.shouldReportNamespacePrefixes {
        parser._popNamespaces()
    }
}

internal func _NSXMLParserCharacters(_ ctx: _CFXMLInterface, ch: UnsafePointer<UInt8>, len: Int32) -> Void {
    let parser = ctx.parser
    let context = parser._parserContext!
    if _CFXMLInterfaceInRecursiveState(context) != 0 {
        _CFXMLInterfaceResetRecursiveState(context)
    } else {
        if let delegate = parser.delegate {
            let str = String(decoding: UnsafeBufferPointer(start: ch, count: Int(len)), as: UTF8.self)
            delegate.parser(parser, foundCharacters: str)
        }
    }
}

internal func _NSXMLParserProcessingInstruction(_ ctx: _CFXMLInterface, target: UnsafePointer<UInt8>, data: UnsafePointer<UInt8>) -> Void {
    let parser = ctx.parser
    if let delegate = parser.delegate {
        let targetString = UTF8STRING(target)!
        let dataString = UTF8STRING(data)
        delegate.parser(parser, foundProcessingInstructionWithTarget: targetString, data: dataString)
    }
}

internal func _NSXMLParserCdataBlock(_ ctx: _CFXMLInterface, value: UnsafePointer<UInt8>, len: Int32) -> Void {
    let parser = ctx.parser
    if let delegate = parser.delegate {
        delegate.parser(parser, foundCDATA: Data(bytes: value, count: Int(len)))
    }
}

internal func _NSXMLParserComment(_ ctx: _CFXMLInterface, value: UnsafePointer<UInt8>) -> Void {
    let parser = ctx.parser
    if let delegate = parser.delegate {
        let comment = UTF8STRING(value)!
        delegate.parser(parser, foundComment: comment)
    }
}

internal func _NSXMLParserExternalSubset(_ ctx: _CFXMLInterface, name: UnsafePointer<UInt8>, ExternalID: UnsafePointer<UInt8>, SystemID: UnsafePointer<UInt8>) -> Void {
    _CFXMLInterfaceSAX2ExternalSubset(ctx.parser._parserContext, name, ExternalID, SystemID)
}

internal func _structuredErrorFunc(_ interface: _CFXMLInterface, error: _CFXMLInterfaceError) {
    let cferr = _CFErrorCreateFromXMLInterface(error)
    let err = _CFErrorSPIForFoundationXMLUseOnly(unsafelyAssumingIsCFError: cferr)._nsObject
    let parser = interface.parser
    parser._parserError = err
    if let delegate = parser.delegate {
        delegate.parser(parser, parseErrorOccurred: err)
    }
}

@available(*, unavailable)
extension XMLParser : @unchecked Sendable { }

open class XMLParser : NSObject {
    private var _handler: _CFXMLInterfaceSAXHandler
    internal var _stream: InputStream?
    internal var _data: Data?

    internal var _chunkSize = Int(4096 * 32) // a suitably large number for a decent chunk size
    // This chunk of data stores the head of the stream. We know we have enough information for encoding
    // when there are atleast 4 bytes in here.
    internal var _bomChunk: Data?
    fileprivate var _parserContext: _CFXMLInterfaceParserContext?
    internal var _delegateAborted = false
    internal var _url: URL?
    internal var _namespaces = [[String:String]]()
    
    // initializes the parser with the specified URL.
    public convenience init?(contentsOf url: URL) {
#if os(WASI)
        return nil
#else
        setupXMLParsing()
        if url.isFileURL {
            if let stream = InputStream(url: url) {
                self.init(stream: stream)
                _url = url
            } else {
                return nil
            }
        } else {
            do {
                let data = try Data(contentsOf: url)
                self.init(data: data)
                self._url = url
            } catch {
                return nil
            }
        }
#endif
    }
    
    // create the parser from data
    public init(data: Data) {
        setupXMLParsing()
        _data = data
        _handler = _CFXMLInterfaceCreateSAXHandler()
        _parserContext = nil
    }
    
    deinit {
        _CFXMLInterfaceDestroySAXHandler(_handler)
        _CFXMLInterfaceDestroyContext(_parserContext)
    }
    
#if !os(WASI)
    //create a parser that incrementally pulls data from the specified stream and parses it.
    public init(stream: InputStream) {
        setupXMLParsing()
        _stream = stream
        _handler = _CFXMLInterfaceCreateSAXHandler()
        _parserContext = nil
    }
#endif
    
    open weak var delegate: XMLParserDelegate?
    
    open var shouldProcessNamespaces: Bool = false
    open var shouldReportNamespacePrefixes: Bool = false
    
    //defaults to XMLNode.ExternalEntityResolvingPolicy.never
    open var externalEntityResolvingPolicy: ExternalEntityResolvingPolicy = .never
    
    open var allowedExternalEntityURLs: Set<URL>?

    /// The current parser is stored in a task local variable to allow for
    /// concurrent parsing in different tasks with different parsers.
    ///
    /// Rationale for `@unchecked Sendable`:
    /// While the ``XMLParser`` class itself is not `Sendable`, `TaskLocal`
    /// requires the value type to be `Sendable`. The sendability requirement
    /// of `TaskLocal` is only for the "default" value and values set with
    /// `withValue` will not be shared between tasks.
    /// So as long as 1. the default value is safe to be shared between tasks
    /// and 2. the `Sendable` conformance of `_CurrentParser` is not used
    /// outside of `TaskLocal`, it is safe to mark it as `@unchecked Sendable`.
    private struct _CurrentParser: @unchecked Sendable {
        let parser: XMLParser?

        static var `default`: _CurrentParser {
            return _CurrentParser(parser: nil)
        }
    }

    @TaskLocal
    private static var _currentParser: _CurrentParser = .default

    internal static func currentParser() -> XMLParser? {
        return _currentParser.parser
    }
    
    internal static func withCurrentParser<R>(_ parser: XMLParser, _ body: () -> R) -> R {
        return self.$_currentParser.withValue(_CurrentParser(parser: parser), operation: body)
    }
    
    internal func _handleParseResult(_ parseResult: Int32) -> Bool {
        if parseResult == 0 {
            return true
        } else {
            if _parserError == nil {
                _parserError = NSError(domain: XMLParser.errorDomain, code: Int(parseResult))
            }
        }
        return false
    }

    internal func parseData(_ data: Data, lastChunkOfData: Bool = false) -> Bool {
        _CFXMLInterfaceSetStructuredErrorFunc(interface, _structuredErrorFunc)
        defer { _CFXMLInterfaceSetStructuredErrorFunc(interface, nil) }

        let handler: _CFXMLInterfaceSAXHandler? = (delegate != nil ? _handler : nil)
        let unparsedData: Data
        // If the parser context is nil, we have not received enough bytes to create the push parser
        if _parserContext == nil {
            // Look at the bomChunk and this data
            let bomChunk: Data = {
                guard var bomChunk = _bomChunk else {
                    return data
                }
                bomChunk.append(data)
                return bomChunk
            }()
            // If we have not received 4 bytes, save the bomChunk for next pass
            if bomChunk.count < 4 {
                _bomChunk = bomChunk
                return true
            }
            // Prepare options (substitute entities, recover on errors)
            var options = _kCFXMLInterfaceRecover | _kCFXMLInterfaceNoEnt
            if shouldResolveExternalEntities {
                options |= _kCFXMLInterfaceDTDLoad
            }
            if handler == nil {
                options |= (_kCFXMLInterfaceNoError | _kCFXMLInterfaceNoWarning)
            }

            // Create the push context with the first 4 bytes
            bomChunk.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
                let bytes = rawBuffer.baseAddress!.assumingMemoryBound(to: CChar.self)
                _parserContext = _CFXMLInterfaceCreatePushParserCtxt(handler, interface, bytes, 4, nil)
            }
            guard _parserContext != nil else {
                if _parserError == nil {
                    _parserError = NSError(domain: XMLParser.errorDomain, code: ErrorCode.outOfMemoryError.rawValue)
                }
                return false
            };
            _CFXMLInterfaceCtxtUseOptions(_parserContext, options)
            // Prepare the remaining data for parsing
            let dataRange = bomChunk.indices
            let unparsed = Range(uncheckedBounds: (dataRange.startIndex.advanced(by: 4), dataRange.endIndex))
            unparsedData = bomChunk.subdata(in: unparsed)
        }
        else {
            unparsedData = data
        }

        let parseResult = unparsedData.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Int32 in
            let bytes = rawBuffer.baseAddress!.assumingMemoryBound(to: CChar.self)
            return _CFXMLInterfaceParseChunk(_parserContext, bytes, Int32(unparsedData.count), lastChunkOfData ? 1 : 0)
        }

        let result = _handleParseResult(parseResult)
        return result
    }

    internal func parseFrom(_ stream : InputStream) -> Bool {
        var result = true

        guard let buffer = malloc(_chunkSize)?.bindMemory(to: UInt8.self, capacity: _chunkSize) else { return false }
        defer { free(buffer) }

        stream.open()
        defer { stream.close() }
        parseLoop: while result {
            switch stream.read(buffer, maxLength: _chunkSize) {
            case let len where len > 0:
                let data = Data(bytesNoCopy: buffer, count: len, deallocator: .none)
                result = parseData(data)
            case 0:
                result = parseData(Data(), lastChunkOfData: true)
                break parseLoop
            default: // See SR-13516, should be `case ..<0:`
                result = false
                if _parserError == nil {
                    _parserError = stream.streamError
                }

                break parseLoop
            }
        }

        return result
    }

    // called to start the event-driven parse. Returns YES in the event of a successful parse, and NO in case of error.
    open func parse() -> Bool {
        return Self.withCurrentParser(self) {
            if _stream != nil {
                return parseFrom(_stream!)
            } else if _data != nil {
                return parseData(_data!, lastChunkOfData: true)
            }
            return false
        }
    }
    
    // called by the delegate to stop the parse. The delegate will get an error message sent to it.
    open func abortParsing() {
        if let context = _parserContext {
            _CFXMLInterfaceStopParser(context)
            _delegateAborted = true
        }
    }
    
    internal var _parserError: Error?

    // can be called after a parse is over to determine parser state.
    open var parserError: Error? {
        return _parserError
    }
    
    //Toggles between disabling external entities entirely, and the current setting of the 'externalEntityResolvingPolicy'.
    //The 'externalEntityResolvingPolicy' property should be used instead of this, unless targeting 10.9/7.0 or earlier
    open var shouldResolveExternalEntities: Bool = false
    
    // Once a parse has begun, the delegate may be interested in certain parser state. These methods will only return meaningful information during parsing, or after an error has occurred.
    open var publicID: String? {
        return nil
    }
    
    open var systemID: String? {
        return nil
    }
    
    open var lineNumber: Int {
        return Int(_CFXMLInterfaceSAX2GetLineNumber(_parserContext))
    }
    
    open var columnNumber: Int {
        return Int(_CFXMLInterfaceSAX2GetColumnNumber(_parserContext))
    }
    
    internal func _pushNamespaces(_ ns: [String:String]) {
        _namespaces.append(ns)
        if let del = self.delegate {
            ns.forEach {
                del.parser(self, didStartMappingPrefix: $0.0, toURI: $0.1)
            }
        }
    }
    
    internal func _popNamespaces() {
        let ns = _namespaces.removeLast()
        if let del = self.delegate {
            ns.forEach {
                del.parser(self, didEndMappingPrefix: $0.0)
            }
        }
    }
}

/*
 
 For the discussion of event methods, assume the following XML:
 
 <?xml version="1.0" encoding="UTF-8"?>
 <?xml-stylesheet type='text/css' href='cvslog.css'?>
 <!DOCTYPE cvslog SYSTEM "cvslog.dtd">
 <cvslog xmlns="http://xml.apple.com/cvslog">
 <radar:radar xmlns:radar="http://xml.apple.com/radar">
 <radar:bugID>2920186</radar:bugID>
 <radar:title>API/NSXMLParser: there ought to be an NSXMLParser</radar:title>
 </radar:radar>
 </cvslog>
 
 */

// The parser's delegate is informed of events through the methods in the NSXMLParserDelegateEventAdditions category.
public protocol XMLParserDelegate: AnyObject {
    
    // Document handling methods
    func parserDidStartDocument(_ parser: XMLParser)
    // sent when the parser begins parsing of the document.
    func parserDidEndDocument(_ parser: XMLParser)
    // sent when the parser has completed parsing. If this is encountered, the parse was successful.
    
    // DTD handling methods for various declarations.
    func parser(_ parser: XMLParser, foundNotationDeclarationWithName name: String, publicID: String?, systemID: String?)
    
    func parser(_ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?, systemID: String?, notationName: String?)
    
    func parser(_ parser: XMLParser, foundAttributeDeclarationWithName attributeName: String, forElement elementName: String, type: String?, defaultValue: String?)
    
    func parser(_ parser: XMLParser, foundElementDeclarationWithName elementName: String, model: String)
    
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?)
    
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?)
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String])
    // sent when the parser finds an element start tag.
    // In the case of the cvslog tag, the following is what the delegate receives:
    //   elementName == cvslog, namespaceURI == http://xml.apple.com/cvslog, qualifiedName == cvslog
    // In the case of the radar tag, the following is what's passed in:
    //    elementName == radar, namespaceURI == http://xml.apple.com/radar, qualifiedName == radar:radar
    // If namespace processing >isn't< on, the xmlns:radar="http://xml.apple.com/radar" is returned as an attribute pair, the elementName is 'radar:radar' and there is no qualifiedName.
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
    // sent when an end tag is encountered. The various parameters are supplied as above.
    
    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String)
    // sent when the parser first sees a namespace attribute.
    // In the case of the cvslog tag, before the didStartElement:, you'd get one of these with prefix == @"" and namespaceURI == @"http://xml.apple.com/cvslog" (i.e. the default namespace)
    // In the case of the radar:radar tag, before the didStartElement: you'd get one of these with prefix == @"radar" and namespaceURI == @"http://xml.apple.com/radar"
    
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String)
    // sent when the namespace prefix in question goes out of scope.
    
    func parser(_ parser: XMLParser, foundCharacters string: String)
    // This returns the string of the characters encountered thus far. You may not necessarily get the longest character run. The parser reserves the right to hand these to the delegate as potentially many calls in a row to -parser:foundCharacters:
    
    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String)
    // The parser reports ignorable whitespace in the same way as characters it's found.
    
    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?)
    // The parser reports a processing instruction to you using this method. In the case above, target == @"xml-stylesheet" and data == @"type='text/css' href='cvslog.css'"
    
    func parser(_ parser: XMLParser, foundComment comment: String)
    // A comment (Text in a <!-- --> block) is reported to the delegate as a single string
    
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data)
    // this reports a CDATA block to the delegate as an NSData.
    
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data?
    // this gives the delegate an opportunity to resolve an external entity itself and reply with the resulting data.
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error)
    // ...and this reports a fatal error to the delegate. The parser will stop parsing.
    
    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error)
}

public extension XMLParserDelegate {
    
    func parserDidStartDocument(_ parser: XMLParser) { }
    func parserDidEndDocument(_ parser: XMLParser) { }
    
    func parser(_ parser: XMLParser, foundNotationDeclarationWithName name: String, publicID: String?, systemID: String?) { }
    
    func parser(_ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?, systemID: String?, notationName: String?) { }
    
    func parser(_ parser: XMLParser, foundAttributeDeclarationWithName attributeName: String, forElement elementName: String, type: String?, defaultValue: String?) { }
    
    func parser(_ parser: XMLParser, foundElementDeclarationWithName elementName: String, model: String) { }
    
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) { }
    
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) { }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) { }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { }
    
    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) { }
    
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) { }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) { }
    
    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) { }
    
    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) { }
    
    func parser(_ parser: XMLParser, foundComment comment: String) { }
    
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { }
    
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? { return nil }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) { }
    
    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) { }
}

extension XMLParser {
    // If validation is on, this will report a fatal validation error to the delegate. The parser will stop parsing.
    public static let errorDomain: String = "NSXMLParserErrorDomain" // for use with NSError.

    // Error reporting
    public enum ErrorCode : Int, Sendable {
        
        
        case internalError
        
        case outOfMemoryError
        
        case documentStartError
        
        case emptyDocumentError
        
        case prematureDocumentEndError
        
        case invalidHexCharacterRefError
        
        case invalidDecimalCharacterRefError
        
        case invalidCharacterRefError
        
        case invalidCharacterError
        
        case characterRefAtEOFError
        
        case characterRefInPrologError
        
        case characterRefInEpilogError
        
        case characterRefInDTDError
        
        case entityRefAtEOFError
        
        case entityRefInPrologError
        
        case entityRefInEpilogError
        
        case entityRefInDTDError
        
        case parsedEntityRefAtEOFError
        
        case parsedEntityRefInPrologError
        
        case parsedEntityRefInEpilogError
        
        case parsedEntityRefInInternalSubsetError
        
        case entityReferenceWithoutNameError
        
        case entityReferenceMissingSemiError
        
        case parsedEntityRefNoNameError
        
        case parsedEntityRefMissingSemiError
        
        case undeclaredEntityError
        
        case unparsedEntityError
        
        case entityIsExternalError
        
        case entityIsParameterError
        
        case unknownEncodingError
        
        case encodingNotSupportedError
        
        case stringNotStartedError
        
        case stringNotClosedError
        
        case namespaceDeclarationError
        
        case entityNotStartedError
        
        case entityNotFinishedError
        
        case lessThanSymbolInAttributeError
        
        case attributeNotStartedError
        
        case attributeNotFinishedError
        
        case attributeHasNoValueError
        
        case attributeRedefinedError
        
        case literalNotStartedError
        
        case literalNotFinishedError
        
        case commentNotFinishedError
        
        case processingInstructionNotStartedError
        
        case processingInstructionNotFinishedError
        
        case notationNotStartedError
        
        case notationNotFinishedError
        
        case attributeListNotStartedError
        
        case attributeListNotFinishedError
        
        case mixedContentDeclNotStartedError
        
        case mixedContentDeclNotFinishedError
        
        case elementContentDeclNotStartedError
        
        case elementContentDeclNotFinishedError
        
        case xmlDeclNotStartedError
        
        case xmlDeclNotFinishedError
        
        case conditionalSectionNotStartedError
        
        case conditionalSectionNotFinishedError
        
        case externalSubsetNotFinishedError
        
        case doctypeDeclNotFinishedError
        
        case misplacedCDATAEndStringError
        
        case cdataNotFinishedError
        
        case misplacedXMLDeclarationError
        
        case spaceRequiredError
        
        case separatorRequiredError
        
        case nmtokenRequiredError
        
        case nameRequiredError
        
        case pcdataRequiredError
        
        case uriRequiredError
        
        case publicIdentifierRequiredError
        
        case ltRequiredError
        
        case gtRequiredError
        
        case ltSlashRequiredError
        
        case equalExpectedError
        
        case tagNameMismatchError
        
        case unfinishedTagError
        
        case standaloneValueError
        
        case invalidEncodingNameError
        
        case commentContainsDoubleHyphenError
        
        case invalidEncodingError
        
        case externalStandaloneEntityError
        
        case invalidConditionalSectionError
        
        case entityValueRequiredError
        
        case notWellBalancedError
        
        case extraContentError
        
        case invalidCharacterInEntityError
        
        case parsedEntityRefInInternalError
        
        case entityRefLoopError
        
        case entityBoundaryError
        
        case invalidURIError
        
        case uriFragmentError
        
        case noDTDError
        
        case delegateAbortedParseError
    }
}

internal func NSUnimplemented(_ fn: String = #function, file: StaticString = #file, line: UInt = #line) -> Never {
    #if os(Android)
    NSLog("\(fn) is not yet implemented. \(file):\(line)")
    #endif
    fatalError("\(fn) is not yet implemented", file: file, line: line)
}

internal func NSUnsupported(_ fn: String = #function, file: StaticString = #file, line: UInt = #line) -> Never {
    #if os(Android)
    NSLog("\(fn) is not supported on this platform. \(file):\(line)")
    #endif
    fatalError("\(fn) is not supported on this platform", file: file, line: line)
}

extension NSObject {
    func withUnretainedReference<T, R>(_ work: (UnsafePointer<T>) -> R) -> R {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque().assumingMemoryBound(to: T.self)
        return work(selfPtr)
    }
    
    func withOpaqueUnretainedReference<R>(_ work: (UnsafeMutableRawPointer) -> R) -> R {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        return work(selfPtr)
    }
}

func setupXMLParsing() {
    _CFSetupXMLInterface()
    _CFSetupXMLBridgeIfNeededUsingBlock {
        __CFSwiftXMLParserBridge.CFBridge = CF.originalBridge
        __CFSwiftXMLParserBridge.currentParser = _NSXMLParserCurrentParser
        __CFSwiftXMLParserBridge._xmlExternalEntityWithURL = _NSXMLParserExternalEntityWithURL
        __CFSwiftXMLParserBridge.getContext = _NSXMLParserGetContext
        __CFSwiftXMLParserBridge.internalSubset = _NSXMLParserInternalSubset
        __CFSwiftXMLParserBridge.isStandalone = _NSXMLParserIsStandalone
        __CFSwiftXMLParserBridge.hasInternalSubset = _NSXMLParserHasInternalSubset
        __CFSwiftXMLParserBridge.hasExternalSubset = _NSXMLParserHasExternalSubset
        __CFSwiftXMLParserBridge.getEntity = _NSXMLParserGetEntity
        __CFSwiftXMLParserBridge.notationDecl = _NSXMLParserNotationDecl
        __CFSwiftXMLParserBridge.attributeDecl = _NSXMLParserAttributeDecl
        __CFSwiftXMLParserBridge.elementDecl = _NSXMLParserElementDecl
        __CFSwiftXMLParserBridge.unparsedEntityDecl = _NSXMLParserUnparsedEntityDecl
        __CFSwiftXMLParserBridge.startDocument = _NSXMLParserStartDocument
        __CFSwiftXMLParserBridge.endDocument = _NSXMLParserEndDocument
        __CFSwiftXMLParserBridge.startElementNs = _NSXMLParserStartElementNs
        __CFSwiftXMLParserBridge.endElementNs = _NSXMLParserEndElementNs
        __CFSwiftXMLParserBridge.characters = _NSXMLParserCharacters
        __CFSwiftXMLParserBridge.processingInstruction = _NSXMLParserProcessingInstruction
        __CFSwiftXMLParserBridge.cdataBlock = _NSXMLParserCdataBlock
        __CFSwiftXMLParserBridge.comment = _NSXMLParserComment
        __CFSwiftXMLParserBridge.externalSubset = _NSXMLParserExternalSubset
    }
}
