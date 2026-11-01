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


## A clock heard through the phone, like amb_night's: once a second a 1.6 kHz
## knock swells over 20 ms and rings out at 250 dB/s.
static func clock_ticks(rate: int, sec: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(roundi(sec * rate))
	var decay := exp(-250.0 / 20.0 * log(10.0) / rate)
	for tick in ceili(sec):
		var start := tick * rate
		var e := amp
		for i in mini(roundi(0.4 * rate), out.size() - start):
			var t := float(i) / rate
			out[start + i] += minf(t / 0.02, 1.0) * e * sin(TAU * 1600.0 * t)
			e *= decay
	return out


## Birdsong: every 1.5 s a phrase of six 100 ms chirps (10 ms fades) sweeping 3.6–5.2 kHz,
## 25 ms apart, so the phrase looks sustained to a level-only detector.
static func birdsong(rate: int, sec: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(roundi(sec * rate))
	var chirp := roundi(0.1 * rate)
	var phrase := 0.0
	while phrase < sec:
		for c in 6:
			var start := roundi((phrase + c * 0.125) * rate)
			var phase := 0.0
			for i in clampi(out.size() - start, 0, chirp):
				var u := float(i) / chirp
				phase += TAU * lerpf(3600.0, 5200.0, u) / rate
				out[start + i] += amp * minf(1.0, minf(u, 1.0 - u) * 10.0) * sin(phase)
		phrase += 1.5
	return out


## Babble: "ba-ba-ba" at 400 Hz, syllables every 0.26 s that dip to silence.
func _babble(sec: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(roundi(sec * RATE))
	for i in out.size():
		var t := float(i) / RATE
		out[i] = amp * (0.5 - 0.5 * cos(24.0 * t)) * sin(TAU * 400.0 * t)
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
	# The Mic bus filters' ringing tail after a recorder closes: tiny, never zero.
	_feed(det, _noise(1.0, 0.000000001))
	check(not det.is_calibrated(), "a filter tail is still digital silence")
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


func test_clock_ticks_never_trigger() -> void:
	for amp in [0.03, 0.08, 0.2]:
		var det := _make()
		_feed(det, _noise(1.0, 0.002))
		_feed(det, _mix(_noise(10.0, 0.002), clock_ticks(RATE, 10.0, amp)))
		check_eq(_started, 0, "ticks at amp %s" % amp)
		_feed(det, _mix(_tone(1.0, 0.3), clock_ticks(RATE, 1.0, amp)))
		_feed(det, _noise(1.5, 0.002))
		check_eq(_clips.size(), 1, "a child over the clock at amp %s" % amp)
	# Why the hold rule exists: the knock outlasts the sustain window.
	var det := _make()
	det.onset_max_drop_db = 100.0
	det.configure(RATE)
	_feed(det, _noise(1.0, 0.002))
	_feed(det, _mix(_noise(10.0, 0.002), clock_ticks(RATE, 10.0, 0.2)))
	check(_started > 0, "without the hold rule the clock triggers")


func test_birdsong_never_triggers() -> void:
	for amp in [0.02, 0.06, 0.2]:
		var det := _make()
		_feed(det, _noise(1.0, 0.002))
		_feed(det, _mix(_noise(10.0, 0.002), birdsong(RATE, 10.0, amp)))
		check_eq(_started, 0, "birdsong at amp %s" % amp)
		_feed(det, _mix(_tone(1.0, 0.3), birdsong(RATE, 1.0, amp)))
		_feed(det, _noise(1.5, 0.002))
		check_eq(_clips.size(), 1, "a child over the birds at amp %s" % amp)
	# Why the pitch rule exists: a phrase of chirps looks sustained.
	var det := _make()
	det.voice_max_hz = 100000.0
	det.configure(RATE)
	_feed(det, _noise(1.0, 0.002))
	_feed(det, _mix(_noise(10.0, 0.002), birdsong(RATE, 10.0, 0.06)))
	check(_started > 0, "without the pitch rule the birds trigger")


func test_babble_still_starts_promptly() -> void:
	var det := _make()
	_feed(det, _noise(1.0, 0.002))
	var audio := _mix(_babble(1.5, 0.3), _noise(1.5, 0.002))
	var window := roundi(det.window_sec * RATE)
	var fed := 0
	while _started == 0 and fed < audio.size():
		det.feed(audio.slice(fed, fed + window))
		fed += window
	check_eq(_started, 1, "started")
	check(float(fed) / RATE <= 0.3, "within the first syllable, got %.2f s" % (float(fed) / RATE))
	det.feed(audio.slice(fed))
	_feed(det, _noise(1.5, 0.002))
	check_eq(_clips.size(), 1, "one clip")
