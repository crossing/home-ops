#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
module=$script_dir/default.nix
cli=$script_dir/../../../packages/ibkr-local/ibkr-local.sh

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

fake_bin=$test_root/bin
mkdir -p "$fake_bin"
cat >"$fake_bin/safe-op" <<'EOF'
#!/usr/bin/env bash
case "$2" in
  op://test/username) printf 'test-user' ;;
  op://test/password) printf 'test-password' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_bin/safe-op"

profiles=$test_root/profiles.json
printf '%s\n' '{"profiles":{"test":{"mode":"live","port":4001}}}' >"$profiles"
runtime_parent=$test_root/runtime
mkdir -p "$runtime_parent"

render_json=$(PATH="$fake_bin:$PATH" \
  IBKR_LOCAL_PROFILES="$profiles" \
  IBKR_IBC_RUNTIME_PARENT="$runtime_parent" \
  bash "$cli" ibc-config \
    --profile test \
    --username-ref op://test/username \
    --password-ref op://test/password \
    --second-factor-device 'IBKR Mobile' \
    --auto-restart-time '08:00 AM')
config=$(printf '%s\n' "$render_json" | jq -er '.config')
runtime_dir=$(printf '%s\n' "$render_json" | jq -er '.runtime_dir')

cleanup() {
  rm -rf -- "$runtime_dir"
}
trap cleanup EXIT

[[ $(stat -c '%a' "$config") == 600 ]] \
  || fail "rendered IBC config must be mode 0600"
[[ $(stat -c '%a' "$runtime_dir") == 700 ]] \
  || fail "rendered IBC runtime directory must be mode 0700"

grep -Fxq 'ExistingSessionDetectedAction=primary' "$config" \
  || fail "rendered IBC config must select IBC's primary session policy"
grep -Fxq 'ReloginAfterSecondFactorAuthenticationTimeout=no' "$config" \
  || fail "rendered IBC config must not retry second-factor authentication without bound"
grep -Fxq 'SecondFactorAuthenticationExitInterval=60' "$config" \
  || fail "rendered IBC config must keep the bounded second-factor exit interval"
grep -Fxq 'AcceptIncomingConnectionAction=reject' "$config" \
  || fail "rendered IBC config must reject untrusted API connections"

grep -Fq 'TrustedIPs=127.0.0.1' "$module" \
  || fail "Gateway API trust policy must remain localhost-only"
grep -Fq "trap '[[ -z \"\${runtime_dir:-}\" ]] || rm -rf -- \"\$runtime_dir\"' EXIT" "$cli" \
  || fail "renderer must clean up ephemeral credentials on failure"
grep -Fq "grep -qx 'ExistingSessionDetectedAction=primary'" "$module" \
  || fail "Gateway reauthentication must fail closed unless the primary session policy is rendered"

printf 'PASS: IBC renderer selects the primary session policy and retains gateway safety controls\n'
