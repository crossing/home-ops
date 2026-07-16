#!/usr/bin/env bash
set -euo pipefail

flake=${1:-.}
json=$(nix eval --json "$flake#homeConfigurations.\"xing@desktop\".config.programs.ibkrLocal.profiles")

jq -e '."main-paper".orderEntry == {
  enable: true,
  ticketTtlSeconds: 120,
  allowedOrderTypes: ["LMT"],
  allowOutsideRth: false
}' <<<"$json" >/dev/null
jq -e '."main-live".orderEntry.enable == false' <<<"$json" >/dev/null
jq -e '."pension-live".orderEntry.enable == false' <<<"$json" >/dev/null

printf 'PASS: paper order entry enabled while live profiles fail closed\n'
