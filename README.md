# PurrPal - Infant Talking Pets & Reinforcement Learning Game

[![ActionPlan Kit](https://img.shields.io/badge/ActionPlan%20Kit-Enabled-blue.svg)](https://github.com/akshaynikhare/action-plan-kit)
[![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20Android%20APK-emerald.svg)](#-building-the-android-apk)
[![License](https://img.shields.io/badge/License-MIT-amber.svg)](LICENSE)

An ultra-clean, minimalist, offline-first reinforcement learning game designed specifically for infants and toddlers (ages 6 months to 2.5 years).

Featuring 3 adorable 2D cartoon companions: **Kitty Cat**, **Puppy Dog**, and **Bunny Rabbit**, with real-time Talking Tom voice mimicry, multi-zone sensory touch interactions, procedural Web Audio synthesis, Web Vibration haptics, circadian lighting cycles, and natural gesture-driven navigation.

---

## 📚 Documentation & Specifications

| Document | Purpose |
|---|---|
| **[Game Design Document (GDD)](docs/GDD.md)** | Infant operant conditioning model, sensory reward loops, audio synthesis graph, and touch matrix |
| **[Design System & Visual Spec](docs/DESIGN_SYSTEM.md)** | Color palettes, SVG geometric anatomy, eye specular formulas, and motion timing curves |
| **[AI Agent Operating Guide](AGENT.md)** | Technical invariants, coding standards, Web Audio safety, and verification rules for AI agents |
| **[ActionPlan Kit Instructions](AGENTS.md)** | Spec-driven development sprint commands (`/ap:new`, `/ap:ask`, `/ap:run`, `/ap:status`) |
| **[Engineering Standard](docs/_workflow/ENGINEERING_STANDARD.md)** | Code hygiene, testing rules, and release gates |

---

## 🌟 Key Features

### 1. Talking Tom Voice Mimicry (100% Offline)
- Built-in Voice Activity Detection (VAD) listening to the baby's coos and babbles via the Web Audio API.
- Repeats the baby's speech pitched up like Talking Tom (~1.45x) with dynamic mouth-sync matching vocal amplitude.
- No network requests, zero cloud dependencies — 100% safe, private, and works offline in airplane mode.

### 2. Natural Gesture-Driven Navigation (Distraction-Free)
- **Natural Swipe / Drag Gestures**: Babies simply swipe left or right across the screen to transition between the pets.
- **Walk-in Animation**: When switching, the next pet slowly waddles onto the screen (~1.1s) with stepping feet and pitter-patter footsteps before greeting the baby.
- **No Intrusive Buttons**: Side arrow buttons have been removed from the main stage, leaving an ultra-clean, un-cluttered viewport.

### 3. Tactile & Multi-Zone Touch Reinforcement
- **Ears**: Purring / audio ripple / heart particles.
- **Cheeks**: Blushing cheek glow / silver twinkle chimes.
- **Mouth**: Talking Tom mimicry / toy feeding / crunchy bites.
- **Belly**: Tickle wobble giggles / floating soap bubbles.
- **Paws**: High-fives forward / wooden marimba chime taps.
- **Canvas Touches**: Generates harmonious notes from the C-Major Pentatonic Scale ($C_4, D_4, E_4, G_4, A_4, C_5$).

### 4. Interactive Pinch-to-Zoom on Face
- Two-finger pinch gesture smoothly zooms into a close-up of the pet's face (1.85x scale centered at `50% 36%`), allowing toddlers to inspect fluffy fur tufts, twitching noses, and shiny gradient eyes.
- Includes a 1-tap zoom toggle button for accessibility.

### 5. Time-Aware Circadian Lighting
- Background atmosphere dynamically shifts through **Sunrise**, **Daylight**, **Sunset**, and starry **Night** modes to create a calming, natural environment.

### 6. Toddler-Proof Parental Lock (Hold 3 Seconds)
- Discreet top gear icon requires holding for 3 seconds to access:
  - Soothing background pentatonic lullaby toggle & volume.
  - Voice pitch modifier (1.2x to 1.8x).
  - Microphone sensitivity adjustments.

---

## 🚀 Quick Start & Development

### Prerequisites
- Node.js 22 or 24
- npm or pnpm

### Running Locally
```bash
# Clone the repository
git clone https://github.com/akshaynikhare/purrpal-baby-game.git
cd purrpal-baby-game

# Install dependencies
npm install

# Start development server on port 3000
npm run dev
```
Open [http://localhost:3000](http://localhost:3000) in your browser.

### ActionPlan Kit Commands
```bash
# Run kit verification gates
make check
# or directly:
node .actionplan/scripts/check.cjs

# View sprint board status
make status
```

---

## 📱 Building the Android APK

This repository is pre-configured with two ways to generate your standalone Android APK:

### Method 1: Automatic GitHub Actions (Recommended)
1. Push your repository to GitHub.
2. Navigate to the **Actions** tab.
3. Select **"Build Android APK for Toddlers"** and click **Run workflow**.
4. Download the compiled `PurrPal-BabyGame-debug.apk` directly from the workflow **Artifacts** section!

### Method 2: Local APK Build Script
With Android Studio & SDK installed locally:
```bash
npm run build:apk
```
The debug APK is generated at:
`android/app/build/outputs/apk/debug/app-debug.apk`

---

## 🛠️ Tech Stack

- **Framework**: React 19 + TypeScript + Vite
- **Styling**: Tailwind CSS v4
- **Animations**: Motion (`motion/react` / `framer-motion`)
- **Audio Engine**: Web Audio API (procedural synthesis, VAD analyser, buffer pitch shifting)
- **Haptics**: Web Vibration API
- **Packaging**: Vite PWA (`vite-plugin-pwa`) / Capacitor Android (`@capacitor/android`)
- **Spec-Driven Kit**: [ActionPlan Kit](https://github.com/akshaynikhare/action-plan-kit)

---

## 📄 License

MIT License. Designed with care for infants and parents.
