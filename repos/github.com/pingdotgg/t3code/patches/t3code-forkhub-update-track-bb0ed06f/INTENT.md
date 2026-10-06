---
id: t3code-forkhub-update-track-bb0ed06f
title: T3 Code ForkHub publisher model with per-publisher trains, x ForkHub brand, update-all nudge, and side-by-side isolation
target_repo: github.com/pingdotgg/t3code
target_area: [packages/contracts/src/ipc.ts, apps/desktop/src/updates/updateChannels.ts, apps/desktop/src/updates/updateMachine.ts, apps/desktop/src/updates/DesktopUpdates.ts, apps/desktop/src/updates/releaseNotes.ts, apps/desktop/src/settings/DesktopAppSettings.ts, apps/desktop/src/ipc/channels.ts, apps/desktop/src/ipc/methods/updates.ts, apps/desktop/src/ipc/DesktopIpcHandlers.ts, apps/desktop/src/preload.ts, apps/web/src/components/forkHub.logic.ts, apps/web/src/components/settings/SettingsPanels.tsx, apps/web/src/components/sidebar/SidebarChrome.tsx, apps/web/src/components/desktopUpdate.logic.ts, apps/web/src/components/desktopUpdate.toast.tsx, apps/mobile/src/components/BrandMark.tsx, scripts/build-desktop-artifact.ts, apps/desktop/src/app/DesktopStatePaths.ts, apps/desktop/src/app/DesktopEnvironment.ts, apps/desktop/src/app/DesktopEarlyElectronStartup.ts, apps/desktop/src/app/DesktopPreReadyPlatform.ts, apps/desktop/src/app/DesktopForkHubStockImport.ts, apps/desktop/src/app/DesktopApp.ts]
status: applied
applied_upstream_pr: none
version: 20
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-09-24
last_realized_against_commit: cfa4f765
verifies_with: node_modules/.bin/vp test run (focused suites, see verify.sh)
---

## Intent

Give T3 Code desktop a third update track called **ForkHub** so patched
forks can ship their own releases without forking the updater: the user picks
"ForkHub" in Settings → Version → Update track, types the GitHub profile or
org whose `.forkhub` releases form the channel, presses **Check** to validate
that account, and the app's electron-updater feed is repointed at that
account's catalog repo at runtime.

## Why

Upstream only ships `latest` (stable) and `nightly`. Anyone running a patched
fork (e.g. via forkhub intent-patches) is stuck: stable/nightly feeds serve
stock builds, so the fork either freezes or hand-installs every release.
A per-owner ForkHub track lets each `.forkhub` publisher be an update channel
for their users, validated before use, with the fork visibly badged so a
patched install is never mistaken for stock.

## Non-negotiables

1. **Default behavior unchanged.** Fresh installs default to `latest`;
   nightly train semantics (prerelease filtering, release-note grouping) are
   byte-for-byte the old behavior. ForkHub code paths only run when the user
   selects the track.
2. **No owner, no feed.** Selecting ForkHub without a validated owner fails
   with `DesktopForkHubOwnerMissingError` ("Set a ForkHub profile or org
   before switching to the ForkHub track."); the updater feed is never
   pointed at an empty or invalid owner. The Check button is the happy
   path: it persists the owner and switches the track in one go.
3. **Validation is releases, not just the account.** Check passes only if
   the public `{owner}/.forkhub` repo exists AND has at least one published,
   non-draft release. A bare account or an empty catalog is rejected with a
   message saying so. Private catalogs are not supported: the check is
   unauthenticated, so only discoverable public releases count.
4. **Side-by-side installs.** ForkHub builds (derived from the version provenance suffix, no build-time flag) are
   named "T3 Code x ForkHub" and the running app badges "x ForkHub" in the
   top-left brand whenever the ForkHub track is active — web sidebar and
   mobile brand mark.
5. **Servers follow the desktop.** After a desktop update downloads and
   before it installs, the UI reminds the user to bring connected T3 Code
   servers to the same version with Update all.
6. **No repo-wide test/typecheck runs.** Verify with the focused suites in
   `verify.sh` only.

## Implementation notes

- `DesktopUpdateChannel` gains `"forkhub"` (contract schema + TS union).
  Update state carries `forkhubOwner` / `forkhubRepo` (null when unset);
  the repo is always `.forkhub`.
- Owner normalization (`normalizeForkHubOwner`, 1–39 chars, GitHub login
  shape) lives in `apps/desktop/src/updates/updateChannels.ts` (main) and is
  mirrored in `apps/web/src/components/forkHub.logic.ts` (renderer); the
  renderer also owns `checkForkHubOwner`, which requires public `.forkhub`
  releases with at least one published release.
- Feed switch is runtime `setFeedURL({provider: "github", owner, repo})`
  plus `channel: "latest"` with prerelease, downgrade, and full-changelog
  enabled (a ForkHub catalog may follow the nightly train, and prerelease
  versions need the flags to install). Switching the owner while on the
  track repoints immediately and drops any staged download from the old feed.
- `isVersionAllowedOnUpdateChannel` keeps nightly on the nightly train and
  stable on release builds; ForkHub allows both stable and nightly-based
  builds and blocks only preview cuts (which ship without a feed).
  Release-note grouping uses the same test, and the release-notes popover
  covers ForkHub like nightly.
- `build.sh` aliases updater manifests across both channel names
  (`latest-*.yml` ↔ `nightly-*.yml`, content is channel-agnostic) because
  the ForkHub track polls `latest` while nightly builds emit `nightly`.
  ForkHub builds always wear production icons, never upstream nightly's.
- New `desktop:update-set-forkhub-owner` IPC (channels, method, handler,
  preload, `DesktopBridge.setForkHubOwner`).
- Settings UI: "ForkHub" select item + owner `Input` with Check button,
  inline valid/invalid status, releases link, success toast that also
  switches the track to ForkHub.
- Release links (toast, notes) resolve to the channel owner's repo on the
  ForkHub track, upstream otherwise.
- `resolveGitHubPublishConfig` accepts `"forkhub"` (release-type publish);
  `resolveDesktopProductName` returns "T3 Code x ForkHub" under
  `T3CODE_FORKHUB_BUILD=1` so CI builds (`build/build.sh`) brand correctly.
- Built versions are `<upstream>.fh.<owner>.<n>` (see `build/BUILD.md`):
  the app's channel patterns treat suffixed nightlies as nightly for
  manifests/icons/defaults, while `isVersionAllowedOnUpdateChannel`
  installs suffixed builds only on ForkHub — stock tracks never touch them.
  The running app brands itself from the same suffix
  (`resolveDesktopAppBranding` → "T3 Code x ForkHub" display name), so no
  build-time flag can get lost between CI and the user's machine.
- CLI needs no code changes: `build.sh` ships the linux-x64 archive
  (`t3-<version>-linux-x64.tar.gz` + `SHA256SUMS`) plus an installable npm
  tarball (`imbios-fh-t3-<version>.tgz`, package `@imbios/fh-t3`, bin
  `t3`, same tree) on the updater release — so `pnpx <asset-URL>` (or
  `fh run t3 ImBIOS`, which resolves the same asset) runs the ForkHub CLI
  with no registry involved, and
  `T3CODE_RELEASE_BASE_URL=<catalog>/releases/download t3 update
  <exact-version>` pins a standalone install (the piece T3 Connect hosts
  are set up through) to the desktop. Channel auto-discovery still points
  upstream (exact versions only for now); linux-arm64/macOS/Windows
  archives need native runners (see `build/BUILD.md`). The catalog
  follows nightly only for now; stable building is disabled.

6. **Stock and ForkHub run side by side.** A ForkHub install keeps its
   own backend home (`~/.t3-forkhub`), Electron profile
   (`t3code-forkhub`), window class, OS app id, and Linux launcher entry,
   so both apps launch together with no shared SQLite/service state, no
   shared Chromium single-instance lock, and no launcher-entry clobbering.
   Backend ports are already picked by free-port scan. An explicit
   `T3CODE_HOME` still wins for both, deliberately. A
   `desktop-settings.json` the ForkHub build cannot decode is quarantined
   to a `.corrupt.bak` sidecar with a warning and startup continues on
   defaults; stock keeps its historical silent-defaults behavior.

7. **First boot adopts stock state.** A fresh ForkHub home (implicit home
   only, never under an explicit `T3CODE_HOME`) copies `desktop-settings`,
   `client-settings`, and `saved-environments` from the stock home before
   the first settings load, so track, owner, prefs, and environments
   survive the switch. Backend identity, credentials, and server settings
   stay fresh per install. A marker file makes it run once; deleting the
   ForkHub home re-arms it.

8. **Publisher model, no ForkHub track.** A ForkHub build is ForkHub by
   version provenance (`.fh.<owner>.<n>`), never by channel: the update
   track stays latest/nightly and selects which train of the publisher's
   `.forkhub` catalog to follow. The retired `forkhub` track value migrates
   to nightly with the publisher preserved. Check reports which trains a
   publisher serves (stable, nightly, both, or invalid). Fresh ForkHub
   homes prefill publisher `with-fh`. Nightly-based ForkHub builds wear
   nightly desktop icons. Provenance and cross-install rules: `.fh`
   versions install on ForkHub builds only, on either track; stock builds
   never flow into ForkHub installs and vice versa.

9. **Tracks follow publisher trains.** The Update track selector only
   offers trains the publisher's catalog serves (with-fh: nightly only).
   Trains persist per publisher, refresh on every Check and once at boot
   on implicit homes (best-effort catalog read; explicit T3CODE_HOME is
   never touched), and the track migrates when the publisher drops it.
   Unknown trains (never checked) leave both tracks.

10. **Trains are authoritative from the catalog manifest.** Tag scans cannot
    tell which target a versioned tag belongs to, so another target's stable
    release in the same catalog repo leaked a phantom Stable track into this
    app's selector. Trains now resolve from this target's `upstream.json`
    manifest in the publisher's catalog first
    (`FORKHUB_T3CODE_UPSTREAM_MANIFEST_PATH`), falling back to the release
    tag scan only for publishers without a manifest entry. Realized against
    upstream `v0.0.43-nightly.20260928.2375` (d15210cd), which also brings
    upstream's Linux .deb support and update-restart tunnel markers under
    the patch.
11. **Installs are named after publisher and train.** ForkHub packaging and
    runtime branding derive the display name from the version provenance,
    e.g. "T3 Code (with-fh, Nightly)", so the launcher entry reads
    `T3 Code (with-fh, Nightly) (<version>)` and one glance tells which
    publisher's which train an install follows. Realized against upstream
    `v0.0.45-nightly.20260930.2468` (0fcd5f90).
12. **Move state with stock T3 Code.** Settings > General > About offers
    Import (stock home into this install) and Export (this install into
    stock) on ForkHub builds. Both directions preview per-file outcomes
    first (new / updated / identical / unreadable / missing, with
    environment and setting counts), then apply with automatic timestamped
    backups. Saved environments merge by id with bearer tokens stripped
    (moved records reconnect with one click, local tokens and timestamps
    kept); prefs merge with the source winning except update identity,
    which never moves either way. Still needs a restart to apply.
13. **Conversations move too.** Import/Export also carries projects with
    their threads: the move copies orchestration events (project + thread
    streams) plus all projection rows for moved ids, and the attachment
    files those messages reference. Streams already present are skipped,
    so reruns are no-ops and nothing ever duplicates. Identity tables
    (auth, pairing, receipts, runtime, projector cursor) are never
    touched; the destination database is snapshotted with VACUUM INTO
    before any write, and table columns intersect so schema drift degrades
    to skipped tables instead of failures. The preview reports project
    titles with thread/message/event counts.
14. **Declared trains are verified against shipped releases.** The
    manifest stays authoritative, but a track is only offered when this
    target's namespaced bundle releases (`<slug>--v<tag>-fh<n>`, the only
    tags that name their target in a shared catalog) actually serve it.
    A declared-but-unbuilt train is never offered; without bundle
    evidence the manifest stands alone, and publishers without a manifest
    keep the legacy tag scan.
15. **Reverted: ForkHub logo builds (v18).** Per publisher request
    the v18 logo work is fully reverted — SVG, generator, icon/web-brand
    wiring, and the CI raster step are gone; ForkHub builds wear train
    icons again (nightly art on the nightly train).

