add_library(uuid STATIC
  uuid.h
  uuid.c)
if(CMAKE_SYSTEM_NAME STREQUAL Windows)
  target_compile_definitions(uuid PRIVATE
    _CRT_NONSTDC_NO_WARNINGS
    _CRT_SECURE_NO_DEPRECATE
    _CRT_SECURE_NO_WARNINGS)
endif()

# Add an include directory for the CoreFoundation framework headers to satisfy
# the dependency on TargetConditionals.h
add_dependencies(uuid CoreFoundation)
target_include_directories(uuid PUBLIC
  ${CMAKE_BINARY_DIR}/CoreFoundation.framework/Headers)

if(CMAKE_SYSTEM_NAME STREQUAL Windows)
  target_link_libraries(uuid PRIVATE Bcrypt)
endif()
set_target_properties(uuid PROPERTIES
  POSITION_INDEPENDENT_CODE YES)

if(NOT BUILD_SHARED_LIBS)
  set_property(GLOBAL APPEND PROPERTY Foundation_EXPORTS uuid)

  # get_swift_host_arch(swift_arch)

  # TODO(drexin): should be installed in architecture specific folder, once
  # the layout is fixed for non-Darwin platforms
  install(TARGETS uuid
    ARCHIVE DESTINATION lib/swift_static/${SWIFT_SYSTEM_NAME}
    LIBRARY DESTINATION lib/swift_static/${SWIFT_SYSTEM_NAME}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()
