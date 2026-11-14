#!/bin/sh
# Verify gate for dsh-linux-support (the ImBIOS Linux patch).
# Runs in the DeepSeek Harness checkout with the with-fh channel patch
# applied first (see manifest depends_on), then layers this patch.
# Focused suites only — full CI stays upstream's job.
set -eu
HERE=$(dirname "$0")

# No channel drift: the linux patch never touches feed/updater defaults.
if grep -E '^[+-].*(setFeedURL|allowPrerelease|getUpdateFeed|forkhubUpdateOwner)' "$HERE/reference.diff" | grep -qv 'openAtLogin'; then
  echo "FAIL: linux patch must not touch channel defaults" >&2
  exit 1
fi

# Layer order: stock -> channel -> linux.
if [ ! -f apps/desktop/src/updateFeed.ts ]; then
  echo "apply the with-fh channel reference.diff first (see depends_on)" >&2
  exit 1
fi
if [ ! -f apps/desktop/src/linuxAutostart.ts ]; then
  CLEAN=$(mktemp)
  sed -e 's/\x1b\[[0-9;]*m//g' "$HERE/reference.diff" > "$CLEAN"
  git apply --check "$CLEAN"
  git apply "$CLEAN"
  rm -f "$CLEAN"
fi

test -f apps/desktop/src/linuxAutostart.ts || { echo "FAIL: linuxAutostart.ts missing" >&2; exit 1; }

test -d node_modules || pnpm install --ignore-scripts
node_modules/.bin/vitest run \
  apps/desktop/tests/linux-autostart.spec.ts \
  apps/desktop/tests/linux-dock-association.spec.ts \
  apps/desktop/tests/electron-builder-config-linux.spec.ts \
  apps/desktop/tests/desktop-build-paths.spec.ts \
  apps/desktop/tests/desktop-auto-update-environment.spec.ts \
  apps/desktop/tests/package-target.spec.ts \
  apps/desktop/tests/desktop-upload-plan.spec.ts \
  apps/desktop/tests/desktop-publish-route.spec.ts \
  apps/desktop/tests/desktop-package-environment.spec.ts \
  apps/desktop/tests/desktop-package-selection.spec.ts
