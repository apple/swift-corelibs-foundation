# This source file is part of the Swift.org open source project
#
# Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
#

script = Script()

foundation = StaticAndDynamicLibrary("Foundation")

foundation.GCC_PREFIX_HEADER = 'CoreFoundation/Base.subproj/CoreFoundation_Prefix.h'

swift_cflags = ['-DDEPLOYMENT_RUNTIME_SWIFT']
if Configuration.current.target.sdk == OSType.Linux:
	foundation.CFLAGS = '-D_GNU_SOURCE -DCF_CHARACTERSET_DATA_DIR="CoreFoundation/CharacterSets"'
	foundation.LDFLAGS = '${SWIFT_USE_LINKER} -lswiftGlibc -Wl,-Bsymbolic '
	Configuration.current.requires_pkg_config = True
elif Configuration.current.target.sdk == OSType.FreeBSD:
	foundation.CFLAGS = '-I/usr/local/include -I/usr/local/include/libxml2 -I/usr/local/include/curl '
	foundation.LDFLAGS = ''
elif Configuration.current.target.sdk == OSType.MacOSX:
	foundation.LDFLAGS = '-licucore -twolevel_namespace -Wl,-alias_list,CoreFoundation/Base.subproj/DarwinSymbolAliases -sectcreate __UNICODE __csbitmaps CoreFoundation/CharacterSets/CFCharacterSetBitmaps.bitmap -sectcreate __UNICODE __properties CoreFoundation/CharacterSets/CFUniCharPropertyDatabase.data -sectcreate __UNICODE __data CoreFoundation/CharacterSets/CFUnicodeData-L.mapping -segprot __UNICODE r r '
elif Configuration.current.target.sdk == OSType.Win32 and Configuration.current.target.environ == EnvironmentType.Cygnus:
	foundation.CFLAGS = '-D_GNU_SOURCE -mcmodel=large '
	foundation.LDFLAGS = '${SWIFT_USE_LINKER} -lswiftGlibc `icu-config --ldflags` -Wl,--allow-multiple-definition '
	swift_cflags += ['-DCYGWIN']

if Configuration.current.build_mode == Configuration.Debug:
    foundation.LDFLAGS += ' -lswiftSwiftOnoneSupport '
    swift_cflags += ['-enable-testing']

foundation.ASFLAGS = " ".join([
        '-DCF_CHARACTERSET_BITMAP=\\"CoreFoundation/CharacterSets/CFCharacterSetBitmaps.bitmap\\"',
        '-DCF_CHARACTERSET_UNICHAR_DB=\\"CoreFoundation/CharacterSets/CFUniCharPropertyDatabase.data\\"',
        '-DCF_CHARACTERSET_UNICODE_DATA_B=\\"CoreFoundation/CharacterSets/CFUnicodeData-B.mapping\\"',
        '-DCF_CHARACTERSET_UNICODE_DATA_L=\\"CoreFoundation/CharacterSets/CFUnicodeData-L.mapping\\"',
])

# For now, we do not distinguish between public and private headers (they are all private to Foundation)
# These are really part of CF, which should ultimately be a separate target
foundation.ROOT_HEADERS_FOLDER_PATH = "${PREFIX}/lib/swift"
foundation.PUBLIC_HEADERS_FOLDER_PATH = "${PREFIX}/lib/swift/CoreFoundation"
foundation.PRIVATE_HEADERS_FOLDER_PATH = "${PREFIX}/lib/swift/CoreFoundation"
foundation.PROJECT_HEADERS_FOLDER_PATH = "${PREFIX}/lib/swift/CoreFoundation"

foundation.PUBLIC_MODULE_FOLDER_PATH = "${PREFIX}/lib/swift/CoreFoundation"

foundation.CFLAGS += " ".join([
	'-DU_SHOW_DRAFT_API',
	'-DCF_BUILDING_CF',
	'-DDEPLOYMENT_RUNTIME_SWIFT',
	'-fconstant-cfstrings',
	'-fexceptions',
	'-Wno-shorten-64-to-32',
	'-Wno-deprecated-declarations',
	'-Wno-unreachable-code',
	'-Wno-conditional-uninitialized',
	'-Wno-unused-variable',
	'-Wno-int-conversion',
	'-Wno-unused-function',
	'-I./',
	'-fno-common',
	'-fcf-runtime-abi=swift',
])

swift_cflags += [
	'-I${BUILD_DIR}/Foundation/${PREFIX}/lib/swift',
]

if "XCTEST_BUILD_DIR" in Configuration.current.variables:
	swift_cflags += [
		'-I${XCTEST_BUILD_DIR}',
		'-L${XCTEST_BUILD_DIR}',
	]

if Configuration.current.requires_pkg_config:
    pkg_config_dependencies = [
        'icu-i18n',
        'icu-uc',
        'libcurl',
        'libxml-2.0',
    ]
    for package_name in pkg_config_dependencies:
        try:
            package = PkgConfig(package_name)
        except PkgConfig.Error as e:
            sys.exit("pkg-config error for package {}: {}".format(package_name, e))
        foundation.CFLAGS += ' {} '.format(' '.join(package.cflags))
        foundation.LDFLAGS += ' {} '.format(' '.join(package.ldflags))
        swift_cflags += package.swiftc_flags
else:
	foundation.CFLAGS += ''.join([
		'-I${SYSROOT}/usr/include/curl ',
		'-I${SYSROOT}/usr/include/libxml2 ',
	])
	foundation.LDFLAGS += ''.join([
		'-lcurl ',
		'-lxml2 ',
	])
	swift_cflags += [
		'-I${SYSROOT}/usr/include/curl',
		'-I${SYSROOT}/usr/include/libxml2',
	]

triple = Configuration.current.target.triple
if triple == "armv7-none-linux-androideabi":
	foundation.LDFLAGS += '-llog '
else:
	foundation.LDFLAGS += '-lpthread '

foundation.LDFLAGS += '-ldl -lm -lswiftCore '

# Configure use of Dispatch in CoreFoundation and Foundation if libdispatch is being built
if "LIBDISPATCH_SOURCE_DIR" in Configuration.current.variables:
	foundation.CFLAGS += " "+" ".join([
		'-DDEPLOYMENT_ENABLE_LIBDISPATCH',
		'-I'+Configuration.current.variables["LIBDISPATCH_SOURCE_DIR"],
		'-I' + os.path.join(Configuration.current.variables["LIBDISPATCH_SOURCE_DIR"], 'src', 'BlocksRuntime'),
		'-I'+Configuration.current.variables["LIBDISPATCH_BUILD_DIR"]+'/tests'  # for include of dispatch/private.h in CF
	])
	swift_cflags += ([
		'-DDEPLOYMENT_ENABLE_LIBDISPATCH',
		'-I'+Configuration.current.variables["LIBDISPATCH_SOURCE_DIR"],
		'-I'+Configuration.current.variables["LIBDISPATCH_BUILD_DIR"]+'/src/swift',
		'-Xcc -fblocks'
	])
	foundation.LDFLAGS += '-ldispatch -lswiftDispatch -L'+Configuration.current.variables["LIBDISPATCH_BUILD_DIR"]+'/src -rpath \$$ORIGIN '
	foundation.LDFLAGS += '-L' + Configuration.current.variables['LIBDISPATCH_BUILD_DIR'] + ' -lBlocksRuntime '

foundation.SWIFTCFLAGS = " ".join(swift_cflags)

if "XCTEST_BUILD_DIR" in Configuration.current.variables:
	foundation.LDFLAGS += '-L${XCTEST_BUILD_DIR}'

headers = CopyHeaders(
module = 'CoreFoundation/Base.subproj/module.modulemap',
public = [
	'CoreFoundation/Stream.subproj/CFStream.h',
	'CoreFoundation/String.subproj/CFStringEncodingExt.h',
	'CoreFoundation/Base.subproj/SwiftRuntime/CoreFoundation.h',
	'CoreFoundation/Base.subproj/SwiftRuntime/TargetConditionals.h',
	'CoreFoundation/RunLoop.subproj/CFMessagePort.h',
	'CoreFoundation/Collections.subproj/CFBinaryHeap.h',
	'CoreFoundation/PlugIn.subproj/CFBundle.h',
	'CoreFoundation/Locale.subproj/CFCalendar.h',
	'CoreFoundation/Collections.subproj/CFBitVector.h',
	'CoreFoundation/Base.subproj/CFAvailability.h',
	'CoreFoundation/Collections.subproj/CFTree.h',
	'CoreFoundation/NumberDate.subproj/CFTimeZone.h',
	'CoreFoundation/Error.subproj/CFError.h',
	'CoreFoundation/Collections.subproj/CFBag.h',
	'CoreFoundation/PlugIn.subproj/CFPlugIn.h',
	'CoreFoundation/Parsing.subproj/CFXMLParser.h',
	'CoreFoundation/String.subproj/CFString.h',
	'CoreFoundation/Collections.subproj/CFSet.h',
	'CoreFoundation/Base.subproj/CFUUID.h',
	'CoreFoundation/NumberDate.subproj/CFDate.h',
	'CoreFoundation/Collections.subproj/CFDictionary.h',
	'CoreFoundation/Base.subproj/CFByteOrder.h',
	'CoreFoundation/AppServices.subproj/CFUserNotification.h',
	'CoreFoundation/Base.subproj/CFBase.h',
	'CoreFoundation/Preferences.subproj/CFPreferences.h',
	'CoreFoundation/Locale.subproj/CFLocale.h',
	'CoreFoundation/RunLoop.subproj/CFSocket.h',
	'CoreFoundation/Parsing.subproj/CFPropertyList.h',
	'CoreFoundation/Collections.subproj/CFArray.h',
	'CoreFoundation/RunLoop.subproj/CFRunLoop.h',
	'CoreFoundation/URL.subproj/CFURLAccess.h',
	'CoreFoundation/URL.subproj/CFURLSessionInterface.h',
	'CoreFoundation/Locale.subproj/CFDateFormatter.h',
	'CoreFoundation/RunLoop.subproj/CFMachPort.h',
	'CoreFoundation/PlugIn.subproj/CFPlugInCOM.h',
	'CoreFoundation/Base.subproj/CFUtilities.h',
	'CoreFoundation/Parsing.subproj/CFXMLNode.h',
	'CoreFoundation/URL.subproj/CFURLComponents.h',
	'CoreFoundation/URL.subproj/CFURL.h',
	'CoreFoundation/Locale.subproj/CFNumberFormatter.h',
	'CoreFoundation/String.subproj/CFCharacterSet.h',
	'CoreFoundation/NumberDate.subproj/CFNumber.h',
	'CoreFoundation/Collections.subproj/CFData.h',
	'CoreFoundation/String.subproj/CFAttributedString.h',
	'CoreFoundation/Base.subproj/CoreFoundation_Prefix.h',
	'CoreFoundation/AppServices.subproj/CFNotificationCenter.h'
],
private = [
	'CoreFoundation/Base.subproj/ForSwiftFoundationOnly.h',
	'CoreFoundation/Base.subproj/ForFoundationOnly.h',
	'CoreFoundation/Base.subproj/CFAsmMacros.h',
	'CoreFoundation/String.subproj/CFBurstTrie.h',
	'CoreFoundation/Error.subproj/CFError_Private.h',
	'CoreFoundation/URL.subproj/CFURLPriv.h',
	'CoreFoundation/Base.subproj/CFLogUtilities.h',
	'CoreFoundation/PlugIn.subproj/CFBundlePriv.h',
	'CoreFoundation/StringEncodings.subproj/CFStringEncodingConverter.h',
	'CoreFoundation/Stream.subproj/CFStreamAbstract.h',
	'CoreFoundation/Base.subproj/CFInternal.h',
	'CoreFoundation/Base.subproj/CFObjCTypes.h',
	'CoreFoundation/Parsing.subproj/CFXMLInputStream.h',
	'CoreFoundation/Parsing.subproj/CFXMLInterface.h',
	'CoreFoundation/PlugIn.subproj/CFPlugIn_Factory.h',
	'CoreFoundation/String.subproj/CFStringLocalizedFormattingInternal.h',
	'CoreFoundation/PlugIn.subproj/CFBundle_Internal.h',
	'CoreFoundation/StringEncodings.subproj/CFStringEncodingConverterPriv.h',
	'CoreFoundation/Collections.subproj/CFBasicHash.h',
	'CoreFoundation/StringEncodings.subproj/CFStringEncodingDatabase.h',
	'CoreFoundation/StringEncodings.subproj/CFUnicodeDecomposition.h',
	'CoreFoundation/Stream.subproj/CFStreamInternal.h',
	'CoreFoundation/PlugIn.subproj/CFBundle_BinaryTypes.h',
	'CoreFoundation/Locale.subproj/CFICULogging.h',
	'CoreFoundation/Locale.subproj/CFLocaleInternal.h',
	'CoreFoundation/StringEncodings.subproj/CFUnicodePrecomposition.h',
	'CoreFoundation/Base.subproj/CFPriv.h',
	'CoreFoundation/StringEncodings.subproj/CFUniCharPriv.h',
	'CoreFoundation/URL.subproj/CFURL.inc.h',
	'CoreFoundation/NumberDate.subproj/CFBigNumber.h',
	'CoreFoundation/StringEncodings.subproj/CFUniChar.h',
	'CoreFoundation/StringEncodings.subproj/CFStringEncodingConverterExt.h',
	'CoreFoundation/Collections.subproj/CFStorage.h',
	'CoreFoundation/Base.subproj/CFRuntime.h',
	'CoreFoundation/String.subproj/CFStringDefaultEncoding.h',
	'CoreFoundation/String.subproj/CFCharacterSetPriv.h',
	'CoreFoundation/Stream.subproj/CFStreamPriv.h',
	'CoreFoundation/StringEncodings.subproj/CFICUConverters.h',
	'CoreFoundation/String.subproj/CFRegularExpression.h',
	'CoreFoundation/String.subproj/CFRunArray.h',
	'CoreFoundation/Locale.subproj/CFDateFormatter_Private.h',
	'CoreFoundation/Locale.subproj/CFLocale_Private.h',
	'CoreFoundation/Parsing.subproj/CFPropertyList_Private.h',
	'CoreFoundation/Base.subproj/CFKnownLocations.h',
    'CoreFoundation/Base.subproj/CFOverflow.h',
	'CoreFoundation/Base.subproj/CFRuntime_Internal.h',
	'CoreFoundation/Collections.subproj/CFCollections_Internal.h',
	'CoreFoundation/RunLoop.subproj/CFMachPort_Internal.h',
	'CoreFoundation/RunLoop.subproj/CFMachPort_Lifetime.h',
	'CoreFoundation/String.subproj/CFAttributedStringPriv.h',
	'CoreFoundation/String.subproj/CFString_Internal.h',
],
project = [
])

foundation.add_phase(headers)

sources = CompileSources([
    'uuid/uuid.c',
	# 'CoreFoundation/AppServices.subproj/CFUserNotification.c',
	'CoreFoundation/Base.subproj/CFBase.c',
	'CoreFoundation/Base.subproj/CFFileUtilities.c',
	'CoreFoundation/Base.subproj/CFPlatform.c',
	'CoreFoundation/Base.subproj/CFRuntime.c',
	'CoreFoundation/Base.subproj/CFSortFunctions.c',
	'CoreFoundation/Base.subproj/CFSystemDirectories.c',
	'CoreFoundation/Base.subproj/CFUtilities.c',
	'CoreFoundation/Base.subproj/CFUUID.c',
	'CoreFoundation/Collections.subproj/CFArray.c',
	'CoreFoundation/Collections.subproj/CFBag.c',
	'CoreFoundation/Collections.subproj/CFBasicHash.c',
	'CoreFoundation/Collections.subproj/CFBinaryHeap.c',
	'CoreFoundation/Collections.subproj/CFBitVector.c',
	'CoreFoundation/Collections.subproj/CFData.c',
	'CoreFoundation/Collections.subproj/CFDictionary.c',
	'CoreFoundation/Collections.subproj/CFSet.c',
	'CoreFoundation/Collections.subproj/CFStorage.c',
	'CoreFoundation/Collections.subproj/CFTree.c',
	'CoreFoundation/Error.subproj/CFError.c',
	'CoreFoundation/Locale.subproj/CFCalendar.c',
	'CoreFoundation/Locale.subproj/CFDateFormatter.c',
	'CoreFoundation/Locale.subproj/CFLocale.c',
	'CoreFoundation/Locale.subproj/CFLocaleIdentifier.c',
	'CoreFoundation/Locale.subproj/CFLocaleKeys.c',
	'CoreFoundation/Locale.subproj/CFNumberFormatter.c',
	'CoreFoundation/NumberDate.subproj/CFBigNumber.c',
	'CoreFoundation/NumberDate.subproj/CFDate.c',
	'CoreFoundation/NumberDate.subproj/CFNumber.c',
	'CoreFoundation/NumberDate.subproj/CFTimeZone.c',
	'CoreFoundation/Parsing.subproj/CFBinaryPList.c',
	'CoreFoundation/Parsing.subproj/CFOldStylePList.c',
	'CoreFoundation/Parsing.subproj/CFPropertyList.c',
	'CoreFoundation/Parsing.subproj/CFXMLInputStream.c',
	'CoreFoundation/Parsing.subproj/CFXMLNode.c',
	'CoreFoundation/Parsing.subproj/CFXMLParser.c',
	'CoreFoundation/Parsing.subproj/CFXMLTree.c',
	'CoreFoundation/Parsing.subproj/CFXMLInterface.c',
	'CoreFoundation/PlugIn.subproj/CFBundle.c',
	'CoreFoundation/PlugIn.subproj/CFBundle_Binary.c',
	'CoreFoundation/PlugIn.subproj/CFBundle_Grok.c',
	'CoreFoundation/PlugIn.subproj/CFBundle_InfoPlist.c',
	'CoreFoundation/PlugIn.subproj/CFBundle_Locale.c',
	'CoreFoundation/PlugIn.subproj/CFBundle_Resources.c',
	'CoreFoundation/PlugIn.subproj/CFBundle_Strings.c',
	'CoreFoundation/PlugIn.subproj/CFBundle_Main.c',
	'CoreFoundation/PlugIn.subproj/CFBundle_ResourceFork.c',
	'CoreFoundation/PlugIn.subproj/CFBundle_Executable.c',
	'CoreFoundation/PlugIn.subproj/CFBundle_DebugStrings.c',
	'CoreFoundation/PlugIn.subproj/CFPlugIn.c',
	'CoreFoundation/PlugIn.subproj/CFPlugIn_Factory.c',
	'CoreFoundation/PlugIn.subproj/CFPlugIn_Instance.c',
	'CoreFoundation/PlugIn.subproj/CFPlugIn_PlugIn.c',
	'CoreFoundation/Preferences.subproj/CFApplicationPreferences.c',
	'CoreFoundation/Preferences.subproj/CFPreferences.c',
    'CoreFoundation/Preferences.subproj/CFXMLPreferencesDomain.c',
	# 'CoreFoundation/RunLoop.subproj/CFMachPort.c',
	# 'CoreFoundation/RunLoop.subproj/CFMessagePort.c',
    # 'CoreFoundation/RunLoop.subproj/CFMachPort_Lifetime.c',
	'CoreFoundation/RunLoop.subproj/CFRunLoop.c',
	'CoreFoundation/RunLoop.subproj/CFSocket.c',
	'CoreFoundation/Stream.subproj/CFConcreteStreams.c',
	'CoreFoundation/Stream.subproj/CFSocketStream.c',
	'CoreFoundation/Stream.subproj/CFStream.c',
	'CoreFoundation/String.subproj/CFBurstTrie.c',
	'CoreFoundation/String.subproj/CFCharacterSet.c',
	'CoreFoundation/String.subproj/CFString.c',
	'CoreFoundation/String.subproj/CFStringEncodings.c',
	'CoreFoundation/String.subproj/CFStringScanner.c',
	'CoreFoundation/String.subproj/CFStringUtilities.c',
	'CoreFoundation/String.subproj/CFStringTransform.c',
	'CoreFoundation/StringEncodings.subproj/CFBuiltinConverters.c',
	'CoreFoundation/StringEncodings.subproj/CFICUConverters.c',
	'CoreFoundation/StringEncodings.subproj/CFPlatformConverters.c',
	'CoreFoundation/StringEncodings.subproj/CFStringEncodingConverter.c',
	'CoreFoundation/StringEncodings.subproj/CFStringEncodingDatabase.c',
	'CoreFoundation/StringEncodings.subproj/CFUniChar.c',
	'CoreFoundation/StringEncodings.subproj/CFUnicodeDecomposition.c',
	'CoreFoundation/StringEncodings.subproj/CFUnicodePrecomposition.c',
	'CoreFoundation/URL.subproj/CFURL.c',
	'CoreFoundation/URL.subproj/CFURLAccess.c',
	'CoreFoundation/URL.subproj/CFURLComponents.c',
	'CoreFoundation/URL.subproj/CFURLComponents_URIParser.c',
	'CoreFoundation/String.subproj/CFCharacterSetData.S',
	'CoreFoundation/String.subproj/CFUnicodeData.S',
	'CoreFoundation/String.subproj/CFUniCharPropertyDatabase.S',
	'CoreFoundation/String.subproj/CFRegularExpression.c',
	'CoreFoundation/String.subproj/CFAttributedString.c',
	'CoreFoundation/String.subproj/CFRunArray.c',
	'CoreFoundation/URL.subproj/CFURLSessionInterface.c',
	'CoreFoundation/Base.subproj/CFKnownLocations.c',
])

# This code is already in libdispatch so is only needed if libdispatch is
# NOT being used
if "LIBDISPATCH_SOURCE_DIR" not in Configuration.current.variables:
    sources += (['closure/data.c', 'closure/runtime.c'])

sources.add_dependency(headers)
foundation.add_phase(sources)

swift_sources = CompileSwiftSources([
	'Foundation/NSObject.swift',
	'Foundation/AffineTransform.swift',
	'Foundation/NSArray.swift',
	'Foundation/NSAttributedString.swift',
	'Foundation/Bundle.swift',
	'Foundation/ByteCountFormatter.swift',
	'Foundation/NSCache.swift',
	'Foundation/NSCalendar.swift',
	'Foundation/NSCFArray.swift',
	'Foundation/NSCFBoolean.swift',
	'Foundation/NSCFDictionary.swift',
	'Foundation/NSCFSet.swift',
	'Foundation/NSCFString.swift',
	'Foundation/NSCharacterSet.swift',
	'Foundation/NSCFCharacterSet.swift',
	'Foundation/NSCoder.swift',
	'Foundation/NSComparisonPredicate.swift',
	'Foundation/NSCompoundPredicate.swift',
	'Foundation/NSConcreteValue.swift',
	'Foundation/NSData.swift',
	'Foundation/NSDate.swift',
	'Foundation/DateComponentsFormatter.swift',
	'Foundation/DateFormatter.swift',
	'Foundation/DateIntervalFormatter.swift',
	'Foundation/Decimal.swift',
	'Foundation/NSDecimalNumber.swift',
	'Foundation/NSDictionary.swift',
	'Foundation/EnergyFormatter.swift',
	'Foundation/NSEnumerator.swift',
	'Foundation/NSError.swift',
	'Foundation/NSExpression.swift',
	'Foundation/FileHandle.swift',
	'Foundation/FileManager.swift',
	'Foundation/FileManager_XDG.swift',
	'Foundation/Formatter.swift',
	'Foundation/NSGeometry.swift',
	'Foundation/Host.swift',
	'Foundation/HTTPCookie.swift',
	'Foundation/HTTPCookieStorage.swift',
	'Foundation/NSIndexPath.swift',
	'Foundation/NSIndexSet.swift',
	'Foundation/ISO8601DateFormatter.swift',
	'Foundation/JSONSerialization.swift',
	'Foundation/NSKeyedCoderOldStyleArray.swift',
	'Foundation/NSKeyedArchiver.swift',
	'Foundation/NSKeyedArchiverHelpers.swift',
	'Foundation/NSKeyedUnarchiver.swift',
	'Foundation/LengthFormatter.swift',
	'Foundation/NSLocale.swift',
	'Foundation/NSLock.swift',
	'Foundation/NSLog.swift',
	'Foundation/MassFormatter.swift',
	'Foundation/NSNotification.swift',
	'Foundation/NotificationQueue.swift',
	'Foundation/NSNull.swift',
	'Foundation/NSNumber.swift',
	'Foundation/NumberFormatter.swift',
	'Foundation/NSObjCRuntime.swift',
	'Foundation/Operation.swift',
	'Foundation/NSOrderedSet.swift',
	'Foundation/NSPathUtilities.swift',
	'Foundation/NSPersonNameComponents.swift',
	'Foundation/PersonNameComponentsFormatter.swift',
	'Foundation/NSPlatform.swift',
	'Foundation/Port.swift',
	'Foundation/PortMessage.swift',
	'Foundation/NSPredicate.swift',
	'Foundation/ProcessInfo.swift',
	'Foundation/Progress.swift',
	'Foundation/ProgressFraction.swift',
	'Foundation/PropertyListSerialization.swift',
	'Foundation/NSRange.swift',
	'Foundation/NSRegularExpression.swift',
	'Foundation/RunLoop.swift',
	'Foundation/Scanner.swift',
	'Foundation/NSSet.swift',
	'Foundation/NSSortDescriptor.swift',
	'Foundation/NSSpecialValue.swift',
	'Foundation/Stream.swift',
	'Foundation/NSString.swift',
	'Foundation/NSStringAPI.swift',
	'Foundation/NSSwiftRuntime.swift',
	'Foundation/Process.swift',
	'Foundation/NSTextCheckingResult.swift',
	'Foundation/Thread.swift',
	'Foundation/Timer.swift',
	'Foundation/NSTimeZone.swift',
	'Foundation/NSURL.swift',
	'Foundation/URLAuthenticationChallenge.swift',
	'Foundation/URLCache.swift',
	'Foundation/URLCredential.swift',
	'Foundation/URLCredentialStorage.swift',
	'Foundation/NSURLError.swift',
	'Foundation/URLProtectionSpace.swift',
	'Foundation/URLProtocol.swift',
	'Foundation/NSURLRequest.swift',
	'Foundation/URLResponse.swift',
	'Foundation/URLSession/Configuration.swift',
	'Foundation/URLSession/libcurl/EasyHandle.swift',
	'Foundation/URLSession/BodySource.swift',
	'Foundation/URLSession/Message.swift',
	'Foundation/URLSession/http/HTTPMessage.swift',
	'Foundation/URLSession/libcurl/MultiHandle.swift',
	'Foundation/URLSession/URLSession.swift',
	'Foundation/URLSession/URLSessionConfiguration.swift',
	'Foundation/URLSession/URLSessionDelegate.swift',
	'Foundation/URLSession/URLSessionTask.swift',
	'Foundation/URLSession/TaskRegistry.swift',
	'Foundation/URLSession/NativeProtocol.swift',
	'Foundation/URLSession/TransferState.swift',
	'Foundation/URLSession/libcurl/libcurlHelpers.swift',
	'Foundation/URLSession/http/HTTPURLProtocol.swift',
	'Foundation/URLSession/ftp/FTPURLProtocol.swift',
	'Foundation/UserDefaults.swift',
	'Foundation/NSUUID.swift',
	'Foundation/NSValue.swift',
	'Foundation/XMLDocument.swift',
	'Foundation/XMLDTD.swift',
	'Foundation/XMLDTDNode.swift',
	'Foundation/XMLElement.swift',
	'Foundation/XMLNode.swift',
	'Foundation/XMLParser.swift',
	'Foundation/FoundationErrors.swift',
	'Foundation/URL.swift',
	'Foundation/UUID.swift',
	'Foundation/Boxing.swift',
	'Foundation/ReferenceConvertible.swift',
	'Foundation/Date.swift',
	'Foundation/Data.swift',
	'Foundation/CharacterSet.swift',
	'Foundation/URLRequest.swift',
	'Foundation/PersonNameComponents.swift',
	'Foundation/Notification.swift',
	'Foundation/URLComponents.swift',
	'Foundation/DateComponents.swift',
	'Foundation/DateInterval.swift',
	'Foundation/IndexPath.swift',
	'Foundation/IndexSet.swift',
	'Foundation/StringEncodings.swift',
	'Foundation/ExtraStringAPIs.swift',
	'Foundation/Measurement.swift',
	'Foundation/NSMeasurement.swift',
	'Foundation/MeasurementFormatter.swift',
	'Foundation/Unit.swift',
	'Foundation/TimeZone.swift',
	'Foundation/Calendar.swift',
	'Foundation/Locale.swift',
	'Foundation/String.swift',
	'Foundation/Set.swift',
	'Foundation/Dictionary.swift',
	'Foundation/Array.swift',
	'Foundation/Bridging.swift',
	'Foundation/CGFloat.swift',
	'Foundation/Codable.swift',
	'Foundation/JSONEncoder.swift',
])

if Configuration.current.build_mode == Configuration.Debug:
    swift_sources.enable_testable_import = True

swift_sources.add_dependency(headers)
foundation.add_phase(swift_sources)

foundation_tests_resources = CopyResources('TestFoundation', [
    'TestFoundation/Resources/Info.plist',
    'TestFoundation/Resources/NSURLTestData.plist',
    'TestFoundation/Resources/Test.plist',
    'TestFoundation/Resources/NSStringTestData.txt',
    'TestFoundation/Resources/NSString-UTF16-BE-data.txt',
    'TestFoundation/Resources/NSString-UTF16-LE-data.txt',
    'TestFoundation/Resources/NSString-UTF32-BE-data.txt',
    'TestFoundation/Resources/NSString-UTF32-LE-data.txt',
    'TestFoundation/Resources/NSString-ISO-8859-1-data.txt',
    'TestFoundation/Resources/NSXMLDocumentTestData.xml',
    'TestFoundation/Resources/PropertyList-1.0.dtd',
    'TestFoundation/Resources/NSXMLDTDTestData.xml',
    'TestFoundation/Resources/NSKeyedUnarchiver-ArrayTest.plist',
    'TestFoundation/Resources/NSKeyedUnarchiver-ComplexTest.plist',
    'TestFoundation/Resources/NSKeyedUnarchiver-ConcreteValueTest.plist',
    'TestFoundation/Resources/NSKeyedUnarchiver-EdgeInsetsTest.plist',
    'TestFoundation/Resources/NSKeyedUnarchiver-NotificationTest.plist',
    'TestFoundation/Resources/NSKeyedUnarchiver-RangeTest.plist',
    'TestFoundation/Resources/NSKeyedUnarchiver-RectTest.plist',
    'TestFoundation/Resources/NSKeyedUnarchiver-URLTest.plist',
    'TestFoundation/Resources/NSKeyedUnarchiver-UUIDTest.plist',
    'TestFoundation/Resources/NSKeyedUnarchiver-OrderedSetTest.plist',
    'TestFoundation/Resources/TestFileWithZeros.txt',
])

# TODO: Probably this should be another 'product', but for now it's simply a phase
foundation_tests = SwiftExecutable('TestFoundation', [
	'TestFoundation/main.swift',
        'TestFoundation/HTTPServer.swift',
	'TestFoundation/FTPServer.swift',
        'Foundation/ProgressFraction.swift',
        'TestFoundation/Utilities.swift',
] + glob.glob('./TestFoundation/Test*.swift')) # all TestSomething.swift are considered sources to the test project in the TestFoundation directory

Configuration.current.extra_ld_flags += ' -L'+Configuration.current.variables["LIBDISPATCH_BUILD_DIR"]+'/src'

foundation_tests.add_dependency(foundation_tests_resources)
xdgTestHelper = SwiftExecutable('xdgTestHelper',
 ['TestFoundation/xdgTestHelper/main.swift'])
xdgTestHelper.outputDirectory = 'TestFoundation'
foundation_tests.add_dependency(xdgTestHelper)
foundation.add_phase(xdgTestHelper)
foundation.add_phase(foundation_tests_resources)
foundation.add_phase(foundation_tests)

plutil = SwiftExecutable('plutil', ['Tools/plutil/main.swift'])
foundation.add_phase(plutil)

script.add_product(foundation)

LIBS_DIRS = Configuration.current.build_directory.absolute()+"/Foundation/:"
if "XCTEST_BUILD_DIR" in Configuration.current.variables:
    LIBS_DIRS += "${XCTEST_BUILD_DIR}:"
if "LIBDISPATCH_BUILD_DIR" in Configuration.current.variables:
    LIBS_DIRS += Configuration.current.variables["LIBDISPATCH_BUILD_DIR"]+"/src:"

Configuration.current.variables["LIBS_DIRS"] = LIBS_DIRS

extra_script = """
rule InstallFoundation
    command = mkdir -p "${DSTROOT}/${PREFIX}/lib/swift/${OS}"; $
    cp "${BUILD_DIR}/Foundation/${DYLIB_PREFIX}Foundation${DYLIB_SUFFIX}" "${DSTROOT}/${PREFIX}/lib/swift/${OS}"; $
    mkdir -p "${DSTROOT}/${PREFIX}/lib/swift_static/${OS}"; $
    cp "${BUILD_DIR}/Foundation/${STATICLIB_PREFIX}Foundation${STATICLIB_SUFFIX}" "${DSTROOT}/${PREFIX}/lib/swift_static/${OS}"; $
    mkdir -p "${DSTROOT}/${PREFIX}/lib/swift/${OS}/${ARCH}"; $
    cp "${BUILD_DIR}/Foundation/Foundation.swiftmodule" "${DSTROOT}/${PREFIX}/lib/swift/${OS}/${ARCH}/"; $
    cp "${BUILD_DIR}/Foundation/Foundation.swiftdoc" "${DSTROOT}/${PREFIX}/lib/swift/${OS}/${ARCH}/"; $
    mkdir -p "${DSTROOT}/${PREFIX}/local/include"; $
    rsync -a "${BUILD_DIR}/Foundation/${PREFIX}/lib/swift/CoreFoundation" "${DSTROOT}/${PREFIX}/lib/swift/"

build ${BUILD_DIR}/.install: InstallFoundation ${BUILD_DIR}/Foundation/${DYLIB_PREFIX}Foundation${DYLIB_SUFFIX}

build install: phony | ${BUILD_DIR}/.install

"""
extra_script += """
rule RunTestFoundation
    command = echo "**** RUNNING TESTS ****\\nexecute:\\nLD_LIBRARY_PATH=${LIBS_DIRS} ${BUILD_DIR}/TestFoundation/TestFoundation\\n**** DEBUGGING TESTS ****\\nexecute:\\nLD_LIBRARY_PATH=${LIBS_DIRS} ${BUILD_DIR}/../lldb-${OS}-${ARCH}/bin/lldb ${BUILD_DIR}/TestFoundation/TestFoundation\\n"
    description = Building Tests

build ${BUILD_DIR}/.test: RunTestFoundation | TestFoundation

build test: phony | ${BUILD_DIR}/.test

"""

script.add_text(extra_script)

script.generate()
