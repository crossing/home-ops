#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

LATEST_TAG=$(curl -sL https://api.github.com/repos/fatwang2/ibkr-cli/releases/latest | jq -r .tag_name)
VERSION=${LATEST_TAG#v}

echo "Updating ibkr-cli to ${LATEST_TAG}..."

COMMIT_HASH=$(curl -sL "https://api.github.com/repos/fatwang2/ibkr-cli/releases/tags/${LATEST_TAG}" | jq -r '.target_commitish // .tag_name')

if [[ ! "$COMMIT_HASH" =~ ^[a-f0-9]{40}$ ]]; then
  COMMIT_HASH=$(git ls-remote https://github.com/fatwang2/ibkr-cli | grep "refs/tags/${LATEST_TAG}" | cut -f1)
fi

echo "Commit: ${COMMIT_HASH}"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

curl -sL "https://raw.githubusercontent.com/fatwang2/ibkr-cli/${COMMIT_HASH}/pyproject.toml" -o "$TMPDIR/pyproject.toml"

cd "$TMPDIR"
uv lock --project pyproject.toml
mv uv.lock "$OLDPWD/uv.lock"
cd "$OLDPWD"

ARCHIVE_URL="https://github.com/fatwang2/ibkr-cli/archive/${COMMIT_HASH}.tar.gz"
echo "Prefetching source hash from ${ARCHIVE_URL}..."

NAR_HASH=$(nix-prefetch-url --unpack --print-path "$ARCHIVE_URL" 2>/dev/null | head -1)

SRI_HASH="sha256-$(nix hash to-base64 --type sha256 "$NAR_HASH")"

cat > metadata.json <<EOF
{
  "version": "${VERSION}",
  "owner": "fatwang2",
  "repo": "ibkr-cli",
  "rev": "${COMMIT_HASH}",
  "narHash": "${SRI_HASH}"
}
EOF

echo "Updated ibkr-cli to ${VERSION}"
echo "Commit: ${COMMIT_HASH}"
echo "narHash: ${SRI_HASH}"