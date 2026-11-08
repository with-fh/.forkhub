# Build — github.com/deepseek-ai/deepseek-harness (ForkHub, DRAFT scaffold)

DRAFT: no legs run until the real channel patch lands
(`upstream.json:build_runs_on` is `[]`, so the shared discover matrix
emits no jobs for this target). On realization (`fh draft` → `fh
satisfied`), restore:

```json
"build_runs_on": ["macos-26", "windows-latest"]
```

Repo-native build for the ForkHub DeepSeek Harness Desktop channel.
Runs one workflow leg per OS (`upstream.json:build_runs_on`) after the
intent stack is applied and `verify.sh` passes. Each build carries a
ForkHub provenance version `<upstream>-fh.<owner>.<n>` (e.g.
`dsh-v0.2.2-rc.1` → `0.2.2-fh.with-fh.1`; the `dsh-v` prefix is
normalized — see `tagMatch` discipline below).

## What each leg will build (mirror of official, unsigned)

Upstream `apps/desktop/scripts/package-target.ts` supports
`mac-arm64 | mac-x64 | win-x64` only (no linux target — Linux ships
from the downstream ImBIOS catalog). Unsigned (no certs in this
catalog): mac legs need `package:mac:*:unsigned`-equivalents,
Gatekeeper right-click-Open on first launch; SmartScreen warnings on
Windows ("More info → Run anyway").

| leg | artifacts |
|---|---|
| mac (`macos-26`, unsigned) | `*.dmg` + `*.zip` (arm64 + x64), updater manifests |
| win (`windows-latest`, unsigned) | nsis `*-Setup-*.exe` + portable `*.exe`, updater manifests |

## `tagMatch` discipline

Upstream tags are `dsh-vX.Y.Z-*` (e.g. `dsh-v0.2.2-rc.1`) and ALL
current upstream releases are prereleases with zero assets — this
catalog's channel tags MUST be its own `v<base>-fh.<owner>.<n>`
unified updater tags (same shape as the Natively channel), so the
`tagMatch` never collides with upstream or bundle tags.

## Linux (downstream ImBIOS)

`package-target.ts` `SUPPORTED_TARGETS` has no linux entry; adding
`linux-x64` (AppImage + deb, XDG desktop-entry/WM_CLASS contract,
node-pty `prebuilds/linux-x64`) is the ImBIOS `dsh-linux-support`
patch, which `depends_on` this channel patch — same split as Natively.
