#!/bin/sh
# Verify gate for natively-linux-support (with-fh Linux leg patch; ported from ImBIOS).
# Runs in the patched Natively checkout with the with-fh update-channel
# patch already applied (one simple command per line: the forkhub verify
# runner executes each line separately).
# Focused suites only — full CI stays upstream's job.
test -d node_modules || npm install --ignore-scripts
node node_modules/electron/install.js
npm run build:electron
node --test electron/services/__tests__/LinuxDockAssociation.test.mjs electron/services/__tests__/LinuxSystemAudio.test.mjs electron/utils/__tests__/linuxAutostart.test.mjs electron/services/__tests__/ForkPatchLinuxSources.test.mjs electron/utils/__tests__/windowsTaskbarPolicy.test.mjs
