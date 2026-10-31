# Design System — {{NAME}}

> The single source for UI decisions. Hardcoded values in components are findings, not style.

## Tokens
- Where they live: TODO(verify) — the ONE file/module components import from.
- Colors: defined for light AND dark. A component with a hex literal = a finding.
- Spacing scale · radius · type scale: named tokens only.

## Components — never hand-roll
| Need | Use the shared | Never |
|---|---|---|
| Overlay / modal | TODO(verify) | a bare positioned div |
| Confirm | TODO(verify) | `window.confirm` |
| Table / list | TODO(verify) | ad-hoc `<table>` styling |
| Tabs | TODO(verify) | hand-rolled button rows |
| Toast / feedback | TODO(verify) | `alert()` |

## Icons
- **ONE library:** TODO(verify). Adding a second is a finding, not a preference.

## Motion
- Durations + easing tokens. Honor reduced-motion. No animation that blocks input.

## Accessibility floor
- Contrast ≥ 4.5:1 body text · visible focus states · touch targets ≥ 44px · labels on every input.

## Rule
**Test light AND dark before any UI ships.** The walk's "Off-brand" lens checks this file live.
Enforce with `/ap:gate design-tokens` once the token file above is real.
