# QA-DEV Loop

Two short texts, passed back and forth until clean. Use config.json `qaMaxRounds` (default 3) — then park it for the poke.

## Dev → QA brief (exactly 7–8 lines)
Based on this code/feature update, write a concise QA input text in 7–8 lines. App name at the top.
In-depth what was built and its expected behaviour, plus the core areas QA needs to verify.
Pure QA text only — strictly read-only, no code changes, no deployment instructions, no extra fluff.
Ask to just check the diff — no simulator or web test, pure code check — and report back in 7–8 lines.

## QA → Dev report (exactly 7–8 lines)
Plain text. No verdict keywords, no tables, no markdown. State what breaks and who it hits.
Nothing wrong → say so in line 1, use the rest for what was verified. Unsure → UNCONFIRMED.

## Rules
- QA is ALWAYS a different agent with fresh context. It never sees the build conversation.
- QA reads the DIFF only. Read-only. Proposes nothing, edits nothing.
- Rounds saved to `.actionplan/qa/<id>/brief-N.md` / `report-N.md` — the loop stays visible.
- Route focused reviewers per `references/focused-review.md` within the same round; save their
  separate briefs/reports. Their scoped source review does not expand `ap-qa`'s diff-only brief.
- After code fixes, rerun `node .actionplan/scripts/verify.cjs <id>` and the affected reviewers;
  general QA always reviews the updated diff. Never reuse verification from before a fix.
- Record explicit dispositions in `review-N.md` (template `templates/review.md`), including reasons
  for skipped roles and refuted findings. Seal with `finish.cjs <id> N` before ticking `QA clean`.
- At the configured round cap, unresolved findings or material uncertainty → park for the human.
  Human sign-off is never ticked by an agent.
