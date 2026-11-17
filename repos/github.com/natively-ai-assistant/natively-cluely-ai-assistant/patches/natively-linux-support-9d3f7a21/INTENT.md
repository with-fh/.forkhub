---
id: natively-linux-support-9d3f7a21
title: Natively Linux fork support (dock + system audio + open-at-login + per-publisher credit)
target_repo: github.com/natively-ai-assistant/natively-cluely-ai-assistant
target_area: [electron/main.ts, electron/ipcHandlers.ts, electron/utils/linuxAutostart.ts, electron/utils/__tests__/linuxAutostart.test.mjs, electron/utils/windowsTaskbarPolicy.ts, native-module/src/speaker/linux.rs, native-module/src/speaker/mod.rs, native-module/Cargo.toml, native-module/Cargo.lock, package.json, scripts/deb-after-install.sh, src/components/AboutSection.tsx, electron/services/__tests__/ForkPatchLinuxSources.test.mjs, electron/services/__tests__/LinuxDockAssociation.test.mjs, electron/services/__tests__/LinuxSystemAudio.test.mjs]
status: draft
applied_upstream_pr: none
version: 1.0.0
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-11-06
last_realized_against_commit: cdc6995
verifies_with: node --test (focused suites, see verify.sh)
upstream_stars: 3193
star_gate: ">=2000 PASS (3193 recorded 2026-11-17)"
depends_on_note: "Applies ONLY on top of with-fh/.forkhub natively-forkhub-support-f276ae13 (see manifest apply_order) - never on stock."
ported_from: "ImBIOS/.forkhub natively-linux-support-9d3f7a21 v1.0.0 (repo deleted 2026-11; same patch id retained)"
---

## Intent

Linux support for the ForkHub Natively build. Applies ONLY on top of
the `with-fh/.forkhub` update-channel patch
(`natively-forkhub-support-f276ae13`, `depends_on` below) — never on
stock. Together they reproduce the previous combined build, with one
improvement: the About credit now follows the update publisher
dynamically instead of hardcoding one maintainer.

1. **Linux dock identity.** Deterministic WM_CLASS / desktop-entry
   contract so the dock shows the icon and offers pin-to-dock:
   `main.ts` pins userData then sets the product name before any
   window (Linux-only); `package.json` declares
   `linux.desktop.entry.StartupWMClass=Natively`; the deb postinst
   hook refreshes desktop/icon caches.
2. **Linux system-audio capture.** The native speaker module gains a
   PulseAudio/PipeWire monitor backend
   (`native-module/src/speaker/linux.rs`, backend name `pulse`): the
   default sink's `*.monitor` source is captured via ALSA
   (`pulse:<monitor>`), resampled to the 16kHz STT rate by the shared
   DSP loop. Without it every Linux build surfaced `Unsupported
   platform ... macOS and Windows only` as a red FATAL banner in Audio
   settings; with it the System Audio Level meter moves and meetings
   transcribe system audio.
3. **Linux open-at-login that works.** Settings → "Open Natively when
   you log in" writes and reads
   `~/.config/autostart/natively.desktop` itself
   (`electron/utils/linuxAutostart.ts`, routed through
   `windowsTaskbarPolicy.ts`), because Electron's login-item API is a
   no-op on Linux and the toggle previously wrote nothing and always
   read OFF. The entry carries `StartupWMClass=Natively` (dock
   grouping) and `TryExec` so a removed binary is skipped, not
   errored; IPC reports the real `{success}`. The launch path is
   resolved at write time: AppImage runs record `$APPIMAGE` (the
   stable host path) instead of the dead FUSE mountpoint
   `app.getPath('exe')` returns, so the entry survives logout/login.
4. **Per-publisher credit (dynamic).** The About Support button opens
   the original creator link AND the current update publisher's
   sponsors page (`https://github.com/sponsors/<owner>/`), and the
   maintainer card shows only on fork-catalog builds, linking that
   publisher's GitHub profile + sponsors page. The publisher is the
   account whose `.forkhub` catalog the install updates from
   (`get-update-feed` IPC) — never hardcoded, so each fork credits
   itself. On stock/upstream feeds the card hides and funding falls
   back to upstream only.

## Why

The `with-fh` catalog intentionally ships no Linux leg for Natively
(channel-only patch, mac + win). Linux installers (AppImage + deb)
ship from the with-fh catalog, which layers this patch over the
`with-fh` channel patch. The with-fh build stamps
`NATIVELY_UPDATE_OWNER=with-fh` at package time so its default feed is
the with-fh catalog (user-overridable via the publisher input), and
bakes its own `NATIVELY_GOOGLE_CLIENT_ID` /
`NATIVELY_GOOGLE_CLIENT_SECRET` for the fork calendar flow the channel
patch provides (per-owner OAuth clients — secrets never committed).

## Non-negotiables

1. **Applies only on stock+A checkout.** Never touches feed, channel,
   `allowPrerelease`, version gates, or publisher logic — `grep -n
   allowPrerelease updateFeed main.ts` in this diff is empty by
   construction. Re-derive against the pinned `with-fh` ref.
2. **Exactly one open-at-login entry.** On Linux the patch writes at
   most one file: `~/.config/autostart/natively.desktop` (honoring
   `$XDG_CONFIG_HOME`). No per-disguise copies, no second filename —
   a stale entry from a moved AppImage reads OFF so a re-toggle heals
   it, and disabling deletes the file. macOS/Windows paths keep the
   exact upstream Electron calls.
3. **No hardcoded maintainer identity.** Credit derives from the live
   update feed. A fork that publishes under another owner gets its own
   card + sponsors links with zero patch changes.
4. **Secret required for calendar, never committed.** The fork-owner OAuth
   client secret arrives only via `build.extraMetadata` (stamped at
   package time from `NATIVELY_GOOGLE_CLIENT_SECRET`) or env, is never
   logged, and never appears in source.
5. **No repo-wide test/typecheck runs.** Verify with the focused
   suites in `verify.sh` only (assumes the channel patch applied).

## Implementation notes

- Realized against upstream `v3.0.0` (commit `cdc6995`) layered over
  `with-fh` `natively-forkhub-support-f276ae13` v2.0.0.
- `electron/utils/linuxAutostart.ts` (new): XDG Autostart entry
  manager (`~/.config/autostart/natively.desktop`, `$XDG_CONFIG_HOME`
  honored, `StartupWMClass=Natively`, `TryExec` guard, `$APPIMAGE`
  launch-path resolution);
  `windowsTaskbarPolicy.ts` routes `linux` through it while
  win32/darwin keep the exact upstream Electron calls; `ipcHandlers`
  `set-open-at-login` reports the real `{success}` and
  `get-open-at-login` is fail-closed.
- `native-module/src/speaker/linux.rs` (new): PulseAudio/PipeWire
  monitor backend (`pulse`); `mod.rs` owns it on
  `#[cfg(target_os = "linux")]`, fallback stub covers remaining
  platforms only. `Cargo.toml` pins the shared `alsa = "=0.9.1"`
  (cpal 0.15's own version — one alsa-sys linkage). No new system
  dependency: libasound + pactl shell-out only.
- `package.json` `linux.desktop` `StartupWMClass`, `deb.afterInstall`
  hook, deb maintainer stamped at build time.
- with-fh build stamps `NATIVELY_UPDATE_OWNER=with-fh` (default feed =
  with-fh catalog) and its own Google OAuth client id/secret;
  the Linux leg runs on `ubuntu-24.04` and publishes the AppImage +
  deb into the shared unified updater release.
- Tests: `LinuxDockAssociation` + `LinuxSystemAudio` +
  `linuxAutostart` + `windowsTaskbarPolicy` (upstream-owned,
  unmodified, regression guard) + `ForkPatchLinuxSources` focused
  suites; `cargo test speaker::linux` (name/pcm-name units) + live
  napi monitor smoke verified during development of the original
  combined patch.
