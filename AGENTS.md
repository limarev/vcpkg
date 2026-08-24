# Repository instructions

This repository builds a customized vcpkg distribution; it is not a fork of `microsoft/vcpkg`.

## Invariants

- Do not vendor the complete upstream vcpkg tree or merge upstream history.
- Read the supported upstream tag and commit from `vcpkg-upstream.json`. Verify that the tag resolves to that commit before building a release.
- Keep only new or replacement overlay ports in `ports/`. A replacement port directory must contain the complete port.
- Increment `port-version` whenever packaging files change without changing the upstream library version.
- Define reverse-proxy URL mappings only in `routes.json`; both the downloader and proxy tests consume it.
- Never commit generated registries, release archives, downloaded tools, credentials, certificates, or build trees.
- Keep proxy credentials in `VCPKG_PROXY_USERNAME` and `VCPKG_PROXY_PASSWORD`; never put them in command lines, source files, or logs.
- Treat release tags as upstream version identifiers. Releases are intentionally mutable: publishing again replaces every asset and moves the same-name distribution tag to the customization commit used for the rebuild.
- Publishing releases is CI-only.

## Validation

- Use the `vcpkg-local-development` skill for local port and proxy testing.
- Test changed ports against the pinned upstream checkout with `--overlay-ports=<repo>/ports`.
- Run consumer tests under `tests/` when a port's public integration changes.
- Keep changes targeted; do not clean unrelated user build trees or caches.
