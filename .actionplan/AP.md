# AP.md — the rules

Loaded at the first step of every `/ap:` command. Not loaded per session.

## The contract

Two interruptions per sprint, never more:

1. **Clarify** — after the plan is drafted, ALL open questions in one batch. Zero code before every answer lands.
2. **The poke** — after everything buildable is built, QA'd, and gated. Parked items first.

Between the two: no user contact. A blocker is parked, not guessed, not asked mid-sprint.

## Hard rules

1. **Never touch git.** No add, commit, stash, checkout, restore. The human commits.
2. **Read the working tree, not HEAD.** In-flight edits are the reality.
3. **Never run the full suite or global coverage.** Gates are static. Tests run targeted, by the orchestrator only.
4. **Write what IS.** Unknown fact → `TODO(verify):`. Never invent a version, port, or behaviour.
5. **Never assume — ask in the batch.** Every question web-searched first, presented as Option A/B with pros/cons and a recommendation.
6. **No agent ever ticks `Human sign-off`.**
7. **Never invoke a skill the user didn't ask for.** Name it, say why, wait for yes.
8. **Never publish to Claude web artifacts.** Deliverables are markdown files in the repo. Diagrams are mermaid blocks.
9. **No plan id in code.** Not in source, not in test names, not in comments. The plan points at code; code never points back.
10. **Locks before edits.** Check `.actionplan/locks/` before touching any file. Overlap → stop and name the holder.

## Memory — slice, never read whole

- `DECISIONS.md`, `PATTERNS.md`, `FROZEN.md` are read ONLY via `scripts/recall.sh <query>`.
- Before planning or editing, run `recall.sh` for every file in scope. A hit means a prior deliberate choice — never "fix" it back. `none` is a valid answer; record it.
- New durable lesson → `DECISIONS.md` entry via `/ap:decide` (needs a pinning test path).
- Same shape used twice → consider a `PATTERNS.md` entry; three times → mandatory.

## Files and stages

- Plans: `.actionplan/{planned,in-progress,archived,audit}/<CODE>-NNNN-slug.md`. Index = highest existing + 1, never reused, never changed on move.
- Raw ideas: one line in `.actionplan/BACKLOG.md`; promote with `/ap:new --from-backlog N`.
- QA evidence: `.actionplan/qa/<id>/` — briefs, reports, walk artifacts. Numbered rounds.
- `docs/` is for humans; `.actionplan/` is for agents. Nearest doc wins; an app without its own doc inherits the parent's.

## Lanes

From `config.json` → `lanes`. Checklist rows carry the lane: `(lane: sonnet)`.
- `bulk` (sonnet): repetitive, mechanical, well-specified tasks.
- `complex` (opus): money, security, tricky UI, anything with judgment.
- `orchestrator`: gates, test runs, baseline edits, plan-file writes. Subagents never do these.

Subagents get a distinct-file manifest and return findings only — never file dumps.

## Tone — the mirror

Evidence first, verdict plain. Name what breaks and who it hits: "this drops every upload over 5MB",
not "consider handling larger files". No praise padding, no hedging. Criticize the work, never the person.
Only computed numbers may speak in the Mirror; nothing to show → `MIRROR: clean.`

## Definition of Done (every plan ends with this block)

All tasks ticked or parked-with-why · every acceptance criterion names its test (`→ file :: "name"`) ·
final targeted verification and gates green · QA-DEV loop clean (sealed evidence on disk) · walk if user-facing · SEO row if public ·
design row if UI changed · **Human sign-off last**.

Completion scripts and archive requirements: `references/completion.md`.
