# Comprehensive Documentation, Design Specifications, Agent Guide & UI Simplification

A complete, production-grade documentation suite for **PurrPal**, consisting of a Game Design Document (`docs/GDD.md`), Design System Specification (`docs/DESIGN_SYSTEM.md`), updated production `README.md`, an AI Agent Protocol guide (`AGENT.md`), and removing the left/right arrow buttons from the main screen for a distraction-free, swipe-only baby experience.

---

### User Review & Critical Decisions

> [!IMPORTANT]
> Confirmed user choices:
> - **UI Simplification**: Remove the left and right arrow buttons from the main screen so the interface is ultra-minimalist and baby-friendly, relying solely on natural touch swipe gestures.
> - **Focus of Documentation Suite**: Comprehensive Game Design Document (GDD), visual design tokens, and technical architecture.
> - **Structure of Design Files**: Markdown design specifications with SVG component breakdowns, geometric anatomy formulas, and color tokens.

---

## 1. Overview & Core Concept

### What It Delivers
1. **Distraction-Free Minimalist UI**:
   - Remove the left/right arrow button controls on the sides of the character screen in `App.tsx`.
   - Infant navigation is 100% natural touch swipe (or drag) across the screen, removing accidental button presses.
2. **`docs/GDD.md` (Game Design Document)**:
   - Core game loop and infant operant conditioning (action $\rightarrow$ instant sensory reward).
   - Interaction matrix: touch zone hitboxes, audio frequencies, haptic motor vibrations, and visual particle reinforcement.
   - Offline Talking Tom audio pipeline: Web Audio VAD, buffer pitch shifting, and mouth amplitude synchronizer.
   - Time-aware environmental day/night cycle and calming lullaby frequencies.
3. **`docs/DESIGN_SYSTEM.md`**:
   - Visual tokens: Color palettes for all 3 themes per pet (Midnight, Ginger, Cloud for Cat; Golden, Chocolate, Spotted for Dog; White, Honey, Smokey for Rabbit).
   - SVG vector anatomy breakdown: mathematical pathing, radial gradient definitions, 3-tiered fluffy cheek tufts, glossy eye specular geometry, and touch target coordinate mapping.
   - Motion & typography specifications: easing curves, idle bouncing harmonics, waddle walking cycles, and typography rules.
4. **`README.md` (Updated & Expanded)**:
   - Complete project overview, architecture diagram, local development instructions, PWA installation, and Android APK compilation guide (GitHub Actions & Capacitor CLI).
5. **`AGENT.md`**:
   - Technical guide for AI coding agents and engineers working on the codebase: strict coding standards, anti-slop rules, Web Audio constraints, SVG hitbox preservation, Framer Motion protocols, and verification workflows.

---

## 2. User Experience & Visual Design

### UI Changes (`App.tsx`)
- Remove the `<button aria-label="Previous animal" ...>` and `<button aria-label="Next animal" ...>` overlay elements.
- The animal character stays centered, uncluttered, with natural horizontal touch drag/swipe gestures (`drag="x"`) to trigger the walk-in transition to the next pet.

### Design Architecture & Asset Map
```
docs/
├── GDD.md               <-- Comprehensive Game Design Document & Infant RL Model
└── DESIGN_SYSTEM.md     <-- Visual design tokens, SVG anatomy, and palette matrices
AGENT.md                 <-- Autonomous agent guide & engineering rules
README.md                <-- Project overview, quickstart & build instructions
src/
└── App.tsx              <-- Ultra-clean UI (arrow buttons removed)
```

---

## 3. Technical Architecture & Component Hierarchy

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PurrPal System Architecture                     │
└────────────────────────────────────────────────────────────────────────┘
                                    │
          ┌─────────────────────────┴────────────────────────┐
          ▼                                                  ▼
┌───────────────────────┐                          ┌───────────────────┐
│     User Interface    │                          │   Sensory Audio   │
│  (Pure Swipe Gestures)│                          │    & Haptic Bus   │
├───────────────────────┤                          ├───────────────────┤
│ • App.tsx (No buttons)│                          │ • soundEffects.ts │
│ • CatCharacter.tsx    │◄──────Touch Events──────►│ • voiceMimic.ts   │
│ • DogCharacter.tsx    │                          │ • haptics.ts      │
│ • RabbitCharacter.tsx │                          │                   │
│ • ParticleLayer.tsx   │                          │                   │
│ • ParentalModal.tsx   │                          │                   │
└───────────────────────┘                          └───────────────────┘
          │                                                  │
          ▼                                                  ▼
┌───────────────────────┐                          ┌───────────────────┐
│ Documentation Suite   │                          │  Mobile Runtime   │
├───────────────────────┤                          ├───────────────────┤
│ • README.md           │                          │ • Vite PWA (SW)   │
│ • docs/GDD.md         │                          │ • Capacitor CLI   │
│ • docs/DESIGN_SYS.md  │                          │ • Android Gradle  │
│ • AGENT.md            │                          │                   │
└───────────────────────┘                          └───────────────────┘
```

---

## 4. Execution Steps

1. **Update `App.tsx`**: Remove the left and right navigation buttons to leave the main screen clean and focused entirely on the pet and touch swipe gestures.
2. **Create `docs/GDD.md`**: Game Design Document detailing baby sensory psychology, reinforcement learning mechanics, touch interaction matrix, and procedural audio synthesis.
3. **Create `docs/DESIGN_SYSTEM.md`**: Comprehensive design tokens, SVG vector diagrams, color palettes, eye sparkle geometry, and typography specs.
4. **Create `AGENT.md`**: Complete AI agent operating guidelines, engineering rules, state invariants, and verification steps.
5. **Update `README.md`**: Polish and integrate links to documentation, architecture diagrams, and testing/deployment details.
6. **Verify**: Run `compile_applet` and `lint_applet` to confirm zero regressions.
