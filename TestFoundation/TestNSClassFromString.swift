// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if DEPLOYMENT_RUNTIME_OBJC || os(Linux)
    import Foundation
    import XCTest
#else
    import SwiftFoundation
    import SwiftXCTest
#endif

class TestNSClassFromString : XCTestCase {
    static var allTests: [(String, (TestNSClassFromString) -> () throws -> Void)] {
        return [
            ("test_classNames", test_classNames),
            ("test_classes", test_classes),
        ]
    }
    
    func test_classNames() {
        XCTAssertEqual("NSByteCountFormatter", NSStringFromClass(ByteCountFormatter.self))
        XCTAssertEqual("NSCachedURLResponse", NSStringFromClass(CachedURLResponse.self))
        XCTAssertEqual("NSDateComponentsFormatter", NSStringFromClass(DateComponentsFormatter.self))
        XCTAssertEqual("NSDateFormatter", NSStringFromClass(DateFormatter.self))
        XCTAssertEqual("NSDateIntervalFormatter", NSStringFromClass(DateIntervalFormatter.self))
        XCTAssertEqual("NSDimension", NSStringFromClass(Dimension.self))
        XCTAssertEqual("NSDirectoryEnumerator", NSStringFromClass(FileManager.DirectoryEnumerator.self))
        XCTAssertEqual("NSFileHandle", NSStringFromClass(FileHandle.self))
        XCTAssertEqual("NSFileManager", NSStringFromClass(FileManager.self))
        XCTAssertEqual("NSFormatter", NSStringFromClass(Formatter.self))
        XCTAssertEqual("NSHTTPCookie", NSStringFromClass(HTTPCookie.self))
        XCTAssertEqual("NSHTTPURLResponse", NSStringFromClass(HTTPURLResponse.self))
        XCTAssertEqual("NSISO8601DateFormatter", NSStringFromClass(ISO8601DateFormatter.self))
        XCTAssertEqual("NSJSONSerialization", NSStringFromClass(JSONSerialization.self))
        XCTAssertEqual("NSLengthFormatter", NSStringFromClass(LengthFormatter.self))
        XCTAssertEqual("NSMassFormatter", NSStringFromClass(MassFormatter.self))
        XCTAssertEqual("NSMeasurementFormatter", NSStringFromClass(MeasurementFormatter.self))
        XCTAssertEqual("NSMessagePort", NSStringFromClass(MessagePort.self))
        XCTAssertEqual("NSAffineTransform", NSStringFromClass(NSAffineTransform.self))
        XCTAssertEqual("NSArray", NSStringFromClass(NSArray.self))
        XCTAssertEqual("NSCalendar", NSStringFromClass(NSCalendar.self))
        XCTAssertEqual("NSCharacterSet", NSStringFromClass(NSCharacterSet.self))
        XCTAssertEqual("NSCoder", NSStringFromClass(NSCoder.self))
        XCTAssertEqual("NSComparisonPredicate", NSStringFromClass(NSComparisonPredicate.self))
        XCTAssertEqual("NSCompoundPredicate", NSStringFromClass(NSCompoundPredicate.self))
        XCTAssertEqual("NSConditionLock", NSStringFromClass(NSConditionLock.self))
        XCTAssertEqual("NSCountedSet", NSStringFromClass(NSCountedSet.self))
        XCTAssertEqual("NSData", NSStringFromClass(NSData.self))
        XCTAssertEqual("NSDate", NSStringFromClass(NSDate.self))
        XCTAssertEqual("NSDateComponents", NSStringFromClass(NSDateComponents.self))
        XCTAssertEqual("NSDateInterval", NSStringFromClass(NSDateInterval.self))
        XCTAssertEqual("NSDecimalNumber", NSStringFromClass(NSDecimalNumber.self))
        XCTAssertEqual("NSDecimalNumberHandler", NSStringFromClass(NSDecimalNumberHandler.self))
        XCTAssertEqual("NSDictionary", NSStringFromClass(NSDictionary.self))
        XCTAssertEqual("NSEnumerator", NSStringFromClass(NSEnumerator.self))
        XCTAssertEqual("NSError", NSStringFromClass(NSError.self))
        XCTAssertEqual("NSExpression", NSStringFromClass(NSExpression.self))
        XCTAssertEqual("NSIndexPath", NSStringFromClass(NSIndexPath.self))
        XCTAssertEqual("NSIndexSet", NSStringFromClass(NSIndexSet.self))
        XCTAssertEqual("NSKeyedArchiver", NSStringFromClass(NSKeyedArchiver.self))
        XCTAssertEqual("NSKeyedUnarchiver", NSStringFromClass(NSKeyedUnarchiver.self))
        XCTAssertEqual("NSMeasurement", NSStringFromClass(NSMeasurement.self))
        XCTAssertEqual("NSMutableArray", NSStringFromClass(NSMutableArray.self))
        XCTAssertEqual("NSMutableAttributedString", NSStringFromClass(NSMutableAttributedString.self))
        XCTAssertEqual("NSMutableCharacterSet", NSStringFromClass(NSMutableCharacterSet.self))
        XCTAssertEqual("NSMutableData", NSStringFromClass(NSMutableData.self))
        XCTAssertEqual("NSMutableDictionary", NSStringFromClass(NSMutableDictionary.self))
        XCTAssertEqual("NSMutableIndexSet", NSStringFromClass(NSMutableIndexSet.self))
        XCTAssertEqual("NSMutableOrderedSet", NSStringFromClass(NSMutableOrderedSet.self))
        XCTAssertEqual("NSMutableSet", NSStringFromClass(NSMutableSet.self))
        XCTAssertEqual("NSMutableString", NSStringFromClass(NSMutableString.self))
        XCTAssertEqual("NSMutableURLRequest", NSStringFromClass(NSMutableURLRequest.self))
        XCTAssertEqual("NSNull", NSStringFromClass(NSNull.self))
        XCTAssertEqual("NSNumber", NSStringFromClass(NSNumber.self))
        XCTAssertEqual("NSObject", NSStringFromClass(NSObject.self))
        XCTAssertEqual("NSOrderedSet", NSStringFromClass(NSOrderedSet.self))
        XCTAssertEqual("NSPersonNameComponents", NSStringFromClass(NSPersonNameComponents.self))
        XCTAssertEqual("NSPredicate", NSStringFromClass(NSPredicate.self))
        XCTAssertEqual("NSSet", NSStringFromClass(NSSet.self))
        XCTAssertEqual("NSString", NSStringFromClass(NSString.self))
        XCTAssertEqual("NSTimeZone", NSStringFromClass(NSTimeZone.self))
        XCTAssertEqual("NSURL", NSStringFromClass(NSURL.self))
        XCTAssertEqual("NSURLQueryItem", NSStringFromClass(NSURLQueryItem.self))
        XCTAssertEqual("NSURLRequest", NSStringFromClass(NSURLRequest.self))
        XCTAssertEqual("NSUUID", NSStringFromClass(NSUUID.self))
        XCTAssertEqual("NSValue", NSStringFromClass(NSValue.self))
        XCTAssertEqual("NSNumberFormatter", NSStringFromClass(NumberFormatter.self))
        XCTAssertEqual("NSOperation", NSStringFromClass(Operation.self))
        XCTAssertEqual("NSOutputStream", NSStringFromClass(OutputStream.self))
        XCTAssertEqual("NSPersonNameComponentsFormatter", NSStringFromClass(PersonNameComponentsFormatter.self))
        XCTAssertEqual("NSPort", NSStringFromClass(Port.self))
        XCTAssertEqual("NSPortMessage", NSStringFromClass(PortMessage.self))
        XCTAssertEqual("NSProgress", NSStringFromClass(Progress.self))
        XCTAssertEqual("NSPropertyListSerialization", NSStringFromClass(PropertyListSerialization.self))
        XCTAssertEqual("NSSocketPort", NSStringFromClass(SocketPort.self))
        XCTAssertEqual("NSThread", NSStringFromClass(Thread.self))
        XCTAssertEqual("NSTimer", NSStringFromClass(Timer.self))
        XCTAssertEqual("NSUnit", NSStringFromClass(Unit.self))
        XCTAssertEqual("NSUnitAcceleration", NSStringFromClass(UnitAcceleration.self))
        XCTAssertEqual("NSUnitAngle", NSStringFromClass(UnitAngle.self))
        XCTAssertEqual("NSUnitArea", NSStringFromClass(UnitArea.self))
        XCTAssertEqual("NSUnitConcentrationMass", NSStringFromClass(UnitConcentrationMass.self))
        XCTAssertEqual("NSUnitConverter", NSStringFromClass(UnitConverter.self))
        XCTAssertEqual("NSUnitConverterLinear", NSStringFromClass(UnitConverterLinear.self))
        XCTAssertEqual("NSUnitDispersion", NSStringFromClass(UnitDispersion.self))
        XCTAssertEqual("NSUnitDuration", NSStringFromClass(UnitDuration.self))
        XCTAssertEqual("NSUnitElectricCharge", NSStringFromClass(UnitElectricCharge.self))
        XCTAssertEqual("NSUnitElectricCurrent", NSStringFromClass(UnitElectricCurrent.self))
        XCTAssertEqual("NSUnitElectricPotentialDifference", NSStringFromClass(UnitElectricPotentialDifference.self))
        XCTAssertEqual("NSUnitElectricResistance", NSStringFromClass(UnitElectricResistance.self))
        XCTAssertEqual("NSUnitEnergy", NSStringFromClass(UnitEnergy.self))
        XCTAssertEqual("NSUnitFrequency", NSStringFromClass(UnitFrequency.self))
        XCTAssertEqual("NSUnitFuelEfficiency", NSStringFromClass(UnitFuelEfficiency.self))
        XCTAssertEqual("NSUnitIlluminance", NSStringFromClass(UnitIlluminance.self))
        XCTAssertEqual("NSUnitLength", NSStringFromClass(UnitLength.self))
        XCTAssertEqual("NSUnitMass", NSStringFromClass(UnitMass.self))
        XCTAssertEqual("NSUnitPower", NSStringFromClass(UnitPower.self))
        XCTAssertEqual("NSUnitPressure", NSStringFromClass(UnitPressure.self))
        XCTAssertEqual("NSUnitSpeed", NSStringFromClass(UnitSpeed.self))
        XCTAssertEqual("NSUnitTemperature", NSStringFromClass(UnitTemperature.self))
        XCTAssertEqual("NSUnitVolume", NSStringFromClass(UnitVolume.self))
        XCTAssertEqual("NSURLAuthenticationChallenge", NSStringFromClass(URLAuthenticationChallenge.self))
        XCTAssertEqual("NSURLCache", NSStringFromClass(URLCache.self))
        XCTAssertEqual("NSURLCredential", NSStringFromClass(URLCredential.self))
        XCTAssertEqual("NSURLProtectionSpace", NSStringFromClass(URLProtectionSpace.self))
        XCTAssertEqual("NSURLProtocol", NSStringFromClass(URLProtocol.self))
        XCTAssertEqual("NSURLResponse", NSStringFromClass(URLResponse.self))
        XCTAssertEqual("NSURLSession", NSStringFromClass(URLSession.self))
        XCTAssertEqual("NSURLSessionConfiguration", NSStringFromClass(URLSessionConfiguration.self))
        XCTAssertEqual("NSURLSessionDataTask", NSStringFromClass(URLSessionDataTask.self))
        XCTAssertEqual("NSURLSessionDownloadTask", NSStringFromClass(URLSessionDownloadTask.self))
        XCTAssertEqual("NSURLSessionStreamTask", NSStringFromClass(URLSessionStreamTask.self))
        XCTAssertEqual("NSURLSessionTask", NSStringFromClass(URLSessionTask.self))
        XCTAssertEqual("NSURLSessionUploadTask", NSStringFromClass(URLSessionUploadTask.self))
        XCTAssertEqual("NSXMLDocument", NSStringFromClass(XMLDocument.self))
        XCTAssertEqual("NSXMLDTD", NSStringFromClass(XMLDTD.self))
        XCTAssertEqual("NSXMLParser", NSStringFromClass(XMLParser.self))
    }
    
    func test_classes() {
        func XCTAssertEqualClasses(_ expected: AnyClass?, _ actual: AnyClass?, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
            XCTAssertTrue(expected == actual, message, file: file, line: line)
        }
        
        XCTAssertEqualClasses(ByteCountFormatter.self, NSClassFromString("NSByteCountFormatter"))
        XCTAssertEqualClasses(CachedURLResponse.self, NSClassFromString("NSCachedURLResponse"))
        XCTAssertEqualClasses(DateComponentsFormatter.self, NSClassFromString("NSDateComponentsFormatter"))
        XCTAssertEqualClasses(DateFormatter.self, NSClassFromString("NSDateFormatter"))
        XCTAssertEqualClasses(DateIntervalFormatter.self, NSClassFromString("NSDateIntervalFormatter"))
        XCTAssertEqualClasses(Dimension.self, NSClassFromString("NSDimension"))
        XCTAssertEqualClasses(FileManager.DirectoryEnumerator.self, NSClassFromString("NSDirectoryEnumerator"))
        XCTAssertEqualClasses(FileHandle.self, NSClassFromString("NSFileHandle"))
        XCTAssertEqualClasses(FileManager.self, NSClassFromString("NSFileManager"))
        XCTAssertEqualClasses(Formatter.self, NSClassFromString("NSFormatter"))
        XCTAssertEqualClasses(HTTPCookie.self, NSClassFromString("NSHTTPCookie"))
        XCTAssertEqualClasses(HTTPURLResponse.self, NSClassFromString("NSHTTPURLResponse"))
        XCTAssertEqualClasses(ISO8601DateFormatter.self, NSClassFromString("NSISO8601DateFormatter"))
        XCTAssertEqualClasses(JSONSerialization.self, NSClassFromString("NSJSONSerialization"))
        XCTAssertEqualClasses(LengthFormatter.self, NSClassFromString("NSLengthFormatter"))
        XCTAssertEqualClasses(MassFormatter.self, NSClassFromString("NSMassFormatter"))
        XCTAssertEqualClasses(MeasurementFormatter.self, NSClassFromString("NSMeasurementFormatter"))
        XCTAssertEqualClasses(MessagePort.self, NSClassFromString("NSMessagePort"))
        XCTAssertEqualClasses(NSAffineTransform.self, NSClassFromString("NSAffineTransform"))
        XCTAssertEqualClasses(NSArray.self, NSClassFromString("NSArray"))
        XCTAssertEqualClasses(NSCalendar.self, NSClassFromString("NSCalendar"))
        XCTAssertEqualClasses(NSCharacterSet.self, NSClassFromString("NSCharacterSet"))
        XCTAssertEqualClasses(NSCoder.self, NSClassFromString("NSCoder"))
        XCTAssertEqualClasses(NSComparisonPredicate.self, NSClassFromString("NSComparisonPredicate"))
        XCTAssertEqualClasses(NSCompoundPredicate.self, NSClassFromString("NSCompoundPredicate"))
        XCTAssertEqualClasses(NSConditionLock.self, NSClassFromString("NSConditionLock"))
        XCTAssertEqualClasses(NSCountedSet.self, NSClassFromString("NSCountedSet"))
        XCTAssertEqualClasses(NSData.self, NSClassFromString("NSData"))
        XCTAssertEqualClasses(NSDate.self, NSClassFromString("NSDate"))
        XCTAssertEqualClasses(NSDateComponents.self, NSClassFromString("NSDateComponents"))
        XCTAssertEqualClasses(NSDateInterval.self, NSClassFromString("NSDateInterval"))
        XCTAssertEqualClasses(NSDecimalNumber.self, NSClassFromString("NSDecimalNumber"))
        XCTAssertEqualClasses(NSDecimalNumberHandler.self, NSClassFromString("NSDecimalNumberHandler"))
        XCTAssertEqualClasses(NSDictionary.self, NSClassFromString("NSDictionary"))
        XCTAssertEqualClasses(NSEnumerator.self, NSClassFromString("NSEnumerator"))
        XCTAssertEqualClasses(NSError.self, NSClassFromString("NSError"))
        XCTAssertEqualClasses(NSExpression.self, NSClassFromString("NSExpression"))
        XCTAssertEqualClasses(NSIndexPath.self, NSClassFromString("NSIndexPath"))
        XCTAssertEqualClasses(NSIndexSet.self, NSClassFromString("NSIndexSet"))
        XCTAssertEqualClasses(NSKeyedArchiver.self, NSClassFromString("NSKeyedArchiver"))
        XCTAssertEqualClasses(NSKeyedUnarchiver.self, NSClassFromString("NSKeyedUnarchiver"))
        XCTAssertEqualClasses(NSMeasurement.self, NSClassFromString("NSMeasurement"))
        XCTAssertEqualClasses(NSMutableArray.self, NSClassFromString("NSMutableArray"))
        XCTAssertEqualClasses(NSMutableAttributedString.self, NSClassFromString("NSMutableAttributedString"))
        XCTAssertEqualClasses(NSMutableCharacterSet.self, NSClassFromString("NSMutableCharacterSet"))
        XCTAssertEqualClasses(NSMutableData.self, NSClassFromString("NSMutableData"))
        XCTAssertEqualClasses(NSMutableDictionary.self, NSClassFromString("NSMutableDictionary"))
        XCTAssertEqualClasses(NSMutableIndexSet.self, NSClassFromString("NSMutableIndexSet"))
        XCTAssertEqualClasses(NSMutableOrderedSet.self, NSClassFromString("NSMutableOrderedSet"))
        XCTAssertEqualClasses(NSMutableSet.self, NSClassFromString("NSMutableSet"))
        XCTAssertEqualClasses(NSMutableString.self, NSClassFromString("NSMutableString"))
        XCTAssertEqualClasses(NSMutableURLRequest.self, NSClassFromString("NSMutableURLRequest"))
        XCTAssertEqualClasses(NSNull.self, NSClassFromString("NSNull"))
        XCTAssertEqualClasses(NSNumber.self, NSClassFromString("NSNumber"))
        XCTAssertEqualClasses(NSObject.self, NSClassFromString("NSObject"))
        XCTAssertEqualClasses(NSOrderedSet.self, NSClassFromString("NSOrderedSet"))
        XCTAssertEqualClasses(NSPersonNameComponents.self, NSClassFromString("NSPersonNameComponents"))
        XCTAssertEqualClasses(NSPredicate.self, NSClassFromString("NSPredicate"))
        XCTAssertEqualClasses(NSSet.self, NSClassFromString("NSSet"))
        XCTAssertEqualClasses(NSString.self, NSClassFromString("NSString"))
        XCTAssertEqualClasses(NSTimeZone.self, NSClassFromString("NSTimeZone"))
        XCTAssertEqualClasses(NSURL.self, NSClassFromString("NSURL"))
        XCTAssertEqualClasses(NSURLQueryItem.self, NSClassFromString("NSURLQueryItem"))
        XCTAssertEqualClasses(NSURLRequest.self, NSClassFromString("NSURLRequest"))
        XCTAssertEqualClasses(NSUUID.self, NSClassFromString("NSUUID"))
        XCTAssertEqualClasses(NSValue.self, NSClassFromString("NSValue"))
        XCTAssertEqualClasses(NumberFormatter.self, NSClassFromString("NSNumberFormatter"))
        XCTAssertEqualClasses(Operation.self, NSClassFromString("NSOperation"))
        XCTAssertEqualClasses(OutputStream.self, NSClassFromString("NSOutputStream"))
        XCTAssertEqualClasses(PersonNameComponentsFormatter.self, NSClassFromString("NSPersonNameComponentsFormatter"))
        XCTAssertEqualClasses(Port.self, NSClassFromString("NSPort"))
        XCTAssertEqualClasses(PortMessage.self, NSClassFromString("NSPortMessage"))
        XCTAssertEqualClasses(Progress.self, NSClassFromString("NSProgress"))
        XCTAssertEqualClasses(PropertyListSerialization.self, NSClassFromString("NSPropertyListSerialization"))
        XCTAssertEqualClasses(SocketPort.self, NSClassFromString("NSSocketPort"))
        XCTAssertEqualClasses(Thread.self, NSClassFromString("NSThread"))
        XCTAssertEqualClasses(Timer.self, NSClassFromString("NSTimer"))
        XCTAssertEqualClasses(Unit.self, NSClassFromString("NSUnit"))
        XCTAssertEqualClasses(UnitAcceleration.self, NSClassFromString("NSUnitAcceleration"))
        XCTAssertEqualClasses(UnitAngle.self, NSClassFromString("NSUnitAngle"))
        XCTAssertEqualClasses(UnitArea.self, NSClassFromString("NSUnitArea"))
        XCTAssertEqualClasses(UnitConcentrationMass.self, NSClassFromString("NSUnitConcentrationMass"))
        XCTAssertEqualClasses(UnitConverter.self, NSClassFromString("NSUnitConverter"))
        XCTAssertEqualClasses(UnitConverterLinear.self, NSClassFromString("NSUnitConverterLinear"))
        XCTAssertEqualClasses(UnitDispersion.self, NSClassFromString("NSUnitDispersion"))
        XCTAssertEqualClasses(UnitDuration.self, NSClassFromString("NSUnitDuration"))
        XCTAssertEqualClasses(UnitElectricCharge.self, NSClassFromString("NSUnitElectricCharge"))
        XCTAssertEqualClasses(UnitElectricCurrent.self, NSClassFromString("NSUnitElectricCurrent"))
        XCTAssertEqualClasses(UnitElectricPotentialDifference.self, NSClassFromString("NSUnitElectricPotentialDifference"))
        XCTAssertEqualClasses(UnitElectricResistance.self, NSClassFromString("NSUnitElectricResistance"))
        XCTAssertEqualClasses(UnitEnergy.self, NSClassFromString("NSUnitEnergy"))
        XCTAssertEqualClasses(UnitFrequency.self, NSClassFromString("NSUnitFrequency"))
        XCTAssertEqualClasses(UnitFuelEfficiency.self, NSClassFromString("NSUnitFuelEfficiency"))
        XCTAssertEqualClasses(UnitIlluminance.self, NSClassFromString("NSUnitIlluminance"))
        XCTAssertEqualClasses(UnitLength.self, NSClassFromString("NSUnitLength"))
        XCTAssertEqualClasses(UnitMass.self, NSClassFromString("NSUnitMass"))
        XCTAssertEqualClasses(UnitPower.self, NSClassFromString("NSUnitPower"))
        XCTAssertEqualClasses(UnitPressure.self, NSClassFromString("NSUnitPressure"))
        XCTAssertEqualClasses(UnitSpeed.self, NSClassFromString("NSUnitSpeed"))
        XCTAssertEqualClasses(UnitTemperature.self, NSClassFromString("NSUnitTemperature"))
        XCTAssertEqualClasses(UnitVolume.self, NSClassFromString("NSUnitVolume"))
        XCTAssertEqualClasses(URLAuthenticationChallenge.self, NSClassFromString("NSURLAuthenticationChallenge"))
        XCTAssertEqualClasses(URLCache.self, NSClassFromString("NSURLCache"))
        XCTAssertEqualClasses(URLCredential.self, NSClassFromString("NSURLCredential"))
        XCTAssertEqualClasses(URLProtectionSpace.self, NSClassFromString("NSURLProtectionSpace"))
        XCTAssertEqualClasses(URLProtocol.self, NSClassFromString("NSURLProtocol"))
        XCTAssertEqualClasses(URLResponse.self, NSClassFromString("NSURLResponse"))
        XCTAssertEqualClasses(URLSession.self, NSClassFromString("NSURLSession"))
        XCTAssertEqualClasses(URLSessionConfiguration.self, NSClassFromString("NSURLSessionConfiguration"))
        XCTAssertEqualClasses(URLSessionDataTask.self, NSClassFromString("NSURLSessionDataTask"))
        XCTAssertEqualClasses(URLSessionDownloadTask.self, NSClassFromString("NSURLSessionDownloadTask"))
        XCTAssertEqualClasses(URLSessionStreamTask.self, NSClassFromString("NSURLSessionStreamTask"))
        XCTAssertEqualClasses(URLSessionTask.self, NSClassFromString("NSURLSessionTask"))
        XCTAssertEqualClasses(URLSessionUploadTask.self, NSClassFromString("NSURLSessionUploadTask"))
        XCTAssertEqualClasses(XMLDocument.self, NSClassFromString("NSXMLDocument"))
        XCTAssertEqualClasses(XMLDTD.self, NSClassFromString("NSXMLDTD"))
        XCTAssertEqualClasses(XMLParser.self, NSClassFromString("NSXMLParser"))
    }
}
