---
id: opendia-resign-f0000000
title: Catalog-owned add-on ID for self-signing (resign pipeline)
target_repo: github.com/aeonfun/opendia
target_area: [opendia-extension/manifest-firefox.json]
status: applied
applied_upstream_pr: none
version: 1.0.0
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-11-13
last_realized_against_commit: v1.1.4
verifies_with: sh verify.sh (see this patch dir)
upstream_stars: 1900
star_gate: ">=2000 FAIL (1900 recorded 2026-11-13) — exception: atomic resign-only patch, no fork rebuild; see Non-negotiables"
---

## Intent

Upstream ships `opendia-firefox-*.zip` unsigned. Installing it in
Firefox/Zen dies on restart (temporary add-on) because Mozilla requires
AMO signatures for permanent installs, and the shipped manifest carries
`"id": "opendia@aaronjmars.com"` — an add-on ID registered to the
upstream author's AMO account. Any `web-ext sign` under our keys 403s
(`You do not have permission to perform this action`) because we do not
own that ID. Verified live 2026-11-13: lint 0 errors, keys authenticate
(200 on `/api/v5/accounts/profile/`), sign 403s.

This patch swaps the add-on ID for a catalog-owned UUID so
`web-ext sign --channel=unlisted` registers the listing under OUR AMO
account and returns a permanently installable `.xpi`:

```diff
-      "id": "opendia@aaronjmars.com",
+      "id": "{22b9fd82-342c-46ab-a615-888115ffc841}",
```

Rationale recorded here so future re-derivations keep it minimal: the
manifest `name` MUST stay `OpenDia` in the signed artifact. Renaming to
e.g. "OpenDia (ForkHub signed)" was considered per Add-on Policies
fork-rule guidance but REJECTED: the name is user-visible in
`about:addons` and inside the popup, and any divergence breaks the
byte-near-identical provenance claim (PROVENANCE.md asserts only the ID
changed). Non-affiliation is carried by the AMO listing metadata
(developer display name), the release notes, and PROVENANCE.md — not by
mutating the artifact. If Mozilla flags name confusion on review,
revisit: rename at sign time AND disclose the rename in PROVENANCE.md.

## Compliance posture (research 2026-11-13, not legal advice)

Verdict: GO-WITH-CHANGES (all items below are implemented in this
pipeline, not aspirational).

1. AMO: unlisted re-sign under our own UUID with our own credentials is
   the documented-correct way to create a distinct AMO object
   (extensionworkshop signing overview: "All submissions, regardless of
   how they are signed, are subject to Mozilla's Add-on Policies and
   the Firefox Add-on Distribution Agreement"; add-on ID doc: "All
   signed add-ons have a unique ID" + "AMO checks that the ID is
   unique"). MIT covers the copyright layer ("use, copy, modify, merge,
   publish, distribute, sublicense"); the load-bearing duties are
   accurate-info/no-confusion + preserving the MIT notice (done via
   LICENSE injection + PROVENANCE.md + non-affiliation release notes).
2. GitHub: no rule found against MIT redistribution, CI-stored AMO
   secrets (intended secrets use), or automated AMO submissions. AUP
   risk is impersonation — neutralized by the non-affiliation
   disclosure — and bulk abuse — neutralized by release-cadence-only
   triggers (Mozilla's own guidance: "Using this for betas or releases
   is great", not per-commit/nightly).
3. Precedents exist for the mechanism (BrodXI chat-on-steroids fork:
   `web-ext sign --channel=unlisted` in CI, fork-owned ID, AMO JWT in
   Actions secrets; FloHub: same secrets + tag-triggered unlisted
   signing; anpa26/website-media-downloader: release-triggered
   sign-and-attach). No exact precedent for re-signing another repo's
   unsigned ZIP verbatim — our disclosure requirements are stricter
   for exactly this reason.
4. AMO throttling is real but release-cadence-safe: documented
   "Request was throttled, try again in N seconds" cases come from
   submitting many versions in a burst; per-release submission
   (upstream ships rarely) stays far under it. IP-level blocks follow
   policy-violating submissions, not signing volume — shared-runner
   egress is fine as long as every submission passes automated review,
   which ours does (lint 0 errors + unmodified upstream code).

Signed 2026-11-13 against v1.1.4 sources: AMO returned
`5ab75a24e9504f839985-1.1.1.xpi` with `META-INF/mozilla.{sf,rsa}`.

## Scope

1. **ID swap only.** One hunk in
   `opendia-extension/manifest-firefox.json`. No behavioral, UI, or
   permission change — `verify.sh` greps that the diff surface stays
   one file / one key.
2. **Sunset.** When upstream ships a signed XPI (any release asset that
   unzips to `META-INF/mozilla.sf`), this pipeline deprecates: stop
   signing, point users upstream. `build/triggers.md` owns the check.

## Non-negotiables

1. The UUID `{22b9fd82-342c-46ab-a615-888115ffc841}` is STABLE across
   all future signings — AMO issues updates per ID, so rotating it
   strands installed users on a dead ID.
2. Never sign with the upstream ID; it 403s and (worse) would
   impersonate the author's listing if it ever succeeded.
3. No code hunks: if a future upstream moves/renames the manifest,
   re-derive the hunk location, do NOT widen the patch.
4. Star gate exception documented above: this is an atomic resign
   (mechanical transform, provenance-verifiable), not a fork rebuild.
5. Manifest `name` stays `OpenDia` in the signed artifact. A rename to
   e.g. "OpenDia (ForkHub signed)" was considered per Add-on Policies
   fork-rule guidance but REJECTED: the name is user-visible and any
   divergence breaks the byte-near-identical provenance claim
   (PROVENANCE.md asserts only the ID changed). Non-affiliation is
   carried by the release notes + PROVENANCE.md + AMO developer display
   name, not by mutating the artifact. If Mozilla flags name confusion
   on review, revisit: rename at sign time AND disclose it.
6. MIT attribution in-artifact: upstream zips ship NO license file, so
   `build.sh` injects the verbatim upstream LICENSE at zip root before
   signing (the MIT condition requires the notice in all copies).

## Re-derivation instruction

If `manifest-firefox.json` moves or the ID key changes shape, regenerate
`reference.diff` against the new upstream tag keeping the same UUID,
re-run `verify.sh`, update `last_realized_against_commit`.
