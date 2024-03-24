// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

// Most imports now centralized in TestImports.swift

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(CRT)
    import CRT
#endif

#if !os(Windows)
// ignore SIGPIPE which is sent when writing to closed file descriptors.
_ = signal(SIGPIPE, SIG_IGN)
#endif

// For the Swift version of the Foundation tests, we must manually list all test cases here.
var allTestCases = [
    testCase(TestAffineTransform.allTests),
    testCase(TestNSArray.allTests),
    testCase(TestBridging.allTests),
    testCase(TestBundle.allTests),
    testCase(TestByteCountFormatter.allTests),
    testCase(TestNSCache.allTests),
    testCase(TestCachedURLResponse.allTests),
    testCase(TestCalendar.allTests),
    testCase(TestNSCalendar.allTests),
    testCase(TestCharacterSet.allTests),
    testCase(TestNSCompoundPredicate.allTests),
    testCase(TestNSData.allTests),
    testCase(TestDataURLProtocol.allTests),
    testCase(TestDate.allTests),
    testCase(TestDateComponents.allTests),
    testCase(TestDateInterval.allTests),
    testCase(TestNSDateComponents.allTests),
    testCase(TestDateFormatter.allTests),
    testCase(TestDateIntervalFormatter.allTests),
    testCase(TestDecimal.allTests),
    testCase(TestNSDictionary.allTests),
    testCase(TestNSError.allTests),
    testCase(TestCocoaError.allTests),
    testCase(TestURLError.allTests),
    testCase(TestEnergyFormatter.allTests),
    testCase(TestFileManager.allTests),
    testCase(TestNSGeometry.allTests),
    testCase(TestHTTPCookie.allTests),
    testCase(TestHTTPCookieStorage.allTests),
    testCase(TestIndexPath.allTests),
    testCase(TestIndexSet.allTests),
    testCase(TestISO8601DateFormatter.allTests),
    testCase(TestJSONSerialization.allTests),
    testCase(TestNSKeyedArchiver.allTests),
    testCase(TestNSKeyedUnarchiver.allTests),
    testCase(TestLengthFormatter.allTests),
    testCase(TestNSLocale.allTests),
    testCase(TestNotificationCenter.allTests),
    testCase(TestNotificationQueue.allTests),
    testCase(TestNSNull.allTests),
    testCase(TestNSNumber.allTests),
    testCase(TestNSNumberBridging.allTests),
    testCase(TestNSObject.allTests),
    testCase(TestNumberFormatter.allTests),
    testCase(TestOperationQueue.allTests),
    testCase(TestNSOrderedSet.allTests),
    testCase(TestPersonNameComponents.allTests),
    testCase(TestPipe.allTests),
    testCase(TestNSPredicate.allTests),
    testCase(TestProcessInfo.allTests),
    testCase(TestHost.allTests),
    testCase(TestPropertyListSerialization.allTests),
    testCase(TestNSRange.allTests),
    testCase(TestNSRegularExpression.allTests),
    testCase(TestRunLoop.allTests),
    testCase(TestScanner.allTests),
    testCase(TestNSSet.allTests),
    testCase(TestSocketPort.allTests),
    testCase(TestStream.allTests),
    testCase(TestNSString.allTests),
    testCase(TestThread.allTests),
    testCase(TestProcess.allTests),
    testCase(TestNSTextCheckingResult.allTests),
    testCase(TestTimer.allTests),
    testCase(TestTimeZone.allTests),
    testCase(TestURL.allTests),
    testCase(TestURLCache.allTests),
    testCase(TestURLComponents.allTests),
    testCase(TestURLCredential.allTests),
    testCase(TestURLCredentialStorage.allTests),
    testCase(TestURLProtectionSpace.allTests),
    testCase(TestURLProtocol.allTests),
    testCase(TestNSURLRequest.allTests),
    testCase(TestNSURL.allTests),
    testCase(TestURLRequest.allTests),
    testCase(TestURLResponse.allTests),
    testCase(TestHTTPURLResponse.allTests),
    testCase(TestNSUUID.allTests),
    testCase(TestUUID.allTests),
    testCase(TestNSValue.allTests),
    testCase(TestUserDefaults.allTests),
    testCase(TestXMLParser.allTests),
    testCase(TestXMLDocument.allTests),
    testCase(TestNSAttributedString.allTests),
    testCase(TestNSMutableAttributedString.allTests),
    testCase(TestFileHandle.allTests),
    testCase(TestUnitConverter.allTests),
    testCase(TestProgressFraction.allTests),
    testCase(TestProgress.allTests),
    testCase(TestObjCRuntime.allTests),
    testCase(TestNotification.allTests),
    testCase(TestMassFormatter.allTests),
    testCase(TestJSONEncoder.allTests),
    testCase(TestPropertyListEncoder.allTests),
    testCase(TestCodable.allTests),
    testCase(TestUnit.allTests),
    testCase(TestDimension.allTests),
    testCase(TestMeasurement.allTests),
    testCase(TestUnitVolume.allTests),
    testCase(TestUnitInformationStorage.allTests),
    testCase(TestNSLock.allTests),
    testCase(TestNSSortDescriptor.allTests),
]

if #available(macOS 12, *) {
    allTestCases.append(contentsOf: [
        testCase(TestAttributedString.allTests),
        testCase(TestAttributedStringCOW.allTests),
        testCase(TestAttributedStringPerformance.allTests)
    ])
}

#if !os(Windows)
allTestCases.append(contentsOf: [
    testCase(TestURLSession.allTests),
    testCase(TestURLSessionFTP.allTests),
])
#endif

atexit({
    fflush(stdout)
    fflush(stderr)
})
XCTMain(allTestCases)
