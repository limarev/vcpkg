cmake_minimum_required(VERSION 3.19)

foreach(required IN ITEMS URL SHA512 DST_FILE)
    if(NOT DEFINED ${required} OR "${${required}}" STREQUAL "")
        message(FATAL_ERROR "${required} is required")
    endif()
endforeach()

if(NOT DEFINED ROUTES_FILE)
    set(ROUTES_FILE "${CMAKE_CURRENT_LIST_DIR}/routes.json")
endif()
if(NOT EXISTS "${ROUTES_FILE}")
    message(FATAL_ERROR "Proxy route file does not exist: ${ROUTES_FILE}")
endif()

if(NOT DEFINED ENV{VCPKG_PROXY_URL} OR "$ENV{VCPKG_PROXY_URL}" STREQUAL "")
    message(FATAL_ERROR "VCPKG_PROXY_URL is required")
endif()

set(proxy_url "$ENV{VCPKG_PROXY_URL}")
string(REGEX REPLACE "/+$" "" proxy_url "${proxy_url}")
if(NOT proxy_url MATCHES "^https?://[^/]+")
    message(FATAL_ERROR "VCPKG_PROXY_URL must include an http:// or https:// scheme")
endif()

file(READ "${ROUTES_FILE}" routes_json)
string(JSON route_count ERROR_VARIABLE routes_error LENGTH "${routes_json}")
if(routes_error)
    message(FATAL_ERROR "Invalid routes file ${ROUTES_FILE}: ${routes_error}")
endif()

set(proxy_download_url "")
if(route_count GREATER 0)
    math(EXPR last_route "${route_count} - 1")
    foreach(index RANGE 0 ${last_route})
        string(JSON origin GET "${routes_json}" ${index} origin)
        string(JSON path GET "${routes_json}" ${index} path)
        string(LENGTH "${origin}" origin_length)
        string(LENGTH "${URL}" url_length)
        if(url_length GREATER_EQUAL origin_length)
            string(SUBSTRING "${URL}" 0 ${origin_length} candidate)
            if(candidate STREQUAL origin)
                string(SUBSTRING "${URL}" ${origin_length} -1 suffix)
                string(REGEX REPLACE "^/+" "" path "${path}")
                string(REGEX REPLACE "/+$" "" path "${path}")
                set(proxy_download_url "${proxy_url}/${path}/${suffix}")
                break()
            endif()
        endif()
    endforeach()
endif()

if(proxy_download_url STREQUAL "")
    message(FATAL_ERROR "URL is not routed through the configured proxy: ${URL}")
endif()

set(tls_verify ON)
if(DEFINED ENV{VCPKG_PROXY_TLS_VERIFY} AND NOT "$ENV{VCPKG_PROXY_TLS_VERIFY}" STREQUAL "")
    set(tls_verify "$ENV{VCPKG_PROXY_TLS_VERIFY}")
endif()

set(auth_args)
set(proxy_username "$ENV{VCPKG_PROXY_USERNAME}")
set(proxy_password "$ENV{VCPKG_PROXY_PASSWORD}")
if((proxy_username STREQUAL "" AND NOT proxy_password STREQUAL "")
   OR (NOT proxy_username STREQUAL "" AND proxy_password STREQUAL ""))
    message(FATAL_ERROR "Set both VCPKG_PROXY_USERNAME and VCPKG_PROXY_PASSWORD, or neither")
endif()
if(NOT proxy_username STREQUAL "")
    list(APPEND auth_args USERPWD "${proxy_username}:${proxy_password}")
endif()

file(DOWNLOAD
    "${proxy_download_url}"
    "${DST_FILE}"
    TLS_VERIFY "${tls_verify}"
    TIMEOUT 120
    STATUS download_status
    LOG download_log
    EXPECTED_HASH "SHA512=${SHA512}"
    ${auth_args}
)

list(GET download_status 0 status_code)
list(GET download_status 1 status_message)
if(NOT status_code EQUAL 0)
    file(REMOVE "${DST_FILE}")
    message(VERBOSE "Downloader log:\n${download_log}")
    message(FATAL_ERROR "Proxy download failed (${status_code}): ${status_message}")
endif()

message(STATUS "Downloaded ${URL} through the configured proxy")
