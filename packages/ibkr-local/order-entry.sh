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

  local ibkr_profile mode ttl preview
  ibkr_profile=$(jq -r '.ibkrProfile' <<<"$policy")
  mode=$(jq -r '.mode' <<<"$policy")
  ttl=$(jq -r '.orderEntry.ticketTtlSeconds' <<<"$policy")

  if ! preview=$(
    XDG_CONFIG_HOME="$ibkr_xdg_home" "$IBKR_UPSTREAM" \
      "$side" "$symbol" "$quantity" \
      --profile "$ibkr_profile" --account "$account" \
      --exchange "$exchange" --currency "$currency" \
      --type "$order_type" --limit "$limit_price" --tif "$tif" \
      --preview --json
  ); then
    printf '%s\n' "$preview" >&2
    return 1
  fi

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
