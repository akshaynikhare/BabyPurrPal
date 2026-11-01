"""Render BabyPurrPal SFX + lullaby to OGG Vorbis (44.1 kHz mono).

  /Users/akshay/Downloads/baby_apps/.tools/kokoro-venv/bin/python tools/audio/render_sfx.py [clip ...]

With no arguments everything is rendered; with names (e.g. `gulp_1 splash`) only those clips.
Recipes follow docs/REWRITE_SPEC.md "Audio", softened: click-free envelopes,
a short synthetic-room reverb tail, peak-normalised to about -3 dBFS
(loops and the lullaby sit lower so they stay in the background).
The toy-system one-shots are levelled to about -19 LUFS instead (peak at most -2 dBFS).
"""
import pathlib
import sys
import numpy as np
import dsp
from dsp import SR

ROOT = pathlib.Path(__file__).resolve().parents[2]
SFX = ROOT / "assets/audio/sfx"
MUSIC = ROOT / "assets/audio/music"

SCALE = [261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0]
CHORDS = [
    [261.63, 329.63, 392.0],    # C
    [220.0, 261.63, 329.63],    # Am
    [174.61, 261.63, 329.63],   # F
    [196.0, 246.94, 293.66],    # G
]


def note(kind, f, dur, g0, dec, attack=0.004):
    n = int(dur * SR)
    return dsp.osc(kind, f, n) * dsp.env(n, g0, 0.001, dec, attack)


def chime(f):
    n = int(0.8 * SR)
    a = dsp.lowpass(dsp.osc("sine", f, n), 1600) * dsp.env(n, 0.35, 1e-4, 0.7, 0.015)
    b = dsp.osc("sine", 2 * f, n) * dsp.env(n, 0.08, 1e-4, 0.35, 0.015)
    return dsp.finish(dsp.reverb(a + b, wet=0.2, rt60=0.7))


def giggle():
    buf = np.zeros(1)
    for i, f in enumerate([400, 560, 480, 640, 520, 700]):
        n = int(0.1 * SR)
        fc = dsp.freq_curve(n, [(0, f), (0.06, f * 1.2)])
        buf = dsp.place(buf, dsp.osc("triangle", fc, n) * dsp.env(n, 0.2, 0.001, 0.09, 0.01), i * 0.07)
    return dsp.finish(dsp.reverb(dsp.lowpass(buf, 5000), wet=0.2, rt60=0.45))


def paw_tap():
    n = int(0.22 * SR)
    f = dsp.freq_curve(n, [(0, 320), (0.15, 140)])
    x = dsp.lowpass(dsp.osc("triangle", f, n), 1200) * dsp.env(n, 0.3, 0.001, 0.2, 0.004)
    return dsp.finish(dsp.reverb(x, wet=0.12, rt60=0.3))


def twinkle():
    buf = np.zeros(1)
    for i, f in enumerate([659.25, 783.99, 987.77, 1318.51]):
        buf = dsp.place(buf, note("sine", f, 0.25, 0.18, 0.2, 0.006), i * 0.05)
    return dsp.finish(dsp.reverb(buf, wet=0.28, rt60=0.9))


PURR_PERIOD = 2.5      # 26 Hz and 3.6 Hz both fit a whole number of times: 65 and 9 cycles
PURR_LEVEL = -6.0


def purr_periodic(seconds):
    """Saw 26 Hz -> band-pass 80 Hz (Q 1.5) with a 3.6 Hz wobble; a second band adds
    body at ~220 Hz so it stays audible on phone speakers."""
    n = int(seconds * SR)
    saw = dsp.osc("saw", 26.0, n)
    low = dsp.bandpass(saw, 80.0, 1.5)
    body = dsp.bandpass(saw, 220.0, 1.2) * 0.9
    t = np.arange(n) / SR
    wobble = 0.72 + 0.28 * np.sin(2 * np.pi * 3.6 * t)
    return (low + body) * wobble


def purr():
    n_loop = int(PURR_PERIOD * SR)
    x = purr_periodic(3 * PURR_PERIOD + 0.5)
    mid = x[n_loop: 2 * n_loop]                      # filter transients are long gone
    gain = 10 ** (PURR_LEVEL / 20) / np.max(np.abs(mid))
    dc = np.mean(mid)
    loop = (mid - dc) * gain
    # tail: the signal continues from the loop end for 0.25 s while fading out
    n_tail = int(0.25 * SR)
    tail = (x[2 * n_loop: 2 * n_loop + n_tail] - dc) * gain
    tail = tail * (0.5 + 0.5 * np.cos(np.pi * np.arange(n_tail) / n_tail))
    return loop, tail


def woof():
    n = int(0.3 * SR)
    f = dsp.freq_curve(n, [(0, 260), (0.06, 460), (0.22, 220)])
    x = 0.7 * dsp.osc("triangle", f, n) + 0.3 * dsp.osc("saw", f, n)
    x = dsp.bandpass(x, 500, 1.2) * dsp.env(n, 0.38, 0.001, 0.24, 0.03)
    return dsp.finish(dsp.reverb(x, wet=0.15, rt60=0.4))


def pant():
    buf = np.zeros(1)
    rng = np.random.default_rng(3)
    for i in range(3):
        n = int(0.13 * SR)
        f = dsp.freq_curve(n, [(0, 180), (0.08, 120)])
        e = dsp.env(n, 0.12, 0.001, 0.09, 0.008)
        breath = dsp.bandpass(rng.standard_normal(n), 1800, 0.7) * e * 0.35
        buf = dsp.place(buf, dsp.osc("sine", f, n) * e + breath, i * 0.12)
    return dsp.finish(dsp.reverb(buf, wet=0.12, rt60=0.3))


def squeak():
    n = int(0.26 * SR)
    f = dsp.freq_curve(n, [(0, 880), (0.12, 1380)])
    x = dsp.osc("sine", f, n) * dsp.env(n, 0.24, 0.001, 0.22, 0.006)
    return dsp.finish(dsp.reverb(x, wet=0.18, rt60=0.4))


def crunch():
    buf = np.zeros(1)
    rng = np.random.default_rng(5)
    for i, f in enumerate([740, 920, 680, 840]):
        n = int(0.07 * SR)
        fc = dsp.freq_curve(n, [(0, f), (0.04, f * 0.5)])
        e = dsp.env(n, 0.2, 0.001, 0.05, 0.002)
        grit = dsp.highpass(rng.standard_normal(n), 1500) * e * 0.35
        buf = dsp.place(buf, dsp.lowpass(dsp.osc("triangle", fc, n), 4000) * e + dsp.lowpass(grit, 7000), i * 0.06)
    return dsp.finish(dsp.reverb(buf, wet=0.12, rt60=0.3))


def footstep():
    n = int(0.1 * SR)
    f = dsp.freq_curve(n, [(0, 180), (0.06, 80)])
    x = dsp.lowpass(dsp.osc("triangle", f, n), 700) * dsp.env(n, 0.15, 0.001, 0.07, 0.004)
    return dsp.finish(dsp.reverb(x, wet=0.1, rt60=0.25))


def babble():
    """Old formula clip: (sin(2*pi*f*t) + 0.3*sin(4*pi*f*t)) * (0.5*sin(24t)+0.5) * 0.45.
    Phase-continuous across the four pitch steps, with short glides instead of jumps."""
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    f = dsp.freq_curve(n, [(0, 520), (0.29, 520), (0.31, 650), (0.59, 650), (0.61, 440),
                           (0.89, 440), (0.91, 720), (1.4, 720)])
    ph = dsp.phase_of(f)
    x = (np.sin(ph) + 0.3 * np.sin(2 * ph)) * (0.5 * np.sin(24 * t) + 0.5) * 0.45
    return dsp.finish(x, fade_in_ms=8, fade_out_ms=40, trim=False)


def lullaby():
    chord_gap, note_gap = 3.2, 0.45
    loop_len = int(round(len(CHORDS) * chord_gap * SR))
    buf = np.zeros(loop_len)
    for ci, chord in enumerate(CHORDS):
        for ni, f in enumerate(chord):
            n = int(3.0 * SR)
            x = dsp.osc("sine", f, n) * dsp.env(n, 0.18, 1e-4, 2.8, 0.1)
            buf = dsp.place(buf, dsp.lowpass(x, 900), ci * chord_gap + ni * note_gap)
    buf = dsp.fold_loop(buf, loop_len)
    buf = dsp.circular_reverb(buf, wet=0.25, rt60=1.8)
    buf = buf - np.mean(buf)
    return dsp.normalise(buf, -6.0), loop_len / SR


# Toy-system one-shots. Same tools as above (soft attacks, small room), but levelled with
# finish_matched so noisy and tonal clips land at the same loudness as crunch / giggle / paw_tap.

def gulp(f0, dip, f1, dur, t_dip, seed, bubble=0.0):
    """Pitch falls to a dip, then rises: a warm swallow with a soft click at the turn."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    fc = dsp.freq_curve(n, [(0, f0), (t_dip, dip), (dur * 0.85, f1)])
    x = 0.8 * dsp.osc("sine", fc, n) + 0.2 * dsp.osc("triangle", fc, n)
    x = dsp.lowpass(x, 1400) * dsp.env(n, 0.3, 0.15, dur, 0.008) * dsp.swell(n, 0.001, 0.07)
    x = x * (1 - bubble + bubble * np.sin(2 * np.pi * 26 * t) ** 2)
    nc = int(0.03 * SR)
    rng = np.random.default_rng(seed)
    click = dsp.lowpass(rng.standard_normal(nc), 2200) * dsp.env(nc, 0.1, 0.002, 0.025, 0.006)
    return dsp.finish_matched(dsp.reverb(dsp.place(x, click, t_dip * 0.8), wet=0.1, rt60=0.25), trim_db=-40)


def lap(ticks, seed):
    """Two quick tongue ticks: a tiny rising bloop with a soft smack."""
    rng = np.random.default_rng(seed)
    buf = np.zeros(1)
    for t0, f0, f1 in ticks:
        n = int(0.045 * SR)
        fc = dsp.freq_curve(n, [(0, f0), (0.03, f1)])
        e = dsp.env(n, 0.25, 0.002, 0.04, 0.006)
        smack = dsp.bandpass(rng.standard_normal(n), 2200, 1.0) * dsp.env(n, 0.2, 0.002, 0.03, 0.006)
        buf = dsp.place(buf, dsp.osc("sine", fc, n) * e + smack, t0)
    return dsp.finish_matched(dsp.reverb(buf, wet=0.1, rt60=0.2), trim_db=-40)


def slurp():
    n = int(0.34 * SR)
    t = np.arange(n) / SR
    f = dsp.freq_curve(n, [(0, 320), (0.26, 980)], "exp") * (1 + 0.03 * np.sin(2 * np.pi * 20 * t))
    rise = 0.35 + 0.65 * np.minimum(t / 0.26, 1)
    x = dsp.lowpass(0.85 * dsp.osc("sine", f, n) + 0.15 * dsp.osc("triangle", f, n), 2500) * 0.3
    air = dsp.sweep_noise(np.random.default_rng(21), dsp.freq_curve(n, [(0, 900), (0.3, 2600)]), 500) * 0.08
    x = (x + air) * rise * (0.8 + 0.2 * np.sin(2 * np.pi * 20 * t)) * dsp.swell(n, 0.04, 0.04)
    nq = int(0.14 * SR)
    pip = dsp.osc("sine", 1319, nq) * dsp.env(nq, 0.35, 0.002, 0.1, 0.008)
    return dsp.finish_matched(dsp.reverb(dsp.place(x, pip, 0.27), wet=0.12, rt60=0.3), trim_db=-40)


def munch(blips, seed):
    """Lighter, shorter crunch: soft triangle blips with band-limited grit."""
    rng = np.random.default_rng(seed)
    buf = np.zeros(1)
    for t0, f in blips:
        n = int(0.055 * SR)
        fc = dsp.freq_curve(n, [(0, f), (0.04, f * 0.6)])
        e = dsp.env(n, 0.2, 0.002, 0.05, 0.006)
        grit = dsp.bandpass(rng.standard_normal(n), 2400, 0.8) * e * 0.3
        buf = dsp.place(buf, dsp.lowpass(dsp.osc("triangle", fc, n), 2500) * e + grit, t0)
    return dsp.finish_matched(dsp.reverb(buf, wet=0.1, rt60=0.25), trim_db=-40)


def yum():
    """Two-note 'mm-hm' hum, the second note a third higher with a small scoop; gentle vibrato."""
    buf = np.zeros(1)
    for t0, f, d, scoop in [(0.0, 523.25, 0.19, 0.0), (0.22, 659.25, 0.2, 0.05)]:
        n = int(d * SR)
        t = np.arange(n) / SR
        fc = f * (1 + 0.014 * np.sin(2 * np.pi * 6 * t) * np.minimum(t / 0.08, 1))
        if scoop:
            fc = fc * dsp.freq_curve(n, [(0, 0.94), (scoop, 1.0)])
        x = dsp.osc("sine", fc, n) + 0.2 * dsp.osc("triangle", fc, n)
        buf = dsp.place(buf, dsp.lowpass(x, 2200) * dsp.swell(n, 0.03, 0.08) * 0.3, t0)
    return dsp.finish_matched(dsp.reverb(buf, wet=0.15, rt60=0.35), trim_db=-38)


def bounce(f0, f1, dur, wob_hz, wob_depth):
    """Rubber boing: falling pitch with a quickly fading wobble, a soft thump underneath."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = dsp.freq_curve(n, [(0, f0), (dur, f1)], "exp") * (1 + wob_depth * np.sin(2 * np.pi * wob_hz * t) * np.exp(-t / 0.09))
    x = dsp.lowpass(0.7 * dsp.osc("sine", f, n) + 0.3 * dsp.osc("triangle", f, n), 1800)
    x = x * dsp.env(n, 0.3, 0.01, dur * 0.95, 0.006) * dsp.swell(n, 0.001, 0.05)
    nt = int(0.06 * SR)
    thump = dsp.osc("sine", dsp.freq_curve(nt, [(0, 190), (0.05, 90)]), nt) * dsp.env(nt, 0.2, 0.002, 0.05, 0.006)
    return dsp.finish_matched(dsp.reverb(dsp.place(x, thump, 0), wet=0.12, rt60=0.3), trim_db=-45)


def roll():
    """Soft rumble with a slowing once-per-turn pulse and a little upper whoosh; yarn, not wood."""
    dur = 0.5
    n = int(dur * SR)
    rng = np.random.default_rng(31)
    noise = rng.standard_normal(n)
    rumble = dsp.lowpass(noise, 420)
    rumble = rumble / np.std(rumble)
    body = dsp.bandpass(noise, 180, 1.0)
    air = dsp.sweep_noise(rng, dsp.freq_curve(n, [(0, 500), (dur, 800)]), 250) * 0.35
    turn = dsp.phase_of(dsp.freq_curve(n, [(0, 8.0), (dur, 5.0)]))
    x = (0.8 * rumble + 0.4 * body + air) * (0.7 + 0.3 * np.sin(turn)) * dsp.swell(n, 0.12, 0.2)
    return dsp.finish_matched(dsp.reverb(x, wet=0.1, rt60=0.3), trim_db=-45)


BELL = [(1.0, 1.0, 0.30), (2.32, 0.38, 0.17), (4.25, 0.2, 0.10), (6.63, 0.09, 0.06)]


def jingle(strikes):
    """Small bells: a few inharmonic partials with fast decay, struck in quick succession."""
    buf = np.zeros(1)
    for t0, f, g in strikes:
        n = int(0.32 * SR)
        x = np.zeros(n)
        for ratio, amp, dec in BELL:
            if f * ratio < 8000:
                x += dsp.osc("sine", f * ratio, n) * dsp.env(n, 0.2 * amp * g, 0.001, dec, 0.006)
        buf = dsp.place(buf, x, t0)
    return dsp.finish_matched(dsp.reverb(dsp.lowpass(buf, 6500), wet=0.22, rt60=0.5), trim_db=-40)


def splash():
    """Filtered noise burst with a trailing trickle, and a few droplet pings."""
    n = int(0.32 * SR)
    rng = np.random.default_rng(41)
    noise = rng.standard_normal(n)
    burst = dsp.lowpass(dsp.bandpass(noise, 1400, 0.7) + 0.5 * dsp.bandpass(noise, 3200, 0.8), 5000)
    amp = dsp.place(dsp.env(n, 0.35, 0.002, 0.16, 0.008), dsp.env(int(0.12 * SR), 0.1, 0.002, 0.1, 0.01), 0.1)
    buf = burst * amp
    for t0, f in [(0.09, 900), (0.16, 1250), (0.23, 1050)]:
        nd = int(0.08 * SR)
        fd = dsp.freq_curve(nd, [(0, f), (0.025, f * 1.5)])
        buf = dsp.place(buf, dsp.osc("sine", fd, nd) * dsp.env(nd, 0.09, 0.002, 0.07, 0.006), t0)
    return dsp.finish_matched(dsp.reverb(buf, wet=0.12, rt60=0.25), trim_db=-45)


def pop_in():
    n = int(0.1 * SR)
    x = dsp.osc("sine", dsp.freq_curve(n, [(0, 330), (0.05, 880)]), n) * dsp.env(n, 0.3, 0.002, 0.09, 0.006)
    puff = dsp.bandpass(np.random.default_rng(51).standard_normal(n), 1800, 1.0) * dsp.env(n, 0.08, 0.002, 0.03, 0.006)
    buf = x + puff
    for t0, f in [(0.03, 1760), (0.065, 2349)]:
        nq = int(0.12 * SR)
        buf = dsp.place(buf, dsp.osc("sine", f, nq) * dsp.env(nq, 0.1, 0.002, 0.1, 0.006), t0)
    return dsp.finish_matched(dsp.reverb(buf, wet=0.15, rt60=0.3), trim_db=-45)


def pop_out():
    """Sparkle falls away first, then a soft sucked-in bloop; slower attack than pop_in."""
    buf = np.zeros(1)
    for t0, f in [(0.0, 2349), (0.035, 1760)]:
        nq = int(0.1 * SR)
        buf = dsp.place(buf, dsp.osc("sine", f, nq) * dsp.env(nq, 0.1, 0.002, 0.08, 0.006), t0)
    n = int(0.11 * SR)
    x = dsp.osc("sine", dsp.freq_curve(n, [(0, 880), (0.07, 300)]), n) * dsp.env(n, 0.3, 0.002, 0.1, 0.02)
    return dsp.finish_matched(dsp.reverb(dsp.place(buf, x, 0.05), wet=0.15, rt60=0.25), trim_db=-38)


def toy_clips():
    return {
        "gulp_1": gulp(430, 200, 340, 0.19, 0.06, 11),
        "gulp_2": gulp(360, 165, 290, 0.21, 0.075, 12, bubble=0.3),
        "gulp_3": gulp(520, 250, 470, 0.17, 0.05, 13),
        "lap_1": lap([(0.0, 560, 900), (0.055, 640, 1000)], 14),
        "lap_2": lap([(0.0, 700, 1100), (0.05, 520, 820)], 15),
        "slurp": slurp(),
        "munch_1": munch([(0.0, 560), (0.07, 480)], 16),
        "munch_2": munch([(0.0, 640), (0.05, 520), (0.1, 580)], 17),
        "yum": yum(),
        "bounce_1": bounce(600, 230, 0.24, 32, 0.07),
        "bounce_2": bounce(480, 190, 0.27, 26, 0.06),
        "roll": roll(),
        "jingle_1": jingle([(0.0, 1319, 1.0), (0.07, 1568, 0.8), (0.14, 1397, 0.7), (0.21, 1760, 0.5)]),
        "jingle_2": jingle([(0.0, 1175, 0.9), (0.06, 1397, 1.0), (0.12, 1760, 0.7), (0.18, 1568, 0.6), (0.25, 1976, 0.4)]),
        "splash": splash(),
        "pop_in": pop_in(),
        "pop_out": pop_out(),
    }


def main():
    """No arguments renders everything; clip names as arguments render only those."""
    only = set(sys.argv[1:])
    SFX.mkdir(parents=True, exist_ok=True)
    MUSIC.mkdir(parents=True, exist_ok=True)
    clips = {f"chime_{i}": chime(f) for i, f in enumerate(SCALE)}
    clips.update(giggle=giggle(), paw_tap=paw_tap(), twinkle=twinkle())
    loop, tail = purr()
    clips.update(purr_loop=loop, purr_tail=tail, woof=woof(), pant=pant(), squeak=squeak(),
                 crunch=crunch(), footstep=footstep(), babble=babble())
    clips.update(toy_clips())
    for name, x in clips.items():
        if only and name not in only:
            continue
        d = dsp.write_ogg(SFX / f"{name}.ogg", x)
        print(f"sfx/{name}.ogg  {d:.3f}s")
    if only and "lullaby" not in only:
        return
    x, t = lullaby()
    d = dsp.write_ogg(MUSIC / "lullaby.ogg", x)
    print(f"music/lullaby.ogg  {d:.3f}s (loop {t:.3f}s)")


if __name__ == "__main__":
    main()
