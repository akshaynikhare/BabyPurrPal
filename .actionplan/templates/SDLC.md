# SDLC — how work moves here

Two interruptions per sprint. Everything else runs without you.

```mermaid
flowchart TD
    I["0 INIT /ap:init - once per project\nintent interview -> INTENT.md + CONSTITUTION.md"] --> P
    P["1 PLAN /ap:new\nstory + acceptance criteria + tasks + DoD"] --> C
    C["2 CLARIFY /ap:ask\nALL open questions, one batch"] --> G{"every answer in?"}
    G -- no --> C
    G -- yes --> B["3 BUILD /ap:run\nlocks -> every task -> gates\nblockers parked, never guessed"]
    B --> T["4 TEST\nQA-DEV loop until clean (max 3 rounds)\n+ browser walk if user-facing"]
    T --> R["5 REVIEW - the poke\nbanner + summary: built, QA rounds, parked, diff sizes"]
    R --> S["6 RELEASE\nhuman sign-off -> archived + 2-line retro"]
```

| Kit | Scrum |
|---|---|
| `.actionplan/planned/` + `BACKLOG.md` | Product backlog |
| A plan file | User story + its sprint backlog |
| `R1, R2…` | Acceptance criteria |
| `/ap:ask` | Backlog refinement + sprint planning |
| `/ap:run` | The sprint — no mid-sprint scope talk |
| DoD block | Definition of Done |
| The poke | Sprint review |
| 2 lines at archive | Retrospective → durable lessons to `DECISIONS.md` / `PATTERNS.md` |

**The contract:** questions are batched before code; blockers found mid-sprint are parked with one line of why and surfaced first in the poke. The human is interrupted twice — at clarify, and at review. Never in between.
