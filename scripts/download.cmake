# download.cmake
# Usage with vcpkg x-script:
# export X_VCPKG_ASSET_SOURCES="clear;x-script,cmake -DURL={url} -DSHA512={sha512} -DDST_FILE={dst} -P <path to download.cmake>;x-block-origin"
#

# ---- Functions ----
function(require_args)
  set(expectedArgs URL SHA512 DST_FILE PROXY PROXY_USERNAME PROXY_PASSWORD TLS_VERIFY)
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
    if(NOT DEFINED ${_arg})
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

# ---- End of functions ----

# Pull script args into local vars and verify
require_args(
  URL            _url
  SHA512         _sha512
  DST_FILE       _dst_file
  PROXY          _proxy
  PROXY_USERNAME _username
  PROXY_PASSWORD _password
  TLS_VERIFY _tls_verify
)

set(_userpwd "${_username}:${_password}")

# Replace URL with proxy — tweak mappings as needed
if (_url MATCHES "^https://github.com")
  string(REPLACE "https://github.com"
                 "https://${_proxy}/repo/extras/github_api"
                 _url "${_url}")
elseif(_url MATCHES "^https://sourceforge.net")
  string(REPLACE "https://sourceforge.net"
                 "https://${_proxy}/repo/sourceforge"
                 _url "${_url}")
elseif(_url MATCHES "^https://download.microsoft.com")
  string(REPLACE "https://download.microsoft.com"
                 "https://${_proxy}/repo/extras/microsoft"
                 _url "${_url}")
elseif(_url MATCHES "^https://www.nuget.org")
  string(REPLACE "https://www.nuget.org"
                 "https://${_proxy}/repo/nuget_org"
                 _url "${_url}")
elseif(_url MATCHES "^https://dl.google.com")
  string(REPLACE "https://dl.google.com"
                 "https://${_proxy}/repo/google_dl"
                 _url "${_url}")
elseif(_url MATCHES "^https://storage.googleapis.com")
  string(REPLACE "https://storage.googleapis.com"
                 "https://${_proxy}/repo/go/google_storage"
                 _url "${_url}")
else()
  message(WARNING "${_url} is not routed through the proxy")
  set(_userpwd "")
endif()

# ---- Download ----
# SHOW_PROGRESS prints progress; TLS_VERIFY ON for HTTPS verification; TIMEOUT to avoid hanging.
# STATUS returns a two-element list: <code> <string>.
set(_status "")
set(_log "")

file(DOWNLOAD
  "${_url}"
  "${_dst_file}"
  # SHOW_PROGRESS
  TLS_VERIFY ${_tls_verify}
  TIMEOUT 120
  STATUS _status
  LOG _log
  USERPWD ${_userpwd}
  EXPECTED_HASH SHA512=${_sha512}
)

list(GET _status 0 _code)
list(GET _status 1 _msg)

if(NOT _code EQUAL 0)
  message(STATUS "Downloader log:\n${_log}")
  file(REMOVE "${_dst_file}") # Clean up partial file if any
  message(FATAL_ERROR "Download failed (${_code}): ${_msg}")
endif()

# ---- Done ----
message(STATUS "Downloaded:")
message(STATUS "  URL : ${_url}")
message(STATUS "  File: ${_dst_file}")
