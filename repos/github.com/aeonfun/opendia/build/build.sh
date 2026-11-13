#!/bin/sh
# Resign pipeline for the ForkHub OpenDia channel.
# Runs with cwd = patched upstream checkout. Best-effort: always exits 0;
# the shared workflow falls back to a patched-source tarball when dist/
# stays empty. See BUILD.md.
#
# Single ubuntu leg (see upstream.json:build_runs_on). Needs `web-ext`
# on PATH (shared workflow installs bun; `bun add -g web-ext` when
# absent) and AMO_JWT_ISSUER / AMO_JWT_SECRET in env (repo Secrets).
set -eu
set -o pipefail

DIST="${GITHUB_WORKSPACE:?}/dist"
REPO="${GITHUB_REPOSITORY:?}"
TAG="${UPSTREAM_TAG:?}"
LOG="$DIST/BUILD_LOG.md"
ADDON_ID="{22b9fd82-342c-46ab-a615-888115ffc841}"

say() {
  printf '%s\n' "$*" | tee -a "$LOG"
}

fail_soft() {
  say "BUILD-SOFT-FAIL: $*"
  rm -rf "$DIST/forkhub" 2>/dev/null || true
  tar --exclude=./node_modules --exclude=./dist --exclude=./.git \
    -czf "$DIST/aeonfun-opendia-patched-source.tar.gz" . 2>/dev/null \
    && say "patched-source tarball packed" \
    || say "source tarball packing failed; bundle will carry the build log only"
  say "Continuing so the bundle release still publishes."
  exit 0
}

# Stable tags only.
case "$TAG" in
  v[0-9]*)
    case "$TAG" in
      *-alpha* | *-beta* | *-rc* | *-preview* | *-nightly* | *-pr.*)
        fail_soft "UPSTREAM_TAG=$TAG is a pre-release tag; refusing to cut a ForkHub release."
        ;;
    esac
    ;;
  *)
    fail_soft "UPSTREAM_TAG=$TAG is not a vX.Y.Z stable tag; refusing."
    ;;
esac

# Provenance version: <upstream>-fh.<owner>.<n>, e.g. 1.1.4-fh.with-fh.1
OWNER=$(printf '%s' "$REPO" | cut -d/ -f1 | tr '[:upper:]' '[:lower:]')
VER=$(printf '%s' "$TAG" | sed 's/^v//')
ESCAPED_BASE=$(printf '%s' "$VER" | sed 's/\./\\./g')
EXISTING_TAGS=$(gh api "repos/$REPO/releases?per_page=100" --jq '.[].tag_name' 2>/dev/null) \
  || fail_soft "could not list releases to number the ForkHub build (gh api failed)"
N=$(printf '%s\n' "$EXISTING_TAGS" | grep -cE "^v${ESCAPED_BASE}[-.]fh\\.${OWNER}\\.[0-9]+\$" || true)
N=$((N + 1))
FORKHUB_VERSION="$VER-fh.$OWNER.$N"
export FORKHUB_VERSION
say "FORKHUB_VERSION=$FORKHUB_VERSION"

command -v web-ext >/dev/null 2>&1 || {
  say "installing web-ext"
  bun add -g web-ext || fail_soft "could not install web-ext"
}

# --- Sunset check: does upstream already ship a signed XPI? ---
UPSTREAM_REPO="aeonfun/opendia"
say "sunset check: listing upstream assets for $TAG"
ASSETS=$(gh api "repos/$UPSTREAM_REPO/releases/tags/$TAG" --jq '.assets[] | .name + " " + .browser_download_url' 2>/dev/null || true)
if [ -z "$ASSETS" ]; then
  say "warning: could not list upstream assets; proceeding (sunset check inconclusive)"
else
  printf '%s\n' "$ASSETS" | while read -r name url; do
    [ -n "$name" ] || continue
    case "$name" in
      *.xpi)
        say "upstream ships $name — checking for META-INF/mozilla.sf"
        if curl -sL --max-time 120 "$url" -o /tmp/upstream-candidate.xpi \
          && unzip -l /tmp/upstream-candidate.xpi 2>/dev/null | grep -q "META-INF/mozilla.sf"; then
          say "SUNSET: upstream $TAG ships a SIGNED xpi ($name); pipeline deprecated for this tag"
          printf '# Sunset: %s\n\nUpstream `%s` ships a signed XPI (`%s`). Install theirs; this catalog no longer re-signs.\n' "$TAG" "$TAG" "$name" > "$DIST/SUNSET-$TAG.md"
          exit 42
        else
          say "$name is NOT Mozilla-signed; continuing resign pipeline"
        fi
        ;;
    esac
  done
  rc=$?
  if [ "$rc" -eq 42 ]; then
    say "sunset note written; nothing else to build"
    exit 0
  fi
fi

# --- Fetch upstream firefox zip ---
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ZIP_NAME=""
ZIP_URL=""
while read -r name url; do
  [ -n "$name" ] || continue
  case "$name" in
    opendia-firefox-*.zip)
      ZIP_NAME="$name"; ZIP_URL="$url"; break
      ;;
  esac
done <<EOF
$ASSETS
EOF
[ -n "$ZIP_URL" ] || fail_soft "no opendia-firefox-*.zip asset on upstream $TAG"
say "fetching $ZIP_NAME"
curl -sL --max-time 300 "$ZIP_URL" -o "$WORK/upstream.zip" \
  || fail_soft "download failed: $ZIP_URL"
ZIP_SHA=$(sha256sum "$WORK/upstream.zip" | cut -d' ' -f1)
say "upstream zip sha256: $ZIP_SHA"
unzip -o -q "$WORK/upstream.zip" -d "$WORK/src" \
  || fail_soft "unzip failed for $ZIP_NAME"

# The zip root IS the built firefox dir (manifest.json at top level).
MANIFEST="$WORK/src/manifest.json"
[ -f "$MANIFEST" ] || fail_soft "manifest.json not at zip root ($ZIP_NAME: $(ls "$WORK/src" | head -5 | tr '\n' ' '))"

# --- Deterministic ID swap (same transform as reference.diff) ---
grep -q '"id": "opendia@aaronjmars.com"' "$MANIFEST" \
  || fail_soft "upstream manifest no longer carries the expected ID — drift: re-derive reference.diff"
sed -i "s|\"id\": \"opendia@aaronjmars.com\"|\"id\": \"$ADDON_ID\"|" "$MANIFEST"
grep -q "\"id\": \"$ADDON_ID\"" "$MANIFEST" || fail_soft "ID swap failed"
# Name stays upstream ("OpenDia") — see INTENT.md rationale. Only the ID changes.
grep -q '"name": "OpenDia"' "$MANIFEST" \
  || fail_soft "upstream manifest name changed — drift: re-check INTENT.md rename rationale"

# --- Version stamp: AMO versions are unique per add-on ID, and any prior
# sign (local or CI) already owns the upstream manifest version.
# Stamp <upstream>.<fhN> (e.g. 1.1.1 -> 1.1.1.4): valid toolkit version
# format, sorts above the base but below any future upstream bump.
# The mapping is recorded in PROVENANCE.md.
UP_VER=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['version'])")
STAMP_VER="$UP_VER.$N"
python3 - "$MANIFEST" "$STAMP_VER" <<'EOF'
import json, sys
p, v = sys.argv[1], sys.argv[2]
m = json.load(open(p)); m['version'] = v
with open(p, 'w') as f:
    json.dump(m, f, indent=2)
    f.write('\n')
EOF
say "version stamped: $UP_VER -> $STAMP_VER"
grep -q "\"version\": \"$STAMP_VER\"" "$MANIFEST" || fail_soft "version stamp failed"

# --- MIT attribution: upstream zip ships NO license file; the MIT condition
# requires the copyright + permission notice in all copies. Inject verbatim.
if ! unzip -l "$WORK/upstream.zip" | grep -qiE "LICENSE(\.txt|\.md)?$"; then
  say "upstream zip lacks LICENSE; injecting verbatim upstream LICENSE at zip root"
  curl -sL --max-time 60 "https://raw.githubusercontent.com/aeonfun/opendia/$TAG/LICENSE" \
    -o "$WORK/src/LICENSE" \
    || fail_soft "could not fetch upstream LICENSE for injection"
  head -c 200 "$WORK/src/LICENSE" | grep -q "Aeon" \
    || fail_soft "fetched LICENSE does not look like upstream's (no Aeon marker)"
fi

# --- Lint gate (0 errors) ---
if ! web-ext lint --source-dir "$WORK/src" 2>&1 | tee -a "$LOG" | grep -qE "errors +0"; then
  say "web-ext lint output above did not confirm 0 errors"
fi
if web-ext lint --source-dir "$WORK/src" 2>&1 | grep -qE "errors +[1-9]"; then
  fail_soft "web-ext lint reports errors; refusing to submit to AMO"
fi

# --- Sign ---
if [ -z "${AMO_JWT_ISSUER:-}" ] || [ -z "${AMO_JWT_SECRET:-}" ]; then
  fail_soft "AMO_JWT_ISSUER / AMO_JWT_SECRET not set (repo Secrets); cannot sign"
fi
ARTIFACTS="$WORK/signed"
mkdir -p "$ARTIFACTS"
WEB_EXT_API_KEY="$AMO_JWT_ISSUER" WEB_EXT_API_SECRET="$AMO_JWT_SECRET" \
  web-ext sign --channel=unlisted --source-dir "$WORK/src" --artifacts-dir "$ARTIFACTS" 2>&1 \
  | tee -a "$LOG" || fail_soft "web-ext sign failed (see log)"
SIGNED=$(ls "$ARTIFACTS"/*.xpi 2>/dev/null | head -1)
[ -n "$SIGNED" ] || fail_soft "sign succeeded but no .xpi in artifacts dir"
unzip -l "$SIGNED" | grep -q "META-INF/mozilla.sf" \
  || fail_soft "signed artifact lacks META-INF/mozilla.sf"

# --- Ship ---
OUT="opendia-firefox-$FORKHUB_VERSION.xpi"
cp "$SIGNED" "$DIST/$OUT"
# MIT attribution also OUTSIDE the artifact: release notes carry it even
# if someone redistributes the bare .xpi without unpacking.
{
  echo "# Provenance — $OUT"
  echo
  echo "Unofficial community build. Not affiliated with, endorsed, or"
  echo "supported by Aeon Inc / aeonfun. For the official project see"
  echo "https://github.com/aeonfun/opendia. Support: file issues in this"
  echo "catalog repo, not upstream."
  echo
  echo "- Upstream tag: \`$TAG\`"
  echo "- Upstream asset: \`$ZIP_NAME\` (sha256 \`$ZIP_SHA\`)"
  echo "- License: MIT, Copyright (c) 2025 Aeon Inc — full text inside"
  echo "  the .xpi (\`LICENSE\` at zip root) and at"
  echo "  https://github.com/aeonfun/opendia/blob/$TAG/LICENSE"
  echo "- Transform: ONLY \`applications.gecko.id\` + version stamp:"
  echo "  \`opendia@aaronjmars.com\` → \`$ADDON_ID\` (catalog-owned AMO"
  echo "  identity; the upstream ID is registered to the author's account"
  echo "  and 403s on our keys); version \`$UP_VER\` → \`$STAMP_VER\`"
  echo "  (AMO versions are unique per add-on ID). Add-on name stays"
  echo "  \`OpenDia\`; no code, UI, or permission change."
  echo "- Channel: unlisted (self-distributed via this catalog)"
  echo "- Install: \`about:addons\` → gear → Install Add-on From File"
  echo "- Sunset: when upstream ships a signed XPI (asset containing"
  echo "  \`META-INF/mozilla.sf\`), this pipeline retires — see triggers.md."
} > "$DIST/PROVENANCE.md"
say "shipped $DIST/$OUT"
