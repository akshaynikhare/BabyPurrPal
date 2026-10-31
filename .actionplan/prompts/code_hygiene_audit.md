# Code Hygiene Audit (report-only)

One-cycle hygiene audit → categorized cleanup report. No code changes. The human approves items;
fixes happen as stories. Purely dead weight, duplication, needless complexity — not security/correctness.

## Architecture
Orchestrator plans, scopes, dispatches, dedupes, writes the report — it does not grep files itself.
All scanners are bulk-lane subagents (`ap-scanner`), dispatched IN ONE MESSAGE, each with a territory
of roughly equal size, the exclusion list, and the finding format. Findings only, never file dumps.

## Categories (one per finding)
1 Dead code · 2 Unused imports · 3 Unused components/classes · 4 Unused functions ·
5 Duplicated implementations (name the canonical) · 6 Redundancy (re-derived values, duplicate constants) ·
7 Unoptimized (N+1 awaits, unmemoized hot loops — obvious wins only) · 8 Needless complexity
(flag-soup state machines, one-caller indirection, hand-rolled stdlib).

Out of scope: style (linter's job), missing tests/docs, security (different pass), taste renames,
speculative refactors. Generated/vendored code and migrations are NEVER findings.

## Phases
0. Scope: entrypoints, exclusion list, detect tooling (tsc/knip/depcheck/eslint — run, never install).
   Check DECISIONS.md via recall.sh — deliberate choices are not findings.
1. Parallel scan: territory scanners + cross-cutting (reachability from entrypoints — check string-based
   references before declaring anything orphaned; duplication across territories; tooling output).
2. Orchestrator: dedupe, verify low-confidence claims at source, drop DECISIONS conflicts with a note.
3. Report → `.actionplan/audit/<CODE>-NNNN-hygiene.md`: summary table
   (ID | Category | Severity | Confidence | Area | One-liner), findings with file:line, triage order.
