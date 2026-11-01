"""Check every expected clip exists, decodes, and report sizes.

  /Users/akshay/Downloads/baby_apps/.tools/kokoro-venv/bin/python tools/audio/verify_assets.py
"""
import pathlib
import sys
import soundfile as sf

AUDIO = pathlib.Path(__file__).resolve().parents[2] / "assets/audio"
EXPECTED = {
    "sfx": [f"chime_{i}" for i in range(10)] + [
        "giggle", "paw_tap", "twinkle", "purr_loop", "purr_tail", "woof", "pant", "squeak",
        "crunch", "footstep", "babble",
        "gulp_1", "gulp_2", "gulp_3", "lap_1", "lap_2", "slurp", "munch_1", "munch_2", "yum",
        "bounce_1", "bounce_2", "roll", "jingle_1", "jingle_2", "splash", "pop_in", "pop_out"],
    "music": ["lullaby"],
    "voice": [],
}


def main():
    missing, total = [], 0
    for folder, names in EXPECTED.items():
        for n in names:
            p = AUDIO / folder / f"{n}.ogg"
            if not p.exists():
                missing.append(f"{folder}/{n}")
                continue
            data, _ = sf.read(str(p))
            assert len(data) > 0, p
        for p in (AUDIO / folder).glob("*.ogg"):
            total += p.stat().st_size
    print(f"expected clips: {sum(map(len, EXPECTED.values()))}, missing: {missing or 'none'}")
    print(f"total ogg size: {total / 1024:.1f} KiB")
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
