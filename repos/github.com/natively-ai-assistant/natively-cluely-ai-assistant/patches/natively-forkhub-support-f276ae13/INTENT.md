---
id: natively-forkhub-support-f276ae13
title: Natively ForkHub support (catalog update feed + publisher input + calendar + dock + linux audio)
target_repo: github.com/natively-ai-assistant/natively-cluely-ai-assistant
target_area: [electron/update/updateFeed.ts, electron/update/updatePublisher.test.mjs, electron/update/updateFeed.test.mjs, electron/update/ReleaseNotesManager.ts, electron/update/ReleaseNotesManager.test.mjs, electron/update/UpdaterAndLifecycleIntegrity2026_08_18.test.mjs, electron/main.ts, electron/ipcHandlers.ts, electron/preload.ts, electron/services/HardwareId.ts, electron/services/__tests__/HardwareId.test.mjs, electron/services/calendarPkce.ts, electron/services/CalendarManager.ts, electron/services/__tests__/CalendarPkce.test.mjs, electron/services/__tests__/ForkPatch2Sources.test.mjs, electron/services/__tests__/LinuxDockAssociation.test.mjs, electron/services/__tests__/LinuxSystemAudio.test.mjs, electron/services/resolveCompanySearchProvider.ts, native-module/Cargo.toml, native-module/Cargo.lock, native-module/src/speaker/linux.rs, native-module/src/speaker/mod.rs, src/components/UpdateBanner.tsx, src/components/UpdateModal.tsx, src/components/AboutSection.tsx, src/components/SettingsOverlay.tsx, src/components/ui/ConnectCalendarButton.tsx, src/types/electron.d.ts, src/lib/trial/trialStart.mjs, src/lib/trial/__tests__/trialStart.test.mjs, package.json, scripts/deb-after-install.sh]
status: applied
applied_upstream_pr: none
version: 1.1.0
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-10-14
last_realized_against_commit: b439c1f0
verifies_with: node --test (focused suites, see verify.sh)
---

## Intent

Add ForkHub support to Natively: the single intent-patch that makes a
stock checkout buildable and self-updating through a ForkHub catalog.
It squashes the four original intents (update-track, fork-ux-and-checks,
linux-dock-icon, publisher-input) with no behavior change — one patch
per software, as the catalog intends.

1. **Catalog update feed.** The app's electron-updater feed,
   release-notes lookup, and manual-download links follow the ForkHub
   catalog (GitHub Releases of a `.forkhub` intent repo, default
   `with-fh/.forkhub`) instead of the upstream author's repo, and the
   free-trial device binding works in open-source / fork builds that
   ship WITHOUT the private `premium/` submodule.
2. **Publisher input.** Settings → Version → ForkHub publisher row: an
   input for the GitHub username/org whose catalog the app updates
   from, with a Check button above the update Check. Typing an owner,
   pressing Check validates the catalog, persists the owner, repoints
   the live updater feed, and immediately checks it.
3. **Fork calendar + resilient checks + dual funding.** Connect calendar
   works with a fork-owned Google client (direct PKCE flow — the stock
   proxy holds upstream's secret); manual version Check never shows a
   bare Error for feed problems (answers from the catalog compare);
   Support funds both upstream and the fork maintainer; About credits
   the fork. The fork flow sends no client secret unless one was
   explicitly provisioned (Google accepts secretless token calls for
   this Desktop client type — verified live), so a build with no
   provisioned secret still connects instead of failing "not configured".
4. **Linux dock identity.** Deterministic WM_CLASS / desktop-entry
   contract so the dock shows the icon and offers pin-to-dock.
5. **Linux system-audio capture.** The native speaker module gains a
   PulseAudio/PipeWire monitor backend (`native-module/src/speaker/
   linux.rs`, backend name `pulse`): the default sink's `*.monitor`
   source is captured via ALSA (`pulse:<monitor>`), resampled to the
   16kHz STT rate by the shared DSP loop. Without it every Linux build
   surfaced `Unsupported platform ... macOS and Windows only` as a red
   FATAL banner in Audio settings; with it the System Audio Level meter
   moves and meetings transcribe system audio.

## Why

Upstream hardcodes its own repo as the update feed and holds the only
OAuth secret and the only signing keys. A patched fork that keeps those
paths is stuck: offered stock builds over its own patches, a dead
calendar button, an unclaimable trial, and an unpinnable Linux icon.
One ForkHub-support patch repoints all of them at the fork's own
catalog and resources, visibly separated from stock.

## Non-negotiables

1. **Single source of truth for the feed.** Owner/repo live in exactly
   one module (`electron/update/updateFeed.ts`), env-overridable via
   `NATIVELY_UPDATE_OWNER` / `NATIVELY_UPDATE_REPO`, defaulting to
   `with-fh/.forkhub`, with a persisted publisher override on top. The
   updater (`setFeedURL`), the builder (`package.json` `publish`),
   release notes, and renderer links all read from it — no second
   hardcoded copy.
2. **Default behavior unchanged.** Fresh installs resolve
   `with-fh/.forkhub`; stock-version gates and the `fh` channel /
   prerelease / no-downgrade updater flags are upstream-identical where
   the fork is unconfigured (proxy calendar flow, placeholder guards,
   stock check event sequences).
3. **No stock/fork cross-talk.** Fork builds never poll upstream
   releases and stock builds never see fork builds. Fork app versions
   carry a `-fh.<owner>.<n>` suffix; the updater runs with
   `allowPrerelease = true` on a feed that contains ONLY fork builds;
   the fork-counter tiebreak orders same-owner rebuilds while
   stock↔fork and cross-owner pairs stay refused. Upstream has no
   `.forkhub` repo, so it can never validate as a publisher.
4. **Validation is releases, not just the account.** Publisher Check
   passes only if the public `{owner}/.forkhub` repo exists AND has at
   least one published, non-draft release (unauthenticated — private
   catalogs unsupported). Nothing persists on failure.
5. **HWID never a placeholder.** `getStableHardwareId()` resolves
   native module → premium `LicenseManager` → OS machine id → persisted
   install id (all SHA-256 hex shaped); it throws rather than returning
   placeholder strings, `trial:start` maps that to `invalid_hwid`
   WITHOUT burning a rate-limit slot, and no raw code reaches the UI.
6. **Contractual dock identity, no profile moves.** The WM_CLASS both
   sides agree on is written into the build config; userData is pinned
   before any rename (Linux-only, pre-disguise); disguise modes still
   rename later; macOS/Windows sequencing untouched.
7. **Exactly one terminal state per Check.** Updater failures surface
   both as a rejected promise AND an async `error` event — one fallback
   run guaranteed; download-time errors still broadcast as before.
8. **Secret optional, never committed.** A fork OAuth client secret,
   when provisioned, arrives only via `build.extraMetadata` (stamped at
   package time) or env, is never logged, and never appears in source.
   Provisioning is optional: unprovisioned builds connect secretless
   (Desktop client type), never failing "not configured" for a missing
   secret — only a missing client id refuses.
9. **No silent UI dead-ends.** Calendar failures render under the
   button; manual compare with no reachable feed broadcasts instead of
   hanging; manual-download fallback never 404s (catalog release page
   on fork feeds, direct asset link only where names are predictable).
10. **No repo-wide test/typecheck runs.** Verify with the focused
    suites in `verify.sh` only.

## Implementation notes

- Realized against upstream `v2.9.2` (commit `b439c1f0`); squashed
  2026-10-14 from update-track v7 + fork-ux-and-checks v4 +
  linux-dock-icon v1 + publisher-input v1 with no behavior change.
- New `electron/update/updateFeed.ts`: feed constants, persisted-owner
  override (`forkhub-updater.json` in userData), `getUpdateFeed()`,
  `normalizeUpdateOwner()`, `checkPublisherCatalog()` (injectable
  fetch), `applyForkFeed()` (runtime twin of the `setupAutoUpdater`
  block — `main.ts` startup untouched, the F-707 source test pins it),
  version/tag/bundle-counter helpers.
- `electron/main.ts` `setupAutoUpdater()`: `setFeedURL({provider:'github',
  owner, repo})`, `channel='fh'`, `allowPrerelease=true`, fork-counter
  tiebreaks in `isRealUpgrade()`/`isVersionNewer()`, catalog-compare
  fallback for manual Checks; Linux-only userData pin + rename.
- `electron/services/HardwareId.ts` (new): ordered HWID resolution.
- `electron/services/calendarPkce.ts` (new): direct PKCE exchange /
  refresh (secret sent only when provisioned); `CalendarManager`
  fork-id resolution (baked extraMetadata → direct, env + flag →
  direct, fork default id → direct) with no fail-fast on a missing
  secret — Connect always opens the browser when a client id exists.
  Exchange/refresh failures keep their readable error under the button.
- `native-module/src/speaker/linux.rs` (new): PulseAudio/PipeWire
  monitor backend (`pulse`); `mod.rs` owns it on
  `#[cfg(target_os = "linux")]`, fallback stub covers remaining
  platforms only. `Cargo.toml` pins the shared `alsa = "=0.9.1"`
  (cpal 0.15's own version — one alsa-sys linkage). No new system
  dependency: libasound + pactl shell-out only.
- `electron/ipcHandlers.ts`: `trial:start` + `license:get-hardware-id`
  via HardwareId; `get-update-feed` + `set-update-feed-owner`
  (validate → persist → repoint live `autoUpdater` → `{ok, owner,
  repo, releases, message}`).
- Renderer: `UpdateBanner`/`UpdateModal` feed-driven fallbacks,
  `SettingsOverlay` publisher row above Version (input + Check +
  valid/invalid status + persisted caption, successful Check
  auto-runs update Check), `AboutSection` dual-support + maintainer
  card, `ConnectCalendarButton` error state, trial `invalid_hwid` →
  friendly copy.
- `package.json` `build.publish`: `with-fh/.forkhub`; `linux.desktop`
  `StartupWMClass`, `deb.afterInstall` hook, deb maintainer stamped at
  build time.
- Open-source build fixes: premium bare-branch `require()`s wrapped in
  try/catch, type-only premium imports localized (byte-identical with
  premium present).
- Linux CI lives beside the patch (`../build/build.sh`, `publish.sh`,
  `BUILD.md`, `CONSUME.md`, `triggers.md`, `../upstream.json`):
  per-OS legs (linux AppImage+deb, mac dmg+zip unsigned, win
  nsis+portable unsigned) into one shared updater release.
- Tests: `updateFeed` + `updatePublisher` + `ReleaseNotesManager` +
  `HardwareId` + `CalendarPkce` + `ForkPatch2Sources` +
  `LinuxDockAssociation` + `LinuxSystemAudio` focused suites; `cargo
  test speaker::linux` (name/pcm-name units) + live napi monitor
  smoke (silence keepalive + tone loopback) verified during
  development.
