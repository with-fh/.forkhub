# DeepSeek Harness Desktop ForkHub — use this build (macOS + Windows)

Patched DeepSeek Harness Desktop that updates from the ForkHub catalog
instead of the Tencent COS feed. Same app, same data — installing it
replaces a stock install and keeps everything, then it self-updates from
here.

## Install

- **macOS (unsigned):** the `*-arm64.dmg` (Apple Silicon) or `*-x64.dmg`
  (Intel). First launch: right-click → Open (the fork carries no
  Developer ID signature, so Gatekeeper blocks a plain double-click; the
  app is otherwise identical).
- **Windows (unsigned):** the `*.exe` installer. SmartScreen will warn
  (unsigned fork build) — More info → Run anyway.
- **Linux:** not in this catalog — Linux installers (AppImage + deb)
  ship from the downstream ImBIOS catalog, which layers
  `dsh-linux-support` over this channel patch.

## Updates

Updates are automatic: the app polls the ForkHub catalog feed
(`with-fh/.forkhub` by default). To follow a different publisher's
catalog, set the ForkHub publisher in Settings → Version first (it
validates, repoints the feed, and checks immediately).

Linux users install from the ImBIOS catalog release instead; the in-app
updater keeps either install on its own publisher's train.
