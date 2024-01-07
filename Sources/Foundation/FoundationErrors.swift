// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if os(Windows)
import WinSDK
#endif

/// File-system operation attempted on non-existent file.
public var NSFileNoSuchFileError: Int                        { return CocoaError.Code.fileNoSuchFile.rawValue }

/// Failure to get a lock on file.
public var NSFileLockingError: Int                           { return CocoaError.Code.fileLocking.rawValue }

/// Read error, reason unknown.
public var NSFileReadUnknownError: Int                       { return CocoaError.Code.fileReadUnknown.rawValue }

/// Read error because of a permission problem.
public var NSFileReadNoPermissionError: Int                  { return CocoaError.Code.fileReadNoPermission.rawValue }

/// Read error because of an invalid file name.
public var NSFileReadInvalidFileNameError: Int               { return CocoaError.Code.fileReadInvalidFileName.rawValue }

/// Read error because of a corrupted file, bad format, or similar reason.
public var NSFileReadCorruptFileError: Int                   { return CocoaError.Code.fileReadCorruptFile.rawValue }

/// Read error because no such file was found.
public var NSFileReadNoSuchFileError: Int                    { return CocoaError.Code.fileReadNoSuchFile.rawValue }

/// Read error because the string encoding was not applicable.
///
/// Access the bad encoding from the `userInfo` dictionary using
/// the `NSStringEncodingErrorKey` key.
public var NSFileReadInapplicableStringEncodingError: Int    { return CocoaError.Code.fileReadInapplicableStringEncoding.rawValue }

/// Read error because the specified URL scheme is unsupported.
public var NSFileReadUnsupportedSchemeError: Int             { return CocoaError.Code.fileReadUnsupportedScheme.rawValue }

/// Read error because the specified file was too large.
public var NSFileReadTooLargeError: Int                      { return CocoaError.Code.fileReadTooLarge.rawValue }

/// Read error because the string coding of the file could not be determined.
public var NSFileReadUnknownStringEncodingError: Int         { return CocoaError.Code.fileReadUnknownStringEncoding.rawValue }

/// Write error, reason unknown.
public var NSFileWriteUnknownError: Int                      { return CocoaError.Code.fileWriteUnknown.rawValue }

/// Write error because of a permission problem.
public var NSFileWriteNoPermissionError: Int                 { return CocoaError.Code.fileWriteNoPermission.rawValue }

/// Write error because of an invalid file name.
public var NSFileWriteInvalidFileNameError: Int              { return CocoaError.Code.fileWriteInvalidFileName.rawValue }

/// Write error returned when `FileManager` class’s copy, move,
/// and link methods report errors when the destination file already exists.
public var NSFileWriteFileExistsError: Int                   { return CocoaError.Code.fileWriteFileExists.rawValue }

/// Write error because the string encoding was not applicable.
///
/// Access the bad encoding from the `userInfo` dictionary
/// using the `NSStringEncodingErrorKey` key.
public var NSFileWriteInapplicableStringEncodingError: Int   { return CocoaError.Code.fileWriteInapplicableStringEncoding.rawValue }

/// Write error because the specified URL scheme is unsupported.
public var NSFileWriteUnsupportedSchemeError: Int            { return CocoaError.Code.fileWriteUnsupportedScheme.rawValue }

/// Write error because of a lack of disk space.
public var NSFileWriteOutOfSpaceError: Int                   { return CocoaError.Code.fileWriteOutOfSpace.rawValue }

/// Write error because because the volume is read only.
public var NSFileWriteVolumeReadOnlyError: Int               { return CocoaError.Code.fileWriteVolumeReadOnly.rawValue }

public var NSFileManagerUnmountUnknownError: Int             { return CocoaError.Code.fileManagerUnmountUnknown.rawValue }

public var NSFileManagerUnmountBusyError: Int                { return CocoaError.Code.fileManagerUnmountBusy.rawValue }

/// Key-value coding validation error.
public var NSKeyValueValidationError: Int                    { return CocoaError.Code.keyValueValidation.rawValue }

/// Formatting error (related to display of data).
public var NSFormattingError: Int                            { return CocoaError.Code.formatting.rawValue }

/// The user cancelled the operation (for example, by pressing Command-period).
///
/// This code is for errors that do not require a dialog displayed and might be
/// candidates for special-casing.
public var NSUserCancelledError: Int                         { return CocoaError.Code.userCancelled.rawValue }

/// The feature is not supported, either because the file system
/// lacks the feature, or required libraries are missing,
/// or other similar reasons.
///
/// For example, some volumes may not support a Trash folder, so these methods
/// will report failure by returning `false` or `nil` and
/// an `NSError` with `NSFeatureUnsupportedError`.
public var NSFeatureUnsupportedError: Int                    { return CocoaError.Code.featureUnsupported.rawValue }

/// Executable is of a type that is not loadable in the current process.
public var NSExecutableNotLoadableError: Int                 { return CocoaError.Code.executableNotLoadable.rawValue }

/// Executable does not provide an architecture compatible with
/// the current process.
public var NSExecutableArchitectureMismatchError: Int        { return CocoaError.Code.executableArchitectureMismatch.rawValue }

/// Executable has Objective-C runtime information incompatible
/// with the current process.
public var NSExecutableRuntimeMismatchError: Int             { return CocoaError.Code.executableRuntimeMismatch.rawValue }

/// Executable cannot be loaded for some other reason, such as
/// a problem with a library it depends on.
public var NSExecutableLoadError: Int                        { return CocoaError.Code.executableLoad.rawValue }

/// Executable fails due to linking issues.
public var NSExecutableLinkError: Int                        { return CocoaError.Code.executableLink.rawValue }

/// An error was encountered while parsing the property list.
public var NSPropertyListReadCorruptError: Int               { return CocoaError.Code.propertyListReadCorrupt.rawValue }

/// The version number of the property list is unable to be determined.
public var NSPropertyListReadUnknownVersionError: Int        { return CocoaError.Code.propertyListReadUnknownVersion.rawValue }

/// An stream error was encountered while reading the property list.
public var NSPropertyListReadStreamError: Int                { return CocoaError.Code.propertyListReadStream.rawValue }

/// An stream error was encountered while writing the property list.
public var NSPropertyListWriteStreamError: Int               { return CocoaError.Code.propertyListWriteStream.rawValue }

public var NSPropertyListWriteInvalidError: Int              { return CocoaError.Code.propertyListWriteInvalid.rawValue }

/// The XPC connection was interrupted.
public var NSXPCConnectionInterrupted: Int                   { return CocoaError.Code.xpcConnectionInterrupted.rawValue }

/// The XPC connection was invalid.
public var NSXPCConnectionInvalid: Int                       { return CocoaError.Code.xpcConnectionInvalid.rawValue }

/// The XPC connection reply was invalid.
public var NSXPCConnectionReplyInvalid: Int                  { return CocoaError.Code.xpcConnectionReplyInvalid.rawValue }

/// The item has not been uploaded to iCloud by another device yet.
///
/// When this error occurs, you do not need to ask the system
/// to start downloading the item. The system will download the item as soon
/// as it can. If you want to know when the item becomes available,
/// use an `NSMetadataQuer`y object to monitor changes to the file’s URL.
public var NSUbiquitousFileUnavailableError: Int             { return CocoaError.Code.ubiquitousFileUnavailable.rawValue }

/// The item could not be uploaded to iCloud because it would make
/// the account go over its quota.
public var NSUbiquitousFileNotUploadedDueToQuotaError: Int   { return CocoaError.Code.ubiquitousFileNotUploadedDueToQuota.rawValue }

/// Connecting to the iCloud servers failed.
public var NSUbiquitousFileUbiquityServerNotAvailable: Int   { return CocoaError.Code.ubiquitousFileUbiquityServerNotAvailable.rawValue }

public var NSUserActivityHandoffFailedError: Int             { return CocoaError.Code.userActivityHandoffFailed.rawValue }

public var NSUserActivityConnectionUnavailableError: Int     { return CocoaError.Code.userActivityConnectionUnavailable.rawValue }

public var NSUserActivityRemoteApplicationTimedOutError: Int { return CocoaError.Code.userActivityRemoteApplicationTimedOut.rawValue }

public var NSUserActivityHandoffUserInfoTooLargeError: Int   { return CocoaError.Code.userActivityHandoffUserInfoTooLarge.rawValue }

public var NSCoderReadCorruptError: Int                      { return CocoaError.Code.coderReadCorrupt.rawValue }

public var NSCoderValueNotFoundError: Int                    { return CocoaError.Code.coderValueNotFound.rawValue }

internal func _NSErrorWithErrno(_ posixErrno : Int32, reading : Bool, path : String? = nil, url : URL? = nil, extraUserInfo : [String : Any]? = nil) -> NSError {
    var cocoaError : CocoaError.Code
    if reading {
        switch posixErrno {
            case EFBIG: cocoaError = .fileReadTooLarge
            case ENOENT: cocoaError = .fileReadNoSuchFile
            case EPERM, EACCES: cocoaError = .fileReadNoPermission
            case ENAMETOOLONG: cocoaError = .fileReadUnknown
            default: cocoaError = .fileReadUnknown
        }
    } else {
        switch posixErrno {
            case ENOENT: cocoaError = .fileNoSuchFile
            case EPERM, EACCES: cocoaError = .fileWriteNoPermission
            case ENAMETOOLONG: cocoaError = .fileWriteInvalidFileName
#if os(Windows)
            case ENOSPC: cocoaError = .fileWriteOutOfSpace
#else
            case EDQUOT, ENOSPC: cocoaError = .fileWriteOutOfSpace
#endif
            case EROFS: cocoaError = .fileWriteVolumeReadOnly
            case EEXIST: cocoaError = .fileWriteFileExists
            default: cocoaError = .fileWriteUnknown
        }
    }
    
    var userInfo = extraUserInfo ?? [String : Any]()
    if let path = path {
        userInfo[NSFilePathErrorKey] = path._nsObject
    } else if let url = url {
        userInfo[NSURLErrorKey] = url
    }
    
    userInfo[NSUnderlyingErrorKey] = NSError(domain: NSPOSIXErrorDomain, code: Int(posixErrno))
    
    return NSError(domain: NSCocoaErrorDomain, code: cocoaError.rawValue, userInfo: userInfo)
}

#if os(Windows)
// The codes in this domain are codes returned by GetLastError in the Windows SDK (in WinError.h):
// https://docs.microsoft.com/en-us/windows/desktop/Debug/system-error-codes
internal let _NSWindowsErrorDomain = "org.swift.Foundation.WindowsError"

internal func _NSErrorWithWindowsError(_ windowsError: DWORD, reading: Bool, paths: [String]? = nil) -> NSError {
    var cocoaError : CocoaError.Code
    switch windowsError {
        case DWORD(ERROR_LOCK_VIOLATION): cocoaError = .fileLocking
        case DWORD(ERROR_NOT_LOCKED): cocoaError = .fileLocking
        case DWORD(ERROR_LOCK_FAILED): cocoaError = .fileLocking
        case DWORD(ERROR_INVALID_EXE_SIGNATURE): cocoaError = .executableNotLoadable
        case DWORD(ERROR_EXE_MARKED_INVALID): cocoaError = .executableNotLoadable
        case DWORD(ERROR_BAD_EXE_FORMAT): cocoaError = .executableNotLoadable
        case DWORD(ERROR_LOCKED): cocoaError = .fileLocking
        default:
            if reading {
                switch windowsError {
                    case DWORD(ERROR_FILE_NOT_FOUND), DWORD(ERROR_PATH_NOT_FOUND):
                        // On an empty path, Windows will return FILE/PATH_NOT_FOUND
                        // rather than invalid path as posix does
                        cocoaError = paths?.contains("") ?? false
                            ? .fileReadInvalidFileName
                            : .fileReadNoSuchFile
                    case DWORD(ERROR_ACCESS_DENIED): cocoaError = .fileReadNoPermission
                    case DWORD(ERROR_INVALID_ACCESS): cocoaError = .fileReadNoPermission
                    case DWORD(ERROR_INVALID_DRIVE): cocoaError = .fileReadNoSuchFile
                    case DWORD(ERROR_SHARING_VIOLATION): cocoaError = .fileReadNoPermission
                    case DWORD(ERROR_INVALID_NAME): cocoaError = .fileReadInvalidFileName
                    case DWORD(ERROR_LABEL_TOO_LONG): cocoaError = .fileReadInvalidFileName
                    case DWORD(ERROR_BAD_PATHNAME): cocoaError = .fileReadInvalidFileName
                    case DWORD(ERROR_FILENAME_EXCED_RANGE): cocoaError = .fileReadInvalidFileName
                    case DWORD(ERROR_DIRECTORY): cocoaError = .fileReadInvalidFileName
                    default:  cocoaError = .fileReadUnknown
                }
            } else {
                switch windowsError {
                    case DWORD(ERROR_FILE_NOT_FOUND), DWORD(ERROR_PATH_NOT_FOUND):
                        // On an empty path, Windows will return FILE/PATH_NOT_FOUND
                        // rather than invalid path as posix does
                        cocoaError = paths?.contains("") ?? false
                            ? .fileWriteInvalidFileName
                            : .fileNoSuchFile
                    case DWORD(ERROR_ACCESS_DENIED): cocoaError = .fileWriteNoPermission
                    case DWORD(ERROR_INVALID_ACCESS): cocoaError = .fileWriteNoPermission
                    case DWORD(ERROR_INVALID_DRIVE): cocoaError = .fileNoSuchFile
                    case DWORD(ERROR_WRITE_PROTECT): cocoaError = .fileWriteVolumeReadOnly
                    case DWORD(ERROR_WRITE_FAULT): cocoaError = .fileWriteNoPermission
                    case DWORD(ERROR_SHARING_VIOLATION): cocoaError = .fileWriteNoPermission
                    case DWORD(ERROR_FILE_EXISTS): cocoaError = .fileWriteFileExists
                    case DWORD(ERROR_DISK_FULL): cocoaError = .fileWriteOutOfSpace
                    case DWORD(ERROR_INVALID_NAME): cocoaError = .fileWriteInvalidFileName
                    case DWORD(ERROR_LABEL_TOO_LONG): cocoaError = .fileWriteInvalidFileName
                    case DWORD(ERROR_BAD_PATHNAME): cocoaError = .fileWriteInvalidFileName
                    case DWORD(ERROR_ALREADY_EXISTS): cocoaError = .fileWriteFileExists
                    case DWORD(ERROR_FILENAME_EXCED_RANGE): cocoaError = .fileWriteInvalidFileName
                    case DWORD(ERROR_DIRECTORY): cocoaError = .fileWriteInvalidFileName
                    case DWORD(ERROR_DISK_RESOURCES_EXHAUSTED): cocoaError = .fileWriteOutOfSpace
                    default:  cocoaError = .fileWriteUnknown
                }
            }
        }

    return NSError(domain: NSCocoaErrorDomain, code: cocoaError.rawValue, userInfo: [
            NSUnderlyingErrorKey: NSError(domain: _NSWindowsErrorDomain, code: Int(windowsError))
    ])
}
#endif
