// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let platformsWithThreads: [Platform] = [
    .iOS,
    .macOS,
    .tvOS,
    .watchOS,
    .macCatalyst,
    .driverKit,
    .android,
    .linux,
]
let buildSettings: [CSetting] = [
    .headerSearchPath("internalInclude"),
    .define("DEBUG", .when(configuration: .debug)),
    .define("CF_BUILDING_CF"),
    .define("DEPLOYMENT_RUNTIME_SWIFT"),
    .define("DEPLOYMENT_ENABLE_LIBDISPATCH"),
    .define("HAVE_STRUCT_TIMESPEC"),
    .define("SWIFT_CORELIBS_FOUNDATION_HAS_THREADS", .when(platforms: platformsWithThreads)),
    .define("_GNU_SOURCE", .when(platforms: [.linux, .android])),
    .define("CF_CHARACTERSET_UNICODE_DATA_L", to: "\"\(Context.packageDirectory)/Sources/CoreFoundation/CFUnicodeData-L.mapping\""),
    .define("CF_CHARACTERSET_UNICODE_DATA_B", to: "\"\(Context.packageDirectory)/Sources/CoreFoundation/CFUnicodeData-B.mapping\""),
    .define("CF_CHARACTERSET_UNICHAR_DB", to: "\"\(Context.packageDirectory)/Sources/CoreFoundation/CFUniCharPropertyDatabase.data\""),
    .define("CF_CHARACTERSET_BITMAP", to: "\"\(Context.packageDirectory)/Sources/CoreFoundation/CFCharacterSetBitmaps.bitmap\""),
    .define("_WASI_EMULATED_SIGNAL", .when(platforms: [.wasi])),
    .define("HAVE_STRLCPY", .when(platforms: [.wasi])),
    .define("HAVE_STRLCAT", .when(platforms: [.wasi])),
    .unsafeFlags([
        "-Wno-shorten-64-to-32",
        "-Wno-deprecated-declarations",
        "-Wno-unreachable-code",
        "-Wno-conditional-uninitialized",
        "-Wno-unused-variable",
        "-Wno-unused-function",
        "-Wno-microsoft-enum-forward-reference",
        "-fconstant-cfstrings",
        "-fexceptions", // TODO: not on OpenBSD
        "-fdollars-in-identifiers",
        "-fno-common",
        "-fcf-runtime-abi=swift",
        // /EHsc for Windows
    ]),
    .unsafeFlags(["-I/usr/lib/swift"], .when(platforms: [.linux, .android])) // dispatch
]

// For _CFURLSessionInterface, _CFXMLInterface
let interfaceBuildSettings: [CSetting] = [
    .headerSearchPath("../CoreFoundation/internalInclude"),
    .headerSearchPath("../CoreFoundation/include"),
    .define("DEBUG", .when(configuration: .debug)),
    .define("CF_BUILDING_CF"),
    .define("DEPLOYMENT_RUNTIME_SWIFT"),
    .define("DEPLOYMENT_ENABLE_LIBDISPATCH"),
    .define("HAVE_STRUCT_TIMESPEC"),
    .define("SWIFT_CORELIBS_FOUNDATION_HAS_THREADS", .when(platforms: platformsWithThreads)),
    .define("_GNU_SOURCE", .when(platforms: [.linux, .android])),
    .define("_WASI_EMULATED_SIGNAL", .when(platforms: [.wasi])),
    .define("HAVE_STRLCPY", .when(platforms: [.wasi])),
    .define("HAVE_STRLCAT", .when(platforms: [.wasi])),
    .unsafeFlags([
        "-Wno-shorten-64-to-32",
        "-Wno-deprecated-declarations",
        "-Wno-unreachable-code",
        "-Wno-conditional-uninitialized",
        "-Wno-unused-variable",
        "-Wno-unused-function",
        "-Wno-microsoft-enum-forward-reference",
        "-fconstant-cfstrings",
        "-fexceptions", // TODO: not on OpenBSD
        "-fdollars-in-identifiers",
        "-fno-common",
        "-fcf-runtime-abi=swift"
        // /EHsc for Windows
    ]),
    .unsafeFlags(["-I/usr/lib/swift"], .when(platforms: [.linux, .android])) // dispatch
]

let package = Package(
    name: "swift-corelibs-foundation",
    platforms: [.macOS("13.3"), .iOS("16.4"), .tvOS("16.4"), .watchOS("9.4")],
    products: [
        .library(name: "Foundation", targets: ["Foundation"]),
        .library(name: "FoundationXML", targets: ["FoundationXML"]),
        .library(name: "FoundationNetworking", targets: ["FoundationNetworking"]),
        .executable(name: "plutil", targets: ["plutil"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-foundation-icu",
            from: "0.0.5"),
        .package(
           url: "https://github.com/apple/swift-foundation",
           revision: "7eb8b598ad8f77ac743b2decc97d56bf350aedee"
        ),
    ],
    targets: [
        .target(
            name: "Foundation",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation"),
                .product(name: "FoundationInternationalization", package: "swift-foundation"),
                "_CoreFoundation"
            ],
            path: "Sources/Foundation",
            swiftSettings: [
              .define("DEPLOYMENT_RUNTIME_SWIFT"),
              .define("SWIFT_CORELIBS_FOUNDATION_HAS_THREADS", .when(platforms: platformsWithThreads))
            ]
        ),
        .target(
            name: "FoundationXML",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation"),
                "Foundation",
                "_CoreFoundation",
                "_CFXMLInterface"
            ],
            path: "Sources/FoundationXML",
            swiftSettings: [
              .define("DEPLOYMENT_RUNTIME_SWIFT"),
              .define("SWIFT_CORELIBS_FOUNDATION_HAS_THREADS", .when(platforms: platformsWithThreads))
            ]
        ),
        .target(
            name: "FoundationNetworking",
            dependencies: [
                .product(name: "FoundationEssentials", package: "swift-foundation"),
                "Foundation",
                "_CoreFoundation",
                "_CFURLSessionInterface"
            ],
            path: "Sources/FoundationNetworking",
            swiftSettings: [
              .define("DEPLOYMENT_RUNTIME_SWIFT"),
              .define("SWIFT_CORELIBS_FOUNDATION_HAS_THREADS", .when(platforms: platformsWithThreads))
            ]
        ),
        .target(
            name: "_CoreFoundation",
            dependencies: [
                .product(name: "FoundationICU", package: "swift-foundation-icu"),
            ],
            path: "Sources/CoreFoundation",
            cSettings: buildSettings
        ),
        .target(
            name: "_CFXMLInterface",
            dependencies: [
                "_CoreFoundation",
                "Clibxml2",
            ],
            path: "Sources/_CFXMLInterface",
            cSettings: interfaceBuildSettings
        ),
        .target(
            name: "_CFURLSessionInterface",
            dependencies: [
                "_CoreFoundation",
                "Clibcurl",
            ],
            path: "Sources/_CFURLSessionInterface",
            cSettings: interfaceBuildSettings
        ),
        .systemLibrary(
            name: "Clibxml2",
            pkgConfig: "libxml-2.0",
            providers: [
                .brew(["libxml2"]),
                .apt(["libxml2-dev"])
            ]
        ),
        .systemLibrary(
            name: "Clibcurl",
            pkgConfig: "libcurl",
            providers: [
                .brew(["libcurl"]),
                .apt(["libcurl"])
            ]
        ),
        .executableTarget(
            name: "plutil",
            dependencies: ["Foundation"]
        ),
        .executableTarget(
            name: "xdgTestHelper",
            dependencies: [
                "Foundation",
                "FoundationNetworking"
            ]
        ),
        .target(
            // swift-corelibs-foundation has a copy of XCTest's sources so:
            // (1) we do not depend on the toolchain's XCTest, which depends on toolchain's Foundation, which we cannot pull in at the same time as a Foundation package
            // (2) we do not depend on a swift-corelibs-xctest Swift package, which depends on Foundation, which causes a circular dependency in swiftpm
            // We believe Foundation is the only project that needs to take this rather drastic measure.
            name: "XCTest", 
            dependencies: [
                "Foundation"
            ], 
            path: "Sources/XCTest"
        ),
        .testTarget(
            name: "TestFoundation",
            dependencies: [
                "Foundation",
                "FoundationXML",
                "FoundationNetworking",
                "XCTest",
                "xdgTestHelper"
            ],
            resources: [
                .copy("Foundation/Resources")
            ],
            swiftSettings: [
                .define("NS_FOUNDATION_ALLOWS_TESTABLE_IMPORT")
            ]
        ),
    ]
)
