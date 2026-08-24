if(TARGET https-client::https-client)
    return()
endif()

get_filename_component(_https_client_prefix "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)
get_filename_component(_https_client_prefix "${_https_client_prefix}" DIRECTORY)

find_library(_https_client_release
    NAMES https_client
    PATHS "${_https_client_prefix}/lib"
    NO_DEFAULT_PATH
)
find_library(_https_client_debug
    NAMES https_client
    PATHS "${_https_client_prefix}/debug/lib"
    NO_DEFAULT_PATH
)

if(NOT _https_client_release AND NOT _https_client_debug)
    message(FATAL_ERROR "https-client library was not found below ${_https_client_prefix}")
endif()

add_library(https-client::https-client UNKNOWN IMPORTED)
set_target_properties(https-client::https-client PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_https_client_prefix}/include"
)

if(_https_client_release)
    set_property(TARGET https-client::https-client APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
    set_property(TARGET https-client::https-client PROPERTY IMPORTED_LOCATION_RELEASE "${_https_client_release}")
endif()
if(_https_client_debug)
    set_property(TARGET https-client::https-client APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
    set_property(TARGET https-client::https-client PROPERTY IMPORTED_LOCATION_DEBUG "${_https_client_debug}")
endif()

unset(_https_client_prefix)
unset(_https_client_release)
unset(_https_client_debug)
