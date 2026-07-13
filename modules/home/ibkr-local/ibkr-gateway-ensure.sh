#!/usr/bin/env bash
set -uo pipefail

if (($# == 0)); then
  echo "usage: ibkr-gateway-ensure-live PROFILE..." >&2
  exit 2
fi

ready_timeout=${IBKR_GATEWAY_READY_TIMEOUT:-600}
ready_interval=${IBKR_GATEWAY_READY_INTERVAL:-2}

if [[ ! "$ready_timeout" =~ ^[1-9][0-9]*$ ]]; then
  echo "IBKR_GATEWAY_READY_TIMEOUT must be a positive integer" >&2
  exit 2
fi
if [[ ! "$ready_interval" =~ ^[1-9][0-9]*$ ]]; then
  echo "IBKR_GATEWAY_READY_INTERVAL must be a positive integer" >&2
  exit 2
fi
if ! command -v ibkr-local >/dev/null 2>&1; then
  echo "ibkr-local: command not found" >&2
  exit 1
fi

wait_until_ready() {
  local profile=$1 deadline
  deadline=$((SECONDS + ready_timeout))

  while true; do
    if ibkr-local connect --profile "$profile" >/dev/null 2>&1; then
      return 0
    fi
    if ((SECONDS >= deadline)); then
      return 1
    fi
    sleep "$ready_interval"
  done
}

for profile in "$@"; do
  if [[ ! "$profile" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    printf '%s: invalid profile name\n' "$profile" >&2
    exit 1
  fi

  service="ibkr-gateway-$profile.service"
  helper="ibkr-gateway-reauth-$profile"

  if systemctl --user -q is-active "$service"; then
    printf '%s: already active\n' "$profile" >&2
  else
    if ! command -v "$helper" >/dev/null 2>&1; then
      printf '%s: missing reauthentication helper\n' "$profile" >&2
      exit 1
    fi

    if ! "$helper"; then
      printf '%s: reauthentication failed\n' "$profile" >&2
      exit 1
    fi

    if systemctl --user -q is-active "$service"; then
      printf '%s: active\n' "$profile" >&2
    else
      printf '%s: inactive after start attempt\n' "$profile" >&2
      exit 1
    fi
  fi

  printf '%s: waiting for API readiness\n' "$profile" >&2
  if wait_until_ready "$profile"; then
    printf '%s: API ready\n' "$profile" >&2
  else
    printf '%s: API readiness timed out after %s seconds\n' "$profile" "$ready_timeout" >&2
    exit 1
  fi
done
