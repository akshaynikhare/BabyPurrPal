# AGENT.md — Autonomous Agent Operating Standard for PurrPal

Welcome, Agent. This document defines the engineering standards, architectural invariants, and verification workflows for working on the **PurrPal** codebase.

---

## 1. ActionPlan Kit Integration

This repository is powered by **ActionPlan Kit** (`action-plan-kit`).

### Command Suite
| Command | Purpose |
|---|---|
| `/ap:init` | Project intent & interview |
| `/ap:new <task>` | Create a new spec-driven task with acceptance criteria |
| `/ap:ask` | Batch all questions to the human in one single turn |
| `/ap:run <id>` | Run sprint: build, verify, QA loop, and present for review |
| `/ap:status` | Review board status, gates, and test metrics |
| `make check` | Execute all static gates via `.actionplan/scripts/check.cjs` |

### Core Rules for AI Agents
1. **Never commit or modify git state**: The human developer commits.
2. **File Locks**: Check `.actionplan/locks/*.json` before editing files in multi-session environments.
3. **No Plan IDs in Code**: Never hardcode plan IDs (e.g., `PP-0001`) in application code, components, or CSS classes.
4. **Gates Must Pass**: Run `node .actionplan/scripts/check.cjs` before declaring a sprint complete.

---

## 2. Codebase Invariants & Non-Negotiables

### A. 100% Offline Audio Processing
- **Rule**: Audio synthesis and voice mimicry must execute **strictly client-side** using the native Web Audio API (`AudioContext`).
- **Never**: Introduce third-party cloud speech APIs, streaming servers, or network calls for audio playback. The app must work in airplane mode on an airplane with a crying baby.

### B. SVG Touch Hitbox Preservation
- The 6 core interactive anatomical zones must remain mapped on all character components (`CatCharacter`, `DogCharacter`, `RabbitCharacter`):
  1. `ears`: Head/ears zone for purring, ear perking, and listening waves.
  2. `cheeks`: Blushing cheek glow, whiskers, and twinkle chimes.
  3. `mouth`: Talking Tom speech mimicry and food toy feeding.
  4. `belly`: Jiggle tickles, giggles, and floating bubbles.
  5. `leftPaw`: High-five paw swipe and marimba taps.
  6. `rightPaw`: High-five paw swipe and marimba taps.
- Always preserve `pointer-events-auto` and stop propagation on touch zones so canvas taps don't conflict with character taps.

### C. Talking Tom Speech-Sync Formula
- The SVG mouth paths must accept `mouthAmplitude: number` (normalized $0.0 \dots 1.0$) and compute:
  $$\text{mouthOpenY} = \min(36, \text{mouthAmplitude} \times 38)$$
- The open mouth geometry must display the deep interior cavity, pink tongue, and character teeth/fangs.

### D. Motion & Animation Performance
- **Rule**: Only animate compositor-friendly properties: `transform` (`scale`, `rotate`, `x`, `y`), `opacity`, and `filter`.
- Never animate layout geometry (`width`, `height`, `margin`, `top`, `left`).
- Idle bouncing is controlled via Framer Motion with an `easeInOut` duration of $1.9\text{s} \dots 2.2\text{s}$.
- Ground shadows must animate inversely with scale and opacity to simulate realistic light bouncing.

### E. Face Zoom Origin
- Pinch-to-zoom and the face toggle zoom are calibrated with `transformOrigin: '50% 36%'`.
- When modifying character SVG viewBoxes (`0 0 400 500`), the center of the head must remain at approximately $(x=200, y=180\dots210)$ so the camera focuses naturally on the face.

---

## 3. Directory Structure

```
/
├── .actionplan/            <-- ActionPlan Kit scripts, gates, and sprint storage
├── .claude/                <-- Claude Code agent commands & slash tools
├── docs/                   <-- Project documentation
│   ├── GDD.md              <-- Complete Game Design Document
│   ├── DESIGN_SYSTEM.md    <-- Visual tokens, palettes, and SVG anatomy
│   ├── _design/            <-- ActionPlan Kit design specs
│   └── _workflow/          <-- SDLC, engineering standards, SEO
├── public/                 <-- Static assets, PWA icons, manifest.webmanifest
├── src/
│   ├── components/         <-- UI Components
│   │   ├── CatCharacter.tsx
│   │   ├── DogCharacter.tsx
│   │   ├── RabbitCharacter.tsx
│   │   ├── ParticleLayer.tsx
│   │   └── ParentalModal.tsx
│   ├── services/           <-- Audio & Hardware services
│   │   ├── soundEffects.ts <-- Web Audio procedural SFX & lullaby
│   │   ├── voiceMimic.ts   <-- Web Audio VAD & pitch-shifted playback
│   │   └── haptics.ts      <-- Web Vibration API
│   ├── App.tsx             <-- Main stage & gesture controller
│   └── index.css           <-- Tailwind CSS v4 entry
├── AGENT.md                <-- This file
├── AGENTS.md               <-- ActionPlan kit agent pointer
├── Makefile                <-- Project automation
└── README.md               <-- User guide & APK compilation
```

---

## 4. Verification Workflow

Before reporting completion on any task:
1. `npm run build` or `compile_applet` must succeed with zero errors.
2. `tsc --noEmit` or `lint_applet` must pass cleanly.
3. Node gate script `node .actionplan/scripts/check.cjs` must pass.
