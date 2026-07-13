#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config=$script_dir/ibkr.nix

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

profile_port() {
  local profile=$1
  awk -v profile="$profile" '
    $0 ~ "^[[:space:]]*" profile " = \\{" { in_profile = 1; next }
    in_profile && /^[[:space:]]*port = [0-9]+;/ {
      gsub(/[^0-9]/, "")
      print
      exit
    }
  ' "$config"
}

declare -A expected=(
  [main-live]=4005
  [main-paper]=4006
  [pension-live]=4003
  [pension-paper]=4004
)
ports=()

for profile in main-live main-paper pension-live pension-paper; do
  port=$(profile_port "$profile")
  [[ -n "$port" ]] || fail "missing port for $profile"
  [[ "$port" == "${expected[$profile]}" ]] \
    || fail "$profile: expected port ${expected[$profile]}, got $port"
  [[ "$port" != 4001 && "$port" != 4002 ]] \
    || fail "$profile uses an IBKR default port"
  ports+=("$port")
done

unique_count=$(printf '%s\n' "${ports[@]}" | sort -u | wc -l)
[[ "$unique_count" -eq "${#ports[@]}" ]] || fail "profile ports are not unique"

printf 'PASS: IBKR profiles use unique non-default ports\n'
