// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

// Most imports now centraized in TestImports.swift

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

// ignore SIGPIPE which is sent when writing to closed file descriptors.
_ = signal(SIGPIPE, SIG_IGN)

// For the Swift version of the Foundation tests, we must manually list all test cases here.
XCTMain([
    testCase(TestAffineTransform.allTests),
    testCase(TestNSArray.allTests),
    testCase(TestBundle.allTests),
    testCase(TestByteCountFormatter.allTests),
    testCase(TestNSCache.allTests),
    testCase(TestCalendar.allTests),
    testCase(TestCharacterSet.allTests),
    testCase(TestNSCompoundPredicate.allTests),
    testCase(TestNSData.allTests),
    testCase(TestDate.allTests),
    testCase(TestDateInterval.allTests),
    testCase(TestNSDateComponents.allTests),
    testCase(TestDateFormatter.allTests),
    testCase(TestDecimal.allTests),
    testCase(TestNSDictionary.allTests),
    testCase(TestNSError.allTests),
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
    testCase(TestStream.allTests),
    testCase(TestNSString.allTests),
    testCase(TestThread.allTests),
    testCase(TestProcess.allTests),
    testCase(TestNSTextCheckingResult.allTests),
    testCase(TestTimer.allTests),
    testCase(TestTimeZone.allTests),
    testCase(TestURL.allTests),
    testCase(TestURLComponents.allTests),
    testCase(TestURLCredential.allTests),
    testCase(TestURLProtectionSpace.allTests),
    testCase(TestURLProtocol.allTests),
    testCase(TestNSURLRequest.allTests),
    testCase(TestURLRequest.allTests),
    testCase(TestURLResponse.allTests),
    testCase(TestHTTPURLResponse.allTests),
    testCase(TestURLSession.allTests),
    testCase(TestNSNull.allTests),
    testCase(TestNSUUID.allTests),
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
    testCase(TestCodable.allTests),
    testCase(TestUnit.allTests),
    testCase(TestNSLock.allTests),
])
