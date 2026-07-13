#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
wrapper=$script_dir/wrapper.sh

if grep -Eq -- '--(net|network)=host' "$wrapper"; then
  echo "wrapper still uses the host network namespace" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

function_file=$tmp/configure-network.sh
awk '
  /^configure_network\(\) \{$/ { capture = 1 }
  capture { print }
  capture && /^}$/ { exit }
' "$wrapper" > "$function_file"

if ! grep -q '^configure_network() {$' "$function_file"; then
  echo "configure_network was not found in $wrapper" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$function_file"

assert_mapping() {
  local port=$1
  local -a expected=(
    --network=bridge
    --publish
    "127.0.0.1:$port:$port/tcp"
  )
  podman_args=()
  configure_network "$port"
  if [[ "${podman_args[*]}" != "${expected[*]}" ]]; then
    echo "unexpected network arguments for port $port" >&2
    exit 1
  fi
}

assert_invalid() {
  local port=$1
  podman_args=()
  if configure_network "$port" >/dev/null 2>&1; then
    echo "invalid API port was accepted: $port" >&2
    exit 1
  fi
}

declare -a podman_args=()
assert_mapping 4001
assert_mapping 4003
assert_invalid 0
assert_invalid 65536
assert_invalid not-a-port

echo "PASS: IB Gateway containers use isolated loopback port publication"
