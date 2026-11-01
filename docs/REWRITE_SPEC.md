# BabyPurrPal: Godot rewrite spec

This spec covers what the React/Capacitor version (v0.0.1) does, which the Godot 4 rewrite must keep, plus the changes the rewrite introduces.

- **Values:** taken from the old source (`src/`, kept in the repo until parity). Where the code and older docs disagree, the code wins.
- **Changes:** listed under "Rewrite changes" at the end.

## Flow (one screen, no start screen)

**Layout**
- **Header:**
  - Left: a voice-state pill. While listening it reads "Listening! 👂" (amber); while repeating, "Repeating! 🗣️" (blue). Otherwise it shows the pet's name: "Kitty Cat 🐱", "Puppy Dog 🐶" or "Bunny Rabbit 🐰".
  - Right: a time-phase button, a zoom toggle (44 px) and the gear.
- **Stage:** the pet.
- **Footer:** 3 toys for the current pet.

**Starting audio**
- Before audio starts, a pulsing "Tap to Enable Sound & Talking Pet" button is shown.
  - Tapping it starts audio, then the mic (which asks for permission), then plays chime 3.
  - The first touch anywhere on the background does the same.
- If the mic is denied, a pill reads "Tap pet's mouth or toys below to hear speech!".

**Pets:** cat → dog → rabbit, wrapping around.

**Time of day**
- Set from the clock hour: 5–9 sunrise, 9–17 day, 17–20 sunset, otherwise night.
- The clock is re-read every 60 s.
- The button cycles sunrise → day → sunset → night, with the twinkle sound and haptic.
- Old background gradients:

| Phase | Gradient |
|---|---|
| sunrise | `#FFF0E6 → #FFF8EE → #FFE5D9` |
| day | `#EDF6FF → #FFFDF7 → #F1F5F9` |
| sunset | `#FFE8D6 → #F3E8EE → #E3D5EE` |
| night | `#0B132B → #1C2541 → #0A0E21`, with 7 pulsing stars |

## Gestures

**Background tap**
- `tap` haptic.
- Plays the next chime, stepping in order through the 10-note scale.
- 4 particles at the touch point: bubble on even indexes, sparkle on odd.

**Swipe** (evaluated on release)
- Counts as a swipe when `|dx| > 45`, `|dx| > |dy| × 1.2` and the gesture took under 800 ms.
- Swiping left goes to the next pet; swiping right goes to the previous one.

**Switching pets**
- Resets zoom.
- Footstep sound and `step` haptic at 0, 300 and 650 ms.
- The new pet walks in from ±260 to 0 over 1.1 s, fading opacity from 0.1 to 1. The next pet enters from the right.
- It then greets you:
  - Cat: purrs for 1200 ms (`purr` haptic) with happy eyes.
  - Dog: woofs (`bounce` haptic) and is happy for 1200 ms.
  - Rabbit: squeaks (`bounce` haptic) and is happy for 1200 ms.

**Pinch**
- Spreading to more than 1.22× zooms in (`bounce` haptic + twinkle). Pinching below 0.82× zooms out (`tap` haptic).
- The base distance resets after each change.
- Zoom is a 1.85× face close-up. The zoom button toggles it too.
- While zoomed, a "Face Close-Up (Pinch or Tap to Reset)" pill shows.

**Touch zones** don't chime the background.

## Zone reactions
Notation:
- `bubble×8` means 8 bubble particles.
- "Mimic if IDLE" means the pet plays its simulated babble, but only while talk-back is idle.

| Zone | Cat | Dog | Rabbit |
|---|---|---|---|
| belly | tickled 600 ms, giggle, `tickle` haptic, bubble×8 | same as cat, plus pant | same as cat |
| ears | purr 1600 ms + twinkle, `purr` haptic, heart×7 | happy 1400 ms, pant, `bounce` haptic, heart×7 | happy 1200 ms, squeak, `bounce` haptic, heart×7 |
| cheeks | twinkle, `twinkle` haptic, sparkle×6 | woof, `bounce` haptic, mimic if IDLE, star×6 | twinkle, `twinkle` haptic, sparkle×6 |
| mouth | `bounce` haptic; if IDLE, mimic + star×6 | same as dog cheeks | carrot crunch, `feed` haptic, mimic if IDLE, star×6 |
| paws (left/right) | paw tap, `paw` haptic, paw×5, paw raised 500 ms | same | same |

## Toys
Every toy also plays the `feed` haptic. Particles appear at the toy.

| Pet | Toy | Reaction |
|---|---|---|
| Cat | 🥛 Warm Milk | purr 1500 ms, heart×8 |
| Cat | 🐟 Fish Snack | paw tap, tickled 500 ms, star×8 |
| Cat | 🧶 Yarn Ball | giggle, tickled 500 ms, bubble×10 |
| Dog | 🦴 Juicy Bone | paw tap + woof, happy 1000 ms, star×8 |
| Dog | 🎾 Tennis Ball | giggle, tickled 500 ms, bubble×9 |
| Dog | 💧 Fresh Water | pant, happy 1200 ms, heart×7 |
| Rabbit | 🥕 Crunchy Carrot | crunch, happy 1000 ms, star×8 |
| Rabbit | 🍀 Sweet Clover | squeak, happy 1000 ms, heart×8 |
| Rabbit | 🔔 Silver Bell | twinkle, tickled 500 ms, bubble×9 |

## Parent gate and settings

**Gate**
- Hold the gear for **3000 ms**. The old code used 2500 ms; the rewrite uses 3000 ms, matching the label.
- When the hold completes: the settings sheet opens, with the twinkle sound and haptic.
- Releasing before 90% plays chime 4 and the `tap` haptic.

**Settings sheet ("Sound Settings")**
- **"Soothing Lullaby"** ("Gentle calming chords"): ON/OFF, default OFF.
- **"Voice Pitch"** slider:
  - range 1.2–1.8, step 0.05, default 1.45
  - end labels "Natural (1.2x)" and "Cute High (1.8x)"
  - shows the value to 2 decimals
- **"Test Voice"** plays the simulated babble.
- **Done**, **X** or tapping the backdrop closes the sheet.
- **New:** settings are saved (`lullaby_on`, `voice_pitch`, `talkback_on`).

## Audio (old procedural recipes; render each to OGG)
Master gain 0.8; lullaby gain 0.25.

| Sound | Recipe |
|---|---|
| Scale | C4–A5: 261.63, 293.66, 329.63, 392, 440, 523.25, 587.33, 659.25, 783.99, 880 |
| chime | Sine → lowpass 1600 Hz. Gain 0.0001 → 0.35 in 15 ms, exponential decay to 0.0001 at 0.7 s. Plus an unfiltered sine at 2f, gain 0.08, decays by 0.35 s. |
| giggle | Triangles 400, 560, 480, 640, 520, 700 Hz, 70 ms apart. Each rises ×1.2 over 60 ms. Gain 0.2, attack 10 ms, decays by 60 ms. |
| paw tap | Triangle 320 → 140 Hz over 150 ms. Gain 0.3, decays by 200 ms. |
| twinkle | Sines 659.25, 783.99, 987.77, 1318.51 Hz, 50 ms apart. Gain 0.18, decays by 200 ms. |
| purr | Sawtooth 26 Hz → bandpass 80 Hz (Q 1.5), with a 3.6 Hz wobble. Fades in to 0.35 over 0.3 s; fades out over 0.25 s. Render a seamless loop plus a tail. |
| woof | Triangle 260 → 460 Hz (60 ms) → 220 Hz (220 ms). Bandpass 500 Hz (Q 1.2). Gain 0.38, attack 30 ms, decays by 240 ms. |
| pant | 3 sines, each 180 → 120 Hz over 80 ms, 120 ms apart. Gain 0.12, decays by 90 ms. |
| squeak | Sine 880 → 1380 Hz over 120 ms. Gain 0.24, decays by 220 ms. |
| crunch | Triangles 740, 920, 680, 840 Hz, 60 ms apart. Each falls ×0.5 over 40 ms. Gain 0.2, decays by 45 ms. |
| footstep | Triangle 180 → 80 Hz over 60 ms. Gain 0.15, decays by 70 ms. |
| lullaby | Chords C [261.63, 329.63, 392], Am [220, 261.63, 329.63], F [174.61, 261.63, 329.63], G [196, 246.94, 293.66]. Notes arpeggiated 0.45 s apart. Each sine → lowpass 900 Hz, gain 0.18, 0.1 s attack, decays by 2.8 s. Next chord every 3200 ms. Render one seamless loop. |
| babble | "Test voice" and mimic when there's no mic. A 1.4 s clip that steps through 520 Hz (0 s), 650 Hz (0.3 s), 440 Hz (0.6 s), 720 Hz (0.9 s). Sample formula: `(sin(2πft) + 0.3·sin(4πft)) × (0.5·sin(24t) + 0.5) × 0.45`. It is played through the talk-back pitch path. |

## Haptics
Defined in `autoload/haptics.gd`: tap, tickle, purr, paw, twinkle, bounce, feed, step.

## Rewrite changes (new requirements)

1. **Engine and stage:**
   - Godot 4.7 with the Mobile renderer, 3D.
   - Portrait locked, 60 fps cap.
   - One pet on stage in a small cozy room.
2. **Look**
   - Inspired by the mood of *Organized Inside*. No assets copied, and the characters are original. Toon/cel shading plus **warm-brown outlines (`#7A5233`)**.
   - **Room colours:** pastel and polka dots. The room tint follows the time-of-day phases.
   - **UI:** cream panels with rounded corners, brown outlines and a rounded OFL font.
   - **Pets:** original, toy-like and chubby, in a 3/4 view.
     - **Cat:** a cream/ginger body. It must *not* be a black blob cat (Organized Inside's mascot) or a grey tabby (Talking Tom).
     - **Dog:** golden.
     - **Rabbit:** white/pink.
   - **Rigs:** each pet has
     - shape keys `jaw_open`, `blink_L`, `blink_R`, `smile`, `ear_perk`
     - bones for the head, ears, tail, paws and spine
     - actions `idle_breathe`, `happy_bounce`, `giggle`, `paw_highfive_L`, `paw_highfive_R`, `listen_nod`, `walk_in`
3. **Touch zones:**
   - Each body part (belly, ears, cheeks, mouth, paw L/R) gets an Area3D collider.
   - Each zone keeps the old reaction above, plus at least 2 animation variants picked at random without repeats.
   - Idle breaks every 6–12 s: look around, stretch, blink.
4. **Talk-back** (Talking Tom pattern; see `research/talking-tom-teardown.md`):
   - **States:** NOT_READY → READY_TO_LISTEN → LISTEN → TALK → (CELEBRATE) → READY_TO_LISTEN. Also DONT_HEAR (mic denied) and CANT_TALK (talk-back off).
   - **Noise floor:** calibrated at the start and kept as a running average. Recording starts when the level is above floor × start factor for about 100 ms, with about 300 ms of pre-roll. It stops after N quiet chunks (about 700 ms), with a minimum of 0.4 s and a maximum of 6 s.
   - **Clean-up:** trim trailing silence, apply a 60 ms fade-out, then normalize peak to about −3 dBFS.
   - **Playback:**
     - Voice bus with `AudioEffectPitchShift`: `pitch_scale` = setting ± a random 0.05, with a slight wobble. Pitch rises without the voice speeding up.
     - **Never** re-hear its own playback: the mic is gated during TALK, plus about 400 ms of cooldown.
     - **The app's own sounds:** a one-shot sound (SFX, haptic buzz) only pauses the detector for its length plus a short tail (150 ms; 100 ms for haptics). A clip in progress carries on, minus that part. Continuous sounds (the lullaby, the purr) never pause it; they duck by 14 dB while the pet listens and talks.
     - **Lullaby:** the mic stays open. About 300 ms after the lullaby starts or stops, the noise floor is measured again, with music-aware settings while it plays.
   - **Mouth:** follows the playback amplitude, with smoothing, an open/close hysteresis and a response curve, and drives the `jaw_open` blend shape.
   - **"I'm listening" cues:** ears perk, and a head nod plays at random every 0.8–1.6 s while in LISTEN.
   - **Mic permission:**
     - Requested on the first interaction.
     - If denied, the pet shows "can't hear" (ears down plus a gentle hint).
     - If granted later, it recovers.
5. **Audio:** all pre-rendered OGG on the SFX, Music and Voice buses. No runtime synthesis except pitch-shifting the recorded voice.
6. **Lifecycle:** when the app is backgrounded, everything pauses and the mic stops. Both restore on resume.
7. **Performance:**
   - One pet, under about 15k triangles, with a single directional light, no shadows (or a blob shadow decal), and an inverted-hull outline.
   - CPUParticles3D or 2D overlays for hearts, stars, bubbles and paws.
