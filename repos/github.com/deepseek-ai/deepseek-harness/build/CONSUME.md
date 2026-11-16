# DeepSeek Harness Desktop ForkHub — use this build (macOS + Windows + Linux)

Patched DeepSeek Harness Desktop that updates from the ForkHub catalog
instead of the Tencent COS feed. Same app, same data — installing it
replaces a stock install and keeps everything, then it self-updates from
here.

## Install

- **macOS (unsigned):** the `*-arm64.dmg` (Apple Silicon). First launch: right-click → Open (the fork carries no
  Developer ID signature, so Gatekeeper blocks a plain double-click; the
  app is otherwise identical). The x64 cross-pack is best-effort (LibreOffice
  under emulation can time out on hosted runners) — arm64 always ships.
- **Windows (unsigned):** the `*.exe` installer. SmartScreen will warn
  (unsigned fork build) — More info → Run anyway.
- **Linux (unsigned):** the `*-linux-x86_64-unsigned.AppImage` from the
  unified updater release (`v<base>.with-fh.<date>.<n>`). Make it
  executable, then run with `--no-sandbox` on headless/Xvfb machines.
  `dsh-linux-support` (in this catalog's stack) adds the linux-x64
  target on top of the channel patch.

## Updates

Updates are automatic: the app polls the ForkHub catalog feed
(`with-fh/.forkhub` by default). To follow a different publisher's
catalog, set the ForkHub publisher in Settings → Version first (it
validates, repoints the feed, and checks immediately).
