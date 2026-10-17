# Acceptance Criteria — natively-pkg-no-maps-8dedeb5a

## Must pass for promotion to APPLIED

1. **Ignore present.** `package.json` `build.files` contains exactly
   one `"!**/*.map"` entry.
2. **Tree still bundles.** `npm run build:electron` succeeds (the
   change touches packaging config only).
3. **Applies first.** `reference.diff` applies to stock v2.9.2 AND on
   top of the with-fh support patch (hunks are disjoint).
4. **Focused suite passes**: `verify.sh` exits 0. Full AppImage proof
   (no `.map` in the payload) rides the `forkhub-pr-build` workflow.
5. **Retirement path documented**: upstream merge of PR #661 turns the
   next apply failure into patch deletion, not re-derivation.

## How to verify

```bash
sh repos/github.com/natively-ai-assistant/natively-cluely-ai-assistant/patches/natively-pkg-no-maps-8dedeb5a/verify.sh
```
