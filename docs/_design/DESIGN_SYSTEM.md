# Design System — PurrPal

> The single source for UI decisions across PurrPal.

See the complete visual specification and SVG anatomy in [docs/DESIGN_SYSTEM.md](../DESIGN_SYSTEM.md).

## Tokens
- **Theme Palettes**: Defined in `docs/DESIGN_SYSTEM.md` and character components (`CatCharacter.tsx`, `DogCharacter.tsx`, `RabbitCharacter.tsx`).
- **Colors**: Defined with daytime and nighttime lighting modes.
- **Icons**: Lucide React (`lucide-react`).

## Motion
- Idle Bouncing: 2.2s `easeInOut` breathing cycle.
- Walk Transition: 1.1s cubic-bezier waddle cycle.
- Face Zoom: Framer Motion spring (`stiffness: 240, damping: 24`).

## Accessibility Floor
- High contrast, baby-friendly colors.
- Generous touch targets (>48px).
- Zero flashing strobes or overstimulating elements.
