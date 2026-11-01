"""Small numpy/scipy DSP kit shared by the SFX and music renderers.

Everything is mono float64 at SR. Run with the shared venv:
  /Users/akshay/Downloads/baby_apps/.tools/kokoro-venv/bin/python tools/audio/render_sfx.py
"""
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
PEAK_DB = -3.0


def t_axis(seconds):
    return np.arange(int(round(seconds * SR))) / SR


def phase_of(freq):
    """Integrate a frequency curve (Hz per sample) into phase in radians."""
    return 2 * np.pi * np.cumsum(freq) / SR


def osc(kind, freq, n):
    """sine / triangle / saw (band-limited by additive synthesis) with scalar or per-sample freq."""
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, float)
    ph = phase_of(f)
    if kind == "sine":
        return np.sin(ph)
    fmax = float(np.max(f))
    kmax = max(1, int(0.45 * SR / max(fmax, 1.0)))
    out = np.zeros(n)
    if kind == "triangle":
        for k in range(0, kmax, 2):
            h = k + 1
            if h > kmax:
                break
            out += ((-1) ** (k // 2)) * np.sin(h * ph) / (h * h)
        return out * 8 / np.pi ** 2
    if kind == "saw":
        for h in range(1, kmax + 1):
            out += np.sin(h * ph) / h
        return out * 2 / np.pi
    raise ValueError(kind)


def ramp(n, f0, f1, curve="lin"):
    if curve == "exp":
        return f0 * (f1 / f0) ** (np.arange(n) / max(n - 1, 1))
    return np.linspace(f0, f1, n)


def freq_curve(n, points, curve="lin"):
    """points: [(time_s, hz), ...]; holds the last value after the final point."""
    t = np.arange(n) / SR
    ts = [p[0] for p in points]
    hz = [p[1] for p in points]
    if curve == "exp":
        return np.exp(np.interp(t, ts, np.log(hz)))
    return np.interp(t, ts, hz)


def env(n, g0, g_end, decay_s, attack_s=0.003, floor=1e-4):
    """Click-free envelope: smooth attack to g0, exponential decay to g_end at decay_s, then silent."""
    t = np.arange(n) / SR
    g_end = max(g_end, floor)
    e = g0 * (g_end / g0) ** (t / decay_s)
    a = max(int(attack_s * SR), 1)
    att = np.ones(n)
    att[:a] = 0.5 - 0.5 * np.cos(np.pi * np.arange(a) / a)
    e = e * att
    cut = int(decay_s * SR)
    if cut < n:
        tail = min(n - cut, int(0.004 * SR))
        e[cut:] = 0
        if tail > 0:
            e[cut - 0:cut + tail] = e[cut - 1] * 0.5 * (1 + np.cos(np.pi * np.arange(tail) / tail))
    return e


def lowpass(x, fc, order=2):
    sos = signal.butter(order, fc, "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, fc, order=2):
    sos = signal.butter(order, fc, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, fc, q):
    """RBJ-style constant-peak-gain band-pass (like WebAudio 'bandpass')."""
    w0 = 2 * np.pi * fc / SR
    alpha = np.sin(w0) / (2 * q)
    b = np.array([alpha, 0, -alpha])
    a = np.array([1 + alpha, -2 * np.cos(w0), 1 - alpha])
    return signal.lfilter(b / a[0], a / a[0], x)


def place(buf, x, start_s):
    i = int(round(start_s * SR))
    end = i + len(x)
    if end > len(buf):
        buf = np.concatenate([buf, np.zeros(end - len(buf))])
    buf[i:end] += x
    return buf


def synth_ir(rt60=0.6, predelay=0.008, damp=4500, seed=7, length=None):
    """Soft synthetic room: exponentially decaying noise, darkened, with a short pre-delay."""
    length = length or rt60 * 1.1
    n = int(length * SR)
    rng = np.random.default_rng(seed)
    noise = rng.standard_normal(n)
    noise = lowpass(noise, damp, 2)
    t = np.arange(n) / SR
    ir = noise * 10 ** (-3 * t / rt60)
    # soften the very first reflections so the tail blooms instead of snapping
    fade_in = np.minimum(1.0, t / 0.015)
    ir *= fade_in
    ir = np.concatenate([np.zeros(int(predelay * SR)), ir])
    return ir / np.sqrt(np.sum(ir ** 2))


def reverb(x, wet=0.18, rt60=0.6, tail=None, **kw):
    """Linear (non-circular) reverb; extends the clip by the tail."""
    ir = synth_ir(rt60=rt60, **kw)
    tail = tail if tail is not None else rt60 * 0.9
    x = np.concatenate([x, np.zeros(int(tail * SR))])
    wetsig = signal.fftconvolve(x, ir)[: len(x)]
    # level-match wet to dry RMS before mixing so `wet` means the same across clips
    rms_d = np.sqrt(np.mean(x ** 2)) + 1e-12
    rms_w = np.sqrt(np.mean(wetsig ** 2)) + 1e-12
    return x + wet * wetsig * (rms_d / rms_w)


def circular_reverb(x, wet=0.2, rt60=1.2, **kw):
    """Reverb whose tail wraps around the loop point (x is exactly one loop long)."""
    n = len(x)
    ir = synth_ir(rt60=rt60, length=min(rt60 * 1.1, n / SR * 0.95), **kw)
    ir = np.concatenate([ir, np.zeros(max(0, n - len(ir)))])[:n]
    wetsig = np.real(np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir), n))
    rms_d = np.sqrt(np.mean(x ** 2)) + 1e-12
    rms_w = np.sqrt(np.mean(wetsig ** 2)) + 1e-12
    return x + wet * wetsig * (rms_d / rms_w)


def fold_loop(x, n):
    """Wrap everything past sample n back onto the start (overlap-add) so a loop is seamless."""
    out = np.zeros(n)
    for i in range(0, len(x), n):
        seg = x[i:i + n]
        out[:len(seg)] += seg
    return out


def finish(x, peak_db=PEAK_DB, fade_in_ms=1.0, fade_out_ms=25.0, trim_db=-60.0, trim=True):
    """Trim the inaudible tail, add micro-fades, remove DC, peak-normalise."""
    x = x - np.mean(x)
    if trim:
        thr = 10 ** (trim_db / 20) * np.max(np.abs(x))
        idx = np.nonzero(np.abs(x) > thr)[0]
        if len(idx):
            x = x[: idx[-1] + 1]
    n_in = int(fade_in_ms * 1e-3 * SR)
    n_out = min(int(fade_out_ms * 1e-3 * SR), len(x))
    if n_in:
        x[:n_in] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(n_in) / n_in)
    if n_out:
        x[-n_out:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(n_out) / n_out)
    return normalise(x, peak_db)


def normalise(x, peak_db=PEAK_DB):
    return x * (10 ** (peak_db / 20) / (np.max(np.abs(x)) + 1e-12))


def write_ogg(path, x, sr=SR):
    sf.write(str(path), x.astype(np.float32), sr, format="OGG", subtype="VORBIS")
    data, rate = sf.read(str(path), dtype="float32")
    assert rate == sr and abs(len(data) - len(x)) < 2048, path
    return len(data) / rate


def swell(n, attack_s=0.02, release_s=0.05):
    """Raised-cosine fade in and out around a flat middle (hums, whooshes)."""
    a = max(min(int(attack_s * SR), n // 2), 1)
    r = max(min(int(release_s * SR), n - a), 1)
    e = np.ones(n)
    e[:a] = 0.5 - 0.5 * np.cos(np.pi * np.arange(a) / a)
    e[n - r:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(r) / r)
    return e


def sweep_noise(rng, freq, bw=300.0):
    """Narrow noise band that follows a per-sample centre frequency (unit RMS)."""
    n = len(freq)
    band = lowpass(rng.standard_normal(n), bw)
    band = band / (np.std(band) + 1e-12)
    return band * np.sin(phase_of(freq)) * np.sqrt(2)


def lufs(x):
    """Whole-clip K-weighted loudness (BS.1770 filters, no gating, so short clips read sensibly)."""
    K = np.tan(np.pi * 1681.974450955533 / SR)
    Vh = 10 ** (3.999843853973347 / 20)
    Vb = Vh ** 0.4996667741545416
    Q = 0.7071752369554196
    a0 = 1 + K / Q + K * K
    y = signal.lfilter([(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0],
                       [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0], x)
    K = np.tan(np.pi * 38.13547087602444 / SR)
    Q = 0.5003270373238773
    a0 = 1 + K / Q + K * K
    y = signal.lfilter([1, -2, 1], [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0], y)
    return -0.691 + 10 * np.log10(np.mean(y ** 2) + 1e-20)


def finish_matched(x, lufs_target=-19.0, ceil_db=-2.0, **kw):
    """finish(), then gain to the shared SFX loudness (about -19 LUFS, like crunch / giggle / paw_tap),
    never past the peak ceiling."""
    x = finish(x, **kw)
    gain_db = lufs_target - lufs(x)
    peak_db = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
    return x * 10 ** (min(gain_db, ceil_db - peak_db) / 20)
