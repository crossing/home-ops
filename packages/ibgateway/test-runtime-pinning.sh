#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dockerfile=$script_dir/Dockerfile
package=$script_dir/default.nix
wrapper=$script_dir/wrapper.sh

grep -Eq '^FROM docker\.io/library/ubuntu@sha256:[0-9a-f]{64}$' "$dockerfile"
grep -q 'ibgatewayInstaller = pkgs.fetchurl' "$package"
grep -Eq 'IBGATEWAY_INSTALLER = ibgatewayInstaller;' "$package"
grep -q 'IBGATEWAY_INSTALLER="${IBGATEWAY_INSTALLER:?IBGATEWAY_INSTALLER is required}"' "$wrapper"
grep -Fq '$IBGATEWAY_INSTALLER:/tmp/$APP_ID-installer.sh:ro' "$wrapper"

if grep -q 'IBGATEWAY_INSTALL_URL' "$wrapper"; then
  echo 'FAIL: Gateway installer still comes from a mutable runtime URL' >&2
  exit 1
fi

printf 'PASS: Gateway image and installer inputs are pinned\n'
