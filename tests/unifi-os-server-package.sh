#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_json="$repo_root/packages/unifi-os-server/source.json"
work=$(mktemp -d)
trap 'status=$?; rm -rf "$work"; exit "$status"' EXIT

out=$(nix build --no-link --print-out-paths "$repo_root#unifi-os-server")
image="$out/share/unifi-os-server/image.tar"
test -r "$image"

tar -xf "$image" -C "$work" index.json blobs
manifest_digest=$(jq -er '.manifests[0].digest | sub("^sha256:"; "")' "$work/index.json")
image_reference=$(jq -er '.manifests[0].annotations["io.containerd.image.name"]' "$work/index.json")
image_id=$(
  jq -er '.config.digest | sub("^sha256:"; "")' \
    "$work/blobs/sha256/$manifest_digest"
)

test "$image_reference" = "$(jq -er .imageReference "$source_json")"
test "$image_id" = "$(jq -er .imageId "$source_json")"
test "$image" = "$(nix eval --raw "$repo_root#unifi-os-server.image")"
test "$image_reference" = "$(nix eval --raw "$repo_root#unifi-os-server.imageReference")"
test "$image_id" = "$(nix eval --raw "$repo_root#unifi-os-server.imageId")"
