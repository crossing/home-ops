#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
module=$script_dir/default.nix
cli=$script_dir/../../../packages/ibkr-local/ibkr-local.sh

grep -Fq 'TrustedIPs=127.0.0.1' "$module"
grep -Fq "printf 'AcceptIncomingConnectionAction=reject\\n'" "$cli"

printf 'PASS: Gateway API trusts localhost only and rejects other prompts\n'
