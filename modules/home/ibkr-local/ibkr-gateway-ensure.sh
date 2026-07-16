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
if command -v ibkr >/dev/null 2>&1; then
  ibkr_cli=ibkr
elif command -v ibkr-local >/dev/null 2>&1; then
  ibkr_cli=ibkr-local
else
  echo "ibkr: command not found (ibkr-local compatibility command also unavailable)" >&2
  exit 1
fi

print_auth_diagnostics() {
  local profile=$1 service=$2
  printf '%s: Gateway may be waiting for headless Second Factor Authentication\n' "$profile" >&2
  printf '%s: diagnose service: systemctl --user status %s\n' "$profile" "$service" >&2
  printf "%s: diagnose authentication: journalctl --user -u %s --since '-10 min'\n" \
    "$profile" "$service" >&2
  printf '%s: if Gateway shows Notification sent but no phone prompt arrives, select Log in with Challenge/Response; in IBKR Mobile use Services -> Authenticate and submit the generated response\n' \
    "$profile" >&2
  printf '%s: do not restart while a challenge is pending; review the bootstrap-ibkr-gateway skill and this coordinator after IB Gateway or IBC upgrades\n' \
    "$profile" >&2
}

wait_until_ready() {
  local profile=$1 service=$2 deadline diagnosed=0
  deadline=$((SECONDS + ready_timeout))

  while true; do
    if "$ibkr_cli" connect --profile "$profile" >/dev/null 2>&1; then
      return 0
    fi
    if ((diagnosed == 0)); then
      print_auth_diagnostics "$profile" "$service"
      diagnosed=1
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
  started_here=0

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
    started_here=1

    if systemctl --user -q is-active "$service"; then
      printf '%s: active\n' "$profile" >&2
    else
      printf '%s: inactive after start attempt\n' "$profile" >&2
      exit 1
    fi
  fi

  printf '%s: waiting for API readiness\n' "$profile" >&2
  if wait_until_ready "$profile" "$service"; then
    printf '%s: API ready\n' "$profile" >&2
  else
    printf '%s: API readiness timed out after %s seconds\n' "$profile" "$ready_timeout" >&2
    if ((started_here)); then
      printf '%s: stopping service started by this coordinator\n' "$profile" >&2
      if ! systemctl --user stop "$service"; then
        printf '%s: failed to stop unready service\n' "$profile" >&2
        exit 1
      fi
      if systemctl --user -q is-active "$service"; then
        printf '%s: service remained active after cleanup\n' "$profile" >&2
        exit 1
      fi
    fi
    exit 1
  fi
done
