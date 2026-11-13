# Acceptance Criteria — dsh-forkhub-support-0qjj6stm (APPLIED)

Realized 2026-11-10 against upstream master `fcc0ad4` (merge of
`dsh-v0.2.2-rc.1`). 277k stars (>= 2k gate).

## Must pass for promotion to APPLIED — all verified

1. **Feed is the catalog.** Update feed resolves `{owner:'with-fh',
   repo:'.forkhub'}` by default; honors `DSH_UPDATE_OWNER` env override,
   baked `extraMetadata.forkhubUpdateOwner` default, persisted publisher
   override; builder publish config stamps the same owner; updater uses
   the fork channel with prerelease allowed (`allowPrerelease=true`).
2. **Publisher input.** Owner normalization (1–39 chars, GitHub login
   shape); catalog validation (public repo + ≥1 published non-draft
   release; distinct messages for bad input / missing / empty /
   unreachable); runtime repoint keeping fork flags; immediate check
   after apply. Nothing persists on failure; upstream has no `.forkhub`
   repo so it can never validate as a publisher.
3. **Fork rebuilds pass the gate.** Same-owner `0.2.2-rc.1.<owner>.<date>.<n>`
   counters order; stock↔fork and cross-owner pairs refused; stock
   behavior unchanged.
4. **Catalog version handling.** `dsh-v*` tags and stock date-builds never
   parse as fork builds (owner field must contain a letter); `latest`
   resolution never throws on fork feeds.
5. **No Linux hunks.** `git diff` of this patch contains no AppImage,
   no deb hook, no WM_CLASS/desktop-entry, no node-pty prebuild
   changes.
6. **Focused suites pass**: `verify.sh` exits 0 (7 files, 255 tests).
   No repo-wide checks.

## How to verify

```sh
sh repos/github.com/deepseek-ai/deepseek-harness/patches/dsh-forkhub-support-0qjj6stm/verify.sh
```
