#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    echo "configuration error: $*" >&2
    exit 1
}

echo "Checking the pinned upstream vcpkg reference"
[[ -f vcpkg-upstream-tag.txt ]] || fail "vcpkg-upstream-tag.txt is missing"
tag="$(<vcpkg-upstream-tag.txt)"
[[ -n "$tag" && "$tag" != *[[:space:]]* ]] \
    || fail "vcpkg-upstream-tag.txt must contain only a non-empty tag"
echo "  $tag"

echo "Checking proxy routes"
[[ -s routes.txt ]] || fail "routes.txt must contain at least one route"
awk 'NF != 2 || $0 !~ /^[^ ]+ [^ ]+$/ { exit 1 }' routes.txt \
    || fail "routes.txt must contain exactly one space-delimited origin and path per line"
route_count="$(wc -l < routes.txt | tr -d ' ')"
unique_origins="$(cut -d ' ' -f 1 routes.txt | sort -u | wc -l | tr -d ' ')"
unique_paths="$(cut -d ' ' -f 2 routes.txt | sort -u | wc -l | tr -d ' ')"
[[ "$route_count" == "$unique_origins" ]] || fail "routes.txt contains duplicate origins"
[[ "$route_count" == "$unique_paths" ]] || fail "routes.txt contains duplicate proxy paths"

while IFS=' ' read -r origin path; do
    [[ "$origin" =~ ^https://[^/]+(/[^/]+)*$ ]] || fail "invalid route origin: $origin"
    [[ "$path" =~ ^[^/]+(/[^/]+)*$ ]] || fail "invalid proxy path: $path"
done < routes.txt
echo "  $route_count unique HTTPS origins and proxy paths"

echo "Checking port customization layout"
replacement_count=0
patch_count=0
shopt -s nullglob
for customization_dir in ports/*; do
    [[ -d "$customization_dir" ]] || continue
    port_directory="$(basename "$customization_dir")"
    manifest="$customization_dir/vcpkg.json"
    portfile="$customization_dir/portfile.cmake"

    if [[ -e "$manifest" || -e "$portfile" ]]; then
        [[ -f "$manifest" && -f "$portfile" ]] \
            || fail "$customization_dir must contain both vcpkg.json and portfile.cmake"
        declared_name="$(jq -r .name "$manifest")"
        [[ "$port_directory" == "$declared_name" ]] \
            || fail "$manifest declares '$declared_name', but its directory is '$port_directory'"
        ((replacement_count += 1))
    else
        entries=("$customization_dir"/*)
        patches=("$customization_dir"/*.patch)
        [[ ${#patches[@]} -gt 0 && ${#entries[@]} -eq ${#patches[@]} ]] \
            || fail "$customization_dir must contain only .patch files"
        ((patch_count += ${#patches[@]}))
    fi
done
echo "  $replacement_count replacement ports and $patch_count upstream port patches"

echo "Repository configuration is valid"
