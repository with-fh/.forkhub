# Build triggers — github.com/deepseek-ai/deepseek-harness

Default choice (mirrors the Natively target; user-explicit change welcome):

- **Nightly check at 00:00 UTC+7 (17:00 UTC cron): build only untagged.**
  The shared workflow resolves the newest `dsh-v*` upstream tag (via
  `upstream.json:tag_match_pattern`) and the skip gate no-ops when that
  tag already has an updater or bundle release. No new upstream tag =
  quiet green run, no noise, no compute beyond the check.
- **On intent change (push to `repos/**`): build** (same skip gate
  applies — a push with no new upstream tag only rebuilds with force).
- **Manual (`workflow_dispatch`, optional `target` filter, `force`
  flag): build.** Rebuilds and on-demand ForkHub releases; `force=true`
  rebuilds even an already-built tag. First build: dispatch with
  `target: github.com/deepseek-ai/deepseek-harness`
  (or push this target dir — same effect). One leg per OS runs
  (`macos-26`, `windows-latest`); per-OS skip markers
  mean a finished leg never blocks the others.

To change the poll cadence, edit the cron in
`.github/workflows/forkhub-build.yml` (shared file — affects all targets).

Drift (apply step fails on a new tag) hands off to `forkhub reimplement`
automatically (GREEN-as-triaged) — the reimplement router regenerates the
patch against the new tag and the next build reruns the verify gate.
