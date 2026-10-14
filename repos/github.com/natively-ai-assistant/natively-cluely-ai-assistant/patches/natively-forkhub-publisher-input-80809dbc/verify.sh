#!/bin/sh
# Verify gate for natively-forkhub-publisher-input.
# Runs in the patched Natively checkout AFTER patches 1-3 (manifest
# apply_order) — one simple command per line: the forkhub verify runner
# executes each line separately.
# Focused suites only — full CI stays upstream's job.
test -d node_modules || npm install --ignore-scripts
node node_modules/electron/install.js
npm run build:electron
node --test electron/update/updateFeed.test.mjs electron/update/updatePublisher.test.mjs
