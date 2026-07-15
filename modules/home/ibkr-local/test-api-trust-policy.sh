#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
module=$script_dir/default.nix
cli=$script_dir/../../../packages/ibkr-local/ibkr-local.sh

grep -Fq 'TrustedIPs=127.0.0.1' "$module"
grep -Fq "printf 'AcceptIncomingConnectionAction=reject\\n'" "$cli"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

guard=$test_root/jts-trust-policy-guard.sh
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'jts_ini=$1'
  sed -n '/^      if \[\[ -f "$jts_ini" \]\]; then$/,/^      fi$/p' "$module" \
    | sed -E 's#\$\{pkgs\.[^}]+\}/bin/([[:alnum:]_-]+)#\1#g'
} >"$guard"
chmod +x "$guard"

grep -Fq 'if [[ -f "$jts_ini" ]]; then' "$guard" \
  || fail "could not extract generated jts.ini trust guard"

expect_accept() {
  local name=$1 path=$2
  if ! "$guard" "$path" >"$test_root/$name.stdout" 2>"$test_root/$name.stderr"; then
    fail "$name should be accepted: $(<"$test_root/$name.stderr")"
  fi
}

expect_reject() {
  local name=$1 path=$2
  if "$guard" "$path" >"$test_root/$name.stdout" 2>"$test_root/$name.stderr"; then
    fail "$name should be rejected"
  fi
}

lf_ini=$test_root/lf.ini
printf '[IBGateway]\nTrustedIPs=127.0.0.1\n' >"$lf_ini"
expect_accept valid_lf "$lf_ini"

crlf_ini=$test_root/crlf.ini
printf '[IBGateway]\r\nTrustedIPs=127.0.0.1\r\n' >"$crlf_ini"
expect_accept valid_crlf "$crlf_ini"

altered_ini=$test_root/altered.ini
printf '[IBGateway]\nTrustedIPs=127.0.0.2\n' >"$altered_ini"
expect_reject altered_value "$altered_ini"

extra_ip_ini=$test_root/extra-ip.ini
printf '[IBGateway]\nTrustedIPs=127.0.0.1,192.0.2.1\n' >"$extra_ip_ini"
expect_reject extra_ip "$extra_ip_ini"

missing_key_ini=$test_root/missing-key.ini
printf '[IBGateway]\nReadOnlyApi=yes\n' >"$missing_key_ini"
expect_reject missing_key "$missing_key_ini"

duplicate_key_ini=$test_root/duplicate-key.ini
printf '[IBGateway]\nTrustedIPs=127.0.0.1\nTrustedIPs=192.0.2.1\n' >"$duplicate_key_ini"
expect_reject duplicate_key "$duplicate_key_ini"

non_regular_ini=$test_root/non-regular.ini
mkdir "$non_regular_ini"
expect_reject non_regular "$non_regular_ini"

new_ini=$test_root/new.ini
expect_accept missing_file "$new_ini"
[[ $(<"$new_ini") == $'[IBGateway]\nTrustedIPs=127.0.0.1' ]] \
  || fail "missing jts.ini was not initialized with the localhost-only policy"

printf 'PASS: Gateway API trust guard accepts LF/CRLF localhost-only policy and fails closed\n'
