# BabyPurrPal: Godot architecture and agent rules

Godot 4.7.2 (GDScript), Mobile renderer, portrait, 60 fps cap. The project lives at the repo root next to the legacy web app. The web app is hidden from Godot by `.gdignore` and will be removed after parity.

## Rules for every agent
1. **Never touch git.** No add, commit, stash, checkout or restore. The human commits.
2. **Check locks before editing.** Run `bash .actionplan/scripts/lock.sh check <path>`; on overlap, stop and report.
3. **Edit only the folders your brief assigns** (see Ownership). Do you need a change outside them, e.g. a new EventBus signal or a project setting? Then report it; don't make it.
4. **Never install on the phone.** The orchestrator does all device work.
5. **No plan ids in code.** Comments explain *why*, briefly.
6. **Keep sounds out of code.** Every sound is a pre-rendered OGG played through `AudioDirector`; there is no runtime synthesis. The one exception is pitch-shifting recorded voice.
7. **Keep the hot path cheap.**
   - No allocations in `_process` loops.
   - No per-frame signal storms except `mouth_amplitude_changed`.
   - Cache node references in `_ready`.

## Verify (run from the repo root)
```bash
godot --headless --path . --import                    # parse/import everything; must print no ERROR
godot --headless --path . -s tests/run_tests.gd       # logic tests; exit code 0
godot --headless --path . --quit-after 120            # run main scene ~2 s headless; no ERROR/SCRIPT ERROR
```
- **Tests:** `tests/test_<area>.gd` scripts extend `TestCase` (`check`, `check_eq`, `check_near`). Test pure logic, such as state machines and detectors, by feeding synthetic data.
- **Export:** only the orchestrator runs `godot --headless --path . --export-debug "Android" build/BabyPurrPal.apk`.

## Autoloads (`autoload/`, owned by the orchestrator)
| Autoload | API |
|---|---|
| `EventBus` | Signals only; see `autoload/event_bus.gd` (talk-back state, mouth amplitude, mic permission, pet changed/reacted, zoom, time phase, UI requests). |
| `Settings` | `get_value(key)`, `set_value(key, value)` → emits `EventBus.settings_changed`. Keys: `lullaby_on`, `voice_pitch`, `talkback_on`. |
| `AudioDirector` | `play_sfx(name, volume_db, pitch)`, `play_voice(name)` (interrupts), `stop_voice()`, `play_music(name)` (loops, at `MUSIC_DB` = −12 dB, the spec's lullaby gain), `stop_music()`, `set_bus_muted(bus, muted)`, `pause_all()` / `resume_all()`, `mark_busy(seconds, tail_msec = 150)` / `is_busy()`, `set_ducked(on)`. Buses: Music, SFX, Voice, Loops (`LOOPS_BUS`, for continuous loops such as the purr). Files: `assets/audio/{sfx,voice,music}/<name>.ogg`. |
| `Haptics` | `play(pattern)`: tap, tickle, purr, paw, twinkle, bounce, feed, step. Marks AudioDirector busy for the buzz + 100 ms. |
| `Lifecycle` | Pauses the tree and AudioDirector when the app leaves the foreground, then emits `EventBus.app_paused` / `app_resumed`. Anything that must stop on background but isn't in the tree's pause (mic capture, custom buses) listens to these. |

## Folders and ownership
| Path | Owner |
|---|---|
| `project.godot`, `export_presets.cfg`, `autoload/`, `docs/`, `icon.svg`, `scenes/main.tscn` (until Phase 2) | orchestrator |
| `scripts/talkback/`, `scenes/talkback/`, `tests/test_talkback_*.gd` | talk-back agent |
| `tools/audio/`, `assets/audio/` | audio-assets agent |
| `tools/blender/`, `assets/characters/` | 3D-pets agent |
| `scenes/stage/`, `scripts/pet/`, `shaders/`, `assets/textures/` (Phase 2); `scenes/main.tscn` from Phase 2 | stage agent |
| `scenes/ui/`, `scripts/ui/`, `assets/fonts/` (Phase 2) | UI agent |

## Runtime audio buses (beyond AudioDirector's Music / SFX / Voice / Loops)
- **Mic:** muted bus with AudioEffectCapture, fed by an AudioStreamMicrophone player. Created by `TalkBack`.
- **TalkBackFX:** AudioEffectPitchShift (FFT 2048, oversampling 4), which sends to Voice. Created by `TalkBack`.

## Integration notes
- `TalkBack` (`scripts/talkback/talkback.gd`) is instanced once by the stage. Its API is `start()`, `stop()` and `play_clip(stream, envelope)`, and it responds to `EventBus.test_voice_requested`.
- **The app's own sounds and the mic:**
  - **One-shot sounds** (`play_sfx`, `play_voice`, `Haptics`) call `mark_busy`. While AudioDirector is busy, TalkBack *mutes* its detector: frames are skipped, but a clip in progress, its timers and the noise floor are kept.
  - **Continuous sounds** never mark busy. Music plays on Music; put a looping player (the purr) on `AudioDirector.LOOPS_BUS`. TalkBack calls `set_ducked(true)` from LISTEN through TALK and CELEBRATE, which drops Music and Loops by 14 dB in 80 ms and brings them back in 400 ms.
  - **Input is dropped outright** only during TALK plus a 400 ms cooldown, while a clip is processing, while the settings sheet is open, and for 300 ms after the lullaby turns on or off.
  - **Lullaby:** the mic stays open. The detector measures the room again with the music and switches to its music mode: a 3.5 s calibration and a floor that sinks slowly between notes, so chord onsets aren't taken for speech.
- **Mouth:** drive it from `EventBus.mouth_amplitude_changed`, using `set_blend_shape_value(jaw_idx, v)` on `<pet>_rig/Skeleton3D/<pet>_head`.
- **Pets:** `assets/characters/{cat,dog,bunny}.glb`.
  - Shape keys: `jaw_open`, `blink_L`, `blink_R`, `smile`, `ear_perk`.
  - Animations: `idle_breathe` (loop), `happy_bounce`, `giggle`, `paw_highfive_L`, `paw_highfive_R`, `listen_nod`, `walk_in` (loop), `look_around`, `stretch`, `ear_perk`.
  - Outlines go on the base materials only (`body`, `ear`, `paw`, `collar`, `collar_tag`, `tail_puff`). Not on `belly`, `patch`, `cheek`, `eye*`, `nose`, `mouth_inner`, `tongue` or `ear_inner`, which are thin shells.
- **Clips:** listed in `assets/audio/MANIFEST.md`. `purr_loop` is a looping SFX; play it on `AudioDirector.LOOPS_BUS`, fade it in from code and end it with `purr_tail`.

## Conventions
- **Naming:** snake_case files, PascalCase `class_name`, typed GDScript (`var x: float`, `-> void`), tabs for indentation.
- **Scenes:** small `.tscn` files with the script attached. Build complex node trees in code if writing `.tscn` by hand would be error-prone.
- **Viewport and input:** 720×1600 base, `canvas_items` stretch, `expand` aspect. Use `InputEventScreenTouch` / `InputEventScreenDrag` (mouse emulates touch on desktop).
- **Audio buses:** a custom bus (e.g. the talk-back Mic and Voice FX buses) is created at runtime by its owner via `AudioServer`, and documented here.
