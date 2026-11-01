extends TestCase

const RATE := 16000
## The lullaby heard through the phone speaker, and a child talking over it.
const MUSIC_RMS := 0.0316
const SPEECH_AMP := 0.25

var _rng := RandomNumberGenerator.new()
var _started := 0
var _clips: Array[PackedFloat32Array] = []
var _short: Array[float] = []


func _make() -> VoiceDetector:
	_rng.seed = 7
	_started = 0
	_clips.clear()
	_short.clear()
	var det := VoiceDetector.new(RATE)
	det.speech_started.connect(func() -> void: _started += 1)
	det.speech_finished.connect(func(clip: PackedFloat32Array) -> void: _clips.append(clip))
	det.too_short.connect(func(d: float) -> void: _short.append(d))
	return det


func _noise(sec: float, rms: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(roundi(sec * RATE))
	var a := rms * sqrt(3.0)
	for i in out.size():
		out[i] = _rng.randf_range(-a, a)
	return out


func _tone(sec: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(roundi(sec * RATE))
	for i in out.size():
		out[i] = amp * sin(TAU * 300.0 * i / RATE)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	for i in mini(a.size(), b.size()):
		a[i] += b[i]
	return a


## Like the lullaby: a three-note chord every 3.2 s, notes 0.45 s apart, each
## swelling in 0.1 s and dying away at ~29 dB/s. Chord levels differ the way a
## phone speaker plays low notes softer; it starts on the softest chord, so
## calibration hears the quiet one first.
func _chords(sec: float, amp: float) -> PackedFloat32Array:
	var chords := [[196.0, 246.94, 293.66], [261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 261.63, 329.63]]
	var gains := [0.55, 1.0, 0.7, 0.7]
	var out := _noise(sec, 0.0018)
	var decay := exp(-3.3 / RATE)
	var c := 0
	while c * 3.2 < sec:
		for n in 3:
			var start := roundi((c * 3.2 + n * 0.45) * RATE)
			var f: float = chords[c % 4][n]
			var e: float = amp * gains[c % 4]
			for i in mini(roundi(3.0 * RATE), out.size() - start):
				var t := float(i) / RATE
				out[start + i] += minf(t * 10.0, 1.0) * e * sin(TAU * f * t)
				e *= decay
		c += 1
	return out


## Feeds in uneven chunks, like a real driver.
func _feed(det: VoiceDetector, samples: PackedFloat32Array) -> void:
	var i := 0
	var sizes := [735, 512, 2048, 97]
	var k := 0
	while i < samples.size():
		var n: int = mini(sizes[k % sizes.size()], samples.size() - i)
		det.feed(samples.slice(i, i + n))
		i += n
		k += 1


func test_silence_never_triggers() -> void:
	var det := _make()
	# Exact zeros: a recorder that isn't delivering. Never calibrates, never triggers.
	_feed(det, _noise(5.0, 0.0))
	check(not det.is_calibrated(), "digital silence doesn't calibrate")
	check_eq(_started, 0, "started")
	# A very quiet real room calibrates to the minimum floor and stays quiet.
	_feed(det, _noise(5.0, 0.0002))
	check(det.is_calibrated(), "calibrated")
	check_eq(_started, 0, "started")
	check_near(det.noise_floor, det.min_floor, 0.00001, "floor clamps to min")


func test_steady_noise_adapts_without_trigger() -> void:
	var det := _make()
	_feed(det, _noise(8.0, 0.03))
	check_near(det.noise_floor, 0.03, 0.006, "floor tracks noise")
	# Slow rise (fan spinning up) is followed, not mistaken for speech.
	var ramp := PackedFloat32Array()
	for step in 40:
		ramp.append_array(_noise(0.25, lerpf(0.03, 0.06, step / 39.0)))
	_feed(det, ramp)
	check_eq(_started, 0, "started")
	check(det.noise_floor > 0.045, "floor rose with noise, got %s" % det.noise_floor)


func test_speech_burst_gives_clip_with_pre_roll() -> void:
	var det := _make()
	var audio := _noise(1.0, 0.002)
	audio.append_array(_tone(1.0, 0.3))
	audio.append_array(_noise(1.5, 0.002))
	_feed(det, audio)
	check_eq(_started, 1, "started")
	check_eq(_clips.size(), 1, "clips")
	if _clips.size() == 1:
		var sec := float(_clips[0].size()) / RATE
		check_near(sec, 1.0 + det.pre_roll_sec + det.tail_keep_sec, 0.05, "clip length")
		check(absf(_clips[0][0]) < 0.02, "clip starts in the quiet pre-roll")
	check(not det.was_forced, "not forced")


func test_max_length_forces_stop() -> void:
	var det := _make()
	var audio := _noise(1.0, 0.002)
	audio.append_array(_tone(10.0, 0.3))
	_feed(det, audio)
	check_eq(_clips.size(), 1, "clips")
	if _clips.size() == 1:
		check_near(float(_clips[0].size()) / RATE, det.max_clip_sec, 0.001, "clip capped")
	check(det.was_forced, "forced")
	check_eq(_started, 1, "steady sound after a forced stop doesn't retrigger")


func test_too_short_burst_rejected() -> void:
	var det := _make()
	var audio := _noise(1.0, 0.002)
	audio.append_array(_tone(0.2, 0.3))
	audio.append_array(_noise(1.5, 0.002))
	_feed(det, audio)
	check_eq(_started, 1, "started")
	check_eq(_clips.size(), 0, "clips")
	check_eq(_short.size(), 1, "too_short")


func test_click_below_sustain_ignored() -> void:
	var det := _make()
	var audio := _noise(1.0, 0.002)
	audio.append_array(_tone(0.04, 0.5))
	audio.append_array(_noise(1.0, 0.002))
	_feed(det, audio)
	check_eq(_started, 0, "started")


func test_muted_audio_is_skipped_and_state_kept() -> void:
	var det := _make()
	det.muted = true
	_feed(det, _noise(2.0, 0.002))
	check(not det.is_calibrated(), "calibration waits while muted")
	det.muted = false
	_feed(det, _noise(1.0, 0.002))
	check(det.is_calibrated(), "calibrated")
	var floor_before := det.noise_floor
	det.muted = true
	_feed(det, _tone(1.0, 0.3))
	_feed(det, _noise(2.0, 0.02))
	check_eq(_started, 0, "a muted sound never starts a clip")
	check_eq(det.noise_floor, floor_before, "floor not fed")
	det.muted = false
	_feed(det, _tone(0.5, 0.3))
	check_eq(_started, 1, "listens after the mute")
	det.muted = true
	# Muted time counts neither as silence nor towards the length cap.
	_feed(det, _noise(3.0, 0.002))
	_feed(det, _tone(8.0, 0.3))
	check(det.is_recording(), "clip kept across the mute")
	det.muted = false
	_feed(det, _tone(0.5, 0.3))
	_feed(det, _noise(1.5, 0.002))
	check_eq(_started, 1, "one start")
	check_eq(_clips.size(), 1, "one clip")
	if _clips.size() == 1:
		check_near(float(_clips[0].size()) / RATE, 1.0 + det.pre_roll_sec + det.tail_keep_sec, 0.05, "muted part left out")
	check(not det.was_forced, "not forced")


func test_speech_over_steady_music() -> void:
	var det := _make()
	det.music = true
	det.recalibrate()
	_feed(det, _noise(30.0, MUSIC_RMS))
	check(det.is_calibrated(), "calibrated over the music")
	check_eq(_started, 0, "music alone never triggers")
	_feed(det, _mix(_noise(1.0, MUSIC_RMS), _tone(1.0, SPEECH_AMP)))
	_feed(det, _noise(1.5, MUSIC_RMS))
	check_eq(_started, 1, "speech over the music starts a clip")
	check_eq(_clips.size(), 1, "and finishes once the music is alone again")


func test_lullaby_chords_never_trigger_in_music_mode() -> void:
	var song := _chords(26.0, 0.25)
	var det := _make()
	det.music = true
	det.recalibrate()
	_feed(det, song)
	check(det.is_calibrated(), "calibrated over the music")
	check_eq(_started, 0, "chord onsets aren't speech")
	_feed(det, _mix(_chords(1.2, 0.25), _tone(1.2, 0.6)))
	_feed(det, _chords(1.5, 0.05))
	check_eq(_started, 1, "a child louder than the music is heard")
	# Why music mode exists: the normal floor sinks between chords.
	det = _make()
	_feed(det, song)
	check(_started > 0, "without music mode the same song triggers")
