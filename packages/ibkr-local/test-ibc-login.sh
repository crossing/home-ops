#!/usr/bin/env bash
set -euo pipefail

readonly APP_NAME="ibkr-ibc-login-test"

profile="main-live"
home_config="xing@desktop"
op_account="my.1password.com"
username="crossing2p"
username_field="username"
password_field="password"
item_id=""
duration="300"
display_mode="visible"
system=""
keep_temp=0
build_package=1
render_only=0
allow_paper=0
read_only_login=0

workdir=""
runtime_parent=""
runtime_dir=""
profiles_json=""
ibc_json=""
ibc_ini=""
tws_dir=""
jts_config_dir=""
profile_mode=""
session=""
session_env=""
selected_item=""
selected_item_vault=""
sanitized_log=""

usage() {
  cat <<'USAGE'
Usage: packages/ibkr-local/test-ibc-login.sh [options]

Runs the local IBKR IBC login test sequence:
  1. Build .#packages.<system>.ibkr-local
  2. Write a temporary programs.ibkrLocal profile JSON
  3. Sign in to 1Password CLI locally
  4. Find the IBKR login item by username
  5. Render an ephemeral IBC config through safe-op
  6. Start TWS through IBC with sanitized logs
  7. Remove the temporary credential config on exit

Options:
  --profile NAME          ibkr-local profile to launch (default: main-live)
  --home-config NAME      Home Manager config to evaluate (default: xing@desktop)
  --op-account ACCOUNT    1Password account selector (default: my.1password.com)
  --username USERNAME     1Password username to match (default: crossing2p)
  --item-id ID            Skip discovery and use this 1Password item id
  --username-field FIELD  1Password username field label (default: username)
  --password-field FIELD  1Password password field label (default: password)
  --duration SECONDS      Attached run duration; 0 means until TWS exits/Ctrl-C (default: 300)
  --visible               Use the current desktop session (default)
  --x11                   Use the current X11 DISPLAY
  --xvfb                  Run IBC/TWS in a virtual X11 display
  --allow-paper           Allow a paper profile for debugging; default requires live mode
  --read-only-login       Ask IBC/TWS for read-only login without completing 2FA
  --system SYSTEM         Flake package system (default: builtins.currentSystem)
  --no-build              Use ibkr-local from PATH instead of building the flake package
  --render-only           Stop after rendering the ephemeral IBC config
  --keep-temp             Keep temp profile and IBC config directories for debugging
  -h, --help              Show this help

Examples:
  packages/ibkr-local/test-ibc-login.sh --item-id 3drrbjgoksyc3tuu4yxyvshjvq
  packages/ibkr-local/test-ibc-login.sh --read-only-login --duration 300 --item-id 3drrbjgoksyc3tuu4yxyvshjvq
  packages/ibkr-local/test-ibc-login.sh --xvfb --duration 600 --item-id 3drrbjgoksyc3tuu4yxyvshjvq
  packages/ibkr-local/test-ibc-login.sh --allow-paper --profile main-paper --render-only
USAGE
}

log() {
  printf '%s: %s\n' "$APP_NAME" "$*" >&2
}

die() {
  log "$*"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

safe_rm_dir() {
  local path=${1:-}
  [[ -n "$path" ]] || return 0
  [[ -e "$path" ]] || return 0

  case "$path" in
    /tmp/ibkr-ibc-test.*|/run/user/*/ibkr-ibc.*)
      rm -rf "$path"
      ;;
    *)
      log "refusing to remove unexpected temp path: $path"
      ;;
  esac
}

restore_tws_launcher() {
  [[ -n "${tws_dir:-}" ]] || return 0
  if [[ ! -e "$tws_dir/tws" && -e "$tws_dir/tws1" ]]; then
    mv "$tws_dir/tws1" "$tws_dir/tws"
  fi
  if [[ ! -e "$tws_dir/ibgateway" && -e "$tws_dir/ibgateway1" ]]; then
    mv "$tws_dir/ibgateway1" "$tws_dir/ibgateway"
  fi
}

cleanup() {
  local status=$?

  restore_tws_launcher || true

  if [[ "$keep_temp" == "0" ]]; then
    safe_rm_dir "$runtime_dir"
    safe_rm_dir "$workdir"
  else
    log "kept temp workdir: ${workdir:-unset}"
    log "kept IBC runtime dir: ${runtime_dir:-unset}"
  fi

  if [[ -n "${session_env:-}" ]]; then
    unset "$session_env" || true
  fi

  exit "$status"
}

sed_escape_regex() {
  sed -e 's/[][\/.^$*+?{}()|&]/\\&/g' <<<"$1"
}

sanitize_output() {
  local escaped_username
  escaped_username=$(sed_escape_regex "$username")

  sed -E \
    -e 's/(IbLoginId=).*/\1[redacted]/' \
    -e 's/(IbPassword=).*/\1[redacted]/' \
    -e 's/(--user[ =])([^ ]+)/\1[redacted]/g' \
    -e 's/(--pw[ =])([^ ]+)/\1[redacted]/g' \
    -e 's/(-DjxBrowserKey=)[^[:space:]"]+/\1[redacted]/g' \
    -e 's/(jxBrowserKey[ =]+)[^[:space:]"]+/\1[redacted]/g' \
    -e "s/${escaped_username}/[redacted-username]/g"
}

detect_auth_state() {
  if [[ -n "${sanitized_log:-}" && -f "$sanitized_log" ]]; then
    if grep -Eiq 'logged in|login (has )?completed|main window|api server' "$sanitized_log"; then
      printf 'logged-in\n'
      return 0
    fi
    if grep -Eiq 'second factor|2fa|two-factor|ib key|ibkr mobile|authentication dialog has timed out|security code' "$sanitized_log"; then
      printf '2fa\n'
      return 0
    fi
  fi

  local launcher_log="$jts_config_dir/launcher.log"
  if [[ -f "$launcher_log" ]]; then
    if tail -n 2000 "$launcher_log" 2>/dev/null | grep -Eiq 'logged in|login (has )?completed|main window'; then
      printf 'logged-in\n'
      return 0
    fi
    if tail -n 2000 "$launcher_log" 2>/dev/null | grep -Eiq 'second factor|2fa|two-factor|ib key|ibkr mobile|security code'; then
      printf '2fa\n'
      return 0
    fi
    if tail -n 2000 "$launcher_log" 2>/dev/null | grep -Eiq 'Authenticating|Starting launcher login thread|LauncherLoginThread'; then
      printf 'credentials-submitted\n'
      return 2
    fi
  fi

  return 1
}

detect_session_env() {
  local candidate
  local candidates=(
    OP_SESSION_my
    OP_SESSION_my_1password_com
    OP_SESSION_my_1password
  )

  for candidate in "${candidates[@]}"; do
    if env "$candidate=$session" op whoami --account "$op_account" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

op_with_session() {
  env "$session_env=$session" OP_ACCOUNT="$op_account" op "$@"
}

safe_op_with_session() {
  env "$session_env=$session" OP_ACCOUNT="$op_account" safe-op "$@"
}

op_secret_ref() {
  local vault=$1 item=$2 field=$3
  printf 'op://%s/%s/%s\n' "$vault" "$item" "$field"
}

jq_vault_ref() {
  jq -er --arg id "$1" '
    .[]
    | select(.id == $id)
    | (.vault.id // .vault.uuid // "") as $vault_id
    | if $vault_id != "" then $vault_id else .vault.name end
  ' "$2"
}

parse_args() {
  while (($#)); do
    case "$1" in
      --profile)
        (($# >= 2)) || die "$1 requires a value"
        profile=$2
        shift 2
        ;;
      --home-config)
        (($# >= 2)) || die "$1 requires a value"
        home_config=$2
        shift 2
        ;;
      --op-account)
        (($# >= 2)) || die "$1 requires a value"
        op_account=$2
        shift 2
        ;;
      --username)
        (($# >= 2)) || die "$1 requires a value"
        username=$2
        shift 2
        ;;
      --item-id)
        (($# >= 2)) || die "$1 requires a value"
        item_id=$2
        shift 2
        ;;
      --username-field)
        (($# >= 2)) || die "$1 requires a value"
        username_field=$2
        shift 2
        ;;
      --password-field)
        (($# >= 2)) || die "$1 requires a value"
        password_field=$2
        shift 2
        ;;
      --duration)
        (($# >= 2)) || die "$1 requires a value"
        duration=$2
        shift 2
        ;;
      --visible)
        display_mode="visible"
        shift
        ;;
      --x11)
        display_mode="x11"
        shift
        ;;
      --xvfb)
        display_mode="xvfb"
        shift
        ;;
      --allow-paper)
        allow_paper=1
        shift
        ;;
      --read-only-login)
        read_only_login=1
        shift
        ;;
      --system)
        (($# >= 2)) || die "$1 requires a value"
        system=$2
        shift 2
        ;;
      --no-build)
        build_package=0
        shift
        ;;
      --render-only)
        render_only=1
        shift
        ;;
      --keep-temp)
        keep_temp=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done

  [[ "$duration" =~ ^[0-9]+$ ]] || die "--duration must be an integer number of seconds"
  case "$display_mode" in
    visible|x11|xvfb) ;;
    *) die "unsupported display mode: $display_mode" ;;
  esac
}

build_or_find_ibkr_local() {
  local ibkr_local package_path

  if [[ "$build_package" == "0" ]]; then
    ibkr_local=$(command -v ibkr-local) || die "ibkr-local is not on PATH"
    printf '%s\n' "$ibkr_local"
    return 0
  fi

  if [[ -z "$system" ]]; then
    system=$(nix eval --raw --impure --expr 'builtins.currentSystem')
  fi

  log "building .#packages.$system.ibkr-local"
  package_path=$(nix build --no-link --print-out-paths ".#packages.$system.ibkr-local" -L | tail -n 1)
  ibkr_local="$package_path/bin/ibkr-local"
  [[ -x "$ibkr_local" ]] || die "built package does not expose executable: $ibkr_local"
  printf '%s\n' "$ibkr_local"
}

write_profiles_json() {
  local home_attr=".#homeConfigurations.\"$home_config\".config.programs.ibkrLocal"

  profiles_json="$workdir/profiles.json"
  log "evaluating $home_attr"
  nix eval --json "$home_attr" \
    | jq '{defaultProfile, accounts, profiles}' > "$profiles_json"

  jq -e --arg profile "$profile" '.profiles[$profile]' "$profiles_json" >/dev/null \
    || die "profile '$profile' not found in $home_attr"

  profile_mode=$(jq -er --arg profile "$profile" '.profiles[$profile].mode' "$profiles_json")
  if [[ "$profile_mode" != "live" && "$allow_paper" == "0" ]]; then
    die "profile '$profile' is mode '$profile_mode'; use --profile main-live or pass --allow-paper for paper diagnostics"
  fi

  tws_dir=$(jq -er --arg profile "$profile" '.profiles[$profile].twsDir' "$profiles_json")
  jts_config_dir=$(jq -er --arg profile "$profile" '.profiles[$profile].jtsConfigDir' "$profiles_json")
}

find_item_by_username() {
  local items_json id matched_count=0 matched_id="" summary

  items_json="$workdir/op-login-items.json"
  op_with_session item list --categories Login --format json > "$items_json"

  if [[ -n "$item_id" ]]; then
    local actual_username username_ref
    selected_item_vault=$(jq_vault_ref "$item_id" "$items_json")
    username_ref=$(op_secret_ref "$selected_item_vault" "$item_id" "$username_field")
    actual_username=$(safe_op_with_session read "$username_ref" --no-newline)
    if [[ "$actual_username" != "$username" ]]; then
      die "item $item_id does not have username '$username' in field '$username_field'"
    fi
    selected_item=$item_id
    return 0
  fi

  while IFS= read -r id; do
    local actual_username vault username_ref
    vault=$(jq_vault_ref "$id" "$items_json")
    username_ref=$(op_secret_ref "$vault" "$id" "$username_field")
    actual_username=$(safe_op_with_session read "$username_ref" --no-newline 2>/dev/null || true)
    if [[ "$actual_username" == "$username" ]]; then
      matched_id=$id
      selected_item_vault=$vault
      matched_count=$((matched_count + 1))
    fi
  done < <(
    jq -r '
      .[]
      | select(
          ((.title // "") | test("interactive|ibkr|broker|tws"; "i"))
          or ((.urls // []) | tostring | test("interactivebrokers|ibkr"; "i"))
        )
      | .id
    ' "$items_json"
  )

  if [[ "$matched_count" == "0" ]]; then
    die "found no IBKR-looking 1Password Login item with username '$username'"
  fi
  if [[ "$matched_count" != "1" ]]; then
    die "found $matched_count matching items; rerun with --item-id"
  fi

  summary=$(jq -r --arg id "$matched_id" '.[] | select(.id == $id) | [.id, .title, .vault.name] | @tsv' "$items_json")
  log "selected 1Password item: $summary"
  selected_item=$matched_id
}

render_ibc_config() {
  local ibkr_local=$1 selected_item=$2
  local username_ref password_ref

  ibc_json="$workdir/ibc.json"
  log "rendering ephemeral IBC config through safe-op"
  username_ref=$(op_secret_ref "$selected_item_vault" "$selected_item" "$username_field")
  password_ref=$(op_secret_ref "$selected_item_vault" "$selected_item" "$password_field")
  local -a ibc_config_args
  ibc_config_args=(
    --profile "$profile"
    --username-ref "$username_ref"
    --password-ref "$password_ref"
    --trading-mode "$profile_mode"
  )
  if [[ "$read_only_login" == "1" ]]; then
    ibc_config_args+=(--read-only-login)
  fi

  env "$session_env=$session" OP_ACCOUNT="$op_account" IBKR_LOCAL_PROFILES="$profiles_json" IBKR_IBC_RUNTIME_PARENT="$runtime_parent" \
    "$ibkr_local" ibc-config \
    "${ibc_config_args[@]}" > "$ibc_json"

  runtime_dir=$(jq -er '.runtime_dir' "$ibc_json")
  ibc_ini=$(jq -er '.config' "$ibc_json")
}

verify_ibc_config() {
  case "$runtime_dir" in
    "$runtime_parent"/ibkr-ibc.*) ;;
    *) die "IBC runtime dir is outside the test runtime parent: $runtime_dir" ;;
  esac

  [[ -f "$ibc_ini" ]] || die "IBC config was not created: $ibc_ini"
  [[ "$(stat -c %a "$ibc_ini")" == "600" ]] || die "IBC config mode is not 600"
  grep -qx "TradingMode=$profile_mode" "$ibc_ini" \
    || die "IBC config TradingMode does not match profile mode '$profile_mode'"
  if [[ "$read_only_login" == "1" ]]; then
    grep -qx "ReadOnlyLogin=yes" "$ibc_ini" \
      || die "IBC config did not enable ReadOnlyLogin"
  else
    ! grep -qx "ReadOnlyLogin=yes" "$ibc_ini" \
      || die "IBC config enabled ReadOnlyLogin unexpectedly"
  fi
}

run_tws_ibc() {
  local ibkr_local=$1 ibc_ini=$2 run_status=0
  local auth_state="" auth_status=1
  local -a command

  command=(
    env
    "IBKR_LOCAL_PROFILES=$profiles_json"
    "IBC_INI=$ibc_ini"
    "$ibkr_local"
    tws
    --profile "$profile"
  )

  case "$display_mode" in
    visible) command+=(--visible) ;;
    x11) command+=(--x11) ;;
    xvfb) command+=(--xvfb) ;;
  esac
  command+=(--ibc)

  sanitized_log="$workdir/tws-ibc-sanitized.log"

  log "launching TWS through IBC for profile '$profile' in '$display_mode' display mode"
  log "logs are sanitized before printing; press Ctrl-C to stop early"

  set +e
  if [[ "$duration" == "0" ]]; then
    "${command[@]}" 2>&1 | sanitize_output | tee "$sanitized_log"
    run_status=${PIPESTATUS[0]}
  else
    timeout --foreground "$duration" "${command[@]}" 2>&1 | sanitize_output | tee "$sanitized_log"
    run_status=${PIPESTATUS[0]}
  fi
  auth_state=$(detect_auth_state)
  auth_status=$?
  set -e

  if [[ "$auth_status" == "0" ]]; then
    log "authentication target reached: $auth_state"
    return 0
  fi

  if [[ "$auth_status" == "2" ]]; then
    log "credentials were submitted, but no 2FA or logged-in evidence was found yet"
  fi

  case "$run_status" in
    0)
      log "TWS/IBC exited normally before the requested authentication state was proven"
      run_status=1
      ;;
    124)
      log "timeout reached after ${duration}s before the requested authentication state was proven"
      ;;
    130|141)
      log "interrupted"
      ;;
    *)
      log "TWS/IBC exited with status $run_status"
      ;;
  esac

  return "$run_status"
}

main() {
  parse_args "$@"

  require_cmd git
  require_cmd grep
  require_cmd jq
  require_cmd nix
  require_cmd op
  require_cmd safe-op
  require_cmd sed
  require_cmd stat
  require_cmd tail
  require_cmd tee
  require_cmd timeout

  local repo_root ibkr_local
  repo_root=$(git rev-parse --show-toplevel)
  cd "$repo_root"

  workdir=$(mktemp -d /tmp/ibkr-ibc-test.XXXXXX)
  runtime_parent="$workdir/runtime"
  mkdir -m 700 "$runtime_parent"
  trap cleanup EXIT

  ibkr_local=$(build_or_find_ibkr_local)
  write_profiles_json

  log "signing in to 1Password CLI account '$op_account'"
  session=$(op signin --account "$op_account" --raw)
  session_env=$(detect_session_env) \
    || die "could not find the 1Password OP_SESSION_* env name for account '$op_account'"

  find_item_by_username
  render_ibc_config "$ibkr_local" "$selected_item"
  verify_ibc_config
  if [[ "$render_only" == "1" ]]; then
    log "render-only completed; ephemeral IBC config was rendered and will be removed on exit"
    return 0
  fi
  run_tws_ibc "$ibkr_local" "$ibc_ini"
}

main "$@"
