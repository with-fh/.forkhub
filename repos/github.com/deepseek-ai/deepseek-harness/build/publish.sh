#!/bin/sh
# Updater-channel publish hook for the ForkHub DeepSeek Harness channel.
# Runs in the shared workflow's publish phase with GH_TOKEN, TARGET, DIST,
# UPSTREAM_TAG and GITHUB_REPOSITORY set. Publishes dist artifacts carrying
# electron-updater manifests to the `v<version>` release in this catalog
# repo — that release is the feed the patched app polls (see
# apps/desktop/src/updateFeed.ts: the fork channel is `github`, so the app
# resolves `latest-mac.yml` / `latest.yml` per platform).
#
# Multi-OS: every leg (mac/win) uploads its own platform files into the
# SAME updater release (create-or-upload with --clobber; filenames are
# disjoint per platform, so parallel legs never clobber each other):
#   mac    dmg + zip + latest-mac.yml + fh-mac.yml + blockmaps
#   win    exe (nsis portable-equivalent unsigned) + latest.yml + fh.yml + blockmaps
set -eu

DIST="${DIST:?}"
REPO="${GITHUB_REPOSITORY:?}"
TAG="${UPSTREAM_TAG:?}"
# build.sh exports FORKHUB_VERSION (<base>.<owner>.<date>.<n>); fall back
# to the bare upstream version when publishing by hand.
if [ -n "${FORKHUB_VERSION:-}" ]; then
  VER="$FORKHUB_VERSION"
else
  VER=$(printf '%s' "$TAG" | sed 's/^[dD][sS][hH]-//; s/^[vV]//')
fi

# Updater manifests per platform — publish when this leg produced ANY of
# them (a leg only ever carries its own OS files).
HAVE_MAC=""
HAVE_WIN=""
[ -n "$(ls "$DIST"/latest-mac.yml 2>/dev/null)" ] && HAVE_MAC="1" || true
[ -n "$(ls "$DIST"/latest.yml 2>/dev/null)" ] && HAVE_WIN="1" || true
if [ -z "$HAVE_MAC$HAVE_WIN" ]; then
  echo "no updater manifest (latest-mac.yml / latest.yml) in dist; skipping updater publish"
  exit 0
fi

# NOTE: filenames may contain spaces (Windows portable exe is
# "<product> <version>.exe"), so the file list uses positional params —
# never a flat string (word-splitting would break it).
set --
if [ -n "$HAVE_MAC" ]; then
  for f in "$DIST"/*.dmg "$DIST"/*.zip "$DIST"/latest-mac.yml "$DIST"/fh-mac.yml "$DIST"/*.blockmap; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      *.blockmap)
        base=$(basename "$f" .blockmap)
        [ -e "$DIST/$base" ] || continue
        ;;
    esac
    set -- "$@" "$f"
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
    set -- "$@" "$f"
  done
fi
[ "$#" -gt 0 ] || { echo "no uploadable updater files; skipping"; exit 0; }

# Create the release WITHOUT files first: asset uploads right after a
# release create can 404 on fresh tags. Parallel legs race safely
# (view-or-create + --clobber; filenames are disjoint per platform).
if gh release view "v$VER" --repo "$REPO" >/dev/null 2>&1; then
  echo "updater release v$VER already exists; uploading into it"
else
  if ! gh release create "v$VER" --repo "$REPO" --title "DeepSeek Harness ForkHub v$VER" --notes "ForkHub (patched) build of \`github.com/deepseek-ai/deepseek-harness\` $TAG (all platforms publish into this release). The matching deepseek-ai-deepseek-harness-$TAG-fh* release carries the full bundle notes."; then
    echo "lost a race with a parallel run that created it first — proceeding to upload"
  fi
  gh release view "v$VER" --repo "$REPO" >/dev/null 2>&1 || { echo "updater release v$VER still missing; skipping"; exit 0; }
fi

# Upload with retries: fresh releases can 404 asset uploads for a short
# window, and large installers occasionally drop mid-upload.
ok=""
for attempt in 1 2 3; do
  if gh release upload "v$VER" "$@" --repo "$REPO" --clobber; then
    ok="1"
    break
  fi
  echo "upload of updater files failed (attempt $attempt/3); waiting before retry"
  sleep 10
done
[ "$ok" = "1" ] || { echo "upload of updater files failed after 3 attempts"; exit 1; }
echo "updater release v$VER updated"
