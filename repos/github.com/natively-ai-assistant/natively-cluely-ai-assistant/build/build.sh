#!/bin/sh
# Repo-native multi-OS build for the ForkHub Natively channel.
# Runs with cwd = patched upstream checkout. Best-effort: always exits 0;
# the shared workflow falls back to a patched-source tarball when dist/
# stays empty. See BUILD.md.
#
# One workflow leg per OS (see upstream.json:build_runs_on): each leg packs
# its NATIVE installers — linux AppImage+deb, mac dmg+zip (arm64+x64,
# unsigned), win nsis+portable (x64) — and uploads them into the SAME
# shared updater + bundle releases (per-OS skip markers make legs resume
# independently; FORKHUB_OS_MARKER reuse keeps one release number).
#
# The shared builder image only guarantees bun (+ node/cargo on GHA
# runners). This target brings its own toolchain (node 22 to match
# upstream release-macos.yml, Rust stable for the native module, keytar
# system headers on linux) because the desktop build compiles native
# addons and packs installers.
set -eu

DIST="${GITHUB_WORKSPACE:?}/dist"
REPO="${GITHUB_REPOSITORY:?}"
TAG="${UPSTREAM_TAG:?}"
LOG="$DIST/BUILD_LOG.md"
# OS leg identity from the shared workflow (linux|mac|win). Hand-runs
# default to the host platform's leg.
OS_KEY="${FORKHUB_OS_KEY:-linux}"
OS_MARKER="${FORKHUB_OS_MARKER:-}"

say() {
  printf '%s\n' "$*" | tee -a "$LOG"
}

fail_soft() {
  say "BUILD-SOFT-FAIL: $*"
  # Never leave an empty staging dir behind: the shared checksum step
  # (`sha256sum *`) chokes on directories and would fail the whole job.
  rm -rf "$DIST/forkhub" 2>/dev/null || true
  # Still ship something useful: the verified patched source (the shared
  # fallback only fires on an empty dist, and BUILD_LOG.md already makes
  # it non-empty).
  tar --exclude=./node_modules --exclude=./dist --exclude=./.git --exclude=./release \
    -czf "$DIST/natively-ai-assistant-natively-cluely-ai-assistant-patched-source.tar.gz" . 2>/dev/null \
    && say "patched-source tarball packed" \
    || say "source tarball packing failed; bundle will carry the build log only"
  say "Continuing so the bundle release still publishes."
  exit 0
}

# Upstream tags are stable-only in practice, but old `-beta` tags exist and a
# future `-beta`/`-rc` cut must never ship as a ForkHub release.
case "$TAG" in
  *-beta* | *-alpha* | *-rc* | *-preview* | *-pr.*)
    fail_soft "UPSTREAM_TAG=$TAG is a pre-release train tag, not a shippable stable tag; refusing to cut a ForkHub release from it."
    ;;
esac

# ForkHub provenance version: <upstream>.fh.<owner>.<n>, e.g.
# 2.8.1.fh.imbios.1. The suffix rides in from upstream.json:version_suffix
# via FORKHUB_VERSION_SUFFIX; n counts existing updater releases for this
# base so force-rebuilds advance. The `-fh.<owner>.<n>` shape is what the
# in-app updater matches on the shared catalog atom feed (prerelease
# channel `fh`) and what isRealUpgrade/isForkCounterUpgrade order in-app.
SUFFIX="${FORKHUB_VERSION_SUFFIX:-fh}"
case "$SUFFIX" in
  "" | *[!a-z0-9-]*)
    fail_soft "bad FORKHUB_VERSION_SUFFIX '$SUFFIX'"
    ;;
esac
OWNER=$(printf '%s' "$REPO" | cut -d/ -f1 | tr '[:upper:]' '[:lower:]')
# Strip leading v case-insensitively: upstream tags both styles (v2.8.1,
# V2.8.8). A capital V inside the version would break semver parsing in
# electron-updater (atom channel match) and the in-app gates.
VER=$(printf '%s' "$TAG" | sed 's/^[vV]//')
ESCAPED_BASE=$(printf '%s' "$VER" | sed 's/\./\\./g')
EXISTING_TAGS=$(gh api "repos/$REPO/releases?per_page=100" --jq '.[].tag_name' 2>/dev/null) \
  || fail_soft "could not list releases to number the ForkHub build (gh api failed)"
N=$(printf '%s\n' "$EXISTING_TAGS" | grep -cE "^v${ESCAPED_BASE}[-.]${SUFFIX}\\.${OWNER}\\.[0-9]+\$" || true)
FH_VERSION="${VER}-${SUFFIX}.${OWNER}.$((N + 1))"
# Multi-OS resume: when this leg's marker asset is missing from the newest
# matching updater release, that release is OURS-but-incomplete (a sibling
# leg published first, or a retry) — reuse its number instead of bumping,
# so every OS ships under ONE updater release per upstream tag.
if [ -n "$OS_MARKER" ]; then
  MARKER_RX=$(printf '%s' "$OS_MARKER" | sed 's/\./\\./g; s/\*/.*/g')
  # Portable newest-pick (no `sort -V` on macOS): matching tags differ
  # only in the trailing .N counter — order by it.
  NEWEST=$(printf '%s\n' "$EXISTING_TAGS" | grep -E "^v${ESCAPED_BASE}[-.]${SUFFIX}\\.${OWNER}\\.[0-9]+\$" | sed -E 's/^.*\.([0-9]+)$/\1 &/' | sort -n | tail -1 | sed -E 's/^[0-9]+ //' || true)
  if [ -n "$NEWEST" ]; then
    if gh release view "$NEWEST" --repo "$REPO" --json assets --jq '.assets[].name' 2>/dev/null | grep -qE "^${MARKER_RX}\$"; then
      say "newest $NEWEST already carries $OS_KEY artifacts; numbering past it"
    else
      FH_VERSION=$(printf '%s' "$NEWEST" | sed 's/^v//')
      say "reusing incomplete $NEWEST for $OS_KEY artifacts (as $FH_VERSION)"
    fi
  fi
fi
echo "FORKHUB_VERSION=$FH_VERSION" >> "${GITHUB_ENV:?}"
say "# ForkHub build [$OS_KEY]: github.com/natively-ai-assistant/natively-cluely-ai-assistant @ $TAG (as $FH_VERSION)"

# ForkHub bundle counter: the in-app manual compare orders same-base
# rebuilds by bundle N (see updateFeed.ts isBundleCounterUpgrade), so the
# app must know which bundle build it is. N counts existing
# `<slug>--<tag>-fhN` bundle releases for this target+tag (FORKHUB_TARGET
# arrives from the shared workflow); this build ships as N+1. Same
# best-effort caveat as FORKHUB_VERSION above: a failed publish can skip
# a number; ordering stays monotonic regardless.
if [ -n "${FORKHUB_TARGET:-}" ]; then
  BUNDLE_SLUG=$(printf '%s' "$FORKHUB_TARGET" | awk -F/ '{print $(NF-1)"-"$NF}' | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')
  ESCAPED_TAG=$(printf '%s' "$TAG" | sed 's/\./\\./g')
  BUNDLE_EXISTING=$(printf '%s\n' "$EXISTING_TAGS" | grep -cE "^${BUNDLE_SLUG}--${ESCAPED_TAG}-fh[0-9]+\$" || true)
  BUNDLE_N=$((BUNDLE_EXISTING + 1))
  say "stamping bundle counter $BUNDLE_N"
  npm pkg set "build.extraMetadata.forkhubBundleN=$BUNDLE_N" >>"$LOG" 2>&1 \
    || fail_soft "bundle counter stamp failed"
else
  say "no FORKHUB_TARGET — bundle counter unstamped (manual compare falls back to version gates)"
fi

# --- toolchain: node 22 (matches upstream release-macos.yml) ---
HAVE_NODE=$(node --version 2>/dev/null | sed 's/^v//') || HAVE_NODE=""
if [ "${HAVE_NODE%%.*}" = "22" ]; then
  say "node $HAVE_NODE ok"
else
  say "node ${HAVE_NODE:-missing} unsuitable; fetching latest node 22"
  command -v curl >/dev/null 2>&1 || fail_soft "no curl to fetch node"
  command -v jq >/dev/null 2>&1 || fail_soft "no jq to resolve node version"
  NODE_TAG=$(curl -fsSL https://nodejs.org/download/release/index.json | jq -r '[.[].version | select(startswith("v22."))][0]')
  [ -n "$NODE_TAG" ] && [ "$NODE_TAG" != "null" ] || fail_soft "could not resolve latest node 22"
  UNAME_S=$(uname -s)
  UNAME_M=$(uname -m)
  case "$UNAME_S" in
    Linux*) NODE_PLAT="linux"; NODE_EXT="tar.xz" ;;
    Darwin*) NODE_PLAT="macos"; NODE_EXT="tar.gz" ;;
    MINGW*|MSYS*|CYGWIN*) NODE_PLAT="win"; NODE_EXT="zip" ;;
    *) fail_soft "unsupported builder OS for node provisioning: $UNAME_S" ;;
  esac
  case "$UNAME_M" in
    x86_64|amd64) NODE_ARCH="x64" ;;
    arm64|aarch64) NODE_ARCH="arm64" ;;
    *) fail_soft "unsupported builder arch for node provisioning: $UNAME_M" ;;
  esac
  NODE_DIR="${RUNNER_TEMP:-/tmp}/forkhub-node22"
  mkdir -p "$NODE_DIR"
  curl -fsSL "https://nodejs.org/download/release/$NODE_TAG/node-$NODE_TAG-$NODE_PLAT-$NODE_ARCH.$NODE_EXT" \
    -o "$NODE_DIR/node-pkg.$NODE_EXT" || fail_soft "node 22 download failed"
  tar -xf "$NODE_DIR/node-pkg.$NODE_EXT" -C "$NODE_DIR" || fail_soft "node 22 extract failed"
  export PATH="$NODE_DIR/node-$NODE_TAG-$NODE_PLAT-$NODE_ARCH/bin:$NODE_DIR/node-$NODE_TAG-$NODE_PLAT-$NODE_ARCH:$PATH"
  say "node $(node --version) provisioned"
fi

# --- toolchain: Rust stable (native-module via napi) ---
if command -v cargo >/dev/null 2>&1; then
  say "cargo $(cargo --version) ok"
else
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) fail_soft "no cargo on Windows runner (expected preinstalled)" ;;
  esac
  say "installing Rust stable via rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal >>"$LOG" 2>&1 \
    || fail_soft "rustup install failed"
  export PATH="$HOME/.cargo/bin:$PATH"
  say "cargo $(cargo --version) installed"
fi

# --- toolchain: native build headers (keytar links libsecret on Linux;
# cpal links ALSA for microphone/speaker capture) ---
# apt-get exists only on linux — mac (Xcode CLT) and win (VS Build Tools)
# runners already carry their native toolchains.
if command -v apt-get >/dev/null 2>&1; then
  say "installing native build prerequisites"
  sudo apt-get update >>"$LOG" 2>&1 || say "apt-get update failed; continuing"
  sudo apt-get install -y build-essential python3 pkg-config libsecret-1-dev libasound2-dev >>"$LOG" 2>&1 \
    || say "prerequisite install failed; the build will say if it mattered"
fi

# --- deps (lockfile-pinned). postinstall rebuilds sharp/native addons,
# verifies vendored models, and checks the native arch — same as local dev.
#
# onnxruntime-node is dev-only (electron-builder `files` excludes it from
# the packaged app), and its postinstall downloads a GPU NuGet package
# whose contents are broken for linux (it hunts a win-x64 CUDA lib and
# throws). Skip its native download; CPU inference is unaffected and the
# shipped app never contains it.
export ONNXRUNTIME_NODE_INSTALL=skip
export ONNXRUNTIME_NODE_INSTALL_CUDA=skip
say "npm ci"
npm ci >>"$LOG" 2>&1 || fail_soft "npm ci failed (see BUILD_LOG.md)"
export PATH="$PWD/node_modules/.bin:$PATH"

# --- stamp the ForkHub provenance version (app + updater manifests) ---
say "stamping version $FH_VERSION"
npm pkg set "version=$FH_VERSION" >>"$LOG" 2>&1 || fail_soft "version stamp failed"

# --- bake the fork's Google OAuth client id (calendar direct PKCE flow) ---
# NATIVELY_GOOGLE_CLIENT_ID is a PUBLIC identifier (ships in every build that
# has it). Absent: the FORK_DEFAULT_CLIENT_ID fallback in CalendarManager
# still applies to catalog builds. (CI can only see this var if the shared
# workflow forwards it; local fork releases set it directly. See
# build/BUILD.md.)
if [ -n "${NATIVELY_GOOGLE_CLIENT_ID:-}" ]; then
  say "baking fork Google client id"
  npm pkg set "build.extraMetadata.nativelyGoogleClientId=$NATIVELY_GOOGLE_CLIENT_ID" >>"$LOG" 2>&1 \
    || fail_soft "client id stamp failed"
else
  say "no NATIVELY_GOOGLE_CLIENT_ID — packaged builds fall back to the fork default client id"
fi

# --- bake the fork's Google OAuth client secret (calendar direct flow) ---
# Google requires client_secret at the token endpoint even for Desktop
# clients using PKCE (absent → 400 `invalid_request: client_secret is
# missing.`), and per Google's own native-app docs the secret is NOT
# treated as confidential here — but it is still never logged and never
# committed: it arrives only via env (CI secret or local shell) and is
# baked into the packaged app. Absent: calendar connect fails fast with a
# clear not-configured error instead of wasting a consent round-trip.
# (CI can only see this var if the shared workflow forwards it; the repo
# secret itself is added in GitHub Settings. See build/BUILD.md.)
if [ -n "${NATIVELY_GOOGLE_CLIENT_SECRET:-}" ]; then
  say "baking fork Google client secret (value never logged)"
  npm pkg set "build.extraMetadata.nativelyGoogleClientSecret=$NATIVELY_GOOGLE_CLIENT_SECRET" >>"$LOG" 2>&1 \
    || fail_soft "client secret stamp failed"
else
  say "no NATIVELY_GOOGLE_CLIENT_SECRET — calendar direct flow will report not-configured at connect time"
fi

# --- deb maintainer (electron-builder requires an author email for the
# deb control file; upstream leaves `author` empty and has no Linux CI).
# Fork-build identity only — the patch itself stays free of fork branding.
# Linux leg only.
if [ "$OS_KEY" = "linux" ]; then
  say "setting deb maintainer"
  npm pkg set "build.linux.maintainer=Natively ForkHub <forkhub@users.noreply.github.com>" >>"$LOG" 2>&1 \
    || fail_soft "maintainer stamp failed"
fi

# --- build (mirrors package.json app:build, per-OS subset) ---
say "vite build"
npm run build >>"$LOG" 2>&1 || fail_soft "vite build failed"
say "electron typecheck"
npm run typecheck:electron >>"$LOG" 2>&1 || fail_soft "electron typecheck failed"
say "electron bundle"
npm run build:electron >>"$LOG" 2>&1 || fail_soft "electron bundle failed"
# --- strip sourcemaps (1.26 GB in v2.9.2: esbuild emits one ~21 MB
# bundle + ~46 MB map PER electron entry point, all duplicated, plus
# renderer maps — dead weight in a shipped app with no devtools).
# Measured on the v2.9.2 AppImage: 1257 MB of *.map inside app.asar.
# Upstream ships them; the fork does not.
say "stripping sourcemaps"
find dist dist-electron -name '*.map' -delete >>"$LOG" 2>&1 || fail_soft "sourcemap strip failed"
if [ "$OS_KEY" = "mac" ]; then
  # Both darwin arches from one arm64 runner (mirrors upstream
  # release-macos.yml): the runner cross-builds the Intel package, and
  # both arch bindings for canvas must be present or the x64 pack ships
  # without PDF text extraction (the v2.8.7 lesson).
  say "native module (all mac arches)"
  NATIVELY_BUILD_ALL_MAC_ARCHES=1 npm run build:native >>"$LOG" 2>&1 || fail_soft "native module build failed"
  say "mac packaged deps"
  node scripts/ensure-sharp-mac-deps.js >>"$LOG" 2>&1 || say "ensure-sharp-mac-deps failed; continuing"
  node scripts/ensure-napi-canvas-mac-deps.js >>"$LOG" 2>&1 || say "ensure-napi-canvas-mac-deps failed; continuing"
  node scripts/ensure-sqlite-vec.js >>"$LOG" 2>&1 || say "ensure-sqlite-vec failed; continuing"
else
  say "native module"
  npm run build:native >>"$LOG" 2>&1 || fail_soft "native module build failed"
  say "sharp mac deps (no-op off mac)"
  node scripts/ensure-sharp-mac-deps.js >>"$LOG" 2>&1 || say "ensure-sharp-mac-deps failed; continuing ($OS_KEY)"
fi

# --- pack native installers for this leg ---
# mac is UNSIGNED (no Developer ID in this catalog — see BUILD.md): the
# default electron-builder config already sets identity null, so the stock
# pack path just works. win is unsigned too (SmartScreen will warn).
case "$OS_KEY" in
  linux)
    # The deb postinst hook arrives via git without the exec bit (patches are
    # text-only), so set it here where the mode doesn't matter how it arrived.
    chmod +x scripts/deb-after-install.sh 2>/dev/null || say "could not chmod deb hook; continuing"
    say "electron-builder (linux AppImage + deb)"
    ./node_modules/.bin/electron-builder --linux AppImage deb --publish never >>"$LOG" 2>&1 \
      || fail_soft "electron-builder failed (see BUILD_LOG.md)"
    ;;
  mac)
    say "electron-builder (mac dmg + zip, arm64 + x64)"
    ./node_modules/.bin/electron-builder --mac dmg zip --arm64 --x64 --publish never >>"$LOG" 2>&1 \
      || fail_soft "electron-builder failed (see BUILD_LOG.md)"
    ;;
  win)
    say "electron-builder (win nsis + portable)"
    ./node_modules/.bin/electron-builder --win nsis portable --publish never >>"$LOG" 2>&1 \
      || fail_soft "electron-builder failed (see BUILD_LOG.md)"
    ;;
  *)
    fail_soft "unknown OS leg: $OS_KEY (expected linux|mac|win)"
    ;;
esac

# --- collect updater-relevant artifacts ---
# ForkHub updater channel files: the app follows the `fh` update channel
# (see setupAutoUpdater), which electron-updater resolves per platform as
# `fh-linux.yml` / `fh-mac.yml` / `fh.yml` (win) — the stock names are
# never requested on this feed. Same content, second name
# (electron-builder only emits the stock name).
if [ -e release/latest-linux.yml ]; then
  cp release/latest-linux.yml release/fh-linux.yml || fail_soft "fh-linux.yml copy failed"
  say "fh-linux.yml emitted"
fi
if [ -e release/latest-mac.yml ]; then
  cp release/latest-mac.yml release/fh-mac.yml || fail_soft "fh-mac.yml copy failed"
  say "fh-mac.yml emitted"
fi
if [ -e release/latest.yml ] && [ "$OS_KEY" = "win" ]; then
  cp release/latest.yml release/fh.yml || fail_soft "fh.yml copy failed"
  say "fh.yml emitted"
fi
mkdir -p "$DIST/forkhub"
MOVED=0
case "$OS_KEY" in
  linux) PATTERNS="release/*.AppImage release/*.deb release/latest-linux.yml release/fh-linux.yml release/*.blockmap" ;;
  mac) PATTERNS="release/*.dmg release/*.zip release/latest-mac.yml release/fh-mac.yml release/*.blockmap" ;;
  win) PATTERNS="release/*.exe release/latest.yml release/fh.yml release/*.blockmap" ;;
esac
# shellcheck disable=SC2086
for f in $PATTERNS; do
  [ -e "$f" ] || continue
  mv "$f" "$DIST/forkhub"/
  MOVED=$((MOVED + 1))
done
[ "$MOVED" -gt 0 ] || fail_soft "electron-builder produced no artifacts in release/"
# The updater feed resolves the manifests per platform: each emitted pair
# must exist and must carry the stamped ForkHub version, or in-app updates
# can never fire on that OS.
for yml in latest-linux.yml fh-linux.yml latest-mac.yml fh-mac.yml latest.yml fh.yml; do
  [ -e "$DIST/forkhub/$yml" ] || continue
  grep -q "version: $FH_VERSION" "$DIST/forkhub/$yml" 2>/dev/null \
    || fail_soft "$yml missing or version mismatch (expected $FH_VERSION)"
done
for f in "$DIST"/forkhub/*; do
  [ -e "$f" ] || continue
  mv "$f" "$DIST"/
done
rm -rf "$DIST/forkhub" 2>/dev/null || true
if [ "$OS_KEY" = "linux" ]; then
  # --- descriptive AppImage name (CONSUME.md promises Natively-*.AppImage) ---
  # Upstream productName is the stealth name `corespeechd`, which
  # electron-builder bakes into the AppImage filename. A per-target
  # artifactName is rejected by electron-builder config schema
  # (TargetConfiguration allows only target+arch), and a linux-wide
  # artifactName would also rename the .deb — which already follows the
  # package `name` (`natively_*_amd64.deb`, as documented) and stays
  # untouched. So rename just the AppImage (+ sidecar blockmap if emitted)
  # and repoint the updater manifest at the new name (hashes/sizes cover
  # file content, so they stay valid).
  for img in "$DIST"/*.AppImage; do
    [ -e "$img" ] || continue
    base=$(basename "$img")
    case "$base" in
      Natively-*) say "AppImage already descriptive: $base"; continue ;;
    esac
    case "$base" in
      *-*) new="Natively-${base#*-}" ;;
      *) fail_soft "unexpected AppImage name without version separator: $base" ;;
    esac
    say "renaming AppImage $base -> $new"
    mv "$img" "$DIST/$new" || fail_soft "AppImage rename failed"
    if [ -e "$img.blockmap" ]; then
      mv "$img.blockmap" "$DIST/$new.blockmap" || fail_soft "blockmap rename failed"
    fi
    for yml in "$DIST"/latest-linux.yml "$DIST"/fh-linux.yml; do
      if [ -e "$yml" ]; then
        sed -i "s/$base/$new/g" "$yml" \
          || fail_soft "updater manifest repoint failed ($yml)"
      fi
    done
  done
fi
# The manifests must reference files that actually shipped (read line by
# line from a temp file — installer names may contain spaces, and a
# pipeline would run the loop in a subshell where fail_soft's exit
# could not stop the script).
URLS="$(mktemp)"
for yml in "$DIST"/latest-linux.yml "$DIST"/fh-linux.yml "$DIST"/latest-mac.yml "$DIST"/fh-mac.yml "$DIST"/latest.yml "$DIST"/fh.yml; do
  [ -e "$yml" ] || continue
  : >"$URLS"
  grep -E '^[[:space:]]*url: ' "$yml" 2>/dev/null | sed 's/^[[:space:]]*url: //' >>"$URLS" || true
  while IFS= read -r url; do
    [ -n "$url" ] || continue
    [ -e "$DIST/$url" ] || { rm -f "$URLS"; fail_soft "updater manifest references missing file: $url ($yml)"; }
  done <"$URLS"
done
rm -f "$URLS"
say "artifacts moved to dist"
ls "$DIST" | tee -a "$LOG"
