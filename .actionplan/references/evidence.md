# Evidence standard

A claim is proved, inferred, or asserted. Only proved claims drive decisions.

- Cite `file:line` and the symbol for every code claim.
- Quantify recon: "0 `getByTestId`, 176 `getByRole`" beats "the repo mostly uses roles".
- Compute, never infer: a height you set but never measured is not evidence of no overlap.
- Trace an id to the table it is generated in before trusting a guard that validates it.
- Test the DEFAULT execution path, not the dev/inline fallback that masks the bug.
- Subagent findings are verified at the source before being relayed — sibling audits produce false positives.
- A file that "does not exist" is a finding to verify with a wider search, never a coverage exemption.
- Date-stamp verified facts: `(verified 2026-09-12)`. Re-verify before reusing an old stamp.
