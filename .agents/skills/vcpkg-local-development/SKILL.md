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

Use the checked-in test entry points rather than copying workflow shell fragments: `tests/validate-config.sh`, `tests/test-bundle.sh`, `tests/test-ports-linux.sh`, and `tests/test-proxy.sh`.

Validate every changed `vcpkg.json` with the pinned vcpkg executable. Ensure the directory and manifest package names match and that packaging-only changes increment `port-version`. A patch-only port directory must contain only `.patch` files.

## Test overlay ports

Generate the test bundle first, then install a changed port through its complete ports tree:

```sh
tests/test-bundle.sh <upstream>
<upstream>/vcpkg install <port> --overlay-ports=<repo>/build/test-bundle/ports
```

When a clean retest is needed, remove only that package and its build tree. Preserve unrelated downloads, packages, caches, and user work.

If `tests/<port>/` exists, configure and build it with the pinned vcpkg toolchain. Run the resulting executable when applicable.

## Test the proxy

For `download.cmake` or `routes.txt` changes, run the repository proxy workflow or its equivalent local Nginx container. Supply `PROXY`, `PROXY_USERNAME`, `PROXY_PASSWORD`, `TLS_VERIFY`, and `PROXY_ROUTES` through the downloader's `-D` arguments. Never place real credentials in generated configuration committed to Git or logs.

Verify an allowed download, an unsupported origin, authentication failure, and SHA512 failure. Confirm `x-block-origin` is active.

## Test bundle generation

Run `filesystem_registry.cmake` with an explicit upstream root, output directory, baseline name, and bootstrapped vcpkg executable. The generator owns the complete bundle: upstream files, overlay ports, proxy files, executable, and metrics-disable marker. Use a disposable output below `build/` or a system temporary directory; do not commit it.

Report the upstream tag and resolved commit, changed ports, commands run, and results. Do not create tags or publish releases during local development.
