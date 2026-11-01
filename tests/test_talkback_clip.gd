extends TestCase

const RATE := 16000


func _const(sec: float, value: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(roundi(sec * RATE))
	out.fill(value)
	return out


func test_trim_trailing_silence() -> void:
	var audio := _const(0.5, 0.5)
	audio.append_array(_const(0.5, 0.0))
	var out := ClipProcessor.trim_trailing_silence(audio, RATE)
	check_near(float(out.size()) / RATE, 0.5 + ClipProcessor.TRIM_PAD_SEC, 0.001, "trimmed length")
	check_eq(ClipProcessor.trim_trailing_silence(_const(0.5, 0.0), RATE).size(), 0, "pure silence")


func test_fades() -> void:
	var audio := _const(1.0, 0.5)
	ClipProcessor.apply_fades(audio, RATE)
	var n := audio.size()
	check_near(audio[0], 0.0, 0.0001, "first sample")
	check_near(audio[n - 1], 0.0, 0.0001, "last sample")
	check_near(audio[roundi(0.005 * RATE)], 0.25, 0.01, "halfway through fade-in")
	check_near(audio[n - 1 - roundi(0.03 * RATE)], 0.25, 0.01, "halfway through fade-out")
	check_near(audio[n / 2], 0.5, 0.0001, "middle untouched")


func test_normalize_peak() -> void:
	var audio := _const(0.1, 0.25)
	audio[10] = -0.25
	ClipProcessor.normalize_peak(audio)
	check_near(ClipProcessor.peak(audio), db_to_linear(-3.0), 0.001, "peak at -3 dBFS")
	var quiet := _const(0.1, 0.001)
	ClipProcessor.normalize_peak(quiet)
	check_near(ClipProcessor.peak(quiet), 0.001 * db_to_linear(ClipProcessor.MAX_GAIN_DB), 0.0001, "gain capped")


func _noise(sec: float, rms: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(roundi(sec * RATE))
	for i in out.size():
		out[i] = rng.randf_range(-rms, rms) * sqrt(3.0)
	return out


func _gain_db(before: PackedFloat32Array, after: PackedFloat32Array, from_sec: float, to_sec: float) -> float:
	var a := 0.0
	var b := 0.0
	for i in range(roundi(from_sec * RATE), roundi(to_sec * RATE)):
		a += before[i] * before[i]
		b += after[i] * after[i]
	return 10.0 * log(b / a) / log(10.0)


func test_gate_dims_room_noise_between_words() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var floor_rms := 0.005
	# Room noise everywhere; words (300 Hz) at 0.4–0.8 s and 0.88–1.2 s, so the
	# 80 ms gap between them is shorter than the hold.
	var clip := _noise(2.0, floor_rms, rng)
	for i in clip.size():
		var t := float(i) / RATE
		if (t >= 0.4 and t < 0.8) or (t >= 0.88 and t < 1.2):
			clip[i] += 0.2 * sin(TAU * 300.0 * t)
	var before := clip.duplicate()
	ClipProcessor.apply_gate(clip, RATE, floor_rms)
	var closed := ClipProcessor.GATE_FLOOR_DB
	check_near(_gain_db(before, clip, 0.0, 0.35), closed, 0.5, "noise before the words")
	check_near(_gain_db(before, clip, 0.4, 0.8), 0.0, 0.05, "first word untouched")
	check_near(_gain_db(before, clip, 0.8, 0.88), 0.0, 0.05, "short gap held open")
	check_near(_gain_db(before, clip, 1.2, 1.2 + ClipProcessor.GATE_HOLD_SEC - 0.01), 0.0, 0.05, "hold after the last word")
	var shut := 1.2 + ClipProcessor.GATE_HOLD_SEC + ClipProcessor.GATE_RELEASE_SEC + 0.01
	check_near(_gain_db(before, clip, shut, 2.0), closed, 0.5, "noise after the release")
	# Looks ahead: fully open where the word starts, ramping over the attack before it.
	var onset := roundi(0.4 * RATE)
	check_near(clip[onset + 3], before[onset + 3], 0.00001, "onset not chopped")
	var ramp := _gain_db(before, clip, 0.4 - ClipProcessor.GATE_ATTACK_SEC, 0.4)
	check(ramp > closed + 3.0 and ramp < -1.0, "attack ramps up before the word, got %.1f dB" % ramp)


func test_gate_never_raises_and_needs_a_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var clip := _noise(0.5, 0.01, rng)
	var before := clip.duplicate()
	ClipProcessor.process(clip, RATE)
	check_eq(clip, before, "no floor, no gate")
	ClipProcessor.apply_gate(clip, RATE, 0.01)
	var louder := false
	for i in clip.size():
		louder = louder or absf(clip[i]) > absf(before[i])
	check(not louder, "gate only ever turns down")
	check_near(_gain_db(before, clip, 0.0, 0.5), ClipProcessor.GATE_FLOOR_DB, 0.5, "pure room noise stays dimmed")


func test_stream_and_envelope() -> void:
	var audio := _const(0.5, 0.0)
	for i in roundi(0.25 * RATE):
		audio[i] = 0.4
	var stream := ClipProcessor.make_stream(audio, RATE, 0.1)
	check_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "format")
	check_eq(stream.data.size(), (audio.size() + roundi(0.1 * RATE)) * 2, "bytes")
	check_near(stream.get_length(), 0.6, 0.001, "length")
	var env := ClipProcessor.compute_envelope(audio, RATE)
	check_eq(env.size(), 30, "one value per 1/60 s")
	check_near(env[0], 1.0, 0.0001, "loud part is 1")
	check_near(env[29], 0.0, 0.0001, "silent part is 0")
