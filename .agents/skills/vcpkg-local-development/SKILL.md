---
name: vcpkg-local-development
description: Develop and test this repository's custom vcpkg overlay ports and asset-proxy behavior against the pinned upstream vcpkg release. Use for adding, changing, validating, or locally testing ports, routes, downloader behavior, or filesystem bundles in this repository.
---

# Local vcpkg development

Read `AGENTS.md` and `vcpkg-upstream.json` first.

## Prepare upstream

Reuse a clean external checkout when it is already at the commit recorded in `vcpkg-upstream.json`. Otherwise clone `https://github.com/microsoft/vcpkg.git`, fetch the recorded tag, verify that it resolves to the recorded commit, and check out that commit. Do not clone or copy upstream into this repository.

Bootstrap with `bootstrap-vcpkg.sh -disableMetrics` on Unix-like systems or `bootstrap-vcpkg.bat -disableMetrics` on Windows when the executable is absent.

## Select tests

Use `git diff --name-only` to identify changed directories below `ports/`. Test only affected ports unless shared downloader, routing, registry-generation, or workflow changes require broader coverage.

Validate every changed `vcpkg.json` with the pinned vcpkg executable. Ensure the directory and manifest package names match and that packaging-only changes increment `port-version`.

## Test overlay ports

Install a changed port through the repository overlay:

```sh
<upstream>/vcpkg install <port> --overlay-ports=<repo>/ports
```

When a clean retest is needed, remove only that package and its build tree. Preserve unrelated downloads, packages, caches, and user work.

If `tests/<port>/` exists, configure and build it with the pinned vcpkg toolchain. Run the resulting executable when applicable.

## Test the proxy

For `download.cmake` or `routes.json` changes, run the repository proxy workflow or its equivalent local Nginx container. Supply `VCPKG_PROXY_URL`, `VCPKG_PROXY_USERNAME`, `VCPKG_PROXY_PASSWORD`, and test-only TLS settings through environment variables. Never place credentials in commands, generated configuration committed to Git, or logs.

Verify an allowed download, an unsupported origin, authentication failure, and SHA512 failure. Confirm `x-block-origin` is active.

## Test bundle generation

Run `filesystem_registry.cmake` with an explicit upstream root, output directory, baseline name, and bootstrapped vcpkg executable. Use a disposable output below `build/` or a system temporary directory. Validate the generated registry with a test manifest; do not commit it.

Report the upstream commit, changed ports, commands run, and results. Do not create tags or publish releases during local development.
