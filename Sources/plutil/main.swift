// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
#if canImport(Darwin)
import Darwin
import SwiftFoundation
#elseif canImport(Glibc)
import Foundation
import Glibc
#elseif canImport(Musl)
import Foundation
import Musl
#elseif canImport(Android)
import Foundation
import Android
#elseif canImport(CRT)
import Foundation
import CRT
#endif

func help() -> Int32 {
    print("plutil: [command_option] [other_options] file...\n" +
    "The file '-' means stdin\n" +
    "Command options are (-lint is the default):\n" +
    " -help                         show this message and exit\n" +
    " -lint                         check the property list files for syntax errors\n" +
    " -convert fmt                  rewrite property list files in format\n" +
    "                               fmt is one of: xml1 binary1 json\n" +
    " -p                            print property list in a human-readable fashion\n" +
    "                               (not for machine parsing! this 'format' is not stable)\n" +
    "There are some additional optional arguments that apply to -convert\n" +
    " -s                            be silent on success\n" +
    " -o path                       specify alternate file path name for result;\n" +
    "                               the -o option is used with -convert, and is only\n" +
    "                               useful with one file argument (last file overwrites);\n" +
    "                               the path '-' means stdout\n" +
    " -e extension                  specify alternate extension for converted files\n" +
    " -r                            if writing JSON, output in human-readable form\n" +
    " --                            specifies that all further arguments are file names\n")
    return EXIT_SUCCESS
}

enum ExecutionMode {
    case help
    case lint
    case convert
    case print
}

enum ConversionFormat {
    case xml1
    case binary1
    case json
}

struct Options {
    var mode: ExecutionMode = .lint
    var silent: Bool = false
    var output: String?
    var fileExtension: String?
    var humanReadable: Bool?
    var conversionFormat: ConversionFormat?
    var inputs = [String]()
}

enum OptionParseError : Swift.Error {
    case unrecognizedArgument(String)
    case missingArgument(String)
    case invalidFormat(String)
}

func parseArguments(_ args: [String]) throws -> Options {
    var opts = Options()
    var iterator = args.makeIterator()
    while let arg = iterator.next() {
        switch arg {
            case "--":
                while let path = iterator.next() {
                    opts.inputs.append(path)
                }
            case "-s":
                opts.silent = true
            case "-o":
                if let path = iterator.next() {
                    opts.output = path
                } else {
                    throw OptionParseError.missingArgument("-o requires a path argument")
                }
            case "-convert":
                opts.mode = .convert
                if let format = iterator.next() {
                    switch format {
                        case "xml1":
                            opts.conversionFormat = .xml1
                        case "binary1":
                            opts.conversionFormat = .binary1
                        case "json":
                            opts.conversionFormat = .json
                        default:
                            throw OptionParseError.invalidFormat(format)
                    }
                } else {
                    throw OptionParseError.missingArgument("-convert requires a format argument of xml1 binary1 json")
                }
            case "-e":
                if let ext = iterator.next() {
                    opts.fileExtension = ext
                } else {
                    throw OptionParseError.missingArgument("-e requires an extension argument")
                }
            case "-help":
                opts.mode = .help
            case "-lint":
                opts.mode = .lint
            case "-p":
                opts.mode = .print
            default:
                if arg.hasPrefix("-") && arg.utf8.count > 1 {
                    throw OptionParseError.unrecognizedArgument(arg)
                }
        }
    }
    
    return opts
}


func lint(_ options: Options) -> Int32 {
    if options.output != nil {
        print("-o is not used with -lint")
        let _ = help()
        return EXIT_FAILURE
    }
    
    if options.fileExtension != nil {
        print("-e is not used with -lint")
        let _ = help()
        return EXIT_FAILURE
    }
    
    if options.inputs.count < 1 {
        print("No files specified.")
        let _ = help()
        return EXIT_FAILURE
    }
    
    let silent = options.silent
    
    var doError = false
    for file in options.inputs {
        let data : Data?
        if file == "-" {
            // stdin
            data = FileHandle.standardInput.readDataToEndOfFile()
        } else {
            data = try? Data(contentsOf: URL(fileURLWithPath: file))
        }
        
        if let d = data {
            do {
                let _ = try PropertyListSerialization.propertyList(from: d, options: [], format: nil)
                if !silent {
                    print("\(file): OK")
                }
            } catch {
                print("\(file): \(error)")
                
            }
            
        } else {
            print("\(file) does not exists or is not readable or is not a regular file")
            doError = true
            continue
        }
    }
    
    if doError {
        return EXIT_FAILURE
    } else {
        return EXIT_SUCCESS
    }
}

func convert(_ options: Options) -> Int32 {
    print("Unimplemented")
    return EXIT_FAILURE
}

enum DisplayType {
    case primary
    case key
    case value
}

extension Dictionary {
    func display(_ indent: Int = 0, type: DisplayType = .primary) {
        let indentation = String(repeating: " ", count: indent * 2)
        switch type {
        case .primary, .key:
            print("\(indentation)[\n", terminator: "")
        case .value:
            print("[\n", terminator: "")
        }

        forEach() {
            if let key = $0.0 as? String {
                key.display(indent + 1, type: .key)
            } else {
                fatalError("plists should have strings as keys but got a \(Swift.type(of: $0.0))")
            }
            print(" => ", terminator: "")
            displayPlist($0.1, indent: indent + 1, type: .value)
        }
        
        print("\(indentation)]\n", terminator: "")
    }
}

extension Array {
    func display(_ indent: Int = 0, type: DisplayType = .primary) {
        let indentation = String(repeating: " ", count: indent * 2)
        switch type {
        case .primary, .key:
            print("\(indentation)[\n", terminator: "")
        case .value:
            print("[\n", terminator: "")
        }

        for idx in 0..<count {
            print("\(indentation)  \(idx) => ", terminator: "")
            displayPlist(self[idx], indent: indent + 1, type: .value)
        }
        
        print("\(indentation)]\n", terminator: "")
    }
}

extension String {
    func display(_ indent: Int = 0, type: DisplayType = .primary) {
        let indentation = String(repeating: " ", count: indent * 2)
        switch type {
        case .primary:
            print("\(indentation)\"\(self)\"\n", terminator: "")
        case .key:
            print("\(indentation)\"\(self)\"", terminator: "")
        case .value:
            print("\"\(self)\"\n", terminator: "")
        }
    }
}

extension Bool {
    func display(_ indent: Int = 0, type: DisplayType = .primary) {
        let indentation = String(repeating: " ", count: indent * 2)
        switch type {
        case .primary:
            print("\(indentation)\"\(self ? "1" : "0")\"\n", terminator: "")
        case .key:
            print("\(indentation)\"\(self ? "1" : "0")\"", terminator: "")
        case .value:
            print("\"\(self ? "1" : "0")\"\n", terminator: "")
        }
    }
}

extension NSNumber {
    func display(_ indent: Int = 0, type: DisplayType = .primary) {
        let indentation = String(repeating: " ", count: indent * 2)
        switch type {
        case .primary:
            print("\(indentation)\"\(self)\"\n", terminator: "")
        case .key:
            print("\(indentation)\"\(self)\"", terminator: "")
        case .value:
            print("\"\(self)\"\n", terminator: "")
        }
    }
}

extension NSData {
    func display(_ indent: Int = 0, type: DisplayType = .primary) {
        let indentation = String(repeating: " ", count: indent * 2)
        switch type {
        case .primary:
            print("\(indentation)\"\(self)\"\n", terminator: "")
        case .key:
            print("\(indentation)\"\(self)\"", terminator: "")
        case .value:
            print("\"\(self)\"\n", terminator: "")
        }
    }
}

extension NSDate {
    func display(_ indent: Int = 0, type: DisplayType = .primary) {
        let indentation = String(repeating: " ", count: indent * 2)
        switch type {
        case .primary:
            print("\(indentation)\"\(self)\"\n", terminator: "")
        case .key:
            print("\(indentation)\"\(self)\"", terminator: "")
        case .value:
            print("\"\(self)\"\n", terminator: "")
        }
    }
}

func displayPlist(_ plist: Any, indent: Int = 0, type: DisplayType = .primary) {
    switch plist {
    case let val as [String : Any]:
        val.display(indent, type: type)
    case let val as [Any]:
        val.display(indent, type: type)
    case let val as String:
        val.display(indent, type: type)
    case let val as Bool:
        val.display(indent, type: type)
    case let val as NSNumber:
        val.display(indent, type: type)
    case let val as NSData:
        val.display(indent, type: type)
    case let val as NSDate:
        val.display(indent, type: type)
    default:
        fatalError("unhandled type \(Swift.type(of: plist))")
    }
}

func display(_ options: Options) -> Int32 {
    if options.inputs.count < 1 {
        print("No files specified.")
        let _ = help()
        return EXIT_FAILURE
    }
    
    var doError = false
    for file in options.inputs {
        let data : Data?
        if file == "-" {
            // stdin
            data = FileHandle.standardInput.readDataToEndOfFile()
        } else {
            data = try? Data(contentsOf: URL(fileURLWithPath: file))
        }
        
        if let d = data {
            do {
                let plist = try PropertyListSerialization.propertyList(from: d, options: [], format: nil)
                displayPlist(plist)
            } catch {
                print("\(file): \(error)")
            }
            
        } else {
            print("\(file) does not exists or is not readable or is not a regular file")
            doError = true
            continue
        }
    }
    
    if doError {
        return EXIT_FAILURE
    } else {
        return EXIT_SUCCESS
    }
}

func main() -> Int32 {
    var args = ProcessInfo.processInfo.arguments
    
    if args.count < 2 {
        print("No files specified.")
        return EXIT_FAILURE
    }
    
    // Throw away process path
    args.removeFirst()
    do {
        let opts = try parseArguments(args)
        switch opts.mode {
            case .lint:
                return lint(opts)
            case .convert:
                return convert(opts)
            case .print:
                return display(opts)
            case .help:
                return help()
        }
    } catch {
        switch error as! OptionParseError {
            case .unrecognizedArgument(let arg):
                print("unrecognized option: \(arg)")
                let _ = help()
            case .invalidFormat(let format):
                print("unrecognized format \(format)\nformat should be one of: xml1 binary1 json")
            case .missingArgument(let errorStr):
                print(errorStr)
        }
        return EXIT_FAILURE
    }
}

exit(main())

