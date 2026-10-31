# Acceptance criteria — EARS format

Every requirement is one testable sentence, ID'd R1, R2, …

| Pattern | Shape | Example |
|---|---|---|
| Event | WHEN <trigger> THEN <response> | WHEN idle 30s THEN log out |
| State | WHILE <state> THEN <behaviour> | WHILE offline THEN queue nothing, block writes |
| Condition | IF <condition> THEN <response> | IF the coupon is expired THEN show "expired", keep the cart |
| Unwanted | WHEN <failure> THEN <safe outcome> | WHEN the API 500s THEN show retry, lose no input |
| Always | THE SYSTEM SHALL <invariant> | THE SYSTEM SHALL never render a price it computed itself |

Rules:
- One behaviour per criterion. "And" usually means two criteria.
- Each R-row in the DoD names its test: `- [ ] R1 covered → tests/auth/login.test.ts :: "logs out after 30s idle"`.
- The test file and test name must exist (checked by the `checklist-trace` gate). The test never mentions the plan id.
- Unhappy paths get their own R — a feature with only happy-path criteria is not specified.
