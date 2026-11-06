# Acceptance Criteria — dsh-forkhub-support-placeholder (DRAFT)

The ForkHub update-channel patch for DeepSeek Harness Desktop.
Placeholder acceptance — the real patch (via `fh draft`) must promote
each item to a focused test suite in `verify.sh`.

## Must pass for promotion to APPLIED

1. **Feed is the catalog.** Update feed resolves `{owner:'with-fh',
   repo:'.forkhub'}` by default; honors env override, baked
   `extraMetadata` default, persisted publisher override; builder
   `publish` config points at the same repo; updater uses the fork
   channel with prerelease allowed.
2. **Publisher input.** Owner normalization; catalog validation (public
   repo + ≥1 published non-draft release; distinct messages for bad
   input / empty / 404 / 403 / 500 / offline); runtime repoint keeping
   fork flags.
3. **Fork rebuilds pass the gate.** Same-owner `-fh.<owner>.<n>`
   counters order; stock↔fork and cross-owner pairs refused; stock
   behavior unchanged.
4. **Catalog version handling.** Prefixed `dsh-v*` tags parse;
   `latest` resolution never throws on fork feeds.
5. **No Linux hunks.** `git diff` of this patch contains no AppImage,
   no deb hook, no WM_CLASS/desktop-entry, no node-pty prebuild
   changes.
6. **Focused suites pass**: `verify.sh` exits 0. No repo-wide checks.

## How to verify

```sh
sh repos/github.com/deepseek-ai/deepseek-harness/patches/dsh-forkhub-support-00000000/verify.sh
```
