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
# REALIZATION/, NEEDS_HUMAN.md, CONTEXT.md, and PROMPT.md are harness
# chatter, not the patch — exclude all four so a future apply-check sees
# only real intent code (a leaked CONTEXT.md would apply cleanly once and
# then drift-check forever on an untracked harness file).
MANIFEST="$PATCH/../../manifest.json"
git -C "$WORK" add -N . 2>/dev/null || true
git -C "$WORK" diff -- . ':!REALIZATION' ':!NEEDS_HUMAN.md' ':!CONTEXT.md' ':!PROMPT.md' > "$PATCH/reference.diff"

# Semver: unattended re-derivation never changes intent, so PROMOTE
# always bumps PATCH (MAJOR/MINOR are human-authored with intent changes).
NEW_VERSION=$(jq -r --arg id "$ID" '(.patches[$id].version // "0.0.0" | tostring | split(".") + ["0","0","0"] | .[0:3] | .[2] = (((.[2] | tonumber?) // 0) + 1 | tostring) | join("."))' "$MANIFEST")
jq --arg id "$ID" --arg v "$NEW_VERSION" \
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
ATTEMPT_N=$(($(wc -l < "$PATCH/attempts.jsonl" 2>/dev/null || echo 0) + 1))
# Report trail for the NEXT agent: what upstream changed + what approach
# worked + what was tried and failed. Sourced from the agent's report —
# first non-empty line of its "Upstream changes" / "Approach" / "Did not
# work" sections, capped so one row stays one line of JSON. Empty report
# sections fall back to the previous defaults, never to a blank record.
REPORT="$WORK/REALIZATION/report.md"
pick_section() {
  awk -v h="$1" 'index($0,h){f=1;next} f&&/^## /{exit} f&&NF{print;exit}' "$REPORT" 2>/dev/null | head -c 300
}
UPSTREAM_CHANGES=$(pick_section "Upstream changes")
APPROACH_TAKEN=$(pick_section "Approach")
TRIED_FAILED=$(pick_section "Did not work")
[ -n "$UPSTREAM_CHANGES" ] || UPSTREAM_CHANGES="unattended opencode re-derivation, verify gate green"
UPSTREAM_CHANGES_JSON=$(printf '%s' "$UPSTREAM_CHANGES" | jq -Rs .)
APPROACH_JSON=$(printf '%s' "$APPROACH_TAKEN" | jq -Rs .)
FAILED_JSON=$(printf '%s' "$TRIED_FAILED" | jq -Rs .)
MODEL_RUN="${MODEL:-unattended}"
printf '{"n":%s,"phase":"re-derivation","timestamp":"%s","upstream_tag":"%s","upstream_sha":"%s","upstream_changes":%s,"approach":%s,"tried_and_failed":%s,"result":"passed","tokens":0,"model":%s,"semver":"%s","change":"patch"}\n' \
  "$ATTEMPT_N" "$NOW" "$TAG" "$REALIZED_SHA" "$UPSTREAM_CHANGES_JSON" "$APPROACH_JSON" "$FAILED_JSON" "$(printf '%s' "$MODEL_RUN" | jq -Rs .)" "$NEW_VERSION" >> "$PATCH/attempts.jsonl"

echo "PROMOTE"
