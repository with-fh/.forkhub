# Build triggers — github.com/natively-ai-assistant/natively-cluely-ai-assistant

Default choice (mirrors the t3code target; user-explicit change welcome):

- **Nightly check at 00:00 UTC+7 (17:00 UTC cron): build only untagged.**
  The shared workflow resolves the newest lowercase-`v` upstream tag and
  the skip gate no-ops when that tag already has an updater or bundle
  release. No new stable tag = quiet green run, no noise, no compute
  beyond the check.
- **On intent change (push to `repos/**`): build** (same skip gate
  applies — a push with no new upstream tag only rebuilds with force).
- **Manual (`workflow_dispatch`, optional `target` filter, `force`
  flag): build.** Rebuilds and on-demand ForkHub releases; `force=true`
  rebuilds even an already-built tag. First build: dispatch with
  `target: github.com/natively-ai-assistant/natively-cluely-ai-assistant`
  (or push this target dir — same effect). One leg per OS runs
  (`ubuntu-latest`, `macos-14`, `windows-latest`); per-OS skip markers
  mean a finished leg never blocks the others.

To change the poll cadence, edit the cron in
`.github/workflows/forkhub-build.yml` (shared file — affects all targets).

Drift (apply step fails on a new tag) does NOT auto-trigger anything:
dispatch `forkhub reimplement` by hand — see the t3code target's
`build/reimplement.md` for the unattended OpenCode flow. (A Natively
reimplement router is a follow-up; until then reuse the shared workflow.)
