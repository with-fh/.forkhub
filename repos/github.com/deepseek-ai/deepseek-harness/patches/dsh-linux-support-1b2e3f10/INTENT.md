---
id: dsh-linux-support-1b2e3f10
title: DeepSeek Harness Desktop Linux support (linux-x64 target, AppImage, XDG autostart, per-publisher credit)
target_repo: github.com/deepseek-ai/deepseek-harness
target_area: [apps/desktop/scripts/package-target.ts, apps/desktop/scripts/desktop-build-paths.mjs, apps/desktop/scripts/desktop-auto-update-environment.mjs, apps/desktop/scripts/electron-builder-config.mjs, apps/desktop/src/linuxAutostart.ts, apps/desktop/src/main.ts]
status: applied
applied_upstream_pr: none
version: 1.0.0
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-11-06
last_realized_against_commit: ddac96760b6e0df8fa0fe17cbdcf0b512f4c12b2c
realized_against_tag: dsh-v0.2.2-rc.2
verifies_with: vitest run (focused suites, see verify.sh)
upstream_stars: 279830
star_gate: ">=2000 PASS (279830 recorded 2026-11-13)"
depends_on_note: "Applies ONLY on top of with-fh/.forkhub dsh-forkhub-support-0qjj6stm (see manifest depends_on) — never on stock."
---

## Intent

Linux support for the ForkHub DeepSeek Harness Desktop build. Applies
ONLY on top of the `with-fh/.forkhub` update-channel patch — never on
stock. Together they reproduce the upstream mac/Windows behavior on
Linux, with one addition: per-publisher credit that follows the update
publisher dynamically.

Realized 2026-11-13 against upstream `dsh-v0.2.2-rc.1` (`66491b05`); re-derived onto `dsh-v0.2.2-rc.2` (`ddac9676`, latest)
layered on the with-fh channel realization (`3bc80970` in derivation
terms = `dsh-forkhub-support-0qjj6stm` @ with-fh `43bf67a`): 329/329
focused tests green (9 new linux suites (incl. package-selection linux routing) + 320+ gate/spec suites on the
layered tree).

1. **Linux desktop packaging.** New `linux-x64` target alongside
   upstream `mac-arm64 | mac-x64 | win-x64`: `SUPPORTED_TARGETS`,
   `UPDATE_TARGETS`, `TARGETS` + linux-x64 host guard, `--linux/--x64`
   builder flags, `package:linux:x64` (+`:unsigned`, `:dir`) and
   `upload:linux:x64` scripts, `desktop-publish-targets` enum +
   `linux-package.yml` mapping, linux `unsigned` qualification path,
   `localLinuxPackageEnvironment` + `.env.linux.example`, toolchain
   preflight widened to linux (tar only). electron-builder `linux:`
   block expanded: `icon.png`, desktop entry (`Name`, `Comment`,
   `Categories`, `StartupWMClass: 'DeepSeek Harness'`), `target:
   ['AppImage']`. The `linux:` stub existed upstream (dead code) — this
   makes it live.
2. **node-pty linux-x64 prebuilds.** Discussion #49 root cause:
   `Failed to load native module: pty.node, checked: ...,
   prebuilds/linux-x64`. No policy change needed — upstream
   `runtime-file-policy.ts` already keeps
   `prebuilds/<platform>-<arch>` for the active target and linux-x64
   prebuilds ship in the npm closure; the linux-x64 target now flows
   through that retention path instead of throwing `unsupported
   target`. Covered by a retention assertion, not new fixtures.
3. **Per-publisher credit (dynamic).** `DesktopFeedRow` shows
   "Maintained by {owner}" linking to
   `https://github.com/{owner}/.forkhub` whenever the live feed owner
   is neither `with-fh` nor empty — i.e. ImBIOS Linux installs credit
   ImBIOS, with-fh installs stay unbranded default. No hardcoded
   maintainer strings; locale key `desktop.feed.maintainedBy` in all 8
   dicts (repo dicts are `satisfies Record<keyof typeof en>`).
4. **Open-at-login.** New `src/linuxAutostart.ts` (XDG
   `deepseek-harness.desktop` entry manager, `$APPIMAGE`-aware launch
   path, fail-closed) + `openAtLoginGet/Set` IPC pair (`ipc.ts`,
   `main.ts`, `preload-app.ts`) mirroring the channel patch's feed
   pair; linux-only, try/catch, `{success:false}` elsewhere.
5. **No channel drift.** No feed/channel/updater defaults touched —
   the with-fh feed default is untouched by this diff.

## Non-negotiables

1. Applies only on stock+channel checkout (channel patch pinned in
   manifest `depends_on` before realization).
2. Exactly one open-at-login entry; `~/.config/autostart` honored.
3. Credit derives from the live update feed, never hardcoded.
4. Secrets never committed.
5. Focused suites in `verify.sh` only (assumes the channel patch applied).

## Re-derivation instruction

Re-derive with `fh draft` against the pinned tag when upstream cuts a
newer release: apply the channel `reference.diff`, then this patch's
`reference.diff`, run `verify.sh`, adapt hunks that no longer apply to
the same intent (linux target gates + AppImage block + XDG autostart +
per-publisher credit), keep the no-channel-drift boundary, then `fh
satisfied`.
