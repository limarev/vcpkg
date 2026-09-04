cmake_minimum_required(VERSION 3.19)

foreach(required IN ITEMS UPSTREAM_DIR DST_DIR BASELINE VCPKG_EXECUTABLE)
    if(NOT DEFINED ${required} OR "${${required}}" STREQUAL "")
        message(FATAL_ERROR "${required} is required")
    endif()
endforeach()

if(NOT DEFINED OVERLAY_PORTS_DIR)
    set(OVERLAY_PORTS_DIR "${CMAKE_CURRENT_LIST_DIR}/ports")
endif()

cmake_path(ABSOLUTE_PATH UPSTREAM_DIR NORMALIZE)
cmake_path(ABSOLUTE_PATH OVERLAY_PORTS_DIR NORMALIZE)
cmake_path(ABSOLUTE_PATH DST_DIR NORMALIZE)
cmake_path(ABSOLUTE_PATH VCPKG_EXECUTABLE NORMALIZE)

foreach(required_path IN ITEMS
    "${UPSTREAM_DIR}/ports"
    "${UPSTREAM_DIR}/scripts"
    "${UPSTREAM_DIR}/triplets"
    "${UPSTREAM_DIR}/.vcpkg-root"
    "${UPSTREAM_DIR}/LICENSE.txt"
    "${OVERLAY_PORTS_DIR}"
    "${VCPKG_EXECUTABLE}"
)
    if(NOT EXISTS "${required_path}")
        message(FATAL_ERROR "Required input does not exist: ${required_path}")
    endif()
endforeach()

if(DST_DIR STREQUAL "/" OR DST_DIR STREQUAL UPSTREAM_DIR OR DST_DIR STREQUAL OVERLAY_PORTS_DIR)
    message(FATAL_ERROR "Unsafe destination directory: ${DST_DIR}")
endif()

file(REMOVE_RECURSE "${DST_DIR}")
file(MAKE_DIRECTORY "${DST_DIR}")
file(COPY "${UPSTREAM_DIR}/ports" DESTINATION "${DST_DIR}")
file(COPY "${UPSTREAM_DIR}/scripts" DESTINATION "${DST_DIR}")
file(COPY "${UPSTREAM_DIR}/triplets" DESTINATION "${DST_DIR}")
file(COPY "${UPSTREAM_DIR}/LICENSE.txt" DESTINATION "${DST_DIR}")
file(COPY "${UPSTREAM_DIR}/.vcpkg-root" DESTINATION "${DST_DIR}")

file(GLOB overlay_entries RELATIVE "${OVERLAY_PORTS_DIR}" "${OVERLAY_PORTS_DIR}/*")
list(SORT overlay_entries)
foreach(port_name IN LISTS overlay_entries)
    if(NOT IS_DIRECTORY "${OVERLAY_PORTS_DIR}/${port_name}")
        continue()
    endif()

    set(manifest "${OVERLAY_PORTS_DIR}/${port_name}/vcpkg.json")
    set(portfile "${OVERLAY_PORTS_DIR}/${port_name}/portfile.cmake")
    if(EXISTS "${manifest}" AND EXISTS "${portfile}")
        file(READ "${manifest}" manifest_json)
        string(JSON declared_name ERROR_VARIABLE manifest_error GET "${manifest_json}" name)
        if(manifest_error OR NOT declared_name STREQUAL port_name)
            message(FATAL_ERROR "Overlay directory ${port_name} must match its manifest name")
        endif()

        file(REMOVE_RECURSE "${DST_DIR}/ports/${port_name}")
        file(COPY "${OVERLAY_PORTS_DIR}/${port_name}" DESTINATION "${DST_DIR}/ports")
    elseif(EXISTS "${manifest}" OR EXISTS "${portfile}")
        message(FATAL_ERROR "Replacement port ${port_name} must contain both vcpkg.json and portfile.cmake")
    else()
        if(NOT IS_DIRECTORY "${DST_DIR}/ports/${port_name}")
            message(FATAL_ERROR "Cannot patch missing upstream port ${port_name}")
        endif()

        file(GLOB patch_entries RELATIVE "${OVERLAY_PORTS_DIR}/${port_name}" "${OVERLAY_PORTS_DIR}/${port_name}/*")
        list(SORT patch_entries)
        if(NOT patch_entries)
            message(FATAL_ERROR "Patch-only port ${port_name} contains no patches")
        endif()

        find_program(GIT_EXECUTABLE git)
        if(NOT GIT_EXECUTABLE)
            message(FATAL_ERROR "git is required to apply port patches")
        endif()

        foreach(patch_name IN LISTS patch_entries)
            set(patch "${OVERLAY_PORTS_DIR}/${port_name}/${patch_name}")
            if(IS_DIRECTORY "${patch}" OR NOT patch_name MATCHES "\\.patch$")
                message(FATAL_ERROR "Patch-only port ${port_name} may contain only .patch files")
            endif()

            # Keep git from discovering a repository above DST_DIR and resolving
            # patch paths relative to that worktree instead of this port.
            execute_process(
                COMMAND "${CMAKE_COMMAND}" -E env
                    "GIT_DIR=${DST_DIR}/ports/${port_name}/.git-disabled"
                    "${GIT_EXECUTABLE}" apply --no-index --whitespace=nowarn "${patch}"
                WORKING_DIRECTORY "${DST_DIR}/ports/${port_name}"
                RESULT_VARIABLE patch_result
                OUTPUT_VARIABLE patch_output
                ERROR_VARIABLE patch_error
            )
            if(NOT patch_result EQUAL 0)
                message(FATAL_ERROR "Failed to apply ${port_name}/${patch_name}:\n${patch_output}${patch_error}")
            endif()
        endforeach()
    endif()
endforeach()

file(COPY
    "${CMAKE_CURRENT_LIST_DIR}/download.cmake"
    "${CMAKE_CURRENT_LIST_DIR}/routes.txt"
    DESTINATION "${DST_DIR}/scripts"
)

set(versions_dir "${DST_DIR}/versions")
file(MAKE_DIRECTORY "${versions_dir}")
file(GLOB port_entries RELATIVE "${DST_DIR}/ports" "${DST_DIR}/ports/*")
list(SORT port_entries)

set(baseline_entries "")
set(first_baseline_entry ON)
set(port_count 0)

foreach(port_name IN LISTS port_entries)
    set(manifest "${DST_DIR}/ports/${port_name}/vcpkg.json")
    if(NOT IS_DIRECTORY "${DST_DIR}/ports/${port_name}" OR NOT EXISTS "${manifest}")
        continue()
    endif()

    file(READ "${manifest}" manifest_json)
    set(version_key "")
    foreach(candidate IN ITEMS version version-semver version-date version-string)
        string(JSON candidate_value ERROR_VARIABLE candidate_error GET "${manifest_json}" "${candidate}")
        if(NOT candidate_error)
            set(version_key "${candidate}")
            set(version_value "${candidate_value}")
            break()
        endif()
    endforeach()
    if(version_key STREQUAL "")
        message(FATAL_ERROR "Port ${port_name} has no supported version field")
    endif()

    string(JSON port_version ERROR_VARIABLE port_version_error GET "${manifest_json}" port-version)
    if(port_version_error)
        set(port_version 0)
    endif()

    string(SUBSTRING "${port_name}" 0 1 prefix)
    string(TOLOWER "${prefix}" prefix)
    file(MAKE_DIRECTORY "${versions_dir}/${prefix}-")
    file(WRITE "${versions_dir}/${prefix}-/${port_name}.json"
        "{\n  \"versions\": [\n    { \"path\": \"$/ports/${port_name}\", \"${version_key}\": \"${version_value}\", \"port-version\": ${port_version} }\n  ]\n}\n"
    )

    if(first_baseline_entry)
        set(first_baseline_entry OFF)
    else()
        string(APPEND baseline_entries ",\n")
    endif()
    string(APPEND baseline_entries
        "    \"${port_name}\": { \"baseline\": \"${version_value}\", \"port-version\": ${port_version} }"
    )
    math(EXPR port_count "${port_count} + 1")
endforeach()

if(port_count EQUAL 0)
    message(FATAL_ERROR "No ports were found in the generated registry")
endif()

file(WRITE "${versions_dir}/baseline.json"
    "{\n  \"${BASELINE}\": {\n${baseline_entries}\n  }\n}\n"
)

get_filename_component(vcpkg_filename "${VCPKG_EXECUTABLE}" NAME)
file(COPY "${VCPKG_EXECUTABLE}" DESTINATION "${DST_DIR}")
file(CHMOD "${DST_DIR}/${vcpkg_filename}"
    PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)
file(TOUCH "${DST_DIR}/vcpkg.disable-metrics")

message(STATUS "Generated filesystem registry at ${DST_DIR} with ${port_count} ports")
