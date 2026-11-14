# Acceptance Criteria — dsh-linux-support-1b2e3f10 (APPLIED)

Realized 2026-11-13 against upstream `dsh-v0.2.2-rc.1` (`66491b05`)
layered on with-fh `dsh-forkhub-support-0qjj6stm` (with-fh main
`43bf67a`). 329/329 focused tests green on the layered tree.

## Must pass for promotion to APPLIED — all verified

1. **Linux target gates.** `linux-x64` resolves in build paths,
   auto-update env (`dsh-latest-linux-x64.AppImage`,
   `nightly-linux.yml`), package target (linux-x64 host guard),
   upload plan (AppImage + blockmap, `application/x-appimage`),
   publish targets/route (linux-package.yml, unsigned path), package
   environment (`.env.linux`, `localLinuxPackageEnvironment`), and
   toolchain preflight (tar only). `linux-arm64` still rejects.
2. **AppImage block.** `createElectronBuilderConfig(…, 'linux',
   'x64').linux` carries `icon.png`, desktop entry with
   `StartupWMClass: 'DeepSeek Harness'` equal to the linux
   `app.setName`, `target: ['AppImage']`.
3. **Dock identity.** Linux-only `app.setName('DeepSeek Harness')`
   after `whenReady` (userData path pinned first); policy guard
   accepts linux; `setName` guarded for mocks.
4. **Open-at-login round-trips.** XDG entry write/read/disable,
   spaces quoting, no `%` codes, `$APPIMAGE` preference, `Hidden=true`
   reads OFF, missing file reads OFF, non-linux safely negative.
5. **Per-publisher credit.** Maintainer card shows for non-default
   owners with working `github.com/{owner}/.forkhub` links; default
   with-fh installs show no card; no hardcoded strings.
6. **No channel drift.** This diff touches no feed/channel/updater
   defaults (grep for `updateFeed|setFeedURL|allowPrerelease` in the
   reference diff is empty outside the IPC wiring lines).
7. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.

## How to verify

```sh
sh repos/github.com/deepseek-ai/deepseek-harness/patches/dsh-linux-support-1b2e3f10/verify.sh
```
