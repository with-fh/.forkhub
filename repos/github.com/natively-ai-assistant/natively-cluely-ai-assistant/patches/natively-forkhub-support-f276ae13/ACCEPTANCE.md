# Acceptance Criteria — natively-forkhub-support-f276ae13

The one ForkHub-support patch for Natively (squash of update-track,
fork-ux-and-checks, linux-dock-icon, publisher-input — no behavior
change).

## Must pass for promotion to APPLIED

1. **Feed is the catalog.** `getUpdateFeed()` returns
   `{owner:'with-fh', repo:'.forkhub'}` by default, honors
   `NATIVELY_UPDATE_OWNER` / `NATIVELY_UPDATE_REPO` env, then a
   persisted publisher override; `package.json` `build.publish` points
   at the same repo; `setupAutoUpdater()` calls `setFeedURL` with it,
   follows channel `fh`, and sets `allowPrerelease=true`
   (`updateFeed.test.mjs`, `updatePublisher.test.mjs`).
2. **Publisher input.** Owner normalization, catalog validation
   (public repo + ≥1 published non-draft release; distinct messages for
   bad input / empty / 404 / 403 / 500 / offline), and runtime repoint
   keeping the fork flags (`updatePublisher.test.mjs`).
3. **Fork rebuilds pass the gate.** `isForkCounterUpgrade` orders
   same-owner `-fh.<owner>.<n>` counters and refuses stock↔fork and
   cross-owner pairs; `isRealUpgrade` / `isVersionNewer` fall through
   to it on numeric ties, with stock-version behavior unchanged.
4. **Catalog version handling.** `extractVersionFromTag` handles plain,
   suffixed, and namespaced tags; `apiReleaseUrl('latest')` throws;
   `ReleaseNotesManager` resolves `latest` via list+prefix-filter.
5. **No placeholder HWID.** Stable 64-hex id, never placeholder, on a
   submodule-less checkout; `trial:start` returns `invalid_hwid`
   without POSTing when no stable id exists (`HardwareId.test.mjs`).
6. **Fork calendar + checks.** Direct PKCE flow with fork client id
   (baked or env), byte-identical proxy otherwise; exactly one terminal
   state per manual Check; failures render in UI, never silent
   (`CalendarPkce.test.mjs`, `ForkPatch2Sources.test.mjs`).
7. **Deterministic Linux dock identity.** userData pinned before
   rename, rename before any window (Linux-only), `StartupWMClass`
   contract in build config, guarded postinst hook
   (`LinuxDockAssociation.test.mjs`).
8. **No raw codes / no 404 fallbacks.** Friendly trial copy, catalog
   release-page fallback on fork feeds.
9. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.

## How to verify

```bash
sh repos/github.com/natively-ai-assistant/natively-cluely-ai-assistant/patches/natively-forkhub-support-f276ae13/verify.sh
```
