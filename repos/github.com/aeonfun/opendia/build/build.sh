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
# Auto-update feed (self-distributed/unlisted: AMO never serves updates for
# install-from-file XPIs, so installed copies need update_url). Stable
# release tag + asset names — NEVER rename the tag or installed copies lose
# their update source (the installed update_url is the only discovery
# mechanism; see INTENT.md).
UPDATE_TAG="opendia-firefox-updates"
UPDATE_URL="https://github.com/$REPO/releases/download/$UPDATE_TAG/updates.json"
LATEST_XPI="opendia-firefox-latest-fh.xpi"
STABLE_XPI_URL="https://github.com/$REPO/releases/download/$UPDATE_TAG/$LATEST_XPI"

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
# NOTE: this target has NO updater (v<base>-fh...) releases (no publish.sh
# hook), so N MUST count the namespaced bundle tags
# ($SLUG-$UP-fhN) — the same counter the shared workflow uses for the
# release it publishes into. Counting updater tags would pin N=1 forever
# and every rebuild would re-submit the same AMO manifest version (409).
OWNER=$(printf '%s' "$REPO" | cut -d/ -f1 | tr '[:upper:]' '[:lower:]')
VER=$(printf '%s' "$TAG" | sed 's/^v//')
SLUG=$(printf '%s' "${FORKHUB_TARGET:-github.com/aeonfun/opendia}" | awk -F/ '{print $(NF-1)"-"$NF}' | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')
EXISTING_TAGS=$(gh api "repos/$REPO/releases?per_page=100" --jq '.[].tag_name' 2>/dev/null) \
  || fail_soft "could not list releases to number the ForkHub build (gh api failed)"
N=$(printf '%s\n' "$EXISTING_TAGS" | grep -cE "^${SLUG}-+${TAG}-fh[0-9]+\$" || true)
N=$((N + 1))
# force=true rebuilds reuse the SAME bundle number when the newest bundle
# is incomplete — but AMO versions are unique per add-on ID, so the manifest
# stamp must still advance. If the newest $SLUG-$UP-fhN bundle already
# carries a signed XPI, N counts it and we move past it; if it does NOT
# (failed sign), reuse would 409, so bump once more.
if [ "$N" -gt 1 ]; then
  NEWEST=$(printf '%s\n' "$EXISTING_TAGS" | grep -E "^${SLUG}-+${TAG}-fh[0-9]+\$" | sed -E 's/.*-fh([0-9]+)$/\1 \0/' | sort -n | tail -1 | awk '{print $2}')
  if [ -n "${NEWEST:-}" ] && ! gh release view "$NEWEST" --repo "$REPO" --json assets --jq '.assets[].name' 2>/dev/null | grep -qE "\.xpi$"; then
    say "newest bundle $NEWEST has no signed XPI (failed sign); reusing its number"
    N=$((N - 1))
  fi
fi
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
#
# --- update_url stamp (auto-update): unlisted/self-distributed XPIs get NO
# AMO-served updates, so without this every install is frozen at its
# install-time version. Stamp the catalog updates.json URL here (same
# signing-time transform family as the ID swap — NOT part of
# reference.diff, which stays one-hunk). Installed copies poll this URL
# (~24h); Firefox refuses downgrades, and our STAMP_VER scheme only moves
# forward within an add-on ID, so a newer updates.json can never push an
# older XPI. Constraint: the UPDATE_TAG/UPDATE_URL constants above must be
# STABLE forever — existing installs pin the URL baked into their XPI.
UP_VER=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['version'])")
STAMP_VER="$UP_VER.$N"
python3 - "$MANIFEST" "$STAMP_VER" "$UPDATE_URL" <<'EOF'
import json, sys
p, v, u = sys.argv[1], sys.argv[2], sys.argv[3]
m = json.load(open(p)); m['version'] = v
g = m.setdefault('applications', {}).setdefault('gecko', {})
g['update_url'] = u
with open(p, 'w') as f:
    json.dump(m, f, indent=2)
    f.write('\n')
EOF
say "version stamped: $UP_VER -> $STAMP_VER"
say "update_url stamped: $UPDATE_URL"
grep -q "\"version\": \"$STAMP_VER\"" "$MANIFEST" || fail_soft "version stamp failed"
grep -q "\"update_url\": \"$UPDATE_URL\"" "$MANIFEST" || fail_soft "update_url stamp failed"

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
# NOTE on MANIFEST_UPDATE_URL: web-ext lint defaults to selfHosted=false,
# so any gecko.update_url fires '"update_url" is not allowed' as an error.
# But AMO's server runs the linter WITH --self-hosted for unlisted channel
# submissions (addons-server run_addons_linter: `if channel ==
# amo.CHANNEL_UNLISTED: args.append('--self-hosted')`), where the check is
# skipped — and --self-hosted is exactly what this pipeline submits.
# So the gate lints WITH --self-hosted for AMO parity: MANIFEST_UPDATE_URL
# must be ABSENT here (proves the stamp landed), and any other error fails.
LINT_OUT="$WORK/lint.txt"
web-ext lint --source-dir "$WORK/src" --self-hosted 2>&1 | tee "$LINT_OUT" | tail -6 >> "$LOG"
if grep -q "MANIFEST_UPDATE_URL" "$LINT_OUT"; then
  fail_soft "MANIFEST_UPDATE_URL still flagged under --self-hosted — unexpected; refusing to submit"
fi
if grep -qE "errors +[1-9]" "$LINT_OUT"; then
  grep -B2 -A6 "ERRORS:" "$LINT_OUT" >> "$LOG" || true
  fail_soft "web-ext lint (--self-hosted) reports errors; refusing to submit to AMO"
fi
say "lint gate passed (--self-hosted, 0 errors)"

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
# --- Update feed: cumulative updates.json + stable latest-XPI alias, both
# published to the STABLE UPDATE_TAG release (created once, then --clobber
# on every build). Installed copies poll updates.json (~24h per
# extensions.update.interval); each entry carries a sha256 so a tampered
# or truncated XPI is rejected client-side. Cumulative (append entry per
# build, keep old ones) so any installed version finds its upgrade path.
# NOTE: forkhub artifact releases are per-(tag,fhN) and non-monotonic
# across upstream tags; the feed only ever advertises the newest build.
OUT_SHA=$(sha256sum "$DIST/$OUT" | cut -d' ' -f1)
FEED_ENTRY=$(mktemp)
python3 - "$FEED_ENTRY" "$ADDON_ID" "$STAMP_VER" "$STABLE_XPI_URL" "$OUT_SHA" <<'EOF'
import json, sys
_, path, addon_id, version, link, sha = sys.argv
try:
    feed = json.load(open(path))
except (FileNotFoundError, json.JSONDecodeError):
    feed = {"addons": {}}
entry = {"version": version, "update_link": link, "update_hash": "sha256:" + sha}
updates = feed.setdefault("addons", {}).setdefault(addon_id, {}).setdefault("updates", [])
updates[:] = [u for u in updates if u.get("version") != version] + [entry]
with open(path, 'w') as f:
    json.dump(feed, f, indent=2)
    f.write('\n')
EOF
say "feed entry staged: $STAMP_VER -> $STABLE_XPI_URL (sha256:$OUT_SHA)"
# Old entries are kept locally but the feed published here is rebuilt
# below from the release's current updates.json, so it stays cumulative
# across builds (each build only knows its own version).
FEED_DL="$WORK/updates-remote.json"
if gh release view "$UPDATE_TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release download "$UPDATE_TAG" --repo "$REPO" -p updates.json -O "$FEED_DL" 2>/dev/null || true
fi
if [ -f "$FEED_DL" ]; then
  python3 - "$FEED_DL" "$FEED_ENTRY" <<'EOF'
import json, sys
remote_path, local_path = sys.argv[1], sys.argv[2]
try:
    remote = json.load(open(remote_path))
except (FileNotFoundError, json.JSONDecodeError):
    remote = {"addons": {}}
local = json.load(open(local_path))
for addon_id, obj in local.get("addons", {}).items():
    r = remote.setdefault("addons", {}).setdefault(addon_id, {}).setdefault("updates", [])
    seen = {u.get("version") for u in r}
    r.extend(u for u in obj.get("updates", []) if u.get("version") not in seen)
with open(local_path, 'w') as f:
    json.dump(remote, f, indent=2)
    f.write('\n')
EOF
fi
cp "$FEED_ENTRY" "$DIST/updates.json"
cp "$DIST/$OUT" "$DIST/$LATEST_XPI"
UPLOAD_TAG="$UPDATE_TAG"
if gh release view "$UPLOAD_TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$UPLOAD_TAG" "$DIST/updates.json" "$DIST/$LATEST_XPI" --repo "$REPO" --clobber \
    || say "warning: feed upload to $UPLOAD_TAG failed; bundle still ships"
else
  say "creating stable update-feed release $UPLOAD_TAG"
  gh release create "$UPLOAD_TAG" "$DIST/updates.json" "$DIST/$LATEST_XPI" \
    --repo "$REPO" --title "OpenDia Firefox auto-update feed (ForkHub)" \
    --notes "STABLE release — do not delete. Installed copies poll updates.json (~24h) for new signed builds. Each entry carries a sha256. Cumulative: every signed build appends an entry." \
    || say "warning: feed release creation failed; bundle still ships"
fi
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
  echo "- Transform: ONLY \`applications.gecko.id\`, \`version\`,"
  echo "  \`update_url stamp (auto-update feed):\`"
  echo "  \`opendia@aaronjmars.com\` → \`$ADDON_ID\` (catalog-owned AMO"
  echo "  identity; the upstream ID is registered to the author's account"
  echo "  and 403s on our keys); version \`$UP_VER\` → \`$STAMP_VER\`"
  echo "  (AMO versions are unique per add-on ID); update_url →"
  echo "  \`$UPDATE_URL\` (installed copies poll for new signed builds"
  echo "  ~daily; feed published to stable \`$UPDATE_TAG\` release)."
  echo "  Add-on name stays \`OpenDia\`; no code, UI, or permission change."
  echo "- Channel: unlisted (self-distributed via this catalog)"
  echo "- Install: \`about:addons\` → gear → Install Add-on From File"
  echo "- Sunset: when upstream ships a signed XPI (asset containing"
  echo "  \`META-INF/mozilla.sf\`), this pipeline retires — see triggers.md."
} > "$DIST/PROVENANCE.md"
say "shipped $DIST/$OUT"
