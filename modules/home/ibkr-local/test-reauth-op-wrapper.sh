#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
module=$script_dir/default.nix

grep -q 'op_bin=/run/wrappers/bin/op' "$module"
grep -Fq '[[ -x "$op_bin" ]]' "$module"
grep -Fq 'export PATH="/run/wrappers/bin:$PATH"' "$module"

printf 'PASS: Gateway reauthentication pins the NixOS op wrapper\n'
