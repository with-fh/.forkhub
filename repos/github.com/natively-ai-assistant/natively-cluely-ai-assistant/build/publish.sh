#!/bin/sh
# Updater-channel publish hook for the ForkHub Natively channel.
# Runs in the shared workflow's publish phase with GH_TOKEN, TARGET, DIST,
# UPSTREAM_TAG and GITHUB_REPOSITORY set. Publishes dist artifacts carrying
# electron-updater manifests to the `v<version>` release in this catalog
# repo — that release is the feed the patched app polls (see
# electron/update/updateFeed.ts). The fork version `-fh.<owner>.<n>` is a
# semver prerelease whose channel (`fh`) is what the updater matches on the
# shared catalog atom feed, skipping every other target's releases.
# The shared step separately publishes the namespaced *-fhN bundle (which
# also carries the .deb).
#
# Multi-OS: every leg (linux/mac/win) uploads its own platform files into
# the SAME updater release (create-or-upload with --clobber; filenames are
# disjoint per platform, so parallel legs never clobber each other):
#   linux  AppImage + latest-linux.yml + fh-linux.yml + blockmaps
#   mac    dmg + zip + latest-mac.yml + fh-mac.yml + blockmaps
#   win    exe (nsis + portable) + latest.yml + fh.yml + blockmaps
set -eu

DIST="${DIST:?}"
REPO="${GITHUB_REPOSITORY:?}"
TAG="${UPSTREAM_TAG:?}"
# build.sh exports FORKHUB_VERSION (<upstream>-fh.<owner>.<n>); fall back to
# the bare upstream version when publishing by hand.
if [ -n "${FORKHUB_VERSION:-}" ]; then
  VER="$FORKHUB_VERSION"
else
  VER=$(printf '%s' "$TAG" | sed 's/^v//')
fi

case "$VER" in
  *-beta* | *-alpha* | *-rc* | *-preview* | *-pr.*)
    echo "not a shippable stable tag ($VER); skipping updater publish"
    exit 0
    ;;
esac

# Updater manifests per platform — publish when this leg produced ANY of
# them (a leg only ever carries its own OS files).
HAVE_LINUX=""
HAVE_MAC=""
HAVE_WIN=""
[ -n "$(ls "$DIST"/latest-linux.yml 2>/dev/null)" ] && HAVE_LINUX="1" || true
[ -n "$(ls "$DIST"/latest-mac.yml 2>/dev/null)" ] && HAVE_MAC="1" || true
[ -n "$(ls "$DIST"/latest.yml 2>/dev/null)" ] && HAVE_WIN="1" || true
if [ -z "$HAVE_LINUX$HAVE_MAC$HAVE_WIN" ]; then
  echo "no updater manifest (latest-linux.yml / latest-mac.yml / latest.yml) in dist; skipping updater publish"
  exit 0
fi

FILES=""
if [ -n "$HAVE_LINUX" ]; then
  for f in "$DIST"/*.AppImage "$DIST"/latest-linux.yml "$DIST"/fh-linux.yml "$DIST"/*.blockmap; do
    [ -e "$f" ] || continue
    # Blockmaps are shared-name space across legs (*.blockmap): only take
    # the ones belonging to this leg's installers (same basename prefix).
    case "$(basename "$f")" in
      *.blockmap)
        base=$(basename "$f" .blockmap)
        [ -e "$DIST/$base" ] || continue
        ;;
    esac
    FILES="$FILES $f"
  done
fi
if [ -n "$HAVE_MAC" ]; then
  for f in "$DIST"/*.dmg "$DIST"/*.zip "$DIST"/latest-mac.yml "$DIST"/fh-mac.yml "$DIST"/*.blockmap; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      *.blockmap)
        base=$(basename "$f" .blockmap)
        [ -e "$DIST/$base" ] || continue
        ;;
    esac
    FILES="$FILES $f"
  done
fi
if [ -n "$HAVE_WIN" ]; then
  for f in "$DIST"/*.exe "$DIST"/latest.yml "$DIST"/fh.yml "$DIST"/*.blockmap; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      *.blockmap)
        base=$(basename "$f" .blockmap)
        [ -e "$DIST/$base" ] || continue
        ;;
    esac
    FILES="$FILES $f"
  done
fi
[ -n "$FILES" ] || { echo "no uploadable updater files; skipping"; exit 0; }

# Create the release WITHOUT files first: asset uploads right after a
# create can 404 while GitHub propagates the release object, and parallel
# matrix runs may race on the same tag — both are handled below.
if gh release view "v$VER" --repo "$REPO" >/dev/null 2>&1; then
  echo "updater release v$VER already exists; uploading into it"
else
  echo "creating updater release v$VER"
  if ! gh release create "v$VER" --repo "$REPO" --title "Natively ForkHub v$VER" --notes "ForkHub (patched) build of upstream natively-ai-assistant/natively-cluely-ai-assistant $TAG (all platforms publish into this release). The matching natively-ai-assistant-natively-cluely-ai-assistant-$TAG-fh* release carries the full bundle notes."; then
    # Lost a race with a parallel run that created it first — proceed to upload.
    echo "create failed; re-checking for v$VER"
    sleep 10
    gh release view "v$VER" --repo "$REPO" >/dev/null 2>&1 || { echo "updater release v$VER still missing; skipping"; exit 0; }
  fi
fi

# Upload with retries: fresh releases can 404 asset uploads for a short
# window, and large installers occasionally drop mid-upload.
# shellcheck disable=SC2086
for f in $FILES; do
  ok=0
  for attempt in 1 2 3; do
    if gh release upload "v$VER" "$f" --repo "$REPO" --clobber; then
      ok=1
      break
    fi
    echo "upload of $(basename "$f") failed (attempt $attempt/3); waiting before retry"
    sleep $((attempt * 15))
  done
  [ "$ok" = "1" ] || { echo "upload of $(basename "$f") failed after 3 attempts"; exit 1; }
done
echo "updater release v$VER published"
