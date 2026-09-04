# Contributing

## Prepare upstream vcpkg

Read the tag from `vcpkg-upstream-tag.txt`, clone `microsoft/vcpkg` outside this repository, check out the tag, and bootstrap the tool for your platform.

Do not copy the upstream tree into this repository.

## Change a port

Each directory below `ports/` is either a complete replacement port or contains only patches applied to the pinned upstream port. Use a patch-only directory for a small upstream-port change; copy the complete upstream directory only when replacing the port.

Increment `port-version` for packaging-only changes. Reset it to zero or remove it when changing the port's upstream library version.

## Test a port

```sh
tests/test-ports-linux.sh /path/to/vcpkg
```

For a clean targeted retest, remove only the affected package and build tree. Do not delete the complete vcpkg cache or unrelated build trees.

Consumer-facing changes should have a small project under `tests/<port>/`.

Use the checked-in test entry points instead of copying commands from GitHub Actions:

```sh
tests/validate-config.sh
tests/test-ports-linux.sh /path/to/vcpkg
```

## Change proxy routing

Edit `routes.txt`; do not duplicate route definitions in CMake or workflow files. Run `tests/test-ports-linux.sh /path/to/vcpkg` after every route or downloader change; it tests the proxy and builds the overlay ports through it. Credentials belong in environment variables and must not be committed.

## Update upstream vcpkg

Update `vcpkg-upstream-tag.txt` in a pull request. Let `actions/checkout` resolve and validate the configured ref. Compare each replacement port with its new upstream version and refresh conflicting overlays before merging.

## Publish

Use the `release.yml` workflow. Do not create or move release tags locally.
