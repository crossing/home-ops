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
service=${!#}
profile=${service#ibkr-gateway-}
profile=${profile%.service}
[[ -f "$IBKR_TEST_STATE_DIR/$profile" ]] || exit 3
[[ $(<"$IBKR_TEST_STATE_DIR/$profile") == active ]]
EOF
chmod +x "$fake_bin/systemctl"

for profile in main-live pension-live; do
  cat >"$fake_bin/ibkr-gateway-reauth-$profile" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' '$profile' >>"\$IBKR_TEST_HELPER_LOG"
if [[ -f "\$IBKR_TEST_STATE_DIR/$profile.fail" ]]; then
  exit 1
fi
printf 'active\\n' >"\$IBKR_TEST_STATE_DIR/$profile"
EOF
  chmod +x "$fake_bin/ibkr-gateway-reauth-$profile"
done

run_case() {
  local name=$1 main_state=$2 pension_state=$3 failed_profile=${4:-}
  case_dir="$test_root/$name"
  mkdir -p "$case_dir"
  printf '%s\n' "$main_state" >"$case_dir/main-live"
  printf '%s\n' "$pension_state" >"$case_dir/pension-live"
  : >"$case_dir/helpers.log"
  if [[ -n "$failed_profile" ]]; then
    : >"$case_dir/$failed_profile.fail"
  fi

  set +e
  PATH="$fake_bin:$PATH" \
    IBKR_TEST_STATE_DIR="$case_dir" \
    IBKR_TEST_HELPER_LOG="$case_dir/helpers.log" \
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

assert_service() {
  local profile=$1 expected=$2 actual
  actual=$(<"$case_dir/$profile")
  [[ "$actual" == "$expected" ]] \
    || fail "$profile state: expected $expected, got $actual"
}

run_case both_active active active
assert_exit 0
assert_helpers ""

run_case pension_missing active inactive
assert_exit 0
assert_helpers "pension-live"
assert_service main-live active
assert_service pension-live active

run_case both_missing inactive inactive
assert_exit 0
assert_helpers $'main-live\npension-live'
assert_service main-live active
assert_service pension-live active

run_case main_fails inactive inactive main-live
assert_exit 1
assert_helpers $'main-live\npension-live'
assert_service main-live inactive
assert_service pension-live active

printf 'PASS: ibkr-gateway-ensure coordinator\n'
