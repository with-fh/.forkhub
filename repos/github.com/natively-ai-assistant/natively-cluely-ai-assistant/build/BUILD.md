# Build — github.com/natively-ai-assistant/natively-cluely-ai-assistant (ForkHub, all OSs)

Repo-native build for the ForkHub Natively channel. Runs one workflow leg
per OS (`upstream.json:build_runs_on`: `ubuntu-latest`, `macos-26`,
`windows-latest`) after the intent stack is applied and `verify.sh`
passes. The catalog follows upstream **stable** (newest lowercase-`v`
tag; see the tag note below). Each build carries a ForkHub provenance
version `<upstream>-fh.<owner>.<n>` (e.g. `2.8.1-fh.imbios.1`).

## What each leg builds (mirror of official + Linux)

Official Natively ships mac (dmg + zip, arm64 + x64, signed) and Windows
(nsis + portable); this catalog ships the same set **unsigned**, plus the
Linux set official CI does not publish:

| leg | artifacts |
|---|---|
| linux (`ubuntu-latest`) | `Natively-*.AppImage`, `natively_*_amd64.deb`, `latest-linux.yml` + `fh-linux.yml` |
| mac (`macos-26`, unsigned) | `Natively-*.dmg` + `Natively-*.zip` (arm64 + x64), `latest-mac.yml` + `fh-mac.yml` |
| win (`windows-latest`, unsigned) | `Natively-Setup-*.exe` (nsis) + portable `*.exe`, `latest.yml` + `fh.yml` |

Every leg also emits `*.blockmap` sidecars (differential updates) and a
per-OS `SHA256SUMS-<os>` (a single shared `SHA256SUMS` would be clobbered
across legs sharing one bundle release).

## What `build.sh` does

1. Refuses pre-release tags (`-beta`/`-alpha`/`-rc`/`-preview*`/`-pr.*`).
2. Numbers the build: `n` counts existing `v<base>-fh.<owner>.N` updater
   releases so force-rebuilds advance — but bumps past the newest match
   ONLY when it is complete on every platform (all skip-marker assets
   present); otherwise reuses it, so all three OS legs converge on ONE
   updater release per upstream tag instead of splitting the feed.
   Exports `FORKHUB_VERSION`.
3. Bootstraps its own toolchain per OS: node 22 (linux/mac/win
   distributions), Rust stable (preinstalled on GHA images; rustup
   fallback on unix), and on linux `build-essential python3 pkg-config
   libsecret-1-dev libasound2-dev` via apt (keytar/ALSA).
4. Installs deps (`npm ci` — postinstall rebuilds sharp/native addons and
   verifies the vendored models, same as local dev).
5. Stamps `package.json` to the ForkHub version, bakes the Google OAuth
   client id/secret extraMetadata when the env is present, and (linux
   only) stamps the deb maintainer identity.
6. Mirrors `app:build` per OS: vite build, electron typecheck + bundle,
   sourcemap strip (`*.map` under `dist/` + `dist-electron/` — 1.26 GB
   of duplicated per-entry maps in v2.9.2; upstream ships them, the
   fork does not), native module (mac: `NATIVELY_BUILD_ALL_MAC_ARCHES=1` + both-arch
   canvas/llama/sqlite ensures, mirroring upstream `release-macos.yml`,
   so the x64 pack does not ship armless PDF extraction — the v2.8.7
   lesson), then `electron-builder` with `--linux AppImage deb` /
   `--mac dmg zip --arm64 --x64` / `--win nsis portable` (`--publish
   never`). mac/Windows builds are UNSIGNED (no Developer ID in this
   catalog): the stock config already sets `identity: null`, so the
   stock pack path just works — Gatekeeper (right-click → Open on first
   launch) and SmartScreen warnings apply, documented in `CONSUME.md`.
7. Moves this leg's installers + both updater manifests (`latest-*` stock
   name + `fh-*` twin the app's `fh` channel resolves) + blockmaps into
   `$GITHUB_WORKSPACE/dist` under their original builder-emitted names
   (AppImage included — no rename), and asserts every manifest
   carries the stamped version and references only shipped files.
8. Never fails the job: on any failure it packs a patched-source tarball,
   logs to `BUILD_LOG.md`, and exits 0. `publish.sh` then skips the
   updater release when no manifest exists.

## What `publish.sh` does (updater-channel release)

Runs in the publish step with `GH_TOKEN`. When `dist/` contains any
updater manifest (`latest-linux.yml` / `latest-mac.yml` / `latest.yml`),
it uploads that leg's platform files (installers + both manifest names +
that leg's blockmaps only) to the **`v<version>` release in this catalog
repo** (creating it if needed; parallel legs race safely via
view-or-create + `--clobber`, and filenames are disjoint per platform) —
that release IS the electron-updater feed the patched app polls
(`electron/update/updateFeed.ts`: channel `fh` resolves `fh-linux.yml` /
`fh-mac.yml` / `fh.yml` per platform). The `.deb` rides the namespaced
bundle release. The shared workflow step separately publishes the
namespaced `natively-ai-assistant-natively-cluely-ai-assistant-v<ver>-fh<N>`
bundle release (human-facing, carries `CONSUME.md` + per-OS checksums).

Why two releases: electron-updater matches versions on the shared catalog
atom feed by semver channel — only a `v<semver>` tag with prerelease
channel `fh` matches the patched app. The namespaced `*-fhN` bundle tags
are not semver and are skipped by the updater (but carry the full bundle:
deb, checksums, build log, notes).

## Requirements / limits (v2)

- **Unsigned mac/Windows.** No Developer ID / certs in this catalog, so
  mac builds skip signing + notarization + stapling (upstream's
  `release-macos.yml` does all three) and Windows ships unsigned NSIS.
  mac legs run on `macos-26`: electron-builder 26 requires Xcode 26+
  (`actool`), which older images lack. First launch needs right-click →
  Open (mac) / "More info → Run anyway" (SmartScreen). The app itself is
  identical; only OS trust differs.
- **Same product name.** The fork build keeps upstream's `productName`
  and appId, so installing it cleanly replaces a stock install and
  inherits its data — the intended migration path. All artifact
  filenames stay as the builder emits them (no post-build rename).
- **Tag note.** The shared clone step only considers lowercase-`v` tags
  (`refs/tags/v*`), so an upstream `V2.8.8`-style capital-V tag is
  invisible and the build follows the newest lowercase tag. If upstream
  switches tagging, either adjust the shared picker or pin via
  `upstream.json:tag_match_pattern`. Do NOT retag upstream.
- **Premium submodule stays absent.** Fork builds ship open-source mode
  (`electron/premium/featureGate.ts`); the patch's `HardwareId` fallback
  chain is what makes trial/licensing work without it.
- **Linux dock identity is deterministic.** The app pins userData then
  sets the product name before any window exists (Linux-only), and the
  build declares `StartupWMClass` + a cache-refreshing deb postinst, so
  the dock shows the icon and offers pin-to-dock. Disguise renames still
  apply later (stealth modes intentionally break association).
