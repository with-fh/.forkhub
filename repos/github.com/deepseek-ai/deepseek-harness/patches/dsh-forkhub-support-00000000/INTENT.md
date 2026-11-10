---
id: dsh-forkhub-support-placeholder
title: DeepSeek Harness Desktop ForkHub update channel (DRAFT — re-derive via fh draft)
target_repo: github.com/deepseek-ai/deepseek-harness
target_area: [apps/desktop/src, apps/desktop/electron-builder.config.mjs, apps/desktop/scripts/package-target.ts, apps/desktop/scripts/desktop-build-paths.mjs, apps/desktop/publishing]
status: draft
applied_upstream_pr: none
version: 0.1.0
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-11-06
last_realized_against_commit: null
verifies_with: node --test (focused suites, see verify.sh)
upstream_stars: 274517
star_gate: ">=2000 PASS (274517 recorded 2026-11-06)"
---

## Intent

Add ForkHub support to DeepSeek Harness Desktop: the single
intent-patch that makes a stock checkout buildable and self-updating
through a ForkHub catalog. Mirrors the Natively
`natively-forkhub-support` shape (one update-channel patch per OSS in
`with-fh/.forkhub`); Linux installers ship downstream from the ImBIOS
catalog, which layers `dsh-linux-support` over this patch.

Verified upstream facts (2026-11-06, do not re-derive from memory):

1. Default branch is `master` (not `main`); tags are `dsh-vX.Y.Z-*`
   (e.g. `dsh-v0.2.2-rc.1`); all 10 latest releases are
   `prerelease:true` with `assets:[]` — no desktop binaries ship
   upstream today.
2. `apps/desktop/scripts/package-target.ts`:
   `DesktopPackageTargetName = 'mac-arm64' | 'mac-x64' | 'win-x64'` and
   `SUPPORTED_TARGETS` in `desktop-build-paths.mjs` has no linux entry
   (`resolveDesktopBuildTarget` throws `unsupported target` otherwise).
3. Linux demand is real: discussion #49 (ArchLinux, `node-pty`
   `prebuilds/linux-x64` missing — `Failed to load native module:
   pty.node`) plus the npm `node-pty` postinstall-trust thread.

## Scope (re-derive fully with `fh draft` against the pinned tag)

1. **Catalog update feed.** Desktop auto-update + manual-download links
   follow the ForkHub catalog (GitHub Releases of a `.forkhub` intent
   repo, default `with-fh/.forkhub`) instead of any upstream feed.
   Single source of truth module, env-overridable owner/repo, baked
   `extraMetadata` default stamped at package time, persisted publisher
   override — no second hardcoded copy.
2. **Publisher input.** Settings → Version → ForkHub publisher row with
   Check: typing an owner validates the catalog (public
   `{owner}/.forkhub` repo exists AND has ≥1 published non-draft
   release), persists the owner, repoints the live updater feed, checks
   immediately. Nothing persists on failure; upstream has no `.forkhub`
   repo so it can never validate as a publisher.
3. **Fork rebuild identity.** Fork versions carry `-fh.<owner>.<n>`; the
   updater allows prerelease on a feed that contains ONLY fork builds;
   stock↔fork and cross-owner pairs stay refused. Unsigned mac/Windows:
   Gatekeeper right-click-Open / SmartScreen More-info-Run-anyway notes.
4. **No Linux in this patch.** Linux dock identity, AppImage/deb
   packaging, node-pty linux-x64 prebuilds, open-at-login entry, and
   per-publisher credit live downstream in ImBIOS `dsh-linux-support`
   (`depends_on` this patch) — same split as Natively.

## Non-negotiables

1. Default behavior unchanged: fresh installs resolve
   `with-fh/.forkhub`; stock-version gates and updater flags are
   upstream-identical where the fork is unconfigured.
2. No stock/fork cross-talk: fork builds never poll upstream releases
   and stock builds never see fork builds.
3. Validation is releases, not just the account (public repo + ≥1
   published non-draft release, unauthenticated).
4. `upstream.json:upstream_main_branch` MUST stay `master`.
5. No Linux hunks in this diff (grep for `linuxAutostart`-equivalents,
   AppImage, deb hook, WM_CLASS must be empty).

## Re-derivation instruction

This placeholder exists so the target shape is reviewable. The real
patch MUST be produced by `fh draft` + agent realization against
`dsh-v0.2.2-rc.1` (or newer stable): implement the feed + publisher
input + rebuild identity against the actual
`apps/desktop/scripts/*update*` + `publishing/` code found there,
write focused `verify.sh` suites, then `fh satisfied`.
