#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
coordinator=${IBKR_GATEWAY_ENSURE_SCRIPT:-$script_dir/ibkr-gateway-ensure.sh}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$coordinator" ]] || fail "missing coordinator: $coordinator"

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT

fake_bin="$test_root/bin"
state_dir="$test_root/state"
mkdir -p "$fake_bin" "$state_dir"

cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == --user ]] && shift
[[ ${1:-} == -q ]] && shift
action=${1:-}
service=${!#}
profile=${service#ibkr-gateway-}
profile=${profile%.service}
case "$action" in
  is-active)
    [[ -f "$IBKR_TEST_STATE_DIR/$profile" ]] || exit 3
    [[ $(<"$IBKR_TEST_STATE_DIR/$profile") == active ]]
    ;;
  stop)
    printf 'stop %s\n' "$profile" >>"$IBKR_TEST_EVENT_LOG"
    printf 'inactive\n' >"$IBKR_TEST_STATE_DIR/$profile"
    ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_bin/systemctl"

cat >"$fake_bin/ibkr-local" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 3 && $1 == connect && $2 == --profile ]] || exit 2
profile=$3
printf 'ready %s\n' "$profile" >>"$IBKR_TEST_EVENT_LOG"
[[ -f "$IBKR_TEST_STATE_DIR/$profile.ready" ]]
EOF
chmod +x "$fake_bin/ibkr-local"

for profile in main-live pension-live; do
  cat >"$fake_bin/ibkr-gateway-reauth-$profile" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' '$profile' >>"\$IBKR_TEST_HELPER_LOG"
printf 'start %s\\n' '$profile' >>"\$IBKR_TEST_EVENT_LOG"
if [[ -f "\$IBKR_TEST_STATE_DIR/$profile.fail" ]]; then
  exit 1
fi
printf 'active\\n' >"\$IBKR_TEST_STATE_DIR/$profile"
EOF
  chmod +x "$fake_bin/ibkr-gateway-reauth-$profile"
done

run_case() {
  local name=$1 main_state=$2 pension_state=$3 failed_profile=${4:-} unready_profile=${5:-}
  case_dir="$test_root/$name"
  mkdir -p "$case_dir"
  printf '%s\n' "$main_state" >"$case_dir/main-live"
  printf '%s\n' "$pension_state" >"$case_dir/pension-live"
  : >"$case_dir/main-live.ready"
  : >"$case_dir/pension-live.ready"
  : >"$case_dir/helpers.log"
  : >"$case_dir/events.log"
  if [[ -n "$failed_profile" ]]; then
    : >"$case_dir/$failed_profile.fail"
  fi
  if [[ -n "$unready_profile" ]]; then
    rm -f "$case_dir/$unready_profile.ready"
  fi

  set +e
  PATH="$fake_bin:$PATH" \
    IBKR_TEST_STATE_DIR="$case_dir" \
    IBKR_TEST_HELPER_LOG="$case_dir/helpers.log" \
    IBKR_TEST_EVENT_LOG="$case_dir/events.log" \
    IBKR_GATEWAY_READY_TIMEOUT=1 \
    IBKR_GATEWAY_READY_INTERVAL=1 \
    bash "$coordinator" main-live pension-live \
      >"$case_dir/stdout" 2>"$case_dir/stderr"
  case_exit=$?
  set -e
}

assert_exit() {
  [[ $case_exit -eq $1 ]] || fail "expected exit $1, got $case_exit"
}

assert_helpers() {
  local expected=$1 actual
  actual=$(<"$case_dir/helpers.log")
  [[ "$actual" == "$expected" ]] \
    || fail "unexpected helper calls: expected [$expected], got [$actual]"
}

assert_events() {
  local expected=$1 actual
  actual=$(<"$case_dir/events.log")
  [[ "$actual" == "$expected" ]] \
    || fail "unexpected events: expected [$expected], got [$actual]"
}

assert_no_event() {
  local pattern=$1
  if grep -Eq -- "$pattern" "$case_dir/events.log"; then
    fail "unexpected event matching [$pattern]: $(<"$case_dir/events.log")"
  fi
}

assert_service() {
  local profile=$1 expected=$2 actual
  actual=$(<"$case_dir/$profile")
  [[ "$actual" == "$expected" ]] \
    || fail "$profile state: expected $expected, got $actual"
}

run_case both_active active active
assert_exit 0
assert_helpers ""
assert_events $'ready main-live\nready pension-live'

run_case pension_missing active inactive
assert_exit 0
assert_helpers "pension-live"
assert_events $'ready main-live\nstart pension-live\nready pension-live'
assert_service main-live active
assert_service pension-live active

run_case both_missing inactive inactive
assert_exit 0
assert_helpers $'main-live\npension-live'
assert_events $'start main-live\nready main-live\nstart pension-live\nready pension-live'
assert_service main-live active
assert_service pension-live active

run_case main_fails inactive inactive main-live
assert_exit 1
assert_helpers 'main-live'
assert_events 'start main-live'
assert_service main-live inactive
assert_service pension-live inactive

run_case main_unready active inactive "" main-live
assert_exit 1
assert_helpers ""
assert_no_event 'pension-live'
assert_no_event 'stop main-live'
assert_service main-live active
assert_service pension-live inactive

run_case main_started_unready inactive inactive "" main-live
assert_exit 1
assert_helpers 'main-live'
assert_events $'start main-live\nready main-live\nready main-live\nstop main-live'
assert_service main-live inactive
assert_service pension-live inactive

printf 'PASS: ibkr-gateway-ensure coordinator\n'
