//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
import XCTest

class TestNSObject : XCTestCase {
    @objc enum TargetState : Int, Equatable {
         case whatTarget = 1
         case why = 19
         case deadInside = -42
     }

     @objc class OptionalStateHolder : NSObject {
         @objc dynamic var objcState: TargetState = .whatTarget
     }

    class Target : NSObject {
        @objc dynamic var objcState: TargetState
        @objc dynamic var optionalStateHolder: OptionalStateHolder?

        init(objcState: TargetState, optionalStateHolder: OptionalStateHolder?) {
            self.objcState = objcState
            self.optionalStateHolder = optionalStateHolder
        }
    }

    func test_raw_representable_kvo_observing() {
        let target = Target(objcState: .whatTarget, optionalStateHolder: OptionalStateHolder())

        var observedChanges = Array<NSKeyValueObservedChange<TargetState>>()
        let observation = target.observe(\.objcState, options: [.old, .new]) { object, change in
            XCTAssertTrue(object === target)
            observedChanges.append(change)
        }

        withExtendedLifetime(observation) {
            target.objcState = .why
            target.objcState = .deadInside
            observation.invalidate()
            target.objcState = .whatTarget
        }

        XCTAssertEqual(observedChanges.count, 2)
        XCTAssertEqual(observedChanges.first?.oldValue, .whatTarget)
        XCTAssertEqual(observedChanges.first?.newValue, .why)
        XCTAssertEqual(observedChanges.last?.oldValue, .why)
        XCTAssertEqual(observedChanges.last?.newValue, .deadInside)
    }

    func test_optional_raw_representable_kvo_observing() {
        let target = Target(objcState: .whatTarget, optionalStateHolder: OptionalStateHolder())

        var observedChanges = Array<NSKeyValueObservedChange<TargetState?>>()
        let observation = target.observe(\.optionalStateHolder?.objcState, options: [.old, .new]) { object, change in
            XCTAssertTrue(object === target)
            observedChanges.append(change)
        }

        withExtendedLifetime(observation) {
            target.optionalStateHolder?.objcState = .why
            target.optionalStateHolder?.objcState = .deadInside
            target.optionalStateHolder = nil
            observation.invalidate()
            target.optionalStateHolder?.objcState = .whatTarget
            target.optionalStateHolder = OptionalStateHolder()
            target.optionalStateHolder?.objcState = .why
        }

        XCTAssertEqual(observedChanges.count, 2)
        XCTAssertEqual(observedChanges.first?.oldValue, .whatTarget)
        XCTAssertEqual(observedChanges.first?.newValue, .why)
        XCTAssertEqual(observedChanges.last?.oldValue, .why)
        XCTAssertEqual(observedChanges.last?.newValue, .deadInside)
    }
}
