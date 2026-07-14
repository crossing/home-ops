#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 VERSION OFFICIAL_INSTALLER_URL" >&2
  exit 64
fi

version=$1
url=$2
case "$url" in
  https://fw-download.ubnt.com/data/unifi-os-server/*-linux-x64-"$version"-*-x64) ;;
  *)
    echo "unexpected Ubiquiti installer URL: $url" >&2
    exit 65
    ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
installer="${TMPDIR:-/tmp}/unifi-os-server-$version-x64"
curl -fL -C - --retry 3 -o "$installer" "$url"
chmod +x "$installer"

hash=$(nix hash file --type sha256 --sri "$installer")
echo "version=$version"
echo "url=$url"
echo "hash=$hash"

mapfile -t eocd_offsets < <(LC_ALL=C grep -aob $'PK\005\006' "$installer" | cut -d: -f1)
echo "zip_eocd_candidates=${#eocd_offsets[@]}"
payload=
for eocd in "${eocd_offsets[@]}"; do
  entries=$(od -An -j $((eocd + 10)) -N 2 -tu2 "$installer" | tr -d ' ')
  [[ "$entries" == 9 ]] || continue
  cd_size=$(od -An -j $((eocd + 12)) -N 4 -tu4 "$installer" | tr -d ' ')
  cd_offset=$(od -An -j $((eocd + 16)) -N 4 -tu4 "$installer" | tr -d ' ')
  archive_start=$((eocd - cd_size - cd_offset))
  archive_size=$((eocd + 22 - archive_start))
  ((archive_start >= 0)) || continue
  candidate="$work/payload-$archive_start.zip"
  dd if="$installer" of="$candidate" bs=1M iflag=skip_bytes,count_bytes \
    skip="$archive_start" count="$archive_size" status=none
  if unzip -t "$candidate" image.tar >/dev/null 2>&1; then
    payload=$candidate
    break
  fi
done

if [[ -z "$payload" ]]; then
  echo "could not locate installer payload containing image.tar" >&2
  exit 66
fi
echo "payload=$payload"

unzip -q "$payload" image.tar -d "$work"
chmod u+r "$work/image.tar"
mkdir "$work/oci" "$work/rootfs"
tar -xf "$work/image.tar" -C "$work/oci"

manifest_digest=$(jq -r '.manifests[0].digest | sub("^sha256:"; "")' "$work/oci/index.json")
image_reference=$(jq -er '.manifests[0].annotations["io.containerd.image.name"]' "$work/oci/index.json")
image_id=$(
  jq -er '.config.digest | sub("^sha256:"; "")' \
    "$work/oci/blobs/sha256/$manifest_digest"
)
case "$image_reference" in
  docker.io/library/uosserver:*) ;;
  *) echo "unexpected OCI image reference: $image_reference" >&2; exit 67 ;;
esac
[[ "$image_id" =~ ^[0-9a-f]{64}$ ]] || {
  echo "unexpected OCI image ID: $image_id" >&2
  exit 68
}
echo "manifest_digest=$manifest_digest"
echo "image_reference=$image_reference"
echo "image_id=$image_id"
while read -r layer; do
  tar -xf "$work/oci/blobs/sha256/$layer" -C "$work/rootfs"
done < <(
  jq -r '.layers[].digest | sub("^sha256:"; "")' \
    "$work/oci/blobs/sha256/$manifest_digest"
)

mongod="$work/rootfs/usr/bin/mongod"
loader=$(find "$work/rootfs/lib/x86_64-linux-gnu" -maxdepth 1 -type f -name 'ld-*.so' -print -quit)
libs="$work/rootfs/lib/x86_64-linux-gnu:$work/rootfs/usr/lib/x86_64-linux-gnu"
test -x "$mongod"
test -n "$loader"
echo "mongod=$mongod"
echo "loader=$loader"
qemu-x86_64 -cpu Westmere "$loader" --library-path "$libs" "$mongod" --version

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
jq -n \
  --arg version "$version" \
  --arg url "$url" \
  --arg hash "$hash" \
  --arg imageReference "$image_reference" \
  --arg imageId "$image_id" \
  '{
    version: $version,
    url: $url,
    hash: $hash,
    imageReference: $imageReference,
    imageId: $imageId
  }' >"$script_dir/source.json"
