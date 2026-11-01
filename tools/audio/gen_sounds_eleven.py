"""Generate sound effects, loops and music with ElevenLabs from eleven_sounds.csv, audition every
take, then write the picked ones as game-ready OGGs.

  PY=/Users/akshay/Downloads/baby_apps/.tools/kokoro-venv/bin/python
  $PY tools/audio/gen_sounds_eleven.py cost                         # credits the CSV would use
  $PY tools/audio/gen_sounds_eleven.py audition <out_dir> [id ...]  # every take + index.html
  $PY tools/audio/gen_sounds_eleven.py pick <out_dir>               # -> assets/audio/{sfx,music}/

CSV columns: id, kind, secs, keep, takes, prompt. kind is sfx (one-shot), loop (sound effect made
with loop=true) or music (Eleven Music, instrumental). takes are generated and the first `keep`
clean ones are picked (<out_dir>/picks.json, {"meow": [1, 3, 4]}, overrides). One kept take is
written as <id>.ogg, several as <id>_1.ogg ... <id>_<keep>.ogg; music goes to music/, the rest to sfx/.

Every take is post-processed the same way: mono, 44.1 kHz (Godot's fixed Android mix rate),
high-passed at HIGHPASS_HZ (phone speakers can't play lower; it only eats headroom), loudness
normalised per kind (LUFS below) and soft-limited to PEAK_DB. One-shots are trimmed, fade in
over FADE_IN_S (nothing starts abruptly enough to startle) and out over FADE_OUT_S. Loops and
music are generated XFADE_S longer and their tail is cross-faded onto their head, so they loop
without a seam; their .import files get loop=true once Godot has imported them (run pick again).
Credits: 40 per second of sound effect, 900 per minute of music (Starter, 2026-11).
The API key is read from ~/.elevenlabs/api_key and never printed.
"""
import concurrent.futures
import csv
import html
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy import signal

HERE = pathlib.Path(__file__).resolve().parent
AUDIO = HERE.parents[1] / "assets/audio"
KEY_FILE = pathlib.Path("~/.elevenlabs/api_key").expanduser()
SR = 44100
HIGHPASS_HZ = 100
PEAK_DB = -1.0
LIMIT_KNEE = 0.7
FADE_IN_S = 0.008
FADE_OUT_S = 0.030
TRIM_DB = -50.0
XFADE_S = 2.0
LOOP_XFADE_S = 0.25
SFX_MODEL = "eleven_text_to_sound_v3"
SFX_INFLUENCE = 0.5
MUSIC_MODEL = "music_v2_5"
# Integrated loudness per kind; the runtime buses set the final balance against the -19 LUFS voice.
LUFS = {"sfx": -22.0, "ui": -25.0, "loop": -24.0, "ambience": -30.0, "music": -20.0}


def rows(only=()):
    out = list(csv.DictReader(open(HERE / "eleven_sounds.csv", encoding="utf-8")))
    return [r for r in out if not only or r["id"] in only]


def level_kind(r):
    if r["id"].startswith("ui_"):
        return "ui"
    if r["id"].startswith("amb_"):
        return "ambience"
    return r["kind"]


def cost(r):
    secs = float(r["secs"]) + (XFADE_S if r["kind"] == "music" else 0.0)
    return int(r["takes"]) * (secs / 60 * 900 if r["kind"] == "music" else max(secs, 0.5) * 40)


def post(path, body):
    key = KEY_FILE.read_text().strip()
    req = urllib.request.Request(f"https://api.elevenlabs.io/v1{path}?output_format=pcm_{SR}", json.dumps(body).encode(),
                                 method="POST", headers={"xi-api-key": key, "Content-Type": "application/json"})
    try:
        raw = urllib.request.urlopen(req, timeout=600).read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{path}: HTTP {e.code} {e.read()[:300].decode(errors='replace')}") from None
    x = np.frombuffer(raw, "<i2").astype(np.float64) / 32768.0
    return x.reshape(-1, 2).mean(1) if len(x) % 2 == 0 else x


def generate(r):
    secs = float(r["secs"])
    if r["kind"] == "music":
        return post("/music", {"prompt": r["prompt"], "music_length_ms": int((secs + XFADE_S) * 1000),
                               "model_id": MUSIC_MODEL, "force_instrumental": True})
    return post("/sound-generation", {"text": r["prompt"], "duration_seconds": max(secs, 0.5), "model_id": SFX_MODEL,
                                      "prompt_influence": SFX_INFLUENCE, "loop": r["kind"] == "loop"})


def loudness(x):
    return pyln.Meter(SR).integrated_loudness(np.concatenate([x, np.zeros(max(0, int(0.6 * SR) - len(x)))]))


def fade(n, rising):
    ramp = 0.5 - 0.5 * np.cos(np.pi * np.arange(n) / n)
    return ramp if rising else ramp[::-1]


def process(x, r):
    x = signal.sosfilt(signal.butter(2, HIGHPASS_HZ, "high", fs=SR, output="sos"), x - np.mean(x))
    if not np.any(x):
        return x
    if r["kind"] == "sfx":
        idx = np.nonzero(np.abs(x) > np.max(np.abs(x)) * 10 ** (TRIM_DB / 20))[0]
        x = x[max(idx[0] - int(0.005 * SR), 0): idx[-1] + int(0.05 * SR)]
        fi, fo = int(FADE_IN_S * SR), int(FADE_OUT_S * SR)
        x[:fi] *= fade(fi, True)
        x[-fo:] *= fade(fo, False)
    else:
        n = int((XFADE_S if r["kind"] == "music" else LOOP_XFADE_S) * SR)
        body = x[:-n].copy()
        body[:n] = body[:n] * np.sqrt(fade(n, True)) + x[-n:] * np.sqrt(fade(n, False))
        x = body
    ceil = 10 ** (PEAK_DB / 20)
    for _ in range(4):
        level = loudness(x)
        if not np.isfinite(level):
            break
        x = x * 10 ** ((LUFS[level_kind(r)] - level) / 20)
        over = np.abs(x) > LIMIT_KNEE * ceil
        k = LIMIT_KNEE * ceil
        x[over] = np.sign(x[over]) * (k + (ceil - k) * np.tanh((np.abs(x[over]) - k) / (ceil - k)))
    return x


def screen(raw, x, r):
    flags = []
    if np.max(np.abs(raw)) >= 0.999:
        flags.append("clipped")
    if np.sqrt(np.mean(raw ** 2)) < 1e-3:
        flags.append("silent")
    if r["kind"] == "sfx" and len(x) < 0.08 * SR:
        flags.append("tiny")
    return flags


def audition(out, only):
    out.mkdir(parents=True, exist_ok=True)
    meta_path = out / "takes.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
    jobs = []
    for r in rows(only):
        for t in range(1, int(r["takes"]) + 1):
            name = f"{r['id']}_{t}.wav"
            if not ((out / name).exists() and meta.get(name, {}).get("prompt") == r["prompt"]):
                jobs.append((r, t, name))
    print(f"{len(jobs)} takes, about {sum(cost(r) / int(r['takes']) for r, _, _ in jobs):.0f} credits")

    def run(job):
        r, t, name = job
        raw = generate(r)
        x = process(raw.copy(), r)
        sf.write(str(out / name), np.tile(x, 2) if r["kind"] != "sfx" else x, SR, subtype="PCM_16")
        np.save(out / name.replace(".wav", ".npy"), x.astype(np.float32))
        return name, {"id": r["id"], "take": t, "prompt": r["prompt"], "secs": round(len(x) / SR, 2),
                      "flags": screen(raw, x, r)}

    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        futures = [pool.submit(run, j) for j in jobs]
        for i, f in enumerate(concurrent.futures.as_completed(futures), 1):
            try:
                name, info = f.result()
            except Exception as e:
                print("FAILED", type(e).__name__, e)
                continue
            meta[name] = info
            print(f"{i}/{len(jobs)} {name} {info['secs']}s {' '.join(info['flags'])}")
            meta_path.write_text(json.dumps(meta, indent=1))
    write_page(out, meta)


def chosen(out, meta):
    picks = json.loads((out / "picks.json").read_text()) if (out / "picks.json").exists() else {}
    best = {}
    for r in rows():
        takes = [m for m in meta.values() if m["id"] == r["id"]]
        clean = sorted((m["take"] for m in takes if not m["flags"]))
        best[r["id"]] = picks.get(r["id"], clean[: int(r["keep"])])
    return best


def write_page(out, meta):
    best = chosen(out, meta)
    parts = ["<meta charset=utf-8><title>Sounds</title><body style='font-family:sans-serif'>",
             "<p>&#9733; = picked. Loops and music play twice so you can hear the seam.</p><table>"]
    for r in rows():
        cells = []
        for t in range(1, int(r["takes"]) + 1):
            m = meta.get(f"{r['id']}_{t}.wav")
            if m:
                star = "&#9733;" if t in best[r["id"]] else ""
                cells.append(f"<td>{star}{t} <audio controls preload=none src='{r['id']}_{t}.wav'></audio>"
                             f"<br><small>{m['secs']}s {' '.join(m['flags'])}</small></td>")
        parts.append(f"<tr><td><b>{r['id']}</b> <small>({r['kind']}, keep {r['keep']})<br>"
                     f"{html.escape(r['prompt'])}</small></td>{''.join(cells)}</tr>")
    (out / "index.html").write_text("".join(parts) + "</table>")
    print(out / "index.html")


def set_loop(path):
    imp = pathlib.Path(str(path) + ".import")
    if imp.exists():
        imp.write_text(re.sub(r"^loop=false$", "loop=true", imp.read_text(), flags=re.M))
    return imp.exists()


def pick(out):
    meta = json.loads((out / "takes.json").read_text())
    unimported = []
    for r in rows():
        takes = chosen(out, meta)[r["id"]]
        folder = AUDIO / ("music" if r["kind"] == "music" else "sfx")
        names = [r["id"]] if len(takes) == 1 else [f"{r['id']}_{n}" for n in range(1, len(takes) + 1)]
        for name, t in zip(names, takes):
            x = np.load(out / f"{r['id']}_{t}.npy").astype(np.float64)
            path = folder / f"{name}.ogg"
            sf.write(str(path), x, SR, format="OGG", subtype="VORBIS")
            if r["kind"] != "sfx" and not set_loop(path):
                unimported.append(path.name)
            print(f"{name:14s} take {t}  {len(x) / SR:5.2f}s  {loudness(x):6.1f} LUFS")
        for derive in DERIVED.get(r["id"], []):
            derive(np.load(out / f"{r['id']}_{takes[0]}.npy").astype(np.float64))
    if unimported:
        print("Import in Godot, then run pick again to set loop=true on:", " ".join(unimported))


def purr_tail(x):
    """0.25 s that continues the purr loop from its first sample, fading out."""
    n = int(0.25 * SR)
    sf.write(str(AUDIO / "sfx/purr_tail.ogg"), x[:n] * fade(n, False), SR, format="OGG", subtype="VORBIS")


def chime_scale(x):
    """The kalimba take retuned to the ten background-tap notes (chime_0 ... chime_9)."""
    seg = x[int(0.05 * SR): int(0.35 * SR)]
    ac = np.correlate(seg, seg, "full")[len(seg) - 1:]
    lo, hi = SR // 1200, SR // 150
    f0 = SR / (lo + np.argmax(ac[lo:hi]))
    for i, target in enumerate([261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0]):
        y = signal.resample(x, int(round(len(x) * f0 / target)))
        fo = int(FADE_OUT_S * SR)
        y[-fo:] *= fade(fo, False)
        sf.write(str(AUDIO / f"sfx/chime_{i}.ogg"), y, SR, format="OGG", subtype="VORBIS")
    print(f"chime_0..9 from a {f0:.0f} Hz kalimba note")


DERIVED = {"purr_loop": [purr_tail], "kalimba": [chime_scale]}


if __name__ == "__main__":
    cmd = sys.argv[1:2]
    if cmd == ["cost"]:
        total = 0.0
        for r in rows():
            total += cost(r)
        music_min = sum(int(r["takes"]) * (float(r["secs"]) + XFADE_S) / 60 for r in rows() if r["kind"] == "music")
        print(f"{len(rows())} sounds, {sum(int(r['takes']) for r in rows())} takes, about {total:.0f} credits "
              f"({music_min:.1f} min of music)")
    elif cmd == ["audition"]:
        audition(pathlib.Path(sys.argv[2]), set(sys.argv[3:]))
    elif cmd == ["pick"]:
        pick(pathlib.Path(sys.argv[2]))
    else:
        sys.exit(__doc__)
