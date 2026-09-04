#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <upstream-vcpkg-directory>" >&2
    exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_dir="$(cd "$1" && pwd)"
vcpkg="$upstream_dir/vcpkg"
overlay="$repo_root/build/test-bundle/ports"

test -x "$vcpkg"
test -d "$overlay"

# These ports work with the upstream static Linux triplet.
"$vcpkg" install \
    argparse \
    boost-cmake \
    https-client \
    libpq \
    --triplet=x64-linux \
    --overlay-ports="$overlay" \
    --clean-after-build

# These overlays intentionally require dynamic linkage.
"$vcpkg" install \
    openssl \
    minio-cpp \
    mip-protection-sdk \
    --triplet=x64-linux-dynamic \
    --overlay-ports="$overlay" \
    --clean-after-build

echo "All overlay ports passed Linux tests"
