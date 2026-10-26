#!/bin/sh
# Verify gate for natively-forkhub-support (the one ForkHub-support patch).
# Runs in the patched Natively checkout (one simple command per line: the
# forkhub verify runner executes each line separately).
# Focused suites only — full CI stays upstream's job.
test -d node_modules || npm install --ignore-scripts
node node_modules/electron/install.js
npm run build:electron
node --test electron/update/updateFeed.test.mjs electron/update/ReleaseNotesManager.test.mjs electron/services/__tests__/HardwareId.test.mjs electron/services/__tests__/CalendarPkce.test.mjs electron/services/__tests__/ForkPatch2Sources.test.mjs electron/services/__tests__/LinuxDockAssociation.test.mjs electron/services/__tests__/LinuxSystemAudio.test.mjs electron/update/updatePublisher.test.mjs
