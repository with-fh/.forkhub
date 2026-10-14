---
id: natively-forkhub-publisher-input-80809dbc
title: ForkHub publisher input above the update check (per-owner catalog feed at runtime)
target_repo: github.com/natively-ai-assistant/natively-cluely-ai-assistant
target_area: [electron/update/updateFeed.ts, electron/ipcHandlers.ts, electron/preload.ts, src/types/electron.d.ts, src/components/SettingsOverlay.tsx, electron/update/updatePublisher.test.mjs]
status: draft
applied_upstream_pr: none
version: 1
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

Give fork installs a Settings → Version → **ForkHub publisher** row —
an input for the GitHub username/org whose `.forkhub` catalog the app
updates from, with a Check button directly above the existing update
Check button (T3 Code parity: same input + Check + valid/invalid status
pattern as the ForkHub publisher row).

Today the feed owner is baked (`with-fh`, env-overridable only at
launch). A user following any other publisher's catalog (their own
`.forkhub` fork, a mirror, a future org move) must hand-edit env or
reinstall. After this patch: type the owner, press Check — the app
validates the catalog, persists the owner, repoints the live updater
feed, and immediately runs an update Check against it.

## Why

Upstream has no per-publisher concept; the update-track patch fixed the
feed at one catalog. ForkHub's model is per-owner catalogs (T3 serves
`with-fh` today, other publishers tomorrow), so every forked desktop
needs the same owner picker or users are pinned to whoever baked the
build. Realizing it as a fourth intent (applied after the dock-icon
patch) keeps the feed/HWID/calendar/dock patches independently
re-derivable.

## Non-negotiables

1. **Single source of truth for the feed.** Owner/repo still live in
   exactly one module (`electron/update/updateFeed.ts`):
   persisted override → `NATIVELY_UPDATE_OWNER`/`NATIVELY_UPDATE_REPO`
   env → baked default. The updater, release notes, and renderer links
   all read from it — the input writes through it, never around it.
2. **Default behavior unchanged.** Fresh installs (nothing persisted,
   no env) resolve `with-fh/.forkhub` exactly as before; stock-version
   gates and the `fh` channel / prerelease / no-downgrade updater flags
   are byte-for-byte the update-track behavior.
3. **Validation is releases, not just the account.** Check passes only
   if the public `{owner}/.forkhub` repo exists AND carries at least one
   published, non-draft release (unauthenticated — private catalogs
   unsupported, T3 parity). A bare account or empty catalog is rejected
   with a message saying so; nothing is persisted on failure.
4. **No stock/fork cross-talk.** The updater keeps the `fh` channel,
   `allowPrerelease`, and the fork-counter gates after a repoint, and
   upstream has no `.forkhub` repo so it can never validate — a fork
   build can never be switched onto stock releases (or vice versa).
5. **Exactly one persisted shape.** The override is one JSON file
   (`forkhub-updater.json` in userData, `{owner}` only); unreadable or
   malformed files fall back to env/default, never throw. `main.ts`
   startup is untouched (the F-707 source test pins its feed block) —
   the runtime repoint is its documented twin.
6. **No repo-wide test/typecheck runs.** Verify with the focused suites
   in `verify.sh` only.

## Implementation notes

- `electron/update/updateFeed.ts`: `normalizeUpdateOwner()`
  (GitHub login shape, lowercased), `readPersistedUpdateOwner()` /
  `writePersistedUpdateOwner()` (lazy electron require — plain-node
  importable, same pattern as `readBakedBundleN`), `getUpdateFeed()`
  prefers persisted → env → default, `summarizePublisherReleases()` /
  `checkPublisherCatalog()` (injectable fetch for tests), and
  `applyForkFeed()` (channel `fh` + restore `allowDowngrade=false`
  after the setter clobber + `setFeedURL` + `allowPrerelease` —
  runtime twin of the `setupAutoUpdater` block).
- `electron/ipcHandlers.ts`: `set-update-feed-owner` validates via
  `checkPublisherCatalog`, persists, repoints the live `autoUpdater`
  from `electron-updater`, and returns `{ok, owner, repo, releases,
  message}` (never throws — failures return `ok:false`).
- `electron/preload.ts` + `src/types/electron.d.ts`:
  `setUpdateFeedOwner` bridge + result type.
- `src/components/SettingsOverlay.tsx`: publisher row above the
  Version row (Globe tile, input placeholder `with-fh`, Enter submits,
  Check button, valid/invalid status lines, persisted `owner/repo`
  caption); effective feed loaded on open via `getUpdateFeed`; a
  successful Check auto-runs the existing update Check against the new
  feed.
- Tests: `electron/update/updatePublisher.test.mjs` (normalize matrix,
  release classifier, catalog-check outcomes with stub fetch, feed-flag
  order incl. the F-707 restore-after-clobber, plain-node default
  feed).
