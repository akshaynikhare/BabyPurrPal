# Engineering Standard — {{NAME}}

> The norm for NEW code. Divergences in old code are recorded in §10, not pretended away.

## 1. Layering
| Layer | Does | Never |
|---|---|---|
| UI / screens | configure, render | compute money, call the DB, own business rules |
| Services | decide, orchestrate | render, reach around the data layer |
| Data | one authority per model | leak raw rows past the service |

## 2. Reuse ladder
Search → Reuse → Extend → Create. Used twice → consider extracting; three times → extraction mandatory.
Find the most similar existing implementation and mirror its structure. Match the file you're in.

## 3. Minimal code
Only what the requirement needs. No future-proofing, no premature abstraction, no wrappers with one caller.
Comments only where the logic is not self-evident. Three similar lines beat a premature helper.

## 4. Errors
Fail loudly. "Silently" is the most expensive adverb in production — no silent catches, no swallowed
promise rejections, no defaults that mask a missing value. Log with enough context to act on.

## 5. Testing
Pyramid: many unit, some integration, few e2e. Every acceptance criterion names its test.
Measure against green — a new failure means you broke it; fix it, never re-baseline it. Ratchet up, never down.

## 6. Money & precision
The server is the only calculator. Clients render server-provided strings.
No float arithmetic on money, no client-side `* tax`, `/ months`, `.reduce()` over amounts.
Never swap a currency glyph for an abbreviation.

## 7. Security floor
Validate on the server. Scope every query to the caller's tenant/role — an id from the client is a claim,
not a fact. No secrets in code. Authz gets asserted in tests, not assumed.

## 8. Definition of Done
All tasks ticked or parked-with-why · criteria → tests named and existing · gates green ·
QA-DEV clean · walk if user-facing · SEO row if public · design row if UI changed · human sign-off last.

## 9. Docs
Markdown only. Diagrams as mermaid blocks. Never a binary diagram file, never a web artifact.
Facts date-stamped `(verified YYYY-MM-DD)`; stale claims labelled stale, not deleted.

## 10. Current divergences (what IS — don't pretend otherwise)
- none recorded (verified {{DATE}})
