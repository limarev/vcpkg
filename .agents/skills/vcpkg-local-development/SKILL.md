---
name: vcpkg-local-development
description: Develop and test this repository's custom vcpkg overlay ports and asset-proxy behavior against the pinned upstream vcpkg release. Use for adding, changing, validating, or locally testing ports, routes, downloader behavior, or filesystem bundles in this repository.
---

# Local vcpkg development

Read `AGENTS.md` and `vcpkg-upstream-tag.txt` first.

## Prepare upstream

Reuse a clean external checkout when it is already at the tag recorded in `vcpkg-upstream-tag.txt`. Otherwise clone `https://github.com/microsoft/vcpkg.git` and check out the recorded tag. In CI, rely on `actions/checkout` to resolve and validate the selected tag; do not add separate tag validation. Do not clone or copy upstream into this repository.

Bootstrap with `bootstrap-vcpkg.sh -disableMetrics` on Unix-like systems or `bootstrap-vcpkg.bat -disableMetrics` on Windows when the executable is absent.

## Select tests

Use `git diff --name-only` to identify changed directories below `ports/`. Test only affected ports unless shared downloader, routing, registry-generation, or workflow changes require broader coverage.

Use the checked-in test entry points rather than copying workflow shell fragments: `tests/validate-config.sh` and `tests/test-ports-linux.sh`.

Validate every changed `vcpkg.json` with the pinned vcpkg executable. Ensure the directory and manifest package names match and that packaging-only changes increment `port-version`. A patch-only port directory must contain only `.patch` files.

## Test overlay ports

Generate the test bundle and install all customized ports through its complete ports tree:

```sh
tests/test-ports-linux.sh <upstream>
```

When a clean retest is needed, remove only that package and its build tree. Preserve unrelated downloads, packages, caches, and user work.

If `tests/<port>/` exists, configure and build it with the pinned vcpkg toolchain. Run the resulting executable when applicable.

## Test the proxy

`tests/test-ports-linux.sh <upstream>` starts a local Nginx proxy and builds every customized port with the proxy as its only asset source. Supply `PROXY_URL`, `PROXY_USERNAME`, `PROXY_PASSWORD`, `TLS_VERIFY`, and `PROXY_ROUTES` through the downloader's `-D` arguments. Never place real credentials in generated configuration committed to Git or logs.

Build every customized port with a fresh downloads directory and confirm `x-block-origin` is active, so successful builds demonstrate that their sources were downloaded through the proxy. Leave archive checksum validation to vcpkg.

## Test bundle generation

Run `filesystem_registry.cmake` with an explicit upstream root, output directory, baseline name, and bootstrapped vcpkg executable. The generator owns the complete bundle: upstream files, overlay ports, proxy files, executable, and metrics-disable marker. Use a disposable output below `build/` or a system temporary directory; do not commit it.

Report the upstream tag and resolved commit, changed ports, commands run, and results. Do not create tags or publish releases during local development.
