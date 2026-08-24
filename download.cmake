# Usage with vcpkg x-script:
# export X_VCPKG_ASSET_SOURCES="clear;x-script,cmake -DURL={url} -DSHA512={sha512} -DDST_FILE={dst} -DPROXY=proxy.example.com -DPROXY_USERNAME=user -DPROXY_PASSWORD=secret -DPROXY_ROUTES=$VCPKG_ROOT/scripts/routes.txt -DTLS_VERIFY=ON -P $VCPKG_ROOT/scripts/download.cmake;x-block-origin"

cmake_minimum_required(VERSION 3.19)

function(require_args)
    set(expected_args
        URL
        SHA512
        DST_FILE
        PROXY
        PROXY_USERNAME
        PROXY_PASSWORD
        PROXY_ROUTES
        TLS_VERIFY
    )
    cmake_parse_arguments(arg "" "${expected_args}" "" ${ARGN})

    set(help "Usage:\n  cmake")
    foreach(expected IN LISTS expected_args)
        string(TOLOWER "${expected}" placeholder)
        string(APPEND help " -D${expected}=<${placeholder}>")
    endforeach()
    string(APPEND help " -P download.cmake")

    foreach(expected IN LISTS expected_args)
        if(NOT arg_${expected})
            message(FATAL_ERROR "require_args is missing a destination for ${expected}")
        endif()
        if(NOT DEFINED ${expected})
            message(FATAL_ERROR "Missing ${expected}\n${help}")
        endif()
        set(${arg_${expected}} "${${expected}}" PARENT_SCOPE)
    endforeach()
endfunction()

require_args(
    URL            url
    SHA512         expected_sha512
    DST_FILE       dst_file
    PROXY          proxy
    PROXY_USERNAME proxy_username
    PROXY_PASSWORD proxy_password
    PROXY_ROUTES   proxy_routes
    TLS_VERIFY     tls_verify
)

if(NOT EXISTS "${proxy_routes}")
    message(FATAL_ERROR "Proxy route file does not exist: ${proxy_routes}")
endif()

file(STRINGS "${proxy_routes}" routes)
if(NOT routes)
    message(FATAL_ERROR "Proxy route file is empty: ${proxy_routes}")
endif()

set(proxy_download_url "")
foreach(route IN LISTS routes)
    string(REPLACE " " ";" fields "${route}")
    list(GET fields 0 origin)
    list(GET fields 1 proxy_path)

    if(url MATCHES "${origin}")
        string(REPLACE "${origin}" "https://${proxy}/${proxy_path}" proxy_download_url "${url}")
        break()
    endif()
endforeach()

if(proxy_download_url STREQUAL "")
    message(FATAL_ERROR "URL is not routed through the configured proxy: ${url}")
endif()

file(DOWNLOAD
    "${proxy_download_url}"
    "${dst_file}"
    TLS_VERIFY "${tls_verify}"
    TIMEOUT 120
    STATUS download_status
    LOG download_log
    USERPWD "${proxy_username}:${proxy_password}"
)

list(GET download_status 0 status_code)
list(GET download_status 1 status_message)
if(NOT status_code EQUAL 0)
    file(REMOVE "${dst_file}")
    message(VERBOSE "Downloader log:\n${download_log}")
    message(FATAL_ERROR "Proxy download failed (${status_code}): ${status_message}")
endif()

file(SHA512 "${dst_file}" actual_sha512)
string(TOLOWER "${expected_sha512}" expected_sha512)
if(NOT actual_sha512 STREQUAL expected_sha512)
    file(REMOVE "${dst_file}")
    message(FATAL_ERROR
        "Proxy download SHA512 mismatch for ${url}\n"
        "Expected: ${expected_sha512}\n"
        "Actual:   ${actual_sha512}"
    )
endif()

message(STATUS "Downloaded ${url} through the configured proxy")
