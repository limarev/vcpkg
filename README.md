# Custom vcpkg distribution

This repository produces self-contained vcpkg filesystem-registry bundles with:

- an exact, pinned release of [`microsoft/vcpkg`](https://github.com/microsoft/vcpkg);
- replacement ports and upstream-port patches from [`ports/`](ports);
- a configurable authenticated download proxy;
- Linux, macOS, and Windows release archives.

It intentionally contains no upstream vcpkg history. The supported upstream tag is recorded in [`vcpkg-upstream-tag.txt`](vcpkg-upstream-tag.txt).

## Customized ports

- `argparse`: adds `get_program_name()`.
- `boost-cmake`: installs the bundled Boost license without a separate download.
- `openssl`: permits dynamic linkage only.
- `https-client`: packages `alex-gv/https_client`.
- `minio-cpp`: backports the no-active-sockets fix onto upstream commit `bc08d87`.
- `mip-protection-sdk`: packages platform SDK archives.

## Local port test

Bootstrap the pinned upstream checkout, then let overlay ports replace or extend its registry:

```sh
tests/test-ports-linux.sh /path/to/vcpkg
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) or invoke the repository's `vcpkg-local-development` skill for the complete workflow.

GitHub Actions delegates validation to the executable scripts under [`tests/`](tests), so the same checks can be run locally.

## Proxy configuration

The downloader is configured as a vcpkg `x-script` asset source. Pass the proxy configuration and route file to the script as CMake arguments:

```sh
export X_VCPKG_ASSET_SOURCES="clear;x-script,cmake -DURL={url} -DSHA512={sha512} -DDST_FILE={dst} -DPROXY=proxy.example.com -DPROXY_USERNAME=user -DPROXY_PASSWORD=secret -DTLS_VERIFY=ON -DPROXY_ROUTES=$VCPKG_ROOT/scripts/routes.txt -P $VCPKG_ROOT/scripts/download.cmake;x-block-origin"
```

`PROXY` is the proxy hostname without a scheme. `PROXY_ROUTES` accepts the path to a route file; each non-empty line contains an HTTPS origin and its proxy path separated by one space. The distribution's routes are defined in [`routes.txt`](routes.txt).

## Releases

The release workflow builds one archive per supported runner and uses the same tag name as the pinned upstream release. Releases are intentionally mutable: rerunning a release replaces all archives and moves the distribution tag to the customization commit used for that rebuild.
