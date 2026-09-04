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
bundle_dir="$repo_root/build/test-bundle"
downloader="$bundle_dir/scripts/download.cmake"
test_dir="$(mktemp -d $repo_root/vcpkg-port-test.XXXXXX)"
routes="$test_dir/routes.txt"
container_name="vcpkg-port-test-$$"

cleanup() {
    exit_code=$?
    trap - EXIT
    if [[ $exit_code -ne 0 ]] && docker inspect "$container_name" >/dev/null 2>&1; then
        docker logs "$container_name" 2>&1 || true
    fi
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    rm -rf "$test_dir"
    exit "$exit_code"
}
trap cleanup EXIT

echo "Checking the bootstrapped vcpkg executable"
test -x "$vcpkg"

cd "$repo_root"
echo "Generating the complete vcpkg bundle"
cmake \
    -DUPSTREAM_DIR="$upstream_dir" \
    -DOVERLAY_PORTS_DIR="$repo_root/ports" \
    -DDST_DIR="$bundle_dir" \
    -DBASELINE="$baseline" \
    -DVCPKG_EXECUTABLE="$vcpkg" \
    -P "$repo_root/filesystem_registry.cmake"

cp "$bundle_dir/scripts/routes.txt" "$routes"
echo 'https://raw.githubusercontent.com repo/extras/github_raw' >>"$routes"

{
    echo 'server {'
    echo '  listen 8443 ssl;'
    echo '  ssl_certificate /etc/nginx/tls/nginx.crt;'
    echo '  ssl_certificate_key /etc/nginx/tls/nginx.key;'
    echo '  auth_basic "vcpkg proxy";'
    echo '  auth_basic_user_file /etc/nginx/.htpasswd;'
    echo '  recursive_error_pages on;'
    echo '  proxy_intercept_errors on;'
    echo '  proxy_set_header Authorization "";'
    echo '  proxy_ssl_server_name on;'
    echo '  proxy_headers_hash_max_size 8192;'
    echo '  proxy_buffer_size 128k;'
    echo '  proxy_buffers 8 256k;'
    echo '  proxy_busy_buffers_size 256k;'
    while IFS=' ' read -r source_origin proxy_path; do
        echo "  location /$proxy_path/ { proxy_pass $source_origin/; }"
    done < "$routes"
    echo '  location @follow_redirect { set $redirect_url $upstream_http_location; proxy_pass $redirect_url; }'
    echo '}'
} >"$test_dir/proxy.conf"

mkdir "$test_dir/tls"
openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout "$test_dir/tls/nginx.key" \
    -out "$test_dir/tls/nginx.crt" \
    -subj '/CN=127.0.0.1' >/dev/null 2>&1
openssl passwd -apr1 -salt test secret | sed 's/^/user:/' >"$test_dir/.htpasswd"

docker run -d --name "$container_name" \
    -p 127.0.0.1:8443:8443 \
    -v "$test_dir/proxy.conf:/etc/nginx/conf.d/default.conf:ro" \
    -v "$test_dir/.htpasswd:/etc/nginx/.htpasswd:ro" \
    -v "$test_dir/tls:/etc/nginx/tls:ro" \
    nginx:alpine >/dev/null

for _ in {1..20}; do
    if curl --insecure --silent --output /dev/null https://127.0.0.1:8443/; then
        break
    fi
    sleep 1
done
docker exec "$container_name" nginx -t

asset_sources="clear;x-script,cmake -DURL={url} -DSHA512={sha512} -DDST_FILE={dst} -DPROXY_URL=https://127.0.0.1:8443 -DPROXY_USERNAME=user -DPROXY_PASSWORD=secret -DTLS_VERIFY=OFF -DPROXY_ROUTES=$routes -P $downloader;x-block-origin"
export X_VCPKG_ASSET_SOURCES="$asset_sources"

# Dynamic-only ports enforce their required linkage while their portfiles run.
"$vcpkg" install \
    argparse \
    boost-build \
    boost-cmake \
    https-client \
    openssl \
    libpq \
    minio-cpp \
    mip-protection-sdk \
    --triplet=x64-linux \
    --vcpkg-root="$bundle_dir" \
    --downloads-root="$test_dir/downloads" \
    --clean-after-build

echo "The generated bundle and proxy-backed port builds are valid"
