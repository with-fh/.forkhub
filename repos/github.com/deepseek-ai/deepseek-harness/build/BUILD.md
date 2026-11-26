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

## What each leg builds

| leg | artifacts |
|---|---|
| mac (`macos-26`) | Unsigned DMG and updater manifests |
| win (`windows-latest`) | Unsigned EXE, updater manifests, and block map |
| linux (`ubuntu-24.04`) | AppImage, detached OpenPGP signature, public key, and updater manifests |

The Linux build sets `FORKHUB_LINUX_RELEASE=1` to select the same client
profile as upstream's signed macOS and Windows builds. After electron-builder
finishes, the workflow imports the dedicated OpenPGP signing subkey from
`DSH_LINUX_SIGNING_SUBKEY`, signs the complete AppImage, and verifies the
signature against the checked-in public key. Signing takes place before
publication and checksum generation. Since the signature is detached,
the embedded differential-update block map and SHA-512 stay valid.

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
6. On packaging failure, stages build logs and a patched-source tarball.
   The Linux signing step requires a complete AppImage and updater manifest
   before either release can publish.

## `tagMatch` discipline

Upstream tags are `dsh-vX.Y.Z-*` (e.g. `dsh-v0.2.2-rc.1`) and ALL
current upstream releases are prereleases with zero assets. The workflow
tag pool is the per-target `tag_pool_prefix` (`dsh-v` for this target),
so `upstream.json:tag_match_pattern` is
`^dsh-v[0-9]+\.[0-9]+\.[0-9]+-` to admit them. This catalog's channel tags
are its own `v<base>.<owner>.<date>.<n>` unified updater tags, so the
registry `tagMatch` (`^v[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+\.<owner>\.[0-9]{8}\.[0-9]+$`
per-owner) never collides with upstream `dsh-v*` prereleases or
namespaced bundle tags.

## Linux (in-catalog since dsh-linux-support port)

The `dsh-linux-support-1b2e3f10` patch adds the
`linux-x64` target (AppImage, XDG desktop-entry/WM_CLASS contract,
node-pty `prebuilds/linux-x64`, XDG autostart, per-publisher credit)
on top of the channel patch via this manifest's `apply_order` —
the unified updater release carries the Linux AppImage +
`latest-linux.yml`/`fh-linux.yml`. The
linux leg runs on `ubuntu-24.04` (Electron 44 smoke SIGSEGVs on
26.04; node 24; `xvfb-run` + `ELECTRON_DISABLE_SANDBOX=1` for the
headless smoke).
