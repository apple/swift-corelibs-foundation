script = Script()

cf = StaticLibrary("CoreFoundation")

cf.GCC_PREFIX_HEADER = 'Base.subproj/CoreFoundation_Prefix.h'

if Configuration.current.target.sdk == OSType.Linux:
	cf.CFLAGS = '-DDEPLOYMENT_TARGET_LINUX -D_GNU_SOURCE '
	Configuration.current.requires_pkg_config = True
elif Configuration.current.target.sdk == OSType.FreeBSD:
	cf.CFLAGS = '-DDEPLOYMENT_TARGET_FREEBSD -I/usr/local/include -I/usr/local/include/libxml2 '
elif Configuration.current.target.sdk == OSType.MacOSX:
	cf.CFLAGS = '-DDEPLOYMENT_TARGET_MACOSX '

cf.ASFLAGS = " ".join([
	'-DCF_CHARACTERSET_BITMAP=\\"CharacterSets/CFCharacterSetBitmaps.bitmap\\"','
        '-DCF_CHARACTERSET_UNICHAR_DB=\\"CharacterSets/CFUniCharPropertyDatabase.data\\"','
        '-DCF_CHARACTERSET_UNICODE_DATA_B=\\"CharacterSets/CFUnicodeData-B.mapping\\"','
        '-DCF_CHARACTERSET_UNICODE_DATA_L=\\"CharacterSets/CFUnicodeData-L.mapping\\"','
])

cf.ROOT_HEADERS_FOLDER_PATH = "${PREFIX}/lib/swift"
cf.PUBLIC_HEADERS_FOLDER_PATH = "${PREFIX}/lib/swift/CoreFoundation"
cf.PRIVATE_HEADERS_FOLDER_PATH = "${PREFIX}/lib/swift/CoreFoundation"
cf.PROJECT_HEADERS_FOLDER_PATH = "${PREFIX}/lib/swift/CoreFoundation"
cf.PUBLIC_MODULE_FOLDER_PATH = "${PREFIX}/lib/swift/CoreFoundation"

cf.CFLAGS += " ".join([
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
	'-I${SYSROOT}/usr/include/libxml2',
	'-I./',
])

headers = CopyHeaders(
module = 'Base.subproj/module.modulemap',
public = [
	'Stream.subproj/CFStream.h',
	'String.subproj/CFStringEncodingExt.h',
	'Base.subproj/SwiftRuntime/CoreFoundation.h',
	'Base.subproj/SwiftRuntime/TargetConditionals.h',
	'RunLoop.subproj/CFMessagePort.h',
	'Collections.subproj/CFBinaryHeap.h',
	'PlugIn.subproj/CFBundle.h',
	'Locale.subproj/CFCalendar.h',
	'Collections.subproj/CFBitVector.h',
	'Base.subproj/CFAvailability.h',
	'Collections.subproj/CFTree.h',
	'NumberDate.subproj/CFTimeZone.h',
	'Error.subproj/CFError.h',
	'Collections.subproj/CFBag.h',
	'PlugIn.subproj/CFPlugIn.h',
	'Parsing.subproj/CFXMLParser.h',
	'String.subproj/CFString.h',
	'Collections.subproj/CFSet.h',
	'Base.subproj/CFUUID.h',
	'NumberDate.subproj/CFDate.h',
	'Collections.subproj/CFDictionary.h',
	'Base.subproj/CFByteOrder.h',
	'AppServices.subproj/CFUserNotification.h',
	'Base.subproj/CFBase.h',
	'Preferences.subproj/CFPreferences.h',
	'Locale.subproj/CFLocale.h',
	'RunLoop.subproj/CFSocket.h',
	'Parsing.subproj/CFPropertyList.h',
	'Collections.subproj/CFArray.h',
	'RunLoop.subproj/CFRunLoop.h',
	'URL.subproj/CFURLAccess.h',
	'Locale.subproj/CFDateFormatter.h',
	'RunLoop.subproj/CFMachPort.h',
	'PlugIn.subproj/CFPlugInCOM.h',
	'Base.subproj/CFUtilities.h',
	'Parsing.subproj/CFXMLNode.h',
	'URL.subproj/CFURLComponents.h',
	'URL.subproj/CFURL.h',
	'Locale.subproj/CFNumberFormatter.h',
	'String.subproj/CFCharacterSet.h',
	'NumberDate.subproj/CFNumber.h',
	'Collections.subproj/CFData.h',
	'String.subproj/CFAttributedString.h',
],
private = [
	'Base.subproj/ForSwiftFoundationOnly.h',
	'Base.subproj/ForFoundationOnly.h',
	'String.subproj/CFBurstTrie.h',
	'Error.subproj/CFError_Private.h',
	'URL.subproj/CFURLPriv.h',
	'Base.subproj/CFLogUtilities.h',
	'PlugIn.subproj/CFBundlePriv.h',
	'StringEncodings.subproj/CFStringEncodingConverter.h',
	'Stream.subproj/CFStreamAbstract.h',
	'Base.subproj/CFInternal.h',
	'Parsing.subproj/CFXMLInputStream.h',
	'Parsing.subproj/CFXMLInterface.h',
	'PlugIn.subproj/CFPlugIn_Factory.h',
	'String.subproj/CFStringLocalizedFormattingInternal.h',
	'PlugIn.subproj/CFBundle_Internal.h',
	'StringEncodings.subproj/CFStringEncodingConverterPriv.h',
	'Collections.subproj/CFBasicHash.h',
	'StringEncodings.subproj/CFStringEncodingDatabase.h',
	'StringEncodings.subproj/CFUnicodeDecomposition.h',
	'Stream.subproj/CFStreamInternal.h',
	'PlugIn.subproj/CFBundle_BinaryTypes.h',
	'Locale.subproj/CFICULogging.h',
	'Locale.subproj/CFLocaleInternal.h',
	'StringEncodings.subproj/CFUnicodePrecomposition.h',
	'Base.subproj/CFPriv.h',
	'StringEncodings.subproj/CFUniCharPriv.h',
	'URL.subproj/CFURL.inc.h',
	'NumberDate.subproj/CFBigNumber.h',
	'StringEncodings.subproj/CFUniChar.h',
	'StringEncodings.subproj/CFStringEncodingConverterExt.h',
	'Collections.subproj/CFStorage.h',
	'Base.subproj/CFRuntime.h',
	'String.subproj/CFStringDefaultEncoding.h',
	'String.subproj/CFCharacterSetPriv.h',
	'Stream.subproj/CFStreamPriv.h',
	'StringEncodings.subproj/CFICUConverters.h',
	'String.subproj/CFRegularExpression.h',
	'String.subproj/CFRunArray.h',
],
project = [
])

cf.add_phase(headers)

sources = CompileSources([
	'Base.subproj/CFBase.c',
	'Base.subproj/CFFileUtilities.c',
	'Base.subproj/CFPlatform.c',
	'Base.subproj/CFRuntime.c',
	'Base.subproj/CFSortFunctions.c',
	'Base.subproj/CFSystemDirectories.c',
	'Base.subproj/CFUtilities.c',
	'Base.subproj/CFUUID.c',
	'Collections.subproj/CFArray.c',
	'Collections.subproj/CFBag.c',
	'Collections.subproj/CFBasicHash.c',
	'Collections.subproj/CFBinaryHeap.c',
	'Collections.subproj/CFBitVector.c',
	'Collections.subproj/CFData.c',
	'Collections.subproj/CFDictionary.c',
	'Collections.subproj/CFSet.c',
	'Collections.subproj/CFStorage.c',
	'Collections.subproj/CFTree.c',
	'Error.subproj/CFError.c',
	'Locale.subproj/CFCalendar.c',
	'Locale.subproj/CFDateFormatter.c',
	'Locale.subproj/CFLocale.c',
	'Locale.subproj/CFLocaleIdentifier.c',
	'Locale.subproj/CFLocaleKeys.c',
	'Locale.subproj/CFNumberFormatter.c',
	'NumberDate.subproj/CFBigNumber.c',
	'NumberDate.subproj/CFDate.c',
	'NumberDate.subproj/CFNumber.c',
	'NumberDate.subproj/CFTimeZone.c',
	'Parsing.subproj/CFBinaryPList.c',
	'Parsing.subproj/CFOldStylePList.c',
	'Parsing.subproj/CFPropertyList.c',
	'Parsing.subproj/CFXMLInputStream.c',
	'Parsing.subproj/CFXMLNode.c',
	'Parsing.subproj/CFXMLParser.c',
	'Parsing.subproj/CFXMLTree.c',
	'Parsing.subproj/CFXMLInterface.c',
	'PlugIn.subproj/CFBundle.c',
	'PlugIn.subproj/CFBundle_Binary.c',
	'PlugIn.subproj/CFBundle_Grok.c',
	'PlugIn.subproj/CFBundle_InfoPlist.c',
	'PlugIn.subproj/CFBundle_Locale.c',
	'PlugIn.subproj/CFBundle_Resources.c',
	'PlugIn.subproj/CFBundle_Strings.c',
	'PlugIn.subproj/CFPlugIn.c',
	'PlugIn.subproj/CFPlugIn_Factory.c',
	'PlugIn.subproj/CFPlugIn_Instance.c',
	'PlugIn.subproj/CFPlugIn_PlugIn.c',
	'Preferences.subproj/CFApplicationPreferences.c',
	'Preferences.subproj/CFPreferences.c',
	'RunLoop.subproj/CFRunLoop.c',
	'RunLoop.subproj/CFSocket.c',
	'Stream.subproj/CFConcreteStreams.c',
	'Stream.subproj/CFSocketStream.c',
	'Stream.subproj/CFStream.c',
	'String.subproj/CFBurstTrie.c',
	'String.subproj/CFCharacterSet.c',
	'String.subproj/CFString.c',
	'String.subproj/CFStringEncodings.c',
	'String.subproj/CFStringScanner.c',
	'String.subproj/CFStringUtilities.c',
	'String.subproj/CFStringTransform.c',
	'StringEncodings.subproj/CFBuiltinConverters.c',
	'StringEncodings.subproj/CFICUConverters.c',
	'StringEncodings.subproj/CFPlatformConverters.c',
	'StringEncodings.subproj/CFStringEncodingConverter.c',
	'StringEncodings.subproj/CFStringEncodingDatabase.c',
	'StringEncodings.subproj/CFUniChar.c',
	'StringEncodings.subproj/CFUnicodeDecomposition.c',
	'StringEncodings.subproj/CFUnicodePrecomposition.c',
	'URL.subproj/CFURL.c',
	'URL.subproj/CFURLAccess.c',
	'URL.subproj/CFURLComponents.c',
	'URL.subproj/CFURLComponents_URIParser.c',
	'String.subproj/CFCharacterSetData.S',
	'String.subproj/CFUnicodeData.S',
	'String.subproj/CFUniCharPropertyDatabase.S',
	'String.subproj/CFRegularExpression.c',
	'String.subproj/CFAttributedString.c',
	'String.subproj/CFRunArray.c',
])

sources.add_dependency(headers)
cf.add_phase(sources)
script.add_product(cf)
script.generate()


