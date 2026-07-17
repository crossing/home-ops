#!/usr/bin/env bash
set -euo pipefail

flake=${1:-.}
json=$(nix eval --json "$flake#homeConfigurations.\"xing@desktop\".config.systemd.user.services")

jq -e '
  .["ibkr-gateway-main-live"].Unit["X-SwitchMethod"] == "keep-old" and
  .["ibkr-gateway-pension-live"].Unit["X-SwitchMethod"] == "keep-old"
' <<<"$json" >/dev/null

printf 'PASS: IBKR Gateway services keep their active definition during Home Manager switches\n'
