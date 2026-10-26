# Natively ForkHub — use this build (all OSs)

Patched Natively that updates from the ForkHub catalog instead of upstream.
Same app, same data — installing it replaces a stock install and keeps
everything, then it self-updates from here.

## Install

- **Linux:** the `natively_*_amd64.deb` below (recommended — installs a
  system-wide desktop entry + icon, so the dock shows the app and offers
  pin-to-dock), or the `Natively-*-x86_64.AppImage` (`chmod +x`, then run).
  The AppImage carries the same `StartupWMClass` contract, so with
  [AppImageLauncher](https://github.com/TheAssassin/AppImageLauncher)
  (or `appimaged`) it integrates too — one click moves it to
  `~/Applications` and registers the desktop entry, with dock
  pinning working the same way. A bare `chmod +x` + run with no
  integration daemon is the only setup with no registered entry.
  Either way the in-app updater (Settings → Version → Check) self-updates
  the AppImage in place; the `.deb` additionally updates through apt.
- **macOS (unsigned):** the `Natively-*-arm64.dmg` (Apple Silicon) or
  `Natively-*-x64.dmg` (Intel). First launch: right-click → Open (the
  fork carries no Developer ID signature, so Gatekeeper blocks a plain
  double-click; the app is otherwise identical).
- **Windows (unsigned):** `Natively-Setup-*.exe` (installer) or the
  portable `*.exe`. SmartScreen will warn (unsigned fork build) — More
  info → Run anyway.

## Trial & updates

1. **Trial works out of the box** — no sign-in; the free trial binds to
   this device via the open-source hardware-ID fallback.
2. **Updates are automatic**: Settings → Version → Check. New ForkHub
   builds install in place and relaunch. To follow a different
   publisher's catalog, set the ForkHub publisher above the Check button
   first (it validates, repoints the feed, and checks immediately).

System audio capture on Linux follows upstream requirements (PipeWire);
if the source tarball is all you need, the matching
`natively-ai-assistant-natively-cluely-ai-assistant-*-fh*` bundle release
carries the verified patched source + build log.

No published `.forkhub` releases for your account yet? Publish this
target's catalog (`fh publish`) and cut a release with the
`forkhub build` workflow — then anyone can install the ForkHub build.
