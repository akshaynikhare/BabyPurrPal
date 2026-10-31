# Game Design Document (GDD): PurrPal

## 1. Executive Summary

- **Title**: PurrPal - Talking Cat Baby Game
- **Platform**: Web (PWA offline-first) & Android (APK via Capacitor)
- **Target Audience**: Infants & Toddlers (Ages 6 months to 2.5 years) and their parents
- **Genre**: Sensory Reinforcement Learning / Virtual Pet Companion
- **Core Hook**: Zero-text, ultra-clean tactile play where every baby tap produces an immediate, rewarding sensory loop (<100ms auditory chime, haptic pulse, visual particle burst, character animation) and offline Talking Tom voice mimicry.

---

## 2. Child Development & Reinforcement Learning Model

PurrPal is built on behavioral psychology principles of **sensorimotor operant conditioning** (Piaget's Sensorimotor Stage: Secondary Circular Reactions, 4–8 months & Coordination of Secondary Schemes, 8–12 months).

```
┌────────────────────────────────────────────────────────┐
│             Baby Operant Conditioning Loop             │
└────────────────────────────────────────────────────────┘
                           │
                 [ Baby Motor Impulse ]
              (Tap, Pinch, Swipe, Babble)
                           │
                           ▼
                 [ Multi-Modal Stimulus ]
     ┌─────────────────────┼─────────────────────┐
     ▼                     ▼                     ▼
[ Auditory ]          [ Tactile ]           [ Visual ]
- C-Major Pentatonic  - Web Vibration API   - Particle Bursts
- LFO Purr / Woof     - Purr hum (60-80ms)  - Fluffy Cheek Glow
- Pitched Mimicry     - High-five tap       - Star & Heart Trails
     │                     │                     │
     └─────────────────────┼─────────────────────┘
                           ▼
              [ Dopaminergic Reward ]
       "My action changed something in my world!"
                           │
                           ▼
             [ Cognitive Schema Reinforced ]
```

### Key Safety & Sensory Guardrails
1. **Zero Overstimulation (No Clutter / Anti-Slop)**:
   - No flashing strobes, screaming ad popups, countdown timers, or scoreboards.
   - Background colors use gentle, time-aware circadian gradients (Sunrise warm peach, Daylight sky blue, Sunset dusk lavender, Night star navy).
2. **Harmonic Guarantee**:
   - Background canvas touches trigger notes strictly from the **C-Major Pentatonic Scale** ($C_4, D_4, E_4, G_4, A_4, C_5$). No dissonant intervals are possible.
3. **Accidental Touch Resistance**:
   - The entire screen is interactive; there are no "dead" zones or penalty states.
   - Screen controls are edge-positioned with a 3-second hold gate for Parental Settings.

---

## 3. Character Roster & Anatomical Touch Matrix

The game loops continuously between 3 animal companions via natural touch swipe gestures:

### 1. Kitty Cat (`CatCharacter`)
- **Visual Personality**: Curious, cuddly, fluffy Persian/tabby kitten with 3-tiered cheek fur tufts, forehead stripes, and glass-depth amber/ocean eyes.
- **Color Themes**: `midnight` (deep navy & peach), `ginger` (terracotta & cream), `cloud` (snow white & pastel).
- **Interactive Zones**:
  - `ears`: Perking ears + soft 25Hz AM purr hum + heart particles.
  - `cheeks`: Blushing cheek glow + silver bell twinkle chime + whisker wiggle.
  - `mouth`: Talking Tom speech mimicry / milk feeding + starburst sparkles.
  - `belly`: Wobble tickle + baby giggles + floating soap bubbles.
  - `leftPaw` / `rightPaw`: Paw raise high-five + wooden marimba tap + paw print particles.

### 2. Puppy Dog (`DogCharacter`)
- **Visual Personality**: Energetic, faithful floppy-eared golden retriever / dalmatian puppy with ear creases, wet black nose highlight, and star medallion collar.
- **Color Themes**: `golden` (warm honey amber), `chocolate` (rich cocoa), `spotted` (Dalmatian eye-patch).
- **Interactive Zones**:
  - `ears`: Floppy ear bounce + listening audio ripple + heart particles.
  - `cheeks`: Cheerful rosy cheek puff + sparkling chime.
  - `mouth`: Playful puppy woof / panting tongue + juicy bone feeding.
  - `belly`: Jiggle belly wobble + dog bone tag wobble + bubbles.
  - `leftPaw` / `rightPaw`: High-five paw swipe + marimba wood block tap.

### 3. Bunny Rabbit (`RabbitCharacter`)
- **Visual Personality**: Gentle, squishy cottontail rabbit with tall curved ears, velvet pink interior, embroidered carrot belly motif, and multi-cloud cotton tail.
- **Color Themes**: `white` (snow bunny & ruby eyes), `honey` (warm yellow & sapphire eyes), `smokey` (slate blue & sky blue eyes).
- **Interactive Zones**:
  - `ears`: Long ear perk + emerald audio waves + heart particles.
  - `cheeks`: Chubby cheek glow + twinkle chimes.
  - `mouth`: Twitching nose + crunchy carrot crunch sound + buck teeth.
  - `belly`: Tickle wobble + clover emblem glow + bubbles.
  - `leftPaw` / `rightPaw`: High-five paw bounce + gentle marimba chime.

---

## 4. Audio Engine & Signal Processing Pipeline

All audio processing is executed **100% locally on-device** using the native Web Audio API (`AudioContext`).

```
┌──────────────────────────────────────────────────────────────┐
│                  PurrPal Audio Signal Graph                  │
└──────────────────────────────────────────────────────────────┘
                               │
       ┌───────────────────────┴───────────────────────┐
       ▼                                               ▼
[ Procedural SFX ]                             [ Voice Engine ]
- Sine/Triangle synth                          - MediaStream mic
- Pentatonic Chimes                            - AnalyserNode (VAD)
- Purr LFO (25Hz AM)                           - AudioBuffer playback
- Calming Lullaby Chords                       - Detune: +600 cents
       │                                               │
       └───────────────────────┬───────────────────────┘
                               ▼
                       [ Master Gain ]
                               │
                               ▼
                    [ AudioContext.destination ]
```

### Voice Activity Detection (VAD)
1. User babble is monitored via `AnalyserNode.getByteTimeDomainData` or `getByteFrequencyData`.
2. When root-mean-square (RMS) exceeds threshold (~$0.025$), recording starts into a circular `Float32Array` audio buffer.
3. When silence is detected for $>450\text{ms}$ or buffer reaches $4\text{s}$, the recording stops.
4. The recorded buffer plays back with `source.playbackRate = 1.45` (or detune $+600\text{ cents}$) to produce the playful high-pitched Talking Tom effect.
5. During playback, an amplitude follower dispatches real-time normalized volume ($0.0 \dots 1.0$) to the pet's SVG mouth element (`mouthOpenY = Math.min(36, amplitude * 38)`).

---

## 5. Mobile & Android APK Packaging

PurrPal is built to operate flawlessly without an active internet connection:
- **Offline PWA**: Service Worker caching via `vite-plugin-pwa` precaches all scripts, SVGs, and web fonts.
- **Android APK**: Packaged via `@capacitor/android` with `AndroidManifest.xml` hardware permissions:
  - `android.permission.RECORD_AUDIO`: Voice mimicry microphone access.
  - `android.permission.VIBRATE`: Tactile haptic feedback.
  - Hardware accelerated WebView on port 3000.
