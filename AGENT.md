# AGENT.md: BabyPurrPal

This repo uses **ActionPlan Kit** (`.actionplan/`). The human commits; agents never change git state.

The app is a **Godot 4.7** project (GDScript, 3D, Mobile renderer). Start here:
- [docs/GODOT_ARCHITECTURE.md](docs/GODOT_ARCHITECTURE.md): rules for agents, autoload APIs, folder ownership, runtime audio buses, verify commands.
- [docs/REWRITE_SPEC.md](docs/REWRITE_SPEC.md): the behaviour contract.

## Non-negotiables
1. **Offline, private audio.** The mic is processed on the device only, and is closed in the background and when talk-back is off. It stays open during the lullaby. Don't add network calls or cloud speech.
2. **The pet never repeats its own sounds.** Every sound goes through `AudioDirector`.
   - One-shot sounds (SFX, haptic buzz) mark it busy, which mutes talk-back's detector without dropping a clip in progress.
   - Continuous sounds (music, loops on `AudioDirector.LOOPS_BUS`) never mark busy; they are ducked while the pet listens and talks.
   - The mic is dropped outright during TALK and its cooldown.
3. **60 fps on a Helio G95.**
   - Rendering: one light, no shadows, inverted-hull outlines, pooled particles.
   - Code: no per-frame allocations, and keep the UI at about 40 draw calls or fewer.
4. **The six touch zones stay on every pet:** ears, cheeks, mouth, belly, paw_L, paw_R. Each zone keeps at least 2 reaction variants, picked at random without repeats.
5. **Verify before reporting:** `make import`, `make test`, and a headless main-scene run with no `ERROR`.

The old React/SVG design docs (`docs/GDD.md`, `docs/DESIGN_SYSTEM.md`) describe the prototype and are kept for history only.
