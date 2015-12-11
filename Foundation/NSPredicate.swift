// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


// Predicates wrap some combination of expressions and operators and when evaluated return a BOOL.

public class NSPredicate : NSObject, NSSecureCoding, NSCopying {
    
    public static func supportsSecureCoding() -> Bool {
        return true
    }
    
    public required init?(coder aDecoder: NSCoder) {
        NSUnimplemented()
    }
    
    public func encodeWithCoder(aCoder: NSCoder) {
        NSUnimplemented()
    }
    
    public func copyWithZone(zone: NSZone) -> AnyObject {
        NSUnimplemented()
    }

    internal let _evaluator : PredicateEvaluator
    internal let _bindings : [String:AnyObject]?

    internal init(evaluator : PredicateEvaluator, bindings : [String:AnyObject]? = nil ) {
        _evaluator = evaluator
        _bindings = bindings
    }

    // Parse predicateFormat and return an appropriate predicate
    public init(format predicateFormat: String, argumentArray arguments: [AnyObject]?) { NSUnimplemented() }
    
    public init?(fromMetadataQueryString queryString: String) { NSUnimplemented() }

    // return predicates that always evaluate to true/false
    public convenience init(value: Bool) {
        self.init(evaluator: ConstantEvaluator(value: value))
    }
    
    public convenience init(block: (AnyObject, [String : AnyObject]?) -> Bool) {
        self.init(evaluator: BlockEvaluator(block: block))
    }
    
    public var predicateFormat: String  { NSUnimplemented() } // returns the format string of the predicate
    
    public func predicateWithSubstitutionVariables(variables: [String : AnyObject]) -> Self { NSUnimplemented() } // substitute constant values for variables

    // evaluate a predicate against a single object
    public func evaluateWithObject(object: AnyObject?) -> Bool {
        return _evaluator.evaluate(object, bindings: _bindings)
    }

    // single pass evaluation substituting variables from the bindings dictionary for any variable expressions encountered
    public func evaluateWithObject(object: AnyObject?, substitutionVariables bindings: [String : AnyObject]?) -> Bool {
        return _evaluator.evaluate(object, bindings: bindings)
    }
    
    public func allowEvaluation() { NSUnimplemented() } // Force a predicate which was securely decoded to allow evaluation
}

internal protocol PredicateEvaluator {
    func evaluate(object : AnyObject?, bindings : [String:AnyObject]?) -> Bool
}

private struct BlockEvaluator : PredicateEvaluator {
    let block : (AnyObject, [String:AnyObject]?) -> Bool

    func evaluate(object: AnyObject?, bindings: [String : AnyObject]?) -> Bool {
        return block(object!, bindings)
    }
}

private struct ConstantEvaluator : PredicateEvaluator {
    let value : Bool
    
    func evaluate(object: AnyObject?, bindings: [String : AnyObject]?) -> Bool {
        return value
    }
}

extension NSArray {
    // evaluate a predicate against an array of objects and return a filtered array
    public func filteredArrayUsingPredicate(predicate: NSPredicate) -> [AnyObject] {
        return filter(predicate.evaluateWithObject)
    }
}

extension NSMutableArray {
    // evaluate a predicate against an array of objects and filter the mutable array directly
    public func filterUsingPredicate(predicate: NSPredicate) {
        let indexes = indexesOfObjectsPassingTest {
            object, index, stop in
            return !predicate.evaluateWithObject(object)
        }
        removeObjectsAtIndexes(indexes)
    }
}

extension NSSet {
    // evaluate a predicate against a set of objects and return a filtered set
    public func filteredSetUsingPredicate(predicate: NSPredicate) -> Set<NSObject> {
        return Set(_storage.filter(predicate.evaluateWithObject))
    }
}

extension NSMutableSet {
    // evaluate a predicate against a set of objects and filter the mutable set directly
    public func filterUsingPredicate(predicate: NSPredicate) {
        setSet(filteredSetUsingPredicate(predicate))
    }
}

extension NSOrderedSet {
    // evaluate a predicate against an ordered set of objects and return a filtered ordered set
    public func filteredOrderedSetUsingPredicate(p: NSPredicate) -> NSOrderedSet {
        return NSOrderedSet(array: array.filter(p.evaluateWithObject))
    }
}

extension NSMutableOrderedSet {
    // evaluate a predicate against an ordered set of objects and filter the mutable ordered set directly
    public func filterUsingPredicate(p: NSPredicate) {
        let indexes = indexesOfObjectsPassingTest( {
            object, index, stop in
            return !p.evaluateWithObject(object)
        })
        removeObjectsAtIndexes(indexes)
    }
}


