//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#elseif canImport(Android)
import Android
#endif

@_implementationOnly import CoreFoundation

public typealias NSErrorDomain = NSString

/// Predefined domain for errors from most Foundation APIs.
public let NSCocoaErrorDomain: String = "NSCocoaErrorDomain"

// Other predefined domains; value of "code" will correspond to preexisting values in these domains.
public let NSPOSIXErrorDomain: String = "NSPOSIXErrorDomain"
public let NSOSStatusErrorDomain: String = "NSOSStatusErrorDomain"
public let NSMachErrorDomain: String = "NSMachErrorDomain"

// Key in userInfo. A recommended standard way to embed NSErrors from underlying calls. The value of this key should be an NSError.
public let NSUnderlyingErrorKey: String = "NSUnderlyingError"

// Keys in userInfo, for subsystems wishing to provide their error messages up-front. Note that NSError will also consult the userInfoValueProvider for the domain when these values are not present in the userInfo dictionary.
public let NSLocalizedDescriptionKey: String = "NSLocalizedDescription"
public let NSLocalizedFailureReasonErrorKey: String = "NSLocalizedFailureReason"
public let NSLocalizedRecoverySuggestionErrorKey: String = "NSLocalizedRecoverySuggestion"
public let NSLocalizedRecoveryOptionsErrorKey: String = "NSLocalizedRecoveryOptions"
public let NSRecoveryAttempterErrorKey: String = "NSRecoveryAttempter"
public let NSHelpAnchorErrorKey: String = "NSHelpAnchor"
public let NSDebugDescriptionErrorKey = "NSDebugDescription"

// Other standard keys in userInfo, for various error codes
public let NSStringEncodingErrorKey: String = "NSStringEncodingErrorKey"
public let NSURLErrorKey: String = "NSURL"
public let NSFilePathErrorKey: String = "NSFilePath"

open class NSError : NSObject, NSCopying, NSSecureCoding, NSCoding {
    typealias CFType = CFError
    
    internal final var _cfObject: CFType {
        return CFErrorCreate(kCFAllocatorSystemDefault, domain._cfObject, code, nil)
    }
    
    // ErrorType forbids this being internal
    open var _domain: String
    open var _code: Int
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation
    /// - Note: This API differs from Darwin because it uses [String : Any] as a type instead of [String : AnyObject]. This allows the use of Swift value types.
    private var _userInfo: [String : Any]?
    
    /// - Experiment: This is a draft API currently under consideration for official import into Foundation
    /// - Note: This API differs from Darwin because it uses [String : Any] as a type instead of [String : AnyObject]. This allows the use of Swift value types.
    public init(domain: String, code: Int, userInfo dict: [String : Any]? = nil) {
        _domain = domain
        _code = code
        _userInfo = dict
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard aDecoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        _code = aDecoder.decodeInteger(forKey: "NSCode")
        _domain = aDecoder.decodeObject(of: NSString.self, forKey: "NSDomain")!._swiftObject
        if let info = aDecoder.decodeObject(of: [NSSet.self, NSDictionary.self, NSArray.self, NSString.self, NSNumber.self, NSData.self, NSURL.self], forKey: "NSUserInfo") as? NSDictionary {
            var filteredUserInfo = [String : Any]()
            // user info must be filtered so that the keys are all strings
            info.enumerateKeysAndObjects({ (key, value, _) in
                if let key = key as? NSString {
                    filteredUserInfo[key._swiftObject] = value
                }
            })
            _userInfo = filteredUserInfo
        }
    }
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    open func encode(with aCoder: NSCoder) {
        guard aCoder.allowsKeyedCoding else {
            preconditionFailure("Unkeyed coding is unsupported.")
        }
        aCoder.encode(_domain._bridgeToObjectiveC(), forKey: "NSDomain")
        aCoder.encode(Int32(_code), forKey: "NSCode")
        aCoder.encode(_userInfo?._bridgeToObjectiveC(), forKey: "NSUserInfo")
    }
    
    open override func copy() -> Any {
        return copy(with: nil)
    }
    
    open func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
    
    open var domain: String {
        return _domain
    }
    
    open var code: Int {
        return _code
    }

    /// - Experiment: This is a draft API currently under consideration for official import into Foundation
    /// - Note: This API differs from Darwin because it uses [String : Any] as a type instead of [String : AnyObject]. This allows the use of Swift value types.
    open var userInfo: [String : Any] {
        if let info = _userInfo {
            return info
        } else {
            return Dictionary<String, Any>()
        }
    }
    
    open var localizedDescription: String {
        if let localizedDescription = userInfo[NSLocalizedDescriptionKey] as? String {
            return localizedDescription
        } else {
            // placeholder values
            return "The operation could not be completed." + " " + (self.localizedFailureReason ?? "(\(domain) error \(code).)")
        }
    }
    
    open var localizedFailureReason: String? {
        
        if let localizedFailureReason = userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            return localizedFailureReason
        } else {
            switch domain {
            case NSPOSIXErrorDomain:
                return String(cString: strerror(Int32(code)), encoding: .ascii)
            case NSCocoaErrorDomain:
                return CocoaError.errorMessages[CocoaError.Code(rawValue: code)]
            case NSURLErrorDomain:
                return nil
            default:
                return nil
            }
        }
    }
    
    open var localizedRecoverySuggestion: String? {
        return userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String
    }

    open var localizedRecoveryOptions: [String]? {
        return userInfo[NSLocalizedRecoveryOptionsErrorKey] as? [String]
    }
    
    open var recoveryAttempter: Any? {
        return userInfo[NSRecoveryAttempterErrorKey]
    }
    
    open var helpAnchor: String? {
        return userInfo[NSHelpAnchorErrorKey] as? String
    }
    
    internal typealias UserInfoProvider = (_ error: Error, _ key: String) -> Any?
    internal static var userInfoProviders = [String: UserInfoProvider]()
    
    open class func setUserInfoValueProvider(forDomain errorDomain: String, provider: (/* @escaping */ (Error, String) -> Any?)?) {
        NSError.userInfoProviders[errorDomain] = provider
    }

    open class func userInfoValueProvider(forDomain errorDomain: String) -> ((Error, String) -> Any?)? {
        return NSError.userInfoProviders[errorDomain]
    }
    
    override open var description: String {
        return "Error Domain=\(domain) Code=\(code) \"\(localizedFailureReason ?? "(null)")\""
    }
    
    // -- NSObject Overrides --
    // The compiler has special paths for attempting to do some bridging on NSError (and equivalent Error instances) -- in particular, in the lookup of NSError objects' superclass.
    // On platforms where we don't have bridging (i.e. Linux), this causes a silgen failure. We can avoid the issue by overriding methods inherited by NSObject ourselves.
    override open var hash: Int {
        // CFHash does the appropriate casting/bridging on platforms where we support it.
        return Int(bitPattern: CFHash(self))
    }
    
    override open func isEqual(_ object: Any?) -> Bool {
        // Pulled from NSObject itself; this works on all platforms.
        guard let obj = object as? NSError else { return false }
        guard obj.domain == self.domain && obj.code == self.code else { return false }
        
        // NSDictionaries are comparable, and that's the actual equality ObjC Foundation cares about.
        return (self.userInfo as NSDictionary) == (obj.userInfo as NSDictionary)
    }
}

extension NSError : Swift.Error { }

extension CFError : _NSBridgeable {
    typealias NSType = NSError
    internal var _nsObject: NSType {
        let userInfo = CFErrorCopyUserInfo(self)._swiftObject
        var newUserInfo: [String: Any] = [:]
        for (key, value) in userInfo {
            if let key = key as? String {
                newUserInfo[key] = value
            }
        }

        return NSError(domain: CFErrorGetDomain(self)._swiftObject, code: CFErrorGetCode(self), userInfo: newUserInfo)
    }
}

public struct _CFErrorSPIForFoundationXMLUseOnly {
    let error: AnyObject
    public init(unsafelyAssumingIsCFError error: AnyObject) {
        self.error = error
    }
    
    public var _nsObject: NSError {
        return unsafeBitCast(error, to: CFError.self)._nsObject
    }
}

/// Class that implements the informal protocol
/// NSErrorRecoveryAttempting, which is used by NSError when it
/// attempts recovery from an error.
class _NSErrorRecoveryAttempter {
    func attemptRecovery(fromError error: Error,
        optionIndex recoveryOptionIndex: Int) -> Bool {
        let error = error as! RecoverableError
        return error.attemptRecovery(optionIndex: recoveryOptionIndex)
  }
}

/// Describes an error that may be recoverable by presenting several
/// potential recovery options to the user.
public protocol RecoverableError : Error {
    /// Provides a set of possible recovery options to present to the user.
    var recoveryOptions: [String] { get }

    /// Attempt to recover from this error when the user selected the
    /// option at the given index. This routine must call handler and
    /// indicate whether recovery was successful (or not).
    ///
    /// This entry point is used for recovery of errors handled at a
    /// "document" granularity, that do not affect the entire
    /// application.
    func attemptRecovery(optionIndex recoveryOptionIndex: Int, resultHandler handler: @escaping (_ recovered: Bool) -> Void)

    /// Attempt to recover from this error when the user selected the
    /// option at the given index. Returns true to indicate
    /// successful recovery, and false otherwise.
    ///
    /// This entry point is used for recovery of errors handled at
    /// the "application" granularity, where nothing else in the
    /// application can proceed until the attempted error recovery
    /// completes.
    func attemptRecovery(optionIndex recoveryOptionIndex: Int) -> Bool
}

public extension RecoverableError {
    /// Default implementation that uses the application-model recovery
    /// mechanism (``attemptRecovery(optionIndex:)``) to implement
    /// document-modal recovery.
    func attemptRecovery(optionIndex recoveryOptionIndex: Int, resultHandler handler: @escaping (_ recovered: Bool) -> Void) {
        handler(attemptRecovery(optionIndex: recoveryOptionIndex))
    }
}

/// Describes an error type that specifically provides a domain, code,
/// and user-info dictionary.
public protocol CustomNSError : Error {
    /// The domain of the error.
    static var errorDomain: String { get }

    /// The error code within the given domain.
    var errorCode: Int { get }

    /// The user-info dictionary.
    var errorUserInfo: [String : Any] { get }
}

public extension CustomNSError {
    /// Default domain of the error.
    static var errorDomain: String {
        return String(reflecting: self)
    }

    /// The error code within the given domain.
    var errorCode: Int {
        return _getDefaultErrorCode(self)
    }

    /// The default user-info dictionary.
    var errorUserInfo: [String : Any] {
        return [:]
    }
}

/// Convert an arbitrary fixed-width integer to an Int, reinterpreting
/// signed -> unsigned if needed but trapping if the result is otherwise
/// not expressible.
func unsafeFixedWidthIntegerToInt<T: FixedWidthInteger>(_ value: T) -> Int {
    if T.isSigned {
        return numericCast(value)
    }

    let uintValue: UInt = numericCast(value)
    return Int(bitPattern: uintValue)
}

/// Convert from an Int to an arbitrary fixed-width integer, reinterpreting
/// signed -> unsigned if needed but trapping if the result is otherwise not
/// expressible.
func unsafeFixedWidthIntegerFromInt<T: FixedWidthInteger>(_ value: Int) -> T {
    if T.isSigned {
        return numericCast(value)
    }

    let uintValue = UInt(bitPattern: value)
    return numericCast(uintValue)
}

extension CustomNSError where Self: RawRepresentable, Self.RawValue: FixedWidthInteger {
    // The error code of Error with integral raw values is the raw value.
    public var errorCode: Int {
        return unsafeFixedWidthIntegerToInt(self.rawValue)
    }
}

public extension Error where Self : CustomNSError {
    /// Default implementation for customized NSErrors.
    var _domain: String { return Self.errorDomain }

    /// Default implementation for customized NSErrors.
    var _code: Int { return self.errorCode }
}

public extension Error where Self: CustomNSError, Self: RawRepresentable, Self.RawValue: FixedWidthInteger {
    /// Default implementation for customized NSErrors.
    var _code: Int { return self.errorCode }
}

public extension Error {
    /// Retrieve the localized description for this error.
    var localizedDescription: String {
        if let nsError = self as? NSError {
            return nsError.localizedDescription
        }

        let defaultUserInfo = _swift_Foundation_getErrorDefaultUserInfo(self) as? [String : Any]
        return NSError(domain: _domain, code: _code, userInfo: defaultUserInfo).localizedDescription
    }
}

/// Retrieve the default userInfo dictionary for a given error.
public func _swift_Foundation_getErrorDefaultUserInfo(_ error: Error) -> Any? {
    // TODO: Implement info value providers and return the code that was deleted here.
    let hasUserInfoValueProvider = false

    // Populate the user-info dictionary
    var result: [String : Any]

    // Initialize with custom user-info.
    if let customNSError = error as? CustomNSError {
        result = customNSError.errorUserInfo
    } else {
        result = [:]
    }

    // Handle localized errors. If we registered a user-info value
    // provider, these will computed lazily.
    if !hasUserInfoValueProvider,
    let localizedError = error as? LocalizedError {
        if let description = localizedError.errorDescription {
            result[NSLocalizedDescriptionKey] = description
        }

        if let reason = localizedError.failureReason {
            result[NSLocalizedFailureReasonErrorKey] = reason
        }

        if let suggestion = localizedError.recoverySuggestion {
            result[NSLocalizedRecoverySuggestionErrorKey] = suggestion
        }

        if let helpAnchor = localizedError.helpAnchor {
            result[NSHelpAnchorErrorKey] = helpAnchor
        }
    }

    // Handle recoverable errors. If we registered a user-info value
    // provider, these will computed lazily.
    if !hasUserInfoValueProvider,
    let recoverableError = error as? RecoverableError {
        result[NSLocalizedRecoveryOptionsErrorKey] =
        recoverableError.recoveryOptions
        result[NSRecoveryAttempterErrorKey] = _NSErrorRecoveryAttempter()
    }

    return result
}

// NSError and CFError conform to the standard Error protocol. Compiler
// magic allows this to be done as a "toll-free" conversion when an NSError
// or CFError is used as an Error existential.
extension CFError {
    var _domain: String {
        return CFErrorGetDomain(self)._swiftObject
    }

    var _code: Int {
        return CFErrorGetCode(self)
    }

    var _userInfo: AnyObject? {
        return CFErrorCopyUserInfo(self) as AnyObject
    }
}

/// An internal protocol to represent Swift error enums that map to standard
/// Cocoa NSError domains.
public protocol _ObjectiveCBridgeableError : Error {
    /// Produce a value of the error type corresponding to the given NSError,
    /// or return nil if it cannot be bridged.
    init?(_bridgedNSError: NSError)
}

/// Helper protocol for _BridgedNSError, which used to provide
/// default implementations.
public protocol __BridgedNSError : Error {
    static var _nsErrorDomain: String { get }
}

// Allow two bridged NSError types to be compared.
extension __BridgedNSError where Self: RawRepresentable, Self.RawValue: FixedWidthInteger {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

extension __BridgedNSError where Self: RawRepresentable, Self.RawValue: FixedWidthInteger {
    public var _domain: String { return Self._nsErrorDomain }
    public var _code: Int {
        return Int(rawValue)
    }
    
    public init?(rawValue: RawValue) {
        self = unsafeBitCast(rawValue, to: Self.self)
    }
    
    public init?(_bridgedNSError: NSError) {
        if _bridgedNSError.domain != Self._nsErrorDomain {
            return nil
        }
        
        self.init(rawValue: RawValue(Int(_bridgedNSError.code)))
    }
    
    public var hashValue: Int { return _code }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

/// Describes a raw representable type that is bridged to a particular
/// NSError domain.
///
/// This protocol is used primarily to generate the conformance to
/// _ObjectiveCBridgeableError for such an enum.
public protocol _BridgedNSError : __BridgedNSError, RawRepresentable, _ObjectiveCBridgeableError, Hashable {
    /// The NSError domain to which this type is bridged.
    static var _nsErrorDomain: String { get }
}

/// Describes a bridged error that stores the underlying NSError, so
/// it can be queried.
public protocol _BridgedStoredNSError : __BridgedNSError, _ObjectiveCBridgeableError, CustomNSError, Hashable, CustomStringConvertible {
    /// The type of an error code.
    associatedtype Code: _ErrorCodeProtocol

    /// The error code for the given error.
    var code: Code { get }

    //// Retrieves the embedded NSError.
    var _nsError: NSError { get }

    /// Create a new instance of the error type with the given embedded
    /// NSError.
    ///
    /// The \c error must have the appropriate domain for this error
    /// type.
    init(_nsError error: NSError)
}

public extension _BridgedStoredNSError {
    var description: String {
        return _nsError.description
    }
}

/// Various helper implementations for _BridgedStoredNSError
extension _BridgedStoredNSError where Code: RawRepresentable, Code.RawValue: FixedWidthInteger {
    public var code: Code {
        return Code(rawValue: unsafeFixedWidthIntegerFromInt(_nsError.code))!
    }

    /// Initialize an error within this domain with the given ``code``
    /// and ``userInfo``.
    public init(_ code: Code, userInfo: [String : Any] = [:]) {
        self.init(_nsError: NSError(domain: Self._nsErrorDomain,
            code: unsafeFixedWidthIntegerToInt(code.rawValue),
            userInfo: userInfo))
    }

    /// The user-info dictionary for an error that was bridged from
    /// NSError.
    public var userInfo: [String : Any] { return errorUserInfo }
}

/// Implementation of __BridgedNSError for all _BridgedStoredNSErrors.
extension _BridgedStoredNSError {
    /// Default implementation of ``init(_bridgedNSError)`` to provide
    /// bridging from NSError.
    public init?(_bridgedNSError error: NSError) {
        if error.domain != Self._nsErrorDomain {
            return nil
        }

        self.init(_nsError: error)
    }
}

/// Implementation of CustomNSError for all _BridgedStoredNSErrors.
public extension _BridgedStoredNSError {
    static var errorDomain: String { return _nsErrorDomain }

    var errorCode: Int { return _nsError.code }

    var errorUserInfo: [String : Any] {
        return _nsError.userInfo
    }
}

/// Implementation of Hashable for all _BridgedStoredNSErrors.
public extension _BridgedStoredNSError {
    var hashValue: Int {
        return _nsError.hash
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(_nsError)
    }
}

/// Describes the code of an error.
public protocol _ErrorCodeProtocol : Equatable {
    /// The corresponding error code.
    associatedtype _ErrorType: _BridgedStoredNSError
        where _ErrorType.Code == Self
}

extension _ErrorCodeProtocol {
    /// Allow one to match an error code against an arbitrary error.
    public static func ~=(match: Self, error: Error) -> Bool {
        guard let specificError = error as? Self._ErrorType else { return false }

        return match == specificError.code
    }
}

extension _BridgedStoredNSError {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs._nsError.isEqual(rhs._nsError)
    }
}

extension CocoaError : _BridgedStoredNSError {
    public init(_nsError: NSError) {
        var info = _nsError.userInfo
        info["_NSError"] = _nsError
        self.init(CocoaError.Code(rawValue: _nsError.code), userInfo: info)
    }

    public var _nsError: NSError {
        if let originalNSError = userInfo["_NSError"] as? NSError {
            return originalNSError
        } else {
            return NSError(domain: NSCocoaErrorDomain, code: code.rawValue, userInfo: userInfo)
        }
    }
    
    public static var _nsErrorDomain: String {
        NSCocoaErrorDomain
    }
}

extension CocoaError.Code : _ErrorCodeProtocol {
    public typealias _ErrorType = CocoaError
}

extension CocoaError.Code {
    // These extend the errors available in FoundationEssentials
    public static var xpcConnectionInterrupted:                 CocoaError.Code { return CocoaError.Code(rawValue: 4097) }
    public static var xpcConnectionInvalid:                     CocoaError.Code { return CocoaError.Code(rawValue: 4099) }
    public static var xpcConnectionReplyInvalid:                CocoaError.Code { return CocoaError.Code(rawValue: 4101) }
    public static var ubiquitousFileUnavailable:                CocoaError.Code { return CocoaError.Code(rawValue: 4353) }
    public static var ubiquitousFileNotUploadedDueToQuota:      CocoaError.Code { return CocoaError.Code(rawValue: 4354) }
    public static var ubiquitousFileUbiquityServerNotAvailable: CocoaError.Code { return CocoaError.Code(rawValue: 4355) }
    public static var userActivityHandoffFailed:                CocoaError.Code { return CocoaError.Code(rawValue: 4608) }
    public static var userActivityConnectionUnavailable:        CocoaError.Code { return CocoaError.Code(rawValue: 4609) }
    public static var userActivityRemoteApplicationTimedOut:    CocoaError.Code { return CocoaError.Code(rawValue: 4610) }
    public static var userActivityHandoffUserInfoTooLarge:      CocoaError.Code { return CocoaError.Code(rawValue: 4611) }
    public static var coderReadCorrupt:                         CocoaError.Code { return CocoaError.Code(rawValue: 4864) }
    public static var coderValueNotFound:                       CocoaError.Code { return CocoaError.Code(rawValue: 4865) }
    public static var coderInvalidValue:                        CocoaError.Code { return CocoaError.Code(rawValue: 4866) }
}

internal extension CocoaError {
    static let errorMessages = [
        Code(rawValue: 4): "The file doesn’t exist.",
        Code(rawValue: 255): "The file couldn’t be locked.",
        Code(rawValue: 257): "You don’t have permission.",
        Code(rawValue: 258): "The file name is invalid.",
        Code(rawValue: 259): "The file isn’t in the correct format.",
        Code(rawValue: 260): "The file doesn’t exist.",
        Code(rawValue: 261): "The specified text encoding isn’t applicable.",
        Code(rawValue: 262): "The specified URL type isn’t supported.",
        Code(rawValue: 263): "The item is too large.",
        Code(rawValue: 264): "The text encoding of the contents couldn’t be determined.",
        Code(rawValue: 513): "You don’t have permission.",
        Code(rawValue: 514): "The file name is invalid.",
        Code(rawValue: 516): "A file with the same name already exists.",
        Code(rawValue: 517): "The specified text encoding isn’t applicable.",
        Code(rawValue: 518): "The specified URL type isn’t supported.",
        Code(rawValue: 640): "There isn’t enough space.",
        Code(rawValue: 642): "The volume is read only.",
        Code(rawValue: 1024): "The value is invalid.",
        Code(rawValue: 2048): "The value is invalid.",
        Code(rawValue: 3072): "The operation was cancelled.",
        Code(rawValue: 3328): "The requested operation is not supported.",
        Code(rawValue: 3840): "The data is not in the correct format.",
        Code(rawValue: 3841): "The data is in a format that this application doesn’t understand.",
        Code(rawValue: 3842): "An error occurred in the source of the data.",
        Code(rawValue: 3851): "An error occurred in the destination for the data.",
        Code(rawValue: 3852): "An error occurred in the content of the data.",
        Code(rawValue: 4353): "The file is not available on iCloud yet.",
        Code(rawValue: 4354): "There isn’t enough space in your account.",
        Code(rawValue: 4355): "The iCloud servers might be unreachable or your settings might be incorrect.",
        Code(rawValue: 4864): "The data isn’t in the correct format.",
        Code(rawValue: 4865): "The data is missing.",
        Code(rawValue: 4866): "The data isn’t in the correct format."
    ]
}

public extension CocoaError {
    private var _nsUserInfo: [String: Any] {
        return _nsError.userInfo
    }
}

extension CocoaError {
    public static var xpcConnectionInterrupted:                 CocoaError.Code { return .xpcConnectionInterrupted }
    public static var xpcConnectionInvalid:                     CocoaError.Code { return .xpcConnectionInvalid }
    public static var xpcConnectionReplyInvalid:                CocoaError.Code { return .xpcConnectionReplyInvalid }
    public static var ubiquitousFileUnavailable:                CocoaError.Code { return .ubiquitousFileUnavailable }
    public static var ubiquitousFileNotUploadedDueToQuota:      CocoaError.Code { return .ubiquitousFileNotUploadedDueToQuota }
    public static var ubiquitousFileUbiquityServerNotAvailable: CocoaError.Code { return .ubiquitousFileUbiquityServerNotAvailable }
    public static var userActivityHandoffFailed:                CocoaError.Code { return .userActivityHandoffFailed }
    public static var userActivityConnectionUnavailable:        CocoaError.Code { return .userActivityConnectionUnavailable }
    public static var userActivityRemoteApplicationTimedOut:    CocoaError.Code { return .userActivityRemoteApplicationTimedOut }
    public static var userActivityHandoffUserInfoTooLarge:      CocoaError.Code { return .userActivityHandoffUserInfoTooLarge }
    public static var coderReadCorrupt:                         CocoaError.Code { return .coderReadCorrupt }
    public static var coderValueNotFound:                       CocoaError.Code { return .coderValueNotFound }
    public static var coderInvalidValue:                        CocoaError.Code { return .coderInvalidValue }
}

extension CocoaError {
    public var isUbiquitousFileError: Bool {
        return code.rawValue >= 4352 && code.rawValue <= 4607
    }

    public var isUserActivityError: Bool {
        return code.rawValue >= 4608 && code.rawValue <= 4863
    }

    public var isXPCConnectionError: Bool {
        return code.rawValue >= 4096 && code.rawValue <= 4224
    }
}

extension CocoaError: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSError {
        return self._nsError
    }

    public static func _forceBridgeFromObjectiveC(_ x: NSError, result: inout CocoaError?) {
        result = _unconditionallyBridgeFromObjectiveC(x)
    }

    public static func _conditionallyBridgeFromObjectiveC(_ x: NSError, result: inout CocoaError?) -> Bool {
        result = CocoaError(_nsError: x)
        return true
    }

    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSError?) -> CocoaError {
        var result: CocoaError?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}

/// Describes errors in the URL error domain.
public struct URLError : _BridgedStoredNSError {
    public let _nsError: NSError

    public init(_nsError error: NSError) {
        precondition(error.domain == NSURLErrorDomain)
        self._nsError = error
    }

    public static var _nsErrorDomain: String { return NSURLErrorDomain }

    public enum Code : Int, _ErrorCodeProtocol {
        public typealias _ErrorType = URLError

        case unknown = -1
        case cancelled = -999
        case badURL = -1000
        case timedOut = -1001
        case unsupportedURL = -1002
        case cannotFindHost = -1003
        case cannotConnectToHost = -1004
        case networkConnectionLost = -1005
        case dnsLookupFailed = -1006
        case httpTooManyRedirects = -1007
        case resourceUnavailable = -1008
        case notConnectedToInternet = -1009
        case redirectToNonExistentLocation = -1010
        case badServerResponse = -1011
        case userCancelledAuthentication = -1012
        case userAuthenticationRequired = -1013
        case zeroByteResource = -1014
        case cannotDecodeRawData = -1015
        case cannotDecodeContentData = -1016
        case cannotParseResponse = -1017
        case appTransportSecurityRequiresSecureConnection = -1022
        case fileDoesNotExist = -1100
        case fileIsDirectory = -1101
        case noPermissionsToReadFile = -1102
        case dataLengthExceedsMaximum = -1103
        case secureConnectionFailed = -1200
        case serverCertificateHasBadDate = -1201
        case serverCertificateUntrusted = -1202
        case serverCertificateHasUnknownRoot = -1203
        case serverCertificateNotYetValid = -1204
        case clientCertificateRejected = -1205
        case clientCertificateRequired = -1206
        case cannotLoadFromNetwork = -2000
        case cannotCreateFile = -3000
        case cannotOpenFile = -3001
        case cannotCloseFile = -3002
        case cannotWriteToFile = -3003
        case cannotRemoveFile = -3004
        case cannotMoveFile = -3005
        case downloadDecodingFailedMidStream = -3006
        case downloadDecodingFailedToComplete = -3007
        case internationalRoamingOff = -1018
        case callIsActive = -1019
        case dataNotAllowed = -1020
        case requestBodyStreamExhausted = -1021
        case backgroundSessionRequiresSharedContainer = -995
        case backgroundSessionInUseByAnotherProcess = -996
        case backgroundSessionWasDisconnected = -997
    }
}

extension URLError {
    private var _nsUserInfo: [String: Any] {
        return _nsError.userInfo
    }

    /// The URL which caused a load to fail.
    public var failingURL: URL? {
        return _nsUserInfo[NSURLErrorFailingURLErrorKey] as? URL
    }

    /// The string for the URL which caused a load to fail.
    public var failureURLString: String? {
        return _nsUserInfo[NSURLErrorFailingURLStringErrorKey] as? String
    }
}

extension URLError {
    public static var unknown:                                  URLError.Code { return .unknown }
    public static var cancelled:                                URLError.Code { return .cancelled }
    public static var badURL:                                   URLError.Code { return .badURL }
    public static var timedOut:                                 URLError.Code { return .timedOut }
    public static var unsupportedURL:                           URLError.Code { return .unsupportedURL }
    public static var cannotFindHost:                           URLError.Code { return .cannotFindHost }
    public static var cannotConnectToHost:                      URLError.Code { return .cannotConnectToHost }
    public static var networkConnectionLost:                    URLError.Code { return .networkConnectionLost }
    public static var dnsLookupFailed:                          URLError.Code { return .dnsLookupFailed }
    public static var httpTooManyRedirects:                     URLError.Code { return .httpTooManyRedirects }
    public static var resourceUnavailable:                      URLError.Code { return .resourceUnavailable }
    public static var notConnectedToInternet:                   URLError.Code { return .notConnectedToInternet }
    public static var redirectToNonExistentLocation:            URLError.Code { return .redirectToNonExistentLocation }
    public static var badServerResponse:                        URLError.Code { return .badServerResponse }
    public static var userCancelledAuthentication:              URLError.Code { return .userCancelledAuthentication }
    public static var userAuthenticationRequired:               URLError.Code { return .userAuthenticationRequired }
    public static var zeroByteResource:                         URLError.Code { return .zeroByteResource }
    public static var cannotDecodeRawData:                      URLError.Code { return .cannotDecodeRawData }
    public static var cannotDecodeContentData:                  URLError.Code { return .cannotDecodeContentData }
    public static var cannotParseResponse:                      URLError.Code { return .cannotParseResponse }
    public static var fileDoesNotExist:                         URLError.Code { return .fileDoesNotExist }
    public static var fileIsDirectory:                          URLError.Code { return .fileIsDirectory }
    public static var noPermissionsToReadFile:                  URLError.Code { return .noPermissionsToReadFile }
    public static var secureConnectionFailed:                   URLError.Code { return .secureConnectionFailed }
    public static var serverCertificateHasBadDate:              URLError.Code { return .serverCertificateHasBadDate }
    public static var serverCertificateUntrusted:               URLError.Code { return .serverCertificateUntrusted }
    public static var serverCertificateHasUnknownRoot:          URLError.Code { return .serverCertificateHasUnknownRoot }
    public static var serverCertificateNotYetValid:             URLError.Code { return .serverCertificateNotYetValid }
    public static var clientCertificateRejected:                URLError.Code { return .clientCertificateRejected }
    public static var clientCertificateRequired:                URLError.Code { return .clientCertificateRequired }
    public static var cannotLoadFromNetwork:                    URLError.Code { return .cannotLoadFromNetwork }
    public static var cannotCreateFile:                         URLError.Code { return .cannotCreateFile }
    public static var cannotOpenFile:                           URLError.Code { return .cannotOpenFile }
    public static var cannotCloseFile:                          URLError.Code { return .cannotCloseFile }
    public static var cannotWriteToFile:                        URLError.Code { return .cannotWriteToFile }
    public static var cannotRemoveFile:                         URLError.Code { return .cannotRemoveFile }
    public static var cannotMoveFile:                           URLError.Code { return .cannotMoveFile }
    public static var downloadDecodingFailedMidStream:          URLError.Code { return .downloadDecodingFailedMidStream }
    public static var downloadDecodingFailedToComplete:         URLError.Code { return .downloadDecodingFailedToComplete }
    public static var internationalRoamingOff:                  URLError.Code { return .internationalRoamingOff }
    public static var callIsActive:                             URLError.Code { return .callIsActive }
    public static var dataNotAllowed:                           URLError.Code { return .dataNotAllowed }
    public static var requestBodyStreamExhausted:               URLError.Code { return .requestBodyStreamExhausted }
    public static var backgroundSessionRequiresSharedContainer: URLError.Code { return .backgroundSessionRequiresSharedContainer }
    public static var backgroundSessionInUseByAnotherProcess:   URLError.Code { return .backgroundSessionInUseByAnotherProcess }
    public static var backgroundSessionWasDisconnected:         URLError.Code { return .backgroundSessionWasDisconnected }
}

extension POSIXErrorCode : _ErrorCodeProtocol {
    public typealias _ErrorType = POSIXError
}

/// Describes an error in the POSIX error domain.
extension POSIXError : _BridgedStoredNSError {
    public var _nsError: NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(code.rawValue))
    }

    public init(_nsError error: NSError) {
        precondition(error.domain == NSPOSIXErrorDomain)
        self = POSIXError(POSIXErrorCode(rawValue: Int32(error.code))!)
    }

    public static var _nsErrorDomain: String { return NSPOSIXErrorDomain }
    
    public typealias Code = POSIXErrorCode
}

enum UnknownNSError: Error {
    case missingError
}

#if !canImport(ObjectiveC)

public // COMPILER_INTRINSIC
func _convertNSErrorToError(_ error: NSError?) -> Error {
    return error ?? UnknownNSError.missingError
}

public // COMPILER_INTRINSIC
func _convertErrorToNSError(_ error: Error) -> NSError {
    if let object = _extractDynamicValue(error as Any) {
        return unsafeBitCast(object, to: NSError.self)
    } else {
        let domain: String
        let code: Int
        let userInfo: [String: Any]
        
        if let error = error as? CustomNSError {
            domain = type(of: error).errorDomain
            code = error.errorCode
            userInfo = error.errorUserInfo
        } else {
            domain = error._domain
            code = error._code
            userInfo = (_swift_Foundation_getErrorDefaultUserInfo(error) as? [String : Any]) ?? [:]
        }
        
        return NSError(domain: domain, code: code, userInfo: userInfo)
    }
}

#endif

