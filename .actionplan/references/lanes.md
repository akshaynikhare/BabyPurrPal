# Lanes and fan-out

## Lanes (from config.json)

| Lane | Default model | Takes |
|---|---|---|
| orchestrator | the session | gates, test runs, baseline edits, plan-file writes, triage |
| complex | opus | money, security, auth, tricky UI, anything needing judgment |
| bulk | sonnet | repetitive passes, well-specified mechanical tasks, scanners |

Checklist rows carry the lane inline: `- [ ] T3 Rename the service calls (lane: sonnet)`.

## Fan-out rules

- Read inline when the scope is ≤3 files or ≤400 lines. Dispatch subagents for breadth: route sweeps, per-app walks, per-territory audits.
- Dispatch all scanners for a wave in ONE message so they run in parallel.
- Every subagent gets: the exact file manifest, the exclusion list, the finding format, and "return findings only — no file dumps".
- Subagents never: run the test suite, edit a baseline, write a plan file, touch git, invoke a skill.
- Batch `typecheck + lint` once at the end of a repo's edits — never per file.
