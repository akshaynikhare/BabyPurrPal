# BabyPurrPal

An ad-free, offline talking-pet game for babies and toddlers. An original cat, dog or bunny lives in a cozy pastel room. It listens to your baby and repeats their coos and babble in a cute, higher voice. Tapping the pet's ears, cheeks, mouth, belly or paws gets a reaction, and each pet has three toys.

Built with **Godot 4.7** (GDScript, 3D, Mobile renderer): toon-shaded pets with warm-brown outlines. Portrait only, 60 fps cap.

## How it plays
- **Talk-back:** the pet calibrates to the room's noise, perks its ears and nods while it listens, then repeats the sound pitch-shifted (higher, not sped up) with its mouth in sync. It never repeats its own sounds.
- **Touch:** each body part has its own reactions, and a reaction never plays twice in a row. Tapping the background plays chimes.
- **Gestures:** swipe to switch pets; pinch, or press the zoom button, for a face close-up.
- **Time of day:** the room follows the clock (sunrise, day, sunset, night). The sun/moon button changes it by hand.

## For parents
- **Settings:** hold the gear for 3 seconds. Inside: soothing lullaby, voice pitch (1.2×–1.8×), talking pet on/off, Test Voice.
- **Microphone privacy:**
  - **Local only:** audio is processed on the phone. Nothing is recorded to storage or sent anywhere.
  - **When the mic is closed:** whenever the app is in the background, and when the talking pet is off.
  - **During the lullaby:** the pet keeps listening. The music turns down while it listens and talks.
- **Network:** no ads and no network use.

## Develop
```bash
make run      # open in Godot
make test     # headless logic tests (talk-back, gestures, UI logic)
make apk      # debug APK → build/BabyPurrPal.apk
make install  # adb install the debug APK
```
- **Architecture, runtime audio buses and agent rules:** [docs/GODOT_ARCHITECTURE.md](docs/GODOT_ARCHITECTURE.md).
- **Behaviour spec:** [docs/REWRITE_SPEC.md](docs/REWRITE_SPEC.md).
- **Pets:** built by a Blender script, `tools/blender/build_pets.py` (Blender 5.2, headless). Regenerate with:
  ```
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/build_pets.py -- --pet all
  ```
- **Sounds:** rendered by `tools/audio/render_sfx.py`.

## Release
Every push to `main` runs CI: it bumps a tag, runs the tests, exports a signed APK and publishes a GitHub Release. Signing uses the `KEYSTORE_B64`, `KEY_ALIAS` and `KEY_PASS` repo secrets; without them CI publishes a debug-signed build.

The previous React/Capacitor prototype is in git history (v0.0.1).
