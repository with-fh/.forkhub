#!/bin/sh
# Sign the finished AppImage, including electron-builder's embedded block map.
set -eu

dist=${1:?path to the release staging directory required}
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
public_key="$here/forkhub-linux-release-key.asc"

set -- "$dist"/*-linux-*-unsigned.AppImage
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "Expected exactly one staged Linux AppImage to sign" >&2
  exit 1
fi
unsigned=$1
appimage=${unsigned%-unsigned.AppImage}.AppImage
old_name=$(basename "$unsigned")
new_name=$(basename "$appimage")
manifest="$dist/latest-linux.yml"

# Renaming leaves the artifact bytes and embedded block map unchanged.
# Require both updater references before rewriting the manifest and its alias.
grep -Fxq "  - url: $old_name" "$manifest"
grep -Fxq "path: $old_name" "$manifest"
digest=$(openssl dgst -sha512 -binary "$unsigned" | openssl base64 -A)
grep -Fxq "    sha512: $digest" "$manifest"
grep -Fxq "sha512: $digest" "$manifest"
awk -v old="$old_name" -v new="$new_name" '
  $0 == "  - url: " old { $0 = "  - url: " new }
  $0 == "path: " old { $0 = "path: " new }
  { print }
' "$manifest" > "$manifest.signed"

check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
fingerprint=$(gpg --batch --with-colons --show-keys "$public_key" | awk -F: '$1 == "fpr" { print $10; exit }')
test -n "$fingerprint"
gpg --batch --armor --local-user "$fingerprint" --output "$check_dir/signature.asc" --detach-sign "$unsigned"
gpg --batch --dearmor --output "$check_dir/release-key.gpg" "$public_key"
gpgv --keyring "$check_dir/release-key.gpg" "$check_dir/signature.asc" "$unsigned"

if [ -f "$unsigned.blockmap" ]; then
  mv "$unsigned.blockmap" "$appimage.blockmap"
fi
mv "$unsigned" "$appimage"
mv "$check_dir/signature.asc" "$appimage.asc"
cp "$public_key" "$dist/forkhub-linux-release-key.asc"
mv "$manifest.signed" "$manifest"
cp "$manifest" "$dist/fh-linux.yml"
