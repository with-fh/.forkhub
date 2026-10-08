# Unattended re-derivation — github.com/natively-ai-assistant/natively-cluely-ai-assistant

When upstream drifts under an intent-patch (the build job's apply step
fails), re-derivation runs **unattended** via the shared
`forkhub reimplement` workflow — no human in the loop until the agent
either succeeds or asks for a decision.

## How to trigger

Manual dispatch only (Actions → `forkhub reimplement` → Run workflow):

| Input | Default | Notes |
|---|---|---|
| `target` | empty (all) | `github.com/natively-ai-assistant/natively-cluely-ai-assistant` |
| `patch` | empty (apply_order) | e.g. `natively-forkhub-update-track-53ac9810` |
| `tag` | empty (newest per `upstream.json`) | pin to re-derive against a specific tag |
| `model` | `opencode-go/muse-spark-1.3-contributor` | |
| `variant` | `xhigh` | provider effort level |
| `timeout-minutes` | `30` | wall budget per patch; `timeout` kills, router files it |

Auto-trigger: the build workflow dispatches this workflow itself when a
patch fails to apply (or verify) on a new tag — one run per
target+patch+tag, skipped while a `needs-human-decision` issue for the
patch is open. A red apply step can still mean "run by hand" when the
auto-dispatch is suppressed or the router files HUMAN/FAIL.

Patches apply in manifest order (`update-track` → `fork-ux-and-checks`
→ `dock-icon`), so re-deriving an early patch can require re-deriving
later ones stacked on top of it — verify the full stack afterwards.

## Secrets / variables (repo scope)

| Name | Kind | Value |
|---|---|---|
| `OPENCODE_API_KEY` | secret | OpenCode Go key (`oc_sk_…`). Never in the repo. |
| `REIMPL_AUTOPROMOTE` | variable, default `true` | `false` → push `forkhub/reimpl-<id>` + open a review PR instead of committing to main. |
| `OPENCODE_MODEL` / `OPENCODE_VARIANT` | — | Not separate variables on purpose: model + variant ride as dispatch inputs so each run records exactly what ran. |

## The contract (enforced by `reimplement-router.sh`, tested)

1. **Drift pre-check first.** If `target_area` is untouched since
   `last_realized_against_commit`, the patch is current — no tokens spent.
2. **Agent prompt** (`PROMPT.md`, assembled in the job): intent is truth,
   `reference.diff` is evidence only, `verify.sh` must go green, finish
   with `REALIZATION/realization.diff` + `report.md`, or with
   `NEEDS_HUMAN.md` (`Decision needed / Options / Recommendation /
   Blocked by / Cost of waiting`). No questions, no commits, stay in the
   checkout. Runs with `--auto` inside an **ephemeral runner** — that
   containment is what makes auto-approve acceptable.
3. **Router** (POSIX sh, unit-tested — see below):
   - `PROMOTE` — realization present AND `verify.sh` green (re-run
     deterministically by the router, not trusted from the agent).
     Refreshes `reference.diff` canonically (excludes `REALIZATION/`,
     `NEEDS_HUMAN.md`), bumps patch version (manifest + INTENT
     frontmatter), stamps `last_realized_against_commit`, appends
     `attempts.jsonl`.
   - `HUMAN` — `NEEDS_HUMAN.md` present; partial work saved to
     `REALIZATION/partial.diff`.
   - `FAIL` — anything else (red verify, wall timeout, empty run).
4. **HUMAN/FAIL → decision issue**, never a commit. Title
   `[reimplement] <target> <patch> needs a human decision`, label
   `needs-human-decision`, deduplicated (comments on the open one).
   Triage SOP: answer inside `NEEDS_HUMAN.md`'s structure if you can;
   otherwise re-dispatch with a narrower `tag`, or re-derive by hand
   and close the issue.
5. **PROMOTE → main** (default) so the build workflow picks it up; with
   `REIMPL_AUTOPROMOTE=false` it becomes a review PR instead.

## Router tests

`reimplement-router.sh` is plain POSIX sh with no CI dependencies:

```sh
# fixtures: $T/target/{manifest.json,patches/x/{INTENT.md,verify.sh}}, $T/work (git repo, tag v9.9.9)
UPSTREAM_TAG=v9.9.9 PATCH_ID=x sh build/reimplement-router.sh $T/work $T/target/patches/x
# → FAIL (empty) | HUMAN (with NEEDS_HUMAN.md) | PROMOTE (with realization + green verify)
```

## Cost notes

- One attempt per dispatch; wall timeout kills runaway sessions.
- Skip-if-built in the build workflow means a promoted re-derivation
  builds exactly once.
- Watch `opencode` spend per run in the job summary log tail
  (`--format json` records usage events in `opencode.log`).
