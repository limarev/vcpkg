vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO alex-gv/minio-cpp
    REF "v${VERSION}"
    SHA512 106baca35027a7de281ce6d6a9ac59d82d12a23df858d24a5c854e9e250495aa2324d4dfb59997585bbbcfb28b619ac90b8a29909de3eb710bf5e4c0c1dfb1f7
    HEAD_REF main
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME miniocpp CONFIG_PATH "lib/cmake/miniocpp")

vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
