"""Generate the pet's voice lines (laughs, giggles, squeals) from voice_lines.csv with
Kokoro-82M (voice af_heart, US English), plus their mouth envelopes.

  /Users/akshay/Downloads/baby_apps/.tools/kokoro-venv/bin/python tools/audio/gen_voice.py [--force] [--only id,id]
  /Users/akshay/Downloads/baby_apps/.tools/kokoro-venv/bin/python tools/audio/gen_voice.py --audition [--only id,id]

Lines are rendered at natural pitch: TalkBack's pitch bus raises them 1.2-1.8x at runtime.
Output: assets/audio/voice/<id>.wav, 16-bit mono 24 kHz, trimmed, about -19 LUFS (like the
toy SFX), peak <= -2 dBFS, with PAD_S of trailing silence so the pitch shifter's FIFO
drains (TalkBack.TAIL_PAD_SEC). assets/audio/voice/envelopes.json holds one mouth envelope
per id, computed from the WAV on disk (pad excluded) exactly like
ClipProcessor.compute_envelope: RMS per round(rate / 60) samples, loudest block = 1.0.

Kokoro reads interjections unevenly, so each CSV row lists the takes that were tried
(`tried`, "text@speed; ..."). --audition renders the chosen take and every tried one and
prints its rhythm: energy peaks, their rate (median gap) and the
longest flat vowel. Laughs and giggles keep the take with the most peaks in a 3-6 Hz
rhythm and no long vowel; one-word lines keep a single clean burst.
Idempotent: a clip is skipped when its file exists and its text/speed/post-process hash
matches tools/audio/.voice_cache.json.
"""
import argparse
import csv
import hashlib
import json
import math
import os
import pathlib
import sys
import warnings

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from scipy import signal

warnings.filterwarnings("ignore")
for lib in ("/opt/homebrew/lib/libespeak-ng.1.dylib", "/opt/homebrew/lib/libespeak-ng.dylib"):
    if "PHONEMIZER_ESPEAK_LIBRARY" not in os.environ and os.path.exists(lib):
        os.environ["PHONEMIZER_ESPEAK_LIBRARY"] = lib

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parents[1] / "assets/audio/voice"
ENVELOPES = OUT / "envelopes.json"
CACHE = HERE / ".voice_cache.json"
SR = 24000
VOICE = "af_heart"
POST_VERSION = 1
TARGET_LUFS = -19.0
PEAK_CEIL_DB = -2.0
LIMIT_KNEE = 0.6
TRIM_DB = -45.0
LEAD_S = 0.010
TRAIL_S = 0.030
PAD_S = 0.100
ENVELOPE_RATE = 60.0


def postprocess(x):
    sos = signal.butter(2, 70, "high", fs=SR, output="sos")
    x = signal.sosfilt(sos, x - np.mean(x))
    thr = np.max(np.abs(x)) * 10 ** (TRIM_DB / 20)
    idx = np.nonzero(np.abs(x) > thr)[0]
    x = x[max(idx[0] - int(LEAD_S * SR), 0): idx[-1] + int(TRAIL_S * SR) + 1]
    fi, fo = int(0.008 * SR), int(0.030 * SR)
    x[:fi] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fi) / fi)
    x[-fo:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(fo) / fo)
    # Reach the loudness target, soft-limiting the odd peaky consonant instead of
    # leaving the whole clip quieter than its neighbours.
    ceil = 10 ** (PEAK_CEIL_DB / 20)
    for _ in range(4):
        x = x * 10 ** ((TARGET_LUFS - loudness(x)) / 20)
        over = np.abs(x) > LIMIT_KNEE
        x[over] = np.sign(x[over]) * (LIMIT_KNEE + (ceil - LIMIT_KNEE) * np.tanh((np.abs(x[over]) - LIMIT_KNEE) / (ceil - LIMIT_KNEE)))
    return x


def loudness(x):
    # pyloudnorm needs a full 400 ms gating block; short clips are measured with silence after.
    return pyln.Meter(SR).integrated_loudness(np.concatenate([x, np.zeros(max(0, int(0.6 * SR) - len(x)))]))


def compute_envelope(samples, sample_rate, rate=ENVELOPE_RATE):
    """Port of ClipProcessor.compute_envelope (scripts/talkback/clip_processor.gd)."""
    block = max(1, math.floor(sample_rate / rate + 0.5))
    blocks = math.ceil(len(samples) / block)
    s = np.asarray(samples, dtype=np.float64)
    env = np.array([math.sqrt(np.sum(s[b * block: (b + 1) * block] ** 2) / len(s[b * block: (b + 1) * block]))
                    for b in range(blocks)])
    top = env.max() if blocks else 0.0
    return env / top if top > 0.0 else env


def rhythm(x):
    """Energy peaks, their rate in Hz (median gap) and the longest flat run (ms) of a 10 ms RMS envelope."""
    hop = SR // 100
    frames = len(x) // hop
    env = np.sqrt(np.convolve(x ** 2, np.ones(2 * hop) / (2 * hop), "same")[: frames * hop].reshape(frames, hop).mean(1))
    env /= env.max()
    peaks, _ = signal.find_peaks(env, prominence=0.2, distance=8)
    rate_hz = 100.0 / float(np.median(np.diff(peaks))) if len(peaks) > 1 else 0.0
    flat = run = 0
    for v in env:
        run = run + 1 if v > 0.5 else 0
        flat = max(flat, run)
    return len(peaks), rate_hz, flat * 10


def laugh_score(peaks, rate_hz, flat_ms):
    return peaks + (2.0 if 3.0 <= rate_hz <= 6.0 else 0.0) - 0.3 * abs(rate_hz - 4.5) - max(0, flat_ms - 200) / 100


def render(pipe, text, speed):
    parts = [np.asarray(res.audio, dtype=np.float64) for res in pipe(text, voice=VOICE, speed=speed)]
    return postprocess(np.concatenate(parts))


def takes(row):
    out = [(row["text"], float(row["speed"]))]
    for t in filter(None, (s.strip() for s in row["tried"].split(";"))):
        text, speed = t.rsplit("@", 1)
        out.append((text, float(speed)))
    return out


def audition(pipe, rows):
    for r in rows:
        laughy = r["id"].startswith(("laugh", "giggle"))
        print(f"{r['id']}  ({'laugh rhythm' if laughy else 'single burst'})")
        for i, (text, speed) in enumerate(takes(r)):
            x = render(pipe, text, speed)
            peaks, rate_hz, flat_ms = rhythm(x)
            score = f"score {laugh_score(peaks, rate_hz, flat_ms):5.1f}" if laughy else ""
            print(f"  {'*' if i == 0 else ' '} {text!r:30s} @{speed:<4} {len(x) / SR:4.2f}s  peaks {peaks}  "
                  f"rate {rate_hz:4.1f} Hz  flat {flat_ms:3d} ms  {score}")


def write_envelopes(rows):
    pad = round(PAD_S * SR)
    envs = {}
    for r in rows:
        path = OUT / f"{r['id']}.wav"
        if path.exists():
            data, _ = sf.read(str(path), dtype="int16")
            envs[r["id"]] = [round(float(v), 4) for v in compute_envelope(data[:-pad] / 32768.0, SR)]
    ENVELOPES.write_text(json.dumps(envs, separators=(",", ":")) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--audition", action="store_true")
    args = ap.parse_args()
    rows = list(csv.DictReader(open(HERE / "voice_lines.csv", encoding="utf-8")))
    only = set(filter(None, args.only.split(",")))
    picked = [r for r in rows if not only or r["id"] in only]
    cache = json.loads(CACHE.read_text()) if CACHE.exists() else {}
    OUT.mkdir(parents=True, exist_ok=True)

    from kokoro import KPipeline
    if args.audition:
        audition(KPipeline(lang_code="a", repo_id="hexgrad/Kokoro-82M"), picked)
        return

    todo = []
    for r in picked:
        key = hashlib.sha1(f"{r['text']}|{VOICE}|{r['speed']}|{POST_VERSION}".encode()).hexdigest()
        path = OUT / f"{r['id']}.wav"
        if args.force or not path.exists() or cache.get(r["id"]) != key:
            todo.append((r, key, path))
    pipe = KPipeline(lang_code="a", repo_id="hexgrad/Kokoro-82M") if todo else None
    for r, key, path in todo:
        x = render(pipe, r["text"], float(r["speed"]))
        x = np.concatenate([x, np.zeros(round(PAD_S * SR))])
        sf.write(str(path), x, SR, subtype="PCM_16")
        cache[r["id"]] = key
        CACHE.write_text(json.dumps(cache, indent=1, sort_keys=True))
    write_envelopes(rows)
    for r in picked:
        data, _ = sf.read(str(OUT / f"{r['id']}.wav"))
        voiced = data[: -round(PAD_S * SR)]
        print(f"{r['id']:10s} {len(data) / SR:4.2f}s  {loudness(voiced):6.1f} LUFS  "
              f"peak {20 * np.log10(np.max(np.abs(voiced))):5.1f} dBFS  {r['text']!r} @{r['speed']}"
              f"{'  (rendered)' if any(t[0] is r for t in todo) else ''}")


if __name__ == "__main__":
    sys.exit(main())
