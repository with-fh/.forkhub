# Build — github.com/deepseek-ai/deepseek-harness (ForkHub channel)

Repo-native build for the ForkHub DeepSeek Harness Desktop channel.
Runs one workflow leg per OS (`upstream.json:build_runs_on`) after the
intent stack is applied and `verify.sh` passes. Each build carries a
ForkHub provenance version `<base>.<owner>.<date>.<n>` (e.g.
`dsh-v0.2.2-rc.1` → `0.2.2-rc.1.with-fh.20261110.1`; the `dsh-v` prefix is
normalized — see `tagMatch` discipline below).

## Version form (DSH-native, not Natively-shaped)

DSH's build validator (`desktop-build-version.mjs`) only accepts versions
extending the product prerelease in native `<base>.<date>.<n>` form, so a
Natively-shaped `-fh.<owner>.<n>` suffix is rejected. Fork builds therefore
ride `<base>.<owner>.<date>.<n>` with the owner folded in. Pure-numeric
segments stay dates (the owner field must contain a letter, so stock
date-builds never parse as fork builds); same-owner rebuilds order by the
trailing counter; semver precedence holds (numeric < alphanumeric, so a
stock date-build never outranks a fork build). Verified:
`validateDesktopBuildVersion("0.2.2-rc.1.with-fh.20261110.1",
"0.2.2-rc.1")` passes; the short `-fh` form fails as designed.

The in-app fork gate (`forkVersion.ts`) enforces the same-owner rule:
`-rc.1.with-fh.<date>.1` → `-rc.1.with-fh.<date>.2` upgrades; stock↔fork
and cross-owner pairs refuse.

## What each leg builds (mirror of official, unsigned)

Upstream `package:linux:x64:unsigned` (+ the `dsh-linux-support`
patch in this manifest's stack) adds `linux-x64` alongside
`mac-arm64 | mac-x64 | win-x64`. Unsigned (no certs in this
catalog): mac legs run `package:mac:<arch>:unsigned`, win runs
`package:win:x64:unsigned`, linux runs `package:linux:x64:unsigned`;
Gatekeeper right-click-Open on first launch; SmartScreen warnings on
Windows ("More info → Run anyway").

| leg | artifacts |
|---|---|
| mac (`macos-26`, unsigned) | `*.dmg` + `*.zip` (arm64 + x64), `latest-mac.yml` + `fh-mac.yml` |
| win (`windows-latest`, unsigned) | unsigned `*.exe`, `latest.yml` + `fh.yml` |
| linux (`ubuntu-24.04`, unsigned) | unsigned `*.AppImage`, `latest-linux.yml` + `fh-linux.yml` |

Every leg also emits `*.blockmap` sidecars (differential updates).

## What `build.sh` does

1. Normalizes `UPSTREAM_TAG` (`dsh-v0.2.2-rc.1` → base `0.2.2-rc.1`) and
   numbers the fork build `<base>.<owner>.<date>.<n>` (`n` counts existing
   updater releases for this base+owner+date; incomplete newest releases
   are reused so all OS legs converge on ONE updater release).
2. Bootstraps node 24 + pnpm 11 if the runner lacks them.
3. Installs deps (`pnpm install --frozen-lockfile`), runs the verify gate
   (`verify.sh`: 7 focused suites, 255 tests).
4. Stamps the version (`DSH_DESKTOP_BUILD_VERSION`, accepted by the build
   validator) and the catalog owner (`DSH_UPDATE_OWNER`, baked into
   `extraMetadata.forkhubUpdateOwner` — `with-fh` unstamped stays default).
5. Packs per-OS unsigned installers (`--build-version <fork> --unsigned`,
   `--publish never`), twins the updater manifests (`latest-*` + `fh-*`,
   content is channel-agnostic since the fork `channel` is `nightly`),
   and asserts each manifest carries the stamped version and references
   only shipped files.
6. Never fails the job: on any failure it packs a patched-source tarball,
   logs to `BUILD_LOG.md`, and exits 0. `publish.sh` then skips the
   updater release when no manifest exists.

## `tagMatch` discipline

Upstream tags are `dsh-vX.Y.Z-*` (e.g. `dsh-v0.2.2-rc.1`) and ALL
current upstream releases are prereleases with zero assets. The workflow
tag pool is `refs/tags/v*`, so `upstream.json:tag_match_pattern` is
`^dsh-v[0-9]+\.[0-9]+\.[0-9]+-` to admit them. This catalog's channel tags
are its own `v<base>.<owner>.<date>.<n>` unified updater tags, so the
registry `tagMatch` (`^v[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+\.<owner>\.[0-9]{8}\.[0-9]+$`
per-owner) never collides with upstream `dsh-v*` prereleases or
namespaced bundle tags.

## Linux (in-catalog since dsh-linux-support port)

The `dsh-linux-support-1b2e3f10` patch (ported from ImBIOS/.forkhub
PR #5, CI-green there as `v0.2.2-rc.3.imbios.20261114.1`) adds the
`linux-x64` target (AppImage, XDG desktop-entry/WM_CLASS contract,
node-pty `prebuilds/linux-x64`, XDG autostart, per-publisher credit)
on top of the channel patch via this manifest's `apply_order` —
same channel+linux layering as Natively, now in one catalog. The
linux leg runs on `ubuntu-24.04` (Electron 44 smoke SIGSEGVs on
26.04; node 24; `xvfb-run` + `ELECTRON_DISABLE_SANDBOX=1` for the
headless smoke).
