// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//


public class NSNull : NSObject, NSCopying, NSSecureCoding {
    
    public override func copy() -> AnyObject {
        return copy(with: nil)
    }
    
    public func copy(with zone: NSZone? = nil) -> AnyObject {
        return self
    }
    
    public override init() {
        // Nothing to do here
    }
    
    public required init?(coder aDecoder: NSCoder) {
        // Nothing to do here
    }
    
    public func encode(with aCoder: NSCoder) {
        // Nothing to do here
    }
    
    public static func supportsSecureCoding() -> Bool {
        return true
    }
    
    public override func isEqual(_ object: AnyObject?) -> Bool {
        return object is NSNull
    }
}

public func ===(lhs: NSNull?, rhs: NSNull?) -> Bool {
    guard let _ = lhs, let _ = rhs else { return false }
    return true
}
