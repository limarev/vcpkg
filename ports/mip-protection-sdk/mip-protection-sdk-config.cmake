# Functions
function(find_mip_components)
    set(multiValueArg COMPONENTS)
    set(oneValueArg COMPONENT_PATH)

    cmake_parse_arguments(arg "" "${oneValueArg}" "${multiValueArg}" ${ARGN})

    if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
        set(CMAKE_FIND_LIBRARY_SUFFIXES ".dll" ".lib")
    endif()

    if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
        # добавляем пустой суффкис, так как openssl либы в составе mip sdk для iOS не имеют суффикса: libssl libcrypto
        set(CMAKE_FIND_LIBRARY_SUFFIXES "" "${CMAKE_FIND_LIBRARY_SUFFIXES}")
    endif()
    
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
        set(mip_build_type "release")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(mip_build_type "debug")
    endif()

    string(TOUPPER ${mip_build_type} mip_build_type_upper)

    foreach(_comp IN LISTS arg_COMPONENTS)
        # looking for dynamic libs - main goal
        if (TARGET mip_${_comp})
            continue()
        endif()

        set(mip_build_type_ "${mip_build_type}")
        if (${mip_build_type} STREQUAL release)
            # релизная либа должна лежать в lib https://learn.microsoft.com/en-us/vcpkg/reference/installation-tree-layout
            # а дебажная либа должна лежать в lib/debug
            set(mip_build_type_ "")
        endif()

        find_library(mip_${_comp}_path
                     PATHS ${arg_COMPONENT_PATH}/lib/${mip_build_type_}
                     NAMES # order matters!
                          mip_${_comp}
                          ${_comp}-3-x64 # libssl-3-x64.dll on Windows
                          ${_comp}.3 # libssl.3.dylib on Darwin
                          ${_comp} # libssl on iOS
                     PATH_SUFFIXES lib${_comp}.framework # ssl locates in libssl.framework
        )

        if (NOT mip_${_comp}_path)
            continue()
        endif()

        # Set a variable in parent scope and make it visible in current scope
        set(mip_${_comp}_FOUND TRUE PARENT_SCOPE)
        set(mip_${_comp}_FOUND TRUE)

        # Set a variable in parent scope and make it visible in current scope
        cmake_path(GET mip_${_comp}_path PARENT_PATH mip_${_comp}_dir_)
        set(mip_${_comp}_dir ${mip_${_comp}_dir_} PARENT_SCOPE)

        message(STATUS "mip_${_comp} component ${arg_COMPONENT_PATH}: found")
        list(APPEND CMAKE_MESSAGE_INDENT "  ")
        message(STATUS "${mip_build_type}: ${mip_${_comp}_path}")
        list(POP_BACK CMAKE_MESSAGE_INDENT)

        add_library(mip::${_comp} SHARED IMPORTED)

        set(mip_imported_lib ${mip_${_comp}_path})
        if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
            cmake_path(REPLACE_EXTENSION mip_imported_lib lib)
        endif()

        set_target_properties(mip::${_comp} PROPERTIES
                              IMPORTED_LOCATION_${mip_build_type_upper} ${mip_${_comp}_path}
                              IMPORTED_IMPLIB_${mip_build_type_upper} ${mip_imported_lib}
                              IMPORTED_NO_SONAME ON)
    endforeach()
endfunction()

# End of functions

get_filename_component(_IMPORTED_PREFIX "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)
get_filename_component(_IMPORTED_PREFIX "${_IMPORTED_PREFIX}" DIRECTORY)

find_mip_components(COMPONENTS core protection_sdk ClientTelemetry ssl crypto COMPONENT_PATH ${_IMPORTED_PREFIX})

target_include_directories(mip::protection_sdk INTERFACE ${_IMPORTED_PREFIX}/include)

if (NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
    # Link to libmip_core.so and libmip_protection_sdk.so on any platform except Windows
    # On Windows link to libmip_protection_sdk.lib only, due to lack of libmip_core.lib for Windows
    target_link_libraries(mip::protection_sdk INTERFACE mip::core)
endif()

unset(_IMPORT_PREFIX)