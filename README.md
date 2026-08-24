# Custom vcpkg distribution

This repository produces self-contained vcpkg filesystem-registry bundles with:

- an exact, pinned release of [`microsoft/vcpkg`](https://github.com/microsoft/vcpkg);
- custom and replacement ports from [`ports/`](ports);
- a configurable authenticated download proxy;
- Linux, macOS, and Windows release archives.

It intentionally contains no upstream vcpkg history. The supported upstream tag and commit are recorded in [`vcpkg-upstream.json`](vcpkg-upstream.json).

## Customized ports

- `argparse`: adds `get_program_name()`.
- `boost-cmake`: installs the bundled Boost license without a separate download.
- `bzip2`: uses the GitHub mirror on RHEL-family systems.
- `openssl`: permits dynamic linkage only.
- `https-client`: packages `alex-gv/https_client`.
- `minio-cpp`: packages the `alex-gv/minio-cpp` fork.
- `mip-protection-sdk`: packages platform SDK archives.

## Local port test

Bootstrap the pinned upstream checkout, then let overlay ports replace or extend its registry:

```sh
/path/to/vcpkg/vcpkg install argparse --overlay-ports="$PWD/ports"
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) or invoke the repository's `vcpkg-local-development` skill for the complete workflow.

## Proxy configuration

The downloader is configured as a vcpkg `x-script` asset source. Set proxy configuration in the environment:

```sh
export VCPKG_PROXY_URL="https://proxy.example.com"
export VCPKG_PROXY_USERNAME="user"
export VCPKG_PROXY_PASSWORD="secret"
export VCPKG_KEEP_ENV_VARS="VCPKG_PROXY_URL;VCPKG_PROXY_USERNAME;VCPKG_PROXY_PASSWORD;VCPKG_PROXY_TLS_VERIFY"
export X_VCPKG_ASSET_SOURCES="clear;x-script,cmake -DURL={url} -DSHA512={sha512} -DDST_FILE={dst} -P $VCPKG_ROOT/scripts/custom-asset-proxy/download.cmake;x-block-origin"
```

Supported URL prefixes are defined in [`routes.json`](routes.json).

## Releases

The release workflow builds one archive per supported runner and uses the same tag name as the pinned upstream release. Releases are intentionally mutable: rerunning a release replaces all archives and checksums and moves the distribution tag to the customization commit used for that rebuild.
