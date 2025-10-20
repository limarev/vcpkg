# Beta builds contains a text in the version string
string(REGEX MATCH "([0-9]+)\\.([0-9]+)\\.([0-9]+)" SEMVER_VERSION "${VERSION}")
configure_file("${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt.in" "${SOURCE_PATH}/CMakeLists.txt" @ONLY)

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()

file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/share/boost/cmake-build")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/vcpkg-port-config.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

set(BOOST_LICENSE "boost-LICENSE_1_0.txt")
cmake_path(ABSOLUTE_PATH BOOST_LICENSE BASE_DIRECTORY ${CMAKE_CURRENT_LIST_DIR} NORMALIZE)

vcpkg_install_copyright(FILE_LIST "${BOOST_LICENSE}")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
