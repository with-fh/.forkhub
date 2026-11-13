# Build — github.com/aeonfun/opendia (ForkHub resign pipeline, single ubuntu leg)

No native build: upstream already publishes `opendia-firefox-*.zip`
(unsigned). This pipeline re-signs it under the catalog-owned add-on ID
(see `../patches/opendia-resign-f0000000/INTENT.md`) and publishes a
signed `.xpi`.

Runs one workflow leg (`upstream.json:build_runs_on`: `ubuntu-latest`)
after the intent stack is applied and `verify.sh` passes. Each build
carries a ForkHub provenance version `<upstream>-fh.<owner>.<n>`
(e.g. `v1.1.4` → `1.1.4-fh.with-fh.1`).

## What `build.sh` does

1. Refuses tags that are not plain `vX.Y.Z` stable (pre-release suffixes
   never ship as a ForkHub release).
2. Numbers the build: `n` counts existing `v<base>-fh.<owner>.N`
   releases in this catalog repo so force-rebuilds advance — reuses the
   newest incomplete release otherwise. Exports `FORKHUB_VERSION`.
3. Downloads the upstream `opendia-firefox-*.zip` asset for
   `$UPSTREAM_TAG` (GitHub releases API, unauthenticated) into a work
   dir. Fails soft (patched-source fallback) when the asset is missing —
   e.g. a tag that ships no firefox zip.
4. Unpacks, applies the ID swap deterministically (`sed` on
   `opendia-extension` → `dist/firefox/manifest.json`; the shared
   workflow already applied `reference.diff` to the checkout, so this
   step only re-materializes the built dir the same way `npm run
   build:firefox` would, without needing node_modules).
5. Runs `web-ext lint` (0 errors required) then
   `web-ext sign --channel=unlisted` with `AMO_JWT_ISSUER` /
   `AMO_JWT_SECRET` from the environment (repo Secrets; absent =
   soft-fail with a clear log line, never a red build).
6. Moves the signed `.xpi` into `$GITHUB_WORKSPACE/dist` as
   `opendia-firefox-<FORKHUB_VERSION>.xpi` plus a `PROVENANCE.md`
   (upstream tag, zip SHA256, ID used, AMO submission id).
7. Never fails the job: on any failure packs a patched-source tarball,
   logs to `BUILD_LOG.md`, exits 0.

## Sunset (upstream ships a signed XPI)

`triggers.md` documents the check, enforced at the top of `build.sh`:
before signing, list upstream release assets for `$UPSTREAM_TAG` and
download any `*.xpi`/`*.zip` whose name suggests signed content; if one
unzips to `META-INF/mozilla.sf`, the pipeline publishes a
`SUNSET-<tag>.md` note instead of an XPI, and the catalog entry is
deprecated (registry removal + README redirect, human-confirmed).
