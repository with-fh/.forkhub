#!/bin/sh
# Router for automated intent re-derivation (see reimplement.md).
# Decides what an unattended OpenCode run produced and, on PROMOTE,
# refreshes the patch artifacts canonically.
#
# Args: <work-checkout> <patch-dir>
# Env: UPSTREAM_TAG (e.g. v0.0.43-nightly.20260924.2187), PATCH_ID,
#   AUTHOR (for attempts.jsonl).
# Prints exactly one word: PROMOTE, HUMAN, or FAIL.
#
# - HUMAN: the agent wrote NEEDS_HUMAN.md (decision required). Partial
#   work, if any, is saved to REALIZATION/partial.diff for resume.
# - PROMOTE: REALIZATION/realization.diff exists AND the patch verify.sh
#   passes in the work checkout. Refreshes reference.diff, bumps the patch
#   version (manifest + INTENT frontmatter), appends attempts.jsonl.
# - FAIL: anything else (red verify, timeout, empty run).
set -eu

WORK="${1:?work checkout required}"
PATCH="${2:?patch dir required}"
TAG="${UPSTREAM_TAG:?UPSTREAM_TAG required}"
ID="${PATCH_ID:?PATCH_ID required}"
AUTHOR="${AUTHOR:-forkhub-reimplement}"

if [ -f "$WORK/NEEDS_HUMAN.md" ]; then
  if [ -n "$(git -C "$WORK" status --porcelain 2>/dev/null)" ]; then
    mkdir -p "$WORK/REALIZATION"
    git -C "$WORK" add -N . 2>/dev/null || true
    git -C "$WORK" diff > "$WORK/REALIZATION/partial.diff" 2>/dev/null || true
  fi
  echo "HUMAN"
  exit 0
fi

if [ ! -f "$WORK/REALIZATION/realization.diff" ]; then
  echo "FAIL"
  exit 0
fi

if [ -f "$PATCH/verify.sh" ]; then
  if ! (cd "$WORK" && sh "$PATCH/verify.sh" >/dev/null 2>&1); then
    echo "FAIL"
    exit 0
  fi
fi

# Green: refresh artifacts canonically (do not trust the agent's diff file).
# REALIZATION/ and NEEDS_HUMAN.md are harness chatter, not the patch.
MANIFEST="$PATCH/../../manifest.json"
git -C "$WORK" add -N . 2>/dev/null || true
git -C "$WORK" diff -- . ':!REALIZATION' ':!NEEDS_HUMAN.md' > "$PATCH/reference.diff"

NEW_VERSION=$(jq -r --arg id "$ID" '.patches[$id].version // 0 | . + 1' "$MANIFEST")
jq --arg id "$ID" --argjson v "$NEW_VERSION" \
  '.patches[$id].version = $v' \
  "$MANIFEST" > "$MANIFEST.tmp"
mv "$MANIFEST.tmp" "$MANIFEST"

REALIZED_SHA=$(git -C "$WORK" rev-parse --short "$TAG^{}" 2>/dev/null || printf '%s' "$TAG")
jq --arg id "$ID" --arg sha "$REALIZED_SHA" \
  '.patches[$id].last_realized_against_commit = $sha' \
  "$MANIFEST" > "$MANIFEST.tmp"
mv "$MANIFEST.tmp" "$MANIFEST"

sed -i "1,/^---$/ s/^version: .*/version: $NEW_VERSION/" "$PATCH/INTENT.md"
sed -i "1,/^---$/ s/^last_realized_against_commit: .*/last_realized_against_commit: $REALIZED_SHA/" "$PATCH/INTENT.md"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '{"n":%s,"phase":"re-derivation","timestamp":"%s","upstream_tag":"%s","upstream_sha":"%s","approach":"unattended opencode re-derivation, verify gate green","result":"passed","tokens":0,"model":"unattended"}\n' \
  "$NEW_VERSION" "$NOW" "$TAG" "$REALIZED_SHA" >> "$PATCH/attempts.jsonl"

echo "PROMOTE"
