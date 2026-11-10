---
id: dsh-forkhub-support-0qjj6stm
title: DeepSeek Harness Desktop ForkHub update channel: catalog feed + publisher input + fork rebuild identity
target_repo: github.com/deepseek-ai/deepseek-harness
target_area: [apps/desktop/scripts/electron-builder-config.mjs, apps/desktop/src/forkVersion.ts, apps/desktop/src/ipc.ts, apps/desktop/src/main.ts, apps/desktop/src/preload-app.ts, apps/desktop/src/update-coordinator.ts, apps/desktop/src/updateFeed.ts, apps/desktop/tests/forkhub-fork-version.spec.ts, apps/desktop/tests/forkhub-update-feed.spec.ts, packages/client/ui-settings-general/src/client/DesktopFeedRow.tsx, packages/client/ui-settings-general/src/client/desktop-feed-source.ts, packages/client/ui-settings-general/src/client/index.ts, packages/client/ui-settings-general/src/client/locales.ts, packages/client/ui-settings-general/src/types.ts, packages/client/ui-settings-general/tests/desktop-feed.client.spec.ts]
status: applied
applied_upstream_pr: none
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-11-10
last_realized_against_commit: fcc0ad4
verifies_with: bun test
---

## Intent

DeepSeek Harness Desktop ForkHub update channel: catalog feed + publisher input + fork rebuild identity

## Why

Upstream hardcodes its Tencent COS feed, holds the only signing keys, and
ships no desktop binaries at all. A patched fork that keeps those paths is
stuck: offered stock builds over its own patches and no Linux story. One
ForkHub-support patch repoints the feed at the fork's own catalog
(`with-fh/.forkhub`), with the update publisher selectable per install and
fork rebuilds visibly separated from stock. Linux specifics (dock identity,
AppImage/deb packaging, node-pty linux-x64 prebuilds, open-at-login entry,
per-publisher credit) are a separate downstream concern in ImBIOS
`dsh-linux-support` (`depends_on` this patch) — same split as Natively.

## Non-negotiables

1. **Single source of truth for the feed.** Owner/repo live in exactly one
   module (`apps/desktop/src/updateFeed.ts`), overridable via
   `DSH_UPDATE_OWNER` env, then a baked
   `build.extraMetadata.forkhubUpdateOwner` default (stamped at package
   time; `with-fh` ships unstamped), then the `with-fh/.forkhub` hardcoded
   default, with a persisted publisher override on top. The live updater
   (`setFeedURL`), builder publish config, and renderer links all read
   from it — no second hardcoded copy.
2. **Default behavior unchanged.** Fresh installs resolve
   `with-fh/.forkhub`; stock channel semantics and the fork-counter
   updater flags are upstream-identical where the fork is unconfigured.
3. **No stock/fork cross-talk.** Fork builds never poll upstream releases
   and stock builds never see fork builds. Fork app versions extend the
   product prerelease in DSH's native `<base>.<date>.<n>` form with the
   owner folded in (`0.2.2-rc.1.with-fh.<date>.<n>` — the build validator
   requires the extension); the updater runs with `allowPrerelease = true`
   on a feed that contains ONLY fork builds; the fork-counter tiebreak
   orders same-owner rebuilds while stock<->fork and cross-owner pairs
   stay refused. Upstream has no `.forkhub` repo, so it can never validate
   as a publisher.
4. **Validation is releases, not just the account.** Publisher Check
   passes only if the public `{owner}/.forkhub` repo exists AND has at
   least one published, non-draft release (unauthenticated — private
   catalogs unsupported). Nothing persists on failure.
5. **No Linux hunks in this diff.** No AppImage, deb hook, WM_CLASS /
   desktop-entry, node-pty prebuild changes (grep for linuxAutostart
   equivalents, AppImage, deb hook, WM_CLASS is empty) — those belong to
   ImBIOS `.forkhub` `dsh-linux-support`.
6. **No repo-wide test/typecheck runs.** Verify with the focused suites
   in `verify.sh` only.

## Implementation notes

- Realized against upstream master `fcc0ad4` (merge of `dsh-v0.2.2-rc.1`);
  277k stars (>= 2k gate).
- New `apps/desktop/src/updateFeed.ts`: feed constants, persisted-owner
  override, `getUpdateFeed()`, `normalizeUpdateOwner()`,
  `checkPublisherCatalog()` (injectable fetch), baked-default reader.
  Resolution order is persisted → `DSH_UPDATE_OWNER` env → baked
  `build.extraMetadata.forkhubUpdateOwner` (stamped at package time by
  fork catalogs; `with-fh` ships unstamped so its default stays
  `with-fh/.forkhub`) → hardcoded default.
- `update-coordinator.ts`: constructor repoints the live updater via
  `applyForkHubFeed()` (`setFeedURL({provider:'github', owner, repo})`,
  `allowPrerelease=true`); `doCheck()` enforces the fork-counter gate
  (`isForkCounterUpgrade`) with stock pairs on semver.
- New `apps/desktop/src/forkVersion.ts`: owner-stamped identity
  `<base>.<owner>.<date8>.<n>`; pure-numeric segments stay dates (the
  owner field must contain a letter, so stock date-builds never parse as
  fork builds).
- `electron-builder-config.mjs` stamps `forkhubUpdateOwner` from
  `DSH_UPDATE_OWNER` at package time (baked default only).
- `main.ts`/`ipc.ts`/`preload-app.ts` + `ui-settings-general` types:
  `updatesFeedGet`/`updatesFeedSet` (validate → persist → repoint live
  `autoUpdater` → `{ok, owner, repo, releases, message}`); renderer
  `DesktopFeedRow` publisher input above Version with per-locale copy
  (zh/en/ja/es/fr/de/ru/pt).
- Tests: `forkhub-update-feed` + `forkhub-fork-version` + `desktop-feed`
  focused suites; `update-coordinator` + `main-startup` + `preload-app` +
  `desktop-channel` run as regression guards.
- Catalog build: `build/build.sh` packs per-OS unsigned installers
  (`macos-26`, `windows-latest`) and `build/publish.sh` uploads them
  into the shared `v<version>` updater release; fork tags are
  `dsh-v<base>-fh.<owner>.<n>`-derived per BUILD.md tagMatch discipline.

