# Acceptance Criteria — natively-linux-support-9d3f7a21

The with-fh Linux fork-support patch for Natively (ported from the deleted ImBIOS catalog, same patch id). Applies on top of
`with-fh` `natively-forkhub-support-f276ae13` (see `depends_on` in
`manifest.json`).

## Must pass for promotion to APPLIED

1. **Deterministic Linux dock identity.** userData pinned before
   rename, rename before any window (Linux-only), `StartupWMClass`
   contract in build config, guarded postinst hook
   (`LinuxDockAssociation.test.mjs`).
2. **Linux system audio captures.** `pulse` backend owns
   `#[cfg(target_os = "linux")]`; `SpeakerInput::new` succeeds, stream
   opens the default monitor, `backend_name() == "pulse"`, fallback stub
   no longer claims Linux unsupported (`LinuxSystemAudio.test.mjs` +
   `cargo test speaker::linux`).
3. **Linux open-at-login round-trips.** Enabling writes exactly one
   `natively.desktop` entry (valid per `desktop-file-validate`,
   `StartupWMClass=Natively`, `TryExec` = exe, quoted `Exec`);
   reading reflects the file (ON after enable, OFF after disable,
   OFF for missing/stale/Hidden/unparseable entries); disabling
   deletes it; win32/darwin call shapes are unchanged
   (`linuxAutostart.test.mjs`). The written Exec is the stable
   AppImage host path (`$APPIMAGE`), never the dead FUSE mountpoint
   `app.getPath('exe')` returns inside an AppImage run — a mountpoint
   entry reads OFF after relogin, prompting a healing re-toggle; the
   stale-path suite pins this.
4. **Per-publisher credit.** On a fork-catalog feed the About card
   shows the feed owner with working profile/sponsors links, and the
   Support button opens upstream donate + the publisher's sponsors
   page; on an upstream feed the card hides and no hardcoded owner
   strings exist anywhere (`ForkPatchLinuxSources.test.mjs`).
5. **No channel drift.** This patch contains no `allowPrerelease`,
   no `channel =`, no `setFeedURL`, no `UPDATE_FEED_OWNER` default
   change; the `with-fh` feed default is untouched by this diff.
6. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.

## How to verify

```bash
sh repos/github.com/natively-ai-assistant/natively-cluely-ai-assistant/patches/natively-linux-support-9d3f7a21/verify.sh
```
