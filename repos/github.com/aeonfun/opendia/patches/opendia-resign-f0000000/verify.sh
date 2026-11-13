#!/bin/sh
# Verify gate for opendia-resign (catalog-owned add-on ID).
# Runs in the patched upstream checkout. set -e: any failing assertion
# fails the gate (a missing file must NOT read as a pass).
set -e
test -f opendia-extension/manifest-firefox.json
git diff --stat | grep -q "opendia-extension/manifest-firefox.json |  1 " || git diff --stat | grep -q "opendia-extension/manifest-firefox.json | 2 "
grep -q '"id": "{22b9fd82-342c-46ab-a615-888115ffc841}"' opendia-extension/manifest-firefox.json
! grep -q "aaronjmars" opendia-extension/manifest-firefox.json
