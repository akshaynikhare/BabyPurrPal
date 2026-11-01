class_name ClipProcessor
extends RefCounted
## Pure clean-up of a detected clip before playback, plus the WAV and mouth
## envelope built from it.

## A sample counts as sound when above peak × this, or above SILENCE_ABS.
const SILENCE_REL := 0.03
const SILENCE_ABS := 0.002
## Sound kept after the last loud block so the fade has something to fade.
const TRIM_PAD_SEC := 0.03
const FADE_IN_SEC := 0.01
const FADE_OUT_SEC := 0.06
## Peak target, about −3 dBFS.
const TARGET_PEAK_DB := -3.0
## Most gain normalize may add; a clip of pure room noise stays quiet.
const MAX_GAIN_DB := 18.0
const ENVELOPE_RATE := 60.0


## Trim, fade and normalize; returns a new array.
## One peak pass: trimming and fading never raise it, so the gain stays safe.
static func process(samples: PackedFloat32Array, sample_rate: int) -> PackedFloat32Array:
	var p := peak(samples)
	var out := trim_trailing_silence(samples, sample_rate, p)
	apply_fades(out, sample_rate)
	normalize_peak(out, TARGET_PEAK_DB, MAX_GAIN_DB, p)
	return out


static func peak(samples: PackedFloat32Array) -> float:
	var p := 0.0
	for s in samples:
		p = maxf(p, absf(s))
	return p


static func trim_trailing_silence(samples: PackedFloat32Array, sample_rate: int, known_peak := -1.0) -> PackedFloat32Array:
	var threshold := maxf((known_peak if known_peak >= 0.0 else peak(samples)) * SILENCE_REL, SILENCE_ABS)
	var last := -1
	for i in range(samples.size() - 1, -1, -1):
		if absf(samples[i]) > threshold:
			last = i
			break
	if last < 0:
		return PackedFloat32Array()
	return samples.slice(0, mini(samples.size(), last + 1 + roundi(TRIM_PAD_SEC * sample_rate)))


## Linear fade-in and fade-out, in place. Fades shrink to fit very short clips.
static func apply_fades(samples: PackedFloat32Array, sample_rate: int, fade_in_sec := FADE_IN_SEC, fade_out_sec := FADE_OUT_SEC) -> void:
	var n := samples.size()
	var fade_in := mini(roundi(fade_in_sec * sample_rate), n / 2)
	var fade_out := mini(roundi(fade_out_sec * sample_rate), n / 2)
	for i in fade_in:
		samples[i] *= float(i) / fade_in
	for i in fade_out:
		samples[n - 1 - i] *= float(i) / fade_out


## Scales in place so the peak sits at target_db, never adding more than max_gain_db.
static func normalize_peak(samples: PackedFloat32Array, target_db := TARGET_PEAK_DB, max_gain_db := MAX_GAIN_DB, known_peak := -1.0) -> float:
	var p := known_peak if known_peak >= 0.0 else peak(samples)
	if p <= 0.0:
		return 1.0
	var gain := minf(db_to_linear(target_db) / p, db_to_linear(max_gain_db))
	for i in samples.size():
		samples[i] *= gain
	return gain


## 16-bit mono WAV. pad_sec of trailing silence lets the pitch-shift FIFO flush
## so the last syllable isn't cut off.
static func make_stream(samples: PackedFloat32Array, sample_rate: int, pad_sec := 0.0) -> AudioStreamWAV:
	var pad := roundi(pad_sec * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize((samples.size() + pad) * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, clampi(roundi(samples[i] * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream


## One RMS value per 1/rate s, scaled so the loudest block is 1.0.
static func compute_envelope(samples: PackedFloat32Array, sample_rate: int, rate := ENVELOPE_RATE) -> PackedFloat32Array:
	var block := maxi(1, roundi(sample_rate / rate))
	var env := PackedFloat32Array()
	env.resize(ceili(float(samples.size()) / block))
	var top := 0.0
	for b in env.size():
		var start := b * block
		var end := mini(start + block, samples.size())
		var sum := 0.0
		for i in range(start, end):
			sum += samples[i] * samples[i]
		env[b] = sqrt(sum / (end - start))
		top = maxf(top, env[b])
	if top > 0.0:
		for b in env.size():
			env[b] /= top
	return env
