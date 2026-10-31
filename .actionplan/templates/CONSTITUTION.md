# CONSTITUTION — {{NAME}}

> The non-negotiables. Every plan is checked against this file by the critic.
> Changing a line here requires a `DECISIONS.md` entry saying why.

## Tech
- Allowed stack: TODO(verify)
- Never introduce without a decision entry: a second icon library, a second state manager, a second styling system.

## Quality bars
- Every acceptance criterion names its test before the story is Done.
- Measure against green — a new failure is a real break; fix it, never baseline it.
- Ratchet up, never down.

## Money & data
- The server is the only calculator. Clients render strings.
- No float arithmetic on money. Never swap a currency glyph.
- User data leaves the system only through reviewed endpoints.

## Process
- Sprint model: all questions first, build everything, QA, one poke. Human signs off last.
- No plan ids in code. No git operations by agents. No web artifacts.
