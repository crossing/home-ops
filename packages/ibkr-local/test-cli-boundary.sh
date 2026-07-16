#!/usr/bin/env bash
set -euo pipefail

package=${1:?usage: test-cli-boundary.sh PACKAGE_PATH}
primary="$package/bin/ibkr"
compat="$package/bin/ibkr-local"

[[ -x "$primary" ]]
[[ -x "$compat" ]]
[[ "$(readlink -f "$compat")" == "$(readlink -f "$primary")" ]]
"$primary" --help | grep -q '^Usage: ibkr '
cmp <("$primary" --help) <("$compat" --help)

if find "$package/bin" -maxdepth 1 -type l -lname '*ibkr-cli*' | grep -q .; then
  echo 'FAIL: unrestricted upstream ibkr is exposed' >&2
  exit 1
fi

printf 'PASS: guarded ibkr is primary and ibkr-local is compatible\n'
