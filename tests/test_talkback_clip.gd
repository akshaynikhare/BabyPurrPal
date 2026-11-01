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
