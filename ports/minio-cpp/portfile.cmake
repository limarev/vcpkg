vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO minio/minio-cpp
    REF bc08d87a8a0001fd32f998e2af33ca1961454dc8
    SHA512 82fb94e3042a73abe610fa3413b64af6f322a897f5060f3c25e48b5d68846ec9283a86785e1e03161dd3b80c2e633790195e5bc7e983f37061b8932568ff647c
    HEAD_REF main
    PATCHES
        # Backport of alex-gv/minio-cpp@9c827a2, with a typed sleep duration.
        fix-select-without-active-sockets.patch
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
