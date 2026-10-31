# Focused review routing

Use during the QA-DEV loop in `/ap:run` and `/ap:qa`. These reviewers supplement `ap-qa`;
they never replace its fresh-context diff review. The orchestrator selects roles from actual scope:

| Agent | Run when | Extra input |
|---|---|---|
| ap-acceptance | The plan has acceptance criteria | Criteria, named tests and implementation files |
| ap-regression | A shared contract, API or persisted format changes | Changed contracts and relevant callers/consumers |
| ap-security | Auth, permissions, tenant isolation, sensitive data or untrusted-input handling changes | Expected access rules, entry points and enforcement files |
| ap-cleanup | Code is removed, replaced or refactored, or temporary scaffolding is added | Changed files, replacement paths and reference evidence for removal candidates |

Skip roles whose trigger is absent; record the reason. Light plans without criteria do not need
acceptance review. Do not add every role to every task.

## Orchestrator contract

1. Prepare fresh context for each selected reviewer: short brief, working-tree diff, exact read-only
   file manifest, exclusions and relevant prior-decision excerpts obtained via `recall.sh`. Never
   send the build conversation or entire memory registers. Reviewers do not gather their own diffs.
2. Save each brief as `qa/<id>/<agent>-brief-N.md`, dispatch the selected agent, and save its reply
   verbatim as `qa/<id>/<agent>-report-N.md`. N is the current QA-DEV round, not a separate loop.
3. Missing context or an unavailable reviewer is incomplete review. Supply scoped context where
   possible; unresolved material uncertainty is parked with its dependent tasks for the final poke.
   Never silently mark an incomplete selected review clean or ask the user mid-sprint.
4. Deduplicate overlapping findings by location and scenario. Validate confirmed findings, fix
   real issues, and rerun affected reviewers after fixes; repeat `ap-qa` for the updated diff.
   Record why a finding is refuted. Cleanup reviewers never delete anything; the orchestrator
   checks removal evidence, honors file locks and frozen paths, and makes scoped cleanup edits.
   Tests and gates remain the orchestrator's responsibility.
5. `QA clean` requires the general QA report and every selected review to have no outstanding
   material findings or uncertainty. Use `config.json`'s `qaMaxRounds` (default 3); then park and leave
   `QA clean` unticked. Record each role's PASS/SKIP/FAIL/UNCONFIRMED disposition in `review-N.md`
   using `templates/review.md`. After fixes, rerun verification; seal with `finish.cjs` only when
   final evidence is clean. Reused unaffected reports retain their original filename and need a
   reason explaining why the current diff does not invalidate them. Never tick human sign-off.
