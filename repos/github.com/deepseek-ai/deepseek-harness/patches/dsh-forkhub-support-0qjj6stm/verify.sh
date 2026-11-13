#!/bin/sh
# Verify gate for dsh-forkhub-support (the ForkHub update-channel patch).
# Runs in the patched DeepSeek Harness checkout (one simple command per
# line). Focused suites only — full CI stays upstream's job.
test -d node_modules || npm install -g pnpm@11 >>/dev/null 2>&1
test -d node_modules || pnpm install --frozen-lockfile --prefer-offline
./node_modules/.bin/vitest run --project thread-safe apps/desktop/tests/forkhub-update-feed.spec.ts apps/desktop/tests/forkhub-fork-version.spec.ts apps/desktop/tests/update-coordinator.spec.ts apps/desktop/tests/main-startup.spec.ts apps/desktop/tests/preload-app.spec.ts packages/client/ui-settings-general/tests/desktop-feed.client.spec.ts
