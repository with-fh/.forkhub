# Acceptance Criteria — opendia-resign (resign pipeline)

The catalog-owned add-on ID patch for OpenDia. Mechanical resign: one
hunk, one file, no behavior change.

## Must pass for promotion to APPLIED (already applied — re-check on drift)

1. **Single-hunk surface.** `git diff --stat` of the applied patch is
   exactly `opendia-extension/manifest-firefox.json | 1 +-`
   (1 insertion, 1 deletion). Any wider surface = drift, re-derive.
2. **ID is the catalog UUID.** Patched manifest contains exactly
   `"id": "{22b9fd82-342c-46ab-a615-888115ffc841}"` and no occurrence
   of `aaronjmars`.
3. **Lint clean.** `web-ext lint` on the built firefox dir reports
   0 errors (warnings allowed).
4. **AMO signs it.** `web-ext sign --channel=unlisted` exits 0 and the
   downloaded `.xpi` unzips to `META-INF/mozilla.sf` (the sunset
   condition is the day upstream's own assets do this).

## How to verify

```sh
sh repos/github.com/aeonfun/opendia/patches/opendia-resign-f0000000/verify.sh
```
