# Completion and archive evidence

1. List every changed file in Files touched, including light plans. Claim before editing or moving
   into in-progress. Use CLAUDE_SESSION_ID, or set a stable ACTIONPLAN_SESSION_ID for the sprint.
2. `node .actionplan/scripts/verify.cjs <id>` executes the plan's explicit targeted verification,
   configured lint/typecheck, and all kit gates. Configure genuine commands for this project; for
   an inapplicable check, configure an explicit command printing the reason, not a hidden skip.
   It saves PASS/FAIL, actual output and a snapshot in `qa/<id>/verification.md`.
3. Run general QA and relevant focused reviewers. Fixes require fresh verification and affected
   reviews; do not rerun a failure hoping it turns green. Keep the existing review round numbering.
4. Fill `qa/<id>/review-N.md` from `templates/review.md`. Every role is accounted for; only focused
   roles can SKIP with a reason. Reuse an unaffected focused report only with an explicit reason.
5. `node .actionplan/scripts/finish.cjs <id> N` seals current verification and report hashes into
   `completion-N.md`. Only then tick QA clean and gates. Later edits, changed reports, new rounds
   or failed verification invalidate completion. Rerun the necessary checks and reseal.
6. The human reviews evidence and ticks Human sign-off. `stage.sh <id> archived` requires explicit
   checked Human sign-off and QA clean, no open questions or unchecked DoD/tasks, plus sealed final
   evidence matching current scoped files. A malformed or missing section is never implicit approval.

The archive gate validates the same evidence structure and hashes. For already archived plans it
checks recorded evidence, not today's source contents: later legitimate development must not break
history. These checks cannot identify who edited a checkbox or interpret prose findings. Honest
review dispositions and human review remain part of the contract. Files outside the declared manifest
are outside the snapshot; the orchestrator must keep that manifest complete.

Locks are session-owned and claims are serialized. A busy registry is a refusal; retry after the
other operation. After a crash, a human must confirm no registry writer remains before removing
`.actionplan/locks/.mutex`. `lock.sh steal <id> --human-confirmed` requires an expired lock according
to lockStaleHours and explicit human approval. Agents never grant that approval themselves.

Upgrading older plans: add missing Files touched/DoD/sign-off rows and regenerate verification and
review evidence before archive. Do not manufacture historical approval to make a gate pass.
