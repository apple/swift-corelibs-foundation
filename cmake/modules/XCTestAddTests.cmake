set(properties "${TEST_PROPERTIES}")
set(script)
set(tests)
set(dll_library_path)

function(add_command NAME)
  set(_args "")
  foreach(_arg ${ARGN})
    if(_arg MATCHES "[^-./:a-zA-Z0-9_]")
      set(_args "${_args} [==[${_arg}]==]")
    else()
      set(_args "${_args} ${_arg}")
    endif()
  endforeach()
  set(script "${script}${NAME}(${_args})\n" PARENT_SCOPE)
endfunction()

if(NOT EXISTS "${TEST_EXECUTABLE}")
  message(FATAL_ERROR
    "Specified test executable does not exist.\n"
    "  Path: '${TEST_EXECUTABLE}'"
  )
endif()
# We need to figure out if some environment is needed to run the test listing.
cmake_parse_arguments("_properties" "" "" "ENVIRONMENT" ${properties})
if(_properties_ENVIRONMENT)
  foreach(_env ${_properties_ENVIRONMENT})
    string(REGEX REPLACE "([a-zA-Z0-9_]+)=(.*)" "\\1" _key "${_env}")
    string(REGEX REPLACE "([a-zA-Z0-9_]+)=(.*)" "\\2" _value "${_env}")
    if(NOT "${_key}" STREQUAL "")
      set(ENV{${_key}} "${_value}")
    endif()
  endforeach()
endif()
# Set Path to avoid DLL missing
if (DEFINED ENV{DLL_LIBRARY_PATH} AND CMAKE_HOST_SYSTEM_NAME STREQUAL Windows)
  string(REPLACE "?" ";" dll_library_path "$ENV{DLL_LIBRARY_PATH}")
  set(ENV{Path} "${dll_library_path};$ENV{Path}")
  string(REPLACE ";" "\\\\;" dll_library_path "${dll_library_path}")
endif()

execute_process(
  COMMAND "${TEST_EXECUTABLE}" --list-tests
  WORKING_DIRECTORY "${TEST_WORKING_DIR}"
  TIMEOUT ${TEST_DISCOVERY_TIMEOUT}
  OUTPUT_VARIABLE output
  ERROR_VARIABLE error_output
  RESULT_VARIABLE result
)
if(NOT ${result} EQUAL 0)
  string(REPLACE "\n" "\n    " output "${output}")
  string(REPLACE "\n" "\n    " error_output "${error_output}")
  message(FATAL_ERROR
    "Error running test executable.\n"
    "  Path: '${TEST_EXECUTABLE}'\n"
    "  Result: ${result}\n"
    "  Output:\n"
    "    ${output}\n"
    "  Error:\n"
    "    ${error_output}\n"
  )
endif()

string(REPLACE "\n" ";" output "${output}")

foreach(line ${output})
  if(line MATCHES "^[ \t]*$")
    continue()
  elseif(line MATCHES "^Listing [0-9]+ tests? in .+:$")
    continue()
  elseif(line MATCHES "^.+\\..+/.+$")
    # TODO: remove non-ASCII characters from module, class and method names
    set(pretty_target "${line}")
    string(REGEX REPLACE "/" "-" pretty_target "${pretty_target}")
    add_command(add_test
      "${pretty_target}"
      "${TEST_EXECUTABLE}"
      "${line}"
    )
    add_command(set_tests_properties
      "${pretty_target}"
      PROPERTIES
      WORKING_DIRECTORY "${TEST_WORKING_DIR}"
      ${properties}
    )
    if (NOT "${dll_library_path}" STREQUAL "")
      add_command(set_tests_properties
        "${pretty_target}"
        PROPERTIES
        ENVIRONMENT "Path=${dll_library_path}"
      )
    endif()
    list(APPEND tests "${pretty_target}")
  else()
    message(FATAL_ERROR
      "Error parsing test executable output.\n"
      "  Path: '${TEST_EXECUTABLE}'\n"
      "  Line: '${line}'"
    )
  endif()
endforeach()

add_command(set "${TARGET}_TESTS" ${tests})

file(WRITE "${CTEST_FILE}" "${script}")
