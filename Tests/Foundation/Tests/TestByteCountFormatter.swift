// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestByteCountFormatter : XCTestCase {
    
    func test_DefaultValues() {
        let formatter = ByteCountFormatter()
        XCTAssertEqual(formatter.allowedUnits, [])
        XCTAssertEqual(formatter.countStyle, ByteCountFormatter.CountStyle.file)
        XCTAssertEqual(formatter.allowsNonnumericFormatting, true)
        XCTAssertEqual(formatter.includesUnit, true)
        XCTAssertEqual(formatter.includesCount, true)
        XCTAssertEqual(formatter.includesActualByteCount, false)
        XCTAssertEqual(formatter.isAdaptive, true)
        XCTAssertEqual(formatter.zeroPadsFractionDigits, false)
        XCTAssertEqual(formatter.formattingContext, Formatter.Context.unknown)
    }
    
    func test_zeroBytes() {
        let formatter = ByteCountFormatter()
        
        XCTAssertEqual(formatter.string(fromByteCount: 0), "Zero KB")
        
        formatter.allowedUnits = .useGB
        XCTAssertEqual(formatter.string(fromByteCount: 0), "Zero KB")
        
        formatter.allowedUnits = []
        formatter.allowsNonnumericFormatting = false
        XCTAssertEqual(formatter.string(fromByteCount: 0), "0 bytes")
        
        formatter.allowedUnits = .useGB
        XCTAssertEqual(formatter.string(fromByteCount: 0), "0 GB")
    }
    
    func test_oneByte() {
        let formatter = ByteCountFormatter()
        
        XCTAssertEqual(formatter.string(fromByteCount: 1), "1 byte")
        
        formatter.allowedUnits = .useKB
        XCTAssertEqual(formatter.string(fromByteCount: 1), "0 KB")
        
        let unitsToUse: ByteCountFormatter.Units = [.useKB, .useGB]
        formatter.allowedUnits = unitsToUse
        XCTAssertEqual(formatter.string(fromByteCount: 1), "0 KB")
        
        formatter.allowedUnits = .useGB
        XCTAssertEqual(formatter.string(fromByteCount: 1), "0 GB")
        
        formatter.allowedUnits = []
        formatter.isAdaptive = false
        XCTAssertEqual(formatter.string(fromByteCount: 1), "1 byte")
        
        formatter.allowedUnits = .useKB
        XCTAssertEqual(formatter.string(fromByteCount: 1), "0.001 KB")
        
        formatter.allowedUnits = unitsToUse
        XCTAssertEqual(formatter.string(fromByteCount: 1), "0.001 KB")
        
        formatter.allowedUnits = .useGB
        XCTAssertEqual(formatter.string(fromByteCount: 1), "0.000000001 GB")
        
    }
    
    func test_allowedUnitsKBGB() {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useGB]
        
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "550,000 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000), "5.5 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000), "55 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000), "550 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000), "5,500 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000), "55,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000000), "550,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000000), "5,500,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000000), "55,000,000 GB")
    }
    
    func test_allowedUnitsMBGB() {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "550 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000), "5.5 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000), "55 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000), "550 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000), "5,500 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000), "55,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000000), "550,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000000), "5,500,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000000), "55,000,000 GB")
    }
    
    func test_adaptiveFalseAllowedUnitsKBMBGB() {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.isAdaptive = false
        XCTAssertEqual(formatter.string(fromByteCount: 55), "0.055 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 550), "0.55 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500), "5.5 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000), "55 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000), "550 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000), "5.5 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000), "55 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "550 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000), "5.5 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000), "55 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000), "550 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000), "5,500 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000), "55,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000000), "550,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000000), "5,500,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000000), "55,000,000 GB")
    }
    
    func test_allowedUnitsKBMBGB() {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        XCTAssertEqual(formatter.string(fromByteCount: 55), "0 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 550), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500), "6 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000), "55 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000), "550 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000), "5.5 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000), "55 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "550 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000), "5.5 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000), "55 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000), "550 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000), "5,500 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000), "55,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000000), "550,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000000), "5,500,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000000), "55,000,000 GB")
    }
    
    func test_allowedUnitsBytesGB() {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useGB]
        XCTAssertEqual(formatter.string(fromByteCount: 55), "55 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 550), "550 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 5500), "5,500 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 55000), "55,000 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 550000), "550,000 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000), "5,500,000 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000), "55,000,000 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "550,000,000 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000), "5.5 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000), "55 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000), "550 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000), "5,500 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000), "55,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000000), "550,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000000), "5,500,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000000), "55,000,000 GB")
    }
    func test_allowedUnitsGB() {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useGB
        XCTAssertEqual(formatter.string(fromByteCount: 55), "0 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550), "0 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500), "0 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000), "0 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000), "0 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000), "0.01 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000), "0.06 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "0.55 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000), "5.5 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000), "55 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000), "550 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000), "5,500 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000), "55,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000000), "550,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000000), "5,500,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000000), "55,000,000 GB")
    }
    func test_adaptiveFalseAllowedUnitsGB() {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useGB
        formatter.isAdaptive = false
        XCTAssertEqual(formatter.string(fromByteCount: 55), "0.000000055 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550), "0.00000055 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500), "0.0000055 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000), "0.000055 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000), "0.00055 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000), "0.0055 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000), "0.055 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "0.55 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000), "5.5 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000), "55 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000), "550 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000), "5,500 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000), "55,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000000000), "550,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 5500000000000000), "5,500,000 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 55000000000000000), "55,000,000 GB")
    }
    
    func test_numberOnly() {
        let formatter = ByteCountFormatter()
        formatter.includesUnit = false
        
        XCTAssertEqual(formatter.string(fromByteCount: 0), "0")
        XCTAssertEqual(formatter.string(fromByteCount: 1), "1")
        XCTAssertEqual(formatter.string(fromByteCount: -1), "-1")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "550")
        
        formatter.allowedUnits = .useYBOrHigher
        XCTAssertEqual(formatter.string(fromByteCount: 0), "0")
        XCTAssertEqual(formatter.string(fromByteCount: 1), "0")
        
        formatter.allowedUnits = .useKB
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "550,000")
        
        formatter.allowedUnits = [.useKB, .useGB]
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "550,000")
        
        formatter.allowedUnits = .useGB
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "0.55")
        
        formatter.allowedUnits = [.useMB, .useGB]
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "550")
    }
    
    func test_unitOnly() {
        let formatter = ByteCountFormatter()
        formatter.includesCount = false
        
        XCTAssertEqual(formatter.string(fromByteCount: 0), "bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 1), "byte")
        XCTAssertEqual(formatter.string(fromByteCount: -1), "byte")
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "MB")
        
        formatter.allowedUnits = .useYBOrHigher
        XCTAssertEqual(formatter.string(fromByteCount: 0), "YB")
        XCTAssertEqual(formatter.string(fromByteCount: 1), "YB")
        
        formatter.allowedUnits = .useKB
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "KB")
        
        formatter.allowedUnits = [.useKB, .useGB]
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "KB")
        
        formatter.allowedUnits = .useGB
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "GB")
        
        formatter.allowedUnits = [.useMB, .useGB]
        XCTAssertEqual(formatter.string(fromByteCount: 550000000), "MB")
    }
    
    func test_isAdaptiveFalse() {
        let formatter = ByteCountFormatter()
        formatter.isAdaptive = false
        
        XCTAssertEqual(formatter.string(fromByteCount: 499), "499 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 900), "900 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 999), "999 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 1000), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1023), "1.02 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1024), "1.02 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 11999), "12 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 900000), "900 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678), "12.3 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 123456789), "123 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 1234567898), "1.23 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678987), "12.3 GB")
    }
    
    func test_isAdaptiveTrue() {
        let formatter = ByteCountFormatter()
        
        XCTAssertEqual(formatter.string(fromByteCount: 499), "499 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 900), "900 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 999), "999 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 1000), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1023), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1024), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 11999), "12 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 900000), "900 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678), "12.3 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 123456789), "123.5 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 1234567898), "1.23 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678987), "12.35 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 999900000), "999.9 MB")
    }
    
    func test_zeroPadsFractionDigitsTrue() {
        let formatter = ByteCountFormatter()
        formatter.zeroPadsFractionDigits = true
        
        XCTAssertEqual(formatter.string(fromByteCount: 1), "1 byte")
        XCTAssertEqual(formatter.string(fromByteCount: 12), "12 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 499), "499 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 900), "900 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 999), "999 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 1000), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1023), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1024), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 11999), "12 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 900000), "900 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678), "12.3 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 123456789), "123.5 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 1234567898), "1.23 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678987), "12.35 GB")
    }
    
    func test_isAdaptiveFalseZeroPadsFractionDigitsTrue() {
        let formatter = ByteCountFormatter()
        formatter.zeroPadsFractionDigits = true
        formatter.isAdaptive = false
        
        XCTAssertEqual(formatter.string(fromByteCount: 1), "1 byte")
        XCTAssertEqual(formatter.string(fromByteCount: 12), "12 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 499), "499 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 900), "900 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 999), "999 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 1000), "1.00 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1023), "1.02 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1024), "1.02 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 11999), "12.0 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 900000), "900 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678), "12.3 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 123456789), "123 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 1234567898), "1.23 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678987), "12.3 GB")
    }
    
    func test_countStyleDecimal() {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        
        XCTAssertEqual(formatter.string(fromByteCount: 499), "499 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 900), "900 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 999), "999 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 1000), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1023), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 1024), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 11999), "12 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 900000), "900 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678), "12.3 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 123456789), "123.5 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 1234567898), "1.23 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678987), "12.35 GB")
    }
    
    func test_countStyleBinary() {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        
        XCTAssertEqual(formatter.string(fromByteCount: 499), "499 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 900), "900 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 999), "999 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 1000), "1,000 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 1023), "1,023 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: 1024), "1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 11999), "12 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 900000), "879 KB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678), "11.8 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 123456789), "117.7 MB")
        XCTAssertEqual(formatter.string(fromByteCount: 1234567898), "1.15 GB")
        XCTAssertEqual(formatter.string(fromByteCount: 12345678987), "11.5 GB")
    }
    
    func test_largeByteValues() {
        let formatter = ByteCountFormatter()
        
        formatter.allowedUnits = .useTB
        XCTAssertEqual(formatter.string(fromByteCount: 9223372036854775807), "9,223,372.04 TB")
        
        formatter.allowedUnits = .useEB
        XCTAssertEqual(formatter.string(fromByteCount: 9223372036854775807), "9.22 EB")
        
        formatter.allowedUnits = .useZB
        XCTAssertEqual(formatter.string(fromByteCount: 9223372036854775807), "0.01 ZB")
        
        formatter.allowedUnits = .useYBOrHigher
        XCTAssertEqual(formatter.string(fromByteCount: 9223372036854775807), "0 YB")
        
        formatter.allowedUnits = .useBytes
        XCTAssertEqual(formatter.string(fromByteCount: 0x7FFFFFFFFFFFFFFF), "9,223,372,036,854,775,807 bytes")
        
        formatter.isAdaptive = false
        formatter.allowedUnits = .useTB
        XCTAssertEqual(formatter.string(fromByteCount: 9223372036854775807), "9,223,372 TB")
        
        formatter.allowedUnits = .useEB
        XCTAssertEqual(formatter.string(fromByteCount: 9223372036854775807), "9.22 EB")
        
        formatter.allowedUnits = .useZB
        XCTAssertEqual(formatter.string(fromByteCount: 9223372036854775807), "0.00922 ZB")
        
        formatter.allowedUnits = .useYBOrHigher
        XCTAssertEqual(formatter.string(fromByteCount: 9223372036854775807), "0.00000922 YB")
    }
    
    func test_negativeByteValues() {
        let formatter = ByteCountFormatter()
        
        XCTAssertEqual(formatter.string(fromByteCount: -1), "-1 byte")
        XCTAssertEqual(formatter.string(fromByteCount: -2), "-2 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: -1023), "-1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: -1234567898), "-1.23 GB")
        XCTAssertEqual(formatter.string(fromByteCount: -12345678987), "-12.35 GB")
        
        formatter.countStyle = .binary
        XCTAssertEqual(formatter.string(fromByteCount: -999), "-999 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: -1000), "-1,000 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: -1023), "-1,023 bytes")
        XCTAssertEqual(formatter.string(fromByteCount: -1024), "-1 KB")
        XCTAssertEqual(formatter.string(fromByteCount: -12345678987), "-11.5 GB")
        
        formatter.allowedUnits = .useGB
        formatter.countStyle = .file
        XCTAssertEqual(formatter.string(fromByteCount: -1), "-0 GB")
        XCTAssertEqual(formatter.string(fromByteCount: -5000), "-0 GB")
        XCTAssertEqual(formatter.string(fromByteCount: -50000), "-0 GB")
        XCTAssertEqual(formatter.string(fromByteCount: -500000), "-0 GB")
        XCTAssertEqual(formatter.string(fromByteCount: -5000000), "-0.01 GB")
        XCTAssertEqual(formatter.string(fromByteCount: -50000000), "-0.05 GB")
        XCTAssertEqual(formatter.string(fromByteCount: -500000000), "-0.5 GB")
        
        formatter.allowedUnits = .useTB
        XCTAssertEqual(formatter.string(fromByteCount: Int64.min), "-9,223,372.04 TB")
        
        formatter.allowedUnits = .useEB
        XCTAssertEqual(formatter.string(fromByteCount: Int64.min), "-9.22 EB")
        
        formatter.allowedUnits = .useZB
        XCTAssertEqual(formatter.string(fromByteCount: Int64.min), "-0.01 ZB")
        
        formatter.allowedUnits = .useYBOrHigher
        XCTAssertEqual(formatter.string(fromByteCount: Int64.min), "-0 YB")
    }
    
    func test_unarchivingFixtures() throws {
        for fixture in [Fixtures.byteCountFormatterDefault, Fixtures.byteCountFormatterAllFieldsSet] {
            let expectation = try fixture.make()
            try fixture.loadEach { (formatter, variant) in
                XCTAssertEqual(formatter.allowedUnits,               expectation.allowedUnits)
                XCTAssertEqual(formatter.countStyle,                 expectation.countStyle)
                XCTAssertEqual(formatter.formattingContext,          expectation.formattingContext)
                XCTAssertEqual(formatter.zeroPadsFractionDigits,     expectation.zeroPadsFractionDigits)
                XCTAssertEqual(formatter.includesActualByteCount,    expectation.includesActualByteCount)
                XCTAssertEqual(formatter.allowsNonnumericFormatting, expectation.allowsNonnumericFormatting)
                XCTAssertEqual(formatter.includesUnit,               expectation.includesUnit)
                XCTAssertEqual(formatter.includesCount,              expectation.includesCount)
                XCTAssertEqual(formatter.isAdaptive,                 expectation.isAdaptive)
            }
        }
    }

    func test_copy() throws {
        let original = ByteCountFormatter()
        original.allowedUnits = .useAll
        original.countStyle = .decimal
        original.allowsNonnumericFormatting = false
        original.includesUnit = false
        original.includesCount = false
        original.includesActualByteCount = true
        original.isAdaptive = false
        original.zeroPadsFractionDigits = true
        original.formattingContext = .dynamic

        let copied = try XCTUnwrap(original.copy() as? ByteCountFormatter)
        XCTAssertEqual(original.allowedUnits, copied.allowedUnits)
        XCTAssertEqual(original.countStyle, copied.countStyle)
        XCTAssertEqual(original.allowsNonnumericFormatting, copied.allowsNonnumericFormatting)
        XCTAssertEqual(original.includesUnit, copied.includesUnit)
        XCTAssertEqual(original.includesCount, copied.includesCount)
        XCTAssertEqual(original.includesActualByteCount, copied.includesActualByteCount)
        XCTAssertEqual(original.isAdaptive, copied.isAdaptive)
        XCTAssertEqual(original.zeroPadsFractionDigits, copied.zeroPadsFractionDigits)
        XCTAssertEqual(original.formattingContext, copied.formattingContext)

        copied.allowedUnits = .useBytes
        copied.countStyle = .binary
        copied.allowsNonnumericFormatting = true
        copied.includesUnit = true
        copied.includesCount = true
        copied.includesActualByteCount = false
        copied.isAdaptive = true
        copied.zeroPadsFractionDigits = false
        copied.formattingContext = .standalone

        XCTAssertNotEqual(original.allowedUnits, copied.allowedUnits)
        XCTAssertNotEqual(original.countStyle, copied.countStyle)
        XCTAssertNotEqual(original.allowsNonnumericFormatting, copied.allowsNonnumericFormatting)
        XCTAssertNotEqual(original.includesUnit, copied.includesUnit)
        XCTAssertNotEqual(original.includesCount, copied.includesCount)
        XCTAssertNotEqual(original.includesActualByteCount, copied.includesActualByteCount)
        XCTAssertNotEqual(original.isAdaptive, copied.isAdaptive)
        XCTAssertNotEqual(original.zeroPadsFractionDigits, copied.zeroPadsFractionDigits)
        XCTAssertNotEqual(original.formattingContext, copied.formattingContext)
    }

    static var allTests: [(String, (TestByteCountFormatter) -> () throws -> Void)] {
        return [
            ("test_DefaultValues", test_DefaultValues),
            ("test_zeroBytes", test_zeroBytes),
            ("test_oneByte", test_oneByte),
            ("test_allowedUnitsKBGB", test_allowedUnitsKBGB),
            ("test_allowedUnitsMBGB", test_allowedUnitsMBGB),
            ("test_adaptiveFalseAllowedUnitsKBMBGB", test_adaptiveFalseAllowedUnitsKBMBGB),
            ("test_allowedUnitsKBMBGB", test_allowedUnitsKBMBGB),
            ("test_allowedUnitsBytesGB", test_allowedUnitsBytesGB),
            ("test_allowedUnitsGB", test_allowedUnitsGB),
            ("test_adaptiveFalseAllowedUnitsGB", test_adaptiveFalseAllowedUnitsGB),
            ("test_numberOnly", test_numberOnly),
            ("test_unitOnly", test_unitOnly),
            ("test_isAdaptiveFalse", test_isAdaptiveFalse),
            ("test_isAdaptiveTrue", test_isAdaptiveTrue),
            ("test_zeroPadsFractionDigitsTrue", test_zeroPadsFractionDigitsTrue),
            ("test_isAdaptiveFalseZeroPadsFractionDigitsTrue", test_isAdaptiveFalseZeroPadsFractionDigitsTrue),
            ("test_countStyleDecimal", test_countStyleDecimal),
            ("test_countStyleBinary", test_countStyleBinary),
            ("test_largeByteValues", test_largeByteValues),
            ("test_negativeByteValues", test_negativeByteValues),
            ("test_unarchivingFixtures", test_unarchivingFixtures),
            ("test_copy", test_copy),
        ]
    }
    
}
