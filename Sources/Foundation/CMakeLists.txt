add_library(Foundation
  AffineTransform.swift
  Array.swift
  AsyncCharacterSequence.swift
  AsyncLineSequence.swift
  AsyncUnicodeScalarSequence.swift
  AttributedString/AttributedString.swift
  AttributedString/AttributedStringAttribute.swift
  AttributedString/AttributedStringCodable.swift
  AttributedString/AttributedStringRunCoalescing.swift
  AttributedString/AttributedString+Locking.swift
  Boxing.swift
  Bridging.swift
  Bundle.swift
  ByteCountFormatter.swift
  Calendar.swift
  CGFloat.swift
  CharacterSet.swift
  Codable.swift
  Collections+DataProtocol.swift
  ContiguousBytes.swift
  AttributedString/Conversion.swift
  Data.swift
  DataProtocol.swift
  Date.swift
  DateComponents.swift
  DateComponentsFormatter.swift
  DateFormatter.swift
  DateInterval.swift
  DateIntervalFormatter.swift
  Decimal.swift
  Dictionary.swift
  DispatchData+DataProtocol.swift
  EnergyFormatter.swift
  ExtraStringAPIs.swift
  FileHandle.swift
  FileHandle+Async.swift
  FileManager.swift
  FileManager+POSIX.swift
  FileManager+Win32.swift
  FileManager+XDG.swift
  Formatter.swift
  AttributedString/FoundationAttributes.swift
  FoundationErrors.swift
  Host.swift
  IndexPath.swift
  IndexSet.swift
  ISO8601DateFormatter.swift
  JSONDecoder.swift
  JSONEncoder.swift
  JSONSerialization.swift
  JSONSerialization+Parser.swift
  LengthFormatter.swift
  Locale.swift
  MassFormatter.swift
  Measurement.swift
  MeasurementFormatter.swift
  Morphology.swift
  Notification.swift
  NotificationQueue.swift
  NSArray.swift
  NSAttributedString.swift
  NSCache.swift
  NSCalendar.swift
  NSCFArray.swift
  NSCFBoolean.swift
  NSCFCharacterSet.swift
  NSCFDictionary.swift
  NSCFSet.swift
  NSCFString.swift
  NSCFTypeShims.swift
  NSCharacterSet.swift
  NSCoder.swift
  NSComparisonPredicate.swift
  NSCompoundPredicate.swift
  NSConcreteValue.swift
  NSData+DataProtocol.swift
  NSData.swift
  NSDate.swift
  NSDateComponents.swift
  NSDecimalNumber.swift
  NSDictionary.swift
  NSEnumerator.swift
  NSError.swift
  NSExpression.swift
  NSGeometry.swift
  NSIndexPath.swift
  NSIndexSet.swift
  NSKeyedArchiver.swift
  NSKeyedArchiverHelpers.swift
  NSKeyedCoderOldStyleArray.swift
  NSKeyedUnarchiver.swift
  NSLocale.swift
  NSLock.swift
  NSLog.swift
  NSMeasurement.swift
  NSNotification.swift
  NSNull.swift
  NSNumber.swift
  NSObjCRuntime.swift
  NSObject.swift
  NSOrderedSet.swift
  NSPathUtilities.swift
  NSPersonNameComponents.swift
  NSPlatform.swift
  NSPredicate.swift
  NSRange.swift
  NSRegularExpression.swift
  NSSet.swift
  NSSortDescriptor.swift
  NSSpecialValue.swift
  NSString.swift
  NSStringAPI.swift
  NSSwiftRuntime.swift
  NSTextCheckingResult.swift
  NSTimeZone.swift
  NSURL.swift
  NSURLComponents.swift
  NSURLQueryItem.swift
  NSURLError.swift
  NSUUID.swift
  NSValue.swift
  NumberFormatter.swift
  Operation.swift
  PersonNameComponents.swift
  PersonNameComponentsFormatter.swift
  Pointers+DataProtocol.swift
  Port.swift
  PortMessage.swift
  Process.swift
  ProcessInfo.swift
  Progress.swift
  ProgressFraction.swift
  PropertyListEncoder.swift
  PropertyListSerialization.swift
  ReferenceConvertible.swift
  RunLoop.swift
  Scanner.swift
  ScannerAPI.swift
  Set.swift
  Stream.swift
  String.swift
  StringEncodings.swift
  Thread.swift
  Timer.swift
  TimeZone.swift
  Unit.swift
  URL.swift
  URL+AsyncBytes.swift
  URLComponents.swift
  URLQueryItem.swift
  URLResourceKey.swift
  UserDefaults.swift
  UUID.swift
  WinSDK+Extensions.swift)
target_compile_definitions(Foundation PRIVATE
  DEPLOYMENT_RUNTIME_SWIFT)
if(Threads_FOUND)
  target_compile_definitions(Foundation PRIVATE
    SWIFT_CORELIBS_FOUNDATION_HAS_THREADS)
  target_compile_options(Foundation PRIVATE
    "SHELL:-Xcc -DSWIFT_CORELIBS_FOUNDATION_HAS_THREADS")
endif()

target_compile_options(Foundation PUBLIC
  $<$<BOOL:${ENABLE_TESTING}>:-enable-testing>
  "SHELL:-Xfrontend -disable-autolink-framework -Xfrontend CoreFoundation"
  "SHELL:-Xcc -F${CMAKE_BINARY_DIR}")
target_link_libraries(Foundation
  PRIVATE
    $<$<PLATFORM_ID:Windows>:CoreFoundationResources>
    $<$<PLATFORM_ID:Windows>:Ole32>
    $<$<PLATFORM_ID:Windows>:Shell32>
    $<$<PLATFORM_ID:Windows>:pathcch>
    CoreFoundation
    uuid
  PUBLIC
    swiftDispatch)
if("${CMAKE_C_COMPILER_TARGET}" MATCHES ".*-musl[^-*]$")
  target_link_libraries(Foundation
    PUBLIC
      fts)
endif()
set_target_properties(Foundation PROPERTIES
  INSTALL_RPATH "$ORIGIN"
  BUILD_RPATH "$<TARGET_FILE_DIR:swiftDispatch>"
  Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_BINARY_DIR}/swift)

if(NOT BUILD_SHARED_LIBS)
  # ICU_I18N_LIBRARY is set by find_package(ICU) in the top level CMakeLists.txt
  # It's an absolute path to the found library file
  get_target_property(icui18n_path ICU::i18n IMPORTED_LOCATION)
  get_filename_component(icu_i18n_basename "${icui18n_path}" NAME_WE)
  get_filename_component(icu_i18n_dir "${icui18n_path}" DIRECTORY)
  string(REPLACE "lib" "" icu_i18n_basename "${icu_i18n_basename}")

  get_target_property(icuuc_path ICU::uc IMPORTED_LOCATION)
  get_filename_component(icu_uc_basename "${icuuc_path}" NAME_WE)
  string(REPLACE "lib" "" icu_uc_basename "${icu_uc_basename}")

  get_target_property(icudata_path ICU::data IMPORTED_LOCATION)
  get_filename_component(icu_data_basename "${icudata_path}" NAME_WE)
  string(REPLACE "lib" "" icu_data_basename "${icu_data_basename}")

  target_compile_options(Foundation
    PRIVATE
      "SHELL:-Xfrontend -public-autolink-library -Xfrontend ${icu_i18n_basename}
             -Xfrontend -public-autolink-library -Xfrontend ${icu_uc_basename}
             -Xfrontend -public-autolink-library -Xfrontend ${icu_data_basename}
             -Xfrontend -public-autolink-library -Xfrontend BlocksRuntime")
  # ICU libraries are linked by absolute library path in this project,
  # but -public-autolink-library forces to resolve library path by
  # library search path given by -L, so add a directory of icui18n
  # in the search path
  target_link_directories(Foundation PUBLIC "${icu_i18n_dir}")

  # Merge private dependencies into single static objects archive
  set_property(TARGET Foundation PROPERTY STATIC_LIBRARY_OPTIONS
    $<TARGET_OBJECTS:CoreFoundation>
    $<TARGET_OBJECTS:uuid>)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL Windows)
  # NOTE: workaround for CMake which doesn't link in OBJECT libraries properly
  add_dependencies(Foundation CoreFoundationResources)
  target_link_options(Foundation PRIVATE
    $<TARGET_OBJECTS:CoreFoundationResources>)
elseif(NOT CMAKE_SYSTEM_NAME STREQUAL Darwin)
  target_link_options(Foundation PRIVATE "SHELL:-no-toolchain-stdlib-rpath")
endif()

if(CMAKE_SYSTEM_NAME STREQUAL WASI)
  target_compile_options(Foundation PRIVATE
    "SHELL:-Xcc -D_WASI_EMULATED_MMAN
           -Xcc -D_WASI_EMULATED_SIGNAL
           -Xcc -D_WASI_EMULATED_PROCESS_CLOCKS
           -Xcc -D_WASI_EMULATED_GETPID")
  # Link wasi-libc emulation libraries. Other emulation libs are also used in stdlib
  target_compile_options(Foundation
    PRIVATE
      "SHELL:-Xfrontend -public-autolink-library -Xfrontend wasi-emulated-getpid")
endif()


set_property(GLOBAL APPEND PROPERTY Foundation_EXPORTS Foundation)
_install_target(Foundation)
