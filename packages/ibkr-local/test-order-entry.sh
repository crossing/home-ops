#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cli=$script_dir/ibkr-local.sh
order_lib=$script_dir/order-entry.sh
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

export XDG_RUNTIME_DIR="$test_root/runtime"
export XDG_STATE_HOME="$test_root/state"
export IBKR_LOCAL_CONFIG_DIR="$test_root/config"
export IBKR_LOCAL_PROFILES="$test_root/config/profiles.json"
export IBKR_LOCAL_XDG_CONFIG_HOME="$test_root/config"
export FAKE_LOG="$test_root/upstream.log"
export FAKE_MODE=success

mkdir -p "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME" "$IBKR_LOCAL_CONFIG_DIR"

cat >"$IBKR_LOCAL_PROFILES" <<'JSON'
{
  "defaultProfile": "main-paper",
  "profiles": {
    "main-paper": {
      "ibkrProfile": "main-paper",
      "mode": "paper",
      "orderEntry": {
        "enable": true,
        "ticketTtlSeconds": 120,
        "allowedOrderTypes": ["LMT"],
        "allowOutsideRth": false
      }
    },
    "main-live": {
      "ibkrProfile": "main-live",
      "mode": "live",
      "orderEntry": {
        "enable": true,
        "ticketTtlSeconds": 120,
        "allowedOrderTypes": ["LMT"],
        "allowOutsideRth": false
      }
    },
    "disabled-live": {
      "ibkrProfile": "disabled-live",
      "mode": "live",
      "orderEntry": {
        "enable": false,
        "ticketTtlSeconds": 120,
        "allowedOrderTypes": ["LMT"],
        "allowOutsideRth": false
      }
    }
  }
}
JSON

fake_upstream="$test_root/fake-ibkr"
cat >"$fake_upstream" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%q ' "$@" >>"$FAKE_LOG"
printf '\n' >>"$FAKE_LOG"

case " $* " in
  *' --preview '*)
    cat <<'JSON'
{
  "profile": "main-live",
  "preview_only": true,
  "selected_account": "TEST123",
  "symbol": "AAPL",
  "local_symbol": "AAPL",
  "exchange": "SMART",
  "primary_exchange": "NASDAQ",
  "currency": "USD",
  "sec_type": "STK",
  "con_id": 265598,
  "status": "PreSubmitted",
  "commission": 1,
  "min_commission": 1,
  "max_commission": 1,
  "commission_currency": "USD",
  "init_margin_change": 100,
  "maint_margin_change": 100,
  "equity_with_loan_change": -100,
  "warning_text": null,
  "raw_error_codes": []
}
JSON
    ;;
  *)
    printf '{"status":"Submitted","order_id":42,"selected_account":"TEST123"}\n'
    ;;
esac
SH
chmod +x "$fake_upstream"
export IBKR_UPSTREAM="$fake_upstream"

run_cli() {
  bash -c '
    order_lib=$1
    cli=$2
    shift 2
    source "$order_lib"
    source "$cli"
  ' _ "$order_lib" "$cli" "$@"
}

expect_fail() {
  if run_cli "$@" >"$test_root/unexpected.out" 2>"$test_root/expected.err"; then
    printf 'FAIL: command unexpectedly succeeded: %s\n' "$*" >&2
    return 1
  fi
}

run_prepare_tests() {
  : >"$FAKE_LOG"

  expect_fail order-prepare buy AAPL 1 --profile disabled-live --account TEST123 --type LMT --limit 100
  expect_fail order-prepare buy AAPL 1 --account TEST123 --type LMT --limit 100
  expect_fail order-prepare buy AAPL 1 --profile main-live --type LMT --limit 100
  expect_fail order-prepare buy AAPL 1 --profile main-live --account TEST123 --type MKT
  expect_fail order-prepare buy AAPL 1 --profile main-live --account TEST123 --type LMT --limit 100 --outside-rth

  ticket_json=$(run_cli order-prepare buy AAPL 1 --profile main-live --account TEST123 --type LMT --limit 100)
  ticket_id=$(jq -er '.ticketId' <<<"$ticket_json")
  ticket="$XDG_RUNTIME_DIR/ibkr-local/order-tickets/prepared/$ticket_id.json"

  [[ -f "$ticket" ]]
  [[ "$(stat -c %a "$ticket")" == 600 ]]
  jq -e '
    .schemaVersion == 1
    and .account == "TEST123"
    and .order.orderType == "LMT"
    and .order.limitPrice == 100
    and .preview.previewOnly == true
    and (.checksum | length == 64)
  ' "$ticket" >/dev/null
  grep -q -- '--preview' "$FAKE_LOG"
  if grep -q -- '--submit' "$FAKE_LOG"; then
    echo 'FAIL: prepare invoked submit' >&2
    return 1
  fi

  printf 'PASS: guarded order preparation\n'
}

case "${1:-all}" in
  prepare|all)
    run_prepare_tests
    ;;
  *)
    echo "unknown test group: $1" >&2
    exit 2
    ;;
esac
