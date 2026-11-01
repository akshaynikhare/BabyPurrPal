"""Render each pet's voice lines (eleven_lines.csv) with its ElevenLabs voice (eleven_voices.json).

  PY=/Users/akshay/Downloads/baby_apps/.tools/kokoro-venv/bin/python
  $PY tools/audio/gen_voice_eleven.py audition <out_dir> [pet:id ...]   # TAKES per line + index.html
  $PY tools/audio/gen_voice_eleven.py pick <out_dir>                    # -> assets/audio/voice/<pet>/

audition renders every take through gen_voice.postprocess (trim, -19 LUFS, peak <= -2 dBFS) at
24 kHz and skips takes already on disk with the same text, so re-runs only pay for changes.
Laughs and giggles are ranked by gen_voice.laugh_score; the rest default to take 1.
<out_dir>/picks.json ({"cat": {"laugh_1": 2}}) overrides the default take.
pick writes assets/audio/voice/<pet>/<id>.wav with gen_voice.PAD_S of trailing silence, and
each pet folder's envelopes.json, computed like ClipProcessor.compute_envelope.
The API key is read from ~/.elevenlabs/api_key and never printed.
"""
import concurrent.futures
import csv
import html
import json
import pathlib
import sys
import urllib.error
import urllib.request

import numpy as np
import soundfile as sf

from gen_voice import PAD_S, SR, compute_envelope, laugh_score, loudness, postprocess, rhythm

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parents[1] / "assets/audio/voice"
KEY_FILE = pathlib.Path("~/.elevenlabs/api_key").expanduser()
# (model, stability, seed): the designed voices are tuned for v3; v4 is the comparison take.
TAKES = (("eleven_v3", 0.5, 1), ("eleven_v3", 0.0, 2), ("eleven_v4", 0.5, 3))


def tts(voice_id, text, model, stability, seed):
    key = KEY_FILE.read_text().strip()
    body = {"text": text, "model_id": model, "seed": seed,
            "voice_settings": {"stability": stability, "similarity_boost": 0.8}}
    req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=pcm_{SR}",
                                 json.dumps(body).encode(), method="POST",
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    try:
        raw = urllib.request.urlopen(req, timeout=120).read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code} {e.read()[:300].decode(errors='replace')}") from None
    return np.frombuffer(raw, "<i2").astype(np.float64) / 32768.0


def lines(only):
    rows = list(csv.DictReader(open(HERE / "eleven_lines.csv", encoding="utf-8")))
    return [r for r in rows if not only or f"{r['pet']}:{r['id']}" in only]


def laughy(line_id):
    return line_id.startswith(("laugh", "giggle"))


def audition(out, only):
    voices = json.loads((HERE / "eleven_voices.json").read_text())
    meta_path = out / "takes.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
    jobs = []
    for r in lines(only):
        (out / r["pet"]).mkdir(parents=True, exist_ok=True)
        for n, (model, stability, seed) in enumerate(TAKES, 1):
            name = f"{r['pet']}/{r['id']}_{n}.wav"
            if (out / name).exists() and meta.get(name, {}).get("text") == r["text"]:
                continue
            jobs.append((r, n, name, model, stability, seed))

    def run(job):
        r, n, name, model, stability, seed = job
        x = postprocess(tts(voices[r["pet"]]["voice_id"], r["text"], model, stability, seed))
        sf.write(str(out / name), x, SR, subtype="PCM_16")
        peaks, rate_hz, flat_ms = rhythm(x)
        return name, {"pet": r["pet"], "id": r["id"], "take": n, "text": r["text"], "model": model,
                      "stability": stability, "secs": round(len(x) / SR, 2), "peaks": peaks,
                      "rate_hz": round(rate_hz, 1), "flat_ms": flat_ms,
                      "score": round(laugh_score(peaks, rate_hz, flat_ms), 1)}

    with concurrent.futures.ThreadPoolExecutor(3) as pool:
        for i, (name, info) in enumerate(pool.map(run, jobs), 1):
            meta[name] = info
            print(f"{i}/{len(jobs)} {name} {info['secs']}s")
    meta_path.write_text(json.dumps(meta, indent=1))
    write_page(out, meta)


def chosen(out, meta):
    picks = json.loads((out / "picks.json").read_text()) if (out / "picks.json").exists() else {}
    best = {}
    for name, m in meta.items():
        key = (m["pet"], m["id"])
        if laughy(m["id"]):
            if key not in best or m["score"] > meta[best[key]]["score"]:
                best[key] = name
        elif m["take"] == 1:
            best[key] = name
    for pet, ids in picks.items():
        for line_id, take in ids.items():
            best[(pet, line_id)] = f"{pet}/{line_id}_{take}.wav"
    return best


def write_page(out, meta):
    best = chosen(out, meta)
    rows = ["<meta charset=utf-8><title>PurrPal lines</title><body style='font-family:sans-serif'>",
            "<p>&#9733; = current pick. Takes: 1 = v3, 2 = v3 expressive, 3 = v4.</p>"]
    for pet in dict.fromkeys(m["pet"] for m in meta.values()):
        rows.append(f"<h2>{pet}</h2><table>")
        for r in [r for r in lines(set()) if r["pet"] == pet]:
            cells = []
            for n in range(1, len(TAKES) + 1):
                name = f"{pet}/{r['id']}_{n}.wav"
                if name in meta:
                    m = meta[name]
                    star = "&#9733;" if best.get((pet, r["id"])) == name else ""
                    extra = f" score {m['score']}" if laughy(r["id"]) else ""
                    cells.append(f"<td>{star}{n} <audio controls preload=none src='{name}'></audio>"
                                 f"<br><small>{m['secs']}s{extra}</small></td>")
            rows.append(f"<tr><td><b>{r['id']}</b><br><small>{html.escape(r['text'])}</small></td>{''.join(cells)}</tr>")
        rows.append("</table>")
    (out / "index.html").write_text("".join(rows))
    print(out / "index.html")


def pick(out):
    meta = json.loads((out / "takes.json").read_text())
    pad = np.zeros(round(PAD_S * SR))
    envs = {}
    for (pet, line_id), name in sorted(chosen(out, meta).items()):
        x, _ = sf.read(str(out / name))
        (OUT / pet).mkdir(parents=True, exist_ok=True)
        sf.write(str(OUT / pet / f"{line_id}.wav"), np.concatenate([x, pad]), SR, subtype="PCM_16")
        data, _ = sf.read(str(OUT / pet / f"{line_id}.wav"), dtype="int16")
        envs.setdefault(pet, {})[line_id] = [round(float(v), 4) for v in compute_envelope(data[:-len(pad)] / 32768.0, SR)]
        print(f"{pet:5s} {line_id:9s} take {meta[name]['take']}  {len(x) / SR:4.2f}s  {loudness(x):6.1f} LUFS")
    for pet, env in envs.items():
        (OUT / pet / "envelopes.json").write_text(json.dumps(env, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    if sys.argv[1:2] == ["audition"]:
        audition(pathlib.Path(sys.argv[2]), set(sys.argv[3:]))
    elif sys.argv[1:2] == ["pick"]:
        pick(pathlib.Path(sys.argv[2]))
    else:
        sys.exit(__doc__)
