"""Design each pet's voice with ElevenLabs Voice Design, then save the one you pick.

  python3 tools/audio/design_voices.py audition <out_dir> [pet ...]   # 2 x 3 previews per pet + index.html
  python3 tools/audio/design_voices.py save <pet> <generated_voice_id>  # keeps it, records the voice id

The API key is read from ~/.elevenlabs/api_key and never printed. Saved voice ids go to
tools/audio/eleven_voices.json (ids only, no secrets).
"""
import base64
import html
import json
import pathlib
import sys
import urllib.error
import urllib.request

API = "https://api.elevenlabs.io/v1"
KEY_FILE = pathlib.Path("~/.elevenlabs/api_key").expanduser()
VOICES = pathlib.Path(__file__).resolve().parent / "eleven_voices.json"
MODEL = "eleven_ttv_v3"
SEEDS = (11, 23)

PETS = {
    "cat": {
        "description": "Native English. A cute cartoon kitten character with a high, bright, sweet voice. "
                       "Studio-quality recording. Playful, a little mischievous and bursting with joy. "
                       "Light, sparkly tone with quick bubbly giggles and a soft purring warmth; speaks at a lively, bouncy pace.",
        "text": "[excited] Hi there! I'm so happy you came to play with me! [giggles] Hee hee, that tickles! "
                "[laughs] Ha ha ha ha! [curious] Oooh, what's that? Mmm, yummy milk! Wow! Hooray!",
    },
    "dog": {
        "description": "Native English. A goofy, lovable cartoon puppy character with a warm, mid-pitched, slightly husky male voice. "
                       "Studio-quality recording. Bouncy, eager and over-excited, a little breathless as if wagging his whole body. "
                       "Big hearty belly laughs, friendly and silly; speaks fast with lots of enthusiasm.",
        "text": "[excited] Hello hello! Wanna play? Let's play! [laughs] Ha ha ha ha ha! [giggles] Hee hee, "
                "that tickles my tummy! Mmm, yummy bone! Woooow! Hoo-ray!",
    },
    "bunny": {
        "description": "Native English. A small, hyper cartoon bunny character with a male voice that is higher-pitched than most men, "
                       "punchy and a little raspy. Studio-quality recording. A fast-talking, wisecracking comic, loud and "
                       "over-the-top animated; his voice jumps up and cracks into squeaks when he gets excited. "
                       "Explosive cackling laughs; rapid, staccato delivery with big dramatic emphasis.",
        "text": "[excited] Yo! Hi there! Oh man, you came to play with me?! [laughs] Ha ha ha ha! [giggles] Hee hee, "
                "stop, stop, that tickles! [curious] Oooh, is that a carrot? Mmm, yummy! Woooow! Hoo-ray!",
    },
}


def post(path, body):
    key = KEY_FILE.read_text().strip()
    if not key or key.startswith("PASTE_"):
        sys.exit(f"Put your ElevenLabs API key in {KEY_FILE}")
    req = urllib.request.Request(API + path, json.dumps(body).encode(), method="POST",
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    try:
        return json.load(urllib.request.urlopen(req, timeout=180))
    except urllib.error.HTTPError as e:
        sys.exit(f"{path}: HTTP {e.code} {e.read()[:400].decode(errors='replace')}")


def audition(out, pets):
    out.mkdir(parents=True, exist_ok=True)
    takes = json.loads((out / "takes.json").read_text()) if (out / "takes.json").exists() else {}
    for pet in pets:
        spec = PETS[pet]
        takes[pet] = []
        for seed in SEEDS:
            res = post("/text-to-voice/design", {"voice_description": spec["description"], "text": spec["text"],
                                                 "model_id": MODEL, "seed": seed})
            for i, p in enumerate(res["previews"]):
                name = f"{pet}_{seed}_{i + 1}.mp3"
                (out / name).write_bytes(base64.b64decode(p["audio_base_64"]))
                takes[pet].append({"file": name, "id": p["generated_voice_id"], "secs": p.get("duration_secs")})
            print(pet, "seed", seed, "->", len(res["previews"]), "previews")
    (out / "takes.json").write_text(json.dumps(takes, indent=1))
    rows = []
    for pet, items in takes.items():
        rows.append(f"<h2>{pet}</h2><p>{html.escape(PETS[pet]['description'])}</p>")
        for n, t in enumerate(items, 1):
            rows.append(f"<div><b>{pet} {n}</b> <audio controls preload=auto src='{t['file']}'></audio> "
                        f"<code>{t['id']}</code></div>")
    (out / "index.html").write_text("<meta charset=utf-8><title>PurrPal voices</title>"
                                    "<body style='font-family:sans-serif;max-width:60em'>" + "".join(rows))
    print(out / "index.html")


def save(pet, generated_id):
    spec = PETS[pet]
    res = post("/text-to-voice", {"voice_name": f"PurrPal {pet}", "voice_description": spec["description"],
                                  "generated_voice_id": generated_id})
    voices = json.loads(VOICES.read_text()) if VOICES.exists() else {}
    voices[pet] = {"voice_id": res["voice_id"], "model": MODEL, "description": spec["description"]}
    VOICES.write_text(json.dumps(voices, indent=1) + "\n")
    print(pet, "->", res["voice_id"])


if __name__ == "__main__":
    if sys.argv[1:2] == ["audition"]:
        audition(pathlib.Path(sys.argv[2]), sys.argv[3:] or list(PETS))
    elif sys.argv[1:2] == ["save"]:
        save(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)
