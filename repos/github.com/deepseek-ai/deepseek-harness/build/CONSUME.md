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
- **Linux:** download the `*-linux-x86_64.AppImage` and its matching
  `.AppImage.asc` signature. The app displays **DeepSeek Harness**.

### Verify the Linux download

Use the [ForkHub release public key](https://github.com/with-fh/.forkhub/blob/main/repos/github.com/deepseek-ai/deepseek-harness/build/forkhub-linux-release-key.asc)
with fingerprint `D8FF 0E4B F333 38DC 18B6 74E4 EF0F 87A3 DB84 CF61`.
After importing the key, run `gpg --verify FILE.AppImage.asc FILE.AppImage`
with the downloaded filenames.

## Updates

Updates are automatic: the app polls the ForkHub catalog feed
(`with-fh/.forkhub` by default). To follow a different publisher's
catalog, set the ForkHub publisher in Settings → Version first (it
validates, repoints the feed, and checks immediately).
