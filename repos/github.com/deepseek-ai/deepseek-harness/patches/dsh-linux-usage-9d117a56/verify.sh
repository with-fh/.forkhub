#!/bin/sh
set -eu
test -f apps/desktop/src/forkhubUsage.ts
test -d node_modules || pnpm install --ignore-scripts
node_modules/.bin/vitest run apps/desktop/tests/forkhub-usage.spec.ts
