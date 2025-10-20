vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

if (VCPKG_TARGET_IS_WINDOWS)
    vcpkg_download_distfile(ARCHIVE
        URLS "https://github.com/limarev/mipsdk-scraper/releases/download/mip-${VERSION}/mip_sdk_protection_win32_${VERSION}.zip"
        FILENAME mip_sdk_protection_win32_${VERSION}.zip
        SHA512 f955a5f24db8ab349047a9ae537e8b00cfacff3871f22df7b33acb34c7ef6dfbcfdb4fcb3c5abc067b1c76b4b3c01d4af8daa4343589bac597da76cd51463ac5
    )
    set(ARCH "amd64")
    set(MATCH_RULE PATTERN "*.dll" PATTERN "*.lib" PATTER "*.exp")
elseif(VCPKG_TARGET_IS_LINUX)
    vcpkg_download_distfile(ARCHIVE
        URLS "https://github.com/limarev/mipsdk-scraper/releases/download/mip-${VERSION}/mip_sdk_protection_ubuntu2404_${VERSION}.tar.gz"
        FILENAME mip_sdk_protection_ubuntu2404_${VERSION}.tar.gz
        SHA512 3c90b6051e11b4b3177e46f60d82f97387f572bfe0492925f85debbabd53a9f851486dabff446c1bbc9621d7456a8f2e5ff24092ec7337523ff3e0b4fc6a2bc3
    )
    set(ARCH "x86_64")
    set(MATCH_RULE PATTERN "*.so")
elseif(VCPKG_TARGET_IS_OSX)
    vcpkg_download_distfile(ARCHIVE
        URLS "https://github.com/limarev/mipsdk-scraper/releases/download/mip-${VERSION}/mip_sdk_protection_macos_${VERSION}.zip"
        FILENAME mip_sdk_protection_macos_${VERSION}.zip
        SHA512 bc07a3c8d22c76628af141d00367ae0e020cdc66d1740df708eb0c3a3de9f25c12a571d29589f745aa498d7d19425e6bb5e5653e0a942f9d1c4a7ad0234e46c7
    )
    set(ARCH "${VCPKG_OSX_ARCHITECTURES}")
    set(MATCH_RULE PATTERN "*.dylib")
elseif(VCPKG_TARGET_IS_IOS)
    vcpkg_download_distfile(ARCHIVE
        URLS "https://github.com/limarev/mipsdk-scraper/releases/download/mip-${VERSION}/mip_sdk_protection_ios_${VERSION}.zip"
        FILENAME mip_sdk_protection_ios_${VERSION}.zip
        SHA512 d8f5d9b952873cbbf8eb7841abc64dea25015e06daced035471013ea67813b3521cede7417efc5baa059510ab9270760fb4ea17cd9c3cf1185d8432f8ae07fd3
    )
    set(ARCH "arm64")
    set(MATCH_RULE PATTERN "*.dylib" PATTERN "libssl" PATTERN "libcrypto")
elseif(VCPKG_TARGET_IS_ANDROID)
    vcpkg_download_distfile(ARCHIVE
        URLS "https://github.com/limarev/mipsdk-scraper/releases/download/mip-${VERSION}/mip_sdk_protection_android_${VERSION}.zip"
        FILENAME mip_sdk_protection_android_${VERSION}.zip
        SHA512 3f6c5bb86ce8334f742d61b4292d0dfa0b44d0ecac0c615c06afd28b94eb22cc6e73f820ba993bda24e85b68b377001632fc6ae4b8a3ff74029b6f9d20afc217
    )

    if (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        set(ARCH armeabi-v7a)
    elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(ARCH arm64-v8a)
    elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        set(ARCH x86)
    elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(ARCH x86_64)
    endif()
    
    set(MATCH_RULE PATTERN "*.so")
else()
    message(FATAL_ERROR "Unsupported system: mipsdk is not currently ported to VCPKG in ${VCPKG_CMAKE_SYSTEM_NAME}!")
endif()

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    NO_REMOVE_ONE_LEVEL
)

file(INSTALL ${SOURCE_PATH}/bins/release/${ARCH}/ DESTINATION ${CURRENT_PACKAGES_DIR}/lib FILES_MATCHING ${MATCH_RULE})
file(INSTALL ${SOURCE_PATH}/bins/debug/${ARCH}/ DESTINATION ${CURRENT_PACKAGES_DIR}/debug/lib FILES_MATCHING ${MATCH_RULE})
file(INSTALL ${SOURCE_PATH}/include/ DESTINATION ${CURRENT_PACKAGES_DIR}/include)
file(INSTALL ${CMAKE_CURRENT_LIST_DIR}/usage DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT})
file(INSTALL ${CMAKE_CURRENT_LIST_DIR}/${PORT}-config.cmake DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT})

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/lib/ios-simulator/")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/lib/libssl.framework/Headers")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/lib/libcrypto.framework/Headers")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/lib/ios-simulator/")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/lib/libssl.framework/Headers")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/lib/libcrypto.framework/Headers")

# Copy and rename License -> copyright.
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")