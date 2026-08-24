#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/vcpkg-proxy-test.XXXXXX")"
container_name="vcpkg-proxy-test-$$"

cleanup() {
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    rm -rf "$test_dir"
}
trap cleanup EXIT

cd "$repo_root"
"$repo_root/tests/validate-config.sh"

# Every configured origin must be recognized by download.cmake. A closed
# local port makes the download fail immediately after URL rewriting.
route_index=0
while IFS=' ' read -r origin _; do
    log="$test_dir/route-$route_index.log"
    if cmake \
            -DURL="$origin/test-asset" \
            -DSHA512=00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 \
            -DDST_FILE="$test_dir/route-$route_index.out" \
            -DPROXY=127.0.0.1:1 \
            -DPROXY_USERNAME= \
            -DPROXY_PASSWORD= \
            -DTLS_VERIFY=OFF \
            -DPROXY_ROUTES="$repo_root/routes.txt" \
            -P download.cmake >"$log" 2>&1; then
        echo "route unexpectedly downloaded: $origin" >&2
        exit 1
    fi
    grep -q "Proxy download failed" "$log"
    route_index=$((route_index + 1))
done < routes.txt

if cmake \
        -DURL=https://example.invalid/test-asset \
        -DSHA512=00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 \
        -DDST_FILE="$test_dir/unsupported.out" \
        -DPROXY=127.0.0.1:1 \
        -DPROXY_USERNAME= \
        -DPROXY_PASSWORD= \
        -DTLS_VERIFY=OFF \
        -DPROXY_ROUTES="$repo_root/routes.txt" \
        -P download.cmake >"$test_dir/unsupported.log" 2>&1; then
    echo "unsupported origin unexpectedly succeeded" >&2
    exit 1
fi
grep -q "URL is not routed" "$test_dir/unsupported.log"

{
    echo 'server {'
    echo '  listen 8443 ssl;'
    echo '  ssl_certificate /etc/nginx/tls/nginx.crt;'
    echo '  ssl_certificate_key /etc/nginx/tls/nginx.key;'
    echo '  auth_basic "vcpkg proxy";'
    echo '  auth_basic_user_file /etc/nginx/.htpasswd;'
    echo '  proxy_pass_request_headers off;'
    while IFS=' ' read -r origin path; do
        host="${origin#https://}"
        host="${host%%/*}"
        echo "  location ^~ /$path/ { proxy_pass $origin/; proxy_set_header Host $host; proxy_ssl_name $host; proxy_ssl_server_name on; }"
    done < routes.txt
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

common_args=(
    -DPROXY=127.0.0.1:8443
    -DPROXY_USERNAME=user
    -DPROXY_PASSWORD=secret
    -DTLS_VERIFY=OFF
    -DPROXY_ROUTES="$repo_root/routes.txt"
)
bzip_url=https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
bzip_sha=083f5e675d73f3233c7930ebe20425a533feedeaaa9d8cc86831312a6581cefbe6ed0d08d2fa89be81082f2a5abdabca8b3c080bf97218a1bd59dc118a30b9f3

cmake \
    -DURL="$bzip_url" \
    -DSHA512="$bzip_sha" \
    -DDST_FILE="$test_dir/bzip2.tar.gz" \
    "${common_args[@]}" \
    -P download.cmake

if cmake \
        -DURL="$bzip_url" \
        -DSHA512="$bzip_sha" \
        -DDST_FILE="$test_dir/bad-auth.tar.gz" \
        -DPROXY=127.0.0.1:8443 \
        -DPROXY_USERNAME=user \
        -DPROXY_PASSWORD=wrong \
        -DTLS_VERIFY=OFF \
        -DPROXY_ROUTES="$repo_root/routes.txt" \
        -P download.cmake; then
    echo "invalid proxy credentials unexpectedly succeeded" >&2
    exit 1
fi

bad_hash_log="$test_dir/bad-hash.log"
if cmake \
    -DURL="$bzip_url" \
    -DSHA512=00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 \
    -DDST_FILE="$test_dir/bad-hash.tar.gz" \
    "${common_args[@]}" \
    -P download.cmake >"$bad_hash_log" 2>&1; then
    echo "incorrect SHA512 unexpectedly succeeded" >&2
    exit 1
fi
grep -q "Expected:" "$bad_hash_log"
grep -q "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" "$bad_hash_log"
grep -q "Actual:" "$bad_hash_log"
grep -q "$bzip_sha" "$bad_hash_log"
test ! -e "$test_dir/bad-auth.tar.gz"
test ! -e "$test_dir/bad-hash.tar.gz"

echo "All proxy routes and failure modes passed"
