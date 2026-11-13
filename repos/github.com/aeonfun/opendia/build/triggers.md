# Build triggers — github.com/aeonfun/opendia

- **Nightly check at 00:00 UTC+7 (17:00 UTC cron): build only untagged.**
  The shared workflow resolves the newest `v*` upstream tag and the skip
  gate no-ops when that tag already has a bundle release. No new tag =
  quiet green run.
- **On intent change (push to `repos/**`): build** (same skip gate —
  a push with no new upstream tag only rebuilds with force).
- **Manual (`workflow_dispatch`, `target:
  github.com/aeonfun/opendia`, `force` flag): build.** First build:
  dispatch with the target filter (or push this target dir — same
  effect). Single ubuntu leg; needs `AMO_JWT_ISSUER` / `AMO_JWT_SECRET`
  repo Secrets or the run soft-fails with a patched-source bundle.
- **`version_suffix: fh`** — releases are `v<base>-fh.<owner>.N`
  provenance tags plus the shared namespaced `aeonfun-opendia-<tag>-fhN`
  bundle (per the shared Publish step).

## Secrets

| name | source | used by |
|---|---|---|
| `AMO_JWT_ISSUER` | addons.mozilla.org → Manage API keys | `build.sh` → `web-ext sign` |
| `AMO_JWT_SECRET` | same page (shown once) | `build.sh` → `web-ext sign` |

## Sunset

When upstream ships a signed XPI, this pipeline retires itself:

1. `build.sh` detects it per-tag (downloads any upstream `*.xpi`,
   greps for `META-INF/mozilla.sf`) and publishes `SUNSET-<tag>.md`
   instead of signing.
2. A human then removes the `opendia` entry from `registry.json`,
   adds a redirect note to this `build/` dir (or the repo README),
   and closes the loop — no auto-archive of the whole `.forkhub` repo,
   which serves other targets.

To change the poll cadence, edit the cron in
`.github/workflows/forkhub-build.yml` (shared file — affects all targets).
