#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cli=$script_dir/ibkr-local.sh
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

mkdir -p "$test_root/bin" "$test_root/runtime"
cat >"$test_root/bin/safe-op" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$2" in
  */username) printf 'test-user' ;;
  */password) printf 'test-password' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$test_root/bin/safe-op"

result=$(
  PATH="$test_root/bin:$PATH" \
    IBKR_IBC_RUNTIME_PARENT="$test_root/runtime" \
    bash "$cli" ibc-config \
      --profile main-live \
      --username-ref op://test/item/username \
      --password-ref op://test/item/password \
      --trading-mode live \
      --api-port 4005 \
      --allow-api-write
)
config=$(jq -r '.config' <<<"$result")

grep -qx 'AcceptIncomingConnectionAction=reject' "$config"
if grep -qx 'AcceptIncomingConnectionAction=accept' "$config"; then
  echo 'FAIL: rendered IBC config accepts unsolicited API prompts' >&2
  exit 1
fi

printf 'PASS: rendered IBC config rejects unsolicited API prompts\n'
