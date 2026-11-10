#!/bin/sh
# Repo-native multi-OS build for the ForkHub DeepSeek Harness Desktop channel.
# Runs with cwd = patched upstream checkout. Best-effort: always exits 0;
# the shared workflow falls back to a patched-source tarball when dist/
# stays empty. See BUILD.md.
#
# One workflow leg per OS (see upstream.json:build_runs_on): each leg packs
# its NATIVE installers and uploads them into the SAME shared updater +
# bundle releases (per-OS skip markers make legs resume independently;
# FORKHUB_OS_MARKER reuse keeps one release number).
#
# Fork version form (see BUILD.md + updateFeed.ts): DSH's build validator
# only accepts versions extending the product prerelease in native
# `<base>.<date>.<n>` form, so fork builds ride
# `<base>.<owner>.<date>.<n>` (e.g. `0.2.2-rc.1.with-fh.20261110.1`).
# UPSTREAM_TAG arrives as `dsh-v0.2.2-rc.1`; the `dsh-v` prefix is
# normalized away before numbering.
#
# The shared builder image only guarantees bun (+ node/pnpm on GHA
# runners). This target brings its own toolchain (node 24 + pnpm 11 to
# match the monorepo engines, no native-module compilation beyond what
# pnpm postinstall already does).
set -eu

DIST="${GITHUB_WORKSPACE:?}/dist"
REPO="${GITHUB_REPOSITORY:?}"
TAG="${UPSTREAM_TAG:?}"
LOG="$DIST/BUILD_LOG.md"
# OS leg identity from the shared workflow (mac|win). Hand-runs default
# to the host platform's leg.
OS_KEY="${FORKHUB_OS_KEY:-mac}"
OS_MARKER="${FORKHUB_OS_MARKER:-}"

say() {
  printf '%s\n' "$*" | tee -a "$LOG"
}

fail_soft() {
  say "BUILD-SOFT-FAIL: $*"
  rm -rf "$DIST/forkhub" 2>/dev/null || true
  tar --exclude=./node_modules --exclude=./dist --exclude=./.git \
    --exclude=./apps/desktop/.desktop-build --exclude=./apps/desktop/dist \
    -czf "$DIST/deepseek-ai-deepseek-harness-patched-source.tar.gz" . 2>/dev/null \
    && say "patched-source tarball packed" \
    || say "source tarball packing failed; bundle will carry the build log only"
  say "Continuing so the bundle release still publishes."
  exit 0
}

# Upstream tags are dsh-vX.Y.Z-* prereleases (zero desktop binaries
# upstream). Accept any dsh-v tag; the tag_match_pattern already gates
# the pool. A future stable tag flows through unchanged.
case "$TAG" in
  dsh-v* | v*)
    ;;
  *)
    fail_soft "UPSTREAM_TAG=$TAG is not a shippable Desktop tag; refusing to cut a ForkHub release from it."
    ;;
esac

# ForkHub provenance version: <base>.<owner>.<date>.<n>, e.g.
# 0.2.2-rc.1.with-fh.20261110.1. The `dsh-v` prefix is normalized away;
# the owner rides in from the catalog repo (lowercased); DATE is the
# UTC build date; n counts existing updater releases for this base+date
# so force-rebuilds advance.
SUFFIX="${FORKHUB_VERSION_SUFFIX:-fh}"
case "$SUFFIX" in
  "" | *[!a-z0-9-]*)
    fail_soft "bad FORKHUB_VERSION_SUFFIX '$SUFFIX'"
    ;;
esac
OWNER=$(printf '%s' "$REPO" | cut -d/ -f1 | tr '[:upper:]' '[:lower:]')
# Strip leading dsh-v (case-insensitive) or bare v: dsh-v0.2.2-rc.1 -> 0.2.2-rc.1.
BASE=$(printf '%s' "$TAG" | sed 's/^[dD][sS][hH]-//; s/^[vV]//')
DATE=$(date -u +%Y%m%d)
ESCAPED_BASE=$(printf '%s' "$BASE" | sed 's/\./\\./g')
EXISTING_TAGS=$(gh api "repos/$REPO/releases?per_page=100" --jq '.[].tag_name' 2>/dev/null) \
  || fail_soft "could not list releases to number the ForkHub build (gh api failed)"
N=$(printf '%s\n' "$EXISTING_TAGS" | grep -cE "^v${ESCAPED_BASE}\\.${OWNER}\\.${DATE}\\.[0-9]+\$" || true)
FH_VERSION="${BASE}.${OWNER}.${DATE}.$((N + 1))"
# Multi-OS resume: reuse the newest incomplete release number so all OS
# legs converge on ONE updater release per upstream tag.
if [ "${FORKHUB_NEXT_REVISION:-}" = "1" ] || [ "${FORKHUB_NEXT_REVISION:-}" = "true" ]; then
  say "next-revision requested: keeping fresh number $FH_VERSION (leaving prior releases untouched)"
elif [ -n "$OS_MARKER" ] && [ -n "${FORKHUB_ALL_MARKERS:-}" ]; then
  NEWEST=$(printf '%s\n' "$EXISTING_TAGS" | grep -E "^v${ESCAPED_BASE}\\.${OWNER}\\.${DATE}\\.[0-9]+\$" | sed -E 's/^.*\.([0-9]+)$/\1 &/' | sort -n | tail -1 | sed -E 's/^[0-9]+ //' || true)
  if [ -n "$NEWEST" ]; then
    ASSETS=$(gh release view "$NEWEST" --repo "$REPO" --json assets --jq '.assets[].name' 2>/dev/null || true)
    COMPLETE=1
    for pair in $FORKHUB_ALL_MARKERS; do
      m=${pair#*:}
      [ -n "$m" ] || continue
      MARKER_RX=$(printf '%s' "$m" | sed 's/\./\\./g; s/\*/.*/g')
      printf '%s\n' "$ASSETS" | grep -qE "^${MARKER_RX}\$" || COMPLETE=0
    done
    if [ "$COMPLETE" = "1" ]; then
      say "newest $NEWEST is complete on all platforms; numbering past it"
    else
      FH_VERSION=$(printf '%s' "$NEWEST" | sed 's/^v//')
      say "reusing incomplete $NEWEST for $OS_KEY artifacts (as $FH_VERSION)"
    fi
  fi
fi
echo "FORKHUB_VERSION=$FH_VERSION" >> "${GITHUB_ENV:?}"
say "# ForkHub build [$OS_KEY]: github.com/deepseek-ai/deepseek-harness @ $TAG (as $FH_VERSION)"

# --- toolchain: node 24 + pnpm 11 (matches monorepo engines) ---
HAVE_NODE=$(node --version 2>/dev/null | sed 's/^v//') || HAVE_NODE=""
if [ "${HAVE_NODE%%.*}" = "24" ] || [ "${HAVE_NODE%%.*}" = "26" ]; then
  say "node $HAVE_NODE ok"
else
  say "node ${HAVE_NODE:-missing} unsuitable; fetching latest node 24"
  command -v curl >/dev/null 2>&1 || fail_soft "no curl to fetch node"
  command -v jq >/dev/null 2>&1 || fail_soft "no jq to resolve node version"
  NODE_TAG=$(curl -fsSL https://nodejs.org/download/release/index.json | jq -r '[.[].version | select(startswith("v24."))][0]')
  [ -n "$NODE_TAG" ] && [ "$NODE_TAG" != "null" ] || fail_soft "could not resolve latest node 24"
  UNAME_S=$(uname -s)
  UNAME_M=$(uname -m)
  case "$UNAME_S" in
    Linux*) NODE_PLAT="linux"; NODE_EXT="tar.xz" ;;
    Darwin*) NODE_PLAT="darwin"; NODE_EXT="tar.gz" ;;
    MINGW*|MSYS*|CYGWIN*) NODE_PLAT="win"; NODE_EXT="zip" ;;
    *) fail_soft "unsupported builder OS for node provisioning: $UNAME_S" ;;
  esac
  case "$UNAME_M" in
    x86_64|amd64) NODE_ARCH="x64" ;;
    arm64|aarch64) NODE_ARCH="arm64" ;;
    *) fail_soft "unsupported builder arch for node provisioning: $UNAME_M" ;;
  esac
  NODE_DIR="${RUNNER_TEMP:-/tmp}/forkhub-node24"
  mkdir -p "$NODE_DIR"
  curl -fsSL "https://nodejs.org/download/release/$NODE_TAG/node-$NODE_TAG-$NODE_PLAT-$NODE_ARCH.$NODE_EXT" \
    -o "$NODE_DIR/node-pkg.$NODE_EXT" || fail_soft "node 24 download failed"
  tar -xf "$NODE_DIR/node-pkg.$NODE_EXT" -C "$NODE_DIR" || fail_soft "node 24 extract failed"
  export PATH="$NODE_DIR/node-$NODE_TAG-$NODE_PLAT-$NODE_ARCH/bin:$NODE_DIR/node-$NODE_TAG-$NODE_PLAT-$NODE_ARCH:$PATH"
  say "node $(node --version) provisioned"
fi
if command -v pnpm >/dev/null 2>&1; then
  say "pnpm $(pnpm --version) ok"
else
  say "installing pnpm 11"
  npm install -g pnpm@11 >>"$LOG" 2>&1 || fail_soft "pnpm install failed"
fi

# --- deps (lockfile-pinned) ---
say "pnpm install"
pnpm install --frozen-lockfile >>"$LOG" 2>&1 || fail_soft "pnpm install failed (see BUILD_LOG.md)"

# --- verify gate (focused suites only — full CI stays upstream's job) ---
say "verify gate"
sh repos/github.com/deepseek-ai/deepseek-harness/patches/dsh-forkhub-support-0qjj6stm/verify.sh >>"$LOG" 2>&1 \
  || fail_soft "verify gate failed (see BUILD_LOG.md)"

# --- stamp the ForkHub provenance version + catalog owner ---
# The version extends the product prerelease in native <base>.<date>.<n>
# form with the owner folded in (see BUILD.md) — the build validator
# accepts it because the product prerelease still prefixes the owner.
say "stamping version $FH_VERSION + owner $OWNER"
export DSH_UPDATE_OWNER="$OWNER"
export DSH_DESKTOP_BUILD_VERSION="$FH_VERSION"

# --- pack the unsigned installer for this leg ---
# Unsigned (no certs in this catalog): mac needs no Developer ID action
# (the stock pack path just works unsigned for local builds via
# --unsigned). Gatekeeper (right-click → Open) and SmartScreen warnings
# apply, documented in CONSUME.md.
case "$OS_KEY" in
  mac)
    say "packaging mac unsigned (arm64 + x64)"
    (cd apps/desktop && pnpm run package:mac:arm64:unsigned -- --build-version "$FH_VERSION" >>"$LOG" 2>&1) \
      || fail_soft "mac arm64 pack failed (see BUILD_LOG.md)"
    (cd apps/desktop && pnpm run package:mac:x64:unsigned -- --build-version "$FH_VERSION" >>"$LOG" 2>&1) \
      || fail_soft "mac x64 pack failed (see BUILD_LOG.md)"
    ;;
  win)
    say "packaging win unsigned (x64)"
    (cd apps/desktop && pnpm run package:win:x64:unsigned -- --build-version "$FH_VERSION" >>"$LOG" 2>&1) \
      || fail_soft "win x64 pack failed (see BUILD_LOG.md)"
    ;;
  *)
    fail_soft "unknown OS leg: $OS_KEY (expected mac|win; linux ships downstream from ImBIOS)"
    ;;
esac

# --- collect updater-relevant artifacts ---
# electron-builder emits per-target updater manifests under
# apps/desktop/.desktop-build/targets/<target>/unsigned-artifacts (mac:
# latest-mac.yml, win: latest.yml) alongside the installers. The ForkHub
# channel twins each stock name (fh-mac.yml / fh.yml) — the manifests
# resolve per platform and carry the stamped ForkHub version.
mkdir -p "$DIST/forkhub"
MOVED=0
for target in mac-arm64 mac-x64 win-x64; do
  ART="apps/desktop/.desktop-build/targets/$target/unsigned-artifacts"
  [ -d "$ART" ] || continue
  for f in "$ART"/*.dmg "$ART"/*.zip "$ART"/*.exe "$ART"/latest-mac.yml "$ART"/latest.yml; do
    [ -e "$f" ] || continue
    mv "$f" "$DIST/forkhub"/
    MOVED=$((MOVED + 1))
  done
  for f in "$ART"/*.blockmap; do
    [ -e "$f" ] || continue
    mv "$f" "$DIST/forkhub"/
    MOVED=$((MOVED + 1))
  done
done
[ "$MOVED" -gt 0 ] || fail_soft "pack produced no artifacts in unsigned-artifacts/"
if [ -e "$DIST/forkhub/latest-mac.yml" ]; then
  cp "$DIST/forkhub/latest-mac.yml" "$DIST/forkhub/fh-mac.yml" || fail_soft "fh-mac.yml copy failed"
  say "fh-mac.yml emitted"
fi
if [ -e "$DIST/forkhub/latest.yml" ]; then
  cp "$DIST/forkhub/latest.yml" "$DIST/forkhub/fh.yml" || fail_soft "fh.yml copy failed"
  say "fh.yml emitted"
fi
# The updater feed resolves the manifests per platform: each emitted pair
# must exist and must carry the stamped ForkHub version.
for yml in latest-mac.yml fh-mac.yml latest.yml fh.yml; do
  [ -e "$DIST/forkhub/$yml" ] || continue
  grep -q "version: $FH_VERSION" "$DIST/forkhub/$yml" 2>/dev/null \
    || fail_soft "$yml missing or version mismatch (expected $FH_VERSION)"
done
for f in "$DIST"/forkhub/*; do
  [ -e "$f" ] || continue
  mv "$f" "$DIST"/
done
rm -rf "$DIST/forkhub" 2>/dev/null || true
say "artifacts moved to dist"
ls "$DIST" | tee -a "$LOG"
