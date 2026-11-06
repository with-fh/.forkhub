---
id: natively-forkhub-support-f276ae13
title: Natively ForkHub update channel (catalog feed + publisher input + resilient checks + fork calendar + OSS trial binding)
target_repo: github.com/natively-ai-assistant/natively-cluely-ai-assistant
target_area: [electron/update/updateFeed.ts, electron/update/updatePublisher.test.mjs, electron/update/updateFeed.test.mjs, electron/update/ReleaseNotesManager.ts, electron/update/ReleaseNotesManager.test.mjs, electron/update/UpdaterAndLifecycleIntegrity2026_08_18.test.mjs, electron/main.ts, electron/ipcHandlers.ts, electron/preload.ts, electron/services/HardwareId.ts, electron/services/__tests__/HardwareId.test.mjs, electron/services/calendarPkce.ts, electron/services/CalendarManager.ts, electron/services/__tests__/CalendarPkce.test.mjs, electron/services/__tests__/ForkPatch2Sources.test.mjs, electron/services/resolveCompanySearchProvider.ts, src/components/UpdateBanner.tsx, src/components/UpdateModal.tsx, src/components/SettingsOverlay.tsx, src/components/ui/ConnectCalendarButton.tsx, src/types/electron.d.ts, src/lib/trial/trialStart.mjs, src/lib/trial/autoTrial.mjs, src/lib/trial/__tests__/trialStart.test.mjs, package.json]
status: applied
applied_upstream_pr: none
version: 2.0.0
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-10-14
last_realized_against_commit: cdc6995
verifies_with: node --test (focused suites, see verify.sh)
---

## Intent

Add ForkHub support to Natively: the single intent-patch that makes a
stock checkout buildable and self-updating through a ForkHub catalog.
It squashes the four original intents (update-track, fork-ux-and-checks,
publisher-input, fork calendar) with no behavior change — one patch
per software, as the catalog intends.

This patch is the ForkHub UPDATE CHANNEL. It is the only patch in
`with-fh/.forkhub` for this target, and the `with-fh` build itself must
stay functional with this patch alone. Linux support lives downstream
in `ImBIOS/.forkhub` (`natively-linux-support`, `depends_on` this
patch), so the combined ImBIOS build keeps today's behavior.

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
3. **Fork calendar + resilient checks.** Connect calendar works with a
   fork-owned Google client (direct PKCE flow — the stock flow holds
   upstream's secret); manual version Check never shows a bare Error
   for feed problems (answers from the catalog compare). The fork flow
   sends the provisioned client secret when one exists (Google rejects
   secretless token calls with 400 `client_secret is missing` —
   verified live 2026-10-26), so calendar needs
   NATIVELY_GOOGLE_CLIENT_SECRET baked at package time; without it the
   flow fails with the honest not-configured copy instead of hanging.
4. **Minimum OSS-runnability (documented exception, not channel).**
   The `with-fh` catalog builds ship WITHOUT the private `premium/`
   submodule, so without these hunks `npm run build:electron` fails
   (esbuild cannot resolve the bare `premium/` requires) and every
   trial binds to the `'unavailable'` sentinel and is rejected. The
   `HardwareId` fallback chain, the `trial:start` /
   `license:get-hardware-id` rewiring, the `invalid_hwid` renderer
   mapping, and the two premium try/catch guards exist so this patch
   ALONE yields a working build — they are not Linux and not branding,
   and they cannot move downstream without regressing the `with-fh`
   build. Branding/credit (About maintainer card) is intentionally NOT
   here: credit follows the update publisher dynamically and lives in
   the downstream ImBIOS patch.

## Why

Upstream hardcodes its own repo as the update feed and holds the only
OAuth secret and the only signing keys. A patched fork that keeps those
paths is stuck: offered stock builds over its own patches, a dead
calendar button, and an unclaimable trial. One ForkHub-support patch
repoints all of them at the fork's own catalog and resources, visibly
separated from stock. Linux specifics (dock identity, system-audio
capture, open-at-login, deb hook, per-publisher credit) are a separate
downstream concern.

## Non-negotiables

1. **Single source of truth for the feed.** Owner/repo live in exactly
   one module (`electron/update/updateFeed.ts`), overridable via
   `NATIVELY_UPDATE_OWNER` / `NATIVELY_UPDATE_REPO` env, then a baked
   `build.extraMetadata.forkhubUpdateOwner/Repo` default (stamped at
   package time; `with-fh` ships unstamped), then the `with-fh/.forkhub`
   hardcoded default, with a persisted publisher override on top. The
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
6. **Exactly one terminal state per Check.** Updater failures surface
   both as a rejected promise AND an async `error` event — one fallback
   run guaranteed; download-time errors still broadcast as before.
7. **Secret required for calendar, never committed.** The fork OAuth
   client secret arrives only via `build.extraMetadata` (stamped at
   package time) or env, is never logged, and never appears in source.
   Calendar REQUIRES it baked: without it Google answers 400
   `client_secret is missing` (verified live), and the app surfaces the
   honest "Calendar isn't set up for this build yet" copy. Add
   NATIVELY_GOOGLE_CLIENT_SECRET in repo Settings → Secrets.
8. **No silent UI dead-ends.** Calendar failures render under the
   button; manual compare with no reachable feed broadcasts instead of
   hanging; manual-download fallback never 404s (catalog release page
   on fork feeds, direct asset link only where names are predictable).
9. **No repo-wide test/typecheck runs.** Verify with the focused
   suites in `verify.sh` only.
10. **Linux hunks live downstream.** This patch never touches
    `linuxAutostart`, speaker backends, `linux.desktop`, the deb hook,
    the Linux dock block in `main.ts`, or the About credit — those
    belong to `ImBIOS/.forkhub` `natively-linux-support`. The
    `with-fh` legs do not ship Linux features (no Linux leg runs
    against this catalog build release flow for Natively).

## Implementation notes

- Realized against upstream `v3.0.0` (commit `cdc6995`); squashed
  2026-10-14 from update-track v7 + fork-ux-and-checks v4 +
  publisher-input v1 with no behavior change; fork calendar direct flow
  added as intent change (MINOR, secret REQUIRED — secretless token
  calls 400 at Google, verified live 2026-10-26).
- v2.0.0 is a scope redefinition (MAJOR): the Linux hunks (dock
  identity, system-audio backend, open-at-login entry, deb hook,
  per-publisher About credit) move to the downstream
  `natively-linux-support` patch in `ImBIOS/.forkhub`. Combined
  `with-fh` + `ImBIOS` output is behavior-identical to v1.2.1 modulo
  the About card (now dynamic per publisher) and the split test files.
- New `electron/update/updateFeed.ts`: feed constants, persisted-owner
  override (`forkhub-updater.json` in userData), `getUpdateFeed()`,
  `normalizeUpdateOwner()`, `checkPublisherCatalog()` (injectable
  fetch), `applyForkFeed()` (runtime twin of the `setupAutoUpdater`
  block — `main.ts` startup untouched, the F-707 source test pins it),
  version/tag/bundle-counter helpers. Resolution order is
  persisted → `NATIVELY_UPDATE_OWNER` env → baked
  `build.extraMetadata.forkhubUpdateOwner/Repo` (stamped at package
  time by fork catalogs; `with-fh` ships unstamped so its default stays
  `with-fh/.forkhub`) → hardcoded default — the `ForkPatch2Sources`
  baked-default test pins the chain.
- `electron/main.ts` `setupAutoUpdater()`: `setFeedURL({provider:'github',
  owner, repo})`, `channel='fh'`, `allowPrerelease=true`, fork-counter
  tiebreaks in `isRealUpgrade()`/`isVersionNewer()`, catalog-compare
  fallback for manual Checks.
- `electron/services/HardwareId.ts` (new): ordered HWID resolution.
- `electron/services/calendarPkce.ts` (new): direct PKCE exchange /
  refresh (secret forwarded when provisioned — REQUIRED, Google 400s
  without it); `CalendarManager` fork-id resolution (baked
  extraMetadata → direct, env + flag → direct, fork default id →
  direct). Connect opens the browser when a client id exists; a missing
  or rejected secret surfaces the named not-configured error under the
  button via the callback error path, never a hang.
- `electron/ipcHandlers.ts`: `trial:start` + `license:get-hardware-id`
  via HardwareId; `get-update-feed` + `set-update-feed-owner`
  (validate → persist → repoint live `autoUpdater` → `{ok, owner,
  repo, releases, message}`).
- Renderer: `UpdateBanner`/`UpdateModal` feed-driven fallbacks,
  `SettingsOverlay` publisher row above Version (input + Check +
  valid/invalid status + persisted caption, successful Check
  auto-runs update Check), `ConnectCalendarButton` error state, trial
  `invalid_hwid` → friendly copy.
- `package.json` `build.publish`: `with-fh/.forkhub` (the `linux`
  desktop/deb stanzas live downstream).
- Open-source build fixes: premium bare-branch `require()`s wrapped in
  try/catch, type-only premium imports localized (byte-identical with
  premium present).
- Linux CI lives beside the patch (`../build/build.sh`, `publish.sh`,
  `BUILD.md`, `CONSUME.md`, `triggers.md`, `../upstream.json`): per-OS
  legs (mac dmg+zip unsigned, win nsis+portable unsigned) into one
  shared updater release. The `with-fh` build does NOT run a Linux leg
  for Natively (no `ubuntu-latest` entry for this target's release
  flow); Linux installers ship from the downstream ImBIOS catalog.
- Tests: `updateFeed` + `updatePublisher` + `ReleaseNotesManager` +
  `HardwareId` + `CalendarPkce` + `ForkPatch2Sources` focused suites;
  `windowsTaskbarPolicy.test.mjs` (upstream-owned, unmodified) runs as
  a regression guard.
