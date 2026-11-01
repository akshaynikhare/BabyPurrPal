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
## Soft noise gate (see apply_gate), on 5 ms frame energies. It opens at +6 dB over
## the room's floor and stays open down to +3 dB. Closed is −18 dB, not silence,
## so a soft sound it misjudges is dimmed, not cut.
const GATE_FRAME_SEC := 0.005
const GATE_OPEN_FACTOR := 2.0
const GATE_CLOSE_FACTOR := 1.4
const GATE_FLOOR_DB := -18.0
const GATE_ATTACK_SEC := 0.01
const GATE_HOLD_SEC := 0.15
const GATE_RELEASE_SEC := 0.06


## Gate (if the room's noise_floor is known), trim, fade and normalize; returns a
## new array and gates samples in place.
## One peak pass, after the gate: trimming and fading never raise it, so the gain stays safe.
static func process(samples: PackedFloat32Array, sample_rate: int, noise_floor := 0.0) -> PackedFloat32Array:
	if noise_floor > 0.0:
		apply_gate(samples, sample_rate, noise_floor)
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


## Turns stretches that are only room noise (the hiss between words) down to
## GATE_FLOOR_DB, in place. The clip is already complete, so the gate looks
## ahead: it is fully open when a word starts, holds GATE_HOLD_SEC after the
## last loud frame so word endings and short gaps stay, then closes over
## GATE_RELEASE_SEC. Gain ramps per sample, so it never clicks.
static func apply_gate(samples: PackedFloat32Array, sample_rate: int, noise_floor: float) -> void:
	var frame := maxi(1, roundi(GATE_FRAME_SEC * sample_rate))
	var count := ceili(float(samples.size()) / frame)
	if count == 0:
		return
	var closed := db_to_linear(GATE_FLOOR_DB)
	var open_sq := pow(noise_floor * GATE_OPEN_FACTOR, 2.0)
	var stay_sq := pow(noise_floor * GATE_CLOSE_FACTOR, 2.0)
	var hold := roundi(GATE_HOLD_SEC / GATE_FRAME_SEC)
	# Gain at the start of each frame (plus one past the end).
	var gains := PackedFloat32Array()
	gains.resize(count + 1)
	var is_open := false
	var held := 0
	for f in count:
		var start := f * frame
		var end := mini(start + frame, samples.size())
		var sum := 0.0
		for i in range(start, end):
			sum += samples[i] * samples[i]
		var mean_sq := sum / (end - start)
		if mean_sq > open_sq or (is_open and mean_sq > stay_sq):
			is_open = true
			held = hold
		elif held > 0:
			held -= 1
		else:
			is_open = false
		gains[f] = 1.0 if is_open else closed
	gains[count] = gains[count - 1]
	# Release forwards, attack backwards (the look-ahead), as a cap on the change per frame.
	var fall := (1.0 - closed) * GATE_FRAME_SEC / GATE_RELEASE_SEC
	for f in range(1, count + 1):
		gains[f] = maxf(gains[f], gains[f - 1] - fall)
	var rise := (1.0 - closed) * GATE_FRAME_SEC / GATE_ATTACK_SEC
	for f in range(count - 1, -1, -1):
		gains[f] = maxf(gains[f], gains[f + 1] - rise)
	for f in count:
		var g := gains[f]
		if g == 1.0 and gains[f + 1] == 1.0:
			continue
		var start := f * frame
		var step := (gains[f + 1] - g) / frame
		for i in range(start, mini(start + frame, samples.size())):
			samples[i] *= g
			g += step


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
