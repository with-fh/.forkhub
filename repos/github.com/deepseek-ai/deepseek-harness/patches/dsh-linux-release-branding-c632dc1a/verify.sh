#!/bin/sh
set -eu
test -f apps/desktop/src/linuxAutostart.ts
grep -Fq "const forkHubLinuxRelease = target.platform === 'linux' && buildEnv.FORKHUB_LINUX_RELEASE === '1'" apps/desktop/scripts/package-target.ts
grep -Fq "process.env.FORKHUB_LINUX_RELEASE === '1' ? 'official' : 'local'" apps/desktop/scripts/pack-local-packages.ts
