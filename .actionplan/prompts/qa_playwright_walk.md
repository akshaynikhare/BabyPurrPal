# QA Playwright Walk

Walk <APP> in a real Chromium and report what is broken. Read-only — change no code.

## Before you start
Run `bash .actionplan/scripts/check-chromium.sh`. [VERDICT] FAIL → stop and say why.
Confirm the app is reachable. A down app is a stop-and-report, not a finding.

## How to walk
- Reach every screen a normal user reaches. Log in first if the app needs it.
- On each screen: load it, read it, click the primary action, submit one form.
- Find things by role, label, text — the way a user does. Never a test id.
- Capture as you go, not at the end.

## Six lenses
1. Broken — 4xx/5xx, console errors, dead buttons, blank states.
2. Confusing — unclear labels, no feedback after an action, no empty state.
3. Wrong — numbers that don't add up, stale data, a filter that ignores input.
4. Leaky — data or actions visible to a role that should not see them.
5. Findable — public pages only: title, meta description, OG tags, one h1, image alt.
6. Off-brand — hardcoded colors, mixed component styles, wrong radius, a second icon set.

## Write to `.actionplan/qa/<PLAN-ID>/<date>/`
- `FINDINGS.md` — one row per finding: severity P0–P3, lens, what you saw, how to repeat it
- `JOURNEY.md` — one line per step, with the URL
- `console.log` — warnings and errors only, deduped
- `network.jsonl` — every non-GET, plus every 4xx/5xx
- `screenshots/` — one per finding. Cap 40; if you hit the cap, say so.

## Rules
- No evidence, no finding — every row cites a screenshot or console line.
- `recall.sh` first — never report a deliberate DECISIONS.md choice as a bug.
- No plan numbers in finding titles. Unsure = UNCONFIRMED; do not pad the list.
- Report only. Fixes are a separate story.
