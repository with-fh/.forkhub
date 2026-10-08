# Build — github.com/natively-ai-assistant/natively-cluely-ai-assistant (ForkHub, Linux)

Repo-native Linux build for the ForkHub Natively channel. Runs on
`ubuntu-latest` after the intent stack is applied and `verify.sh` passes.
The catalog follows upstream **stable** (newest lowercase-`v` tag; see the
tag note below). Each build carries a ForkHub provenance version
`<upstream>-fh.<owner>.<n>` (e.g. `2.8.1-fh.imbios.1`).

## What `build.sh` does

1. Refuses pre-release tags (`-beta`/`-alpha`/`-rc`/`-preview`/`-pr.*`).
2. Numbers the build: `n` counts existing `v<base>-fh.<owner>.N` updater
   releases so force-rebuilds advance. Exports `FORKHUB_VERSION`.
3. Bootstraps its own toolchain (the shared builder only has bun):
   node 22 (matches upstream `release-macos.yml`), Rust stable via
   rustup (native-module via napi), and `build-essential python3
   pkg-config libsecret-1-dev` via apt (keytar links libsecret).
4. Installs deps (`npm ci` — postinstall rebuilds sharp/native addons and
   verifies the vendored models, same as local dev).
5. Stamps `package.json` to the ForkHub version, then mirrors
   `app:build` (Linux subset): vite build, electron typecheck + bundle,
   native module, `ensure-sharp-mac-deps` (no-op on linux), and
   `electron-builder --linux AppImage deb --publish never`.
6. Moves `*.AppImage`, `*.deb`, `latest-linux.yml`, `*.blockmap` into
   `$GITHUB_WORKSPACE/dist`, renames the AppImage to the descriptive
   `Natively-<version>-<arch>.AppImage` (upstream `productName` is the
   stealth name `corespeechd`; the `.deb` already follows the package
   `name` and is left alone), repoints `latest-linux.yml` at the new
   name, and asserts the manifest references only shipped files — then
   asserts `latest-linux.yml` carries the stamped version. Without it
   in-app updates can never fire.
7. Never fails the job: on any failure it packs a patched-source tarball,
   logs to `BUILD_LOG.md`, and exits 0. `publish.sh` then skips the updater
   release when no `latest-linux.yml` exists.

## What `publish.sh` does (updater-channel release)

Runs in the publish step with `GH_TOKEN`. If `dist/` contains
`latest-linux.yml`, it uploads the AppImage + manifest + blockmaps to the
**`v<version>` release in this catalog repo** (creating it if needed) —
that release IS the electron-updater feed the patched app polls
(`electron/update/updateFeed.ts`). The `.deb` rides the namespaced bundle
release. The shared workflow step separately publishes the namespaced
`natively-ai-assistant-natively-cluely-ai-assistant-v<ver>-fh<N>` bundle
release (human-facing, carries `CONSUME.md`).

Why two releases: electron-updater matches versions on the shared catalog
atom feed by semver channel — only a `v<semver>` tag with prerelease
channel `fh` matches the patched app. The namespaced `*-fhN` bundle tags
are not semver and are skipped by the updater (but carry the full bundle:
deb, checksums, build log, notes).

## Requirements / limits (v1)

- **Linux only from CI.** macOS needs Developer ID + notarization and
  Windows its own runner — both live outside this catalog. macOS/Windows
  users build the patched source locally (`npm run dist`, DMG/NSIS).
- **Same product name.** The fork build keeps upstream's `productName`
  (`corespeechd` — the stealth name; same appId/paths), so installing it
  cleanly replaces a stock install and inherits its data — the intended
  migration path. Side-by-side installs are a follow-up (needs appId +
  protocol + path changes). Only the Linux *artifact filename* is made
  descriptive (`Natively-*.AppImage`, per `CONSUME.md`); the `.deb`
  already ships as `natively_*_amd64.deb` from the package `name`.
- **Tag note.** The shared clone step only considers lowercase-`v` tags
  (`refs/tags/v*`), so an upstream `V2.8.8`-style capital-V tag is
  invisible and the build follows the newest lowercase tag (currently
  `v2.8.1`). If upstream switches tagging, either adjust the shared
  picker or pin via `upstream.json:tag_match_pattern`. Do NOT retag
  upstream.
- **Premium submodule stays absent.** Fork builds ship open-source mode
  (`electron/premium/featureGate.ts`); the patch's `HardwareId` fallback
  chain is what makes trial/licensing work without it.
- **Linux dock identity is deterministic.** The app pins userData then
  sets the product name before any window exists (Linux-only), and the
  build declares `StartupWMClass` + a cache-refreshing deb postinst, so
  the dock shows the icon and offers pin-to-dock. Disguise renames still
  apply later (stealth modes intentionally break association).
- **Google calendar client (one-time maintainer setup).** Connect calendar
  uses the direct PKCE flow with the fork's own OAuth client: create a
  Google Cloud "Desktop app" OAuth client with redirect URI
  `http://localhost:11111/auth/callback`, then build with
  `NATIVELY_GOOGLE_CLIENT_ID=<id>` (baked into `build.extraMetadata` by
  `build.sh`; the id is public, not a secret). Without it, connect
  reports unconfigured instead of failing silently. CI forwarding of that
  var through the shared workflow is a follow-up; local fork releases set
  it directly.
- **Known drift risk.** `reference.diff` is verified against the upstream
  tag at capture time (currently `v2.8.1`). When upstream drifts, the
  apply step fails loudly — re-derive via `fh` (`drift-check` →
  `re-derive` → `apply`) and re-capture; do not hand-edit
  `reference.diff`.
