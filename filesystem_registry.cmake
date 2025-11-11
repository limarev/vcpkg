# Minimal filesystem registry generator for vcpkg (no CONTROL fallback)
# Requires: CMake 3.19+ (for string(JSON))
# Usage:
#   cmake -P make_fs_registry.cmake -- --registry-root <path> --baseline-name <name> [--dry-run] [--strict]

cmake_minimum_required(VERSION 3.19)

if(NOT CMAKE_SCRIPT_MODE_FILE)
  message(FATAL_ERROR "Run this file with: cmake -P make_fs_registry.cmake -- --registry-root <path> --baseline-name <name> [--dry-run] [--strict]")
endif()

# ---- Functions ----
function(require_args)
  set(expectedArgs SOURCE_REGISTRY_DIR BASELINE DST_DIR)
  cmake_parse_arguments(ra "" "${expectedArgs}" "" ${ARGN})

  # validate that destination var names (right-hand values) were provided
  foreach(_arg IN LISTS expectedArgs)
    if(NOT ra_${_arg})
      message(FATAL_ERROR "${_arg} argument is required")
    endif()
  endforeach()

  # help message template
  set(_help "Usage:\n  cmake -P download.cmake")
  foreach(_arg IN LISTS expectedArgs)
    string(TOLOWER "${_arg}" _arg_lower_case)
    string(APPEND _help " -D${_arg}=<${_arg_lower_case}>")
  endforeach()

  # set arg if passed to script, otherwise error
  foreach(_arg IN LISTS expectedArgs)
    message(CHECK_START "Check if ${_arg} is set")
    if(NOT ${_arg})
      message(CHECK_FAIL "false. Missing ${_arg}")
      string(APPEND _help "\nMissing ${_arg}")
      message(FATAL_ERROR "${_help}")
    else()
      # Set into the destination variable name provided to this function
      # e.g. URL -> _url, SHA512 -> _sha512, etc.
      set(${ra_${_arg}} "${${_arg}}" PARENT_SCOPE)
      message(CHECK_PASS "true. Using passed value: ${${_arg}}")
    endif()
  endforeach()
endfunction()

function(json_escape OUT IN)
  # Escape \, ", and control chars commonly seen in versions
  set(s "${IN}")
  string(REPLACE "\\" "\\\\" s "${s}")
  string(REPLACE "\"" "\\\"" s "${s}")
  string(REPLACE "\n" "\\n" s "${s}")
  string(REPLACE "\r" "\\r" s "${s}")
  string(REPLACE "\t" "\\t" s "${s}")
  set(${OUT} "${s}" PARENT_SCOPE)
endfunction()

function(first_letter_prefix OUT PORT_NAME)
  string(SUBSTRING "${PORT_NAME}" 0 1 _c)
  string(TOLOWER "${_c}" _c)
  set(${OUT} "${_c}-" PARENT_SCOPE)
endfunction()

function(check_if_exists ARG_NAME VAR_NAME)
  message(CHECK_START "Check if ${ARG_NAME} exists: ${${VAR_NAME}}")
  if(NOT EXISTS "${${VAR_NAME}}")
    message(CHECK_FAIL "false. ${${VAR_NAME}} doesn't exist")
    message(FATAL_ERROR "${${VAR_NAME}} doesn't exist")
  else()
    message(CHECK_PASS "true")
  endif()
endfunction()

# ---- End of functions ----

# ---- argument parsing ----
# Pull script args into local vars and verify
require_args(
  SOURCE_REGISTRY_DIR     _source_registry_dir
  BASELINE                _baseline_name
  DST_DIR                 _dst_dir
)

cmake_path(ABSOLUTE_PATH _source_registry_dir BASE_DIRECTORY ${CMAKE_CURRENT_LIST_DIR} NORMALIZE)
message(VERBOSE "Normalized SOURCE_REGISTRY_DIR: ${_source_registry_dir}")

set(_ports_dir ${_source_registry_dir})
cmake_path(APPEND _ports_dir "ports")
message(VERBOSE "Normalized ports dir: ${_ports_dir}")

cmake_path(ABSOLUTE_PATH _dst_dir BASE_DIRECTORY ${CMAKE_CURRENT_LIST_DIR} NORMALIZE)
message(VERBOSE "Normalized DST_DIR: ${_dst_dir}")

set(_versions_dir ${_dst_dir})
cmake_path(APPEND _versions_dir "versions")

# existent checks
# check_if_exists(SOURCE_REGISTRY_DIR _source_registry_dir)
check_if_exists("ports dir" _ports_dir)

# ----------------------- scan ports -----------------------
file(GLOB _children RELATIVE "${_ports_dir}" "${_ports_dir}/*")
if(NOT _children)
  message(FATAL_ERROR "No entries under ${_ports_dir}")
endif()
list(SORT _children)

set(_baseline_items "")       # will hold  "  \"port\": { \"baseline\": \"ver\", \"port-version\": N }" lines
set(_first TRUE)
set(_ports_indexed 0)
set(_skipped 0)

foreach(_name IN LISTS _children)
  if(NOT IS_DIRECTORY "${_ports_dir}/${_name}")
    continue()
  endif()

  set(_vj "${_ports_dir}/${_name}/vcpkg.json")
  if(NOT EXISTS "${_vj}")
    if(STRICT)
      message(FATAL_ERROR "${_name}: missing vcpkg.json")
    else()
      math(EXPR _skipped "${_skipped}+1")
      message(WARNING "${_name}: no vcpkg.json; skipped")
      continue()
    endif()
  endif()

  file(READ "${_vj}" _json)

  # Find version key (in priority order). If not present, either fail (strict) or skip.
  set(_version_key "")
  set(_version_val "")
  foreach(_k version version-semver version-date version-string)
    string(JSON _tmp ERROR_VARIABLE _err GET "${_json}" "${_k}")
    if(NOT _err)
      set(_version_key "${_k}")
      set(_version_val "${_tmp}")
      break()
    endif()
  endforeach()
  if(NOT _version_key)
    if(STRICT)
      message(FATAL_ERROR "${_name}: vcpkg.json missing version key (version|version-semver|version-date|version-string)")
    else()
      math(EXPR _skipped "${_skipped}+1")
      message(WARNING "${_name}: missing version key; skipped")
      continue()
    endif()
  endif()

  # port-version (default 0)
  string(JSON _pv_raw ERROR_VARIABLE _pv_err GET "${_json}" "port-version")
  if(_pv_err)
    set(_pv_raw "0")
  endif()
  if(_pv_raw STREQUAL "")
    set(_pv_raw "0")
  endif()
  # ensure integer
  string(REGEX MATCH "^[0-9]+" _pv "${_pv_raw}")
  if(NOT _pv)
    set(_pv "0")
  endif()

  # Escape version value for JSON
  json_escape(_ver_esc "${_version_val}")

  # Write per-port versions file
  first_letter_prefix(_pfx "${_name}")
  set(_dir "${_versions_dir}/${_pfx}")
  set(_dest "${_dir}/${_name}.json")

  set(_per_port "\
{
  \"versions\": [
    { \"path\": \"$/ports/${_name}\", \"${_version_key}\": \"${_ver_esc}\", \"port-version\": ${_pv} }
  ]
}"
  )

  if(NOT DRY_RUN)
    file(MAKE_DIRECTORY "${_dir}")
    file(WRITE "${_dest}" "${_per_port}")
  else()
    message(STATUS "would write: versions/${_pfx}${_name}.json")
    message("${_per_port}")
  endif()

  # Accumulate baseline entry
  if(_first)
    set(_first FALSE)
  else()
    string(APPEND _baseline_items ",\n")
  endif()
  string(APPEND _baseline_items "    \"${_name}\": { \"baseline\": \"${_ver_esc}\", \"port-version\": ${_pv} }")

  math(EXPR _ports_indexed "${_ports_indexed}+1")
endforeach()

if(_ports_indexed EQUAL 0)
  message(FATAL_ERROR "No valid ports with vcpkg.json were discovered.")
endif()

# ----------------------- write baseline.json -----------------------
set(_baseline "\
{
  \"${_baseline_name}\": {
${_baseline_items}
  }
}"
)

# generate versions
file(MAKE_DIRECTORY "${_versions_dir}")
file(WRITE "${_versions_dir}/baseline.json" "${_baseline}")

file(COPY ${_ports_dir} DESTINATION ${_dst_dir})
file(COPY ${_source_registry_dir}/scripts DESTINATION ${_dst_dir})
file(COPY ${_source_registry_dir}/triplets DESTINATION ${_dst_dir})
file(COPY ${_source_registry_dir}/LICENSE.txt DESTINATION ${_dst_dir})
file(COPY ${_source_registry_dir}/.vcpkg-root DESTINATION ${_dst_dir})
file(TOUCH ${_dst_dir}/vcpkg.disable-metrics)

# parse scripts/vcpkg-tool-metadata.txt
file(STRINGS ${_source_registry_dir}/scripts/vcpkg-tool-metadata.txt _METADATA_CONTENTS)

# read and set VCPKG_TOOL_RELEASE_TAG
# read and set VCPKG_MACOS_SHA
# read and set VCPKG_MUSLC_SHA
# read and set VCPKG_GLIBC_SHA
# read and set VCPKG_GLIBC_ARM64_SHA
foreach(_line IN LISTS _METADATA_CONTENTS)
  # trim whitespace
  string(STRIP "${_line}" _line)
  string(REPLACE "=" ";" _key_value_list ${_line})
  list(GET _key_value_list 0 _key)
  list(GET _key_value_list 1 _value)

  set(${_key} ${_value})
endforeach()

# TODO VCPKG_TOOL_RELEASE_TAG validation
# TODO VCPKG_MACOS_SHA validation
# TODO VCPKG_MUSLC_SHA validation
# TODO VCPKG_GLIBC_SHA validation
# TODO VCPKG_GLIBC_ARM64_SHA validation

# ---- Download vcpkg ----
# SHOW_PROGRESS prints progress; TLS_VERIFY ON for HTTPS verification; TIMEOUT to avoid hanging.
# STATUS returns a two-element list: <code> <string>.
set(_status "")
set(_log "")

# TODO sha512 validation
message(STATUS "CMAKE_HOST_SYSTEM_NAME: ${CMAKE_HOST_SYSTEM_NAME}")
if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
  set(_url "https://github.com/microsoft/vcpkg-tool/releases/download/${VCPKG_TOOL_RELEASE_TAG}/vcpkg.exe")
  set(_dst_file "${_dst_dir}/vcpkg.exe")
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
  set(_url "https://github.com/microsoft/vcpkg-tool/releases/download/${VCPKG_TOOL_RELEASE_TAG}/vcpkg-glibc")
  set(_dst_file "${_dst_dir}/vcpkg")
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
  set(_url "https://github.com/microsoft/vcpkg-tool/releases/download/${VCPKG_TOOL_RELEASE_TAG}/vcpkg-macos")
  set(_dst_file "${_dst_dir}/vcpkg")
else()
  message(FATAL_ERROR "No vcpkg asset is available for system: ${CMAKE_HOST_SYSTEM_NAME}")
endif()

file(DOWNLOAD
  "${_url}"
  "${_dst_file}"
  # SHOW_PROGRESS
  TLS_VERIFY ON
  TIMEOUT 120
  STATUS _status
  LOG _log
)

list(GET _status 0 _code)
list(GET _status 1 _msg)

if(NOT _code EQUAL 0)
  message(STATUS "Downloader log:\n${_log}")
  file(REMOVE "${_dst_file}") # Clean up partial file if any
  message(FATAL_ERROR "Download failed (${_code}): ${_msg}")
endif()

file(CHMOD "${_dst_file}" FILE_PERMISSIONS
OWNER_READ OWNER_EXECUTE OWNER_WRITE
GROUP_READ GROUP_EXECUTE
WORLD_READ WORLD_EXECUTE
)

message(STATUS "Filesystem registry generated at: ${_dst_dir}")
message(STATUS "Ports indexed: ${_ports_indexed}")
if(_skipped GREATER 0)
  message(STATUS "Ports skipped: ${_skipped}  (use --strict to fail instead)")
endif()
