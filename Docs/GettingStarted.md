# Getting Started

## On macOS

Although macOS is not a deployment platform for Swift Foundation, it is useful for development and test purposes.

In order to build on macOS, you will need:

* The latest version of Xcode
* The latest version of the macOS SDK (at this time: 10.15)
* The [current Swift toolchain](https://swift.org/download/#snapshots).

> Note: due to https://bugs.swift.org/browse/SR-12177 the default Xcode toolchain should be used for now.

Foundation is developed at the same time as the rest of Swift, so the most recent version of the compiler is required in order to build it.

The repository includes an Xcode project file as well as an Xcode workspace. The workspace includes both Foundation and XCTest, which makes it easy to build and run everything together. The workspace assumes that Foundation and XCTest are checked out from GitHub in sibling directories. For example:

```sh
cd Development
ls
swift-corelibs-foundation swift-corelibs-xctest
```

Build and test steps:

0. Run Xcode with the latest toolchain. Follow [the instructions here](https://swift.org/download/#installation) to start Xcode with the correct toolchain.
0. Open `Foundation.xcworkspace`.
0. Build the _SwiftFoundation_ target. This builds CoreFoundation and Foundation.
0. Run (Cmd-R) the _TestFoundation_ target. This builds CoreFoundation, Foundation, XCTest, and TestFoundation, then runs the tests.

> Note: If you see the name of the XCTest project file in red in the workspace, then Xcode cannot find the cloned XCTest repository. Make sure that it is located next to the `swift-corelibs-foundation` directory and has the name `swift-corelibs-xctest`.

### Darwin Compatibility Tests

In order to increase the compatibility between corelibs-foundation and the native Foundation shipped with macOS, there is another Xcode project in the `swift-corelibs-foundation` repository called `DarwinCompatibilityTests.xcodeproj`. This project just runs all of the `TestFoundation` tests using native Foundation. Ideally, any new test written for corelibs-foundation should be tested against
native Foundation to validate that that test is correct. The tests can be run individually using the Test navigator in the left hand pane.

It should be noted that not all tests currently run correctly either due to differences between the two implementations, the test being used to validate some
internal functionality of corelibs-foundation or the test (and the implementation) actually being incorrect. Overtime these test differences should be reduced as compatibility is increased.


## On Linux

You will need:

* A supported distribution of Linux. At this time, we support [Ubuntu 16.04 and Ubuntu 18.04](http://www.ubuntu.com).

To get started, follow the instructions on how to [build Swift](https://github.com/apple/swift/blob/main/docs/HowToGuides/GettingStarted.md#building-the-project-for-the-first-time). Foundation is developed at the same time as the rest of Swift, so the most recent version of the `clang` and `swift` compilers are required in order to build it. The easiest way to make sure you have all of the correct dependencies is to build everything together.

The default build script does not include Foundation. To configure and build Foundation and TestFoundation including lldb for debugging and the correct ICU library, the following command can be used. All other tests are disabled to reduce build and test time. `--release` is used to avoid building LLVM and the compiler with debugging.

```sh
swift/utils/build-script  --libicu --lldb --release --test --foundation --xctest \
  --foundation-build-type=debug  --skip-test-swift --skip-build-benchmarks \
  --skip-test-lldb --skip-test-xctest --skip-test-libdispatch --skip-test-libicu --skip-test-cmark
```

The build artifacts will be written to the subdirectory `build/Ninja-ReleaseAssert`. To use a different build directory set the `SWIFT_BUILD_ROOT` environment variable to point to a different directory to use instead of `build`.

When developing on Foundation, it is simplest to write tests to check the functionality, even if the test is not something that can be used in the final PR, e.g. it runs continuously to demonstrate a memory leak. Tests are added
to the appropriate file in the  `TestFoundation` directory, and remember to add the test in to the `allTests` array in that file.

After the complete Swift build has finished you can iterate over changes you make to Foundation using `cmake` to build `TestFoundation` and run the tests.
Note that `cmake` needs to be a relatively recent version, currently 3.15.1, and if this is not installed already
then it is built as part of the `build-script` invocation. Therefore `cmake` may be installed in `build/cmake`.

```sh
export BUILD_DIR=build/Ninja-ReleaseAssert
# Build TestFoundation
build/cmake-linux-x86_64/bin/cmake --build $BUILD_DIR/foundation-linux-x86_64/ -v -- -j4 TestFoundation
# Run the tests
build/cmake-linux-x86_64/bin/cmake --build $BUILD_DIR/foundation-linux-x86_64/ -v -- -j4 test
```

If `TestFoundation` needs to be run outside of `ctest`, perhaps to run under `lldb`  or to run individual tests, then it can be run directly but an appropriate `LD_LIBRARY_PATH`
needs to be set so that `libdispatch` and `libXCTest` can be found.

```sh
export BUILD_DIR=build/Ninja-ReleaseAssert
export LD_LIBRARY_PATH=$BUILD_DIR/foundation-linux-x86_64/Foundation:$BUILD_DIR/xctest-linux-x86_64:$BUILD_DIR/libdispatch-linux-x86_64
$BUILD_DIR/foundation-linux-x86_64/TestFoundation.app/TestFoundation
```

To run only one test class or a single test, the tests to run can be specified as a command argument in the form of `TestFoundation.<TestClass>{/testName}` eg to run all of the tests in `TestDate` use
`TestFoundation.TestDate`. To run just `test_BasicConstruction`, use `TestFoundation.TestDate/test_BasicConstruction`.

If the tests need to be run under `lldb`, use the following command:

```sh
export BUILD_DIR=build/Ninja-ReleaseAssert
export LD_LIBRARY_PATH=$BUILD_DIR/foundation-linux-x86_64/Foundation:$BUILD_DIR/xctest-linux-x86_64:$BUILD_DIR/libdispatch-linux-x86_64
$BUILD_DIR/lldb-linux-x86_64/bin/lldb $BUILD_DIR/foundation-linux-x86_64/TestFoundation.app/TestFoundation
```

When new source files or flags are added to any of the `CMakeLists.txt` files, the project will need to be reconfigured in order for the build system to pick them up. Simply rerun the `cmake` command to build `TestFoundation` given above and it should be reconfigured and built correctly. 

If `update-checkout` is used to update other repositories, rerun the `build-script` command above to reconfigure and rebuild the other libraries.
