# Contributing

## Prepare upstream vcpkg

Read `tag` and `commit` from `vcpkg-upstream.json`, clone `microsoft/vcpkg` outside this repository, check out the commit, and bootstrap the tool for your platform.

Do not copy the upstream tree into this repository.

## Change a port

Each directory below `ports/` is a complete overlay port. To replace another upstream port, first copy its complete directory at the pinned commit, then make the smallest required change.

Increment `port-version` for packaging-only changes. Reset it to zero or remove it when changing the port's upstream library version.

## Test a port

```sh
/path/to/vcpkg/vcpkg install <port> --overlay-ports="$PWD/ports"
```

For a clean targeted retest, remove only the affected package and build tree. Do not delete the complete vcpkg cache or unrelated build trees.

Consumer-facing changes should have a small project under `tests/<port>/`.

## Change proxy routing

Edit `routes.json`; do not duplicate route definitions in CMake or workflow files. Run the proxy tests after every route or downloader change. Credentials belong in environment variables and must not be committed.

## Update upstream vcpkg

Update `vcpkg-upstream.json` in a pull request. Verify the tag-to-commit mapping and compare each replacement port with its new upstream version. Refresh conflicting overlays before merging.

## Publish

Use the `release.yml` workflow. Do not create or move release tags locally.
