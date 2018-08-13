// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

class TestNSArray : XCTestCase {
    
    static var allTests: [(String, (TestNSArray) -> () throws -> Void)] {
        return [
            ("test_BasicConstruction", test_BasicConstruction),
            ("test_constructors", test_constructors),
            ("test_constructorWithCopyItems", test_constructorWithCopyItems),
            ("test_enumeration", test_enumeration),
            ("test_enumerationUsingBlock", test_enumerationUsingBlock),
            ("test_sequenceType", test_sequenceType),
            ("test_objectAtIndex", test_objectAtIndex),
            ("test_binarySearch", test_binarySearch),
            ("test_binarySearchFringeCases", test_binarySearchFringeCases),
            ("test_replaceObjectsInRange_withObjectsFrom", test_replaceObjectsInRange_withObjectsFrom),
            ("test_replaceObjectsInRange_withObjectsFrom_range", test_replaceObjectsInRange_withObjectsFrom_range),
            ("test_replaceObjectAtIndex", test_replaceObjectAtIndex),
            ("test_removeObjectsInArray", test_removeObjectsInArray),
            ("test_sortedArrayUsingComparator", test_sortedArrayUsingComparator),
            ("test_sortedArrayWithOptionsUsingComparator", test_sortedArrayWithOptionsUsingComparator),
            ("test_arrayReplacement", test_arrayReplacement),
            ("test_arrayReplaceObjectsInRangeFromRange", test_arrayReplaceObjectsInRangeFromRange),
            ("test_sortUsingFunction", test_sortUsingFunction),
            ("test_sortUsingComparator", test_sortUsingComparator),
            ("test_equality", test_equality),
            ("test_AnyHashable", test_AnyHashable),
            ("test_copying", test_copying),
            ("test_mutableCopying", test_mutableCopying),
            ("test_writeToFile", test_writeToFile),
            ("test_initWithContentsOfFile", test_initWithContentsOfFile),
            ("test_initMutableWithContentsOfFile", test_initMutableWithContentsOfFile),
            ("test_initMutableWithContentsOfURL", test_initMutableWithContentsOfURL),
            ("test_readWriteURL", test_readWriteURL),
            ("test_insertObjectAtIndex", test_insertObjectAtIndex),
            ("test_insertObjectsAtIndexes", test_insertObjectsAtIndexes),
            ("test_replaceObjectsAtIndexesWithObjects", test_replaceObjectsAtIndexesWithObjects),
            ("test_pathsMatchingExtensions", test_pathsMatchingExtensions),
        ]
    }
    
    func test_BasicConstruction() {
        let array = NSArray()
        let array2 : NSArray = ["foo", "bar"]
        XCTAssertEqual(array.count, 0)
        XCTAssertEqual(array2.count, 2)
    }

    func test_constructors() {
        let arrayNil = NSArray(objects: nil, count: 0)
        XCTAssertEqual(arrayNil.count, 0)

        let array1 = NSArray(object: "foo")
        XCTAssertEqual(array1.count, 1)

        let testStrings: [AnyObject] = [NSString(string:"foo"), NSString(string: "bar")]
        testStrings.withUnsafeBufferPointer { ptr in
            let array2 = NSArray(objects: ptr.baseAddress, count: 1)
            XCTAssertEqual(array1, array2)
        }

        let array3 = NSArray(objects: "foo" as NSString, "bar" as NSString, "baz" as NSString)
        XCTAssertEqual(array3.count, 3)
        let array4 = NSArray(array: ["foo", "bar", "baz"])
        XCTAssertEqual(array4.count, 3)
        let array5 = NSArray(arrayLiteral: "foo", "bar", "baz")
        XCTAssertEqual(array5.count, 3)
        XCTAssertEqual(array3, array4)
        XCTAssertEqual(array3, array5)
        XCTAssertEqual(array4, array5)

    }

    func test_constructorWithCopyItems() {
        let foo = "foo" as NSMutableString

        let array1 = NSArray(array: [foo], copyItems: false)
        let array2 = NSArray(array: [foo], copyItems: true)

        XCTAssertEqual(array1[0] as! String, "foo")
        XCTAssertEqual(array2[0] as! String, "foo")
        foo.append("1")
        XCTAssertEqual(array1[0] as! String, "foo1")
        XCTAssertEqual(array2[0] as! String, "foo")
    }
    
    func test_enumeration() {
        let array : NSArray = ["foo", "bar", "baz"]
        let e = array.objectEnumerator()
        XCTAssertEqual((e.nextObject() as! String), "foo")
        XCTAssertEqual((e.nextObject() as! String), "bar")
        XCTAssertEqual((e.nextObject() as! String), "baz")
        XCTAssertNil(e.nextObject())
        XCTAssertNil(e.nextObject())
        
        let r = array.reverseObjectEnumerator()
        XCTAssertEqual((r.nextObject() as! String), "baz")
        XCTAssertEqual((r.nextObject() as! String), "bar")
        XCTAssertEqual((r.nextObject() as! String), "foo")
        XCTAssertNil(r.nextObject())
        XCTAssertNil(r.nextObject())
        
        let empty = NSArray().objectEnumerator()
        XCTAssertNil(empty.nextObject())
        XCTAssertNil(empty.nextObject())
        
        let reverseEmpty = NSArray().reverseObjectEnumerator()
        XCTAssertNil(reverseEmpty.nextObject())
        XCTAssertNil(reverseEmpty.nextObject())
    }
    
    func test_enumerationUsingBlock() {
        let array : NSArray = NSArray(array: Array(0..<100))
        let createIndexesArrayHavingSeen = { (havingSeen: IndexSet) in
            return (0 ..< array.count).map { havingSeen.contains($0) }
        }
        
        let noIndexes = IndexSet()
        let allIndexes = IndexSet(integersIn: 0 ..< array.count)
        let firstHalfOfIndexes = IndexSet(integersIn: 0 ..< array.count / 2)
        let lastHalfOfIndexes = IndexSet(integersIn: array.count / 2 ..< array.count)
        let evenIndexes : IndexSet = {
            var indexes = IndexSet()
            for index in allIndexes.filter({ $0 % 2 == 0 }) {
                indexes.insert(index)
            }
            return indexes
        }()
        
        let testExpectingToSee = { (expectation: IndexSet, block: (inout UnsafeMutableBufferPointer<Bool>) -> Void) in
            var indexesSeen = createIndexesArrayHavingSeen(noIndexes)
            indexesSeen.withUnsafeMutableBufferPointer(block)
            XCTAssertEqual(indexesSeen, createIndexesArrayHavingSeen(expectation))
        }
        
        // Test enumerateObjects(_:), allowing it to run to completion...
        
        testExpectingToSee(allIndexes) { (indexesSeen) in
            array.enumerateObjects { (value, index, stop) in
                XCTAssertEqual(value as! NSNumber, array[index] as! NSNumber)
                indexesSeen[index] = true
            }
        }
        
        // ... and stopping after the first half:
        
        testExpectingToSee(firstHalfOfIndexes) { (indexesSeen) in
            array.enumerateObjects { (value, index, stop) in
                XCTAssertEqual(value as! NSNumber, array[index] as! NSNumber)
                
                if firstHalfOfIndexes.contains(index) {
                    indexesSeen[index] = true
                } else {
                    stop.pointee = true
                }
            }
        }
        
        // -----
        // Test enumerateObjects(options:using) and enumerateObjects(at:options:using:):
        
        // Test each of these options combinations:
        let optionsToTest : [NSEnumerationOptions] = [
            [],
            [.concurrent],
            [.reverse],
            [.concurrent, .reverse],
        ]
        
        for options in optionsToTest {
            // Run to completion,
            testExpectingToSee(allIndexes) { (indexesSeen) in
                array.enumerateObjects(options: options, using: { (value, index, stop) in
                    XCTAssertEqual(value as! NSNumber, array[index] as! NSNumber)
                    indexesSeen[index] = true
                })
            }
            
            // run it only for half the indexes (use the right half depending on where we start),
            let indexesForHalfEnumeration = options.contains(.reverse) ? lastHalfOfIndexes : firstHalfOfIndexes
            
            testExpectingToSee(indexesForHalfEnumeration) { (indexesSeen) in
                array.enumerateObjects(options: options, using: { (value, index, stop) in
                    XCTAssertEqual(value as! NSNumber, array[index] as! NSNumber)
                    
                    if indexesForHalfEnumeration.contains(index) {
                        indexesSeen[index] = true
                    } else {
                        stop.pointee = true
                    }
                })
            }
            
            // run only for a specific index set to test the at:… variant,
            testExpectingToSee(evenIndexes) { (indexesSeen) in
                array.enumerateObjects(at: evenIndexes, options: options, using: { (value, index, stop) in
                    XCTAssertEqual(value as! NSNumber, array[index] as! NSNumber)
                    indexesSeen[index] = true
                })
            }
            
            // and run for some indexes only to test stopping.
            var indexesForStaggeredEnumeration = indexesForHalfEnumeration
            indexesForStaggeredEnumeration.formIntersection(evenIndexes)
            
            let finalCount = indexesForStaggeredEnumeration.count
            
            let lockForSeenCount = NSLock()
            var seenCount = 0
            
            testExpectingToSee(indexesForStaggeredEnumeration) { (indexesSeen) in
                array.enumerateObjects(at: evenIndexes, options: options, using: { (value, index, stop) in
                    XCTAssertEqual(value as! NSNumber, array[index] as! NSNumber)
                    
                    if (indexesForStaggeredEnumeration.contains(index)) {
                        indexesSeen[index] = true
                        
                        lockForSeenCount.lock()
                        seenCount += 1
                        let currentCount = seenCount
                        lockForSeenCount.unlock()
                        
                        if currentCount == finalCount {
                            stop.pointee = true
                        }
                    }
                })
            }
        }
        
    }
    
    func test_sequenceType() {
        let array : NSArray = ["foo", "bar", "baz"]
        var res = [String]()
        for obj in array {
            res.append((obj as! String))
        }
        XCTAssertEqual(res, ["foo", "bar", "baz"])
    }

//    func test_getObjects() {
//        let array : NSArray = ["foo", "bar", "baz", "foo1", "bar2", "baz3",].bridge()
//        var objects = [AnyObject]()
//        array.getObjects(&objects, range: NSRange(location: 1, length: 3))
//        XCTAssertEqual(objects.count, 3)
//        let fetched = [
//            (objects[0] as! NSString).bridge(),
//            (objects[1] as! NSString).bridge(),
//            (objects[2] as! NSString).bridge(),
//        ]
//        XCTAssertEqual(fetched, ["bar", "baz", "foo1"])
//    }
    
    func test_objectAtIndex() {
        let array : NSArray = ["foo", "bar"]
        let foo = array.object(at: 0) as! String
        XCTAssertEqual(foo, "foo")
        
        let bar = array.object(at: 1) as! String
        XCTAssertEqual(bar, "bar")
    }

    func test_binarySearch() {
        let numbers: [AnyObject] = [
            NSNumber(value: 0 as Int), NSNumber(value: 1 as Int), NSNumber(value: 2 as Int), NSNumber(value: 2 as Int), NSNumber(value: 3 as Int),
            NSNumber(value: 4 as Int), NSNumber(value: 4 as Int), NSNumber(value: 6 as Int), NSNumber(value: 7 as Int), NSNumber(value: 7 as Int),
            NSNumber(value: 7 as Int), NSNumber(value: 8 as Int), NSNumber(value: 9 as Int), NSNumber(value: 9 as Int)]
        let array = NSArray(array: numbers)
        
        // Not sure how to test fatal errors.
        
//        NSArray throws NSInvalidArgument if range exceeds bounds of the array.
//        let rangeOutOfArray = NSRange(location: 5, length: 15)
//        let _ = array.indexOfObject(NSNumber(value: 9 as Int), inSortedRange: rangeOutOfArray, options: [.insertionIndex, .firstEqual], usingComparator: compareIntNSNumber)
        
//        NSArray throws NSInvalidArgument if both .firstEqual and .lastEqual are specified
//        let searchForBoth: NSBinarySearchingOptions = [.firstEqual, .lastEqual]
//        let _ = objectIndexInArray(array, value: 9, startingFrom: 0, length: 13, options: searchForBoth)

        let notFound = objectIndexInArray(array, value: 11, startingFrom: 0, length: 13)
        XCTAssertEqual(notFound, NSNotFound, "NSArray return NSNotFound if object is not found.")
        
        let notFoundInRange = objectIndexInArray(array, value: 7, startingFrom: 0, length: 5)
        XCTAssertEqual(notFoundInRange, NSNotFound, "NSArray return NSNotFound if object is not found.")
        
        let indexOfAnySeven = objectIndexInArray(array, value: 7, startingFrom: 0, length: 13)
        XCTAssertTrue(Set([8, 9, 10]).contains(indexOfAnySeven), "If no options provided NSArray returns an arbitrary matching object's index.")
        
        let indexOfFirstNine = objectIndexInArray(array, value: 9, startingFrom: 7, length: 6, options: [.firstEqual])
        XCTAssertTrue(indexOfFirstNine == 12, "If .FirstEqual is set NSArray returns the lowest index of equal objects.")
        
        let indexOfLastTwo = objectIndexInArray(array, value: 2, startingFrom: 1, length: 7, options: [.lastEqual])
        XCTAssertTrue(indexOfLastTwo == 3, "If .LastEqual is set NSArray returns the highest index of equal objects.")
        
        let anyIndexToInsertNine = objectIndexInArray(array, value: 9, startingFrom: 0, length: 13, options: [.insertionIndex])
        XCTAssertTrue(Set([12, 13, 14]).contains(anyIndexToInsertNine), "If .InsertionIndex is specified and no other options provided NSArray returns any equal or one larger index than any matching object’s index.")
        
        let lowestIndexToInsertTwo = objectIndexInArray(array, value: 2, startingFrom: 0, length: 5, options: [.insertionIndex, .firstEqual])
        XCTAssertTrue(lowestIndexToInsertTwo == 2, "If both .InsertionIndex and .FirstEqual are specified NSArray returns the lowest index of equal objects.")
        
        let highestIndexToInsertNine = objectIndexInArray(array, value: 9, startingFrom: 7, length: 6, options: [.insertionIndex, .lastEqual])
        XCTAssertTrue(highestIndexToInsertNine == 13, "If both .InsertionIndex and .LastEqual are specified NSArray returns the index of the least greater object...")
        
        let indexOfLeastGreaterObjectThanFive = objectIndexInArray(array, value: 5, startingFrom: 0, length: 10, options: [.insertionIndex, .lastEqual])
        XCTAssertTrue(indexOfLeastGreaterObjectThanFive == 7, "If both .InsertionIndex and .LastEqual are specified NSArray returns the index of the least greater object...")
        
        let rangeStart = 0
        let rangeLength = 13
        let endOfArray = objectIndexInArray(array, value: 10, startingFrom: rangeStart, length: rangeLength, options: [.insertionIndex, .lastEqual])
        XCTAssertTrue(endOfArray == (rangeStart + rangeLength), "...or the index at the end of the array if the object is larger than all other elements.")
        
        let arrayOfTwo = NSArray(array: [NSNumber(value: 0 as Int), NSNumber(value: 2 as Int)])
        let indexInMiddle = objectIndexInArray(arrayOfTwo, value: 1, startingFrom: 0, length: 2, options: [.insertionIndex, .firstEqual])
        XCTAssertEqual(indexInMiddle, 1, "If no match found item should be inserted before least greater object")
        let indexInMiddle2 = objectIndexInArray(arrayOfTwo, value: 1, startingFrom: 0, length: 2, options: [.insertionIndex, .lastEqual])
        XCTAssertEqual(indexInMiddle2, 1, "If no match found item should be inserted before least greater object")
        let indexInMiddle3 = objectIndexInArray(arrayOfTwo, value: 1, startingFrom: 0, length: 2, options: [.insertionIndex])
        XCTAssertEqual(indexInMiddle3, 1, "If no match found item should be inserted before least greater object")
    }


    func test_arrayReplacement() {
        let numbers: [AnyObject] = [
            NSNumber(value: 0 as Int), NSNumber(value: 1 as Int), NSNumber(value: 2 as Int), NSNumber(value: 3 as Int),
            NSNumber(value: 4 as Int), NSNumber(value: 5 as Int), NSNumber(value: 7 as Int)]
        let array = NSMutableArray(array: numbers)
        array.replaceObjects(in: NSRange(location: 0, length: 2), withObjectsFrom: [NSNumber(value: 8 as Int), NSNumber(value: 9 as Int)])
        XCTAssertTrue((array[0] as! NSNumber).intValue == 8)
        XCTAssertTrue((array[1] as! NSNumber).intValue == 9)
        XCTAssertTrue((array[2] as! NSNumber).intValue == 2)
    }

    func test_arrayReplaceObjectsInRangeFromRange() {
        let numbers: [AnyObject] = [
            NSNumber(value: 0 as Int), NSNumber(value: 1 as Int), NSNumber(value: 2 as Int), NSNumber(value: 3 as Int),
            NSNumber(value: 4 as Int), NSNumber(value: 5 as Int), NSNumber(value: 7 as Int)]
        let array = NSMutableArray(array: numbers)
        array.replaceObjects(in: NSRange(location: 0, length: 2), withObjectsFrom: [NSNumber(value: 8 as Int), NSNumber(value: 9 as Int), NSNumber(value: 10 as Int)], range: NSRange(location: 1, length: 2))
        XCTAssertTrue((array[0] as! NSNumber).intValue == 9)
        XCTAssertTrue((array[1] as! NSNumber).intValue == 10)
        XCTAssertTrue((array[2] as! NSNumber).intValue == 2)
    }

    func test_replaceObjectAtIndex() {
        let numbers: [AnyObject] = [
            NSNumber(value: 0 as Int), NSNumber(value: 1 as Int), NSNumber(value: 2 as Int), NSNumber(value: 3 as Int),
            NSNumber(value: 4 as Int), NSNumber(value: 5 as Int), NSNumber(value: 7 as Int)]
        let array = NSMutableArray(array: numbers)

        // 1. Check replacement in the middle of the array
        array.replaceObject(at: 3, with: NSNumber(value: 8 as Int))
        XCTAssertEqual(array.count, 7)
        XCTAssertEqual((array[3] as! NSNumber).intValue, 8)

        // 2. Check replacement of the first element
        array.replaceObject(at: 0, with: NSNumber(value: 7 as Int))
        XCTAssertEqual(array.count, 7)
        XCTAssertEqual((array[0] as! NSNumber).intValue, 7)

        // 3. Check replacement of the last element
        array.replaceObject(at: 6, with: NSNumber(value: 6 as Int))
        XCTAssertEqual(array.count, 7)
        XCTAssertEqual((array[6] as! NSNumber).intValue, 6)
    }

    func test_removeObjectsInArray() {
        let numbers: [AnyObject] = [
            NSNumber(value: 0 as Int), NSNumber(value: 1 as Int), NSNumber(value: 2 as Int), NSNumber(value: 3 as Int),
            NSNumber(value: 4 as Int), NSNumber(value: 5 as Int), NSNumber(value: 7 as Int)]
        let array = NSMutableArray(array: numbers)
        let objectsToRemove: Array<AnyObject> = [
            NSNumber(value: 1 as Int), NSNumber(value: 22 as Int), NSNumber(value: 7 as Int), NSNumber(value: 5 as Int)]
        array.removeObjects(in: objectsToRemove)
        XCTAssertEqual(array.count, 4)
        XCTAssertEqual((array[0] as! NSNumber).intValue, 0)
        XCTAssertEqual((array[1] as! NSNumber).intValue, 2)
        XCTAssertEqual((array[2] as! NSNumber).intValue, 3)
        XCTAssertEqual((array[3] as! NSNumber).intValue, 4)
    }

    func test_binarySearchFringeCases() {
        let numbers: [AnyObject] = [
            NSNumber(value: 0 as Int), NSNumber(value: 1 as Int), NSNumber(value: 2 as Int), NSNumber(value: 2 as Int), NSNumber(value: 3 as Int),
            NSNumber(value: 4 as Int), NSNumber(value: 4 as Int), NSNumber(value: 6 as Int), NSNumber(value: 7 as Int), NSNumber(value: 7 as Int),
            NSNumber(value: 7 as Int), NSNumber(value: 8 as Int), NSNumber(value: 9 as Int), NSNumber(value: 9 as Int)]
        let array = NSArray(array: numbers)
        
        let emptyArray = NSArray()
//        Same as for non empty NSArray but error message ends with 'bounds for empty array'.
//        let _ = objectIndexInArray(emptyArray, value: 0, startingFrom: 0, length: 1)
        
        let notFoundInEmptyArray = objectIndexInArray(emptyArray, value: 9, startingFrom: 0, length: 0)
        XCTAssertEqual(notFoundInEmptyArray, NSNotFound, "Empty NSArray return NSNotFound for any valid arguments.")
        
        let startIndex = objectIndexInArray(emptyArray, value: 7, startingFrom: 0, length: 0, options: [.insertionIndex])
        XCTAssertTrue(startIndex == 0, "For Empty NSArray any objects should be inserted at start.")
        
        let rangeStart = 0
        let rangeLength = 13
        
        let leastSearch = objectIndexInArray(array, value: -1, startingFrom: rangeStart, length: rangeLength)
        XCTAssertTrue(leastSearch == NSNotFound, "If object is less than least object in the range then there is no change it could be found.")
        
        let greatestSearch = objectIndexInArray(array, value: 15, startingFrom: rangeStart, length: rangeLength)
        XCTAssertTrue(greatestSearch == NSNotFound, "If object is greater than greatest object in the range then there is no change it could be found.")
        
        let leastInsert = objectIndexInArray(array, value: -1, startingFrom: rangeStart, length: rangeLength, options: .insertionIndex)
        XCTAssertTrue(leastInsert == rangeStart, "If object is less than least object in the range it should be inserted at range' location.")
        
        let greatestInsert = objectIndexInArray(array, value: 15, startingFrom: rangeStart, length: rangeLength, options: .insertionIndex)
        XCTAssertTrue(greatestInsert == (rangeStart + rangeLength), "If object is greater than greatest object in the range it should be inserted at range' end.")
    }
    
    func objectIndexInArray(_ array: NSArray, value: Int, startingFrom: Int, length: Int, options: NSBinarySearchingOptions = []) -> Int {
        return array.index(of: NSNumber(value: value), inSortedRange: NSRange(location: startingFrom, length: length), options: options, usingComparator: compareIntNSNumber)
    }
    
    func compareIntNSNumber(_ lhs: Any, rhs: Any) -> ComparisonResult {
        let lhsInt = (lhs as! NSNumber).intValue
        let rhsInt = (rhs as! NSNumber).intValue
        if lhsInt == rhsInt {
            return .orderedSame
        }
        if lhsInt < rhsInt {
            return .orderedAscending
        }
        
        return .orderedDescending
    }
    
    func test_replaceObjectsInRange_withObjectsFrom() {
        let array1 = NSMutableArray(array:[
            "foo1",
            "bar1",
            "baz1"])
        
        let array2: [Any] = [
            "foo2",
            "bar2",
            "baz2"]
        
        array1.replaceObjects(in: NSRange(location: 0, length: 2), withObjectsFrom: array2)
        
        XCTAssertEqual(array1[0] as? String, "foo2", "Expected foo2 but was \(array1[0])")
        XCTAssertEqual(array1[1] as? String, "bar2", "Expected bar2 but was \(array1[1])")
        XCTAssertEqual(array1[2] as? String, "baz2", "Expected baz2 but was \(array1[2])")
        XCTAssertEqual(array1[3] as? String, "baz1", "Expected baz1 but was \(array1[3])")
    }
    
    func test_replaceObjectsInRange_withObjectsFrom_range() {
        let array1 = NSMutableArray(array:[
            "foo1",
            "bar1",
            "baz1"])
        
        let array2: [Any] = [
            "foo2",
            "bar2",
            "baz2"]
        
        array1.replaceObjects(in: NSRange(location: 1, length: 1), withObjectsFrom: array2, range: NSRange(location: 1, length: 2))
        
        XCTAssertEqual(array1[0] as? String, "foo1", "Expected foo1 but was \(array1[0])")
        XCTAssertEqual(array1[1] as? String, "bar2", "Expected bar2 but was \(array1[1])")
        XCTAssertEqual(array1[2] as? String, "baz2", "Expected baz2 but was \(array1[2])")
        XCTAssertEqual(array1[3] as? String, "baz1", "Expected baz1 but was \(array1[3])")
    }

    func test_sortedArrayUsingComparator() {
        // sort with localized caseInsensitive compare
        let input = ["this", "is", "a", "test", "of", "sort", "with", "strings"]
        let expectedResult: Array<String> = input.sorted()
        let result = NSArray(array: input).sortedArray(comparator:) { left, right -> ComparisonResult in
            let l = left as! String
            let r = right as! String
            return l.localizedCaseInsensitiveCompare(r)
        }
        XCTAssertEqual(result.map { ($0 as! String)} , expectedResult)

        // sort empty array
        let emptyArray = NSArray().sortedArray(comparator:) { _,_ in .orderedSame }
        XCTAssertTrue(emptyArray.isEmpty)

        // sort numbers
        let inputNumbers = [0, 10, 25, 100, 21, 22]
        let expectedNumbers = inputNumbers.sorted()
        let resultNumbers = NSArray(array: inputNumbers).sortedArray(comparator:) { left, right -> ComparisonResult in
            let l = (left as! NSNumber).intValue
            let r = (right as! NSNumber).intValue
            return l < r ? .orderedAscending : (l == r ? .orderedSame : .orderedDescending)
        }
        XCTAssertEqual(resultNumbers.map { ($0 as! NSNumber).intValue}, expectedNumbers)
    }

    func test_sortedArrayWithOptionsUsingComparator() {
        // check that sortedArrayWithOptions:comparator: works in the way sortedArrayUsingComparator does
        let input = NSArray(array: ["this", "is", "a", "test", "of", "sort", "with", "strings"])
        let comparator: (Any, Any) -> ComparisonResult = { left, right -> ComparisonResult in
            let l = left as! String
            let r = right as! String
            return l.localizedCaseInsensitiveCompare(r)
        }
        let result1 = NSArray(array: input.sortedArray(comparator: comparator))
        let result2 = input.sortedArray(options: [], usingComparator: comparator)

        XCTAssertTrue(result1.isEqual(to: result2))

        // sort empty array
        let emptyArray = NSArray().sortedArray(options: []) { _,_ in .orderedSame }
        XCTAssertTrue(emptyArray.isEmpty)
    }

    func test_sortUsingFunction() {
        let inputNumbers = [11, 120, 215, 11, 1, -22, 35, -89, 65]
        let mutableInput = NSArray(array: inputNumbers).mutableCopy() as! NSMutableArray
        let expectedNumbers = inputNumbers.sorted()

        func compare(_ left: Any, right:Any,  context: UnsafeMutableRawPointer?) -> Int {
            let l = (left as! NSNumber).intValue
            let r = (right as! NSNumber).intValue
            return l < r ? -1 : (l == r ? 0 : 1)
        }
        mutableInput.sort(compare, context: UnsafeMutableRawPointer(bitPattern: 0))

        XCTAssertEqual(mutableInput.map { ($0 as! NSNumber).intValue}, expectedNumbers)
    }

    func test_sortUsingComparator() {
        // check behaviour with Array's sort method
        let inputNumbers = [11, 120, 215, 11, 1, -22, 35, -89, 65]
        let mutableInput = NSMutableArray(array: inputNumbers)
        let expectedNumbers = inputNumbers.sorted()

        mutableInput.sort { left, right -> ComparisonResult in
            let l = (left as! NSNumber).intValue
            let r = (right as! NSNumber).intValue
            return l < r ? .orderedAscending : (l == r ? .orderedSame : .orderedDescending)
        }

        XCTAssertEqual(mutableInput.map { ($0 as! NSNumber).intValue}, expectedNumbers)

        // check that it works in the way self.sortWithOptions([], usingComparator: cmptr) does
        let inputStrings = ["this", "is", "a", "test", "of", "sort", "with", "strings"]
        let mutableStringsInput1 = NSMutableArray(array: inputStrings)
        let mutableStringsInput2 = NSMutableArray(array: inputStrings)
        let comparator: (Any, Any) -> ComparisonResult = { left, right -> ComparisonResult in
            let l = left as! String
            let r = right as! String
            return l.localizedCaseInsensitiveCompare(r)
        }
        mutableStringsInput1.sort(comparator: comparator)
        mutableStringsInput2.sort(options: [], usingComparator: comparator)
        XCTAssertTrue(mutableStringsInput1.isEqual(to: Array(mutableStringsInput2)))
    }

    func test_equality() {
        let array1 = NSArray(array: ["this", "is", "a", "test", "of", "equal", "with", "strings"])
        let array2 = NSArray(array: ["this", "is", "a", "test", "of", "equal", "with", "strings"])
        let array3 = NSArray(array: ["this", "is", "a", "test", "of", "equal", "with", "objects"])

        XCTAssertTrue(array1 == array2)
        XCTAssertTrue(array1.isEqual(array2))
        XCTAssertTrue(array1.isEqual(to: Array(array2)))
        // if 2 arrays are equal, hashes should be equal as well. But not vise versa
        XCTAssertEqual(array1.hash, array2.hash)
        XCTAssertEqual(array1.hashValue, array2.hashValue)

        XCTAssertFalse(array1 == array3)
        XCTAssertFalse(array1.isEqual(array3))
        XCTAssertFalse(array1.isEqual(to: Array(array3)))

        XCTAssertFalse(array1.isEqual(nil))
        XCTAssertFalse(array1.isEqual(NSObject()))

        let objectsArray1 = NSArray(array: [NSArray(array: [0])])
        let objectsArray2 = NSArray(array: [NSArray(array: [1])])
        XCTAssertFalse(objectsArray1 == objectsArray2)
        XCTAssertFalse(objectsArray1.isEqual(objectsArray2))
        XCTAssertFalse(objectsArray1.isEqual(to: Array(objectsArray2)))
    }

    func test_AnyHashable() {
        let a1: AnyHashable = [1, 2, 3]
        let a2: AnyHashable = NSArray(array: [
                NSNumber(value: 1),
                NSNumber(value: 2),
                NSNumber(value: 3)])
        XCTAssertEqual(a1, a2)
        XCTAssertEqual(a1.hashValue, a2.hashValue)
    }

    /// - Note: value type conversion will destroy identity. So use index(of:) instead of indexOfObjectIdentical(to:)
    func test_copying() {
        let array = NSArray(array: ["this", "is", "a", "test", "of", "copy", "with", "strings"])

        let arrayCopy1 = array.copy() as! NSArray
        XCTAssertTrue(array === arrayCopy1)

        let arrayMutableCopy = array.mutableCopy() as! NSMutableArray
        let arrayCopy2 = arrayMutableCopy.copy() as! NSArray
        XCTAssertTrue(type(of: arrayCopy2) === NSArray.self)
        XCTAssertFalse(arrayMutableCopy === arrayCopy2)
        for entry in arrayCopy2 {
            XCTAssertTrue(array.index(of: entry) != NSNotFound)
        }

    }

    func test_mutableCopying() {
        let array = NSArray(array: ["this", "is", "a", "test", "of", "mutableCopy", "with", "strings"])

        let arrayMutableCopy1 = array.mutableCopy() as! NSMutableArray
        XCTAssertTrue(type(of: arrayMutableCopy1) === NSMutableArray.self)
        XCTAssertFalse(array === arrayMutableCopy1)
        for entry in arrayMutableCopy1 {
            XCTAssertTrue(array.index(of: entry) != NSNotFound)
        }

        let arrayMutableCopy2 = arrayMutableCopy1.mutableCopy() as! NSMutableArray
        XCTAssertTrue(type(of: arrayMutableCopy2) === NSMutableArray.self)
        XCTAssertFalse(arrayMutableCopy2 === arrayMutableCopy1)
        for entry in arrayMutableCopy2 {
            XCTAssertTrue(arrayMutableCopy1.index(of: entry) != NSNotFound)
        }
    }

    func test_initWithContentsOfFile() {
        let testFilePath = createTestFile("TestFileOut.txt", _contents: Data(capacity: 234))
        if let _ = testFilePath {
            let a1: NSArray = ["foo", "bar"]
            let isWritten = a1.write(toFile: testFilePath!, atomically: true)
            if isWritten {
                let array = NSArray.init(contentsOfFile: testFilePath!)
                XCTAssert(array == a1)
            } else {
                XCTFail("Write to file failed")
            }
            removeTestFile(testFilePath!)
        } else {
            XCTFail("Temporary file creation failed")
        }
    }

    func test_initMutableWithContentsOfFile() {
        if let testFilePath = createTestFile("TestFileOut.txt", _contents: Data(capacity: 234)) {
            let a1: NSArray = ["foo", "bar"]
            let isWritten = a1.write(toFile: testFilePath, atomically: true)
            if isWritten {
                let array = NSMutableArray.init(contentsOfFile: testFilePath)
                XCTAssert(array == a1)
                XCTAssertEqual(array?.count, 2)
                array?.removeAllObjects()
                XCTAssertEqual(array?.count, 0)
            } else {
                XCTFail("Write to file failed")
            }
            removeTestFile(testFilePath)
        } else {
            XCTFail("Temporary file creation failed")
        }
    }

    func test_initMutableWithContentsOfURL() {
        if let testFilePath = createTestFile("TestFileOut.txt", _contents: Data(capacity: 234)) {
            let a1: NSArray = ["foo", "bar"]
            let isWritten = a1.write(toFile: testFilePath, atomically: true)
            if isWritten {
                let url = URL(fileURLWithPath: testFilePath, isDirectory: false)
                let array = NSMutableArray.init(contentsOf: url)
                XCTAssert(array == a1)
                XCTAssertEqual(array?.count, 2)
                array?.removeAllObjects()
                XCTAssertEqual(array?.count, 0)
            } else {
                XCTFail("Write to file failed")
            }
            removeTestFile(testFilePath)
        } else {
            XCTFail("Temporary file creation failed")
        }
    }

    func test_writeToFile() {
        let testFilePath = createTestFile("TestFileOut.txt", _contents: Data(capacity: 234))
        if let _ = testFilePath {
            let d1: NSArray = ["foo", "bar"]
            let isWritten = d1.write(toFile: testFilePath!, atomically: true)
            if isWritten {
                do {
                    let plistDoc = try XMLDocument(contentsOf: URL(fileURLWithPath: testFilePath!, isDirectory: false), options: [])
                    XCTAssert(plistDoc.rootElement()?.name == "plist")
                    let plist = try PropertyListSerialization.propertyList(from: plistDoc.xmlData, options: [], format: nil) as! [Any]
                    XCTAssert((plist[0] as? String) == d1[0] as? String)
                    XCTAssert((plist[1] as? String) == d1[1] as? String)
                } catch {
                    XCTFail("Failed to read and parse XMLDocument")
                }
            } else {
                XCTFail("Write to file failed")
            }
            removeTestFile(testFilePath!)
        } else {
            XCTFail("Temporary file creation failed")
        }
    }

    func test_readWriteURL() {
        let data = NSArray(arrayLiteral: "one", "two", "three", "four", "five")
        do {
            let tempDir = NSTemporaryDirectory() + "TestFoundation_Playground_" + NSUUID().uuidString
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: false, attributes: nil)
            let testFile = tempDir + "/readWriteURL.txt"
            let url = URL(fileURLWithPath: testFile)
            let data2: NSArray
#if DARWIN_COMPATIBILITY_TESTS
            if #available(macOS 10.13, *) {
                try data.write(to: url)
                data2 = try NSArray(contentsOf: url, error: ())
            } else {
                guard data.write(toFile: testFile, atomically: true) else {
                    throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteUnknown.rawValue)
                }
                data2 = NSArray(contentsOfFile: testFile)!
            }
#else
            try data.write(to: url)
            data2 = try NSArray(contentsOf: url, error: ())
#endif
            XCTAssertEqual(data, data2)
            removeTestFile(testFile)
        } catch let e {
            XCTFail("Failed to write to file: \(e)")
        }
    }

    func test_insertObjectAtIndex() {
        let a1 = NSMutableArray(arrayLiteral: "one", "two", "three", "four")
        a1.insert("a", at: 0)
        XCTAssertEqual(a1, ["a", "one", "two", "three", "four"])
        
        let a2 = NSMutableArray(arrayLiteral: "one", "two", "three", "four")
        a2.insert("a", at: 4)
        XCTAssertEqual(a2, ["one", "two", "three", "four", "a"])
        
        let a3 = NSMutableArray()
        a3.insert("a", at: 0)
        XCTAssertEqual(a3, ["a"])
    }

    func test_insertObjectsAtIndexes() {
        let a1 = NSMutableArray(arrayLiteral: "one", "two", "three", "four")
        a1.insert(["a", "b"], at: [0, 1])
        XCTAssertEqual(a1, ["a", "b", "one", "two", "three", "four"])

        let a2 = NSMutableArray(arrayLiteral: "one", "two", "three", "four")
        a2.insert(["a", "b"], at: [1, 3])
        XCTAssertEqual(a2, ["one", "a", "two", "b", "three", "four"])
        
        let a3 = NSMutableArray(arrayLiteral: "one", "two", "three", "four")
        a3.insert(["a", "b"], at: [5, 4])
        XCTAssertEqual(a3, ["one", "two", "three", "four", "a", "b"])
        
        let a4 = NSMutableArray()
        a4.insert(["a", "b"], at: [0, 1])
        XCTAssertEqual(a4, ["a", "b"])
    }

    func test_replaceObjectsAtIndexesWithObjects() {
        let a1 = NSMutableArray(arrayLiteral: "one", "two", "three", "four")
        a1.replaceObjects(at: [0], with: ["a"])
        XCTAssertEqual(a1, ["a", "two", "three", "four"])

        let a2 = NSMutableArray(arrayLiteral: "one", "two", "three", "four")
        a2.replaceObjects(at: [1, 2], with: ["a", "b"])
        XCTAssertEqual(a2, ["one", "a", "b", "four"])

        let a3 = NSMutableArray(arrayLiteral: "one", "two", "three", "four")
        a3.replaceObjects(at: [3, 2, 1, 0], with: ["a", "b", "c", "d"])
        XCTAssertEqual(a3, ["a", "b", "c", "d"])
    }

    func test_pathsMatchingExtensions() {
        let paths = NSArray(arrayLiteral: "file1.txt", "/tmp/file2.txt", "file3.jpg", "file3.png", "/file4.png", "txt", ".txt")
        let match1 = paths.pathsMatchingExtensions(["txt"])
        XCTAssertEqual(match1, ["file1.txt", "/tmp/file2.txt"])

        let match2 = paths.pathsMatchingExtensions([])
        XCTAssertEqual(match2, [])

        let match3 = paths.pathsMatchingExtensions([".txt", "png"])
        XCTAssertEqual(match3, ["file3.png", "/file4.png"])

        let match4 = paths.pathsMatchingExtensions(["", ".tx", "tx"])
        XCTAssertEqual(match4, [])

        let match5 = paths.pathsMatchingExtensions(["..txt"])
        XCTAssertEqual(match5, [])
    }

    private func createTestFile(_ path: String, _contents: Data) -> String? {
        let tempDir = NSTemporaryDirectory() + "TestFoundation_Playground_" + NSUUID().uuidString + "/"
        do {
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: false, attributes: nil)
            if FileManager.default.createFile(atPath: tempDir + "/" + path, contents: _contents, attributes: nil) {
                return tempDir + path
            } else {
                return nil
            }
        } catch _ {
            return nil
        }
    }
    
    private func removeTestFile(_ location: String) {
        do {
            try FileManager.default.removeItem(atPath: location)
        } catch _ {
            
        }
    }
}
