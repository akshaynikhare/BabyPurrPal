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
  - Under `-s` the autoloads are not in the tree yet: `AudioDirector.play_sfx` / `start_sfx` do nothing there, and tests that need its players or buses build a fresh instance and call `_ready()`.
- **Exit leaks:** in 4.7.2 headless, any stream still playing on the quit frame prints `ObjectDB instances were leaked` / `resources still in use` at exit (an idle-break sound can land on it). It's the engine's dummy driver, not our scripts; rerun to confirm.
- **Export:** only the orchestrator runs `godot --headless --path . --export-debug "Android" build/BabyPurrPal.apk`.

## Autoloads (`autoload/`, owned by the orchestrator)
| Autoload | API |
|---|---|
| `EventBus` | Signals only; see `autoload/event_bus.gd` (talk-back state, mouth amplitude, mic permission, pet changed/reacted, zoom, time phase, UI requests). |
| `Settings` | `get_value(key)`, `set_value(key, value)` → emits `EventBus.settings_changed`. Keys (all saved): `lullaby_on` (false), `voice_pitch` (1.45), `talkback_on` (true), `music_on` (false, day music while the lullaby is off), `ambience_on` (true, room ambience), `quiet_mode` (false, Master −8 dB). Talk-back treats `lullaby_on or music_on` as "music playing". |
| `AudioDirector` | `play_sfx(name, volume_db, pitch)`: a name with takes `<name>_1..N` plays one of them, never the same twice in a row; animal and body sounds vary ×(1±0.03) pitch and ±1.5 dB per play (`chime_*`, `ui_*`, `twinkle`, `sunrise`, `nightfall`, `yum`, `giggle`, `purr_tail` stay steady). `start_sfx(name)` / `stop_sfx(name)`: a sound its caller ends (the run patter, the gear-hold rise), on its own player outside the SFX pool; the mic counts as busy while it plays. `play_ambience(name)` / `stop_ambience()`: a room loop on Loops, cross-faded over 2 s. `play_voice(name)` (interrupts), `stop_voice()`, `play_music(name)` (loops, at `MUSIC_DB`), `stop_music()`, `set_bus_muted(bus, muted)`, `pause_all()` / `resume_all()`, `mark_busy(seconds, tail_msec = 150)` / `is_busy()`, `set_ducked(on)`, `take(name)` / `varies(name)`. Files: `assets/audio/{sfx,voice,music}/<name>.ogg`. |
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

## The mix (AudioDirector, created at runtime)
The pets' voice lines are the anchor: `-19 LUFS` files on Voice at 0 dB. File loudness is set by `tools/audio/gen_sounds_eleven.py` (one-shots −22 LUFS, `ui_*` −25, loops −24, `amb_*` −30, music −20); the buses and players set the balance:

| Where | Level | Lands |
|---|---|---|
| SFX bus | `SFX_DB` −3 dB, then a hard limiter (ceiling −1 dB, before the fader) | one-shots ~6 dB under the voice; a burst of them is held to one sound's level, so it can't push the Master limiter down on the voice |
| Music player | `MUSIC_DB` −8 dB | lullaby / day music ~9 dB under the voice |
| Ambience players (Loops) | `AMBIENCE_DB` −9 dB | ~20 dB under the voice |
| Purr player (Loops) | `PURR_DB` −2 dB (stage) | as before |
| Master | hard limiter, ceiling `LIMIT_CEILING_DB` −1 dB; `quiet_mode` sets the bus to `QUIET_DB` −8 dB | never clips |

## Sound map
Every sound plays through `AudioDirector` by name; the tables are the source of truth.

| Event | Sound | Table |
|---|---|---|
| Walk-in steps | cat `pad`, dog `step`, bunny `hop` | `PetSounds.STEPS` |
| Clips (`sit_down`, `lie_down`, `get_up`, `jump`, `pounce`, `laugh_tumble`, `happy_wiggle`, `scratch_ear`, `head_shake`, `excited`) | `sit`, `lie`, `rollover`, `jump`+`land`, `pounce`, `tumble`+`rollover`, `wiggle`+`swish`, `scratch`+`flap`, `flap`, excited call (cat `chirp`, dog `pant`, bunny `thump`), timed into the clip | `PetSounds.CLIPS` (`Pet` plays them on `animation_started`) |
| Chase run | `run` loop until the run clip gives way | `Pet.play_run` |
| Rare idle surprise (45–90 s) | `sneeze` (nose twitch) / `hiccup`, with a squash | `PetIdle.surprise`, `PetSounds.SURPRISES` |
| Zones, greeting, come-play wave | per-pet calls (cat `meow`/`chirp`/`trill`, dog `woof`/`yip`/`pant`/`whine`, bunny `squeak`/`snuffle`); belly `boing` | `PetReactions` |
| Echo bookend | after the child's echo (TALK out of LISTEN, then CELEBRATE): cat `chirp`, dog `yip`, bunny `squeak`, 6 dB down | `PetSounds.ECHO_CALL` |
| Toy bites / laps | cat `nibble`, dog `gnaw`, bunny `crunch` (clover `munch`); cat/dog `lap`, bunny `sip`; milk `gulp`s, last swallow or lap `slurp` | `PetSounds.EAT` / `DRINK`, `ToySession` |
| Toy props | appear `pop_in` (milk + `pour_milk`; water `bowl` + `pour_water`), vanish `pop_out`, lift milk `clink` / bone `squeaky`, ball `bounce`, yarn `roll`, bell `jingle` | `ToyScript` (`appear_sfx`, `lift_sfx`, `roll_sfx`, `eat_sfx`), `ToySession` |
| Toy finale | `end_sfx` / `end_voice` (dog bone: `sigh`) | `ToyScript` |
| Time of day | ambience `amb_morning` / `amb_day` / `amb_evening` / `amb_night` (from the first touch, if `ambience_on`); `sunrise` / `nightfall` chimes when the phase turns (clock or sun button; the button twinkles for the other two) | `TimeOfDay.AMBIENCE` / `CHIMES` |
| UI | toy `ui_toy`, locked toy `ui_nope`, sheet `ui_open` / `ui_close`, gear hold `ui_hold` → `ui_unlock`, slider `ui_tick`, switches `ui_tap`, zoom `ui_zoom_in` / `ui_zoom_out`, pet swipe `ui_swipe` | UI scripts, stage |

Voice lines (PetVoice): `toy_<id>` as a toy appears; `come_play*` with the wave; walk-in `morning` at sunrise, `night` at night, else `hello*`; `yawn` with the idle yawn at night; now and then `hum` on an idle break with the lullaby on.

## Runtime audio buses (beyond AudioDirector's Music / SFX / Voice / Loops)
- **Mic:** muted bus: AudioStreamMicrophone → high-pass 120 Hz → low-pass 7 kHz (Q 0.707) → AudioEffectCapture. Created by `TalkBack`.
- **TalkBackFX:** pitch shift (FFT 2048, ×4) → low shelf 500 Hz → high shelf 4 kHz → compressor (−18 dB, ratio 1.5 ≈ 3:1, +6 dB) → hard limiter −1 dB, sending to Voice. Created by `TalkBack`. Only the child's echo and the babble go through it; total pitch = `voice_pitch` × the pet's share, split between playback speed (the pet's resample, capped at the total) and the shifter. Each pet's character is in `TalkBack.PET_ECHO`; the stage calls `TalkBack.set_pet(pet_id)`. The pets' own lines play straight to Voice. Lullaby/day music put the detector in music mode; ambience doesn't, the detector's start rules (ring-out within 6 dB, centred below 3 kHz) reject clock ticks and birdsong.

## Integration notes
- `TalkBack` (`scripts/talkback/talkback.gd`) is instanced once by the stage. Its API is `start()`, `stop()` and `play_clip(stream, envelope)`, and it responds to `EventBus.test_voice_requested`.
- **The app's own sounds and the mic:**
  - **One-shot sounds** (`play_sfx`, `play_voice`, `Haptics`) call `mark_busy`. While AudioDirector is busy, TalkBack *mutes* its detector: frames are skipped, but a clip in progress, its timers and the noise floor are kept.
  - **Continuous sounds** never mark busy. Music plays on Music; looping players (the purr, the room ambience) go on `AudioDirector.LOOPS_BUS`. TalkBack calls `set_ducked(true)` from LISTEN through TALK and CELEBRATE, which drops Music and Loops by 24 dB (`DUCK_DB`) in 80 ms and brings them back in 400 ms. The run patter is a loop but plays on SFX through `start_sfx`, so it does mark busy.
  - **Input is dropped outright** only during TALK plus a 400 ms cooldown, while a clip is processing, while the settings sheet is open, and for 300 ms after the lullaby turns on or off.
  - **Lullaby:** the mic stays open. The detector measures the room again with the music and switches to its music mode: a 3.5 s calibration and a floor that sinks slowly between notes, so chord onsets aren't taken for speech.
- **Mouth:** drive it from `EventBus.mouth_amplitude_changed`, using `set_blend_shape_value(jaw_idx, v)` on `<pet>_rig/Skeleton3D/<pet>_head`.
- **Pets:** `assets/characters/{cat,dog,bunny}.glb`.
  - Shape keys: `jaw_open`, `blink_L`, `blink_R`, `smile`, `ear_perk`.
  - Animations: `idle_breathe` (loop), `happy_bounce`, `giggle`, `paw_highfive_L`, `paw_highfive_R`, `listen_nod`, `walk_in` (loop), `look_around`, `stretch`, `ear_perk`.
  - Outlines go on the base materials only (`body`, `ear`, `paw`, `collar`, `collar_tag`, `tail_puff`). Not on `belly`, `patch`, `cheek`, `eye*`, `nose`, `mouth_inner`, `tongue` or `ear_inner`, which are thin shells.
- **Clips:** listed in `assets/audio/MANIFEST.md`. The stage owns the purr player on `AudioDirector.LOOPS_BUS`: the cat's `purr_loop` (ended with `purr_tail`) and the bunny's `purr_bunny` (a slower fade, no tail), faded in and out from code. The dog has no purr.

## Conventions
- **Naming:** snake_case files, PascalCase `class_name`, typed GDScript (`var x: float`, `-> void`), tabs for indentation.
- **Scenes:** small `.tscn` files with the script attached. Build complex node trees in code if writing `.tscn` by hand would be error-prone.
- **Viewport and input:** 720×1600 base, `canvas_items` stretch, `expand` aspect. Use `InputEventScreenTouch` / `InputEventScreenDrag` (mouse emulates touch on desktop).
- **Audio buses:** a custom bus (e.g. the talk-back Mic and Voice FX buses) is created at runtime by its owner via `AudioServer`, and documented here.
