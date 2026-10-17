---
id: natively-pkg-no-maps-8dedeb5a
title: Exclude sourcemaps from the packaged app (upstream PR #661)
target_repo: github.com/natively-ai-assistant/natively-cluely-ai-assistant
target_area: [package.json]
status: draft
applied_upstream_pr: none
version: 1
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-10-17
last_realized_against_commit: b439c1f0
verifies_with: config assertion + electron bundle (see verify.sh)
---

## Intent

Exclude `*.map` from the packaged Natively app by adding one ignore to
`package.json` `build.files`. This is the FIRST intent-patch of Natively
in this (`ImBIOS/.forkhub`) catalog, and it tracks upstream PR #661
verbatim — the change is meant to be merged upstream, not to live here
forever.

## Why

Measured on the v2.9.2 AppImage: **1257 MB of `.map` files (8061 of
them)** inside `app.asar`. `scripts/build-electron.js` compiles every
`electron/**/*.ts` as its own esbuild entry with `bundle: true` +
`sourcemap: true` (`format: 'cjs'` can't split), so each of the ~23
top-level bundles inlines the whole shared graph (~21.5 MB js + ~46 MB
map per entry) — plus every dependency's own maps, since `build.files`
has no `.map` ignore. Production has no devtools and nothing reads
`.map` at runtime; dev builds keep generating them.

## Upstream dependency

This patch depends on the intent-patch in `with-fh/.forkhub`:

- repo: `with-fh/.forkhub`
- patch: `natively-forkhub-support-f276ae13`
- pinned ref: `f797d1a` (re-pin when that patch changes; procedure:
  point `WITHFH_REF` at the new commit in `forkhub-pr-build.yml` and
  re-run the full flavor)

Full ImBIOS builds apply the with-fh support patch FIRST (fetched raw
at the pinned ref), then this patch (`apply_order` below) — the maps
hunk lives in `build.files`, the support hunks in `build.publish` and
elsewhere, so the two never overlap. This patch ALSO applies to stock
upstream alone (verified both orders), which is what the `pr-only`
build flavor proves.

## Retirement

When upstream merges PR #661 (or any equivalent maps exclusion), this
patch's hunk duplicates the upstream line and `git apply` starts
failing on new tags. That failure is the retirement signal: do NOT
re-derive — delete this patch dir, drop it from `manifest.json`
(`patches`, `apply_order`), and keep the with-fh support patch as the
single remaining entry.

## Non-negotiables

1. **One hunk, packaging only.** No JS/TS changes; dev builds keep
   their maps.
2. **First in apply_order.** Base layer under the with-fh support
   patch; verified to apply to stock v2.9.2 both before and after it.
3. **No repo-wide test/typecheck runs.** Verify with `verify.sh` only;
   the full AppImage proof rides the `forkhub-pr-build` workflow.

## Implementation notes

- `package.json`: `"!**/*.map"` appended to `build.files`
  (electron-builder minimatch — covers `dist-electron` maps and every
  dependency's maps in one rule).
- Expected effect: asar 2.0 GB → ~0.75 GB, AppImage ~1.2 GB → well
  under 1 GB. (The remaining bulk is duplicated JS bundles, which
  needs upstream-owned esbuild splitting — tracked in issue #660, out
  of scope here.)
