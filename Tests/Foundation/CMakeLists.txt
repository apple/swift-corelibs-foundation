add_executable(TestFoundation
  main.swift
  HTTPServer.swift
  Imports.swift
  FTPServer.swift
  ../../Sources/Foundation/ProgressFraction.swift
  Utilities.swift
  FixtureValues.swift)

# Test Cases
target_sources(TestFoundation PRIVATE
  Tests/TestAffineTransform.swift
  Tests/TestAttributedString.swift
  Tests/TestAttributedStringCOW.swift
  Tests/TestAttributedStringPerformance.swift
  Tests/TestAttributedStringSupport.swift
  Tests/TestBridging.swift
  Tests/TestBundle.swift
  Tests/TestByteCountFormatter.swift
  Tests/TestCachedURLResponse.swift
  Tests/TestCalendar.swift
  Tests/TestCharacterSet.swift
  Tests/TestCodable.swift
  Tests/TestDataURLProtocol.swift
  Tests/TestDateComponents.swift
  Tests/TestDateFormatter.swift
  Tests/TestDateInterval.swift
  Tests/TestDateIntervalFormatter.swift
  Tests/TestDate.swift
  Tests/TestDecimal.swift
  Tests/TestDimension.swift
  Tests/TestEnergyFormatter.swift
  Tests/TestFileHandle.swift
  Tests/TestFileManager.swift
  Tests/TestHost.swift
  Tests/TestHTTPCookieStorage.swift
  Tests/TestHTTPCookie.swift
  Tests/TestHTTPURLResponse.swift
  Tests/TestIndexPath.swift
  Tests/TestIndexSet.swift
  Tests/TestISO8601DateFormatter.swift
  Tests/TestJSONEncoder.swift
  Tests/TestJSONSerialization.swift
  Tests/TestLengthFormatter.swift
  Tests/TestMassFormatter.swift
  Tests/TestMeasurement.swift
  Tests/TestNotificationCenter.swift
  Tests/TestNotificationQueue.swift
  Tests/TestNotification.swift
  Tests/TestNSArray.swift
  Tests/TestNSAttributedString.swift
  Tests/TestNSCache.swift
  Tests/TestNSCalendar.swift
  Tests/TestNSCompoundPredicate.swift
  Tests/TestNSData.swift
  Tests/TestNSDateComponents.swift
  Tests/TestNSDictionary.swift
  Tests/TestNSError.swift
  Tests/TestNSGeometry.swift
  Tests/TestNSKeyedArchiver.swift
  Tests/TestNSKeyedUnarchiver.swift
  Tests/TestNSLocale.swift
  Tests/TestNSLock.swift
  Tests/TestNSNull.swift
  Tests/TestNSNumberBridging.swift
  Tests/TestNSNumber.swift
  Tests/TestNSOrderedSet.swift
  Tests/TestNSPredicate.swift
  Tests/TestNSRange.swift
  Tests/TestNSRegularExpression.swift
  Tests/TestNSSet.swift
  Tests/TestNSSortDescriptor.swift
  Tests/TestNSString.swift
  Tests/TestNSTextCheckingResult.swift
  Tests/TestNSURL.swift
  Tests/TestNSURLRequest.swift
  Tests/TestNSUUID.swift
  Tests/TestNSValue.swift
  Tests/TestNumberFormatter.swift
  Tests/TestObjCRuntime.swift
  Tests/TestOperationQueue.swift
  Tests/TestPersonNameComponents.swift
  Tests/TestPipe.swift
  Tests/TestProcessInfo.swift
  Tests/TestProcess.swift
  Tests/TestProgress.swift
  Tests/TestProgressFraction.swift
  Tests/TestPropertyListEncoder.swift
  Tests/TestPropertyListSerialization.swift
  Tests/TestRunLoop.swift
  Tests/TestScanner.swift
  Tests/TestSocketPort.swift
  Tests/TestStream.swift
  Tests/TestThread.swift
  Tests/TestTimer.swift
  Tests/TestTimeZone.swift
  Tests/TestUnitConverter.swift
  Tests/TestUnitInformationStorage.swift
  Tests/TestUnitVolume.swift
  Tests/TestUnit.swift
  Tests/TestURLCache.swift
  Tests/TestURLCredential.swift
  Tests/TestURLCredentialStorage.swift
  Tests/TestURLComponents.swift
  Tests/TestURLProtectionSpace.swift
  Tests/TestURLProtocol.swift
  Tests/TestURLRequest.swift
  Tests/TestURLResponse.swift
  Tests/TestURLSession.swift
  Tests/TestURLSessionFTP.swift
  Tests/TestURL.swift
  Tests/TestUserDefaults.swift
  Tests/TestUtils.swift
  Tests/TestUUID.swift
  Tests/TestXMLDocument.swift
  Tests/TestXMLParser.swift)

target_compile_definitions(TestFoundation PRIVATE
  $<$<BOOL:${ENABLE_TESTING}>:NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT>)
target_link_libraries(TestFoundation PRIVATE
  Foundation
  FoundationNetworking
  FoundationXML)
target_link_libraries(TestFoundation PRIVATE
  XCTest)

# NOTE(compnerd) create a test "app" directory as we need the xdgTestHelper as
# an executable peer and the binary will be placed in the directory with the
# same name as a peer in the build tree.
if(CMAKE_SYSTEM_NAME STREQUAL Windows)
  set(Resources TestFoundation.resources)
else()
  set(Resources Resources)
endif()

add_custom_command(TARGET TestFoundation POST_BUILD
  COMMAND
    ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/TestFoundation.app
  COMMAND
    ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:TestFoundation> ${CMAKE_BINARY_DIR}/TestFoundation.app
  COMMAND
    ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:plutil> ${CMAKE_BINARY_DIR}/TestFoundation.app
  COMMAND
    ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:xdgTestHelper> ${CMAKE_BINARY_DIR}/TestFoundation.app
  COMMAND
    ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/TestFoundation.app/${Resources}
  COMMAND
    ${CMAKE_COMMAND} -E copy_if_different
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSURLTestData.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/Test.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSStringTestData.txt
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSString-UTF16-BE-data.txt
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSString-UTF16-LE-data.txt
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSString-UTF32-BE-data.txt
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSString-UTF32-LE-data.txt
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSString-ISO-8859-1-data.txt
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSXMLDocumentTestData.xml
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/PropertyList-1.0.dtd
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSXMLDTDTestData.xml
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSKeyedUnarchiver-ArrayTest.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSKeyedUnarchiver-ComplexTest.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSKeyedUnarchiver-ConcreteValueTest.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSKeyedUnarchiver-EdgeInsetsTest.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSKeyedUnarchiver-NotificationTest.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSKeyedUnarchiver-RangeTest.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSKeyedUnarchiver-RectTest.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSKeyedUnarchiver-URLTest.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSKeyedUnarchiver-UUIDTest.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/NSKeyedUnarchiver-OrderedSetTest.plist
      ${CMAKE_CURRENT_SOURCE_DIR}/Resources/TestFileWithZeros.txt
    ${CMAKE_BINARY_DIR}/TestFoundation.app/${Resources}
  COMMAND
    ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/Resources/Fixtures ${CMAKE_BINARY_DIR}/TestFoundation.app/${Resources}/Fixtures
  COMMAND
    ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:Foundation> ${CMAKE_BINARY_DIR}/TestFoundation.app
  COMMAND
    ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:FoundationNetworking> ${CMAKE_BINARY_DIR}/TestFoundation.app
  COMMAND
    ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:FoundationXML> ${CMAKE_BINARY_DIR}/TestFoundation.app)

cmake_path(GET CMAKE_Swift_COMPILER PARENT_PATH Swift_LIBRARY_PATH)
# NOTE(stevapple): Path separator ; is passed as ? because it conflicts with CMake's list separator
xctest_discover_tests(TestFoundation
                      COMMAND
                        ${CMAKE_BINARY_DIR}/TestFoundation.app/TestFoundation${CMAKE_EXECUTABLE_SUFFIX}
                      WORKING_DIRECTORY
                        ${CMAKE_BINARY_DIR}/TestFoundation.app
                      DISCOVERY_TIMEOUT
                        30
                      PROPERTIES
                        ENVIRONMENT
                          LD_LIBRARY_PATH=${CMAKE_BINARY_DIR}/TestFoundation.app:$<TARGET_LINKER_FILE_DIR:XCTest>:$<TARGET_LINKER_FILE_DIR:dispatch>:$<TARGET_LINKER_FILE_DIR:swiftDispatch>:$<TARGET_LINKER_FILE_DIR:BlocksRuntime>
                          DLL_LIBRARY_PATH=${Swift_LIBRARY_PATH}?${CMAKE_BINARY_DIR}/bin?$<TARGET_FILE_DIR:XCTest>?$<TARGET_FILE_DIR:dispatch>?$<TARGET_FILE_DIR:swiftDispatch>?$<TARGET_FILE_DIR:BlocksRuntime>)
