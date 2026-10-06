---
id: natively-fork-ux-and-checks-f1c3d2a8
title: Fork calendar direct auth, resilient version check, dual fund links, maintainer card
target_repo: github.com/natively-ai-assistant/natively-cluely-ai-assistant
target_area: [electron/services/calendarPkce.ts, electron/services/CalendarManager.ts, electron/main.ts, src/components/AboutSection.tsx, src/components/ui/ConnectCalendarButton.tsx, electron/services/__tests__/CalendarPkce.test.mjs, electron/services/__tests__/ForkPatch2Sources.test.mjs]
status: draft
applied_upstream_pr: none
version: 3
license: MIT
author: Imamuzzaki Abu Salam
last_modified_by: Imamuzzaki Abu Salam
owners: [Imamuzzaki Abu Salam]
source_url: null
imported_at: null
created: 2026-09-30
last_realized_against_commit: b439c1f0
verifies_with: node --test (focused suites, see verify.sh)
---

## Intent

Make four fork-facing behaviors work in the ImBIOS/with-fh build that are
dead or misleading on stock code paths:

1. **Connect calendar works with a fork-owned Google client.** Stock
   exchanges the auth code through the natively-api proxy, which holds the
   secret for UPSTREAM's OAuth client and cannot serve a foreign client id
   — and the OSS tree ships the placeholder `YOUR_CLIENT_ID_HERE`, so the
   button spins then silently dies. Add a direct PKCE flow (public clients
   need no secret) selected when the fork's own client id is present, keep
   the proxy path byte-identical otherwise, and surface failures in the UI.
2. **Version Check never shows a bare Error for feed problems.** When
   electron-updater rejects (or errors async) during a manual Check with no
   downloadable release yet, answer from the catalog compare instead.
3. **Fund dev funds both sides.** The Support button opens the original
   creator link AND the fork maintainer's sponsors page.
4. **About credits the fork.** A maintainer card below the creator card.

## Why

Each of these is fork-shaped: upstream cannot use a foreign OAuth client,
never sees an empty catalog feed, and has no fork to credit. Realizing
them as a second intent (applied after the update-track patch) keeps the
feed/HWID patch independently re-derivable.

## Non-negotiables

1. **Upstream paths byte-identical when the fork is unconfigured.**
   No baked id + no direct env → proxy flow, placeholder guard, and all
   stock version-check event sequences behave exactly as before. Fork code
   paths run only with a fork client id present (or an explicit direct
   env), or inside Check-failure handling.
2. **Exactly one terminal state per Check.** Updater failures surface both
   as a rejected promise AND an async `error` event — the
   `manualCheckFallbackPending` flag guarantees one fallback run, and
   download-time errors (flag clear) still broadcast as before.
3. **No secret in the fork.** The direct flow sends no `client_secret`
   anywhere (asserted in tests); the baked client id is a public
   identifier, like any shipped OAuth client id.
4. **No silent UI dead-ends.** Calendar connect failures render under the
   button; manual compare with no reachable feed broadcasts instead of
   leaving Checking stuck.
5. **No repo-wide test/typecheck runs.** Verify with the focused suites in
   `verify.sh` only.

## Implementation notes

- New `electron/services/calendarPkce.ts` (pure, no electron import):
  `createPkcePair()`, `exchangeCodeDirect()`, `refreshTokenDirect()`
  against `oauth2.googleapis.com/token`.
- `CalendarManager`: fork id resolution (baked `nativelyGoogleClientId`
  extraMetadata → direct; env id + `NATIVELY_CALENDAR_DIRECT=1` → direct;
  else placeholder → readable error); PKCE state per flow; direct
  exchange/refresh branches; proxy + event fetching untouched.
- Release `build.sh` bakes `build.extraMetadata.nativelyGoogleClientId`
  from `NATIVELY_GOOGLE_CLIENT_ID` when set (no shared-workflow change
  needed for local fork releases; CI forwarding is a follow-up).
- Zero-config default: fork catalog builds fall back to the maintainer's
  public Desktop client id (gated on the packaged publish owner, so stock
  checkouts keep the placeholder guard); explicit baked/env configuration
  always wins. v2 addition — the client id is public by design (PKCE uses
  no secret).
- One-time maintainer setup (Google Cloud → Desktop OAuth client with
  `http://localhost:11111/auth/callback`) documented in `build/BUILD.md`.
- `main.ts`: `manualCheckFallbackPending` flag; updater-reject and
  async-error-during-check both fall back to the catalog compare; manual
  null-feed broadcasts instead of hanging.
- `AboutSection`: Support opens buymeacoffee (donation timer preserved)
  + `github.com/sponsors/ImBIOS/`; maintainer card (initials avatar —
  no binary assets in text patches) with GitHub + Sponsor links.
- `ConnectCalendarButton`: error state rendered under the button.
- Tests: `CalendarPkce.test.mjs` (pair shape, challenge correctness,
  uniqueness), `ForkPatch2Sources.test.mjs` (source assertions).
