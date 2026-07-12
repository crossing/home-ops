#!/usr/bin/env bash
set -uo pipefail

if (($# == 0)); then
  echo "usage: ibkr-gateway-ensure-live PROFILE..." >&2
  exit 2
fi

failed=0
for profile in "$@"; do
  if [[ ! "$profile" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    printf '%s: invalid profile name\n' "$profile" >&2
    failed=1
    continue
  fi

  service="ibkr-gateway-$profile.service"
  helper="ibkr-gateway-reauth-$profile"

  if systemctl --user -q is-active "$service"; then
    printf '%s: already active\n' "$profile" >&2
    continue
  fi

  if ! command -v "$helper" >/dev/null 2>&1; then
    printf '%s: missing reauthentication helper\n' "$profile" >&2
    failed=1
    continue
  fi

  if ! "$helper"; then
    printf '%s: reauthentication failed\n' "$profile" >&2
    failed=1
  fi

  if systemctl --user -q is-active "$service"; then
    printf '%s: active\n' "$profile" >&2
  else
    printf '%s: inactive after start attempt\n' "$profile" >&2
    failed=1
  fi
done

exit "$failed"
