"""Check every expected clip exists, decodes, and report sizes. Voice WAVs (one folder per pet)
must also be 16-bit mono 24 kHz, peak at most -2 dBFS, end in 100 ms of silence and have a
mouth envelope in their folder's envelopes.json.

Expected clips: every sound in eleven_sounds.csv (one kept take is <id>.ogg, several are
<id>_1.ogg ... <id>_<keep>.ogg; a pick may keep a single take of a several-take sound), the
files derived from them (purr_tail, chime_0..9) or kept from the synth (babble), and every
voice line in eleven_lines.csv for each pet.

  /Users/akshay/Downloads/baby_apps/.tools/kokoro-venv/bin/python tools/audio/verify_assets.py
"""
import csv
import json
import pathlib
import sys
import numpy as np
import soundfile as sf

HERE = pathlib.Path(__file__).resolve().parent
AUDIO = HERE.parents[1] / "assets/audio"
DERIVED = ["purr_tail"] + [f"chime_{i}" for i in range(10)]
SYNTH = ["babble"]
VOICE_RATE = 24000
VOICE_PAD = 2400
VOICE_PEAK_DB = -2.0


def sound_names(row):
    """The files a kept sound is written as."""
    folder = AUDIO / ("music" if row["kind"] == "music" else "sfx")
    keep = int(row["keep"])
    if keep == 1 or (folder / f"{row['id']}.ogg").exists():
        return [row["id"]]
    return [f"{row['id']}_{n}" for n in range(1, keep + 1)]


def expected():
    out = {"sfx": DERIVED + SYNTH, "music": []}
    for row in csv.DictReader(open(HERE / "eleven_sounds.csv", encoding="utf-8")):
        out["music" if row["kind"] == "music" else "sfx"] += sound_names(row)
    for row in csv.DictReader(open(HERE / "eleven_lines.csv", encoding="utf-8")):
        out.setdefault(f"voice/{row['pet']}", []).append(row["id"])
    return out


EXPECTED = expected()


def check_voice(name, path, envelopes):
    info = sf.info(str(path))
    data, _ = sf.read(str(path), dtype="int16")
    problems = []
    if (info.samplerate, info.channels, info.subtype) != (VOICE_RATE, 1, "PCM_16"):
        problems.append(f"format {info.samplerate} Hz x{info.channels} {info.subtype}")
    if np.any(data[-VOICE_PAD:]):
        problems.append("no 100 ms silent tail")
    if 20 * np.log10(np.max(np.abs(data)) / 32768) > VOICE_PEAK_DB:
        problems.append("peak above -2 dBFS")
    if len(envelopes.get(name, [])) != -(-(len(data) - VOICE_PAD) // (VOICE_RATE // 60)):
        problems.append("envelope missing or wrong length")
    return [f"{path.parent.name}/{name}: {p}" for p in problems]


def main():
    missing, bad, sizes = [], [], {}
    for folder, names in EXPECTED.items():
        ext = "wav" if folder.startswith("voice") else "ogg"
        env_path = AUDIO / folder / "envelopes.json"
        envelopes = json.loads(env_path.read_text()) if env_path.exists() else {}
        for n in names:
            p = AUDIO / folder / f"{n}.{ext}"
            if not p.exists():
                missing.append(f"{folder}/{n}")
                continue
            data, _ = sf.read(str(p))
            assert len(data) > 0, p
            if ext == "wav":
                bad += check_voice(n, p, envelopes)
        sizes[ext] = sizes.get(ext, 0) + sum(p.stat().st_size for p in (AUDIO / folder).glob(f"*.{ext}"))
    print(f"expected clips: {sum(map(len, EXPECTED.values()))}, missing: {missing or 'none'}")
    for problem in bad:
        print(problem)
    print("total size: " + ", ".join(f"{ext} {size / 1024:.1f} KiB" for ext, size in sizes.items()))
    sys.exit(1 if missing or bad else 0)


if __name__ == "__main__":
    main()
