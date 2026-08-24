# Repository instructions

This repository builds a customized vcpkg distribution; it is not a fork of `microsoft/vcpkg`.

## Invariants

- Do not vendor the complete upstream vcpkg tree or merge upstream history.
- Keep the default upstream tag only in `vcpkg-upstream-tag.txt`. A non-empty release workflow input overrides the default tag; `actions/checkout` resolves and validates the selected ref.
- Keep port customizations in `ports/`. A replacement directory contains a complete port; a patch-only directory contains only `.patch` files applied to the pinned upstream port.
- Increment `port-version` whenever packaging files change without changing the upstream library version.
- Define reverse-proxy URL mappings only in `routes.txt`; both the downloader and proxy tests consume it.
- Never commit generated registries, release archives, downloaded tools, credentials, certificates, or build trees.
- Pass proxy settings to `download.cmake` through its `-D` arguments. Never put real credentials in source files or logs.
- Treat release tags as upstream version identifiers. Releases are intentionally mutable: publishing again replaces every asset and moves the same-name distribution tag to the customization commit used for the rebuild.
- Publishing releases is CI-only.

## Validation

- Use the `vcpkg-local-development` skill for local port and proxy testing.
- Generate the test bundle, then test changed ports with `--overlay-ports=<repo>/build/test-bundle/ports`.
- Run consumer tests under `tests/` when a port's public integration changes.
- Keep changes targeted; do not clean unrelated user build trees or caches.
