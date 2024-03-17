if(NOT CMAKE_SYSTEM_NAME STREQUAL Darwin)
  find_package(CURL CONFIG)
  if(CURL_FOUND)
    set(CURL_VERSION_STRING ${CURL_VERSION})
  else()
    find_package(CURL REQUIRED)
  endif()
endif()

if(NOT CMAKE_SYSTEM_NAME STREQUAL Darwin)
  if((NS_CURL_ASSUME_FEATURES_MISSING) OR (CURL_VERSION_STRING VERSION_LESS "7.32.0"))
    add_compile_definitions(NS_CURL_MISSING_XFERINFOFUNCTION)
  endif()

  if((NS_CURL_ASSUME_FEATURES_MISSING) OR (CURL_VERSION_STRING VERSION_LESS "7.30.0"))
    add_compile_definitions(NS_CURL_MISSING_MAX_HOST_CONNECTIONS)
  endif()

  if((NS_CURL_ASSUME_FEATURES_MISSING) OR (CURL_VERSION_STRING VERSION_LESS "7.84.0"))
    add_compile_definitions(NS_CURL_MISSING_CURLINFO_CAINFO)
  endif()
endif()

add_library(FoundationNetworking
  ../Foundation/Boxing.swift
  DataURLProtocol.swift
  HTTPCookie.swift
  HTTPCookieStorage.swift
  NSURLRequest.swift
  URLAuthenticationChallenge.swift
  URLCache.swift
  URLCredential.swift
  URLCredentialStorage.swift
  URLProtectionSpace.swift
  URLProtocol.swift
  URLRequest.swift
  URLResponse.swift
  URLSession/BodySource.swift
  URLSession/Configuration.swift
  URLSession/FTP/FTPURLProtocol.swift
  URLSession/HTTP/HTTPMessage.swift
  URLSession/HTTP/HTTPURLProtocol.swift
  URLSession/WebSocket/WebSocketURLProtocol.swift
  URLSession/Message.swift
  URLSession/NativeProtocol.swift
  URLSession/NetworkingSpecific.swift
  URLSession/TaskRegistry.swift
  URLSession/TransferState.swift
  URLSession/URLSession.swift
  URLSession/URLSessionConfiguration.swift
  URLSession/URLSessionDelegate.swift
  URLSession/URLSessionTask.swift
  URLSession/URLSessionTaskMetrics.swift
  URLSession/libcurl/EasyHandle.swift
  URLSession/libcurl/MultiHandle.swift
  URLSession/libcurl/libcurlHelpers.swift)
target_compile_definitions(FoundationNetworking PRIVATE
  DEPLOYMENT_RUNTIME_SWIFT
  NS_BUILDING_FOUNDATION_NETWORKING)
target_compile_options(FoundationNetworking PUBLIC
  -autolink-force-load
  # SR-12254: workaround for the swift compiler not properly tracking the
  # forced load symbol when validating the TBD
  -Xfrontend -validate-tbd-against-ir=none
  $<$<BOOL:${ENABLE_TESTING}>:-enable-testing>
  "SHELL:-Xfrontend -disable-autolink-framework -Xfrontend CFURLSessionInterface"
  "SHELL:-Xcc -F${CMAKE_BINARY_DIR}")
target_link_libraries(FoundationNetworking
  PRIVATE
    CFURLSessionInterface
  PUBLIC
    Foundation)

if(NOT BUILD_SHARED_LIBS)
  target_compile_options(FoundationNetworking
    PRIVATE
      "SHELL:-Xfrontend -public-autolink-library -Xfrontend curl")

  if(BUILD_FULLY_STATIC)
    target_compile_options(FoundationNetworking
      PRIVATE
        "SHELL:-Xfrontend -public-autolink-library -Xfrontend crypto"
        "SHELL:-Xfrontend -public-autolink-library -Xfrontend ssl"
        "SHELL:-Xfrontend -public-autolink-library -Xfrontend z")
  endif()

  # Merge private dependencies into single static objects archive
  set_property(TARGET FoundationNetworking PROPERTY STATIC_LIBRARY_OPTIONS
    $<TARGET_OBJECTS:CFURLSessionInterface>)
endif()

set_target_properties(FoundationNetworking PROPERTIES
  INSTALL_RPATH "$ORIGIN"
  Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_BINARY_DIR}/swift)

if(NOT CMAKE_SYSTEM_NAME MATCHES "Darwin|Windows")
  target_link_options(FoundationNetworking PRIVATE "SHELL:-no-toolchain-stdlib-rpath")
endif()


set_property(GLOBAL APPEND PROPERTY Foundation_EXPORTS FoundationNetworking)
_install_target(FoundationNetworking)
