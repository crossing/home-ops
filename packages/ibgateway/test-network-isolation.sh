#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
wrapper=$script_dir/wrapper.sh

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

grep -Eq -- '--(net|network)=host' "$wrapper" \
  || fail "Gateway wrapper does not use the host network namespace"

if grep -q -- '--publish' "$wrapper"; then
  fail "Gateway wrapper still publishes a bridge-network port"
fi

if grep -q '^configure_network() {' "$wrapper"; then
  fail "Gateway wrapper still configures bridge networking"
fi

printf 'PASS: IB Gateway containers use host networking\n'
