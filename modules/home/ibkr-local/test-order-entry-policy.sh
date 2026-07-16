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
jq -e '."main-live".orderEntry.enable == true' <<<"$json" >/dev/null
jq -e '."pension-live".orderEntry.enable == true' <<<"$json" >/dev/null

printf 'PASS: guarded order entry enabled for paper and live profiles\n'
