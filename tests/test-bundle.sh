#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <upstream-vcpkg-directory>" >&2
    exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_dir="$(cd "$1" && pwd)"
baseline="$(<"$repo_root/vcpkg-upstream-tag.txt")"
vcpkg="$upstream_dir/vcpkg"

echo "Checking the bootstrapped vcpkg executable"
test -x "$vcpkg"

cd "$repo_root"
echo "Checking that overlay manifests are already formatted"
"$vcpkg" format-manifest ports/*/vcpkg.json
git diff --exit-code -- ports

bundle_dir="$repo_root/build/test-bundle"
echo "Generating the complete vcpkg bundle"
cmake \
    -DUPSTREAM_DIR="$upstream_dir" \
    -DOVERLAY_PORTS_DIR="$repo_root/ports" \
    -DDST_DIR="$bundle_dir" \
    -DBASELINE="$baseline" \
    -DVCPKG_EXECUTABLE="$vcpkg" \
    -P "$repo_root/filesystem_registry.cmake"

echo "Checking every overlay port and its generated version entry"
for manifest in "$repo_root"/ports/*/vcpkg.json; do
    port="$(jq -r .name "$manifest")"
    test -f "$bundle_dir/ports/$port/portfile.cmake"
    jq -e --arg baseline "$baseline" --arg port "$port" \
        '.[$baseline] | has($port)' \
        "$bundle_dir/versions/baseline.json" >/dev/null
done

echo "Checking upstream port patches"
for customization_dir in "$repo_root"/ports/*; do
    [[ -d "$customization_dir" ]] || continue
    [[ ! -f "$customization_dir/vcpkg.json" ]] || continue
    port="$(basename "$customization_dir")"
    test -f "$bundle_dir/ports/$port/portfile.cmake"
    for patch in "$customization_dir"/*.patch; do
        git -C "$bundle_dir/ports/$port" apply --reverse --check --no-index "$patch"
    done
done

echo "Checking the runtime files shipped in the bundle"
test -x "$bundle_dir/vcpkg"
test -f "$bundle_dir/vcpkg.disable-metrics"
test -f "$bundle_dir/scripts/download.cmake"
test -f "$bundle_dir/scripts/routes.txt"
test ! -e "$bundle_dir/scripts/custom-asset-proxy"

echo "The generated vcpkg bundle is valid"
