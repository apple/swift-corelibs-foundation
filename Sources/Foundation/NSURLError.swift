// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


/// `NSURLErrorDomain` indicates an `NSURL` error.
///
/// Constants used by `NSError` to differentiate between "domains" of error codes,
/// serving as a discriminator for error codes that originate from different subsystems or sources.
public let NSURLErrorDomain: String = "NSURLErrorDomain"

/// The `NSError` userInfo dictionary key used to store and retrieve the URL which
/// caused a load to fail.
public let NSURLErrorFailingURLErrorKey: String = "NSErrorFailingURLKey"

/// The `NSError` userInfo dictionary key used to store and retrieve the NSString
/// object for the URL which caused a load to fail.
public let NSURLErrorFailingURLStringErrorKey: String = "NSErrorFailingURLStringKey"

/// The `NSError` userInfo dictionary key used to store and retrieve the
/// SecTrustRef object representing the state of a failed SSL handshake.
public let NSURLErrorFailingURLPeerTrustErrorKey: String = "NSURLErrorFailingURLPeerTrustErrorKey"

/// The `NSError` userInfo dictionary key used to store and retrieve the
/// `NSNumber` corresponding to the reason why a background `URLSessionTask`
/// was cancelled
/// 
/// One of
/// * `NSURLErrorCancelledReasonUserForceQuitApplication`
/// * `NSURLErrorCancelledReasonBackgroundUpdatesDisabled`
/// * `NSURLErrorCancelledReasonInsufficientSystemResources`
public let NSURLErrorBackgroundTaskCancelledReasonKey: String = "NSURLErrorBackgroundTaskCancelledReasonKey"

/// Code associated with `NSURLErrorBackgroundTaskCancelledReasonKey`
public var NSURLErrorCancelledReasonUserForceQuitApplication: Int { return 0 }
/// Code associated with `NSURLErrorBackgroundTaskCancelledReasonKey`
public var NSURLErrorCancelledReasonBackgroundUpdatesDisabled: Int { return 1 }
/// Code associated with `NSURLErrorBackgroundTaskCancelledReasonKey`
public var NSURLErrorCancelledReasonInsufficientSystemResources: Int { return 2 }

//MARK: NSURL-related Error Codes

public var NSURLErrorUnknown: Int { return -1 }
public var NSURLErrorCancelled: Int { return -999 }
public var NSURLErrorBadURL: Int { return -1000 }
public var NSURLErrorTimedOut: Int { return -1001 }
public var NSURLErrorUnsupportedURL: Int { return -1002 }
public var NSURLErrorCannotFindHost: Int { return -1003 }
public var NSURLErrorCannotConnectToHost: Int { return -1004 }
public var NSURLErrorNetworkConnectionLost: Int { return -1005 }
public var NSURLErrorDNSLookupFailed: Int { return -1006 }
public var NSURLErrorHTTPTooManyRedirects: Int { return -1007 }
public var NSURLErrorResourceUnavailable: Int { return -1008 }
public var NSURLErrorNotConnectedToInternet: Int { return -1009 }
public var NSURLErrorRedirectToNonExistentLocation: Int { return -1010 }
public var NSURLErrorBadServerResponse: Int { return -1011 }
public var NSURLErrorUserCancelledAuthentication: Int { return -1012 }
public var NSURLErrorUserAuthenticationRequired: Int { return -1013 }
public var NSURLErrorZeroByteResource: Int { return -1014 }
public var NSURLErrorCannotDecodeRawData: Int { return -1015 }
public var NSURLErrorCannotDecodeContentData: Int { return -1016 }
public var NSURLErrorCannotParseResponse: Int { return -1017 }
public var NSURLErrorAppTransportSecurityRequiresSecureConnection: Int { return -1022 }
public var NSURLErrorFileDoesNotExist: Int { return -1100 }
public var NSURLErrorFileIsDirectory: Int { return -1101 }
public var NSURLErrorNoPermissionsToReadFile: Int { return -1102 }
public var NSURLErrorDataLengthExceedsMaximum: Int { return -1103 }

// SSL errors
public var NSURLErrorFileOutsideSafeArea: Int { return -1104 }
public var NSURLErrorSecureConnectionFailed: Int { return -1200 }
public var NSURLErrorServerCertificateHasBadDate: Int { return -1201 }
public var NSURLErrorServerCertificateUntrusted: Int { return -1202 }
public var NSURLErrorServerCertificateHasUnknownRoot: Int { return -1203 }
public var NSURLErrorServerCertificateNotYetValid: Int { return -1204 }
public var NSURLErrorClientCertificateRejected: Int { return -1205 }
public var NSURLErrorClientCertificateRequired: Int { return -1206 }
public var NSURLErrorCannotLoadFromNetwork: Int { return -2000 }

// Download and file I/O errors
public var NSURLErrorCannotCreateFile: Int { return -3000 }
public var NSURLErrorCannotOpenFile: Int { return -3001 }
public var NSURLErrorCannotCloseFile: Int { return -3002 }
public var NSURLErrorCannotWriteToFile: Int { return -3003 }
public var NSURLErrorCannotRemoveFile: Int { return -3004 }
public var NSURLErrorCannotMoveFile: Int { return -3005 }
public var NSURLErrorDownloadDecodingFailedMidStream: Int { return -3006 }
public var NSURLErrorDownloadDecodingFailedToComplete: Int { return -3007 }

public var NSURLErrorInternationalRoamingOff: Int { return -1018 }
public var NSURLErrorCallIsActive: Int { return -1019 }
public var NSURLErrorDataNotAllowed: Int { return -1020 }
public var NSURLErrorRequestBodyStreamExhausted: Int { return -1021 }

public var NSURLErrorBackgroundSessionRequiresSharedContainer: Int { return -995 }
public var NSURLErrorBackgroundSessionInUseByAnotherProcess: Int { return -996 }
public var NSURLErrorBackgroundSessionWasDisconnected: Int { return -997 }

