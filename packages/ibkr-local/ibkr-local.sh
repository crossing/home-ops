#!/usr/bin/env bash
set -euo pipefail

readonly APP_NAME="ibkr"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
local_config_dir="${IBKR_LOCAL_CONFIG_DIR:-$config_home/ibkr-local}"
profiles_json="${IBKR_LOCAL_PROFILES:-$local_config_dir/profiles.json}"
ibkr_xdg_home="${IBKR_LOCAL_XDG_CONFIG_HOME:-$local_config_dir}"

usage() {
  cat <<'USAGE'
Usage: ibkr <command> [options]

Profile options:
  -p, --profile NAME       Local runtime profile (default from profiles.json)
  -g, --group NAME         Account group filter: margin, cash, isa, pension
  --account ACCOUNT        Restrict to one IBKR account id
  --raw                    Print upstream JSON without local account filtering

Commands:
  doctor                   JSON connectivity/config diagnostic
  connect                  JSON TCP/API connectivity test
  positions                JSON positions
  balances                 JSON account summary
  executions               JSON order executions
  flex-trades              JSON Flex trades
  transfers                JSON Flex transfers
  dividends                JSON Flex dividends/cash transactions
  order-preview buy|sell   What-if order preview only; --submit is blocked
  config path|show         Print local/upstream config paths or local config
  gateway                  Launch IB Gateway for a local profile
  ibc-config               Render ephemeral IBC config from safe-op secret refs

Examples:
  ibkr positions --profile main-paper --group isa
  ibkr balances --profile main-live --account U1234567
  ibkr order-preview buy AAPL 1 --profile main-paper --limit 100 --json
USAGE
}

die() {
  printf '%s: %s\n' "$APP_NAME" "$*" >&2
  exit 1
}

require_config() {
  [[ -f "$profiles_json" ]] || die "missing profile config: $profiles_json"
}

jq_profile() {
  local profile=$1 expr=$2
  jq -er --arg profile "$profile" "$expr" "$profiles_json"
}

default_profile() {
  jq -er '.defaultProfile // (.profiles | keys[0])' "$profiles_json"
}

profile_string() {
  local profile=$1 key=$2 fallback=${3:-}
  jq -er --arg profile "$profile" --arg key "$key" --arg fallback "$fallback" \
    '.profiles[$profile][$key] // $fallback' "$profiles_json"
}

account_ids_json() {
  local profile=$1 group=$2
  if [[ -z "$group" ]]; then
    jq -cn '[]'
    return
  fi
  jq -c --arg profile "$profile" --arg group "$group" '
    ((.profiles[$profile].accounts[$group] // .accounts[$group] // []) | map(tostring))
  ' "$profiles_json"
}

filter_accounts() {
  local profile=$1 group=$2 account=$3
  local ids_json
  if [[ -n "$account" ]]; then
    ids_json=$(jq -cn --arg account "$account" '[$account]')
  else
    ids_json=$(account_ids_json "$profile" "$group")
  fi

  if [[ "$ids_json" == "[]" ]]; then
    cat
    return
  fi

  jq --argjson ids "$ids_json" '
    def acct:
      (.account // .accountId // .account_id // .acctId // .acct_id // .AccountID // .accountNumber // empty)
      | tostring;
    def keep:
      (acct as $acct | ($ids | index($acct)) != null);
    def walk_filter:
      if type == "array" then map(if type == "object" and ((acct? // "") != "") then select(keep) else . end)
      elif type == "object" then with_entries(.value |= walk_filter)
      else .
      end;
    walk_filter
  '
}

safe_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --submit|submit|cancel|modify)
        die "live order mutation is blocked; use ibkr order-preview for what-if only"
        ;;
    esac
  done
}

parse_common() {
  profile=""
  group=""
  account=""
  raw=0
  remaining=()

  while (($#)); do
    case "$1" in
      -p|--profile)
        (($# >= 2)) || die "$1 requires a value"
        profile=$2
        shift 2
        ;;
      -g|--group)
        (($# >= 2)) || die "$1 requires a value"
        group=$2
        shift 2
        ;;
      --account)
        (($# >= 2)) || die "$1 requires a value"
        account=$2
        shift 2
        ;;
      --raw)
        raw=1
        shift
        ;;
      *)
        remaining+=("$1")
        shift
        ;;
    esac
  done

  if [[ -z "$profile" ]]; then
    profile=$(default_profile)
  fi
}

ibkr_profile_name() {
  local profile=$1
  profile_string "$profile" "ibkrProfile" "$profile"
}

run_ibkr_json() {
  local profile=$1 group=$2 account=$3 raw=$4
  shift 4

  local ib_profile
  ib_profile=$(ibkr_profile_name "$profile")

  local output
  if ! output=$(XDG_CONFIG_HOME="$ibkr_xdg_home" "${IBKR_UPSTREAM:?IBKR_UPSTREAM is required}" "$@" --profile "$ib_profile" --json); then
    printf '%s\n' "$output" >&2
    return 1
  fi

  if [[ "$raw" == "1" ]]; then
    printf '%s\n' "$output"
  else
    printf '%s\n' "$output" | filter_accounts "$profile" "$group" "$account"
  fi
}

run_flex_json() {
  local profile=$1 group=$2 account=$3 raw=$4
  shift 4

  local output
  if ! output=$(XDG_CONFIG_HOME="$ibkr_xdg_home" "${IBKR_UPSTREAM:?IBKR_UPSTREAM is required}" "$@" --json); then
    printf '%s\n' "$output" >&2
    return 1
  fi

  if [[ "$raw" == "1" ]]; then
    printf '%s\n' "$output"
  else
    printf '%s\n' "$output" | filter_accounts "$profile" "$group" "$account"
  fi
}

cmd_config() {
  local sub=${1:-}
  case "$sub" in
    path)
      jq -n \
        --arg profiles "$profiles_json" \
        --arg xdg "$ibkr_xdg_home" \
        --arg upstream "$ibkr_xdg_home/ibkr-cli/config.toml" \
        '{profiles_json: $profiles, ibkr_xdg_config_home: $xdg, ibkr_cli_config: $upstream}'
      ;;
    show)
      require_config
      jq . "$profiles_json"
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

cmd_gateway() {
  parse_common "$@"
  set -- "${remaining[@]}"
  require_config

  local gateway_dir jts_dir log_dir
  gateway_dir=$(profile_string "$profile" "gatewayDir" "$HOME/.local/share/ibkr/$profile/gateway")
  jts_dir=$(profile_string "$profile" "jtsConfigDir" "$HOME/.config/ibkr-local/jts/$profile")
  log_dir=$(profile_string "$profile" "logDir" "$state_home/ibkr-local/$profile")

  mkdir -p "$gateway_dir" "$jts_dir" "$log_dir"
  IBGATEWAY_DIR="$gateway_dir" IBGATEWAY_CONFIG_DIR="$jts_dir" IBGATEWAY_LOG_DIR="$log_dir" exec ibgateway "$@"
}

cmd_ibc_config() {
  require_config
  local profile="" username_ref="" password_ref="" username_item="" username_field="" username_vault="" password_item="" password_field="" password_vault="" trading_mode="" api_port="" second_factor_device="" auto_restart_time="" read_only_login=0 read_only_api=yes
  while (($#)); do
    case "$1" in
      -p|--profile)
        profile=$2
        shift 2
        ;;
      --username-ref)
        username_ref=$2
        shift 2
        ;;
      --username-item)
        username_item=$2
        shift 2
        ;;
      --username-field)
        username_field=$2
        shift 2
        ;;
      --username-vault)
        username_vault=$2
        shift 2
        ;;
      --password-ref)
        password_ref=$2
        shift 2
        ;;
      --password-item)
        password_item=$2
        shift 2
        ;;
      --password-field)
        password_field=$2
        shift 2
        ;;
      --password-vault)
        password_vault=$2
        shift 2
        ;;
      --trading-mode)
        trading_mode=$2
        shift 2
        ;;
      --api-port)
        api_port=$2
        shift 2
        ;;
      --second-factor-device)
        second_factor_device=$2
        shift 2
        ;;
      --auto-restart-time)
        auto_restart_time=$2
        shift 2
        ;;
      --read-only-login)
        read_only_login=1
        shift
        ;;
      --allow-api-write)
        read_only_api=no
        shift
        ;;
      *)
        die "unknown ibc-config option: $1"
        ;;
    esac
  done
  [[ -n "$profile" ]] || profile=$(default_profile)
  if [[ -z "$username_ref" ]]; then
    [[ -n "$username_item" ]] || die "--username-ref or --username-item is required"
    [[ -n "$username_field" ]] || die "--username-ref or --username-field is required"
    [[ -n "$username_vault" ]] || die "--username-ref or --username-vault is required"
    username_ref="op://$username_vault/$username_item/$username_field"
  fi
  if [[ -z "$password_ref" ]]; then
    [[ -n "$password_item" ]] || die "--password-ref or --password-item is required"
    [[ -n "$password_field" ]] || die "--password-ref or --password-field is required"
    [[ -n "$password_vault" ]] || die "--password-ref or --password-vault is required"
    password_ref="op://$password_vault/$password_item/$password_field"
  fi
  command -v safe-op >/dev/null 2>&1 || die "safe-op is required; refusing to read secrets with raw op"

  local runtime_parent runtime_dir config_path username password mode
  mode=${trading_mode:-$(profile_string "$profile" "mode" "paper")}
  api_port=${api_port:-$(profile_string "$profile" "port" "")}
  [[ "$api_port" =~ ^[0-9]+$ && "$api_port" -ge 1 && "$api_port" -le 65535 ]] \
    || die "profile API port must be an integer from 1 to 65535"
  runtime_parent=${IBKR_IBC_RUNTIME_PARENT:-${XDG_RUNTIME_DIR:-/tmp}}
  [[ -d "$runtime_parent" ]] || die "IBC runtime parent does not exist: $runtime_parent"

  username=$(safe-op read "$username_ref" --no-newline)
  password=$(safe-op read "$password_ref" --no-newline)
  [[ "$username" != *$'\n'* && "$username" != *$'\r'* ]] || die "username contains a line break"
  [[ "$password" != *$'\n'* && "$password" != *$'\r'* ]] || die "password contains a line break"
  [[ "$second_factor_device" != *$'\n'* && "$second_factor_device" != *$'\r'* ]] \
    || die "second-factor device contains a line break"
  if [[ -n "$auto_restart_time" ]]; then
    [[ "$auto_restart_time" =~ ^(0[1-9]|1[0-2]):[0-5][0-9]\ (AM|PM)$ ]] \
      || die "--auto-restart-time must use HH:MM AM/PM format"
  fi
  runtime_dir=$(mktemp -d "$runtime_parent/ibkr-ibc.XXXXXX")
  trap '[[ -z "${runtime_dir:-}" ]] || rm -rf -- "$runtime_dir"' EXIT
  chmod 700 "$runtime_dir"
  config_path="$runtime_dir/ibc.ini"
  umask 077
  {
    printf 'IbLoginId=%s\n' "$username"
    printf 'IbPassword=%s\n' "$password"
    printf 'TradingMode=%s\n' "$mode"
    printf 'ReadOnlyApi=%s\n' "$read_only_api"
    printf 'OverrideTwsApiPort=%s\n' "$api_port"
    if [[ "$read_only_login" == "1" ]]; then
      printf 'ReadOnlyLogin=yes\n'
    fi
    if [[ -n "$second_factor_device" ]]; then
      printf 'SecondFactorDevice=%s\n' "$second_factor_device"
    fi
    if [[ -n "$auto_restart_time" ]]; then
      printf 'AutoRestartTime=%s\n' "$auto_restart_time"
    fi
    printf 'ReloginAfterSecondFactorAuthenticationTimeout=no\n'
    printf 'SecondFactorAuthenticationExitInterval=60\n'
    printf 'ExistingSessionDetectedAction=secondary\n'
    printf 'AcceptIncomingConnectionAction=reject\n'
  } > "$config_path"
  username=""
  password=""
  unset username password

  jq -n --arg config "$config_path" --arg runtime_dir "$runtime_dir" --arg read_only_login "$read_only_login" \
    '{config: $config, runtime_dir: $runtime_dir, read_only_login: ($read_only_login == "1"), note: "ephemeral IBC config written with mode 0600; delete runtime_dir after use"}'
  runtime_dir=""
  trap - EXIT
}

main() {
  local cmd=${1:-}
  [[ -n "$cmd" ]] || { usage; exit 2; }
  shift || true

  case "$cmd" in
    -h|--help|help)
      usage
      ;;
    config)
      cmd_config "$@"
      ;;
    doctor)
      parse_common "$@"; require_config
      run_ibkr_json "$profile" "$group" "$account" "$raw" doctor
      ;;
    connect)
      parse_common "$@"; require_config
      run_ibkr_json "$profile" "$group" "$account" "$raw" connect test
      ;;
    positions)
      parse_common "$@"; require_config
      run_ibkr_json "$profile" "$group" "$account" "$raw" positions "${remaining[@]}"
      ;;
    balances)
      parse_common "$@"; require_config
      run_ibkr_json "$profile" "$group" "$account" "$raw" account summary "${remaining[@]}"
      ;;
    executions)
      parse_common "$@"; require_config
      run_ibkr_json "$profile" "$group" "$account" "$raw" orders executions "${remaining[@]}"
      ;;
    flex-trades)
      parse_common "$@"; require_config
      run_flex_json "$profile" "$group" "$account" "$raw" trades "${remaining[@]}"
      ;;
    transfers)
      parse_common "$@"; require_config
      run_flex_json "$profile" "$group" "$account" "$raw" transfers "${remaining[@]}"
      ;;
    dividends)
      parse_common "$@"; require_config
      run_flex_json "$profile" "$group" "$account" "$raw" dividends "${remaining[@]}"
      ;;
    order-preview)
      parse_common "$@"; require_config
      set -- "${remaining[@]}"
      safe_args "$@"
      local side=${1:-}
      [[ "$side" == "buy" || "$side" == "sell" ]] || die "order-preview requires buy or sell"
      shift
      local -a order_args
      order_args=("$side" "$@" --preview)
      if [[ -n "$account" ]]; then
        order_args+=(--account "$account")
      fi
      run_ibkr_json "$profile" "$group" "$account" "$raw" "${order_args[@]}"
      ;;
    gateway)
      cmd_gateway "$@"
      ;;
    ibc-config)
      cmd_ibc_config "$@"
      ;;
    *)
      die "unknown command: $cmd"
      ;;
  esac
}

main "$@"
