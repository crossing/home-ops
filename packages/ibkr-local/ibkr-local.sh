#!/usr/bin/env bash
set -euo pipefail

readonly APP_NAME="ibkr-local"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
local_config_dir="${IBKR_LOCAL_CONFIG_DIR:-$config_home/ibkr-local}"
profiles_json="${IBKR_LOCAL_PROFILES:-$local_config_dir/profiles.json}"
ibkr_xdg_home="${IBKR_LOCAL_XDG_CONFIG_HOME:-$local_config_dir}"

usage() {
  cat <<'USAGE'
Usage: ibkr-local <command> [options]

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
  tws                      Launch TWS for a local profile
  automation-smoke         Prove Xvfb can see/control a Java window
  ibc-config               Render ephemeral IBC config from safe-op secret refs

Examples:
  ibkr-local positions --profile main-paper --group isa
  ibkr-local balances --profile main-live --account U1234567
  ibkr-local order-preview buy AAPL 1 --profile main-paper --limit 100 --json
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
        die "live order mutation is blocked in v1; use ibkr-local order-preview for what-if only"
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
  if ! output=$(XDG_CONFIG_HOME="$ibkr_xdg_home" ibkr "$@" --profile "$ib_profile" --json); then
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
  if ! output=$(XDG_CONFIG_HOME="$ibkr_xdg_home" ibkr "$@" --json); then
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

cmd_tws() {
  parse_common "$@"
  set -- "${remaining[@]}"
  require_config

  local tws_dir jts_dir log_dir
  tws_dir=$(profile_string "$profile" "twsDir" "$HOME/.local/share/ibkr/$profile/tws")
  jts_dir=$(profile_string "$profile" "jtsConfigDir" "$HOME/.config/ibkr-local/jts/$profile")
  log_dir=$(profile_string "$profile" "logDir" "$state_home/ibkr-local/$profile")

  mkdir -p "$tws_dir" "$jts_dir" "$log_dir"
  TWS_DIR="$tws_dir" CONFIG_DIR="$jts_dir" TWS_LOG_DIR="$log_dir" exec tws "$@"
}

cmd_automation_smoke() {
  local workdir screenshot
  mkdir -p "$state_home/ibkr-local/smoke"
  workdir=$(mktemp -d "$state_home/ibkr-local/smoke/java.XXXXXX")
  screenshot="$workdir/java-smoke.png"

  cat > "$workdir/IbkrSmoke.java" <<'JAVA'
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.SwingUtilities;

public class IbkrSmoke {
  public static void main(String[] args) throws Exception {
    SwingUtilities.invokeAndWait(() -> {
      JFrame frame = new JFrame("ibkr-local-java-smoke");
      frame.add(new JLabel("ibkr-local automation smoke"));
      frame.setSize(420, 160);
      frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
      frame.setVisible(true);
    });
    Thread.sleep(15000);
  }
}
JAVA

  javac "$workdir/IbkrSmoke.java"
  # shellcheck disable=SC2016
  xvfb-run -a --server-args="-screen 0 1280x800x24" bash -euo pipefail -c '
    java -cp "$1" IbkrSmoke &
    pid=$!
    trap "kill $pid 2>/dev/null || true" EXIT
    for _ in $(seq 1 50); do
      if xdotool search --name ibkr-local-java-smoke >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done
    window=$(xdotool search --name ibkr-local-java-smoke | head -n 1)
    test -n "$window"
    wmctrl -ia "$window"
    import -window root "$2"
  ' smoke "$workdir" "$screenshot"

  jq -n --arg screenshot "$screenshot" '{ok: true, screenshot: $screenshot}'
}

cmd_ibc_config() {
  require_config
  local profile="" username_ref="" password_ref="" username_item="" username_field="" username_vault="" password_item="" password_field="" password_vault="" trading_mode=""
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
  runtime_parent=${IBKR_IBC_RUNTIME_PARENT:-${XDG_RUNTIME_DIR:-/tmp}}
  [[ -d "$runtime_parent" ]] || die "IBC runtime parent does not exist: $runtime_parent"

  username=$(safe-op read "$username_ref" --no-newline)
  password=$(safe-op read "$password_ref" --no-newline)
  runtime_dir=$(mktemp -d "$runtime_parent/ibkr-ibc.XXXXXX")
  chmod 700 "$runtime_dir"
  config_path="$runtime_dir/ibc.ini"
  umask 077
  {
    printf 'IbLoginId=%s\n' "$username"
    printf 'IbPassword=%s\n' "$password"
    printf 'TradingMode=%s\n' "$mode"
    printf 'ReadOnlyApi=yes\n'
    printf 'AcceptIncomingConnectionAction=accept\n'
  } > "$config_path"
  username=""
  password=""
  unset username password

  jq -n --arg config "$config_path" --arg runtime_dir "$runtime_dir" \
    '{config: $config, runtime_dir: $runtime_dir, note: "ephemeral IBC config written with mode 0600; delete runtime_dir after use"}'
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
    tws)
      cmd_tws "$@"
      ;;
    automation-smoke)
      cmd_automation_smoke "$@"
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
