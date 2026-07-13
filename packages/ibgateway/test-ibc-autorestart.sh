#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /path/to/ibcstart.sh" >&2
  exit 2
fi

ibcstart=$1
if [ ! -f "$ibcstart" ]; then
  echo "IBC start script not found: $ibcstart" >&2
  exit 2
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

settings=$tmp/Jts
mkdir -p "$settings/session"
: > "$settings/session/autorestart"

function_file=$tmp/find-auto-restart.sh
awk '
  /^function find_auto_restart \{$/ { capture = 1 }
  capture { print }
  capture && /^}$/ { exit }
' "$ibcstart" > "$function_file"

if ! grep -q '^function find_auto_restart {$' "$function_file"; then
  echo "find_auto_restart was not found in $ibcstart" >&2
  exit 1
fi

runner=$tmp/runner.sh
{
  echo 'set -u'
  cat "$function_file"
  cat <<'RUNNER'
find() {
  "$find_bin" "$@"
}

autorestart_option=
restart_needed=
PATH=/path-intentionally-absent
find_auto_restart

if [[ "$autorestart_option" != " -Drestart=session" ]]; then
  echo "unexpected autorestart option" >&2
  exit 1
fi
if [[ "$restart_needed" != yes ]]; then
  echo "restart was not marked as needed" >&2
  exit 1
fi
RUNNER
} > "$runner"

FIND_BIN=$(command -v find)
FIND_BIN=$FIND_BIN SETTINGS=$settings bash -c '
  find_bin=$FIND_BIN
  tws_settings_path=$SETTINGS
  source "$1"
' bash "$runner"

echo "PASS: IBC autorestart parser uses Bash path handling"
