// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

@_implementationOnly import CoreFoundation

/* NSListFormatter provides locale-correct formatting of a list of items using the appropriate separator and conjunction. Note that the list formatter is unaware of the context where the joined string will be used, e.g., in the beginning of the sentence or used as a standalone string in the UI, so it will not provide any sort of capitalization customization on the given items, but merely join them as-is. The string joined this way may not be grammatically correct when placed in a sentence, and it should only be used in a standalone manner.
*/
open class ListFormatter: Formatter {
    private let cfFormatter: CFListFormatter

    /* Specifies the locale to format the items. Defaults to autoupdatingCurrentLocale. Also resets to autoupdatingCurrentLocale on assignment of nil.
     */
    private var _locale: Locale = .autoupdatingCurrent
    open var locale: Locale! {
        get { return _locale }
        set { _locale = newValue ?? .autoupdatingCurrent }
    }

    /* Specifies how each object should be formatted. If not set, the object is formatted using its instance method in the following order: -descriptionWithLocale:, -localizedDescription, and -description.
     */
    /*@NSCopying*/ open var itemFormatter: Formatter?

    public override init() {
        self.cfFormatter = _CFListFormatterCreate(kCFAllocatorSystemDefault, CFLocaleCopyCurrent())!
        super.init()
    }

    public required init?(coder: NSCoder) {
        self.cfFormatter = _CFListFormatterCreate(kCFAllocatorSystemDefault, CFLocaleCopyCurrent())!
        super.init(coder: coder)
    }

    open override func copy(with zone: NSZone? = nil) -> Any {
        let copied = ListFormatter()
        copied.locale = locale
        copied.itemFormatter = itemFormatter?.copy(with: zone) as? Formatter
        return copied
    }

    /* Convenience method to return a string constructed from an array of strings using the list format specific to the current locale. It is recommended to join only disjointed strings that are ready to display in a bullet-point list. Sentences, phrases with punctuations, and appositions may not work well when joined together.
     */
    open class func localizedString(byJoining strings: [String]) -> String {
        let formatter = ListFormatter()
        return formatter.string(from: strings)!
    }

    /* Convenience method for -stringForObjectValue:. Returns a string constructed from an array in the locale-aware format. Each item is formatted using the itemFormatter. If the itemFormatter does not apply to a particular item, the method will fall back to the item's -descriptionWithLocale: or -localizedDescription if implemented, or -description if not.

     Returns nil if `items` is nil or if the list formatter cannot generate a string representation for all items in the array.
     */
    open func string(from items: [Any]) -> String? {
        let strings = items.map { item in
            if let string = itemFormatter?.string(for: item) {
                return string
            }

            // Use the item’s `description(withLocale:)` if implemented
            if let item = item as? NSArray {
                return item.description(withLocale: locale)
            } else if let item = item as? NSDecimalNumber {
                return item.description(withLocale: locale)
            } else if let item = item as? NSDictionary {
                return item.description(withLocale: locale)
            } else if let item = item as? NSNumber {
                return item.description(withLocale: locale)
            } else if let item = item as? NSOrderedSet {
                return item.description(withLocale: locale)
            } else if let item = item as? NSSet {
                return item.description(withLocale: locale)
            }

            // Use the item’s `localizedDescription` if implemented
            if let item = item as? Error {
                return item.localizedDescription
            }

            return String(describing: item)
        }

        _CFListFormatterSetLocale(cfFormatter, locale._cfObject)
        return _CFListFormatterCreateStringByJoiningStrings(kCFAllocatorSystemDefault, cfFormatter, strings._cfObject)?._swiftObject
    }

    /* Inherited from NSFormatter. `obj` must be an instance of NSArray. Returns nil if `obj` is nil, not an instance of NSArray, or if the list formatter cannot generate a string representation for all objects in the array.
     */
    open override func string(for obj: Any?) -> String? {
        guard let list = obj as? [Any] else {
            return nil
        }

        return string(from: list)
    }
}
