# Acceptance Criteria — natively-forkhub-publisher-input-80809dbc

## Must pass for promotion to APPLIED

1. **Default feed unchanged.** With nothing persisted and no env,
   `getUpdateFeed()` returns `{owner:'with-fh', repo:'.forkhub'}`
   (`updatePublisher.test.mjs`).
2. **Owner normalization.** Lowercases, trims, accepts GitHub login
   shapes (1–39 chars), rejects empty/space/underscore/leading- or
   trailing-hyphen/overlong/non-string input (`updatePublisher.test.mjs`).
3. **Catalog validation.** `checkPublisherCatalog` accepts only public
   `{owner}/.forkhub` catalogs with ≥1 published non-draft release;
   maps invalid input (no fetch), empty catalog, 404, 403, 500, and
   network failure to distinct `ok:false` messages
   (`updatePublisher.test.mjs`).
4. **Runtime repoint keeps fork flags.** `applyForkFeed` sets channel
   `fh`, restores `allowDowngrade=false` AFTER the channel-setter
   clobber (F-707 order asserted), points `setFeedURL` at the given
   feed, and enables `allowPrerelease` (`updatePublisher.test.mjs`).
   `main.ts` startup block untouched.
5. **UI wiring present.** SettingsOverlay renders the ForkHub publisher
   row above the Version row (input + Check, valid/invalid status,
   persisted owner caption); successful Check persists, repoints, and
   triggers an update Check (by construction in code).
6. **Applies after patches 1–3**: reference applies onto the
   update-track + ux-and-checks + dock-icon realization (manifest
   `apply_order`).
7. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.

## How to verify

```bash
sh repos/github.com/natively-ai-assistant/natively-cluely-ai-assistant/patches/natively-forkhub-publisher-input-80809dbc/verify.sh
```
