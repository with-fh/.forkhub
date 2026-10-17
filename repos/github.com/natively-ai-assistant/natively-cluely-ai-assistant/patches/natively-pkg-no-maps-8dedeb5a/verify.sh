#!/bin/sh
# Verify gate for natively-pkg-no-maps.
# Packaging-only change: assert the files-ignore is present and the
# electron tree still bundles. Runs in the Natively checkout with this
# patch applied (one simple command per line: the verify runner executes
# each line separately). Full AppImage proof (payload carries no .map)
# rides the forkhub-pr-build workflow, not this gate.
test -d node_modules || npm install --ignore-scripts
node node_modules/electron/install.js
node -e "const p=require('./package.json'); if(!p.build.files.includes('!**/*.map')){console.error('missing map ignore in build.files');process.exit(1)} console.log('map ignore present')"
npm run build:electron
