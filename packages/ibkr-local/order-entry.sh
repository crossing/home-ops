#!/usr/bin/env bash

order_policy_json() {
  local profile=$1
  jq -cer --arg profile "$profile" '
    .profiles[$profile] as $p
    | if $p == null then error("unknown profile") else $p end
    | {
        ibkrProfile: (.ibkrProfile // $profile),
        mode: (.mode // "paper"),
        orderEntry: {
          enable: (.orderEntry.enable // false),
          ticketTtlSeconds: (.orderEntry.ticketTtlSeconds // 120),
          allowedOrderTypes: (.orderEntry.allowedOrderTypes // ["LMT"]),
          allowOutsideRth: (.orderEntry.allowOutsideRth // false)
        }
      }
  ' "$profiles_json"
}

order_checksum() {
  jq -cS 'del(.checksum)' "$1" | sha256sum | cut -d' ' -f1
}

order_ticket_id() {
  od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
}

order_positive_number() {
  jq -en --arg value "$1" '$value | tonumber | . > 0' >/dev/null 2>&1
}

cmd_order_prepare() {
  require_config

  local side=${1:-} symbol=${2:-} quantity=${3:-}
  (($# >= 3)) || die "order-prepare requires buy|sell SYMBOL QUANTITY"
  shift 3

  [[ "$side" == "buy" || "$side" == "sell" ]] || die "order-prepare requires buy or sell"
  [[ -n "$symbol" ]] || die "order-prepare requires a symbol"
  order_positive_number "$quantity" || die "order quantity must be positive"

  local profile="" account="" order_type="LMT" limit_price=""
  local exchange="SMART" currency="USD" tif="DAY" outside_rth=0
  while (($#)); do
    case "$1" in
      -p|--profile)
        (($# >= 2)) || die "$1 requires a value"
        profile=$2
        shift 2
        ;;
      --account)
        (($# >= 2)) || die "$1 requires a value"
        account=$2
        shift 2
        ;;
      --type)
        (($# >= 2)) || die "$1 requires a value"
        order_type=$2
        shift 2
        ;;
      --limit)
        (($# >= 2)) || die "$1 requires a value"
        limit_price=$2
        shift 2
        ;;
      --exchange)
        (($# >= 2)) || die "$1 requires a value"
        exchange=$2
        shift 2
        ;;
      --currency)
        (($# >= 2)) || die "$1 requires a value"
        currency=$2
        shift 2
        ;;
      --tif)
        (($# >= 2)) || die "$1 requires a value"
        tif=$2
        shift 2
        ;;
      --outside-rth)
        outside_rth=1
        shift
        ;;
      --json)
        shift
        ;;
      *)
        die "unknown order-prepare option: $1"
        ;;
    esac
  done

  [[ -n "$profile" ]] || die "order-prepare requires explicit --profile"
  [[ -n "$account" ]] || die "order-prepare requires explicit --account"
  [[ "$order_type" == "LMT" ]] || die "guarded order entry currently permits only LMT orders"
  [[ "$tif" == "DAY" ]] || die "guarded order entry currently permits only DAY orders"
  [[ "$outside_rth" == "0" ]] || die "guarded order entry currently blocks outside-RTH orders"
  [[ -n "$limit_price" ]] || die "LMT orders require --limit"
  order_positive_number "$limit_price" || die "limit price must be positive"

  local policy
  if ! policy=$(order_policy_json "$profile"); then
    die "unknown profile: $profile"
  fi
  [[ "$(jq -r '.orderEntry.enable' <<<"$policy")" == "true" ]] \
    || die "order entry is disabled for profile: $profile"
  jq -e --arg order_type "$order_type" '.orderEntry.allowedOrderTypes | index($order_type) != null' \
    <<<"$policy" >/dev/null || die "order type is not enabled for profile: $profile"

  local ibkr_profile mode ttl preview preview_output
  ibkr_profile=$(jq -r '.ibkrProfile' <<<"$policy")
  mode=$(jq -r '.mode' <<<"$policy")
  ttl=$(jq -r '.orderEntry.ticketTtlSeconds' <<<"$policy")

  if ! preview_output=$(
    XDG_CONFIG_HOME="$ibkr_xdg_home" "$IBKR_UPSTREAM" \
      "$side" "$symbol" "$quantity" \
      --profile "$ibkr_profile" --account "$account" \
      --exchange "$exchange" --currency "$currency" \
      --type "$order_type" --limit "$limit_price" --tif "$tif" \
      --preview --json
  ); then
    printf '%s\n' "$preview_output" >&2
    return 1
  fi

  preview=$(order_response_json "$preview_output")
  [[ "$preview" != "null" ]] || die "IBKR preview returned invalid JSON"

  jq -e --arg account "$account" '
    .preview_only == true and .selected_account == $account
  ' <<<"$preview" >/dev/null \
    || die "IBKR preview did not confirm the requested account"

  local ticket_root prepared_dir claimed_dir ticket_id created_at expires_at
  local tmp final_tmp checksum ticket
  ticket_root="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/ibkr-local/order-tickets"
  prepared_dir="$ticket_root/prepared"
  claimed_dir="$ticket_root/claimed"
  umask 077
  mkdir -p "$prepared_dir" "$claimed_dir"
  chmod 700 "$ticket_root" "$prepared_dir" "$claimed_dir"

  ticket_id=$(order_ticket_id)
  created_at=$(date +%s)
  expires_at=$((created_at + ttl))
  ticket="$prepared_dir/$ticket_id.json"
  tmp=$(mktemp "$prepared_dir/.ticket.XXXXXX")
  final_tmp=$(mktemp "$prepared_dir/.ticket-final.XXXXXX")

  jq -n \
    --argjson schema_version 1 \
    --arg ticket_id "$ticket_id" \
    --argjson created_at "$created_at" \
    --argjson expires_at "$expires_at" \
    --arg profile "$profile" \
    --arg ibkr_profile "$ibkr_profile" \
    --arg mode "$mode" \
    --arg account "$account" \
    --arg action "${side^^}" \
    --arg symbol "$symbol" \
    --arg quantity "$quantity" \
    --arg exchange "$exchange" \
    --arg currency "$currency" \
    --arg order_type "$order_type" \
    --arg limit_price "$limit_price" \
    --arg tif "$tif" \
    --argjson preview "$preview" '
      {
        schemaVersion: $schema_version,
        ticketId: $ticket_id,
        createdAt: $created_at,
        expiresAt: $expires_at,
        profile: $profile,
        ibkrProfile: $ibkr_profile,
        mode: $mode,
        account: $account,
        order: {
          action: $action,
          symbol: $symbol,
          quantity: ($quantity | tonumber),
          exchange: $exchange,
          currency: $currency,
          orderType: $order_type,
          limitPrice: ($limit_price | tonumber),
          tif: $tif,
          outsideRth: false
        },
        contract: {
          symbol: $preview.symbol,
          localSymbol: $preview.local_symbol,
          exchange: $preview.exchange,
          primaryExchange: $preview.primary_exchange,
          currency: $preview.currency,
          secType: $preview.sec_type,
          conId: $preview.con_id
        },
        preview: {
          previewOnly: $preview.preview_only,
          status: $preview.status,
          commission: $preview.commission,
          minCommission: $preview.min_commission,
          maxCommission: $preview.max_commission,
          commissionCurrency: $preview.commission_currency,
          initMarginChange: $preview.init_margin_change,
          maintMarginChange: $preview.maint_margin_change,
          equityWithLoanChange: $preview.equity_with_loan_change,
          warningText: $preview.warning_text,
          rawErrorCodes: ($preview.raw_error_codes // [])
        }
      }
    ' >"$tmp"

  checksum=$(order_checksum "$tmp")
  jq --arg checksum "$checksum" '. + {checksum: $checksum}' "$tmp" >"$final_tmp"
  chmod 600 "$final_tmp"
  mv "$final_tmp" "$ticket"
  rm -f "$tmp"
  cat "$ticket"
}

order_write_audit() {
  local path=$1 state=$2 response=$3 exit_status=$4
  local tmp="$path.tmp.$$" updated_at
  updated_at=$(date +%s)
  jq \
    --arg state "$state" \
    --argjson response "$response" \
    --argjson exit_status "$exit_status" \
    --argjson updated_at "$updated_at" '
      . + {
        state: $state,
        updatedAt: $updated_at,
        brokerExitStatus: $exit_status,
        brokerResponse: $response
      }
    ' "$path" >"$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$path"
}

order_response_json() {
  local output=$1
  local payload
  payload=$(awk 'found || /^[[:space:]]*\{/ { found=1; print }' <<<"$output")
  if jq -e 'type == "object"' <<<"$payload" >/dev/null 2>&1; then
    jq -c . <<<"$payload"
  else
    printf 'null\n'
  fi
}

order_finish_mutation() {
  local audit=$1 exit_status=$2 output=$3 operation=$4
  local response state
  response=$(order_response_json "$output")

  if [[ "$exit_status" == "0" && "$response" != "null" ]]; then
    state="submitted"
  elif [[ "$exit_status" != "0" && "$response" != "null" ]]; then
    state="rejected"
  else
    state="attempted-unknown"
  fi

  order_write_audit "$audit" "$state" "$response" "$exit_status"
  if [[ "$state" == "submitted" ]]; then
    cat "$audit"
    return 0
  fi

  if [[ "$state" == "rejected" ]]; then
    printf '%s: broker rejected %s; inspect %s\n' "$APP_NAME" "$operation" "$audit" >&2
  else
    printf '%s: %s result is unknown; inspect orders before retrying; audit: %s\n' \
      "$APP_NAME" "$operation" "$audit" >&2
  fi
  return 1
}

order_validate_ticket() {
  local ticket=$1 ticket_id=$2 confirm=$3
  local checksum expected now profile policy

  [[ "$confirm" == "$ticket_id" ]] || die "order-submit confirmation must match the ticket id"
  [[ -f "$ticket" && ! -L "$ticket" ]] || die "prepared order ticket not found: $ticket_id"
  jq -e --arg ticket_id "$ticket_id" '
    .schemaVersion == 1
    and .ticketId == $ticket_id
    and (.profile | type == "string" and length > 0)
    and (.ibkrProfile | type == "string" and length > 0)
    and (.account | type == "string" and length > 0)
    and (.order.action == "BUY" or .order.action == "SELL")
    and .order.orderType == "LMT"
    and .order.tif == "DAY"
    and .order.outsideRth == false
    and (.order.quantity | type == "number" and . > 0)
    and (.order.limitPrice | type == "number" and . > 0)
  ' "$ticket" >/dev/null || die "prepared order ticket is malformed"

  checksum=$(jq -er '.checksum' "$ticket")
  expected=$(order_checksum "$ticket")
  [[ "$checksum" == "$expected" ]] || die "prepared order ticket checksum mismatch"

  now=$(date +%s)
  [[ "$(jq -r '.expiresAt' "$ticket")" -ge "$now" ]] || die "prepared order ticket has expired"

  profile=$(jq -r '.profile' "$ticket")
  if ! policy=$(order_policy_json "$profile"); then
    die "unknown profile in prepared order ticket: $profile"
  fi
  [[ "$(jq -r '.orderEntry.enable' <<<"$policy")" == "true" ]] \
    || die "order entry is disabled for profile: $profile"
  jq -e --arg order_type "$(jq -r '.order.orderType' "$ticket")" '
    .orderEntry.allowedOrderTypes | index($order_type) != null
  ' <<<"$policy" >/dev/null || die "ticket order type is no longer enabled"
  [[ "$(jq -r '.ibkrProfile' <<<"$policy")" == "$(jq -r '.ibkrProfile' "$ticket")" ]] \
    || die "ticket upstream profile no longer matches configuration"
  [[ "$(jq -r '.mode' <<<"$policy")" == "$(jq -r '.mode' "$ticket")" ]] \
    || die "ticket trading mode no longer matches configuration"
}

cmd_order_submit() {
  require_config

  local ticket_id=${1:-} confirm=""
  [[ "$ticket_id" =~ ^[0-9a-f]{32}$ ]] || die "order-submit requires a valid ticket id"
  shift
  while (($#)); do
    case "$1" in
      --confirm)
        (($# >= 2)) || die "$1 requires a value"
        confirm=$2
        shift 2
        ;;
      --json)
        shift
        ;;
      *)
        die "unknown order-submit option: $1"
        ;;
    esac
  done

  local ticket_root prepared claimed audit_dir audit tmp
  ticket_root="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/ibkr-local/order-tickets"
  prepared="$ticket_root/prepared/$ticket_id.json"
  claimed="$ticket_root/claimed/$ticket_id.json"
  order_validate_ticket "$prepared" "$ticket_id" "$confirm"

  mkdir -p "$ticket_root/claimed"
  chmod 700 "$ticket_root" "$ticket_root/claimed"
  if ! mv "$prepared" "$claimed" 2>/dev/null; then
    die "prepared order ticket was already consumed: $ticket_id"
  fi

  audit_dir="${state_home}/ibkr-local/orders"
  umask 077
  mkdir -p "$audit_dir"
  chmod 700 "${state_home}/ibkr-local" "$audit_dir"
  audit="$audit_dir/$ticket_id.json"
  tmp=$(mktemp "$audit_dir/.audit.XXXXXX")
  jq --argjson updated_at "$(date +%s)" \
    '. + {state: "submitting", updatedAt: $updated_at, brokerResponse: null}' \
    "$claimed" >"$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$audit"

  local action symbol quantity ibkr_profile account exchange currency order_type limit_price tif
  action=$(jq -r '.order.action | ascii_downcase' "$claimed")
  symbol=$(jq -r '.order.symbol' "$claimed")
  quantity=$(jq -r '.order.quantity' "$claimed")
  ibkr_profile=$(jq -r '.ibkrProfile' "$claimed")
  account=$(jq -r '.account' "$claimed")
  exchange=$(jq -r '.order.exchange' "$claimed")
  currency=$(jq -r '.order.currency' "$claimed")
  order_type=$(jq -r '.order.orderType' "$claimed")
  limit_price=$(jq -r '.order.limitPrice' "$claimed")
  tif=$(jq -r '.order.tif' "$claimed")

  local output exit_status
  set +e
  output=$(
    XDG_CONFIG_HOME="$ibkr_xdg_home" "$IBKR_UPSTREAM" \
      "$action" "$symbol" "$quantity" \
      --profile "$ibkr_profile" --account "$account" \
      --exchange "$exchange" --currency "$currency" \
      --type "$order_type" --limit "$limit_price" --tif "$tif" \
      --submit --json 2>&1
  )
  exit_status=$?
  set -e

  order_finish_mutation "$audit" "$exit_status" "$output" "order submission"
}

cmd_order_cancel() {
  require_config

  local order_id=${1:-} profile="" account="" confirm=""
  [[ "$order_id" =~ ^[0-9]+$ ]] || die "order-cancel requires a numeric order id"
  shift
  while (($#)); do
    case "$1" in
      -p|--profile)
        (($# >= 2)) || die "$1 requires a value"
        profile=$2
        shift 2
        ;;
      --account)
        (($# >= 2)) || die "$1 requires a value"
        account=$2
        shift 2
        ;;
      --confirm)
        (($# >= 2)) || die "$1 requires a value"
        confirm=$2
        shift 2
        ;;
      --json)
        shift
        ;;
      *)
        die "unknown order-cancel option: $1"
        ;;
    esac
  done

  [[ -n "$profile" ]] || die "order-cancel requires explicit --profile"
  [[ -n "$account" ]] || die "order-cancel requires explicit --account"
  [[ "$confirm" == "$order_id" ]] || die "order-cancel confirmation must match the order id"

  local policy ibkr_profile audit_id audit_dir audit tmp created_at
  if ! policy=$(order_policy_json "$profile"); then
    die "unknown profile: $profile"
  fi
  [[ "$(jq -r '.orderEntry.enable' <<<"$policy")" == "true" ]] \
    || die "order entry is disabled for profile: $profile"
  ibkr_profile=$(jq -r '.ibkrProfile' <<<"$policy")

  audit_id="cancel-$(order_ticket_id)"
  audit_dir="${state_home}/ibkr-local/orders"
  umask 077
  mkdir -p "$audit_dir"
  chmod 700 "${state_home}/ibkr-local" "$audit_dir"
  audit="$audit_dir/$audit_id.json"
  tmp=$(mktemp "$audit_dir/.audit.XXXXXX")
  created_at=$(date +%s)
  jq -n \
    --argjson schema_version 1 \
    --arg audit_id "$audit_id" \
    --argjson created_at "$created_at" \
    --arg profile "$profile" \
    --arg ibkr_profile "$ibkr_profile" \
    --arg account "$account" \
    --arg order_id "$order_id" '
      {
        schemaVersion: $schema_version,
        auditId: $audit_id,
        createdAt: $created_at,
        updatedAt: $created_at,
        state: "submitting",
        profile: $profile,
        ibkrProfile: $ibkr_profile,
        account: $account,
        cancellation: {orderId: ($order_id | tonumber)},
        brokerResponse: null
      }
    ' >"$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$audit"

  local output exit_status
  set +e
  output=$(
    XDG_CONFIG_HOME="$ibkr_xdg_home" "$IBKR_UPSTREAM" \
      orders cancel "$order_id" \
      --profile "$ibkr_profile" --account "$account" --json 2>&1
  )
  exit_status=$?
  set -e

  order_finish_mutation "$audit" "$exit_status" "$output" "order cancellation"
}
